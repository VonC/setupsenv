@echo off
setlocal enabledelayedexpansion

rem https://www.yworks.com/resources/yed/demo/yEd-3.24.zip
rem <a href="/products/yed">yEd Graph Editor 3.24</a> at https://www.yworks.com/downloads#yEd

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "src=%~1"
set "dst=%~2"
set "file=%~3"

if not defined src (
    call:usage
    %_fatal% "src is missing" 1
)

if "%src%"=="/?" (
    robocopy /?
    goto:eof
)

if not defined dst (
    call:usage
    %_fatal% "dst is missing" 2
)

if not defined file (
    call:usage
    %_fatal% "file is missing" 3
)

if not exist "%src%\%file%" (
    %_fatal% "file does not exist: '%src%\%file%'" 4
)

rem Shift the parameters to skip the first three
shift
shift
shift

rem Collect the remaining parameters
set "params="
:loop
if "%~1"=="" goto endloop
set "params=!params! %1"
shift
goto loop
:endloop

if not defined RBC_RETRY ( set "RBC_RETRY=5")
if not defined RBC_WAIT ( set "RBC_WAIT=5")
if not defined RBC_MT ( set "RBC_MT=16")

rem Test if env vars RBC_RETRY, RBC_WAIT and RBC_MT are composed of digits only
rem set "vars=RBC_RETRY"
set "vars=RBC_RETRY RBC_WAIT RBC_MT"
for %%v in (%vars%) do (
    set "value=!%%v!"
    rem echo var '%%v', value '!value!'
    for /l %%i in (0,1,9) do (
        if defined value (
            set "value=!value:%%i=!"
        )
    )
    if defined value (
        %_fatal% "%%v '!%%v!' value '!value!' must be composed of digits only" 5
    )
)

%_task% "Must robocopy '%file%' from '%src%' to '%dst%' (RBC_RETRY='%RBC_RETRY%', RBC_WAIT='%RBC_WAIT%', RBC_MT='%RBC_MT%', RBC_ERROR='%RBC_ERROR%')"
robocopy "%src%" "%dst%" "%file%" /Z /R:%RBC_RETRY% /W:%RBC_WAIT% /MT:%RBC_MT% /TBD /NJH /NJS %params%
IF %ERRORLEVEL% LSS 8 (
    SET "OK=ok_%ERRORLEVEL%"
) else (
    set OK=%ERRORLEVEL%
)
rem echo "OK='%OK%' '!OK!'"
if "%OK:ok_=%"=="ok" (
    if defined RBC_ERROR (
        %_error% "[%~nx0] Unable to robocopy '%src%\%file%' to '%dst%': errorlevel '%OK%'" && goto:eof
    )
    %_fatal% "[%~nx0] Unable to robocopy '%src%\%file%' to '%dst%': errorlevel '%OK%'" 6
)
%_ok% "[%~nx0] %name% updated from '%src%' to '%dst%' (exit '%OK:ok_=%')"
goto:eof

:usage
%_info% "Simple Usage :: ROBOCOPY source destination file"
%_info% " "
%_info% "      source :: Source Directory (drive:\path or \\server\share\path)."
%_info% " destination :: Destination Dir  (drive:\path or \\server\share\path).
%_info% " "
%_info% "For more usage information run rbc /?"
%_info% " "
%_info% "Default options:"
%_info% " "
%_info% "  /Z: copy in restartable mode (survive network glitches)"
%_info% "  /R:5: retry 5 times (change with env var RBC_RETRY)"
%_info% "  /W:5: wait 5 seconds between retries (change with env var RBC_WAIT)"
%_info% "  /TBD: wait for sharenames to be defined (useful for network drives)"
%_info% "  /MT:16: use 16 threads (change with env var RBC_MT)"
%_info% "  /NJH: no job header"
%_info% "  /NJS: no job summary"
%_info% " "
%_info% "  If env var RBC_ERROR is defined, failure to robocopy triggers error, not fatal"
goto:eof