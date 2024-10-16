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
set "repo=go/dev"
set "prgname=go"
%_info% "[%~nx0] Dwl '%repo%' for '%prgname%'"
call "%script_dir%\dwl_from_github.bat" "%repo%" "%prgname%"
goto:eof

:get_latest_version
rem @echo on
rem <td class="filename"><a class="download" href="/dl/go1.23.2.windows-amd64.zip">go1.23.2.windows-amd64.zip</a></td>
curl -sLk https://go.dev/dl/ 2>&1 | findstr .windows-amd64.zip > "%script_dir%\go_vers.txt"
for /f "delims=" %%a in ('sed -e "s/.*zip.>//" -e "s/<.*//" "%script_dir%\go_vers.txt"') do (
  set "version=%%a"
  goto :continue
)
:continue
set "version=%version:go=%"
set "version=%version:.windows-amd64.zip=%"
del "%script_dir%\go_vers.txt"
rem https://fossies.org/windows/misc/go1.23.2.windows-amd64.zip
set "gu=https://fossies.org/windows/misc/go%version%.windows-amd64.zip"
echo.%version%#%gu%
endlocal
goto:eof

:get_filename
rem https://go.dev/dl/go1.23.2.windows-amd64.zip
set "version=%~2"
echo go%version%.windows-amd64.zip
goto:eof
