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
set "SENV_DWL_ASK_FOR_LATEST_VERSION=1"
if defined SENV_DWL_DEBUG (
  set "SENV_DWL_VERSION=131.0.3"
  set "SENV_DWL_URL=https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe"
  ::                https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe
  %_info% "[%~nx0] SENV_DWL_DEBUG set: SENV_DWL_VERSION '%SENV_DWL_VERSION%' and SENV_DWL_URL '%SENV_DWL_URL%'"
) else (
  %_info% "[%~nx0] SENV_DWL_DEBUG not set: version (SENV_DWL_VERSION) and URL (SENV_DWL_URL) to be fetched"
)
set "repo=sysinternals/suite"
set "prgname=sysinternalsSuite"
:: The download script is called dwljdk.bat, but the archives must go 
set "SENV_DWL_SCRIPT_NAME=sys"

%_info% "[%~nx0] Dwl '%repo%' for '%prgname%'"
call "%script_dir%\dwl_prg.bat" "%repo%" "%prgname%"
goto:eof

:get_latest_version
rem @echo on
if "%py_cycle%"=="" ( %_fatal% "[%~nx0] py_cycle needs to be set (3.12, 3.13, ...)" 11 )

curl -skL https://learn.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite > "%script_dir%\sysinternalsSuite.tmp"
for /f "delims=" %%a in ('findstr "calculated" "%script_dir%\sysinternalsSuite.tmp"') do ( set "version=%%a" )
set "version=%version:>=%"
set "version=%version:<=%"
set "version=%version:*calculated=%"
set "version=%version:"=%"
echo %version%> "%script_dir%\sysinternalsSuite.tmp"
for /f "tokens=1,2,3 delims=/" %%a in ('type "%script_dir%\sysinternalsSuite.tmp"') do ( set "version=%%c%%a%%b" )
rem https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe
set "gu=https://download.sysinternals.com/files/SysinternalsSuite.zip"
del "%script_dir%\sysinternalsSuite.tmp"
echo.%version%#%gu%
endlocal
goto:eof

:get_filename
rem "name": "OpenJDK17U-jdk_x64_windows_hotspot_17.0.12_7.zip"
set "version=%~2"
echo SysinternalsSuite-%version%.zip
goto:eof
