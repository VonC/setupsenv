# How to add a personal alias or environment variable

Goal: customize your sessions (PATH additions, variables, doskey aliases)
in a way that no senv update ever overwrites.

## Where personal settings live

Setup creates four files in `%HOME%\bin` **only if they do not exist yet**,
and never touches them again — this is what makes them update-proof:

- `senv.local.pre.bat` — sourced first; holds the authoritative `PRGS`,
  `HOME`, `PROG`, `REMOTE_HOME`. Add early settings here only.
- `senv.local.bat` — sourced after the team `senv.custom.bat`; your
  variables and PATH additions. Personal settings win over team settings.
- `senv.local.doskey` — loaded after the global and team doskey layers;
  your aliases. Setup only re-manages two lines in it: `cdi` and `cdis`.
- `gsenv.local.bat` — run by `gsenv` before starting the editor.

Everything else in `%HOME%\bin` is overwritten on each `s` / `setup.bat` run.

Two edit aliases drive the whole loop, each with its own reload:

- `senve` — open `senv.local.bat` (your variables) in VSCode; a variable
  change needs a full `senv` to be reloaded in the current session,
- `aliase` — open `senv.local.doskey` (your aliases) in VSCode; an alias
  change only needs `aliasr`, which reloads the doskey layers alone.

## Steps

1. Add a variable or PATH entry — type `senve` and edit
   `%HOME%\bin\senv.local.bat`:

   ```bat
   set "MY_TOOL_HOME=%PRGS%\mytools\current"
   set "PATH=%MY_TOOL_HOME%\bin;%PATH%"
   ```

2. Add an alias — type `aliase` and append to
   `%HOME%\bin\senv.local.doskey`:

   ```text
   cdp=cd /d %PROG%\git\myproject
   ll=lsd -al $*
   ```

   `cdp` is the customary name for "my current project", ideally under the
   `cdg` clone home (`%PROG%\git`) — nothing enforces it, but one common
   root keeps every repository findable.

3. Reload without reopening the terminal:

   - after `aliase`: `aliasr` reloads the three doskey layers, nothing else,
   - after `senve`: `senv` re-runs the whole activation, variables included.

## Check

`alias cdp` shows the new macro; `echo %MY_TOOL_HOME%` shows the variable.
Run `s`, open a new session: both are still there.

Related: [doskey aliases](../reference/doskey-aliases.md),
[the four configuration layers](../explanation/configuration-layers.md).
