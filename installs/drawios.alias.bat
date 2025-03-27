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

doskey /MACROS | findstr drawio >NUL
if errorlevel 0 (
    %_ok% "drawio alias in place"
    exit /b 0
    goto:eof
)

echo drawio=%%PRGS%%\drawios\current\draw.io.exe $*>> "%HOME%\bin\senv.local.doskey"
if errorlevel 0 (
    %_ok% "'drawio' alias added to '%HOME%\bin\senv.local.doskey'"
    exit /b 0
    goto:eof
)
%_fatal% "Unable to add 'drawio' alias to '%HOME%\bin\senv.local.doskey'" 85
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
