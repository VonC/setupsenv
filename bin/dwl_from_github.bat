@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%senv_dir%\..\setup") do ( set "setup_dir=%%~fi" )

set "repo=%~1"
set "prgname=%~2"

if "%repo%"=="" (
    %_fatal% "[%~nx0] repo must be provided (ex: charmbracelet/gum)" 1
)
rem @echo on
echo.%repo%| findstr /R /C:"^[a-Z0-9_]*/[a-Z0-9_]*$" >nul
rem echo %ERRORLEVEL%
if errorlevel 1 (
    %_fatal% "[%~nx0] repo must be in the format org/repo (ex: charmbracelet/gum)" 1
)

if "%prgname%"=="" (
    %_fatal% "[%~nx0] prgname must be provided (ex: gum)" 1
)
echo.%prgname%| findstr /R /C:"^[a-Z0-9_]*$" >nul
rem echo %ERRORLEVEL%
if errorlevel 1 (
    %_fatal% "[%~nx0] prgname must be composed of letter, digits or _ (ex: gum)" 1
)

set "prgsfolder=%prgname%s"

mkdir "%PRGS%\%prgsfolder%" 2> nul


set "version=0.14.5"
goto:dr


%_info% "[%~nx0] Check latest '%repo%' version for '%prgname%'"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/%repo%/releases/latest"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
set "version=%version:v=%"

:dr
rem set "version=2.35.1.windows.2"
%_info% "[%~nx0] Latest version='%version%'"

rem Call the script and capture its output
for /f "delims=" %%i in ('call "%script_dir%\dwl%prgname%.bat" :get_filename %version%') do set "file=%%i"
%_info% "[%~nx0] file='%file%'"
goto:eof

if exist "%PRGS%\%setup_dir%\%file%" (
    %_ok% "[%~nx0] '%file%' Already downloaded in setup_dir '%setup_dir%'"
    goto:install
)

set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
%_task% "[%~nx0] Download latest to '%PRGS%\%prgsfolder%\%file%' from URL '%url%'"
curl -kL %url% -o "%PRGS%\%prgsfolder%\%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "[%~nx0] Unable to download '%PRGS%\%prgsfolder%\%file%' from latest, URL '%url%'" 1
)
%_ok% "[%~nx0] '%file%' downloaded"

:install
set "filename=%file:~0,-4%"
if not exist "%PRGS%\%prgsfolder%\%filename%" (
    %_task% "[%~nx0] Unzip '%PRGS%\%prgsfolder%\%file%' to '%PRGS%\%prgsfolder%'"
    unzip "%PRGS%\%prgsfolder%\%file%" -d "%PRGS%\%prgsfolder%\%filename%"
    if ERRORLEVEL 1 (
        %_fatal% "[%~nx0] Unable to unzip '%PRGS%\%prgsfolder%\%file%' to '%PRGS%\%prgsfolder%'" 1
    )
    %_ok% "[%~nx0] '%PRGS%\%prgsfolder%\%file%' unzipped to '%PRGS%\%prgsfolder%'"
) else (
    %_ok% "[%~nx0] %PRGS%\%prgsfolder%\%filename%" already unzipped
)

for /f "tokens=5,* delims= " %%a in ('dir "%PRGS%\gums" ^| grep current') do ( set "curr=%%a" )
if "%curr%"=="" (
    %_task% "[%~nx0] No current junction folder detected: must create '%PRGS%\%prgsfolder%\current'"
)
rem echo filename='%filename%'
rem echo curr='%curr%'
echo.%curr% | findstr /C:"%filename%" >nul
if %errorlevel% equ 0 (
    %_ok% "[%~nx0] %filename% is already referenced by junction current"
    goto:final
)
%_warning% "[%~nx0] current (%curr%) does not reference '%filename%' yet"
%_task% "[%~nx0] '%PRGS%\%prgsfolder%\current' must reference '%filename%'"
if exist "%PRGS%\%prgsfolder%\current" (
    rmdir "%PRGS%\%prgsfolder%\current"
)
:createcurr
mklink /J "%PRGS%\%prgsfolder%\current" "%PRGS%\%prgsfolder%\%filename%\%filename%"
if ERRORLEVEL 1 (
    %_fatal% "[%~nx0] Unable to create current referencing '%PRGS%\%prgsfolder%\%filename%\%filename%'" 2
)
%_ok% "[%~nx0] current now references '%PRGS%\%prgsfolder%\%filename%\%filename%'"
:final
%_ok% "[%~nx0] Gum available at '%PRGS%\gums\current:"
%PRGS%\gums\current\gum.exe --version