"""Tell the agent panes that tuitp starts to resume the llm-shared session paused in their checkout.

An llm-shared pause leaves one resume prompt per checkout, in its review
artifact home: `a.session-resume.local.md`, whose first line names the agent
that paused (`# chatgpt: Resume session: <task>`). Once resume-session has
read that prompt, the receipt `a.session-resume.used.local.md` holds its
SHA-256. A prompt with no receipt for its bytes waits for its agent.

When tuitp starts the panes of a session, the first pane declared for that
agent and folder runs resume-session, and the first pane of the other agent
runs review-resume as reviewer when the pause was a review requestor's: its
resume may publish a request. tuitp only reads these files: resume-session and
review-resume make every check again before they act.

Run as a script, this module is the helper that types each command into its
pane once the agent there is at its prompt, through `tuios queue`.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from tuitp_model import PANE_ROLES, key, pane_name

PROMPT, RECEIPT = "a.session-resume.local.md", "a.session-resume.used.local.md"
# The agent ids that llm-shared's pause-session writes, by pane role.
AGENTS = {"Claude": "claude", "Codex": "chatgpt"}
# How each agent calls an llm-shared skill. "as reviewer" is the role that
# review-resume takes only from the person: tuitp asks it on their behalf.
# Typed at its end, a Codex skill name keeps the skill picker open, which
# takes the Enter of the queue: a space closes the picker first.
COMMANDS = {("Claude", "resume"): "/resume-session",
            ("Codex", "resume"): "$llm-shared:resume-session ",
            ("Claude", "review"): "/review-resume as reviewer",
            ("Codex", "review"): "$llm-shared:review-resume as reviewer"}
HEADING = re.compile(r"# ([a-z0-9-]+): Resume session: (.*)")
# Long enough for a Codex that fails its first start twice, or for the person
# to answer a "Trust this folder?" question.
WAIT_MS = 600_000


def artifact_home(root: Path) -> Path:
    """Return the review artifact home of a checkout: `.reviews`, unless `.review-artifacts.ini` declares another."""
    declaration = root / ".review-artifacts.ini"
    if not declaration.exists():
        return root / ".reviews"
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    try:
        parser.read_string(declaration.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, configparser.Error) as error:
        raise ValueError(f"cannot read {declaration}: {error}") from error
    if parser.sections() != ["review-artifacts"] or set(parser["review-artifacts"]) != {"home"}:
        raise ValueError(f"{declaration} must declare only [review-artifacts] home")
    relative = Path(parser["review-artifacts"]["home"].strip())
    home = (root / relative).resolve()
    if relative.is_absolute() or root.resolve() not in home.parents:
        raise ValueError(f"{declaration} must name a folder inside the checkout")
    return home


def field(text, name):
    match = re.search(rf"^- {re.escape(name)}: *(.*?) *$", text, re.MULTILINE)
    return match[1] if match else None


def waiting_prompt(root: Path):
    """Return the author, title and role of the checkout's resume prompt that no resume-session read, or None.

    Raises ValueError where resume-session would stop instead: an empty prompt,
    or a receipt that it cannot match to this prompt and checkout.
    """
    home = artifact_home(root)
    prompt = home / PROMPT
    if not prompt.is_file():
        return None
    data = prompt.read_bytes()
    text = "\n".join(data.decode("utf-8-sig", errors="replace").splitlines())  # CRLF or LF alike.
    if not text.strip():
        raise ValueError(f"{prompt} is empty")
    first = text.splitlines()[0].strip()
    heading = HEADING.fullmatch(first)
    # A prompt saved before agents named themselves has no author: no agent takes it.
    found = {"author": heading[1] if heading else "unknown", "title": heading[2] if heading else first.lstrip("# "),
             "role": field(text, "Session role") or ""}
    receipt = home / RECEIPT
    if not receipt.is_file():
        return found
    flag = receipt.read_text(encoding="utf-8-sig", errors="replace")
    digest, used_root = field(flag, "SHA-256") or "", field(flag, "Project root") or ""
    if field(flag, "Prompt") != PROMPT or not re.fullmatch(r"[0-9a-fA-F]{64}", digest) or not used_root:
        raise ValueError(f"{receipt} is not a resume-session receipt")
    if os.path.normcase(os.path.realpath(used_root)) != os.path.normcase(os.path.realpath(root)):
        raise ValueError(f"{receipt} names another checkout: {used_root}")
    return None if digest.lower() == hashlib.sha256(data).hexdigest() else found


def resume_plan(layout, starting):
    """Return the commands to queue in the agent panes of the starting sessions, and the lines that describe them.

    A checkout's prompt goes to the first pane that the whole list declares for
    the agent that paused it, and review-resume to the first pane of the other
    agent. Only the panes of the starting sessions get a command: an agent that
    already runs is not interrupted.
    """
    first = {}  # (folder key, agent id) -> (session name, pane role) declared first
    for session in layout.sessions.values():
        for role in PANE_ROLES[session.kind]:
            if role in AGENTS:
                first.setdefault((key(session.folder), AGENTS[role]), (session.name, role))
    deliveries, lines, prompts = [], [], {}
    for session in starting:
        # The agents of a pane take its folder, where tuitp starts them, as their checkout.
        root, place = Path(session.folder), key(session.folder)
        if place not in prompts:
            try:
                prompts[place] = waiting_prompt(root)
            except (OSError, ValueError) as error:
                prompts[place] = error
        prompt = prompts[place]
        if prompt is None:
            continue
        if isinstance(prompt, Exception):
            lines.append(f"NOTE session {session.name}: no agent resumes it, its resume prompt cannot be read: {prompt}")
            continue
        author, commands = prompt["author"], []
        for role in PANE_ROLES[session.kind]:
            me = AGENTS.get(role)
            if not me or first[place, me] != (session.name, role):
                continue  # A CMD pane, or another pane holds this agent's part for the checkout.
            if author == me:
                action = "resume"
            elif (place, author) in first and "requestor" in prompt["role"].casefold():
                action = "review"
            else:
                continue
            text = COMMANDS[role, action]
            deliveries.append({"session": session.name, "window": pane_name(role, session.id), "text": text})
            commands.append(f"{role} runs {text.strip()}")
        about = f"the prompt {author} paused for {prompt['title']!r}"
        if commands:
            lines.append(f"RESUME session {session.name}: {' and '.join(commands)}, for {about}")
        elif author == "unknown":
            lines.append(f"NOTE session {session.name}: no agent resumes {about}, which names no agent: "
                         "run resume-session in the agent that paused it")
        elif (place, author) not in first:
            agent = next((role for role, agent in AGENTS.items() if agent == author), author)
            lines.append(f"NOTE session {session.name}: no agent resumes {about}, since the list declares "
                         f"no {agent} pane for {root}")
    return deliveries, lines


def deliver(tuios, deliveries, log, run=subprocess.run, wait_ms=WAIT_MS):
    """Queue each command in its pane once the agent there is at rest, all panes at once."""
    def one(item):
        pane = f"{item['session']}/{item['window']}"
        target = ["-s", item["session"], "-w", item["window"]]
        # Before the agent runs, the pane is a CMD that activates senv: queue
        # only once its agent reports, so that nothing lands in that CMD.
        waited = run([tuios, "wait-for", "agent-state", *target, "--until", "idle,done", "--timeout", str(wait_ms)],
                     capture_output=True, text=True, encoding="utf-8", errors="replace",
                     creationflags=subprocess.CREATE_NO_WINDOW)
        if waited.returncode:
            log(f"{pane}: no agent at its prompt, {item['text']} not queued: {(waited.stderr or waited.stdout).strip()}")
            return
        # queue types it once the agent rests a second, never over a question
        # it waits on, and opens an Inbox item if the agent does not take it.
        queued = run([tuios, "queue", *target, "--json", "--", item["text"]],
                     capture_output=True, text=True, encoding="utf-8", errors="replace",
                     creationflags=subprocess.CREATE_NO_WINDOW)
        if queued.returncode:
            log(f"{pane}: cannot queue {item['text']}: {(queued.stderr or queued.stdout).strip()}")
        else:
            log(f"{pane}: queued {item['text']} {queued.stdout.strip()}")

    with ThreadPoolExecutor(max_workers=min(4, len(deliveries) or 1)) as pool:
        list(pool.map(one, deliveries))


def main(argv):
    tuios, deliveries = argv[0], json.loads(argv[1])
    def log(message):
        print(time.strftime("%Y-%m-%d %H:%M:%S ") + message, flush=True)
    deliver(tuios, deliveries, log)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
