# ESMFold Container Definitions

This directory contains container definitions and related files for the ESMFold service.

## Files

- `Dockerfile` - Docker container definition
- `esmfold.def` - Apptainer/Singularity definition
- `esmfold.cwl` - Common Workflow Language tool description
- `bvbrc_config.yaml` - BV-BRC service configuration
- `build.sh` - Build script for containers
- `test.sh` - Test script for container validation

## Building Containers

### Docker
```bash
./build.sh
# or manually:
docker build -t esmfold:latest -f Dockerfile .
```

### Apptainer/Singularity
```bash
./build.sh
# or manually:
apptainer build esmfold.sif esmfold.def
```

## Testing

Run the test script to validate container functionality:
```bash
./test.sh
```

This will test both Docker and Apptainer containers with the test data.

## Usage

### Docker
```bash
docker run -v /path/to/input:/input -v /path/to/output:/output \
    esmfold:latest -i /input/proteins.fasta -o /output
```

### Singularity/Apptainer
```bash
singularity run esmfold.sif -i proteins.fasta -o output_dir
```

## Container Features

- Pre-downloaded ESMFold v1 model
- GPU support with CUDA 11.7
- CPU-only fallback mode
- Batch processing for short sequences
- Memory-efficient CPU offloading option

## Resource Requirements

- **Minimum RAM**: 16GB
- **Recommended RAM**: 32GB (64GB for sequences >1000aa)
- **GPU**: Optional but recommended (NVIDIA GPU with CUDA 11.7+)
- **Storage**: ~5GB for container + model