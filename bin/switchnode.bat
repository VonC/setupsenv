@echo off
set "NODE_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

:: Find Nodes 2x.x.y folders
set NODE_ROOT=%PRGS%\nodes
pushd %NODE_ROOT%

set "switchver_todelete=node"
call "%script_dir%\switchver.bat" nodes node "node[0-9]*$" npm.cmd "%~1"
set "switchver_todelete="
%_ok% "Node version chosen: '%SELECTED_VERSION%'"
if defined SWITCHVER_DEBUG (
  %_ok% "Node PATH updated: '%newPath%'"
)
set "NODE_HOME=%PRGS%\nodes\%SELECTED_VERSION%"
set "NODE_VERSION=%SELECTED_VERSION%"
popd

endlocal & set "NODE_HOME=%NODE_HOME%" & set "NODE_VERSION=%NODE_VERSION%" & set "PATH=%newPath%"
where node 2>nul | findstr exe >nul 2>nul
if errorlevel 1 (
    set "PATH=%NODE_HOME%;%PATH%"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
