# ESMFold HuggingFace Dockerfile
#
# Modern, lightweight containerized environment for running ESMFold
# using HuggingFace Transformers (no OpenFold compilation required)
#
# Build command:
#   docker build -t esmfold-hf:latest .
#
# Run command (with GPU):
#   docker run --gpus all -v $(pwd)/data:/data -it esmfold-hf:latest
#
# For CPU-only mode:
#   docker build --build-arg INSTALL_GPU=false -t esmfold-hf:cpu .

# Use CUDA runtime (not devel) since we don't need compilation
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

# Build arguments
ARG PYTHON_VERSION=3.10
ARG INSTALL_GPU=true
ARG TORCH_VERSION=2.6.0
ARG TORCH_CUDA=cu124
ARG NUMPY_VERSION=1.26.4

# Metadata
LABEL maintainer="ESM HuggingFace Docker Image"
LABEL description="ESMFold with HuggingFace Transformers - Lightweight Protein Structure Prediction (PyTorch 2.6, NumPy 1.26.4)"
LABEL version="1.0.0"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /workspace

# Install system dependencies (minimal set)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    git \
    wget \
    curl \
    ca-certificates \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install NumPy FIRST (before PyTorch to ensure correct version)
RUN pip install --no-cache-dir "numpy==${NUMPY_VERSION}"

# Install PyTorch with appropriate CUDA support
RUN if [ "$INSTALL_GPU" = "true" ]; then \
        pip install --no-cache-dir \
        torch==${TORCH_VERSION} \
        torchvision==0.21.0 \
        torchaudio==2.6.0 \
        --index-url https://download.pytorch.org/whl/${TORCH_CUDA}; \
    else \
        pip install --no-cache-dir \
        torch==${TORCH_VERSION} \
        torchvision==0.21.0 \
        torchaudio==2.6.0 \
        --index-url https://download.pytorch.org/whl/cpu; \
    fi

# Verify NumPy version wasn't overwritten by PyTorch dependencies
RUN pip install --no-cache-dir "numpy==${NUMPY_VERSION}" --force-reinstall

# Install HuggingFace dependencies (matching Singularity def versions)
RUN pip install --no-cache-dir \
    "transformers>=4.44.0,<4.58.0" \
    "accelerate>=0.20.0" \
    "biopython" \
    "scipy" \
    "einops"

# Copy requirements first for better layer caching
COPY requirements.txt /workspace/

# Copy the package source code
COPY . /workspace/

# Install the package
RUN pip install --no-cache-dir -e .

# Verify esm-fold-hf is installed
RUN which esm-fold-hf || echo "Warning: esm-fold-hf not in PATH"

# Create directories for data
RUN mkdir -p /data/input /data/output /root/.cache/huggingface

# Add test script
RUN cat > /workspace/test_installation.py << 'TESTEOF'
#!/usr/bin/env python
import sys

print("=" * 50)
print("ESMFold HuggingFace Installation Test")
print("=" * 50)
print(f"Python version: {sys.version.split()[0]}")

import numpy as np
print(f"NumPy version: {np.__version__}")

import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

print("\nTesting HuggingFace transformers...")
try:
    from transformers import __version__ as tf_version
    print(f"Transformers version: {tf_version}")
    print("\nLoading ESMFold tokenizer...")
    from transformers import AutoTokenizer
    tokenizer = AutoTokenizer.from_pretrained("facebook/esmfold_v1")
    print("Tokenizer loaded successfully!")
    print("\nNote: Model will be downloaded on first use (~10GB)")
    print("\n" + "=" * 50)
    print("Installation test PASSED!")
    print("=" * 50)
except Exception as e:
    print(f"\nError: {e}")
    sys.exit(1)
TESTEOF
RUN chmod +x /workspace/test_installation.py

# Add simple inference script
RUN cat > /workspace/inference.py << 'INFEREOF'
#!/usr/bin/env python
"""Simple ESMFold HF inference script
Usage: python inference.py <sequence> [--output output.pdb]
"""
import argparse
import torch
from transformers import AutoTokenizer, EsmForProteinFolding
from transformers.models.esm.openfold_utils.protein import to_pdb, Protein as OFProtein
from transformers.models.esm.openfold_utils.feats import atom14_to_atom37

def convert_outputs_to_pdb(outputs):
    final_atom_positions = atom14_to_atom37(outputs["positions"][-1], outputs)
    outputs = {k: v.to("cpu").numpy() for k, v in outputs.items()}
    final_atom_positions = final_atom_positions.cpu().numpy()
    final_atom_mask = outputs["atom37_atom_exists"]

    aa = outputs["aatype"][0]
    pred_pos = final_atom_positions[0]
    mask = final_atom_mask[0]
    resid = outputs["residue_index"][0] + 1
    pred = OFProtein(
        aatype=aa,
        atom_positions=pred_pos,
        atom_mask=mask,
        residue_index=resid,
        b_factors=outputs["plddt"][0],
        chain_index=outputs["chain_index"][0] if "chain_index" in outputs else None,
    )
    return to_pdb(pred)

def main():
    parser = argparse.ArgumentParser(description="Run ESMFold inference")
    parser.add_argument("sequence", type=str, help="Protein sequence")
    parser.add_argument("--output", type=str, default="output.pdb", help="Output PDB file")
    parser.add_argument("--cpu", action="store_true", help="Use CPU instead of GPU")
    parser.add_argument("--fp16", action="store_true", help="Use half precision")
    args = parser.parse_args()

    print(f"Loading ESMFold model from HuggingFace...")
    tokenizer = AutoTokenizer.from_pretrained("facebook/esmfold_v1")
    model = EsmForProteinFolding.from_pretrained("facebook/esmfold_v1")

    if args.fp16 and not args.cpu:
        model.esm = model.esm.half()

    model = model.eval()

    if torch.cuda.is_available() and not args.cpu:
        model = model.cuda()
        print(f"Using GPU: {torch.cuda.get_device_name(0)}")
    else:
        print("Using CPU (this will be slow)")

    print(f"Running inference on sequence ({len(args.sequence)} residues)...")
    tokenized = tokenizer([args.sequence], return_tensors="pt", add_special_tokens=False)["input_ids"]

    if not args.cpu and torch.cuda.is_available():
        tokenized = tokenized.cuda()

    with torch.no_grad():
        output = model(tokenized)

    pdb_string = convert_outputs_to_pdb(output)

    with open(args.output, "w") as f:
        f.write(pdb_string)

    mean_plddt = output["plddt"].mean().item()
    print(f"Structure saved to {args.output}")
    print(f"Mean pLDDT: {mean_plddt:.2f}")

if __name__ == "__main__":
    main()
INFEREOF
RUN chmod +x /workspace/inference.py

# Create example FASTA file
RUN cat > /data/input/example.fasta << 'FASTAEOF'
>example_protein
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG
>short_peptide
MKFLKFSLLTAVLLSVVFAFSSCGDDDDTYPYDVPDYAG
FASTAEOF

# Set environment variables
ENV CUDA_VISIBLE_DEVICES=0
ENV HF_HOME=/root/.cache/huggingface
ENV TRANSFORMERS_CACHE=/root/.cache/huggingface/transformers

# Volume mount points
VOLUME ["/data/input", "/data/output", "/root/.cache/huggingface"]

# Default command
CMD ["esm-fold-hf", "--help"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import torch; from transformers import AutoTokenizer; AutoTokenizer.from_pretrained('facebook/esmfold_v1')" || exit 1
