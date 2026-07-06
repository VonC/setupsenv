# Command reference

Exact synopsis and behavior of the user-facing senv commands. All of them run
inside a senv session (`%HOME%\bin` on the PATH), except `getstarted.bat`,
`setup.bat` and `s.bat` which run from the senv repository folder.

Related pages: [doskey aliases](doskey-aliases.md),
[environment variables](environment-variables.md),
[exit codes](exit-codes.md).

## Session

### `senv [global|all]`

```text
senv
senv global
senv all
```

Doskey alias for `call "%USERPROFILE%\senv.bat" $*`. That generated
launcher calls a `senv.bat` present in the current directory if there is
one (project-specific senv), otherwise `%HOME%\bin\senv.bat`.

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
  [doskey aliases](doskey-aliases.md)).

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

### `fsenv`

Re-activates the session with `no_local_senv=true`: forces the deployed
(non-local) activation.

### `profile.bat`

No argument. Prints the active profile, compares the local senv and custom
versions (`git describe`, `custom\version`) with the remote ones, flags
uncommitted changes, and says whether to update (`upg`, `upa`) or publish.

## Download and install

### `dwl <program> [<version>]` (alias `dl`, `download`)

Downloads the portable archive of a program into `%PRGS%\setup`.

| Argument | Meaning |
| --- | --- |
| `<program>` | a name or alias from [prgs.list](prgs-list-format.md); with no argument, an interactive `gum` picker opens |
| `<version>` | exact version, major/cycle (`21`, `3.13`), `lts` or `latest` (default `latest`) |

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
`%setupsdir%` (team share), `%USERPROFILE%\senv_setups\setups`. Hooks from
`installs\` and `custom\` run around the extraction (see
[naming conventions](naming-conventions.md)). `inst_prg -h` (or `--help`,
`/?`) prints the manual page.

### `div <program> [<version>]` (`dwl_inst_ver.bat`)

`dwl` then `inst_prg` in one step. `<version>` defaults to `latest`.
Exits 111 when the download fails, 112 when the install fails.

## Version switching

All `switch*` commands act on the current session `PATH` only. They are
safe to run in several terminals at once: their transient files are
suffixed with the per-session `SENV_UID`
([environment variables](environment-variables.md)).

### `switchver <prgs_name> <prefix> <pattern> <exe> [<version>]`

Generic engine used by the wrappers below.

| Argument | Example | Meaning |
| --- | --- | --- |
| `<prgs_name>` | `javas` | family folder under `%PRGS%`, must end with `s` |
| `<prefix>` | `jdk` | version folder prefix |
| `<pattern>` | `jdk[0-9]*$` | `findstr /r` filter for valid version folders |
| `<exe>` | `bin\java.exe` | file used to detect "already on PATH" |
| `<version>` | `21` | wanted version (optional) |

Behavior: lists `%PRGS%\<prgs_name>\<prefix>*` folders matching the pattern;
picks the exact match, or the only one available, or (if
`SWITCHVER_DWL_INST` is defined) downloads and installs the missing version
via `div`, or asks with `gum choose`. Removes previous `%PRGS%\<prgs_name>`
entries from `PATH` and returns `SELECTED_VERSION` and `newPath` to the
caller.

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
alias. `switchwf` only sets variables; the server is driven by
`wildfly.bat` (alias `wf`).

### `activate`

Activates the single Python venv found under `.\venvs` in the current
directory (created by `switchpy ... local`). Errors when zero or more than
one venv is present.

## Update

### `up`, `upg`, `upa` (`update_profile.bat`)

| Alias | Expansion | Effect |
| --- | --- | --- |
| `up` | `update_profile.bat` | update from the team share (passthrough arguments) |
| `upg` | `update_profile.bat gits` | quick update, Git only |
| `upa` | `update_profile.bat all` | full update |

Finds the profile setups folder from the `cdis` alias, refreshes the mapped
drive, and re-runs `s.bat` there.

## Git

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

## Diagnostics

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
