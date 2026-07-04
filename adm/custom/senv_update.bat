@echo off
setlocal enabledelayedexpansion
for %%i in ("%~dp0") do SET "script_dir=%%~fi"
for %%i in ("%~dp0..\..") do SET "senv_dir=%%~fi"
cd /d "%script_dir%"
call "%senv_dir%\batcolors\echos_macros.bat"
set "custom_dir=%senv_dir%\custom"
set "builds_dir=%senv_dir%\builds"

%_info% "script_dir='%script_dir%'"
set profile=
set profil=
set script_dir_bin=
set setupsdir=
set setupsdirbat=
set "prgtoinstall=%1"

set profile=%1
if "%profile%"=="" (
    %_fatal% "profile must be provided" 1
)

if not exist "%HOME%\bin\senv.local.doskey" (
     %_fatal% "'%HOME%\bin\senv.local.doskey' does not exists" 2
)
@echo on
for /f "delims=" %%x in ('findstr "cdis=" "%HOME%\bin\senv.local.doskey"') do set setupsdir=%%x
set "setupsdir=%setupsdir:*/d =%"
%_info% "setupsdir='%setupsdir%'"

if not exist "%setupsdir%\senv_%profile%-zip.exe" (
     %_fatal% "'senv_%profile%-zip.exe' does not exists in '%setupsdir%'" 2
)

if exist "%builds_dir%\senv_%profile%-zip.exe" (
    %_task% "Must update 'senv_%profile%-zip.exe' from '%builds_dir%' to '%setupsdir%'"
    (robocopy "%builds_dir%" "%setupsdir%" "senv_%profile%-zip.exe" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
    if not "%ERRORLEVEL%"=="0" ( %_fatal% "Unable to copy '%builds_dir%\senv_%profile%-zip.exe' to '%setupsdir%'" 18 )
    %_ok% "'senv_%profile%-zip.exe' in '%setupsdir%' updated from '%builds_dir%'"
)

set senv_noconfirm=1
rem https://superuser.com/questions/1078662/7zip-create-self-extracting-archive-sfx-with-specified-extract-path/1184818#1184818
rem After https://superuser.com/questions/331148/7-zip-command-line-extract-silently-quietly/331150#331150
rem %sz% x -aoa -y -o^"%PRGS%^" -pdefault -sccUTF-8 ^"%setupsdir%\senv_%profile%-zip.exe^"
start /W ^"%setupsdir%\senv_%profile%-zip.exe^" -y -o^"%PRGS%^"
cd "%PRGS%\senv"
cd
call setup.bat
set senv_noconfirm=
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
