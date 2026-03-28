cwlVersion: v1.2
class: CommandLineTool

doc: |
  ESMFold protein structure prediction using Meta's ESM model.
  Predicts 3D structure from amino acid sequences.

label: "ESMFold Protein Structure Prediction"

baseCommand: [esm-fold-hf]

requirements:
  DockerRequirement:
    dockerPull: "dxkb/esmfold-bvbrc:latest-gpu"
  ResourceRequirement:
    coresMin: 4
    coresMax: 16
    ramMin: 16384    # 16GB minimum
    ramMax: 65536    # 64GB maximum
  InitialWorkDirRequirement:
    listing:
      - $(inputs.sequences)

inputs:
  sequences:
    type: File
    inputBinding:
      prefix: -i
      position: 1
    doc: "FASTA file containing protein sequences"
    format: "edam:format_1929"  # FASTA
    
  output_dir:
    type: string
    inputBinding:
      prefix: -o
      position: 2
    default: "structures"
    doc: "Output directory for PDB structure files"
    
  num_recycles:
    type: int?
    inputBinding:
      prefix: --num-recycles
      position: 3
    default: 4
    doc: "Number of recycles to run (default: 4, max: 4)"
    
  chunk_size:
    type: int?
    inputBinding:
      prefix: --chunk-size
      position: 4
    default: 128
    doc: "Chunk size for processing (affects memory usage)"
    
  max_tokens_per_batch:
    type: int?
    inputBinding:
      prefix: --max-tokens-per-batch
      position: 5
    default: 1024
    doc: "Maximum tokens per batch (for batching shorter sequences)"
    
  cpu_only:
    type: boolean?
    inputBinding:
      prefix: --cpu-only
      position: 6
    doc: "Run on CPU only (no GPU)"
    default: false

outputs:
  structures:
    type: Directory
    outputBinding:
      glob: $(inputs.output_dir)
    doc: "Directory containing PDB structure files"
    
  log:
    type: stdout
    doc: "Processing log"
    
stderr: esmfold.err
stdout: esmfold.log

$namespaces:
  edam: http://edamontology.org/

$schemas:
  - http://edamontology.org/EDAM_1.25.owl