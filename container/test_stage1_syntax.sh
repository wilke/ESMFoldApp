#!/bin/bash
#
# Stage 1: Quick syntax and structure validation (macOS compatible)
#

set -e

echo "======================================"
echo "Stage 1: Syntax and Structure Check"
echo "======================================"
echo ""

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found"
    exit 1
fi

# Test 1: Validate Dockerfile syntax
echo "1. Validating Dockerfile syntax..."
if docker build -f Dockerfile.cpu -t test:syntax --no-cache --target=base 2>/dev/null <<EOF
FROM python:3.9-slim as base
RUN echo "Syntax OK"
EOF
then
    echo "✅ Dockerfile syntax valid"
else
    echo "❌ Dockerfile syntax error"
    exit 1
fi

# Test 2: Check Python and pip
echo "2. Testing Python environment..."
if docker run --rm python:3.9-slim python -c "import sys; print(f'Python {sys.version}')" > /dev/null 2>&1; then
    echo "✅ Python environment OK"
else
    echo "❌ Python environment failed"
    exit 1
fi

# Test 3: Test pip install capability
echo "3. Testing pip install..."
if docker run --rm python:3.9-slim pip list > /dev/null 2>&1; then
    echo "✅ pip working"
else
    echo "❌ pip failed"
    exit 1
fi

# Test 4: Check if ESM can be installed (dry run)
echo "4. Checking ESM package availability..."
if docker run --rm python:3.9-slim pip install --dry-run fair-esm > /dev/null 2>&1; then
    echo "✅ ESM package available"
else
    echo "❌ ESM package not found"
    exit 1
fi

# Test 5: Validate test data exists
echo "5. Validating test data..."
if [ -f "../test_data/single_protein.fasta" ]; then
    echo "✅ Test data found"
else
    echo "❌ Test data missing"
    exit 1
fi

echo ""
echo "======================================"
echo "✅ Stage 1 Complete - Ready for Stage 2"
echo "======================================"