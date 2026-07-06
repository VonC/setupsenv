@echo off
set "JAVA_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "usage="
set "JDK_VERSION=%~1"
if defined JDK_VERSION (
    echo %1| findstr /r "^[0-9]*$" >nul
    if errorlevel 1 (
        %_error% "First argument JDK_VERSION '%JDK_VERSION%' must be x, like 8 or 11 or 17 as version of JDK" 2
        set "usage=1"
    )
)
if defined usage (
    %_fatal% "Usage: switchjdk [15 or 17 for JDK version] -- no version to chose amongst installed ones." 2
)
set "usage="


set "switchver_todelete=java"
call "%script_dir%\switchver.bat" javas jdk "jdk[0-9]*$" "bin\java.exe" "%JDK_VERSION%"
set "switchver_todelete="
%_ok% "Java version chosen: '%SELECTED_VERSION%'"

set "must_switchjdk="
set "jdk_bin_path=%PRGS%\javas\%SELECTED_VERSION%\bin"
set "path_prefix=%PRGS%\javas"

set "path_check_awk_file=%script_dir%\path_check.awk"
rem Temp file unique per terminal (SENV_UID set by senv.bat) and outside the current
rem directory: a fixed name in the project dir collides across concurrent tabs.
if not defined SENV_UID set "SENV_UID=%RANDOM%%RANDOM%"
set "path_temp=%TEMP%\switchjdk_path_%SENV_UID%.tmp"
echo %PATH%> "%path_temp%"
set "awk_path_prefix=%path_prefix:\=\\\\%"
set "awk_jdk_bin_path=%jdk_bin_path:\=\\\\%"
rem echo awk -v prefix="%awk_path_prefix%" -v jdk_bin_path="%awk_jdk_bin_path%" -f "%path_check_awk_file%" "%path_temp%"
for /f "delims=" %%a in ('awk -v prefix^="%awk_path_prefix%" -v jdk_bin_path^="%awk_jdk_bin_path%" -f "%path_check_awk_file%" "%path_temp%"') do (
    set "complete_output=%%a"
)
del "%path_temp%"
rem %_info% "complete_output='%complete_output%'" 

REM Split the output at the special separator
for /f "tokens=1,2 delims=#@#" %%b in ("!complete_output!") do (
    set "filtered_path=%%b"
    set "flags=%%c"
)
if not defined filtered_path (
    %_fatal% "Unable to filter PATH" 4
)
if "%filtered_path:\=%" == "%filtered_path%" (
    %_fatal% "Unable to detect PATH in filtered_path '%filtered_path%'" 5
)

set "jdk_path_found="
set "multiple_paths_found="
REM Extract individual flags
set "jdk_path_found=!flags:~0,1!"
set "multiple_paths_found=!flags:~1,1!"

rem %_info% "jdk_bin_path='%jdk_bin_path%'"
rem %_info% "filtered_path='%filtered_path%'"
rem %_info% "jdk_path_found='%jdk_path_found%'"
rem  %_info% "multiple_paths_found='%multiple_paths_found%'"

:clean_path
set "JAVA_HOME=%PRGS%\javas\%SELECTED_VERSION%"

set "newPath=%filtered_path%"

if "%jdk_path_found%" == "1" (
    set "msg=Java '%SELECTED_VERSION%' already in PATH"
) else (
    set "newPath=%JAVA_HOME%\bin;%filtered_path%"
    set "msg=Java '%SELECTED_VERSION%' added to PATH"
)
if "%multiple_paths_found%" == "1" (
    set "msg=%msg%, other '%PRGS%\javas' paths removed"
)
%_ok% "%msg%"

:skip_clean_path
endlocal & set "JAVA_HOME=%PRGS%\javas\%SELECTED_VERSION%" & set "JAVA_VERSION=%SELECTED_VERSION:jdk=%" & set "PATH=%newPath%" 
rem echo JAVA_HOME='%JAVA_HOME%'
rem where java
rem echo PATH='%PATH%'
exit /b 0
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
