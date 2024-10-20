@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

rem @echo on
set "arg=%~1"
if "%arg%"=="" ( goto:dwl_prg)
if not "%arg::=%"=="%arg%" ( goto%arg% )
echo nope
goto:eof

:dwl_prg
set "SENV_DWL_SETUP_DIR=%PROG%\senv_setups\setups"
set "SENV_DWL_ASK_FOR_LATEST_VERSION=1"
if defined SENV_DWL_DEBUG (
  set "SENV_DWL_VERSION=131.0.3"
  set "SENV_DWL_URL=https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe"
  ::                https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe
  %_info% "[%~nx0] SENV_DWL_DEBUG set: SENV_DWL_VERSION '%SENV_DWL_VERSION%' and SENV_DWL_URL '%SENV_DWL_URL%'"
) else (
  %_info% "[%~nx0] SENV_DWL_DEBUG not set: version (SENV_DWL_VERSION) and URL (SENV_DWL_URL) to be fetched"
)
set "repo=softaro/net"
set "prgname=firefox"
%_info% "[%~nx0] Dwl '%repo%' for '%prgname%'"
call "%script_dir%\dwl_prg.bat" "%repo%" "%prgname%"
goto:eof

:get_latest_version
rem %_info% "Check latest Firefox version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://softaro.net/download-file/21759/?version=English 2^>^&1"
rem echo.%cmd%
rem %cmd%|grep Firefox
for /f "tokens=* delims=" %%a in ('%cmd%^|grep Firefox') do ( set gu=%%a)
set "gu=%gu:HTTP/1.1 403 Forbidden=%"
if not "%gu:Japanese=%"=="%gu%" (
  set "gu=%gu:Japanese=English%"
)
for /f "tokens=2 delims=:" %%a in ("%gu%") do set gu=https:%%a
set "gu=%gu:exehttp=exe%"
rem echo.Latest version URL='%gu%'
for /f "tokens=1,2,3,4,5 delims=/" %%a in ("%gu%") do set version=%%e
set "version=%version:HTTP=%"
set "version=%version:*FirefoxPortable_=%"
set "version=%version:_English.paf.exe=%"
echo.%version%#%gu%
endlocal
goto:eof

:get_filename
rem https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.sync.7z
set "version=%~2"
echo FirefoxPortable_%version%_English.paf.exe
goto:eof
