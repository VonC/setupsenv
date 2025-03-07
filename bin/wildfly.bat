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

:start
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

:runWildFly
call:prepare_log_for_action
echo wildfly_log_file start='%wildfly_log_file%'
type nul > "%wildfly_log_file%"
start /b cmd /c ""%WF_HOME%\bin\standalone.bat" > "%wildfly_log_file%" 2>&1" 
rem -c %STANDALONE_CONF%"

rem set "ECHO_STATE=ON"
rem @echo on
:monitor_wildfly
call :get_wildfly_state
if "%WILDFLY_STATE%"=="running" (
    %_ok% "WildFly started successfully."
    exit /b 0
) else if "%WILDFLY_STATE%"=="failed" (
    %_fatal% "WildFly failed to start." 121
) else (
    %_info% "WildFly state: '%WILDFLY_STATE%'. Waiting for start..."
    REM Wait for 5 seconds
    C:\Windows\System32\timeout.exe /t 5 >nul
    goto :monitor_wildfly
)
goto:eof


:stop
call:get_wildfly_state
if "%WILDFLY_STATE%" == "not started" (
  %_ok% "Wildfly '%WF_VERSION%' already stopped"
  exit /b 0
)
if "%WILDFLY_STATE%" == "failed" (
  %_fatal% "Wildfly '%WF_VERSION%' failed to stop" 142
)
if "%WILDFLY_STATE%" == "running" (
  %_task% "Must stop Wildfly '%WF_VERSION%'"
  call:stop_wildfly
)
goto:eof

:stop_wildfly
call:prepare_log_for_action
rem @echo on
set "curl_cmd=C:\Windows\System32\curl.exe -s -L -H "Content-Type: application/json" -d "{\"operation\":\"shutdown\"}" -u %WF_MGMT_USER%:%WF_MGMT_PASS% -x "" --digest %WF_URL%/management"
echo wildfly_log_file stop='%wildfly_log_file%'
type nul > "%wildfly_log_file%"
( %curl_cmd% ) >> "%wildfly_log_file%"

:monitor_stopping_wildfly
call :get_wildfly_state
if "%WILDFLY_STATE%"=="not started" (
    %_ok% "WildFly stopped successfully."
    exit /b 0
) else if "%WILDFLY_STATE%"=="failed" (
    %_fatal% "WildFly failed to stop." 141
) else (
    %_info% "WildFly state: '%WILDFLY_STATE%'. Waiting for stop..."
    REM Wait for 5 seconds
    C:\Windows\System32\timeout.exe /t 5 >nul
    goto :monitor_stopping_wildfly
)
goto:eof

:vversion
call:version verbose
goto:eof
:version
set "verbose=%1"
%_task% "Version: Must check WF state first"
call :get_wildfly_state
%_info% "Version: WF state '%WF_STATE%'"
if "%WILDFLY_STATE%"=="running" ( goto:version_running )
set "glob_pattern=%WF_HOME%\modules\system\layers\base\org\jboss\as\ee\main\wildfly-ee-*.Final.jar"
set "WF_EE_JAR="
for /f "delims=" %%a in ('dir /b /a-d "%glob_pattern%"') do (
    set "WF_EE_JAR=%%a"
)
if defined WF_EE_JAR (
    for /f "delims=" %%a in ('echo !WF_EE_JAR! ^| sed -E "s/.*wildfly-ee-(.*).jar/\1/"') do (
        set "WF_EE_VERSION=%%a"
    )
) else (
    %_fatal% "No matching file found for pattern: %glob_pattern%" 171
)
if not defined verbose (
  echo %WF_EE_VERSION%
  exit /b 0
)
set "glob_pattern=%WF_HOME%\modules\system\layers\base\org\wildfly\bootable-jar\main\wildfly-jar-runtime-*.jar"
set "WF_JAR="
for /f "delims=" %%a in ('dir /b /a-d "%glob_pattern%"') do (
    set "WF_JAR=%%a"
)
if defined WF_JAR (
    for /f "delims=" %%a in ('echo !WF_JAR! ^| sed -E "s/.*wildfly-jar-runtime-(.*).jar/\1/"') do (
        set "WF_CORE_VERSION=%%a"
    )
) else (
    %_fatal% "No matching file found for pattern: %glob_pattern%" 172
)
set "manifest_file=%WF_HOME%\modules\system\layers\base\org\jboss\as\product\main\dir\META-INF\MANIFEST.MF"
set "WF_NAME="
for /f "tokens=2 delims=: " %%a in ('findstr "JBoss-Product-Release-Name:" "%manifest_file%"') do set "WF_NAME=%%a"
if not defined WF_NAME (
    %_fatal% "No 'JBoss-Product-Release-Name' found in '%manifest_file%'" 173
)
echo Product name: %WF_NAME%, version: %WF_EE_VERSION%, release version: %WF_CORE_VERSION%
exit /b 0
:version_running
set "curl_cmd=C:\Windows\System32\curl.exe -s -L -H "Content-Type: application/json" -d "{\"operation\":\"read-resource\"}" -u %WF_MGMT_USER%:%WF_MGMT_PASS% -x "" --digest %WF_URL%/management"
rem @echo on
for /f "tokens=*" %%i in ('%curl_cmd%') do (
    rem echo i=%%i
    set "RESPONSE=%%i"
)
rem @echo off
if not defined verbose (
  rem echo echo %RESPONSE% ^| "%PRGS%\jqs\current\jq-win64.exe" -r '.result."product-version"'
  echo %RESPONSE% | "C:\Public\SOFTWARE\jqs\current\jq-win64.exe" -r ".result.\"product-version\""
  exit /b 0
)
echo %RESPONSE% | "C:\Public\SOFTWARE\jqs\current\jq-win64.exe" -r "\"Product name: \" + .result.\"product-name\" + \", version: \" + .result.\"product-version\" + \", release version: \" + .result.\"release-version\""
exit /b 0
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
rem echo RESPONSE0='%RESPONSE%'
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

:prepare_log_for_action
if not defined WF_ACTION (
  %_fatal% "Cannot prepare log if no action" 151
)
for /f %%i in ('bash -c "date +%%Y%%m%%d_%%H%%M%%S"') do set "wildfly_log_timestamp=%%i"
set "wildfly_log_file=wildfly_%WF_VERSION%_%WF_ACTION%_%wildfly_log_timestamp%.log"
set "wildfly_log=wildfly_log_%WF_ACTION% "
if exist %wildfly_log% ( rmdir %wildfly_log% )
rem mklink /J %wildfly_log% %wildfly_log_file%
%_info% "WildFly log for '%WF_ACTION%' is available at '%wildfly_log_file%'"
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
if defined WF_JDK (
  if exist "%PRGS%\javas\jdk%WF_JDK%" (
    if "%JAVA_HOME%" == "%PRGS%\javas\jdk%WF_JDK%" (
      %_info% "JDK '%WF_JDK%' already set as JAVA_HOME"
      goto:check_param_version
    )
  )
)
call:check_param jdk "Must be a version number like 17"
set "jdk_version=%param_value%"
if not exist "%PRGS%\javas\jdk%jdk_version%" (
  %_fatal% "Invalid jdk version '%jdk_version%' (Must be a version number like 17)" 3
)
call switchjdk %jdk_version%
%_ok% "jdk version '%jdk_version%' exists as '%PRGS%\javas\jdk%jdk_version%'"

:check_param_version
if defined WF_VERSION (
  if exist "%PRGS%\wildflys\wildfly%WF_VERSION%" (
      %_info% "Wildfly '%WF_VERSION%' already set"
      goto:check_param_url
  )
)
call:check_param version "Must be a version number like 27"
set "WF_VERSION=%param_value%"
if not exist "%PRGS%\wildflys\wildfly%WF_VERSION%" (
  %_fatal% "Invalid Wildfly version '%WF_VERSION%' (Must be a version number like 27)" 3
)
%_info% "Wildfly version '%WF_VERSION%' selected."

:check_param_url
if defined WF_URL (
      %_info% "Wildfly '%WF_URL%' already set"
      goto:eof
  )
)
call:check_param url
set "WF_URL=%param_value%"
if not defined WF_URL (
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