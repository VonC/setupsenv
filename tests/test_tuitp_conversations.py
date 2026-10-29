"""Which conversation each agent pane that tuitp resume starts takes again. No TUIOS, Claude or Codex runs."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
from tuitp_conversations import conversation_plan
from tuitp_model import read_list

SAVED = time.time() - 3600  # When TUIOS last saved the sessions, before the restart.
PAST = SAVED - 7200


def uuid(n):
    return f"{n:08x}-0000-4000-8000-000000000000"


def iso(when):
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(when))


class Profiles(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="tuitp-conversations-")
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name).resolve()
        self.local, self.profile = self.base / "local", self.base / "profile"
        environ = {name: value for name, value in os.environ.items() if name not in ("CLAUDE_CONFIG_DIR", "CODEX_HOME")}
        environ.update(LOCALAPPDATA=str(self.local), USERPROFILE=str(self.profile))
        patcher = patch.dict(os.environ, environ, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.folder = self.repo("project one")
        self.other = self.repo("other")

    def repo(self, name):
        folder = self.base / name
        folder.mkdir()
        return folder

    def layout(self, text):
        path = self.base / "tuitp.list"
        path.write_text(text.replace("FOLDER", str(self.folder)).replace("OTHER", str(self.other)), encoding="utf-8")
        return read_list(path)

    def plan(self, text):
        layout = self.layout(text)
        return conversation_plan(layout, list(layout.sessions.values()))

    def tuios(self, name, *windows, saved=SAVED):
        path = self.local / "tuios" / "sessions" / f"{name}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"name": name, "windows": list(windows)}), encoding="utf-8")
        os.utime(path, (saved, saved))

    def claude(self, folder, conversation, active, started=None, entrypoint="cli", prompt="Fix the parser",
               titles=()):
        place = self.profile / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(folder))
        place.mkdir(parents=True, exist_ok=True)
        lines = [{"type": "permission-mode", "permissionMode": "default"},
                 {"type": "user", "entrypoint": entrypoint, "timestamp": iso(started or active - 60),
                  "cwd": str(folder), "message": {"role": "user", "content": prompt}}]
        lines += [{"type": kind, key: value} for kind, key, value in titles]
        path = place / f"{conversation}.jsonl"
        path.write_text("".join(json.dumps(line) + "\n" for line in lines), encoding="utf-8")
        os.utime(path, (active, active))
        return path

    def codex_database(self, *threads):
        home = self.profile / ".codex"
        home.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(home / "state_5.sqlite")
        connection.execute("CREATE TABLE threads (id TEXT PRIMARY KEY, rollout_path TEXT NOT NULL, created_at INTEGER, "
                           "updated_at INTEGER, source TEXT, cwd TEXT, title TEXT, archived INTEGER DEFAULT 0, "
                           "thread_source TEXT, name TEXT, originator TEXT)")
        for thread in threads:
            row = {"rollout_path": "", "source": "vscode", "thread_source": "user", "originator": "codex-tui",
                   "title": "$llm-shared:resume-session", "archived": 0, **thread}
            connection.execute(f"INSERT INTO threads ({', '.join(row)}) VALUES ({', '.join('?' * len(row))})",
                               list(row.values()))
        connection.commit()
        connection.close()

    def thread(self, n, active, folder=None, started=None, **fields):
        return {"id": uuid(n), "cwd": "\\\\?\\" + str(folder or self.folder), "updated_at": int(active),
                "created_at": int(started or active - 60), **fields}

    def rollout(self, n, started, folder=None, **payload):
        stamp = time.strftime("%Y-%m-%dT%H-%M-%S", time.localtime(started))
        path = self.profile / ".codex" / "sessions" / stamp[:4] / stamp[5:7] / stamp[8:10] / \
            f"rollout-{stamp}-{uuid(n)}.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        meta = {"id": uuid(n), "timestamp": iso(started), "cwd": str(folder or self.folder),
                "originator": "codex-tui", "source": "cli", "thread_source": "user", **payload}
        prompt = {"type": "response_item", "payload": {"type": "message", "role": "user", "content": [
            {"type": "input_text", "text": "# AGENTS.md instructions for the project"},
            {"type": "input_text", "text": "<environment_context>...</environment_context>"},
            {"type": "input_text", "text": f"Thread {n} prompt\nwith a second line"}]}}
        path.write_text(json.dumps({"type": "session_meta", "payload": meta}) + "\n" + json.dumps(prompt) + "\n",
                        encoding="utf-8")
        return path


class ClaudeTests(Profiles):
    def test_a_claude_pane_resumes_what_tuios_recorded_for_it(self):
        self.claude(self.folder, uuid(1), PAST, titles=[("ai-title", "aiTitle", "Old title"),
                                                         ("custom-title", "customTitle", "Renamed"),
                                                         ("ai-title", "aiTitle", "Newer AI title")])
        self.claude(self.folder, uuid(2), SAVED - 60)  # Newer, but another pane's or none.
        self.tuios("one", {"custom_name": "Claude pdf", "agent_session_id": uuid(1),
                           "agent_session_harness": "claude-code"}, {"custom_name": "CMD"})
        deliveries, lines = self.plan("=== A\n+ FOLDER|one|claude|pdf")
        self.assertEqual(deliveries, [{"session": "one", "window": "Claude pdf", "resume": uuid(1)}])
        # A title the person gave wins over Claude's own.
        self.assertRegex(lines[0], rf"^RESUME Claude pdf of session one: claude --resume {uuid(1)}, 'Renamed', "
                                   r"last active \d{4}-\d\d-\d\d \d\d:\d\d \(TUIOS recorded it in this pane\)$")

    def test_a_recorded_conversation_without_transcript_starts_a_new_one(self):
        self.claude(self.folder, uuid(2), PAST, prompt="Range confirmed?")
        self.tuios("one", {"custom_name": "Claude", "agent_session_id": uuid(1),
                           "agent_session_harness": "claude-code"})
        deliveries, lines = self.plan("=== A\n+ FOLDER|one|claude")
        self.assertEqual(deliveries, [])
        self.assertIn(f"NOTE Claude of session one starts a new conversation: the one TUIOS recorded there, "
                      f"{uuid(1)}, has no transcript, so it never got a message; the newest Claude conversation of "
                      f"its folder is {uuid(2)}, 'Range confirmed?', last active", lines[0])
        self.assertTrue(lines[0].endswith(f": claude --resume {uuid(2)} in that pane resumes it"))

    def test_without_a_record_the_newest_terminal_conversation_of_the_folder_not_taken(self):
        self.claude(self.folder, uuid(1), SAVED - 10, entrypoint="sdk-cli")  # claude -p, from a script.
        self.claude(self.folder, uuid(2), SAVED + 600, started=SAVED + 60)  # Started after the restart.
        self.claude(self.folder, uuid(3), SAVED - 30)  # The other pane's.
        self.claude(self.folder, uuid(4), SAVED - 40,
                    prompt="<command-message>review-resume</command-message>\n"
                           "<command-name>/review-resume</command-name>\n<command-args>as reviewer</command-args>")
        self.claude(self.other, uuid(5), SAVED - 20)  # Another folder's.
        self.tuios("one", {"custom_name": "Claude", "agent_state": "idle"})
        self.tuios("two", {"custom_name": "Claude", "agent_session_id": uuid(3),
                           "agent_session_harness": "claude-code"})
        deliveries, lines = self.plan("=== A\n+ FOLDER|one|claude\n=== B\n+ FOLDER|two|claude")
        self.assertEqual([d["resume"] for d in deliveries], [uuid(4), uuid(3)])
        self.assertIn(f"RESUME Claude of session one: claude --resume {uuid(4)}, '/review-resume as reviewer', "
                      "last active", lines[0])
        self.assertTrue(lines[0].endswith("(the newest Claude conversation of its folder)"))

    def test_no_conversation_and_ids_that_cmd_must_never_receive(self):
        self.tuios("one", {"custom_name": "Claude", "agent_session_id": "x & del *",
                           "agent_session_harness": "claude-code"})
        deliveries, lines = self.plan("=== A\n+ FOLDER|one|claude")
        self.assertEqual(deliveries, [])
        self.assertEqual(lines, [f"NOTE Claude of session one starts a new conversation: no Claude conversation "
                                 f"started in {self.folder} before its session was saved"])

    def test_a_renamed_pane_and_a_session_without_agents(self):
        self.claude(self.folder, uuid(1), PAST)
        self.tuios("one", {"custom_name": "Claude old", "agent_session_id": uuid(1),
                           "agent_session_harness": "claude-code"})
        deliveries, _ = self.plan("=== A\n+ FOLDER|one|claude|new")
        self.assertEqual(deliveries, [{"session": "one", "window": "Claude new", "resume": uuid(1)}])
        self.assertEqual(self.plan("=== A\n+ FOLDER|shell|single")[1],
                         ["NOTE no agent pane starts: tuitp resume resumes the agents of the sessions it creates "
                          "or restores, and keeps the running ones as they are"])


class CodexTests(Profiles):
    def threads(self):
        self.codex_database(
            self.thread(1, SAVED - 100),  # The newest of the folder.
            self.thread(2, SAVED - 500),  # Its last activity is the pane's.
            self.thread(3, SAVED - 900, name="Fix the parser"),
            self.thread(4, SAVED - 1300),
            self.thread(10, SAVED - 10, source='{"subagent":{}}', thread_source="subagent"),
            self.thread(11, SAVED - 10, source="exec", originator="codex_exec"),
            self.thread(12, SAVED - 10, originator="codex_vscode"),
            self.thread(13, SAVED - 10, archived=1),
            self.thread(14, SAVED - 10, folder=self.other),
            self.thread(15, SAVED + 100, started=SAVED + 50))  # Started after the restart.

    def test_a_codex_pane_takes_the_thread_of_its_activity_then_of_its_title_then_the_newest(self):
        self.threads()
        cases = [({"program_status": [{"app": "codex", "at": int((SAVED - 500) * 1e9)}],
                   "agent_state_at": int((SAVED - 100) * 1e9)}, 2, "its last activity is the pane's"),
                 ({"title": "Fix the parser | project one", "agent_state_at": int(PAST * 1e9)}, 3,
                  "the pane's title names it"),
                 ({"title": "Another thread | project one"}, 1,
                  "the newest Codex thread of its folder, though the pane's title named 'Another thread'"),
                 ({"title": "project one"}, 1, "the newest Codex thread of its folder")]
        for window, expected, how in cases:
            with self.subTest(window=window):
                self.tuios("one", {"custom_name": "Codex", **window})
                deliveries, lines = self.plan("=== A\n+ FOLDER|one|codex")
                self.assertEqual(deliveries, [{"session": "one", "window": "Codex", "resume": uuid(expected)}])
                self.assertTrue(lines[0].startswith(f"RESUME Codex of session one: codex resume {uuid(expected)}, '"))
                self.assertTrue(lines[0].endswith(f"({how})"), lines[0])

    def test_panes_on_one_folder_resume_different_threads_and_a_title_comes_from_the_index(self):
        self.threads()
        (self.profile / ".codex" / "session_index.jsonl").write_text(
            json.dumps({"id": uuid(1), "thread_name": "First name"}) + "\n"
            + json.dumps({"id": uuid(1), "thread_name": "Renamed"}) + "\n", encoding="utf-8")
        for name in ("one", "two"):
            self.tuios(name, {"custom_name": "Codex"})
        deliveries, lines = self.plan("=== A\n+ FOLDER|one\n=== B\n+ FOLDER|two|codex")
        self.assertEqual([(d["window"], d["resume"]) for d in deliveries], [("Codex", uuid(1)), ("Codex", uuid(2))])
        self.assertIn(f"codex resume {uuid(1)}, 'Renamed', last active", lines[-2])
        # Without any Claude conversation, the project's Claude starts a new one.
        self.assertTrue(lines[0].startswith("NOTE Claude of session one starts a new conversation"))

    def test_without_its_database_codex_reads_the_rollouts_by_start(self):
        self.rollout(1, SAVED - 100)
        self.rollout(2, SAVED - 50, source={"subagent": {}}, thread_source="subagent")
        self.rollout(3, SAVED - 40, originator="codex_exec", source="exec")
        self.rollout(4, SAVED + 60)  # Started after the restart.
        self.rollout(5, SAVED - 30, folder=self.other)
        self.rollout(6, PAST)
        (self.profile / ".codex" / "state_5.sqlite").write_bytes(b"not a database")
        for name in ("one", "two", "three"):
            self.tuios(name, {"custom_name": "Codex"})
        deliveries, lines = self.plan("=== A\n+ FOLDER|one|codex\n=== B\n+ FOLDER|two|codex\n=== C\n+ OTHER|three|codex")
        self.assertEqual([d["resume"] for d in deliveries], [uuid(1), uuid(6), uuid(5)])
        self.assertIn(f"codex resume {uuid(1)}, 'Thread 1 prompt', last active", lines[0])
        self.assertTrue(lines[0].endswith("(the newest Codex thread of its folder)"))

    def test_no_thread_names_the_days_read_without_a_database(self):
        deliveries, lines = self.plan("=== A\n+ FOLDER|one|codex")
        self.assertEqual(deliveries, [])
        self.assertEqual(lines, [f"NOTE Codex of session one starts a new conversation: no Codex thread of the "
                                 f"last 30 days started in {self.folder} before its session was saved"])


if __name__ == "__main__":
    unittest.main()
