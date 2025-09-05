#!/bin/bash
#
# Local test script for ESMFold container development
# This script tests the container build and execution locally
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "==================================="
echo "ESMFold Container Local Testing"
echo "==================================="
echo ""

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please install Docker to test the container"
    exit 1
fi

echo "✓ Docker is available"
echo ""

# Build the container
echo "📦 Building ESMFold Docker container..."
echo "This will take several minutes on first build..."
echo ""

if docker build -t esmfold:test -f Dockerfile . ; then
    echo "✓ Container built successfully"
else
    echo "❌ Container build failed"
    exit 1
fi

echo ""
echo "🧪 Testing container with test data..."
echo ""

# Create test output directory
TEST_OUTPUT="test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_OUTPUT"

# Test 1: Check if esm-fold command is available
echo "Test 1: Checking esm-fold command..."
if docker run --rm esmfold:test --help > "$TEST_OUTPUT/help.txt" 2>&1; then
    echo "✓ esm-fold command is available"
else
    echo "❌ esm-fold command failed"
    cat "$TEST_OUTPUT/help.txt"
    exit 1
fi

# Test 2: Process single protein
echo "Test 2: Processing single protein (ubiquitin)..."
if docker run --rm \
    -v "$SCRIPT_DIR/../test_data:/input:ro" \
    -v "$SCRIPT_DIR/$TEST_OUTPUT:/output" \
    esmfold:test \
    -i /input/single_protein.fasta \
    -o /output/single_protein \
    --num-recycles 1 \
    --chunk-size 128 > "$TEST_OUTPUT/single_protein.log" 2>&1; then
    
    if [ -f "$TEST_OUTPUT/single_protein/test_ubiquitin.pdb" ]; then
        echo "✓ Single protein processed successfully"
        echo "  PDB file size: $(ls -lh $TEST_OUTPUT/single_protein/test_ubiquitin.pdb | awk '{print $5}')"
    else
        echo "❌ PDB file not generated"
        echo "  Check log: $TEST_OUTPUT/single_protein.log"
        exit 1
    fi
else
    echo "❌ Single protein processing failed"
    echo "  Error log:"
    tail -20 "$TEST_OUTPUT/single_protein.log"
    exit 1
fi

# Test 3: Process multiple proteins with reduced settings for speed
echo "Test 3: Processing multiple proteins (quick test)..."
if docker run --rm \
    -v "$SCRIPT_DIR/../test_data:/input:ro" \
    -v "$SCRIPT_DIR/$TEST_OUTPUT:/output" \
    esmfold:test \
    -i /input/test_proteins.fasta \
    -o /output/multi_protein \
    --num-recycles 1 \
    --chunk-size 64 \
    --max-tokens-per-batch 512 > "$TEST_OUTPUT/multi_protein.log" 2>&1; then
    
    PDB_COUNT=$(find "$TEST_OUTPUT/multi_protein" -name "*.pdb" 2>/dev/null | wc -l)
    if [ "$PDB_COUNT" -gt 0 ]; then
        echo "✓ Multiple proteins processed successfully"
        echo "  Generated $PDB_COUNT PDB files"
        ls -lh "$TEST_OUTPUT/multi_protein"/*.pdb 2>/dev/null | awk '{print "  - "$9": "$5}'
    else
        echo "❌ No PDB files generated"
        echo "  Check log: $TEST_OUTPUT/multi_protein.log"
        exit 1
    fi
else
    echo "❌ Multiple protein processing failed"
    echo "  Error log:"
    tail -20 "$TEST_OUTPUT/multi_protein.log"
    exit 1
fi

echo ""
echo "==================================="
echo "✅ All tests passed successfully!"
echo "==================================="
echo ""
echo "Results saved in: $TEST_OUTPUT"
echo ""
echo "Container is ready for deployment."
echo "You can now close issues #4, #5, and #6"
echo ""

# Display summary
echo "Summary:"
echo "--------"
echo "✓ Issue #4: Docker container builds successfully"
echo "✓ Issue #5: Test data is valid and processable"
echo "✓ Issue #6: Container correctly executes esm-fold on test data"