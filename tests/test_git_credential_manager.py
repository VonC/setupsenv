"""Regression checks for the Git install hooks and the standalone Git Credential Manager.

These read the shipped batch files as text: no process starts, each test stays
far below a second. The behaviour of the system credential helper section was
checked by running it against scratch configurations (GIT_CONFIG_SYSTEM).
"""
import fnmatch
import re
import unittest
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@lru_cache(maxsize=None)
def shipped_bytes(relative: str) -> bytes:
    """Shipped files do not change during a test run."""
    return (ROOT / relative).read_bytes()


def shipped_text(relative: str) -> str:
    return shipped_bytes(relative).decode("ascii").replace("\r\n", "\n")


class InstPrgHookOrderTest(unittest.TestCase):
    def test_post_hooks_run_once_current_points_at_the_new_version(self):
        text = shipped_text("bin/inst_prg.bat")
        section = text[text.index(":_check_post_install\n"):]
        link = section.index('check_prg_symlink.bat"')
        save = section.index(":save_gitconfig")
        first_post_hook = section.index('.post.bat" "%sln%"')
        self.assertLess(link, save)
        self.assertLess(save, first_post_hook)
        # A single link check: none left after the hooks.
        self.assertEqual(text.count('check_prg_symlink.bat"'), 1)


class GitsPostCredentialHelperTest(unittest.TestCase):
    def section(self) -> str:
        text = shipped_text("installs/gits.post.bat")
        start = text.index("set \"system_helpers=\"\n")
        # The label at a line start, not the goto lines that name it.
        return text[start:text.index("\n:system_helper_done\n", start)]

    def test_system_helper_is_set_by_name_over_every_value(self):
        section = self.section()
        self.assertIn("git config --system --replace-all credential.helper %mgrname%", section)
        # findstr anchors a line end on a CR, and git prints LF-only lines.
        self.assertNotIn("findstr /I /X", section)
        # 'if errorlevel 0' is always true.
        self.assertIsNone(re.search(r"if errorlevel 0\b", section))

    def test_standalone_gcm_is_applied_after_the_helper_is_set(self):
        text = shipped_text("installs/gits.post.bat")
        done = text.index("\n:system_helper_done\n")
        self.assertGreater(text.index('call "%installs_dir%\\gcms.post.bat"'), done)


class StandaloneGcmCatalogTest(unittest.TestCase):
    def test_prgs_list_entry_matches_the_dwl_download(self):
        lines = [line for line in shipped_text("bin/prgs.list").splitlines() if "/gcm~" in line]
        self.assertEqual(len(lines), 1)
        names, _versions, folder, pattern, scope = lines[0].split("~")
        self.assertEqual(folder, "gcms")
        self.assertEqual(scope, "global")
        dwl = shipped_text("bin/dwl.bat")
        block = dwl[dwl.index(":dwl_gcm\n"):]
        block = block[:block.index("goto:eof")]
        file_name = re.search(r'set "file=([^"]+)"', block).group(1).replace("%version%", "3.0.2")
        self.assertTrue(fnmatch.fnmatch(file_name, pattern), (file_name, pattern))

    def test_gcms_post_keeps_the_bundled_files(self):
        text = shipped_text("installs/gcms.post.bat")
        self.assertIn('move "%git_bin%\\%%~nxf" "%git_bin%\\%%~nxf.bundled"', text)
        self.assertIn("credential-manager --version", text)


class TestInternetTest(unittest.TestCase):
    def test_curl_writes_to_nul_with_a_15_second_timeout(self):
        text = shipped_text("bin/testinternet.bat")
        self.assertNotIn("-o /dev/null", text)
        self.assertIn('set "curl_timeout=15"', text)
        self.assertEqual(text.count("-o NUL -m %curl_timeout%"), 2)


class BatchLineEndingTest(unittest.TestCase):
    def test_changed_hooks_use_crlf_only(self):
        # cmd fails to find a goto label in LF-only lines.
        for relative in ("bin/inst_prg.bat", "bin/testinternet.bat",
                         "installs/gits.post.bat", "installs/gcms.post.bat"):
            with self.subTest(relative=relative):
                data = shipped_bytes(relative)
                self.assertEqual(data.count(b"\n"), data.count(b"\r\n"))


if __name__ == "__main__":
    unittest.main()
