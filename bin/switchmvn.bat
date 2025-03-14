@echo off
set "M2_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat


:: Find JDKxx folders
set MAVENS_ROOT=%PRGS%\mavens
pushd "%MAVENS_ROOT%"
if errorlevel 1 (
    %_fatal% "Unable to change to MAVENS_ROOT directory '%MAVENS_ROOT%'" 1
)

if not "%1" == "" (
    echo %1| findstr /r "^[0-9].[0-9].[0-9]$" >nul
    if errorlevel 1 (
        %_fatal% "First argument '%1' must be x.y.z, like 3.3.9 or 3.6.0 or 3.9.9" 2
    )
)

set "switchver_todelete=maven"
call "%script_dir%\switchver.bat" mavens mvn "mvn[0-9]\.[0-9]*\.[0-9]*$" "bin\mvn.cmd" "%~1"
set "switchver_todelete="
%_ok% "Maven version chosen: '%SELECTED_VERSION%'"
if defined SWITCHVER_DEBUG (
    %_ok% "Maven PATH updated: '%newPath%'"
)
popd

endlocal & set "M2_HOME=%PRGS%\mavens\%SELECTED_VERSION%" & set "M2=%PRGS%\mavens\%SELECTED_VERSION%\bin" & set "PATH=%newPath%" & set "MVN_VERSION=%SELECTED_VERSION:mvn=%"
rem echo M2_HOME='%M2_HOME%'
where mvn 2>nul | findstr cmd >nul 2>nul
if errorlevel 1 (
    set "PATH=%M2%;%PATH%"
)
exit /b 0
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
