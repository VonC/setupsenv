@echo off
setlocal enabledelayedexpansion
for %%i in ("%~dp0") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
for %%i in ("%script_dir%\..\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

rem @echo on
rem set "ECHO_STATE=ON"

set "slpb=%HOME%\bin\senv.local.pre.bat"
if not exist "%slpb%" (
	%_fatal% "%%%%%%%%HOME%%%%%%%%\bin\senv.local.pre.bat should exist. (with HOME='%HOME%' so: '%slpb%')"
)

call:check_var_set PROG
call:check_var_set PRGS
call:check_var_set HOME
call:check_var_set REMOTE_HOME

%_info% "Content of '%slpb%'"
type "%slpb%"

goto:eof

:check_var_set
set "var_set=%1"

C:\Windows\System32\findstr.exe /R /C:"set %var_set%=." "%slpb%" 1>NUL: 2>NUL:
if "%ERRORLEVEL%"=="0" ( goto:check_var_set_ok )

C:\Windows\System32\findstr.exe /R /C:"set .%var_set%=." "%slpb%" 1>NUL: 2>NUL:
if "%ERRORLEVEL%"=="0" ( goto:check_var_set_ok )

%_task% "Must update '%slpb%' with  %var_set% '!%var_set%!'"
echo set ^"%var_set%=!%var_set%!^">> "%slpb%"
goto:eof

:check_var_set_ok
	%_ok% "'%var_set%' already defined in '%slpb%'"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
