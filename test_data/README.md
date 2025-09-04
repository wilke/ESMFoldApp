# ESMFold Test Data

This directory contains test protein sequences for validating the ESMFold service.

## Test Files

### test_proteins.fasta
Contains multiple protein sequences of varying lengths:
- **Hemoglobin subunit alpha (HBA_HUMAN)**: 141 amino acids
- **Superoxide dismutase (SOD1_HUMAN)**: 153 amino acids  
- **Serum albumin fragment (ALBU_BOVIN)**: 583 amino acids (longer sequence)
- **Lysozyme C (LYSC_CHICK)**: 129 amino acids
- **Test short peptide**: 117 amino acids

### single_protein.fasta
Contains a single ubiquitin sequence (76 amino acids) for quick testing.

## Usage

These test files can be used to:
1. Validate the ESMFold container build
2. Test the service script functionality
3. Benchmark performance with different sequence lengths
4. Verify PDB output generation

## Expected Results

When processed through ESMFold, each sequence should produce:
- A PDB structure file named after the sequence ID
- Successful folding for all sequences (they are all valid proteins)
- Varying processing times based on sequence length

## Performance Notes

- Short sequences (<100 aa): ~10-30 seconds
- Medium sequences (100-200 aa): ~30-60 seconds
- Long sequences (>500 aa): ~2-5 minutes
- Times may vary based on GPU availability and model caching