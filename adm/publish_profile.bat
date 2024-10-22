@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
set "bc=%senv_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "[%~nx0] script_dir(profile)='%script_dir%'"

cd "%senv_dir%\..\setup" || %_fatal% "[%~nx0] Unable to access setup folder at '%senv_dir%/../setup'" 3
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd "%senv_dir%\..\dl" || %_fatal% "[%~nx0] Unable to access dl folder at '%senv_dir%/../dl (must link to C:\%USERNAME%\Downloads)'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)

set "custom_dir=%senv_dir%\custom"
cd "%custom_dir%" || %_fatal% "[%~nx0] Unable to access custom folder" 1
%_info% "[%~nx0] Custom folder full path: '%custom_dir%', setup_dir='%setup_dir%', dl_dir='%dl_dir%'"

if exist "%custom_dir%\profile" (
    for /f "delims=" %%x in (%custom_dir%\profile) do set profile=%%x
)
if "%profile%"=="" (
    if "%1"=="" (
        %_fatal%  "Usage: publish xxx (profile whose list is to be published)" 4
    )
)
if not "%1"=="" ( set "profile=%1" )
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
    %_fatal% "[%~nx0] No target spath found in '%fsetupsdir%'" 111
)
%_info% "[%~nx0] Target path spath: '%spath%'"

rem C:\Public\SOFTWARE\senv\custom>cat *.list | sort -f | uniq
call:publishOne "peazip_portable-"
call:publishOne "PortableGit"
call:publishOne "gitcred"
call:publishOne "VSCode"
call:publishOne "SysinternalsSuite-"
call:publishOne "gum_"
call:publishOne "px-"
call:publishOne "apache-maven-3.0.4-"
call:publishOne "apache-maven-3.3.9-"
call:publishOne "apache-maven-3.9.9-"
call:publishOne "jdk-8"
call:publishOne "OpenJDK17"
call:publishOne "OpenJDK11"
call:publishOne "OpenJDK21"
call:publishOne "putty-"
call:publishOne "shellcheck-"
call:publishOne "WinSCP-"
call:publishOne "MobaXterm"
call:publishOne "node-v10."
call:publishOne "node-v14."
call:publishOne "node-v22."
call:publishOne "sqldeveloper-"
call:publishOne "Postman-"
call:publishOne "mqmon"
call:publishOne "npp."
call:publishOne "FileZilla_"
call:publishOne "jd-gui-"
call:publishOne "python-3.12"
call:publishOne "python-3.13"
call:publishOne "gh_"
call:publishOne "yEd-"
call:publishOne "ideaIC"
endlocal
goto:eof

:publishOne
set "pattern=%1"

set "fname="
for /F "delims=" %%f in ('dir /OD /b ..\..\setup^|findstr %pattern%^|tail -1') do ( set fname=%%f)
%_info% "[%~nx0] fname: '%fname%'"
if "%fname%"=="" ( %_fatal% "[%~nx0] Unknown name pattern '%pattern%'" 23 )

set "name="
call %script_dir%\publish_setname.bat
if "%name%"=="" ( %_fatal% "[%~nx0] Unknown name for fname: '%fname%'" 222 )

:execrbcs
if exist "!spath!\%fname%" (
    %_ok% "[%~nx0] Skip '%name% '%fname%': already in '!spath!'"
) else (
    call:rbc "!spath!"
)
goto:eof

:rbc
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=..\..\setup" )
%_info% "[%~nx0] Robocopy '%name%': '%fname%' from '%src%' to '%dst%'"
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

