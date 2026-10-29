"""Find the conversation each agent pane ran last, so that `tuitp resume` starts its agent on it again.

A Windows restart ends the TUIOS daemon and every program in its panes. TUIOS
keeps each session in `%LOCALAPPDATA%\\tuios\\sessions\\<name>.json`, and the
Claude Code hooks that tuitp gives its Claude panes record there the
conversation each one runs (`agent_session_id`). tuitp reads that file before
it starts the daemon, which restores the session and rewrites the file, then
starts each agent pane through tuitp.pane.bat with `claude --resume <id>` or
`codex resume <id>`.

Codex panes record nothing: TUIOS's Codex hooks would go to the user's
`~/.codex/hooks.json`, for every Codex. Among the Codex threads started from a
terminal in its folder before TUIOS last saved its session, a Codex pane
resumes the one whose last activity is the pane's, else the one its title
names, else the newest. A Claude pane without a record resumes the newest
conversation of its folder. Each conversation resumes in one pane only.
tuitp only reads these files.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import json
import os
from pathlib import Path
import re
import sqlite3
import time

from tuitp_model import PANE_ROLES, pane_name
from tuitp_windows import codex_home

# The harness TUIOS records a pane's conversation for, by pane role.
HARNESSES = {"Claude": "claude-code", "Codex": "codex"}
# Both agents name a conversation with a UUID: anything else never reaches CMD.
CONVERSATION_ID = re.compile(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}")
# Codex threads of a terminal: the TUI writes codex-tui, older ones codex_cli_rs.
# codex exec, the VS Code extension and subagents have their own threads.
CODEX_TERMINALS = {"codex-tui", "codex_cli_rs"}
# Without its state database, tuitp reads the rollouts, and each one opened
# costs: on 2026-10-29, after a restart, 652 first lines took 28 s. The newest
# ones are read first, and none older than this.
CODEX_DAYS = 30
# Codex writes a thread's last activity to its database and TUIOS the pane's
# to its session file, within the same second.
SAME_ACTIVITY_S = 2


@dataclass
class Conversation:
    id: str
    path: Path
    active: float  # Its last activity, in seconds since the epoch.
    title: str = ""
    folder: str = ""
    started: float = 0

    def describe(self):
        title = f"{self.title!r}, " if self.title else ""
        return f"{title}last active {time.strftime('%Y-%m-%d %H:%M', time.localtime(self.active))}"


def records(lines):
    for line in lines:
        try:
            record = json.loads(line)
        except ValueError:
            continue  # A line cut by the end of a read, or by the restart.
        if isinstance(record, dict):
            yield record


def created(path, record_time=None):
    """Return when a conversation started: its first record's time, else its file's."""
    if record_time:
        try:
            return datetime.fromisoformat(record_time.replace("Z", "+00:00")).timestamp()
        except ValueError:
            pass
    stat = path.stat()
    return getattr(stat, "st_birthtime", stat.st_ctime)


def seconds(value):
    """TUIOS saves its times in nanoseconds, Codex in seconds."""
    return value / 1e9 if value and value > 1e12 else value


def same_folder(path, folder):
    path = path.removeprefix("\\\\?\\")  # Codex records its cwd in this form too.
    return os.path.normcase(os.path.normpath(path)) == os.path.normcase(os.path.normpath(folder))


def first_line(text):
    return text.strip().splitlines()[0][:80] if text and text.strip() else ""


def saved_session(name):
    """Return the windows of a session as TUIOS last saved them, and when, or ([], None) without a saved file."""
    path = Path(os.environ["LOCALAPPDATA"]) / "tuios" / "sessions" / f"{name}.json"
    if not path.is_file():
        return [], None
    try:
        windows = json.loads(path.read_text(encoding="utf-8-sig")).get("windows")
    except (OSError, ValueError, AttributeError) as error:
        raise ValueError(f"cannot read {path}: {error}") from error
    return [window for window in windows or [] if isinstance(window, dict)], path.stat().st_mtime


def pane_window(windows, role, pane):
    """Return the saved window of a pane: by its name, else the only one named for its role, as before an id change."""
    named = [window for window in windows if window.get("custom_name") == pane]
    if not named:
        named = [window for window in windows
                 if re.fullmatch(rf"{role}( .+)?", window.get("custom_name") or "")]
    return named[0] if len(named) == 1 else None


class Claude:
    """Claude Code's transcripts: one `<id>.jsonl` per conversation, in a folder named after its checkout."""

    def __init__(self):
        config = os.environ.get("CLAUDE_CONFIG_DIR") or Path(os.environ["USERPROFILE"]) / ".claude"
        self.projects = Path(config) / "projects"

    def folder(self, folder):
        # `claude --resume <id>` looks for the transcript in the folder of the checkout it runs in.
        return self.projects / re.sub(r"[^A-Za-z0-9]", "-", folder)

    def find(self, folder, conversation):
        path = self.folder(folder) / f"{conversation}.jsonl"
        return self.read(path) if path.is_file() else None

    def newest(self, folder, before, claimed, window=None):
        """Return the newest conversation started in a terminal in this folder before that time, and not claimed."""
        place = self.folder(folder)
        paths = sorted(place.glob("*.jsonl"), key=lambda path: path.stat().st_mtime, reverse=True) \
            if place.is_dir() else []
        for path in paths:
            if path.stem in claimed or not CONVERSATION_ID.fullmatch(path.stem):
                continue
            with path.open("rb") as handle:
                head = [handle.readline() for _ in range(50)]
            first = next((record for record in records(head) if record.get("entrypoint")), {})
            # sdk-cli is claude -p, as scripts run it; claude-vscode is the VS Code extension.
            if first.get("entrypoint") == "cli" and created(path, first.get("timestamp")) <= before:
                return self.read(path), "the newest Claude conversation of its folder"
        return None, ""

    def read(self, path):
        """Return a conversation with the title Claude gave it, else its first prompt."""
        with path.open("rb") as handle:
            head = [handle.readline() for _ in range(50)]
            handle.seek(0, os.SEEK_END)
            handle.seek(max(0, handle.tell() - 262_144))
            tail = handle.read().splitlines()
        # Claude appends its title records again as the conversation goes on: the last one counts.
        titles = list(records(line for line in tail if b'-title"' in line))
        title = next((r["customTitle"] for r in reversed(titles) if r.get("customTitle")), "") \
            or next((r["aiTitle"] for r in reversed(titles) if r.get("aiTitle")), "")
        for record in records(head):
            if title:
                break
            message = record.get("message") if record.get("type") == "user" else None
            text = message.get("content") if isinstance(message, dict) else None
            if isinstance(text, str):
                # A slash command is saved in tags: /review-resume as reviewer.
                command = re.search(r"<command-name>(.*?)</command-name>(?:.*?<command-args>(.*?)</command-args>)?",
                                    text, re.S)
                title = " ".join(part for part in command.groups() if part).strip() if command \
                    else "" if text.startswith("<") else text
        return Conversation(path.stem, path, path.stat().st_mtime, first_line(title))


class Codex:
    """Codex's threads, from its state database, else from its rollouts read newest first, only as needed."""

    def __init__(self):
        self.home = codex_home()
        self.threads, self.rollouts, self.names = None, None, None
        self.dated = True  # Whether the threads hold their last activity, as only the database has it.

    def all_threads(self):
        """Yield the terminal threads: all of them from the database, else the rollouts newest first, read lazily."""
        if self.threads is None:
            try:
                self.threads = self.database()
            except (sqlite3.Error, OSError, ValueError):
                self.threads, self.dated = [], False
                files = [(name, Path(dirpath) / name) for dirpath, _, names in os.walk(self.home / "sessions")
                         for name in names if name.startswith("rollout-") and name.endswith(".jsonl")]
                oldest = time.time() - CODEX_DAYS * 86400
                # rollout-<yyyy-mm-ddThh-mm-ss>-<id>.jsonl: by name is by start, without opening them.
                self.rollouts = (path for _, path in sorted(files, reverse=True) if path.stat().st_mtime >= oldest)
        index = 0
        while True:
            if index == len(self.threads):
                thread = next((thread for thread in map(self.rollout, self.rollouts or ()) if thread), None)
                if thread is None:
                    return
                self.threads.append(thread)
            yield self.threads[index]
            index += 1

    def database(self):
        """Read every terminal thread of the newest state_<n>.sqlite, the index Codex lists its threads from."""
        path = max(self.home.glob("state_*.sqlite"), key=lambda path: int(re.sub(r"\D", "", path.stem) or 0))
        connection = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
        try:
            rows = connection.execute("SELECT id, rollout_path, cwd, created_at, updated_at, source, thread_source, "
                                      "originator, name, title FROM threads WHERE archived = 0").fetchall()
        finally:
            connection.close()
        threads = []
        for thread, rollout, cwd, started, active, source, kind, originator, name, title in rows:
            # A subagent's source is its spawn, in JSON.
            terminal = originator in CODEX_TERMINALS or (originator is None and source == "cli")
            if (terminal and kind in (None, "user") and not str(source).startswith("{") and source != "exec"
                    and CONVERSATION_ID.fullmatch(str(thread))):
                threads.append(Conversation(thread, Path(rollout or ""), seconds(active) or 0,
                                            first_line(name or title), cwd or "", seconds(started) or 0))
        return sorted(threads, key=lambda thread: thread.active, reverse=True)

    def rollout(self, path):
        try:
            with path.open("rb") as handle:
                meta = next(records([handle.readline()]), {})
        except OSError:
            return None
        payload = meta.get("payload") if meta.get("type") == "session_meta" else None
        if not isinstance(payload, dict) or not CONVERSATION_ID.fullmatch(str(payload.get("id"))):
            return None
        source, kind = payload.get("source"), payload.get("thread_source")
        if (payload.get("originator") not in CODEX_TERMINALS or kind not in (None, "user")
                or isinstance(source, dict) or source == "exec"):
            return None
        started = created(path, payload.get("timestamp"))
        # Codex no longer writes all its history there: the start is the date that holds.
        return Conversation(payload["id"], path, started, "", payload.get("cwd") or "", started)

    def find(self, folder, conversation):
        thread = next((thread for thread in self.all_threads() if thread.id == conversation), None)
        if thread is None:
            path = next((self.home / "sessions").rglob(f"rollout-*-{conversation}.jsonl"), None)
            thread = path and Conversation(conversation, path, path.stat().st_mtime)
        return self.titled(thread) if thread else None

    def newest(self, folder, before, claimed, window=None):
        """Return the thread of a pane, and how it was told: by its last activity, its pane's title, or as the newest."""
        window = window or {}
        times = [seconds(status.get("at")) for status in window.get("program_status") or []
                 if isinstance(status, dict) and status.get("app") == "codex" and status.get("at")]
        pane_active = max(times) if times else seconds(window.get("agent_state_at"))
        # Codex titles its pane "<thread name> | <folder>", a long one cut with "...".
        title = window.get("title") or ""
        named = title.rsplit(" | ", 1)[0] if " | " in title and not title.endswith("...") else ""
        best, rank = None, None
        for thread in self.all_threads():
            if thread.id in claimed or thread.started > before or not same_folder(thread.folder, folder):
                continue
            if not self.dated:
                best, rank = thread, (False, False)  # Rollouts come newest first: the first one is it.
                break
            self.titled(thread)
            key = (bool(pane_active) and abs(thread.active - pane_active) <= SAME_ACTIVITY_S,
                   bool(named) and thread.title == named, thread.active)
            if rank is None or key > rank:
                best, rank = thread, key
        if best is None:
            return None, ""
        how = "its last activity is the pane's" if rank[0] else "the pane's title names it" if rank[1] \
            else "the newest Codex thread of its folder"
        self.titled(best)
        if named and not rank[1]:
            how += f", though the pane's title named {named!r}"
        return best, how

    def titled(self, conversation):
        """Give a thread its name, as `codex resume` lists it, else its first prompt."""
        if self.names is None:
            self.names = {}
            index = self.home / "session_index.jsonl"
            if index.is_file():
                for record in records(index.read_text(encoding="utf-8", errors="replace").splitlines()):
                    if record.get("id") and record.get("thread_name"):
                        self.names[record["id"]] = record["thread_name"]  # The last rename wins.
        conversation.title = first_line(self.names.get(conversation.id)) or conversation.title
        if not conversation.title and conversation.path.is_file():
            with conversation.path.open("rb") as handle:
                head = [handle.readline() for _ in range(40)]
            for record in records(head):
                payload = record.get("payload") or {}
                if payload.get("type") == "message" and payload.get("role") == "user":
                    texts = [part.get("text", "") for part in payload.get("content") or [] if isinstance(part, dict)]
                    text = next((t for t in texts if t.strip() and not t.startswith(("<", "# AGENTS.md"))), "")
                    if text:
                        conversation.title = first_line(text)
                        break
        return conversation


def command(role, conversation):
    return f"claude --resume {conversation}" if role == "Claude" else f"codex resume {conversation}"


def conversation_plan(layout, starting):
    """Return the conversation each agent pane of the starting sessions resumes, and the lines that describe them.

    A pane resumes the conversation TUIOS recorded for it, else one of its
    agent started in its folder before TUIOS last saved its session. A
    recorded conversation without a transcript never got a message: its pane
    starts a new one, as it was. Every delivery is the start of its pane.
    """
    stores = {"Claude": Claude(), "Codex": Codex()}
    panes, lines = [], []
    for session in starting:
        try:
            windows, saved = saved_session(session.name)
        except ValueError as error:
            windows, saved = [], None
            lines.append(f"NOTE session {session.name}: {error}: its panes resume the newest conversations of "
                         "its folder")
        for role in PANE_ROLES[session.kind]:
            if role in HARNESSES:
                pane = pane_name(role, session.id)
                window = pane_window(windows, role, pane) or {}
                recorded = str(window.get("agent_session_id") or "") \
                    if window.get("agent_session_harness") == HARNESSES[role] else ""
                panes.append((session, role, pane, recorded if CONVERSATION_ID.fullmatch(recorded) else "",
                              window, saved or time.time()))
    # The recorded conversations first: a pane without one never takes another's.
    claimed, found, empty = set(), {}, set()
    for session, role, pane, recorded, _, _ in panes:
        conversation = stores[role].find(session.folder, recorded) if recorded else None
        if recorded and not conversation:
            empty.add((session.name, pane))
        elif conversation and conversation.id not in claimed:
            claimed.add(conversation.id)
            found[session.name, pane] = conversation
    deliveries = []
    for session, role, pane, recorded, window, before in panes:
        where = f"{pane} of session {session.name}"
        agent = "Claude conversation" if role == "Claude" else "Codex thread"
        conversation, how = found.get((session.name, pane)), "TUIOS recorded it in this pane"
        if (session.name, pane) in empty:
            newest, _ = stores[role].newest(session.folder, before, claimed)
            lines.append(f"NOTE {where} starts a new conversation: the one TUIOS recorded there, {recorded}, "
                         "has no transcript, so it never got a message"
                         + (f"; the newest {agent} of its folder is {newest.id}, {newest.describe()}: "
                            f"{command(role, newest.id)} in that pane resumes it" if newest else ""))
            continue
        if not conversation:
            conversation, how = stores[role].newest(session.folder, before, claimed, window)
            if not conversation:
                recent = f" of the last {CODEX_DAYS} days" if role == "Codex" and not stores[role].dated else ""
                lines.append(f"NOTE {where} starts a new conversation: no {agent}{recent} "
                             f"started in {session.folder} before its session was saved")
                continue
            claimed.add(conversation.id)
        deliveries.append({"session": session.name, "window": pane, "resume": conversation.id})
        lines.append(f"RESUME {where}: {command(role, conversation.id)}, {conversation.describe()} ({how})")
    if not panes:
        lines.append("NOTE no agent pane starts: tuitp resume resumes the agents of the sessions it creates "
                     "or restores, and keeps the running ones as they are")
    return deliveries, lines
