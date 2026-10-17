@echo off
rem senv_uid: sets SENV_UID, an id unique per console, so that concurrent tabs never
rem share the same switch* or ppath temp files. senv.bat only clears it: a console
rem inherits SENV_UID from the console that opened it, so a batch of tabs opened at
rem once all carried one id, and one tab deleted the temp file another one was
rem still reading. %RANDOM% is no better on its own: tabs opened by one command
rem start the same second and can draw identical values. The id is the console PID.
rem
rem The lookup is left to the first script that needs a temp file: it costs 1.5 to
rem 2.5s (powershell plus WMI), and when senv.bat made it, it was 70% of every senv
rem run, in every tab, needed or not. Call this before any setlocal, so that the id
rem stays in the console and the next scripts reuse it.
rem
rem The lookup climbs two levels: for /f runs its command through a throwaway
rem cmd.exe of its own, so the parent of the powershell process is that helper and
rem the grandparent is the console. [wmi] gets each process by its key, about a
rem second faster than two Get-CimInstance queries.
if defined SENV_UID goto:eof
for /f "usebackq delims=" %%p in (`powershell -NoProfile -Command "$h=([wmi]('Win32_Process.Handle=''' + $PID + '''')).ParentProcessId; ([wmi]('Win32_Process.Handle=''' + $h + '''')).ParentProcessId"`) do set "SENV_UID=%%p"
if not defined SENV_UID set "SENV_UID=%RANDOM%%RANDOM%"
