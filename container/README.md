# ESMFold Container Definitions

Container definitions for ESMFold protein structure prediction with BV-BRC integration.

## Directory Structure

```
container/
├── docker/                     # Docker container definitions
│   ├── Dockerfile.cuda11       # GPU (CUDA 11.3, V100/A100)
│   ├── Dockerfile.cuda12       # GPU (CUDA 12.1, H100 compatible)
│   ├── Dockerfile.cpu          # CPU-only version
│   ├── Dockerfile.bvbrc        # BV-BRC integrated version
│   ├── Dockerfile.dev          # Development version
│   └── openfold_1.0.1.dockerfile # OpenFold build utility
│
├── apptainer/                  # Apptainer/Singularity definitions
│   ├── ESMFoldApp.def          # Primary production definition
│   ├── esmfold-bvbrc.def       # BV-BRC with Perl runtime
│   ├── esmfold-base.def        # Base image definition
│   └── esmfold_pytorch.def     # H100/PyTorch 2.x compatible
│
├── tests/                      # Container test scripts
└── archive/                    # Deprecated definitions
```

## Container Versions

### OpenFold-based (Original)

These containers use the original ESMFold with OpenFold dependencies:

| Container | Base Image | GPU Support | Notes |
|-----------|------------|-------------|-------|
| `Dockerfile.cuda11` | nvidia/cuda:11.3.1 | V100, A100 | Production |
| `Dockerfile.cuda12` | nvidia/cuda:12.1.0 | V100, A100, H100 | CUDA 12 |
| `Dockerfile.cpu` | python:3.9-slim | None | Testing only |
| `ESMFoldApp.def` | Local base image | V100, A100 | Primary Apptainer |
| `esmfold_pytorch.def` | pytorch:2.0.1 | H100 | PyTorch 2.x |

### HuggingFace Version (Lightweight)

The `esm_hf/` package provides a lightweight alternative:

| Container | Base Image | GPU Support | Notes |
|-----------|------------|-------------|-------|
| `esm_hf/Dockerfile` | nvidia/cuda:12.4.0-runtime | V100, A100, H100 | No compilation |
| `esm_hf/esmfold_hf.def` | nvidia/cuda:12.4.0-runtime | V100, A100, H100 | Apptainer |

**Benefits of HuggingFace version:**
- No OpenFold compilation required
- Smaller container size
- Supports H100 GPUs (PyTorch 2.6)
- Memory optimization options (`--fp16`, `--chunk-size`)

## Building Containers

### Docker

```bash
# GPU version (CUDA 11.3)
docker build -f docker/Dockerfile.cuda11 -t esmfold:cuda11 .

# GPU version (CUDA 12, H100 compatible)
docker build -f docker/Dockerfile.cuda12 -t esmfold:cuda12 .

# CPU only
docker build -f docker/Dockerfile.cpu -t esmfold:cpu .

# HuggingFace version (recommended for H100)
cd ../esm_hf && docker build -t esmfold-hf:latest .
```

### Apptainer/Singularity

```bash
# Primary production build
apptainer build esmfold.sif apptainer/ESMFoldApp.def

# H100 compatible (PyTorch 2.x)
apptainer build esmfold-pytorch.sif apptainer/esmfold_pytorch.def

# HuggingFace version
apptainer build esmfold-hf.sif ../esm_hf/esmfold_hf.def
```

## Running Predictions

### Docker

```bash
docker run --gpus all \
  -v /path/to/input:/input \
  -v /path/to/output:/output \
  esmfold:cuda11 \
  esm-fold -i /input/sequences.fasta -o /output
```

### Apptainer

```bash
apptainer run --nv esmfold.sif \
  esm-fold -i sequences.fasta -o output_dir
```

### HuggingFace Version

```bash
# Docker
docker run --gpus all \
  -v $(pwd):/data \
  esmfold-hf:latest \
  esm-fold-hf -i /data/input.fasta -o /data/output --fp16

# Apptainer
apptainer run --nv esmfold-hf.sif \
  esm-fold-hf -i input.fasta -o output/ --fp16 --chunk-size 64
```

## Base Image Dependencies

```
OpenFold Containers:
├── nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04  (V100/A100)
├── nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04  (H100)
└── pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

HuggingFace Containers:
└── nvidia/cuda:12.4.0-runtime-ubuntu22.04       (All GPUs)
```

## Testing

```bash
# Quick syntax validation
./tests/test_stage1_syntax.sh

# CPU-only testing
./tests/test_stage2_cpu.sh

# Full GPU testing (requires GPU)
./tests/test_stage3_gpu.sh
```

## Related Documentation

- [Benchmarks](../docs/BENCHMARKS.md) - Performance data
- [HuggingFace README](../esm_hf/README.md) - Lightweight version
- [BV-BRC Integration](DOCUMENTATION_STATUS.md) - Service integration
