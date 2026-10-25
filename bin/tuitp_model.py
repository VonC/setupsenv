"""Declarative layout and reconciliation. No terminal or process side effects here."""
from __future__ import annotations

import hashlib
import os
import re
from dataclasses import dataclass, field
from pathlib import Path


def key(text: str) -> str:
    return hashlib.sha256(text.casefold().encode("utf-8")).hexdigest()[:24]


def safe_path(text: str, base: Path) -> str:
    def expand(match):
        name = match[1]
        if name not in os.environ:
            raise ValueError(f"Undefined environment variable %{name}%")
        return os.environ[name]

    text = text.strip()
    if text.startswith('"') and text.endswith('"'):
        text = text[1:-1]
    text = re.sub(r"%([^%]+)%", expand, text)
    # These paths will ultimately be passed to CALL in CMD. Do not evaluate
    # arbitrary batch expressions from the list, including CALL's second pass.
    if not text or re.search(r'[\r\n"%!^&|<>;]', text):
        raise ValueError(f"Unsupported CMD character or empty folder: {text!r}")
    path = Path(text)
    path = (base / path).resolve() if not path.is_absolute() else path.resolve()
    if not path.is_dir():
        raise ValueError(f"Folder does not exist: {path}")
    return str(path)


PANE_ROLES = {"project": ("Claude", "Codex", "CMD"), "single": ("CMD",),
              "claude": ("Claude",), "codex": ("Codex",)}
# Since TUIOS 0.11.0, on every system, so that a saved session can move between machines.
DEVICE_NAMES = {"con", "prn", "aux", "nul", *(f"com{n}" for n in range(1, 10)), *(f"lpt{n}" for n in range(1, 10))}


def pane_name(role: str, pane_id: str) -> str:
    """Name an agent pane after its project id, so that the TUIOS rail tells agents apart."""
    return f"{role} {pane_id}" if pane_id and role != "CMD" else role


@dataclass
class Session:
    name: str
    folder: str
    kind: str = "project"
    id: str = ""


@dataclass
class Tab:
    window: str
    title: str
    kind: str
    folder: str = ""
    sessions: list[str] = field(default_factory=list)
    slot: str = ""

    @property
    def attach(self):
        return self.sessions[0] if self.sessions else ""

    def binding(self):
        # Adding another session to a group does not restart its client. TUIOS
        # discovers the new session through the shared daemon's session list.
        return (self.window, self.title, self.kind, self.folder, self.attach)


@dataclass
class Layout:
    tabs: list[Tab] = field(default_factory=list)
    sessions: dict[str, Session] = field(default_factory=dict)


def read_list(path: Path) -> Layout:
    layout = Layout()
    window, group = "dev", None
    ranks, slots, names = {}, set(), set()

    def close_group():
        if group and not group.sessions:
            raise ValueError(f"TUIOS tab {group.title!r} has no '+' sessions")

    for number, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            if line.startswith("---"):
                close_group()
                window, group = line[3:].strip(), None
                if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*", window):
                    raise ValueError("Window names use letters, digits, '_', '-' and '.'")
            elif line.startswith("==="):
                close_group()
                title = line[3:].strip()
                if not title or re.search(r'[\r\n";|]', title):
                    raise ValueError("A TUIOS tab needs a title without quotes, ';' or '|'")
                slot = key(f"{window}|tuios|{title}")
                if slot in slots:
                    raise ValueError(f"Duplicate tab {title!r} in window {window!r}")
                slots.add(slot)
                group = Tab(window, title, "tuios", slot=slot)
                layout.tabs.append(group)
            elif line.startswith("+"):
                if group is None:
                    raise ValueError("A '+' session must follow an '=== <tab title>' line")
                fields = [part.strip() for part in line[1:].split("|")]
                if len(fields) > 4:
                    raise ValueError("Expected + folder|session-name|project-claude-codex-senv-or-single|id")
                folder = safe_path(fields[0], path.parent)
                # An empty name or kind keeps its default, so that an id needs neither.
                name = fields[1] if len(fields) > 1 and fields[1] else Path(folder).name
                kind = fields[2].lower() if len(fields) > 2 and fields[2] else "project"
                pane_id = fields[3] if len(fields) > 3 else ""
                if pane_id and not re.fullmatch(r"[A-Za-z0-9_.-]+", pane_id):
                    raise ValueError(f"Invalid id {pane_id!r}: use letters, digits, '_', '-' and '.'")
                if kind == "senv":
                    kind = "single"  # Keep compatibility with persisted single-session records.
                if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*", name):
                    raise ValueError(f"Invalid session name: {name!r}")
                if name.endswith(".") or name.casefold() in DEVICE_NAMES:
                    raise ValueError(f"Invalid session name: {name!r}: TUIOS refuses a name that ends with a dot "
                                     "or names a Windows device")
                if name.casefold() in names:
                    raise ValueError(f"Session {name!r} is declared more than once")
                if kind not in ("project", "single", "claude", "codex"):
                    raise ValueError("Session kind must be 'project', 'claude', 'codex', 'senv' or 'single'")
                names.add(name.casefold())
                layout.sessions[name] = Session(name, folder, kind, pane_id)
                group.sessions.append(name)
            else:
                close_group()
                group = None
                fields = [part.strip() for part in line.split("|")]
                if len(fields) > 2 or (len(fields) == 2 and not fields[1]):
                    raise ValueError("Expected folder or folder|title")
                folder = safe_path(fields[0], path.parent)
                title = fields[1] if len(fields) == 2 else ""
                if re.search(r'[";]', title):
                    raise ValueError("Tab titles cannot contain quotes or ';'")
                rank_key = f"{window}|cmd|{folder}".casefold()
                ranks[rank_key] = ranks.get(rank_key, 0) + 1
                slot = key(f"{rank_key}|{ranks[rank_key]}")
                layout.tabs.append(Tab(window, title, "cmd", folder, slot=slot))
        except ValueError as error:
            raise ValueError(f"{path}:{number}: {error}") from error
    close_group()
    return layout


def reconcile_plan(layout: Layout, state: dict, live: dict, tab_alive) -> dict:
    """Only entries in this launcher's ownership ledger may be removed."""
    old_tabs = state["tabs"]
    keep, open_tabs, close_tabs = [], [], []
    for tab in layout.tabs:
        old = old_tabs.get(tab.slot)
        if old and Tab(**old["spec"]).binding() == tab.binding() and tab_alive(old):
            keep.append(tab.slot)
        else:
            open_tabs.append(tab)
    for slot, record in old_tabs.items():
        if slot not in keep and tab_alive(record):
            close_tabs.append((slot, record))
    create = [session for name, session in layout.sessions.items() if name not in live]
    # A saved session is listed while no daemon runs. Starting the daemon
    # restores its windows with bare shells: its panes need starting again.
    restore = [session for name, session in layout.sessions.items() if live.get(name, {}).get("saved")]
    remove = [name for name in state["sessions"] if name not in layout.sessions]
    # A running session keeps its panes: a new id renames them in place. A
    # session the ledger lacks still has the role names its creator gave.
    rename = [(session, state["sessions"].get(name, {}).get("id", "")) for name, session in layout.sessions.items()
              if name in live]
    rename = [(session, old) for session, old in rename
              if any(pane_name(role, old) != pane_name(role, session.id) for role in PANE_ROLES[session.kind])]
    for name, session in layout.sessions.items():
        old = state["sessions"].get(name)
        if old and name in live:
            if old.get("status") != "ready":
                raise ValueError(f"Session {name!r} has incomplete setup ({old['status']}). "
                                 "Inspect its panes before retrying; no commands will be replayed. "
                                 "After recovering work, remove that session manually and rerun.")
            if (old["folder"].casefold(), old["kind"]) != (session.folder.casefold(), session.kind):
                raise ValueError(f"Session {name!r} already exists with a different folder/layout. "
                                 "Use a new session name to replace it, or restore its declaration.")
    return {"keep": keep, "open": open_tabs, "close": close_tabs,
            "create": create, "restore": restore, "remove": remove, "rename": rename}


def new_state():
    return {"version": 1, "sessions": {}, "tabs": {}}


def describe(plan: dict, layout: Layout) -> list[str]:
    lines = [f"KEEP tab {tab.title or tab.folder} in tuitp-{tab.window}"
             for tab in layout.tabs if tab.slot in plan["keep"]]
    lines += [f"OPEN tab {tab.title or tab.folder} in tuitp-{tab.window}"
              + (f" -> {', '.join(tab.sessions)}" if tab.sessions else "")
              for tab in plan["open"]]
    lines += [f"CREATE session {s.name} ({s.kind}) in {s.folder}" for s in plan["create"]]
    lines += [f"RESTORE session {s.name}, then start its panes again" for s in plan["restore"]]
    started = {s.name for s in plan["create"] + plan["restore"]}
    lines += [f"REUSE session {name}" for name in layout.sessions if name not in started]
    lines += [f"RENAME panes of session {s.name}: "
              + ", ".join(f"{pane_name(role, old)} -> {pane_name(role, s.id)}" for role in PANE_ROLES[s.kind]
                          if pane_name(role, old) != pane_name(role, s.id))
              for s, old in plan["rename"]]
    lines += [f"CLOSE tab {r['spec']['title'] or r['spec']['folder']} in tuitp-{r['spec']['window']}"
              for _, r in plan["close"]]
    lines += [f"DELETE session {name} and its running processes" for name in plan["remove"]]
    return lines
