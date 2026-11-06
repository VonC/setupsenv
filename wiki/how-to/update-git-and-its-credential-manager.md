# How to update Git and its credential manager

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: install a new Git for Windows, or a Git Credential Manager (GCM) newer
than the one Git bundles, and check that Git runs it for its `manager`
credential helper.

A newer GCM matters when a Git hosting service refuses the bundled one:
Bitbucket Cloud refuses a GCM older than 3.0.0 from 2026-11-30, while Git for
Windows 2.56.0.4 still bundles GCM 2.9.1 (GCM 3.0.2 came out a few hours
after it, and is planned for the next Git for Windows release).

## 📋 Steps

1. Update Git:

   ```cmd
   dwl git
   inst git
   ```

   `inst git` extracts the new PortableGit, points `%PRGS%\gits\current` at
   it, then runs the `gits` install hooks. They set `credential.helper` to
   `manager`, globally and in the new Git folder (see
   [Git configuration](../reference/git-configuration.md)), and put the
   standalone GCM of step 2 in use when there is one.

2. Install the standalone GCM:

   ```cmd
   dwl gcm
   inst gcm
   ```

   `dwl gcm` downloads the portable `gcm-win-x64-<version>.zip` of the GCM
   GitHub releases into `%PRGS%\setup`: the program and its native DLLs, no
   installer, no .NET runtime to install. `inst gcm` extracts it into
   `%PRGS%\gcms`, then its hook `installs\gcms.post.bat` copies it over the
   GCM bundled in Git's `ucrt64\bin` (`mingw64\bin` before Git for Windows
   2.56). Each replaced file stays next to it as `<name>.bundled`.

The order of the two steps does not matter: a later `inst git` puts the
standalone GCM in use again in the new Git folder. Once Git bundles a GCM at
least as recent, the hook keeps the bundled one, and `%PRGS%\gcms` can go.

For a whole team, add the line `gcm-win-x64-*.zip gcms` to the profile's
`custom\install_<profile>.list` (see
[install_&lt;profile&gt;.list format](../reference/install-list-format.md)):
`setup.bat` installs it after Git, and publishing the profile copies the zip
to the team share.

Why a copy and not `PATH`: Git runs the `manager` helper as
`git credential-manager`, and looks for `git-credential-manager.exe` in its
own folders (`libexec\git-core`, then `ucrt64\bin`) before `PATH`. A
standalone GCM placed first on `PATH` is listed first by
`where git-credential-manager`, yet Git still runs the bundled one.

## ✅ Check

```cmd
git config --show-origin --get-all credential.helper
git credential-manager --version
where git-credential-manager
```

```text
file:C:/Public/SOFTWARE/gits/PortableGit-2.56.0.4-64-bit.7z/etc/gitconfig	manager
file:C:/Users/<you>/home_senv/.gitconfig	manager
3.0.2+0d95999b8fb39bd1045770fe1d69f6a2b07101d7
C:\Public\SOFTWARE\gits\current\ucrt64\bin\git-credential-manager.exe
```

Both helper lines say `manager`, the version is the standalone one, and
`where` finds a single GCM. A full path instead of `manager`, such as
`!"C:/.../git-credential-manager.exe"`, comes from the helper-selector dialog
of Git for Windows: run `inst git` again.

## Go back to the bundled GCM

In `%PRGS%\gits\current\ucrt64\bin`, replace each file that has a
`.bundled` copy by that copy, then remove the `%PRGS%\gcms\current`
junction so that the next `inst git` keeps the bundled GCM.

Related: [Git configuration](../reference/git-configuration.md),
[Write an install hook](write-an-install-hook.md),
[prgs.list format](../reference/prgs-list-format.md).
