"""Windows process identity, native commands and managed Windows Terminal clients."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import contextlib
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time
import uuid

from tuitp_model import Tab


# TUITP_TIMING (set TUITP_TIMING=1) prints how long each native command and
# each wait took, then a summary by command. An antivirus reputation check can
# hold every tuios.exe start for seconds, which plain output cannot tell apart
# from TUIOS itself.
TIMING = bool(os.environ.get("TUITP_TIMING"))
_timings = []
_timings_lock = threading.Lock()
# TUIOS gives most Claude hooks 5 seconds. Under a heavy CPU load, such as a
# test run, tuios.exe starts slower than that: Claude discards the state the
# hook reports and prints a timeout under each prompt.
HOOK_TIMEOUT = 30


@contextlib.contextmanager
def timed(label, kind="wait"):
    started = time.monotonic()
    try:
        yield
    finally:
        seconds = time.monotonic() - started
        with _timings_lock:  # Session workers run commands in parallel.
            _timings.append((kind, label, seconds))
        if TIMING:
            print(f"[tuitp timing] {seconds:6.2f}s {label}", flush=True)


def timing_summary(total):
    if not TIMING:
        return
    with _timings_lock:
        rows = list(_timings)
    commands = [(label, seconds) for kind, label, seconds in rows if kind == "command"]
    print(f"[tuitp timing] total {total:.1f}s; {len(commands)} native commands took "
          f"{sum(s for _, s in commands):.1f}s, up to 4 of them in parallel", flush=True)
    groups = {}
    for label, seconds in commands:
        key = " ".join(label.split()[:2])
        count, spent, slowest = groups.get(key, (0, 0.0, 0.0))
        groups[key] = (count + 1, spent + seconds, max(slowest, seconds))
    for key, (count, spent, slowest) in sorted(groups.items(), key=lambda item: -item[1][1]):
        print(f"[tuitp timing]   {key}: {count} x, {spent:.1f}s, average {spent / count:.1f}s, "
              f"slowest {slowest:.1f}s", flush=True)
    for kind, label, seconds in rows:
        if kind == "wait":
            print(f"[tuitp timing]   wait {seconds:.1f}s: {label}", flush=True)


def shared(action, timeout=2):
    """Retry the PermissionError Windows raises while another process swaps the file.

    Each tab host rewrites its .live file while the launcher polls it: opening
    it during os.replace is refused, and so is os.replace while it is open.
    """
    deadline = time.monotonic() + timeout
    while True:
        try:
            return action()
        except PermissionError:
            if time.monotonic() > deadline:
                raise
            time.sleep(.01)


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        temporary.write_text(json.dumps(value, indent=2), encoding="utf-8")
        shared(lambda: os.replace(temporary, path))
    finally:
        temporary.unlink(missing_ok=True)


def read_json(path: Path):
    return json.loads(shared(lambda: path.read_text(encoding="utf-8-sig")))


def kernel():
    api = ctypes.WinDLL("kernel32", use_last_error=True)
    api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    api.OpenProcess.restype = wintypes.HANDLE
    api.CloseHandle.argtypes = [wintypes.HANDLE]
    api.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    api.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    api.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    return api


def identity(pid: int):
    api = kernel()
    handle = api.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION
    if not handle:
        error = ctypes.get_last_error()
        if error == 87:  # PID no longer exists
            return None
        raise OSError(error, f"Cannot inspect process {pid}")
    try:
        times = [wintypes.FILETIME() for _ in range(4)]
        code = wintypes.DWORD()
        if not api.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
            raise ctypes.WinError(ctypes.get_last_error())
        if not api.GetExitCodeProcess(handle, ctypes.byref(code)):
            raise ctypes.WinError(ctypes.get_last_error())
        if code.value != 259:  # STILL_ACTIVE
            return None
        return {"pid": pid, "created": (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime}
    finally:
        api.CloseHandle(handle)


def alive(process):
    return bool(process) and identity(process["pid"]) == process


def terminate_exact(process):
    """Check creation time again on the same handle used to terminate."""
    api = kernel()
    handle = api.OpenProcess(0x1001, False, process["pid"])
    if not handle:
        if ctypes.get_last_error() == 87:
            return
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        times = [wintypes.FILETIME() for _ in range(4)]
        if not api.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
            raise ctypes.WinError(ctypes.get_last_error())
        created = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
        if created == process["created"] and not api.TerminateProcess(handle, 0):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        api.CloseHandle(handle)


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD),
                ("cntThreads", wintypes.DWORD), ("th32ParentProcessID", wintypes.DWORD),
                ("pcPriClassBase", wintypes.LONG), ("dwFlags", wintypes.DWORD),
                ("szExeFile", wintypes.WCHAR * 260)]


def process_table():
    """Return {pid: (parent pid, executable name)} of every process, from one Toolhelp snapshot."""
    api = kernel()
    api.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    api.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    api.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    api.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W)]
    snapshot = api.CreateToolhelp32Snapshot(0x2, 0)  # TH32CS_SNAPPROCESS
    if snapshot in (None, wintypes.HANDLE(-1).value):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        entry = PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(entry)
        table = {}
        more = api.Process32FirstW(snapshot, ctypes.byref(entry))
        while more:
            table[entry.th32ProcessID] = (entry.th32ParentProcessID, entry.szExeFile)
            more = api.Process32NextW(snapshot, ctypes.byref(entry))
        return table
    finally:
        api.CloseHandle(snapshot)


def running(pid):
    """Return the identity of a running process, or None when it is gone or cannot be inspected."""
    try:
        return identity(pid) if pid else None
    except OSError:
        return None


def descendants(table, roots):
    """Return these processes, then every process they started, each one created after its parent.

    Windows keeps a dead parent's PID in its children's records: the creation
    times tell a child from a process that reused that PID later.
    """
    result, queue = [], list(roots)
    while queue:
        parent = queue.pop(0)
        result.append(parent)
        for pid, (parent_pid, _) in table.items():
            child = running(pid) if parent_pid == parent["pid"] and pid != parent["pid"] else None
            if child and child["created"] >= parent["created"] and child not in result + queue:
                queue.append(child)
    return result


def started_from(table, process, roots):
    """Whether a process is one of these processes or descends from one, each parent older than its child."""
    seen = set()
    while process and process["pid"] not in seen:
        if process in roots:
            return True
        seen.add(process["pid"])
        parent = running(table.get(process["pid"], (0, ""))[0])
        if parent and parent["created"] > process["created"]:
            return False  # A later process reused the dead parent's PID.
        process = parent
    return False


def codex_home():
    return Path(os.environ.get("CODEX_HOME") or Path(os.environ["USERPROFILE"]) / ".codex")


def codex_daemon_roots(home):
    """Return the running Codex app-server daemon and its updater, as their pid files name them."""
    roots = {}
    for role, name in (("updater", "daemon-updater.pid"), ("daemon", "daemon.pid")):
        try:
            record = read_json(home / "app-server-daemon" / name)
            process = {"pid": int(record["pid"]), "created": int(record["processStartTime"])}
        except (OSError, ValueError, KeyError, TypeError):
            continue  # No daemon ran, or this Codex version records another shape.
        if running(process["pid"]) == process:
            roots[role] = process
    return roots


@contextlib.contextmanager
def launcher_lock():
    # One lock per user, including launches with different list files. TUIOS
    # daemon creation and the sessions namespace are shared by all their tabs.
    from tuitp_model import key
    api = kernel()
    api.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
    api.CreateMutexW.restype = wintypes.HANDLE
    api.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    api.ReleaseMutex.argtypes = [wintypes.HANDLE]
    handle = api.CreateMutexW(None, False, "Local\\tuitp-" + key(os.environ["USERPROFILE"]))
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    acquired = False
    try:
        acquired = api.WaitForSingleObject(handle, 0) in (0, 0x80)
        if not acquired:
            raise RuntimeError("Another tuitp reconciliation is running")
        yield
    finally:
        if acquired:
            api.ReleaseMutex(handle)
        api.CloseHandle(handle)


def run(argv, timeout=60, check=True, env=None):
    label = " ".join([Path(str(argv[0])).stem, *map(str, argv[1:])])
    with timed(label[:110], "command"):
        result = subprocess.run([str(a) for a in argv], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=timeout, env=env,
                                creationflags=subprocess.CREATE_NO_WINDOW)
    if check and result.returncode:
        raise RuntimeError(f"{subprocess.list2cmdline([str(a) for a in argv])}\n"
                           f"exit {result.returncode}: {result.stderr or result.stdout}")
    return result


def daemon_environment(environ):
    """Return the TUIOS daemon's environment, without the launcher's virtual env.

    Every pane shell, restored ones included, inherits the daemon's
    environment: a venv active where tuitp ran would show in their prompt and
    lead their PATH before any senv runs.
    """
    env = dict(environ)
    venv = env.pop("VIRTUAL_ENV", None)
    env.pop("VIRTUAL_ENV_PROMPT", None)
    env.pop("_OLD_VIRTUAL_PATH", None)
    old_prompt = env.pop("_OLD_VIRTUAL_PROMPT", None)
    if venv:
        scripts = os.path.normcase(os.path.join(venv, "Scripts"))
        entries = env.get("PATH", "").split(os.pathsep)
        env["PATH"] = os.pathsep.join(e for e in entries if os.path.normcase(e.rstrip("\\/")) != scripts)
        if old_prompt is None:
            env.pop("PROMPT", None)
        else:
            env["PROMPT"] = old_prompt
    return env


class Windows:
    def __init__(self, scripts: Path, root: Path):
        self.scripts, self.root = scripts, root
        self.wt = Path(os.environ["LOCALAPPDATA"]) / "Microsoft/WindowsApps/wt.exe"
        self.tuios = Path(os.environ.get("PRGS", r"C:\Public\SOFTWARE")) / "tuioss/current/tuios.exe"
        self.cmd = Path(os.environ["SystemRoot"]) / "System32/cmd.exe"
        self.daemon_live = False

    def validate(self, need_tuios):
        paths = [self.wt, self.cmd, Path(os.environ["USERPROFILE"]) / "senv.bat",
                 self.scripts / "tuitp_host.py", self.scripts / "tuitp.pane.bat"]
        if need_tuios:
            paths.append(self.tuios)
        for path in paths:
            if not path.is_file():
                raise ValueError(f"Required file is missing: {path}")
        from tuitp_model import safe_path
        safe_path(str(self.scripts), self.scripts)

    def ensure_internet(self):
        """Run the ensure_internet.bat beside tuitp, which restarts the proxy if needed, or raise: nothing starts offline."""
        script = self.scripts / "ensure_internet.bat"
        if not script.is_file():
            raise ValueError(f"Required file is missing: {script}: tuitp starts nothing without checking "
                             "Internet access")
        with timed("ensure_internet.bat", "command"):
            # Its own output tells the person what it checked and repaired. The
            # console's input too: the 'timeout' waits of its proxy restart refuse
            # a redirected one, and px would then be tested before it listens.
            code = subprocess.run([str(self.cmd), "/d", "/c", "call", str(script)], timeout=300).returncode
        if code:
            raise RuntimeError(f"no Internet access (ensure_internet.bat exit {code}): nothing started. "
                               "Run tuitp again once 'ei' succeeds.")

    def pane_helper(self):
        """Return a copy of tuitp.pane.bat named after its content, for panes to call.

        CMD reads a running batch file from disk at a byte offset. Replacing
        tuitp.pane.bat while an agent runs would make its pane resume in the
        middle of a line of the new file once the agent exits.
        """
        source = (self.scripts / "tuitp.pane.bat").read_bytes()
        folder = self.root / "panes"
        target = folder / f"tuitp.pane.{hashlib.sha256(source).hexdigest()[:12]}.bat"
        if not target.is_file():
            folder.mkdir(parents=True, exist_ok=True)
            from tuitp_model import safe_path
            safe_path(str(folder), folder)  # CMD receives this path in a CALL.
            temporary = target.with_name(target.name + "." + uuid.uuid4().hex + ".tmp")
            try:
                temporary.write_bytes(source)
                shared(lambda: os.replace(temporary, target))
            finally:
                temporary.unlink(missing_ok=True)
        return target

    def write_claude_hooks(self):
        """Write TUIOS's Claude Code hooks to the settings file that tuitp.pane.bat gives Claude.

        On Windows, TUIOS cannot read a pane's foreground process: only these
        hooks report a Claude pane's state. In the user's settings, each hook
        would start tuios.exe in every Claude session, outside TUIOS too.
        Asking TUIOS on each run keeps the hooks current after an upgrade, with
        their timeouts raised to HOOK_TIMEOUT seconds.
        """
        target = self.root / "claude" / "settings.json"
        with tempfile.TemporaryDirectory(prefix="tuitp-claude-") as config:
            settings = Path(config) / "settings.json"
            settings.write_text("{}", encoding="utf-8")
            # CLAUDE_CONFIG_DIR points the install at this folder, not at the user's settings.
            run([self.tuios, "integration", "install", "claude-code", "--no-skill", "--command", self.tuios],
                env=dict(os.environ, CLAUDE_CONFIG_DIR=config))
            hooks = read_json(settings).get("hooks")
        if not hooks:
            raise RuntimeError("tuios integration install claude-code wrote no hooks")
        for groups in hooks.values():
            for hook in (hook for group in groups for hook in group.get("hooks", [])):
                if isinstance(hook.get("timeout"), (int, float)) and hook["timeout"] < HOOK_TIMEOUT:
                    hook["timeout"] = HOOK_TIMEOUT
        value = {"hooks": hooks}
        # Rewrite only a change: Claude panes started earlier keep a file they may watch.
        current = shared(lambda: target.read_text(encoding="utf-8")) if target.is_file() else ""
        if current != json.dumps(value, indent=2):
            write_json(target, value)
        return target

    def watcher_digest(self):
        files = ("tuitp_watch.py", "tuitp_tabs.ps1", "tuitp_windows.py", "tuitp_model.py")
        return hashlib.sha256(b"".join((self.scripts / name).read_bytes() for name in files)).hexdigest()[:12]

    def ensure_watcher(self):
        """Start the tab watcher of tuitp_watch.py, or start it again when its files changed."""
        record_file = self.root / "watch.json"
        record = read_json(record_file) if record_file.is_file() else {}
        digest = self.watcher_digest()
        running = alive(record.get("process"))
        if running and record.get("digest") == digest:
            return False
        if running:
            terminate_exact(record["process"])
        process = self.start_helper("tuitp_watch.py", [str(self.tuios)], "watch.log")
        write_json(record_file, {"process": identity(process.pid), "digest": digest})
        return True

    def start_helper(self, script, args, log_name):
        """Start one of tuitp's Python helpers, detached, appending its output to a log in the state folder."""
        # As for stop outside TUIOS: without the TUIOS_* variables of a pane
        # tuitp may run in, and out of its job, so that it outlives the pane.
        env = {name: value for name, value in daemon_environment(os.environ).items()
               if not name.startswith("TUIOS_")}
        env["PYTHONUNBUFFERED"] = "1"
        flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
        with (self.root / log_name).open("ab") as log:
            argv = [sys.executable, str(self.scripts / script), *args]
            try:
                return subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=log, env=env,
                                        creationflags=flags | subprocess.CREATE_BREAKAWAY_FROM_JOB)
            except PermissionError:  # A job that refuses breakaway: the helper ends with it.
                return subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=log, env=env,
                                        creationflags=flags)

    def queue_resume(self, deliveries):
        """Start the helper that queues each resume command once its agent is at its prompt: tuitp does not wait."""
        self.start_helper("tuitp_resume.py", [str(self.tuios), json.dumps(deliveries)], "resume.log")

    def stop_watcher(self):
        record_file = self.root / "watch.json"
        record = read_json(record_file) if record_file.is_file() else {}
        if not alive(record.get("process")):
            return False
        terminate_exact(record["process"])  # Its tab selector reads its pipe and ends with it.
        return True

    def command(self, *args):
        return run([self.tuios, *args]).stdout

    def pane_names(self, session):
        """Return the names that address the panes of a session, as set-window --name gave them."""
        windows = json.loads(self.command("list-windows", "-s", session, "--json")).get("windows") or []
        return {w.get("custom_name") or w.get("display_name") or "" for w in windows}

    def pane_processes(self, session):
        windows = json.loads(self.command("list-windows", "-s", session, "--json")).get("windows") or []
        return [process for process in map(running, (w.get("pid") for w in windows)) if process]

    def codex_daemon(self, sessions):
        """Find the Codex app-server daemon, and count the Codex processes inside these sessions and outside them.

        Codex panes share one daemon per user, which the first of them starts
        outside its pane's console, with an updater and a code-mode host:
        deleting the session of that pane leaves them running.
        """
        roots = codex_daemon_roots(codex_home())
        if not roots:
            return None
        table = process_table()
        found = {role: descendants(table, [root]) for role, root in roots.items()}
        own = {process["pid"] for processes in found.values() for process in processes}
        # Any codex*.exe, such as the binary of an npm install: one too many only keeps the daemon.
        clients = [process for pid, (_, name) in table.items() if name.lower().startswith("codex") and pid not in own
                   for process in [running(pid)] if process]
        panes = []
        if clients and self.daemon_live:  # Without a daemon, no pane runs a program.
            with ThreadPoolExecutor(max_workers=min(4, len(sessions) or 1)) as pool:
                panes = [process for processes in pool.map(self.pane_processes, sessions) for process in processes]
        inside = sum(started_from(table, process, panes) for process in clients)
        return {**found, "inside": inside, "outside": len(clients) - inside}

    def stop_codex_daemon(self, found):
        """End the updater first, so that it starts no daemon again, then the daemon, then what it started.

        No Codex uses the daemon any more. 'codex app-server daemon stop' would
        ask it to stop, but each codex.exe start took 8 to 20s on a workstation
        with endpoint protection. Codex starts a new daemon on demand, after
        checking that the one its pid file names still runs.
        """
        failed = []
        for process in found.get("updater", []) + found.get("daemon", []):
            try:
                terminate_exact(process)
            except OSError as error:
                if running(process["pid"]) == process:  # Not one that ended meanwhile.
                    failed.append(f"process {process['pid']}: {error}")
        if failed:
            raise OSError("; ".join(failed))

    def snapshot(self):
        result = run([self.tuios, "ls", "--json"], check=False)
        try:
            rows = json.loads(result.stdout)
            if not isinstance(rows, list) or any(not isinstance(r.get("name"), str) for r in rows):
                raise ValueError("Unexpected session list shape")
            if result.returncode not in (0, 1, 3):
                raise ValueError("Unexpected exit code")
            if result.returncode and any(not r.get("saved") for r in rows):
                raise ValueError("Failed live-session query")
        except (ValueError, TypeError, AttributeError) as error:
            raise RuntimeError(f"Cannot safely read TUIOS sessions: {result.stderr or result.stdout}") from error
        self.daemon_live = result.returncode == 0 and not any(r.get("saved") for r in rows)
        return {r["name"]: r for r in rows}

    def ensure_daemon(self):
        if self.daemon_live:
            return
        self.root.mkdir(parents=True, exist_ok=True)
        # The foreground 'daemon' command is explicitly detached here. It
        # restores saved layouts before we issue any new/kill commands.
        with timed("daemon ready, including its 'ls' polls"):
            with (self.root / "daemon.log").open("ab") as log:
                subprocess.Popen([str(self.tuios), "daemon"], stdin=subprocess.DEVNULL,
                                 stdout=log, stderr=log, env=daemon_environment(os.environ),
                                 creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP)
            deadline = time.monotonic() + 90
            while time.monotonic() < deadline:
                time.sleep(1)
                self.snapshot()
                if self.daemon_live:
                    return
        raise RuntimeError(f"TUIOS daemon did not become ready; see {self.root / 'daemon.log'}")

    def host_path(self, record):
        token = record["token"]
        if len(token) != 32 or any(c not in "0123456789abcdef" for c in token):
            raise ValueError("Invalid managed tab token")
        return self.root / "hosts" / f"{token}.json"

    def tab_alive(self, record):
        if "legacy" in record:
            return alive(record["legacy"]["process"])
        manifest = self.host_path(record)
        live_file = manifest.with_suffix(".live")
        if live_file.exists():
            return alive(read_json(live_file)["process"])
        # A previous launcher may have stopped between asking WT to open a
        # tab and its host registering. Do not issue a duplicate immediately.
        if record.get("launched", 0) > time.time() - 30:
            return self.wait_host(record, 30)
        return False

    def wait_host(self, record, timeout=30):
        live_file = self.host_path(record).with_suffix(".live")
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if live_file.exists() and alive(read_json(live_file)["process"]):
                return True
            time.sleep(.25)
        return False

    def open_tab(self, record):
        tab = Tab(**record["spec"])
        manifest = self.host_path(record)
        write_json(manifest, {"tab": record["spec"], "tuios": str(self.tuios), "cmd": str(self.cmd),
                              "scripts": str(self.scripts), "pane": str(self.pane_helper())})
        argv = [str(self.wt), "-w", "tuitp-" + tab.window, "new-tab"]
        profile = os.environ.get("TUITP_PROFILE", os.environ.get("WTP_PROFILE", ""))
        if profile:
            argv += ["-p", profile]
        if tab.title:
            argv += ["--suppressApplicationTitle", "--title", tab.title]
        folder = tab.folder or str(self.scripts)
        argv += ["-d", folder, sys.executable, str(self.scripts / "tuitp_host.py"), str(manifest)]
        # A first WT invocation can own the GUI's lifetime. Waiting on it
        # would time out (and kill it); the host registration is our handshake.
        log_file = manifest.with_suffix(".wt.log")
        with timed(f"open tab {tab.title or tab.folder}, until its host registers"):
            with log_file.open("ab") as log:
                launcher = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                            creationflags=subprocess.CREATE_NO_WINDOW)
            registered = self.wait_host(record)
        if not registered:
            raise RuntimeError(f"WT did not register tab {tab.title or tab.folder} "
                               f"(launcher exit: {launcher.poll()}); see {log_file}")

    def release_tab(self, record):
        if "legacy" not in record:
            self.host_path(record).with_suffix(".ready").touch()

    def verify_tabs(self, records):
        # Registration alone only proves the waiting host started. Require its
        # foreground child to survive startup before closing old attachments.
        pending = [r for r in records if "legacy" not in r]
        with timed(f"{len(pending)} tabs attached ('tuios attach' started in each)"):
            self._wait_attached(pending)

    def _wait_attached(self, pending):
        deadline = time.monotonic() + 30
        while pending and time.monotonic() < deadline:
            for record in pending[:]:
                manifest = self.host_path(record)
                error_file = manifest.with_suffix(".error")
                if error_file.exists():
                    raise RuntimeError(error_file.read_text(encoding="utf-8"))
                info = read_json(manifest.with_suffix(".live"))
                if not alive(info["process"]):
                    raise RuntimeError(f"Tab exited during startup: {record['spec']['title']}")
                if (info.get("status") == "attached" and alive(info.get("child"))
                        and info.get("attached", time.time()) < time.time() - 1):
                    pending.remove(record)
            if pending:
                time.sleep(.25)
        if pending:
            raise RuntimeError("Tabs did not attach: " + ", ".join(r["spec"]["title"] for r in pending))

    def close_tab(self, record):
        if "legacy" in record:
            # Only the verified CMD wrapper and its 'tuios attach' client,
            # never the daemon or a whole WindowsTerminal.exe process tree.
            for process in record["legacy"].get("clients", []):
                terminate_exact(process)
            terminate_exact(record["legacy"]["process"])
            return
        manifest = self.host_path(record)
        manifest.with_suffix(".stop").touch()
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if not self.tab_alive(record):
                return
            time.sleep(.25)
        raise RuntimeError(f"Tab did not close: {record['spec']['title']}")

    def fail_tabs(self, records, message):
        for record in records:
            if "legacy" not in record:
                self.host_path(record).with_suffix(".abort").write_text(message, encoding="utf-8")

    def legacy_tabs(self, migration):
        """Discover the old launcher's exact CMD markers during installation migration."""
        helper = str(self.scripts / "tuitp.tab.bat")
        powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        script = ("$ErrorActionPreference='Stop'; @("
                  "Get-CimInstance Win32_Process -Filter \"Name='cmd.exe' OR Name='tuios.exe'\" | "
                  "Select-Object ProcessId,ParentProcessId,CommandLine,Name) | ConvertTo-Json -Compress")
        rows = json.loads(run([powershell, "-NoProfile", "-Command", script]).stdout or "[]")
        if isinstance(rows, dict):
            rows = [rows]
        result = {}
        for row in rows:
            command = row.get("CommandLine") or ""
            for declaration in migration.get("tabs", []):
                # Match the exact old /k helper session form, including the
                # command boundary. Never adopt /k echo <helper> <session>.
                expected = (r'(?i)^(?:"[^"]*cmd\.exe"|\S*cmd\.exe)\s+/k\s+"?'
                            + re.escape(helper) + r'"?\s+"?'
                            + re.escape(declaration["sessions"][0]) + r'"?\s*$')
                if row["Name"].lower() != "cmd.exe" or not re.fullmatch(expected, command):
                    continue
                owner = identity(row["ProcessId"])
                if not owner:
                    continue
                clients = []
                for child in rows:
                    child_command = (child.get("CommandLine") or "").replace('"', "").lower()
                    if (child["ParentProcessId"] == row["ProcessId"] and child["Name"].lower() == "tuios.exe"
                            and child_command.endswith("attach " + declaration["sessions"][0].lower())):
                        client = identity(child["ProcessId"])
                        if client:
                            clients.append(client)
                slot = declaration["slot"]
                if slot in result:
                    slot += "~" + str(row["ProcessId"])
                result[slot] = {"spec": declaration, "legacy": {"process": owner, "clients": clients}}
        return result
