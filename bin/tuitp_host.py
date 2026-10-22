"""One cooperative foreground host per managed Windows Terminal tab."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import signal
import sys
import time

from tuitp_windows import identity, read_json, run, write_json


def host(manifest: Path):
    config = read_json(manifest)
    tab = config["tab"]
    live_file = manifest.with_suffix(".live")
    ready_file = manifest.with_suffix(".ready")
    stop_file = manifest.with_suffix(".stop")
    abort_file = manifest.with_suffix(".abort")
    process = identity(os.getpid())
    write_json(live_file, {"process": process, "status": "waiting"})
    child = None
    try:
        print(f"tuitp: {tab['title'] or tab['folder']} - waiting for session layouts", flush=True)
        deadline = time.monotonic() + 600
        while not ready_file.exists():
            if stop_file.exists():
                return 0
            if abort_file.exists():
                raise RuntimeError(abort_file.read_text(encoding="utf-8"))
            if time.monotonic() > deadline:
                raise RuntimeError("Setup timed out. Check the launching terminal and rerun tuitp.")
            time.sleep(.5)
        if stop_file.exists():
            return 0
        if tab["kind"] == "tuios":
            argv = [config["tuios"], "attach", tab["sessions"][0]]
            child = subprocess.Popen(argv)  # Inherit this tab's console, no new window.
        else:
            helper = config["pane"]
            # CMD uses different quoting from CommandLineToArgvW. Pass the
            # raw command line with a quoted CALL target, not C-style \".
            command = f'"{config["cmd"]}" /d /v:off /k call "{helper}" "{tab["folder"]}" cmd'
            child = subprocess.Popen(command, cwd=tab["folder"])
        write_json(live_file, {"process": process, "status": "attached", "child": identity(child.pid),
                               "attached": time.time()})
        while child.poll() is None:
            if stop_file.exists():
                if tab["kind"] == "cmd":
                    taskkill = Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"
                    run([taskkill, "/PID", str(child.pid), "/T", "/F"])
                else:
                    # Kill only this foreground attach client. The daemon and
                    # the session's Claude/Codex/CMD processes remain alive.
                    child.terminate()
                child.wait(timeout=15)
                return 0
            time.sleep(.5)
        if child.returncode:
            raise RuntimeError(f"{tab['title'] or tab['folder']}: foreground command exited {child.returncode}")
        return 0
    finally:
        if child and child.poll() is None:
            child.terminate()
        # Leave the PID + creation-time record behind so reconciliation can
        # distinguish an exited host from a tab still starting up.


def main(manifest):
    try:
        return host(manifest)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"tuitp tab: {error}", file=sys.stderr, flush=True)
        manifest.with_suffix(".error").write_text(str(error), encoding="utf-8")
        # WT's automatic/graceful closeOnExit closes a successful host. Keep
        # diagnostics in the sidecar so a failed tab cannot linger untracked.
        return 0


if __name__ == "__main__":
    # Ctrl+C/Break belong to the interactive child, not this monitoring loop.
    signal.signal(signal.SIGINT, lambda *_: None)
    signal.signal(signal.SIGBREAK, lambda *_: None)
    raise SystemExit(main(Path(sys.argv[1])))
