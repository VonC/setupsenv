# How to find why senv is slow to start

<img src="../assets/logo-senv-terminal-transparent.png" alt="" height="90" align="right">

Goal: when `senv` takes seconds (or worse) before its final line, find the
step that spends the time, then remove, defer or fix it.

## Read the total

Every activation ends with its duration:

```text
 OK    : [senv.bat] senv activated in 0.67s: senv_dir='...'
```

That total is measured inside `senv.bat`, from its first line to its last
step. Starting `cmd.exe` and printing the final line add about 0.3s more to
what you see on screen. An activation usually completes in under a second.
Much more than that is worth the next section.

## Time each step

Set `SENV_TIMING` in the terminal, then activate again:

```cmd
set SENV_TIMING=1
senv
```

Each step now prints how long it took and the running total:

```text
[senv timing]   0.00s (total   0.00s) detect local senv
[senv timing]   0.03s (total   0.03s) batcolors macros
[senv timing]   0.03s (total   0.06s) senv.local.pre.bat
[senv timing]   0.10s (total   0.16s) base variables, npp alias, Go
[senv timing]   0.00s (total   0.16s) usernamel
[senv timing]   0.03s (total   0.19s) senv.custom.bat
[senv timing]   0.11s (total   0.30s) senv.local.bat
[senv timing]   0.05s (total   0.35s) senv.custom.profile.bat
[senv timing]   0.07s (total   0.42s) doskey senv.doskey
[senv timing]   0.08s (total   0.50s) doskey senv.custom.doskey
[senv timing]   0.07s (total   0.57s) doskey senv.local.doskey
[senv timing]   0.08s (total   0.65s) doskey senv.custom.profile.doskey
[senv timing]   0.02s (total   0.67s) end
 OK    : [senv.bat] senv activated in 0.67s: senv_dir='...'
```

A step that takes 0.5s or more ends with `[slow]`, and one that takes 2s or
more ends with `[REALLY SLOW]`. The [command reference](../reference/commands.md#timing-an-activation)
lists what each step covers. Printing and logging the steps happen after
the clock stops, so they do not change the numbers. Clear the variable with
`set SENV_TIMING=` when you are done.

## Catch a slow start in tabs opened together

A slowdown that appears only when many terminals start at once (a `wtp` or
`tuitp` layout, or Windows Terminal restoring its tabs) cannot be watched
tab by tab. Let every new terminal log its timing instead:

1. Set the variable for your user, so that every new terminal inherits it:

   ```cmd
   setx SENV_TIMING 1
   ```

2. Reproduce the slow start, for example by opening the layout again.

3. Read `%TEMP%\senv.timing.log`. Each activation appends a header line
   with its date and folder, then one line per step. Every line of one run
   starts with the same `#` id, the time the run started, so runs that
   overlapped can still be told apart:

   ```text
   #17:25:38,38 ==== 17/10/2026 senv.bat in C:\work\project-a
   #17:25:38,38   0.00s (total   0.00s) detect local senv
   ...
   ```

   To list only the slow steps of all runs:

   ```cmd
   findstr /I /C:"slow]" "%TEMP%\senv.timing.log"
   ```

4. Remove the variable and the log once you have your answer: the log
   grows with every activation and nothing trims it.

   ```cmd
   reg delete HKCU\Environment /v SENV_TIMING /f
   del "%TEMP%\senv.timing.log"
   ```

## Act on the slow step

- **`senv.custom.bat`, `senv.local.bat` or `senv.custom.profile.bat`**: a
  command in that layer starts a program (PowerShell, `where`, `git`, a
  network check) or reads a network share. Move it to an alias you run when
  needed, or guard it with `if not defined ...` so that it runs once per
  terminal instead of at every activation.
- **One `doskey ...` step**: one `doskey` call costs about 0.1s. A step
  that takes seconds most likely reads its macro file from a slow or
  sleeping network drive.
- **Every step slower than in the example**: on a workstation where an
  antivirus or endpoint protection agent inspects every file opening, each
  line of a batch file and each `call` costs a few milliseconds more, and
  each program start much more. The whole activation slows down in
  proportion to its length, as [anatomy of a session](../explanation/anatomy-of-a-session.md#what-an-activation-costs)
  explains.
- **A tool started by your layers takes seconds while using almost no
  CPU**: endpoint protection can hold an unsigned or rarely seen executable
  at launch while it checks its reputation online. Compare the elapsed time
  of `tool --version` with its CPU time in Task Manager. Only the team that
  manages the workstation can exempt the tool's path.

The first `ppath` or `switch*` command in a terminal also takes 1 to 2s
more than the next ones: it looks up the terminal's `SENV_UID`, once. That
cost is not part of the activation.

Related: [commands](../reference/commands.md),
[environment variables](../reference/environment-variables.md).
