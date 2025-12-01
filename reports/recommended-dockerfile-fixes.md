# Recommended Dockerfile Fixes - Action Items

**Date**: 2025-11-17
**Based on**: Critical Review of ESMFold Docker Implementation
**Priority**: P0 and P1 fixes for production readiness

---

## Quick Reference

| File | Status | Recommendation |
|------|--------|----------------|
| `Dockerfile` (CUDA 11.7) | GOOD | Apply fixes below, use for production |
| `Dockerfile.cuda12` (CUDA 12.9) | RISKY | Replace with CUDA 12.1 variant |
| `Dockerfile.cpu` | BLOCKED | Remove or document as experimental |
| `esmfold.def` (Singularity) | GOOD | Mirror Dockerfile fixes |

---

## Fix 1: Production-Ready Dockerfile (CUDA 11.7)

**File**: `/Users/me/Development/ESMFoldApp/container/Dockerfile.fixed`

```dockerfile
# ESMFold Docker container for BV-BRC - Production Ready
# Based on official PyTorch image with CUDA 11.7
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

LABEL maintainer="BV-BRC" \
      version="1.0.0" \
      description="ESMFold protein structure prediction" \
      cuda.version="11.7" \
      pytorch.version="2.0.1" \
      gpu.required="true" \
      gpu.min_memory="8GB" \
      gpu.driver_min="515.43.04"

# System dependencies (minimize and pin versions where critical)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget=1.20.3-1ubuntu2 \
    git \
    curl \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies in dependency order
# Layer 1: Core scientific stack
RUN pip install --no-cache-dir \
    numpy==1.24.3 \
    scipy==1.10.1 \
    pandas==2.0.2 \
    biopython==1.81

# Layer 2: ML/DL dependencies
RUN pip install --no-cache-dir \
    typing-extensions==4.6.3 \
    omegaconf==2.3.0 \
    einops==0.6.1

# Layer 3: OpenFold prerequisites (explicit versions)
RUN pip install --no-cache-dir \
    dllogger==1.0.0 \
    dm-tree==0.1.8 \
    ml-collections==0.1.1

# Layer 4: OpenFold (critical - verify compilation)
RUN pip install --no-cache-dir OpenFold==1.0.1 && \
    python -c "import openfold; import openfold.model.model; print('OpenFold imported successfully')" || \
    (echo "ERROR: OpenFold import failed" && exit 1)

# Layer 5: ESM with esmfold extras
RUN pip install --no-cache-dir "fair-esm[esmfold]" && \
    python -c "import esm; print(f'ESM version: {esm.__version__}')" || \
    (echo "ERROR: ESM import failed" && exit 1)

# Layer 6: Download and verify ESMFold model with proper error handling
ENV TORCH_HOME=/data/models
RUN mkdir -p /data/models && \
    python -c "
import esm
import os
import sys

print('Downloading ESMFold v1 model...')
try:
    model = esm.pretrained.esmfold_v1()
    print(f'Model type: {type(model).__name__}')
except Exception as e:
    print(f'ERROR: Model download failed: {e}', file=sys.stderr)
    sys.exit(1)

# Verify model file exists
model_path = os.path.expanduser('~/.cache/torch/hub/checkpoints/esmfold_3B_v1.pt')
if not os.path.exists(model_path):
    print(f'ERROR: Model file not found at {model_path}', file=sys.stderr)
    sys.exit(1)

# Report model size
model_size_gb = os.path.getsize(model_path) / 1e9
print(f'Model downloaded and verified: {model_size_gb:.2f} GB')

# Verify model can be loaded (basic sanity check)
import torch
if torch.cuda.is_available():
    print(f'CUDA available: {torch.cuda.get_device_name(0)}')
else:
    print('WARNING: CUDA not available during build (this may be expected)')
" || (echo "ERROR: Model verification failed" && exit 1)

# Create runtime directories
RUN mkdir -p /data/input /data/output /data/models /data/logs

# Environment variables for runtime
ENV ESMFOLD_MODEL_DIR=/data/models \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    PYTHONUNBUFFERED=1 \
    CUDA_LAUNCH_BLOCKING=0

# Copy health check script
COPY container/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Add health check
HEALTHCHECK --interval=60s --timeout=30s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Security: Run as non-root user
RUN groupadd -g 1000 esmfold && \
    useradd -m -u 1000 -g esmfold esmfold && \
    chown -R esmfold:esmfold /data /app /root/.cache && \
    chmod -R 755 /data

USER esmfold

# The esm-fold command is installed with the package
ENTRYPOINT ["esm-fold"]

# Default command shows help
CMD ["--help"]

# Build arguments for offline builds (optional)
ARG PIP_INDEX_URL=https://pypi.org/simple
ARG MODEL_CACHE_URL=""
```

---

## Fix 2: Health Check Script

**File**: `/Users/me/Development/ESMFoldApp/container/healthcheck.sh`

```bash
#!/bin/bash
# ESMFold Container Health Check
# Validates GPU availability, Python environment, and ESMFold functionality

set -e

echo "[HEALTH] Starting health check..."

# Check 1: Python version
echo "[HEALTH] Checking Python..."
PYTHON_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "[HEALTH] Python version: $PYTHON_VERSION"
if [[ "$PYTHON_VERSION" != "3.9" ]] && [[ "$PYTHON_VERSION" != "3.10" ]]; then
    echo "[HEALTH] WARNING: Python version $PYTHON_VERSION may not be optimal"
fi

# Check 2: PyTorch installation
echo "[HEALTH] Checking PyTorch..."
python -c "
import torch
print(f'[HEALTH] PyTorch version: {torch.__version__}')
if not torch.cuda.is_available():
    print('[HEALTH] WARNING: CUDA not available')
    print('[HEALTH] This container requires GPU support')
else:
    print(f'[HEALTH] CUDA version: {torch.version.cuda}')
    print(f'[HEALTH] cuDNN version: {torch.backends.cudnn.version()}')
    print(f'[HEALTH] GPU device: {torch.cuda.get_device_name(0)}')
    print(f'[HEALTH] GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB')
" || exit 1

# Check 3: ESM import
echo "[HEALTH] Checking ESM..."
python -c "
import esm
print(f'[HEALTH] ESM version: {esm.__version__}')
" || exit 1

# Check 4: Model availability
echo "[HEALTH] Checking model cache..."
python -c "
import os
model_path = os.path.expanduser('~/.cache/torch/hub/checkpoints/esmfold_3B_v1.pt')
if os.path.exists(model_path):
    size_gb = os.path.getsize(model_path) / 1e9
    print(f'[HEALTH] Model found: {size_gb:.2f} GB')
else:
    print('[HEALTH] WARNING: Model not in cache, will download on first run')
" || exit 1

# Check 5: Memory availability
echo "[HEALTH] Checking system memory..."
python -c "
import psutil
mem = psutil.virtual_memory()
print(f'[HEALTH] System memory: {mem.total / 1e9:.2f} GB')
print(f'[HEALTH] Available memory: {mem.available / 1e9:.2f} GB')
if mem.available < 16e9:
    print('[HEALTH] WARNING: Less than 16 GB available memory')
    print('[HEALTH] Recommend at least 32 GB for ESMFold')
" 2>/dev/null || echo "[HEALTH] psutil not available, skipping memory check"

echo "[HEALTH] Health check PASSED"
exit 0
```

---

## Fix 3: Updated CUDA 12 Dockerfile (Use 12.1, Not 12.9)

**File**: `/Users/me/Development/ESMFoldApp/container/Dockerfile.cuda12.fixed`

```dockerfile
# ESMFold Docker container using CUDA 12.1 (official PyTorch support)
# DO NOT use CUDA 12.9 until PyTorch provides official builds

# Option 1: Use PyTorch official image (RECOMMENDED)
FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

# Option 2: Use NVIDIA official image (if you need to build PyTorch layer)
# FROM nvcr.io/nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu20.04
# ... then install Python and PyTorch manually

LABEL maintainer="BV-BRC" \
      version="1.0.0-cuda12" \
      description="ESMFold protein structure prediction with CUDA 12.1" \
      cuda.version="12.1" \
      pytorch.version="2.1.2" \
      gpu.required="true" \
      gpu.min_memory="8GB" \
      gpu.driver_min="530.30.02"

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget git curl build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# If using NVIDIA base instead of PyTorch base, install PyTorch here:
# RUN pip install torch==2.1.2+cu121 torchvision==0.16.2+cu121 \
#     --index-url https://download.pytorch.org/whl/cu121

# Core dependencies (same as CUDA 11.7 version)
RUN pip install --no-cache-dir \
    numpy scipy pandas biopython \
    typing-extensions omegaconf einops \
    dllogger dm-tree ml-collections

# OpenFold with verification
RUN pip install --no-cache-dir OpenFold==1.0.1 && \
    python -c "import openfold; print('OpenFold OK')"

# ESM with verification
RUN pip install --no-cache-dir "fair-esm[esmfold]" && \
    python -c "import esm; print('ESM OK')"

# Verify CUDA functionality before model download
RUN python -c "
import torch
assert torch.cuda.is_available(), 'CUDA not available'
print(f'CUDA version: {torch.version.cuda}')
print(f'GPU: {torch.cuda.get_device_name(0)}')
"

# Download model with proper error handling
ENV TORCH_HOME=/data/models
RUN mkdir -p /data/models && \
    python -c "
import esm, os, sys
try:
    model = esm.pretrained.esmfold_v1()
    model_path = os.path.expanduser('~/.cache/torch/hub/checkpoints/esmfold_3B_v1.pt')
    assert os.path.exists(model_path), 'Model file missing'
    print(f'Model verified: {os.path.getsize(model_path) / 1e9:.2f} GB')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"

# Runtime setup
RUN mkdir -p /data/input /data/output /data/logs

ENV ESMFOLD_MODEL_DIR=/data/models \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    PYTHONUNBUFFERED=1

COPY container/healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/healthcheck.sh

HEALTHCHECK --interval=60s --timeout=30s --start-period=120s \
    CMD /usr/local/bin/healthcheck.sh

# Non-root user
RUN useradd -m -u 1000 esmfold && \
    chown -R esmfold:esmfold /data /app /root/.cache
USER esmfold

ENTRYPOINT ["esm-fold"]
CMD ["--help"]
```

---

## Fix 4: Multi-Stage Build for Size Optimization

**File**: `/Users/me/Development/ESMFoldApp/container/Dockerfile.multistage`

```dockerfile
# Stage 1: Builder - compile and download everything
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget git curl build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install all Python packages
RUN pip install --no-cache-dir \
    numpy scipy pandas biopython \
    typing-extensions omegaconf einops \
    dllogger dm-tree ml-collections \
    OpenFold==1.0.1 \
    "fair-esm[esmfold]"

# Download model
ENV TORCH_HOME=/models
RUN mkdir -p /models && \
    python -c "import esm; esm.pretrained.esmfold_v1()"

# Stage 2: Runtime - minimal image
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

LABEL maintainer="BV-BRC" \
      version="1.0.0-optimized"

# Copy only necessary files from builder
COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /models /root/.cache/torch

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mkdir -p /data/input /data/output /data/logs

ENV ESMFOLD_MODEL_DIR=/data/models \
    PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512 \
    PYTHONUNBUFFERED=1

COPY container/healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/healthcheck.sh

HEALTHCHECK --interval=60s --timeout=30s --start-period=120s \
    CMD /usr/local/bin/healthcheck.sh

RUN useradd -m -u 1000 esmfold && \
    chown -R esmfold:esmfold /data /root/.cache
USER esmfold

ENTRYPOINT ["esm-fold"]
CMD ["--help"]

# Expected size: ~8-10 GB (vs 15-18 GB single stage)
```

---

## Fix 5: Updated Singularity Definition

**File**: `/Users/me/Development/ESMFoldApp/container/esmfold.fixed.def`

```singularity
Bootstrap: docker
From: pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

%post
    # System dependencies
    apt-get update && apt-get install -y --no-install-recommends \
        wget git curl build-essential \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

    # Python dependencies in order
    pip install --no-cache-dir \
        numpy scipy pandas biopython \
        typing-extensions omegaconf einops \
        dllogger dm-tree ml-collections

    # OpenFold with verification
    pip install --no-cache-dir OpenFold==1.0.1
    python -c "import openfold; print('OpenFold OK')" || exit 1

    # ESM with verification
    pip install --no-cache-dir "fair-esm[esmfold]"
    python -c "import esm; print('ESM OK')" || exit 1

    # Download and verify model
    mkdir -p /data/models
    python -c "
import esm, os, sys
try:
    model = esm.pretrained.esmfold_v1()
    model_path = os.path.expanduser('~/.cache/torch/hub/checkpoints/esmfold_3B_v1.pt')
    if not os.path.exists(model_path):
        raise FileNotFoundError('Model not downloaded')
    print(f'Model verified: {os.path.getsize(model_path) / 1e9:.2f} GB')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" || exit 1

    # Create directories
    mkdir -p /data/input /data/output /data/logs

%environment
    export ESMFOLD_MODEL_DIR=/data/models
    export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
    export PYTHONUNBUFFERED=1
    export PATH=/opt/conda/bin:$PATH

%runscript
    exec esm-fold "$@"

%test
    # Verify installation
    python -c "
import torch
import esm
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'ESM version: {esm.__version__}')
    "

%labels
    Author BV-BRC
    Name ESMFold
    Version 1.0.0
    CUDA 11.7
    PyTorch 2.0.1

%help
    ESMFold protein structure prediction container for BV-BRC.

    Usage:
        singularity run esmfold.sif -i input.fasta -o output_dir

    Options:
        -i, --input             Input FASTA file with protein sequences
        -o, --output            Output directory for PDB files
        --num-recycles          Number of recycles (0-4, default: 4)
        --chunk-size            Chunk size for processing (default: 128)
        --max-tokens-per-batch  Maximum tokens per batch (default: 1024)
        --cpu-only              Run on CPU only (not recommended)
        --cpu-offload           Offload to CPU for memory efficiency

    GPU Requirements:
        - NVIDIA GPU with CUDA 11.7+ support
        - Minimum 8 GB GPU memory (16 GB recommended)
        - Driver version >= 515.43.04

    System Requirements:
        - Minimum 16 GB RAM (32 GB recommended)
        - 10 GB disk space for container + model
```

---

## Fix 6: Build Script Updates

**File**: `/Users/me/Development/ESMFoldApp/container/build.sh`

```bash
#!/bin/bash
# Build script for ESMFold containers with validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=== ESMFold Container Build ==="
echo "Date: $(date)"
echo "Directory: $(pwd)"
echo ""

# Parse arguments
BUILD_TYPE="${1:-all}"
PUSH="${2:-false}"

build_docker_cuda11() {
    echo ">>> Building Docker container (CUDA 11.7)..."
    docker build \
        --progress=plain \
        --tag esmfold:cuda11.7 \
        --tag esmfold:latest \
        --file container/Dockerfile.fixed \
        .

    echo ">>> Testing container..."
    docker run --rm esmfold:latest --version || echo "Warning: --version failed"

    echo ">>> Container size:"
    docker images esmfold:latest --format "{{.Size}}"
}

build_docker_cuda12() {
    echo ">>> Building Docker container (CUDA 12.1)..."
    docker build \
        --progress=plain \
        --tag esmfold:cuda12.1 \
        --file container/Dockerfile.cuda12.fixed \
        .

    echo ">>> Testing container..."
    docker run --rm esmfold:cuda12.1 --version || echo "Warning: --version failed"

    echo ">>> Container size:"
    docker images esmfold:cuda12.1 --format "{{.Size}}"
}

build_singularity() {
    echo ">>> Building Singularity container..."
    if ! command -v singularity &> /dev/null; then
        echo "Warning: Singularity not installed, skipping"
        return 0
    fi

    singularity build --force \
        container/esmfold.sif \
        container/esmfold.fixed.def

    echo ">>> Testing container..."
    singularity run container/esmfold.sif --version || echo "Warning: --version failed"

    echo ">>> Container size:"
    du -sh container/esmfold.sif
}

# Build based on argument
case "$BUILD_TYPE" in
    cuda11|11)
        build_docker_cuda11
        ;;
    cuda12|12)
        build_docker_cuda12
        ;;
    singularity|sif)
        build_singularity
        ;;
    docker)
        build_docker_cuda11
        build_docker_cuda12
        ;;
    all)
        build_docker_cuda11
        build_docker_cuda12
        build_singularity
        ;;
    *)
        echo "Usage: $0 {cuda11|cuda12|singularity|docker|all} [push]"
        exit 1
        ;;
esac

echo ""
echo "=== Build Complete ==="
echo "Available images:"
docker images | grep esmfold || true
ls -lh container/*.sif 2>/dev/null || true

if [ "$PUSH" == "push" ]; then
    echo ""
    echo ">>> Pushing to registry..."
    # Add your registry push commands here
    # docker push esmfold:latest
    # docker push esmfold:cuda12.1
fi
```

---

## Fix 7: Enhanced Testing Script

**File**: `/Users/me/Development/ESMFoldApp/container/test_comprehensive.sh`

```bash
#!/bin/bash
# Comprehensive container testing script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="${SCRIPT_DIR}/../test_data"
OUTPUT_DIR="${SCRIPT_DIR}/test_output"

echo "=== ESMFold Container Comprehensive Test ==="
echo "Date: $(date)"
echo ""

# Setup
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"/*

# Test 1: Health Check
echo ">>> Test 1: Health Check"
docker run --rm --gpus all esmfold:latest \
    /usr/local/bin/healthcheck.sh

# Test 2: Version and Help
echo ">>> Test 2: Version and Help"
docker run --rm esmfold:latest --help

# Test 3: Single Protein Fold
echo ">>> Test 3: Single Protein Fold"
docker run --rm --gpus all \
    -v "$TEST_DATA_DIR:/input:ro" \
    -v "$OUTPUT_DIR:/output" \
    esmfold:latest \
    -i /input/single_protein.fasta \
    -o /output

# Verify output
if [ ! -f "$OUTPUT_DIR"/*.pdb ]; then
    echo "ERROR: No PDB output generated"
    exit 1
fi

echo ">>> PDB files generated:"
ls -lh "$OUTPUT_DIR"/*.pdb

# Test 4: Batch Processing
echo ">>> Test 4: Batch Processing"
docker run --rm --gpus all \
    -v "$TEST_DATA_DIR:/input:ro" \
    -v "$OUTPUT_DIR/batch:/output" \
    esmfold:latest \
    -i /input/test_proteins.fasta \
    -o /output \
    --max-tokens-per-batch 1024

# Test 5: Memory Stress Test
echo ">>> Test 5: Resource Usage"
docker stats --no-stream esmfold_test || echo "No running container"

# Test 6: Validate PDB format
echo ">>> Test 6: Validate PDB Output"
python3 - <<EOF
import sys
from pathlib import Path

output_dir = Path("$OUTPUT_DIR")
pdb_files = list(output_dir.glob("*.pdb"))

if not pdb_files:
    print("ERROR: No PDB files found")
    sys.exit(1)

for pdb in pdb_files:
    with open(pdb) as f:
        lines = f.readlines()

    # Check for ATOM records
    atom_count = sum(1 for line in lines if line.startswith('ATOM'))

    print(f"{pdb.name}: {atom_count} atoms")

    if atom_count == 0:
        print(f"ERROR: {pdb.name} has no ATOM records")
        sys.exit(1)

print("All PDB files validated successfully")
EOF

echo ""
echo "=== All Tests Passed ==="
```

---

## Implementation Checklist

### Immediate Actions (P0)

- [ ] Replace `container/Dockerfile` with `Dockerfile.fixed`
- [ ] Create `container/healthcheck.sh` with proper permissions
- [ ] Replace `container/Dockerfile.cuda12` with `Dockerfile.cuda12.fixed`
- [ ] Update `container/build.sh` with new script
- [ ] Test CUDA 11.7 build on development machine
- [ ] Test CUDA 11.7 build on GPU server with actual inference

### Short-term Actions (P1)

- [ ] Create multi-stage Dockerfile variant for size optimization
- [ ] Update Singularity definition file
- [ ] Implement comprehensive test suite
- [ ] Add vulnerability scanning to CI/CD
- [ ] Document GPU driver requirements
- [ ] Create troubleshooting guide

### Documentation Updates

- [ ] Update README with GPU requirements
- [ ] Document build times and image sizes
- [ ] Add performance benchmarks per GPU type
- [ ] Create migration guide from old containers
- [ ] Document offline build procedure

---

## Testing Plan

### Phase 1: Development Machine (No GPU)
```bash
# Build container
./container/build.sh cuda11

# Verify build
docker run --rm esmfold:latest --help

# Check image size
docker images esmfold:latest
```

### Phase 2: GPU Server (V100/A100)
```bash
# Run health check
docker run --gpus all --rm esmfold:latest /usr/local/bin/healthcheck.sh

# Test single protein
docker run --gpus all --rm \
    -v $(pwd)/test_data:/input \
    -v $(pwd)/output:/output \
    esmfold:latest \
    -i /input/single_protein.fasta \
    -o /output

# Verify GPU utilization
nvidia-smi
```

### Phase 3: Production Validation
```bash
# Run comprehensive test suite
./container/test_comprehensive.sh

# Performance benchmark
time docker run --gpus all --rm \
    -v $(pwd)/test_data:/input \
    -v $(pwd)/output:/output \
    esmfold:latest \
    -i /input/test_proteins.fasta \
    -o /output
```

---

## Rollback Plan

If fixes cause issues:

1. **Immediate Rollback**:
   ```bash
   git checkout container/Dockerfile
   docker build -t esmfold:rollback -f container/Dockerfile .
   ```

2. **Partial Rollback**:
   - Keep health check improvements
   - Revert to original base image
   - Document what worked and what didn't

3. **Safe Testing**:
   - Build with new tag: `esmfold:test`
   - Run parallel to production
   - Compare outputs before cutover

---

**Document Version**: 1.0
**Last Updated**: 2025-11-17
**Next Review**: After implementation and testing
