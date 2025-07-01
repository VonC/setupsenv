@echo off
set "WF_VERSION="
set "WF_JDK="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "usage="
set "WF_VERSION=%1"
if defined WF_VERSION (
    echo %1| findstr /r "^[0-9]*$" >nul
    if errorlevel 1 (
        %_error% "First argument WF_VERSION '%WF_VERSION%' must be xyz, like 25 or 26 as version of Wildfly" 2
        set "usage=1"
    )
) else (
    %_error% "First argument WF_VERSION is MISSING, like 25 or 26 as version of Wildfly"
    set "usage=1"
)
set "WF_JDK=%2"
if defined WF_JDK (
    echo %1| findstr /r "^[0-9]*$" >nul
    if errorlevel 1 (
        %_error% "First argument WF_VERSION '%WF_JDK%' must be xyz, like 11 or 17 as version of JDK" 3
        set "usage=1"
    )
) else (
    %_error% "Second argument WF_JDK is MISSING, like 11 or 17 as version of JDK"
    set "usage=1"
)
if defined usage (
    %_fatal% "Usage: switchwf 26 17 for Wildfly 26 with jdk 17" 2
)
set "usage="

set "switchver_todelete=wildfly"
call "%script_dir%\switchver.bat" wildflys wildfly "wildfly[0-9]*$" "bin\standalone.bat" "%~1"
set "switchver_todelete="
%_post% "Use wildfly.bat (alias wf) to start/stop/status the Wildfly server"
%_ok% "Wildly version chosen: '%SELECTED_VERSION%', WF_JDK='%WF_JDK%'"
rem if defined SWITCHVER_DEBUG (
rem     %_ok% "Maven PATH updated: '%newPath%'"
rem )
popd

endlocal & set "WF_VERSION=%SELECTED_VERSION:wildfly=%" & set "WF_JDK=%WF_JDK%" & set "WF_HOME=%PRGS%\wildflys\wildfly%WF_VERSION%"
rem echo M2_HOME='%M2_HOME%'
exit /b 0
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
