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

if not exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_task% "Must create '%prg_folder%' in '%PRGS%\%prgs_folder%'"
    mkdir "%PRGS%\%prgs_folder%\%prg_folder%"
    if errorlevel 1 ( %_fatal% "Issue when creating prg_folder '%prg_folder%' in '%PRGS%\%prgs_folder%'" 88 )
    %_ok% "prg_folder '%prg_folder%' in '%PRGS%\%prgs_folder%' created"
) else (
    %_ok% "prg_folder '%prg_folder%' in '%PRGS%\%prgs_folder%' already present"
)
if not exist "%PRGS%\%prgs_folder%\%prg_folder%\%fname%" (
    %_task% "Must create '%fname%' in '%PRGS%\%prgs_folder%\%prg_folder%'"
    copy "%PRGS%\%prgs_folder%\%fname%" "%PRGS%\%prgs_folder%\%prg_folder%"
    if errorlevel 1 ( %_fatal% "Issue when copying '%fname%' to '%prg_folder%'" 89 )
    %_ok% "'%fname%' in '%PRGS%\%prgs_folder%\%prg_folder%' created"
) else (
    %_ok% "'%fname%' in '%PRGS%\%prgs_folder%\%prg_folder%' present"
)
if not exist "%PRGS%\%prgs_folder%\%prg_folder%\draw.io.exe" (
    %_task% "Must create 'draw.io.exe' in '%PRGS%\%prgs_folder%\%prg_folder%'"
    copy "%PRGS%\%prgs_folder%\%fname%" "%PRGS%\%prgs_folder%\%prg_folder%\draw.io.exe"
    if errorlevel 1 ( %_fatal% "Issue when copying '%fname%' to '%prg_folder%' as draw.io.exe" 90 )
    %_ok% "'draw.io.exe' in '%PRGS%\%prgs_folder%\%prg_folder%' created"
) else (
    %_ok% "'draw.io.exe' in '%PRGS%\%prgs_folder%\%prg_folder%' present"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
