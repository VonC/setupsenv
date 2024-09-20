@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir%\echos_macros.bat
rem goto:dr
set "repo=cli/cli"
set "prgname=gh"
set "prgsfolder=%prgname%s"
set "extension=_windows_amd64"
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
echo.Latest version='%version%'

rem https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip
set "file=%prgname%_%version%%extension%.zip"
echo.file='%file%'
if exist "%PRGS%\%prgsfolder%\%file%" (
    %_ok% "'%file%' Already downloaded"
    goto:eof
)

set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
%_task% "Download latest to '%PRGS%\%prgsfolder%\%file%' from URL '%url%'"
curl -kL %url% -o "%PRGS%\%prgsfolder%\%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "Unable to download '%PRGS%\%prgsfolder%\%file%' from latest, URL '%url%'" 1
)
%_ok% "'%file%' downloaded"