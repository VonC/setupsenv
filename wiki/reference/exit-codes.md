# Exit codes and fatal conditions

<img src="../assets/logo-senv-terminal-transparent.png" alt="" height="90" align="right">

Confirmed error behavior of the main scripts. All fatal messages go through
the `batcolors` `%_fatal%` macro, which prints in red and exits with the
given code.

## `div` (`dwl_inst_ver.bat`)

| Code | Condition |
| --- | --- |
| 2 | missing program name (usage error) |
| 111 | download failed (`dwl.bat` returned an error) |
| 112 | install failed (`inst_prg.bat` returned an error) |

## `setup.bat`

| Code | Condition |
| --- | --- |
| 1 | `custom\install_<profile>.list` does not exist |
| 1 | `custom\setup.ini.bat` just created: fill `PRGS`, `HOME`, `PROG` first |
| 1 | `PRGS`, `HOME`, `PROG` or `REMOTE_HOME` empty after `setup.ini.bat` |
| 1 | `custom\setupsdir_<profile>.bat` missing or not defining `setupsdir` |
| 2 | error while running `custom\setup.ini.bat` |
| 24 | unable to write `%USERPROFILE%\senv.bat` from the template |
| 231 | unable to copy `bin\*` or `custom\*.custom.*` to `%HOME%\bin` |
| 112 | no setup archive found for a program of the install list |
| 79 | no junction name returned by `installs\check_symlink.bat` (junction creation or repair failed; the warning printed just before gives the cause) |
| 94-98 | Git PATH activation failed (`PRGS`/`HOME` unset, `git.exe` or `awk.exe` not found) |
| 99-102 | proxy activation failed (`senv.custom.bat` missing, or `HTTP_PROXY`/`HTTPS_PROXY` not defined by it) |

## `senv.bat` (session activation)

| Code | Condition |
| --- | --- |
| 101 | `senv.local.pre.bat` not found next to the script nor in `%HOME%\bin` |
| 102 | `PRGS` not defined after sourcing `senv.local.pre.bat` |
| 103 | `HOME` not defined |
| 104 | `PROG` not defined |

## `select_prg.bat` (program lookup)

| Code | Condition |
| --- | --- |
| 1 | `gum.exe` missing, or nothing selected in the picker |
| 11 | program name not found in `prgs.list` |
| 12 | program name missing in a non-interactive call |
| 13 | version missing in a non-interactive call |
| 14 | version not in the allowed list |
| 15 | folder field empty in the matched line |
| 19 | requested version not found among the listed ones |
| 126 | malformed `prgs.list` line (missing fields) |

## `inst_prg.bat`

| Code | Condition |
| --- | --- |
| 2 | `setupsdir_<profile>.bat` script not found |
| 3 | unable to create `%PRGS%\<folder>` |
| 5 | unable to access `%USERPROFILE%\Downloads` |
| 6 | no file matching the pattern in any search folder |
| 7 | more than one file matches the pattern |
| 8 | unable to access `%PRGS%\<folder>` |
| 9 | empty program id after selection |
| 1 | 7-Zip extraction error |

## Junction scripts

`installs\check_symlink.bat` (called by `setup.bat`) reports a failed
junction creation as a warning and clears the junction name, which
`setup.bat` turns into its fatal 79. Its own fatal codes:

| Code | Condition |
| --- | --- |
| 1 | `PRGS` not defined, or unable to create `%PRGS%\<folder>` |
| 32-33 | pre-check `system`: registry lookup failed or returned nothing |
| 42-43 | post-check `system`: registry lookup failed or returned nothing |
| 1, 2, 3, 5 | network-drive fallback: delete, rename or marker-file step failed |

`bin\check_prg_symlink.bat` (called by `inst_prg`):

| Code | Condition |
| --- | --- |
| 44 | usage error (missing argument) |
| 1 | unable to create `%PRGS%\<folder>` |
| 43 | junction name is a real directory and moving it aside to `<name>.old` failed |

## `switchver.bat`

| Code | Condition |
| --- | --- |
| 2 | usage error (missing or invalid argument) |
| 3 | no version found or none selected |

`switchjdk` exits 2 on a non-numeric version argument, 4-5 on a PATH
filtering failure; `switchmvn` exits 2 when the argument is not `x.y.z`;
`switchwf` exits 2 when version or JDK argument is missing.

Code 3 is only reachable for a call that names no version, or names one
that is not installed: a version whose folder exists is taken before the
listing runs.

## `wtp.bat`

| Code | Condition |
| --- | --- |
| 51 | unknown argument |
| 52 | `notabs` and `nostartup` together, which leaves nothing to open |
| 53 | no `wt.exe` found |
| 54 | `%USERPROFILE%\senv.bat` missing (run `s` once) |
| 55-56 | the path of `wtp.tab.bat` or `wtp.startup.bat` holds a space |
| 57 | `startup.bat` is there but `wtp.startup.bat` is not |
| 58 | Windows Terminal refused the startup tab |
| 60 | `wtp.list` exists but names no usable folder |
| 61 | Windows Terminal refused a project window |
| 62-63 | the open tabs could not be read; `wtp force` opens them blind |
| 64 | `wtp.tab.bat` missing next to `wtp.bat` |

A missing `wtp.list` is not an error: `wtp` says what the file is for,
points at `wtp.list.example`, and exits 0.

## `aiup.bat`

| Code | Condition |
| --- | --- |
| 41 | unknown argument |
| 42 | `ensure_internet.bat` missing next to `aiup.bat` |
| 43 | no Internet access |
| 44 | the Codex installer could not be downloaded |
| 45 | the Codex installer failed |
| 46 | the Claude installer could not be downloaded |
| 47 | the Claude installer failed |

A failed Codex update does not stop the Claude one: `aiup` exits with the
code of the last failure.

## `ghclear.bat`

| Code | Condition |
| --- | --- |
| 41 | unknown argument |
| 42 | no `gh.exe` found |
| 43 | `gh` is not logged in |
| 44 | the notification inbox could not be read |
| 45 | the inbox could not be marked read |
| 46 | some threads could not be marked done, or new unread ones arrived |

Nothing to clear, a `dry` run and a cancelled question all exit 0.
