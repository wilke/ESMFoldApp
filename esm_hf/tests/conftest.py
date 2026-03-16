"""Shared test fixtures for esm_hf tests."""

from pathlib import Path

import pytest


@pytest.fixture
def sample_fasta(tmp_path):
    """Create a single-sequence FASTA file (crambin, 46 residues)."""
    fasta = tmp_path / "test.fasta"
    fasta.write_text(">1CRN\nTTCCPSIVARSNFNVCRLPGTPEALCATYTGCIIIPGATCPGDYAN\n")
    return fasta


@pytest.fixture
def multi_seq_fasta(tmp_path):
    """Create a multi-sequence FASTA file for batching tests."""
    fasta = tmp_path / "multi.fasta"
    fasta.write_text(
        ">seq1\nMKTIIALSYIFCLVFA\n"
        ">seq2\nGIVLAAVLLLLVAGSS\n"
    )
    return fasta
