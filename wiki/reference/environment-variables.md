# Environment variables

Variables set or read by a senv session, with their origin. See
[Anatomy of a session](../explanation/anatomy-of-a-session.md) for the order
in which they are applied.

## Core locations

| Variable | Origin | Meaning |
| --- | --- | --- |
| `PRGS` | `senv.local.pre.bat` (seeded by `custom\setup.ini.bat`) | root of the portable programs |
| `HOME` | same | dedicated senv home, default `%USERPROFILE%\home_senv` |
| `PROG` | same | work/data folder (Git repositories, `senv_setups`) |
| `REMOTE_HOME` | same | remote location for HOME backup/migration |

## Session basics (set by `bin\senv.bat`)

| Variable | Value | Meaning |
| --- | --- | --- |
| `PATH` | rebuilt | minimal Windows folders, then `%HOME%\bin`, then the portable Git folders, then per-tool additions |
| `SENV_UID` | PID of the terminal's `cmd.exe` (random fallback) | per-terminal id, suffixes the transient files of `switch*` and `ppath` so concurrent tabs never share them |
| `GH` | `%PRGS%\gits\current` | portable Git root |
| `LANG`, `LC_ALL` | `en_US.UTF-8`, `C.UTF-8` | locale |
| `TERM` | `msys` | terminal type for the Git tools |
| `pz`, `sz` | peazip paths | `pz` GUI folder, `sz` the `7z.exe` used by all extraction |
| `EDITOR` | VSCode `code.cmd`, else Notepad++ | default editor |
| `DL`, `DWL` | `%USERPROFILE%\Downloads` | download folder shortcuts |
| `GOROOT`, `GOBIN`, `GOPROXY` | from `%PRGS%\gos\current` when present | Go toolchain |

## Proxy (from the custom layer)

| Variable | Origin | Meaning |
| --- | --- | --- |
| `HTTP_PROXY`, `HTTPS_PROXY` | `senv.custom.bat` | local or corporate proxy; `setup.bat` aborts when missing |
| `NO_PROXY` | `senv.custom.bat` | domains reached directly |

## Per-tool (set by the `switch*` commands)

| Variables | Set by |
| --- | --- |
| `JAVA_HOME`, `JAVA_VERSION` | `switchjdk` |
| `M2_HOME`, `M2`, `MVN_VERSION` | `switchmvn` |
| `NODE_HOME`, `NODE_VERSION` | `switchnode` |
| `PYTHON_HOME`, `PYTHON_VERSION`, `PYTHON_ROOT`, `VIRTUAL_ENV` | `switchpy` |
| `WF_HOME`, `WILDFLY_HOME`, `WF_VERSION`, `WF_JDK` | `switchwf` |

## Behavior switches

| Variable | Read by | Effect when set |
| --- | --- | --- |
| `senv_noconfirm` | `setup.ini.bat` | skip the Y/N confirmation (`s.bat` sets it) |
| `SWITCHVER_DWL_INST` | `switchver` | a missing version is downloaded and installed instead of prompting |
| `switchver_todelete` | `switchver` | override of the PATH substring to clean |
| `SWITCHVER_DEBUG` | `switch*` | print the rebuilt PATH |
| `no_local_senv`, `local_senv` | `senv.bat` | force or skip the "local" (repository) activation mode |
| `internalsenvcall` | `senv.bat` | quiet activation, used by wrapper scripts |
| `senv_force_build` | `adm\build.bat` | rebuild even when the remote version matches |
