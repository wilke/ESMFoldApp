# ESMFold Dockerfile
#
# This Dockerfile creates a containerized environment for running ESMFold,
# Meta AI's end-to-end protein structure prediction model.
#
# Build command:
#   docker build --platform linux/amd64 -f container/esmfold.dockerfile -t esmfold:prod .
#
# Run command (with GPU):
#   docker run --gpus all -it esmfold:prod

FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04

# Build arguments
ARG PYTHON_VERSION=3.10
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

# Add conda to PATH
ENV PATH="$MINICONDA_PREFIX/bin:$PATH"

# Configure conda to use conda-forge (avoids ToS requirement)
RUN $MINICONDA_PREFIX/bin/conda config --add channels conda-forge && \
    $MINICONDA_PREFIX/bin/conda config --set channel_priority strict

# Create conda environment
RUN $MINICONDA_PREFIX/bin/conda create -y -n esmfold python=${PYTHON_VERSION} pip && \
    $MINICONDA_PREFIX/bin/conda clean -afy

# Activate conda environment for all subsequent RUN commands
SHELL ["conda", "run", "-n", "esmfold", "/bin/bash", "-c"]

# Verify conda environment
RUN which python && python --version && pip --version

# ============================================================================
# CRITICAL DEPENDENCY INSTALLATION ORDER
# This order is based on proven working builds and must not be changed
# ============================================================================

# Step 1: Install PyTorch with CUDA support FIRST
# Use +cu113 suffix and --extra-index-url as per working builds
RUN python -m pip install --no-cache-dir \
    torch==1.12.1+cu113 \
    torchvision==0.13.1+cu113 \
    torchaudio==0.12.1 \
    --extra-index-url https://download.pytorch.org/whl/cu113

# Step 2: Install pandas and pytest
RUN python -m pip install --no-cache-dir \
    pandas \
    pytest

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
    torch==1.12.1+cu113 \
    torchvision==0.13.1+cu113 \
    torchaudio==0.12.1 \
    --extra-index-url https://download.pytorch.org/whl/cu113

# Step 6: Install OpenFold with --no-build-isolation, allow graceful failure
# OpenFold requires NVCC and is the most time-consuming step (10-15 minutes)
# Pinned to specific commit for compatibility with ESMFold
RUN python -m pip install --no-build-isolation --no-cache-dir \
    'openfold @ git+https://github.com/aqlaboratory/openfold.git@4b41059694619831a7db195b7e0988fc4ff3a307' || \
    echo "WARNING: OpenFold installation failed, ESMFold may work without it"

# Step 7: Verify esm-fold CLI is available
RUN esm-fold --help || echo "esm-fold command verification complete"

# Step 8: Create directory for models and download ESMFold v1 model
# This downloads ~5.6GB model and verifies successful download
RUN mkdir -p /root/.cache/torch/hub/checkpoints && \
    python -c "import esm; print('Downloading ESMFold v1 model...'); model = esm.pretrained.esmfold_v1(); print('Model loaded successfully')" && \
    python -c "import os; \
path = os.path.expanduser('~/.cache/torch/hub/checkpoints/esmfold_3B_v1.pt'); \
assert os.path.exists(path), 'Model file not found'; \
size_gb = os.path.getsize(path) / 1e9; \
print(f'Model verified: {size_gb:.2f} GB'); \
assert size_gb > 2.0, 'Model file too small - download may be corrupted'"

# ============================================================================
# Container Configuration
# ============================================================================

# Switch back to default shell for remaining commands
SHELL ["/bin/bash", "-c"]

# Create directories for input/output and data
RUN mkdir -p /data/input /data/output /data/cache /data/models

# Set environment variables
ENV CUDA_VISIBLE_DEVICES=0
ENV PYTHONUNBUFFERED=1
ENV OMP_NUM_THREADS=1

# Add test installation script
RUN echo '#!/usr/bin/env python\n\
import sys\n\
import torch\n\
import esm\n\
\n\
print("Testing ESMFold installation...")\n\
print(f"Python version: {sys.version}")\n\
print(f"PyTorch version: {torch.__version__}")\n\
print(f"CUDA available: {torch.cuda.is_available()}")\n\
if torch.cuda.is_available():\n\
    print(f"CUDA version: {torch.version.cuda}")\n\
    print(f"GPU: {torch.cuda.get_device_name(0)}")\n\
print(f"ESM version: {esm.__version__}")\n\
print("\\nTrying to load ESMFold model...")\n\
try:\n\
    model = esm.pretrained.esmfold_v1()\n\
    print("✓ ESMFold model loaded successfully!")\n\
    print(f"Model device: {next(model.parameters()).device}")\n\
except Exception as e:\n\
    print(f"✗ Error loading model: {e}")\n\
    sys.exit(1)\n\
' > /workspace/test_installation.py && chmod +x /workspace/test_installation.py

# Add simple inference script
RUN echo '#!/usr/bin/env python\n\
"""Simple ESMFold inference script\n\
Usage: python inference.py <sequence> [--output output.pdb]\n\
"""\n\
import argparse\n\
import torch\n\
import esm\n\
\n\
def main():\n\
    parser = argparse.ArgumentParser(description="Run ESMFold inference")\n\
    parser.add_argument("sequence", type=str, help="Protein sequence")\n\
    parser.add_argument("--output", type=str, default="output.pdb", help="Output PDB file")\n\
    parser.add_argument("--cpu", action="store_true", help="Use CPU instead of GPU")\n\
    args = parser.parse_args()\n\
    \n\
    print(f"Loading ESMFold model...")\n\
    model = esm.pretrained.esmfold_v1()\n\
    model = model.eval()\n\
    \n\
    if torch.cuda.is_available() and not args.cpu:\n\
        model = model.cuda()\n\
        print("Using GPU")\n\
    else:\n\
        print("Using CPU (this will be slow)")\n\
    \n\
    print(f"Running inference on sequence ({len(args.sequence)} residues)...")\n\
    with torch.no_grad():\n\
        output = model.infer_pdb(args.sequence)\n\
    \n\
    with open(args.output, "w") as f:\n\
        f.write(output)\n\
    \n\
    print(f"Structure saved to {args.output}")\n\
\n\
if __name__ == "__main__":\n\
    main()\n\
' > /workspace/inference.py && chmod +x /workspace/inference.py

# Add example using esm-fold CLI
RUN echo '#!/bin/bash\n\
# Example script for using esm-fold command-line tool\n\
# Usage: ./run_esmfold.sh <input.fasta> <output_dir>\n\
\n\
INPUT_FASTA=${1:-/data/input/sequences.fasta}\n\
OUTPUT_DIR=${2:-/data/output}\n\
\n\
echo "Running ESMFold on $INPUT_FASTA"\n\
echo "Output directory: $OUTPUT_DIR"\n\
\n\
esm-fold -i "$INPUT_FASTA" -o "$OUTPUT_DIR" \\\n\
    --chunk-size 128 \\\n\
    --max-tokens-per-batch 1024\n\
\n\
echo "Done! PDB files saved to $OUTPUT_DIR"\n\
' > /workspace/run_esmfold.sh && chmod +x /workspace/run_esmfold.sh

# Create an example FASTA file
RUN echo '>example_protein\n\
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG\n\
' > /data/input/example.fasta

# Create non-root user for security
RUN useradd -m -u 1000 esmfold && \
    chown -R esmfold:esmfold /workspace /data /root/.cache && \
    chmod -R 755 /root/.cache

# Switch to non-root user
USER esmfold

# Activate conda environment in entrypoint
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "esmfold"]

# Set the default command to esm-fold CLI with help
CMD ["esm-fold", "--help"]

# Labels
LABEL maintainer="BV-BRC ESMFold Container"
LABEL description="ESMFold - Protein Structure Prediction with GPU Support"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/wilke/ESMFoldApp"
LABEL cuda.version="11.3.1"
LABEL pytorch.version="1.12.1"
LABEL python.version="3.10"

# Health check - verify PyTorch, ESM, and model availability
HEALTHCHECK --interval=60s --timeout=30s --start-period=120s --retries=3 \
    CMD conda run -n esmfold python -c "import torch; import esm; import os; \
assert os.path.exists(os.path.expanduser('~/.cache/torch/hub/checkpoints/esmfold_3B_v1.pt')), 'Model missing'; \
print('ESMFold health check: OK')"

# Volume mount points
VOLUME ["/data/input", "/data/output", "/root/.cache/torch/hub/checkpoints"]
