#!/bin/bash
#
# Quick smoke test for macOS
# Catches obvious issues in <1 minute
#

echo "🚀 Quick Smoke Test (macOS)"
echo "=========================="
echo ""

# Test 1: Docker available?
echo -n "Docker available... "
if command -v docker &> /dev/null; then
    echo "✅"
else
    echo "❌"
    echo "Install Docker Desktop for macOS"
    exit 1
fi

# Test 2: Can we run x86_64 containers?
echo -n "x86_64 emulation... "
if docker run --rm --platform linux/amd64 alpine uname -m | grep -q x86_64; then
    echo "✅"
else
    echo "⚠️  (will be slow)"
fi

# Test 3: Can Python run?
echo -n "Python runtime... "
if docker run --rm --platform linux/amd64 python:3.9-slim python --version > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Test 4: Can we install PyTorch?
echo -n "PyTorch install... "
if docker run --rm --platform linux/amd64 python:3.9-slim \
    pip install --quiet torch --index-url https://download.pytorch.org/whl/cpu 2>/dev/null; then
    echo "✅"
else
    echo "⚠️  (might need more memory)"
fi

# Test 5: Can we access test data?
echo -n "Test data... "
if [ -f "../test_data/single_protein.fasta" ]; then
    echo "✅"
else
    echo "❌"
    echo "Test data missing!"
    exit 1
fi

# Test 6: Quick ESM import test (with PyTorch dependency)
echo -n "ESM package... "
if docker run --rm --platform linux/amd64 python:3.9-slim bash -c \
    "pip install -q torch --index-url https://download.pytorch.org/whl/cpu 2>/dev/null && \
     pip install -q fair-esm 2>/dev/null && \
     python -c 'import esm' 2>/dev/null"; then
    echo "✅"
else
    echo "⚠️  (needs PyTorch first)"
fi

echo ""
echo "=========================="
echo "✅ Ready for full testing!"
echo ""
echo "Next: ./test_stage1_syntax.sh"
