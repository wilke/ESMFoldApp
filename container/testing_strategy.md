# ESMFold Container Testing Strategy

## Overview
Multi-stage testing approach to ensure quick debugging and successful deployment.

## Stage 1: Local Syntax Validation (macOS)
**Goal**: Catch syntax and structure issues quickly
**Time**: ~5 minutes

```bash
# Check Dockerfile syntax
docker build -f Dockerfile.cpu -t esmfold:syntax-check --target base .

# Validate build context
./validate_structure.sh
```

## Stage 2: CPU-Only Container Testing (macOS)
**Goal**: Verify basic functionality without GPU
**Time**: ~15-30 minutes

```bash
# Build CPU-only version
docker build -f Dockerfile.cpu -t esmfold:cpu .

# Test basic import and command
docker run --rm esmfold:cpu --help

# Test with minimal data (CPU mode)
./test_cpu_minimal.sh
```

## Stage 3: Mock GPU Testing (macOS with emulation)
**Goal**: Test GPU codepaths without actual GPU
**Time**: ~20 minutes

```bash
# Build with CUDA stubs
docker build -f Dockerfile.mock -t esmfold:mock .

# Test with mock GPU
./test_mock_gpu.sh
```

## Stage 4: Full GPU Testing (H100 Server)
**Goal**: Production validation
**Time**: ~1-2 hours

```bash
# Build full container
docker build -f Dockerfile -t esmfold:gpu .

# Run comprehensive tests
./test_gpu_full.sh
```

## Testing Matrix

| Test | macOS | GPU Server | Purpose |
|------|-------|------------|---------|
| Dockerfile syntax | ✅ | - | Quick validation |
| Python imports | ✅ | - | Dependency check |
| CPU inference (tiny) | ✅ | ✅ | Basic functionality |
| CPU inference (full) | ⚠️ | ✅ | Memory requirements |
| GPU inference | - | ✅ | Performance validation |
| Multi-sequence batch | - | ✅ | Production readiness |

## Quick Debug Commands

### macOS Quick Test
```bash
# Fastest possible test (no model download)
docker run --rm -v $PWD/test_data:/data python:3.9 \
  bash -c "pip install fair-esm && python -c 'import esm; print(\"OK\")'"
```

### Check Architecture Compatibility
```bash
docker run --rm --platform linux/amd64 python:3.9 \
  uname -m  # Should show x86_64
```

### Test ESM Installation Only
```bash
docker run --rm python:3.9 \
  bash -c "pip install fair-esm && esm-fold --help"
```

## Debugging Workflow

1. **Start simple**: Test Python + pip only
2. **Add ESM**: Test import and basic commands
3. **Add model**: Test small model download
4. **Add CUDA**: Test GPU initialization
5. **Full test**: Run actual folding

## Resource Requirements

### Minimal Testing (macOS)
- RAM: 8GB
- Storage: 10GB
- Time: 30 minutes

### Full Testing (GPU)
- RAM: 32GB
- GPU: 16GB VRAM
- Storage: 50GB
- Time: 2 hours

## Common Issues & Solutions

### Issue: ARM64 vs x86_64
**Solution**: Use `--platform linux/amd64` flag

### Issue: Out of memory on macOS
**Solution**: Use smaller test proteins, reduce batch size

### Issue: CUDA not available
**Solution**: Use CPU-only mode with `--cpu-only` flag

### Issue: Model download timeout
**Solution**: Pre-download models or use smaller model (esm2_t6_8M_UR50D)