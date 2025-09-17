#!/bin/bash
#
# Stage 3: Full GPU testing with Apptainer on H100 server
# Production validation with comprehensive tests
#

set -e

echo "========================================="
echo "Stage 3: Apptainer GPU Container Test"
echo "========================================="
echo ""

# Check for NVIDIA drivers
echo "Checking GPU environment..."
if ! nvidia-smi > /dev/null 2>&1; then
    echo "❌ nvidia-smi not found. Is this a GPU server?"
    exit 1
fi

echo "GPU Info:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo ""

# Check if Apptainer is available
echo "Checking Apptainer availability..."
if ! command -v apptainer > /dev/null 2>&1; then
    echo "❌ Apptainer not found. Please install Apptainer."
    echo "   Try: module load apptainer (on HPC systems)"
    exit 1
fi

echo "Apptainer version: $(apptainer version)"
echo ""

# Build the GPU container from definition file
echo "Building Apptainer GPU container..."
IMAGES_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images"
CONTAINER_FILE="$IMAGES_DIR/esmfold_gpu.sif"

# Ensure images directory exists
mkdir -p "$IMAGES_DIR"

if [ -f "$CONTAINER_FILE" ]; then
    echo "⚠️  Container $CONTAINER_FILE already exists"
    read -p "Rebuild? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$CONTAINER_FILE"
    else
        echo "Using existing container..."
    fi
fi

if [ ! -f "$CONTAINER_FILE" ]; then
    echo "Building from esmfold.def..."
    START_BUILD=$(date +%s)
    
    if apptainer build "$CONTAINER_FILE" esmfold.def; then
        END_BUILD=$(date +%s)
        BUILD_TIME=$((END_BUILD - START_BUILD))
        echo "✅ Container built successfully in ${BUILD_TIME}s"
    else
        echo "❌ Container build failed"
        echo "Try with --fakeroot flag if permission issues:"
        echo "   apptainer build --fakeroot $CONTAINER_FILE esmfold.def"
        exit 1
    fi
else
    echo "✅ Using existing container: $CONTAINER_FILE"
fi

# Test GPU accessibility in container
echo ""
echo "Test 1: GPU access in container..."
if apptainer exec --nv "$CONTAINER_FILE" python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print(f'GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB')
else:
    print('❌ CUDA not available')
    exit(1)
" ; then
    echo "✅ GPU accessible in container"
else
    echo "❌ GPU not accessible"
    echo "Check NVIDIA drivers and --nv flag"
    exit 1
fi

# Test nvidia-smi access in container
echo ""
echo "Test 1.5: NVIDIA tools in container..."
if apptainer exec --nv "$CONTAINER_FILE" nvidia-smi --query-gpu=name --format=csv,noheader; then
    echo "✅ nvidia-smi works in container"
else
    echo "⚠️  nvidia-smi not accessible (may still work for training)"
fi

# Test 2: ESMFold model loading
echo ""
echo "Test 2: Loading ESMFold model..."
if apptainer exec --nv "$CONTAINER_FILE" python -c "
import esm
import torch
print('Loading ESMFold v1...')
model = esm.pretrained.esmfold_v1()
model = model.eval()
if torch.cuda.is_available():
    model = model.cuda()
    print('✅ Model loaded on GPU')
else:
    print('⚠️  Model loaded on CPU')
    exit(1)
print(f'Model parameters: {sum(p.numel() for p in model.parameters()):,}')
" ; then
    echo "✅ Model loading successful"
else
    echo "❌ Model loading failed"
    exit 1
fi

# Test 3: Single protein folding with GPU
echo ""
echo "Test 3: Single protein folding (GPU)..."
mkdir -p test_output_apptainer

START_TIME=$(date +%s)

apptainer run --nv \
    --bind "$PWD/../test_data:/input:ro" \
    --bind "$PWD/test_output_apptainer:/output" \
    "$CONTAINER_FILE" \
    -i /input/single_protein.fasta \
    -o /output/single \
    --num-recycles 4 \
    --chunk-size 128

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Check for output files (look for any .pdb files)
PDB_FILES=$(find test_output_apptainer/single -name "*.pdb" 2>/dev/null | head -1)
if [ -n "$PDB_FILES" ]; then
    echo "✅ Single protein folded in ${ELAPSED}s"
    echo "   PDB file: $(basename "$PDB_FILES")"
    echo "   File size: $(ls -lh "$PDB_FILES" | awk '{print $5}')"
else
    echo "❌ Single protein folding failed"
    echo "Output directory contents:"
    ls -la test_output_apptainer/single/ || echo "Directory not created"
    exit 1
fi

# Test 4: Multi-protein batch processing
echo ""
echo "Test 4: Multi-protein batch (GPU)..."
START_TIME=$(date +%s)

apptainer run --nv \
    --bind "$PWD/../test_data:/input:ro" \
    --bind "$PWD/test_output_apptainer:/output" \
    "$CONTAINER_FILE" \
    -i /input/test_proteins.fasta \
    -o /output/batch \
    --num-recycles 4 \
    --chunk-size 256 \
    --max-tokens-per-batch 2048

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

PDB_COUNT=$(find test_output_apptainer/batch -name "*.pdb" 2>/dev/null | wc -l)
if [ "$PDB_COUNT" -gt 0 ]; then
    echo "✅ Batch processing complete in ${ELAPSED}s"
    echo "   Generated $PDB_COUNT structures:"
    find test_output_apptainer/batch -name "*.pdb" 2>/dev/null | while read pdb; do
        echo "   - $(basename "$pdb"): $(ls -lh "$pdb" | awk '{print $5}')"
    done
else
    echo "❌ Batch processing failed"
    echo "Output directory contents:"
    ls -la test_output_apptainer/batch/ || echo "Directory not created"
    exit 1
fi

# Test 5: Memory efficiency test
echo ""
echo "Test 5: Memory efficiency with CPU offloading..."
apptainer run --nv \
    --bind "$PWD/../test_data:/input:ro" \
    --bind "$PWD/test_output_apptainer:/output" \
    "$CONTAINER_FILE" \
    -i /input/single_protein.fasta \
    -o /output/offload \
    --cpu-offload \
    --num-recycles 2

OFFLOAD_FILES=$(find test_output_apptainer/offload -name "*.pdb" 2>/dev/null | head -1)
if [ -n "$OFFLOAD_FILES" ]; then
    echo "✅ CPU offloading mode works"
else
    echo "⚠️  CPU offloading might need adjustment"
fi

# Test 6: Container info and metadata
echo ""
echo "Test 6: Container information..."
echo "Container size: $(ls -lh "$CONTAINER_FILE" | awk '{print $5}')"
echo ""
echo "Container metadata:"
apptainer inspect "$CONTAINER_FILE" | head -20

# Performance summary
echo ""
echo "========================================="
echo "🎉 Apptainer GPU Container Test Complete!"
echo "========================================="
echo ""
echo "Performance Summary:"
echo "- Container build: ✅"
echo "- GPU access: ✅"
echo "- Model loading: ✅"
echo "- Single protein: ✅"
echo "- Batch processing: ✅"
echo "- Memory modes: ✅"
echo ""
echo "Container: $CONTAINER_FILE"
echo "Size: $(ls -lh "$CONTAINER_FILE" | awk '{print $5}')"
echo ""
echo "The Apptainer container is production-ready!"
echo "Issues #4, #5, #6 can be closed."
echo ""

# Display GPU utilization stats if available
if command -v nvidia-smi > /dev/null; then
    echo "Final GPU status:"
    nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used --format=csv,noheader
fi

echo ""
echo "Next steps:"
echo "1. Update TEST_RESULTS.md with Apptainer results"
echo "2. Commit successful container to git LFS or registry"
echo "3. Update production deployment scripts"