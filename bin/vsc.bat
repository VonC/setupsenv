@echo off

set "standalone_call=true"
if defined script_dir (
  set "standalone_call="
)

rem https://www.yworks.com/resources/yed/demo/yEd-3.24.zip
rem <a href="/products/yed">yEd Graph Editor 3.24</a> at https://www.yworks.com/downloads#yEd

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
set "bc=%senv_dir%\batcolors"
call %bc%\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

rem get the name of the current folder (pwd, or %cd%)
for %%i in ("%cd%") do (
    set "current_folder=%%~nxi"
)

if exist "%cd%\.vscode\*%current_folder%.code-workspace" (
  rem resolve "%cd%\.vscode\*%current_folder%.code-workspace"
  for %%i in ("%cd%\.vscode\*%current_folder%.code-workspace") do (
    set "workspace_file=%%~fi"
  )
) else (
    set "workspace_file=%cd%\.vscode\%current_folder%.code-workspace"
)

if exist "%workspace_file%" goto:_workspace_found


REM Check if there are any .code-workspace files in the .vscode folder
if not exist "%cd%\.vscode\*.code-workspace" (
  call:unset
  %_fatal% "workspace file not found: '%workspace_file%'" 3
  goto:eof
)

REM Count .code-workspace files
set "workspace_count=0"
set "single_workspace="
for %%i in ("%cd%\.vscode\*.code-workspace") do (
  set /a "workspace_count+=1"
  set "single_workspace=%%~fi"
)

REM If exactly one workspace file exists
if "%workspace_count%"=="1" (
  %_warn% "Expected workspace file '%workspace_file%' not found, but using the only available: '%single_workspace%'"
  set "workspace_file=%single_workspace%"
  goto:_workspace_found
)

REM If multiple workspace files exist, list them
if %workspace_count% gtr 1 (
  %_error% "Multiple workspace files found in %cd%\.vscode\:"
  for %%i in ("%cd%\.vscode\*.code-workspace") do (
    %_info% " - %%~nxi"
  )
  call:unset
  %_fatal% "Please keep only one workspace file" 9
  goto:eof
)

call:unset
%_fatal% "workspace file not found: '%workspace_file%'" 3
goto:eof


:_workspace_found
if exist "%cd%\senv.bat" (
  %_task% "Must call '%cd%\senv.bat'"
  call "%cd%\senv.bat"
  if errorlevel 1 (
    call:unset
    %_fatal% "error calling '%cd%\senv.bat'" 4
  ) else (
    call "%bc%\echos_macros.bat"
    %_ok% "called '%cd%\senv.bat'"
  )
)

if exist "%cd%\tools\init.bat" (
  %_task% "Must call '%cd%\tools\init.bat'"
  call "%cd%\tools\init.bat"
  if errorlevel 1 (
    call:unset
    %_fatal% "error calling '%cd%\tools\init.bat'" 5
  ) else (
    call "%bc%\echos_macros.bat"
    %_ok% "called '%cd%\tools\init.bat'"
  )
)

%_info% "workspace_file: '%workspace_file%'"
if exist "%workspace_file%" (
  %_task% "Must open workspace file: '%workspace_file%'"
  call "%PRGS%\vscodes\current\bin\code.cmd" -- "%workspace_file%"
  if errorlevel 1 (
    call:unset
    %_fatal% "error opening workspace file: '%workspace_file%'" 2
  )
  %_ok% "opened workspace file: '%workspace_file%'"
) else (
  %_error% "workspace file not found: '%workspace_file%'"
)

:unset
if defined standalone_call (
  set "script_dir="
)
set "standalone_call="
set "workspace_file="
set "current_folder="
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
