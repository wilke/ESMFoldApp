# ESM HuggingFace - Lightweight ESMFold

Modern, lightweight ESMFold protein structure prediction using HuggingFace Transformers. This package provides a simpler alternative to the original OpenFold-based implementation with no compilation required.

## Features

- **Simple Installation**: No OpenFold compilation or CUDA build dependencies
- **Lightweight**: Uses HuggingFace Transformers with optimized attention
- **Modern**: Built on actively maintained transformers library
- **Flexible**: Supports GPU, CPU, fp16, and memory optimization options
- **Containerized**: Docker and Singularity support included

## Quick Start

### Installation

#### Option 1: pip install (Recommended)

```bash
# Create virtual environment
python -m venv esm-hf-env
source esm-hf-env/bin/activate  # Linux/Mac
# or: esm-hf-env\Scripts\activate  # Windows

# Install PyTorch (visit pytorch.org for GPU-specific instructions)
# For CUDA 12.1:
pip install torch --index-url https://download.pytorch.org/whl/cu121
# For CPU only:
pip install torch --index-url https://download.pytorch.org/whl/cpu

# Install esm-hf
pip install -e .
```

#### Option 2: Conda

```bash
# Create conda environment
conda create -n esm-hf python=3.10 -y
conda activate esm-hf

# Install PyTorch
conda install pytorch pytorch-cuda=12.1 -c pytorch -c nvidia -y
# or for CPU: conda install pytorch cpuonly -c pytorch -y

# Install requirements and package
pip install -r requirements.txt
pip install -e .
```

### Usage

#### Command Line Interface

```bash
# Basic usage
esm-fold-hf -i input.fasta -o output_pdb_dir/

# With GPU memory optimization
esm-fold-hf -i input.fasta -o output_pdb_dir/ --fp16 --chunk-size 64

# CPU-only mode (slower)
esm-fold-hf -i input.fasta -o output_pdb_dir/ --cpu-only

# Advanced options
esm-fold-hf \
  -i input.fasta \
  -o output_pdb_dir/ \
  --max-tokens-per-batch 512 \
  --chunk-size 32 \
  --fp16 \
  --use-tf32
```

#### Python API

```python
from transformers import AutoTokenizer, EsmForProteinFolding
import torch

# Load model and tokenizer
tokenizer = AutoTokenizer.from_pretrained("facebook/esmfold_v1")
model = EsmForProteinFolding.from_pretrained("facebook/esmfold_v1")

# Optional: Enable optimizations
model.esm = model.esm.half()  # Use fp16
model.trunk.set_chunk_size(64)  # Reduce memory usage
model = model.cuda()
model.eval()

# Predict structure
sequence = "MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG"
tokenized = tokenizer([sequence], return_tensors="pt", add_special_tokens=False)['input_ids']
tokenized = tokenized.cuda()

with torch.no_grad():
    output = model(tokenized)

# Access predictions
positions = output["positions"]  # 3D coordinates
plddt = output["plddt"]  # Confidence scores per residue
mean_plddt = plddt.mean()  # Overall confidence

print(f"Predicted structure with mean pLDDT: {mean_plddt:.2f}")
```

## CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --fasta` | Input FASTA file (required) | - |
| `-o, --pdb` | Output PDB directory (required) | - |
| `-m, --model-name` | HuggingFace model name or local path | `facebook/esmfold_v1` |
| `--max-tokens-per-batch` | Max tokens per batch (lower for less memory) | 1024 |
| `--chunk-size` | Axial attention chunk size (32, 64, 128) | None |
| `--cpu-only` | Force CPU execution | False |
| `--fp16` | Use half precision for language model | False |
| `--use-tf32` | Enable TensorFloat32 (Ampere GPUs) | False |
| `--low-cpu-mem` | Low CPU memory mode during loading | True |

## Building Containers

### Docker

```bash
# Build with GPU support
docker build -t esmfold-hf:latest .

# Build for CPU only
docker build --build-arg INSTALL_GPU=false -t esmfold-hf:cpu .

# Run with GPU
docker run --gpus all -v $(pwd)/data:/data -it esmfold-hf:latest

# Run inference
docker run --gpus all \
  -v /path/to/input:/data/input \
  -v /path/to/output:/data/output \
  esmfold-hf:latest \
  esm-fold-hf -i /data/input/sequences.fasta -o /data/output

# Test installation
docker run --gpus all esmfold-hf:latest python /workspace/test_installation.py
```

### Singularity

```bash
# Build container (requires root or fakeroot)
singularity build --fakeroot esmfold_hf.sif esmfold_hf.def
# or
sudo singularity build esmfold_hf.sif esmfold_hf.def

# Test installation
singularity run --nv esmfold_hf.sif

# Run inference
singularity exec --nv esmfold_hf.sif python /workspace/inference.py "MKTVRQERLK" --output test.pdb

# With data binding
singularity exec --nv --bind /path/to/data:/data esmfold_hf.sif \
    esm-fold-hf -i /data/input.fasta -o /data/output

# Cache model weights for faster startup
singularity exec --nv --bind /path/to/cache:/tmp/.cache/huggingface esmfold_hf.sif \
    python -c "from transformers import EsmForProteinFolding; EsmForProteinFolding.from_pretrained('facebook/esmfold_v1')"
```

## Memory Optimization Tips

### For GPU memory issues:
1. Use `--fp16` to halve language model memory
2. Set `--chunk-size 64` or `32` to reduce attention memory
3. Lower `--max-tokens-per-batch` to process shorter sequences

### For very long sequences:
1. Use `--chunk-size 32` (slower but much less memory)
2. Consider splitting into domains if biologically appropriate

### For CPU-only execution:
1. Use `--cpu-only` flag
2. Be patient - CPU inference is much slower
3. The model automatically converts to fp32 for CPU

## Requirements

### Minimum
- Python >= 3.8
- PyTorch >= 1.12.0
- transformers >= 4.30.0
- accelerate >= 0.20.0

### Recommended
- CUDA-capable GPU with 8GB+ VRAM
- 16GB+ system RAM
- SSD storage for model caching

## Troubleshooting

### Out of Memory Errors

```bash
# Try these in order:
esm-fold-hf -i input.fasta -o output/ --fp16
esm-fold-hf -i input.fasta -o output/ --fp16 --chunk-size 64
esm-fold-hf -i input.fasta -o output/ --fp16 --chunk-size 32 --max-tokens-per-batch 512
esm-fold-hf -i input.fasta -o output/ --cpu-only
```

### Model Download Issues

```bash
# Pre-download model
python -c "from transformers import EsmForProteinFolding; EsmForProteinFolding.from_pretrained('facebook/esmfold_v1')"

# Use local model
esm-fold-hf -i input.fasta -o output/ --model-name /path/to/local/model
```

### Import Errors

```bash
# Ensure all dependencies are installed
pip install transformers accelerate biopython torch

# Verify installation
python -c "import transformers; print(transformers.__version__)"
```

## Project Structure

```
esm_hf/
├── __init__.py              # Package initialization
├── scripts/
│   ├── __init__.py
│   └── hf_fold.py           # Main CLI script
├── requirements.txt         # Core dependencies
├── requirements_dev.txt     # Development dependencies
├── setup.py                 # Setup script
├── pyproject.toml           # Modern Python project config
├── Dockerfile               # Docker container definition
├── esmfold_hf.def           # Singularity container definition
└── README.md                # This file
```

## Citation

If you use ESMFold in your research, please cite:

```bibtex
@article{lin2022language,
  title={Language models of protein sequences at the scale of evolution enable accurate structure prediction},
  author={Lin, Zeming and Akin, Halil and Rao, Roshan and Hie, Brian and Zhu, Zhongkai and Lu, Wenting and Smetanin, Nikita and Verkuil, Robert and Kabeli, Ori and Shmueli, Yilun and others},
  journal={Science},
  year={2022}
}
```

## License

MIT License - see the LICENSE file for details.

## Additional Resources

- [Original ESM Repository](https://github.com/facebookresearch/esm)
- [HuggingFace ESMFold Model](https://huggingface.co/facebook/esmfold_v1)
- [HuggingFace Tutorial Notebook](https://colab.research.google.com/github/huggingface/notebooks/blob/main/examples/protein_folding.ipynb)
- [ESMFold Paper](https://www.science.org/doi/10.1126/science.ade2574)
