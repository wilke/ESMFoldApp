# ESMFold Performance Benchmarks

## Summary

Performance benchmarks for ESMFold structure prediction on GPU hardware.

**Test Date**: 2025-09-17
**Container**: `esmfold.v0.1.sif` (OpenFold-based, PyTorch 1.12.1, CUDA 11.3)
**Model**: ESM2_t36_3B_UR50D
**Hardware**: NVIDIA GPU (V100/A100 compatible)

## Results

| Sequence Length | Chunk Size | Runtime (s) | CPU Memory (MB) | GPU Memory (MB) |
|-----------------|------------|-------------|-----------------|-----------------|
| 50 aa           | 128        | 61.2        | 19,211          | 9,206           |
| 50 aa           | 256        | 56.8        | 19,212          | 9,206           |
| 100 aa          | 128        | 59.0        | 19,211          | 9,334           |
| 100 aa          | 256        | 54.7        | 19,211          | 9,334           |
| 200 aa          | 128        | 61.0        | 19,211          | 9,740           |
| 200 aa          | 256        | 63.2        | 19,213          | 9,924           |
| 400 aa          | 128        | 71.5        | 19,211          | 10,948          |
| 400 aa          | 256        | 73.7        | 19,210          | 12,168          |

### Key Observations

1. **Model Loading Dominates Runtime**: ~45-50 seconds for model loading, regardless of sequence length
2. **Chunk Size Impact**: chunk_size=256 is slightly faster for short sequences, but uses more GPU memory for longer sequences
3. **GPU Memory Scaling**: Approximately linear with sequence length (~9GB base + ~8MB per residue)
4. **CPU Memory**: Consistent ~19GB regardless of sequence length

## Resource Recommendations

Based on benchmark results:

| Sequence Length | CPU Memory | GPU Memory | Estimated Runtime |
|-----------------|------------|------------|-------------------|
| ≤100 aa         | 24 GB      | 12 GB      | 60 seconds        |
| ≤400 aa         | 32 GB      | 16 GB      | 90 seconds        |
| ≤800 aa         | 48 GB      | 24 GB      | 180 seconds       |
| ≤1500 aa        | 64 GB      | 32 GB      | 600 seconds       |

## Reproducing Benchmarks

### Prerequisites

- Singularity/Apptainer runtime
- NVIDIA GPU with CUDA support
- ESMFold container image

### Running the Benchmark

```bash
# Set container path
export CONTAINER="/path/to/esmfold.sif"

# Create test data directory
mkdir -p test_data output

# Create test sequences
cat > test_data/test_100aa.fasta << 'EOF'
>test_100aa
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG
KGKRIEIDSPNFQVVEKFMRFKVRMEGSVNGHEFEIEGEGEGRPYEGTQT
EOF

# Run benchmark with timing
/usr/bin/time -v singularity exec --nv \
    --bind test_data:/input,output:/output \
    "$CONTAINER" \
    esm-fold \
    -i /input/test_100aa.fasta \
    -o /output \
    --chunk-size 128
```

### Using the Benchmark Script

```bash
# Run full benchmark suite
./tests/performance_test.sh

# Results are saved to:
# - performance_results/performance_YYYYMMDD_HHMMSS.csv
```

### Monitoring GPU Memory

```bash
# Monitor GPU memory during prediction
watch -n 1 nvidia-smi --query-gpu=memory.used --format=csv,noheader
```

## Container Versions

| Container | PyTorch | CUDA | GPU Support | Notes |
|-----------|---------|------|-------------|-------|
| `esmfold.v0.1.sif` | 1.12.1 | 11.3 | V100, A100 | OpenFold-based, production |
| `esm_hf/` | 2.6.0 | 12.4 | V100, A100, H100 | HuggingFace-based, lightweight |

## HuggingFace Version

The `esm_hf/` package provides a lightweight alternative using HuggingFace Transformers:

```bash
# Install
pip install -e esm_hf/

# Run
esm-fold-hf -i input.fasta -o output/ --fp16 --chunk-size 64
```

Benefits:
- No OpenFold compilation required
- Supports H100 GPUs (PyTorch 2.x)
- Memory optimization options (`--fp16`, `--chunk-size`)
