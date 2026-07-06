# How to open project tabs in Windows Terminal

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

## Steps

1. Regenerate the launcher once, so it knows the two arguments, from the
   senv repository folder:

   ```cmd
   s
   ```

2. In Windows Terminal, open Settings, then "Open JSON file", and add one
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

3. Open the tabs together, either way:

   - in the same JSON, make Terminal start with both tabs:

     ```json
     "startupActions": "new-tab -p myproject ; new-tab -p otherproject"
     ```

   - or keep Terminal's startup as is, and pin a shortcut running:

     ```cmd
     wt -p myproject ; new-tab -p otherproject
     ```

## Check

Each tab prints `senv activated` (the global pass) followed by the project
switches (`switchjdk`, `switchnode`, ...). In any tab, `ppath java` shows
the version pinned by that tab's project, and a plain `cmd` window outside
Terminal still shows no senv at all.

## If tabs opened together fail

Tabs launched at the same time run their `switch*` commands concurrently.
Deployments older than the introduction of `SENV_UID` shared one set of
transient files between terminals, and one tab could delete a version list
another tab was still reading. The failing tab then shows, in sequence:

```txt
Impossible de trouver ...\switchver_list.tmp
 WARN  : [switchver.bat] Your ... version argument '...' was NOT found ...
 FATAL 3 : [switchver.bat] No ... version selected ...
```

even though the version is installed. If this appears,
[update senv](update-senv-and-diagnose-version-drift.md) so each terminal
gets its own files, then reopen the tabs. To recover a single failed tab
without reopening it, run `%USERPROFILE%\senv.bat all` in that tab.

Related: [give a project its own senv](../tutorials/03-give-a-project-its-own-senv.md),
[commands](../reference/commands.md).
