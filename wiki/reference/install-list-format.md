# install_<profile>.list file format

`custom\install_<profile>.list` names the applications installed by
`setup.bat` for one profile. One line per application, two
whitespace-separated columns:

```text
<archive-glob-pattern> <program-folder>
```

Example:

```text
jdk-*-windows-x64.zip javas
apache-maven-*-bin.zip mavens
node-v22.* nodes
ideaIC* ideaics
system peazips
```

## Columns

| Column | Content |
| --- | --- |
| 1 | filename glob of the archive to look for, or the keyword `system` |
| 2 | family folder under `%PRGS%` (tool name plus trailing `s`) |

- the newest file matching the glob wins when several are present,
- `system` marks a tool expected to be installed outside senv (by a real
  installer); senv does not extract anything and only creates the `current`
  junction to the detected install location (`getInstallPath.bat`, registry
  lookup).

## Where archives are searched

In order, first match wins:

1. `%PRGS%\setup` (local cache, filled by `dwl`),
2. `%USERPROFILE%\Downloads`,
3. `%setupsdir%`: the team share resolved by
  `custom\setupsdir_<profile>.bat`,
4. `%USERPROFILE%\senv_setups\setups`.

A match found outside `%PRGS%\setup` is copied into it before extraction.

## Base list and local list

Independently of the profile list, `setup.bat` always installs the base
tools first (peazip, git, px, vscode, npp, gum, sysinternals, terminal,
git-cliff, jq), then the profile list, then an optional personal list at
`%PROG%\senv_setups\install.list` (same format), which is never overwritten
by an update.

See also [prgs.list format](prgs-list-format.md) and
[naming conventions](naming-conventions.md).
