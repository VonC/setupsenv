@REM ********************************************************************
@REM * GCM - Git Commit Message (Generator)
@REM * 
@REM * This script makes a commit with the message passed in parameters,
@REM * or generates a commit message based on staged changes using AI,
@REM * depending on said parameters.
@REM *
@REM * See:
@REM * - gsh.bat -h
@REM *
@REM * Usage:
@REM *   gcm         - Call gsh.bat (Git Smart Helper) to analyse staged changes
@REM *   gcm x y z   - Make a commit with message 'x y z'
@REM *                 unless params are limited to:
@REM *                 'doc(s)', 'rel', 'context', 'prompt', 'dump', 'txt' or 'md'
@REM ********************************************************************

@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

REM If no parameters, just call gsh without parameters
if "%~1"=="" (
    call "%script_dir%\gsh.bat"
    exit /b %errorlevel%
)

REM Check if all parameters are special keywords
set "all_special=true"
set "params="

:check_params
if "%~1"=="" goto :done_checking
set "param_special="
if /i "%~1"=="doc" set "param_special=true"
if /i "%~1"=="docs" set "param_special=true"
if /i "%~1"=="rel" set "param_special=true"
if /i "%~1"=="context" set "param_special=true"
if /i "%~1"=="prompt" set "param_special=true"
if /i "%~1"=="dump" set "param_special=true"
if /i "%~1"=="txt" set "param_special=true"
if /i "%~1"=="md" set "param_special=true"

if not defined param_special (
    set "all_special="
)

set "params=%params% %~1"
shift
goto :check_params

:done_checking
REM Remove leading space from params
set "params=%params:~1%"

REM If all parameters are special, call gsh with those parameters
if "%all_special%"=="true" (
    %_task% "Calling gsh.bat with parameters: %params%"
    call "%script_dir%\gsh.bat" %params%
    exit /b %errorlevel%
) else (
    REM Otherwise, perform git commit with the message
    git commit -m "%params%"
    exit /b %errorlevel%
)
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: call_echos_stack
@REM
@REM Handles script tracing and logging by integrating with an external echo
@REM utility for better debugging and error reporting. It checks if the ECHOS_STACK
@REM variable is defined and either sets the current script name or calls the
@REM echos.bat script with the current script name.
@REM
@REM Parameters: None
@REM Returns: None
@REM -----------------------------------------------------------------------------
:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" && goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
