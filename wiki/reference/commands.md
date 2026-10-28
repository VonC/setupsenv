# Command reference

<img src="../assets/logo-senv-terminal-transparent.png" alt="" height="90" align="right">

Exact synopsis and behavior of the user-facing senv commands. All of them run
inside a senv session (`%HOME%\bin` on the PATH), except `getstarted.bat`,
`setup.bat` and `s.bat` which run from the senv repository folder.

Related pages: [doskey aliases](doskey-aliases.md),
[environment variables](environment-variables.md),
[exit codes](exit-codes.md).

## 🖥️ Session

### `senv [global|all]`

```text
senv
senv global
senv all
```

Doskey alias for `call "%USERPROFILE%\senv.bat" $*`. That generated
launcher calls a `senv.bat` present in the current directory if there is
one (project-specific senv), otherwise `%HOME%\bin\senv.bat`. The
`senv.bat` files that `setup.bat` writes in `%HOME%` and at the root of
`%HOMEDRIVE%` only call the launcher back, so the launcher ignores them
and runs the global activation from these two folders.

| Argument | Behavior |
| --- | --- |
| none | project `senv.bat` if the current folder has one, else global |
| `global` | always the global activation, current folder ignored |
| `all` | global activation first, then the project `senv.bat` on top ([Windows Terminal how-to](../how-to/open-project-tabs-in-windows-terminal.md)) |

The activator:

- resets `PATH` to the minimal Windows folders,
- sources `%HOME%\bin\senv.local.pre.bat` (defines `PRGS`, `HOME`, `PROG`,
  `REMOTE_HOME`),
- prepends `%HOME%\bin` and the portable Git folders to `PATH`,
- sets locale, editor, 7-Zip and Go variables,
- sources `senv.custom.bat`, `senv.local.bat`, `senv.custom.<profile>.bat`,
- loads the four doskey macro files (see
  [doskey aliases](doskey-aliases.md)),
- ends with `senv activated in <seconds>s: senv_dir='...'`, the time the
  activation took.

#### Timing an activation

With `SENV_TIMING` defined, `senv.bat` also prints one
`[senv timing] <step> (total <total>) <label>` line per step, and appends
the same lines to `%TEMP%\senv.timing.log` (see
[the how-to](../how-to/find-why-senv-is-slow-to-start.md)). A step of
0.5s or more is flagged `[slow]`, one of 2s or more `[REALLY SLOW]`.

| Label | Time spent since the previous label |
| --- | --- |
| `detect local senv` | local-mode and `publish_profile.bat` detection |
| `batcolors macros` | `batcolors\echos_macros.bat` |
| `senv.local.pre.bat` | `PATH` reset, maintainer aliases (local mode), `senv.local.pre.bat`, `PRGS`/`HOME`/`PROG` checks |
| `base variables, npp alias, Go` | Git on `PATH`, locale, editor, `npp` alias, Go, `WTP_PROFILE` |
| `usernamel` | lowercase user name, cached in `%USERPROFILE%\usernamel` |
| `senv.custom.bat` | team layer, or `senv.custom.full.<profile>.bat` |
| `senv.local.bat` | personal layer |
| `senv.custom.profile.bat` | `senv.custom.<profile>.bat` |
| `doskey senv.doskey` | `installs` on `PATH`, global aliases |
| `doskey senv.custom.doskey` | team aliases |
| `doskey senv.local.doskey` | personal aliases |
| `doskey senv.custom.profile.doskey` | profile aliases |
| `end` | the last cleanup before the report |

The log lines start with `#<time the run started>`, then the same text. A
header line `#<id> ==== <date> senv.bat in <folder>` opens each run. The
clock stops before the report and the final message, which are not
counted.

### `getstarted.bat [<profile>] ["Full Name"] [<email>]`

Unattended onboarding, run once from a fresh clone of the repository.

| Argument | Meaning |
| --- | --- |
| `<profile>` | name of the first profile to register (default `perso`) |
| `"Full Name"` | git identity name (default `%USERNAME%`) |
| `<email>` | git identity email (default `%USERNAME%@%COMPUTERNAME%`) |

Behavior: seeds `custom\` from `custom_example\`, writes `custom\profile`,
an empty `custom\install_<profile>.list` and a
`custom\setupsdir_<profile>.bat` pointing at `senv\setups`, pre-registers
locations and git identity in `%HOME%\bin\senv.local.pre.bat`, downloads
the minimal tool set (peazip, PortableGit, gum, Notepad++, Sysinternals,
VSCode) into `setups\` with the Windows `curl`, drops skip markers for
`pxs`, `terminals`, `git-cliffs`, `jqs`, runs `setup.bat` with
`senv_noconfirm=1`, then makes `custom\` a Git repository. Honors `PRGS`,
`HOME`, `PROG` and `HTTPS_PROXY` if set beforehand. Exit codes: 1
(batcolors missing), 2 (no system curl), 3 (custom seeding failed), 4
(locations not set), 5 (download failed), 6 (`setup.bat` failed).

### `setup.bat [_<profile>] [<program>]`

Installer and refresher, run from the senv repository folder.

| Argument | Meaning |
| --- | --- |
| `_<profile>` | profile override, with a leading underscore (`setup.bat _myteam`); default is the content of `custom\profile` |
| `<program>` | limit the run to one program of the install list |

Reads `custom\setup.ini.bat`, regenerates `%USERPROFILE%\senv.bat` and
`%HOME%\bin`, installs the base tools then the profile list, and ends by
calling `%HOME%\bin\senv.bat`.

### `s` (`s.bat`)

Same as `setup.bat`, with `senv_noconfirm=1` set first: no confirmation
prompt. Arguments are passed through.

### `gsenv`

Runs `senv`, then `gsenv.custom.bat` and `gsenv.local.bat` if present, then
starts VSCode if it is not already running.

### `lsenv`

Re-activates the session from `%PRGS%\senv\bin\senv.bat` (the repository
copy, "local" developer mode) instead of `%HOME%\bin`.

### `tuitp [dry] [stop [<session>...]] [--list <path>]`

Reconciles `tuitp.list` beside the launcher with named Windows Terminal
windows, ordinary CMD tabs, and persistent TUIOS session groups. Keeps
existing sessions running, adds missing entries, and closes/deletes removed
managed entries. Moving a TUIOS tab between windows preserves its sessions.
`dry` reports the plan without changes. `stop` closes every managed tab,
deletes every TUIOS session with its processes, saved ones and the ones
tuitp did not start included, then stops the TUIOS daemon, so that no
session comes back. It does not read the list. Run from a TUIOS pane, it
goes on outside TUIOS, with its output in `%LOCALAPPDATA%\tuitp\stop.log`.
`dry stop` previews it. `stop <session>...` closes the tabs that show these
sessions and deletes them, then reconciles the list, which creates the
declared ones again and reopens their tabs. It changes nothing when a name
is in neither the list nor TUIOS, or when the list cannot be reconciled.
Run from a pane of a session it deletes, it goes on outside TUIOS too.
Deleting a session with a Codex pane also ends the Codex app-server daemon,
its updater and what it started, unless Codex runs outside the deleted
sessions.
Claude panes start with TUIOS's Claude Code hooks, which tuitp writes to
`%LOCALAPPDATA%\tuitp\claude\settings.json`, so that they show on the TUIOS
rail; other Claude sessions do not load them. A session declared with an id
names its agent panes `Claude <id>` and `Codex <id>`. A run that leaves TUIOS
tabs open starts a watcher: a session picked on the TUIOS rail of another tab
opens in its own tab, and the first tab goes back to its session
(`TUITP_WATCH=0` turns it off). When it starts the panes of a session whose
folder holds an llm-shared resume prompt that no resume-session read, it
gives `resume-session` to the agent that paused it and, after a review
requestor's pause, `review-resume as reviewer` to the other agent: Codex starts
with its command, and a helper types Claude's (`TUITP_RESUME=0` turns it off).
Before it opens a tab or starts a pane, it runs `ensure_internet.bat` (`ei`),
and stops without changing anything when Internet access is missing. A
`claude` or `codex` session has its agent in workspace 1 and a CMD in
workspace 2.
An alternate list replaces the
desired layout using the same per-user state. Removing a managed session
from the list terminates its processes on the next applied run. With
`TUITP_TIMING` defined, it prints the duration of each native command and
each wait, then a summary by command.

Runs from any CMD: it switches itself, without a venv, to the highest
`%PRGS%\pythons\pythonX.Y.Z` (3.10+ required), and the caller's Python and
venv stay as they were. Requires Windows Terminal and TUIOS. List syntax, migration,
startup behavior, and recovery:
[manage TUIOS terminal layouts](../how-to/manage-tuios-terminal-layouts.md).

#### The resume helper

`bin\tuitp_resume.py`, which `tuitp` starts detached, outside TUIOS, when it
starts Claude panes that have a resume command. It handles every pane at
once, one worker each, and always exits 0. Its output goes to
`%LOCALAPPDATA%\tuitp\resume.log`. For each pane:

| Step | Command | Limit |
| --- | --- | --- |
| wait for Claude at its prompt | `tuios wait-for agent-state -s <session> -w <pane> --until idle,done --timeout 600000` | 10 minutes |
| let the run's startup pass | none | 15 seconds |
| type the command | `tuios ask-agent -s <session> -w <pane> --stall-timeout 60000 --timeout 100000 --lines 1 --json -- <command>` | 30 seconds for a turn in progress to end, 60 seconds for Claude to take the command, 100 seconds in all |
| when not taken | `tuios set-agent-state needs_input -s <session> -w <pane> --kind question --if-state idle,done -m "tuitp could not have <command> taken here: look at the pane"` | only on a pane in `idle` or `done` |

`ask-agent` counts as taken an exit 0 with `"success": true`, the turn
finished (`state` `done`) or still running at 100 seconds (`settled_by`
`timeout`, `state` `working`).

| Log line | Meaning |
| --- | --- |
| `<session>/<pane>: <command> taken, the agent is <state>` | Claude took it; `<state>` is `done` or `working` |
| `<session>/<pane>: <command> not taken: <first line of the tuios error>` | typed with no sign within 60 seconds, or refused (`agent_blocked`, a turn still running after 30 seconds); the Inbox question follows |
| `<session>/<pane>: no agent at its prompt, <command> not typed: <reason>` | no `idle` or `done` within 10 minutes; nothing typed, no question |
| `<session>/<pane>: no Inbox question: <reason>` | the `set-agent-state` of the line before failed |

Background:
[why tuitp types resume commands with ask-agent](../explanation/why-tuitp-types-resume-commands-with-ask-agent.md).

### `fsenv`

Re-activates the session with `no_local_senv=true`: forces the deployed
(non-local) activation.

### `profile.bat`

No argument. Prints the active profile, compares the local senv and custom
versions (`git describe`, `custom\version`) with the remote ones, flags
uncommitted changes, and says whether to update (`upg`, `upa`) or publish.

### `wtp [dry|force|notabs|nostartup]`

```text
wtp
wtp dry
wtp force
wtp notabs
wtp nostartup
```

Opens the Windows Terminal windows and tabs described by
`%HOME%\bin\wtp.list`, each tab sitting in the folder its line names, with
the global activation and then that folder's own `senv.bat` already run
(`senv all`). See the
[how-to](../how-to/open-project-tabs-in-windows-terminal.md) for the file
format and `bin\wtp.list.example` for the pattern to copy.

| Argument | Behavior |
| --- | --- |
| none | the project tabs still missing, plus the startup tab |
| `dry` | print the `wt.exe` command lines, open nothing |
| `force` | open every tab again, the ones already open included |
| `notabs` | only the startup tab |
| `nostartup` | only the project windows |

A second run opens nothing: each tab is started as
`cmd.exe /k wtp.tab.bat <slot>`, so `wtp` reads the command line of every
live `cmd.exe` and skips the slots that answer. A tab closed by hand comes
back on the next run, in the window its block names. Nothing is written to
disk.

Without a `wtp.list`, `wtp` prints what the file is for and where the
example lives, and exits 0. With a `startup.bat` next to `wtp.bat`, one
extra tab running it is added to the current window; without one, that step
is skipped. `WTP_PROFILE` names the Windows Terminal profile the tabs open
with ([environment variables](environment-variables.md)).

## 💬 Teams cache

### `tc <day> [-MinPerConversation N]`

Copies a transcript from the local Microsoft Teams cache directly to the
Windows clipboard. It does not create an output file.

| Argument | Meaning |
| --- | --- |
| none | print usage and accepted day forms |
| `today` | messages dated today in local time |
| `yesterday` | messages dated yesterday in local time |
| `N` (1 to 4 digits) | messages from `N` days ago: `0` is today, `1` is yesterday |
| `yyyy-MM-dd` or `yyyyMMdd` | messages from the exact local calendar day |
| `-MinPerConversation N` | omit conversations with fewer than `N` matching messages; default `1` |

`tct [N]` runs `tct.bat`, which copies today, or `N` days ago when given
(`tct 2` is the day before yesterday); `tcy` expands to `tc.bat yesterday`.

Before extraction, the launcher checks `%HOME%\bin\teams-reader.exe` against
the `.go`, `go.mod`, and `go.sum` files under `tools\team-chat`. A missing or
older executable is rebuilt with Go and deployed to `%HOME%\bin`. Setting
`TEAM_CHAT_READER` selects an externally managed executable and disables this
build check.

The reader copies the active LevelDB store to a temporary directory, decodes
recent journal entries and Snappy-compressed tables, removes duplicate
messages, groups the result by conversation, and writes UTF-8 text to standard
output. The launcher copies that text to the clipboard with CRLF line endings.
HTML line breaks are retained and non-breaking spaces are converted to regular
spaces.

Only messages fetched by the local Teams client are available. Open and scroll
a conversation in Teams before retrying a missing older day. See the
[daily-use how-to](../how-to/copy-cached-teams-chats.md).

## 📸 Screenshots

### `lsc [N|watch|stop|status]`

```text
lsc
lsc 3
lsc watch
lsc stop
lsc status
lsc /?
```

Copies the full path of the newest screenshot, between double quotes, to the
clipboard, and prints it. Pasted into a Claude Code prompt, a quoted image path
becomes an attachment such as `[Image #1]`.

| Argument | Behavior |
| --- | --- |
| none | the newest image |
| `N` | the `N` newest images, each quoted, separated by one space, oldest first |
| `watch` | start the tray watcher described below, then return |
| `stop` | stop the tray watcher |
| `status` | say whether the tray watcher runs, and where its log is |
| `/?`, `-h`, `--help` | print usage |

Images are the files ending in `.png`, `.jpg`, `.jpeg`, `.gif`, `.bmp` or
`.webp`, in any case; other files, such as `desktop.ini`, are skipped. The
newest is the latest modification time, then the greater name. With fewer
than `N` images, all of them are copied and a warning names the count.

The folder comes from `lsc.custom.ini`, beside `lsc.bat` in `%HOME%\bin`,
copied there by setup from `custom\lsc.custom.ini`:

```ini
[screenshots]
folder = %USERPROFILE%\Pictures\Screenshots
```

The file is UTF-8, with or without a BOM, so a localized folder name such as
a OneDrive `Captures d’écran` survives; environment variables are expanded and
surrounding quotes are dropped. Without the file or the `folder` key, `lsc`
uses the Windows Screenshots folder: the
`{B7BEDE81-DF94-4682-A7D8-57A52620B86F}` value of the per-user
`User Shell Folders` key, set once the folder is redirected, else
`Screenshots` under the Pictures folder. Exit codes are in the
[exit codes reference](exit-codes.md#lsc).

#### The tray watcher

`lsc watch` starts `last-screenshots-watch.ps1` in a hidden Windows
PowerShell, waits until it watches the folder (a second or two), and returns.
From then on, each new image created or renamed in the folder has its quoted
path put on the clipboard as text, once the file can be opened and 0.4 seconds
have passed, so the capture tool's own clipboard write comes first. A bitmap
already on the clipboard stays beside the text: a text field pastes the path,
an image editor still pastes the picture.

| Tray icon | State |
| --- | --- |
| green square, white snip-frame corners | watching |
| grey square, white pause bars | paused: new images are ignored |

Hover over the icon to see the state and the time of the last copy.
Right-click it for **Pause**, **Resume** and **Exit**. `lsc watch` while a
watcher runs leaves it alone; `lsc stop` asks it to exit and waits until it
has. One watcher runs per Windows session, and it needs no administrator
rights. It logs its start, copies, pauses and stop in
`%LOCALAPPDATA%\senv\senv-lsc-watch.log`, rewritten at each start.

## 🧰 Download and install

### `dwl <program> [<version>]` (alias `dl`, `download`)

Downloads the portable archive of a program into `%PRGS%\setup`.

| Argument | Meaning |
| --- | --- |
| `<program>` | a name or alias from [prgs.list](prgs-list-format.md); with no argument, an interactive `gum` picker opens |
| `<version>` | exact version, major/cycle (`21`, `3.13`), Eclipse quarterly release (`2026-03`), `lts` or `latest` (default `latest`) |

The download is skipped when the target file already exists in
`%PRGS%\setup`. Requires internet access (checked by
`ensure_internet.bat`) and `gum`.

Utility form:

```text
dwl --get-latest-version github <owner/repo>
```

prints the latest release version of a GitHub repository.

### `inst_prg [<program>] [<pattern>|<version>|latest] [<symlink>]` (aliases `inst`, `in`, `install`)

Uncompresses a downloaded archive under `%PRGS%` and creates the junction.

| Argument | Meaning |
| --- | --- |
| `<program>` | name or alias from `prgs.list`; with no argument, a picker opens |
| 2nd | an explicit filename pattern, a version fragment, or `latest` (default) |
| `<symlink>` | junction name, default `current` (or a versioned name for jdk, node, python, maven, wildfly) |

Archives are searched in order: `%PRGS%\setup`, `%USERPROFILE%\Downloads`,
`%setupsdir%` (team share), `%USERPROFILE%\senv_setups\setups`. With
`latest`, the archive with the highest version in those folders wins, versions
compared in natural order (`0.10.1` after `0.9.5`), whatever their download
order; creation time only separates copies of the same version. Hooks from
`installs\` and `custom\` run around the extraction (see
[naming conventions](naming-conventions.md)). `inst_prg -h` (or `--help`,
`/?`) prints the manual page.

### `div <program> [<version>]` (`dwl_inst_ver.bat`)

`dwl` then `inst_prg` in one step. `<version>` defaults to `latest`.
Exits 111 when the download fails, 112 when the install fails.

### `aiup [codex] [claude] [force] [dry]`

```text
aiup
aiup codex
aiup claude force
aiup dry
```

Checks Internet access with `ensure_internet.bat`, updates the Claude CLI
with its official PowerShell installer (`https://claude.ai/install.ps1`),
then Codex with `codexu` (below): its CLI, from
`https://chatgpt.com/codex/install.ps1`, and its app-server daemon. Neither
asks anything.

| Argument | Behavior |
| --- | --- |
| none | update Claude, then Codex |
| `codex`, `claude` | update only that one |
| `force` | update Claude even when one of its processes is running |
| `dry` | print what would be done, change nothing (`codexu dry` for Codex) |

A Claude with a running process is skipped unless `force` is given, which
means a plain `aiup claude` run from inside a Claude session skips Claude.
Codex has no such check: its daemon and the daemon's updater are `codex.exe`
processes too, so one would nearly always be found. Its installer puts each
version in its own folder, which leaves running sessions alone; `codexu`
then replaces the daemon package without asking, which can interrupt their
work.
When `HTTPS_PROXY` is set, both installers run with it as the PowerShell
default web proxy: `Invoke-WebRequest` ignores `HTTPS_PROXY`, and without
it the Codex installer cannot reach `releases.openai.com` and falls back to
the GitHub API, which allows 60 unauthenticated calls per hour per address.

### `codexu [dry]`

```text
codexu
codexu dry
```

Checks Internet access with `ensure_internet.bat`, updates the Codex CLI
with its official installer (`HTTPS_PROXY` included, as for `aiup`), then
the Codex app-server daemon that every Codex session connects to. The
installer runs with `CODEX_NON_INTERACTIVE=1`, so it asks nothing and does
not start Codex once done. `codexu dry` prints the versions of the CLI, of
the daemon package and of the running daemon, then what it would do, and
changes nothing. `aiup` runs `codexu` for Codex, after Claude.

The CLI and daemon package versions come from the `codex-package.json` of
each package; only the running daemon is asked, through `codex app-server
daemon version`, which fails when no daemon runs. The running daemon then
shows as `-`.

The daemon cannot update itself in a senv session. It keeps the environment
of the Codex that started it, where the Git `tar` comes before the Windows
one, and its hourly installer run fails to extract the package: GNU tar
reads the `C:` of a Windows path as a remote host. Each new Codex then warns
that "a background Codex service is running" an older version.

`codexu` runs `codex app-server daemon update --from-cli`, which selects the
CLI package just installed: nothing is downloaded or extracted again. Codex
asks before it replaces the daemon package, since that can interrupt the
work of running Codex sessions: `codexu` passes `--yes`, so nothing is
asked. Run it when those sessions can wait. The daemon is then pinned to
that version and stops its hourly attempts: run `codexu` again after each
Codex update (`codex app-server daemon update` returns the daemon to its own
updates). When the daemon package already has the CLI version, and the
running daemon too if one runs, `codexu` leaves the daemon alone. Steps and
checks: [update Claude and Codex](../how-to/update-claude-and-codex.md).

## 🔀 Version switching

All `switch*` commands act on the current session `PATH` only. They are
safe to run in several terminals at once: their transient files are
suffixed with the per-session `SENV_UID`
([environment variables](environment-variables.md)). The first `switch*`
or `ppath` command of a terminal looks that id up through `senv_uid.bat`,
which takes 1 to 2s once; the next ones reuse it.

### `switchver <prgs_name> <prefix> <pattern> <exe> [<version>]`

Generic engine used by the wrappers below.

| Argument | Example | Meaning |
| --- | --- | --- |
| `<prgs_name>` | `javas` | family folder under `%PRGS%`, must end with `s` |
| `<prefix>` | `jdk` | version folder prefix |
| `<pattern>` | `jdk[0-9]*$` | `findstr /r` filter for valid version folders |
| `<exe>` | `bin\java.exe` | file used to detect "already on PATH" |
| `<version>` | `21` | wanted version (optional) |

Behavior: a `<version>` whose `%PRGS%\<prgs_name>\<prefix><version>` folder
exists is taken straight away, with no listing and no prompt. Otherwise it
lists `%PRGS%\<prgs_name>\<prefix>*` folders matching the pattern and picks
the only one available, or (if `SWITCHVER_DWL_INST` is defined) downloads and
installs the missing version via `div`, or asks with `gum choose`. Removes
previous `%PRGS%\<prgs_name>` entries from `PATH` and returns
`SELECTED_VERSION` and `newPath` to the caller.

### Wrappers

| Command | Arguments | Variables set |
| --- | --- | --- |
| `switchjdk [N]` | major digits only (`8`, `11`, `17`, `21`) | `JAVA_HOME`, `JAVA_VERSION`, PATH gets `%JAVA_HOME%\bin` |
| `switchmvn [x.y.z]` | full version (`3.9.9`) | `M2_HOME`, `M2`, `MVN_VERSION`, PATH gets `%M2%` |
| `switchnode [N]` | major digits (`20`, `22`) | `NODE_HOME`, `NODE_VERSION`, PATH gets `%NODE_HOME%` |
| `switchpy [ver] [no\|global\|local]` | version, then venv mode | `PYTHON_HOME`, `PYTHON_VERSION`, `PYTHON_ROOT` |
| `switchwf <N> <jdk>` | both required (`switchwf 26 17`) | `WF_VERSION`, `WF_JDK`, `WF_HOME`, `WILDFLY_HOME` |

`switchpy` also proposes a Python virtual environment: none, global
(`%PYTHON_ROOT%\venvs`) or local (`%CD%\venvs`), and defines a `deactivate`
alias. It repairs incomplete venv scaffolding before activation. A local venv
installs every `requirements*.txt` through pip when those files exist;
otherwise a project with `pyproject.toml` is synchronized through uv, using a
frozen lock when `uv.lock` exists. `switchwf` only sets variables; the server is driven by
`wildfly.bat` (alias `wf`).

### `activate`

Activates the single Python venv found under `.\venvs` in the current
directory (created by `switchpy ... local`). Errors when zero or more than
one venv is present.

## 🔄 Update

### `up`, `upg`, `upa` (`update_profile.bat`)

| Alias | Expansion | Effect |
| --- | --- | --- |
| `up` | `update_profile.bat` | update from the team share (passthrough arguments) |
| `upg` | `update_profile.bat gits` | quick update, Git only |
| `upa` | `update_profile.bat all` | full update |

Finds the profile setups folder from the `cdis` alias, refreshes the mapped
drive, and re-runs `s.bat` there.

## Git

### `sshagent [load|status]`

Starts or reuses a user SSH agent and loads the private key configured in
`%LOCALAPPDATA%\senv\ssh-agent.local.json`. Its passphrase, if any, is
read from the first line of `<privateKey>.passphrase` when that file
exists, and prompted for locally otherwise. A passphrase file inside a Git
working tree must be ignored there, or the command stops. Exports the
agent environment into the calling CMD;
use `call` from another batch script. An already loaded key is reused.
`status` only checks the agent and key. No service or administrator rights
are required. Setup, expiry and alternate config paths:
[use an SSH agent](../how-to/use-ssh-agent.md).

### `gcu`

Sets `user.name` and `user.email` in the current repository, from the
`FULLNAME` and `USERMAIL` registered in `%HOME%\bin\senv.local.pre.bat`.
Run it once after each clone: the senv Git configuration sets
`user.useConfigOnly=true`, so commits are refused until the repository has
its own identity. Generated into `%HOME%\bin\gcu.bat` by the `gits` install
hook. Full option list and rationale:
[git configuration](git-configuration.md).

### `gcua [<folder>] [<hosts-list>|-] [--force] [--dry-run]`

Applies the `gcu` identity to every first-level repository under
`<folder>` (default `%PROG%\git`), reporting each repository with the
name/email set, kept, or the skip reason. Skips repositories that already
have a local `user.email` (`--force` overrides). With a hosts list, by
default `%HOME%\bin\senv.custom.<profile>.gcua.list`, a repository is
stamped only when all URLs of all its remotes match a listed service; `-`
disables the filter; `senv.custom.all_teams.gcua.list` is the fallback shared by every
profile. Without a list and without `-`, does nothing. `--dry-run` prints
the report without writing. `setup.bat` runs it automatically at the end
of each install or update when either list applies to the active profile.
Details: [git configuration](git-configuration.md).

### `ghclear [all] [yes] [read] [dry]`

Clears the GitHub notification inbox through `gh api`, using
`%PRGS%\ghs\gh-cli\bin\gh.exe` first and a `gh.exe` on `PATH` otherwise. The
`gh` login needs the `notifications` or the `repo` scope.

| Argument | Behavior |
| --- | --- |
| none | list the unread threads, ask, then mark them done |
| `all` | the same over every thread the API lists, read ones included |
| `yes` | skip the question |
| `read` | only mark the whole inbox read; the threads stay in the inbox |
| `dry` | report what would be done, change nothing |

GitHub has no bulk "done" endpoint: each thread takes one `DELETE`, paced
under the API rate budget, while `read` is a single `PUT`. Done cannot be
undone; a thread comes back only with new activity, so `ghclear dry` shows
what would go first. The run ends by checking each `DELETE` succeeded and
that nothing unread is left.

## 🩺 Diagnostics

### `alias [-l] [<pattern>]`

No argument: lists all doskey macros. With a pattern: filters them through
`findstr /i`, so the pattern matches anywhere in the name **or the
definition**: `alias cd` lists the `cd*` navigation aliases, `alias git`
everything that runs git.

### `ppath [/i] [<term> ...]`

Prints the LOCAL `PATH` plus the USER and SYSTEM `PATH` values read from the
registry, one entry per line. Missing folders are marked `[X]`, entries that
are not folders `[?]`. With terms, only entries containing all of them are
shown; `/i` makes the match case-insensitive.

### `h [<pattern>]`

Command history (`doskey /history`), filtered through `grep -i` when a
pattern is given.

### `p <name>`

Running processes (`tasklist`) filtered through `grep -ai <name>`.

### `ti` (`testinternet.bat`)

Tests internet access with the portable `curl` against a rotating test URL
(`testinternet.urls`). Exit 0 when reachable.

### `ei` (`ensure_internet.bat`)

Calls `ti`; on failure and when `HTTPS_PROXY` is set, restarts the local
`px` proxy and tests again. Fatal when still offline.
