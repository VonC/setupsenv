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
endlocal
goto:eof

:publishOne
set "pattern=%1"

for /F "delims=" %%f in ('dir /OD /b ..\..\setup^|findstr %pattern%^|tail -1') do ( set fname=%%f)
%_info% "fname: '%fname%'"


rem @echo on
set "name="
if not "%name%" == "" ( goto:execrbcs )
if not "%fname:peazip_portable-=%" == "%fname%" ( set "name=peazips" )
if not "%fname:PortableGit-=%" == "%fname%" ( set "name=gits" )
if not "%fname:gitcred=%" == "%fname%" ( set "name=gits" )
if not "%fname:ZoomIt-=%" == "%fname%" ( set "name=zis" )
if not "%fname:ProcessExplorer-=%" == "%fname%" ( set "name=pes" )
if not "%fname:px-=%" == "%fname%" ( set "name=pxs" )
if not "%fname:putty-=%" == "%fname%" ( set "name=puttys" )
if not "%fname:shellcheck-=%" == "%fname%" ( set "name=shellchecks" )
if not "%fname:VSCodeUserSetup=%" == "%fname%" ( set "name=vscodes" )
if not "%fname:VSCode-win32-x64=%" == "%fname%" ( set "name=vscodes" )
if not "%fname:go1=%" == "%fname%" ( set "name=gos" )
if "%name%" == "" ( %_fatal% "Unknown name for fname '%fname%'" 22 )

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
if "%src%" == "" ( set "src=..\..\setup" )
%_info% "Robocopy '%name%': '%fname%' from '%src%' to '%dst%'"
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%
goto:eof

