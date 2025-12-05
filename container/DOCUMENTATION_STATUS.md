# ESMFold Container Documentation Status

## Container Images Available

Location: `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/`

### Production-Ready Containers
- **esmfold.v0.1.sif** (7.2GB) - Base ESMFold with PyTorch 1.12.1, CUDA 11.3
  - Built: Sep 5, 2025
  - Status: ✅ Working on V100/A100 GPUs
  - Issue: ❌ Incompatible with H100 (needs PyTorch 2.0+)

### H100 Compatibility Attempts
- **esmfold_h100.sif** (10.8GB) - PyTorch 2.0.1 base
- **esmfold_h100_fixed.sif** (7.0GB) - Added OpenFold dependency
- **esmfold_h100_v2.sif** (7.0GB) - Updated DeepSpeed >=0.9.0
  - Status: ⚠️ pytorch_lightning API incompatibility issues

### Base Images
- **pytorch_1.12.1-cuda11.3-cudnn8-devel.sif** (7.1GB) - V100/A100 compatible
- **pytorch_2.0.1-cuda11.7-cudnn8-devel.sif** (6.8GB) - H100 compatible

## Documentation Files

### Prerequisites & Setup
1. **DEPENDENCY_NOTES.md** - Python package dependencies and versions
2. **environment.yml** - Conda environment specification
3. **bvbrc_config.yaml** - BV-BRC service configuration

### Solved Issues
1. **issue_5_update.md** - ✅ CLOSED: Test data creation and GPU container testing
   - Successfully built v0.1.0 with GPU support
   - Identified H100 incompatibility issue

2. **TEST_RESULTS.md** - Initial container test results
   - Syntax validation passed
   - CPU tests successful
   - GPU tests identified H100 issue

### Obsolete/Historical
1. **GPU_HANDOFF.md** - Original Docker-based documentation (replaced by Apptainer)
2. **SESSION_SNAPSHOT_20250908.md** - Historical debugging session for H100

### Current Problems & Tasks
1. **issue_h100_compatibility.md** - GitHub issue #18 (OPEN)
   - PyTorch version mismatch for H100
   - Dependency chain conflicts

2. **PROGRESS.md** - Current container version matrix and known issues
   - Container compatibility matrix
   - GPU architecture requirements

3. **STATUS.md** - Overall project status and blockers

### Provenance & Build Scripts
1. **Definition Files**:
   - `esmfold.def` - Original V100/A100 compatible
   - `esmfold_h100.def` - H100 attempt with PyTorch 2.0
   - `esmfold_h100_fixed.def` - H100 with dependency fixes
   - `ESMFoldApp.def` - ✅ Unified container with PATRIC runtime

2. **Build Scripts**:
   - `build.sh` - Basic container build
   - `build_unified.sh` - Unified ESMFold+PATRIC build
   - `extract_minimal_runtime.sh` - PATRIC runtime extraction

3. **Test Scripts**:
   - `test_stage1_syntax.sh` - Syntax validation
   - `test_stage2_cpu.sh` - CPU functionality
   - `test_stage3_gpu_apptainer.sh` - GPU testing
   - `test_apptainer_syntax.sh` - Container validation

## Current Status Summary

### ✅ Completed
- Base ESMFold container for V100/A100 GPUs
- PATRIC runtime extraction
- Unified container definition (ESMFoldApp.def)
- Test data creation (Issue #5 CLOSED)

### 🔄 In Progress
- H100 GPU support (Issue #18) - POSTPONED for alpha
- Workspace integration (Issue #15)
- Performance testing for preflight function

### 📋 TODO for Alpha Release
1. Test existing esmfold.v0.1.sif on current V100 host
2. Build unified container if not exists
3. Complete workspace integration
4. Run performance tests
5. Update preflight function with resource requirements
6. Implement cleanup function
7. Create integration tests

## Recommended Actions
1. Use **esmfold.v0.1.sif** as base (proven to work on V100)
2. Check if unified container already exists before building
3. Focus on V100 support for alpha release
4. Document H100 limitations for future work