"""Install the tuitp files, retaining the local list and migration information."""
from __future__ import annotations

import argparse
from dataclasses import asdict
from datetime import datetime
import os
from pathlib import Path
import re
import shutil

from tuitp_model import Tab, key
from tuitp_windows import write_json


FILES = ("tuitp.bat", "tuitp.setup.bat", "tuitp.tab.bat", "tuitp.pane.bat",
         "tuitp.py", "tuitp_model.py", "tuitp_windows.py", "tuitp_host.py", "tuitp_watch.py", "tuitp_resume.py",
         "tuitp_conversations.py", "tuitp_tabs.ps1", "tuitp_install.py", "tuitp.list.example")
# setup.bat copies the old hard-coded launcher here before replacing it.
LEGACY_DIR = "tuitp-legacy"


def legacy_layout(target: Path):
    launcher, setup = target / "tuitp.bat", target / "tuitp.setup.bat"
    if not launcher.is_file() or not setup.is_file():
        return None
    text = launcher.read_text(encoding="utf-8-sig")
    if "call :tab" not in text or "tuitp.py" in text:
        return None
    match = re.search(r"\s-w\s+tuitp-([A-Za-z0-9_.-]+)", text)
    if not match:
        raise ValueError("Cannot determine the old tuitp window name; installation stopped")
    window = match[1]
    tabs = []
    for line in text.splitlines():
        match = re.fullmatch(r'call :tab\s+"?([^"\r\n]+?)"?\s+"?([A-Za-z0-9_.-]+)"?', line.strip(), re.I)
        if match:
            title, session = match.groups()
            tabs.append(asdict(Tab(window, title, "tuios", sessions=[session],
                                  slot=key(f"{window}|tuios|{title}"))))
    sessions = {}
    text = setup.read_text(encoding="utf-8-sig")
    for match in re.finditer(r'^call :ensure\s+(\S+)\s+"([^"]+)"\s+(project|single)\b', text, re.M | re.I):
        name, folder, kind = match.groups()
        folder = re.sub(r"%([^%]+)%", lambda m: os.environ[m[1]], folder)
        sessions[name] = {"name": name, "folder": str(Path(folder).resolve()), "kind": kind.lower()}
    if not tabs or not sessions or any(t["sessions"][0] not in sessions for t in tabs):
        raise ValueError("Cannot read the old tuitp layout; installation stopped before replacing files")
    return {"tabs": tabs, "sessions": sessions}


def legacy_list(migration) -> str:
    lines = []
    for tab in migration["tabs"]:
        lines += ["--- " + tab["window"], "=== " + tab["title"]]
        names = tab["sessions"]
        # The old multi-project tab attached to its first project;
        # the other project sessions lived in that same group.
        if migration["sessions"][names[0]]["kind"] == "project":
            names = [name for name, s in migration["sessions"].items() if s["kind"] == "project"]
        for name in names:
            session = migration["sessions"][name]
            lines.append(f"+ {session['folder']}|{name}|{session['kind']}")
        lines.append("")
    return "\n".join(lines)


def adopt_legacy(target: Path) -> bool:
    """Capture the old launcher setup.bat kept aside, so setup needs no Python.

    Return True when the layout is captured now; an existing capture is kept.
    """
    record = target / "tuitp.legacy.json"
    if record.exists():
        return False
    try:
        migration = legacy_layout(target / LEGACY_DIR)
    except ValueError as error:
        raise ValueError(f"{error}: {target / LEGACY_DIR} (remove that folder to skip the migration)") from error
    if not migration:
        return False
    write_json(record, migration)
    local_list = target / "tuitp.list"
    if not local_list.exists():
        local_list.write_text(legacy_list(migration), encoding="utf-8")
    return True


def install(source: Path, target: Path):
    source, target = source.resolve(), target.resolve()
    if source == target:
        raise ValueError("Source and installation directory must differ")
    for name in FILES:
        if not (source / name).is_file():
            raise ValueError(f"Missing installation source: {source / name}")
    migration = legacy_layout(target)
    target.mkdir(parents=True, exist_ok=True)
    backup = target / "tuitp-backups" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    existing = [name for name in (*FILES, "tuitp.list", "tuitp.legacy.json") if (target / name).is_file()]
    if existing:
        backup.mkdir(parents=True)
        for name in existing:
            shutil.copy2(target / name, backup / name)
    if migration:
        write_json(target / "tuitp.legacy.json", migration)
    for name in FILES:
        shutil.copy2(source / name, target / name)
    local_list = target / "tuitp.list"
    if not local_list.exists():
        seed = source / "tuitp.list"
        if seed.is_file():
            shutil.copy2(seed, local_list)
        elif migration:
            local_list.write_text(legacy_list(migration), encoding="utf-8")
        else:
            print("Create tuitp.list from tuitp.list.example before launching.")
    print(f"Installed tuitp into {target}")
    if existing:
        print(f"Previous files backed up to {backup}")
    print("Run tuitp dry to review changes, then tuitp to apply them.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=Path, default=Path(os.environ.get("HOME", os.environ["USERPROFILE"])) / "bin")
    arguments = parser.parse_args()
    install(Path(__file__).resolve().parent, arguments.target)
