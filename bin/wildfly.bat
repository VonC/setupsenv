@echo off
setlocal enabledelayedexpansion
call:init_env
set "WF_ACTION="
call:init_params %*
%_info% "Wildfly URL '%WF_URL%', WF_ACTION='%WF_ACTION%'."
endlocal & set "PATH=%PATH%" & set "WF_URL=%WF_URL%" & set "WF_VERSION=%WF_VERSION%" & set "WF_ACTION=%WF_ACTION%"
set "WF_HOME=%PRGS%\wildflys\wildfly%WF_VERSION%"

setlocal enabledelayedexpansion

call:init_env
call:init_mgmt_user
call:%WF_ACTION%
endlocal
goto:eof

:status
call:get_wildfly_state
%_ok% "Wildfly Status: '%WILDFLY_STATE%'"
goto:eof

:run
call:get_wildfly_state
if "%WILDFLY_STATE%" == "running" (
  %_ok% "Wildfly '%WF_VERSION%' already started"
  exit /b 0
)
if "%WILDFLY_STATE%" == "failed" (
  %_fatal% "Wildfly '%WF_VERSION%' failed to start" 121
)
if "%WILDFLY_STATE%" == "not started" (
  %_task% "Must start Wildfly '%WF_VERSION%'"
  call:runWildFly
)
goto:eof

endlocal
goto:eof

:init_mgmt_user
if not exist wildfly_mgmt_user.txt (
  %_fatal% "No wildfly_mgmt_user file present in %CD%" 122
)
for /f "tokens=1,2 delims= " %%a in (wildfly_mgmt_user.txt) do (
  set "WF_MGMT_USER=%%a"
  set "WF_MGMT_PASS=%%b"
)

if not defined WF_MGMT_USER (
  %_fatal% "Could not read username from wildfly_mgmt_user.txt in '%CD%'" 123
)
if not defined WF_MGMT_PASS (
  %_fatal% "Could not read password from wildfly_mgmt_user.txt in '%CD%'" 124
)
%_ok% "Wildfly management user '%WF_MGMT_USER%' and password read from wildfly_mgmt_user.txt"
set "WF_MGMT_USERS_FILE=%WF_HOME%\standalone\configuration\mgmt-users.properties"
if not exist "%WF_MGMT_USERS_FILE%" (
  %_fatal% "No mgmt-users.properties file present in '%WF_MGMT_USERS_FILE%'" 125
)
findstr /i "^%WF_MGMT_USER%=" "%WF_MGMT_USERS_FILE%" >nul
if %errorlevel% equ 0 (
    %_ok% "User "%WF_MGMT_USER%" exists in '%WF_MGMT_USERS_FILE%'"
    exit /b 0
)
%_task% "Must add 'WF_MGMT_USER' to '%WF_MGMT_USERS_FILE%'"
rem https://docs.redhat.com/en/documentation/jboss_enterprise_application_platform_continuous_delivery/12/html/getting_started_guide/administering_jboss_eap#running_the_add_user_utility_non_interactively
rem https://docs.redhat.com/en/documentation/jboss_enterprise_application_platform_continuous_delivery/12/html/getting_started_guide/reference_material#reference_of_add_user_utility_arguments
%_info% "%WF_HOME%\bin\add-user.bat -u %WF_MGMT_USER% -p %WF_MGMT_PASS%"
call "%WF_HOME%\bin\add-user.bat" -u "%WF_MGMT_USER%" -p "%WF_MGMT_PASS%" --silent
if errorlevel 1 (
    %_fatal% "Failed to add user '%WF_MGMT_USER%' to '%WF_MGMT_USERS_FILE%'" 126
)
%_ok% "User '%WF_MGMT_USER%' added to '%WF_MGMT_USERS_FILE%'"
goto:eof

:runWildFly
start /b cmd /c "%WF_HOME%\bin\standalone.bat"
rem -c %STANDALONE_CONF%"

:monitor_wildfly
call :get_wildfly_state
if "%WILDFLY_STATE%"=="running" (
    %_ok% "WildFly started successfully."
    exit /b 0
) else if "%WILDFLY_STATE%"=="failed" (
    %_fatal% "WildFly failed to start." 121
) else (
    %_info% "WildFly state: '%WILDFLY_STATE%'. Waiting..."
    timeout /t 5 >nul  REM Wait for 5 seconds
    goto :monitor_wildfly
)
goto:eof

:get_wildfly_state
set "STATE_TO_CHECK=%~1"
set "WILDFLY_STATE="
if not defined WF_MGMT_USER (
  %_fatal% "An admin user is needed to access console/management and read WildFly state" 131
)
if not defined WF_MGMT_PASS (
  %_fatal% "An admin user is needed to access console/management and read WildFly state" 132
)
set "curl_cmd=C:\Windows\System32\curl.exe -s -L -H "Content-Type: application/json" -d "{\"operation\":\"read-attribute\",\"name\":\"server-state\"}" -u %WF_MGMT_USER%:%WF_MGMT_PASS% -x "" --digest %WF_URL%/management"
rem %_info% "curl_cmd='%curl_cmd:"='%'"
rem echo %curl_cmd%
set "RESPONSE="
for /f "tokens=*" %%i in ('%curl_cmd%') do (
    set "RESPONSE=%%i"
)
if defined RESPONSE (
    set "RESPONSE=%RESPONSE:"=%"
)
rem echo RESPONSE='%RESPONSE%'
rem @echo on
if defined RESPONSE (
    for /f "delims=" %%a in ('echo %RESPONSE% ^| awk "{sub(/}/, \"\", $NF); print $NF}"') do (
        set "WILDFLY_STATE=%%a"
    )
)
rem @echo off

if not defined WILDFLY_STATE ( set "WILDFLY_STATE=not started" )
rem echo.%WILDFLY_STATE%
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

set "WF_ACTION=status"  REM Default value

rem echo args_count='%args_count%', '!args_count!'

if !args_count! == 0 (
    set "WF_ACTION=status"
) else (
    set "WF_ACTION="
    set /a remainder=!args_count! %% 2
    if !remainder! == 0 ( set "WF_ACTION=status" )
)
if not defined WF_ACTION (
  set "WF_ACTION=!param[%args_count%]!"
)
rem echo WF_ACTION='%WF_ACTION%'
rem set "WF_JDK=17"
call:check_param jdk "Must be a version number like 17"
set "jdk_version=%param_value%"
if not exist "%PRGS%\javas\jdk%jdk_version%" (
  %_fatal% "Invalid jdk version '%jdk_version%' (Must be a version number like 17)" 3
)
call switchjdk %jdk_version%
%_ok% "jdk version '%jdk_version%' exists as '%PRGS%\javas\jdk%jdk_version%'"

call:check_param version "Must be a version number like 27"
set "WF_VERSION=%param_value%"
if not exist "%PRGS%\wildflys\wildfly%WF_VERSION%" (
  %_fatal% "Invalid Wildfly version '%WF_VERSION%' (Must be a version number like 27)" 3
)
%_info% "Wildfly version '%WF_VERSION%' selected."

call:check_param url
set "WF_URL=%param_value%"
if not defined wildfly_console_url (
  %_warning% "url param missing (Wildfly console URL). Use http://127.0.0.1:9990"
  set "WF_URL=http://127.0.0.1:9990"
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