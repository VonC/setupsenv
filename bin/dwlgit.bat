@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir_bin%\echos_macros.bat
rem goto:dr
%_info% "Check latest Git version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/git-for-windows/git/releases/latest"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
set "version=%version:v=%"

:dr
rem set "version=2.35.1.windows.2"
echo.Latest version='%version%'

set "file=PortableGit-%version%-64-bit.7z.exe"
set "file=%file:.windows.1=%"
set "file=%file:.windows.=.%"
echo.file='%file%'
if exist "%PRGS%\gits\%file%" (
    %_ok% "'%file%' Already downloaded"
    goto:eof
)

set "url=https://github.com/git-for-windows/git/releases/download/v%version%/%file%"
%_task% "Download latest to '%PRGS%\gits\%file%' from URL '%url%'"
curl -kL %url% -o "%PRGS%\gits\%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "Unable to download '%PRGS%\gits\%file%' from latest, URL '%url%'" 1
)
%_ok% "'%file%' downloaded"