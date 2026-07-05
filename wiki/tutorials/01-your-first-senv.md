# Your first senv

In this tutorial you install senv from scratch on a Windows machine, without
admin rights, and open your first working session. Allow 15 to 30 minutes,
mostly download time.

You need: Windows, an internet connection (possibly through a proxy), and a
folder where you can write, for example `C:\Public\SOFTWARE`.

## 1. Clone the repository

Pick your programs folder — senv calls it `PRGS`. Here we use
`C:\Public\SOFTWARE`:

```cmd
cd /d C:\Public\SOFTWARE
git clone --recurse-submodules https://github.com/VonC/setupsenv senv
cd senv
```

The `--recurse-submodules` flag matters: it brings `batcolors`, the colored
output used by every script.

If Git is not available yet on the machine, download the repository as a zip
from GitHub and uncompress it to `C:\Public\SOFTWARE\senv` instead — setup
installs its own portable Git anyway (also uncompress the
[batcolors](https://github.com/VonC/batcolors) zip into `senv\batcolors`).

## 2. The fast path: getstarted.bat

If you want the result without the walk-through, run:

```cmd
getstarted.bat
```

It performs, unattended, everything the rest of this tutorial does by hand:
seeds `custom\`, registers a `perso` profile and your git identity,
downloads the minimal tool set with the Windows `curl`, runs `setup.bat`,
and makes `custom\` a local Git repository. When it ends, jump to step
[5. Open your first session](#5-open-your-first-session).

Optional arguments and overrides:

```cmd
getstarted.bat [profile] ["Full Name"] [email]
set "PRGS=D:\SOFTWARE"      &:: force the programs root, before calling
set "HTTPS_PROXY=..."       &:: if the downloads go through a proxy
```

To understand what just happened — or to do it step by step — continue
reading.

## 3. The guided path: setup.bat

```cmd
setup.bat
```

On this first run, setup:

- creates `custom\` from the `custom_example\` template,
- runs `custom\setup.ini.bat`, which detects the key folders and asks you to
  confirm them:

```text
Do you confirm HOME ('C:\Users\you\home_senv'), REMOTE_HOME (...),
PRGS ('C:\Public\SOFTWARE') and PROG ('C:\Users\you') (Y/[N])?
```

- `PRGS` — where portable programs are uncompressed,
- `HOME` — the dedicated senv home (config files, utilities),
- `PROG` — where your Git repositories and work data live.

Answer `Y` to accept. To force other locations, answer `N`, edit the `set`
lines in `custom\setup.ini.bat`, and run `setup.bat` again.

## 4. The same run installs the base tools

After the confirmation, setup downloads and uncompresses the base tool set:
7-Zip (peazip), Git, px, VSCode, Notepad++, gum, Sysinternals, Windows
Terminal, git-cliff, jq. You see one colored `[peazips]`, `[gits]`, ...
block per tool.

Setup also:

- copies all utilities into `%HOME%\bin`,
- generates `%USERPROFILE%\senv.bat`, the session entry point,
- creates your personal `senv.local.*` files (kept across future updates).

The run ends with `You are good to go!`.

## 5. Open your first session

Open a **new** `CMD` window and type:

```cmd
senv
```

You should see:

```text
senv activated: senv_dir='...'
```

That single line means: PATH rebuilt from scratch, portable Git and all senv
utilities available, variables set, aliases loaded — in this window only.

## 6. Look around

Try a few of the loaded aliases:

```cmd
cds     &:: cd to %PRGS%, the programs folder
cdh     &:: cd to %HOME%, the senv home
cdi     &:: cd to %PRGS%\senv, this repository
cdg     &:: cd to %PROG%\git, the home of your clones
gs      &:: git status, short form
alias   &:: list every doskey alias
alias cd  &:: filter: every alias with "cd" in its name or definition
```

Two habits worth taking from day one: clone your repositories under `cdg`
(one common place for all of them), and run `gcu` once inside each clone —
senv sets no global Git identity, so commits are refused until the
repository has its own name and email (see
[git configuration](../reference/git-configuration.md)).

And when you want to make senv yours, the customization trio:

```cmd
senve   &:: edit your personal variables (senv.local.bat) in VSCode
senv    &:: reload everything, so the variable change takes effect
aliase  &:: edit your personal aliases (senv.local.doskey) in VSCode
aliasr  &:: reload only the aliases, enough after an aliase edit
```

Both files survive every senv update.

Then close the window. Open a plain `CMD` again without typing `senv`: none
of this exists there. That is the whole point — senv lives inside the
session, and only there.

## Next steps

- [Install and use a tool on demand](02-install-and-use-a-tool-on-demand.md)
- The exact activation sequence is described in
  [Anatomy of a session](../explanation/anatomy-of-a-session.md).
