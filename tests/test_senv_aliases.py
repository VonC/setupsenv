"""Behavioral tests of the alias loading shared by senv.bat and the user launcher.

Doskey macros belong to one console, and a new console inherits none: a console
where only a project senv.bat ran lacked the global, team and personal aliases.
bin/senv_doskey.bat loads them, and the %USERPROFILE%\\senv.bat launcher, rendered
from senv.user_profile.tpl.bat, calls it on its own and before a project senv.bat.

Every cmd that loads real macros runs with CREATE_NO_WINDOW, in a console of its
own: macros loaded in the console running the tests would replace the user's.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bin" / "senv_doskey.bat"
TEMPLATE = ROOT / "senv.user_profile.tpl.bat"
CMD = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "cmd.exe"


def run_isolated(command: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    """Run one cmd line in a console of its own, delayed expansion on, outside any senv run.

    Delayed expansion lets !errorlevel! and !variable! read their values after a
    call on the same line; %...% would read them when cmd parses the line.
    """
    env = {name: value for name, value in os.environ.items() if name.lower() != "senv_t_m"}
    return subprocess.run(f'"{CMD}" /d /v:on /c "{command}"', capture_output=True, text=True,
                          encoding="oem", errors="replace", timeout=20, env=env, cwd=cwd,
                          creationflags=subprocess.CREATE_NO_WINDOW)


class SenvDoskeyTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="senv-doskey-")
        self.addCleanup(temp.cleanup)
        self.bin = Path(temp.name) / "home bin"
        self.bin.mkdir()
        shutil.copy(HELPER, self.bin / HELPER.name)
        self.helper = self.bin / HELPER.name
        (self.bin / "senv.doskey").write_text("senvtestll=echo GLOBAL\nsenvtestboth=echo GLOBAL\n")
        (self.bin / "senv.custom.doskey").write_text("senvtestteam=echo TEAM\n")
        (self.bin / "senv.local.doskey").write_text("senvtestboth=echo LOCAL\n")

    def load(self) -> tuple[dict[str, str], subprocess.CompletedProcess[str]]:
        result = run_isolated(f'call "{self.helper}" & echo EXIT=!errorlevel! & doskey /macros')
        macros = dict(line.split("=", 1) for line in result.stdout.splitlines() if line.startswith("senvtest"))
        return macros, result

    def test_loads_the_three_files_in_order_and_the_profile_file(self):
        (self.bin / "profile").write_text("team2\n")
        (self.bin / "senv.custom.team2.doskey").write_text("senvtestprofile=echo PROFILE\n")
        macros, result = self.load()
        self.assertIn("EXIT=0", result.stdout, result.stdout + result.stderr)
        self.assertEqual(macros, {
            "senvtestll": "echo GLOBAL",
            "senvtestboth": "echo LOCAL",  # The personal file loads after the global one.
            "senvtestteam": "echo TEAM",
            "senvtestprofile": "echo PROFILE",
        })
        self.assertNotIn("WARNING", result.stdout)

    def test_reports_a_missing_file_and_still_loads_the_others(self):
        (self.bin / "senv.custom.doskey").unlink()
        macros, result = self.load()
        self.assertIn("EXIT=0", result.stdout)
        self.assertIn("WARNING: Issue setting custom (team) aliases from", result.stdout)
        self.assertEqual(macros, {"senvtestll": "echo GLOBAL", "senvtestboth": "echo LOCAL"})

    def test_adds_its_timing_marks_only_inside_a_timed_senv_run(self):
        (self.bin / "profile").write_text("team2\n")
        timed = run_isolated(f'set senv_t_m=0=start& call "{self.helper}" & echo MARKS=[!senv_t_m!]'
                             ' & if defined senv_doskey_profile (echo PROFILE-LEFT) else echo PROFILE-CLEARED')
        marks = timed.stdout.split("MARKS=[", 1)[1].split("]", 1)[0].split(";")
        self.assertEqual([mark.split("=", 1)[1] for mark in marks], [
            "start", "doskey npp", "doskey senv.doskey", "doskey senv.custom.doskey",
            "doskey senv.local.doskey", "doskey senv.custom.profile.doskey"])
        self.assertIn("PROFILE-CLEARED", timed.stdout)  # The helper leaves no variable of its own.
        untimed = run_isolated(f'call "{self.helper}" & if defined senv_t_m (echo TIMED) else echo UNTIMED')
        self.assertIn("UNTIMED", untimed.stdout)

    def npp(self, prgs: Path | None) -> str | None:
        """The npp macro the helper leaves, with PRGS set to prgs, or cleared."""
        result = run_isolated(f'set "PRGS={prgs or ""}"& call "{self.helper}" & doskey /macros')
        found = [line.split("=", 1)[1] for line in result.stdout.splitlines() if line.startswith("npp=")]
        return found[0] if found else None

    def test_defines_npp_with_the_settings_folder_when_there_is_one(self):
        # senv.bat defined npp until 2026-11-09: a project console, which runs
        # only this helper and the project senv.bat, had no npp.
        prgs = self.bin.parent / "prgs"
        (prgs / "npps").mkdir(parents=True)
        exe = prgs / "npps" / "current" / "notepad++.exe"
        self.assertEqual(self.npp(prgs), f'"{exe}" $*')
        (prgs / "npps" / "settings").mkdir()
        self.assertEqual(self.npp(prgs), f'"{exe}" -settingsDir="{prgs / "npps" / "settings"}" $*')
        self.assertIsNone(self.npp(None))  # No PRGS: no macro pointing at '\npps\...'.

    def test_a_personal_npp_line_still_replaces_it(self):
        (self.bin / "senv.local.doskey").write_text("npp=echo PERSONAL $*\n")
        prgs = self.bin.parent / "prgs"
        prgs.mkdir()
        self.assertEqual(self.npp(prgs), "echo PERSONAL $*")


class SenvBatDefinesNoSharedAliasTest(unittest.TestCase):
    def test_only_the_maintainer_aliases_stay_in_senv_bat(self):
        # The launcher runs senv_doskey.bat, not senv.bat, before a project
        # senv.bat: an alias defined in senv.bat misses from that console, as
        # npp did. ba, pb and pp call adm scripts, on PATH in local mode only.
        text = (ROOT / "bin" / "senv.bat").read_text(encoding="utf-8", errors="replace")
        names = re.findall(r"(?im)^\s*doskey\s+([^\s=/]+)=", text)
        self.assertEqual(sorted(names), ["ba", "pb", "pp"])


class LauncherTest(unittest.TestCase):
    """The launcher as setup.bat renders it, with fake activations that only echo."""

    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="senvlauncher")
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        # Most template lines call _HOME_ paths unquoted, as setup.bat has always
        # rendered them: the HOME here has no space, as on the machines.
        self.home, self.profile = base / "home", base / "profile"
        self.project, self.plain = base / "project (one)", base / "plain"
        for folder in (self.home / "bin", self.profile, self.project, self.plain):
            folder.mkdir(parents=True)
        (self.home / "bin" / "senv.bat").write_text("@echo off\necho RAN-GLOBAL\n")
        self.aliases = self.home / "bin" / "senv_doskey.bat"
        self.aliases.write_text("@echo off\necho RAN-ALIASES\n")
        (self.project / "senv.bat").write_text("@echo off\necho RAN-PROJECT\nexit /b 3\n")
        self.launcher = self.profile / "senv.bat"
        # The rendering of setup.bat: the template with _HOME_ replaced, CRLF kept.
        self.launcher.write_text(TEMPLATE.read_text().replace("_HOME_", str(self.home)))

    def run_launcher(self, folder: Path, argument: str = "") -> tuple[list[str], subprocess.CompletedProcess[str]]:
        result = subprocess.run(f'"{CMD}" /d /c call "{self.launcher}" {argument}', capture_output=True,
                                text=True, encoding="oem", errors="replace", timeout=20, cwd=folder)
        return [word for word in result.stdout.split() if word.startswith("RAN-")], result

    def test_aliases_loads_only_the_aliases(self):
        for folder in (self.project, self.plain):
            with self.subTest(folder=folder.name):
                self.assertEqual(self.run_launcher(folder, "aliases")[0], ["RAN-ALIASES"])

    def test_a_project_folder_gets_the_aliases_before_its_own_senv(self):
        ran, result = self.run_launcher(self.project)
        self.assertEqual(ran, ["RAN-ALIASES", "RAN-PROJECT"])
        self.assertEqual(result.returncode, 3)  # The project's exit code, as before.

    def test_the_global_activation_loads_the_aliases_itself(self):
        self.assertEqual(self.run_launcher(self.plain)[0], ["RAN-GLOBAL"])
        self.assertEqual(self.run_launcher(self.project, "global")[0], ["RAN-GLOBAL"])
        self.assertEqual(self.run_launcher(self.project, "all")[0], ["RAN-GLOBAL", "RAN-PROJECT"])

    def test_a_project_console_keeps_npp_and_the_global_aliases(self):
        # The reported case, with the real helper: in a project console, 'll'
        # worked and 'npp' was not recognized. The project's own aliases win.
        bin_dir = self.home / "bin"
        shutil.copy(HELPER, self.aliases)
        (bin_dir / "senv.doskey").write_text("senvtestll=echo GLOBAL\nsenvtestboth=echo GLOBAL\n")
        (bin_dir / "senv.custom.doskey").write_text("")
        (bin_dir / "senv.local.doskey").write_text("")
        (self.project / "senv.doskey").write_text("senvtestboth=echo PROJECT\n")
        (self.project / "senv.bat").write_text('@echo off\ndoskey /MACROFILE="%~dp0senv.doskey"\n')
        prgs = self.home.parent / "prgs"
        prgs.mkdir()
        result = run_isolated(f'set "PRGS={prgs}"& call "{self.launcher}" & doskey /macros', cwd=self.project)
        macros = dict(line.split("=", 1) for line in result.stdout.splitlines()
                      if line.startswith(("senvtest", "npp=")))
        self.assertEqual(macros, {
            "senvtestll": "echo GLOBAL",
            "senvtestboth": "echo PROJECT",
            "npp": f'"{prgs}\\npps\\current\\notepad++.exe" $*',
        }, result.stdout + result.stderr)

    def test_a_home_without_the_helper_still_runs_the_project(self):
        self.aliases.unlink()
        ran, result = self.run_launcher(self.project)
        self.assertEqual(ran, ["RAN-PROJECT"])
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.run_launcher(self.project, "aliases")[0], [])


if __name__ == "__main__":
    unittest.main()
