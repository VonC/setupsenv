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

if exist "%setup_dir%\%file%" (
    %_ok% "[%~nx0] '%file%' Already downloaded in setup_dir '%setup_dir%'"
    goto:eof
)

set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
%_task% "[%~nx0] Download latest to '%setup_dir%\%file%' from URL '%url%'"
where curl
curl -kL %url% -o "%setup_dir%\%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "[%~nx0] Unable to download '%setup_dir%\%file%' from latest, URL '%url%'" 1
)
%_ok% "[%~nx0] '%file%' downloaded to '%setup_dir%'"
