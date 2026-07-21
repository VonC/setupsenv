"""Structural tests for switchpy's local-project venv workflow."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SWITCHPY = (ROOT / "bin" / "switchpy.bat").read_text(encoding="utf-8")


class SwitchpyStructureTests(unittest.TestCase):
    """Check repair, dependency selection, and public state behavior."""

    def test_repairs_before_activation(self) -> None:
        repair = 'call :repair_venv_scaffold "%PYTHON_VENVS%\\%venv_name%"'
        activate = 'call "%PYTHON_VENVS%\\%venv_name%\\Scripts\\activate.bat"'

        self.assertIn('call :repair_venv_scaffold "%VIRTUAL_ENV%"', SWITCHPY)
        self.assertLess(SWITCHPY.index(repair), SWITCHPY.index(activate))
        self.assertIn('bin\\repair_venv_scaffold.py" "%repair_venv_dir%"', SWITCHPY)

    def test_selects_requirements_or_uv_project_sync(self) -> None:
        dependency_sync = SWITCHPY[SWITCHPY.index("\n:sync_project_dependencies\n") :]

        self.assertIn("-m ensurepip --upgrade", dependency_sync)
        self.assertIn("-m pip install --upgrade pip", dependency_sync)
        self.assertIn('for %%r in ("%ccd%\\requirements*.txt")', dependency_sync)
        self.assertIn('-m pip install -r "%%~fr"', dependency_sync)
        self.assertIn("-m pip install --upgrade --force-reinstall uv", dependency_sync)
        self.assertIn("sync --frozen --all-groups", dependency_sync)
        self.assertIn("sync --all-groups", dependency_sync)

    def test_keeps_documented_python_state(self) -> None:
        unset = SWITCHPY[
            SWITCHPY.index("\n:unset\n") : SWITCHPY.index("\n:call_echos_stack\n")
        ]

        self.assertNotIn('set "PYTHON_HOME="', unset)
        self.assertNotIn('set "PYTHON_VERSION="', unset)
        self.assertNotIn('set "PYTHON_ROOT="', unset)


if __name__ == "__main__":
    unittest.main()
