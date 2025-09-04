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

# Install Python dependencies
# Using the official ESM package with esmfold extras
RUN pip install --no-cache-dir \
    "fair-esm[esmfold]" \
    biopython \
    dllogger \
    dm-tree \
    ml-collections \
    OpenFold==1.0.1

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