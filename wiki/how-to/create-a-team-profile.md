# How to create a team profile

Profiles are not only for teams: the same recipe gives one person a profile
per computer (say `perso` and `laptop`), sharing the same private custom
repository.

Goal: define a named bundle of applications, variables and aliases (`xyz` in
the examples) that a whole team installs and updates from a shared location.

All files below live in the private `custom\` repository — see
[custom_example/README.md](../../custom_example/README.md).

## Steps

1. Declare the application list `custom\install_xyz.list`, one tool per line:

   ```text
   jdk-*-windows-x64.zip javas
   apache-maven-*-bin.zip mavens
   system peazips
   ```

   Format details in [install-list format](../reference/install-list-format.md).

2. Point at the team share with `custom\setupsdir_xyz.bat`:

   ```bat
   call "%~dp0..\installs\setupsdir.bat" "xyz" "\\server\share$\path" "sub\folder"
   ```

3. Add the team environment variables in `custom\senv.custom.xyz.bat`
   (sourced by every session running that profile), for example `M2_HOME` or
   `MAVEN_OPTS`. To replace the team-wide `senv.custom.bat` entirely instead
   of adding to it, provide `custom\senv.custom.full.xyz.bat`.

4. Add the team aliases in `custom\senv.custom.xyz.doskey` (loaded after the
   global and team-wide doskey layers).

5. Activate the profile on a machine: write the single line `xyz` into
   `custom\profile`, or run `setup.bat _xyz` once (the leading underscore
   selects the profile).

6. Run `s`. Setup copies the `xyz` files into `%HOME%\bin` and removes the
   files of every other profile from there — one custom repository can serve
   many teams, but a machine runs exactly one profile.

## The identical-token rule

The `xyz` token must be strictly identical across `profile`,
`install_xyz.list`, `setupsdir_xyz.bat`, `senv.custom.xyz.bat`,
`senv.custom.xyz.doskey` and the built `senv_xyz-zip.exe`: the build and
publish scripts discover profiles by globbing those exact names.

## Check

In a new session, `profile.bat` reports `xyz` as the active profile, `alias`
lists the team aliases, and the variables from `senv.custom.xyz.bat` are set.

Next: [Build and publish a profile archive](build-and-publish-a-profile-archive.md).
