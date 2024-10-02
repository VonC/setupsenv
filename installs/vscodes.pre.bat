@echo off
setlocal enabledelayedexpansion
if "%script_dir%"=="" (
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
		set "empty_pre_ok=true"
)
call %script_dir%\batcolors\echos_macros.bat export
%_info% "vscodes.pre: vscode"

set "pre_ok="
call %script_dir%\bin\getInstallPath.bat VSCode code
%_info% "vscodes.pre: instPath='%instPath%'"
rem @echo on
if exist "%instPath%\bin\code.cmd" (
  set "pre_ok=true"
	if "%1"=="" (
		%_ok% "VSCode already installed in '%instPath%"
	)
)
endlocal & set "pre_ok=%pre_ok%" & set "empty_pre_ok=%empty_pre_ok%"
set "vscodei="
if "%empty_pre_ok%"=="true" (
	set "pre_ok="
)
set "empty_pre_ok="