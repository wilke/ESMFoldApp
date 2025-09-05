# ESMFold Dependency Chain

## Core Dependencies

ESMFold has a complex dependency chain that requires careful installation order:

1. **PyTorch** (must be installed first)
   - CPU version for testing: `torch --index-url https://download.pytorch.org/whl/cpu`
   - GPU version for production: Default PyTorch with CUDA

2. **fair-esm** (the main package)
   - Does NOT include all dependencies
   - Does NOT provide `esm-fold` CLI by default

3. **Required Python packages**:
   ```
   - biopython
   - numpy
   - typing-extensions
   - omegaconf
   - einops  
   - scipy
   ```

4. **OpenFold** (critical for ESMFold)
   - Complex dependency with its own requirements
   - Requires: dllogger, dm-tree, ml-collections
   - Installation: `pip install OpenFold==1.0.1`

## Known Issues

### Issue 1: No esm-fold command
**Problem**: fair-esm doesn't provide CLI tool
**Solution**: Created `esm_fold_wrapper.py` as replacement

### Issue 2: Missing omegaconf
**Problem**: Not declared as dependency in fair-esm
**Solution**: Explicitly install omegaconf

### Issue 3: OpenFold complexity
**Problem**: OpenFold has C++ extensions and complex build requirements
**Solution**: Use pre-built wheels or GPU container with full environment

## Recommended Approach

### For Testing (CPU)
Use minimal dependencies and wrapper script:
```dockerfile
RUN pip install torch --index-url https://download.pytorch.org/whl/cpu
RUN pip install fair-esm biopython omegaconf einops scipy
# Use wrapper script instead of full OpenFold
```

### For Production (GPU)
Use full dependency chain with CUDA:
```dockerfile
FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime
RUN pip install fair-esm[esmfold] OpenFold==1.0.1
```

## Container Build Times

- CPU minimal: ~5 minutes
- CPU with OpenFold: ~15-20 minutes  
- GPU full: ~20-30 minutes

## Memory Requirements

- Model download: ~2GB
- Runtime (CPU): 8-16GB minimum
- Runtime (GPU): 16-32GB recommended

## Alternative: Use Pre-built Containers

Consider using official or community containers:
- `docker pull facebookresearch/esm:latest`
- Build on top of existing bioinformatics images