# ESM HuggingFace - Installation Guide

This guide covers all installation methods for the ESM HuggingFace package.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Local Installation](#local-installation)
3. [Docker Installation](#docker-installation)
4. [Singularity Installation](#singularity-installation)
5. [HPC Cluster Installation](#hpc-cluster-installation)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32+ GB |
| GPU VRAM | 8 GB | 16+ GB |
| Storage | 20 GB | 50+ GB |

### Software Requirements

- Python 3.8 - 3.11
- pip >= 21.0
- CUDA 11.7+ (for GPU support)

## Local Installation

### Method 1: pip (Recommended)

```bash
# 1. Clone or copy the esm_hf directory
cd /path/to/esm_hf

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# 3. Install PyTorch (choose one based on your system)

# For CUDA 12.1 (most modern GPUs):
pip install torch --index-url https://download.pytorch.org/whl/cu121

# For CUDA 11.8:
pip install torch --index-url https://download.pytorch.org/whl/cu118

# For CPU only:
pip install torch --index-url https://download.pytorch.org/whl/cpu

# 4. Install the package
pip install -e .

# 5. Verify installation
esm-fold-hf --help
```

### Method 2: Conda

```bash
# 1. Create environment
conda create -n esm-hf python=3.10 -y
conda activate esm-hf

# 2. Install PyTorch with CUDA
conda install pytorch pytorch-cuda=12.1 -c pytorch -c nvidia -y
# OR for CPU:
# conda install pytorch cpuonly -c pytorch -y

# 3. Install the package
cd /path/to/esm_hf
pip install -e .

# 4. Verify
esm-fold-hf --help
```

### Method 3: Development Installation

```bash
# Clone the repo
cd /path/to/esm_hf

# Create environment
python -m venv venv
source venv/bin/activate

# Install with dev dependencies
pip install torch --index-url https://download.pytorch.org/whl/cu121
pip install -e ".[dev]"

# Run tests
pytest tests/
```

## Docker Installation

### Building the Image

```bash
cd /path/to/esm_hf

# Build with GPU support (default)
docker build -t esmfold-hf:latest .

# Build for CPU only
docker build --build-arg INSTALL_GPU=false -t esmfold-hf:cpu .

# Build with specific PyTorch version
docker build \
  --build-arg TORCH_VERSION=2.1.0 \
  --build-arg TORCH_CUDA=cu121 \
  -t esmfold-hf:custom .
```

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `PYTHON_VERSION` | 3.10 | Python version |
| `INSTALL_GPU` | true | Include CUDA support |
| `TORCH_VERSION` | 2.2.0 | PyTorch version |
| `TORCH_CUDA` | cu121 | CUDA version for PyTorch |

### Running Docker Containers

```bash
# Interactive shell with GPU
docker run --gpus all -it esmfold-hf:latest /bin/bash

# Run inference
docker run --gpus all \
  -v /local/input:/data/input \
  -v /local/output:/data/output \
  esmfold-hf:latest \
  esm-fold-hf -i /data/input/sequences.fasta -o /data/output

# With model caching (recommended)
docker run --gpus all \
  -v /local/input:/data/input \
  -v /local/output:/data/output \
  -v /local/cache:/root/.cache/huggingface \
  esmfold-hf:latest \
  esm-fold-hf -i /data/input/sequences.fasta -o /data/output
```

## Singularity Installation

### Building the Container

```bash
cd /path/to/esm_hf

# Build with fakeroot (unprivileged)
singularity build --fakeroot esmfold_hf.sif esmfold_hf.def

# Build with sudo (if fakeroot not available)
sudo singularity build esmfold_hf.sif esmfold_hf.def
```

### Running Singularity Containers

```bash
# Test installation
singularity run --nv esmfold_hf.sif

# Interactive shell
singularity shell --nv esmfold_hf.sif

# Run inference
singularity exec --nv \
  --bind /local/data:/data \
  esmfold_hf.sif \
  esm-fold-hf -i /data/input.fasta -o /data/output

# With model caching
singularity exec --nv \
  --bind /local/data:/data \
  --bind /local/cache:/tmp/.cache/huggingface \
  esmfold_hf.sif \
  esm-fold-hf -i /data/input.fasta -o /data/output
```

## HPC Cluster Installation

### SLURM Job Script Example

```bash
#!/bin/bash
#SBATCH --job-name=esmfold
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --output=esmfold_%j.out

# Load modules (adjust for your cluster)
module load singularity
module load cuda/12.1

# Set paths
CONTAINER=/path/to/esmfold_hf.sif
INPUT_DIR=/path/to/input
OUTPUT_DIR=/path/to/output
CACHE_DIR=/path/to/cache

# Run ESMFold
singularity exec --nv \
  --bind ${INPUT_DIR}:/data/input \
  --bind ${OUTPUT_DIR}:/data/output \
  --bind ${CACHE_DIR}:/tmp/.cache/huggingface \
  ${CONTAINER} \
  esm-fold-hf \
    -i /data/input/sequences.fasta \
    -o /data/output \
    --fp16 \
    --chunk-size 64
```

### PBS/Torque Job Script Example

```bash
#!/bin/bash
#PBS -N esmfold
#PBS -l select=1:ncpus=8:mem=32gb:ngpus=1
#PBS -l walltime=4:00:00
#PBS -o esmfold.out
#PBS -e esmfold.err

cd $PBS_O_WORKDIR

# Load modules
module load singularity
module load cuda/12.1

# Run
singularity exec --nv \
  --bind /path/to/data:/data \
  /path/to/esmfold_hf.sif \
  esm-fold-hf -i /data/input.fasta -o /data/output --fp16
```

## Verification

### Quick Test

```bash
# Test CLI
esm-fold-hf --help

# Test Python imports
python -c "from transformers import EsmForProteinFolding; print('OK')"

# Test with example sequence
echo ">test
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG" > test.fasta
esm-fold-hf -i test.fasta -o test_output/
```

### Full Test Script

```bash
#!/bin/bash
# test_installation.sh

set -e

echo "Testing ESM HuggingFace installation..."

# Test 1: CLI available
echo "1. Testing CLI..."
esm-fold-hf --help > /dev/null
echo "   CLI: OK"

# Test 2: Python imports
echo "2. Testing Python imports..."
python -c "
import torch
from transformers import AutoTokenizer, EsmForProteinFolding
print(f'   PyTorch: {torch.__version__}')
print(f'   CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'   GPU: {torch.cuda.get_device_name(0)}')
"
echo "   Imports: OK"

# Test 3: Tokenizer loading
echo "3. Testing tokenizer loading..."
python -c "
from transformers import AutoTokenizer
tokenizer = AutoTokenizer.from_pretrained('facebook/esmfold_v1')
print('   Tokenizer: OK')
"

echo ""
echo "All tests passed!"
```

## Troubleshooting

### Common Issues

#### 1. CUDA not available
```bash
# Check CUDA installation
nvidia-smi
nvcc --version

# Check PyTorch CUDA
python -c "import torch; print(torch.cuda.is_available())"

# Reinstall PyTorch with correct CUDA version
pip uninstall torch
pip install torch --index-url https://download.pytorch.org/whl/cu121
```

#### 2. Out of Memory (OOM)
```bash
# Use memory optimization flags
esm-fold-hf -i input.fasta -o output/ --fp16 --chunk-size 32
```

#### 3. Model download fails
```bash
# Set HuggingFace cache directory
export HF_HOME=/path/to/cache
export TRANSFORMERS_CACHE=/path/to/cache

# Pre-download model
python -c "
from transformers import EsmForProteinFolding
model = EsmForProteinFolding.from_pretrained('facebook/esmfold_v1')
"
```

#### 4. Import errors
```bash
# Reinstall dependencies
pip install --upgrade transformers accelerate biopython
```

#### 5. Singularity permission issues
```bash
# Use writable tmp directory
singularity exec --nv \
  --bind /tmp:/tmp \
  --writable-tmpfs \
  esmfold_hf.sif esm-fold-hf ...
```

### Getting Help

1. Check the README.md for common usage patterns
2. Verify all prerequisites are installed
3. Try the CPU-only mode to isolate GPU issues
4. Check HuggingFace model page for known issues: https://huggingface.co/facebook/esmfold_v1
