# dwl

`dwl.bat` downloads a supported program archive or installer into `%PRGS%\setup`.
It does not install the program. Installation is handled by `inst_prg.bat`.

Typical usage:

```bat
dwl codex
dwl codex 0.141.0
dwl gh latest
```

## Program Discovery

`dwl.bat` delegates program lookup to `bin\select_prg.bat`.
Supported programs are declared in `bin\prgs.list`:

```text
Name/alias1/alias2~versions-or-#~folder-name-with-s~download-pattern~global
```

Example:

```text
Codex/cdx~#~codexs~codex-rust-v*-x86_64-pc-windows-msvc.zip~global
```

Fields:

- `Name/alias1/alias2`: names accepted on the command line. `dwl codex` and `dwl cdx` both match the Codex entry.
- `versions-or-#`: allowed version choices. `#` means no fixed list; any version or `latest` is accepted.
- `folder-name-with-s`: install family folder, for example `codexs`, `gits`, `npps`.
- `download-pattern`: file pattern used later by `inst_prg.bat` to find the archive.
- `global`: optional marker used by the broader setup/profile logic.

`select_prg.bat` returns:

- `prg_id`: the folder name without its trailing `s`, for example `codex`.
- `prg_version`: the selected version or `latest`.
- `prg_pattern`: the archive pattern from `prgs.list`.

`dwl.bat` then calls a matching label:

```bat
call :dwl_%prgname%
```

For `codex`, that means `:dwl_codex` must exist in `bin\dwl.bat`.

## Normal GitHub Download

The default pattern for GitHub-hosted tools is:

```bat
:dwl_tool
set "repo=owner/repository"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "Dwl (%prgname%)'%repo%' version '%version%'"
set "file=tool-%version%-windows-x64.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof
```

The common helper `:get_latest_version_from_github`:

- Follows `https://github.com/<repo>/releases/latest`.
- Extracts the final tag from the redirected URL.
- Stores the original tag in `tag`.
- Stores the version without a leading `v` in `version`.
- Has special handling to avoid nightly releases when it detects a nightly tag.

The common helper `:curl`:

- Calls `:template`.
- Defaults `target_local_file` to `file` when not set.
- Replaces `[v]` placeholders with the resolved `version`.
- Skips the download if `%PRGS%\setup\%target_local_file%` already exists.
- Downloads with `curl -fkL --url "%url%" -o "%PRGS%\setup\%target_local_file%"`.

Use the normal GitHub shape when all of these are true:

- The project is on GitHub.
- `latest` resolves to a tag that can be converted by removing a leading `v`.
- The asset name contains the same version string.
- The release URL uses either `v%version%` or another simple tag shape.
- The downloaded filename is also the filename that should be stored in `%PRGS%\setup`.

## Adding A Regular GitHub Program

1. Add an entry to `bin\prgs.list`.

   ```text
   Tool/toolalias~#~tools~tool-*-windows-x64.zip
   ```

2. Add a `:dwl_tool` label to `bin\dwl.bat`.

   ```bat
   :dwl_tool
   set "repo=owner/tool"
   if "%version%"=="latest" ( call :get_latest_version_from_github )
   %_info% "Dwl (%prgname%)'%repo%' version '%version%'"
   set "file=tool-%version%-windows-x64.zip"
   set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
   call :curl
   goto:eof
   ```

3. Run:

   ```bat
   dwl tool
   inst_prg tool
   ```

4. If the active command comes from `%HOME%\bin`, run `setup.bat` or copy the changed `bin` files to `%HOME%\bin`.

## Special Download Cases

Not every tool follows the regular GitHub convention. Adjust the `:dwl_<id>` label when any part of the release flow differs.

### Release Tag Is Not `v%version%`

Some projects use bare numeric tags, date tags, product prefixes, or custom prefixes.

Examples:

- `ripgrep`: release URL uses `%version%`, not `v%version%`.
- `msys2`: release tag is a date like `2024-01-13`.
- `codex`: release tag is `rust-v0.141.0`.
- `postman`: release tag is the full Portapps version string, without `v`.

Codex normalizes common user inputs into the real release tag:

```bat
dwl codex 0.141.0      rem tag rust-v0.141.0
dwl codex v0.141.0     rem tag rust-v0.141.0
dwl codex rust-v0.141.0
```

The stored archive is renamed with `target_local_file`:

```bat
set "file=codex-x86_64-pc-windows-msvc.exe.zip"
set "target_local_file=codex-%tag%-x86_64-pc-windows-msvc.zip"
set "url=https://github.com/%repo%/releases/download/%tag%/%file%"
```

Use `target_local_file` when the upstream filename is too generic or does not include the version.

### Asset Name Does Not Match The Program Id

Many labels build the asset filename directly from `%prgname%`, but that only works when the asset begins with the same id.

Examples:

- `npp`: asset is `npp.<version>.portable.x64.zip`.
- `terminal`: asset is `Microsoft.WindowsTerminal_<version>_x64.zip`.
- `codex`: asset is `codex-x86_64-pc-windows-msvc.exe.zip`, but the local archive is versioned as `codex-rust-v...zip`.

Set `file` explicitly in these cases.

### Upstream Latest Is Not A GitHub Release Redirect

Use a custom query when the latest version must be parsed from a website or API.

Examples:

- `python`: reads `https://endoflife.date/api/python/<cycle>.json`.
- `jdk`: reads the Adoptium API to resolve the JDK build and download link.
- `go`: scrapes the Go download page for the Windows zip.
- `maven`, `eclipse`, `yed`, `treesize`, `ffmpeg`, `nexus`, `artifactory`: parse project-specific pages.

In those labels, set `version`, `file`, and `url` yourself before calling `:curl`.

### User Version Is A Major Or Cycle

Some entries accept a major or cycle rather than an exact release.

Examples:

- `dwl node 22` resolves the latest `v22.x.y`.
- `dwl python 3.13` resolves the latest Python `3.13.x`.
- `dwl wildfly 35` resolves the latest matching WildFly release.
- `dwl jdk 21` resolves the latest JDK 21 build.

Implement this before setting `file` and `url`.

### Download Has Fallback Mirrors

`go` uses `next_url` and retries alternate mirrors when the first URL fails.

Use this pattern when upstream availability is unreliable:

```bat
set "url=primary"
set "next_url=fallback"
call :curl
if errorlevel 1 (
  set "url=%next_url%"
  set "next_url="
  call :curl
)
```

### Downloaded File Needs Repackaging

`jq` downloads a single `.exe`, copies it into a versioned directory under `%PRGS%\setup`, and creates a zip archive. This makes the result compatible with the default installer, which expects an archive or installable file pattern from `prgs.list`.

Use this only when the upstream asset is not already in a shape that `inst_prg.bat` can install cleanly.

### Archive Is Built Locally And Cannot Be Downloaded

`python`: python.org only ships an `.exe` installer. The portable archive `python-<version>-amd64.zip` matching the `prgs.list` pattern is built by `installs\pythons.install.bat` and may already be published in a setups folder. After resolving the version, `:dwl_python` looks for that zip in the local `%PRGS%\setup`, then in the remote profile setups folder and in `%USERPROFILE%\senv_setups\setups` (through `:find_setups_zip`, which copies the archive locally when found). The installer `.exe` is downloaded only when no zip exists anywhere.

Use `:find_setups_zip` in a `:dwl_<prg_id>` label when a senv-built archive can make the upstream download unnecessary.

### Upstream Stops Publishing The Windows Asset

`python`: python.org builds a Windows installer only while a cycle stays in its bugfix phase. Once the cycle turns security-only, `https://www.python.org/ftp/python/<version>/` holds source archives alone and `python-<version>-amd64.exe` answers 404. Python 3.12 left its bugfix phase on 2025-04-02, so 3.12.10 is its last release with an installer, while `endoflife.date` keeps reporting newer 3.12 releases.

Before downloading, `:dwl_python` calls `:python_check_installer`, which sends a HEAD request to the installer URL. On 200 the download proceeds. On anything else, the routine walks the same cycle down, patch by patch, up to 15 releases, then stops with exit code 13 and names the last release that still carries an installer:

```text
 WARN  : [dwl.bat] python.org has no Windows installer 'python-3.12.13-amd64.exe' for version '3.12.13'
 INFO  : [dwl.bat] That usually means the cycle turned security-only: such releases ship source archives alone, no .exe and no .msi
 INFO  : [dwl.bat] Last '3.12' release with a Windows installer: '3.12.10'. Use: dwl python 3.12.10
 INFO  : [dwl.bat] Or publish 'python-3.12.13-amd64.zip' in '%PRGS%\setup' or in a setups folder: installs\pythons.install.bat builds it
 FATAL 13 : [dwl.bat] python.org publishes no Windows installer for Python '3.12.13'
```

The probe is skipped when that installer is already in `%PRGS%\setup`, and it never runs when `:find_setups_zip` found a matching zip first.

Use this pattern in a `:dwl_<prg_id>` label when upstream keeps releasing versions but stops publishing the Windows asset.

## Keep `prgs.list` And `dwl.bat` In Sync

A program must exist in both places:

- `bin\prgs.list` so `select_prg.bat` can resolve names and patterns.
- `bin\dwl.bat` with a matching `:dwl_<prg_id>` label so the download can run.

If the command is being run from `%HOME%\bin` instead of this repository, update the active copy too. `where dwl` shows which script is used.
