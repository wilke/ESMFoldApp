#!/usr/bin/env python3
"""
ESMFold command-line wrapper
Provides a simple interface to run ESMFold predictions
"""

import argparse
import os
import sys
from pathlib import Path
import torch
import esm
from Bio import SeqIO


def main():
    parser = argparse.ArgumentParser(description='ESMFold protein structure prediction')
    parser.add_argument('-i', '--input', required=True, help='Input FASTA file')
    parser.add_argument('-o', '--output', required=True, help='Output directory')
    parser.add_argument('--num-recycles', type=int, default=4, help='Number of recycles (0-4)')
    parser.add_argument('--chunk-size', type=int, default=128, help='Chunk size')
    parser.add_argument('--cpu-only', action='store_true', help='Use CPU only')
    parser.add_argument('--cpu-offload', action='store_true', help='Enable CPU offloading')
    parser.add_argument('--max-tokens-per-batch', type=int, default=1024, help='Max tokens per batch')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Set device
    if args.cpu_only or not torch.cuda.is_available():
        device = 'cpu'
        print(f"Using CPU for inference")
    else:
        device = 'cuda'
        print(f"Using GPU for inference")
    
    # Load model
    print("Loading ESMFold model...")
    model = esm.pretrained.esmfold_v1()
    model = model.eval()
    
    if device == 'cuda':
        model = model.cuda()
        print("Model loaded on GPU")
    else:
        print("Model loaded on CPU")
    
    # Process sequences
    print(f"Processing sequences from {args.input}")
    for record in SeqIO.parse(args.input, "fasta"):
        seq_id = record.id
        sequence = str(record.seq)
        
        print(f"Folding {seq_id} ({len(sequence)} residues)...")
        
        with torch.no_grad():
            # Set number of recycles
            if hasattr(model, 'set_chunk_size'):
                model.set_chunk_size(args.chunk_size)
            
            # Run prediction
            output = model.infer_pdb(sequence)
        
        # Save PDB
        output_file = output_dir / f"{seq_id}.pdb"
        with open(output_file, 'w') as f:
            f.write(output)
        
        print(f"  Saved to {output_file}")
    
    print("Done!")


if __name__ == '__main__':
    main()