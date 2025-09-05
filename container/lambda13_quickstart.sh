#!/bin/bash
#
# Quick start script for Lambda13 GPU testing
# Run this on Lambda13 to set up and test ESMFold container
#

set -e

echo "=================================="
echo "ESMFold Lambda13 Quick Start"
echo "=================================="
echo ""

# Check if we're on a GPU machine
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ nvidia-smi not found. Are you on Lambda13?"
    exit 1
fi

echo "GPU Info:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo ""

# Clone repository if not exists
if [ ! -d "ESMFoldApp" ]; then
    echo "📦 Cloning repository from GitHub..."
    git clone https://github.com/wilke/ESMFoldApp.git
    cd ESMFoldApp
    git checkout feature/container-testing
else
    echo "📂 Repository exists, updating..."
    cd ESMFoldApp
    git fetch
    git checkout feature/container-testing
    git pull origin feature/container-testing
fi

# Navigate to container directory
cd container
echo "📍 Working directory: $(pwd)"
echo ""

# Build GPU container
echo "🔨 Building GPU container..."
echo "This will take 20-30 minutes on first build..."
docker build -f Dockerfile -t esmfold:gpu .

echo ""
echo "✅ Container built successfully!"
echo ""

# Test GPU access
echo "🎮 Testing GPU access in container..."
docker run --rm --gpus all esmfold:gpu nvidia-smi

# Quick test with single protein
echo ""
echo "🧬 Testing with single protein..."
mkdir -p output
docker run --rm --gpus all \
    -v $PWD/../test_data:/input:ro \
    -v $PWD/output:/output \
    esmfold:gpu \
    -i /input/single_protein.fasta \
    -o /output \
    --num-recycles 2

# Check results
if [ -f "output/test_ubiquitin.pdb" ]; then
    echo "✅ Test successful! PDB file generated:"
    ls -lh output/*.pdb
else
    echo "❌ Test failed - no PDB file found"
    exit 1
fi

echo ""
echo "=================================="
echo "✅ Lambda13 Setup Complete!"
echo "=================================="
echo ""
echo "Container is ready. You can now:"
echo "1. Run full test suite: ./test_stage3_gpu.sh"
echo "2. Process your own proteins"
echo "3. Close issues #4, #5, #6"
echo ""
echo "To update GitHub with success:"
echo "  git add container/TEST_RESULTS.md"
echo "  git commit -m 'test: GPU validation passed on Lambda13'"
echo "  git push origin feature/container-testing"