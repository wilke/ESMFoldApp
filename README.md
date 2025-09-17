# ESMFold BV-BRC Application

ESMFold protein structure prediction service integrated with the BV-BRC (Bacterial and Viral Bioinformatics Resource Center) platform.

## Overview

This application provides protein structure prediction using Meta's ESMFold model, packaged as a BV-BRC AppService module with GPU acceleration support.

**Status**: Alpha Release v0.9.0 - Production ready for V100/A100 GPUs

## Features

- **ESMFold Integration**: Meta's state-of-the-art protein folding model (ESM2_t36_3B_UR50D)
- **GPU Acceleration**: V100/A100 GPU support for fast prediction
- **BV-BRC Integration**: Full workspace I/O and service framework compatibility
- **Resource Management**: Intelligent resource scaling based on sequence characteristics
- **Container Deployment**: Apptainer/Singularity container runtime

## Quick Start

### Prerequisites
- Singularity/Apptainer runtime
- NVIDIA GPU with CUDA 11.3+ support
- BV-BRC workspace access

### Container Usage
```bash
# Test ESMFold functionality
singularity run --nv /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif esm-fold --help

# Run structure prediction
singularity run --nv \
  --bind input:/input,output:/output \
  esmfold.v0.1.sif \
  esm-fold -i /input/sequences.fasta -o /output
```

### BV-BRC Service Usage
```bash
# Submit job through BV-BRC AppService
perl service-scripts/App-ESMFold.pl parameters.json
```

## Performance Characteristics

| Sequence Length | Memory | GPU Memory | Runtime | Notes |
|----------------|--------|------------|---------|-------|
| ≤400 aa        | 32GB   | 16GB       | ~10 min | Optimal range |
| 400-800 aa     | 40GB   | 20GB       | ~15 min | Good performance |
| 800-1500 aa    | 48GB   | 24GB       | ~30 min | Long sequences |
| >1500 aa       | 64GB   | 32GB       | ~1 hour | Memory intensive |

## GPU Compatibility

- ✅ **V100**: Fully supported (CUDA 11.3, PyTorch 1.12.1)
- ✅ **A100**: Supported (compute capability 8.0)
- ❌ **H100**: Not supported in alpha (requires PyTorch 2.0+)

## Directory Structure

```
ESMFoldApp/
├── service-scripts/        # BV-BRC service implementation
│   └── App-ESMFold.pl     # Main service script
├── app_specs/             # Application specifications
│   └── ESMFold.json       # BV-BRC app configuration
├── scripts/               # Utility and wrapper scripts
│   ├── esm-fold-wrapper   # Container wrapper script
│   └── performance_test.sh # Benchmarking tool
├── container/             # Container definitions and build scripts
│   ├── ESMFoldApp.def     # Unified container definition
│   └── build_unified.sh   # Build automation
├── test/                  # Test suites and validation
│   ├── test_service.sh    # Service validation
│   └── integration_test.sh # End-to-end testing
└── performance_results/   # Benchmarking data
```

## Testing

```bash
# Run service tests
./test/test_service.sh

# Run integration tests
./test/integration_test.sh

# Run performance benchmarks
./scripts/performance_test.sh
```

## Documentation

- [Alpha Release Notes](ALPHA_RELEASE_NOTES.md) - Current release information and limitations
- [Container Documentation Status](container/DOCUMENTATION_STATUS.md) - Technical details and provenance
- [CLAUDE.md](CLAUDE.md) - Development guidelines and BV-BRC integration notes

## About this module

This module is a component of the BV-BRC build system, designed to fit into the
`dev_container` infrastructure which manages development and production deployment.
More documentation is available [here](https://github.com/BV-BRC/dev_container/tree/master/README.md).

This service executes ESMFold (https://github.com/facebookresearch/esm) within the BV-BRC environment with optimized resource management and GPU acceleration.

