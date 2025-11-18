# Issue: ESMFold container incompatible with H100 GPUs

## Problem Description

The current ESMFold container (v0.1.0) fails on NVIDIA H100 GPUs due to PyTorch version incompatibility.

### Error Details

When running on Lambda13 with H100 NVL GPUs:

```
NVIDIA H100 NVL with CUDA capability sm_90 is not compatible with the current PyTorch installation.
The current PyTorch install supports CUDA capabilities sm_37 sm_50 sm_60 sm_61 sm_70 sm_75 sm_80 sm_86 compute_37.
```

Followed by:
```
RuntimeError: CUDA out of memory. Tried to allocate 2.00 MiB (GPU 0; 93.11 GiB total capacity; 6.47 GiB already allocated; 1.50 MiB free; 6.70 GiB reserved in total by PyTorch)
```

## Root Cause

- **PyTorch 1.12.1** only supports up to CUDA compute capability **sm_86** (NVIDIA A100)
- **H100 GPUs** require **sm_90** support
- This causes the model to fail when attempting GPU operations

## Impact

- Container works on older GPU architectures (V100, A100)
- Fails on newer H100 architecture
- Blocks deployment on latest HPC systems with H100 GPUs

## Proposed Solution

Upgrade to PyTorch 2.0+ which includes H100 support:

1. **Update base image** from `pytorch/pytorch:1.12.1-cuda11.3-cudnn8-devel` to `pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel`
2. **Test compatibility** with ESMFold and dependencies
3. **Verify OpenFold** compilation with newer CUDA toolkit

### Container Definition Changes

Created `esmfold_h100.def` with:
```dockerfile
Bootstrap: docker
From: pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel
```

## Test Environment

- **Platform**: Lambda13
- **GPU**: 8x NVIDIA H100 NVL (94GB each)
- **CUDA Driver**: Compatible with CUDA 11.7+
- **Container**: Apptainer/Singularity

## Verification Steps

1. Build new container with PyTorch 2.0.1
2. Verify H100 GPU detection without warnings
3. Test ESMFold inference on single protein
4. Benchmark performance vs A100

## Timeline

- **v0.1.0**: Current release (A100 compatible)
- **v0.1.1**: H100 support (in development)

## References

- [PyTorch H100 Support Announcement](https://pytorch.org/get-started/locally/)
- [NVIDIA H100 Architecture (sm_90)](https://developer.nvidia.com/cuda-gpus)
- Container definition: `container/esmfold_h100.def`

## Labels
- bug
- compatibility
- gpu
- high-priority

## Assignees
@wilke

## Milestone
v0.1.1 - H100 Support