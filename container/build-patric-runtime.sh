#!/bin/bash
# Build ESMFold + PATRIC Runtime Integrated Container
#
# This script builds the esmfold:patric image which integrates
# BV-BRC PATRIC runtime with the working ESMFold container.

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Build configuration
DOCKERFILE="$SCRIPT_DIR/esmfold-patric.dockerfile"
IMAGE_TAG="esmfold:patric"
PLATFORM="linux/amd64"
BUILD_LOG="/tmp/esmfold_patric_build.log"

echo "============================================"
echo "ESMFold + PATRIC Runtime Build"
echo "============================================"
echo "Dockerfile:  $DOCKERFILE"
echo "Image tag:   $IMAGE_TAG"
echo "Platform:    $PLATFORM"
echo "Build log:   $BUILD_LOG"
echo "============================================"
echo ""

# Check if base image exists
echo "Checking for base image esmfold:prod..."
if ! docker image inspect esmfold:prod >/dev/null 2>&1; then
    echo "ERROR: Base image 'esmfold:prod' not found!"
    echo "Please build it first with:"
    echo "  docker build --platform $PLATFORM -f container/esmfold.dockerfile -t esmfold:prod ."
    exit 1
fi
echo "✓ Base image esmfold:prod found"
echo ""

# Start build
echo "Starting build at $(date)"
echo "This will take approximately 15-20 minutes..."
echo ""
echo "Build stages:"
echo "  Stage 1: Building PATRIC runtime (10-15 min)"
echo "  Stage 2: Integrating with ESMFold (2-3 min)"
echo ""

# Run docker build with logging
docker build \
    --platform "$PLATFORM" \
    -f "$DOCKERFILE" \
    -t "$IMAGE_TAG" \
    "$PROJECT_ROOT" \
    2>&1 | tee "$BUILD_LOG"

BUILD_STATUS=${PIPESTATUS[0]}

echo ""
echo "============================================"

if [ $BUILD_STATUS -eq 0 ]; then
    echo "✓ BUILD SUCCESSFUL"
    echo "============================================"
    echo ""
    echo "Image created: $IMAGE_TAG"
    echo "Build log saved to: $BUILD_LOG"
    echo ""
    echo "Image details:"
    docker image inspect "$IMAGE_TAG" --format '{{.Size}}' | awk '{print "  Size: " $1/1024/1024/1024 " GB"}'
    docker image inspect "$IMAGE_TAG" --format '{{.Created}}' | awk '{print "  Created: " $1}'
    echo ""
    echo "Next steps:"
    echo "  1. Test the image:"
    echo "     ./container/test-patric-integration.sh"
    echo ""
    echo "  2. Run ESMFold with PATRIC runtime:"
    echo "     docker run --rm $IMAGE_TAG"
    echo ""
    echo "  3. Test Perl modules:"
    echo "     docker run --rm $IMAGE_TAG /bin/bash -c \\"
    echo "       'perl -MBio::KBase::AppService::AppScript -e \"print \\\"OK\\\\n\\\"\"'"
    echo ""
else
    echo "✗ BUILD FAILED"
    echo "============================================"
    echo ""
    echo "Build log saved to: $BUILD_LOG"
    echo ""
    echo "Check the log for errors:"
    echo "  tail -100 $BUILD_LOG"
    echo ""
    echo "Common issues:"
    echo "  - Network connectivity (cloning GitHub repos)"
    echo "  - CPAN module installation failures (retry build)"
    echo "  - Platform mismatch (ensure --platform linux/amd64)"
    echo ""
    exit 1
fi
