@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

@echo on
REM Initialize parameter array
set "args_count=0"
for %%a in (%*) do (
    set /a args_count+=1
    set "param[!args_count!]=%%a"
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

@echo on
REM Loop over parameters
for /L %%i in (1,2,!args_count!) do (
    set "current_param=!param[%%i]!"
    REM Check if the parameter starts with param_name=
    if "!current_param!"=="!param_name!" (
        set "value=!param[%%i+1]!"
        
        REM Trim leading spaces
        for /f "tokens=* delims= " %%x in ("!value!") do set "value=%%x"
        
        REM Trim trailing spaces (up to 10 spaces)
        for /L %%x in (1,1,10) do (
            if "!value:~-1!"==" " set "value=!value:~0,-1!"
        )
        
        REM Assign the trimmed value to a variable
        set "extracted_value=!value!"
        echo Extracted value: "!extracted_value!"
    )
    
    echo Parameter %%i: !current_param!
    REM Add your processing here
)

goto:eof