@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& goto:eof
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "bin_dir=%senv_dir%\bin"

set "f=%HOME%\bin\senv.local.doskey"
if not exist "%f%"  ( goto:eoflocal )
grep "postman=" "%f%">NUL
if errorlevel 1 (
    %_info% "Make sure '%f%' does have postman alias"
    rem insert `doskey postman="%PRGS%\postmans\current\postman-portable.exe" $*` before the line `cdi=`, with a blank line before it
    sed -i "/^cdi=.*$/i postman=\"%PRGS:\=\\\\%\\\\postmans\\\\current\\\\postman-portable.exe\" \$*\n" "%f%"
    if errorlevel 1 ( %_error% "Issue when adding postman alias to '%f%'" ) else ( %_ok% "postman alias added to '%f%'" )
    doskey postman="%PRGS%\postmans\current\postman-portable.exe" $*
    if errorlevel 1 ( %_error% "Issue when adding postman alias to current session" ) else ( %_ok% "postman alias added to current session" )
) else (
    %_info% "postman alias already present in '%f%'"
)
:eoflocal
endlocal
exit /b 0
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
