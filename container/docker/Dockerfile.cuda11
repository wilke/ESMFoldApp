# ESMFold Docker container for BV-BRC
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    git \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Python dependencies in correct order
# PyTorch is already in the base image, but we need additional packages
RUN pip install --no-cache-dir \
    biopython \
    typing-extensions \
#    dllogger \
    dm-tree \
    ml-collections \
    OpenFold==1.0.1

# Install ESM after dependencies are ready
# RUN pip install --no-cache-dir "fair-esm[esmfold]"
RUN pip install "fair-esm[esmfold]" && \
    pip install 'dllogger @ git+https://github.com/NVIDIA/dllogger.git' && \
    pip install 'openfold @ git+https://github.com/aqlaboratory/openfold.git@4b41059694619831a7db195b7e0988fc4ff3a307'

# Download and cache ESMFold models
# This pre-downloads the model to avoid runtime delays
RUN python -c "import esm; model = esm.pretrained.esmfold_v1()"

# Create directories for input/output
RUN mkdir -p /data/input /data/output /data/models

# Set environment variables
ENV ESMFOLD_MODEL_DIR=/data/models
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# The esm-fold command is installed with the package
# Set it as the entrypoint for direct usage
ENTRYPOINT ["esm-fold"]

# Default command shows help
CMD ["--help"]