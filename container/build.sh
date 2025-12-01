#!/bin/bash
#
# Build script for ESMFold containers
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Building ESMFold containers..."

# Build Docker container
if command -v docker &> /dev/null; then
    echo "Building Docker container..."
    docker build --platform linux/amd64 -t esmfold:latest -f Dockerfile .
    echo "Docker container built successfully: esmfold:latest"
else
    echo "Docker not found, skipping Docker build"
fi

# Build Singularity/Apptainer container
if command -v apptainer &> /dev/null; then
    echo "Building Apptainer container..."
    apptainer build esmfold.sif esmfold.def
    echo "Apptainer container built successfully: esmfold.sif"
elif command -v singularity &> /dev/null; then
    echo "Building Singularity container..."
    singularity build esmfold.sif esmfold.def
    echo "Singularity container built successfully: esmfold.sif"
else
    echo "Neither Apptainer nor Singularity found, skipping SIF build"
fi

echo "Container build complete!"