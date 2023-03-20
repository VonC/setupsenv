@echo off
setlocal enabledelayedexpansion

rem Define the function
:replace_line
set "old_line=%~1"
set "new_line=%~2"
set "filename=%~3"
set "tempfile=%filename%.tmp"
del "%tempfile%" 2>nul

if "%_ok%"=="" ( set _ok=echo )
if "%_info%"=="" ( set _info=echo )
if "%_warning%"=="" ( set _warning=echo )
if "%_task%"=="" ( set _task=echo )
if "%_error%"=="" ( set _error=echo )
if "%_fatal%"=="" ( set _fatal=echo )

%_task% "Check for pattern '%old_line%' in filename '%filename%', updated to '%new_line%'"
if not exist "%filename%" (
    "%_ok%" "filename '%filename%' does not exist, nothing to do"
    goto :eof
)

set found=false
set found_new=false
for /f "usebackq tokens=*" %%a in ("%filename%") do (
    set "line=%%a"
    rem echo line='!line!' so minus old_line '%old_line%' ==== '!line:%old_line%=!'
    rem echo !line!|findstr /C:"!old_line!" >nul 
    rem echo "errorlevel='!errorlevel!' for line '!line!'"
    echo !line!|findstr /C:"!old_line!" >nul 
    if !errorlevel! equ 0 (
        set found=true
        echo !new_line!>>"%tempfile%"
    ) else (
        echo !line!>>"%tempfile%"
    )
    
    echo !line!|findstr /C:"!new_line!" >nul 
    if !errorlevel! equ 0 (
        set found_new=true
    )
)

if not "%found%"=="true" (
    if not "%found_new%"=="true" (
        %_ok% "Pattern '%old_line%' not found in filename '%filename%', add '%new_line%'"
        echo %new_line%>>"%tempfile%"
    ) else (
        %_ok% "Pattern '%new_line%' found in filename '%filename%', nothing to do"
    )
) else (
    %_ok% "Pattern '%old_line%' found in filename '%filename%', replaced with '%new_line%'"
)

move /y "%tempfile%" "%filename%" >nul
goto :eof
