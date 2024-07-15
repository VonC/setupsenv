@echo on
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir_bin%\echos_macros.bat
%_info% "Check latest chrome version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/Hibbiki/chromium-win64/releases/latest"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
echo.Latest version='%version%'

set "file=%PRGS%\chromiums\chrome%version%.7z"
if exist "%file%" (
    %_ok% "'%file%' Already downloaded"
    goto:eof
)

%_task% "Download latest to '%file%'"
curl -kL https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.sync.7z -o "%file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "Unable to download '%file%' from latest" 1
)
%_ok% "'%file%' downloaded"