"""Windows tests for the old Codex release cleanup of bin/codexu-prune.ps1.

Run: python -m unittest discover -s tests -p test_codexu_prune.py -v
Each test builds a disposable Codex home with fake releases: no Codex runs,
and the real %USERPROFILE%\\.codex is never read.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

if os.name == "nt":
    import _winapi


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "codexu-prune.ps1"
BAT = ROOT / "bin" / "codexu.bat"
SUFFIX = "-x86_64-pc-windows-msvc"
TWO_DAYS = 2 * 24 * 3600


@unittest.skipUnless(os.name == "nt", "Requires Windows PowerShell")
class CodexuPruneTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senv-codexu-")
        self.addCleanup(self.temp.cleanup)
        # TEMP can be an 8.3 short path, while PowerShell prints long names.
        self.home = Path(self.temp.name).resolve()

    def release(self, kind, version, name=None):
        folder = self.home / "packages" / kind / "releases" / (name or version + SUFFIX)
        (folder / "bin").mkdir(parents=True)
        (folder / "bin" / "codex.exe").write_bytes(b"MZ")
        if version:
            (folder / "codex-package.json").write_text(json.dumps({"version": version}), encoding="utf-8")
        return folder

    def current(self, kind, folder):
        link = self.home / "packages" / kind / "current"
        _winapi.CreateJunction(str(folder), str(link))
        # TemporaryDirectory's cleanup would follow the junction otherwise.
        self.addCleanup(os.rmdir, link)

    def leftover(self, name, age=0):
        folder = self.home / "packages" / "standalone" / "releases" / name
        folder.mkdir(parents=True)
        (folder / "part").write_bytes(b"x")
        stamp = time.time() - age
        os.utime(folder, (stamp, stamp))
        return folder

    def prune(self, *args):
        command = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
            "-CodexHome", str(self.home), *args,
        ]
        return subprocess.run(command, capture_output=True, encoding="utf-8", timeout=60)

    def codexu(self, *args):
        env = dict(os.environ, CODEX_HOME=str(self.home), NO_COLOR="1")
        return subprocess.run(
            ["cmd", "/d", "/c", str(BAT), *args],
            capture_output=True, encoding="utf-8", errors="replace", env=env, timeout=60,
        )

    def test_keeps_the_two_newest_current_in_use_and_unknown(self):
        newest = self.release("standalone", "0.101.0")
        alpha = self.release("standalone", "0.101.0-alpha.1")
        older = self.release("standalone", "0.100.0")
        lexically_newest = self.release("standalone", "0.99.0")
        pointed = self.release("standalone", "0.98.0")
        busy = self.release("standalone", "0.97.0")
        oldest = self.release("standalone", "0.96.0")
        unknown = self.release("standalone", None, name="manual")
        self.current("standalone", pointed)
        stale = self.leftover(".staging.0.95.0" + SUFFIX + ".1", age=TWO_DAYS)
        fresh = self.leftover(".staging.0.102.0" + SUFFIX + ".2")
        half_removed = self.leftover(".prune.0.90.0" + SUFFIX)
        daemon_new = self.release("app-server-daemon", "0.101.0", name="local-aaa" + SUFFIX)
        daemon_mid = self.release("app-server-daemon", "0.100.0", name="local-bbb" + SUFFIX)
        daemon_old = self.release("app-server-daemon", "0.99.0", name="local-ccc" + SUFFIX)
        self.current("app-server-daemon", daemon_new)

        # A running codex.exe cannot be opened for exclusive access either.
        with open(busy / "bin" / "codex.exe", "rb"):
            result = self.prune()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for kept in (newest, alpha, pointed, busy, unknown, fresh, daemon_new, daemon_mid):
            self.assertTrue(kept.is_dir(), f"{kept.name} was removed\n{result.stdout}")
        for gone in (older, lexically_newest, oldest, stale, half_removed, daemon_old):
            self.assertFalse(gone.exists(), f"{gone.name} was kept\n{result.stdout}")
        prunes = list((self.home / "packages" / "standalone" / "releases").glob(".prune.*"))
        self.assertEqual(prunes, [])
        self.assertIn("keep standalone 0.98.0, 'current' points to it", result.stdout)
        self.assertIn("keep standalone 0.97.0, in use:", result.stdout)
        self.assertIn("removed standalone 0.96.0", result.stdout)
        self.assertIn("removed app-server-daemon 0.99.0", result.stdout)

    def test_dry_run_lists_and_removes_nothing(self):
        self.release("standalone", "0.3.0")
        self.release("standalone", "0.2.0")
        old = self.release("standalone", "0.1.0")

        result = self.prune("-DryRun")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(old.is_dir())
        self.assertIn("would remove standalone 0.1.0", result.stdout)
        self.assertIn("would free", result.stdout)

    def test_codexu_dry_prune_skips_the_update_steps(self):
        self.release("standalone", "0.3.0")
        self.release("standalone", "0.2.0")
        old = self.release("standalone", "0.1.0")

        result = self.codexu("dry", "prune")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(old.is_dir())
        self.assertIn("would remove standalone 0.1.0", result.stdout)
        self.assertNotIn("install.ps1", result.stdout)

    def test_codexu_prune_removes_old_releases_without_updating(self):
        kept = self.release("standalone", "0.3.0")
        self.release("standalone", "0.2.0")
        old = self.release("standalone", "0.1.0")

        result = self.codexu("prune")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(kept.is_dir())
        self.assertFalse(old.exists(), result.stdout)
        self.assertIn("removed standalone 0.1.0", result.stdout)
        self.assertIn("codexu finished", result.stdout)
        self.assertNotIn("ensure_internet", result.stdout)


if __name__ == "__main__":
    unittest.main()
