"""Tests for PDB output conversion.

These tests mock the model output tensors to avoid needing GPU or model download.
They verify the convert_outputs_to_pdb function handles tensor shapes correctly.
"""

from unittest.mock import patch, MagicMock

import pytest

try:
    import torch
    HAS_TORCH = True
except ImportError:
    HAS_TORCH = False

pytestmark = pytest.mark.skipif(not HAS_TORCH, reason="torch not installed")


def _make_mock_outputs(batch_size=1, seq_len=10, num_recycles=4):
    """Create mock tensors mimicking EsmForProteinFolding output shape.

    Returns a dict with the same keys as the real model output, but with
    random data. We mock atom14_to_atom37 and to_pdb to avoid needing
    the actual openfold utilities to work on the random data.
    """
    outputs = {
        "positions": torch.randn(num_recycles, batch_size, seq_len, 14, 3),
        "aatype": torch.zeros(batch_size, seq_len, dtype=torch.long),
        "atom37_atom_exists": torch.ones(batch_size, seq_len, 37),
        "residue_index": torch.arange(seq_len).unsqueeze(0).expand(batch_size, -1),
        "plddt": torch.rand(batch_size, seq_len) * 0.5 + 0.5,  # 0.5-1.0 range
    }
    return outputs


class TestConvertOutputsToPdb:

    @patch("scripts.esmfold_hf.to_pdb")
    @patch("scripts.esmfold_hf.atom14_to_atom37")
    def test_returns_list_of_strings(self, mock_a14, mock_to_pdb):
        from scripts.esmfold_hf import convert_outputs_to_pdb

        outputs = _make_mock_outputs(batch_size=1, seq_len=5)

        # Mock atom14_to_atom37 to return plausible atom37 positions
        mock_a14.return_value = torch.randn(1, 5, 37, 3)

        # Mock to_pdb to return a PDB string
        mock_to_pdb.return_value = "ATOM      1  N   ALA A   1\nEND\n"

        pdbs = convert_outputs_to_pdb(outputs)

        assert isinstance(pdbs, list)
        assert len(pdbs) == 1
        assert "ATOM" in pdbs[0]

    @patch("scripts.esmfold_hf.to_pdb")
    @patch("scripts.esmfold_hf.atom14_to_atom37")
    def test_batch_size_two(self, mock_a14, mock_to_pdb):
        from scripts.esmfold_hf import convert_outputs_to_pdb

        outputs = _make_mock_outputs(batch_size=2, seq_len=5)

        mock_a14.return_value = torch.randn(2, 5, 37, 3)
        mock_to_pdb.return_value = "ATOM      1  N   ALA A   1\nEND\n"

        pdbs = convert_outputs_to_pdb(outputs)

        assert len(pdbs) == 2
        assert mock_to_pdb.call_count == 2

    @patch("scripts.esmfold_hf.to_pdb")
    @patch("scripts.esmfold_hf.atom14_to_atom37")
    def test_plddt_passed_as_bfactors(self, mock_a14, mock_to_pdb):
        from scripts.esmfold_hf import convert_outputs_to_pdb

        outputs = _make_mock_outputs(batch_size=1, seq_len=5)
        mock_a14.return_value = torch.randn(1, 5, 37, 3)
        mock_to_pdb.return_value = "ATOM\nEND\n"

        convert_outputs_to_pdb(outputs)

        # Verify to_pdb was called with a Protein object that has b_factors
        call_args = mock_to_pdb.call_args
        protein = call_args[0][0]
        assert protein.b_factors is not None
        assert protein.b_factors.shape == (5,)

    @patch("scripts.esmfold_hf.to_pdb")
    @patch("scripts.esmfold_hf.atom14_to_atom37")
    def test_chain_index_passed_when_present(self, mock_a14, mock_to_pdb):
        from scripts.esmfold_hf import convert_outputs_to_pdb

        outputs = _make_mock_outputs(batch_size=1, seq_len=5)
        outputs["chain_index"] = torch.zeros(1, 5, dtype=torch.long)

        mock_a14.return_value = torch.randn(1, 5, 37, 3)
        mock_to_pdb.return_value = "ATOM\nEND\n"

        convert_outputs_to_pdb(outputs)

        protein = mock_to_pdb.call_args[0][0]
        assert protein.chain_index is not None
