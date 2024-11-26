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
    %_fatal% "[%~nx0] Unable to change to MAVENS_ROOT directory '%MAVENS_ROOT%'" 1
)

if not "%1" == "" (
    echo %1| findstr /r "^[0-9].[0-9].[0-9]$" >nul
    if errorlevel 1 (
        %_fatal% "[%~nx0] First argument '%1' must be x.y.z, like 3.3.9 or 3.6.0 or 3.9.9" 2
    )
)

set "switchver_todelete=maven"
call "%script_dir%\switchver.bat" mavens mvn "mvn[0-9]\.[0-9]*\.[0-9]*$" "bin\mvn.cmd" "%~1"
set "switchver_todelete="
%_ok% "[%~nx0] Node version chosen: '%SELECTED_VERSION%'"
set "NODE_HOME=%PRGS%\nodes\%SELECTED_VERSION%"
set "NODE_VERSION=3%SELECTED_VERSION:*3=%"
popd

endlocal & set "M2_HOME=%PRGS%\mavens\%SELECTED_VERSION%" & set "M2=%PRGS%\mavens\%SELECTED_VERSION%\bin" & set "PATH=%newPath%" & set "MVN_VERSION=%SELECTED_VERSION:mvn=%"
echo M2_HOME='%M2_HOME%'
where mvn | findstr cmd
