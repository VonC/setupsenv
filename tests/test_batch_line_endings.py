"""Every batch file Git tracks must end its lines with CRLF in the working tree.

Run: python -m unittest discover -s tests -p test_batch_line_endings.py -v

cmd finds a `goto` or `call` label by reading the file in blocks. With LF-only
lines, that search can miss the label or stop in the middle of a line. On
2026-11-08, an LF bin/dwl.bat made `call :curl` from the Node section land on a
`goto:eof`: `dwl node 22` exited 0 without a download, and `dwl gum` built a jq
URL. .gitattributes asks for CRLF, but Git writes it only on checkout: a tool
that rewrites a batch file with LF goes unseen, since `git status` and
`git diff` compare the normalized content.

The check reads the files, no process starts but one `git ls-files`.
"""
from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SUFFIXES = (".bat", ".cmd")


@unittest.skipUnless(shutil.which("git"), "Requires git")
class BatchFilesUseCrlfTest(unittest.TestCase):
    def test_every_tracked_batch_file_uses_crlf_only(self):
        listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--recurse-submodules"],
                                capture_output=True, check=True, timeout=30).stdout
        names = [name for name in listed.decode("utf-8").split("\0")
                 if name.lower().endswith(SUFFIXES)]
        self.assertTrue(names, "git ls-files listed no batch file")
        offenders = []
        for name in names:
            path = ROOT / name
            if not path.is_file():
                continue
            data = path.read_bytes()
            bare = data.count(b"\n") - data.count(b"\r\n")
            if bare:
                offenders.append(f"{name}: {bare} LF-only line(s)")
        self.assertEqual(offenders, [], "rewrite with CRLF line endings:\n" + "\n".join(offenders))


if __name__ == "__main__":
    unittest.main()
