# ESMFold Container Testing Strategy

## Testing Objectives

### 1. Build Validation
- Dockerfile syntax is valid
- Apptainer definition syntax is valid
- All dependencies resolve correctly
- Container builds complete without errors

### 2. Runtime Environment
- Python imports work (torch, esm, transformers)
- CLI entrypoints respond (`esm-fold --help`)
- Environment variables are set correctly
- Model paths are accessible

### 3. CPU Inference
- Small sequence folding works on CPU
- Memory usage is within expected bounds
- Output files are generated correctly (PDB format)

### 4. GPU Inference
- CUDA is detected and available
- GPU memory allocation works
- Folding produces correct output
- Performance meets benchmarks

### 5. Container Variants
- `cuda11` - V100/A100 compatibility
- `cuda12` - H100 compatibility
- `cpu` - CPU-only functionality
- `hf` - HuggingFace variant works
- Apptainer `.sif` - HPC deployment

### 6. BV-BRC Integration
- PATRIC runtime loads
- Perl modules accessible
- Service script executes
- Workspace paths functional

### 7. Output Validation
- PDB files are valid
- pLDDT scores are reasonable
- Batch processing works
- Error handling is appropriate

---

## Build & Test Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 1: Syntax Validation (macOS)                                      │
│   └── Dockerfile + Apptainer .def syntax checks                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 2: CPU Testing (macOS/Linux)                                      │
│   └── Build cpu container → test imports, CLI, CPU inference            │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 3: GPU Testing (GPU Server)                                       │
│   └── Build cuda11/cuda12 → test CUDA, GPU inference, performance       │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Stage 4: BV-BRC Integration (GPU Server)                                │
│   └── Build esmfold-bvbrc.sif (includes PATRIC runtime)                 │
│   └── Test PATRIC runtime, Perl modules, service scripts                │
└─────────────────────────────────────────────────────────────────────────┘
```

**PATRIC Runtime**: Built during Stage 4 as part of `esmfold-bvbrc.def`. This extends the base ESMFold container with BV-BRC service integration. Only built after Stage 3 GPU validation passes.

---

## Test Directory Structure

```
container/tests/
├── test_stage1_syntax.sh         # Stage 1: Dockerfile/def syntax
├── test_stage2_cpu.sh            # Stage 2: CPU-only testing
├── test_stage3_gpu.sh            # Stage 3: GPU testing (Docker)
├── test_stage3_gpu_apptainer.sh  # Stage 3: GPU testing (Apptainer)
├── test_apptainer_syntax.sh      # Apptainer definition validation
├── test_patric_integration.sh    # Stage 4: BV-BRC runtime integration
├── test_pytorch.py               # PyTorch/CUDA verification
├── quick_test.sh                 # Fast validation
├── local_test.sh                 # Local development tests
└── test_minimal.fasta            # Test sequence data
```

---

## Stage 1: Syntax Validation (macOS)

**Goal**: Catch syntax and structure issues quickly
**Time**: ~2 minutes
**Objectives**: Build Validation

```bash
# Docker syntax check
./container/tests/test_stage1_syntax.sh

# Apptainer definition syntax
./container/tests/test_apptainer_syntax.sh
```

## Stage 2: CPU-Only Testing (macOS/Linux)

**Goal**: Verify imports, dependencies, and basic functionality without GPU
**Time**: ~15-30 minutes
**Objectives**: Runtime Environment, CPU Inference

```bash
./container/tests/test_stage2_cpu.sh
```

Tests:
- Python imports (torch, esm, transformers)
- CLI help commands
- Small sequence folding (CPU mode)

## Stage 3: GPU Testing (GPU Server)

**Goal**: Full production validation with GPU
**Time**: ~1-2 hours
**Objectives**: GPU Inference, Container Variants, Output Validation

```bash
# Docker
./container/tests/test_stage3_gpu.sh

# Apptainer
./container/tests/test_stage3_gpu_apptainer.sh
```

Tests:
- CUDA availability
- GPU memory allocation
- Full sequence folding
- Batch processing

## Stage 4: BV-BRC Integration (GPU Server)

**Goal**: Validate PATRIC runtime and BV-BRC service integration
**Time**: ~30 minutes (after base container built)
**Objectives**: BV-BRC Integration
**Prerequisite**: Stage 3 base Apptainer container (`esmfold.sif`) must pass

```bash
# Build BV-BRC container (extends base with PATRIC runtime)
./build.sh apptainer bvbrc

# Test integration
./container/tests/test_patric_integration.sh
```

**Build includes**:
- Clone `runtime_build` repository
- Bootstrap PATRIC Perl modules via `bootstrap_modules.pl`
- Install BV-BRC service dependencies

**Tests**:
- PATRIC runtime availability (`/opt/patric-common/runtime`)
- Perl module loading
- Service script execution (`App-ESMFold.pl`)
- Workspace path configuration

---

## Testing Matrix

| Stage | Test | macOS | GPU Server | Script |
|-------|------|-------|------------|--------|
| 1 | Dockerfile syntax | ✅ | - | `test_stage1_syntax.sh` |
| 1 | Apptainer syntax | ✅ | - | `test_apptainer_syntax.sh` |
| 2 | Python imports | ✅ | ✅ | `test_stage2_cpu.sh` |
| 2 | CPU inference | ✅ | ✅ | `test_stage2_cpu.sh` |
| 3 | PyTorch/CUDA | - | ✅ | `test_pytorch.py` |
| 3 | GPU inference | - | ✅ | `test_stage3_gpu.sh` |
| 4 | BV-BRC integration | - | ✅ | `test_patric_integration.sh` |

---

## Quick Commands

### Run All Stages
```bash
cd container
./build.sh test
```

### Quick Validation
```bash
./container/tests/quick_test.sh
```

### PyTorch/CUDA Check
```bash
python container/tests/test_pytorch.py
```

### Test Specific Container
```bash
# Docker
docker run --rm esmfold:cuda12 --help

# Apptainer
apptainer run --nv esmfold.sif --help
```

---

## Container Variants

| Container | Base Image | GPU Support | Stage | Test Script |
|-----------|------------|-------------|-------|-------------|
| `esmfold:cpu` | Python 3.10 | None | 2 | `test_stage2_cpu.sh` |
| `esmfold:cuda11` | CUDA 11.3 | V100, A100 | 3 | `test_stage3_gpu.sh` |
| `esmfold:cuda12` | CUDA 12.1 | H100 | 3 | `test_stage3_gpu.sh` |
| `esmfold-hf` | PyTorch | H100 | 3 | `test_stage3_gpu.sh` |
| `esmfold.sif` | Apptainer | V100, A100 | 3 | `test_stage3_gpu_apptainer.sh` |
| `esmfold-bvbrc.sif` | Apptainer + PATRIC | V100, A100 | 4 | `test_patric_integration.sh` |

---

## Resource Requirements

### Development (macOS) - Stages 1-2
- RAM: 8GB minimum
- Storage: 10GB
- Time: 30 minutes

### Production (GPU Server) - Stages 3-4
- RAM: 32GB
- GPU: 16GB+ VRAM
- Storage: 50GB
- Time: 2-3 hours

---

## Common Issues

| Issue | Solution |
|-------|----------|
| ARM64 vs x86_64 | Use `--platform linux/amd64` |
| Out of memory (macOS) | Use smaller test proteins, `--cpu-only` |
| CUDA not available | Use CPU-only container or check driver |
| Model download timeout | Pre-download or use smaller model |
| Apptainer permission denied | Check `--fakeroot` or contact admin |
| PATRIC bootstrap fails | Check network access to GitHub |
| Perl module not found | Verify `modules-base.dat` path |
