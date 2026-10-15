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
if /I "%TUITP_ROLE%"=="claude" call claude
if /I "%TUITP_ROLE%"=="codex" call codex
exit /b %errorlevel%
