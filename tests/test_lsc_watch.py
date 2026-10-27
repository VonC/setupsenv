"""Windows tests for the tray watcher of `lsc watch`.

Run: python -m unittest discover -s tests -p test_lsc_watch.py -v
Each test starts its own watcher instance on a temporary folder, with its log
under a temporary LOCALAPPDATA and the clipboard left alone, then stops it.
A tray icon shows for the few seconds each test runs.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "last-screenshots.ps1"


@unittest.skipUnless(os.name == "nt", "Requires Windows PowerShell")
class LscWatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senv-lsc-watch-")
        self.addCleanup(self.temp.cleanup)
        # TEMP can be an 8.3 short path, while PowerShell prints long names.
        self.root = Path(self.temp.name).resolve()
        self.folder = self.root / "Captures d’écran"
        self.folder.mkdir()
        self.ini = self.root / "lsc.custom.ini"
        self.ini.write_text("[screenshots]\nfolder = " + str(self.folder) + "\n", encoding="utf-8")
        self.instance = "senv-lsc-test-" + uuid.uuid4().hex[:8]
        self.env = dict(os.environ, LOCALAPPDATA=str(self.root))
        self.addCleanup(self.lsc, "stop")

    def lsc(self, *args, ini=None):
        command = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
            *args, "-Ini", str(ini or self.ini), "-Instance", self.instance, "-NoClipboard",
        ]
        return subprocess.run(
            command, capture_output=True, encoding="utf-8", timeout=60, env=self.env,
        )

    def log(self):
        path = self.root / "senv" / (self.instance + ".log")
        return path.read_text(encoding="utf-8-sig") if path.exists() else ""

    def wait_for_log(self, text, seconds=10):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if text in self.log():
                return True
            time.sleep(0.2)
        return False

    def start(self):
        result = self.lsc("watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("lsc: watching '" + str(self.folder) + "'", result.stdout)
        return result

    def test_watch_returns_and_stop_ends_the_watcher(self):
        started = time.monotonic()
        self.start()
        self.assertLess(time.monotonic() - started, 15)
        self.assertIn("the watcher runs", self.lsc("status").stdout)

        result = self.lsc("stop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("lsc: watcher stopped", result.stdout)
        self.assertIn("no watcher runs", self.lsc("status").stdout)
        self.assertIn("stop requested", self.log())
        self.assertIn("stopped", self.log())

    def test_a_new_image_path_is_copied(self):
        self.start()
        (self.folder / "notes.txt").write_text("not an image", encoding="utf-8")
        shot = self.folder / "Capture d'écran 2026-10-27 090000.png"
        shot.write_bytes(b"\x89PNG" + bytes(200))
        self.assertTrue(self.wait_for_log('copied "' + str(shot) + '"'), self.log())
        self.assertNotIn("notes.txt", self.log())

    def test_an_image_renamed_into_place_is_copied(self):
        self.start()
        partial = self.folder / "capture.tmp"
        partial.write_bytes(bytes(100))
        shot = self.folder / "capture.PNG"
        partial.rename(shot)
        self.assertTrue(self.wait_for_log('copied "' + str(shot) + '"'), self.log())

    def test_a_second_watch_keeps_the_running_watcher(self):
        self.start()
        result = self.lsc("watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("the watcher already runs", result.stdout)
        self.assertEqual(self.log().count(" watching "), 1)

    def test_stop_without_a_watcher(self):
        result = self.lsc("stop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("lsc: no watcher runs", result.stdout)

    def test_watch_on_a_missing_folder_exits_with_two(self):
        ini = self.root / "gone.ini"
        ini.write_text("[screenshots]\nfolder = " + str(self.root / "gone") + "\n", encoding="utf-8")
        result = self.lsc("watch", ini=ini)
        self.assertEqual(result.returncode, 2)
        self.assertIn("screenshots folder not found", result.stderr)
        self.assertIn("no watcher runs", self.lsc("status").stdout)

    def test_usage_lists_the_watch_commands(self):
        result = self.lsc("/?")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("lsc watch | stop | status", result.stdout)


if __name__ == "__main__":
    unittest.main()
