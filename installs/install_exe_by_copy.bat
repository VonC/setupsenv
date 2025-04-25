@echo off
rem https://stackoverflow.com/questions/42582230/how-to-install-visual-studio-code-silently-without-auto-open-when-installation
rem VSCodeSetup-1.10.1.exe /VERYSILENT /MERGETASKS=!runcode
set install_ok=
if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion
set "echos_standalone=%~dp0standalone_%~nx0.flag"

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& goto:eof
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
set "installs_dir=%senv_dir%\installs"
call %senv_dir%\batcolors\echos_macros.bat

set "exe_name=%~1"
if not defined exe_name (
    %_fatal% "exe_name not defined" 86
)

if not exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_task% "Must create '%PRGS%\%prgs_folder%\%prg_folder%'"
    mkdir "%PRGS%\%prgs_folder%\%prg_folder%" >nul 2>&1
    if not errorlevel 0 (
        %_fatal% "'%prg_folder%' in '%PRGS%\%prgs_folder%' is missing" 81
    )
    %_ok% "'%PRGS%\%prgs_folder%\%prg_folder%' created"
) else (
    %_ok% "''%PRGS%\%prgs_folder%\%prg_folder%' already created"
)

if not exist "%PRGS%\%prgs_folder%\%prg_folder%.exe" (
    if not exist "%PRGS%\setup\%prg_folder%.exe" (
        %_fatal% "'%prg_folder%.exe' missing in in '%PRGS%\setup' is missing" 89
    )
    %_task% "Must copy '%prg_folder%.exe' from '%PRGS%\setup' to '%PRGS%\%prgs_folder%'"
    copy "%PRGS%\setup\%prg_folder%.exe" "%PRGS%\%prgs_folder%\%prg_folder%.exe" >nul 2>&1
    if errorlevel 1 (
        %_fatal% "Unable to copy '%prg_folder%.exe' from '%PRGS%\setup' to '%PRGS%\%prgs_folder%'" 88
    )
    %_ok% "'%prg_folder%.exe' copied from '%PRGS%\setup' to '%PRGS%\%prgs_folder%'"
) else (
    %_ok% "'%prg_folder%.exe' already present in '%PRGS%\%prgs_folder%'"
)

if not exist "%PRGS%\%prgs_folder%\%prg_folder%.exe" (
    %_fatal% "'%prg_folder%.exe' in '%PRGS%\%prgs_folder%' is missing" 84
)

if not exist "%PRGS%\%prgs_folder%\%prg_folder%\%exe_name%" (
    %_task% "Must clean up '%PRGS%\%prgs_folder%\%prg_folder%'"
    del /S "%PRGS%\%prgs_folder%\%prg_folder%\%exe_name%" >nul 2>&1
    if errorlevel 1 (
        %_fatal% "Unable to cleanup '%prg_folder%' in '%PRGS%\%prgs_folder%'" 82
    )
    %_ok% "'%PRGS%\%prgs_folder%\%prg_folder%' cleaned up"
    %_task% "Must copy '%PRGS%\%prgs_folder%\%prg_folder%.exe' to folder '%prg_folder%' as %exe_name%"
    rem echo copy "%PRGS%\%prgs_folder%\%prg_folder%.exe" "%PRGS%\%prgs_folder%\%prg_folder%\%exe_name%"
    copy "%PRGS%\%prgs_folder%\%prg_folder%.exe" "%PRGS%\%prgs_folder%\%prg_folder%\%exe_name%" >nul 2>&1
    if errorlevel 1 (
        %_fatal% "Unable to copy '%exe_name%' in '%PRGS%\%prgs_folder%\%prg_folder%'" 83
    )
    %_ok% "'%PRGS%\%prgs_folder%\%prg_folder%.exe' copied to folder '%prg_folder%' as %exe_name%"
) else (
    %_ok% "'%PRGS%\%prgs_folder%\%prg_folder%\%exe_name%' already present"
)
endlocal & set "install_ok=true"
exit /b 0
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
