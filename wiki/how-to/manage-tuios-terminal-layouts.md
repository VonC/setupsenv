# Manage Windows Terminal tabs and TUIOS sessions with tuitp

`tuitp` reconciles a local `tuitp.list` with named Windows Terminal windows,
their tabs, and persistent TUIOS sessions. Run it again after editing the
list: existing tabs and sessions stay running, additions appear, and removed
entries close. Moving a TUIOS tab between windows preserves its sessions,
including running Claude and Codex processes.

## Install or upgrade

Use Windows Terminal, TUIOS 0.9.2, and Python 3.10 or newer in
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
| `+ folder\|name\|claude` | One Claude pane, started after local senv if present, otherwise global senv. |
| `+ folder\|name\|codex` | One Codex pane, with the same senv initialization. |
| `+ folder\|name\|senv` | One CMD pane running local senv if present, otherwise global senv. |
| `+ folder\|name\|single` | Backward-compatible alias for `senv`. |
| `+ folder` | A project session named after the folder's final component. |
| Blank line or `# comment` | Ignored. |

Session names must be unique across the whole list. TUIOS tab titles must
be unique within a window. An ordinary folder row or another `===` / `---`
line ends a TUIOS group; blank lines do not. A group must have a session.
Window and session names accept letters, digits, underscores, dots, and
hyphens. A session's folder and kind cannot be changed while it exists;
use a new session name to replace it.

For example, `+ %USERPROFILE%\git\test|test|claude` opens Claude alone in
the test project. If `test` already exists as a managed `single` session,
use a new name such as `test-claude`, or recover your work and remove the
old session before rerunning. The launcher preserves existing sessions
instead of changing their running programs.

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
Empty WT windows close with their final tab.

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

## Startup and recovery

New tabs appear first, waiting for their sessions. New sessions are created
sequentially; their layouts are then configured with up to four parallel
session workers. Only after all layouts exist are startup commands sent.
For `project`, each pane runs global senv, then project senv if present. The launcher adds
the TUIOS, Claude, and standalone Codex directories back to PATH after
activation. Existing sessions never receive automatic startup commands.
The one-pane kinds (`claude`, `codex`, `senv`, and its alias `single`) run
the folder's local `senv.bat` if present, otherwise global senv. Tool
directories are added to PATH after activation, then the selected agent
starts, or CMD stays open for `senv`. An activation failure prevents agent
startup. A local script can itself call global senv if it needs both.

Successful reconciliation means the layout exists, attachments survived
initial startup, and new pane commands were submitted. Claude/Codex startup
and authentication happen interactively; their readiness is not monitored.
An agent that exits in error less than a minute after it started failed its
startup: its pane starts it again after 5 seconds, 3 times in all. Codex
fails this way when its app-server, just started, times out on its first
network call (`account/read failed during TUI bootstrap: ... workspace
routing discovery timed out`), and later starts succeed. A normal exit, or
a failure after a minute, leaves the pane at its CMD prompt. To stay at the
prompt instead of a retry, press Ctrl+C during the 5-second wait and confirm
the end of the batch job.

If only saved TUIOS sessions exist, the daemon restores their saved layouts.
Saved layouts cannot preserve processes across a daemon shutdown: restored
panes contain new shells. `tuitp` starts the panes of the declared restored
sessions once, as for new sessions. A session reused from a running daemon
keeps its panes as they are, even when their agents have exited: run
`tuitp stop NAME` to start that session again from scratch, or `tuitp stop`,
then `tuitp`, for every session.

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
