# GPU Testing Handoff Document

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

### 3. Build GPU Container
```bash
docker build -f Dockerfile -t esmfold:gpu .
```

### 4. Run GPU Tests
```bash
# Quick validation
./test_stage3_gpu.sh

# Or manual test
docker run --rm --gpus all \
  -v $PWD/../test_data:/input \
  -v $PWD/output:/output \
  esmfold:gpu \
  -i /input/single_protein.fasta \
  -o /output
```

## What's Ready

### ✅ Complete Files
- `Dockerfile` - Full GPU container definition
- `test_stage3_gpu.sh` - Comprehensive GPU test script
- Test data in `../test_data/`
- All supporting scripts

### ✅ Tested Components
- Container builds on macOS (CPU version)
- Syntax validation passed
- Test data validated
- Dependencies identified

## Known Requirements

### GPU Container Needs
```dockerfile
# These are already in Dockerfile:
- PyTorch with CUDA
- fair-esm[esmfold]
- OpenFold==1.0.1
- All dependencies
```

### Expected Issues & Solutions

1. **If esm-fold command not found**:
   - Use the wrapper: `python /app/esm_fold_wrapper.py`
   - Or try: `python -m esm.scripts.fold`

2. **If OpenFold build fails**:
   - Install build tools: `apt-get install build-essential`
   - Try pre-built wheel: `pip install OpenFold==1.0.1 --no-build-isolation`

3. **If CUDA version mismatch**:
   - Check GPU: `nvidia-smi`
   - Match PyTorch CUDA version to system

## Success Criteria

The container is ready when:
1. ✅ Container builds without errors
2. ✅ `docker run esmfold:gpu --help` shows usage
3. ✅ Single protein test produces PDB file
4. ✅ Batch test processes all 5 proteins
5. ✅ GPU utilization visible in nvidia-smi

## Validation Steps

```bash
# 1. Check GPU access
docker run --rm --gpus all esmfold:gpu nvidia-smi

# 2. Test single protein (fast)
time docker run --rm --gpus all \
  -v $PWD/../test_data:/input \
  -v $PWD/output:/output \
  esmfold:gpu \
  -i /input/single_protein.fasta \
  -o /output

# 3. Check output
ls -la output/*.pdb

# 4. Run full test suite
./test_stage3_gpu.sh
```

## When Tests Pass

1. **Update GitHub**:
   ```bash
   git checkout feature/container-testing
   git pull origin feature/container-testing
   echo "✅ GPU tests passed on Lambda13" >> container/TEST_RESULTS.md
   git add container/TEST_RESULTS.md
   git commit -m "test: Confirm GPU validation on Lambda13"
   git push origin feature/container-testing
   ```

2. **Close Issues**:
   - Comment on PR that tests passed
   - Issues #4, #5, #6 can be closed
   - Merge PR to main

## Performance Expectations

On Lambda13 GPU:
- Container build: 20-30 minutes
- Single protein (76 aa): 10-20 seconds
- Full test suite: 5-10 minutes
- GPU memory usage: 4-8 GB

## Support Files

All in `container/` directory:
- `STATUS.md` - Current development status
- `TEST_RESULTS.md` - Test execution log
- `DEPENDENCY_NOTES.md` - Dependency details
- `testing_strategy.md` - Full testing approach

## Contact

If issues arise, check:
1. This document
2. DEPENDENCY_NOTES.md for dependency issues
3. GitHub issue comments for updates

Good luck with GPU testing! 🚀