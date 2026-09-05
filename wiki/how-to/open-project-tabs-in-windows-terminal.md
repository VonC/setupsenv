# How to open project tabs in Windows Terminal

<img src="../assets/logo-senv-terminal-transparent.png" alt="" height="90" align="right">

Goal: a Windows Terminal layout where each tab opens on one project, with
the **global** senv applied first and the **project** `senv.bat` applied on
top, instead of the default behavior where a project `senv.bat` replaces
the global activation.

The launcher `%USERPROFILE%\senv.bat` takes two optional arguments:

- `senv global`: always run the global activation, even if the current
  folder has its own `senv.bat`,
- `senv all`: run the global activation, **then** the project `senv.bat`
  of the current folder if there is one.

A project `senv.bat` that already calls the global activator itself (the
pattern of [the project tutorial](../tutorials/03-give-a-project-its-own-senv.md))
also works with `all`: the global part simply runs twice, which is
harmless.

`wtp` opens that layout in one command. The Terminal profiles further down
are the manual equivalent, still useful when Terminal itself has to start
the tabs at login.

## 📋 Steps with `wtp`

1. Regenerate the launcher once, so it knows the two arguments, from the
   senv repository folder:

   ```cmd
   s
   ```

2. Write the list of tabs. `wtp.list.example`, installed next to `wtp.bat`,
   is the pattern to copy:

   ```cmd
   copy %HOME%\bin\wtp.list.example %HOME%\bin\wtp.list
   ```

   Then edit `%HOME%\bin\wtp.list`: one project folder per line, in tab
   order.

   ```text
   --- main

   C:\Users\me\git\myproject
   C:\Users\me\git\myproject
   C:\Users\me\git\myproject|myproject

   --- side

   C:\Users\me\git\otherproject|otherproject
   ```

   | Line | Meaning |
   | --- | --- |
   | `<folder>` | one tab on that folder, title left to whatever runs in it |
   | `<folder>\|<title>` | the same tab, with its title pinned |
   | `--- <name>` | close the window gathered so far, open a new one called `<name>` |
   | `# ...` or blank | ignored |

   The same folder can be listed several times, once per tab wanted on it.
   A line with no title lets a tool that names its own tab keep control of
   it.

3. Check what would open, then open it:

   ```cmd
   wtp dry
   wtp
   ```

Running `wtp` a second time opens nothing. Each tab is started as
`cmd.exe /k wtp.tab.bat <slot>`, so `wtp` reads the command line of every
live `cmd.exe` and skips the slots that answer. Close one tab by hand and
the next `wtp` brings it back, in the window its block names. `wtp force`
reopens everything regardless.

Two pieces sit outside `wtp.bat` itself:

- `WTP_PROFILE` names the Windows Terminal profile the tabs open with.
  `senv.bat` sets it to `senv`, the profile the senv install creates and makes
  the default, so the whole layout shares one font and one set of colours out
  of the box. Only the look is taken: `wtp` passes its own command line and
  its own folder. Override it in `senv.custom.bat` for a team or in
  `senv.local.bat` for one machine, both read after `senv.bat`, and empty it
  to fall back to the Windows Terminal default profile.
- a `startup.bat` next to `wtp.bat` gets a tab of its own in the current
  window, for whatever has to run once per session. It ships with no such
  file, so that tab appears only once you add one. `wtp nostartup` skips it,
  `wtp notabs` opens only it.

Without a `wtp.list`, `wtp` says what the file is for, points at the
example, and exits 0.

## 📋 Steps with Terminal profiles only

1. In Windows Terminal, open Settings, then "Open JSON file", and add one
   profile per project:

   ```json
   {
     "name": "myproject",
     "commandline": "cmd.exe /k call %USERPROFILE%\\senv.bat all",
     "startingDirectory": "C:\\Users\\me\\git\\myproject"
   },
   {
     "name": "otherproject",
     "commandline": "cmd.exe /k call %USERPROFILE%\\senv.bat all",
     "startingDirectory": "C:\\Users\\me\\git\\otherproject"
   }
   ```

2. Open the tabs together, either way:

   - in the same JSON, make Terminal start with both tabs:

     ```json
     "startupActions": "new-tab -p myproject ; new-tab -p otherproject"
     ```

   - or keep Terminal's startup as is, and pin a shortcut running:

     ```cmd
     wt -p myproject ; new-tab -p otherproject
     ```

## ✅ Check

Each tab prints `senv activated` (the global pass) followed by the project
switches (`switchjdk`, `switchnode`, ...). In any tab, `ppath java` shows
the version pinned by that tab's project, and a plain `cmd` window outside
Terminal still shows no senv at all.

## If tabs opened together fail

Tabs launched at the same time run their `switch*` commands concurrently.
Those commands work through transient files kept apart by `SENV_UID`, the
PID of the terminal holding the tab. Where that id ends up shared between
tabs, one tab deletes a version list another tab is still reading, and the
tab that lost the race shows, in sequence:

```txt
FINDSTR: Cannot open ...\switchver_<id>_list.tmp
 WARN  : [switchver.bat] Your ... version argument '...' was NOT found ...
 FATAL 3 : [switchver.bat] No ... version selected ...
```

even though the version is installed. Two things put tabs on the same id,
and both are fixed in `bin\senv.bat`. The id was kept whenever the variable
was already set, and an environment variable is inherited, so every tab
opened from an activated terminal carried the id of that terminal: a batch
of tabs opened by one command all shared it. The lookup that computed the
id was wrong too, returning the PID of the throwaway `cmd.exe` that
`for /f` spawns to run its command rather than the PID of the terminal.

If this appears, [update senv](update-senv-and-diagnose-version-drift.md)
so every terminal computes its own id, then reopen the tabs. To recover a
single failed tab without reopening it, run `%USERPROFILE%\senv.bat all` in
that tab.

A version named on the command line, such as the one a project pins for
itself, no longer depends on that list at all: `switchver` takes it as soon
as its folder is there, without listing anything.

Related: [give a project its own senv](../tutorials/03-give-a-project-its-own-senv.md),
[commands](../reference/commands.md).
