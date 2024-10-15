@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

rem @echo on
set "arg=%~1"
if "%arg%"=="" ( goto:dwl_prg )
if not "%arg::=%"=="%arg%" ( goto%arg% )
echo nope
goto:eof

:dwl_prg
set "SENV_DWL_SETUP_DIR=%PROG%\senv_setups"
if defined SENV_DWL_DEBUG (
  set "SENV_DWL_VERSION=2.49.0"
  set "SENV_DWL_URL=https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip"
  %_info% "[%~nx0] SENV_DWL_DEBUG set: SENV_DWL_VERSION '%SENV_DWL_VERSION%' and SENV_DWL_URL '%SENV_DWL_URL%'"
) else (
  %_info% "[%~nx0] SENV_DWL_DEBUG not set: version (SENV_DWL_VERSION) and URL (SENV_DWL_URL) to be fetched"
)
set "repo=cli/cli"
set "prgname=gh"
%_info% "[%~nx0] Dwl '%repo%'"
call "%script_dir%\dwl_from_github.bat" "%repo%" "%prgname%"
goto:eof

:get_filename
rem https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip
set "version=%~2"
echo gh_%version%_windows_amd64.zip
goto:eof
