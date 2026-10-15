# Manage Windows Terminal tabs and TUIOS sessions with tuitp

`tuitp` reconciles a local `tuitp.list` with named Windows Terminal windows,
their tabs, and persistent TUIOS sessions. Run it again after editing the
list: existing tabs and sessions stay running, additions appear, and removed
entries close. Moving a TUIOS tab between windows preserves its sessions,
including running Claude and Codex processes.

## Install or upgrade

Use an activated senv CMD with Python 3.10 or newer, Windows Terminal, and
TUIOS 0.9.2. The TUIOS executable is expected at
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
`tuitp.list.example` first. `setup.bat` also captures the legacy layout before
overwriting scripts and preserves the installed list. The Git post-install
refresh also preserves this list and the captured legacy ownership. Run
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

If only saved TUIOS sessions exist, the daemon restores their saved layouts.
Saved layouts cannot preserve processes across a daemon shutdown: restored
panes contain new shells. The launcher does not replay agent commands into
those panes. Start the desired agents there manually.

Ownership and launch progress are stored in `%LOCALAPPDATA%\tuitp\state.json`.
Per-tab host records and errors are in its `hosts` directory; daemon startup
output is in `daemon.log`. Keep this ledger: deleting it loses the mapping
to existing managed tabs. Process records include creation times to avoid
mistaking a reused PID for a managed tab. One reconciliation runs at a time.

Failures during setup prevent the removal phase. If session setup was
interrupted, a retry refuses to replay partially submitted commands into
existing panes. Inspect and recover work from the named session, then
remove that incomplete session with `tuios kill-session NAME` and rerun
`tuitp` to create it afresh. If a deletion or tab close fails, rerun after
resolving the reported error; completed operations are already recorded.

Set `TUITP_PROFILE` to choose a WT profile; otherwise `WTP_PROFILE` is used,
then WT's default. The profile must use `closeOnExit: "automatic"`,
`"graceful"`, or `"always"`, so exiting the managed host closes its tab.
`"never"` deliberately retains ended tabs and prevents automatic removal.
Run the launcher and its WT windows at the same elevation.

Related: [ordinary project tabs with wtp](open-project-tabs-in-windows-terminal.md),
[command reference](../reference/commands.md).
