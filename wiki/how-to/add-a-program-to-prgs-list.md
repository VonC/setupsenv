# How to add a program to prgs.list

Goal: make a new portable tool downloadable with `dwl <tool>` and installable
with `inst_prg <tool>`.

## Steps

1. Add one line to [bin/prgs.list](../../bin/prgs.list), fields separated by `~`:

   ```text
   Name/alias1/alias2~#~<tool>s~<archive-glob-pattern>
   ```

   - field 1: the name and its aliases, `/`-separated, case-insensitive,
   - field 2: `#` for "any version or latest", or a fixed version list
     (only JDK, Node and Python need one),
   - field 3: the program folder under `%PRGS%`, tool name plus trailing `s`,
   - field 4: the glob matched against the downloaded archive filename
     (`/` separates alternatives),
   - optional field 5: `global`.

   See [prgs-list format](../reference/prgs-list-format.md) for the details.

2. Add a `:dwl_<id>` label in [bin/dwl.bat](../../bin/dwl.bat), where `<id>` is
   the folder name minus the trailing `s`. For a GitHub release, reuse the
   standard template:

   ```bat
   :dwl_mytool
   set "repo=owner/mytool"
   call :get_latest_version_from_github
   set "file=mytool-[v]-windows-amd64.zip"
   set "url=https://github.com/%repo%/releases/download/%tag%/%file%"
   call :curl
   goto:eof
   ```

   `[v]` is replaced by the resolved version, and `:curl` skips the download
   when the file already sits in `%PRGS%\setup`.

3. If the default 7-Zip extraction plus `current` junction is not sufficient,
   add hooks in `installs\` — see
   [How to write an install hook](write-an-install-hook.md).

4. Test the pair:

   ```cmd
   dwl mytool
   inst_prg mytool
   ```

   or both at once with `div mytool`.

5. Sync the active copy: the session runs the scripts from `%HOME%\bin`, not
   from the repository. Re-run `s` (or copy the two changed files to
   `%HOME%\bin`), then confirm with:

   ```cmd
   where dwl
   where inst_prg
   ```

## Check

`dwl mytool` downloads into `%PRGS%\setup`, `inst_prg mytool` uncompresses to
`%PRGS%\mytools\...` and creates the `current` junction. `prgs.list` and
`dwl.bat` must stay in sync: a name resolvable in the list and a matching
`:dwl_` label.

Related: [commands](../reference/commands.md),
[maintainer notes docs/dwl.md](../../docs/dwl.md) and
[docs/inst.md](../../docs/inst.md).
