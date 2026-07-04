# Give a project its own senv

In this tutorial you add a `senv.bat` to one of your projects, so that
opening a session in that project automatically selects the tool versions
the project needs — say JDK 17 and Node 20.

You need a working senv and the versions installed under `%PRGS%` (see
[Install and use a tool on demand](02-install-and-use-a-tool-on-demand.md)):

```cmd
div jdk 17
div node 20
```

## 1. How the entry point picks a project senv

`%USERPROFILE%\senv.bat` — what the `senv` alias calls — first looks for a
`senv.bat` in the **current directory**. If one exists, it calls that one
instead of the global activator. That is the whole hook: a project opts in
by shipping its own `senv.bat`.

## 2. Write the project senv.bat

In your project root (for example `%PROG%\git\myproject`), create
`senv.bat`:

```bat
@echo off
call "%USERPROFILE%\home_senv\bin\senv.bat"
call switchjdk 17
call switchnode 20
```

- line 2 runs the normal global activation (minimal PATH, variables,
  aliases),
- the `switch` lines then pin the versions this project needs.

Each `switch` call finds its versions at the conventional location
`%PRGS%\<tool>s\<prefix><version>` — here `%PRGS%\javas\jdk17` and
`%PRGS%\nodes\node20`. A tool installed elsewhere on the machine can be
reached through the same path via a junction, so the project never needs to
know real install locations.

## 3. Use it

Open a new `CMD` window in the project folder (or `cd` into it), then:

```cmd
senv
```

You should see the usual `senv activated` line, followed by the two switch
confirmations. Verify:

```cmd
java -version
node -v
echo %JAVA_HOME%
```

JDK 17 and Node 20, found through `%PRGS%`, in this session only.

## 4. Check the isolation

Open another `CMD` in a different folder and type `senv`: you get the plain
global session, without the project pins. Two sessions, two tool sets, same
laptop, nothing global changed.

## Next steps

- Commit `senv.bat` with the project, so every teammate with senv gets the
  same versions.
- If a version is missing on a teammate's machine, they install it with one
  `div` command — or the project `senv.bat` can set `SWITCHVER_DWL_INST=1`
  before the switches so missing versions are fetched on demand (see
  [Commands](../reference/commands.md)).
