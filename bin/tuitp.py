"""Reconcile tuitp.list with this launcher's Windows Terminal tabs and TUIOS sessions, or stop them all or some."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict
import os
from pathlib import Path
import sys
import subprocess
import time
import uuid

from tuitp_install import LEGACY_DIR, adopt_legacy
from tuitp_model import PANE_ROLES, Layout, describe, new_state, pane_name, read_list, reconcile_plan
from tuitp_windows import Windows, launcher_lock, read_json, timing_summary, write_json


def session_layout(runtime, session):
    first = PANE_ROLES[session.kind][0]
    runtime.command("set-window", "-s", session.name, "-w", "0", "--name", pane_name(first, session.id))
    if session.kind == "project":
        for workspace, role in ((2, "Codex"), (3, "CMD")):
            runtime.command("new-window", pane_name(role, session.id), "-s", session.name, "--workspace",
                            str(workspace), "--cwd", session.folder, "--no-focus", "--", str(runtime.cmd),
                            "/d", "/v:off")


def rename_panes(runtime, session, old_id):
    """Give the agent panes of a running session the names of its new id, without restarting them."""
    names = runtime.pane_names(session.name)
    for role in PANE_ROLES[session.kind]:
        old, new = pane_name(role, old_id), pane_name(role, session.id)
        if old == new or new in names:
            continue  # Already so named, by hand or by an interrupted run.
        if old not in names:
            print(f"tuitp: session {session.name} has no {old} pane to name {new}", flush=True)
            continue
        runtime.command("set-window", "-s", session.name, "-w", old, "--name", new)


def session_init(runtime, session):
    roles = PANE_ROLES[session.kind]
    helper = runtime.pane_helper()
    for role in roles:
        # subprocess passes this entire command as ONE native send-text argv.
        # The inner quotes belong to the receiving CMD, not the outer shell.
        command = f'call "{helper}" "{session.folder}" {role.lower()}'
        if session.kind != "project":
            command += " local-or-global"
        window = pane_name(role, session.id)
        runtime.command("send-text", "-s", session.name, "-w", window, command)
        runtime.command("send-keys", "Enter", "-s", session.name, "-w", window)


def parallel_sessions(runtime, sessions, action, completed):
    if not sessions:
        return
    failures = []
    with ThreadPoolExecutor(max_workers=min(4, len(sessions))) as pool:
        futures = {pool.submit(action, runtime, session): session for session in sessions}
        for future in as_completed(futures):
            session = futures[future]
            try:
                future.result()
                completed(session)
            except Exception as error:
                failures.append(f"{session.name}: {error}")
    if failures:
        raise RuntimeError("\n".join(failures))


def follow_tabs(runtime, wanted):
    """Run the watcher that shows each session in its own tab while TUIOS tabs exist, and only then."""
    try:
        if wanted and runtime.ensure_watcher():
            print("Started the tab watcher: a session picked in another tab's rail opens in its own tab.",
                  flush=True)
        elif not wanted and runtime.stop_watcher():
            print("Stopped the tab watcher.", flush=True)
    except (OSError, ValueError) as error:
        # The tabs and sessions are in place: only the rail clicks stay in their tab.
        print(f"tuitp: tab watcher: {error}", flush=True)


def codex_daemon_left(runtime, state, live, names):
    """Return the Codex app-server daemon that deleting these sessions leaves without a client, and what to say.

    It is stopped when one of these sessions has a Codex pane, and no Codex
    runs outside them, in another session or another terminal.
    """
    names = [name for name in names if name in live]
    if not names:
        return None, None
    try:
        found = runtime.codex_daemon(names)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"tuitp: the Codex app-server daemon keeps running, it could not be checked: {error}", flush=True)
        return None, None
    declared = any("Codex" in PANE_ROLES.get(state["sessions"].get(name, {}).get("kind"), ()) for name in names)
    if not found or not (found["inside"] or declared):
        return None, None
    if found["outside"]:
        others = found["outside"]
        return None, f"KEEP the Codex app-server daemon for {others} Codex process{'es' if others > 1 else ''} " \
                     "outside the deleted sessions"
    return found, "STOP the Codex app-server daemon and its helpers: no Codex runs outside the deleted sessions"


def stop_codex_daemon(runtime, daemon, dry):
    found, message = daemon
    if message:
        print(("[dry] " if dry else "") + message, flush=True)
    if found and not dry:
        try:
            runtime.stop_codex_daemon(found)
        except OSError as error:
            # The sessions are deleted: only the daemon is left.
            print(f"tuitp: cannot stop the Codex app-server daemon: {error}", flush=True)


def apply_layout(layout, state, live, runtime, save, dry=False, check_codex=True):
    plan = reconcile_plan(layout, state, live, runtime.tab_alive)
    for line in describe(plan, layout):
        print(("[dry] " if dry else "") + line, flush=True)
    # Before any deletion, while the Codex processes of these sessions still run.
    daemon = codex_daemon_left(runtime, state, live, plan["remove"]) if check_codex else (None, None)
    if dry:
        stop_codex_daemon(runtime, daemon, dry)
        return
    started = time.monotonic()
    if any("Claude" in PANE_ROLES[session.kind] for session in plan["create"] + plan["restore"]):
        try:
            runtime.write_claude_hooks()
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            # Before any change: Claude panes still start, without reporting their state.
            print(f"tuitp: Claude panes start without TUIOS agent hooks: {error}", flush=True)
    opened = []
    try:
        # Adopt declared existing sessions, including sessions created by the
        # original launcher. Only these recorded names can later be deleted.
        for name, session in layout.sessions.items():
            if name in live and name not in state["sessions"]:
                # Its panes keep the role names until the rename below records the id.
                state["sessions"][name] = {**asdict(session), "id": "", "status": "ready"}
        save(state)

        print("[1/4] Open missing tabs", flush=True)
        for tab in plan["open"]:
            if tab.slot in state["tabs"]:
                previous = state["tabs"].pop(tab.slot)
                state["tabs"][tab.slot + "~" + uuid.uuid4().hex] = previous
            record = {"spec": asdict(tab), "token": uuid.uuid4().hex, "launched": time.time()}
            state["tabs"][tab.slot] = record
            save(state)  # Retain launch intent if interrupted during wt.exe.
            opened.append(record)
            runtime.open_tab(record)

        print("[2/4] Ensure sessions, then complete every new layout", flush=True)
        if layout.sessions or state["sessions"]:
            runtime.ensure_daemon()
        for session in plan["create"]:
            state["sessions"][session.name] = {**asdict(session), "status": "creating"}
            save(state)
            # Creation stays sequential: all session workers share one daemon.
            runtime.command("new", session.name, "--detach", "--cwd", session.folder)
            state["sessions"][session.name]["status"] = "layout"
            save(state)

        def layout_done(session):
            state["sessions"][session.name]["status"] = "initializing"
            save(state)

        parallel_sessions(runtime, plan["create"], session_layout, layout_done)
        # Also release a retained host if a previous launch was interrupted
        # after creating its session but before signalling the tab.
        for tab in layout.tabs:
            runtime.release_tab(state["tabs"][tab.slot])
        runtime.verify_tabs([state["tabs"][tab.slot] for tab in layout.tabs])

        print("[3/4] Initialize new and restored sessions", flush=True)
        # A restored session comes back with the pane names it had: rename
        # them first, since its pane commands go to the names of its id.
        for session, old_id in plan["rename"]:
            rename_panes(runtime, session, old_id)
            state["sessions"][session.name]["id"] = session.id
            save(state)
        # The daemon is ready, so every restored window holds a bare shell:
        # start its pane command, as for a new session, and only this once.
        for session in plan["restore"]:
            state["sessions"][session.name]["status"] = "initializing"
        save(state)

        def init_done(session):
            state["sessions"][session.name]["status"] = "ready"
            save(state)

        parallel_sessions(runtime, plan["create"] + plan["restore"], session_init, init_done)

        print("[4/4] Close obsolete tabs, then delete removed sessions", flush=True)
        # A move opens the destination before detaching the old client. All
        # desired session names, regardless of their window, are retained.
        for _, record in plan["close"]:
            runtime.close_tab(record)
            for slot in list(state["tabs"]):
                if state["tabs"][slot] is record:
                    del state["tabs"][slot]
            save(state)
        for name in plan["remove"]:
            if name in live:
                runtime.command("kill-session", name)
            del state["sessions"][name]
            save(state)
        stop_codex_daemon(runtime, daemon, dry)
        desired_slots = {tab.slot for tab in layout.tabs}
        state["tabs"] = {slot: record for slot, record in state["tabs"].items() if slot in desired_slots}
        for tab in layout.tabs:
            state["tabs"][tab.slot]["spec"] = asdict(tab)
        for name, session in layout.sessions.items():
            state["sessions"][name]["id"] = session.id  # Also a CMD-only session, which renames nothing.
        save(state)
        tuios_tabs = any(tab.kind == "tuios" for tab in layout.tabs)
        follow_tabs(runtime, tuios_tabs and os.environ.get("TUITP_WATCH") != "0")
        print(f"Reconciled in {time.monotonic() - started:.1f}s."
              + (" New pane startup commands submitted." if plan["create"] or plan["restore"] else ""))
    except Exception as error:
        runtime.fail_tabs(opened, str(error))
        # Never continue deletions after creation, layout or startup failures.
        raise


def stop_sessions(layout, state, live, runtime, save, names, dry=False):
    """Close the tabs that show these sessions and delete them, then reconcile as a new tuitp run."""
    unknown = [name for name in names if name not in layout.sessions and name not in live]
    if unknown:
        raise ValueError(f"No session {', '.join(unknown)} in the list or in TUIOS (the list declares "
                         f"{', '.join(layout.sessions) or 'none'}). Nothing changed.")
    # Close the tab first: once its attached session is deleted, its client
    # would exit while the reconciliation below still counts that tab as open.
    closing = {slot: record for slot, record in state["tabs"].items()
               if set(names) & set(record["spec"]["sessions"]) and runtime.tab_alive(record)}
    deleting = [name for name in names if name in live]
    prefix = "[dry] " if dry else ""
    for record in closing.values():
        print(prefix + f"CLOSE tab {record['spec']['title']} in tuitp-{record['spec']['window']}", flush=True)
    for name in deleting:
        print(prefix + f"DELETE session {name} and its running processes", flush=True)
    daemon = codex_daemon_left(runtime, state, live, deleting)
    if dry:
        stop_codex_daemon(runtime, daemon, dry)
    for slot in closing:
        del state["tabs"][slot]
    for name in names:
        state["sessions"].pop(name, None)
    live = {name: row for name, row in live.items() if name not in names}
    if not dry:
        # Plan first: a layout that cannot be reconciled closes and deletes nothing.
        reconcile_plan(layout, state, live, runtime.tab_alive)
        for record in closing.values():
            runtime.close_tab(record)
        if deleting:
            # As in stop_tuios, a saved session is deleted from a running daemon.
            runtime.ensure_daemon()
        for name in deleting:
            runtime.command("kill-session", name)
        save(state)
        stop_codex_daemon(runtime, daemon, dry)
    apply_layout(layout, state, live, runtime, save, dry)


def stop_tuios(runtime, owned, dry=False):
    """Delete every session left, then stop the daemon: none remains to restore."""
    live = runtime.snapshot()
    if not live and not runtime.daemon_live:
        return
    prefix = "[dry] " if dry else ""
    for name in live:
        if name not in owned:
            print(prefix + f"DELETE session {name} and its running processes, though tuitp did not start it",
                  flush=True)
    print(prefix + "STOP the TUIOS daemon", flush=True)
    if dry:
        return
    # A starting daemon restores every saved session with bare shells: let it
    # restore them now, so that they are deleted like the live ones.
    runtime.ensure_daemon()
    for name in runtime.snapshot():
        runtime.command("kill-session", name)
    # kill-server saves the sessions the daemon still holds, so it comes last.
    runtime.command("kill-server")
    left = runtime.snapshot()
    if left:
        raise RuntimeError(f"TUIOS still lists sessions after stop: {', '.join(left)}")
    print("No TUIOS session or daemon left.", flush=True)


def stop_outside_tuios(scripts, args):
    """Run stop again outside this TUIOS pane: deleting its session would end this process."""
    log_file = Path(os.environ["LOCALAPPDATA"]) / "tuitp" / "stop.log"
    log_file.parent.mkdir(parents=True, exist_ok=True)
    # Without the pane's TUIOS_* variables, tuios commands no longer act for
    # this pane, nor refuse once its daemon stops. Out of the pane's job, the
    # copy outlives the session.
    env = {name: value for name, value in os.environ.items() if not name.startswith("TUIOS_")}
    env["PYTHONUNBUFFERED"] = "1"
    argv = ["stop", *args.sessions] + (["--list", str(args.list.resolve())] if args.list else [])
    with log_file.open("wb") as log:
        subprocess.Popen([sys.executable, str(scripts / "tuitp.py"), *argv], stdin=subprocess.DEVNULL,
                         stdout=log, stderr=log, env=env,
                         creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
                         | subprocess.CREATE_BREAKAWAY_FROM_JOB)
    print(f"tuitp {' '.join(['stop', *args.sessions])} deletes this pane's TUIOS session "
          f"{os.environ.get('TUIOS_SESSION', '')}{'' if args.sessions else ' too'}: "
          f"it goes on outside TUIOS, with its output in {log_file}", flush=True)
    return 0


def load_state(path):
    if not path.exists():
        return new_state()
    state = read_json(path)
    if (not isinstance(state, dict) or state.get("version") != 1
            or not isinstance(state.get("tabs"), dict) or not isinstance(state.get("sessions"), dict)):
        raise ValueError(f"Invalid state file; nothing will be changed: {path}")
    for name, record in state["sessions"].items():
        if record.get("name") != name or not all(field in record for field in ("folder", "kind", "status")):
            raise ValueError(f"Invalid session record in {path}: {name}")
    for record in state["tabs"].values():
        if "spec" not in record or not ("token" in record or "legacy" in record):
            raise ValueError(f"Invalid tab record in {path}")
    return state


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="*", metavar="dry|stop|session",
                        help="dry: preview without changing tabs or sessions; stop: close every "
                             "managed tab, delete every TUIOS session and stop the daemon, "
                             "whatever the list says; stop followed by session names: close their "
                             "tabs and delete only these sessions, then reconcile the list")
    parser.add_argument("--list", type=Path, help="layout file (default: adjacent tuitp.list)")
    args = parser.parse_args(argv)
    args.dry = "dry" in args.mode
    words = [word for word in args.mode if word != "dry"]
    # Words after stop name the sessions to stop: stop alone stops them all.
    args.stop, args.sessions = words[:1] == ["stop"], list(dict.fromkeys(words[1:]))
    if words and not args.stop:
        parser.error(f"unknown mode {', '.join(sorted(set(words) - {'stop'}))}: "
                     "expected dry, stop or both, then session names after stop")
    started = time.monotonic()
    try:
        return reconcile(args)
    finally:
        timing_summary(time.monotonic() - started)


def reconcile(args):
    scripts = Path(__file__).resolve().parent
    dry, names = args.dry, args.sessions
    stop_all = args.stop and not names
    if (args.stop and not dry and os.environ.get("TUIOS_ENV") == "1"
            and (stop_all or os.environ.get("TUIOS_SESSION") in (None, *names))):
        try:
            return stop_outside_tuios(scripts, args)
        except OSError as error:
            print(f"tuitp: cannot run stop outside this TUIOS pane: {error}. "
                  "Run tuitp stop from a CMD outside TUIOS.", file=sys.stderr)
            return 1
    try:
        # Capture first: the old layout can seed a missing tuitp.list.
        if adopt_legacy(scripts):
            print(f"Captured the old tuitp layout kept in {scripts / LEGACY_DIR}.")
    except (OSError, ValueError) as error:
        print(f"tuitp: {error}", file=sys.stderr)
        return 1
    list_path = (args.list or scripts / "tuitp.list").resolve()
    if not stop_all and not list_path.is_file():
        print(f"No list at {list_path}. Copy and edit {scripts / 'tuitp.list.example'}. Nothing changed.")
        return 0
    try:
        # Stop alone never reads the list: the ledger names what this launcher
        # owns, whichever list created it. Otherwise validate it before any changes.
        layout = Layout() if stop_all else read_list(list_path)
        # TUIOS has one session namespace per user. An alternative list is a
        # replacement layout, never a second independent ownership ledger.
        root = Path(os.environ["LOCALAPPDATA"]) / "tuitp"
        state_file = root / "state.json"
        with launcher_lock():
            state = load_state(state_file)
            runtime = Windows(scripts, root)
            migration_file = scripts / "tuitp.legacy.json"
            migrating = not state_file.exists() and migration_file.exists()
            migration = read_json(migration_file) if migrating else {}
            # Stop also deletes the sessions tuitp did not start, saved ones included.
            need_tuios = bool(args.stop or layout.sessions or state["sessions"] or migration.get("sessions"))
            runtime.validate(need_tuios)
            live = runtime.snapshot() if need_tuios else {}
            if migrating:
                state["tabs"] = runtime.legacy_tabs(migration)
                state["sessions"] = {name: {**spec, "status": "ready"}
                                     for name, spec in migration.get("sessions", {}).items() if name in live}
            save = lambda value: write_json(state_file, value)
            if names:
                stop_sessions(layout, state, live, runtime, save, names, dry)
            elif stop_all:
                # Stop deletes every session, owned or not: check their Codex once, for all of them.
                daemon = codex_daemon_left(runtime, state, live, list(live))
                apply_layout(layout, state, live, runtime, save, dry=dry, check_codex=False)
                stop_tuios(runtime, state["sessions"], dry)
                stop_codex_daemon(runtime, daemon, dry)
            else:
                apply_layout(layout, state, live, runtime, save, dry=dry)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"tuitp: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
