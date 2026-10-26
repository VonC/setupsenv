"""Which resume command each agent pane that tuitp starts gets, and how it is queued. No TUIOS runs."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
import tuitp_windows
from tuitp_model import read_list
from tuitp_resume import deliver, resume_plan, waiting_prompt
from tuitp_windows import Windows


def prompt_text(author, title="Finish the step", role="specification review requestor"):
    heading = f"# {author}: Resume session: {title}" if author else f"# Resume session: {title}"
    return f"{heading}\n\nContinue.\n\n- Paused by: {author}\n- Session role: {role}\n"


class Checkouts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tuitp-resume-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()  # read_list expands short names.

    def repo(self, name, author=None, **fields):
        folder = self.base / name
        (folder / ".git").mkdir(parents=True)
        if author is not None:
            self.pause(folder, author, **fields)
        return folder

    def pause(self, folder, author, home=".reviews", **fields):
        (folder / home).mkdir(exist_ok=True)
        prompt = folder / home / "a.session-resume.local.md"
        prompt.write_text(prompt_text(author, **fields), encoding="utf-8")
        return prompt

    def receipt(self, folder, digest=None, root=None, home=".reviews", prompt="a.session-resume.local.md"):
        data = (folder / home / "a.session-resume.local.md").read_bytes()
        (folder / home / "a.session-resume.used.local.md").write_text(
            "# Session resume usage receipt\n\n- Schema: 2\n"
            f"- Prompt: {prompt}\n- SHA-256: {digest or hashlib.sha256(data).hexdigest()}\n"
            f"- Project root: {root or folder}\n- Used at: 2026-10-25T16:20:00+01:00\n", encoding="utf-8")

    def layout(self, text, **folders):
        for name, folder in folders.items():
            text = text.replace(name.upper(), str(folder))
        path = self.base / "tuitp.list"
        path.write_text(text, encoding="utf-8")
        return read_list(path)


class WaitingPromptTests(Checkouts):
    def test_a_prompt_waits_until_a_receipt_holds_its_digest(self):
        folder = self.repo("api")
        self.assertIsNone(waiting_prompt(folder))
        self.pause(folder, "chatgpt", title="Step 4: managed writes")
        self.assertEqual(waiting_prompt(folder), {"author": "chatgpt", "title": "Step 4: managed writes",
                                                  "role": "specification review requestor"})
        self.receipt(folder)
        self.assertIsNone(waiting_prompt(folder))
        # A new pause since the last resume: its bytes differ from the receipt's.
        self.pause(folder, "claude", title="Step 5")
        self.assertEqual(waiting_prompt(folder)["author"], "claude")

    def test_a_prompt_saved_before_agents_named_themselves_has_no_author(self):
        folder = self.repo("api", author="")
        self.assertEqual(waiting_prompt(folder)["author"], "unknown")

    def test_where_resume_session_would_stop_it_raises(self):
        folder = self.repo("api", author="claude")
        cases = {"another checkout": lambda: self.receipt(folder, root=self.base / "other"),
                 "not a resume-session receipt": lambda: self.receipt(folder, digest="abc"),
                 "not a resume-session receipt ": lambda: self.receipt(folder, prompt="other.md")}
        for message, write in cases.items():
            with self.subTest(message=message):
                write()
                with self.assertRaisesRegex(ValueError, message.strip()):
                    waiting_prompt(folder)
        (folder / ".reviews" / "a.session-resume.used.local.md").unlink()
        (folder / ".reviews" / "a.session-resume.local.md").write_text(" \n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "is empty"):
            waiting_prompt(folder)

    def test_the_receipt_root_compares_as_windows_paths_do(self):
        folder = self.repo("api", author="claude")
        self.receipt(folder, root=str(folder).upper())
        self.assertIsNone(waiting_prompt(folder))

    def test_a_declared_artifact_home_holds_the_prompt(self):
        folder = self.repo("api")
        (folder / ".review-artifacts.ini").write_text("[review-artifacts]\nhome = notes/private\n", encoding="utf-8")
        (folder / "notes").mkdir()
        self.pause(folder, "chatgpt", home="notes/private")
        self.assertEqual(waiting_prompt(folder)["author"], "chatgpt")
        for text in ("[other]\nhome = x\n", "[review-artifacts]\nhome = x\nmore = y\n",
                     "[review-artifacts]\nhome = ..\\outside\n", "[review-artifacts]\nhome = .\n", "home = x"):
            with self.subTest(text=text):
                (folder / ".review-artifacts.ini").write_text(text, encoding="utf-8")
                with self.assertRaises(ValueError):
                    waiting_prompt(folder)

    def test_crlf_prompts_read_as_lf_ones(self):
        folder = self.repo("api")
        (folder / ".reviews").mkdir()
        (folder / ".reviews" / "a.session-resume.local.md").write_bytes(
            prompt_text("chatgpt").replace("\n", "\r\n").encode("utf-8"))
        self.assertEqual(waiting_prompt(folder)["role"], "specification review requestor")


class ResumePlanTests(Checkouts):
    def plan(self, text, starting=None, **folders):
        layout = self.layout(text, **folders)
        sessions = [layout.sessions[name] for name in starting] if starting else list(layout.sessions.values())
        return resume_plan(layout, sessions)

    def test_a_project_tab_paused_by_its_codex_requestor(self):
        api = self.repo("api", author="chatgpt", title="Q25 and Q26")
        deliveries, lines = self.plan("=== Tab\n+ API|api||pdf", api=api)
        self.assertEqual(deliveries, [
            {"session": "api", "window": "Claude pdf", "text": "/review-resume as reviewer"},
            # Codex takes its command as the prompt it starts with: the helper queues only Claude's.
            {"session": "api", "window": "Codex pdf", "text": "$llm-shared:resume-session", "start": True}])
        self.assertEqual(lines, ["RESUME session api: Claude runs /review-resume as reviewer and Codex starts with "
                                 "$llm-shared:resume-session, for the prompt chatgpt paused for 'Q25 and Q26'"])

    def test_the_other_agent_waits_as_reviewer_only_after_a_requestor_pause(self):
        api = self.repo("api", author="claude", role="implementation")
        deliveries, lines = self.plan("=== Tab\n+ API|api", api=api)
        self.assertEqual(deliveries, [{"session": "api", "window": "Claude", "text": "/resume-session"}])
        self.assertEqual(lines, ["RESUME session api: Claude runs /resume-session, for the prompt claude "
                                 "paused for 'Finish the step'"])
        self.pause(api, "claude", role="code-review requestor")
        deliveries, _ = self.plan("=== Tab\n+ API|api", api=api)
        self.assertEqual([d["text"] for d in deliveries], ["/resume-session", "$llm-shared:review-resume as reviewer"])

    def test_a_one_agent_session_resumes_only_its_own_agent_s_pause(self):
        mine, theirs = self.repo("mine", author="claude"), self.repo("theirs", author="chatgpt")
        deliveries, lines = self.plan("=== Solo\n+ MINE|mine|claude\n+ THEIRS|theirs|claude", mine=mine,
                                      theirs=theirs)
        self.assertEqual(deliveries, [{"session": "mine", "window": "Claude", "text": "/resume-session"}])
        self.assertEqual(lines[1], f"NOTE session theirs: no agent resumes the prompt chatgpt paused for "
                                   f"'Finish the step', since the list declares no Codex pane for {theirs}")

    def test_a_cmd_session_and_an_unknown_author_only_note(self):
        shell, old = self.repo("shell", author="chatgpt"), self.repo("old", author="")
        deliveries, lines = self.plan("=== Shell\n+ SHELL|shell|senv\n=== Old\n+ OLD|old", shell=shell, old=old)
        self.assertEqual(deliveries, [])
        self.assertIn("no Codex pane", lines[0])
        self.assertIn("which names no agent: run resume-session in the agent that paused it", lines[1])

    def test_sessions_on_one_checkout_split_the_roles_and_the_first_pane_wins(self):
        api = self.repo("api", author="chatgpt")
        text = "=== A\n+ API|cl|claude\n=== B\n+ API|cx|codex\n+ API|cl2|claude"
        deliveries, lines = self.plan(text, api=api)
        self.assertEqual([(d["session"], d["text"]) for d in deliveries],
                         [("cl", "/review-resume as reviewer"), ("cx", "$llm-shared:resume-session")])
        self.assertEqual(len(lines), 2)  # cl2 has no part, and no note: Codex holds the prompt.
        # A running session keeps its part: the starting one gets nothing in its place.
        deliveries, lines = self.plan(text, starting=["cl2"], api=api)
        self.assertEqual((deliveries, lines), ([], []))

    def test_a_used_missing_or_unreadable_prompt(self):
        used, empty, broken = self.repo("used", author="claude"), self.repo("empty"), self.repo("broken", author="claude")
        self.receipt(used)
        self.receipt(broken, digest="abc")
        deliveries, lines = self.plan("=== A\n+ USED|used\n+ EMPTY|empty\n+ BROKEN|broken", used=used, empty=empty,
                                      broken=broken)
        self.assertEqual(deliveries, [])
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith("NOTE session broken: no agent resumes it, its resume prompt cannot be "
                                            "read: "))

    def test_each_checkout_is_read_once(self):
        api = self.repo("api", author="chatgpt")
        with patch("tuitp_resume.waiting_prompt", wraps=waiting_prompt) as read:
            self.plan("=== A\n+ API|one|claude\n+ API|two|codex\n+ API|three|senv", api=api)
        self.assertEqual(read.call_count, 1)


class DeliverTests(unittest.TestCase):
    def deliver(self, *results):
        calls, lines = [], []
        replies = iter(results)
        def run(argv, **kwargs):
            calls.append(argv)
            return next(replies)
        deliver("tuios.exe", [{"session": "api", "window": "Codex pdf", "text": "$llm-shared:resume-session"}],
                lines.append, run=run, wait_ms=5)
        return calls, lines

    def test_it_queues_once_the_agent_is_at_its_prompt(self):
        ok = subprocess.CompletedProcess([], 0, '{"id": "q1"}', "")
        calls, lines = self.deliver(ok, ok)
        self.assertEqual(calls, [
            ["tuios.exe", "wait-for", "agent-state", "-s", "api", "-w", "Codex pdf", "--until", "idle,done",
             "--timeout", "5"],
            ["tuios.exe", "queue", "-s", "api", "-w", "Codex pdf", "--json", "--", "$llm-shared:resume-session"]])
        self.assertEqual(lines, ['api/Codex pdf: queued $llm-shared:resume-session {"id": "q1"}'])

    def test_no_agent_at_its_prompt_queues_nothing(self):
        calls, lines = self.deliver(subprocess.CompletedProcess([], 1, "", "timeout\n"))
        self.assertEqual(len(calls), 1)
        self.assertEqual(lines, ["api/Codex pdf: no agent at its prompt, $llm-shared:resume-session not queued: "
                                 "timeout"])

    def test_a_refused_queue_is_logged(self):
        calls, lines = self.deliver(subprocess.CompletedProcess([], 0, "", ""),
                                    subprocess.CompletedProcess([], 2, "", "agent_blocked"))
        self.assertEqual(lines, ["api/Codex pdf: cannot queue $llm-shared:resume-session: agent_blocked"])


class QueueResumeProcessTests(unittest.TestCase):
    def test_the_helper_runs_detached_outside_tuios_with_the_deliveries(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-resume-") as temp:
            scripts, root = Path(temp) / "bin", Path(temp) / "state"
            scripts.mkdir()
            root.mkdir()
            runtime = Windows(scripts, root)
            deliveries = [{"session": "api", "window": "Claude", "text": "/resume-session"}]
            with patch("tuitp_windows.subprocess.Popen", return_value=Mock(pid=7)) as popen, \
                    patch.dict(os.environ, {"TUIOS_SESSION": "api", "TUIOS_ENV": "1"}):
                runtime.queue_resume(deliveries)
            argv, kwargs = popen.call_args.args[0], popen.call_args.kwargs
            self.assertEqual(argv[1:3], [str(scripts / "tuitp_resume.py"), str(runtime.tuios)])
            self.assertEqual(json.loads(argv[3]), deliveries)
            self.assertFalse([name for name in kwargs["env"] if name.startswith("TUIOS_")])
            self.assertTrue(kwargs["creationflags"] & tuitp_windows.subprocess.DETACHED_PROCESS)
            self.assertEqual(Path(kwargs["stdout"].name), root / "resume.log")


if __name__ == "__main__":
    unittest.main()
