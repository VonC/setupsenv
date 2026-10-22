@echo off
rem No SETLOCAL: senv activation must persist in this interactive CMD.
rem Caller supplies validated paths and disables delayed expansion.
set "TUITP_PROJECT=%~1"
set "TUITP_ROLE=%~2"
if /I "%TUITP_ROLE%"=="claude" goto :initialize
if /I "%TUITP_ROLE%"=="codex" goto :initialize
if /I "%TUITP_ROLE%"=="cmd" goto :initialize
echo ERROR: Expected claude, codex or cmd.
exit /b 2
:initialize
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
rem An agent exiting in error within a minute failed its startup, as Codex
rem does when its just started app-server times out on a slow first network
rem call ("workspace routing discovery timed out"): start it again, 3 times
rem in all. A later failure or a normal exit leaves the pane at its prompt.
set "attempt=1"
:start_agent
call :seconds started
call %TUITP_ROLE%
set "code=%errorlevel%"
if "%code%"=="0" exit /b 0
call :seconds ended
set /a "elapsed=(ended - started + 86400) %% 86400"
if %elapsed% GEQ 60 exit /b %code%
if %attempt% GEQ 3 exit /b %code%
set /a "attempt+=1"
echo tuitp: %TUITP_ROLE% exited %code% after %elapsed%s while starting. Attempt %attempt% of 3 in 5s, Ctrl+C to stop.
ping -n 6 127.0.0.1 >nul
goto :start_agent

:seconds
rem Seconds since midnight, whether TIME reads " 8:05:09,12" or "08:05:09.12".
for /f "tokens=1-3 delims=:.," %%a in ("%TIME: =0%") do set /a "%~1=(1%%a - 100) * 3600 + (1%%b - 100) * 60 + 1%%c - 100"
exit /b 0
