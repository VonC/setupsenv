# inst_prg

`inst_prg.bat` installs an already-downloaded archive or installer into `%PRGS%`.
The usual workflow is:

```bat
dwl codex
inst_prg codex
```

The default `senv.doskey` also exposes these aliases:

```bat
inst codex
install codex
in codex
```

`dwl.bat` stores files in `%PRGS%\setup`.
`inst_prg.bat` finds the matching file, copies it locally if needed, extracts or installs it, runs optional hooks, and creates a `current` junction by default.

## Usage

```bat
inst_prg [program] [pattern-or-latest] [symlink-name]
```

Examples:

```bat
inst_prg codex
inst_prg codex latest
inst_prg codex codex-rust-v0.141.0-x86_64-pc-windows-msvc.zip
inst_prg codex latest codex0141
```

Arguments:

- `program`: name or alias from `bin\prgs.list`.
- `pattern-or-latest`: explicit file pattern, version fragment, or `latest`.
- `symlink-name`: optional junction name. Defaults to `current`, unless `inst_prg.bat` derives a versioned name for known families.

## Program Lookup

For normal program names, `inst_prg.bat` calls:

```bat
select_prg.bat <program> inst_prg
```

That resolves:

- `prg_id`: install id without trailing `s`.
- `prg_pattern`: archive pattern from `bin\prgs.list`.
- `prgs_folder`: computed as `%prg_id%s`.

For Codex:

```text
Codex/cdx~#~codexs~codex-rust-v*-x86_64-pc-windows-msvc.zip~global
```

This resolves to:

- `prg_id=codex`
- `prgs_folder=codexs`
- `prg_pattern=codex-rust-v*-x86_64-pc-windows-msvc.zip`

If the first argument contains `*`, `inst_prg.bat` enters list mode and searches for that pattern directly.

## File Search

`inst_prg.bat` searches for the selected archive in this order:

1. `%PRGS%\setup`
2. `%USERPROFILE%\Downloads`
3. `%setupsdir%`, when configured by the active profile
4. `%USERPROFILE%\senv_setups\setups`, when it exists

When a match is found outside `%PRGS%\setup`, it is copied into `%PRGS%\setup` before installation.

When `latest` is used, the installer asks `bin\dir_by_date.ps1` for the newest matching file by creation time across the searched locations.

When no match is found for a Python zip pattern, `inst_prg.bat` falls back to `pythons.install.bat`.

## Pattern Handling

The pattern comes from `prgs.list`, but a second argument can narrow it.

Given:

```text
codex-rust-v*-x86_64-pc-windows-msvc.zip
```

These calls result in these searches:

```bat
inst_prg codex
```

Uses the declared pattern and selects the latest matching file.

```bat
inst_prg codex 0.141.0
```

Injects the version fragment into the first `*`, producing a search like:

```text
codex-rust-v*0.141.0*x86_64-pc-windows-msvc.zip
```

```bat
inst_prg codex "codex-rust-v0.141.0-x86_64-pc-windows-msvc.zip"
```

Uses the explicit pattern as-is.

Patterns can contain alternatives separated by `/`. `drawio` uses this to allow both the `.zip` and the older `-no-installer.exe` asset shape.

## Default Installation Flow

After a single file is selected:

1. `fname` is set to the selected archive filename.
2. `prg_folder` is set to the archive basename, using `%%~ni`.
3. `%PRGS%\%prgs_folder%` is created if missing.
4. The archive is copied into `%PRGS%\%prgs_folder%`.
5. A custom install hook may run.
6. Otherwise, `pzxx.bat` extracts the archive with 7-Zip.
7. `.tar.xz` archives get a second extraction pass for the inner `.tar`.
8. A post-install hook may run.
9. `check_prg_symlink.bat` creates or updates the symlink, usually `%PRGS%\%prgs_folder%\current`. If that name is a real directory instead of a junction (previous manual installation), it is kept aside as `current.old` first.
10. An alias hook may run.

For Codex, a downloaded file like:

```text
codex-rust-v0.141.0-x86_64-pc-windows-msvc.zip
```

installs into:

```text
%PRGS%\codexs\codex-rust-v0.141.0-x86_64-pc-windows-msvc
```

and then:

```text
%PRGS%\codexs\current
```

points to that folder.

## Custom Install Hooks

Create `installs\<prgs_folder>.install.bat` when default extraction is not enough.

The hook is called before default extraction:

```bat
call "%install_dir%\%prgs_folder%.install.bat" "%sln%"
```

Use a custom install hook when:

- The downloaded file is a standalone `.exe` that should be copied into a versioned folder.
- The archive layout needs reshaping before symlink creation.
- The program has a non-archive installer flow.

Examples in this repo:

- `tailwindcsss.install.bat`: copies the downloaded executable into a versioned directory under several executable names and adds a local alias.
- `riffs.install.bat` and `moars.install.bat`: handle standalone executables.
- `pythons.install.bat`: handles Python-specific installation.
- `vscodes.install.bat`: handles VS Code-specific install/update behavior.

If no custom install hook exists, `inst_prg.bat` extracts with `pzxx.bat`.

## Post-Install Hooks

Create `installs\<prgs_folder>.post.bat` when default extraction works, but the installed tree needs a small adjustment.

The hook is called after extraction and before symlink creation:

```bat
call "%install_dir%\%prgs_folder%.post.bat"
```

Use a post hook when:

- A file must be copied or renamed after extraction.
- Settings directories must be created.
- App configuration must be patched.
- A tool needs extra local files before `current` is created.

Examples:

- `npps.post.bat`: creates a Notepad++ settings directory and updates Git editor configuration.
- `peazips.post.bat`: adds a missing `res\7z` junction.
- `terminals.post.bat`: delegates to a PowerShell wrapper for Windows Terminal settings.
- `codexs.post.bat`: copies `codex-x86_64-pc-windows-msvc.exe` to `codex.exe`.

Codex is a post-install case because the zip extraction is normal, but the executable name is platform-specific. The installed command should be stable:

```text
codex.exe
```

### Windows Terminal Font

`terminals.post.ps1` installs `HackNerdFont-Regular.ttf` for the current user before it writes the `senv` Windows Terminal profile.

The font file is searched in the same folders as an archive, in the same order:

1. `%PRGS%\setup`
2. `%USERPROFILE%\Downloads`
3. `%setupsdir%`, when configured by the active profile
4. `%USERPROFILE%\senv_setups\setups`

Each folder is checked directly and in its `fonts` subfolder, so a setups folder can keep fonts apart from the program archives. The nerd-fonts download runs only when no folder holds the file, that repository being the least reliable source.

To seed the shares, copy the installed font to `%PRGS%\setup` and publish it:

```bat
copy "%LOCALAPPDATA%\Microsoft\Windows\Fonts\HackNerdFont-Regular.ttf" "%PRGS%\setup\"
adm\publish.bat HackNerdFont-Regular.ttf all
```

`publish.bat` sees no program of `prgs.list` behind that name and publishes the file as is, into the `fonts` subfolder of every profile share.

`terminals.post.bat` resolves `setupsdir` from the active profile when the hook runs on its own (`setup.bat` and `inst_prg.bat` already define it), and reports connectivity through `SENV_INTERNET_OK`.

A font that cannot be installed is a warning, not an error: the `senv` profile is still created and used, with the default font face.

## Symlink Hooks

Create `installs\<prgs_folder>.sln.bat` when the default symlink target or symlink name needs adjustment.

`check_prg_symlink.bat` calls the hook and uses its output as the symlink name.

Examples:

- `javas.sln.bat`
- `mavens.sln.bat`
- `nodes.sln.bat`
- `pythons.sln.bat`
- `wildflys.sln.bat`

`inst_prg.bat` also has built-in symlink names for common families:

- Node archives become names like `node22`.
- Python archives become names like `python3`.
- JDK archives become names like `jdk21`.
- Maven archives become names like `mvn3.9.9`.
- WildFly archives become names like `wildfly35`.

If no hook or built-in rule applies, the symlink name is `current`.

## Alias Hooks

Create `installs\<prgs_folder>.alias.bat` when installation should add or refresh command aliases.

The hook runs after symlink creation.

Examples:

- `drawios.alias.bat`
- `postmans.alias.bat`

Alias hooks commonly edit `%HOME%\bin\senv.local.doskey` and reload aliases with `DOSKEY /MACROFILE`.

## Special Cases Compared To Default Extraction

### Archive Root Has One Nested Folder

`check_prg_symlink.bat` checks whether the extracted folder contains a single subdirectory. If it does, the junction targets that nested folder instead of the outer extraction folder.

This handles archives that unpack as:

```text
tool-version\tool-version\tool.exe
```

instead of:

```text
tool-version\tool.exe
```

### `.tar.xz` Needs Two Extraction Passes

Default extraction creates a `.tar` folder first. `inst_prg.bat` then enters that folder, extracts the inner `.tar`, and removes the `.tar` file.

This is used by entries such as `msys2`.

### Standalone Executable Downloads

Default extraction expects an archive. For a single `.exe`, either:

- Repackage it during `dwl.bat`, as `jq` does.
- Add a custom `.install.bat`, as `tailwindcsss`, `riffs`, and `moars` do.

### Filename Does Not Match Desired Executable Name

Use a post hook when the installed executable should have a stable name.

Codex downloads and extracts:

```text
codex-x86_64-pc-windows-msvc.exe
```

`installs\codexs.post.bat` creates:

```text
codex.exe
```

The original executable remains in place.

### Multiple Possible Archive Patterns

Use `/` in the `prgs.list` pattern when a program has multiple accepted asset names.

Example:

```text
draw.io-*-windows.zip/draw.io-*-windows-no-installer.exe
```

`inst_prg.bat` checks each pattern in order.

### Installed Command Comes From `%HOME%\bin`

The command you type may resolve to `%HOME%\bin`, not this repository.

Check with:

```bat
where inst_prg
where dwl
```

`setup.bat` copies `bin\*` into `%HOME%\bin`. If you change `bin\dwl.bat`, `bin\prgs.list`, or install hooks while developing locally, make sure the active copy is updated before testing from a normal shell.
