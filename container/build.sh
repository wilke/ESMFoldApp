#!/bin/bash
#
# ESMFold Container Build Script
# Unified build script for Docker and Apptainer containers
#
# Usage:
#   ./build.sh docker [target]    Build Docker images
#   ./build.sh apptainer [target] Build Apptainer images
#   ./build.sh test               Run container tests
#   ./build.sh all                Build everything
#   ./build.sh clean              Remove build artifacts
#
# Docker targets: cuda11, cuda12, cpu, bvbrc, dev, hf
# Apptainer targets: prod, bvbrc, pytorch, hf

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default settings
PLATFORM="linux/amd64"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << 'EOF'
ESMFold Container Build Script

Usage: ./build.sh <command> [target]

Commands:
  docker [target]     Build Docker image(s)
  apptainer [target]  Build Apptainer/Singularity image(s)
  test                Run container tests
  all                 Build all containers
  clean               Remove build artifacts
  help                Show this help

Docker Targets:
  cuda11    GPU container (CUDA 11.3, V100/A100)
  cuda12    GPU container (CUDA 12.1, H100 compatible)
  cpu       CPU-only container (testing)
  bvbrc     BV-BRC integrated container
  dev       Development container
  hf        HuggingFace lightweight container
  all       Build all Docker targets

Apptainer Targets:
  prod      Production container (ESMFoldApp.def)
  bvbrc     BV-BRC integrated (esmfold-bvbrc.def)
  pytorch   PyTorch 2.x / H100 (esmfold_pytorch.def)
  hf        HuggingFace container
  all       Build all Apptainer targets

Examples:
  ./build.sh docker cuda11       # Build CUDA 11 Docker image
  ./build.sh docker all          # Build all Docker images
  ./build.sh apptainer prod      # Build production Apptainer
  ./build.sh test                # Run tests
  ./build.sh all                 # Build everything

Environment Variables:
  DOCKER_REGISTRY    Docker registry prefix (e.g., "dxkb/")
  PLATFORM           Build platform (default: linux/amd64)
EOF
}

# Docker build functions
build_docker_cuda11() {
    log_info "Building Docker CUDA 11.3 image..."
    docker build --platform "$PLATFORM" \
        -f "$SCRIPT_DIR/docker/Dockerfile.cuda11" \
        -t "${DOCKER_REGISTRY}esmfold:cuda11" \
        "$PROJECT_ROOT"
    log_success "Built ${DOCKER_REGISTRY}esmfold:cuda11"
}

build_docker_cuda12() {
    log_info "Building Docker CUDA 12 image..."
    docker build --platform "$PLATFORM" \
        -f "$SCRIPT_DIR/docker/Dockerfile.cuda12" \
        -t "${DOCKER_REGISTRY}esmfold:cuda12" \
        "$PROJECT_ROOT"
    log_success "Built ${DOCKER_REGISTRY}esmfold:cuda12"
}

build_docker_cpu() {
    log_info "Building Docker CPU image..."
    docker build --platform "$PLATFORM" \
        -f "$SCRIPT_DIR/docker/Dockerfile.cpu" \
        -t "${DOCKER_REGISTRY}esmfold:cpu" \
        "$PROJECT_ROOT"
    log_success "Built ${DOCKER_REGISTRY}esmfold:cpu"
}

build_docker_bvbrc() {
    log_info "Building Docker BV-BRC image..."
    # Check for base image
    if ! docker image inspect esmfold:prod >/dev/null 2>&1; then
        log_warn "Base image esmfold:prod not found, building cuda11 first..."
        build_docker_cuda11
        docker tag "${DOCKER_REGISTRY}esmfold:cuda11" esmfold:prod
    fi
    docker build --platform "$PLATFORM" \
        -f "$SCRIPT_DIR/docker/Dockerfile.bvbrc" \
        -t "${DOCKER_REGISTRY}esmfold:bvbrc" \
        "$PROJECT_ROOT"
    log_success "Built ${DOCKER_REGISTRY}esmfold:bvbrc"
}

build_docker_dev() {
    log_info "Building Docker dev image..."
    docker build --platform "$PLATFORM" \
        -f "$SCRIPT_DIR/docker/Dockerfile.dev" \
        -t "${DOCKER_REGISTRY}esmfold:dev" \
        "$PROJECT_ROOT"
    log_success "Built ${DOCKER_REGISTRY}esmfold:dev"
}

build_docker_hf() {
    log_info "Building Docker HuggingFace image..."
    docker build --platform "$PLATFORM" \
        -f "$PROJECT_ROOT/esm_hf/Dockerfile" \
        -t "${DOCKER_REGISTRY}esmfold-hf:latest" \
        "$PROJECT_ROOT/esm_hf"
    log_success "Built ${DOCKER_REGISTRY}esmfold-hf:latest"
}

build_docker_all() {
    log_info "Building all Docker images..."
    build_docker_cpu
    build_docker_cuda11
    build_docker_cuda12
    build_docker_hf
    log_success "All Docker images built"
}

# Apptainer build functions
check_apptainer() {
    if command -v apptainer &> /dev/null; then
        echo "apptainer"
    elif command -v singularity &> /dev/null; then
        echo "singularity"
    else
        log_error "Neither Apptainer nor Singularity found"
        exit 1
    fi
}

build_apptainer_prod() {
    local cmd=$(check_apptainer)
    log_info "Building Apptainer production image..."
    $cmd build esmfold.sif "$SCRIPT_DIR/apptainer/ESMFoldApp.def"
    log_success "Built esmfold.sif"
}

build_apptainer_bvbrc() {
    local cmd=$(check_apptainer)
    log_info "Building Apptainer BV-BRC image..."
    $cmd build esmfold-bvbrc.sif "$SCRIPT_DIR/apptainer/esmfold-bvbrc.def"
    log_success "Built esmfold-bvbrc.sif"
}

build_apptainer_pytorch() {
    local cmd=$(check_apptainer)
    log_info "Building Apptainer PyTorch/H100 image..."
    $cmd build esmfold-pytorch.sif "$SCRIPT_DIR/apptainer/esmfold_pytorch.def"
    log_success "Built esmfold-pytorch.sif"
}

build_apptainer_hf() {
    local cmd=$(check_apptainer)
    log_info "Building Apptainer HuggingFace image..."
    $cmd build esmfold-hf.sif "$PROJECT_ROOT/esm_hf/esmfold_hf.def"
    log_success "Built esmfold-hf.sif"
}

build_apptainer_all() {
    log_info "Building all Apptainer images..."
    build_apptainer_prod
    build_apptainer_pytorch
    build_apptainer_hf
    log_success "All Apptainer images built"
}

# Test function
run_tests() {
    log_info "Running container tests..."

    # Run test scripts in tests/ directory
    if [ -d "$SCRIPT_DIR/tests" ]; then
        for test_script in "$SCRIPT_DIR/tests"/test_*.sh; do
            if [ -f "$test_script" ]; then
                log_info "Running $(basename "$test_script")..."
                bash "$test_script" || log_warn "Test failed: $test_script"
            fi
        done
    fi

    log_success "Tests completed"
}

# Clean function
clean_artifacts() {
    log_info "Cleaning build artifacts..."
    rm -f "$SCRIPT_DIR"/*.sif
    rm -f /tmp/esmfold_*.log
    log_success "Cleaned build artifacts"
}

# Main command handling
case "${1:-help}" in
    docker)
        case "${2:-all}" in
            cuda11) build_docker_cuda11 ;;
            cuda12) build_docker_cuda12 ;;
            cpu) build_docker_cpu ;;
            bvbrc) build_docker_bvbrc ;;
            dev) build_docker_dev ;;
            hf) build_docker_hf ;;
            all) build_docker_all ;;
            *) log_error "Unknown Docker target: $2"; show_help; exit 1 ;;
        esac
        ;;
    apptainer|singularity)
        case "${2:-all}" in
            prod) build_apptainer_prod ;;
            bvbrc) build_apptainer_bvbrc ;;
            pytorch) build_apptainer_pytorch ;;
            hf) build_apptainer_hf ;;
            all) build_apptainer_all ;;
            *) log_error "Unknown Apptainer target: $2"; show_help; exit 1 ;;
        esac
        ;;
    test)
        run_tests
        ;;
    all)
        build_docker_all
        build_apptainer_all
        ;;
    clean)
        clean_artifacts
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
