@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

rem @echo on
set "arg=%~1"
if "%arg%"=="" ( goto:dwl_from_github)
if not "%arg::=%"=="%arg%" ( goto%arg% )
echo nope
goto:eof

:dwl_from_github
set "SENV_DWL_SETUP_DIR=%PROG%\senv_setups\setups"
set "SENV_DWL_SCRIPT_NAME=lg"
set "repo=jesseduffield/lazygit"
set "prgname=lazygit"
%_info% "[%~nx0] Dwl '%repo%'"
call "%script_dir%\dwl_from_github.bat" "%repo%" "%prgname%"
goto:eof

:get_filename
rem https://github.com/jesseduffield/lazygit/releases/download/v0.38.0/lazygit_0.38.0_Windows_x86_64.zip
set "version=%~2"
echo.lazygit_%version%_Windows_x86_64.zip
goto:eof
