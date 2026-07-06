# How to update senv and diagnose version drift

<img src="../assets/logo-senv-transparent.png" alt="" height="90" align="right">

Goal: refresh your environment from the team share, and understand what
`profile.bat` reports when local and remote versions differ.

## Update

From inside a session:

- `up`: quick update. Refreshes the drive mapping, goes to the profile
  setups folder (the `cdis` alias) and runs `s.bat gits` there: Git, HOME
  and the `%HOME%\bin` utilities,
- `upg`: same as `up` with no arguments (explicit "gits" form),
- `upa`: full update, `s.bat` with no filter, every tool of the profile
  list is checked and (re)installed,
- `up <tool>`: targeted, passes the arguments through to `s.bat`.

All three are `update_profile.bat`, which reads the setups folder and drive
letter from the `cdis` alias, calls `drive_refresh.bat`, then runs `s.bat`
in that folder.

Alternative without aliases: `cdis` then `s`.

## Diagnose drift

```cmd
profile.bat
```

It prints the active profile, then compares versions:

- `git describe` of `%PRGS%\senv` and `%PRGS%\senv\custom`, against
- the `version` recorded locally (`custom\version`) and on the remote share.

Two directions, possibly combined:

- "new remote commit in remote senv/custom": the team published a newer
  build: run `up` or `upa` to update,
- "new local commit in senv/custom": your checkout is ahead of the share
  (maintainer case), publish with `adm\build.bat <profile>`, see
  [Build and publish a profile archive](build-and-publish-a-profile-archive.md).

A dirty working tree in either repository is flagged too: commit or stash
before publishing.

## ✅ Check

After `up`/`upa`, `profile.bat` reports the local `git describe` as
unchanged from the remote recorded version.

Related: [commands](../reference/commands.md),
[the distribution model](../explanation/distribution-model.md).
