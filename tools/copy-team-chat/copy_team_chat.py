"""Collect and clean Microsoft Teams Ctrl+A/Ctrl+C chat transcripts."""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
from datetime import date, datetime
import os
from pathlib import Path
import re
import sys
import time

# cSpell: disable
INVISIBLE = str.maketrans("", "", "\u200b\u200e\u200f\u2066\u2067\u2068\u2069\ufeff")
SPACE_RE = re.compile(r"[ \t\v\f]+")
TIME_RE = re.compile(
    r"^(?:(?:[01]?\d|2[0-3])[:h][0-5]\d(?:[:h][0-5]\d)?|"
    r"(?:0?[1-9]|1[0-2]):[0-5]\d(?::[0-5]\d)?\s*[ap]\.?m\.?)$",
    re.IGNORECASE,
)
DATE_TIME_RE = re.compile(
    r"^(?:\d{4}[./-]\d{1,2}[./-]\d{1,2}|"
    r"\d{1,2}[./-]\d{1,2}(?:[./-]\d{2,4})?)(?:\s+(?:à|at)?\s*"
    r"(?:(?:[01]?\d|2[0-3])[:h][0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[ap]\.?m\.?))?$",
    re.IGNORECASE,
)
LOCALIZED_DATE_TIME_RE = re.compile(
    r"^(?=.*(?:"
    r"monday|tuesday|wednesday|thursday|friday|saturday|sunday|"
    r"lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|"
    r"january|february|march|april|may|june|july|august|september|october|november|december|"
    r"janvier|février|fevrier|mars|avril|mai|juin|juillet|août|aout|septembre|octobre|novembre|décembre|decembre|"
    r"today|yesterday|aujourd'hui|aujourd’hui|hier)\b).+"
    r"(?:(?:[01]?\d|2[0-3])[:h][0-5]\d|(?:0?[1-9]|1[0-2]):[0-5]\d\s*[ap]\.?m\.?)$",
    re.IGNORECASE,
)
PREVIEW_AUTHOR_RE = re.compile(r"^(?P<preview>.+)\s+(?:par|by)\s+(?P<author>.+)$", re.IGNORECASE)
REACTION_RE = re.compile(r"^\d+\s+(?:réaction|réactions|reaction|reactions)\b", re.IGNORECASE)
BARE_REACTION_RE = re.compile(r"^[\U0001F000-\U0001FAFF\u2600-\u27BF\ufe0f\u200d]+$")
UI_NOISE = {
    "dispose d’un menu contextuel",
    "dispose d'un menu contextuel",
    "has context menu",
    "réponse aux participants externes.",
    "reponse aux participants externes.",
    "reply to external participants.",
    "taper un message",
    "type a message",
}


def _clean_line(line: str) -> str:
    line = line.translate(INVISIBLE).replace("\u00a0", " ")
    return SPACE_RE.sub(" ", line).strip()


def normalize_text(text: str) -> str:
    """Normalize clipboard text without changing meaningful line wrapping."""
    raw_lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    normalized: list[str] = []
    for line in (_clean_line(line) for line in raw_lines):
        if not line:
            if normalized and normalized[-1]:
                normalized.append("")
        else:
            normalized.append(line)
    while normalized and not normalized[-1]:
        normalized.pop()
    return "\n".join(normalized)


def is_timestamp(line: str) -> bool:
    line = line.strip(" []()")
    return bool(
        TIME_RE.fullmatch(line)
        or DATE_TIME_RE.fullmatch(line)
        or LOCALIZED_DATE_TIME_RE.fullmatch(line)
    )


def _line_key(line: str) -> str:
    return SPACE_RE.sub(" ", line).strip().casefold()


def _author_matches(preview_author: str, full_author: str) -> bool:
    """Match a full author or a Teams-truncated author such as ``Dan...``."""
    preview = _line_key(preview_author)
    full = _line_key(full_author)
    if preview == full:
        return True
    if preview.endswith(("...", "…")):
        prefix = preview.rstrip(". …")
        return len(prefix) >= 4 and full.startswith(prefix)
    return False


def _next_nonblank(lines: list[str], start: int) -> int | None:
    for index in range(start, len(lines)):
        if lines[index]:
            return index
    return None


def _trim_blank_lines(lines: list[str]) -> list[str]:
    compact: list[str] = []
    for line in lines:
        if not line:
            if compact and compact[-1]:
                compact.append("")
        else:
            compact.append(line)
    while compact and not compact[-1]:
        compact.pop()
    return compact


def _remove_teams_previews(lines: list[str]) -> list[str]:
    """Remove Teams' truncated accessible preview while retaining metadata."""
    remove: set[int] = set()
    for index, line in enumerate(lines):
        match = PREVIEW_AUTHOR_RE.match(line)
        if not match:
            continue
        first = _next_nonblank(lines, index + 1)
        second = _next_nonblank(lines, first + 1) if first is not None else None
        if first is None or second is None:
            continue
        author = match.group("author")
        incoming = _author_matches(author, lines[first]) and is_timestamp(lines[second])
        outgoing = is_timestamp(lines[first]) and _author_matches(author, lines[second])
        if incoming or outgoing:
            remove.add(index)
    return [line for index, line in enumerate(lines) if index not in remove]


def _normalize_metadata_order(lines: list[str]) -> list[str]:
    """Use Author, timestamp order for both incoming and outgoing messages."""
    result = lines[:]
    index = 0
    while index + 1 < len(result):
        if (is_timestamp(result[index]) and result[index + 1] and
                not is_timestamp(result[index + 1]) and
                (index + 2 == len(result) or not result[index + 2])):
            result[index], result[index + 1] = result[index + 1], result[index]
            index += 2
        else:
            index += 1
    return result


def _remove_reaction_duplicates(lines: list[str]) -> list[str]:
    result: list[str] = []
    for index, line in enumerate(lines):
        if BARE_REACTION_RE.fullmatch(line):
            following = _next_nonblank(lines, index + 1)
            if following is not None and REACTION_RE.match(lines[following]):
                continue
        result.append(line)
    return result


def _collapse_repeated_block(lines: list[str]) -> list[str]:
    """Remove a later contiguous duplicate block within one clipboard value."""
    nonblank = [(index, _line_key(line)) for index, line in enumerate(lines) if line]
    keys = [key for _, key in nonblank]
    best: tuple[int, int, int] | None = None
    for left in range(len(keys)):
        for right in range(left + 1, len(keys)):
            length = 0
            while (right + length < len(keys) and left + length < right and
                   keys[left + length] == keys[right + length]):
                length += 1
            if length >= 2 and (best is None or length > best[2]):
                best = (left, right, length)
    if best is None:
        return lines
    _, right, length = best
    remove = {nonblank[pos][0] for pos in range(right, right + length)}
    result = [line for index, line in enumerate(lines) if index not in remove]
    return _collapse_repeated_block(_trim_blank_lines(result))


def clean_teams_text(text: str) -> str:
    """Return a cleaned transcript fragment copied from Teams."""
    normalized = normalize_text(text)
    if not normalized:
        return ""
    lines = normalized.split("\n")
    lines = _remove_teams_previews(lines)
    lines = _normalize_metadata_order(lines)
    lines = _remove_reaction_duplicates(lines)
    lines = [line for line in lines if _line_key(line) not in UI_NOISE]
    lines = _collapse_repeated_block(_trim_blank_lines(lines))
    return "\n".join(_trim_blank_lines(lines))


def append_novel(existing: str, fragment: str) -> tuple[str, str]:
    """Append only lines not already present at the end of the transcript."""
    existing = normalize_text(existing)
    fragment = normalize_text(fragment)
    if not fragment:
        return existing, ""
    if not existing:
        return fragment, fragment
    old_lines = existing.split("\n")
    new_lines = fragment.split("\n")
    old_keys = [_line_key(line) for line in old_lines]
    new_keys = [_line_key(line) for line in new_lines]
    width = len(new_keys)
    for start in range(len(old_keys) - width + 1):
        if old_keys[start:start + width] == new_keys:
            return existing, ""
    overlap = 0
    for size in range(min(len(old_keys), len(new_keys)), 0, -1):
        if old_keys[-size:] == new_keys[:size]:
            overlap = size
            break
    novel_lines = new_lines[overlap:]
    while novel_lines and not novel_lines[0]:
        novel_lines.pop(0)
    if not novel_lines:
        return existing, ""
    appended = "\n".join(novel_lines)
    return existing + "\n\n" + appended, appended


def prepare_daily_file(path: Path, today: date | None = None) -> str:
    """Create/truncate a stale daily file, or return today's existing content."""
    today = today or date.today()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and datetime.fromtimestamp(path.stat().st_mtime).date() == today:
        return path.read_text(encoding="utf-8-sig")
    path.write_text("", encoding="utf-8")
    return ""


def append_file(path: Path, current: str, appended: str) -> None:
    if not appended:
        return
    separator = "" if not current else ("" if current.endswith("\n") else "\n\n")
    with path.open("a", encoding="utf-8", newline="") as stream:
        stream.write(separator + appended)
        stream.flush()
        os.fsync(stream.fileno())


class WindowsClipboard:
    CF_UNICODETEXT = 13
    GMEM_MOVEABLE = 0x0002

    def __init__(self) -> None:
        if os.name != "nt":
            raise RuntimeError("copy-team-chat requires Windows")
        self.user32 = ctypes.WinDLL("user32", use_last_error=True)
        self.kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self._configure_signatures()

    def _configure_signatures(self) -> None:
        self.user32.OpenClipboard.argtypes = [wintypes.HWND]
        self.user32.OpenClipboard.restype = wintypes.BOOL
        self.user32.CloseClipboard.restype = wintypes.BOOL
        self.user32.IsClipboardFormatAvailable.argtypes = [wintypes.UINT]
        self.user32.IsClipboardFormatAvailable.restype = wintypes.BOOL
        self.user32.GetClipboardData.argtypes = [wintypes.UINT]
        self.user32.GetClipboardData.restype = wintypes.HANDLE
        self.user32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
        self.user32.SetClipboardData.restype = wintypes.HANDLE
        self.user32.GetClipboardSequenceNumber.restype = wintypes.DWORD
        self.kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
        self.kernel32.GlobalAlloc.restype = wintypes.HGLOBAL
        self.kernel32.GlobalLock.argtypes = [wintypes.HGLOBAL]
        self.kernel32.GlobalLock.restype = wintypes.LPVOID
        self.kernel32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
        self.kernel32.GlobalUnlock.restype = wintypes.BOOL
        self.kernel32.GlobalFree.argtypes = [wintypes.HGLOBAL]
        self.kernel32.GlobalFree.restype = wintypes.HGLOBAL

    def sequence(self) -> int:
        return int(self.user32.GetClipboardSequenceNumber())

    def _open(self) -> None:
        for _ in range(40):
            if self.user32.OpenClipboard(None):
                return
            time.sleep(0.01)
        raise OSError(ctypes.get_last_error(), "unable to open the clipboard")

    def read_text(self) -> str | None:
        self._open()
        try:
            if not self.user32.IsClipboardFormatAvailable(self.CF_UNICODETEXT):
                return None
            handle = self.user32.GetClipboardData(self.CF_UNICODETEXT)
            if not handle:
                return None
            pointer = self.kernel32.GlobalLock(handle)
            if not pointer:
                return None
            try:
                return ctypes.wstring_at(pointer)
            finally:
                self.kernel32.GlobalUnlock(handle)
        finally:
            self.user32.CloseClipboard()

    def write_text(self, text: str) -> None:
        payload = (text + "\0").encode("utf-16-le")
        handle = self.kernel32.GlobalAlloc(self.GMEM_MOVEABLE, len(payload))
        if not handle:
            raise MemoryError("unable to allocate clipboard memory")
        pointer = self.kernel32.GlobalLock(handle)
        if not pointer:
            self.kernel32.GlobalFree(handle)
            raise MemoryError("unable to lock clipboard memory")
        ctypes.memmove(pointer, payload, len(payload))
        self.kernel32.GlobalUnlock(handle)
        self._open()
        try:
            if not self.user32.EmptyClipboard():
                raise OSError(ctypes.get_last_error(), "unable to empty the clipboard")
            if not self.user32.SetClipboardData(self.CF_UNICODETEXT, handle):
                raise OSError(ctypes.get_last_error(), "unable to set clipboard text")
            handle = None
        finally:
            self.user32.CloseClipboard()
            if handle:
                self.kernel32.GlobalFree(handle)


class CtrlVPoller:
    VK_CONTROL = 0x11
    VK_V = 0x56

    def __init__(self) -> None:
        self.user32 = ctypes.WinDLL("user32", use_last_error=True)
        self.user32.GetAsyncKeyState.argtypes = [ctypes.c_int]
        self.user32.GetAsyncKeyState.restype = wintypes.SHORT
        self.was_v_down = self._down(self.VK_V)

    def _down(self, key: int) -> bool:
        return bool(self.user32.GetAsyncKeyState(key) & 0x8000)

    def pressed(self) -> bool:
        v_down = self._down(self.VK_V)
        pressed = v_down and not self.was_v_down and self._down(self.VK_CONTROL)
        self.was_v_down = v_down
        return pressed


def default_output_path() -> Path:
    return Path(os.environ.get("HOME") or Path.home()) / "a.tc.copy"


def listen(path: Path, poll_ms: int = 50) -> int:
    content = normalize_text(prepare_daily_file(path))
    clipboard = WindowsClipboard()
    keyboard = CtrlVPoller()
    clipboard.write_text(content)
    sequence = clipboard.sequence()
    print(f"Collecting Teams copies in {path}")
    print("Press Ctrl+V anywhere to paste the full transcript and stop.")
    try:
        while True:
            if keyboard.pressed():
                print(f"Stopped. Clipboard contains {len(content.splitlines())} line(s).")
                return 0
            current_sequence = clipboard.sequence()
            if current_sequence != sequence:
                copied = clipboard.read_text()
                sequence = current_sequence
                if copied is not None:
                    cleaned = clean_teams_text(copied)
                    updated, appended = append_novel(content, cleaned)
                    if appended:
                        append_file(path, content, appended)
                        content = updated
                        print(f"Collected {len(appended.splitlines())} new line(s).")
                    if copied != content:
                        clipboard.write_text(content)
                        sequence = clipboard.sequence()
            time.sleep(poll_ms / 1000)
    except KeyboardInterrupt:
        clipboard.write_text(content)
        print("\nStopped. Clipboard contains the full transcript.")
        return 130


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect, clean, and deduplicate Teams chat copies until Ctrl+V."
    )
    parser.add_argument("--file", type=Path, default=default_output_path())
    parser.add_argument("--poll-ms", type=int, default=50, help=argparse.SUPPRESS)
    parser.add_argument("--clean-stdin", action="store_true",
                        help="clean standard input once and print it")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if args.clean_stdin:
        cleaned = clean_teams_text(sys.stdin.read())
        if cleaned:
            sys.stdout.write(cleaned + "\n")
        return 0
    if args.poll_ms < 10:
        raise SystemExit("--poll-ms must be at least 10")
    return listen(args.file.expanduser(), args.poll_ms)


if __name__ == "__main__":
    raise SystemExit(main())
