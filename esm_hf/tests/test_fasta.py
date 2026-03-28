"""Tests for FASTA reading and batching logic (pure functions, no model)."""

from scripts.esmfold_hf import read_fasta, create_batched_sequences


class TestReadFasta:

    def test_single_sequence(self, sample_fasta):
        seqs = read_fasta(sample_fasta)
        assert len(seqs) == 1
        assert seqs[0][0] == "1CRN"
        assert seqs[0][1] == "TTCCPSIVARSNFNVCRLPGTPEALCATYTGCIIIPGATCPGDYAN"

    def test_multi_sequence(self, multi_seq_fasta):
        seqs = read_fasta(multi_seq_fasta)
        assert len(seqs) == 2
        assert seqs[0][0] == "seq1"
        assert seqs[1][0] == "seq2"

    def test_empty_file(self, tmp_path):
        fasta = tmp_path / "empty.fasta"
        fasta.write_text("")
        seqs = read_fasta(fasta)
        assert seqs == []

    def test_multiline_sequence(self, tmp_path):
        fasta = tmp_path / "multiline.fasta"
        fasta.write_text(">test\nMKTIIALS\nYIFCLVFA\n")
        seqs = read_fasta(fasta)
        assert len(seqs) == 1
        assert seqs[0][1] == "MKTIIALSYIFCLVFA"

    def test_header_first_word(self, tmp_path):
        fasta = tmp_path / "header.fasta"
        fasta.write_text(">1CRN|Crambin|46 residues\nTTCCPS\n")
        seqs = read_fasta(fasta)
        assert seqs[0][0] == "1CRN|Crambin|46"


class TestCreateBatchedSequences:

    def test_single_batch(self):
        sequences = [("s1", "MKT"), ("s2", "GIV")]
        batches = list(create_batched_sequences(sequences, max_tokens_per_batch=100))
        assert len(batches) == 1
        assert batches[0][0] == ["s1", "s2"]

    def test_split_across_batches(self):
        sequences = [("s1", "A" * 50), ("s2", "B" * 50), ("s3", "C" * 50)]
        batches = list(create_batched_sequences(sequences, max_tokens_per_batch=80))
        assert len(batches) >= 2

    def test_exact_boundary(self):
        sequences = [("s1", "A" * 50), ("s2", "B" * 50)]
        batches = list(create_batched_sequences(sequences, max_tokens_per_batch=100))
        assert len(batches) == 1
        assert batches[0][0] == ["s1", "s2"]

    def test_empty_input(self):
        batches = list(create_batched_sequences([], max_tokens_per_batch=100))
        assert batches == []

    def test_single_long_sequence(self):
        sequences = [("s1", "A" * 200)]
        batches = list(create_batched_sequences(sequences, max_tokens_per_batch=100))
        assert len(batches) == 1
        assert batches[0][0] == ["s1"]
