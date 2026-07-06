# How to write an install hook

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: customize how one tool is installed, beyond the default
"uncompress with 7-Zip, then junction `current`".

## Hook kinds

Hooks are batch files named after the program folder (`<tool>s`), placed in
`installs\` (public), `custom\` (team) or the local folder: all three are
looked up, in that order, for each kind:

- `<tool>s.pre.bat`: before the install; state checks (example:
  `vscodes.pre.bat` detects an existing VSCode install),
- `<tool>s.install.bat`: replaces the default extraction; used for
  non-archive assets (example: `vscodes.install.bat` runs the installer
  silently, `riffs.install.bat` copies a bare exe into a versioned folder),
- `<tool>s.post.bat`: after extraction, before the junction; reshapes the
  tree or configures the tool,
- `<tool>s.sln.bat`: computes the junction name from the extracted folder
  (versioned families),
- `<tool>s.alias.bat`: after the junction; adds doskey aliases,
- `<tool>s.test.bat`: manual diagnostics, outside the install path.

## 📋 Steps

1. Pick the smallest hook that does the job (usually `.post.bat`).
2. Create `installs\<tool>s.<kind>.bat`. Real examples to copy from:

   - `installs\codexs.post.bat`: gives the exe a stable command name:
     copies `codex-x86_64-pc-windows-msvc.exe` to `codex.exe`,
   - `installs\javas.sln.bat`: emits the versioned junction name (`jdk21`)
     by stripping the archive prefix and suffix,
   - `installs\drawios.alias.bat`: inserts a `drawio=` line into
     `%HOME%\bin\senv.local.doskey` with `sed` and loads it live.

3. Follow the local conventions: load
   `%senv_dir%\batcolors\echos_macros.bat` and report with `%_info%`,
   `%_ok%`, `%_task%`, `%_fatal%`.
4. For a corporate-only step (certificates, internal mirrors), put the hook
   in `custom\` instead of `installs\`: same name, private repository. It
   runs in addition to the public one.
5. Re-install the tool to exercise the hook:

   ```cmd
   inst_prg <tool>
   ```

## ✅ Check

Watch the `inst_prg` output: each hook announces itself. The final tree must
match [naming conventions](../reference/naming-conventions.md), with the
junction pointing at the right folder.

Related: [How to add a program](add-a-program-to-prgs-list.md),
[install hooks in the layers model](../explanation/configuration-layers.md).
