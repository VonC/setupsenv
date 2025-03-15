@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
%_info% "~~~~~~~~~~~~ Notepad++ post installation ~~~~~~~~~~~~"
%_task% "Must check presence of settings in '%PRGS%\npps'"
if exist "%PRGS%\npps\settings" (
    %_ok% "settings exists in '%PRGS%\npps'"
    goto:check_global_config_editor
)
mkdir "%PRGS%\npps\settings"
if errorlevel 1 (
    call:fatal "[%~nx0] Unable to create '%PRGS%\npps\settings'" 126
) else (
    %_ok% "settings created in '%PRGS%\npps'"
)
:check_global_config_editor
%_task% "Must check HOME global Git config at '%HOME%\.gitconfig'"
if not exist "%HOME%\.gitconfig" (
    %_warning% "HOME global Git config at '%HOME%\.gitconfig' not accessible"
    goto:endlocal
)
findstr /i /r /c:"editor.*notepad.*settingsDir" "%HOME%\.gitconfig" >NUL 2>NUL
if errorlevel 0 (
    %_ok% "Global Git config editor already using Notepad++ with settingsDir=settings"
    goto:endlocal
)
findstr /i /r /c:"editor.*notepad" "%HOME%\.gitconfig" >NUL 2>NUL
if errorlevel 0 (
    git config --global core.editor "%PRGS:\=/%/npps/current/notepad++.exe -settingsDir='%PRGS:\=/%/npps/settings' -multiInst -notabbar -nosession -noPlugin"
    if errorlevel 1 (
        call:fatal "[%~nx0] Unable to set global Git config editor using Notepad++" 12
    ) else (
        %_ok% "Global Git config editor now using Notepad++ with settingsDir=settings"
        goto:endlocal
    )
)
%_ok% "Global Git config editor not using notepad: nothing more to set"
git config --global core.editor

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