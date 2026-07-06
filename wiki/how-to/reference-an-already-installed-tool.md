# How to reference an already-installed tool

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: give a tool that was installed outside senv (corporate installer,
Program Files) the standard `%PRGS%\<tool>s\current` path, so scripts and
aliases find it like any portable tool.

## 📋 Steps

1. In the profile application list (`custom\install_<profile>.list`), declare
   the tool with the `system` keyword instead of an archive pattern:

   ```text
   system npps
   ```

   See [install-list format](../reference/install-list-format.md).

2. Run `s` (or `setup.bat`). For a `system` entry, senv skips download and
   extraction and calls `installs\check_symlink.bat`, which:

   - locates the external install with `bin\getInstallPath.bat`, a registry
     lookup of `InstallLocation` under the `Uninstall` keys of `HKCU` and
     `HKLM`, filtered by the tool pattern (a few tools have hardcoded paths:
     GitHub CLI, Notepad++, Sysinternals),
   - creates the junction `%PRGS%\<tool>s\current` pointing at that external
     folder (`mklink /J`).

3. For a one-off outside the lists, create the junction directly:

   ```cmd
   call check_prg_symlink.bat <tool>s <target-folder> current
   ```

   The script removes a stale junction first, and follows a single nested
   subfolder (`tool-ver\tool-ver\...`) down to the real content.

## Network drives

Junctions do not work on network drives. On a non-`C:`/`D:` location,
`check_prg_symlink.bat` falls back to renaming the version folder to the
junction name and records the original name in a `_<folder>` marker file.

## ✅ Check

```cmd
dir %PRGS%\<tool>s
```

must show `current` as a `<JUNCTION>` entry pointing at the external install,
and the tool must start from a senv session through its usual alias or path.

Related: [naming conventions](../reference/naming-conventions.md),
[junctions as a location contract](../explanation/junctions-as-a-contract.md).
