# --- BASE COM CUDA + PYTHON 3.12 ---
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Pacotes essenciais + venv
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    curl ffmpeg git git-lfs wget vim \
    libgl1 libglib2.0-0 build-essential gcc && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    python3.12 -m venv /opt/venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# PyTorch + ferramentas
RUN pip install --upgrade pip && \
    pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128 && \
    pip freeze | grep -E "^(torch|torchvision|torchaudio)" > /tmp/torch-constraint.txt && \
    pip install packaging setuptools wheel pyyaml gdown opencv-python runpod jupyterlab jupyter-server-terminals terminado psutil

# Clona o ComfyUI e instala requirements
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI && \
    pip install -r /ComfyUI/requirements.txt --constraint /tmp/torch-constraint.txt

# --- FINAL IMAGE ---
FROM base AS final

WORKDIR /ComfyUI
ENV PATH="/opt/venv/bin:$PATH"

RUN mkdir -p /models /ComfyUI/user/default/workflows

COPY start.sh /start.sh
COPY workflows /workflows
RUN chmod +x /start.sh

EXPOSE 8188 8888
CMD ["/start.sh"]