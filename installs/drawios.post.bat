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
    %_fatal% "'%prg_folder%' in '%PRGS%\%prgs_folder%' is missing" 81
)
if exist "%PRGS%\%prgs_folder%\%prg_folder%\draw.io.exe" (
    %_ok% "'draw.io.exe' in '%PRGS%\%prgs_folder%\%prg_folder%\' present: 27.0.9 or more recent."
    exit /b 0
    goto:eof
)
if not exist "%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR" (
    %_fatal% "'$PLUGINSDIR' in '%PRGS%\%prgs_folder%\%prg_folder%' is missing" 82
)
if exist "%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR\draw.io.exe" (
    %_ok% "'draw.io.exe' in '%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR' present"
    exit /b 0
    goto:eof
)
if not exist "%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR\app-64.7z" (
    %_fatal% "'app-64.7z' in '%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR' is missing" 83
)
%sz% x -aos -o"%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR" -pdefault -sccUTF-8 "%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR\app-64.7z"
if errorlevel 1 (
    %_fatal% "Unable to unzip 'app-64.7z' in '%PRGS%\%prgs_folder%\%prg_folder%\$PLUGINSDIR'" 84
)
set "install_ok=true"
exit /b 0
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
