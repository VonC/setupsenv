# How to migrate HOME from a network drive to local

Goal: move a slow remote/roaming senv `HOME` to the fast local
`%USERPROFILE%\home_senv`, keeping the remote as a Git backup.

This is handled by [check_migrate_home.bat](../../check_migrate_home.bat).
It runs automatically from `setup.bat` when `HOME`, `PRGS` and `PROG` are
already set and `grep` is available (portable Git installed), so usually a
plain `s` is all you type.

## What it does

1. Copies the remote `HOME` to `%USERPROFILE%\home_senv` with `robocopy`
   (excluding `*.git` and `old`).
2. Turns the local copy into a Git repository (`git init` plus an initial
   commit, or a commit of pending changes on later runs).
3. Creates a bare repository `home_senv.git` on the remote and wires it as
   the backup remote.
4. Rewrites the pointers with `sed`:

   - `set "HOME=..."` and `REMOTE_HOME` in `%HOME%\bin\senv.local.pre.bat`,
   - the `call` line of `%USERPROFILE%\senv.bat`, so new sessions activate
     from the local HOME.

5. Moves the old remote content into `%REMOTE_HOME%\old`.

Each phase runs once: progress is recorded in a `%REMOTE_HOME%\state` file
with the tokens `_copied_`, `_updated_`, `_nosenvupdate_`, `_cleaned_`. A
re-run resumes where it left off.

## Steps

1. Confirm `REMOTE_HOME` is set (it is written by `setup.ini.bat` into
   `senv.local.pre.bat`).
2. Run `s`.
3. Open a new `CMD` and type `senv`.

## Check

- `echo %HOME%` prints `%USERPROFILE%\home_senv`,
- `git -C %HOME% remote -v` shows the bare remote `home_senv.git`,
- the remote `state` file contains `_cleaned_`.

Related: [environment variables](../reference/environment-variables.md),
[the configuration layers](../explanation/configuration-layers.md).
