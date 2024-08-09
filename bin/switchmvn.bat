@echo off
set "M2_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir_bin%\echos_macros.bat

:: Find JDKxx folders
set MAVENS_ROOT=%PRGS%\mavens
pushd "%MAVENS_ROOT%"
if errorlevel 1 (
    %_fatal% "Unable to change to MAVENS_ROOT directory '%MAVENS_ROOT%'" 1
)

if not "%1" == "" (
    echo %1| findstr /r "^mvn[0-9].[0-9].[0-9]$" >nul
    if errorlevel 1 (
        %_fatal% "First argument '%1' must be mvnx.y.z, like mvn3.3.9 or mvn3.6.0" 2
    )
)

rem Initialize counter
set count=0
set SELECTED_VERSION=
set MAVEN_VERSIONS=
for /d %%f in (mvn*) do (
    set "dirname=%%~nxf"
    rem %_info% "dirname='!dirname!'"
    echo !dirname!| findstr /r "^mvn[0-9].[0-9].[0-9]$" >nul
    if not errorlevel 1 (
        set "MAVEN_VERSIONS=!MAVEN_VERSIONS! %%f"
        set /a count+=1
        if "%%f" == "%1" (
            set "SELECTED_VERSION=%%f"
        )
    )
)
popd

if "%SELECTED_VERSION%" == "" (
    if not "%1" == "" (
        %_warning% "Your Maven version argument '%1' was NOT found in '%MAVENS_ROOT%'"
    )
)

:: if count == 1, set SELECTED_VERSION to MAVEN_VERSIONS, and trim any space
if %count% equ 1 (
    %_info% "Only one Maven version found: '%MAVEN_VERSIONS: =%'"
    for %%v in (%MAVEN_VERSIONS%) do (
        set "SELECTED_VERSION=%%~v"
    )
    goto:selected
)

rem %_info% "MAVEN_VERSIONS='%MAVEN_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%'"
if "%SELECTED_VERSION%" == "" (
    %_task% "Select Maven version amongst '%count%' available"
    :: Use gum for selection
    set "gum=%PRGS%\gums\current\gum.exe"
    for /f "tokens=*" %%a in ('!gum! choose %MAVEN_VERSIONS%') do set SELECTED_VERSION=%%a
)
:selected
%_ok% "Maven version chosen: '%SELECTED_VERSION%'"



:clean_path
set "M2_HOME=%PRGS%\mavens\%SELECTED_VERSION%"

set "newPath="
rem Test if `where mvn` is equal to %PRGS%\mavens\%SELECTED_VERSION%
for /f "tokens=*" %%j in ('where mvn^|findstr cmd') do (
    if "%%j" == "%PRGS%\mavens\%SELECTED_VERSION%\bin\mvn.cmd" (
        set "newPath=%PATH%"
    )
)

if not "%newPath%" == "" (
    %_ok% "Maven '%SELECTED_VERSION%' already in PATH"
    goto:skip_clean_path
)

set "current_path="
rem echo PATH='%PATH%'
:: Split the PATH variable at semicolons and echo each part
for %%a in ("%PATH:;=" "%") do (
    set "current_path=%%~a"
    echo !current_path!| findstr /C:"%PRGS%\mavens" >nul
    if not !errorlevel! equ 0 (
        if "!newPath!" == "" (
            set "newPath=!current_path!"
        ) else (
            set "newPath=!newPath!;!current_path!"
        )
    )
)
rem echo newPath='%newPath%'
set "newPath=%M2_HOME%\bin;%newPath%"
set "current_path="
:skip_clean_path
endlocal & set "M2_HOME=%PRGS%\mavens\%SELECTED_VERSION%" & set "M2=%M2_HOME%\bin" & set "PATH=%newPath%" & set "MVN_VERSION=%SELECTED_VERSION:mvn=%"
echo M2_HOME='%M2_HOME%'
where mvn | findstr cmd
rem echo PATH='%PATH%'
