"""Windows tests of the archive that dwl names, div checks and inst_prg picks.

Run: python -m unittest discover -s tests -p test_dwl_archive.py -v

On 2026-11-08, `dwl node 22` resolved Node 22.23.4, downloaded nothing and
exited 0; `div node 22` then reported a download and kept the node22 junction
on 22.9.0. bin/dwl.bat now names in dwl_file the archive it leaves in
%PRGS%\\setup, dwl_inst_ver.bat (div) stops when that archive is missing, and
inst_prg.bat takes the highest archive of a Node release line.

Each test runs the shipped batch file in a temporary sandbox: the real
batcolors, and stubs for the network check, the program picker and the
install, so no test downloads or installs anything.
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CMD = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "cmd.exe"


def write_batch(path: Path, *lines: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))
    return path


def run_cmd(command: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    """Run one cmd line with delayed expansion, stdin from NUL as agents run it."""
    return subprocess.run(f'"{CMD}" /d /v:on /c "{command}"', capture_output=True, text=True,
                          encoding="oem", errors="replace", timeout=30, env=env,
                          stdin=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)


class Sandbox:
    """A senv tree (bin, batcolors), a PRGS with its setup folder, a HOME."""

    def __init__(self, test: unittest.TestCase):
        temp = tempfile.TemporaryDirectory(prefix="senv-dwl-archive-")
        test.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "senv" / "bin"
        self.bin.mkdir(parents=True)
        shutil.copytree(ROOT / "batcolors", self.root / "senv" / "batcolors",
                        ignore=shutil.ignore_patterns(".git", ".vscode", "*.png"))
        self.prgs = self.root / "prgs"
        self.setup = self.prgs / "setup"
        self.setup.mkdir(parents=True)
        self.home = self.root / "home"
        (self.home / "bin").mkdir(parents=True)
        self.env = {name: value for name, value in os.environ.items()
                    if name.upper() not in {"FATALNOEXIT", "DWL_FILE", "SCRIPT_DIR"}}
        self.env.update(PRGS=str(self.prgs), HOME=str(self.home), NOCOLORS="1")

    def ship(self, relative: str) -> Path:
        """Copy a shipped file byte for byte: an LF copy must fail here too."""
        target = self.root / "senv" / relative
        shutil.copyfile(ROOT / relative, target)
        return target


@unittest.skipUnless(os.name == "nt", "Requires cmd.exe")
class DwlNamesItsArchiveTest(unittest.TestCase):
    """The real dwl.bat; test_batch_line_endings.py guards its label lookups."""

    ARCHIVE = "node-v22.23.4-win-x64.zip"

    def setUp(self):
        self.box = Sandbox(self)
        self.dwl = self.box.ship("bin/dwl.bat")
        write_batch(self.box.bin / "ensure_internet.bat", "@exit /b 0")
        write_batch(self.box.bin / "select_prg.bat", "@echo off",
                    'set "prg_id=%~1"', 'set "prg_version=%~2"')
        gum = self.box.prgs / "gums" / "current" / "gum.exe"
        gum.parent.mkdir(parents=True)
        gum.write_bytes(b"")

    def test_node_reaches_curl_and_names_the_archive(self):
        # The exact version skips the nodejs.org release list. A section that
        # stops before :curl leaves no name. Whether an LF-only dwl.bat misses
        # a label depends on byte offsets: test_batch_line_endings.py checks
        # the line endings themselves.
        (self.box.setup / self.ARCHIVE).write_bytes(b"")
        result = run_cmd(f'call "{self.dwl}" node 22.23.4 '
                         f'& echo EXIT=!errorlevel! DWL_FILE=[!dwl_file!]', self.box.env)
        output = result.stdout + result.stderr
        self.assertIn(f"EXIT=0 DWL_FILE=[{self.ARCHIVE}]", output, output)


@unittest.skipUnless(os.name == "nt", "Requires cmd.exe")
class DivChecksTheArchiveTest(unittest.TestCase):
    """dwl_inst_ver.bat with a stub dwl.bat and a stub inst_prg.bat."""

    ARCHIVE = "node-v22.23.4-win-x64.zip"

    def setUp(self):
        self.box = Sandbox(self)
        self.div = self.box.ship("bin/dwl_inst_ver.bat")
        write_batch(self.box.bin / "dwl.bat", "@echo off", "echo STUB-DWL %*",
                    'if defined STUB_DWL_FILE set "dwl_file=%STUB_DWL_FILE%"', "exit /b 0")
        write_batch(self.box.home / "bin" / "inst_prg.bat", "@echo off", "echo STUB-INST %*",
                    "exit /b 0")

    def div_node_22(self, named: str | None) -> tuple[subprocess.CompletedProcess[str], str]:
        env = dict(self.box.env)
        env.pop("STUB_DWL_FILE", None)
        if named:
            env["STUB_DWL_FILE"] = named
        result = run_cmd(f'call "{self.div}" node 22', env)
        return result, result.stdout + result.stderr

    def test_installs_once_the_named_archive_is_in_setup(self):
        (self.box.setup / self.ARCHIVE).write_bytes(b"")
        result, output = self.div_node_22(self.ARCHIVE)
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("STUB-INST node 22", output)
        self.assertIn(f"downloaded: '{self.ARCHIVE}'", output)

    def test_stops_before_the_install_when_the_named_archive_is_missing(self):
        # An older match, as node-v22.9.0 on 2026-11-08, must not be installed.
        (self.box.setup / "node-v22.9.0-win-x64.zip").write_bytes(b"")
        result, output = self.div_node_22(self.ARCHIVE)
        self.assertNotEqual(result.returncode, 0, output)
        self.assertIn(f"'{self.ARCHIVE}' is missing from", output)
        self.assertNotIn("STUB-INST", output)

    def test_stops_before_the_install_when_dwl_names_no_archive(self):
        result, output = self.div_node_22(None)
        self.assertNotEqual(result.returncode, 0, output)
        self.assertIn("dwl named no archive", output)
        self.assertNotIn("STUB-INST", output)


@unittest.skipUnless(os.name == "nt", "Requires cmd.exe")
class InstPrgNodeReleaseLineTest(unittest.TestCase):
    """The :node_release_line label of inst_prg.bat, run on its own."""

    GENERIC = "node-v*22*-win-x64.zip"

    def setUp(self):
        text = (ROOT / "bin" / "inst_prg.bat").read_bytes().decode("ascii").replace("\r\n", "\n")
        start = text.index("\n:node_release_line\n") + 1
        label = text[start:text.index("\ngoto:eof\n", start) + len("\ngoto:eof")]
        temp = tempfile.TemporaryDirectory(prefix="senv-node-line-")
        self.addCleanup(temp.cleanup)
        self.batch = write_batch(Path(temp.name) / "node_line.bat", "@echo off",
                                 "setlocal enabledelayedexpansion", 'set "_info=rem"',
                                 f'set "prg_pattern={self.GENERIC}"',
                                 'call:node_release_line "%~1"',
                                 "echo %~1=[!prg_pattern!] EXIT=!errorlevel!", "goto:eof",
                                 *label.split("\n"))

    def test_only_a_major_takes_the_highest_archive_of_its_line(self):
        # One cmd for the four inputs: each call starts from the generic pattern.
        versions = ("22", "22.23.4", "latest", "")
        command = " & ".join(f'call "{self.batch}" "{version}"' for version in versions)
        result = run_cmd(command, dict(os.environ))
        self.assertEqual(result.stdout.split(), [
            "22=[node-v22.*-win-x64.zip-latest]", "EXIT=0",
            f"22.23.4=[{self.GENERIC}]", "EXIT=0",
            f"latest=[{self.GENERIC}]", "EXIT=0",
            f"=[{self.GENERIC}]", "EXIT=0",
        ], result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
