@echo off
setlocal enabledelayedexpansion

rem https://stackoverflow.com/questions/42582230/how-to-install-visual-studio-code-silently-without-auto-open-when-installation
rem VSCodeSetup-1.10.1.exe /VERYSILENT /MERGETASKS=!runcode

if "%script_dir%"=="" (
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
)
call %script_dir%\batcolors\echos_macros.bat export
call %script_dir%\bin\getInstallPath.bat VSCode code
%_info% "Check vscode path '%instPath%\'"

if exist "%instPath%\bin\code.cmd" (
    if not "%1"=="update" (
        %_ok% "Standard path"
        goto:eoflocal
    )
)
if "%instPath%"=="" ( %_warning% "No VSCode Installation path detected"&& exit /b 0 )
if not exist "%instPath%" ( %_warning% "VSCode Installation path '%instPath%' does not exist"&& goto:eoflocal )
set "f=%HOME%\bin\senv.local.doskey"
if not exist "%f%"  ( goto:eoflocal )
grep vscodes "%f%">NUL
if not errorlevel 1 (
    %_info% "Make sure '%f%' does not have vscode or aliase aliases"
    sed -i "/^vscode=.*$/d" "%f%"
    sed -i "/^aliase=.*$/d" "%f%"
)
:eoflocal
endlocal
exit /b 0