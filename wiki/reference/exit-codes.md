# Exit codes and fatal conditions

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

## `switchver.bat`

| Code | Condition |
| --- | --- |
| 2 | usage error (missing or invalid argument) |
| 3 | no version found or none selected |

`switchjdk` exits 2 on a non-numeric version argument, 4-5 on a PATH
filtering failure; `switchmvn` exits 2 when the argument is not `x.y.z`;
`switchwf` exits 2 when version or JDK argument is missing.
