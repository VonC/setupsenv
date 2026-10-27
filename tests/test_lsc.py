"""Windows tests for the newest screenshot paths of bin/last-screenshots.ps1.

Run: python -m unittest discover -s tests -p test_lsc.py -v
Each test works on disposable images in a temporary folder, and never
touches the clipboard.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "last-screenshots.ps1"
BAT = ROOT / "bin" / "lsc.bat"
SCREENSHOTS_FOLDER_ID = "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}"
SHELL_FOLDERS_KEY = r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
# A redirected OneDrive folder carries a typographic apostrophe, and its files
# an ASCII one with an accented letter.
LOCALIZED = "Captures d’écran"


@unittest.skipUnless(os.name == "nt", "Requires Windows PowerShell")
class LscTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senv-lsc-")
        self.addCleanup(self.temp.cleanup)
        # TEMP can be an 8.3 short path, while PowerShell prints long names.
        self.root = Path(self.temp.name).resolve()
        self.folder = self.root / "shots"
        self.folder.mkdir()
        self.ini = self.write_ini("[screenshots]\nfolder = " + str(self.folder) + "\n")

    def write_ini(self, text, name="lsc.custom.ini", encoding="utf-8"):
        path = self.root / name
        path.write_text(text, encoding=encoding)
        return path

    def image(self, name, minute, folder=None):
        path = (folder or self.folder) / name
        path.write_bytes(b"")
        stamp = 1793000000 + minute * 60
        os.utime(path, (stamp, stamp))
        return path

    def lsc(self, *args, ini=None):
        command = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
            *args, "-Ini", str(ini or self.ini), "-NoClipboard",
        ]
        return subprocess.run(
            command, capture_output=True, encoding="utf-8", timeout=30,
        )

    def quoted(self, *paths):
        return " ".join('"' + str(path) + '"' for path in paths)

    def test_newest_image_by_default(self):
        self.image("Capture 1.png", 1)
        newest = self.image("Capture 2.png", 2)
        result = self.lsc()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(newest))
        self.assertEqual(result.stderr, "")

    def test_n_newest_in_capture_order(self):
        self.image("a.png", 1)
        second = self.image("b.png", 2)
        third = self.image("c.png", 3)
        fourth = self.image("d.png", 4)
        result = self.lsc("3")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(second, third, fourth))

    def test_other_files_are_skipped(self):
        png = self.image("shot.PNG", 1)
        jpg = self.image("photo.Jpg", 2)
        for name in ("desktop.ini", "notes.txt", "shot.png.tmp"):
            self.image(name, 9)
        (self.folder / "newer.png").mkdir()
        result = self.lsc("5")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(png, jpg))

    def test_every_image_extension_counts(self):
        names = ["a.png", "b.jpg", "c.jpeg", "d.gif", "e.bmp", "f.webp"]
        paths = [self.image(name, minute) for minute, name in enumerate(names)]
        result = self.lsc("6")
        self.assertEqual(result.stdout.strip(), self.quoted(*paths))

    def test_same_time_orders_by_name(self):
        first = self.image("Capture 163019.png", 5)
        second = self.image("Capture 163019b.png", 5)
        self.assertEqual(self.lsc("2").stdout.strip(), self.quoted(first, second))
        self.assertEqual(self.lsc().stdout.strip(), self.quoted(second))

    def test_fewer_images_than_asked_copies_them_all(self):
        first = self.image("a.png", 1)
        second = self.image("b.png", 2)
        result = self.lsc("4")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(first, second))
        self.assertIn("only 2 image(s)", result.stderr)
        self.assertIn("4 asked", result.stderr)

    def test_invalid_n_exits_with_one(self):
        self.image("a.png", 1)
        for value in ("0", "abc", "2.5", "00"):
            with self.subTest(value=value):
                result = self.lsc(value)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, "")
                self.assertIn("N must be a whole number", result.stderr)

    def test_empty_folder_exits_with_three(self):
        self.image("desktop.ini", 1)
        result = self.lsc()
        self.assertEqual(result.returncode, 3)
        self.assertEqual(result.stdout, "")
        self.assertIn("no image in", result.stderr)

    def test_missing_folder_exits_with_two(self):
        missing = self.root / "gone"
        ini = self.write_ini("[screenshots]\nfolder = " + str(missing) + "\n", "gone.ini")
        result = self.lsc(ini=ini)
        self.assertEqual(result.returncode, 2)
        self.assertIn("screenshots folder not found", result.stderr)
        self.assertIn(str(missing), result.stderr)

    def test_localized_folder_from_utf8_with_and_without_bom(self):
        folder = self.root / LOCALIZED
        folder.mkdir()
        shot = self.image("Capture d'écran 2026-10-26 163019.png", 1, folder)
        for encoding in ("utf-8", "utf-8-sig"):
            with self.subTest(encoding=encoding):
                ini = self.write_ini(
                    "[screenshots]\nfolder = " + str(folder) + "\n", encoding + ".ini", encoding,
                )
                result = self.lsc(ini=ini)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), self.quoted(shot))

    def test_ini_syntax(self):
        shot = self.image("a.png", 1)
        ini = self.write_ini(
            "; a comment\n"
            "[other]\n"
            "folder = " + str(self.root / "wrong") + "\n"
            "\n"
            "[Screenshots]\n"
            "# folder = " + str(self.root / "commented") + "\n"
            "  Folder   =   \"" + str(self.folder) + "\"  \n",
            "syntax.ini",
        )
        result = self.lsc(ini=ini)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(shot))

    def test_environment_variables_expand(self):
        shot = self.image("a.png", 1)
        ini = self.write_ini("[screenshots]\nfolder = %LSC_TEST_ROOT%\\shots\n", "env.ini")
        env = dict(os.environ, LSC_TEST_ROOT=str(self.root))
        result = subprocess.run([
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
            "-Ini", str(ini), "-NoClipboard",
        ], capture_output=True, encoding="utf-8", timeout=30, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(shot))

    def test_without_the_key_the_known_folder_is_used(self):
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, SHELL_FOLDERS_KEY) as key:
                known, _ = winreg.QueryValueEx(key, SCREENSHOTS_FOLDER_ID)
        except OSError:
            self.skipTest("no Screenshots folder recorded for this user")
        known = Path(os.path.expandvars(known))
        for ini in (self.write_ini("[screenshots]\n", "empty.ini"), self.root / "absent.ini"):
            with self.subTest(ini=ini.name):
                result = self.lsc(ini=ini)
                self.assertIn(result.returncode, (0, 3), result.stderr)
                if result.returncode == 0:
                    first = result.stdout.strip().split('" "')[0].strip('"')
                    self.assertEqual(Path(first).parent, known)
                else:
                    self.assertIn(str(known), result.stderr)

    def test_help_exits_with_zero(self):
        for command in (
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT), "/?"],
            ["cmd", "/d", "/c", str(BAT), "-h"],
            ["cmd", "/d", "/c", str(BAT), "--help"],
        ):
            with self.subTest(argument=command[-1]):
                result = subprocess.run(command, capture_output=True, encoding="utf-8", timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Usage: lsc [N]", result.stdout)

    def test_bat_passes_its_arguments(self):
        self.image("a.png", 1)
        second = self.image("b.png", 2)
        third = self.image("c.png", 3)
        result = subprocess.run(
            ["cmd", "/d", "/c", str(BAT), "2", "-Ini", str(self.ini), "-NoClipboard"],
            capture_output=True, encoding="utf-8", timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.quoted(second, third))

    def test_bat_returns_the_exit_code(self):
        result = subprocess.run(
            ["cmd", "/d", "/c", str(BAT), "abc"], capture_output=True, encoding="utf-8", timeout=30,
        )
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
