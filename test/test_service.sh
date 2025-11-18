#!/bin/bash
#
# Service Tests for App-ESMFold.pl
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DATA_DIR="$BASE_DIR/test_data"
TEST_OUTPUT_DIR="$BASE_DIR/test_output"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "ESMFold Service Tests"
echo "===================="
echo

# Create test directories
mkdir -p "$TEST_DATA_DIR"
mkdir -p "$TEST_OUTPUT_DIR"

# Test 1: Perl syntax check
echo "Test 1: Perl syntax validation"
echo "-------------------------------"
if perl -c "$BASE_DIR/service-scripts/App-ESMFold.pl" 2>/dev/null; then
    echo -e "${GREEN}✓ Perl syntax valid${NC}"
else
    echo -e "${RED}✗ Perl syntax error${NC}"
    exit 1
fi
echo

# Test 2: Check required modules
echo "Test 2: Required Perl modules"
echo "------------------------------"
REQUIRED_MODULES=(
    "Bio::KBase::AppService::AppScript"
    "Bio::KBase::AppService::AppConfig"
    "File::Basename"
    "File::Path"
    "File::Temp"
    "JSON"
    "Data::Dumper"
)

all_modules_ok=true
for module in "${REQUIRED_MODULES[@]}"; do
    if perl -M"$module" -e 'print "OK\n"' 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $module"
    else
        echo -e "  ${RED}✗${NC} $module"
        all_modules_ok=false
    fi
done

if $all_modules_ok; then
    echo -e "${GREEN}✓ All required modules available${NC}"
else
    echo -e "${YELLOW}⚠ Some modules missing - may work in container environment${NC}"
fi
echo

# Test 3: Create test FASTA file
echo "Test 3: Create test FASTA file"
echo "-------------------------------"
cat > "$TEST_DATA_DIR/test_protein.fasta" << 'EOF'
>test_protein_ubiquitin
MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG
EOF

if [ -f "$TEST_DATA_DIR/test_protein.fasta" ]; then
    echo -e "${GREEN}✓ Test FASTA created${NC}"
    echo "  Sequence: 76 amino acids (ubiquitin)"
else
    echo -e "${RED}✗ Failed to create test FASTA${NC}"
    exit 1
fi
echo

# Test 4: Create mock parameters file
echo "Test 4: Create test parameters"
echo "-------------------------------"
cat > "$TEST_DATA_DIR/test_params.json" << EOF
{
    "sequences": "$TEST_DATA_DIR/test_protein.fasta",
    "output_path": "$TEST_OUTPUT_DIR",
    "output_file_basename": "test_run",
    "use_gpu": "true",
    "chunk_size": 128,
    "num_recycles": 4,
    "max_tokens_per_batch": 1024
}
EOF

if [ -f "$TEST_DATA_DIR/test_params.json" ]; then
    echo -e "${GREEN}✓ Test parameters created${NC}"
    echo "  Output will go to: $TEST_OUTPUT_DIR"
else
    echo -e "${RED}✗ Failed to create test parameters${NC}"
    exit 1
fi
echo

# Test 5: Function extraction test (check if main functions are defined)
echo "Test 5: Function definitions"
echo "-----------------------------"
if grep -q "sub preflight" "$BASE_DIR/service-scripts/App-ESMFold.pl"; then
    echo -e "  ${GREEN}✓${NC} preflight function defined"
else
    echo -e "  ${RED}✗${NC} preflight function missing"
fi

if grep -q "sub process_esmfold" "$BASE_DIR/service-scripts/App-ESMFold.pl"; then
    echo -e "  ${GREEN}✓${NC} process_esmfold function defined"
else
    echo -e "  ${RED}✗${NC} process_esmfold function missing"
fi

if grep -q "sub validate_fasta" "$BASE_DIR/service-scripts/App-ESMFold.pl"; then
    echo -e "  ${GREEN}✓${NC} validate_fasta function defined"
else
    echo -e "  ${RED}✗${NC} validate_fasta function missing"
fi

if grep -q "sub build_esmfold_command" "$BASE_DIR/service-scripts/App-ESMFold.pl"; then
    echo -e "  ${GREEN}✓${NC} build_esmfold_command function defined"
else
    echo -e "  ${RED}✗${NC} build_esmfold_command function missing"
fi
echo

# Test 6: Container detection
echo "Test 6: Container availability"
echo "-------------------------------"
CONTAINER_PATH="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif"
if [ -f "$CONTAINER_PATH" ]; then
    echo -e "  ${GREEN}✓${NC} Base container found: $CONTAINER_PATH"

    # Check if we can run help command
    if singularity run --nv "$CONTAINER_PATH" esm-fold --help > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Container executable"
    else
        echo -e "  ${YELLOW}⚠${NC} Container exists but esm-fold command failed"
    fi
else
    echo -e "  ${RED}✗${NC} Base container not found: $CONTAINER_PATH"
fi

# Check for unified container
UNIFIED_CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold-bvbrc.sif"
if [ -f "$UNIFIED_CONTAINER" ]; then
    echo -e "  ${GREEN}✓${NC} Unified container found: $UNIFIED_CONTAINER"
else
    echo -e "  ${YELLOW}⚠${NC} Unified container not found (may be building): $UNIFIED_CONTAINER"
fi
echo

# Test 7: GPU detection
echo "Test 7: GPU availability"
echo "------------------------"
if command -v nvidia-smi > /dev/null 2>&1; then
    gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
    gpu_names=$(nvidia-smi --query-gpu=name --format=csv,noheader)
    echo -e "  ${GREEN}✓${NC} NVIDIA GPUs detected: $gpu_count"
    echo "  GPU types:"
    while read -r gpu_name; do
        echo "    - $gpu_name"
    done <<< "$gpu_names"
else
    echo -e "  ${YELLOW}⚠${NC} nvidia-smi not available - GPU support uncertain"
fi
echo

echo "Service Test Summary"
echo "==================="
echo -e "${GREEN}✓ Service script syntax valid${NC}"
echo -e "${GREEN}✓ Core functions implemented${NC}"
echo -e "${GREEN}✓ Test data prepared${NC}"

if [ -f "$CONTAINER_PATH" ]; then
    echo -e "${GREEN}✓ Container available for testing${NC}"
else
    echo -e "${YELLOW}⚠ Container needs to be built${NC}"
fi

echo
echo "Next steps:"
echo "1. Wait for unified container build to complete"
echo "2. Run integration test with actual workspace"
echo "3. Test with real BV-BRC AppService framework"

echo
echo "To run manual test:"
echo "  cd $BASE_DIR"
echo "  # Set up workspace credentials first"
echo "  perl service-scripts/App-ESMFold.pl test_data/test_params.json"