#!/bin/bash
#
# Extract minimal Perl runtime from PATRIC for ESMFold service
# This creates a much smaller runtime package with only Perl components
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/runtime"
UBUNTU_DEV="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/ubuntu-dev-118-12.sif"
OUTPUT_TAR="$RUNTIME_DIR/patric-perl-minimal-$(date +%Y%m%d).tar.gz"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Extracting Minimal Perl Runtime from PATRIC"
echo "==========================================="
echo

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${GREEN}Creating minimal runtime structure...${NC}"
mkdir -p "$TEMP_DIR/opt/patric-common/runtime"

# Extract only essential Perl components
echo -e "${GREEN}Extracting Perl binaries...${NC}"
apptainer exec "$UBUNTU_DEV" bash -c "
    cd /opt/patric-common/runtime
    # Copy perl binary and essential perl tools
    tar -cf - \
        bin/perl \
        bin/perl5* \
        bin/perldoc \
        bin/cpan* \
        2>/dev/null || true
" | tar -xf - -C "$TEMP_DIR/opt/patric-common/runtime"

echo -e "${GREEN}Extracting Perl libraries...${NC}"
apptainer exec "$UBUNTU_DEV" bash -c "
    cd /opt/patric-common/runtime
    # Copy all Perl libraries including Bio::KBase modules
    tar -cf - lib/perl5 2>/dev/null
" | tar -xf - -C "$TEMP_DIR/opt/patric-common/runtime"

echo -e "${GREEN}Extracting shared libraries for Perl...${NC}"
apptainer exec "$UBUNTU_DEV" bash -c "
    cd /opt/patric-common/runtime
    # Copy essential shared libraries that Perl modules might need
    tar -cf - \
        lib/*.so* \
        lib/x86_64-linux-gnu/*.so* \
        2>/dev/null || true
" | tar -xf - -C "$TEMP_DIR/opt/patric-common/runtime"

echo -e "${GREEN}Extracting Perl configuration...${NC}"
apptainer exec "$UBUNTU_DEV" bash -c "
    cd /opt/patric-common/runtime
    # Copy Perl configuration and share files
    tar -cf - \
        etc/perl* \
        share/perl* \
        2>/dev/null || true
" | tar -xf - -C "$TEMP_DIR/opt/patric-common/runtime"

# Check what we extracted
echo -e "${YELLOW}Extracted components:${NC}"
du -sh "$TEMP_DIR/opt/patric-common/runtime/"*

# Calculate total size
TOTAL_SIZE=$(du -sh "$TEMP_DIR/opt/patric-common/runtime" | cut -f1)
echo -e "${GREEN}Total minimal runtime size: $TOTAL_SIZE${NC}"

# Create compressed archive
echo -e "${GREEN}Creating compressed archive...${NC}"
cd "$TEMP_DIR"
tar -czf "$OUTPUT_TAR" opt/

# Show final size
FINAL_SIZE=$(ls -lh "$OUTPUT_TAR" | awk '{print $5}')
echo
echo -e "${GREEN}Minimal Perl runtime created:${NC}"
echo "  File: $OUTPUT_TAR"
echo "  Size: $FINAL_SIZE"
echo
echo "This runtime contains only Perl components needed for BV-BRC service integration."
echo "Use this for building the unified ESMFold container to reduce size significantly."