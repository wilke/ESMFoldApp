# Standard Operating Procedure: ESMFold Service Development

## Overview
This document outlines the procedure for developing, testing, and deploying the ESMFold service for BV-BRC/PATRIC.

## Prerequisites
- Access to BV-BRC dev containers
- ESMFold base container image
- PATRIC runtime environment
- Model weights cached in designated location

## Development Workflow

### Step 1: Extract PATRIC Runtime
Extract the PATRIC runtime from the ubuntu-dev container to create a reusable tar archive:

```bash
# Extract runtime from container
apptainer exec /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/ubuntu-dev-118-12.sif \
    tar -czf /tmp/patric-runtime.tar.gz -C / opt/patric-common/runtime

# Verify tar structure (should unpack to /opt/patric-common/runtime)
tar -tzf /tmp/patric-runtime.tar.gz | head -5
```

### Step 2: Setup Development Environment

#### 2.1 Clone/Setup dev_container
```bash
# Use existing dev_container
DEV_CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/dev_container"

# Or clone fresh copy
git clone <dev_container_repo> dev_container
```

#### 2.2 Prepare Service Module
```bash
# Current ESMFoldApp location
SERVICE_APP="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp"
```

### Step 3: Development Container Testing

#### 3.1 Run with ubuntu-dev container
```bash
# Start development container with necessary bind mounts
apptainer shell --nv \
    --bind $DEV_CONTAINER:/dev_container \
    --bind $SERVICE_APP:/dev_container/modules/ESMFoldApp \
    --bind /nfs/ml_lab/projects/ml_lab/cepi/alphafold/models:/models \
    /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/ubuntu-dev-118-12.sif

# Inside container:
cd /dev_container
./bootstrap /opt/patric-common/runtime  # Initialize with runtime
source user-env.sh                      # Setup environment
make                                     # Build modules
cd modules/ESMFoldApp
# Test service scripts
```

#### 3.2 Unit Testing
```bash
# Test individual components
perl -c service-scripts/App-ESMFold.pl  # Syntax check
python3 lib/ESMFoldWrapper.py --help     # Python wrapper
./scripts/esmfold --help                 # CLI wrapper
```

### Step 4: Create Service-App Dev Container

#### 4.1 Create Apptainer Definition
```singularity
Bootstrap: localimage
From: /nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif

%files
    # Add PATRIC runtime
    /tmp/patric-runtime.tar.gz /tmp/

%post
    # Extract PATRIC runtime
    cd /
    tar -xzf /tmp/patric-runtime.tar.gz
    rm /tmp/patric-runtime.tar.gz
    
    # Install additional dependencies for BV-BRC
    apt-get update && apt-get install -y \
        perl \
        libfindbin-libs-perl \
        libjson-perl
    
    # Setup environment
    echo "export PATH=/opt/patric-common/runtime/bin:\$PATH" >> /etc/profile
    echo "export PERL5LIB=/opt/patric-common/runtime/lib/perl5:\$PERL5LIB" >> /etc/profile

%environment
    export PATH=/opt/patric-common/runtime/bin:$PATH
    export PERL5LIB=/opt/patric-common/runtime/lib/perl5:$PERL5LIB
    export ESMFOLD_MODELS=/models

%runscript
    exec "$@"
```

#### 4.2 Build Dev Container
```bash
apptainer build esmfold-dev.sif esmfold-dev.def
```

### Step 5: Integration Testing

#### 5.1 Test with Dev Container
```bash
# Run with all necessary binds
apptainer exec --nv \
    --bind $DEV_CONTAINER:/dev_container \
    --bind $SERVICE_APP:/dev_container/modules/ESMFoldApp \
    --bind /nfs/ml_lab/projects/ml_lab/cepi/alphafold/models:/models \
    --bind ./test_data:/test_data \
    esmfold-dev.sif \
    /dev_container/modules/ESMFoldApp/service-scripts/App-ESMFold.pl \
    --test-mode
```

#### 5.2 Workspace Integration
```bash
# Login to P3/BV-BRC
p3-login <username>

# Test with workspace
# (Requires credentials and workspace access)
```

### Step 6: Model Weight Management

#### 6.1 Cache Model Weights
```bash
# Models should be cached in:
MODEL_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/models/esmfold"
mkdir -p $MODEL_DIR

# Download and cache models (if not already present)
python3 -c "
import torch
import esm
# Set cache directory
torch.hub.set_dir('$MODEL_DIR')
# Download model
model = esm.pretrained.esmfold_v1()
"
```

#### 6.2 Configure Service to Use Cached Models
The service should use `application_backend_dir()` to find models:
- Development: `/nfs/ml_lab/projects/ml_lab/cepi/alphafold/models`
- Production: Automatically mounted by BV-BRC

## Testing Checklist

### Unit Tests
- [ ] Perl syntax check passes
- [ ] Python wrapper executes
- [ ] CLI script runs with --help
- [ ] JSON specification is valid

### Integration Tests
- [ ] Service runs in dev container
- [ ] Input FASTA processing works
- [ ] Output PDB files generated
- [ ] Container GPU detection works
- [ ] Model weights load from cache

### System Tests
- [ ] Workspace authentication works
- [ ] File upload/download to workspace
- [ ] Resource allocation (CPU/GPU/Memory)
- [ ] Job completion and cleanup

## Troubleshooting

### Common Issues

1. **Missing PATRIC modules**
   - Ensure PERL5LIB includes `/opt/patric-common/runtime/lib/perl5`
   - Check runtime was extracted correctly

2. **Model download issues**
   - Pre-cache models in designated directory
   - Set TORCH_HOME environment variable

3. **GPU not detected**
   - Add `--nv` flag to apptainer commands
   - Check nvidia-smi availability

4. **Workspace access denied**
   - Run `p3-login` to authenticate
   - Check credentials in `~/.patric_config`

## Production Deployment

Final container should include:
1. ESMFold application
2. PATRIC runtime
3. Service scripts
4. Cached model weights (or mount point)

Container will be registered with BV-BRC service registry for automatic deployment.