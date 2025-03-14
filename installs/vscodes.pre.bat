@echo off

if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion
set "echos_standalone=%~dp0standalone_%~nx0.flag"

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& goto:eof
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
set "bin_dir=%senv_dir%\bin"

call %senv_dir%\batcolors\echos_macros.bat
%_info% "vscodes.pre: vscode"

set "pre_ok="
call "%bin_dir%\getInstallPath.bat" VSCode code nofatal
%_info% "vscodes.pre: instPath='%instPath%'"
rem @echo on
if exist "%instPath%\bin\code.cmd" (
  set "pre_ok=true"
	if "%1"=="" (
		%_ok% "VSCode already installed in '%instPath%"
	)
) else (
	%_warning% "VSCode not installed. To be installed by next step."
)
endlocal & set "pre_ok=%pre_ok%"
set "vscodei="
if exist "%~dp0standalone_%~nx0.flag" (
    echo pre_ok='%pre_ok%'
		set "pre_ok="
    del "%~dp0standalone_%~nx0.flag"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
