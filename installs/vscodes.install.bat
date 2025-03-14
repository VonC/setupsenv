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

%_info% "install vscode %PRGS%\setup\%fs%"
set "install_ok=check_symlink"
"%PRGS%\setup\%fs%" /DIR="%PRGS%\vscode" /VERYSILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /MERGETASKS=!runcode
if errorlevel 1 ( %_fatal% "Issue when installing vscode" 1 )
call "%installs_dir%\vscodes.pre.bat"
call "%installs_dir%\vscodes.post.bat" "update"
endlocal & set "install_ok=%install_ok%"
set "vscodei="
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
