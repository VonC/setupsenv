@echo off

if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "echos_standalone=%~dp0standalone_%~nx0.flag"

rem Temp files must be unique per terminal (SENV_UID set by senv.bat): a shared name
rem lets one tab delete the list while another tab is still reading it.
if not defined SENV_UID set "SENV_UID=%RANDOM%%RANDOM%"
set "svtmp=%TEMP%\switchver_%SENV_UID%"

set "usage="
set "prgs_name=%~1"
if "%prgs_name%"=="" (
    %_error% "switchver first param prgs_name (ex: 'pythons' or 'javas') is MISSING"
    set "usage=1"
)
if not "%prgs_name:~-1%"=="s" (
    %_error% "switchver first param prgs_name must ends with an s (ex: 'pythons' or 'javas')"
    set "usage=1"
)
set "prg_prefix=%~2"
if "%prg_prefix%"=="" (
    %_error% "switchver second param prg_prefix (ex: 'py' or 'jdk') is MISSING"
    set "usage=1"
)
set "prg_pattern=%~3"
if "%prg_pattern%"=="" (
    %_error% "switchver third param prg_pattern (ex: 'python[2-9].[0-9]*$' '^jdk[0-9][0-9]*$') is MISSING"
    set "usage=1"
)
set "prg_exe=%~4"
if "%prg_exe%"=="" (
    %_error% "switchver fourth param prg_exe (ex: 'java' 'python', do not add the '.exe') is MISSING"
    set "usage=1"
)
set "prg_version=%~5"
if defined usage (
    :: Example: switchver pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python
    %_fatal% "Usage: switchver prgs_name prg_prefix prg_pattern prg_exe [prg_version]" 2
)
set "usage="
set "PRGS_ROOT=%PRGS%\%prgs_name%"

if not exist "%PRGS_ROOT%" (
    mkdir "%PRGS_ROOT%"
    if errorlevel 1 (
        %_fatal% "Unable to create PRGS_ROOT directory '%PRGS_ROOT%'" 1
    )
    %_ok% "Created PRGS_ROOT directory '%PRGS_ROOT%'"
)
pushd "%PRGS_ROOT%"
if errorlevel 1 (
    %_fatal% "Unable to change to PRGS_ROOT directory '%PRGS_ROOT%'" 1
)


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
rem %_fatal% "prgs_name='%prgs_name%' vs. prg_name=%prg_name%'" 1

pushd %PRGS_ROOT%
if errorlevel 1 %_fatal% "unable to cd to PRGS_ROOT '%PRGS_ROOT%'" 1
%_info% "Switch Ver from PRGS_ROOT '%PRGS_ROOT%'"
rem A pinned version needs no listing: when its folder is there, take it. That
rem keeps the choice deterministic and never reaches the gum prompt, whatever
rem the shared temp files below are doing in a tab that starts at the same time.
if "%prg_version%"=="" goto:no_pinned_version
if not exist "%PRGS_ROOT%\%prg_prefix%%prg_version%\" goto:no_pinned_version
set "SELECTED_VERSION=%prg_prefix%%prg_version%"
popd
goto:selected
:no_pinned_version
rem set ECHO_STATE=ON
rem @echo on
rem Initialize counter
set count=0
set SELECTED_VERSION=
set PRG_VERSIONS=
:: on suspended process, see
:: https://superuser.com/questions/1469567/executable-gets-suspended-when-called-from-batch-script
:: https://www.dostips.com/forum/viewtopic.php?t=8940
:: Write the %prg_prefix%* list to a file
dir /b "%prg_prefix%*" > "%svtmp%_list.tmp"
: Filter the entries using findstr and write to another file
findstr /r "%prg_pattern%" "%svtmp%_list.tmp" > "%svtmp%_filtered_list.tmp"
:: Read the filtered entries from the file and process them
for /f "delims=" %%i in ('type "%svtmp%_filtered_list.tmp"') do (
    set "PRG_VERSIONS=!PRG_VERSIONS! %%i"
    set /a count+=1
    if "%%i" == "%prg_prefix%%prg_version%" (
        set "SELECTED_VERSION=%%i"
    )
)
popd
rem %_info% "switchver_list.tmp:"
rem type "%svtmp%_list.tmp"
rem %_info% "switchver_filtered_list.tmp:"
rem type "%svtmp%_filtered_list.tmp"
rem %_ok% "PRG_VERSIONS='%PRG_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%', count=%count%."
del "%svtmp%_list.tmp" "%svtmp%_filtered_list.tmp"
rem %_fatal% "stop" 1
rem echo "PRG_VERSIONS='%PRG_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%'"

if not "%SELECTED_VERSION%" == "" ( goto:selected )
if not "%prg_version%" == "" (
    %_warning% "Your %prg_name% version argument '%prg_version%' was NOT found in PRGS_ROOT '%PRGS_ROOT%' (prg_prefix='%prg_prefix%')"
)

:: if count == 1, set SELECTED_VERSION to PRG_VERSIONS, and trim any space
if %count% equ 1 (
    %_info% "Only one %prg_name% version found: '%PRG_VERSIONS: =%'"
    for %%v in (%PRG_VERSIONS%) do (
        set "SELECTED_VERSION=%%~v"
    )
    goto:selected
)

if not defined SWITCHVER_DWL_INST (
    %_post% "SWITCHVER_DWL_INST not defined: no download/installation attempted"
    %_warning% "No prg_version '%prg_version%' version found in '%PRGS_ROOT%'" 3
) else (
    %_post% "SWITCHVER_DWL_INST defined"
    %_error% "No prg_version '%prg_version%' version found in '%PRGS_ROOT%'"
    call "%script_dir%\dwl_inst_ver.bat" %prg_name% %prg_version%
    if errorlevel 1 (
        %_error% "Unable to download prg_name '%prg_name%' at prg_version '%prg_version%'"
    ) else (
        %_ok% "switchver can proceed"
        set "SELECTED_VERSION=%prg_prefix%%prg_version%"
        goto:selected
    )
)

rem %_info% "PRG_VERSIONS='%PRG_VERSIONS%', SELECTED_VERSION='%SELECTED_VERSION%'"
if "%SELECTED_VERSION%" == "" (
    %_task% "Select %prg_name% version amongst '%count%' available"
    :: Use gum for selection
    set "gum=%PRGS%\gums\current\gum.exe"
    for /f "tokens=*" %%a in ('!gum! choose %PRG_VERSIONS%') do set SELECTED_VERSION=%%a
)

:selected

if "%SELECTED_VERSION%" == "" (
    %_fatal% "No %prg_name% version selected for PRGS_ROOT '%PRGS_ROOT%'" 3
)
%_ok% "%prg_name% version chosen: '%SELECTED_VERSION%'"
rem @echo on
:clean_path
set "newPath="
rem Test if `where prg_exe` is equal to %PRGS%\prgs_name\%SELECTED_VERSION%
rem echo PRGS\prgs_name\SELECTED_VERSION\prg_exe = '%PRGS%\%prgs_name%\%SELECTED_VERSION%\%prg_exe%'
for %%f in ("%prg_exe%") do set "prg_exe_file=%%~nxf"
rem echo prg_exe_file='%prg_exe_file%'
for /f "tokens=*" %%j in ('where %prg_exe_file% 2^>NUL') do (
    if "%%j" == "%PRGS%\%prgs_name%\%SELECTED_VERSION%\%prg_exe%" (
        set "newPath=%PATH%"
    )
)

if not "%newPath%" == "" (
    %_ok% "%prg_name% '%SELECTED_VERSION%' already in PATH"
    goto:skip_clean_path
)

%_task% "Must clean PATH from any '%PRGS%\%prgs_name%' occurrence"
set "current_path="
:: Write the PATH variable to a file, splitting at semicolons
(for %%a in ("%PATH:;=" "%") do echo %%~a) > "%svtmp%_path_list.tmp"
:: Filter out entries containing %PRGS%\%prgs_name%
if not defined switchver_todelete (
    set "switchver_todelete=%PRGS%\%prgs_name%"
)
rem echo findstr /V /C:"\%prg_name%" "%svtmp%_path_list.tmp"
findstr /I /V /C:"%switchver_todelete%" "%svtmp%_path_list.tmp" > "%svtmp%_filtered_path_list.tmp"
set "switchver_todelete="
ping -n 1 -w 300 127.0.0.1 > nul
:: Read the filtered entries from the file and reconstruct newPath
for /f "delims=" %%i in ('type "%svtmp%_filtered_path_list.tmp"') do (
    if "!newPath!" == "" (
        set "newPath=%%i"
    ) else (
        set "newPath=!newPath!;%%i"
    )
)
if defined SWITCHVER_DEBUG (
    %_info% "Cleaned newPath='%newPath%'
)
rem %_info% "switchver_path_list.tmp:"
rem type "%svtmp%_path_list.tmp"
rem %_info% "switchver_filtered_path_list.tmp:"
rem type "%svtmp%_filtered_path_list.tmp"
del "%svtmp%_path_list.tmp" "%svtmp%_filtered_path_list.tmp"
rem %_fatal% "stop" 1

set "current_path="
:skip_clean_path
endlocal & set "SELECTED_VERSION=%SELECTED_VERSION%" & set "newPath=%newPath%"
popd
rem echo [%~nx0] SELECTED_VERSION='%SELECTED_VERSION%'
rem echo [%~nx0] newPath='%newPath%'
rem goto:eof
if exist "%~dp0standalone_%~nx0.flag" (
    echo [%~nx0] newPath='!newPath!';
    set "newPath="
    echo [%~nx0] SELECTED_VERSION='%SELECTED_VERSION%'.
    set "SELECTED_VERSION="
    del "%~dp0standalone_%~nx0.flag"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
