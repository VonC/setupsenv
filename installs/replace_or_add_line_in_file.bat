@echo off
setlocal enabledelayedexpansion

rem Define the function
:replace_line
set "old_line=%~1"
set "new_line=%~2"
set "filename=%~3"
set "tempfile=%filename%.tmp"

set "pattern=%new_line%"
if not "%new_line:set #=%"=="%new_line%" ( set "new_line=%new_line:#="%" )
echo new_line='%new_line%' 1>&2
if not "%old_line:set #=%"=="%old_line%" ( 
    set "old_line1=!old_line:set #=set !" 
    set "old_line1=!old_line1:#="!" 
    set "old_line2=!old_line:set #=set "!" 
    set "old_line2=!old_line2:#=!" 
    set "old_line2=!old_line2!"" 
    set "old_line=%old_line:#=%" 
)
echo old_line='%old_line%' 1>&2
echo old_line1='%old_line1%' 1>&2
echo old_line2='%old_line2%' 1>&2
REM goto:eof
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
@echo off

set found=false
set found_new=false
set found_old=false
for /f "usebackq tokens=*" %%a in ("%filename%") do (
    set "line=%%a"
    rem echo line='!line!' so minus old_line '%old_line%' ==== '!line:%old_line%=!'
    rem echo !line!|findstr /C:"!old_line!" >nul 
    rem echo "errorlevel='!errorlevel!' for line '!line!'"
    echo !line!|findstr /C:"!old_line!" >nul 
    if !errorlevel! equ 0 (
        set found=true
    ) else (
        if not "!old_line1!"=="" (
            echo !line!|findstr /C:"!old_line1!" >nul 
            if !errorlevel! equ 0 (
                set found=true
                set "old_line=!old_line1!"
            ) else (
                if not "!old_line2!"=="" (
                    echo !line!|findstr /C:"!old_line2!" >nul 
                    if !errorlevel! equ 0 (
                        set found=true
                        set "old_line=!old_line2!"
                    )
                )
            )
        )
    )

    if "!found!"=="true" (
        echo !new_line!>>"%tempfile%"
        set found_old=true
        set found=false
    ) else (
        echo !line!>>"%tempfile%"
    )
    
    rem echo "LINE        : !line!"
    rem echo "vs new line : !new_line!"
    rem echo "--------------"
    rem echo echo !line!^|findstr /C:^"!new_line!^" 
    rem echo !line!|findstr /C:"!new_line!" >nul 
    rem if !errorlevel! equ 0 (
    if "!line!"=="!new_line!" (
        set found_new=true
        %_ok% "Pattern F '!pattern!' found in filename '!filename!', found_new true"
    ) else (
        %_info% "Pattern NF '!pattern!'  in filename '!filename!', found_new remains '!found_new!'"
    )
)

if not "%found_old%"=="true" (
    if not "!found_new!"=="true" (
        %_ok% "Pattern '!pattern!' not found in filename '%filename%', adding it"
        echo %new_line%>>"%tempfile%"
    ) else (
        %_ok% "Pattern '%pattern%' found in filename '%filename%', nothing to do"
    )
) else (
    %_ok% "Pattern '!old_line!' found in filename '%filename%', replaced with '!new_line!'"
)

move /y "%tempfile%" "%filename%" >nul
goto :eof
