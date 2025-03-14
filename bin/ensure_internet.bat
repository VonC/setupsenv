@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

call "%script_dir%\testinternet.bat"
if "%ERRORLEVEL%" == "0" (
    %_ok% "Internet connection there. Proceed"
    goto:eof
)
if not defined HTTPS_PROXY (
    %_fatal% "Internet access missing: no download possible" 21
)
if not exist "%HOME%\bin\pxkill.bat" (
    %_fatal% "pxkill missing: unable to reset Internet access" 22
)
call "%HOME%\bin\pxkill.bat"
if not exist "%HOME%\bin\px.bat" (
    %_fatal% "px missing: unable to reset Internet access" 23
)
call "%HOME%\bin\px.bat"
call "%script_dir%\testinternet.bat"
if not "%ERRORLEVEL%" == "0" (
   %_fatal% "Internet access still missing after reset" 22
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
