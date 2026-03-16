"""Tests for CLI argument parsing (no model loading, no GPU needed)."""

import pytest

from scripts.esmfold_hf import create_parser


class TestCreateParser:
    """Test argparse configuration via create_parser()."""

    def test_defaults(self, tmp_path):
        fasta = tmp_path / "input.fasta"
        fasta.write_text(">seq\nMKT\n")
        out = tmp_path / "out"

        parser = create_parser()
        args = parser.parse_args(["-i", str(fasta), "-o", str(out)])

        assert args.model_name == "facebook/esmfold_v1"
        assert args.max_tokens_per_batch == 1024
        assert args.num_recycles == 4
        assert args.chunk_size is None
        assert args.cpu_only is False
        assert args.fp16 is False

    def test_custom_args(self, tmp_path):
        fasta = tmp_path / "input.fasta"
        fasta.write_text(">seq\nMKT\n")

        parser = create_parser()
        args = parser.parse_args([
            "-i", str(fasta),
            "-o", "out/",
            "--num-recycles", "8",
            "--cpu-only",
            "--fp16",
            "--chunk-size", "64",
        ])

        assert args.num_recycles == 8
        assert args.cpu_only is True
        assert args.fp16 is True
        assert args.chunk_size == 64

    def test_required_input(self):
        parser = create_parser()
        with pytest.raises(SystemExit):
            parser.parse_args(["-o", "out/"])

    def test_required_output(self, tmp_path):
        fasta = tmp_path / "input.fasta"
        fasta.write_text(">seq\nMKT\n")

        parser = create_parser()
        with pytest.raises(SystemExit):
            parser.parse_args(["-i", str(fasta)])

    def test_num_recycles_zero(self, tmp_path):
        fasta = tmp_path / "input.fasta"
        fasta.write_text(">seq\nMKT\n")

        parser = create_parser()
        args = parser.parse_args(["-i", str(fasta), "-o", "out/", "--num-recycles", "0"])
        assert args.num_recycles == 0

    def test_num_recycles_high(self, tmp_path):
        fasta = tmp_path / "input.fasta"
        fasta.write_text(">seq\nMKT\n")

        parser = create_parser()
        args = parser.parse_args(["-i", str(fasta), "-o", "out/", "--num-recycles", "48"])
        assert args.num_recycles == 48
