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

if not "%fs:.zip=%"=="%fs%" (
    %_ok% "Zip '%fs%' means no installation required beside regular unzip"
    set "install_ok=false"
    goto:endlocal
)

set "py_version=%fs:python-=%"
set "py_version=%py_version:-amd64.exe=%"
%_task% "Must install Python %PRGS%\setup\%fs%, version '%py_version%'"
set "install_ok=check_symlink"
rem python-3.13.7-amd64.exe /passive /quiet TargetDir="%PRGS%\pythons\python-3.13.7-amd64" Shortcuts=0 Include_launcher=1 CompileAll=1 Include_debug=1 Include_symbols=1
"%PRGS%\setup\%fs%" /passive /quiet TargetDir="%PRGS%\pythons\python-%py_version%-amd64" Shortcuts=0 Include_launcher=1 CompileAll=1 Include_debug=1 Include_symbols=1
if errorlevel 1 ( %_fatal% "Issue when installing Python" 1 )
rem call "%installs_dir%\vscodes.pre.bat"
rem call "%installs_dir%\vscodes.post.bat" "update"
:endlocal
endlocal & set "install_ok=%install_ok%"
if exist "%~dp0standalone_%~nx0.flag" (
    echo install_ok='%install_ok%'
		set "install_ok="
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
