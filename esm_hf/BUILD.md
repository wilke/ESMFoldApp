# ESM HuggingFace - Build Instructions

This document covers building containers and packages for the ESM HuggingFace project.

## Table of Contents
1. [Python Package Build](#python-package-build)
2. [Docker Build](#docker-build)
3. [Singularity Build](#singularity-build)
4. [CI/CD Integration](#cicd-integration)

## Python Package Build

### Building the Package

```bash
cd /path/to/esm_hf

# Install build tools
pip install build twine

# Build source distribution and wheel
python -m build

# Output will be in dist/
ls dist/
# esm_hf-1.0.0.tar.gz
# esm_hf-1.0.0-py3-none-any.whl
```

### Installing from Built Package

```bash
# Install from wheel
pip install dist/esm_hf-1.0.0-py3-none-any.whl

# Install from source distribution
pip install dist/esm_hf-1.0.0.tar.gz
```

## Docker Build

### Standard Build

```bash
cd /path/to/esm_hf

# Build GPU version
docker build -t esmfold-hf:latest .

# Build with custom tag
docker build -t esmfold-hf:v1.0.0 .

# Build CPU-only version
docker build --build-arg INSTALL_GPU=false -t esmfold-hf:cpu .
```

### Build Arguments Reference

| Argument | Default | Description |
|----------|---------|-------------|
| `PYTHON_VERSION` | 3.10 | Python version to install |
| `INSTALL_GPU` | true | Whether to include CUDA support |
| `TORCH_VERSION` | 2.2.0 | PyTorch version |
| `TORCH_CUDA` | cu121 | CUDA version for PyTorch wheel |

### Custom Builds

```bash
# Build with specific versions
docker build \
  --build-arg PYTHON_VERSION=3.11 \
  --build-arg TORCH_VERSION=2.3.0 \
  --build-arg TORCH_CUDA=cu124 \
  -t esmfold-hf:custom .

# Build with model pre-downloaded (larger image, faster startup)
# Uncomment the RUN python -c "..." line in Dockerfile first
docker build -t esmfold-hf:with-model .
```

### Multi-Platform Build

```bash
# Enable buildx
docker buildx create --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t esmfold-hf:latest \
  --push .
```

### Image Optimization

```bash
# Check image size
docker images esmfold-hf

# Analyze image layers
docker history esmfold-hf:latest

# Slim the image (removes unused files)
docker-slim build esmfold-hf:latest
```

### Docker Best Practices

1. **Layer Caching**: The Dockerfile is structured to maximize layer caching:
   - System packages first
   - Python packages second
   - Application code last

2. **Multi-stage Builds**: For smaller images, consider multi-stage builds:
```dockerfile
# Build stage
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04 as builder
# ... install build dependencies ...

# Runtime stage
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04
COPY --from=builder /workspace /workspace
```

3. **Security Scanning**:
```bash
# Scan for vulnerabilities
docker scan esmfold-hf:latest
# or
trivy image esmfold-hf:latest
```

## Singularity Build

### Standard Build

```bash
cd /path/to/esm_hf

# Build with fakeroot (unprivileged user)
singularity build --fakeroot esmfold_hf.sif esmfold_hf.def

# Build with sudo
sudo singularity build esmfold_hf.sif esmfold_hf.def
```

### Build from Docker Image

```bash
# Build Docker image first
docker build -t esmfold-hf:latest .

# Convert to Singularity
singularity build esmfold_hf.sif docker-daemon://esmfold-hf:latest
```

### Build on Remote System

```bash
# Build on Sylabs Cloud
singularity build --remote esmfold_hf.sif esmfold_hf.def

# Or using a remote builder
singularity build --builder https://build.example.com esmfold_hf.sif esmfold_hf.def
```

### Singularity Build Options

```bash
# Build sandbox (writable directory format)
singularity build --sandbox esmfold_sandbox/ esmfold_hf.def

# Convert sandbox to SIF
singularity build esmfold_hf.sif esmfold_sandbox/

# Force rebuild
singularity build --force esmfold_hf.sif esmfold_hf.def
```

### Signing Containers

```bash
# Generate key pair
singularity key newpair

# Sign the container
singularity sign esmfold_hf.sif

# Verify signature
singularity verify esmfold_hf.sif
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/build.yml
name: Build and Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install dependencies
        run: |
          pip install torch --index-url https://download.pytorch.org/whl/cpu
          pip install -e ".[dev]"

      - name: Run tests
        run: pytest tests/

  build-docker:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build image
        uses: docker/build-push-action@v5
        with:
          context: ./esm_hf
          push: false
          tags: esmfold-hf:latest
          build-args: |
            INSTALL_GPU=false
          cache-from: type=gha
          cache-to: type=gha,mode=max

  build-package:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Build package
        run: |
          pip install build
          cd esm_hf && python -m build

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: package
          path: esm_hf/dist/
```

### Makefile for Common Tasks

```makefile
# Makefile
.PHONY: all clean build test docker singularity

VERSION := 1.0.0
IMAGE_NAME := esmfold-hf

all: build

clean:
	rm -rf dist/ build/ *.egg-info
	rm -f *.sif

build:
	python -m build

test:
	pytest tests/ -v

docker:
	docker build -t $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest

docker-cpu:
	docker build --build-arg INSTALL_GPU=false -t $(IMAGE_NAME):$(VERSION)-cpu .

singularity:
	singularity build --fakeroot $(IMAGE_NAME)_$(VERSION).sif esmfold_hf.def

install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"
```

## Build Checklist

Before releasing a new version:

1. [ ] Update version in `__init__.py`
2. [ ] Update version in `setup.py` and `pyproject.toml`
3. [ ] Update CHANGELOG.md
4. [ ] Run all tests: `pytest tests/`
5. [ ] Build Python package: `python -m build`
6. [ ] Build Docker image: `docker build -t esmfold-hf:vX.X.X .`
7. [ ] Build Singularity image: `singularity build esmfold_hf.sif esmfold_hf.def`
8. [ ] Test containers with example data
9. [ ] Tag release in git: `git tag vX.X.X`
