"""Tests for the non-destructive venv scaffold repair helper."""

from __future__ import annotations

import sys
import tempfile
import unittest
import venv
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

import repair_venv_scaffold  # noqa: E402


class RepairVenvScaffoldTests(unittest.TestCase):
    """Check complete, partial, and failed scaffold repairs."""

    def test_restores_activation_without_replacing_python(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            env_dir = Path(temporary_dir) / "env"
            venv.EnvBuilder(with_pip=False).create(env_dir)
            config, python, activation = repair_venv_scaffold.required_paths(env_dir)
            python_before = python.read_bytes()
            activation.unlink()

            repaired = repair_venv_scaffold.repair_scaffold(env_dir)

            self.assertEqual(repaired, (activation,))
            self.assertTrue(config.is_file())
            self.assertTrue(activation.is_file())
            self.assertEqual(python.read_bytes(), python_before)

    def test_creates_a_missing_scaffold_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            env_dir = Path(temporary_dir) / "env"

            repaired = repair_venv_scaffold.repair_scaffold(env_dir)

            required = repair_venv_scaffold.required_paths(env_dir)
            self.assertEqual(repaired, required)
            self.assertTrue(all(path.is_file() for path in required))
            self.assertEqual(repair_venv_scaffold.repair_scaffold(env_dir), ())

    def test_reports_missing_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            with mock.patch.object(venv.EnvBuilder, "setup_scripts", return_value=None):
                with self.assertRaisesRegex(
                    repair_venv_scaffold.VenvScaffoldError,
                    "activate",
                ):
                    repair_venv_scaffold.repair_scaffold(
                        Path(temporary_dir) / "env"
                    )


if __name__ == "__main__":
    unittest.main()
