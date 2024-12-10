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



:clean_path
set "JAVA_HOME=%PRGS%\javas\%SELECTED_VERSION%"

set "newPath="
rem Test if `where java` is equal to %PRGS%\javas\%SELECTED_VERSION%
for /f "tokens=*" %%j in ('where java 2^>NUL') do (
    if "%%j" == "%PRGS%\javas\%SELECTED_VERSION%\bin\java.exe" (
        set "newPath=%PATH%"
    )
)

if not "%newPath%" == "" (
    %_ok% "[%~nx0] Java '%SELECTED_VERSION%' already in PATH"
    goto:skip_clean_path
)

set "current_path="
rem echo PATH='%PATH%'
rem for /f "tokens=*" %%a in ('set PATH ^| sed "s,%PRGS%\pythons,,g"') do ( set "newPath=%%a" )
:: Split the PATH variable at semicolons and echo each part
for %%a in ("%PATH:;=" "%") do (
    set "current_path=%%~a"
    echo !current_path!| findstr /C:"%PRGS%\javas" >nul
    if not !errorlevel! equ 0 (
        if "!newPath!" == "" (
            set "newPath=!current_path!"
        ) else (
            set "newPath=!newPath!;!current_path!"
        )
    )
)
rem echo newPath='%newPath%'
set "newPath=%JAVA_HOME%\bin;%newPath%"
set "current_path="
:skip_clean_path
endlocal & set "JAVA_HOME=%PRGS%\javas\%SELECTED_VERSION%" & set "PATH=%newPath%" & set "JAVA_VERSION=%SELECTED_VERSION:jdk=%"
echo JAVA_HOME='%JAVA_HOME%'
where java
rem echo PATH='%PATH%'
exit /b 0