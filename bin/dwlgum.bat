@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir_bin%\echos_macros.bat
set "repo=charmbracelet/gum"
set "prgname=gum"
set "prgsfolder=%prgname%s"
mkdir "%PRGS%\%prgsfolder%" 2> nul
set "extension=_Windows_x86_64"
set "version=0.14.1"
goto:dr

%_info% "Check latest '%repo%' version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/%repo%/releases/latest"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
set "version=%version:v=%"

:dr
rem set "version=2.35.1.windows.2"
%_info% "Latest version='%version%'"

rem https://github.com/charmbracelet/gum/releases/download/v0.14.1/gum_0.14.1_Windows_x86_64.zip
set "file=%prgname%_%version%%extension%.zip"
%_info% "file='%file%'"
if exist "%PRGS%\%prgsfolder%\%file%" (
    %_ok% "'%file%' Already downloaded"
    goto:install
)

set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
%_task% "Download latest to '%PRGS%\%prgsfolder%\%file%' from URL '%url%'"
curl -kL %url% -o "%PRGS%\%prgsfolder%\%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "Unable to download '%PRGS%\%prgsfolder%\%file%' from latest, URL '%url%'" 1
)
%_ok% "'%file%' downloaded"

:install
set "filename=%file:~0,-4%"
if not exist "%PRGS%\%prgsfolder%\%filename%" (
    %_task% "Unzip '%PRGS%\%prgsfolder%\%file%' to '%PRGS%\%prgsfolder%'"
    unzip "%PRGS%\%prgsfolder%\%file%" -d "%PRGS%\%prgsfolder%\%filename%"
    if ERRORLEVEL 1 (
        %_fatal% "Unable to unzip '%PRGS%\%prgsfolder%\%file%' to '%PRGS%\%prgsfolder%'" 1
    )
    %_ok% "'%PRGS%\%prgsfolder%\%file%' unzipped to '%PRGS%\%prgsfolder%'"
) else (
    %_ok% "%PRGS%\%prgsfolder%\%filename%" already unzipped
)

for /f "tokens=5,* delims= " %%a in ('dir "%PRGS%\gums" ^| grep current') do ( set "curr=%%a" )
if "%curr%"=="" (
    %_task% "No current junction folder detected: must create '%PRGS%\%prgsfolder%\current'"
)
rem echo filename='%filename%'
rem echo curr='%curr%'
echo.%curr% | findstr /C:"%filename%" >nul
if %errorlevel% equ 0 (
    %_ok% "%filename% is already referenced by junction current"
    goto:final
)
%_warning% "current (%curr%) does not reference '%filename%' yet"
%_task% "'%PRGS%\%prgsfolder%\current' must reference '%filename%'"
if exist "%PRGS%\%prgsfolder%\current" (
    rmdir "%PRGS%\%prgsfolder%\current"
)
:createcurr
mklink /J "%PRGS%\%prgsfolder%\current" "%PRGS%\%prgsfolder%\%filename%\%filename%"
if ERRORLEVEL 1 (
    %_fatal% "Unable to create current referencing '%PRGS%\%prgsfolder%\%filename%\%filename%'" 2
)
%_ok% "current now references '%PRGS%\%prgsfolder%\%filename%\%filename%'"
:final
%_ok% "Gum available at '%PRGS%\gums\current:"
%PRGS%\gums\current\gum.exe --version