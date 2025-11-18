# ESMFold H100 Container Development - Session Snapshot

## Session Summary
**Date:** 2025-09-08  
**Goal:** Build and test H100-compatible ESMFold containers to resolve GPU architecture incompatibility

## Problem Statement
The original ESMFold container (v0.1.0) using PyTorch 1.12.1 fails on H100 GPUs due to missing sm_90 (compute capability 9.0) support. H100 GPUs require PyTorch 2.0+ for proper CUDA support.

## Technical Discovery Chain

### 1. Initial Issue Identification
- **Error:** `NVIDIA H100 NVL with CUDA capability sm_90 is not compatible with the current PyTorch installation`
- **Root Cause:** PyTorch 1.12.1 only supports up to sm_86 (A100), not sm_90 (H100)

### 2. First Solution Attempt
- **Action:** Created `esmfold_h100.def` using `pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel`
- **Result:** Container built but ESMFold requires OpenFold dependency
- **Issue:** OpenFold failed to install due to CUDA version mismatch

### 3. Second Solution Attempt  
- **Action:** Created `esmfold_h100_fixed.def` with OpenFold installed before ESM
- **Result:** OpenFold installed successfully with CUDA kernels
- **New Issue:** DeepSpeed 0.5.9 incompatible with PyTorch 2.0 (torch._six module removed)

### 4. Final Solution
- **Action:** Updated `esmfold_h100_fixed.def` to use DeepSpeed >=0.9.0
- **Result:** Successfully built `esmfold_h100_v2.sif` with all dependencies

## Container Versions Created

| Version | File | Base Image | Status | Issue |
|---------|------|------------|--------|-------|
| v0.1.0 | esmfold.v0.1.sif | PyTorch 1.12.1 CUDA 11.3 | ✅ Works on V100/A100 | ❌ No H100 support |
| v0.1.1 | esmfold_h100.sif | PyTorch 2.0.1 CUDA 11.7 | ⚠️ Built (11GB) | Missing OpenFold |
| v0.1.2 | esmfold_h100_fixed.sif | PyTorch 2.0.1 CUDA 11.7 | ⚠️ Built (6.7GB) | DeepSpeed incompatible |
| v0.1.3 | esmfold_h100_v2.sif | PyTorch 2.0.1 CUDA 11.7 | ✅ Built | Testing in progress |

## Active Background Processes

### Container Builds (3 running)
```bash
# Process 98a622 - Building from source with PyTorch base
cd /nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp/container && \
apptainer build /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold_from_source.sif esmfold_pytorch.def

# Process c8379a - Building test container
cd /nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp/container && \
apptainer build /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold_test.sif esmfold_test.def

# Process eecf75 - Building original H100 container
apptainer build /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold_h100.sif esmfold_h100.def
```

### ESMFold Tests (4 running)
```bash
# Process 6f4a8a - Testing v0.1.0 on H100
apptainer run --nv --bind ../test_data:/input,test_output:/output \
  /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif \
  -i /input/single_protein.fasta -o /output --chunk-size 128

# Process 28cb0b - Testing original H100 container
apptainer run --nv --bind ../test_data:/input,test_h100_output:/output \
  /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold_h100.sif \
  -i /input/single_protein.fasta -o /output --chunk-size 128

# Process d3d194 - Testing fixed H100 container
apptainer run --nv --bind ../test_data:/input,test_h100_output:/output \
  /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold_h100_fixed.sif \
  -i /input/single_protein.fasta -o /output --chunk-size 128

# Process ffb16c - Testing H100 v2 container (CURRENT FOCUS)
apptainer run --nv --bind ../test_data:/input,test_h100_output:/output \
  /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold_h100_v2.sif \
  -i /input/single_protein.fasta -o /output --chunk-size 128
```

## Key Technical Learnings

1. **PyTorch GPU Support Matrix:**
   - PyTorch 1.12.1: Supports up to sm_86 (A100)
   - PyTorch 2.0+: Adds sm_90 support (H100)

2. **Dependency Compatibility Chain:**
   - ESMFold → requires OpenFold
   - OpenFold → requires matching CUDA versions
   - OpenFold → uses DeepSpeed
   - DeepSpeed 0.5.9 → incompatible with PyTorch 2.0 (torch._six removed)
   - DeepSpeed 0.9+ → compatible with PyTorch 2.0

3. **Container Build Strategy:**
   - Install OpenFold BEFORE ESM (dependency order matters)
   - Use pytorch-devel base for CUDA compilation tools
   - Ensure DeepSpeed version matches PyTorch major version

## Files Modified/Created

```
/nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp/container/
├── esmfold_h100.def         # Initial H100 attempt
├── esmfold_h100_fixed.def   # Fixed with OpenFold and DeepSpeed >=0.9.0
├── PROGRESS.md              # Updated with session progress
└── issue_h100_compatibility.md  # GitHub issue documentation

/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/
├── esmfold_h100.sif (11GB)
├── esmfold_h100_fixed.sif (6.7GB)  
└── esmfold_h100_v2.sif (new)
```

## Next Steps After Current Tests Complete

1. **Verify H100 v2 container** - Confirm ESMFold runs successfully with GPU acceleration
2. **Performance benchmarking** - Compare inference times between container versions
3. **Update GitHub issues** - Document resolution in issues #5 and #7
4. **Tag release** - Create v0.1.3 release with H100 support
5. **Documentation** - Update README with GPU compatibility matrix

## Environment Details
- **Platform:** Lambda13
- **GPUs:** 8x NVIDIA H100 NVL (93.1GB each)
- **Container Runtime:** Apptainer/Singularity
- **Test Data:** Human ubiquitin (76 aa) from `test_data/single_protein.fasta`

## Critical Definition File: esmfold_h100_fixed.def

```dockerfile
Bootstrap: docker
From: pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

%post
    # Install system dependencies
    apt-get update && apt-get install -y \
        wget \
        git \
        curl \
        build-essential \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*
    
    # First install OpenFold with proper CUDA toolkit
    # This must be done before installing ESM to ensure compatibility
    cd /opt
    
    # Clone OpenFold and install with CUDA compilation
    git clone https://github.com/aqlaboratory/openfold.git
    cd openfold
    git checkout 4b41059694619831a7db195b7e0988fc4ff3a307
    
    # Install OpenFold dependencies first
    pip install --no-cache-dir \
        'deepspeed>=0.9.0' \
        'dm-tree==0.1.6' \
        'ml-collections==0.1.0' \
        'numpy<2.0' \
        'scipy==1.7.3' \
        'pytorch_lightning==2.0.4' \
        'biopython==1.79' \
        'wandb==0.12.21'
    
    # Now install OpenFold with CUDA kernels
    python setup.py install
    
    # Clone ESM repository and install from source
    cd /opt
    git clone https://github.com/facebookresearch/esm.git
    cd esm
    
    # Install ESM without esmfold extras first to avoid dependency conflicts
    pip install --no-cache-dir -e .
    
    # Then install the esmfold-specific dependencies
    pip install --no-cache-dir \
        'einops' \
        'omegaconf' \
        'hydra-core' \
        'dllogger @ git+https://github.com/NVIDIA/dllogger.git'
    
    # Create directories for input/output
    mkdir -p /data/input /data/output /data/models

%environment
    export ESMFOLD_MODEL_DIR=/data/models
    export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
    export PATH=/opt/conda/bin:$PATH
    # Ensure OpenFold can find its data
    export PYTHONPATH=/opt/openfold:$PYTHONPATH

%runscript
    exec /opt/conda/bin/esm-fold "$@"

%labels
    Author BV-BRC
    Name ESMFold H100 Fixed
    Version 2.0.1
    Description ESMFold with proper OpenFold support for H100 GPUs

%help
    ESMFold protein structure prediction container for H100 GPUs.
    Built on PyTorch 2.0.1 with CUDA 11.7 support for sm_90 architecture.
    Includes OpenFold with CUDA kernels for accelerated inference.
```

---

**Session Status:** All background processes still running. Ready to switch to new task while monitoring completions.
**Resume Command:** `cat /nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp/container/SESSION_SNAPSHOT_20250908.md`