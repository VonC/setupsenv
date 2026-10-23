"""Show each TUIOS session in its own tuitp tab: a switch to another tab's session brings that tab forward.

A click on an agent of another session in the TUIOS rail switches the client
of the current tab to that session. tuitp starts this watcher to follow such
switches: it selects the Windows Terminal tab that groups the session, shows
the session there, then switches the first client back to its own session.
"""
from __future__ import annotations

import base64
from datetime import datetime
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time

from tuitp_windows import read_json, run, write_json


class Follower:
    """Decide, from TUIOS client-session-changed events, which tab to select and which clients to switch."""

    def __init__(self):
        self.tabs = {}   # Session name -> slot of the tuitp tab that groups it.
        self.specs = {}  # Slot -> its tab spec.
        self.home = {}   # Client id -> slot of its tab: the tab whose tuios attach opened it.
        self.shows = {}  # Client id -> the session it shows; absent while it is detached.
        self.left = {}   # Client id -> the session it detached from, until it attaches again.

    def load(self, state):
        """Take the TUIOS tabs that tuitp recorded in its state."""
        self.tabs, self.specs = {}, {}
        for slot, record in state.get("tabs", {}).items():
            spec = record.get("spec") or {}
            if spec.get("kind") != "tuios" or "~" in slot:  # A ~ slot is a tab being replaced.
                continue
            self.specs[slot] = spec
            for session in spec.get("sessions", []):
                self.tabs[session] = slot

    def siblings(self, slot):
        """Return the titles of the other tuitp tabs of the slot's window, which tell its window apart."""
        window = self.specs[slot]["window"]
        return sorted(spec["title"] for other, spec in self.specs.items()
                      if other != slot and spec["window"] == window and spec.get("title"))

    def resync(self, clients, homes=None):
        """Take the clients TUIOS lists now: one known before keeps its tab, a new one belongs where it is."""
        homes = homes or {}
        listed = {client["client_id"]: client.get("session") or "" for client in clients}
        self.shows = {client: session for client, session in listed.items() if session}
        self.left = {}
        known = {client: self.home.get(client) or homes.get(client) or self.tabs.get(session)
                 for client, session in listed.items()}
        self.home = {client: slot for client, slot in known.items() if slot in self.specs}

    def event(self, event):
        """Return the actions that show a switched-to session in its own tab, in their order."""
        client, session = event.get("client_id"), event.get("session")
        if event.get("type") != "client-session-changed" or not client or not session:
            return []
        if not event.get("attached"):
            self.left[client] = session
            self.shows.pop(client, None)
            return []
        old = self.left.pop(client, None)
        self.shows[client] = session
        if client not in self.home:
            # A new client attaches where tuitp opened it; else it comes from its tab's session.
            slot = self.tabs.get(old or session)
            if slot:
                self.home[client] = slot
        home, target = self.home.get(client), self.tabs.get(session)
        if home not in self.specs:
            home = None  # Its tab was removed from the list since.
        if old is None or home is None or target is None or target == home:
            return []  # A first attach, a rename, or a switch inside one tab.
        viewers = sorted(c for c, slot in self.home.items() if slot == target and c in self.shows)
        if not viewers:
            return [("note", f"no client shows tab {self.specs[target]['title']}: "
                             f"session {session} stays where it was picked")]
        viewer = viewers[-1]  # Client ids grow with time: the newest one.
        spec = self.specs[target]
        actions = [("select", spec["title"], self.siblings(target))]
        if self.shows[viewer] != session:
            actions.append(("switch", viewer, session))
        back = old if self.tabs.get(old) == home else self.specs[home]["sessions"][0]
        actions.append(("switch", client, back))
        return actions


class TabSelector:
    """Select Windows Terminal tabs through one PowerShell process that keeps UI Automation loaded."""

    def __init__(self, script: Path, timeout=15):
        self.script, self.timeout = script, timeout
        self.process, self.lines = None, None

    def start(self):
        powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        # An encoded command is not a script file: no execution policy applies to it.
        encoded = base64.b64encode(self.script.read_text(encoding="utf-8").encode("utf-16-le")).decode()
        self.process = subprocess.Popen([str(powershell), "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8",
                                        errors="replace", creationflags=subprocess.CREATE_NO_WINDOW)
        self.lines = queue.Queue()
        threading.Thread(target=self._read, args=(self.process, self.lines), daemon=True).start()
        if self._reply().get("ready") is not True:
            raise RuntimeError("the tab selector did not start")

    @staticmethod
    def _read(process, lines):
        for line in process.stdout:
            lines.put(line)
        lines.put("")

    def _reply(self):
        try:
            line = self.lines.get(timeout=self.timeout)
        except queue.Empty:
            line = ""
        if not line:
            self.stop()
            raise RuntimeError("the tab selector did not answer")
        return json.loads(line)

    def select(self, title, siblings):
        if not self.process or self.process.poll() is not None:
            self.start()
        # ASCII JSON: titles reach PowerShell's console input whatever its code page.
        self.process.stdin.write(json.dumps({"title": title, "siblings": siblings}) + "\n")
        self.process.stdin.flush()
        return self._reply()

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.kill()
        self.process = None


def log(message):
    print(f"{datetime.now():%Y-%m-%d %H:%M:%S} {message}", flush=True)


class Watch:
    """Apply the follower's actions: select the tab, then switch the clients through tuios."""

    def __init__(self, tuios, root: Path, selector, command=run):
        self.tuios, self.root, self.selector, self.command = tuios, root, selector, command
        self.follower = Follower()
        self.boot_id, self.state_mtime = "", None

    def reload(self):
        state_file = self.root / "state.json"
        try:
            mtime = state_file.stat().st_mtime_ns
            if mtime != self.state_mtime:
                self.follower.load(read_json(state_file))
                self.state_mtime = mtime
        except (OSError, ValueError) as error:
            log(f"cannot read {state_file}: {error}")

    def resync(self):
        """Read the clients again, keeping the tabs of the clients this daemon start already showed."""
        homes_file = self.root / "watch.clients.json"
        saved = {}
        try:
            saved = read_json(homes_file) if homes_file.is_file() else {}
        except (OSError, ValueError):
            pass
        homes = saved.get("homes", {}) if saved.get("boot_id") == self.boot_id else {}
        result = self.command([self.tuios, "list-clients", "--json"], check=False)
        try:
            clients = json.loads(result.stdout) if result.returncode == 0 else []
        except ValueError:
            clients = []
        self.reload()
        self.follower.resync(clients if isinstance(clients, list) else [], homes)
        self.save()

    def save(self):
        try:
            write_json(self.root / "watch.clients.json", {"boot_id": self.boot_id, "homes": self.follower.home})
        except OSError as error:
            log(f"cannot save the client tabs: {error}")

    def line(self, text):
        try:
            event = json.loads(text)
        except ValueError:
            return
        if event.get("type") == "subscribed":
            self.boot_id = event.get("boot_id", "")
            self.resync()
            return
        if event.get("type") == "gap":
            self.resync()  # Events were dropped: what the clients show now is what counts.
            return
        self.reload()
        homes = dict(self.follower.home)
        actions = self.follower.event(event)
        if self.follower.home != homes:
            self.save()
        self.perform(actions)

    def perform(self, actions):
        # Stop at the first failure: never leave a client away from a session it did not reach.
        for action in actions:
            if action[0] == "note":
                log(action[1])
                return
            if action[0] == "select":
                try:
                    reply = self.selector.select(action[1], action[2])
                except (OSError, ValueError, RuntimeError) as error:
                    reply = {"ok": False, "error": str(error)}
                if not reply.get("ok"):
                    log(f"cannot select tab {action[1]}: {reply.get('error')}")
                    return
                log(f"selected tab {action[1]}" + (" and raised its window" if reply.get("raised") else ""))
            else:
                _, client, session = action
                result = self.command([self.tuios, "switch-session", "--client", client, session], check=False)
                if result.returncode:
                    log(f"cannot switch client {client} to {session}: {(result.stderr or result.stdout).strip()}")
                    return
                log(f"switched client {client} to {session}")


def daemon_live(tuios):
    result = run([tuios, "ls", "--json"], check=False)
    try:
        return result.returncode == 0 and not any(row.get("saved") for row in json.loads(result.stdout))
    except (ValueError, TypeError, AttributeError):
        return False


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    tuios, root = argv[0], Path(os.environ["LOCALAPPDATA"]) / "tuitp"
    selector = TabSelector(Path(__file__).resolve().with_name("tuitp_tabs.ps1"))
    watch = Watch(tuios, root, selector)
    try:
        selector.start()  # Load UI Automation now, not on the first click.
    except (OSError, RuntimeError) as error:
        log(f"tab selector: {error}; it starts again on the first switch")
    log(f"watching the TUIOS clients of {tuios}")
    try:
        while True:
            stream = subprocess.Popen([tuios, "subscribe", "--types", "client-session-changed"],
                                      stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                      text=True, encoding="utf-8", errors="replace",
                                      creationflags=subprocess.CREATE_NO_WINDOW)
            for text in stream.stdout:
                watch.line(text)
            stream.wait()
            time.sleep(2)  # Neither a burst of retries nor a daemon caught while it stops.
            # The stream ends with the daemon, as tuitp stop ends it. The next tuitp run starts a new watcher.
            if not daemon_live(tuios):
                log("the TUIOS daemon stopped: the watcher stops too")
                return 0
    finally:
        selector.stop()


if __name__ == "__main__":
    raise SystemExit(main())
