@echo off
setlocal enabledelayedexpansion

rem https://stackoverflow.com/questions/42582230/how-to-install-visual-studio-code-silently-without-auto-open-when-installation
rem VSCodeSetup-1.10.1.exe /VERYSILENT /MERGETASKS=!runcode

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& goto:eof
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
set "bin_dir=%senv_dir%\bin"

call "%senv_dir%\batcolors\echos_macros.bat" export
call "%bin_dir%\getInstallPath.bat" VSCode code
%_info% "[%~nx0] Check vscode path '%instPath%'"

if exist "%instPath%\bin\code.cmd" (
    if not "%1"=="update" (
        %_ok% "[%~nx0] Standard path"
        goto:eoflocal
    )
)
if "%instPath%"=="" ( %_warning% "[%~nx0] No VSCode Installation path detected"&& exit /b 0 )
if not exist "%instPath%" ( %_warning% "[%~nx0] VSCode Installation path '%instPath%' does not exist"&& goto:eoflocal )
set "f=%HOME%\bin\senv.local.doskey"
if not exist "%f%"  ( goto:eoflocal )
grep vscodes "%f%">NUL
if not errorlevel 1 (
    %_info% "[%~nx0] Make sure '%f%' does not have vscode or aliase aliases"
    sed -i "/^vscode=.*$/d" "%f%"
    sed -i "/^aliase=.*$/d" "%f%"
)
:eoflocal
endlocal
exit /b 0