@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
if exist %script_dir%\..\batcolors (
  call %script_dir%\..\batcolors\echos_macros.bat
) else if exist %script_dir%\batcolors (
  call %script_dir%\batcolors\echos_macros.bat
) else if exist %script_dir%\echos_macros.bat (
  call %script_dir%\echos_macros.bat
) else (
  echo "batcolor not found in script_dir '%script_dir%'" >&2
  endlocal
  exit /b 1
)

if "%~1"=="/i" (
  set "case_insensitive=/I "
  shift
)

:: Get User PATH from Registry
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH ^| findstr /i PATH') do set "user_path=%%b"

:: Get System PATH from Registry
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path ^| findstr /i Path') do set "system_path=%%b"

:: Display User PATH
set "prefix=USER  : "
if "%~1"=="" (
  %_info% "User PATH:"
  set "prefix="
)
rem set "user_path=%%USERPROFILE%%\go\bin"
rem @echo on
for %%u in ("%user_path:;=" "%") do (
    REM Remove first and last character of %%u
    set "modified_u=%%u"
    set "modified_u=!modified_u:~1,-1!"
    call set "expanded_u=!modified_u!"
    set "expanded="
    if not "!expanded_u!"=="!modified_u!" (
      set "expanded= == !expanded_u!"
    )
    rem echo %prefix%!modified_u!!expanded! xxx
    call :contains_all_params %%u %*
    if not errorlevel 1 (
        echo %prefix%!modified_u!!expanded!
    ) else (
      if not "!expanded_u!"=="!modified_u!" (
        rem echo must test '!modified_u:%%=_!'
        call :contains_all_params "!modified_u:%%=_!" %*
        if not errorlevel 1 (
            echo %prefix%!modified_u!!expanded! _
        )
      )
    )
)

:: Display System PATH
set "prefix=SYSTEM: "
if "%~1"=="" (
  %_warning% "System PATH:"
  set "prefix="
)
for %%s in ("%system_path:;=" "%") do (
    REM Remove first and last character of %%s
    set "modified_s=%%s"
    set "modified_s=!modified_s:~1,-1!"
    call set "expanded_s=!modified_s!"
    set "expanded="
    if not "!expanded_s!"=="!modified_s!" (
      set "expanded= == !expanded_s!"
    )
    rem echo %prefix%!modified_s!!expanded! xxx
    call :contains_all_params %%s %*
    if not errorlevel 1 (
        echo %prefix%!modified_s!!expanded!
    ) else (
      if not "!expanded_s!"=="!modified_s!" (
        rem echo must test '!modified_s:%%=_!'
        call :contains_all_params "!modified_s:%%=_!" %*
        if not errorlevel 1 (
            echo %prefix%!modified_s!!expanded! _
        )
      )
    )
)
goto:eof

REM Function to check if all parameters are found in %%u
:contains_all_params
set "line=%~1"
if "!line!"=="" (
    exit /b 1
)
shift
if "%~1"=="/i" (
    shift
)
:check_next_param
if "%~1"=="" (
    exit /b 0
)
echo !line! | findstr %case_insensitive%/c:"%~1" >nul
if errorlevel 1 (
    @echo off
    exit /b 1
)
shift
goto:check_next_param