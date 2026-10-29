# Manage Windows Terminal tabs and TUIOS sessions with tuitp

`tuitp` reconciles a local `tuitp.list` with named Windows Terminal windows,
their tabs, and persistent TUIOS sessions. Run it again after editing the
list: existing tabs and sessions stay running, additions appear, and removed
entries close. Moving a TUIOS tab between windows preserves its sessions,
including running Claude and Codex processes.

## Install or upgrade

Use Windows Terminal, TUIOS 0.11.0, and Python 3.10 or newer in
`%PRGS%\pythons`. `tuitp` runs from any CMD: for its own run, it calls
`switchpy` on the highest `pythonX.Y.Z` folder there, without a venv, and
skips that switch when this Python already comes first on the `PATH`. The
caller's Python and venv stay as they were. The installer below runs with the
Python of an activated senv CMD. The TUIOS executable is expected at
`%PRGS%\tuioss\current\tuios.exe`. Its configured preferred shell must be
`cmd.exe`: the first pane created by `tuios new --detach` uses that shell.
Claude and Codex must already be installed and authenticated.

From the senv repository, run:

```cmd
python bin\tuitp_install.py
tuitp dry
tuitp
```

The installer targets `%HOME%\bin`, backs up existing files in
`tuitp-backups`, and preserves an existing `tuitp.list`. When upgrading the
original hard-coded launcher, it captures the old layout before replacing
scripts, then seeds the list from the repository's local list if present,
or from the old layout otherwise. Without either, copy and edit
`tuitp.list.example` first.

`setup.bat` needs no Python. When it finds the original launcher in
`%HOME%\bin`, it keeps a copy in `%HOME%\bin\tuitp-legacy` before replacing
the scripts, and it preserves the installed list. The next `tuitp` run
captures the old layout from that copy into `tuitp.legacy.json`, and seeds
`tuitp.list` from it when the list is missing. If that copy cannot be read,
`tuitp` stops and names the folder; remove the folder to skip the migration.
The Git post-install refresh also preserves this list and the captured legacy
ownership. Run
`s gits` to select the Git module and refresh the helpers in `%HOME%\bin`;
the module selector is `gits`, not `git`.

The first reconciliation adopts existing legacy tabs by their exact CMD
launch command and adopts the declared sessions. It does not restart them.
This one-time discovery uses Windows CIM process information; if that query
fails, reconciliation stops before opening tabs or deleting sessions.

The TUIOS daemon keeps running the TUIOS it started with. To upgrade TUIOS,
pause the agents (`pause-session` in each), run `tuitp stop`, install the new
TUIOS in `%PRGS%\tuioss\current`, then run `tuitp`: it starts a daemon of the
new TUIOS, and the paused agents resume, as
[Resume the agents paused in a session](#resume-the-agents-paused-in-a-session)
shows. Do not use `tuios restart-server` for these sessions. It brings them
back with their layouts and new shells, and `tuitp` keeps a running session as
it is, so their panes stay at a bare prompt. Its Inbox offers to resume each
agent with `claude --resume <id>` or `codex resume <id>`, without senv and
without the hooks that show Claude on the rail. After such a restart, run
`tuitp stop`, then `tuitp`.

## Declare a layout

Edit `%HOME%\bin\tuitp.list`. Paths must exist. `%ENVIRONMENT_VARIABLES%`,
spaces, parentheses, and paths relative to the list file are supported.
Batch expressions and CMD metacharacters in paths are rejected.

```text
--- work
C:\projects\tools|Tools shell

=== Projects
+ C:\projects\api|api
+ C:\projects\web|web

=== Test
+ C:\projects\test|test|single

--- experiments
=== Demo
+ C:\projects\demo|demo|single
```

| Declaration | Meaning |
| --- | --- |
| `--- work` | Following tabs belong to the named WT window `tuitp-work`. Default: `dev`. |
| `folder` | An ordinary CMD tab with global and project senv activated. |
| `folder\|title` | An ordinary CMD tab with a pinned title. |
| `=== title` | A pinned TUIOS tab containing the following `+` session declarations. |
| `+ folder\|name` | A project session with Claude, Codex, and CMD in workspaces 1, 2, and 3. |
| `+ folder\|name\|claude` | A Claude session: Claude in workspace 1 and a CMD in workspace 2, each after local senv if present, otherwise global senv. |
| `+ folder\|name\|codex` | A Codex session: Codex in workspace 1 and a CMD in workspace 2, with the same senv initialization. |
| `+ folder\|name\|senv` | One CMD pane running local senv if present, otherwise global senv. |
| `+ folder\|name\|single` | Backward-compatible alias for `senv`. |
| `+ folder\|name\|kind\|id` | Names the agent panes `Claude <id>` and `Codex <id>`; CMD panes keep their name. |
| `+ folder\|name\|\|id` | An empty name or kind keeps its default: here a project session with an id. |
| `+ folder` | A project session named after the folder's final component. |
| Blank line or `# comment` | Ignored. |

Session names must be unique across the whole list. TUIOS tab titles must
be unique within a window. An ordinary folder row or another `===` / `---`
line ends a TUIOS group; blank lines do not. A group must have a session.
Window and session names accept letters, digits, underscores, dots, and
hyphens. TUIOS refuses a session name that ends with a dot or names a Windows
device (`con`, `prn`, `aux`, `nul`, `com1` to `com9`, `lpt1` to `lpt9`), so
the list does too. A session's folder and kind cannot be changed while it exists;
use a new session name to replace it.

An id tells agents apart on the TUIOS rail. The rail shows the session name
before the agents of other sessions only when it fits, which a long session
name does not: with `+ %USERPROFILE%\git\project-with-a-long-name|project-with-a-long-name||long`,
its agents show as `Claude long` and `Codex long` in every tab. Ids use letters,
digits, underscores, dots, and hyphens. Adding, changing, or removing the id
of a running session renames its panes on the next run, without restarting
them. `tuitp` finds the panes by these names when it starts them, including
after TUIOS restores a session: change them through the list, not with
`tuios set-window`.

For example, `+ %USERPROFILE%\git\test|test|claude` opens Claude in the test
project, with a CMD in workspace 2. If `test` already exists as a managed
`single` session, use a new name such as `test-claude`, or recover your work
and remove the old session before rerunning. The launcher preserves existing
sessions instead of changing their running programs. A `claude` or `codex`
session started before these kinds had a CMD gets one on the next run, beside
its running agent: `tuitp dry` lists it as `ADD a CMD pane to session <name>`.

The first session in each group is attached initially. TUIOS's session
switcher can select the others. **TUIOS has a global session list:** grouping
expresses which tab starts on which session; it does not hide sessions from
other tabs or restrict the switcher. Changing the first session reopens the
tab attachment while preserving retained sessions. Adding another session
to the same group keeps that tab open.

## Add, remove, or move entries

Run `tuitp dry` to preview, then `tuitp` to apply:

- Add an `===` block to open another tab in its named window. Add a `---`
  block to use another window. Existing windows are reused by name.
- Move a whole `===` block under another `---` line to move its tab. The
  destination attachment opens before the source closes. The TUIOS daemon
  and retained sessions keep running throughout.
- Move a `+` entry to another group to retain that session under the new
  declaration. Other sessions in the source group remain there; its tab
  closes only if you remove the group itself.
- Remove a session from the entire list to terminate that managed session
  and its processes. Remove a tab declaration to close its managed tab.
  Closing an ordinary CMD tab also terminates its child processes.

Unrelated sessions and tabs are left alone. Once an existing session is
explicitly declared, `tuitp` adopts it and will delete it if later removed.
A missing list changes nothing. A valid empty list removes all managed
tabs and sessions. Empty WT windows close when their final tab closes;
windows containing unrelated tabs stay open.

Manually closed tabs are recreated on the next run; their surviving TUIOS
sessions are reused. Reordering declarations does not reorder existing WT
tabs. `tuitp --list another.list` uses that file as the **replacement desired
layout**, sharing the same ownership ledger; it is not an independent
launcher.

## Restart or remove one session

To start one session again from scratch, name it after `stop`:

```cmd
tuitp dry stop cplx
tuitp stop cplx
```

`tuitp stop cplx` closes the tab that shows `cplx`, deletes that session
with its Claude, Codex, and CMD processes, then reconciles the list as a new
`tuitp` run does: it creates `cplx` again, starts its panes, and opens its
tab. When that tab also shows other sessions, they keep running, and the
tab opens again on its first session. The other tabs and sessions stay as
they are. Name several sessions to restart them together, such as
`tuitp stop api web`.

A session that `tuitp.list` no longer declares is deleted and not created
again. A name that is neither in the list nor in TUIOS stops `tuitp` with
nothing changed, as does a list that the reconciliation would refuse, so
that a session is never deleted without being created again. Run from a
pane of the session it deletes, `tuitp stop cplx` goes on outside TUIOS,
with its output in `%LOCALAPPDATA%\tuitp\stop.log`; from any other pane, it
runs in place.

To remove a session for good, delete its `===` block from `tuitp.list` and
run `tuitp`: it closes the tab and deletes the session.

## Restart one agent pane

`tuitp stop NAME` starts every pane of a session again. To restart only one
agent and leave the other panes running, for example a Claude pane started
before the TUIOS hooks file existed, use its pane:

1. Quit the agent: type `/exit` in Claude, or `/quit` in Codex. The pane
   returns to its CMD prompt, in the session folder, with senv still active
   and the tool directories on `PATH`.
2. Start the agent again with the command that `tuitp` runs in that pane:

   ```cmd
   claude --settings "%LOCALAPPDATA%\tuitp\claude\settings.json"
   codex
   ```

Add `--continue` to the Claude command to resume the latest conversation of
that folder, or `--resume` to pick one. `codex resume --last` resumes the
latest Codex session of that folder, and `codex resume` lists them. Without
`--settings`, Claude starts without the TUIOS hooks and does not show on the
rail. An agent started by hand gets no startup retry, and no resume command:
type `/resume-session` in Claude, or `$llm-shared:resume-session` in Codex,
to resume a session paused in that folder.

## Stop every tab, session and the daemon

Run `tuitp dry stop` to preview, then `tuitp stop`:

```cmd
tuitp dry stop
tuitp stop
```

`tuitp stop` closes every tab recorded in the ownership ledger, then deletes
every TUIOS session, including the ones `tuitp` did not start, and stops the
TUIOS daemon. It does not read `tuitp.list`, so it also stops tabs and
sessions created from an earlier version of the list. The Claude, Codex, and
CMD processes in those sessions end: save or pause the work they hold first.
The next `tuitp` resumes the agents that paused, as
[Resume the agents paused in a session](#resume-the-agents-paused-in-a-session)
shows. Empty WT windows close with their final tab.

Nothing is left for TUIOS to restore. The daemon saves every session it still
holds when it stops, and a new daemon restores those sessions with bare
shells, so `stop` deletes the sessions first. When no daemon runs, `stop`
starts one so that it restores the saved sessions, then deletes them. It
fails, and names them, if TUIOS still lists sessions afterwards. The next
`tuitp` starts a new daemon, creates the declared sessions, and starts their
panes.

Deleting the session of the pane that runs `tuitp stop` would also end
`tuitp`. From a TUIOS pane, `tuitp stop` therefore starts a copy outside
TUIOS and returns at once. That copy writes its output to
`%LOCALAPPDATA%\tuitp\stop.log`.

## Stop the Codex daemon with its last sessions

Codex panes share one Codex app-server daemon per user. The first Codex
that starts launches it, with an updater and a code-mode host, and the other
Codex connect to it. The commands that a Codex agent runs are processes of
that daemon, not of its pane. Deleting a session ends the processes attached
to the console of its panes, Claude, Codex and CMD, but not the daemon,
which has no console there.

When `tuitp` deletes a session that has a Codex pane, with `tuitp stop`,
`tuitp stop NAME`, or by removing it from the list, and no Codex runs outside
the deleted sessions, it also ends the updater, the daemon, and what the
daemon started: the code-mode host and any command still running. The
preview shows it as `STOP the Codex app-server daemon`. While Codex runs in
another session or another terminal, the daemon keeps running for it, and
the preview says `KEEP the Codex app-server daemon for 2 Codex processes`.

`tuitp` finds the daemon and its updater through the pid files that Codex
writes in `%CODEX_HOME%\app-server-daemon`, `%USERPROFILE%\.codex` by default,
and ends them as Task Manager would: `codex app-server daemon stop` took 12
to 20s on a workstation with endpoint protection, only to start. The next
Codex starts a new daemon.

## See Claude panes on the TUIOS rail

On Windows, TUIOS cannot read which program runs in a pane, so it detects no
agent by its process. Codex sends its own state as OSC 7501 program status
reports, so its panes show on the rail and in the Inbox without setup.
Claude Code sends none: its panes show only through TUIOS's Claude Code
hooks.

Each `tuitp` run that starts Claude panes asks TUIOS for these hooks
(`tuios integration install claude-code`, aimed at a temporary folder) and
writes them to `%LOCALAPPDATA%\tuitp\claude\settings.json`. Claude panes start
`claude --settings` with that file, and report idle, working, waiting for you,
and done. Asking TUIOS on each run keeps the hooks current after a TUIOS
upgrade; the file changes only when they do.

TUIOS gives most of these hooks 5 seconds. Under a heavy load, such as a test
run, `tuios.exe` can start slower than that: Claude then discards what the hook
reports and prints `hook [...] timed out after 5s` under the prompt. `tuitp`
raises any shorter timeout to 30 seconds when it writes the file. Claude reads
its hooks when it starts, so a pane started with the older file keeps 5 seconds
until its Claude restarts.

Other Claude sessions do not load these hooks. Each hook starts `tuios.exe`,
which took about a second on a workstation with endpoint protection, and
Claude waits for its hooks before and after every tool call. For the same
reason, do not run `tuios integration install claude-code` for your own Claude
settings: the panes would also report each event twice.

To check a pane, run `tuios list-agents --all-sessions`: a Claude pane shows
the `claude-code` harness. Panes started before the hooks file existed do
not load it: restart their Claude as
[Restart one agent pane](#restart-one-agent-pane) shows, or their whole
session with `tuitp stop NAME`. If TUIOS cannot
write the hooks, `tuitp` prints `Claude panes start without TUIOS agent
hooks` with the reason, keeps any previous file, and starts the panes.

## Open an agent picked on the rail in its own tab

A click on an agent of another session in the TUIOS rail, or a pick in the
session switcher, switches the client of the current tab to that session:
TUIOS has no setting to open it elsewhere. Each `tuitp` run that leaves a
TUIOS tab open starts a watcher, which shows such a session in its own tab:

1. It selects the Windows Terminal tab whose `===` group holds that session,
   and raises its window when it is another one.
2. If that tab shows another session of its group, it switches it to the
   picked session. The agent you clicked has the focus there.
3. It switches the first tab back to the session it showed.

A switch between the sessions of one tab, or to a session that no `===`
group declares, stays as TUIOS made it. When no tab shows the group of the
picked session, for example after you closed its tab, the session stays
where you picked it: run `tuitp` to open that tab again. The watcher finds
tabs by the titles that `tuitp` pins: it does not find a tab renamed by
hand, and leaves the session where you picked it.

The watcher, `tuitp_watch.py`, follows TUIOS's `client-session-changed`
events. It selects tabs through Windows UI Automation, from one PowerShell
process running `tuitp_tabs.ps1` that it keeps loaded, so a tab comes forward
about half a second after the click. It stops with the TUIOS daemon and with
`tuitp stop`. A `tuitp` run starts it again when it is not running, or when
its files changed. It logs each tab it selects and each client it switches
in `%LOCALAPPDATA%\tuitp\watch.log`. Set `TUITP_WATCH=0` before `tuitp` to
stop it and keep rail clicks in their tab.

It tells tabs apart by the TUIOS client that each tab's `tuios attach` opened.
It learns each client when it attaches, and keeps them in `watch.clients.json`
for a watcher started again on the same daemon. A watcher started while a tab
showed the session of another tab takes that tab for the other one: close
that tab, then run `tuitp`, which opens it again.

## Resume the agents paused in a session

When `tuitp` starts the panes of a session, new or restored, it reads the
llm-shared resume prompt of the session folder: `a.session-resume.local.md`
in its review artifact home, `.reviews` unless `.review-artifacts.ini`
declares another. If no resume-session has read that prompt yet, the agent
that paused it resumes it, and nobody has to type anything:

| Prompt paused by | Pane of that agent | Pane of the other agent |
| --- | --- | --- |
| `claude` | Claude runs `/resume-session` | Codex starts with `$llm-shared:review-resume as reviewer` when Claude paused as a review requestor |
| `chatgpt` (Codex) | Codex starts with `$llm-shared:resume-session` | Claude runs `/review-resume as reviewer` when Codex paused as a review requestor |

resume-session itself tells the agent whether it goes on as requestor. The
reviewer waits for that requestor's next request. Each part goes to the first
pane that the whole list declares for its agent and that folder, so a project
session works as a `claude` and a `codex` session on one folder do.

A session whose folder has only the other agent's pane resumes nothing: tuitp
prints a `NOTE` line, as it does for a prompt that names no agent or whose
receipt resume-session would refuse. A used prompt, or none, changes nothing.
An agent that already runs is never interrupted. `tuitp dry` prints the same
`RESUME` and `NOTE` lines:

```text
RESUME session api: Claude runs /review-resume as reviewer and Codex starts with $llm-shared:resume-session, for the prompt chatgpt paused for 'Answer the review of Step 4'
NOTE session test: no agent resumes the prompt chatgpt paused for 'Fix the parser', since the list declares no Codex pane for C:\projects\test
```

Codex takes its command as the prompt it starts with, as in
`codex "$llm-shared:resume-session"`: its pane passes it again to each start
it makes after a failed startup (see [Startup and recovery](#startup-and-recovery)).
For Claude, a helper that `tuitp` leaves running in the background types the
command, for all Claude panes at once:

1. It waits for Claude to report that it is at its prompt, ten minutes at
   most: it never types into the CMD that starts Claude, nor over a question
   Claude waits on, such as "Trust this folder?".
2. It waits 15 seconds more: every agent of the run starts at the same time,
   and the machine is less busy once they have.
3. It types the command with `tuios ask-agent`, which again checks that
   Claude rests and waits on no question of its own.
4. Claude has 60 seconds to show that it took the command. It shows it
   through a hook that starts `tuios.exe`, which a busy machine delays: up
   to 18 seconds were measured, past the 5 seconds that `tuios queue`
   allowed before it warned for nothing.
5. If Claude shows nothing in that time, the helper puts a question in the
   TUIOS Inbox for that pane: "tuitp could not have /resume-session taken
   here: look at the pane".

Why it works this way:
[why tuitp types resume commands with ask-agent](../explanation/why-tuitp-types-resume-commands-with-ask-agent.md).
Set `TUITP_RESUME=0` before `tuitp` to start the agents without resuming
them.

### Check that each Claude took its command

The helper logs one line per command in `%LOCALAPPDATA%\tuitp\resume.log`:

```cmd
type %LOCALAPPDATA%\tuitp\resume.log
```

```text
2026-10-28 10:45:55 api/Claude: /resume-session taken, the agent is working
2026-10-28 10:46:40 web/Claude: /review-resume as reviewer not taken: ask-agent failed: the prompt was pasted and Enter was sent, and within 1m0s it did not turn working or needs_input; its state is idle.
```

`taken, the agent is working` or `done` is the normal outcome. Any other
line comes with an Inbox question, except `no agent at its prompt ... not
typed`, where Claude never reached its prompt in ten minutes and nothing was
typed: look at that pane. [Commands](../reference/commands.md#the-resume-helper)
lists every line.

To see what one Claude did with its command, read its activity:

```cmd
tuios agent-log -s api -w "Claude" --limit 256
```

A `state working` line followed by `prompt /resume-session` shows that it
took it, and when.

### Answer the question "tuitp could not have ... taken here"

The question appears in the TUIOS Inbox (prefix key then `i`, or `o` for the
oldest item), under Questions. Open the pane it names, then:

- Claude runs the command: nothing to do. The question leaves the Inbox by
  itself as soon as Claude reports that it works.
- The command sits in Claude's input box: press Enter in the pane.
- The pane shows something else (an error, a menu, a stopped Claude): deal
  with it, then type the command yourself.

The command was most likely typed already: do not type it again without
looking at the pane.

## Startup and recovery

Before it opens a tab or starts a pane, `tuitp` runs the `ensure_internet.bat`
beside it (`ei`): it checks Internet access, and restarts the px proxy when
the check fails. Without Internet access, `tuitp` stops before it changes
anything: an agent started offline fails or hangs, and Codex's shared
app-server daemon, which times out on its first calls, takes every Codex pane
down with it. Run `tuitp` again once `ei` succeeds. `tuitp dry` names this
check with a `CHECK` line, and does not run it.

New tabs appear first, waiting for their sessions. New sessions are created
sequentially; their layouts are then configured with up to four parallel
session workers. Only after all layouts exist are startup commands sent.
For `project`, each pane runs global senv, then project senv if present. The launcher adds
the TUIOS, Claude, and standalone Codex directories back to PATH after
activation. Existing sessions never receive automatic startup commands, except
the CMD pane added to a `claude` or `codex` session that has none.
The `claude`, `codex`, `senv`, and `single` kinds run the folder's local
`senv.bat` in each pane if present, otherwise global senv. Tool directories are
added to PATH after activation, then the agent starts in its pane, and a CMD
pane stays at its prompt. An activation failure prevents agent startup. A
local script can itself call global senv if it needs both.

Each pane clears `SENV_UID` before it activates anything. A pane inherits the
environment of the TUIOS daemon, which held the `SENV_UID` of the CMD that ran
`tuitp`, and only global senv clears it: panes that ran only a local
`senv.bat` kept that one id and shared their `switch*` temp files, so one of
them could end with an empty `PATH` and never start its agent. The daemon no
longer receives the id either, for the panes opened by hand.

Codex starts without `SSL_CERT_FILE`: a certificate bundle that senv sets for
other tools breaks its TLS connections, and its shared app-server daemon keeps
the environment of the Codex that started it. The CMD of the pane keeps the
variable for the other tools.

Successful reconciliation means the layout exists, attachments survived
initial startup, and new pane commands were submitted. Claude/Codex startup
and authentication happen interactively: `tuitp` does not wait for them. Only
the helper that types Claude's resume commands waits, in the background, for
the agents it has a command for.
An agent that exits in error less than 5 minutes after it started failed its
startup: its pane starts it again after 5 seconds, 3 times in all, with the
command it started with. Codex fails this way when its app-server, just
started, times out on its first network call (`account/read failed during TUI
bootstrap: ... workspace routing discovery timed out`), which a cold start can
make last more than a minute. Each failed exit prints
`tuitp: codex exited <code> after <seconds>s`, followed by the next attempt or
by why the pane stays at its prompt. A normal exit, or a failure after 5
minutes, leaves the pane at its CMD prompt. To stay at the prompt instead of a
retry, press Ctrl+C during the 5-second wait and confirm the end of the batch
job.

If only saved TUIOS sessions exist, the daemon restores their saved layouts.
Saved layouts cannot preserve processes across a daemon shutdown: restored
panes contain new shells. `tuitp` starts the panes of the declared restored
sessions once, as for new sessions, and adds the CMD pane of a `claude` or
`codex` session saved without one. A session reused from a running daemon
keeps its panes as they are, even when their agents have exited: start an
agent again in its pane as [Restart one agent pane](#restart-one-agent-pane)
shows, run `tuitp stop NAME` to start that session again from scratch, or
`tuitp stop`, then `tuitp`, for every session.

Ownership and launch progress are stored in `%LOCALAPPDATA%\tuitp\state.json`.
Per-tab host records and errors are in its `hosts` directory; daemon startup
output is in `daemon.log`. Panes call a copy of `tuitp.pane.bat` kept in
its `panes` directory and named after its content: CMD reads a running batch
file from disk, so an update of `tuitp.pane.bat` never reaches a pane already
started. Keep this ledger: deleting it loses the mapping
to existing managed tabs. Process records include creation times to avoid
mistaking a reused PID for a managed tab. One reconciliation runs at a time.

Failures during setup prevent the removal phase. If session setup was
interrupted, a retry refuses to replay partially submitted commands into
existing panes. Inspect and recover work from the named session, then
run `tuitp stop NAME` to delete that incomplete session and create it
afresh. If a deletion or tab close fails, rerun after
resolving the reported error; completed operations are already recorded.

Set `TUITP_PROFILE` to choose a WT profile; otherwise `WTP_PROFILE` is used,
then WT's default. The profile must use `closeOnExit: "automatic"`,
`"graceful"`, or `"always"`, so exiting the managed host closes its tab.
`"never"` deliberately retains ended tabs and prevents automatic removal.
Run the launcher and its WT windows at the same elevation.

## Find what makes a run slow

Set `TUITP_TIMING` before running the launcher:

```cmd
set TUITP_TIMING=1
tuitp
```

Each native command (every `tuios` call, and the PowerShell process scan of
a migration) and each wait prints its duration as it ends. The waits cover
a tab until its host registers, the daemon until it answers, and the tabs
until `tuios attach` runs in each:

```text
[tuitp timing]   0.72s tuios ls --json
[tuitp timing]   0.92s open tab Projects, until its host registers
[tuitp timing]   2.61s daemon ready, including its 'ls' polls
[tuitp timing]   2.08s 3 tabs attached ('tuios attach' started in each)
```

A summary ends the run: the total, then for each command its number of
calls, total, average and slowest time, then each wait. Session workers run
up to four commands in parallel, so command times can add up to more than
the total. `tuitp dry` prints the same lines for its session query. Clear
the variable with `set TUITP_TIMING=` afterwards.

Every `tuios` call starts a new `tuios.exe`. When most of the time goes to
`tuios` calls that each take seconds, endpoint protection is the usual
cause: it can hold an unsigned executable at start while it checks its
reputation online. On one workstation, the first `tuios` start after a pause
took 8 to 12s, and the next ones under a second while the daemon kept
running. A slow first call followed by fast ones points there, not at TUIOS;
see [find why senv is slow to start](find-why-senv-is-slow-to-start.md#act-on-the-slow-step).

Related: [ordinary project tabs with wtp](open-project-tabs-in-windows-terminal.md),
[command reference](../reference/commands.md).
