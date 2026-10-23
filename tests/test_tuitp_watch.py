"""Behavioral tests of the tab watcher: no real WT tab is selected and no TUIOS client is switched."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
import tuitp_windows
from tuitp_watch import Follower, TabSelector, Watch
from tuitp_windows import Windows, write_json


def tab(window, title, *sessions, kind="tuios"):
    return {"spec": {"window": window, "title": title, "kind": kind, "folder": "", "sessions": list(sessions),
                     "slot": f"{window}|{title}"}, "token": "0" * 32}


STATE = {"version": 1, "sessions": {}, "tabs": {
    "dev|bill": tab("dev", "bill", "billing"),
    "dev|tools": tab("dev", "tools", "api", "web"),
    "dev|shell": tab("dev", "Shell", kind="cmd"),
    "work|notes": tab("work", "notes", "notes"),
    "dev|bill~0123": tab("dev", "bill", "old-bill"),  # A tab being replaced.
}}


def attach(client, session):
    return {"type": "client-session-changed", "client_id": client, "session": session, "attached": True}


def detach(client, session):
    return {"type": "client-session-changed", "client_id": client, "session": session, "attached": False}


class FollowerTests(unittest.TestCase):
    def setUp(self):
        self.follower = Follower()
        self.follower.load(STATE)
        self.follower.resync([{"client_id": "client-1", "session": "billing"},
                              {"client_id": "client-2", "session": "api"},
                              {"client_id": "client-3", "session": "notes"},
                              {"client_id": "client-4", "session": ""}])

    def switch(self, client, old, new):
        self.assertEqual(self.follower.event(detach(client, old)), [])
        return self.follower.event(attach(client, new))

    def test_tabs_map_their_sessions_but_not_plain_or_replaced_tabs(self):
        self.assertEqual(self.follower.tabs, {"billing": "dev|bill", "api": "dev|tools", "web": "dev|tools",
                                              "notes": "work|notes"})
        self.assertEqual(self.follower.home, {"client-1": "dev|bill", "client-2": "dev|tools", "client-3": "work|notes"})
        self.assertEqual(self.follower.siblings("dev|bill"), ["tools"])

    def test_switch_to_another_tabs_session_selects_that_tab_then_sends_the_client_back(self):
        self.assertEqual(self.switch("client-1", "billing", "api"),
                         [("select", "tools", ["bill"]), ("switch", "client-1", "billing")])
        # Its own switch back, inside its tab, asks for nothing more.
        self.assertEqual(self.switch("client-1", "api", "billing"), [])

    def test_the_other_tab_first_shows_the_session_when_it_shows_another_of_its_group(self):
        self.assertEqual(self.switch("client-2", "api", "web"), [])  # Inside its tab: left alone.
        self.assertEqual(self.switch("client-1", "billing", "api"),
                         [("select", "tools", ["bill"]), ("switch", "client-2", "api"),
                          ("switch", "client-1", "billing")])
        self.assertEqual(self.switch("client-2", "web", "api"), [])

    def test_a_tab_of_another_window_is_told_apart_by_its_own_siblings(self):
        self.assertEqual(self.switch("client-1", "billing", "notes"),
                         [("select", "notes", []), ("switch", "client-1", "billing")])

    def test_sessions_outside_tuitp_tabs_and_first_attaches_are_left_alone(self):
        self.assertEqual(self.switch("client-1", "billing", "scratch"), [])
        self.assertEqual(self.follower.event(attach("client-5", "web")), [])
        self.assertEqual(self.follower.home["client-5"], "dev|tools")
        self.assertEqual(self.follower.event(attach("client-1", "renamed")), [])  # A rename has no detach.
        self.assertEqual(self.follower.event({"type": "agent-state", "client_id": "client-1"}), [])

    def test_a_tab_without_a_client_leaves_the_session_where_it_was_opened(self):
        self.follower.event(detach("client-3", "notes"))  # Its tab closed.
        actions = self.switch("client-1", "billing", "notes")
        self.assertEqual([a[0] for a in actions], ["note"])
        self.assertIn("no client shows tab notes", actions[0][1])
        # Away from its tab, the client goes back to its tab's first session.
        self.assertEqual(self.switch("client-1", "notes", "web"),
                         [("select", "tools", ["bill"]), ("switch", "client-2", "web"),
                          ("switch", "client-1", "billing")])

    def test_the_newest_client_of_a_tab_shows_the_session(self):
        self.follower.event(attach("client-6", "api"))  # tuitp opened the tab again.
        self.assertEqual(self.switch("client-1", "billing", "web"),
                         [("select", "tools", ["bill"]), ("switch", "client-6", "web"),
                          ("switch", "client-1", "billing")])

    def test_resync_keeps_the_known_tabs_of_clients_and_drops_the_gone_ones(self):
        self.switch("client-1", "billing", "scratch")  # Away from its tab while events were lost.
        self.follower.resync([{"client_id": "client-1", "session": "api"},
                              {"client_id": "client-7", "session": "web"}], homes={"client-7": "dev|bill"})
        self.assertEqual(self.follower.home, {"client-1": "dev|bill", "client-7": "dev|bill"})
        self.assertEqual(self.follower.shows, {"client-1": "api", "client-7": "web"})

    def test_a_removed_tab_no_longer_brings_its_clients_back(self):
        self.follower.load({"tabs": {key: STATE["tabs"][key] for key in ("dev|tools", "work|notes")}})
        self.assertEqual(self.switch("client-1", "billing", "api"), [])


class WatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tuitp-watch-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        write_json(self.root / "state.json", STATE)
        self.calls = []
        self.clients = [{"client_id": "client-1", "session": "billing"},
                        {"client_id": "client-2", "session": "api"}]
        self.selector = Mock()
        self.selector.select.side_effect = lambda title, siblings: self.calls.append(("select", title)) or {"ok": True}
        self.watch = Watch("tuios.exe", self.root, self.selector, command=self.command)

    def command(self, argv, check=True):
        self.calls.append(tuple(argv[1:]))
        if argv[1] == "list-clients":
            return Mock(returncode=0, stdout=json.dumps(self.clients))
        return Mock(returncode=0, stdout="", stderr="")

    def feed(self, *events):
        with patch("builtins.print"):
            for event in events:
                self.watch.line(json.dumps(event))

    def test_a_rail_jump_selects_the_tab_first_then_switches_the_client_back(self):
        self.feed({"type": "subscribed", "boot_id": "b1"}, detach("client-1", "billing"), attach("client-1", "api"))
        self.assertEqual(self.calls, [("list-clients", "--json"), ("select", "tools"),
                                      ("switch-session", "--client", "client-1", "billing")])

    def test_a_failed_tab_selection_switches_no_client(self):
        self.selector.select.side_effect = RuntimeError("the tab selector did not answer")
        self.feed({"type": "subscribed", "boot_id": "b1"}, detach("client-1", "billing"), attach("client-1", "api"))
        self.assertEqual(self.calls, [("list-clients", "--json")])

    def test_client_tabs_survive_a_watcher_restart_of_the_same_daemon_start_only(self):
        self.feed({"type": "subscribed", "boot_id": "b1"}, attach("client-3", "web"))
        saved = json.loads((self.root / "watch.clients.json").read_text())
        self.assertEqual(saved["homes"]["client-3"], "dev|tools")
        # Restarted while client-3 showed another tab's session.
        self.clients.append({"client_id": "client-3", "session": "billing"})
        again = Watch("tuios.exe", self.root, self.selector, command=self.command)
        with patch("builtins.print"):
            again.line(json.dumps({"type": "subscribed", "boot_id": "b1"}))
        self.assertEqual(again.follower.home["client-3"], "dev|tools")
        other = Watch("tuios.exe", self.root, self.selector, command=self.command)
        with patch("builtins.print"):
            other.line(json.dumps({"type": "subscribed", "boot_id": "b2"}))
        self.assertEqual(other.follower.home["client-3"], "dev|bill")

    def test_state_changes_reach_the_watcher_without_a_restart(self):
        self.feed({"type": "subscribed", "boot_id": "b1"})
        state = json.loads(json.dumps(STATE))
        state["tabs"]["dev|tools"]["spec"]["sessions"].append("docs")
        write_json(self.root / "state.json", state)
        os.utime(self.root / "state.json", ns=(1, 1))  # A new mtime, however fast the test runs.
        self.feed(detach("client-1", "billing"), attach("client-1", "docs"))
        self.assertIn(("select", "tools"), self.calls)


class TabSelectorTests(unittest.TestCase):
    def test_selector_runs_the_script_as_an_encoded_command_and_reads_one_reply_per_request(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-tabs-") as temp:
            script = Path(temp) / "tabs.ps1"
            script.write_text("Write-Output 'tabs'\n", encoding="utf-8")
            process = Mock()
            process.poll.return_value = None
            process.stdout = iter(['{"ready": true}\n', '{"ok": true, "raised": false}\n'])
            with patch("tuitp_watch.subprocess.Popen", return_value=process) as popen:
                selector = TabSelector(script, timeout=2)
                self.assertEqual(selector.select("tools", ["bill"]), {"ok": True, "raised": False})
            argv = popen.call_args.args[0]
            self.assertEqual(argv[1:4], ["-NoProfile", "-NonInteractive", "-EncodedCommand"])
            import base64
            self.assertEqual(base64.b64decode(argv[4]).decode("utf-16-le"), "Write-Output 'tabs'\n")
            process.stdin.write.assert_called_once_with('{"title": "tools", "siblings": ["bill"]}\n')

    def test_a_silent_selector_is_stopped_and_reported(self):
        with tempfile.TemporaryDirectory(prefix="tuitp-tabs-") as temp:
            script = Path(temp) / "tabs.ps1"
            script.write_text("", encoding="utf-8")
            process = Mock()
            process.poll.return_value = None
            process.stdout = iter([])
            with patch("tuitp_watch.subprocess.Popen", return_value=process):
                with self.assertRaisesRegex(RuntimeError, "did not answer"):
                    TabSelector(script, timeout=2).start()
            process.kill.assert_called_once()


class WatcherProcessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tuitp-watcher-")
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.scripts, self.root = base / "bin", base / "state"
        self.scripts.mkdir()
        self.root.mkdir()
        for name in ("tuitp_watch.py", "tuitp_tabs.ps1", "tuitp_windows.py", "tuitp_model.py"):
            (self.scripts / name).write_text(name, encoding="utf-8")
        self.runtime = Windows(self.scripts, self.root)
        self.process = {"pid": 4242, "created": 7}

    def ensure(self, alive):
        with patch("tuitp_windows.subprocess.Popen", return_value=Mock(pid=4242)) as popen, \
                patch("tuitp_windows.identity", return_value=self.process), \
                patch("tuitp_windows.alive", return_value=alive), \
                patch("tuitp_windows.terminate_exact") as terminate, \
                patch.dict(os.environ, {"TUIOS_SESSION": "bill", "TUIOS_ENV": "1"}):
            started = self.runtime.ensure_watcher()
        return started, popen, terminate

    def test_watcher_starts_once_outside_tuios_and_again_when_its_files_change(self):
        started, popen, terminate = self.ensure(alive=False)
        self.assertTrue(started)
        argv, env = popen.call_args.args[0], popen.call_args.kwargs["env"]
        self.assertEqual(argv[1:], [str(self.scripts / "tuitp_watch.py"), str(self.runtime.tuios)])
        self.assertFalse([name for name in env if name.startswith("TUIOS_")])
        self.assertTrue(popen.call_args.kwargs["creationflags"] & tuitp_windows.subprocess.CREATE_BREAKAWAY_FROM_JOB)
        record = json.loads((self.root / "watch.json").read_text())
        self.assertEqual(record["process"], self.process)
        started, popen, terminate = self.ensure(alive=True)
        self.assertFalse(started)
        popen.assert_not_called()
        (self.scripts / "tuitp_watch.py").write_text("a new version", encoding="utf-8")
        started, popen, terminate = self.ensure(alive=True)
        self.assertTrue(started)
        terminate.assert_called_once_with(self.process)

    def test_a_job_that_refuses_breakaway_still_gets_its_watcher(self):
        with patch("tuitp_windows.subprocess.Popen", side_effect=[PermissionError(5, "denied"), Mock(pid=4242)]) as popen, \
                patch("tuitp_windows.identity", return_value=self.process), \
                patch("tuitp_windows.alive", return_value=False):
            self.assertTrue(self.runtime.ensure_watcher())
        flags = [call.kwargs["creationflags"] & tuitp_windows.subprocess.CREATE_BREAKAWAY_FROM_JOB
                 for call in popen.call_args_list]
        self.assertEqual([bool(flag) for flag in flags], [True, False])

    def test_stop_watcher_ends_only_a_running_watcher(self):
        write_json(self.root / "watch.json", {"process": self.process, "digest": "x"})
        with patch("tuitp_windows.alive", return_value=True), patch("tuitp_windows.terminate_exact") as terminate:
            self.assertTrue(self.runtime.stop_watcher())
        terminate.assert_called_once_with(self.process)
        with patch("tuitp_windows.alive", return_value=False), patch("tuitp_windows.terminate_exact") as terminate:
            self.assertFalse(self.runtime.stop_watcher())
        terminate.assert_not_called()


if __name__ == "__main__":
    unittest.main()
