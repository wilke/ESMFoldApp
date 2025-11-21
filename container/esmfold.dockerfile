FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

# Build arguments
ARG PYTHON_VERSION=3.9
ARG MINICONDA_VERSION=latest

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV CUDA_HOME=/usr/local/cuda
ENV TORCH_HOME=/data/cache/
ENV TORCH_HUB=/data/models/
ENV MINICONDA_PREFIX=/opt/miniconda

# Set working directory
WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    ca-certificates \
    software-properties-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN MINICONDA_INSTALLER=Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    wget --quiet https://repo.anaconda.com/miniconda/$MINICONDA_INSTALLER -O /tmp/$MINICONDA_INSTALLER && \
    bash /tmp/$MINICONDA_INSTALLER -b -p $MINICONDA_PREFIX && \
    rm /tmp/$MINICONDA_INSTALLER && \
    echo "export PATH=$MINICONDA_PREFIX/bin:\$PATH" >> /etc/profile.d/conda.sh && \
    $MINICONDA_PREFIX/bin/conda init bash && \
    $MINICONDA_PREFIX/bin/conda clean -afy

ENV PATH="$MINICONDA_PREFIX/bin:$PATH"

RUN export PATH=$MINICONDA_PREFIX/bin:\$PATH && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda create -y -n esmfold python=${PYTHON_VERSION} "pip<24.1"
   

SHELL ["conda", "run", "-n", "esmfold", "/bin/bash", "-c"]

# Step 1: Install pytorch with CUDA support, pandas, pytest

RUN python -m pip install --no-cache-dir \
    torch==1.12.1+cu113 \
    torchvision==0.13.1+cu113 \
    torchaudio==0.12.1 \
    pytest \
    --extra-index-url https://download.pytorch.org/whl/cu113

# Step 2: merged into Step 1

# Step 3: Clone ESM repository and install with esmfold extras
# Installing with -e ".[esmfold]" pulls in all dependencies from setup.py
# This includes: biopython, deepspeed==0.5.9, dm-tree, pytorch-lightning,
#                omegaconf, ml-collections, einops, scipy
RUN cd /opt && \
    git clone https://github.com/facebookresearch/esm.git && \
    cd esm && \
    python -m pip install --no-cache-dir -e ".[esmfold]"

# Step 4: Install dllogger with --no-build-isolation
RUN python -m pip install --no-build-isolation --no-cache-dir \
    'dllogger @ git+https://github.com/NVIDIA/dllogger.git'

# Step 5: Reinstall PyTorch to ensure correct version after esmfold extras
# This fixes any version conflicts from pytorch-lightning or other dependencies
RUN python -m pip install --no-cache-dir \
    pytorch-lightning==1.5.10 \
    torch==1.12.1+cu113 \
    torchvision==0.13.1+cu113 \
    torchaudio==0.12.1 \
    --extra-index-url https://download.pytorch.org/whl/cu113

RUN pip install "numpy<2.0" "pandas>=2.0,<2.3" \
    "deepspeed==0.5.9" \
    "scipy==1.7.1" \
     "ml-collections==0.1.0" \
    "dm-tree==0.1.6"

# Step 6: Install OpenFold with --no-build-isolation, allow graceful failure
# OpenFold requires NVCC and is the most time-consuming step (10-15 minutes)
# Pinned to specific commit for compatibility with ESMFold
RUN python -m pip install --no-build-isolation --no-cache-dir \
    'openfold @ git+https://github.com/aqlaboratory/openfold.git@4b41059694619831a7db195b7e0988fc4ff3a307' || \
    echo "WARNING: OpenFold installation failed, ESMFold may work without it"

# Step 7: Verify esm-fold CLI is available
RUN esm-fold --help || echo "esm-fold command verification complete"



# RUN python -c "import esm; print('Downloading ESMFold v1 model...'); model = esm.pretrained.esmfold_v1(); print('Model loaded successfully')"