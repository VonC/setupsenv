@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\..\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(publish)='%script_dir%'"

cd ../custom || %_fatal% "Unable to access custom folder" 1
for /F "delims=" %%f in ('pwd') do ( set cpwd=%%f )
%_info% "Custom folder full path: '%cpwd%'"

dir ..\..\setup > NUL
if errorlevel 1 (
    %_fatal%  "../../setup unavailable" 3
)

dir ..\..\dl > NUL
if errorlevel 1 (
    %_fatal%  "../../dl unavailable (should symlink to C:\%USERNAME%\Downloads)" 5
)

if "%1"=="" (
    %_fatal%  "Usage: publish xxx (profile whose list is to be published)" 4
)

set "profile=%1"
set "fprofile=install_%profile%.list"
if not exist "%fprofile%" (
    %_fatal%  "'%fprofile%' does not exist (list of tools to install for profile '%profile%')" 44
)

set "spath="
set "fsetupsdir=setupsdir_%profile%.bat"
set "UNCPathOnly=1"
call "%fsetupsdir%"
set "UNCPathOnly="
set "spath=!setupsdir!"
if "%spath%"=="" (
    %_fatal% "No target spath found in '%fsetupsdir%'" 111
)
%_info% "Target path spath: '%spath%'"

call:publishOne "peazip_portable-"
call:publishOne "PortableGit"
call:publishOne "gitcred"
call:publishOne "VSCode"
call:publishOne "ZoomIt-"
call:publishOne "ProcessExplorer-"
call:publishOne "px-"
call:publishOne "putty-"
call:publishOne "shellcheck-"
call:publishOne "WinSCP-"
call:publishOne "MobaXterm"
call:publishOne "node-v10."
call:publishOne "node-v14."
endlocal
goto:eof

:publishOne
set "pattern=%1"

set "fname="
for /F "delims=" %%f in ('dir /OD /b ..\..\setup^|findstr %pattern%^|tail -1') do ( set fname=%%f)
%_info% "fname: '%fname%'"
if "%fname%"=="" ( %_fatal% "Unknown name pattern '%pattern%'" 23 )

set "name="
call %script_dir%\publish_setname.bat
if "%name%"=="" ( %_fatal% "Unknown name for fname: '%fname%'" 222 )

:execrbcs
if exist "!spath!\%fname%" (
    %_warning% "Skip '%name% '%fname%': already in '%fsetupsdir%'"
) else (
    call:rbc "!spath!"
)
goto:eof

:rbc
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=..\..\setup" )
%_info% "Robocopy '%name%': '%fname%' from '%src%' to '%dst%'"
REM Explain the robocopy options:
REM /Z: copy in restartable mode (survive network glitches)
REM /R:5: retry 5 times
REM /W:5: wait 5 seconds between retries
REM /TBD: wait for sharenames to be defined (useful for network drives)
REM /MT:16: use 16 threads
REM /NJH: no job header
REM /NJS: no job summary
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%
goto:eof

