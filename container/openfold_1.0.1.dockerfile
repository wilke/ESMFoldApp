# Base image with CUDA *development* tools (includes nvcc & CUDA toolkit)
FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04

# Set noninteractive frontend
ENV DEBIAN_FRONTEND=noninteractive

# Basic system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    ca-certificates \
    build-essential \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Make "python" point to python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Upgrade pip & setuptools
RUN python -m pip install --upgrade pip setuptools wheel

# ---- PyTorch (CUDA-enabled) ----
# This uses the PyTorch extra index for CUDA 12.1 wheels
RUN pip install --index-url https://download.pytorch.org/whl/cu121 \
    torch torchvision torchaudio

# Optional: verify CUDA is visible to torch (uncomment if you want)
# RUN python - << 'EOF'
# import torch
# print("Torch version:", torch.__version__)
# print("CUDA available:", torch.cuda.is_available())
# print("CUDA device count:", torch.cuda.device_count())
# EOF

# ---- OpenFold + dependencies ----
# Install some common scientific Python deps OpenFold tends to rely on
RUN pip install \
    numpy \
    scipy \
    biopython \
    pandas \
    tqdm \
    matplotlib \
    pynvml \
    ml-collections

# Clone OpenFold and install the specific commit
WORKDIR /opt
RUN git clone https://github.com/aqlaboratory/openfold.git && \
    cd openfold && \
    git checkout 4b41059694619831a7db195b7e0988fc4ff3a307 && \
    pip install -e .

# Set workdir to repo for convenience
WORKDIR /opt/openfold

# Default command: open a shell (you can override with docker run)
CMD ["/bin/bash"]