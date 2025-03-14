@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

if "%~1"=="/i" (
  set "case_insensitive=/I "
  shift
)

set ASCII27=
rem set ASCII27=← 

REM Set the variable with colored text
set "red_bg_white_text=%ASCII27%[41;97m[X]%ASCII27%[0m"
set "yellow_bg_white_text=%ASCII27%[43;97m[?]%ASCII27%[0m"
REM Combine the variables
set "colored_text=%red_bg_white_text% %yellow_bg_white_text%"
REM Echo the variable
rem echo %colored_text%

:: Get User PATH from Registry
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH ^| findstr /i PATH') do set "user_path=%%b"

:: Get System PATH from Registry
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path ^| findstr /i Path') do set "system_path=%%b"

set "local_path=%PATH%"

:: Display Local PATH
set "prefix=LOCAL : "
if "%~1"=="" (
  %_ok% "Local PATH:"
  set "prefix="
)
rem @echo on
call :filter_path "%local_path%" %*

:: Display User PATH
set "prefix=USER  : "
if "%~1"=="" (
  %_info% "User PATH:"
  set "prefix="
)
rem @echo on
call :filter_path "%user_path%" %*

:: Display System PATH
set "prefix=SYSTEM: "
if "%~1"=="" (
  %_warning% "System PATH:"
  set "prefix="
)
call :filter_path "%system_path%" %*

goto:eof

:filter_path
set "path_to_filter=%~1"
shift
rem set "user_path=%%USERPROFILE%%\go\bin"
rem @echo on
for %%u in ("%path_to_filter:;=" "%") do (
    REM Remove first and last character of %%u
    set "modified_u=%%~u"
    rem set "modified_u=!modified_u:~1,-1!"
    call set "expanded_u=!modified_u!"
    set "expanded="
    set "error="
    if not "!expanded_u!"=="!modified_u!" (
      set "expanded= == !expanded_u!"
    )
    if exist "!expanded_u!" (
        dir /a:d "!expanded_u!" >nul 2>&1
        if errorlevel 1 (
            set "error= %yellow_bg_white_text%"
        )
    ) else (
      set "error= %red_bg_white_text%"
    )
    rem echo %prefix%!modified_u!!expanded! xxx
    call :contains_all_params %%u %1 %2 %3 %4 %5 %6 %7 %8 %9
    if not errorlevel 1 (
        echo %prefix%!modified_u!!expanded!!error!
    ) else (
      if not "!expanded_u!"=="!modified_u!" (
        rem echo must test '!modified_u:%%=_!'
        call :contains_all_params "!modified_u:%%=_!" %*
        if not errorlevel 1 (
            echo %prefix%!modified_u!!expanded!!error! _
        )
      )
    )
)
goto:eof

REM Function to check if all parameters are found in %%u
:contains_all_params
set "line=%~1"
if "!line!"=="" (
    if defined SENV_PPATH_DEBUG ( %_error% "[contains_all_params] empty line. [SENV_PPATH_DEBUG]" )
    exit /b 1
)
shift
if "%~1"=="/i" (
    shift
)
:check_next_param
if "%~1"=="" (
    if defined SENV_PPATH_DEBUG ( %_ok% "[contains_all_params] empty param for line '%line%' [SENV_PPATH_DEBUG]" )
    del /Q /F "%script_dir%\ppath.tmp" 2>NUL
    exit /b 0
)
echo !line!> "%script_dir%\ppath.tmp"
findstr %case_insensitive%/c:"%~1" "%script_dir%\ppath.tmp" >nul
if errorlevel 1 (
    @echo off
    if defined SENV_PPATH_DEBUG ( %_warning% "[contains_all_params] does not find param '%~1' into line '!line!' [SENV_PPATH_DEBUG]" )
    exit /b 1
)
if defined SENV_PPATH_DEBUG ( %_ok% "[contains_all_params] empty first param for line '%line%' [SENV_PPATH_DEBUG]" )
shift
goto:check_next_param
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
