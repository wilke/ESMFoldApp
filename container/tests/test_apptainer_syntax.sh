#!/bin/bash
#
# Quick syntax validation for Apptainer definition file
# Tests the definition without full build
#

set -e

echo "========================================="
echo "Apptainer Definition Syntax Test"
echo "========================================="

# Check Apptainer availability
if ! command -v apptainer > /dev/null 2>&1; then
    echo "❌ Apptainer not found"
    echo "   Try: module load apptainer"
    exit 1
fi

echo "✅ Apptainer available: $(apptainer version)"

# Check definition file exists
if [ ! -f "esmfold.def" ]; then
    echo "❌ esmfold.def not found"
    exit 1
fi

echo "✅ Definition file found: esmfold.def"

# Validate definition file syntax by checking sections
echo ""
echo "Checking definition file structure..."

# Check required sections
BOOTSTRAP=$(grep "^Bootstrap:" esmfold.def)
FROM=$(grep "^From:" esmfold.def)

if [ -n "$BOOTSTRAP" ] && [ -n "$FROM" ]; then
    echo "✅ Header: $BOOTSTRAP"
    echo "✅ Base image: $FROM"
else
    echo "❌ Invalid header section"
    exit 1
fi

# Check for %post section
if grep -q "^%post" esmfold.def; then
    echo "✅ %post section found"
else
    echo "⚠️  No %post section"
fi

# Check for %runscript
if grep -q "^%runscript" esmfold.def; then
    echo "✅ %runscript section found"
else
    echo "⚠️  No %runscript section"
fi

# Check for %help
if grep -q "^%help" esmfold.def; then
    echo "✅ %help section found"
else
    echo "⚠️  No %help section"
fi

# Check images directory
IMAGES_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images"
if [ -d "$IMAGES_DIR" ]; then
    echo "✅ Images directory exists: $IMAGES_DIR"
    echo "   Available images:"
    ls -1 "$IMAGES_DIR" | head -5
    if [ $(ls "$IMAGES_DIR" | wc -l) -gt 5 ]; then
        echo "   ... and $(expr $(ls "$IMAGES_DIR" | wc -l) - 5) more"
    fi
else
    echo "⚠️  Images directory not found: $IMAGES_DIR"
    echo "   Will create during build"
fi

echo ""
echo "========================================="
echo "✅ Syntax validation passed!"
echo "========================================="
echo ""
echo "Definition file is ready for:"
echo "  apptainer build $IMAGES_DIR/esmfold_gpu.sif esmfold.def"
echo ""
echo "Estimated build time: 15-25 minutes"
echo "Container size: ~2-4 GB"