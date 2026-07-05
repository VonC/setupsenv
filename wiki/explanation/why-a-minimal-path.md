# Why a minimal PATH

Every senv session starts by throwing the inherited `PATH` away. The first
thing `bin\senv.bat` does after loading its color macros is:

```bat
set PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\
```

Four entries, the bare minimum for `cmd.exe`, the standard Windows tools and
PowerShell, and nothing else. Everything the session needs is then added
deliberately, entry by entry: `%HOME%\bin` (the senv scripts), the portable
Git (which also brings `grep`, `awk`, `sed`, `curl` and `bash`), and whatever
each `switchxxx` call decides to add later. This page explains why senv is
built on that reset rather than on the more common "append to the user PATH"
approach.

## The problem with the inherited PATH

On a corporate laptop, the system and user `PATH` values are a shared,
unmanaged resource. Installers append to them, IT policies rewrite them,
agents and antivirus tools inject their folders, and none of it is under the
developer's control, especially without admin rights. Starting a dev shell
on top of that inheritance means:

- **unpredictability**: the same command may resolve to different binaries on
  two laptops, or on the same laptop before and after an IT update,
- **shadowing**: a stray `python.exe` or `git.exe` earlier in the PATH wins
  over the version the project needs, and the failure is silent,
- **fragility**: a broken or slow network entry in the system PATH slows down
  or breaks every command lookup in every shell.

A locked-down environment makes this worse: the user cannot clean the system
PATH, so the only reliable move is to stop depending on it.

## What the reset buys

- **Reproducibility.** Two people running the same senv profile get the same
  resolution order, because the order is written in scripts under version
  control, not accumulated on a machine over the years.
- **Isolation both ways.** Nothing from the host leaks into the session, and
  nothing from the session leaks out. `senv` never writes the machine or user
  PATH; closing the terminal restores the laptop exactly as it was. The
  session is the unit of configuration, not the machine.
- **Debuggability.** When a command misbehaves, the PATH is short enough to
  read. The `ppath` command prints it entry by entry and flags folders that
  do not exist: practical only because the list stays small and intentional.
- **Deliberate versions.** Since no tool is on the PATH by accident, adding
  one is an explicit act: `switchjdk 21` for this session, a project
  `senv.bat` for that repository. See
  [junctions-as-a-contract](junctions-as-a-contract.md) for how the tools are
  laid out so those additions stay uniform.

## The trade-off

The reset has a cost, accepted on purpose:

- tools installed outside senv are invisible until referenced through the
  `%PRGS%` convention (a junction makes them visible again, see
  [../how-to/reference-an-already-installed-tool.md](../how-to/reference-an-already-installed-tool.md)),
- each new tool needs a small amount of wiring (an entry in `prgs.list`, a
  `switchxxx` call or a doskey alias) instead of "just working" because some
  installer edited the global PATH.

That friction is the feature: every entry on the PATH has an owner and a
reason, which is exactly what a contractor needs when the rest of the machine
is out of their hands.

## Where to look next

- [anatomy-of-a-session.md](anatomy-of-a-session.md) for the full activation
  sequence around the PATH reset.
- [../reference/environment-variables.md](../reference/environment-variables.md)
  for the variables set alongside the PATH.
