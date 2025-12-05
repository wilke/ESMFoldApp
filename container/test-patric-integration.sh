#!/bin/bash
# Test ESMFold + PATRIC Runtime Integration
#
# Verifies that both ESMFold and PATRIC components work correctly in the integrated container

set -e

IMAGE="esmfold:patric"
PLATFORM="linux/amd64"

echo "============================================"
echo "ESMFold + PATRIC Integration Tests"
echo "============================================"
echo "Image: $IMAGE"
echo "Platform: $PLATFORM"
echo ""

# Check if image exists
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ERROR: Image '$IMAGE' not found!"
    echo "Build it first with: ./container/build-patric-runtime.sh"
    exit 1
fi

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    echo "TEST: $test_name"
    echo "  Command: $test_cmd"

    if eval "$test_cmd" > /tmp/test_output.txt 2>&1; then
        echo "  ✓ PASSED"
        cat /tmp/test_output.txt | sed 's/^/  | /'
        ((TESTS_PASSED++))
    else
        echo "  ✗ FAILED"
        cat /tmp/test_output.txt | sed 's/^/  | /'
        ((TESTS_FAILED++))
    fi
    echo ""
}

echo "Running integration tests..."
echo ""

# Test 1: ESMFold Python environment
run_test "ESMFold Python Environment" \
    "docker run --rm --platform $PLATFORM $IMAGE python -c 'import sys; import torch; import esm; print(f\"Python {sys.version_info.major}.{sys.version_info.minor}\"); print(f\"PyTorch {torch.__version__}\"); print(f\"ESM {esm.__version__}\")'"

# Test 2: ESMFold model loading (without download)
run_test "ESMFold Model Availability" \
    "docker run --rm --platform $PLATFORM $IMAGE python -c 'import esm; print(\"ESMFold model class available:\", hasattr(esm.pretrained, \"esmfold_v1\"))'"

# Test 3: PATRIC Perl runtime
run_test "PATRIC Perl Runtime" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'perl -v | head -2'"

# Test 4: Bio::KBase::AppService::AppScript module
run_test "Bio::KBase::AppService::AppScript" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'perl -MBio::KBase::AppService::AppScript -e \"print \\\"AppScript module OK\\\\n\\\"\"'"

# Test 5: Workspace client module
run_test "Bio::P3::Workspace::WorkspaceClient" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'perl -MBio::P3::Workspace::WorkspaceClient -e \"print \\\"Workspace client OK\\\\n\\\"\"'"

# Test 6: Service script exists and is executable
run_test "App-ESMFold.pl Service Script" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'test -x /service-scripts/App-ESMFold.pl && echo \"Service script exists and is executable\"'"

# Test 7: App spec JSON exists
run_test "ESMFold App Spec" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'test -f /app_specs/ESMFold.json && echo \"App spec found\"'"

# Test 8: Verify PATH preserves ESMFold Python
run_test "Python Path Priority (ESMFold preserved)" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'which python | grep -q conda && echo \"ESMFold conda Python is first in PATH\"'"

# Test 9: PERL5LIB includes BV-BRC modules
run_test "PERL5LIB Configuration" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'echo \$PERL5LIB | grep -q app_service && echo \"PERL5LIB includes BV-BRC modules\"'"

# Test 10: Environment variables set
run_test "BV-BRC Environment Variables" \
    "docker run --rm --platform $PLATFORM $IMAGE /bin/bash -c 'test -n \"\$KB_RUNTIME\" && test -n \"\$KB_TOP\" && echo \"KB_RUNTIME=\$KB_RUNTIME\" && echo \"KB_TOP=\$KB_TOP\"'"

echo "============================================"
echo "Test Summary"
echo "============================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED"
    echo ""
    echo "The integrated container is ready for use!"
    echo ""
    echo "Usage examples:"
    echo "  # Run ESMFold"
    echo "  docker run --rm -v \$(pwd)/data:/data/cache $IMAGE"
    echo ""
    echo "  # Run BV-BRC service"
    echo "  docker run --rm $IMAGE /bin/bash -c 'perl /service-scripts/App-ESMFold.pl --help'"
    echo ""
    exit 0
else
    echo "✗ SOME TESTS FAILED"
    echo ""
    echo "Review the failures above and check:"
    echo "  - Build logs: /tmp/esmfold_patric_build.log"
    echo "  - Runtime errors in test output"
    echo "  - Module installation in PATRIC stage"
    echo ""
    exit 1
fi
