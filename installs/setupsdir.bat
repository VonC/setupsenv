@echo off

set "setupsdir="
set "setupsdirsenv="

setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& goto:endlocalko
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
cd /d "%script_dir%"
call %senv_dir%\batcolors\echos_macros.bat
set "custom_dir=%script_dir%"

%_info% "[%~nx0] called as: setupsdir.bat %1 %2 %3"

set "profile=%1"
rem https://stackoverflow.com/questions/1964192/removing-double-quotes-from-variables-in-batch-file-creates-problems-with-cmd-en
if not defined profile (
    %_fatal% "[%~nx0] first parameter must be provided (profile)" 1
)
set profile=%profile:"=%

set "driveUNCPath=%2"
rem https://stackoverflow.com/questions/1964192/removing-double-quotes-from-variables-in-batch-file-creates-problems-with-cmd-en
if not defined driveUNCPath (
    %_fatal% "[%~nx0] second parameter must be provided (driveUNCPath)" 1
)
set driveUNCPath=%driveUNCPath:"=%
set driveUNCPath=%driveUNCPath:^==%


set "localPath=%3"
rem https://stackoverflow.com/questions/1964192/removing-double-quotes-from-variables-in-batch-file-creates-problems-with-cmd-en
if not defined localPath (
    %_fatal% "[%~nx0] third parameter must be provided (localPath)" 1
)
set localPath=%localPath:"=%


if "%localPath%"=="." (
    set "localPath=\"
) else (
    set "localPath=\%localPath%\"
)

if "%senvname%"=="" ( set "senvname=senv" )

set "SKIPPED_PROFILES_FILE=%senv_dir%\builds\skipped_profiles.txt"
set "skipped_profile="
:: Check if the profile is in the skipped profiles file and capture the full line
for /f "tokens=*" %%A in ('findstr /i /c:"[%profile%]" "%SKIPPED_PROFILES_FILE%" 2^>nul') do (
    set "skipped_profile=%%A"
)
if defined skipped_profile (
    %_info% "[%~nx0] (SENV_PUBLISH_FORCE_RECHECK=%SENV_PUBLISH_FORCE_RECHECK%)"
    if "%SENV_PUBLISH_FORCE_RECHECK%"=="%profile%" (
        %_task% "[%~nx0] Must force re-check of profile '%profile%' (marked as skipped: '%skipped_profile%')"
        goto:recheck
    )
    if "%SENV_PUBLISH_FORCE_RECHECK%"=="all" (
        %_task% "[%~nx0] Must force re-check of all profiles ('%profile%' marked as skipped: '%skipped_profile%')"
        goto:recheck
    )
    set "errorMessage=Profile path is marked as SKIPPED: %skipped_profile%"
    goto:endlocal_ko_noadd
) else (
    %_ok% "[%~nx0] Profile '%profile%' is not marked as skipped (SENV_PUBLISH_FORCE_RECHECK='%SENV_PUBLISH_FORCE_RECHECK%')"
)

:recheck
if not "%UNCPathOnly%"=="" (
    set "setupsdir=%driveUNCPath%%localPath%%senvname%\setups"
    goto:endlocal
)

%_task% "[%~nx0] [drive detection] Must test access to driveUNCPath '%driveUNCPath%'"
dir "%driveUNCPath%" 1>NUL: 2>NUL:
if errorlevel 1 (
    set "errorMessage=Unable to access network UNC path '%driveUNCPath%'"
    goto:endlocalko
)
%_ok% "[%~nx0] driveUNCPath '%driveUNCPath%' is accessible"

call "%senv_dir%\installs\drive_detection.bat" "%driveUNCPath%"
set "dl=%custom_dir%\driverLetter.bat"
%_info% "[%~nx0] === first call to drive_detection: type '%dl%'"
rem type "%dl%"
call "%dl%"
del "%dl%"
rem %_info% "[%~nx0] RES driveLetter='%driveLetter%'"
if "%driveLetter%"=="" (
    %_warning% "[%~nx0] [%profile%] Must map '%driveUNCPath%' to a drive letter:"
    net use * "%driveUNCPath%" /PERSISTENT:YES
    if errorlevel 1 (
        %_warning% "[%~nx0] [%profile%] Unable to map '%driveUNCPath%' to a drive letter" 112
        goto:networkPathOnly
    )
    call "%senv_dir%\installs\drive_detection.bat" "%driveUNCPath%"
    %_info% "[%~nx0] === second callgi to drive_detection: type '%custom_dir%\driverLetter.bat'"
    type "%custom_dir%\driverLetter.bat"
    call "%custom_dir%\driverLetter.bat"
    del "%custom_dir%\driverLetter.bat"
    set drive
    if "%driveLetter%"=="" (
        set "errorMessage=Unable to find drive letter for '%driveUNCPath%'"
        goto:endlocalko
    )
)

if not "%driveLetter%"=="" (
    set "setupsdir=%driveLetter%%localPath%%senvname%\setups"
    set "setupsdirsenv=%driveLetter%%localPath%%senvname%"
    dir "!setupsdir!" 1>NUL: 2>NUL:
    if errorlevel 1 (
        %_warning% "[%~nx0] [%profile%] UNABLE to access drive path '!setupsdir!' with driveLetter '%driveLetter%'. Fall back to network path '%driveUNCPath%' for setup"
        set "driveLetter="
    ) else (
        %_ok% "[%~nx0] [%profile%] Able to access drive path '!setupsdir!' with driveLetter '%driveLetter%'"
    )
)
:networkPathOnly
if "%driveLetter%"=="" (
    set "setupsdir=%driveUNCPath%%localPath%%senvname%\setups"
    set "setupsdirsenv=%driveUNCPath%%localPath%%senvname%"
    dir "!setupsdir!" 1>NUL: 2>NUL:
    if errorlevel 1 (
        set "errorMessage=Unable to access network path '!setupsdir!'"
        goto:endlocalko
    )
)
goto:endlocal

:endlocalko
echo [%profile%] %errorMessage%>> "%SKIPPED_PROFILES_FILE%"
:endlocal_ko_noadd
set "setupsdir="
set "setupsdirsenv="
%_error% "[%~nx0] [%profile%] %errorMessage%"
endlocal & set "setupsdir=" & set "setupsdirsenv="
exit /b 1
goto:eof

:endlocal
set "temp_file=%senv_dir%\builds\skipped_profiles.tmp"

:: Check if the skipped profiles file exists
if exist "%skipped_profiles_file%" (
    :: Filter out the line containing [%profile%] and write to a temporary file
    findstr /v /c:"[%profile%]" "%skipped_profiles_file%" > "%temp_file%"

    :: Replace the original file with the temporary file
    move /y "%temp_file%" "%skipped_profiles_file%" >nul
)
:endlocalnoclean
endlocal & set "setupsdir=%setupsdir%" & set "setupsdirsenv=%setupsdirsenv%"