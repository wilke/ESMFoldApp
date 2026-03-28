# ESMFold BV-BRC Application

ESMFold protein structure prediction service integrated with the BV-BRC (Bacterial and Viral Bioinformatics Resource Center) platform.

## Overview

This application provides protein structure prediction using Meta's ESMFold model, packaged as a BV-BRC AppService module with GPU acceleration support.

**Status**: Alpha Release v0.9.0

## Features

- **ESMFold Integration**: Meta's state-of-the-art protein folding model (ESM2_t36_3B_UR50D)
- **GPU Acceleration**: V100, A100, and H100 GPU support
- **Two Implementations**: Original OpenFold-based and lightweight HuggingFace version
- **BV-BRC Integration**: Full workspace I/O and service framework compatibility
- **Container Deployment**: Docker and Apptainer/Singularity support

## Container Versions

| Version | Location | GPU Support | Use Case |
|---------|----------|-------------|----------|
| OpenFold (CUDA 11.3) | `container/docker/Dockerfile.cuda11` | V100, A100 | Production |
| OpenFold (CUDA 12) | `container/docker/Dockerfile.cuda12` | V100, A100, H100 | H100 support |
| HuggingFace | `esm_hf/` | V100, A100, H100 | Lightweight, no compilation |

**Recommendation**: Use the HuggingFace version (`esm_hf/`) for new deployments - it's simpler to build and supports all GPU types.

## Quick Start

### HuggingFace Version (Recommended)

```bash
# Install
cd esm_hf && pip install -e .

# Run prediction
esm-fold-hf -i sequences.fasta -o output/ --fp16 --chunk-size 64

# Or use Docker
docker build -t esmfold-hf:latest esm_hf/
docker run --gpus all -v $(pwd):/data esmfold-hf:latest \
  esm-fold-hf -i /data/input.fasta -o /data/output --fp16
```

### OpenFold Version (Apptainer)

```bash
# Run structure prediction
apptainer run --nv esmfold.sif \
  esm-fold -i sequences.fasta -o output_dir
```

### BV-BRC Service

```bash
perl service-scripts/App-ESMFold.pl parameters.json
```

## Performance

| Sequence Length | CPU Memory | GPU Memory | Runtime |
|-----------------|------------|------------|---------|
| ≤100 aa         | 24 GB      | 12 GB      | ~60s    |
| ≤400 aa         | 32 GB      | 16 GB      | ~90s    |
| ≤800 aa         | 48 GB      | 24 GB      | ~3 min  |
| ≤1500 aa        | 64 GB      | 32 GB      | ~10 min |

See [docs/BENCHMARKS.md](docs/BENCHMARKS.md) for detailed performance data.

## GPU Compatibility

| GPU | OpenFold (CUDA 11) | OpenFold (CUDA 12) | HuggingFace |
|-----|--------------------|--------------------|-------------|
| V100 | Yes | Yes | Yes |
| A100 | Yes | Yes | Yes |
| H100 | No | Yes | Yes |

## Directory Structure

```
ESMFoldApp/
├── esm_hf/                 # HuggingFace implementation (recommended)
│   ├── Dockerfile          # Docker container
│   ├── esmfold_hf.def      # Apptainer container
│   └── scripts/            # CLI tools
│
├── container/              # OpenFold-based containers
│   ├── docker/             # Docker definitions
│   │   ├── Dockerfile.cuda11
│   │   ├── Dockerfile.cuda12
│   │   └── Dockerfile.cpu
│   ├── apptainer/          # Apptainer definitions
│   │   ├── ESMFoldApp.def
│   │   └── esmfold_pytorch.def
│   └── tests/              # Container tests
│
├── service-scripts/        # BV-BRC service implementation
│   └── App-ESMFold.pl
├── app_specs/              # BV-BRC application specs
│   └── ESMFold.json
├── docs/                   # Documentation
│   └── BENCHMARKS.md
└── test_data/              # Test sequences
```

## Testing

```bash
# HuggingFace version
cd esm_hf && python -c "from transformers import EsmForProteinFolding; print('OK')"

# Container syntax validation
./container/tests/test_stage1_syntax.sh

# Full GPU testing
./container/tests/test_stage3_gpu.sh
```

## Documentation

- [Benchmarks](docs/BENCHMARKS.md) - Performance data and reproducible tests
- [Container Guide](container/README.md) - Container build and usage
- [HuggingFace README](esm_hf/README.md) - Lightweight version documentation
- [Alpha Release Notes](ALPHA_RELEASE_NOTES.md) - Release information

## About

This module is a component of the BV-BRC build system. It executes ESMFold within the BV-BRC environment with optimized resource management and GPU acceleration.

- ESMFold: https://github.com/facebookresearch/esm
- BV-BRC: https://www.bv-brc.org/
