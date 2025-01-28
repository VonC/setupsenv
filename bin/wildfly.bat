@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

set "WF_JDK=17"
call:check_param jdk
set "jdk_version=%param_output%"

if "%jdk_version%"=="" (
  %_fatal% "Missing first mandatory parameter (e.g. Java version number like 17)" 2
)
set "jdk_version=%~1"
if not exist "%PRGS%\javas\jdk%jdk_version%" (
  %_fatal% "Invalid jdk version '%jdk_version%' (Must be a version number like 17)" 3
)

goto:eof

:check_param
set "param_name=%1"
for /f %%A in ('powershell -command "('%param_name%').ToUpper()"') do set "param_name_upper=%%A"
echo param_name_upper=%param_name_upper%

if defined WF_%param_name_upper% (
    set "param_value=!WF_%param_name_upper%!"
    %_ok% "Environment variable 'WF_%param_name_upper%' set to '!param_value!'"
) else (
    %_ok% "No 'WF_%param_name_upper%' set. Look for a '--%param_name=' argument"
)


goto:eof