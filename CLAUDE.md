# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ESMFoldApp is a BV-BRC (Bacterial and Viral Bioinformatics Resource Center) module that provides protein structure prediction using Meta's ESMFold model. It integrates with the BV-BRC infrastructure and follows the standard BV-BRC application service pattern.

## Architecture

### BV-BRC Module Structure
- **`app_specs/`** - Application specifications in JSON format defining parameters, resources, and metadata
- **`lib/`** - Perl/Python libraries for the ESMFold wrapper and utilities
- **`scripts/`** - Command-line scripts for direct invocation
- **`service-scripts/`** - Service entry points (App-*.pl files) that integrate with BV-BRC AppService framework

### Service Pattern
BV-BRC services follow a standard pattern:
1. Service scripts (App-*.pl) use Bio::KBase::AppService::AppScript framework
2. Each service implements a main function and preflight function
3. Preflight defines resource requirements (CPU, memory, runtime, storage)
4. Main function performs the actual work using parameters from app_specs JSON

## Common Development Commands

### Build and Deploy
```bash
# Build the module
make

# Deploy client tools
make deploy-client

# Deploy service (includes specs, scripts, and libs)
make deploy-service

# Deploy to specific target
make deploy TARGET=/kb/deployment
```

### Testing
```bash
# Run client tests
make test-client

# Run server tests  
make test-server

# Run production tests
make test-prod
```

## ESMFold Integration Requirements

### Model Setup
- ESMFold requires downloading pre-trained model weights (~2GB for esm2_t36_3B_UR50D)
- Models should be cached in a persistent location (e.g., `/kb/deployment/models/esmfold/`)
- First-time model loading can take several minutes

### Dependencies
The service requires:
- Python 3.8+
- PyTorch
- Fair-esm library (`pip install fair-esm`)
- BioPython for sequence handling
- NumPy for array operations

### Input/Output Format
- **Input**: FASTA format protein sequences
- **Output**: PDB format structure files
- **Parameters**: model_name, chunk_size, num_recycles

### Resource Requirements
Typical resource allocation for ESMFold:
- CPU: 4-8 cores
- Memory: 16-32GB (depending on model size)
- GPU: Optional but recommended for performance
- Runtime: 300-600 seconds per sequence (varies by length)

## Application Specification Format

App specs in `app_specs/ESMFold.json` should define:
```json
{
    "id": "ESMFold",
    "script": "App-ESMFold",
    "label": "ESMFold Protein Structure Prediction",
    "description": "Predict protein structures using Meta's ESMFold",
    "parameters": [
        {
            "id": "input_file",
            "type": "wsfile",
            "required": 1,
            "label": "Input FASTA file"
        },
        {
            "id": "model_name", 
            "type": "string",
            "default": "esm2_t36_3B_UR50D",
            "label": "ESMFold model to use"
        }
    ],
    "default_memory": "32G",
    "default_cpu": 8,
    "default_runtime": 3600
}
```

## Service Script Pattern

Service scripts in `service-scripts/` should follow the BV-BRC pattern:
```perl
use Bio::KBase::AppService::AppScript;
use strict;

my $script = Bio::KBase::AppService::AppScript->new(\&run_esmfold, \&preflight);
$script->run(\@ARGV);

sub preflight {
    my($app, $app_def, $raw_params, $params) = @_;
    return {
        cpu => 8,
        memory => "32G", 
        runtime => 3600,
        storage => "10G"
    };
}

sub run_esmfold {
    my($app, $app_def, $raw_params, $params) = @_;
    # Implementation calling Python ESMFold wrapper
}
```

## Python Wrapper Implementation

The Python wrapper in `lib/` should:
1. Load the ESMFold model from cached location
2. Process input FASTA sequences
3. Run structure prediction
4. Write PDB output files
5. Handle errors and logging

## Deployment Notes

- Service runs within BV-BRC's execution environment
- Access to workspace service for file I/O
- Integrates with BV-BRC job management
- Results stored in user's workspace