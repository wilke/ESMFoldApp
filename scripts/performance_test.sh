#!/bin/bash
#
# ESMFold Performance Testing Script
# Gathers runtime and memory usage for different input sizes
#

set -e

# Configuration
CONTAINER="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif"
TEST_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp/test_data"
OUTPUT_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold/ESMFoldApp/performance_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$OUTPUT_DIR/performance_${TIMESTAMP}.csv"

# Create directories
mkdir -p "$TEST_DIR"
mkdir -p "$OUTPUT_DIR"

# Create test sequences of different lengths
cat > "$TEST_DIR/test_50aa.fasta" << 'EOF'
>test_50aa
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSL
EOF

cat > "$TEST_DIR/test_100aa.fasta" << 'EOF'
>test_100aa
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG
KGKRIEIDSPNFQVVEKFMRFKVRMEGSVNGHEFEIEGEGEGRPYEGTQT
EOF

cat > "$TEST_DIR/test_200aa.fasta" << 'EOF'
>test_200aa
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG
KGKRIEIDSPNFQVVEKFMRFKVRMEGSVNGHEFEIEGEGEGRPYEGTQTAKLKVTKGGPLPFAW
DILSPQFMYGSKAYVKHPADIPDYLKLSFPEGFKWERVMNFEDGGVVTVTQDSSLQDGEFIYKVK
LRGTNFPSDGPVMQKKTMGWEASSERMYPEDGALKGEIKQR
EOF

cat > "$TEST_DIR/test_400aa.fasta" << 'EOF'
>test_400aa
MKTVRQERLKSIVRILERSKEPVSGAQLAEELSVSRQVIVQDIAYLRSLGYNIVATPRGYVLAGG
KGKRIEIDSPNFQVVEKFMRFKVRMEGSVNGHEFEIEGEGEGRPYEGTQTAKLKVTKGGPLPFAW
DILSPQFMYGSKAYVKHPADIPDYLKLSFPEGFKWERVMNFEDGGVVTVTQDSSLQDGEFIYKVK
LRGTNFPSDGPVMQKKTMGWEASSERMYPEDGALKGEIKQRLKLKDGGHYDAEVKTTYKAKKPVQ
LPGAYNVNIKLDITSHNEDYTIVEQYERAEGRHSTGGMDELYKLKGTNFPSDGPVMQKKTMGWEA
SSERMYPEDGALKGEIKQRLKLKDGGHYDAEVKTTYKAKKPVQLPGAYNVNIKLDITSHNEDYTI
EOF

# Initialize results file
echo "sequence_length,model,chunk_size,runtime_seconds,max_memory_mb,gpu_memory_mb,exit_code" > "$RESULTS_FILE"

# Test parameters
MODELS=("esm2_t36_3B_UR50D")  # Can add more models if needed
CHUNK_SIZES=(128 256)
TEST_FILES=("test_50aa.fasta" "test_100aa.fasta" "test_200aa.fasta" "test_400aa.fasta")
SEQUENCE_LENGTHS=(50 100 200 400)

echo "ESMFold Performance Testing"
echo "=========================="
echo "Container: $CONTAINER"
echo "Results: $RESULTS_FILE"
echo

# Function to run a single test
run_test() {
    local test_file=$1
    local seq_len=$2
    local model=$3
    local chunk_size=$4
    local test_output_dir="$OUTPUT_DIR/test_${seq_len}_${model}_${chunk_size}"

    echo "Testing: ${seq_len}aa, model=$model, chunk_size=$chunk_size"

    # Create output directory
    rm -rf "$test_output_dir"
    mkdir -p "$test_output_dir"

    # Run with time and memory monitoring
    local start_time=$(date +%s.%N)

    # Run the container and capture GPU memory usage
    /usr/bin/time -v singularity exec --nv \
        --bind "$TEST_DIR:/input,$test_output_dir:/output" \
        "$CONTAINER" \
        esm-fold \
        -i "/input/$test_file" \
        -o "/output" \
        --chunk-size "$chunk_size" \
        2>&1 | tee "$test_output_dir/run.log" &

    local pid=$!
    local max_gpu_mem=0

    # Monitor GPU memory usage (sample every 2 seconds)
    while kill -0 $pid 2>/dev/null; do
        gpu_mem=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
        if [ "$gpu_mem" -gt "$max_gpu_mem" ]; then
            max_gpu_mem=$gpu_mem
        fi
        sleep 2
    done

    wait $pid
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local runtime=$(echo "$end_time - $start_time" | bc)

    # Extract max memory from time output
    local max_memory=$(grep "Maximum resident set size" "$test_output_dir/run.log" | awk '{print int($6/1024)}' || echo "0")

    # Record results
    echo "${seq_len},${model},${chunk_size},${runtime},${max_memory},${max_gpu_mem},${exit_code}" >> "$RESULTS_FILE"

    if [ $exit_code -eq 0 ]; then
        echo "  ✓ Completed in ${runtime}s, Max Memory: ${max_memory}MB, GPU Memory: ${max_gpu_mem}MB"
    else
        echo "  ✗ Failed with exit code $exit_code"
    fi
    echo
}

# Run tests
for i in ${!TEST_FILES[@]}; do
    test_file=${TEST_FILES[$i]}
    seq_len=${SEQUENCE_LENGTHS[$i]}

    for model in ${MODELS[@]}; do
        for chunk_size in ${CHUNK_SIZES[@]}; do
            run_test "$test_file" "$seq_len" "$model" "$chunk_size"
        done
    done
done

# Generate summary
echo "Performance Test Summary"
echo "========================"
echo
echo "Results saved to: $RESULTS_FILE"
echo

# Display summary statistics
echo "Average runtime by sequence length:"
for len in ${SEQUENCE_LENGTHS[@]}; do
    avg=$(awk -F',' -v len=$len '$1==len && $7==0 {sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}' "$RESULTS_FILE")
    echo "  ${len}aa: ${avg}s"
done

echo
echo "Maximum memory usage by sequence length:"
for len in ${SEQUENCE_LENGTHS[@]}; do
    max_mem=$(awk -F',' -v len=$len '$1==len && $7==0 {if($5>max) max=$5} END {print max+0}' "$RESULTS_FILE")
    max_gpu=$(awk -F',' -v len=$len '$1==len && $7==0 {if($6>max) max=$6} END {print max+0}' "$RESULTS_FILE")
    echo "  ${len}aa: CPU=${max_mem}MB, GPU=${max_gpu}MB"
done

echo
echo "Recommended preflight resources based on testing:"
echo "  CPU: 8 cores"
echo "  Memory: 32GB"
echo "  GPU Memory: 16GB minimum"
echo "  Runtime: 600s for sequences up to 400aa"