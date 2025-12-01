# ESMFold CUDA 12 Migration: Feasibility and Caveats

## Overview
This document outlines the feasibility and potential issues when migrating ESMFold to use `dxkb/dev:12.9.1-cudnn-devel-ubuntu20.04` as the base image.

## Feasibility Assessment

### ✅ **Feasible with Considerations**
The migration is technically feasible but requires careful attention to compatibility issues.

## Key Dependencies Added

1. **Python 3.9** - Not included in base image, must be installed
2. **PyTorch 2.1.2** - With CUDA 12.1 support (closest to 12.9)
3. **Fair-ESM with ESMFold** - Core ML package
4. **OpenFold 1.0.1** - Required dependency
5. **Scientific libraries** - NumPy, SciPy, BioPython, etc.

## Critical Caveats

### 1. **CUDA Version Mismatch**
- **Issue**: Base image has CUDA 12.9.1, but PyTorch official builds only go up to CUDA 12.1
- **Impact**: Potential compatibility issues or performance degradation
- **Mitigation**:
  - Use PyTorch with CUDA 12.1 (usually forward compatible)
  - Or compile PyTorch from source for CUDA 12.9 (complex, time-consuming)
  - Test thoroughly to ensure GPU acceleration works

### 2. **Base Image Uncertainty**
- **Issue**: `dxkb/dev` is not a well-known/official image
- **Risks**:
  - May not be regularly maintained
  - Security updates uncertain
  - Could disappear from registry
- **Mitigation**:
  - Consider using official NVIDIA CUDA images instead
  - Or mirror the image to your own registry

### 3. **Python Installation Required**
- **Issue**: Unlike PyTorch base images, this doesn't include Python
- **Impact**: Increases image size and build time
- **Consideration**: Need to manage Python version compatibility

### 4. **Library Compatibility Chain**
- **Complex dependency order**:
  ```
  CUDA 12.9 → PyTorch 2.1.2+cu121 → OpenFold 1.0.1 → fair-esm[esmfold]
  ```
- **Risk**: Version conflicts between components
- **Testing needed**: Verify all components work together

### 5. **Model Download Size**
- **Issue**: ESMFold model (~2GB) downloaded during build
- **Impact**:
  - Large image size
  - Build failures if download fails
  - Network timeout issues
- **Mitigation**: Consider multi-stage build or runtime download

### 6. **Runtime Compatibility Issues**

#### Potential Problems:
- cuDNN version mismatches
- CUDA compute capability requirements
- Memory allocation issues with newer CUDA

#### Testing Required:
```bash
# Verify CUDA functionality
docker run --gpus all cuda12-esmfold python3 -c "
import torch
import esm
print('CUDA available:', torch.cuda.is_available())
print('GPU count:', torch.cuda.device_count())
model = esm.pretrained.esmfold_v1()
print('Model loaded successfully')
"
```

## Recommendations

### Option 1: Use Official NVIDIA Base (Recommended)
```dockerfile
FROM nvcr.io/nvidia/cuda:12.1.1-cudnn8-devel-ubuntu20.04
```
- Better maintained
- Known compatibility
- Official support

### Option 2: Use PyTorch Base with CUDA 12
```dockerfile
FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime
```
- Includes Python and PyTorch
- Tested configuration
- Smaller image size

### Option 3: Build PyTorch from Source
- Compile PyTorch for CUDA 12.9 specifically
- Most compatible but complex
- Significantly longer build times

## Build and Test Commands

```bash
# Build the image
docker build -f container/Dockerfile.cuda12 -t esmfold:cuda12 .

# Test with GPU
docker run --gpus all --rm esmfold:cuda12 python3 -c "import torch; print(torch.cuda.is_available())"

# Run ESMFold test
docker run --gpus all --rm \
  -v $(pwd)/test_data:/data/input \
  -v $(pwd)/output:/data/output \
  esmfold:cuda12 -i /data/input/test.fasta -o /data/output/
```

## Performance Considerations

1. **CUDA 12.9 Features**: May not be fully utilized with PyTorch built for CUDA 12.1
2. **Memory Management**: CUDA 12 has different memory allocation strategies
3. **Kernel Compilation**: First run may be slower due to JIT compilation

## Conclusion

While migration is **feasible**, recommend:
1. Use official NVIDIA/PyTorch base images for stability
2. Thoroughly test GPU functionality before production
3. Consider maintaining multiple Dockerfile versions for different CUDA versions
4. Document specific CUDA/GPU requirements for users