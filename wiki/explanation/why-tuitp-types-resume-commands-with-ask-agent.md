# Why tuitp types resume commands with ask-agent

<img src="../assets/logo-senv-terminal-transparent.png" alt="" height="90" align="right">

When `tuitp` starts the panes of a session whose folder holds an unread
llm-shared resume prompt, the agent that paused it should resume without
anybody typing. Codex makes this easy: it takes its command as the prompt it
starts with (`codex "$llm-shared:resume-session"`). Claude's command is
typed into its pane instead, once Claude is at its prompt, by a helper that
`tuitp` leaves running in the background (`bin\tuitp_resume.py`).

Typing into a terminal is blind: nothing in a pane says that the text was
read. This page explains how the helper knows, why it first used
`tuios queue` and then moved to `tuios ask-agent`, and what it does when an
agent really does not take its command.

## How TUIOS knows what Claude is doing

A Claude pane started by `tuitp` loads TUIOS's Claude Code hooks, which
`tuitp` writes to `%LOCALAPPDATA%\tuitp\claude\settings.json`. Each hook
runs `tuios.exe agent-hook claude-code`, a new process each time, which
reports the pane's agent state to the TUIOS daemon:

- `SessionStart` reports `idle`: Claude is at its prompt,
- `UserPromptSubmit` reports `working`: Claude took a prompt,
- the end of a turn reports `done`, a permission or a question
  `needs_input`.

Those states are the only signal the helper has. Before Claude runs, the
pane is a CMD that activates senv, so the helper waits for `idle` or `done`
(up to ten minutes, enough for a Claude that fails its first start twice or
for a "Trust this folder?" answer) and never types into that CMD.

## What went wrong with tuios queue

The helper first typed with `tuios queue`. It types a message once the
agent has rested a second, never over a prompt the agent waits on, and then
watches: an agent that shows no sign of taking it **within 5 seconds** is
marked stalled, and TUIOS pops up "Claude X has a question · your queued
message was typed but Claude X did not take it: look at the pane". Those 5
seconds are fixed: in tuios 0.11.1, `queue` has no flag or setting for them.

On 2026-10-28, `tuitp` started seven Claude panes, several Codex panes and
the Codex daemon at once, with the CPU around 85%. Six of the seven queued
commands were flagged, yet all six were taken: `tuios agent-log` showed each
`working` report 5 to 18 seconds after Enter. The `UserPromptSubmit` hook is
a new `tuios.exe` process, and process starts are slow while every agent of
the run starts. The warnings were false alarms: the Inbox questions cleared
themselves as each agent worked, but the popups stayed until closed.

## The two changes

**A pause before typing.** Once Claude first reports that it rests, the
helper waits 15 seconds more. Every agent of the run starts at the same
time, and the load drops once they have: the hook that follows the command
then starts sooner. The cost is a resume that begins 15 seconds later.

**A longer stall timeout.** `tuios ask-agent` types the same way
`tuios queue` does, only at rest and never over a prompt the agent waits on
(that is refused as `agent_blocked`, with nothing typed), and it takes a
`--stall-timeout`. The helper gives Claude 60 seconds to show that it took
the command, more than three times the 18 seconds measured. Unlike `queue`,
`ask-agent` waits for the turn that the command starts, up to `--timeout`:
the helper gives it 100 seconds in all (up to 30 for the agent to end a turn
in progress, then the 60), and counts a command taken as delivered even when
the turn is still running then (`settled_by: timeout`, state `working`).
Each ask stays open that long, so the helper gives each pane its own worker:
one slow Claude never delays the command of another.

## The fallback: a question in the Inbox

`ask-agent` reports a stall to its caller only: unlike `queue`, it raises
nothing in TUIOS. A Claude that really cannot take its command (a crash, a
menu nobody expected) would then go unnoticed, so the helper raises the
question itself:

```text
tuios set-agent-state needs_input -s <session> -w <pane> --kind question --if-state idle,done -m "tuitp could not have <command> taken here: look at the pane"
```

The question shows in the TUIOS Inbox, under Questions, for that pane. Three
details keep it from doing harm:

- `--if-state idle,done` applies it only to an agent at rest: an agent that
  works is not interrupted, and a question of the agent's own, such as a
  permission menu, is not replaced by this one,
- the agent's next report replaces it: as soon as Claude shows it works, the
  question leaves the Inbox,
- the command was typed once (except for a refused or late `ask-agent`), so
  the question says to look at the pane, not to type it again.

The same question follows any other failure of the ask: an agent still in a
turn after 30 seconds, or one that waits on a question of its own.

## What was checked

The helper ran against fake Claude panes in a throwaway TUIOS session:
scripts that report their state with `tuios set-agent-state` as the hooks
do, as late as asked. A pane that reported `working` 8 seconds after Enter,
which `queue` would have flagged, was logged as taken. A pane that showed
nothing for 60 seconds got the Inbox question, which its next report then
cleared. With the default 5 seconds, `ask-agent` failed the same way `queue`
had, which confirmed the cause.

Related: [manage TUIOS terminal layouts](../how-to/manage-tuios-terminal-layouts.md#resume-the-agents-paused-in-a-session)
for the steps and the checks, [commands](../reference/commands.md#the-resume-helper)
for the exact commands, limits and log lines.
