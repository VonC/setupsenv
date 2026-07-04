@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
if errorlevel 1 echo "unable to cd to '%script_dir%'"&& exit /b 1

set "remote_setup_standalone="
if exist "echos_macros.bat" (
    call "echos_macros.bat"
) else if exist ..\..\batcolors\echos_macros.bat (
    call ..\..\batcolors\echos_macros.bat
    set "remote_setup_standalone=true"
) else (
    echo echos_macros is missing 1>&2
    exit /b 1
)
%_info% "script_dir='%script_dir%'"
set profile=
set profil=
set script_dir_bin=
set setupsdir=
set setupsdirbat=

set "profile=%~1"
if "%profile%"=="" (
    %_fatal% "profile must be provided" 1
)

set "setupsdir=%script_dir%\setups"
if defined remote_setup_standalone (
    cd ..\..\builds
    for /F "delims=" %%f in ('cd') do ( set setupsdir=%%f)
    cd /d "%script_dir%"
)
%_info% "setupsdir='%setupsdir%' '!setupsdir!'"

if not exist "%setupsdir%\senv_%profile%-zip.exe" (
     %_fatal% "'senv_%profile%-zip.exe' does not exists in '%setupsdir%'" 3
)

set senv_noconfirm=
set "VARNOSET="
call "%script_dir%\setup.ini.bat"
if errorlevel 1 (
    %_error% "Error during '%script_dir%\setup.ini.bat'"
    set VARNOSET=1
)
%_info% "VDI res='%VDI%', senv_noconfirm='%senv_noconfirm%'"
if "%HOME%"=="" (
    %_error% "vars not set (HOME '%HOME%')"
    set VARNOSET=1
)
if "%PRGS%"=="" (
    %_error% "vars not set (PRGS '%PRGS%')"
    set VARNOSET=1
)
if "%PROG%"=="" (
    %_error% "vars not set (PROG '%PROG%')"
    set VARNOSET=1
)
if "%VARNOSET%"=="1" (
	%_fatal% "vars not set (HOME '%HOME%', PRGS '%PRGS%', PROG '%PROG%')" 4
)

if exist "%PRGS%\senv\custom\profile" (
    %_info% "Update existing profile in '%PRGS%\senv\custom' to '%profile%'"
    rem https://stackoverflow.com/questions/804646/how-do-you-strip-quotes-out-of-an-echoed-string-in-a-windows-batch-file
    echo|set /p="%profile%" > "%PRGS%\senv\custom\profile"
)

if not exist version (
    %_warning% "No version found in remote: must update senv"
    goto:update_senv
)
for /f "tokens=* delims=" %%i in ('type version') do SET "vc=%%i" 
if not exist "%PRGS%\senv\custom" (
    %_warning% "No PRGS/senv ('%PRGS%\senv') found: must install senv"
    goto:update_senv
)
if exist "%PRGS%\senv\custom\version" (
    for /f "tokens=* delims=" %%i in ('type "%PRGS%\senv\custom\version" 2^>NUL') do SET "vcsenv=%%i" 
    %_info% "local custom version: '!vcsenv!'"
) else (
    where git >NUL 2>NUL
    if errorlevel 1 (
        %_warning% "No senv\custom\version, and no git: must update senv"
        goto:update_senv
    ) else (
        %_ok% "git there: compute version now"
        for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv\custom" describe --long --all HEAD') do SET "vcsenv=%%i"
        for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv" describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
    )
)
%_info% "remote vc    '%vc%'"
%_info% "local vcsenv '%vcsenv%'"
if not exist "%PRGS%\senv\custom\version" (
    echo %vcsenv%>"%PRGS%\senv\custom\version"
)
if not "%vc%"=="%vcsenv%" (
    %_warning% "Senv version has changed: must update senv"
    goto:update_senv
)
%_ok% "No need to update senv itself. Calling setup directly"
goto:senvsetup

:update_senv
rem %_fatal% "stop for now version" 1
%_task% "Must update local '%PRGS%' with senv_%profile%-zip.exe' from remote '%script_dir%'"
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS setups "%PRGS%" "senv_%profile%-zip.exe"
IF %ERRORLEVEL% LSS 8 (
    SET "OK=ok_%ERRORLEVEL%"
) else (
    set OK=%ERRORLEVEL%
)
rem echo "OK='%OK%' '!OK!'"
if "%OK:ok_=%"=="ok" (
    %_fatal% "Unable to robocopy '%CD%\setups\senv_%profile%-zip.exe' to '%PRGS%': errorlevel '%OK%'" 18
)
%_ok% "senv_%profile%-zip.exe has been copied from remote '%script_dir%' to local '%PRGS%' (exit '%OK:ok_=%')"

if defined remote_setup_standalone (
    %_ok% "Skip uncompressing senv_%profile%-zip.exe in '%PRGS%': standalone mode"
    goto:eof
)
set senv_noconfirm=1
cd /d "%PRGS%"
if errorlevel 1 %_fatal% "Unable to access '%PRGS% to uncompress senv_%profile%-zip.exe'" 19
rem do not call sz: 7zip might not be available, and this is an auto-extract archive anyway
rem %sz% x -aoa -o^"%PRGS%^" -pdefault -sccUTF-8 ^"%setupsdir%\senv_%profile%-zip.exe^"
%_task% "Must uncompress senv_%profile%-zip.exe in '%PRGS%'"
start /W senv_%profile%-zip.exe -y -o^"%PRGS%^"
if errorlevel 1 (
    %_fatal% "Unable to uncompress '%PRGS%\senv_%profile%-zip.exe'" 20
)
%_ok% "senv_%profile%-zip.exe has been uncompressed in '%PRGS%'"
:senvsetup
cd /d "%PRGS%\senv"
if errorlevel 1 %_fatal% "Unable to access '%PRGS% to uncompress senv_%profile%-zip.exe'" 39
rem cd
if defined remote_setup_standalone (
    %_ok% "Skip setup in '%PRGS%\senv': standalone mode"
    goto:eof
)
REM Replace the existing parameter handling
for /f "tokens=1,* delims= " %%a in ("%*") do set "args=%%b"

%_info% "call local setup.bat in '%cd%' with args='%args%'"
call setup.bat !args!
set senv_noconfirm=
set remote_setup_standalone=
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
