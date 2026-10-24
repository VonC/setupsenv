"""Behavioral tests: no real WT windows, agents or TUIOS sessions are launched."""
from __future__ import annotations

import contextlib
import copy
from dataclasses import asdict
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
import tuitp
import tuitp_host
import tuitp_windows
from tuitp_install import FILES, LEGACY_DIR, adopt_legacy, install, legacy_layout
from tuitp_model import Tab, key, new_state, read_list, reconcile_plan
from tuitp_windows import Windows, alive, daemon_environment, identity, run, write_json


class FakeWindows:
    def __init__(self):
        self.scripts = Path(r"C:\Tools with spaces\bin")
        self.cmd = Path(r"C:\Windows\System32\cmd.exe")
        self.events, self.hosts = [], set()
        self.live = {}
        self.panes = {}  # Session name -> its pane names, in window order.
        self.daemon_live = False
        self.watching = False  # Whether the tab watcher runs.
        self.codex_running = False  # Whether a Codex app-server daemon runs.
        self.codex_clients = {}  # Session name -> its Codex processes.
        self.codex_others = 0  # Codex processes outside every session.
        self.fail = None
        self.lock = threading.Lock()

    def validate(self, need_tuios):
        pass

    def pane_helper(self):
        return Path(r"C:\Local App Data\tuitp\panes\tuitp.pane.0123456789ab.bat")

    def write_claude_hooks(self):
        self.events.append(("claude-hooks",))

    def pane_names(self, session):
        return set(self.panes.get(session, []))

    def ensure_watcher(self):
        started, self.watching = not self.watching, True
        return started

    def stop_watcher(self):
        stopped, self.watching = self.watching, False
        return stopped

    def snapshot(self):
        return copy.deepcopy(self.live)

    def codex_daemon(self, sessions):
        if not self.codex_running:
            return None  # A read-only check: recorded only to order it among changes.
        self.events.append(("codex-check", *sessions))
        inside = sum(self.codex_clients.get(name, 0) for name in sessions)
        everywhere = self.codex_others + sum(self.codex_clients.get(name, 0) for name in self.live)
        return {"updater": [{"pid": 2, "created": 2}], "daemon": [{"pid": 1, "created": 1}],
                "inside": inside, "outside": everywhere - inside}

    def stop_codex_daemon(self, found):
        self.events.append(("codex-stop", found["daemon"][0]["pid"]))
        self.codex_running = False

    def tab_alive(self, record):
        return record.get("token") in self.hosts

    def open_tab(self, record):
        self.events.append(("open", record["spec"]["window"], record["spec"]["title"]))
        self.hosts.add(record["token"])

    def close_tab(self, record):
        self.events.append(("close", record["spec"]["window"], record["spec"]["title"]))
        self.hosts.discard(record["token"])

    def release_tab(self, record):
        self.events.append(("release", record["spec"]["title"]))

    def verify_tabs(self, records):
        self.events.append(("verify",))

    def ensure_daemon(self):
        self.events.append(("daemon",))
        self.daemon_live = True
        for row in self.live.values():  # Starting the daemon restores saved sessions.
            row["saved"] = False

    def fail_tabs(self, records, message):
        self.events.append(("error", message))

    def command(self, *args):
        with self.lock:
            self.events.append(args)
            if self.fail and self.fail(args):
                raise RuntimeError("simulated native command failure")
            if args[0] == "new":
                if args[1] in self.live:
                    raise AssertionError("duplicate session creation")
                self.live[args[1]] = {"name": args[1], "saved": False}
                self.panes[args[1]] = ["cmd"]
            if args[0] in ("set-window", "send-text", "send-keys"):
                # Like TUIOS, address a pane by its index or its name.
                session, window = args[args.index("-s") + 1], args[args.index("-w") + 1]
                names = self.panes.get(session, [])
                if window not in names and not (window.isdigit() and int(window) < len(names)):
                    raise RuntimeError(f"no window {window!r} in session {session}")
                if args[0] == "set-window":
                    names[int(window) if window.isdigit() else names.index(window)] = args[args.index("--name") + 1]
            if args[0] == "new-window":
                self.panes[args[args.index("-s") + 1]].append(args[1])
            if args[0] == "kill-session":
                del self.live[args[1]]
                self.panes.pop(args[1], None)
            if args[0] == "kill-server":
                self.daemon_live = False
                for row in self.live.values():  # The daemon saves what it still holds.
                    row["saved"] = True
        return ""


class ReconciliationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tuitp-test-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.project = self.folder / "project with spaces"
        self.project.mkdir()
        self.path = self.folder / "tuitp.list"
        self.runtime, self.state = FakeWindows(), new_state()
        self.saved = None

    def layout(self, text):
        self.path.write_text(text.replace("FOLDER", str(self.project)), encoding="utf-8")
        return read_list(self.path)

    def apply(self, text, dry=False):
        layout = self.layout(text)
        def save(state):
            self.saved = copy.deepcopy(state)
        tuitp.apply_layout(layout, self.state, copy.deepcopy(self.runtime.live), self.runtime, save, dry)
        return layout

    def events(self, name):
        return [e for e in self.runtime.events if e[0] == name]

    def main(self, *argv):
        """Run the command line against the fake runtime, with the state file under the test folder."""
        out = io.StringIO()
        with patch.dict(os.environ, {"LOCALAPPDATA": str(self.folder)}), \
                patch("tuitp.Windows", return_value=self.runtime), patch("tuitp.adopt_legacy", return_value=False), \
                patch("tuitp.launcher_lock", contextlib.nullcontext), contextlib.redirect_stdout(out):
            # Run from a TUIOS pane, stop would start a real one outside it.
            for name in [name for name in os.environ if name.startswith("TUIOS_")]:
                del os.environ[name]
            code = tuitp.main(list(argv))
        return code, out.getvalue()

    def owned_by_another_list(self):
        self.apply("=== Projects\n+ FOLDER|one\n+ FOLDER|two\n=== Test\n+ FOLDER|test|single")
        self.runtime.live["unrelated"] = {"name": "unrelated", "saved": False}
        self.state_file = self.folder / "tuitp" / "state.json"
        write_json(self.state_file, self.state)
        self.runtime.events.clear()

    def test_mixed_list_and_environment_expansion(self):
        with patch.dict(os.environ, {"TUITP_TEST_PATH": str(self.project)}):
            layout = self.layout("# comment\n--- work\n%TUITP_TEST_PATH%|Shell\n=== Projects\n+ FOLDER|one\n+ FOLDER|two|single\n--- side\nFOLDER\n")
        self.assertEqual([t.kind for t in layout.tabs], ["cmd", "tuios", "cmd"])
        self.assertEqual(layout.tabs[1].sessions, ["one", "two"])
        self.assertEqual(layout.sessions["two"].kind, "single")
        self.assertEqual(layout.tabs[2].window, "side")

    def test_invalid_lists_fail_before_mutation(self):
        cases = ["+ FOLDER|one", "=== Empty", "=== A\n+ FOLDER|same\n=== B\n+ FOLDER|same",
                 "=== A\n+ FOLDER|bad name", "=== A\n+ FOLDER|one|invalid",
                 "--- bad window\nFOLDER", "=== A\n+ %TUITP_UNDEFINED%|one",
                 "=== A\n+ FOLDER|one\n=== A\n+ FOLDER|two", "FOLDER|a|b", "FOLDER&whoami"]
        for text in cases:
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.apply(text)
        self.assertFalse(self.runtime.events)

    def test_cold_phases_and_three_workspaces(self):
        self.apply("=== Projects\n+ FOLDER|one\n+ FOLDER|two|single")
        names = [e[0] for e in self.runtime.events]
        self.assertLess(names.index("open"), names.index("new"))
        self.assertLess(max(i for i, n in enumerate(names) if n == "new"), names.index("set-window"))
        self.assertLess(max(i for i, n in enumerate(names) if n == "new-window"), names.index("send-text"))
        self.assertEqual(len(self.events("new-window")), 2)
        self.assertEqual(len(self.events("send-text")), 4)
        self.assertTrue(all(s["status"] == "ready" for s in self.saved["sessions"].values()))
        for event in self.events("send-text"):
            self.assertEqual(len(event), 6)
            self.assertTrue(event[-1].startswith(f'call "{self.runtime.pane_helper()}" '))
            self.assertIn("project with spaces", event[-1])

    def test_claude_hooks_are_written_before_any_change_only_for_new_claude_panes(self):
        self.apply("=== Projects\n+ FOLDER|one\n=== Solo\n+ FOLDER|solo|codex")
        self.assertEqual(self.runtime.events[0], ("claude-hooks",))
        self.assertEqual(len(self.events("claude-hooks")), 1)
        self.runtime.events.clear()
        self.apply("=== Projects\n+ FOLDER|one\n=== Solo\n+ FOLDER|solo|codex")
        self.assertFalse(self.events("claude-hooks"))
        # Codex and CMD panes never load the hooks.
        self.apply("=== Projects\n+ FOLDER|one\n=== Solo\n+ FOLDER|solo|codex\n+ FOLDER|shell|senv")
        self.assertFalse(self.events("claude-hooks"))
        self.apply("=== Projects\n+ FOLDER|one\n=== Solo\n+ FOLDER|solo|codex\n+ FOLDER|shell|senv\n+ FOLDER|cl|claude")
        self.assertEqual(len(self.events("claude-hooks")), 1)

    def test_failed_claude_hooks_still_start_the_panes(self):
        out = io.StringIO()
        with patch.object(self.runtime, "write_claude_hooks", side_effect=RuntimeError("no hooks")), \
                contextlib.redirect_stdout(out):
            self.apply("=== Projects\n+ FOLDER|one")
        self.assertIn("tuitp: Claude panes start without TUIOS agent hooks: no hooks", out.getvalue())
        self.assertEqual([e[4] for e in self.events("send-text")], ["Claude", "Codex", "CMD"])
        self.assertEqual(self.saved["sessions"]["one"]["status"], "ready")

    def test_repeat_has_no_session_or_tab_mutations(self):
        text = "=== Projects\n+ FOLDER|one"
        self.apply(text)
        self.runtime.events.clear()
        self.apply(text)
        self.assertFalse(self.events("new") + self.events("open") + self.events("close") + self.events("send-text"))

    def test_one_pane_kinds_initialize_only_the_selected_role_and_remain_idempotent(self):
        for kind, role in (("claude", "Claude"), ("codex", "Codex"), ("senv", "CMD"), ("single", "CMD")):
            with self.subTest(kind=kind):
                self.runtime, self.state = FakeWindows(), new_state()
                text = f"=== Test\n+ FOLDER|test|{kind}"
                self.apply(text)
                self.assertEqual(self.events("set-window"), [("set-window", "-s", "test", "-w", "0", "--name", role)])
                self.assertFalse(self.events("new-window"))
                startup = self.events("send-text")
                self.assertEqual(len(startup), 1)
                self.assertEqual(startup[0][4], role)
                self.assertTrue(startup[0][-1].endswith(f" {role.lower()} local-or-global"))
                self.runtime.events.clear()
                self.apply(text)
                self.assertFalse(self.events("new") + self.events("open") + self.events("send-text"))

    def test_single_and_senv_spellings_reuse_the_same_session(self):
        self.apply("=== Test\n+ FOLDER|test|single")
        self.runtime.events.clear()
        self.apply("=== Test\n+ FOLDER|test|senv")
        self.assertFalse(self.events("new") + self.events("open") + self.events("send-text"))

    def test_list_id_names_the_agent_panes_and_keeps_empty_fields_default(self):
        (self.folder / "web-app").mkdir()
        layout = self.layout(f"=== P\n+ FOLDER|one||pdf\n+ {self.folder / 'web-app'}|||web\n+ FOLDER|cl|claude|t\n"
                             "+ FOLDER|sh|senv|x")
        self.assertEqual([(s.name, s.kind, s.id) for s in layout.sessions.values()],
                         [("one", "project", "pdf"), ("web-app", "project", "web"), ("cl", "claude", "t"),
                          ("sh", "single", "x")])
        for bad in ("+ FOLDER|one|project|p d", "+ FOLDER|one|project|pdf|extra"):
            with self.subTest(line=bad), self.assertRaises(ValueError):
                self.layout("=== P\n" + bad)
        self.apply("=== P\n+ FOLDER|one||pdf\n=== C\n+ FOLDER|cl|claude|t\n+ FOLDER|sh|senv|x")
        self.assertEqual(self.runtime.panes["one"], ["Claude pdf", "Codex pdf", "CMD"])
        self.assertEqual(self.runtime.panes["cl"], ["Claude t"])
        self.assertEqual(self.runtime.panes["sh"], ["CMD"])  # CMD panes keep their name.
        self.assertEqual(sorted(e[4] for e in self.events("send-text")),
                         ["CMD", "CMD", "Claude pdf", "Claude t", "Codex pdf"])
        self.assertEqual({name: s["id"] for name, s in self.state["sessions"].items()},
                         {"one": "pdf", "cl": "t", "sh": "x"})

    def test_new_id_renames_running_panes_in_place(self):
        self.apply("=== P\n+ FOLDER|one")
        out = io.StringIO()
        for old, new in (("", "pdf"), ("pdf", "pds"), ("pds", "")):
            with self.subTest(old=old, new=new):
                self.runtime.events.clear()
                with contextlib.redirect_stdout(out):
                    self.apply(f"=== P\n+ FOLDER|one||{new}")
                rename = (lambda role: f"{role} {new}".strip())
                self.assertEqual(self.events("set-window"),
                                 [("set-window", "-s", "one", "-w", f"{role} {old}".strip(), "--name", rename(role))
                                  for role in ("Claude", "Codex")])
                self.assertFalse(self.events("new") + self.events("kill-session") + self.events("send-text"))
                self.assertEqual(self.runtime.panes["one"], [rename("Claude"), rename("Codex"), "CMD"])
                self.assertEqual(self.state["sessions"]["one"]["id"], new)
        self.assertIn("RENAME panes of session one: Claude -> Claude pdf, Codex -> Codex pdf", out.getvalue())
        self.runtime.events.clear()
        self.apply("=== P\n+ FOLDER|one")
        self.assertFalse(self.events("set-window"))

    def test_panes_named_by_hand_or_missing_are_left_as_they_are(self):
        self.apply("=== P\n+ FOLDER|one\n+ FOLDER|two")
        self.runtime.panes["one"] = ["Claude pdf", "Codex pdf", "CMD"]  # Renamed with tuios set-window.
        self.runtime.panes["two"] = ["Claude", "CMD"]  # Its Codex pane was closed.
        self.runtime.events.clear()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.apply("=== P\n+ FOLDER|one||pdf\n+ FOLDER|two||web")
        self.assertEqual(self.events("set-window"), [("set-window", "-s", "two", "-w", "Claude", "--name", "Claude web")])
        self.assertIn("tuitp: session two has no Codex pane to name Codex web", out.getvalue())
        self.assertEqual({name: s["id"] for name, s in self.state["sessions"].items()}, {"one": "pdf", "two": "web"})

    def test_restored_session_is_renamed_before_its_panes_start(self):
        self.runtime.live["saved"] = {"name": "saved", "saved": True}
        self.runtime.panes["saved"] = ["Claude", "Codex", "CMD"]
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.apply("=== Restored\n+ FOLDER|saved||pdf", dry=True)
        self.assertIn("[dry] RENAME panes of session saved: Claude -> Claude pdf, Codex -> Codex pdf", out.getvalue())
        self.assertFalse(self.runtime.events)
        self.apply("=== Restored\n+ FOLDER|saved||pdf")
        names = [e[0] for e in self.runtime.events]
        self.assertLess(names.index("daemon"), names.index("set-window"))
        self.assertLess(max(i for i, n in enumerate(names) if n == "set-window"), names.index("send-text"))
        self.assertEqual([e[4] for e in self.events("send-text")], ["Claude pdf", "Codex pdf", "CMD"])
        self.assertEqual(self.state["sessions"]["saved"]["id"], "pdf")

    def test_existing_single_session_is_not_replaced_by_claude_implicitly(self):
        self.apply("=== Test\n+ FOLDER|test|single")
        self.runtime.events.clear()
        with self.assertRaisesRegex(ValueError, "different folder/layout"):
            self.apply("=== Test\n+ FOLDER|test|claude")
        self.assertFalse(self.runtime.events)

    def test_add_session_does_not_recreate_existing_tab(self):
        self.apply("=== Projects\n+ FOLDER|one")
        self.runtime.events.clear()
        self.apply("=== Projects\n+ FOLDER|one\n+ FOLDER|two")
        self.assertEqual([e[1] for e in self.events("new")], ["two"])
        self.assertFalse(self.events("open") + self.events("close"))

    def test_move_opens_destination_then_closes_source_and_preserves_sessions(self):
        self.apply("--- first\n=== Projects\n+ FOLDER|one\n+ FOLDER|two")
        self.runtime.events.clear()
        self.apply("--- second\n=== Projects\n+ FOLDER|one\n+ FOLDER|two")
        self.assertEqual(self.events("open"), [("open", "second", "Projects")])
        self.assertEqual(self.events("close"), [("close", "first", "Projects")])
        self.assertLess(self.runtime.events.index(self.events("open")[0]), self.runtime.events.index(self.events("close")[0]))
        self.assertFalse(self.events("new") + self.events("kill-session") + self.events("send-text"))
        self.assertEqual(len(self.state["tabs"]), 1)

    def test_move_one_session_between_groups_keeps_unaffected_tab(self):
        self.apply("--- first\n=== A\n+ FOLDER|one\n+ FOLDER|two\n--- second\n=== B\n+ FOLDER|three")
        self.runtime.events.clear()
        self.apply("--- first\n=== A\n+ FOLDER|one\n--- second\n=== B\n+ FOLDER|three\n+ FOLDER|two")
        self.assertFalse(self.events("new") + self.events("kill-session") + self.events("open") + self.events("close"))

    def test_removed_sessions_deleted_only_after_tab_closed(self):
        self.runtime.live["unrelated"] = {"name": "unrelated"}
        self.apply("=== A\n+ FOLDER|one\n=== B\n+ FOLDER|two|single")
        self.runtime.events.clear()
        self.apply("=== A\n+ FOLDER|one")
        self.assertEqual(self.events("kill-session"), [("kill-session", "two")])
        self.assertIn("unrelated", self.runtime.live)
        self.assertLess(self.runtime.events.index(self.events("close")[0]), self.runtime.events.index(self.events("kill-session")[0]))

    def test_empty_valid_list_removes_only_owned_entries(self):
        self.runtime.live["unrelated"] = {"name": "unrelated"}
        self.apply("=== A\n+ FOLDER|one")
        self.apply("# deliberately empty\n")
        self.assertEqual(self.state, new_state())
        self.assertEqual(list(self.runtime.live), ["unrelated"])

    def test_tab_watcher_runs_while_tuios_tabs_exist(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.apply("=== Projects\n+ FOLDER|one", dry=True)
            self.assertFalse(self.runtime.watching)
            self.apply("=== Projects\n+ FOLDER|one")
            self.assertTrue(self.runtime.watching)
            self.apply("=== Projects\n+ FOLDER|one")
            self.assertEqual(out.getvalue().count("Started the tab watcher"), 1)
            self.apply("FOLDER|Shell")  # A plain CMD tab has no rail.
            self.assertFalse(self.runtime.watching)
            self.assertIn("Stopped the tab watcher.", out.getvalue())
            with patch.dict(os.environ, {"TUITP_WATCH": "0"}):
                self.apply("=== Projects\n+ FOLDER|one")
            self.assertFalse(self.runtime.watching)

    def test_failed_tab_watcher_leaves_the_reconciliation_done(self):
        self.runtime.ensure_watcher = Mock(side_effect=OSError("no python"))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.apply("=== Projects\n+ FOLDER|one")
        self.assertIn("tuitp: tab watcher: no python", out.getvalue())
        self.assertIn("Reconciled in", out.getvalue())
        self.assertEqual(self.saved["sessions"]["one"]["status"], "ready")

    def test_stop_ignores_the_list_and_leaves_no_tab_session_or_daemon(self):
        self.owned_by_another_list()
        # The current list has another structure: stop must neither read nor apply it.
        self.path.write_text(f"=== One\n+ {self.project}|one\n=== New\n+ {self.project}|three\n", encoding="utf-8")
        code, out = self.main("stop", "--list", str(self.path))
        self.assertEqual(code, 0)
        self.assertEqual(sorted(e[2] for e in self.events("close")), ["Projects", "Test"])
        self.assertEqual(sorted(e[1] for e in self.events("kill-session")), ["one", "test", "two", "unrelated"])
        self.assertFalse(self.events("open") + self.events("new") + self.events("send-text"))
        self.assertLess(max(self.runtime.events.index(e) for e in self.events("close")),
                        self.runtime.events.index(self.events("kill-session")[0]))
        # kill-server saves what the daemon still holds: every session is gone first.
        self.assertEqual(self.runtime.events[-1], ("kill-server",))
        self.assertEqual(self.runtime.live, {})
        self.assertFalse(self.runtime.daemon_live)
        self.assertFalse(self.runtime.watching)
        self.assertEqual(json.loads(self.state_file.read_text()), new_state())
        self.assertIn("DELETE session unrelated and its running processes, though tuitp did not start it", out)
        self.assertIn("STOP the TUIOS daemon", out)
        self.assertNotIn("New pane startup commands submitted", out)

    def test_dry_stop_previews_without_a_list_and_changes_nothing(self):
        self.owned_by_another_list()
        before = self.state_file.read_text()
        code, out = self.main("stop", "dry", "--list", str(self.folder / "missing.list"))
        self.assertEqual(code, 0)
        for line in ("CLOSE tab Projects", "CLOSE tab Test", "DELETE session one and its running processes\n",
                     "DELETE session two", "DELETE session test",
                     "DELETE session unrelated and its running processes, though tuitp did not start it",
                     "STOP the TUIOS daemon"):
            self.assertIn("[dry] " + line, out)
        self.assertNotIn("DELETE session one and its running processes, though", out)
        self.assertNotIn("No list at", out)
        self.assertFalse(self.runtime.events)
        self.assertEqual(self.state_file.read_text(), before)

    def test_stop_restores_saved_sessions_to_delete_them(self):
        # No daemon runs, after a reboot or a kill-server: TUIOS still lists the
        # sessions it saved, and the next daemon would restore them with bare shells.
        self.runtime.live = {name: {"name": name, "saved": True} for name in ("old", "older")}
        code, out = self.main("stop")
        self.assertEqual(code, 0)
        steps = [e for e in self.runtime.events if e[0] in ("daemon", "kill-session", "kill-server")]
        self.assertEqual(steps, [("daemon",), ("kill-session", "old"), ("kill-session", "older"), ("kill-server",)])
        self.assertEqual(self.runtime.live, {})
        self.assertIn("DELETE session old and its running processes, though tuitp did not start it", out)

    def test_stop_without_sessions_or_daemon_starts_nothing(self):
        code, out = self.main("stop")
        self.assertEqual(code, 0)
        self.assertFalse(self.events("daemon") + self.events("kill-session") + self.events("kill-server"))
        self.assertNotIn("STOP the TUIOS daemon", out)

    def test_stop_fails_when_a_session_survives(self):
        self.owned_by_another_list()
        command = self.runtime.command

        def kill_fails_silently(*args):
            if args == ("kill-session", "unrelated"):
                return ""
            return command(*args)

        err = io.StringIO()
        with patch.object(self.runtime, "command", side_effect=kill_fails_silently), contextlib.redirect_stderr(err):
            code, out = self.main("stop")
        self.assertEqual(code, 1)
        self.assertIn("TUIOS still lists sessions after stop: unrelated", err.getvalue())
        self.assertNotIn("No TUIOS session or daemon left", out)

    def test_stop_in_a_tuios_pane_goes_on_outside_it(self):
        self.owned_by_another_list()
        before = self.state_file.read_text()
        pane = {"LOCALAPPDATA": str(self.folder), "TUIOS_ENV": "1", "TUIOS_SESSION": "one",
                "TUIOS_SOCKET": r"C:\sock", "TUIOS_PANE_TOKEN": "secret"}
        out = io.StringIO()
        with patch.dict(os.environ, pane), patch("tuitp.Windows", return_value=self.runtime), \
                patch("tuitp.subprocess.Popen") as popen, contextlib.redirect_stdout(out):
            code = tuitp.main(["stop"])
        self.assertEqual(code, 0)
        argv, kwargs = popen.call_args.args[0], popen.call_args.kwargs
        self.assertEqual(argv, [sys.executable, str(Path(tuitp.__file__).resolve().parent / "tuitp.py"), "stop"])
        self.assertFalse([name for name in kwargs["env"] if name.startswith("TUIOS_")])
        self.assertTrue(kwargs["creationflags"] & subprocess.CREATE_BREAKAWAY_FROM_JOB)
        self.assertTrue(kwargs["creationflags"] & subprocess.DETACHED_PROCESS)
        self.assertIn(str(self.folder / "tuitp" / "stop.log"), out.getvalue())
        self.assertFalse(self.runtime.events)
        self.assertEqual(self.state_file.read_text(), before)
        # A preview changes nothing, so it runs in the pane as it is.
        with patch.dict(os.environ, pane), patch("tuitp.Windows", return_value=self.runtime), \
                patch("tuitp.adopt_legacy", return_value=False), patch("tuitp.launcher_lock", contextlib.nullcontext), \
                patch("tuitp.subprocess.Popen") as popen, contextlib.redirect_stdout(io.StringIO()) as dry_out:
            self.assertEqual(tuitp.main(["dry", "stop"]), 0)
        popen.assert_not_called()
        self.assertIn("[dry] STOP the TUIOS daemon", dry_out.getvalue())

    def test_stop_named_session_closes_its_tab_deletes_it_then_reconciles(self):
        self.owned_by_another_list()
        old_token = json.loads(self.state_file.read_text())["tabs"][key("dev|tuios|Projects")]["token"]
        code, out = self.main("stop", "two", "--list", str(self.path))
        self.assertEqual(code, 0)
        events = self.runtime.events
        # Only the tab that shows two closes, before two is deleted, then both start again.
        self.assertEqual(self.events("close"), [("close", "dev", "Projects")])
        self.assertEqual(self.events("kill-session"), [("kill-session", "two")])
        self.assertEqual(self.events("open"), [("open", "dev", "Projects")])
        self.assertEqual([e[1] for e in self.events("new")], ["two"])
        self.assertLess(events.index(("close", "dev", "Projects")), events.index(("kill-session", "two")))
        self.assertLess(events.index(("kill-session", "two")), events.index(self.events("open")[0]))
        self.assertLess(events.index(("kill-session", "two")), events.index(self.events("new")[0]))
        self.assertEqual({e[2] for e in self.events("send-text")}, {"two"})
        self.assertFalse(self.events("kill-server"))
        self.assertEqual(sorted(self.runtime.live), ["one", "test", "two", "unrelated"])
        state = json.loads(self.state_file.read_text())
        self.assertNotEqual(state["tabs"][key("dev|tuios|Projects")]["token"], old_token)
        self.assertEqual(state["sessions"]["two"]["status"], "ready")
        self.assertEqual(sorted(state["sessions"]), ["one", "test", "two"])
        for line in ("CLOSE tab Projects in tuitp-dev", "DELETE session two and its running processes",
                     "OPEN tab Projects in tuitp-dev -> one, two", "CREATE session two (project)",
                     "REUSE session one", "KEEP tab Test in tuitp-dev"):
            self.assertIn(line, out)
        self.assertNotIn("STOP the TUIOS daemon", out)

    def test_dry_stop_named_session_previews_and_changes_nothing(self):
        self.owned_by_another_list()
        before = self.state_file.read_text()
        code, out = self.main("dry", "stop", "two", "--list", str(self.path))
        self.assertEqual(code, 0)
        for line in ("CLOSE tab Projects in tuitp-dev", "DELETE session two and its running processes",
                     "OPEN tab Projects in tuitp-dev -> one, two", "CREATE session two (project)"):
            self.assertIn("[dry] " + line, out)
        self.assertFalse(self.runtime.events)
        self.assertEqual(self.state_file.read_text(), before)

    def test_stop_named_session_deletes_an_undeclared_one_without_creating_it(self):
        self.owned_by_another_list()
        code, out = self.main("stop", "unrelated", "--list", str(self.path))
        self.assertEqual(code, 0)
        self.assertEqual(self.events("kill-session"), [("kill-session", "unrelated")])
        self.assertFalse(self.events("close") + self.events("open") + self.events("new"))
        self.assertEqual(sorted(self.runtime.live), ["one", "test", "two"])

    def test_stop_named_saved_session_restores_then_deletes_it(self):
        self.owned_by_another_list()
        for row in self.runtime.live.values():  # After a reboot: TUIOS lists saved sessions only.
            row["saved"] = True
        self.runtime.hosts.clear()
        code, _ = self.main("stop", "two", "--list", str(self.path))
        self.assertEqual(code, 0)
        steps = [e[:2] for e in self.runtime.events if e[0] in ("daemon", "kill-session", "new")]
        self.assertEqual(steps[0], ("daemon",))
        self.assertEqual([step for step in steps if step != ("daemon",)], [("kill-session", "two"), ("new", "two")])
        # The other declared sessions come back with bare shells: their panes start again.
        self.assertEqual({e[2] for e in self.events("send-text")}, {"one", "test", "two"})

    def test_stop_unknown_or_unreconcilable_session_changes_nothing(self):
        self.owned_by_another_list()
        before = self.state_file.read_text()
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code, _ = self.main("stop", "two", "nope", "--list", str(self.path))
        self.assertEqual(code, 1)
        self.assertIn("No session nope in the list or in TUIOS (the list declares one, two, test). Nothing changed.",
                      err.getvalue())
        # Another session left incomplete: the reconciliation would fail after two was deleted.
        state = json.loads(before)
        state["sessions"]["test"]["status"] = "initializing"
        write_json(self.state_file, state)
        with contextlib.redirect_stderr(io.StringIO()) as err:
            code, _ = self.main("stop", "two", "--list", str(self.path))
        self.assertEqual(code, 1)
        self.assertIn("Session 'test' has incomplete setup", err.getvalue())
        self.assertFalse(self.runtime.events)
        self.assertEqual(sorted(self.runtime.live), ["one", "test", "two", "unrelated"])

    def test_stop_named_session_goes_outside_only_the_pane_it_deletes(self):
        self.owned_by_another_list()
        before = self.state_file.read_text()
        pane = {"LOCALAPPDATA": str(self.folder), "TUIOS_ENV": "1", "TUIOS_SESSION": "two"}
        runs = (patch("tuitp.Windows", return_value=self.runtime), patch("tuitp.adopt_legacy", return_value=False),
                patch("tuitp.launcher_lock", contextlib.nullcontext))
        with patch.dict(os.environ, pane), runs[0], runs[1], runs[2], patch("tuitp.subprocess.Popen") as popen, \
                contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(tuitp.main(["stop", "two", "--list", str(self.path)]), 0)
        self.assertEqual(popen.call_args.args[0][2:], ["stop", "two", "--list", str(self.path.resolve())])
        self.assertIn("tuitp stop two deletes this pane's TUIOS session two: it goes on outside TUIOS", out.getvalue())
        self.assertFalse(self.runtime.events)
        self.assertEqual(self.state_file.read_text(), before)
        # From a pane of another session, it runs in place.
        pane["TUIOS_SESSION"] = "one"
        with patch.dict(os.environ, pane), runs[0], runs[1], runs[2], patch("tuitp.subprocess.Popen") as popen, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tuitp.main(["stop", "two", "--list", str(self.path)]), 0)
        popen.assert_not_called()
        self.assertEqual(self.events("kill-session"), [("kill-session", "two")])

    def test_unknown_mode_is_rejected_before_any_change(self):
        with contextlib.redirect_stderr(io.StringIO()) as err, self.assertRaises(SystemExit) as exit:
            self.main("halt")
        self.assertEqual(exit.exception.code, 2)
        self.assertIn("unknown mode halt", err.getvalue())
        self.assertFalse(self.runtime.events)

    def test_failed_setup_preserves_obsolete_tabs_and_blocks_replay(self):
        self.apply("=== Old\n+ FOLDER|old")
        self.runtime.events.clear()
        self.runtime.fail = lambda a: a[0] == "send-keys"
        with self.assertRaises(RuntimeError):
            self.apply("=== New\n+ FOLDER|new")
        self.assertFalse(self.events("close") + self.events("kill-session"))
        self.assertEqual(self.saved["sessions"]["new"]["status"], "initializing")
        self.runtime.events.clear()
        with self.assertRaisesRegex(ValueError, "incomplete"):
            self.apply("=== New\n+ FOLDER|new")
        self.assertFalse(self.runtime.events)

    def test_restored_sessions_start_their_panes_once_without_duplicate_panes(self):
        text = "=== Restored\n+ FOLDER|saved\n+ FOLDER|alone|single"
        self.runtime.live["saved"] = {"name": "saved", "saved": True}
        self.runtime.live["alone"] = {"name": "alone", "saved": True}
        # TUIOS restores the pane names a session was saved with.
        self.runtime.panes = {"saved": ["Claude", "Codex", "CMD"], "alone": ["CMD"]}
        self.apply(text)
        self.assertFalse(self.events("new") + self.events("new-window"))
        names = [e[0] for e in self.runtime.events]
        self.assertLess(names.index("daemon"), names.index("send-text"))
        commands = [e[-1] for e in self.events("send-text")]
        self.assertEqual(len(commands), 4)
        self.assertEqual(sum(c.endswith(" local-or-global") for c in commands), 1)
        self.assertEqual({s["status"] for s in self.state["sessions"].values()}, {"ready"})
        self.runtime.events.clear()
        self.apply(text)  # The daemon now runs: its sessions are reused as they are.
        self.assertFalse(self.events("send-text"))

    def test_dry_run_names_restored_sessions(self):
        self.runtime.live["saved"] = {"name": "saved", "saved": True}
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.apply("=== Restored\n+ FOLDER|saved", dry=True)
        self.assertIn("[dry] RESTORE session saved, then start its panes again", out.getvalue())
        self.assertNotIn("REUSE session saved", out.getvalue())
        self.assertFalse(self.runtime.events)

    def test_failed_restore_start_blocks_replay(self):
        self.runtime.live["saved"] = {"name": "saved", "saved": True}
        self.runtime.panes["saved"] = ["Claude", "Codex", "CMD"]
        self.runtime.fail = lambda a: a[0] == "send-keys"
        with self.assertRaises(RuntimeError):
            self.apply("=== Restored\n+ FOLDER|saved")
        self.assertEqual(self.saved["sessions"]["saved"]["status"], "initializing")

    def test_daemon_environment_drops_the_launcher_venv(self):
        venv = os.path.join("root", ".venv")
        env = {"PATH": os.pathsep.join([os.path.join(venv, "Scripts"), "other"]), "VIRTUAL_ENV": venv,
               "VIRTUAL_ENV_PROMPT": ".venv", "PROMPT": "(.venv) $P$G", "_OLD_VIRTUAL_PROMPT": "$P$G",
               "_OLD_VIRTUAL_PATH": "other", "KEEP": "1"}
        self.assertEqual(daemon_environment(env), {"PATH": "other", "PROMPT": "$P$G", "KEEP": "1"})
        del env["_OLD_VIRTUAL_PROMPT"]
        self.assertNotIn("PROMPT", daemon_environment(env))
        plain = {"PATH": "a", "PROMPT": "$P$G"}
        self.assertEqual(daemon_environment(plain), plain)

    def test_manually_closed_tab_reopens_without_reinitializing_session(self):
        self.apply("=== A\n+ FOLDER|one")
        self.runtime.hosts.clear()
        self.runtime.events.clear()
        self.apply("=== A\n+ FOLDER|one")
        self.assertEqual(len(self.events("open")), 1)
        self.assertFalse(self.events("new") + self.events("send-text"))

    def test_dry_run_changes_nothing(self):
        self.apply("=== A\n+ FOLDER|one")
        before = copy.deepcopy(self.state)
        self.runtime.events.clear()
        self.apply("--- moved\n=== B\n+ FOLDER|two", dry=True)
        self.assertEqual(self.state, before)
        self.assertFalse(self.runtime.events)

    def test_changed_running_session_layout_is_not_silently_reset(self):
        self.apply("=== A\n+ FOLDER|one")
        with self.assertRaisesRegex(ValueError, "different folder/layout"):
            self.apply("=== A\n+ FOLDER|one|single")

    def test_rename_or_first_session_change_rebinds_tab_without_killing_retained(self):
        self.apply("=== A\n+ FOLDER|one\n+ FOLDER|two")
        self.runtime.events.clear()
        self.apply("=== A\n+ FOLDER|two\n+ FOLDER|one")
        self.assertEqual(len(self.events("close")), 1)
        self.assertEqual(len(self.events("open")), 1)
        self.assertFalse(self.events("kill-session") + self.events("new"))

    def test_failed_move_retains_old_attachment_and_retry_closes_it(self):
        self.apply("--- first\n=== A\n+ FOLDER|one")
        moved = "--- second\n=== A\n+ FOLDER|one"
        with patch.object(self.runtime, "verify_tabs", side_effect=RuntimeError("attach failed")):
            with self.assertRaisesRegex(RuntimeError, "attach failed"):
                self.apply(moved)
        self.assertEqual(len(self.state["tabs"]), 2)
        self.assertFalse(self.events("close") + self.events("kill-session"))
        self.apply(moved)
        self.assertEqual(len(self.state["tabs"]), 1)
        self.assertEqual(self.events("close"), [("close", "first", "A")])
        self.assertFalse(self.events("kill-session"))

    def test_rebind_failure_keeps_archived_old_tab_until_retry(self):
        self.apply("=== A\n+ FOLDER|one\n+ FOLDER|two")
        reordered = "=== A\n+ FOLDER|two\n+ FOLDER|one"
        with patch.object(self.runtime, "verify_tabs", side_effect=RuntimeError("attach failed")):
            with self.assertRaises(RuntimeError):
                self.apply(reordered)
        self.assertEqual(len(self.state["tabs"]), 2)
        self.apply(reordered)
        self.assertEqual(len(self.state["tabs"]), 1)
        self.assertEqual(len(self.events("close")), 1)

    def test_plain_tabs_are_idempotent_and_removed_without_tuios_deletion(self):
        self.apply("--- first\nFOLDER|Shell")
        self.runtime.events.clear()
        self.apply("--- first\nFOLDER|Shell")
        self.assertFalse(self.events("open") + self.events("close") + self.events("daemon"))
        self.apply("--- second\nFOLDER|Shell")
        self.assertEqual(len(self.events("open")), 1)
        self.assertEqual(len(self.events("close")), 1)
        self.assertFalse(self.events("new") + self.events("kill-session"))

    def codex_in(self, **clients):
        """A Codex app-server daemon runs, used by these Codex processes per session."""
        self.runtime.codex_running, self.runtime.codex_clients = True, clients

    def test_stop_ends_the_codex_daemon_its_panes_left_without_a_client(self):
        self.owned_by_another_list()
        self.codex_in(one=1, two=1)
        code, out = self.main("stop")
        self.assertEqual(code, 0)
        events = self.runtime.events
        # Checked once, before any deletion, for every session; stopped once all are gone.
        self.assertEqual(sorted(self.events("codex-check")[0][1:]), ["one", "test", "two", "unrelated"])
        self.assertEqual(len(self.events("codex-check")), 1)
        self.assertLess(events.index(self.events("codex-check")[0]), events.index(self.events("close")[0]))
        self.assertEqual(events[-1], ("codex-stop", 1))
        self.assertLess(events.index(("kill-server",)), events.index(("codex-stop", 1)))
        self.assertIn("STOP the Codex app-server daemon and its helpers: no Codex runs outside the deleted sessions",
                      out)

    def test_stop_keeps_the_codex_daemon_while_codex_runs_elsewhere(self):
        self.owned_by_another_list()
        self.codex_in(one=1)
        self.runtime.codex_others = 2  # Codex in another terminal.
        code, out = self.main("stop")
        self.assertEqual(code, 0)
        self.assertFalse(self.events("codex-stop"))
        self.assertIn("KEEP the Codex app-server daemon for 2 Codex processes outside the deleted sessions", out)
        self.assertEqual(self.runtime.live, {})

    def test_dry_stop_previews_the_codex_daemon_stop(self):
        self.owned_by_another_list()
        self.codex_in(one=1, two=1)
        code, out = self.main("dry", "stop")
        self.assertEqual(code, 0)
        self.assertIn("[dry] STOP the Codex app-server daemon and its helpers", out)
        self.assertLess(out.index("[dry] DELETE session one"), out.index("[dry] STOP the Codex"))
        self.assertEqual([e[0] for e in self.runtime.events], ["codex-check"])

    def test_stop_named_session_keeps_the_codex_daemon_of_other_sessions(self):
        self.owned_by_another_list()
        self.codex_in(one=1, two=1)
        code, out = self.main("stop", "two", "--list", str(self.path))
        self.assertEqual(code, 0)
        self.assertEqual(self.events("codex-check"), [("codex-check", "two")])
        self.assertFalse(self.events("codex-stop"))
        self.assertIn("KEEP the Codex app-server daemon for 1 Codex process outside the deleted sessions", out)

    def test_stop_named_session_ends_the_codex_daemon_of_its_last_codex(self):
        self.owned_by_another_list()
        self.codex_in(two=1)
        code, out = self.main("stop", "two", "--list", str(self.path))
        self.assertEqual(code, 0)
        events = self.runtime.events
        self.assertLess(events.index(("kill-session", "two")), events.index(("codex-stop", 1)))
        self.assertLess(events.index(("codex-stop", 1)), events.index(self.events("new")[0]))
        self.assertIn("STOP the Codex app-server daemon", out)

    def test_an_idle_codex_daemon_stops_with_a_session_declaring_codex_only(self):
        self.owned_by_another_list()
        self.codex_in()  # Every Codex has exited: no client at all.
        code, out = self.main("stop", "test", "--list", str(self.path))
        self.assertEqual(code, 0)
        self.assertFalse(self.events("codex-stop"))  # A CMD session: not tuitp's to stop.
        self.assertNotIn("Codex app-server daemon", out)
        code, out = self.main("stop", "two", "--list", str(self.path))
        self.assertEqual(code, 0)
        self.assertEqual(self.events("codex-stop"), [("codex-stop", 1)])

    def test_removing_a_session_from_the_list_checks_its_codex_and_a_plain_run_does_not(self):
        self.owned_by_another_list()
        self.codex_in(two=1)
        self.apply("=== Projects\n+ FOLDER|one\n+ FOLDER|two\n=== Test\n+ FOLDER|test|single")
        self.assertFalse(self.events("codex-check"))
        self.apply("=== Projects\n+ FOLDER|one\n=== Test\n+ FOLDER|test|single")
        self.assertEqual(self.events("codex-check"), [("codex-check", "two")])
        self.assertLess(self.runtime.events.index(("kill-session", "two")),
                        self.runtime.events.index(("codex-stop", 1)))

    def test_a_failed_codex_check_leaves_the_daemon_and_still_stops_the_sessions(self):
        self.owned_by_another_list()
        self.codex_in(one=1)
        with patch.object(self.runtime, "codex_daemon", side_effect=OSError("access denied")):
            code, out = self.main("stop")
        self.assertEqual(code, 0)
        self.assertIn("tuitp: the Codex app-server daemon keeps running, it could not be checked: access denied",
                      out)
        self.assertFalse(self.events("codex-stop"))
        self.assertEqual(self.runtime.live, {})


@unittest.skipUnless(os.name == "nt", "Windows native boundary checks")
class WindowsTests(unittest.TestCase):
    def test_wt_first_window_waits_for_registration_not_gui_exit(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-wt-") as temp:
            runtime = Windows(ROOT / "bin", Path(temp))
            tab = Tab("side", "Projects", "tuios", sessions=["one"])
            record = {"spec": asdict(tab), "token": "a" * 32}
            launcher = Mock()
            launcher.poll.return_value = None  # First WT process stays alive.
            with patch("tuitp_windows.subprocess.Popen", return_value=launcher) as popen, \
                    patch.object(runtime, "wait_host", return_value=True) as handshake:
                runtime.open_tab(record)
            launcher.wait.assert_not_called()
            launcher.communicate.assert_not_called()
            launcher.kill.assert_not_called()
            handshake.assert_called_once_with(record)
            self.assertIn("tuitp-side", popen.call_args.args[0])

    def test_daemon_starts_without_the_launcher_venv(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-daemon-") as temp:
            runtime = Windows(ROOT / "bin", Path(temp))

            def ready():
                runtime.daemon_live = True
                return {}

            with patch.dict(os.environ, {"VIRTUAL_ENV": r"C:\work\.venv"}), \
                    patch("tuitp_windows.subprocess.Popen") as popen, patch("tuitp_windows.time.sleep"), \
                    patch.object(runtime, "snapshot", side_effect=ready):
                runtime.ensure_daemon()
            self.assertEqual(popen.call_args.args[0][1:], ["daemon"])
            self.assertNotIn("VIRTUAL_ENV", popen.call_args.kwargs["env"])

    def test_setup_copy_block_keeps_legacy_without_python_and_preserves_local_list(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-setup-") as temp:
            base = Path(temp)
            source, target = base / "source" / "bin", base / "target" / "bin"
            source.mkdir(parents=True)
            target.mkdir(parents=True)
            for name in FILES:
                shutil.copy2(ROOT / "bin" / name, source / name)
            (source / "tuitp.list").write_text("# source must not replace the local list\n")
            (source / "tuitp.legacy.json").write_text('{"must_not_copy":true}')
            (source / "ordinary.bat").write_text("@echo ordinary\n")
            (target / "tuitp.bat").write_text('@echo off\ncall :tab Projects one\nstart "" wt -w tuitp-dev new-tab\n')
            (target / "tuitp.setup.bat").write_text(f'call :ensure one "{temp}" project\n')
            (target / "tuitp.list").write_text("# retained local list\n")
            setup = (ROOT / "setup.bat").read_text()
            block = setup[setup.index("rem Keep the old hard-coded tuitp launcher aside"):]
            block = block[:block.index('%_ok% "script_dir')]
            self.assertNotRegex(block, r"(?im)^(?!\s*rem\b).*python")  # comments may name it
            # Execute the actual install block, with HOME references redirected
            # to a test-only variable. Never overwrite the user's environment.
            block = block.replace("%HOME%", "%TUITP_TEST_TARGET%")
            batch = base / "copy-test.bat"
            batch.write_text("@echo off\n" + block)
            # Setup must work from a console without Python: only System32.
            system32 = str(Path(os.environ["SystemRoot"]) / "System32")
            env = dict(os.environ, TUITP_TEST_TARGET=str(target.parent), script_dir=str(source.parent),
                       PATH=system32, _info="echo", _fatal="echo")
            result = subprocess.run(f'cmd.exe /d /c call "{batch}"', env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stderr, "")
            self.assertEqual((target / "tuitp.list").read_text(), "# retained local list\n")
            self.assertFalse((target / "tuitp.legacy.json").exists())
            self.assertIn("call :tab", (target / LEGACY_DIR / "tuitp.bat").read_text())
            self.assertTrue((target / LEGACY_DIR / "tuitp.setup.bat").is_file())
            self.assertEqual((target / "ordinary.bat").read_text(), "@echo ordinary\n")
            self.assertIn("tuitp.py", (target / "tuitp.bat").read_text())
            # tuitp captures the kept launcher on its next run, with Python.
            self.assertTrue(adopt_legacy(target))
            self.assertIn("one", json.loads((target / "tuitp.legacy.json").read_text())["sessions"])
            self.assertFalse(adopt_legacy(target))
            # A second setup finds the new launcher and keeps nothing more.
            kept = (target / LEGACY_DIR / "tuitp.bat").read_text()
            result = subprocess.run(f'cmd.exe /d /c call "{batch}"', env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((target / LEGACY_DIR / "tuitp.bat").read_text(), kept)

            # Git's post-install refresh follows setup and must preserve the
            # installed list and migration data through its second bin copy.
            post = (ROOT / "installs" / "gits.post.bat").read_text()
            block = post[post.index("rem Preserve machine-local tuitp declarations"):]
            block = block[:block.index('%_info% "   [Copy senv.doskey')]
            block = block.replace("%HOMEBIN%", "%TUITP_TEST_TARGET_BIN%")
            batch.write_text("@echo off\n" + block)
            env.update(TUITP_TEST_TARGET_BIN=str(target), bin_dir=str(source))
            (target / "ordinary.bat").write_text("@echo outdated\n")
            result = subprocess.run(f'cmd.exe /d /c call "{batch}"', env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((target / "tuitp.list").read_text(), "# retained local list\n")
            self.assertIn("one", json.loads((target / "tuitp.legacy.json").read_text())["sessions"])
            self.assertEqual((target / "ordinary.bat").read_text(), "@echo ordinary\n")
            (target / "tuitp.list").unlink()
            result = subprocess.run(f'cmd.exe /d /c call "{batch}"', env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((target / "tuitp.list").read_text(), (source / "tuitp.list").read_text())

    def test_pane_cmd_quoting_activation_path_and_error_propagation(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-cmd-") as temp:
            base = Path(temp)
            profile, project = base / "user profile", base / "project (with spaces)"
            profile.mkdir()
            project.mkdir()
            local_bin = profile / ".local" / "bin"
            local_bin.mkdir(parents=True)
            (profile / "senv.bat").write_text('@echo off\nset "TUITP_GLOBAL=global-%1"\nset "PATH=%SystemRoot%\\System32"\nexit /b 0\n')
            (project / "senv.bat").write_text('@echo off\nset "TUITP_LOCAL=project"\nset "PATH=%SystemRoot%\\System32"\nexit /b 0\n')
            (local_bin / "codex.bat").write_text('@echo off\necho CODEX-STARTED\nexit /b 0\n')
            helper = ROOT / "bin" / "tuitp.pane.bat"
            cmd = Path(os.environ["SystemRoot"]) / "System32" / "cmd.exe"
            command = f'"{cmd}" /d /v:off /c call "{helper}" "{project}" codex && set TUITP_ && cd && path'
            with patch.dict(os.environ, {"USERPROFILE": str(profile), "PRGS": str(base)}):
                result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("CODEX-STARTED", result.stdout)
                self.assertIn("TUITP_GLOBAL=global-global", result.stdout)
                self.assertIn("TUITP_LOCAL=project", result.stdout)
                self.assertIn(str(project), result.stdout)
                self.assertIn(str(base / "tuioss" / "current"), result.stdout)
                self.assertIn(str(profile / ".codex" / "packages" / "standalone" / "current" / "bin"), result.stdout)
                (profile / "senv.bat").write_text('@echo off\nexit /b 7\n')
                result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 7)
                self.assertNotIn("CODEX-STARTED", result.stdout)

    def test_one_pane_startup_prefers_local_senv_and_falls_back_to_global(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-env-") as temp:
            base = Path(temp)
            profile, project = base / "user profile", base / "project (with spaces)"
            profile.mkdir()
            project.mkdir()
            local_bin = profile / ".local" / "bin"
            local_bin.mkdir(parents=True)
            for role in ("claude", "codex"):
                (local_bin / f"{role}.bat").write_text(f'@echo off\necho {role.upper()}-STARTED-%TUITP_TEST_ACTIVE%\nexit /b 0\n')
            helper = ROOT / "bin" / "tuitp.pane.bat"
            cmd = Path(os.environ["SystemRoot"]) / "System32" / "cmd.exe"
            with patch.dict(os.environ, {"USERPROFILE": str(profile), "PRGS": str(base)}):
                for has_local in (False, True):
                    source = "LOCAL" if has_local else "GLOBAL"
                    global_script = profile / "senv.bat"
                    global_script.write_text('@echo off\necho PREP-GLOBAL\nset "TUITP_TEST_ACTIVE=GLOBAL"\nset "PATH=%SystemRoot%\\System32"\nexit /b 0\n')
                    local_script = project / "senv.bat"
                    if has_local:
                        local_script.write_text('@echo off\necho PREP-LOCAL\nset "TUITP_TEST_ACTIVE=LOCAL"\nset "PATH=%SystemRoot%\\System32"\nexit /b 0\n')
                    for role in ("claude", "codex", "cmd"):
                        with self.subTest(local=has_local, role=role):
                            command = f'"{cmd}" /d /v:off /c call "{helper}" "{project}" {role} local-or-global && set TUITP_TEST_ACTIVE'
                            result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                            self.assertIn(f"TUITP_TEST_ACTIVE={source}", result.stdout)
                            self.assertIn("PREP-" + source, result.stdout)
                            self.assertNotIn("PREP-" + ("GLOBAL" if has_local else "LOCAL"), result.stdout)
                            for agent in ("claude", "codex"):
                                marker = agent.upper() + "-STARTED-" + source
                                if role == agent:
                                    self.assertIn(marker, result.stdout)
                                    self.assertLess(result.stdout.index("PREP-" + source), result.stdout.index(marker))
                                else:
                                    self.assertNotIn(agent.upper() + "-STARTED", result.stdout)
                    failing_script = local_script if has_local else global_script
                    failing_script.write_text('@echo off\nexit /b 7\n')
                    for role in ("claude", "codex", "cmd"):
                        command = f'"{cmd}" /d /v:off /c call "{helper}" "{project}" {role} local-or-global'
                        result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                        self.assertEqual(result.returncode, 7)
                        self.assertNotIn("-STARTED", result.stdout)

    def test_agent_failing_at_startup_starts_again_three_times_in_all(self):
        # Codex exits at once when its app-server times out on a slow first
        # network call. Each retry waits 5 seconds, hence the longer timeouts.
        with tempfile.TemporaryDirectory(prefix="tuitp-retry-") as temp:
            base = Path(temp)
            profile, project = base / "user profile", base / "project (with spaces)"
            local_bin = profile / ".local" / "bin"
            local_bin.mkdir(parents=True)
            project.mkdir()
            (profile / "senv.bat").write_text('@echo off\nset "PATH=%SystemRoot%\\System32"\nexit /b 0\n')
            starts, fake = base / "starts.txt", base / "fake_codex.py"
            # The Nth start exits with the Nth code; later starts reuse the last one.
            fake.write_text("import pathlib, sys\n"
                            "starts = pathlib.Path(sys.argv[1])\n"
                            "with starts.open('a') as log: log.write('start\\n')\n"
                            "codes = [int(c) for c in sys.argv[2].split(',')]\n"
                            "code = codes[min(len(starts.read_text().splitlines()), len(codes)) - 1]\n"
                            "print('CODEX-EXIT', code, flush=True)\n"
                            "sys.exit(code)\n")
            (local_bin / "codex.bat").write_text(f'@"{sys.executable}" -I "{fake}" "{starts}" %TUITP_TEST_CODES%\n'
                                                 '@exit /b %errorlevel%\n')
            helper = ROOT / "bin" / "tuitp.pane.bat"
            cmd = Path(os.environ["SystemRoot"]) / "System32" / "cmd.exe"
            command = (f'"{cmd}" /d /v:off /c call "{helper}" "{project}" codex local-or-global'
                       ' && (if defined attempt (echo LEAKED) else echo CLEAN)')
            for codes, exit_code, started in (("3,0", 0, 2), ("3", 3, 3)):
                with self.subTest(codes=codes):
                    starts.unlink(missing_ok=True)
                    env = dict(os.environ, USERPROFILE=str(profile), PRGS=str(base), TUITP_TEST_CODES=codes)
                    result = subprocess.run(command, capture_output=True, text=True, timeout=60, env=env)
                    self.assertEqual(result.returncode, exit_code, result.stdout + result.stderr)
                    self.assertEqual(len(starts.read_text().splitlines()), started)
                    self.assertIn("codex exited 3 after", result.stdout)
                    self.assertIn(f"Attempt {started} of 3 in 5s, Ctrl+C to stop.", result.stdout)
                    self.assertNotIn(f"Attempt {started + 1} of 3", result.stdout)
                    if exit_code == 0:
                        self.assertIn("CLEAN", result.stdout)

    def test_legacy_adoption_matches_exact_launcher_and_closes_only_attachment(self):
        runtime = Windows(Path(r"C:\Tools with spaces"), ROOT / "unused")
        tab = asdict(Tab("dev", "Projects", "tuios", sessions=["one"], slot=key("dev|tuios|Projects")))
        helper = runtime.scripts / "tuitp.tab.bat"
        rows = [
            {"Name": "cmd.exe", "ProcessId": 11, "ParentProcessId": 1,
             "CommandLine": f'cmd.exe /k "{helper}" "one"'},
            {"Name": "tuios.exe", "ProcessId": 12, "ParentProcessId": 11,
             "CommandLine": '"C:\\Tools\\tuios.exe" attach "one"'},
            {"Name": "cmd.exe", "ProcessId": 13, "ParentProcessId": 1,
             "CommandLine": f'cmd.exe /k echo "{helper}" "one"'},
            {"Name": "tuios.exe", "ProcessId": 14, "ParentProcessId": 11,
             "CommandLine": '"C:\\Tools\\tuios.exe" daemon'},
        ]
        with patch("tuitp_windows.run", return_value=subprocess.CompletedProcess([], 0, json.dumps(rows))), \
                patch("tuitp_windows.identity", side_effect=lambda pid: {"pid": pid, "created": 123}):
            records = runtime.legacy_tabs({"tabs": [tab]})
        self.assertEqual(len(records), 1)
        record = next(iter(records.values()))
        with patch("tuitp_windows.terminate_exact") as terminate:
            runtime.close_tab(record)
        self.assertEqual([c.args[0]["pid"] for c in terminate.call_args_list], [12, 11])

    def test_host_detaches_client_without_terminating_session_or_daemon(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-host-") as temp:
            manifest = Path(temp) / "host.json"
            write_json(manifest, {"tab": {"kind": "tuios", "title": "A", "sessions": ["one"]}, "tuios": "tuios.exe"})
            manifest.with_suffix(".ready").touch()
            child = Mock(pid=123)
            child.poll.return_value = None
            child.terminate.side_effect = lambda: setattr(child.poll, "return_value", 0)
            def start(argv):
                self.assertEqual(argv, ["tuios.exe", "attach", "one"])
                manifest.with_suffix(".stop").touch()
                return child
            with patch("tuitp_host.identity", return_value={"pid": 1, "created": 2}), \
                    patch("tuitp_host.subprocess.Popen", side_effect=start), patch("tuitp_host.run") as native:
                self.assertEqual(tuitp_host.host(manifest), 0)
            child.terminate.assert_called_once()
            native.assert_not_called()

    def test_panes_call_a_copy_that_a_pane_script_update_leaves_alone(self):
        # CMD resumes a running batch file at a byte offset: an in-place update
        # once made agent panes run line fragments, then the agent again.
        with tempfile.TemporaryDirectory(prefix="tuitp-pane-copy-") as temp:
            scripts, root = Path(temp) / "bin", Path(temp) / "state"
            scripts.mkdir()
            source = scripts / "tuitp.pane.bat"
            source.write_bytes(b"@echo off\r\nrem first\r\n")
            runtime = Windows(scripts, root)
            first = runtime.pane_helper()
            self.assertEqual(first.parent, root / "panes")
            self.assertEqual(first.read_bytes(), source.read_bytes())
            self.assertEqual(runtime.pane_helper(), first)
            source.write_bytes(b"@echo off\r\nrem second, longer\r\n")
            second = runtime.pane_helper()
            self.assertNotEqual(second, first)
            self.assertEqual(second.read_bytes(), source.read_bytes())
            self.assertEqual(first.read_bytes(), b"@echo off\r\nrem first\r\n")
            # A WT tab host gets the same copy through its manifest.
            record = {"spec": asdict(Tab("dev", "", "cmd", temp, slot="s")), "token": "b" * 32}
            with patch("tuitp_windows.subprocess.Popen"), patch.object(runtime, "wait_host", return_value=True):
                runtime.open_tab(record)
            self.assertEqual(tuitp_windows.read_json(runtime.host_path(record))["pane"], str(second))

    def test_pane_names_read_the_names_tuios_lists(self):
        runtime = Windows(Path(r"C:\bin"), Path(r"C:\state"))
        listing = {"windows": [{"custom_name": "Claude pdf", "display_name": "Claude pdf"},
                               {"custom_name": "", "display_name": "CMD"}]}
        with patch("tuitp_windows.run", return_value=Mock(stdout=json.dumps(listing))) as native:
            self.assertEqual(runtime.pane_names("one"), {"Claude pdf", "CMD"})
        self.assertEqual(native.call_args.args[0], [runtime.tuios, "list-windows", "-s", "one", "--json"])

    def test_claude_hooks_come_from_tuios_into_a_file_of_their_own(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-claude-hooks-") as temp:
            runtime = Windows(Path(temp) / "bin", Path(temp) / "state")
            calls, hooks = [], {"Stop": [{"hooks": [{"type": "command", "command": "tuios agent-hook claude-code"}]}]}

            def install(argv, env=None, **_):
                # As tuios does: merge its hooks into the settings of CLAUDE_CONFIG_DIR.
                calls.append((argv, env["CLAUDE_CONFIG_DIR"]))
                settings = Path(env["CLAUDE_CONFIG_DIR"]) / "settings.json"
                settings.write_text(json.dumps({**json.loads(settings.read_text()), "hooks": hooks}))

            with patch("tuitp_windows.run", side_effect=install):
                target = runtime.write_claude_hooks()
                self.assertEqual(target, Path(temp) / "state" / "claude" / "settings.json")
                self.assertEqual(json.loads(target.read_text()), {"hooks": hooks})
                argv, config = calls[0]
                self.assertEqual(argv, [runtime.tuios, "integration", "install", "claude-code", "--no-skill",
                                        "--command", runtime.tuios])
                self.assertFalse(Path(config).exists())  # A temporary folder, never the user's settings.
                # The same hooks leave the file alone; new ones replace it.
                with patch("tuitp_windows.write_json") as write:
                    runtime.write_claude_hooks()
                write.assert_not_called()
                hooks["Stop"][0]["hooks"][0]["command"] += " --integration 4"
                runtime.write_claude_hooks()
                self.assertEqual(json.loads(target.read_text()), {"hooks": hooks})
                hooks.clear()
                with self.assertRaisesRegex(RuntimeError, "wrote no hooks"):
                    runtime.write_claude_hooks()

    def test_only_claude_panes_load_the_hooks_file_when_it_exists(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-pane-hooks-") as temp:
            base = Path(temp)
            profile, project, local = base / "user profile", base / "project (with spaces)", base / "local app data"
            local_bin = profile / ".local" / "bin"
            local_bin.mkdir(parents=True)
            project.mkdir()
            (profile / "senv.bat").write_text('@echo off\nset "PATH=%SystemRoot%\\System32"\nexit /b 0\n')
            for role in ("claude", "codex"):
                (local_bin / f"{role}.bat").write_text(f'@echo off\necho {role.upper()}-ARGS [%*]\nexit /b 0\n')
            hooks = local / "tuitp" / "claude" / "settings.json"
            helper = ROOT / "bin" / "tuitp.pane.bat"
            cmd = Path(os.environ["SystemRoot"]) / "System32" / "cmd.exe"
            with patch.dict(os.environ, {"USERPROFILE": str(profile), "PRGS": str(base), "LOCALAPPDATA": str(local)}):
                for exists in (False, True):
                    if exists:
                        hooks.parent.mkdir(parents=True)
                        hooks.write_text("{}")
                    for role in ("claude", "codex"):
                        with self.subTest(exists=exists, role=role):
                            command = (f'"{cmd}" /d /v:off /c call "{helper}" "{project}" {role} local-or-global'
                                       ' && (if defined agent (echo LEAKED) else echo CLEAN)')
                            result = subprocess.run(command, capture_output=True, text=True, timeout=20)
                            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                            expected = f'--settings "{hooks}"' if exists and role == "claude" else ""
                            self.assertIn(f"{role.upper()}-ARGS [{expected}]", result.stdout)
                            self.assertIn("CLEAN", result.stdout)

    def test_live_file_reads_and_rewrites_survive_each_other(self):
        # The launcher polls each .live file while its tab host rewrites it.
        # Unretried, Windows refuses hundreds of these opens and replaces.
        with tempfile.TemporaryDirectory(prefix="tuitp-live-") as temp:
            live = Path(temp) / "host.live"
            write_json(live, {"status": "waiting"})
            errors = []
            stop = threading.Event()

            def rewrite():
                while not stop.is_set():
                    try:
                        write_json(live, {"status": "attached"})
                    except OSError as error:
                        errors.append(error)

            writer = threading.Thread(target=rewrite)
            writer.start()
            try:
                for _ in range(2000):
                    try:
                        self.assertIn(tuitp_windows.read_json(live)["status"], ("waiting", "attached"))
                    except OSError as error:
                        errors.append(error)
            finally:
                stop.set()
                writer.join()
            self.assertEqual(errors, [])

    def test_failed_host_records_error_and_exits_successfully_to_close_wt_tab(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-host-error-") as temp:
            manifest = Path(temp) / "host.json"
            with patch("tuitp_host.host", side_effect=OSError("attach failed")):
                self.assertEqual(tuitp_host.main(manifest), 0)
            self.assertEqual(manifest.with_suffix(".error").read_text(), "attach failed")

    def test_native_argument_quoting_preserves_one_send_text_argument(self):
        payload = 'call "C:\\Tools with spaces\\tuitp.pane.bat" "C:\\Project (one)" claude'
        args = ["send-text", "-s", "project", "-w", "Claude", payload, "C:\\trailing space\\", ""]
        result = run([sys.executable, "-c", "import json,sys; print(json.dumps(sys.argv[1:]))", *args])
        self.assertEqual(json.loads(result.stdout), args)

    def timing_output(self, enabled):
        out = io.StringIO()
        with patch.object(tuitp_windows, "TIMING", enabled), patch.object(tuitp_windows, "_timings", []), \
                contextlib.redirect_stdout(out):
            run([sys.executable, "-c", "pass"])
            run([sys.executable, "-c", "pass"])
            with tuitp_windows.timed("tab wait"):
                pass
            tuitp_windows.timing_summary(1.5)
        return out.getvalue()

    def test_timing_prints_each_command_wait_and_a_summary_when_enabled(self):
        text = self.timing_output(True)
        stem = Path(sys.executable).stem
        self.assertEqual(text.count(f"s {stem} -c pass\n"), 2)
        self.assertIn("total 1.5s; 2 native commands took", text)
        self.assertIn(f"  {stem} -c: 2 x,", text)
        self.assertIn("  wait 0.0s: tab wait\n", text)

    def test_timing_prints_nothing_by_default(self):
        self.assertEqual(self.timing_output(False), "")

    def test_identity_rejects_reused_pid_timestamp(self):
        current = identity(os.getpid())
        self.assertTrue(alive(current))
        self.assertFalse(alive({**current, "created": current["created"] - 1}))

    def test_process_table_follows_a_real_child_to_its_parent(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        self.addCleanup(child.kill)
        table = tuitp_windows.process_table()
        self.assertEqual(table[child.pid][0], os.getpid())
        self.assertEqual(table[os.getpid()][1].lower(), Path(sys.executable).name.lower())
        me, kid = identity(os.getpid()), identity(child.pid)
        self.assertIn(kid, tuitp_windows.descendants(table, [me]))
        self.assertTrue(tuitp_windows.started_from(table, kid, [me]))
        self.assertFalse(tuitp_windows.started_from(table, me, [kid]))

    def test_a_parent_pid_reused_later_is_not_an_ancestor(self):
        # Process 10 outlived parent 5; a process created later took PID 5.
        table = {10: (5, "codex.exe"), 5: (1, "cmd.exe")}
        with patch("tuitp_windows.running", side_effect=lambda pid: {"pid": pid, "created": 50 if pid == 5 else pid}):
            self.assertFalse(tuitp_windows.started_from(table, {"pid": 10, "created": 10}, [{"pid": 5, "created": 50}]))
            self.assertEqual(tuitp_windows.descendants(table, [{"pid": 5, "created": 50}]), [{"pid": 5, "created": 50}])

    def test_codex_daemon_roots_are_the_running_processes_of_its_pid_files(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-codex-") as temp:
            home, me = Path(temp), identity(os.getpid())
            self.assertEqual(tuitp_windows.codex_daemon_roots(home), {})
            write_json(home / "app-server-daemon" / "daemon.pid",
                       {"pid": me["pid"], "processStartTime": str(me["created"])})
            write_json(home / "app-server-daemon" / "daemon-updater.pid",
                       {"pid": me["pid"], "processStartTime": str(me["created"] - 1)})  # A reused PID.
            self.assertEqual(tuitp_windows.codex_daemon_roots(home), {"daemon": me})
            (home / "app-server-daemon" / "daemon.pid").write_text("not JSON")
            self.assertEqual(tuitp_windows.codex_daemon_roots(home), {})

    def test_codex_daemon_counts_the_codex_inside_and_outside_the_sessions(self):
        # Pane 40 runs Codex 50, which started the daemon 100, its code-mode
        # host 101 and its updater 102. Codex 60 runs in another terminal 70.
        table = {40: (30, "cmd.exe"), 50: (40, "codex.exe"), 100: (50, "codex.exe"),
                 101: (100, "codex-code-mode-host.exe"), 102: (50, "codex.exe"), 60: (70, "codex.exe"),
                 70: (1, "cmd.exe")}
        runtime = Windows(ROOT / "bin", ROOT / "unused")
        runtime.daemon_live = True

        def process(pid):
            return {"pid": pid, "created": pid}

        roots = {"updater": process(102), "daemon": process(100)}
        with patch("tuitp_windows.codex_daemon_roots", return_value=roots), \
                patch("tuitp_windows.process_table", return_value=table), \
                patch("tuitp_windows.running", side_effect=lambda pid: process(pid) if pid in table else None), \
                patch.object(runtime, "pane_processes", return_value=[process(40)]) as panes:
            found = runtime.codex_daemon(["one"])
            panes.assert_called_once_with("one")
            self.assertEqual(found, {"updater": [process(102)], "daemon": [process(100), process(101)],
                                     "inside": 1, "outside": 1})
            del table[60]
            self.assertEqual(runtime.codex_daemon(["one"])["outside"], 0)
            table[60] = (70, "codex-x86_64-pc-windows-msvc.exe")  # Codex installed with npm.
            self.assertEqual(runtime.codex_daemon(["one"])["outside"], 1)
        with patch("tuitp_windows.codex_daemon_roots", return_value={}):
            self.assertIsNone(runtime.codex_daemon(["one"]))

    def test_stop_codex_daemon_ends_the_updater_then_the_daemon_then_what_it_started(self):
        found = {"updater": [{"pid": 102, "created": 102}],
                 "daemon": [{"pid": 100, "created": 100}, {"pid": 101, "created": 101}, {"pid": 103, "created": 103}]}
        ended = []

        def terminate(process):
            ended.append(process["pid"])
            if process["pid"] >= 101:
                raise OSError(5, "Access is denied")  # 101 had just ended; 103 still runs.

        runtime = Windows(ROOT / "bin", ROOT / "unused")
        with patch("tuitp_windows.terminate_exact", side_effect=terminate), \
                patch("tuitp_windows.running", side_effect=lambda pid: {"pid": pid, "created": pid} if pid == 103 else None):
            with self.assertRaisesRegex(OSError, r"^process 103: .*Access is denied$"):
                runtime.stop_codex_daemon(found)
        self.assertEqual(ended, [102, 100, 101, 103])

    def test_snapshot_accepts_saved_exit_one_but_rejects_malformed_and_failed_live(self):
        runtime = Windows(ROOT / "bin", ROOT / "unused")
        for result, accepted in [(subprocess.CompletedProcess([], 1, '[{"name":"one","saved":true}]', ''), True),
                                 (subprocess.CompletedProcess([], 1, '[{"name":"one","saved":false}]', ''), False),
                                 (subprocess.CompletedProcess([], 1, 'not JSON', 'failure'), False)]:
            with patch("tuitp_windows.run", return_value=result):
                if accepted:
                    self.assertIn("one", runtime.snapshot())
                else:
                    with self.assertRaises(RuntimeError):
                        runtime.snapshot()

    def test_install_preserves_list_backs_up_scripts_and_captures_legacy_layout(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-install-") as temp:
            target = Path(temp) / "destination with spaces"
            target.mkdir()
            (target / "tuitp.bat").write_text('@echo off\ncall :tab Projects one\ncall :tab Test two\nstart "" wt -w tuitp-dev new-tab\n')
            (target / "tuitp.setup.bat").write_text(f'call :ensure one "{temp}" project\ncall :ensure two "{temp}" single\n')
            (target / "tuitp.list").write_text("# retain my list\n")
            install(ROOT / "bin", target)
            self.assertEqual((target / "tuitp.list").read_text(), "# retain my list\n")
            self.assertTrue(all((target / name).exists() for name in FILES))
            migration = json.loads((target / "tuitp.legacy.json").read_text())
            self.assertEqual(list(migration["sessions"]), ["one", "two"])
            self.assertEqual(migration["tabs"][0]["title"], "Projects")
            self.assertEqual(len(list((target / "tuitp-backups").iterdir())), 1)
            install(ROOT / "bin", target)
            self.assertEqual(json.loads((target / "tuitp.legacy.json").read_text()), migration)

    def test_adopt_legacy_seeds_missing_list_and_names_an_unreadable_launcher(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-adopt-") as temp:
            target = Path(temp) / "bin with spaces"
            legacy = target / LEGACY_DIR
            legacy.mkdir(parents=True)
            self.assertFalse(adopt_legacy(target))  # empty folder: nothing kept
            (legacy / "tuitp.bat").write_text('@echo off\ncall :tab Projects one\ncall :tab Test two\nstart "" wt -w tuitp-dev new-tab\n')
            (legacy / "tuitp.setup.bat").write_text(f'call :ensure one "{temp}" project\ncall :ensure two "{temp}" single\n')
            self.assertTrue(adopt_legacy(target))
            layout = read_list(target / "tuitp.list")
            self.assertEqual(list(layout.sessions), ["one", "two"])
            self.assertEqual([tab.title for tab in layout.tabs], ["Projects", "Test"])
            (target / "tuitp.legacy.json").unlink()
            (legacy / "tuitp.setup.bat").write_text("rem no sessions\n")
            with self.assertRaisesRegex(ValueError, re.escape(str(legacy))):
                adopt_legacy(target)
            self.assertFalse((target / "tuitp.legacy.json").exists())


if __name__ == "__main__":
    unittest.main()
