"""Windows tests for bin/ghwatched.ps1 and its ghwatched.bat wrapper.

Run: python -m unittest discover -s tests -p test_ghwatched.py -v
A stub gh prints a fixture of starred repositories, so no test reaches GitHub.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ghwatched.ps1"
WRAPPER = ROOT / "bin" / "ghwatched.bat"

# Two watched repositories that must never show: one fully watched, one not
# watched at all. viewerSubscription is null for a custom watch only.
REPOS = [
    {"nameWithOwner": "acme/scanner", "isArchived": False, "viewerSubscription": None,
     "description": "Find vulnerabilities \U0001F512 in dépôts",
     "repositoryTopics": {"nodes": [{"topic": {"name": "security"}}, {"topic": {"name": "vulnerability"}}]}},
    {"nameWithOwner": "acme/pipeline-kit", "isArchived": False, "viewerSubscription": None,
     "description": "Data pipelines",
     "repositoryTopics": {"nodes": [{"topic": {"name": "pipeline"}}]}},
    {"nameWithOwner": "acme/piptool", "isArchived": False, "viewerSubscription": None,
     "description": "Installs packages",
     "repositoryTopics": {"nodes": [{"topic": {"name": "pip"}}, {"topic": {"name": "python"}}]}},
    {"nameWithOwner": "acme/full", "isArchived": False, "viewerSubscription": "SUBSCRIBED",
     "description": "security everywhere",
     "repositoryTopics": {"nodes": [{"topic": {"name": "security"}}]}},
    {"nameWithOwner": "acme/none", "isArchived": False, "viewerSubscription": "UNSUBSCRIBED",
     "description": "security nowhere",
     "repositoryTopics": {"nodes": [{"topic": {"name": "security"}}]}},
    {"nameWithOwner": "acme/old", "isArchived": True, "viewerSubscription": None,
     "description": None, "repositoryTopics": {"nodes": []}},
    {"nameWithOwner": "acme/oauth-proxy", "isArchived": False, "viewerSubscription": None,
     "description": "Proxy in\nfront", "repositoryTopics": {"nodes": [{"topic": {"name": "oauth"}}]}},
]
CUSTOM = ["acme/scanner", "acme/pipeline-kit", "acme/piptool", "acme/old", "acme/oauth-proxy"]

STUB = "\r\n".join([
    "@echo off",
    'if not "%~1"=="api" exit /b 9',
    '>"%~dp0args.txt" echo(%*',
    'if exist "%~dp0fail.txt" (',
    '   type "%~dp0fail.txt" 1>&2',
    "   exit /b 1",
    ")",
    'type "%~dp0nodes.jsonl"',
    "exit /b 0",
    "",
])


@unittest.skipUnless(os.name == "nt", "Requires Windows PowerShell")
class GhWatchedTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senv-ghwatched-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.gh = self.folder / "gh.bat"
        self.gh.write_text(STUB, encoding="ascii", newline="")
        lines = [json.dumps(repo, ensure_ascii=False) for repo in REPOS]
        (self.folder / "nodes.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")

    def run_script(self, *words, gh=None):
        command = [
            "powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
            "-Gh", str(gh or self.gh), *words,
        ]
        return subprocess.run(command, capture_output=True, timeout=60)

    @staticmethod
    def out(result):
        return result.stdout.decode("utf-8").splitlines()

    @staticmethod
    def err(result):
        return result.stderr.decode("utf-8", "replace")

    def names(self, result):
        return [line.split(" | ")[0].replace(" (archived)", "") for line in self.out(result)]

    def test_lists_only_the_custom_watches(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, self.err(result))
        self.assertEqual(sorted(self.names(result)), sorted(CUSTOM))
        self.assertIn("5 custom-watched repositories", self.err(result))

    def test_line_holds_topics_description_and_archived_mark(self):
        lines = self.out(self.run_script())
        self.assertIn("acme/scanner | security, vulnerability | Find vulnerabilities \U0001F512 in dépôts", lines)
        self.assertIn("acme/old (archived) |  | ", lines)
        self.assertIn("acme/oauth-proxy | oauth | Proxy in front", lines)

    def test_word_matches_at_a_word_start(self):
        self.assertEqual(self.names(self.run_script("vuln")), ["acme/scanner"])
        self.assertEqual(sorted(self.names(self.run_script("pip"))), ["acme/pipeline-kit", "acme/piptool"])

    def test_word_inside_another_word_does_not_match(self):
        result = self.run_script("auth")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.out(result), [])
        self.assertIn("0 of 5 custom-watched repositories match", self.err(result))

    def test_equal_sign_wants_the_whole_word(self):
        self.assertEqual(self.names(self.run_script("=pip")), ["acme/piptool"])

    def test_commas_and_arguments_add_words(self):
        expected = ["acme/old", "acme/pipeline-kit", "acme/scanner"]
        self.assertEqual(sorted(self.names(self.run_script("pipeline,old", "scanner"))), expected)

    def test_word_list_file_skips_comments_and_blanks(self):
        words = self.folder / "mine.txt"
        words.write_text("# a comment naming scanner\n\n=pip, oauth\n", encoding="utf-8")
        result = self.run_script("@" + str(words))
        self.assertEqual(sorted(self.names(result)), ["acme/oauth-proxy", "acme/piptool"])

    def test_shipped_security_list_is_found_by_name(self):
        result = self.run_script("@security")
        self.assertEqual(sorted(self.names(result)), ["acme/oauth-proxy", "acme/scanner"])

    def test_missing_word_list_exits_41(self):
        result = self.run_script("@no-such-list")
        self.assertEqual(result.returncode, 41)
        self.assertIn("No word list 'no-such-list'", self.err(result))

    def test_arguments_without_any_word_exit_41(self):
        self.assertEqual(self.run_script(",", "=").returncode, 41)

    def test_names_prints_only_owner_and_name(self):
        result = self.run_script("-Names", "pipeline")
        self.assertEqual(self.out(result), ["acme/pipeline-kit"])

    def test_missing_gh_exits_42(self):
        result = self.run_script(gh=self.folder / "missing.exe")
        self.assertEqual(result.returncode, 42)

    def test_gh_failure_exits_44_with_its_message(self):
        (self.folder / "fail.txt").write_text("HTTP 401: Bad credentials\n", encoding="ascii")
        result = self.run_script()
        self.assertEqual(result.returncode, 44)
        self.assertIn("Bad credentials", self.err(result))

    def test_every_page_of_stars_is_requested(self):
        self.run_script()
        args = (self.folder / "args.txt").read_text(encoding="utf-8", errors="replace")
        self.assertIn("--paginate", args)
        self.assertIn("starredRepositories(first: 100, after: $endCursor)", args)
        self.assertIn("viewerSubscription", args)

    def test_wrapper_passes_words_and_prints_usage(self):
        result = subprocess.run(["cmd", "/c", str(WRAPPER), "-Gh", str(self.gh), "=pip"],
                                capture_output=True, timeout=60)
        self.assertEqual(result.returncode, 0, self.err(result))
        self.assertEqual(self.names(result), ["acme/piptool"])
        usage = subprocess.run(["cmd", "/c", str(WRAPPER), "-h"], capture_output=True, timeout=60)
        self.assertEqual(usage.returncode, 0)
        self.assertIn("Usage: ghwatched", usage.stdout.decode("utf-8", "replace"))


if __name__ == "__main__":
    unittest.main()
