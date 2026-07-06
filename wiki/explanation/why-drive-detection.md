# Why senv detects and wakes network drives

<img src="../assets/logo-senv-transparent.png" alt="" height="90" align="right">

On a corporate laptop, the team shares live on mapped network drives:
`L:`, `W:`, `U:`. Those mappings have a failure mode every Windows user
knows by sight: the **red cross** on the drive icon. After a login, a
resume from sleep, or a VPN reconnection, the drive is still *mapped* but
marked disconnected. Command-line access fails, `dir L:` errors out,
while the underlying UNC path often answers perfectly well.

The classic remedy is manual: open the Explorer, click the crossed drive,
and the click makes Windows re-establish the SMB session. That gesture is
exactly what an unattended `setup.bat` or `up` run cannot ask for, and
those runs are precisely the ones that need the drive, since the team
share holds the tool archives and the senv self-extracting archive.

`installs\drive_detection.bat` exists to perform that human gesture
without a human.

## What it actually does

1. **Find the mapping.** It parses the `net use` table for the wanted UNC
   path. Three outcomes: the path is mapped and `OK`; mapped but flagged
   unavailable (the red cross, seen as a `Non`/`Unavailable` status or a
   blank one); or not mapped at all.
2. **Map when missing.** With no mapping, it first checks the UNC path
   itself answers, then maps a free letter with `net use *`.
3. **Reproduce the click when crossed.** For a mapped-but-disconnected
   drive, it does what the user would do: it opens the Explorer on the
   drive: `start /min explorer.exe L:`. A real, minimized Explorer window
   appears for a few seconds; its browsing is what wakes the SMB session.
   The script snapshots the `explorer.exe` process list before, waits five
   seconds, then kills **only the window it spawned**, leaving any Explorer
   the user had open untouched. A final `dir` proves the drive answers.
4. **Hand the letter back.** The result returns through the
   `endlocal & set` idiom plus the transient `custom\driverLetter.bat`
   (see [anatomy of a session](anatomy-of-a-session.md)).

So when a setup log shows a minimized Explorer window flashing in the
taskbar, that is not a glitch: it is the red-cross click, automated.

## Why not just use the UNC path everywhere

The drive letter is not cosmetic. The corporate shares behind
`setupsdir_<profile>.bat` are reached faster and more reliably through
their established drive session than through fresh UNC connections, some
tooling on the shares expects drive-letter paths, and the `cdis` alias
gives users a one-word jump to the setups folder: a letter is what they
know. The resolver therefore prefers the drive letter and only falls back
to the raw UNC path when no letter can be obtained.

## A note on `wmic`

The spawn-and-kill bookkeeping used to identify the new Explorer window
with `wmic`, which Microsoft removed from Windows 11 24H2 and later. On
those machines the refresh branch printed `'wmic' n'est pas reconnu` and
left its minimized Explorer window open instead of cleaning it up. The
scripts now enumerate PIDs with `tasklist`, which exists on Windows 10
and Windows 11 alike, so a single code path serves both and no version
detection is needed. The same removal is why `wildfly.bat` reads process
command lines through a PowerShell `Get-CimInstance` query rather than
`wmic`.

Related: [distribution model](distribution-model.md) for what the shares
carry, [naming conventions](../reference/naming-conventions.md#generated-and-transient-files)
for the transient `driverLetter.bat`.
