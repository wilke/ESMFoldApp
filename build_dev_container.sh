#!/bin/bash
#
# Build script for ESMFold service development container
# This script creates a dev container with PATRIC runtime and ESMFold
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Paths
UBUNTU_DEV_CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/ubuntu-dev-118-12.sif"
ESMFOLD_CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif"
DEV_CONTAINER_REPO="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/dev_container"
MODELS_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/models"
OUTPUT_DIR="${OUTPUT_DIR:-/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "ESMFold Service Development Container Builder"
echo "============================================="
echo

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if [ ! -f "$UBUNTU_DEV_CONTAINER" ]; then
        print_error "Ubuntu dev container not found: $UBUNTU_DEV_CONTAINER"
        exit 1
    fi
    
    if [ ! -f "$ESMFOLD_CONTAINER" ]; then
        print_error "ESMFold container not found: $ESMFOLD_CONTAINER"
        exit 1
    fi
    
    if [ ! -d "$DEV_CONTAINER_REPO" ]; then
        print_error "Dev container repo not found: $DEV_CONTAINER_REPO"
        exit 1
    fi
    
    print_status "All prerequisites found"
}

# Step 1: Extract PATRIC runtime
extract_runtime() {
    print_status "Extracting PATRIC runtime from ubuntu-dev container..."
    
    RUNTIME_TAR="/tmp/patric-runtime-$(date +%Y%m%d).tar.gz"
    
    if [ -f "$RUNTIME_TAR" ]; then
        print_warning "Runtime tar already exists, skipping extraction"
    else
        apptainer exec "$UBUNTU_DEV_CONTAINER" \
            tar -czf - -C / opt/patric-common/runtime 2>/dev/null > "$RUNTIME_TAR"
        
        # Verify tar structure
        print_status "Verifying tar structure..."
        tar -tzf "$RUNTIME_TAR" | head -3
        
        print_status "Runtime extracted to: $RUNTIME_TAR"
    fi
}

# Step 2: Create development container definition
create_dev_definition() {
    print_status "Creating development container definition..."
    
    DEF_FILE="/tmp/esmfold-dev-$(date +%Y%m%d).def"
    
    cat > "$DEF_FILE" << 'EOF'
Bootstrap: localimage
From: ESMFOLD_CONTAINER_PATH

%files
    RUNTIME_TAR_PATH /tmp/patric-runtime.tar.gz

%post
    # Extract PATRIC runtime
    echo "Extracting PATRIC runtime..."
    cd /
    tar -xzf /tmp/patric-runtime.tar.gz
    rm /tmp/patric-runtime.tar.gz
    
    # Install additional dependencies
    apt-get update && apt-get install -y \
        perl \
        libfindbin-libs-perl \
        libjson-perl \
        libwww-perl \
        libio-socket-ssl-perl \
        git \
        vim \
        less \
        && apt-get clean
    
    # Create necessary directories
    mkdir -p /dev_container
    mkdir -p /models
    mkdir -p /workspace
    
    # Setup environment
    cat >> /etc/profile << 'PROFILE'
export PATH=/opt/patric-common/runtime/bin:$PATH
export PERL5LIB=/opt/patric-common/runtime/lib/perl5:$PERL5LIB
export ESMFOLD_MODELS=/models
export TORCH_HOME=/models/torch
PROFILE

%environment
    export PATH=/opt/patric-common/runtime/bin:$PATH
    export PERL5LIB=/opt/patric-common/runtime/lib/perl5:$PERL5LIB
    export ESMFOLD_MODELS=/models
    export TORCH_HOME=/models/torch
    export ESMFOLD_CONTAINER=self

%runscript
    if [ "$1" = "shell" ]; then
        exec /bin/bash --login
    else
        exec "$@"
    fi

%labels
    Author BV-BRC
    Version 0.1.0
    Description ESMFold service development container with PATRIC runtime
EOF
    
    # Replace placeholders
    sed -i "s|ESMFOLD_CONTAINER_PATH|$ESMFOLD_CONTAINER|g" "$DEF_FILE"
    sed -i "s|RUNTIME_TAR_PATH|$RUNTIME_TAR|g" "$DEF_FILE"
    
    print_status "Definition file created: $DEF_FILE"
}

# Step 3: Build development container
build_container() {
    print_status "Building development container..."
    
    OUTPUT_IMAGE="$OUTPUT_DIR/esmfold-dev-$(date +%Y%m%d).sif"
    
    if [ -f "$OUTPUT_IMAGE" ]; then
        print_warning "Container already exists: $OUTPUT_IMAGE"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping build"
            return
        fi
        rm -f "$OUTPUT_IMAGE"
    fi
    
    apptainer build "$OUTPUT_IMAGE" "$DEF_FILE"
    
    print_status "Container built: $OUTPUT_IMAGE"
    
    # Create symlink for easy access
    SYMLINK="$OUTPUT_DIR/esmfold-dev.sif"
    rm -f "$SYMLINK"
    ln -s "$OUTPUT_IMAGE" "$SYMLINK"
    print_status "Created symlink: $SYMLINK"
}

# Step 4: Test the container
test_container() {
    print_status "Testing development container..."
    
    IMAGE="${1:-$OUTPUT_DIR/esmfold-dev.sif}"
    
    # Test 1: Check PATRIC runtime
    print_status "Testing PATRIC runtime..."
    apptainer exec "$IMAGE" which perl
    apptainer exec "$IMAGE" perl -e 'print "Perl OK\n"'
    
    # Test 2: Check Python/ESMFold
    print_status "Testing Python environment..."
    apptainer exec "$IMAGE" python3 -c "print('Python OK')"
    
    # Test 3: Check bind mounts work
    print_status "Testing bind mounts..."
    apptainer exec \
        --bind "$SCRIPT_DIR:/test" \
        "$IMAGE" ls /test/service-scripts/
    
    print_status "Container tests passed"
}

# Step 5: Create helper scripts
create_helpers() {
    print_status "Creating helper scripts..."
    
    # Create run script
    RUN_SCRIPT="$SCRIPT_DIR/run_dev.sh"
    cat > "$RUN_SCRIPT" << 'SCRIPT'
#!/bin/bash
# Helper script to run development container with proper mounts

CONTAINER="${ESMFOLD_DEV_CONTAINER:-/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold-dev.sif}"
DEV_CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/dev_container"
SERVICE_APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/models"

echo "Starting ESMFold development environment..."
echo "Container: $CONTAINER"
echo "Service app: $SERVICE_APP"

exec apptainer shell --nv \
    --bind "$DEV_CONTAINER:/dev_container" \
    --bind "$SERVICE_APP:/dev_container/modules/ESMFoldApp" \
    --bind "$MODELS_DIR:/models" \
    --bind "$HOME/.patric_config:/root/.patric_config" \
    "$CONTAINER"
SCRIPT
    chmod +x "$RUN_SCRIPT"
    print_status "Created run script: $RUN_SCRIPT"
    
    # Create test script
    TEST_SCRIPT="$SCRIPT_DIR/test_dev.sh"
    cat > "$TEST_SCRIPT" << 'SCRIPT'
#!/bin/bash
# Test script for development container

CONTAINER="${ESMFOLD_DEV_CONTAINER:-/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold-dev.sif}"
SERVICE_APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running service tests in development container..."

apptainer exec \
    --bind "$SERVICE_APP:/app" \
    "$CONTAINER" \
    bash -c "cd /app && ./tests/test_service.sh"
SCRIPT
    chmod +x "$TEST_SCRIPT"
    print_status "Created test script: $TEST_SCRIPT"
}

# Main execution
main() {
    case "${1:-all}" in
        extract)
            check_prerequisites
            extract_runtime
            ;;
        build)
            check_prerequisites
            extract_runtime
            create_dev_definition
            build_container
            ;;
        test)
            test_container "${2:-$OUTPUT_DIR/esmfold-dev.sif}"
            ;;
        helpers)
            create_helpers
            ;;
        all)
            check_prerequisites
            extract_runtime
            create_dev_definition
            build_container
            test_container "$OUTPUT_DIR/esmfold-dev.sif"
            create_helpers
            ;;
        *)
            echo "Usage: $0 [extract|build|test|helpers|all]"
            echo
            echo "Commands:"
            echo "  extract  - Extract PATRIC runtime from ubuntu-dev container"
            echo "  build    - Build development container"
            echo "  test     - Test the development container"
            echo "  helpers  - Create helper scripts"
            echo "  all      - Run all steps (default)"
            exit 1
            ;;
    esac
    
    echo
    print_status "Done!"
    
    if [ "${1:-all}" = "all" ] || [ "$1" = "helpers" ]; then
        echo
        echo "To start development environment, run:"
        echo "  ./run_dev.sh"
        echo
        echo "To run tests, use:"
        echo "  ./test_dev.sh"
    fi
}

# Run main
main "$@"