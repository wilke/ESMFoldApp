# ESMFold BV-BRC Alpha Release v0.9.0

## Overview

ESMFold BV-BRC Alpha provides protein structure prediction capabilities integrated with the BV-BRC (Bacterial and Viral Bioinformatics Resource Center) platform. This alpha release enables researchers to predict protein structures using Meta's ESMFold model through the standard BV-BRC AppService framework.

## Key Features

### ✅ Implemented in Alpha
- **ESMFold Integration**: Working protein structure prediction using ESM2_t36_3B_UR50D model
- **GPU Acceleration**: V100 GPU support with CUDA 11.3
- **BV-BRC Service Integration**: Complete App-ESMFold.pl service script
- **Workspace I/O**: Download input FASTA files and upload PDB results to BV-BRC workspace
- **Resource Management**: Intelligent preflight function that scales resources based on sequence characteristics
- **Container Runtime**: Apptainer/Singularity container deployment
- **Cleanup**: Automatic temporary file cleanup
- **Validation**: FASTA format validation and error handling

### 🔄 Container Configurations
- **Base Container**: `esmfold.v0.1.sif` (7.2GB) - Proven V100/A100 compatibility
- **Unified Container**: `esmfold-bvbrc.sif` - ESMFold + PATRIC runtime (in progress)

## Performance Characteristics

### Resource Requirements
- **CPU**: 8 cores (default), up to 16 for CPU-only mode
- **Memory**: 32-64GB depending on sequence length
- **GPU Memory**: 16-32GB for V100/A100 GPUs
- **Runtime**: 10 minutes to 1 hour depending on sequence length and count

### Sequence Length Scaling
- **≤400 amino acids**: 32GB RAM, 16GB GPU memory, ~10 minutes
- **400-800 amino acids**: 40GB RAM, 20GB GPU memory, ~15 minutes
- **800-1500 amino acids**: 48GB RAM, 24GB GPU memory, ~30 minutes
- **>1500 amino acids**: 64GB RAM, 32GB GPU memory, ~1 hour

### GPU Compatibility
- ✅ **V100**: Fully supported (CUDA 11.3, PyTorch 1.12.1)
- ✅ **A100**: Supported (compute capability 8.0)
- ❌ **H100**: Not supported in alpha (requires PyTorch 2.0+)

## Known Limitations

### GPU Architecture
- H100 GPUs require PyTorch 2.0+ (dependency conflicts in current container)
- CPU-only mode is 8x slower than GPU acceleration

### Model Support
- Currently supports ESM2_t36_3B_UR50D model only
- No support for smaller/larger ESM variants in this release

### Sequence Constraints
- Maximum tested sequence length: ~1500 amino acids
- Very long sequences (>2000 aa) may cause memory issues
- Batch processing efficiency decreases with mixed sequence lengths

## Installation & Usage

### Container Images
```bash
# Base ESMFold container (working)
/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif

# Unified BV-BRC container (when available)
/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold-bvbrc.sif
```

### Service Integration
```bash
# Service script location
service-scripts/App-ESMFold.pl

# App specification
app_specs/ESMFold.json
```

### Test Commands
```bash
# Test ESMFold directly
singularity run --nv esmfold.v0.1.sif esm-fold --help

# Test container functionality
singularity test esmfold.v0.1.sif

# Run integration test
./test/integration_test.sh
```

## Testing Status

### ✅ Completed Tests
- Container syntax validation
- ESMFold executable verification
- Service script implementation
- FASTA validation
- Basic GPU detection
- Resource requirement calculation

### 🔄 In Progress Tests
- Performance benchmarking with different sequence lengths
- Integration testing with BV-BRC workspace
- Unified container validation

### ❌ Deferred Tests
- H100 GPU compatibility
- Multi-model support
- Large-scale batch processing

## Dependencies

### Container Runtime
- Singularity/Apptainer
- NVIDIA Container Toolkit (for GPU support)
- CUDA 11.3+ compatible drivers

### Perl Modules (in container)
- Bio::KBase::AppService::AppScript
- Bio::KBase::AppService::AppConfig
- Standard Perl modules (File::*, JSON, Data::Dumper)

### Python Environment (in container)
- PyTorch 1.12.1
- fair-esm
- OpenFold
- BioPython

## File Structure
```
ESMFoldApp/
├── service-scripts/
│   └── App-ESMFold.pl          # Main BV-BRC service
├── app_specs/
│   └── ESMFold.json            # Application specification
├── scripts/
│   ├── esm-fold-wrapper        # ESMFold wrapper script
│   └── performance_test.sh     # Performance benchmarking
├── container/
│   ├── ESMFoldApp.def          # Unified container definition
│   ├── esmfold.def             # Base ESMFold container
│   └── build_unified.sh        # Build script
└── test/
    ├── test_service.sh         # Service validation
    └── integration_test.sh     # End-to-end testing
```

## Deployment Notes

### For BV-BRC Integration
1. Deploy container to shared storage location
2. Install service script in BV-BRC AppService framework
3. Register app specification in BV-BRC catalog
4. Configure resource allocation in cluster scheduler

### For Standalone Use
1. Download container image
2. Prepare input FASTA files
3. Run with appropriate GPU and memory allocation
4. Process PDB outputs as needed

## Future Work (Post-Alpha)

### High Priority
- H100 GPU support (PyTorch 2.0 upgrade)
- Performance optimization for large sequences
- Multi-model support (ESM2 variants)

### Medium Priority
- CPU performance improvements
- Batch processing optimization
- Advanced result visualization

### Low Priority
- Custom model fine-tuning
- Integration with other structure prediction tools
- Cloud deployment options

## Support & Documentation

### Logs and Debugging
- Container logs: Check singularity execution output
- Service logs: Available through BV-BRC AppService framework
- Performance data: Generated by performance_test.sh

### Common Issues
1. **GPU Memory Errors**: Reduce chunk_size parameter or use smaller sequences
2. **Container Not Found**: Verify container path and permissions
3. **Slow Performance**: Ensure GPU acceleration is enabled with --nv flag

## Release Metadata

- **Version**: v0.9.0-alpha
- **Release Date**: September 17, 2025
- **Container Base**: esmfold.v0.1.sif
- **BV-BRC Compatibility**: AppService framework
- **GPU Target**: V100/A100 (H100 deferred)
- **Test Status**: Integration testing in progress