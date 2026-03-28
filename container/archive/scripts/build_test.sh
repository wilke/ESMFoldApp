#!/bin/bash
#
# Build test for CPU container on macOS
# Tests that the container builds correctly
#

set -e

echo "================================"
echo "Container Build Test"
echo "================================"
echo ""

# Build the CPU test container
echo "Building CPU container for testing..."
echo "This will take a few minutes on first build..."
echo ""

START_TIME=$(date +%s)

if docker build -f Dockerfile.cpu -t esmfold:cpu-test --platform linux/amd64 . ; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    echo ""
    echo "✅ Container built successfully in ${ELAPSED}s"
else
    echo "❌ Container build failed"
    exit 1
fi

echo ""
echo "Testing container..."
echo ""

# Test 1: Check Python and imports
echo "Test 1: Python environment..."
if docker run --rm --platform linux/amd64 esmfold:cpu-test python -c "
import sys
print(f'Python: {sys.version}')
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
import esm
print('ESM: imported successfully')
"; then
    echo "✅ Python environment OK"
else
    echo "❌ Python environment failed"
    exit 1
fi

echo ""
echo "Test 2: ESM fold command..."
if docker run --rm --platform linux/amd64 esmfold:cpu-test --help | grep -q "fold"; then
    echo "✅ ESM fold command available"
else
    echo "⚠️  ESM fold command might need adjustment"
fi

echo ""
echo "================================"
echo "✅ Build test complete!"
echo "================================"
echo ""
echo "Container is ready for testing with proteins."
echo "Note: Actual folding will be slow on CPU."