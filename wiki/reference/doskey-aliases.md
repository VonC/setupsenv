# Doskey alias reference

Aliases are loaded by `senv.bat` from four macro files, later files
overriding earlier ones:

1. `%HOME%\bin\senv.doskey`: global (this page),
2. `%HOME%\bin\senv.custom.doskey`: team,
3. `%HOME%\bin\senv.local.doskey`: personal (holds `cdi`, `cdis`),
4. `%HOME%\bin\senv.custom.<profile>.doskey`: profile.

`aliasr` reloads the first three; `alias [pattern]` lists what is loaded.
`senve` and `aliase` open the two personal files (`senv.local.bat`,
`senv.local.doskey`) in VSCode: they are the usual entry point for any
customization. After `aliase`, `aliasr` is enough to reload the aliases;
after `senve`, run `senv` to re-apply the variables in the session.

## Navigation

| Alias | Target |
| --- | --- |
| `cdu` | `%USERPROFILE%` |
| `cdh` | `%HOME%` |
| `cdb` | `%HOME%\bin` |
| `cds` | `%PRGS%` |
| `cdi` | `%PRGS%\senv` (regenerated in `senv.local.doskey`) |
| `cdic` | `%PRGS%\senv\custom` |
| `cdss` | `%PRGS%\setup` |
| `cdis` | profile setups folder (in `senv.local.doskey`) |
| `cdd` | `%PROG%` |
| `cdg` | `%PROG%\git` |
| `cdgg` | `%PROG%\git\git` |
| `cdl` | `%USERPROFILE%\Downloads` |
| `cdls` | `%USERPROFILE%\senv_setups` |
| `cdlss` | `%USERPROFILE%\senv_setups\setups` |

`alias cd` lists them all: `alias <xxx>` shows every alias whose name or
definition contains `xxx`.

`cdg` is the conventional home of your clones: nothing stops a repository
from living elsewhere, but keeping them all under `%PROG%\git` gives every
script, colleague and future you one place to look, and pairs with the
per-repository identity habit ([`gcu`](commands.md#git)). A common personal
addition is a `cdp` alias in `senv.local.doskey` jumping to the current
project, ideally under `cdg`:

```text
cdp=cd /d %PROG%\git\myproject
```

## Session and editors

| Alias | Expansion |
| --- | --- |
| `senv` | `call "%USERPROFILE%\senv.bat"` |
| `vscode` | portable VSCode `code.cmd` |
| `aliasr` | reload the three main doskey files |
| `aliase` | edit `senv.local.doskey` in VSCode |
| `senve` | edit `senv.local.bat` in VSCode |
| `clear` | `cls` |
| `e.` | `explorer .` |
| `ls`, `ll` | `ls` with colors / long listing |
| `vi` | `vim` |
| `mem` | `memory.bat` |

## Git

| Alias | Expansion |
| --- | --- |
| `gl`, `gla`, `glab` | `git lg -10` / `--all` / `--all --branches` |
| `gc`, `gca`, `gcam`, `gcamm` | commit / amend / amend no-edit / amend with message |
| `gcie` | initial empty commit |
| `gcm` | emptied on purpose: replaced by `gcm.bat` |
| `gcma` | `gcm.bat a` then amend |
| `ga` | `git add .` |
| `gs` | `git st` |
| `gd`, `gdc`, `gdni` | diff / cached / no-index, word-colored |
| `gdca` | cached diff to `a.diff` plus a short status |
| `gp`, `gpf`, `gpft` | push / force / follow-tags |
| `grc` | rebase continue with `GIT_EDITOR=true` |
| `gsu`, `gsubu`, `gsur`, `gsubur` | submodule update (`--remote` variants) |
| `gstr` | `gst.bat` with `REPLACE_DATE=1` |
| `gtn`, `gtm` | tag messages |
| `gcliff` | portable `git-cliff` |

## 7-Zip

| Alias | Expansion |
| --- | --- |
| `pz` | peazip GUI |
| `pzx` | `7z x` extract to a named folder |
| `pzc` | `7z a` create a zip |

## Download, install, update

| Alias | Expansion |
| --- | --- |
| `dl`, `download` | `dwl.bat` |
| `div` | `dwl_inst_ver.bat` |
| `install`, `inst`, `in` | `inst_prg` |
| `dlc`, `dlg`, `dlf`, `dlgh`, `dllg`, `dlgum` | per-tool downloaders (chrome, git, firefox, gh, lazygit, gum) |
| `gum` | portable `gum.exe` |
| `up`, `upg`, `upa` | update profile / Git only / all |
| `ti`, `ei` | test internet / restore internet |

## Sysinternals

| Alias | Expansion |
| --- | --- |
| `pe` | Process Explorer |
| `zi` | ZoomIt |
| `ssleep`, `shutd`, `shutr` | sleep / shutdown / reboot via `psshutdown64` |
