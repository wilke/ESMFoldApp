#!/bin/bash
#
# Test script for ESMFold service components
#

set -e

echo "ESMFold Service Test Suite"
echo "=========================="
echo

# Test directory setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_OUTPUT="/tmp/esmfold_test_$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Clean up on exit
cleanup() {
    rm -rf "$TEST_OUTPUT"
}
trap cleanup EXIT

# Create test output directory
mkdir -p "$TEST_OUTPUT"

echo "1. Checking directory structure"
echo "--------------------------------"
run_test "app_specs directory exists" "[ -d '$BASE_DIR/app_specs' ]"
run_test "lib directory exists" "[ -d '$BASE_DIR/lib' ]"
run_test "scripts directory exists" "[ -d '$BASE_DIR/scripts' ]"
run_test "service-scripts directory exists" "[ -d '$BASE_DIR/service-scripts' ]"
run_test "test_data directory exists" "[ -d '$BASE_DIR/test_data' ]"
echo

echo "2. Checking required files"
echo "---------------------------"
run_test "ESMFold.json spec exists" "[ -f '$BASE_DIR/app_specs/ESMFold.json' ]"
run_test "App-ESMFold.pl service script exists" "[ -f '$BASE_DIR/service-scripts/App-ESMFold.pl' ]"
run_test "ESMFoldWrapper.py exists" "[ -f '$BASE_DIR/lib/ESMFoldWrapper.py' ]"
run_test "esmfold CLI script exists" "[ -f '$BASE_DIR/scripts/esmfold' ]"
run_test "esmfold CLI is executable" "[ -x '$BASE_DIR/scripts/esmfold' ]"
echo

echo "3. Validating JSON specification"
echo "---------------------------------"
run_test "ESMFold.json is valid JSON" "python3 -m json.tool '$BASE_DIR/app_specs/ESMFold.json' > /dev/null"
run_test "ESMFold.json has required fields" "grep -q '\"id\"' '$BASE_DIR/app_specs/ESMFold.json' && grep -q '\"parameters\"' '$BASE_DIR/app_specs/ESMFold.json'"
echo

echo "4. Checking Perl syntax"
echo "------------------------"
run_test "App-ESMFold.pl syntax check" "perl -c '$BASE_DIR/service-scripts/App-ESMFold.pl' 2>/dev/null"
echo

echo "5. Checking Python syntax"
echo "--------------------------"
run_test "ESMFoldWrapper.py syntax check" "python3 -m py_compile '$BASE_DIR/lib/ESMFoldWrapper.py'"
echo

echo "6. Testing CLI help"
echo "--------------------"
run_test "esmfold --help works" "'$BASE_DIR/scripts/esmfold' --help"
echo

echo "7. Checking test data"
echo "----------------------"
run_test "Test FASTA file exists" "[ -f '$BASE_DIR/test_data/single_protein.fasta' ]"
run_test "Test FASTA is valid" "grep -q '^>' '$BASE_DIR/test_data/single_protein.fasta'"
echo

# Test with actual data if container exists
if [ -f "/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif" ]; then
    echo "8. Container integration test"
    echo "------------------------------"
    run_test "Container exists" "[ -f '/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif' ]"
    
    # Only run if container exists and we have GPU
    if command -v nvidia-smi &> /dev/null; then
        echo "Note: Full container test would run here with GPU"
    else
        echo "Note: Skipping container execution test (no GPU available)"
    fi
else
    echo "8. Container integration test"
    echo "------------------------------"
    echo "Note: Container not found, skipping integration tests"
fi
echo

# Summary
echo "Test Summary"
echo "============"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi