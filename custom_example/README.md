# custom: the private configuration repository of senv

<!-- markdownlint-disable MD013 -->

<img src="logo-senv-custom-transparent.png" alt="senv custom logo: the senv terminal window closed by a padlock" width="200">

`custom_example\` is the seed of your `custom\` folder: the place where
everything specific to your company, your teams and your machines lives.

`senv` (the parent repository) is public and only contains the engine:
scripts, conventions, and a curated list of portable tools. It never contains
a proxy address, a network share, a certificate or an internal host name.
All of that goes into `custom\`, which is:

- a **separate Git repository**, nested inside the senv folder,
- **gitignored by senv** (`/*custom*/` in the parent `.gitignore`), so it can
  never leak into the public history,
- typically hosted on a **private, local-only or corporate remote**.

## 🌱 Bootstrap

You do not create `custom\` by hand. The fastest path is `getstarted.bat`
at the senv root: unattended, it seeds `custom\` from `custom_example\`
(including neutral `senv.custom.bat`, `senv.custom.doskey` and
`gsenv.custom.bat` files to fill later), registers a first profile, runs
`setup.bat`, and makes `custom\` a local Git repository.

Manually, the first run of `setup.bat` copies `custom_example\*` into
`custom\` when the folder is missing. Then:

1. Confirm the locations proposed by `custom\setup.ini.bat` (the template
  detects them, and you can edit the file to force your own values):

   - `PRGS`: local folder where portable programs are uncompressed
     (default `C:\Public\SOFTWARE`; a `nosoft` marker file at a drive root
     excludes that drive),
   - `HOME`: the dedicated senv home (default `%USERPROFILE%\home_senv`),
   - `PROG`: local folder where your Git repositories and work data live
     (a `nodata` marker file excludes a drive).

2. Let `setup.bat` finish its run.
3. Make `custom\` a Git repository with a private remote:

   ```cmd
   cd custom
   git init
   git add .
   git commit -m "chore: initial custom configuration"
   git remote add origin <your private URL>
   ```

`setup.ini.bat` only deals with folder locations. Proxy, shares and
certificates belong to the other files described below.

## 🔒 What goes into custom

Files shared by all profiles:

| File | Role |
| --- | --- |
| `setup.ini.bat` | detects and confirms `PRGS`, `HOME`, `PROG`, `REMOTE_HOME` (seeded from `custom_example\`; edit it to pin site-specific values) |
| `profile` | one line: the name of the active profile on this machine |
| `senv.custom.bat` | team-wide environment variables, sourced by every session (typically `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`) |
| `senv.custom.doskey` | team-wide doskey aliases |
| `gsenv.custom.bat` | team-wide additions to the graphical session (`gsenv`) |
| `senv.custom.all_teams.gcua.list` | default git-hosting services for every profile: setup registers the git identity in every repository whose remotes all match those services |

Files keyed by a profile name (see next section), for a profile `xyz`:

| File | Role |
| --- | --- |
| `install_xyz.list` | the applications installed for that team |
| `setupsdir_xyz.bat` | resolves the team network share holding the archives |
| `senv.custom.xyz.bat` | environment variables for that team |
| `senv.custom.xyz.doskey` | aliases for that team |
| `senv.custom.full.xyz.bat` | optional: fully replaces `senv.custom.bat` for that team |
| `senv.custom.xyz.gcua.list` | optional: the team git-hosting services (one per line), with priority over `senv.custom.all_teams.gcua.list` for that team |

Optional install hooks, named after the program folder (`<tool>s`):

| File | Runs |
| --- | --- |
| `<tool>s.pre.bat` | before the install of that tool |
| `<tool>s.install.bat` | instead of the default uncompress step |
| `<tool>s.post.bat` | after the uncompress step |

Hooks extend the public ones in `senv\installs\`; they are the right place
for corporate steps such as pushing a CA bundle into the Git configuration,
copying a Maven `settings.xml`, or injecting proxy settings into an IDE.

One rule for every file above: reference tools and folders through the
senv variables, `%PRGS%`, `%PROG%`, `%HOME%` in scripts and aliases,
`${env.PRGS}` or `${env.PROG}` in XML settings that support them, never
through an absolute path. `PRGS` is `C:\Public\SOFTWARE` on one machine
and `%USERPROFILE%\SOFTWARE` on the next: a hardcoded path is a profile
that breaks on the next laptop.

## 📦 What senv provides (do not duplicate it here)

The generic machinery is maintained in the public senv repository, so keep
in `custom\` only data and corporate steps:

- `senv\adm\custom\` holds the distribution scripts: `remote_setup.bat`
  (client bootstrap/update from the share), `ss.bat` (published to the share
  as `s.bat`), `senv_update.bat` (push a built archive and refresh), and
  `setup.senv.local.pre.bat` (registers `PRGS`/`HOME`/`PROG`/`REMOTE_HOME`
  in `senv.local.pre.bat`). A file with the same name in `custom\` takes
  precedence, for the rare site that needs a variant.
- `senv\installs\setupsdir.bat` is the share resolver called by your
  `setupsdir_<profile>.bat` scripts.
- `senv\installs\` holds the generic hooks (for example `gos.post.bat`);
  only corporate hooks belong in `custom\`.
- `senv\bin\` holds the generic session tools, including the `px.bat` /
  `pxkill.bat` local-proxy wrappers; only the proxy data (`px.ini`) is
  yours.

## 👥 Profiles

A **profile** is a named bundle: applications, variables, aliases, network
share, shared by one team. The profile token must be strictly identical
across every file that carries it: `profile`, `install_<profile>.list`,
`setupsdir_<profile>.bat`, `senv.custom.<profile>.bat`,
`senv.custom.<profile>.doskey` and the built artifact
`senv_<profile>-zip.exe`. The build and publish scripts discover profiles by
globbing those exact names.

At setup time, only the files of the active profile are copied into
`%HOME%\bin`; the files of other profiles are removed from there, so one
custom repository can serve many teams.

### `install_<profile>.list` format

One line per application, two whitespace-separated columns:

```text
<archive-glob-pattern> <program-folder>
```

For example:

```text
jdk-*-windows-x64.zip javas
apache-maven-*-bin.zip mavens
node-v22.* nodes
system peazips
```

- column 1 is the archive filename pattern to look for in the setups folder,
- column 2 is the program folder under `%PRGS%` (tool name plus trailing `s`),
- the special first token `system` marks a tool expected to be already
  installed on the machine; senv only creates the `current` junction to it.

### `setupsdir_<profile>.bat`

A one-call script:

```bat
call "%~dp0..\installs\setupsdir.bat" "xyz" "\\server\share$\path" "sub\folder"
```

It resolves (and maps, if needed) the network share where the team archives
and the senv self-extracting archive are published.

## 📤 Building and publishing a profile

From a maintainer machine (senv in "local" mode, `adm\` on the PATH):

- `adm\build.bat <profile>`: records the combined senv+custom version, packs
  the whole senv tree (custom included) into a self-extracting
  `builds\senv_<profile>-zip.exe`, and publishes it to the share resolved by
  `setupsdir_<profile>.bat`, together with a generated bootstrap `s.bat`.
- `adm\build_all.bat`: same, for every `setupsdir_*.bat` found.
- `adm\publish.bat <archive> [profile|all]`: publishes one downloaded tool
  archive to every profile share whose list contains that tool.
- `adm\publish_profile.bat [profile|all]`: publishes the whole tool set of a
  profile to its share.

Team members then:

- bootstrap by running the `s.bat` found on the team share (it downloads and
  self-extracts `senv_<profile>-zip.exe`, then runs `setup.bat`),
- update later from inside a session with `up` (current profile), `upg`
  (quick, Git only) or `upa` (everything).

## ⚠️ What must never leave this repository

The built `senv_<profile>-zip.exe` contains the full custom tree, so treat
the archives with the same care as the repository itself. Typical content
that stays private:

- network share paths and internal host names (`setupsdir_*.bat`),
- proxy configuration (`px.ini`, `senv.custom.bat`),
- corporate CA bundles and trust stores (`*.pem`, `*.jks`),
- Maven/IDE settings pointing at internal mirrors,
- SSH `known_hosts` and internal Git remotes,
- the application lists themselves, when they reveal internal stacks.

Keep the remote of this repository private (corporate Git server, or none at
all), and publish the built archives only to internal shares.

## 👉 See also

- [Create a team profile](../wiki/how-to/create-a-team-profile.md)
- [Build and publish a profile archive](../wiki/how-to/build-and-publish-a-profile-archive.md)
- [Work behind a corporate proxy](../wiki/how-to/work-behind-a-corporate-proxy.md)
- [Public engine, private data](../wiki/explanation/public-engine-private-data.md)
