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
MESSAGE_LIST_MARKERS = {"liste des messages", "message list"}
STATUS_LINE_RE = re.compile(r"^(?:votre message de statut|your status message)\b", re.IGNORECASE)
CONTEXT_MENU_RE = re.compile(r"(?:menu contextuel|context menu)$", re.IGNORECASE)
SEARCH_HINT_RE = re.compile(r"^(?:appuyez sur|press) ctrl\+f\b", re.IGNORECASE)
UI_NOISE = {
    "comporte un menu contextuel",
    "dispose d’un menu contextuel",
    "dispose d'un menu contextuel",
    "présente un menu contextuel",
    "presente un menu contextuel",
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


def _is_header(lines: list[str], index: int) -> bool:
    """Return whether an ``Author, timestamp`` message header starts at index."""
    return (index + 1 < len(lines) and bool(lines[index]) and
            not is_timestamp(lines[index]) and is_timestamp(lines[index + 1]) and
            (index + 2 == len(lines) or not lines[index + 2]))


def _is_continuation(lines: list[str], index: int) -> bool:
    """Return whether a lone timestamp starts a follow-up message.

    Teams omits the author line on consecutive messages from the same author.
    """
    return (is_timestamp(lines[index]) and (index == 0 or not lines[index - 1]) and
            (index + 1 == len(lines) or not lines[index + 1]))


def _remove_chrome(lines: list[str]) -> list[str]:
    """Remove the Teams navigation and chat header preceding each message list.

    A Ctrl+A copy starts with the status message, the chat list and the chat
    header, then the "Liste des messages" marker. The chrome starts at the
    status message, or else at the first context-menu label, after the last
    message header; with no message before the marker, everything goes.
    """
    result: list[str] = []
    for line in lines:
        if _line_key(line) not in MESSAGE_LIST_MARKERS:
            result.append(line)
            continue
        status = menu = None
        for index in range(len(result) - 1, -1, -1):
            if _is_header(result, index):
                break
            if STATUS_LINE_RE.match(result[index]):
                status = index
            elif CONTEXT_MENU_RE.search(result[index]):
                menu = index
        else:
            status = 0
        cut = status if status is not None else menu
        if cut is not None:
            del result[cut:]
    return result


def _is_noise(line: str) -> bool:
    return _line_key(line) in UI_NOISE or bool(SEARCH_HINT_RE.match(line))


MessageKey = tuple[tuple[str | None, str] | None, tuple[str, ...]]


def _split_messages(lines: list[str]) -> list[list[str]]:
    """Split cleaned lines into blocks, each starting at a message header."""
    blocks: list[list[str]] = []
    current: list[str] = []
    for index, line in enumerate(lines):
        if current and (_is_header(lines, index) or _is_continuation(lines, index)):
            blocks.append(current)
            current = []
        current.append(line)
    blocks.append(current)
    return [block for block in map(_trim_blank_lines, blocks) if block]


def _message_keys(blocks: list[list[str]]) -> list[MessageKey]:
    """Return each block's (author, timestamp) header and identifying body.

    A follow-up message takes the author of the previous block, or None when
    it opens the copy. Reaction counts are left out of the body because they
    change between copies.
    """
    keys: list[MessageKey] = []
    author = None
    for block in blocks:
        lines = [_line_key(line) for line in block if line]
        if _is_header(block, 0):
            author = lines[0]
            header, body = (author, lines[1]), lines[2:]
        elif _is_continuation(block, 0):
            header, body = (author, lines[0]), lines[1:]
        else:
            header, body = None, lines
        keys.append((header, tuple(key for key in body if not REACTION_RE.match(key))))
    return keys


def _same_header(header: tuple[str | None, str], other: tuple[str | None, str]) -> bool:
    return header[1] == other[1] and (
        header[0] is None or other[0] is None or header[0] == other[0])


def _starts_with(lines: tuple[str, ...], prefix: tuple[str, ...]) -> bool:
    return lines[:len(prefix)] == prefix


def _contains(lines: tuple[str, ...], part: tuple[str, ...]) -> bool:
    width = len(part)
    return any(lines[start:start + width] == part for start in range(len(lines) - width + 1))


def _find_message(keys: list[MessageKey], key: MessageKey) -> int | None:
    """Return the index of the collected message matching key, if any.

    Messages with the same author and timestamp match when one body starts
    with the other, so a message cut at the edge of a copy matches its full
    version; an unknown author matches any author. A block without header
    matches any block containing its lines.
    """
    header, body = key
    for index, (other_header, other_body) in enumerate(keys):
        if header is None:
            if _contains(other_body, body):
                return index
        elif other_header and _same_header(header, other_header) and (
                _starts_with(body, other_body) or _starts_with(other_body, body)):
            return index
    return None


def _merge_messages(blocks: list[list[str]],
                    fragment: list[list[str]]) -> tuple[list[list[str]], int, int]:
    """Merge fragment blocks into blocks, keeping each message once.

    A new message is inserted after the previous fragment message already
    collected, so a copy scrolled above or below the transcript lands in
    conversation order. A known message is replaced by a longer or equally
    long version, which keeps the latest reactions. Returns the merged blocks
    with the added and updated message counts.
    """
    result = list(blocks)
    keys = _message_keys(result)
    fragment_keys = _message_keys(fragment)
    anchor = len(result) - 1
    for key in fragment_keys:
        index = _find_message(keys, key) if key[0] else None
        if index is not None:
            anchor = index - 1
            break
    added = updated = 0
    for block, key in zip(fragment, fragment_keys):
        index = _find_message(keys, key)
        if index is None:
            anchor += 1
            result.insert(anchor, block)
            keys.insert(anchor, key)
            added += 1
        elif key[0]:
            if block != result[index] and len(key[1]) >= len(keys[index][1]):
                result[index] = block
                keys[index] = key
                updated += 1
            anchor = index
    return result, added, updated


def _dedupe(blocks: list[list[str]]) -> list[list[str]]:
    """Merge blocks into themselves until each message appears once.

    Follow-up authors are taken from the merged order, so one pass can reveal
    a duplicate the previous pass could not see.
    """
    while True:
        merged, _, _ = _merge_messages([], blocks)
        if len(merged) == len(blocks):
            return merged
        blocks = merged


def _render(blocks: list[list[str]]) -> str:
    return "\n\n".join("\n".join(block) for block in blocks)


def clean_teams_text(text: str) -> str:
    """Return a cleaned transcript copied from Teams, each message once."""
    normalized = normalize_text(text)
    if not normalized:
        return ""
    lines = normalized.split("\n")
    lines = _remove_teams_previews(lines)
    lines = _normalize_metadata_order(lines)
    lines = _remove_reaction_duplicates(lines)
    lines = _remove_chrome(lines)
    lines = [line for line in lines if not _is_noise(line)]
    return _render(_dedupe(_split_messages(_trim_blank_lines(lines))))


def merge_transcript(existing: str, fragment: str) -> tuple[str, int, int]:
    """Merge a cleaned copy into the transcript, keeping each message once.

    Returns the merged transcript with the added and updated message counts.
    """
    blocks, added, updated = _merge_messages(
        _split_messages(normalize_text(existing).split("\n")),
        _split_messages(normalize_text(fragment).split("\n")),
    )
    deduped = _dedupe(blocks)
    return _render(deduped), max(0, added - (len(blocks) - len(deduped))), updated


def prepare_daily_file(path: Path, today: date | None = None) -> str:
    """Create/truncate a stale daily file, or return today's existing content."""
    today = today or date.today()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and datetime.fromtimestamp(path.stat().st_mtime).date() == today:
        return path.read_text(encoding="utf-8-sig")
    path.write_text("", encoding="utf-8")
    return ""


def write_transcript(path: Path, content: str) -> None:
    """Replace the transcript file, never leaving it half written."""
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="") as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


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
    stored = normalize_text(prepare_daily_file(path))
    content = clean_teams_text(stored)
    if content != stored:
        write_transcript(path, content)
        print(f"Kept each message once in {path}: "
              f"{len(stored.splitlines())} -> {len(content.splitlines())} line(s).")
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
                    merged, added, updated = merge_transcript(content, cleaned)
                    if merged != content:
                        write_transcript(path, merged)
                        content = merged
                        changes = f", updated {updated}" if updated else ""
                        print(f"Collected {added} new message(s){changes}.")
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
