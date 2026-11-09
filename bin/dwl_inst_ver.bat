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
    set "prg_version=latest"
)

if defined usage (
    rem Example: dwl_inst_ver python [1.13.1]
    %_fatal% "Usage: dwl_inst_ver python [1.13.1]" 2
)
set "usage="

%_task% "Try and download prg_name '%prg_name%' at prg_version '%prg_version%'"
rem dwl.bat names the archive it left in %PRGS%\setup in dwl_file. Without
rem that archive, inst_prg.bat would install whatever older one matches.
set "dwl_file="
call "%script_dir%\dwl.bat" %prg_name% %prg_version%
if errorlevel 1 (
    %_fatal% "Unable to download prg_name '%prg_name%' at prg_version '%prg_version%'" 111
)
if not defined dwl_file (
    %_fatal% "dwl named no archive for prg_name '%prg_name%' at prg_version '%prg_version%': nothing to install" 113
)
if not exist "%PRGS%\setup\%dwl_file%" (
    %_fatal% "'%dwl_file%' is missing from '%PRGS%\setup' after the download of prg_name '%prg_name%' at prg_version '%prg_version%'" 113
)
%_ok% "prg_name '%prg_name%' at prg_version '%prg_version%' downloaded: '%dwl_file%'"
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
