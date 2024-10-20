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
rem set "SENV_DWL_VERSION=129.0.6668.101-r1343869"
set "SENV_DWL_SETUP_DIR=%PROG%\senv_setups\setups"
set "repo=Hibbiki/chromium-win64"
set "prgname=chrome"
%_info% "[%~nx0] Dwl '%repo%' for '%prgname%'"
call "%script_dir%\dwl_prg.bat" "%repo%" "%prgname%"
goto:eof

:get_filename
rem https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.sync.7z
set "version=%~2"
echo chrome.sync.7z#chromev%version%.7z
goto:eof
