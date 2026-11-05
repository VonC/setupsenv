# How to build and publish a profile archive

<img src="../assets/logo-senv-transparent.png" alt="" height="90" align="right">

Goal: produce the self-extracting `senv_<profile>-zip.exe` and push it, with
its bootstrap, to the team share so members can install or update from it.

Prerequisite: a maintainer machine running senv in "local" mode (the
repository checkout, with `adm\` on the PATH), and a profile already defined:
see [Create a team profile](create-a-team-profile.md).

## 📋 Steps

1. Rewrite the two changelogs, `wiki\reference\changelog.md` for senv and
   `custom\changelog.md` for custom, with the changes since the build on the
   share. Its `version` file names the commits of that build, custom first,
   then senv:

   ```cmd
   type "<share>\version"
   git log --oneline <senv-commit>..HEAD
   git -C custom log --oneline <custom-commit>..HEAD
   ```

   Each page replaces its previous content: it describes this publication
   only, with an example per change. Keep the senv one free of company,
   project and host names, which belong to custom.

2. Commit your work: `adm\build.bat` refuses to run with a dirty `git status`
   in `senv` or in `custom`. Two knobs relax this during tests:

   - `set SENV_BUILD_SKIP_STATUS=1` skips the check entirely,
   - `SENV_BUILD_ERROR_MODE=custom|senv|both` selects which repository must
     be clean.

3. Build one profile:

   ```cmd
   adm\build.bat xyz
   ```

   The script:

   - writes the combined `git describe` of custom and senv into
     `custom\version`,
   - skips the build if the remote `version` already matches (force with
     `set senv_force_build=1`),
   - packs the whole senv tree (custom included, builds/venvs/logs excluded)
     into a 7-Zip SFX: `builds\senv_xyz-zip.exe`,
   - publishes the exe to the share resolved by `setupsdir_xyz.bat`, along
     with `version`, `setup.ini.bat`, `remote_setup.bat` and a generated
     bootstrap `s.bat` (from `adm\call_remote_setup.bat`). The generic
     `remote_setup.bat` and `ss.bat` come from `adm\custom\`; a file with
     the same name in `custom\` takes precedence.

4. Build every profile at once with `adm\build_all.bat` (failures are logged
   to `builds\build_all.log`).

5. Publish tool archives, independently of the senv build:

   - `adm\publish.bat <archive-pattern> [profile|local|all]`: pushes one
     downloaded archive to every profile share whose list contains that tool.
     A file of `%PRGS%\setup` or `%USERPROFILE%\Downloads` matching no program
     of `prgs.list` (a font, a certificate) is published as is, to every
     targeted share, since no install list can mention it. A `.ttf` or `.otf`
     goes to the `fonts` subfolder of each share, where
     `installs\terminals.post.ps1` looks for it,
   - `adm\publish_profile.bat [profile|all]`: pushes the whole tool set of a
     profile (newest matching archive of each entry) to its share.

## ✅ Check

On the share: `senv_xyz-zip.exe`, `version` and `s.bat` are present and
dated now. On a member machine, running that `s.bat` self-extracts the
archive into `%PRGS%` and chains into `setup.bat`; later updates go through
`up` / `upa`: see
[Update senv and diagnose version drift](update-senv-and-diagnose-version-drift.md).

The exe contains the full custom tree: publish it only to internal shares.
