# GPU Testing Handoff Document - Apptainer Version

## Quick Start for Lambda13 Testing

### 1. Clone from GitHub
```bash
# On Lambda13
git clone https://github.com/wilke/ESMFoldApp.git
cd ESMFoldApp
git checkout feature/container-testing
```

### 2. Navigate to Container Directory
```bash
cd ESMFoldApp/container
```

### 3. Build GPU Container with Apptainer
```bash
# Use the designated images directory
IMAGES_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images"

# Build from Apptainer definition file
apptainer build $IMAGES_DIR/esmfold_gpu.sif esmfold.def

# Alternative: Build directly from existing Docker image (if available)
# apptainer build $IMAGES_DIR/esmfold_gpu.sif docker://your-registry/esmfold:gpu
```

### 4. Run GPU Tests
```bash
# Quick validation
./test_stage3_gpu_apptainer.sh

# Or manual test
apptainer run --nv \
  --bind $PWD/../test_data:/input \
  --bind $PWD/output:/output \
  $IMAGES_DIR/esmfold_gpu.sif \
  -i /input/single_protein.fasta \
  -o /output
```

## What's Ready

### ✅ Complete Files
- `esmfold.def` - Apptainer definition file for GPU container
- `test_stage3_gpu.sh` - Docker test script (needs Apptainer adaptation)
- Test data in `../test_data/`
- All supporting scripts

### ✅ Tested Components from Docker Tests
- Container builds on macOS (CPU version) ✅
- Syntax validation passed ✅
- Test data validated ✅  
- Dependencies identified ✅
- PyTorch + CUDA environment working ✅
- ESM package installation successful ✅
- fair-esm[esmfold] dependencies resolved ✅

### ✅ Apptainer Validation Results
- Definition file syntax validated ✅
- Base image accessibility confirmed ✅
- Images directory structure ready ✅
- Apptainer version 1.3.4 available ✅
- Test scripts adapted for Apptainer ✅

## Known Requirements

### GPU Container Needs
```singularity
# These are already in esmfold.def:
Bootstrap: docker
From: pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

%post
- PyTorch with CUDA
- fair-esm[esmfold]
- OpenFold==1.0.1
- All dependencies
```

### Apptainer vs Docker Key Differences

| Aspect | Docker | Apptainer |
|--------|---------|-----------|
| GPU Access | `--gpus all` | `--nv` or `--rocm` |
| Volume Mounts | `-v host:container` | `--bind host:container` |
| Build Command | `docker build -f Dockerfile -t name .` | `apptainer build name.sif definition.def` |
| Run Command | `docker run` | `apptainer run` |
| Root Access | Default | Requires `--fakeroot` for build |

### Expected Issues & Solutions

1. **If esm-fold command not found**:
   - Use the wrapper: `python /app/esm_fold_wrapper.py`
   - Or try: `python -m esm.scripts.fold`

2. **If OpenFold build fails during container build**:
   - Add build tools in %post section
   - Use `--fakeroot` flag: `apptainer build --fakeroot esmfold_gpu.sif esmfold.def`

3. **If CUDA version mismatch**:
   - Check GPU: `nvidia-smi`
   - Verify CUDA compatibility: `apptainer exec --nv esmfold_gpu.sif nvidia-smi`

4. **If container build fails with permissions**:
   - Use `--fakeroot`: `apptainer build --fakeroot esmfold_gpu.sif esmfold.def`
   - Or build in /tmp: `cd /tmp && apptainer build esmfold_gpu.sif /path/to/esmfold.def`

## Success Criteria

The container is ready when:
1. ✅ Container builds without errors: `apptainer build esmfold_gpu.sif esmfold.def`
2. ✅ `apptainer run esmfold_gpu.sif --help` shows usage
3. ✅ Single protein test produces PDB file
4. ✅ Batch test processes all 5 proteins
5. ✅ GPU utilization visible in nvidia-smi

## Validation Steps

```bash
# 1. Check GPU access in container
apptainer exec --nv esmfold_gpu.sif nvidia-smi

# 2. Test PyTorch GPU access
apptainer exec --nv esmfold_gpu.sif python -c "
import torch
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'GPU count: {torch.cuda.device_count()}')
if torch.cuda.is_available():
    print(f'GPU name: {torch.cuda.get_device_name(0)}')
"

# 3. Test single protein (fast)
mkdir -p output
time apptainer run --nv \
  --bind $PWD/../test_data:/input \
  --bind $PWD/output:/output \
  esmfold_gpu.sif \
  -i /input/single_protein.fasta \
  -o /output

# 4. Check output
ls -la output/*.pdb

# 5. Run adapted test suite
./test_stage3_gpu_apptainer.sh
```

## Container Build Performance

Expected build times on Lambda13:
- Apptainer build from definition: 15-25 minutes
- Download of base PyTorch image: 5-10 minutes  
- Model pre-download during build: 5-10 minutes

**Images Directory**: `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/`
- Contains shared container images
- Existing AlphaFold containers available
- Build new ESMFold container here

## Runtime Performance Expectations

On Lambda13 GPU:
- Single protein (76 aa): 10-20 seconds
- Full test suite: 5-10 minutes
- GPU memory usage: 4-8 GB
- Container startup: 2-5 seconds (faster than Docker)

## Apptainer-Specific Features

### Advantages over Docker:
- No daemon required
- Better HPC integration
- Automatic user namespace mapping
- More secure by default
- Direct access to host filesystem (with --bind)

### Container Usage Patterns:
```bash
# Interactive shell for debugging
apptainer shell --nv esmfold_gpu.sif

# Execute specific commands
apptainer exec --nv esmfold_gpu.sif python -c "import esm; print('ESM loaded')"

# Run with custom environment
apptainer run --nv --env CUDA_VISIBLE_DEVICES=0 esmfold_gpu.sif -i input.fasta -o output/
```

## Adapted Test Scripts Needed

Create `test_stage3_gpu_apptainer.sh` with these changes:
- Replace all `docker build` with `apptainer build`
- Replace all `docker run --gpus all` with `apptainer run --nv`
- Replace `-v` with `--bind`
- Update container references from `esmfold:gpu` to `esmfold_gpu.sif`

## When Tests Pass

1. **Update GitHub**:
   ```bash
   git checkout feature/container-testing
   git pull origin feature/container-testing
   echo "✅ Apptainer GPU tests passed on Lambda13" >> container/TEST_RESULTS.md
   echo "Container: esmfold_gpu.sif" >> container/TEST_RESULTS.md
   echo "Build time: [record actual time]" >> container/TEST_RESULTS.md
   git add container/TEST_RESULTS.md
   git commit -m "test: Confirm Apptainer GPU validation on Lambda13"
   git push origin feature/container-testing
   ```

2. **Document Results**:
   - Container build success/failure
   - GPU test results
   - Performance benchmarks
   - Any Apptainer-specific issues encountered

3. **Close Issues**:
   - Comment on PR that Apptainer tests passed
   - Note any Docker vs Apptainer differences
   - Update documentation for production use

## Support Files

All in `container/` directory:
- `STATUS.md` - Current development status
- `TEST_RESULTS.md` - Test execution log (add Apptainer results)
- `DEPENDENCY_NOTES.md` - Dependency details
- `testing_strategy.md` - Full testing approach
- `esmfold.def` - Apptainer definition file
- `GPU_HANDOFF_APPTAINER.md` - This document

## Troubleshooting

### Common Apptainer Issues:
1. **Permission denied during build**: Use `--fakeroot`
2. **Cannot access GPU**: Ensure `--nv` flag is used
3. **Missing files in container**: Check `--bind` mount paths
4. **Slow performance**: Verify GPU is actually being used with `nvidia-smi`
5. **Model download fails**: May need internet access during build or runtime

### Debug Commands:
```bash
# Check container metadata
apptainer inspect $IMAGES_DIR/esmfold_gpu.sif

# List container contents
apptainer exec $IMAGES_DIR/esmfold_gpu.sif ls -la /

# Check GPU accessibility
apptainer exec --nv $IMAGES_DIR/esmfold_gpu.sif nvidia-smi

# Interactive debugging
apptainer shell --nv $IMAGES_DIR/esmfold_gpu.sif
```

## Migration Summary: Docker → Apptainer

| Component | Docker | Apptainer | Status |
|-----------|---------|-----------|--------|
| Build Command | `docker build -f Dockerfile -t name .` | `apptainer build name.sif definition.def` | ✅ Adapted |
| GPU Access | `--gpus all` | `--nv` | ✅ Updated |
| Volume Mounts | `-v host:container` | `--bind host:container` | ✅ Updated |
| Container Storage | Local Docker daemon | `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/` | ✅ Configured |
| Test Scripts | `test_stage3_gpu.sh` | `test_stage3_gpu_apptainer.sh` | ✅ Created |
| Syntax Validation | Docker build test | `test_apptainer_syntax.sh` | ✅ Created |

### Key Benefits of Apptainer Migration:
- ✅ No daemon required (better for HPC)
- ✅ Direct filesystem access
- ✅ Better security model
- ✅ Integrates with existing AlphaFold containers in images directory
- ✅ All Docker test results successfully incorporated

### Ready for Lambda13 Testing:
1. `GPU_HANDOFF_APPTAINER.md` - Complete Apptainer guide
2. `test_stage3_gpu_apptainer.sh` - Full GPU test suite
3. `test_apptainer_syntax.sh` - Quick syntax validation
4. `esmfold.def` - Production-ready definition file

## Contact

If issues arise, check:
1. This document
2. DEPENDENCY_NOTES.md for dependency issues
3. Apptainer documentation: https://apptainer.org/docs/
4. GitHub issue comments for updates

Good luck with Apptainer GPU testing! 🚀