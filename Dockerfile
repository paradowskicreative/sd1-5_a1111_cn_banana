FROM nvidia/cuda:11.7.1-runtime-ubuntu22.04
  
# To use a different model, change the model URL below:
ARG MODEL_URL='https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt'

# If you are using a private Huggingface model (sign in required to download) insert your Huggingface
# access token (https://huggingface.co/settings/tokens) below:
ARG HF_TOKEN=''

# AWS Configuration
ARG AWS_REGION=''
ARG AWS_ACCESS_KEY=''
ARG AWS_SECRET_ACCESS_KEY=''
ARG BUCKET_NAME=''
ARG CKPT_OBJECT_KEY=''
ARG CONTROLNET_FOLDER=''

RUN apt update && apt-get -y install git wget \
    ffmpeg libsm6 libxext6 \
    python3.10 python3.10-venv python3-pip \
    build-essential libgl-dev libglib2.0-0 vim
RUN ln -s /usr/bin/python3.10 /usr/bin/python

RUN useradd -ms /bin/bash banana
WORKDIR /app

RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git checkout 58c4777cc0e2ef1c1ac76cbfbec6eab330de931a && \
    cd extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet.git && \
    cd sd-webui-controlnet && \
    git checkout 3f5c272098ea5a32399dff72fd0160d2416e58c4
WORKDIR /app/stable-diffusion-webui

ENV MODEL_URL=${MODEL_URL}
ENV HF_TOKEN=${HF_TOKEN}

ENV AWS_REGION=${AWS_REGION}
ENV AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV BUCKET_NAME=${BUCKET_NAME}
ENV CKPT_OBJECT_KEY=${CKPT_OBJECT_KEY}
ENV CONTROLNET_FOLDER=${CONTROLNET_FOLDER}

RUN pip3 install --upgrade pip
ADD requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

RUN pip install -q opencv-contrib-python
RUN pip install -q controlnet_aux

ADD download_checkpoint.py .
RUN python download_checkpoint.py

ADD prepare.py .
RUN python prepare.py --skip-torch-cuda-test --xformers --reinstall-torch --reinstall-xformers

ADD download.py download.py
RUN python download.py --use-cpu=all

RUN pip install dill

RUN mkdir -p extensions/banana/scripts
ADD script.py extensions/banana/scripts/banana.py
ADD app.py app.py
ADD server.py server.py

CMD ["python", "server.py", "--xformers", "--disable-safe-unpickle", "--lowram", "--allow-code", "--enable-insecure-extension-access",  "--no-hashing", "--listen", "--port", "8000"]
