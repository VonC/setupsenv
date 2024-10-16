@echo off

if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "echos_standalone=%~dp0standalone_%~nx0.flag"

set "usage="
set "prgs_name=%~1"
if "%prgs_name%"=="" (
    %_error% "[%~nx0] switchver first param prgs_name (ex: 'pythons' or 'javas') is MISSING"
    set "usage=1"
)
if not "%prgs_name:~-1%"=="s" (
    %_error% "[%~nx0] switchver first param prgs_name must ends with an s (ex: 'pythons' or 'javas')"
    set "usage=1"
)
set "prg_prefix=%~2"
if "%prg_prefix%"=="" (
    %_error% "[%~nx0] switchver second param prg_prefix (ex: 'py' or 'jdk') is MISSING"
    set "usage=1"
)
set "prg_pattern=%~3"
if "%prg_pattern%"=="" (
    %_error% "[%~nx0] switchver third param prg_pattern (ex: 'python[2-9].[0-9]*$' '^jdk[0-9][0-9]*$') is MISSING"
    set "usage=1"
)
set "prg_exe=%~4"
if "%prg_exe%"=="" (
    %_error% "[%~nx0] switchver fourth param prg_exe (ex: 'java' 'python', do not add the '.exe') is MISSING"
    set "usage=1"
)
set "prg_version=%~5"
if defined usage (
    :: Example: switchver pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python
    %_fatal% "[%~nx0] Usage: switchver prgs_name prg_prefix prg_pattern prg_exe [prg_version]" 2
)
set "usage="
set "PRGS_ROOT=%PRGS%\%prgs_name%"

:: Extract the first letter
set "first_letter=%prgs_name:~0,1%"
:: Convert the first letter to uppercase
for %%a in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if /i "%%a"=="%first_letter%" set "first_letter=%%a"
)
:: Concatenate the uppercase first letter with the rest of the string
set "prg_name=%first_letter%%prgs_name:~1%"
:: Remove the last letter 
set "prg_name=%prg_name:~0,-1%"
rem %_fatal% "[%~nx0] prgs_name='%prgs_name%' vs. prg_name=%prg_name%'" 1

pushd %PRGS_ROOT% || %_fatal% "[%~nx0] unable to cd to PRGS_ROOT '%PRGS_ROOT%'" 1
%_info% "[%~nx0] Switch Ver from PRGS_ROOT '%PRGS_ROOT%'"
rem @echo on
rem Initialize counter
set count=0
set SELECTED_VERSION=
set PRG_VERSIONS=
:: on suspended process, see
:: https://superuser.com/questions/1469567/executable-gets-suspended-when-called-from-batch-script
:: https://www.dostips.com/forum/viewtopic.php?t=8940
for /d %%f in (%prg_prefix%*) do (
    set "dirname=%%~nxf"
    rem %_info% "[%~nx0] dirname='!dirname!'"
    echo !dirname!| findstr /r "%prg_pattern%" >nul
    if not errorlevel 1 (
        set "PRG_VERSIONS=!PRG_VERSIONS! %%f"
        set /a count+=1
        if "%%f" == "%prg_prefix%%prg_version%" (
            set "SELECTED_VERSION=%%f"
        )
    )
)
popd
echo "PRG_VERSIONS='%PRG_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%'"

if not "%SELECTED_VERSION%" == "" ( goto:selected )
if not "%prg_version%" == "" (
    %_warning% "[%~nx0] Your %prg_name% version argument '%prg_version%' was NOT found in PRGS_ROOT '%PRGS_ROOT%'"
)

:: if count == 1, set SELECTED_VERSION to PRG_VERSIONS, and trim any space
if %count% equ 1 (
    %_info% "[%~nx0] Only one %prg_name% version found: '%PRG_VERSIONS: =%'"
    for %%v in (%PRG_VERSIONS%) do (
        set "SELECTED_VERSION=%%~v"
    )
    goto:selected
)

if %count% equ 0 (
    %_fatal% "[%~nx0] No %prg_version% version found in '%PRGS_ROOT%'" 3
)

rem %_info% "[%~nx0] PRG_VERSIONS='%PRG_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%'"
if "%SELECTED_VERSION%" == "" (
    %_task% "[%~nx0] Select %prg_name% version amongst '%count%' available"
    :: Use gum for selection
    set "gum=%PRGS%\gums\current\gum.exe"
    for /f "tokens=*" %%a in ('!gum! choose %PRG_VERSIONS%') do set SELECTED_VERSION=%%a
)

:selected

if "%SELECTED_VERSION%" == "" (
    %_fatal% "[%~nx0] No %prg_name% version selected for PRGS_ROOT '%PRGS_ROOT%'" 3
)
%_ok% "[%~nx0] %prg_name% version chosen: '%SELECTED_VERSION%'"
@echo on
:clean_path
set "newPath="
rem Test if `where prg_exe` is equal to %PRGS%\prgs_name\%SELECTED_VERSION%
for /f "tokens=*" %%j in ('where %prg_exe%') do (
    if "%%j" == "%PRGS%\%prgs_name%\%SELECTED_VERSION%\bin\%prg_exe%.exe" (
        set "newPath=%PATH%"
    )
)

if not "%newPath%" == "" (
    %_ok% "[%~nx0] %prg_name% '%SELECTED_VERSION%' already in PATH"
    goto:skip_clean_path
)

set "current_path="
rem echo PATH='%PATH%'
rem for /f "tokens=*" %%a in ('set PATH ^| sed "s,%PRGS%\pythons,,g"') do ( set "newPath=%%a" )
:: Split the PATH variable at semicolons and echo each part
for %%a in ("%PATH:;=" "%") do (
    set "current_path=%%~a"
    echo !current_path!| findstr /C:"%PRGS%\%prgs_name%" >nul
    if not !errorlevel! equ 0 (
        if "!newPath!" == "" (
            set "newPath=!current_path!"
        ) else (
            set "newPath=!newPath!;!current_path!"
        )
    )
)
rem echo newPath='%newPath%'
set "current_path="
:skip_clean_path
endlocal & set "newPath=%newPath%" & set "SELECTED_VERSION=%SELECTED_VERSION%"
popd
if exist "%~dp0standalone_%~nx0.flag" (
    echo newPath='%newPath%'
    set "newPath="
    echo SELECTED_VERSION='%SELECTED_VERSION%'
    set "SELECTED_VERSION="
    del "%~dp0standalone_%~nx0.flag"
)
