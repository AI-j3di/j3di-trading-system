# ══════════════════════════════════════════════════════════════════════════════
# J3DI Trading System — Development Container (GPU)
# Base: NVIDIA CUDA 12.6 + cuDNN 9 on Ubuntu 22.04 (x86_64)
# Target: Lenovo P16 — RTX 3000 Ada 12 GB / 128 GB RAM
# ══════════════════════════════════════════════════════════════════════════════

# ── Stage 1: System + TA-Lib ─────────────────────────────────────────────────
FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04 AS base

LABEL maintainer="J3DI Team"
LABEL description="J3DI Trading System — GPU Dev Environment (P16)"

# Prevent interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# First: install PPA prerequisites (gnupg is required to authenticate the key)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    gnupg \
    ca-certificates \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Second: add the PPA and install Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
    && rm -rf /var/lib/apt/lists/*

# Third: install build tools (separate layer — these rarely change)
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        gfortran \
        cmake \
        pkg-config \
        automake \
        autoconf \
        libtool \
        libhdf5-dev \
        postgresql-client \
        git \
        vim \
        htop \
    && rm -rf /var/lib/apt/lists/*

# ── Set Python 3.12 as default ───────────────────────────────────────────────
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

# ── Install TA-Lib C library from source (local copy) ────────────────────────
COPY ta-lib-0.4.0-src.tar.gz /tmp/ta-lib-0.4.0-src.tar.gz
RUN cd /tmp \
    && tar -xzf ta-lib-0.4.0-src.tar.gz \
    && cd ta-lib \
    && ./configure --prefix=/usr/local CFLAGS="-Wno-error -Wno-implicit-function-declaration" \
    && make -j1 \
    && make install \
    && ldconfig \
    && cd / && rm -rf /tmp/ta-lib*

# ── Install TA-Lib Python wrapper - v2 ────────────────────────────────────────────
RUN pip install --no-cache-dir "TA-Lib>=0.4.0"

# ── Stage 2: Python ML stack (layer-cached for fast rebuilds) ────────────────

# PyTorch with CUDA 12.6 (largest download — cache this layer)
RUN pip install --no-cache-dir \
    --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu128

# TensorFlow with CUDA (auto-detects GPU since TF 2.16+)
RUN pip install --no-cache-dir "tensorflow[and-cuda]"


# Remaining requirements
COPY requirements-docker.txt /tmp/requirements-docker.txt
RUN pip install --no-cache-dir --ignore-installed blinker \
    && pip install --no-cache-dir -r /tmp/requirements-docker.txt \
    && rm /tmp/requirements-docker.txt

# ── Create non-root user ─────────────────────────────────────────────────────
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} j3di && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash j3di

# ── Directory structure ──────────────────────────────────────────────────────
RUN mkdir -p /app/src /app/config /app/data /app/notebooks \
             /app/tests /app/logs /app/scripts /app/models \
    && chown -R j3di:j3di /app

WORKDIR /app

# ── Environment variables ────────────────────────────────────────────────────
ENV PYTHONPATH=/app \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # CUDA
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    # cuDNN
    CUDNN_PATH=/usr/lib/x86_64-linux-gnu \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH} \
    # Jupyter
    JUPYTER_CONFIG_DIR=/app/.jupyter \
    # MLflow
    MLFLOW_TRACKING_URI=http://mlflow:5000 \
    # TensorFlow — suppress info logs, confirm GPU
    TF_CPP_MIN_LOG_LEVEL=1 \
    # XGBoost — use CUDA
    XGBOOST_DEVICE=cuda

# ── Switch to non-root ───────────────────────────────────────────────────────
USER j3di

# ── Default: JupyterLab ─────────────────────────────────────────────────────
EXPOSE 8888 6006
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--NotebookApp.token=j3di"]
