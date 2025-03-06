@echo off
set "JAVA_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

:: Find JDKxx folders
set JAVA_ROOT=%PRGS%\javas
pushd "%JAVA_ROOT%"
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to change to JAVA_ROOT directory '%JAVA_ROOT%'" 1
)

if not "%1" == "" (
    echo %1| findstr /r "^[0-9][0-9]*$" >nul
    if errorlevel 1 (
        %_fatal% "[%~nx0] First argument '%1' must be a jdk version, like 8 or 17" 2
    )
)

rem Initialize counter
set count=0
set SELECTED_VERSION=
set JAVA_VERSIONS=
for /d %%f in (jdk*) do (
    set "dirname=%%~nxf"
    rem %_info% "[%~nx0] dirname='!dirname!'"
    echo !dirname!| findstr /r "^jdk[0-9][0-9]*$" >nul
    if not errorlevel 1 (
        set "JAVA_VERSIONS=!JAVA_VERSIONS! %%f"
        set /a count+=1
        if "%%f" == "jdk%1" (
            set "SELECTED_VERSION=%%f"
        )
    )
)
popd

if "%SELECTED_VERSION%" == "" (
    if not "%1" == "" (
        %_warning% "[%~nx0] Your Java version argument '%1' was NOT found in JAVA_ROOT '%JAVA_ROOT%'"
    )
)

:: if count == 1, set SELECTED_VERSION to JAVA_VERSIONS, and trim any space
if %count% equ 1 (
    %_info% "[%~nx0] Only one Java version found: '%JAVA_VERSIONS: =%'"
    for %%v in (%JAVA_VERSIONS%) do (
        set "SELECTED_VERSION=%%~v"
    )
    goto:selected
)

if %count% equ 0 (
    %_fatal% "[%~nx0] No Java version found in '%JAVA_ROOT%'" 3
)

rem %_info% "[%~nx0] JAVA_VERSIONS='%JAVA_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%'"
if "%SELECTED_VERSION%" == "" (
    %_task% "[%~nx0] Select Java version amongst '%count%' available"
    :: Use gum for selection
    set "gum=%PRGS%\gums\current\gum.exe"
    for /f "tokens=*" %%a in ('!gum! choose %JAVA_VERSIONS%') do set SELECTED_VERSION=%%a
)

:selected

if "%SELECTED_VERSION%" == "" (
    %_fatal% "[%~nx0] No Java version selected for JAVA_ROOT '%JAVA_ROOT%'" 3
)
%_ok% "[%~nx0] Java version chosen: '%SELECTED_VERSION%'"

set "must_switchjdk="
set "jdk_bin_path=%PRGS%\javas\%SELECTED_VERSION%\bin"
set "path_prefix=%PRGS%\javas"

set "path_check_awk_file=%script_dir%\path_check.awk"
echo %PATH%> "path_temp.txt"
set "awk_path_prefix=%path_prefix:\=\\\\%"
set "awk_jdk_bin_path=%jdk_bin_path:\=\\\\%"
rem echo awk -v prefix="%awk_path_prefix%" -v jdk_bin_path="%awk_jdk_bin_path%" -f "%path_check_awk_file%" path_temp.txt
for /f "delims=" %%a in ('awk -v prefix^="%awk_path_prefix%" -v jdk_bin_path^="%awk_jdk_bin_path%" -f "%path_check_awk_file%" path_temp.txt') do (
    set "complete_output=%%a"
)
del path_temp.txt
rem %_info% "complete_output='%complete_output%'" 

REM Split the output at the special separator
for /f "tokens=1,2 delims=#@#" %%b in ("!complete_output!") do (
    set "filtered_path=%%b"
    set "flags=%%c"
)
if not defined filtered_path (
    %_fatal% "[%~nx0] Unable to filter PATH" 4
)
if "%filtered_path:\=%" == "%filtered_path%" (
    %_fatal% "[%~nx0] Unable to detect PATH in filtered_path '%filtered_path%'" 5
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