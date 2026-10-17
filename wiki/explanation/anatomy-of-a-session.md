# Anatomy of a session

<img src="../assets/logo-senv-terminal-transparent.png" alt="" height="90" align="right">

Two scripts define senv: `setup.bat`, run occasionally to build or refresh
the environment, and `bin\senv.bat`, run at every terminal to activate it.
This page walks through both flows to explain *why* each stage exists; the
exact commands and options belong to the reference and how-to pages.

## setup.bat: building the environment

**Profile detection comes first** because everything downstream, which
tools to install, which share to read, which aliases to keep, depends on
it. The profile is read from `custom\profile`, or forced with a leading
`_<profile>` argument for machines serving several teams.

**`custom\setup.ini.bat` is called next** to establish the three anchor
locations: `PRGS` (programs), `HOME` (the senv home) and `PROG` (work
data), plus optionally `REMOTE_HOME`. These are the only questions senv
ever asks about the machine; if `custom\` does not exist yet, it is seeded
from `custom_example\` so there is always a place to answer them.

**The entry point is rendered, not written by hand.**
`senv.user_profile.tpl.bat` becomes `%USERPROFILE%\senv.bat` with the real
`HOME` substituted in. This tiny launcher holds the per-project trick: if
the current directory has its own `senv.bat`, that one runs instead of the
global one. Two arguments bend that rule when the default replacement is
not what a caller wants: `global` ignores the current folder, and `all`
runs the global activation first, then the project one on top: the mode a
Windows Terminal project tab uses. Keeping the launcher generated means a
HOME migration only has to patch one file.

**`bin\*` is copied into `%HOME%\bin`, and `*.custom.*` files follow.**
The session never runs scripts out of the repository; it runs the copies in
HOME. That makes the environment self-contained (HOME can be a Git
repository, backed up and restored as a unit) and lets one machine keep the
repository and the live environment at different revisions. Files of other
profiles are pruned at this point.

**Some results travel through tiny generated scripts.** A batch script
running under `setlocal` loses its variables at `endlocal`, so a result
that must cross that boundary is handed off twice: once through the
`endlocal & set` idiom, and once through a generated two-line batch the
caller can `call` from any context. The drive detection
([why it exists](why-drive-detection.md)) does exactly that: it writes the
found letter into `custom\driverLetter.bat`, which the share resolver
calls and deletes seconds later. Such files are transient by
design and gitignored. The
[generated-files reference](../reference/naming-conventions.md#generated-and-transient-files)
inventories them, so a stray appearance is recognized instead of
committed.

**Local files are created once, never overwritten.** The four `*.local.*`
files are seeded only if absent: the structural guarantee that updates
never destroy personal settings (see
[configuration-layers.md](configuration-layers.md)).

**The install loop runs last**: a bootstrap sequence (7-Zip first, since
everything else is an archive; then Git, since its `usr\bin` provides the
Unix tools the other scripts use; then the base comfort tools), followed by
the profile's `install_<profile>.list`. Each tool goes through the same
stations (find the newest matching archive, copy, uncompress, junction)
with optional `pre`/`install`/`post` hooks looked up in `installs\`, then
`custom\`, so corporate steps slot in without touching public code.

Setup ends by calling `senv.bat`: building and activating are separate
concerns, but a fresh setup should leave the user in a working session.

## senv.bat: activating a session

**Local-mode detection** runs first: when senv is executed from a working
repository clone (the `adm\` folder is present), the maintainer paths and
aliases are added. A deployed user never sees this branch.

**The PATH reset** follows: four bare Windows entries, nothing inherited.
The reasons are covered in [why-a-minimal-path.md](why-a-minimal-path.md).

**A session id, `SENV_UID`, is cleared at every activation and looked up
on first use**: the PID of the terminal's own `cmd.exe`. Its only job is
isolation. The `switch*`
commands work through small transient files (piping console programs
directly can leave them suspended, so lists are written to disk and read
back), and a fixed file name would be shared by every terminal: a second
tab opened at the same moment could delete a list the first tab was still
reading, and the first tab would conclude the requested version does not
exist. A PID is used rather than `%RANDOM%` because tabs launched by one
command start within the same second and can draw identical random
values.

It is cleared rather than kept, because an environment variable crosses
process boundaries: a terminal opened from an activated one inherits its
`SENV_UID`, and a batch of tabs opened by a single command all carry the
id of the terminal that opened them, the very collision the id exists to
prevent.

The lookup itself is left to `senv_uid.bat`, which the first `switch*` or
`ppath` command of a terminal calls before its `setlocal`, so that the id
stays in the terminal for the next commands. The lookup starts
`powershell` and queries WMI twice, 1 to 2s. When the activation made it,
it was most of every activation, paid in every tab whether or not that tab
ever switched a version. It climbs two process levels, because `for /f`
runs its command through a throwaway `cmd.exe` of its own: the parent of
the `powershell` process is that helper, whose PID is freed as soon as it
returns, and the grandparent is the terminal.

**`senv.local.pre.bat` loads before anything else** because it answers the
question every later line depends on: where are `PRGS`, `HOME` and `PROG`
on this machine? Activation fails loudly if the file is missing: a session
with guessed locations would misbehave in quieter, worse ways.

**Git goes on the PATH first among tools.** The portable Git also supplies
`grep`, `awk`, `sed`, `curl` and `bash`, which the rest of the scripts rely
on; putting `%HOME%\bin` ahead of it keeps senv's own commands first in
resolution order.

**Environment variables** come next: locale, editor, downloads folder,
7-Zip, language homes, always derived from the `%PRGS%` convention rather
than from machine state, so two laptops with the same profile produce the
same session.

**The configuration chain** then sources team, personal and profile
scripts, and the **four doskey layers** load in the same order. Ordering is
precedence; the details and the reasons are in
[configuration-layers.md](configuration-layers.md).

The end state prints one line, `senv activated in 0.67s`, and that is the
whole visible footprint: no registry writes, no machine PATH edits, nothing
that outlives the terminal window.

## What an activation costs

An activation takes well under a second, and most of it goes to starting
programs. A batch built-in such as `set`, `if` or a `for` over a list costs
a millisecond or less. Starting a program costs about a tenth of a second
for a small one such as `doskey.exe` or `where.exe`, and over a second for
`powershell`. `senv.bat` therefore lets `cmd` do the work itself wherever it
can: `%%~$PATH:i` searches the `PATH` in place of `where`, and the `npp`
alias is defined by a single `doskey` call. The four alias layers remain
four `doskey` starts, nearly half of the total, because
`doskey /macrofile` reads one file per call.

On a workstation where an antivirus or endpoint protection agent inspects
every file opening, the cheap operations stop being cheap. On one such
machine, each executed batch line cost about 2ms, each `call` about 20ms,
and each append to a file about 30ms. A batch script then slows down in
proportion to the lines it runs. That is why each timing mark in
`senv.bat` is a single `set` line that adds `%TIME%` and a label to one
variable, while the arithmetic, the printing and the log wait for the end:
a mark that called a subroutine or wrote to a file would cost more than
many of the steps it measures.

The total is printed at every activation, not only when `SENV_TIMING`
asks for the details, so that a slow start is noticed on the day it
appears rather than after it has become normal.
[find-why-senv-is-slow-to-start.md](../how-to/find-why-senv-is-slow-to-start.md)
shows how to find the step responsible.

## 👉 Where to look next

- [../reference/commands.md](../reference/commands.md) for every command
  available once the session is active.
- [../how-to/update-senv-and-diagnose-version-drift.md](../how-to/update-senv-and-diagnose-version-drift.md) for refreshing an
  existing environment instead of rebuilding it.
