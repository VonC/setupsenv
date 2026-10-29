@echo off
rem No SETLOCAL: senv activation must persist in this interactive CMD.
rem Caller supplies validated paths and disables delayed expansion.
rem tuitp.pane.bat "folder" claude|codex|cmd [project|local-or-global] ["command"]
rem The command is what the agent starts with, such as its resume skill.
set "TUITP_PROJECT=%~1"
set "TUITP_ROLE=%~2"
if /I "%TUITP_ROLE%"=="claude" goto :initialize
if /I "%TUITP_ROLE%"=="codex" goto :initialize
if /I "%TUITP_ROLE%"=="cmd" goto :initialize
echo ERROR: Expected claude, codex or cmd.
exit /b 2
:initialize
rem A pane is a new console, but it inherits the SENV_UID of the console that
rem ran tuitp, through the TUIOS daemon. Only the global senv.bat clears it,
rem and a one-pane entry with its own senv.bat never runs that one: on
rem 2026-10-29, four panes shared one id, and so the switchver temp files, and
rem one of them got an empty PATH. senv_uid.bat looks this pane's id up again.
set "SENV_UID="
cd /d "%TUITP_PROJECT%" || exit /b 1
rem One-pane list entries prefer the project's activation when it exists.
if /I "%~3"=="local-or-global" goto :local_or_global
call "%USERPROFILE%\senv.bat" global
if errorlevel 1 exit /b %errorlevel%
cd /d "%TUITP_PROJECT%" || exit /b 1
if not exist "%TUITP_PROJECT%\senv.bat" goto :launch
call "%TUITP_PROJECT%\senv.bat"
if errorlevel 1 exit /b %errorlevel%
goto :launch
:local_or_global
if exist "%TUITP_PROJECT%\senv.bat" (
    call "%TUITP_PROJECT%\senv.bat"
) else (
    call "%USERPROFILE%\senv.bat" global
)
if errorlevel 1 exit /b %errorlevel%
:launch
if not defined PRGS set "PRGS=C:\Public\SOFTWARE"
set "PATH=%PRGS%\tuioss\current;%USERPROFILE%\.local\bin;%USERPROFILE%\.codex\packages\standalone\current\bin;%PATH%"
cd /d "%TUITP_PROJECT%" || exit /b 1
if /I "%TUITP_ROLE%"=="cmd" exit /b 0
rem senv is active: the retry counters below need not outlive this script.
setlocal
rem An agent exiting in error within 5 minutes failed its startup, as Codex
rem does when its just started app-server times out on a slow first network
rem call ("workspace routing discovery timed out"), more than a minute after
rem a cold start: start it again, 3 times in all. A later failure or a normal
rem exit leaves the pane at its prompt.
set "attempt=1"
rem tuitp writes TUIOS's Claude Code hooks to this file, so that only these
rem panes report their state: in the user's settings, each hook would start
rem tuios.exe in every Claude session.
set "agent=%TUITP_ROLE%"
if /I "%TUITP_ROLE%"=="claude" if exist "%LOCALAPPDATA%\tuitp\claude\settings.json" set agent=claude --settings "%LOCALAPPDATA%\tuitp\claude\settings.json"
rem Codex reads SSL_CERT_FILE: a certificate bundle that senv sets for other
rem tools breaks its TLS connections, and its shared app-server daemon keeps
rem the environment of the Codex that started it.
if /I "%TUITP_ROLE%"=="codex" set "SSL_CERT_FILE="
rem Passed again at each start, so that a retry still runs it.
set "start_with=%~4"
if defined start_with set agent=%agent% "%start_with%"
:start_agent
call :seconds started
call %agent%
set "code=%errorlevel%"
if "%code%"=="0" exit /b 0
call :seconds ended
set /a "elapsed=(ended - started + 86400) %% 86400"
set "left=tuitp: %TUITP_ROLE% exited %code% after %elapsed%s"
if %elapsed% GEQ 300 (echo %left%, past its startup: left at the prompt. & exit /b %code%)
if %attempt% GEQ 3 (echo %left%, start %attempt% of 3: left at the prompt. & exit /b %code%)
set /a "attempt+=1"
echo tuitp: %TUITP_ROLE% exited %code% after %elapsed%s while starting. Attempt %attempt% of 3 in 5s, Ctrl+C to stop.
ping -n 6 127.0.0.1 >nul
goto :start_agent

:seconds
rem Seconds since midnight, whether TIME reads " 8:05:09,12" or "08:05:09.12".
for /f "tokens=1-3 delims=:.," %%a in ("%TIME: =0%") do set /a "%~1=(1%%a - 100) * 3600 + (1%%b - 100) * 60 + 1%%c - 100"
exit /b 0
