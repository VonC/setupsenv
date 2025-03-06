@echo off
setlocal enabledelayedexpansion
call:init_env
call:init_params %*
%_info% "Wildfly URL '%WF_URL%' ."
endlocal & set "PATH=%PATH%" & set "WF_URL=%WF_URL%"

setlocal enabledelayedexpansion
call:init_env
call:get_wildfly_state
%_ok% "Wildfly Status done"

endlocal
goto:eof

:get_wildfly_state
set "STATE_TO_CHECK=%~1"
set "WILDFLY_STATE="

for /f "tokens=*" %%i in ('curl -s -H "Content-Type: application/json" -d "{\"operation\":\"read-attribute\",\"name\":\"server-state\"}" %WF_URL%') do (
    set "RESPONSE=%%i"
)
echo RESPONSE='%RESPONSE%'
for /f "tokens=2 delims=:" %%a in ('echo %RESPONSE% ^| findstr /c:"\"result\""') do (
    for /f "delims=," %%b in ("%%a") do (
        set "WILDFLY_STATE=%%~b"
        set "WILDFLY_STATE=%WILDFLY_STATE:"=%"
    )
)

if not defined WILDFLY_STATE (
    echo not started
    exit /b 0
)
echo.%WILDFLY_STATE%
exit /b 0
goto:eof


:checkWildFlyState
set "WILDFLY_URL=http://localhost:9990/management"
set "STATE_TO_CHECK=%~1"

call :getWildFlyState
set "CURRENT_STATE=%WILDFLY_STATE%"

if "%CURRENT_STATE%"=="%STATE_TO_CHECK%" (
    exit /b 0
) else (
    exit /b 1
)
goto:eof

:prepare_new_log
for /f %%i in ('bash -c "date +%%Y%%m%%d_%%H%%M%%S"') do set "wildfly_log_timestamp=%%i"
set "wildfly_log_file=wildfly_%wildfly_version%_%wildfly_log_timestamp%.log"
if exist wildfly_log ( rmdir wildfly_log )
mklink /J wildfly_log %wildfly_log_file%
goto:eof

:init_env
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)
goto:eof

:init_params
REM Initialize parameter array
set "args_count=0"
for %%a in (%*) do (
    set /a args_count+=1
    set "param[!args_count!]=%%a"
    rem echo "Add '%%a' to param at '!args_count!'"
)

rem set "WF_JDK=17"
call:check_param jdk "Must be a version number like 17"
set "jdk_version=%param_value%"
if not exist "%PRGS%\javas\jdk%jdk_version%" (
  %_fatal% "Invalid jdk version '%jdk_version%' (Must be a version number like 17)" 3
)
call switchjdk %jdk_version%
%_ok% "jdk version '%jdk_version%' exists as '%PRGS%\javas\jdk%jdk_version%'"

call:check_param version "Must be a version number like 27"
set "wildfly_version=%param_value%"
if not exist "%PRGS%\wildflys\wildfly%wildfly_version%" (
  %_fatal% "Invalid Wildfly version '%jdk_version%' (Must be a version number like 27)" 3
)
%_info% "Wildfly version '%wildfly_version%' selected."

call:check_param url
set "WF_URL=%param_value%"
if not defined wildfly_console_url (
  %_warning% "url param missing (Wildfly console URL). Use http://localhost:9990"
  set "WF_URL=http://localhost:9990"
)
goto:eof

:check_param
set "param_name=%~1"
set "mandatory=%~2"
for /f %%A in ('powershell -command "('%param_name%').ToUpper()"') do set "param_name_upper=%%A"
rem echo param_name_upper=%param_name_upper%

set "param_value="
if defined WF_%param_name_upper% (
    set "param_value=!WF_%param_name_upper%!"
    %_ok% "Environment variable 'WF_%param_name_upper%' set to '!param_value!'"
) else (
    %_ok% "No 'WF_%param_name_upper%' set. Look for a '%param_name% [value]' argument"
)

set "extracted_value="
REM Loop over parameters
for /L %%i in (1,2,!args_count!) do (
    set "current_param=!param[%%i]!"
    rem echo "current_param='!current_param!' at '%%i'"
    REM Check if the parameter starts with param_name=
    if "!current_param!"=="!param_name!" (
        set /a next=%%i+1
        call set "value=%%param[!next!]%%"
        rem echo "value='!value!' at '!next!'"
        
        REM Trim leading spaces
        for /f "tokens=* delims= " %%x in ("!value!") do set "value=%%x"
        
        REM Trim trailing spaces (up to 10 spaces)
        for /L %%x in (1,1,10) do (
            if "!value:~-1!"==" " set "value=!value:~0,-1!"
        )
        
        REM Assign the trimmed value to a variable
        set "extracted_value=!value!"
        rem echo Extracted value: "!extracted_value!"
        goto:extracted_value
    )
    
    rem echo Parameter %%i: !current_param!
    REM Add your processing here
)
:extracted_value
if defined extracted_value (
  if defined param_value (
    %_warning% "Parameter '%param_name%=%extracted_value% will override env var 'WF_%param_name_upper%=%param_value%'"
  )
  set "param_value=%extracted_value%"
  %_ok% "'%param_name%' set to '!param_value!'"
)
if not defined param_value (
  if defined mandatory (
    %_fatal% "Missing mandatory parameter '%param_name%' (%mandatory%)" 2
  )
)
goto:eof