# From zero on a team laptop

In this tutorial you set up senv on a locked-down corporate laptop, as a
contractor joining a team that already publishes a senv profile on a network
share. No admin rights, no clone from the internet: everything comes from
the share.

You need: the path of your team's setups share (ask your team admin), for
example `\\server\share\teamtools\senv`.

## 1. Run the bootstrap from the share

Open a `CMD` window and run the `s.bat` published next to the team archive:

```cmd
\\server\share\teamtools\senv\s.bat
```

This bootstrap:

- compares the published version with what is on your machine (nothing, the
  first time),
- copies the self-extracting archive `senv_<profile>-zip.exe` locally and
  uncompresses it into your programs folder (`PRGS`), giving you the full
  senv tree with the team's `custom\` configuration and profile already in
  place,
- chains into `setup.bat`, which installs the base tools plus every
  application of the team list `install_<profile>.list`.

Answer the folder confirmation if prompted (defaults are usually right). The
run ends with `You are good to go!`.

## 2. Open your first session

Open a **new** `CMD` window and type:

```cmd
senv
```

You should see `senv activated: ...`. Everything the team defined is there:

```cmd
alias        &:: team aliases are loaded on top of the global ones
ppath        &:: the PATH only contains senv-managed entries
git --version
```

Close the window: the laptop is unchanged outside the session.

Your first clone follows the two senv habits: `cdg` to reach the common
clone home (`%PROG%\git`), then `gcu` inside the fresh clone to register
your name and email there — senv sets no global Git identity, precisely so
a professional email can never end up in the wrong repository (see
[git configuration](../reference/git-configuration.md)):

```cmd
cdg
git clone https://server.example.corp/team/myrepo
cd myrepo
gcu
```

## 3. Update when the team publishes a new version

Later, from inside any session, one alias refreshes your environment from
the share:

```cmd
up
```

- `up` — re-runs setup for your profile,
- `upg` — quick variant, refreshes Git and configuration only,
- `upa` — full variant, refreshes everything.

Your personal files (`senv.local.*` in `%HOME%\bin`: your aliases, your
variables) are never overwritten by an update.

To know whether an update is needed at all:

```cmd
profile
```

It compares your local senv and custom versions with the published ones and
tells you which command to run.

## Next steps

- [Install and use a tool on demand](02-install-and-use-a-tool-on-demand.md)
  when you need a tool or a version outside the team list.
- [Add a personal alias or environment variable](../how-to/add-personal-alias-or-env-var.md).
- How the archive is built and published, on the admin side:
  [Distribution model](../explanation/distribution-model.md).
