# senv: a portable, no-admin development environment for Windows

<p align="center">
  <img src="wiki/assets/logo-senv-transparent.png" alt="senv logo: a terminal window containing the four senv themes" width="220">
</p>

`senv` ("session environment") turns a plain `CMD` session into a fully equipped
development shell on a locked-down Windows laptop:

- no admin rights needed,
- no installer run on the machine (tools are only downloaded and uncompressed,
  the single exception is VSCode, installed per-user),
- nothing outside the session is modified: close the terminal and the laptop is
  exactly as before.

Open a terminal, type `senv`, and inside that session "everything works":
Git, Java, Node, Python, Maven, your editors, your aliases, your proxy.
Outside the session, nothing is affected.

The initial focus is contractors working in a locked corporate environment,
but it fits anyone who wants a reproducible, self-contained Windows setup.

## 📦 How it works

A senv session is built from scratch each time, instead of relying on the
laptop system and user environments:

- 🖥️ a **minimal `PATH`**: reset to the bare Windows folders, then extended only
  with what senv provides (`%HOME%\bin` first, then a portable Git, which also
  brings `grep`, `awk`, `sed`, `curl` and `bash`),
- 🧰 a set of **portable applications** installed under `%PRGS%`,
- 🏷️ a set of **environment variables** (locale, editor, proxy, tool homes),
- ⚡ a set of **aliases** (`doskey` macros) for navigation, Git, tools and updates,
- 🏠 a dedicated **senv user `HOME`** (by default `%USERPROFILE%\home_senv`),
  which is its own Git repository and can be backed up to a remote location.

### 🧰 Program layout: `%PRGS%\<tool>s\<version|current>`

Every tool family lives in one folder named after the tool plus a trailing
`s`, one subfolder per version, and a junction pointing at the active one:

```text
%PRGS%\javas\jdk21
%PRGS%\nodes\node22
%PRGS%\gits\current
%PRGS%\vscodes\current
```

A tool already installed elsewhere (for example by a corporate installer) is
still referenced through the same convention, using a junction folder to the
external location. Every script can therefore rely on one single path shape.

### 🏷️ Configuration layers

Settings and aliases are loaded in four layers, each one able to override the
previous:

1. **senv** (this public repository): the engine and the global aliases.
2. **custom** (a private, nested repository in `custom\`, gitignored here):
  team-shared and possibly corporate-sensitive settings: proxy, network
  shares, certificates. See [custom_example/README.md](custom_example/README.md).
3. **profile** (`senv.custom.<profile>.*` in the custom repository): the
  application list, variables and aliases shared by one team.
4. **local** (`senv.local.*` in `%HOME%\bin`): your personal settings. These
  files are created once and never overwritten, so a senv update does not
  touch your customizations.

### 🧰 On-demand tools and versions

- `dwl <tool> [version]` downloads a portable archive from a curated list
  ([bin/prgs.list](bin/prgs.list), about 50 applications and languages).
- `inst_prg <tool>` (alias `inst`) uncompresses it under `%PRGS%` and wires
  the junction. `div <tool> [version]` does both in one step.
- `switchjdk`, `switchmvn`, `switchnode`, `switchpy`, `switchwf` (all built on
  the generic `switchver`) add one specific tool version to the `PATH` of the
  current session only. The global `PATH` is never modified permanently.

### 🖥️ Per-project senv

`senv` first looks for a `senv.bat` in the current directory. A project can
therefore ship its own `senv.bat` that calls the global one and then, for
example, runs `switchjdk 17` and `switchnode 20`: opening a session in that
project gives the exact tool versions the project needs, found at their
conventional `%PRGS%` locations. `senv all` runs the global activation
first and the project one on top, handy for a Windows Terminal tab per
project
([how-to](wiki/how-to/open-project-tabs-in-windows-terminal.md)).

## 🚀 Quick start

1. Clone this repository (with its `batcolors` submodule) into `<PRGS>\senv`,
   for example `C:\Public\SOFTWARE\senv`:

   ```cmd
   git clone --recurse-submodules https://github.com/VonC/setupsenv senv
   ```

2. Run `getstarted.bat`. Unattended, it:

   - creates your private `custom\` nested repository from `custom_example\`
     and makes it a local Git repository,
   - registers a first profile, named `perso` by default,
   - downloads a minimal tool set, 7-Zip (peazip), Git, gum, Notepad++,
     Sysinternals, VSCode, with the `curl` shipped in Windows,
   - runs `setup.bat`: tools uncompressed under `%PRGS%`, dedicated senv
    `HOME` created, `%USERPROFILE%\senv.bat` generated.

3. In any new `CMD` session, type `senv`. You are good to go.

`getstarted.bat [profile] ["Full Name"] [email]` accepts overrides, and you
can set `PRGS`, `HOME`, `PROG` (or `HTTPS_PROXY` for the downloads)
beforehand to force locations. The guided, step-by-step version of the same
install is the [first tutorial](wiki/tutorials/01-your-first-senv.md).

### ✨ After the first run

- ⚡ **Customize your session**: type `senve` to edit your personal
  variables (`senv.local.bat`, reload with `senv`), or `aliase` to edit
  your personal aliases (`senv.local.doskey`, reload with `aliasr`); both
  files survive every senv update
  ([how-to](wiki/how-to/add-personal-alias-or-env-var.md)).
- 🧰 **Add tools on demand**: `div node`, or `dwl jdk 21` then `inst jdk`,
  then `switchjdk`/`switchnode` inside a session
  ([tutorial](wiki/tutorials/02-install-and-use-a-tool-on-demand.md)).
- 📦 **More profiles when you need them**: one per computer for yourself, or
  one per team you equip: each profile is an `install_<profile>.list` plus
  `senv.custom.<profile>.*` files in `custom\`, and can be distributed from
  a team share ([how-to](wiki/how-to/create-a-team-profile.md),
  [explanation](wiki/explanation/distribution-model.md)).

## 🖥️ Everyday commands

A few of the commands available inside a session; the complete list is (or
will be) in the wiki reference pages:

| Command | Role |
| --- | --- |
| `senv` | activate the session (minimal PATH, variables, aliases) |
| `s` | re-run setup unattended (refresh tools and configuration) |
| `dwl`, `inst`, `div` | download / uncompress / both, for one tool |
| `switchjdk`, `switchnode`, ... | put one tool version on the session PATH |
| `up`, `upg`, `upa` | update the environment from the team share |
| `alias [pattern]` | list the doskey aliases, filtered by name or content (`alias cd`) |
| `cdg`, `cds`, `cdh`, ... | jump to the key folders; `cdg` is where you clone (`%PROG%\git`) |
| `gcu` | register your name/email in the current repository (see below) |
| `senve` | edit your personal variables in VSCode; reload with `senv` |
| `aliase` | edit your personal aliases in VSCode; reload with `aliasr` |
| `ppath` | print and check the PATH, entry by entry |
| `ti`, `ei` | test / restore internet access (proxy restart) |

### 🪪 Git identity, per repository

senv sets no global Git email: with `user.useConfigOnly=true`, a commit is
refused until the repository has its own identity. Clone under `cdg`
(`%PROG%\git`), run `gcu` once in the clone, done: a professional email
can no longer slip into a public repository by accident. Details in the
[git configuration reference](wiki/reference/git-configuration.md) and the
[reasoning](wiki/explanation/public-engine-private-data.md#one-git-identity-per-repository).

## 🗂️ Repository layout

```text
getstarted.bat       unattended onboarding for a new user
setup.bat            installer/bootstrapper (s.bat = unattended re-run)
bin\                 session scripts, copied to %HOME%\bin (senv.bat, dwl.bat,
                     inst_prg.bat, switch*.bat, prgs.list, senv.doskey, ...)
installs\            per-tool install hooks (*.pre|install|post|sln|alias.bat)
adm\                 maintainer tooling: build and publish profile archives
adm\custom\          generic distribution scripts (remote_setup.bat, ss.bat,
                     senv_update.bat, ...) that a custom repository may override
custom_example\      template to bootstrap your private custom repository
setups_example\      template for a local archive folder
docs\                working notes for maintainers (dwl.md, inst.md)
wiki\                documentation, one subfolder per Diátaxis category
batcolors\           submodule: colored output for batch scripts
custom\              your private repository (gitignored, created at setup)
```

## 🤝 Teams and distribution

A team administrator defines a **profile** in the private custom repository
(application list, variables, aliases, network share), then builds a
self-extracting archive with `adm\build.bat <profile>` and publishes it to the
team share. Team members bootstrap or update their whole environment from that
share, still without admin rights. Details in
[custom_example/README.md](custom_example/README.md).

## 📚 Documentation

This README is only the front door: it says what senv is and where to go
next. The rest of the documentation lives in the [wiki/](wiki/README.md)
folder, organized on the [Diátaxis](https://diataxis.fr/) model, which
separates four kinds of pages so that none of them gets mixed with the
others:

- 🎓 **[Tutorials](wiki/tutorials/)**: learning by doing: first installation,
  first session, first project-specific senv.
- 🧭 **[How-to guides](wiki/how-to/)**: recipes for a precise goal, add a
  program to `prgs.list`, create a team profile, publish an update.
- 📖 **[Reference](wiki/reference/)**: exact descriptions, commands and their
  arguments, file naming conventions, environment variables, alias list.
- 💡 **[Explanation](wiki/explanation/)**: background and reasoning, why a
  minimal PATH, why a dedicated HOME, how the configuration layers fit
  together.

[docs/dwl.md](docs/dwl.md) and [docs/inst.md](docs/inst.md) remain the
maintainers' working notes on the download and install workflows.
