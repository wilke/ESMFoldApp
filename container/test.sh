#!/bin/bash
#
# Test script for ESMFold containers
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

TEST_DATA="../test_data"
OUTPUT_DIR="test_output"

# Clean previous test output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Testing ESMFold containers..."

# Test Docker container
if command -v docker &> /dev/null && docker images | grep -q "esmfold"; then
    echo "Testing Docker container..."
    
    # Test with single protein
    echo "  Testing single protein..."
    docker run --rm -v "$PWD/$TEST_DATA:/input:ro" -v "$PWD/$OUTPUT_DIR:/output" \
        esmfold:latest -i /input/single_protein.fasta -o /output/docker_single
    
    # Verify output
    if [ -f "$OUTPUT_DIR/docker_single/test_ubiquitin.pdb" ]; then
        echo "  ✓ Docker single protein test passed"
    else
        echo "  ✗ Docker single protein test failed"
        exit 1
    fi
    
    # Test with multiple proteins
    echo "  Testing multiple proteins..."
    docker run --rm -v "$PWD/$TEST_DATA:/input:ro" -v "$PWD/$OUTPUT_DIR:/output" \
        esmfold:latest -i /input/test_proteins.fasta -o /output/docker_multi \
        --chunk-size 128 --num-recycles 2
    
    # Count PDB files
    PDB_COUNT=$(find "$OUTPUT_DIR/docker_multi" -name "*.pdb" 2>/dev/null | wc -l)
    if [ "$PDB_COUNT" -gt 0 ]; then
        echo "  ✓ Docker multi-protein test passed ($PDB_COUNT structures)"
    else
        echo "  ✗ Docker multi-protein test failed"
        exit 1
    fi
else
    echo "Docker container not available, skipping Docker tests"
fi

# Test Singularity/Apptainer container
if [ -f "esmfold.sif" ]; then
    if command -v apptainer &> /dev/null; then
        RUNNER="apptainer"
    elif command -v singularity &> /dev/null; then
        RUNNER="singularity"
    else
        echo "SIF file exists but no runner available"
        exit 0
    fi
    
    echo "Testing $RUNNER container..."
    
    # Test with single protein
    echo "  Testing single protein..."
    $RUNNER run esmfold.sif -i "$TEST_DATA/single_protein.fasta" \
        -o "$OUTPUT_DIR/sif_single"
    
    # Verify output
    if [ -f "$OUTPUT_DIR/sif_single/test_ubiquitin.pdb" ]; then
        echo "  ✓ $RUNNER single protein test passed"
    else
        echo "  ✗ $RUNNER single protein test failed"
        exit 1
    fi
else
    echo "Singularity/Apptainer container not available, skipping SIF tests"
fi

echo ""
echo "All container tests completed successfully!"
echo "Output structures saved in: $OUTPUT_DIR"