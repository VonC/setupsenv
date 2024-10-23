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
if defined SENV_DWL_DEBUG (
  set "SENV_DWL_VERSION=131.0.3"
  set "SENV_DWL_URL=https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe"
  ::                https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe
  %_info% "[%~nx0] SENV_DWL_DEBUG set: SENV_DWL_VERSION '%SENV_DWL_VERSION%' and SENV_DWL_URL '%SENV_DWL_URL%'"
) else (
  %_info% "[%~nx0] SENV_DWL_DEBUG not set: version (SENV_DWL_VERSION) and URL (SENV_DWL_URL) to be fetched"
)
set "repo=nodejs/node"
set "prgname=node"
:: The download script is called dwljdk.bat, but the archives must go 

set "SENV_DWL_ASK_FOR_URL=1"
%_info% "[%~nx0] Dwl '%repo%' for '%prgname%'"
call "%script_dir%\dwl_prg.bat" "%repo%" "%prgname%"
goto:eof


:get_url
rem https://nodejs.org/download/release/v22.9.0/node-v22.9.0-win-x64.zip
rem https://nodejs.org/download/release/v23.0.0/node-v23.0.0-win-x64.zip
rem https://nodejs.org/download/release/v23.0.0/node-v23.0.0-win-x64.zip
set "version=%~2"
echo https://nodejs.org/download/release/v%version%/node-v%version%-win-x64.zip
goto:eof

:get_filename
rem https://nodejs.org/download/release/v22.9.0/node-v22.9.0-win-x64.zip
set "version=%~2"
echo node-v%version%-win-x64.zip
goto:eof
