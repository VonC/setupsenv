"""Windows tests for the latest archive pick of bin/dir_by_date.ps1.

Run: python -m unittest discover -s tests -p test_dir_by_date.py -v
Each test works on disposable archives in a temporary folder.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "dir_by_date.ps1"
PATTERN = "tuios_*_Windows_x86_64.tar.gz"


@unittest.skipUnless(os.name == "nt", "Requires Windows PowerShell")
class DirByDateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senv-dir-by-date-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)

    def archive(self, version, created):
        path = self.folder / ("tuios_" + version + "_Windows_x86_64.tar.gz")
        path.write_bytes(b"")
        literal = str(path).replace("'", "''")
        result = subprocess.run([
            "powershell", "-NoProfile", "-Command",
            "(Get-Item -LiteralPath '" + literal + "').CreationTime = [datetime]'" + created + "'",
        ], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return path.name

    def latest(self, existing=None):
        command = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
            str(self.folder), PATTERN,
        ]
        if existing is not None:
            command.append(existing)
        return subprocess.run(command, capture_output=True, text=True, timeout=30)

    def test_higher_version_wins_over_a_later_download(self):
        newer = self.archive("0.10.1", "2026-10-18 19:15:38")
        self.archive("0.10.0", "2026-10-18 19:15:56")
        result = self.latest()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "20261018-1915 " + newer)

    def test_versions_compare_in_natural_order(self):
        self.archive("0.9.5", "2026-10-18 20:00:00")
        newer = self.archive("0.10.0", "2026-10-18 19:00:00")
        self.assertEqual(self.latest().stdout.strip(), "20261018-1900 " + newer)

    def test_higher_version_from_an_earlier_folder_is_kept(self):
        self.archive("0.10.0", "2026-10-19 08:00:00")
        existing = "20261001-1200 tuios_0.10.1_Windows_x86_64.tar.gz"
        self.assertEqual(self.latest(existing).stdout.strip(), existing)

    def test_higher_version_replaces_an_earlier_folder_pick(self):
        newer = self.archive("0.10.1", "2026-10-01 12:00:00")
        existing = "20261019-0800 tuios_0.10.0_Windows_x86_64.tar.gz"
        self.assertEqual(self.latest(existing).stdout.strip(), "20261001-1200 " + newer)

    def test_same_version_keeps_the_newer_copy(self):
        name = self.archive("0.10.1", "2026-10-18 19:15:38")
        older = "20261001-1200 " + name
        newer = "20261019-0800 " + name
        self.assertEqual(self.latest(older).stdout.strip(), "20261018-1915 " + name)
        self.assertEqual(self.latest(newer).stdout.strip(), newer)

    def test_no_match_exits_with_one(self):
        result = self.latest()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
