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
call "%script_dir%\switchver.bat" nodes node "node[2-9]*$" NODE "%~1"
set "switchver_todelete="
%_ok% "[%~nx0] Node version chosen: '%SELECTED_VERSION%'"
set "NODE_HOME=%PRGS%\nodes\%SELECTED_VERSION%"
set "NODE_VERSION=3%SELECTED_VERSION:*3=%"
popd

endlocal & set "NODE_HOME=%NODE_HOME%" & set "NODE_VERSION=%NODE_VERSION%" & set "PATH=%newPath%"

set "PATH=%NODE_HOME%;%PATH%"