#!/bin/bash
#
# Integration Test for ESMFold BV-BRC Service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "ESMFold Integration Test"
echo "========================"
echo

# Configuration
CONTAINER_PATH="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold-bvbrc.sif"
BASE_CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif"
TEST_DIR="$BASE_DIR/test_data"
OUTPUT_DIR="$BASE_DIR/integration_test_output"

# Use base container if unified not available yet
if [ ! -f "$CONTAINER_PATH" ]; then
    echo -e "${YELLOW}Unified container not found, using base container${NC}"
    CONTAINER_PATH="$BASE_CONTAINER"
fi

if [ ! -f "$CONTAINER_PATH" ]; then
    echo -e "${RED}No container found at $CONTAINER_PATH${NC}"
    exit 1
fi

echo "Using container: $CONTAINER_PATH"
echo

# Create test directories
mkdir -p "$TEST_DIR"
mkdir -p "$OUTPUT_DIR"

# Test 1: Container basic functionality
echo "Test 1: Container Basic Functionality"
echo "--------------------------------------"

# Test help command
if singularity run --nv "$CONTAINER_PATH" esm-fold --help > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} ESMFold help command works"
else
    echo -e "  ${RED}✗${NC} ESMFold help command failed"
    exit 1
fi

# Test container test suite if available
if singularity test "$CONTAINER_PATH" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Container internal tests pass"
else
    echo -e "  ${YELLOW}⚠${NC} Container internal tests failed or not implemented"
fi
echo

# Test 2: Service Script in Container (if unified)
echo "Test 2: Service Script Availability"
echo "------------------------------------"
if singularity exec "$CONTAINER_PATH" test -f /service-scripts/App-ESMFold.pl 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Service script found in container"

    # Test Perl syntax in container
    if singularity exec "$CONTAINER_PATH" perl -c /service-scripts/App-ESMFold.pl 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Service script syntax valid in container"
    else
        echo -e "  ${YELLOW}⚠${NC} Service script syntax issues (may need BV-BRC modules)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Service script not found (base container mode)"
fi
echo

# Test 3: Create Test Data
echo "Test 3: Create Test Sequence"
echo "-----------------------------"
cat > "$TEST_DIR/integration_test.fasta" << 'EOF'
>test_small_protein
MNIFEMLRIDEGLRLKIYKDTEGYYTIGIGHLLTKSPSLNAAKSELDKAIGRNTNGVITKDEAEKLFNQDVDAAVRGILRNAKLKPVYDSLDAVRRAALINMVFQMGETGVAGFTNSLRMLQQKRWDEAAVNLAKSRWYNQTPNRAKRVITTFRTGTWDAYKNL
EOF

if [ -f "$TEST_DIR/integration_test.fasta" ]; then
    seq_length=$(grep -v ">" "$TEST_DIR/integration_test.fasta" | tr -d '\n' | wc -c)
    echo -e "  ${GREEN}✓${NC} Test sequence created (${seq_length} amino acids)"
else
    echo -e "  ${RED}✗${NC} Failed to create test sequence"
    exit 1
fi
echo

# Test 4: ESMFold Execution Test
echo "Test 4: ESMFold Execution"
echo "--------------------------"
echo "Running ESMFold on test sequence (this may take several minutes)..."

start_time=$(date +%s)
if timeout 600 singularity run --nv \
    --bind "$TEST_DIR:/input,$OUTPUT_DIR:/output" \
    "$CONTAINER_PATH" \
    esm-fold \
    -i /input/integration_test.fasta \
    -o /output \
    --chunk-size 128 > "$OUTPUT_DIR/esmfold.log" 2>&1; then

    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    echo -e "  ${GREEN}✓${NC} ESMFold completed successfully in ${runtime} seconds"

    # Check outputs
    if ls "$OUTPUT_DIR"/*.pdb > /dev/null 2>&1; then
        pdb_count=$(ls "$OUTPUT_DIR"/*.pdb | wc -l)
        echo -e "  ${GREEN}✓${NC} Generated $pdb_count PDB structure(s)"
    else
        echo -e "  ${YELLOW}⚠${NC} No PDB files found in output"
    fi
else
    echo -e "  ${RED}✗${NC} ESMFold execution failed or timed out (600s)"
    echo "  Check log: $OUTPUT_DIR/esmfold.log"
fi
echo

# Test 5: Resource Usage Analysis
echo "Test 5: Resource Usage"
echo "-----------------------"
if [ -f "$OUTPUT_DIR/esmfold.log" ]; then
    # Check for GPU usage indicators
    if grep -q "Using device: cuda" "$OUTPUT_DIR/esmfold.log" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} GPU acceleration detected"
    else
        echo -e "  ${YELLOW}⚠${NC} GPU usage not confirmed in logs"
    fi

    # Check for memory usage
    if grep -q "Loading" "$OUTPUT_DIR/esmfold.log" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Model loading detected"
    fi
fi

# Monitor current GPU usage
if command -v nvidia-smi > /dev/null 2>&1; then
    gpu_mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    echo -e "  ${GREEN}✓${NC} Current GPU memory usage: ${gpu_mem}MB"
fi
echo

echo "Integration Test Summary"
echo "========================"
echo -e "${GREEN}✓ Container functional${NC}"
echo -e "${GREEN}✓ ESMFold executable${NC}"

if [ -f "$OUTPUT_DIR"/*.pdb ]; then
    echo -e "${GREEN}✓ Structure generation successful${NC}"
else
    echo -e "${YELLOW}⚠ Structure generation issues${NC}"
fi

echo
echo "Test artifacts saved to: $OUTPUT_DIR"
echo "Logs available in: $OUTPUT_DIR/esmfold.log"

if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A $OUTPUT_DIR)" ]; then
    echo
    echo "Generated files:"
    ls -la "$OUTPUT_DIR"
fi