@echo off

if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "echos_standalone=%~dp0standalone_%~nx0.flag"

set "usage="
set "prg_name=%~1"
if "%prg_name%"=="" (
    %_error% "dwl_inst_prg first param prg_name (ex: 'maven' or 'mvn' or 'java') is MISSING"
    set "usage=1"
)
set "prg_version=%~2"
if "%prg_version%"=="" (
    %_error% "switchver second param prg_version (ex: '3.9.9' or '3.6.0' or '22') is MISSING"
    set "usage=1"
)
if defined usage (
    :: Example: switchver pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python
    %_fatal% "Usage: dwl_inst_ver prg_name prg_version" 2
)
set "usage="

%_task% "Try and download prg_name '%prg_name%' at prg_version '%prg_version%'"
call "%script_dir%\dwl.bat" %prg_name% %prg_version%
if errorlevel 1 (
    %_fatal% "Unable to download prg_name '%prg_name%' at prg_version '%prg_version%'" 111
)
%_ok% "prg_name '%prg_name%' at prg_version '%prg_version%' downloaded"
%_task% "Try and install prg_name '%prg_name%' at prg_version '%prg_version%'"
call "%HOME%\bin\inst_prg.bat" %prg_name% %prg_version%
if errorlevel 1 (
    %_fatal% "Unable to install prg_name '%prg_name%' at prg_version '%prg_version%'" 112
)
%_ok% "prg_name '%prg_name%' at prg_version '%prg_version%' is now installed"

endlocal
popd
rem goto:eof
if exist "%~dp0standalone_%~nx0.flag" (
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
