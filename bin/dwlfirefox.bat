@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir_bin%\echos_macros.bat
%_info% "Check latest Firefox version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://softaro.net/download-file/21759/?version=English 2^>^&1"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%^|grep Firefox') do ( set gu=%%a)
set "gu=%gu:HTTP/1.1 403 Forbidden=%"
set "gu=%gu:Japanese=English%"
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5 delims=/" %%a in ("%gu%") do set version=%%e
set "version=%version:HTTP=%"
echo.Latest version='%version%'

set "file=%PRGS%\firefoxs\%version%"
if exist "%file%" (
    %_ok% "'%file%' Already downloaded"
    goto:eof
)

%_task% "Download '%gu%' latest to '%file%'"
curl -kL "%gu%" -o "%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "Unable to download '%file%' from latest" 1
)
%_ok% "'%file%' downloaded"