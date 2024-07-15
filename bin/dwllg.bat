@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir_bin%\echos_macros.bat
rem goto:dr
%_info% "Check latest LazyGit version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/jesseduffield/lazygit/releases/latest"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
set "version=%version:v=%"

:dr
rem set "version=2.35.1.windows.2"
echo.Latest version='%version%'

rem https://github.com/jesseduffield/lazygit/releases/download/v0.38.0/lazygit_0.38.0_Windows_x86_64.zip
set "file=lazygit_%version%_Windows_x86_64.zip"
echo.file='%file%'
if exist "%PRGS%\gits\%file%" (
    %_ok% "'%file%' Already downloaded"
    goto:eof
)

set "url=https://github.com/jesseduffield/lazygit/releases/download/v%version%/%file%"
%_task% "Download latest to '%PRGS%\lazygits\%file%' from URL '%url%'"
curl -kL %url% -o "%PRGS%\lazygits\%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "Unable to download '%PRGS%\lazygits\%file%' from latest, URL '%url%'" 1
)
%_ok% "'%file%' downloaded"