#!/bin/bash
#
# Build unified ESMFold + PATRIC runtime container
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
RUNTIME_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/runtime"
OUTPUT_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images"
DATE_TAG=$(date +%Y%m%d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "ESMFold Unified Container Builder"
echo "================================="
echo

# Find the latest complete runtime
if [ -f "$RUNTIME_DIR/patric.tar.gz" ]; then
    RUNTIME_TAR="$RUNTIME_DIR/patric.tar.gz"
    echo -e "${GREEN}Using compressed runtime: $RUNTIME_TAR${NC}"
elif [ -f "$RUNTIME_DIR/patric.tar" ]; then
    # Compress it first
    echo -e "${YELLOW}Compressing uncompressed runtime...${NC}"
    gzip -c "$RUNTIME_DIR/patric.tar" > "$RUNTIME_DIR/patric.tar.gz"
    RUNTIME_TAR="$RUNTIME_DIR/patric.tar.gz"
elif [ -f "$RUNTIME_DIR/patric-runtime-20250908.tar.gz" ]; then
    RUNTIME_TAR="$RUNTIME_DIR/patric-runtime-20250908.tar.gz"
    echo -e "${YELLOW}Using existing runtime: $RUNTIME_TAR${NC}"
else
    echo -e "${RED}No PATRIC runtime found in $RUNTIME_DIR${NC}"
    exit 1
fi

# Create temporary definition with correct runtime path
TMP_DEF="/tmp/ESMFoldApp-${DATE_TAG}.def"
cp "$SCRIPT_DIR/ESMFoldApp.def" "$TMP_DEF"
sed -i "s|PATRIC_RUNTIME_TAR|$RUNTIME_TAR|g" "$TMP_DEF"

# Output image name
OUTPUT_IMAGE="$OUTPUT_DIR/esmfold-bvbrc-${DATE_TAG}.sif"

echo "Building unified container..."
echo "  Runtime: $RUNTIME_TAR"
echo "  Output: $OUTPUT_IMAGE"
echo

# Build the container
if apptainer build --force "$OUTPUT_IMAGE" "$TMP_DEF"; then
    echo -e "${GREEN}Build successful!${NC}"
    
    # Create symlink for easy access
    SYMLINK="$OUTPUT_DIR/esmfold-bvbrc.sif"
    rm -f "$SYMLINK"
    ln -s "$OUTPUT_IMAGE" "$SYMLINK"
    echo -e "${GREEN}Created symlink: $SYMLINK${NC}"
    
    # Test the container
    echo
    echo "Testing container..."
    apptainer test "$OUTPUT_IMAGE"
    
    echo
    echo -e "${GREEN}Container ready: $OUTPUT_IMAGE${NC}"
    echo
    echo "Test commands:"
    echo "  # Test ESMFold:"
    echo "  apptainer run --nv $SYMLINK esm-fold --help"
    echo
    echo "  # Test service script:"
    echo "  apptainer exec $SYMLINK perl -c /service-scripts/App-ESMFold.pl"
    echo
    echo "  # Interactive shell:"
    echo "  apptainer shell $SYMLINK"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

# Cleanup
rm -f "$TMP_DEF"