# ESMFold Container Status

**Last Updated**: 2025-12-05

## Current State

### ✅ Completed
- Container directory reorganized (docker/, apptainer/, tests/, config/)
- Unified build script created (`build.sh`)
- 4-stage testing strategy documented
- Multiple container variants available (cuda11, cuda12, cpu, hf, bvbrc)
- CLI wrapper created (`scripts/my-esm-fold`)
- HuggingFace version available (`esm_hf/`)
- Benchmarks documented (`docs/BENCHMARKS.md`)

### ⏳ Pending
- Full GPU testing on production servers
- BV-BRC integration testing (Stage 4)
- Performance validation against benchmarks

## Container Variants

| Variant | Base | GPU Support | Status |
|---------|------|-------------|--------|
| `esmfold:cuda11` | CUDA 11.3 | V100, A100 | Ready |
| `esmfold:cuda12` | CUDA 12.1 | H100 | Ready |
| `esmfold:cpu` | Python 3.10 | None | Ready |
| `esmfold-hf` | PyTorch/HF | H100 | Ready |
| `esmfold.sif` | Apptainer | V100, A100 | Ready |
| `esmfold-bvbrc.sif` | + PATRIC | V100, A100 | Pending |

## Testing Stages

| Stage | Environment | Status | Script |
|-------|-------------|--------|--------|
| 1 - Syntax | macOS | ✅ Pass | `tests/test_stage1_syntax.sh` |
| 2 - CPU | macOS/Linux | ✅ Pass | `tests/test_stage2_cpu.sh` |
| 3 - GPU | GPU Server | ⏳ Pending | `tests/test_stage3_gpu.sh` |
| 4 - BV-BRC | GPU Server | ⏳ Pending | `tests/test_patric_integration.sh` |

## Directory Structure

```
container/
├── docker/
│   ├── Dockerfile.cuda11      # CUDA 11.3 (V100/A100)
│   ├── Dockerfile.cuda12      # CUDA 12.1 (H100)
│   ├── Dockerfile.cpu         # CPU-only testing
│   ├── Dockerfile.bvbrc       # BV-BRC Docker variant
│   └── Dockerfile.dev         # Development container
├── apptainer/
│   ├── ESMFoldApp.def         # Production Apptainer
│   ├── esmfold-base.def       # Base definition
│   ├── esmfold-bvbrc.def      # BV-BRC integrated
│   └── esmfold_pytorch.def    # PyTorch 2.x / H100
├── config/
│   ├── environment.yml        # Conda environment spec
│   └── modules-base.dat       # PATRIC module list
├── tests/
│   ├── test_stage1_syntax.sh
│   ├── test_stage2_cpu.sh
│   ├── test_stage3_gpu.sh
│   ├── test_stage3_gpu_apptainer.sh
│   ├── test_patric_integration.sh
│   ├── test_pytorch.py
│   └── test_minimal.fasta
├── archive/                   # Old/site-specific scripts
├── build.sh                   # Unified build script
├── README.md                  # Container documentation
├── TESTING_STRATEGY.md        # Testing objectives & pipeline
└── STATUS.md                  # This file
```

## Quick Reference

### Build Commands
```bash
./build.sh docker cuda11     # Build CUDA 11 Docker image
./build.sh docker cuda12     # Build CUDA 12 Docker image
./build.sh docker cpu        # Build CPU-only image
./build.sh apptainer prod    # Build production Apptainer
./build.sh apptainer bvbrc   # Build BV-BRC Apptainer
./build.sh test              # Run test suite
```

### Test Commands
```bash
./tests/test_stage1_syntax.sh       # Syntax validation
./tests/test_stage2_cpu.sh          # CPU testing
./tests/test_stage3_gpu.sh          # GPU testing (requires GPU)
./tests/test_patric_integration.sh  # BV-BRC integration
```

## Related Files

- `app_specs/ESMFold.json` - BV-BRC app specification
- `service-scripts/App-ESMFold.pl` - BV-BRC service script
- `scripts/my-esm-fold` - Python CLI wrapper
- `esm_hf/` - HuggingFace Transformers version
- `docs/BENCHMARKS.md` - Performance benchmarks

## Next Steps

1. Complete Stage 3 GPU testing on V100/A100/H100
2. Build and test `esmfold-bvbrc.sif` (Stage 4)
3. Validate PATRIC runtime integration
4. Merge cleanup branch to main
