# Changelog

<img src="../assets/logo-senv-transparent.png" alt="" height="90" align="right">

What changed in senv since the build on the team share. This page is
rewritten at each publication (see
[Build and publish a profile archive](../how-to/build-and-publish-a-profile-archive.md)):
it covers one step only, here from the build of 2026-10-05 (senv `ecf619e`)
to 2026-11-05. Once a build is published, `up` or `upa` brings it to your
machine (see
[Update senv and diagnose version drift](../how-to/update-senv-and-diagnose-version-drift.md)).
The changes of the private `custom` layer are in `custom\changelog.md`.

## 🆕 New commands

### `tuitp`: terminal layouts that survive a closed tab

`tuitp` opens the Windows Terminal tabs declared in `%HOME%\bin\tuitp.list`.
A TUIOS tab holds one or more TUIOS sessions, and a session keeps running
when its tab closes. Each run compares the list with what runs and changes
only the difference: running agents and shells stay as they are.

```text
=== my-project
+ %USERPROFILE%\git\my-project|my-project||web
+ %USERPROFILE%\git\my-project|my-project-cmd|senv
```

This list gives one tab, `my-project`, with two sessions: a project session
with Claude, Codex and a CMD, whose agent panes show as `Claude web` and
`Codex web` on the TUIOS rail, and a session with one senv CMD.

| Command | What it does |
| --- | --- |
| `tuitp dry` | preview: one `KEEP`, `OPEN`, `CREATE`, `RESTORE`, `ADD` or `RENAME` line per change, nothing changes |
| `tuitp` | apply the list |
| `tuitp stop my-project` | restart one session: delete it, then create it again with its panes |
| `tuitp stop` | close every tab and TUIOS session, then the TUIOS daemon, and the Codex daemon when no Codex runs elsewhere |
| `tuitp resume` | after a reboot: start each agent pane on the conversation it ran last |

What you get with it:

- An agent that fails at startup starts again. A Codex that exits with
  `workspace routing discovery timed out` within 5 minutes prints
  `Attempt 2 of 3 in 5s, Ctrl+C to stop.` and starts again, up to 3 times.
- No agent starts without Internet: `tuitp` runs `ei` first and stops before
  any change when the proxy does not answer.
- Claude panes show on the TUIOS rail and in its Inbox (idle, working,
  waiting for you, done), through hooks written to
  `%LOCALAPPDATA%\tuitp\claude\settings.json`. Other Claude sessions do not
  load them.
- A paused agent resumes by itself: when the folder holds a resume prompt
  left by an llm-shared pause, the agent that paused it gets
  `resume-session`, typed once Claude waits at its prompt, or as the start
  command of Codex.
- A click on an agent of another session, on the TUIOS rail, brings forward
  the tab of that session instead of showing it in the current tab.
- Each pane activates senv on its own: the global aliases, then the folder's
  `senv.bat` with its own venv, and its own `SENV_UID`.
- `set TUITP_TIMING=1` before `tuitp` prints how long each `tuios` call took.
- `dwl tuios` then `inst tuios` install the latest TUIOS.

With no `tuitp.list` yet, the first run after the update writes one from
the layout of the original hard-coded `tuitp`, kept in
`%HOME%\bin\tuitp-legacy`. See
[Manage TUIOS terminal layouts](../how-to/manage-tuios-terminal-layouts.md).

### `lsc`: paste a screenshot into an agent prompt

Claude Code turns a quoted image path pasted in its prompt into an
attachment. `lsc` puts that quoted path on the clipboard.

| Command | What you get |
| --- | --- |
| `lsc` | the newest screenshot, as `"C:\Users\you\Pictures\Screenshots\Screenshot 2026-11-05 091512.png"` |
| `lsc 3` | the 3 newest, oldest first, separated by a space |
| `lsc watch` | a tray icon: after each `Win+Shift+S` snip, the clipboard holds the image and its quoted path |
| `lsc stop`, `lsc status` | end the tray watcher, or tell whether it runs |

The folder comes from `lsc.custom.ini`, for a machine where OneDrive moves
the screenshots, else from the Windows Screenshots folder. See the
[command reference](commands.md#-screenshots).

### `aiup` and `codexu`: update Claude and Codex in one command

`aiup` checks Internet access, updates the Claude CLI, then runs `codexu`,
without a single question. `codexu` updates the Codex CLI through the
proxy, then the Codex app-server daemon that every Codex session connects
to. Under senv, that daemon could not update itself, and each new Codex
warned "A background Codex service is running v0.162.1, older than your
Codex CLI".

```text
codexu dry
 INFO  : [codexu.bat] Codex CLI 0.166.0, daemon package 0.166.0, running daemon 0.166.0
```

`codexu` also removes the old Codex versions, about 450 MB each, keeping
the 2 newest and any version a running Codex still uses: on a machine
updated since July, the first run removed 26 versions and freed 10 GB.
`codexu prune` does only that cleanup. See
[Update Claude and Codex](../how-to/update-claude-and-codex.md).

### `ghwatched`: the repositories you watch for releases or alerts

GitHub lists in its API only the repositories watched for "All activity".
`ghwatched` finds the starred ones watched with a custom setting, such as
releases only or security alerts:

```text
ghwatched                 every one, as owner/name | topics | description
ghwatched @security       only those about security (shipped word list)
ghwatched -Names =go      the whole word "go", names only
```

See
[Find the GitHub repositories you watch](../how-to/find-custom-watched-github-repositories.md).

### `sshagent`: sign commits with an SSH key, no admin rights

`sshagent load` starts or reuses a per-user `ssh-agent` and loads the key
named in `%LOCALAPPDATA%\senv\ssh-agent.local.json`: the next Git commands
of that console sign with it. With a `<privateKey>.passphrase` file beside
the key, no prompt is shown; `sshagent` refuses that file inside a Git
working tree that does not ignore it. `sshagent status` only reports. See
[Use an SSH agent](../how-to/use-ssh-agent.md).

### Vulnerability scanners: `dwl trivy`, `dwl grype`

Both install like any program, then scan a project's lock file, as
GitHub's Dependabot alerts do:

```cmd
dwl grype
inst grype
cd /d %USERPROFILE%\git\my-project
"%PRGS%\grypes\current\grype.exe" file:uv.lock
```

A clean project prints `No vulnerabilities found`. Behind a proxy that
blocks container registries, Trivy cannot download its database
(`403 Forbidden`): use Grype, whose database comes from a plain HTTPS site.
See [Scan dependencies for vulnerabilities](../how-to/scan-dependencies-for-vulnerabilities.md).

### `tct N` and `tc yyyyMMdd`: older Teams chats

`tct 2` copies the cached Teams chats of 2 days ago, and `tc 20261017` is
the same as `tc 2026-10-17`. Alone, `tct` still copies today's chats.

### `vsc`: a workspace created when missing

In a project whose `.vscode` folder holds no `.code-workspace` file, `vsc`
used to stop with "workspace file not found". It now creates
`.vscode\my-project.code-workspace` with `{"folders": [{"path": ".."}]}`, no
absolute path inside, and fills a selected workspace file that is empty.

## ⚡ Faster activation

- An activation took 3.3 seconds and now takes about 0.7. `SENV_UID`, the
  id that `ppath` and the `switch*` commands give their temp files, cost 1.5
  to 2.5 seconds at each activation: it is now looked up by the first
  command that needs it.
- The final activation message gives its time. `set SENV_TIMING=1` then
  `senv` prints each step, flags the slow ones with `[slow]` or
  `[REALLY SLOW]`, and logs them to `%TEMP%\senv.timing.log`. See
  [Find why senv is slow to start](../how-to/find-why-senv-is-slow-to-start.md).

## 🐞 Fixes

- Aliases in project consoles: a console where only a project `senv.bat`
  ran answered `'ll' is not recognized`. `%USERPROFILE%\senv.bat` now loads
  the global, team and personal aliases before the project `senv.bat`, whose
  own aliases still win, and `senv aliases` loads them in the current
  console.
- `inst <program>` takes the highest version, not the newest download:
  with `tuios_0.10.0` downloaded 18 seconds after `0.10.1`, `inst tuios`
  installed 0.10.0. It now installs 0.10.1.
- `ctc` keeps each Teams message once. Five copies of one chat used to save
  3560 lines, most messages up to four times; they now give 196 messages in
  1354 lines, none lost. A message copied again with new reactions replaces
  the stored one.
- Reconnecting a share drive waits 5 seconds without needing a console:
  `adm\build_all.bat`, run from a script, no longer stops every profile build
  with `FATAL 118` when a drive needs reconnecting.

## 📚 New documentation

- How-to:
  [Manage TUIOS terminal layouts](../how-to/manage-tuios-terminal-layouts.md),
  [Update Claude and Codex](../how-to/update-claude-and-codex.md),
  [Use an SSH agent](../how-to/use-ssh-agent.md),
  [Scan dependencies for vulnerabilities](../how-to/scan-dependencies-for-vulnerabilities.md),
  [Find the GitHub repositories you watch](../how-to/find-custom-watched-github-repositories.md),
  [Find why senv is slow to start](../how-to/find-why-senv-is-slow-to-start.md).
- Explanation:
  [Why tuitp types resume commands with ask-agent](../explanation/why-tuitp-types-resume-commands-with-ask-agent.md),
  [Why ghwatched looks among your stars](../explanation/why-ghwatched-looks-among-your-stars.md).
