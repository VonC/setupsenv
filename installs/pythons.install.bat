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

set "py_version=%fs:python-=%"
set "py_version=%py_version:-amd64.exe=%"
%_task% "[%~nx0] Must install Python %PRGS%\setup\%fs%, version '%py_version%'"
set "install_ok=check_symlink"
rem "%PRGS%\setup\%fs%" /DIR="%PRGS%\vscode" /VERYSILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /MERGETASKS=!runcode
"%PRGS%\setup\%fs%" /quiet TargetDir="%PRGS%\pythons\python-%py_version%-amd64" Include_launcher=0
if errorlevel 1 ( %_fatal% "[%~nx0] Issue when installing Python" 1 )
rem call "%installs_dir%\vscodes.pre.bat"
rem call "%installs_dir%\vscodes.post.bat" "update"
endlocal & set "install_ok=%install_ok%"
if exist "%~dp0standalone_%~nx0.flag" (
    echo install_ok='%install_ok%'
		set "install_ok="
    del "%~dp0standalone_%~nx0.flag"
)
