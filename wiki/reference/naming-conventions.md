# Naming conventions

<img src="../assets/logo-senv-transparent.png" alt="" height="90" align="right">

Every rule of thumb senv relies on, in one page. The rationale is in
[Junctions as a location contract](../explanation/junctions-as-a-contract.md).

## Program folders

| Convention | Example |
| --- | --- |
| family folder: tool name plus trailing `s`, under `%PRGS%` | `%PRGS%\javas`, `%PRGS%\gits` |
| program id: family folder minus the `s` | `java`, `git` |
| one subfolder per version, `<prefix><version>` | `jdk21`, `node22`, `mvn3.9.9`, `python3.13.1`, `wildfly35` |
| junction to the active version, default name `current` | `%PRGS%\gits\current` |
| versioned junction names for jdk, node, python, maven, wildfly | `%PRGS%\javas\jdk21` |
| tools installed outside senv: `current` junction to the external path | `%PRGS%\vscodes\current` |

On drives where junctions are not possible (network), the extracted folder
is renamed to the junction name and a `_<original-name>` marker file records
it.

When a junction name is found to be a real directory (previous manual
installation, or a network-fallback rename brought back to a local drive),
the junction scripts keep the directory aside as `<junction-name>.old`
before creating the junction; delete that backup once the new installation
is validated.

## Install hooks

For a family folder `<tool>s`, hook scripts are looked up by name in
`installs\` (public), then `custom\` (private), then the local folder:

| Hook | Runs |
| --- | --- |
| `<tool>s.pre.bat` | before the install |
| `<tool>s.install.bat` | instead of the default 7-Zip extraction |
| `<tool>s.post.bat` | after extraction, before the junction |
| `<tool>s.sln.bat` | during junction creation, prints the junction name |
| `<tool>s.alias.bat` | after the junction, adds doskey aliases |
| `<tool>s.test.bat` | manual diagnostics only |

## Profile-keyed files (in `custom\`)

The `<profile>` token must be identical across all of them:

| File | Content |
| --- | --- |
| `profile` | one line: the active profile name |
| `install_<profile>.list` | application list ([format](install-list-format.md)) |
| `setupsdir_<profile>.bat` | resolves the team archive share |
| `senv.custom.<profile>.bat` | per-profile environment variables |
| `senv.custom.<profile>.doskey` | per-profile aliases |
| `senv.custom.full.<profile>.bat` | optional, sourced by sessions instead of `senv.custom.bat` (the shared file stays untouched) |
| `senv.custom.<profile>.gcua.list` | optional, team git-hosting services: setup then applies the git identity to matching repositories ([git configuration](git-configuration.md)) |
| `senv_<profile>-zip.exe` | built self-extracting archive (in `builds\`) |

## Custom-wide files (all profiles)

| File | Content |
| --- | --- |
| `setup.ini.bat` | detects and confirms `PRGS`, `HOME`, `PROG`, `REMOTE_HOME` |
| `senv.custom.bat` | team environment variables, sourced by every session |
| `senv.custom.doskey` | team aliases |
| `gsenv.custom.bat` | team additions to the graphical session |
| `senv.custom.all_teams.gcua.list` | default git-hosting services for every profile; a `senv.custom.<profile>.gcua.list` has priority over it ([git configuration](git-configuration.md)) |

## Senv-provided distribution scripts, in `adm\custom\`

Generic machinery maintained in the public repository. A file with the same
name in `custom\` takes precedence over the `adm\custom\` one:

| File | Content |
| --- | --- |
| `remote_setup.bat` | client bootstrap/update from the team share |
| `ss.bat` | published to the share as its `s.bat` |
| `senv_update.bat` | push a built archive to the share and refresh locally |
| `setup.senv.local.pre.bat` | registers the four location variables in `senv.local.pre.bat` |

The share resolver called by `setupsdir_<profile>.bat` is
`installs\setupsdir.bat`.

## Local (personal) files, in `%HOME%\bin`

Created once by `setup.bat`, never overwritten by an update:

| File | Content |
| --- | --- |
| `senv.local.pre.bat` | authoritative `PRGS`, `HOME`, `PROG`, `REMOTE_HOME` |
| `senv.local.bat` | personal environment variables |
| `senv.local.doskey` | personal aliases (holds `cdi`, `cdis`) |
| `gsenv.local.bat` | personal additions to the graphical session |

## Generated and transient files

Files senv writes at run time. None is tracked by git (all gitignored or
outside the repositories):

| File | Written by | Lifetime |
| --- | --- | --- |
| `%USERPROFILE%\senv.bat` | `setup.bat`, rendered from `senv.user_profile.tpl.bat` | regenerated on every setup run |
| `%HOME%\bin\gcu.bat` | the `gits` install hook, from the registered identity | regenerated when the identity changes |
| `%HOME%\bin\teams-reader.exe` | `team-chat.ps1`, built from `tools\team-chat` | created on first extraction and rebuilt when a Go or module source is newer |
| `custom\profile`, `custom\version` | setup (profile) and `adm\build.bat` (version) | per machine / per build |
| `custom\driverLetter.bat` | `installs\drive_detection.bat`, holds the detected drive letter (`set "driveLetter=L:"`) | consumed and deleted by `installs\setupsdir.bat` seconds later; both the `driveLetter` and the historical `driverLetter` spellings are gitignored |
| `setup_cleanup*.tmp`, `tmp` | `setup.bat`, profile cleanup and doskey rebuild | deleted at the end of the run |
| `%TEMP%\switchver_<SENV_UID>_*.tmp`, `%TEMP%\switchjdk_path_<SENV_UID>.tmp`, `%TEMP%\switchpy_<SENV_UID>.tmp`, `%TEMP%\ppath_<SENV_UID>.tmp` | `switch*` and `ppath`, version lists and `PATH` filtering | deleted before the command returns; the `SENV_UID` suffix ([environment variables](environment-variables.md)) keeps concurrent terminals apart |
| `%PRGS%\<tool>s\<junction-name>.old` | `installs\check_symlink.bat` and `bin\check_prg_symlink.bat`, real directory found in place of a junction and kept aside | persists until deleted manually; replaced by the next repair |
| `%REMOTE_HOME%\state` | `check_migrate_home.bat`, HOME-migration progress tokens | persists on the remote home |
| `%USERPROFILE%\usernamel` | `senv.bat`, cached lowercase user name | persists, one line |

## Load order

Environment: `senv.local.pre.bat` → built-in senv settings →
`senv.custom.bat` → `senv.local.bat` → `senv.custom.<profile>.bat`.

Doskey: `senv.doskey` → `senv.custom.doskey` → `senv.local.doskey` →
`senv.custom.<profile>.doskey`. Later files win.
