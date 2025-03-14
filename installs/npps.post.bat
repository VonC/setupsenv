@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
%_info% "~~~~~~~~~~~~ Notepad++ post installation ~~~~~~~~~~~~"
%_task% "Must check presence of settings in '%PRGS%\npps'"
if exist "%PRGS%\npps\settings" (
    %_ok% "settings exists in '%PRGS%\npps'"
    goto:endlocal
)
mkdir "%PRGS%\npps\settings"
if errorlevel 1 (
    call:fatal "[%~nx0] Unable to create '%PRGS%\npps\settings'" 126
) else (
    %_ok% "settings created in '%PRGS%\npps'"
)

:endlocal
endlocal
if defined standalone_%~nx0 ( 
    call "%PRGS%\senv\batcolors\echos_macros.bat" unset
    set "standalone_%~nx0="
    set "setup_dir="
    set "senv_dir="
    set "prgname="
    set "batdir="
)
set "standalone_%~nx0="
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof

:fatal
call:endlocal
call "%PRGS%\senv\batcolors\echos.bat" :fatal "%~1" %~2