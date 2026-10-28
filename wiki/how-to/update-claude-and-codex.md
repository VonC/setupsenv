# How to update Claude and Codex

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: update the Claude CLI, the Codex CLI and the Codex app-server daemon
in one command, without a question, then check that the daemon runs the
version of the CLI.

## 📋 Steps

1. Close or pause the Codex sessions whose work cannot wait: replacing the
   daemon package can interrupt them, and `codexu` does it without asking.
2. From a plain CMD tab, not from inside Claude or Codex, run:

   ```cmd
   aiup
   ```

   It checks Internet access, updates Claude, then runs `codexu` for Codex:
   the Codex CLI first, then the daemon package, copied from that CLI. It
   asks nothing: the Codex installer runs with `CODEX_NON_INTERACTIVE=1`,
   which also keeps it from starting Codex, and the daemon update gets
   `--yes`. A Claude that still runs is skipped, which is always the case
   from inside a Claude session: `aiup claude force` updates it anyway.

   For Codex alone, run `codexu`; for Claude alone, `aiup claude`.

3. Open a Codex session: it starts the daemon from the new package.

## ✅ Check

```cmd
codexu dry
```

```text
 INFO  : [codexu.bat] Codex CLI 0.165.0, daemon package 0.165.0, running daemon 0.165.0
```

The three versions match. `running daemon -` means that no daemon runs, no
Codex being open: the next Codex starts it from the daemon package, so a
daemon package at the CLI version is enough. `codexu` reads the CLI and
daemon package versions from their `codex-package.json`, and asks the
running daemon for its own.

## When Codex warns that a background service is older

A new Codex says "A background Codex service is running v0.162.1, older than
your Codex CLI" when the daemon did not follow a CLI update. Under senv, the
daemon cannot update itself (see [commands](../reference/commands.md#codexu-dry)):
run `codexu`, then check as above. A daemon package already at the CLI
version, with no older daemon running, is left alone.

## When codexu asks "Start Codex now?"

If `codexu` prints none of its own `INFO` and `TASK` lines, asks
"Start Codex now? [y/N]" or says "releases.openai.com is unavailable", a
doskey macro named `codexu` runs instead of `codexu.bat`, typically an old
alias that ran the installer alone. A macro wins over a script on `PATH`,
and reloading the aliases never deletes one (see
[remove or replace an alias](add-personal-alias-or-env-var.md#remove-or-replace-an-alias)).
Answer `N`, then either:

- run `codexu.bat`, which no macro shadows,
- delete the macro from the current console with `doskey codexu=`,
- or define the alias to call the script, as
  `codexu="%HOME%\bin\codexu.bat" $*` in `senv.local.doskey`, then run
  `aliasr`.

Related: [commands](../reference/commands.md#aiup-codex-claude-force-dry)
for every argument, [exit codes](../reference/exit-codes.md) for `aiup` and
`codexu` failures.
