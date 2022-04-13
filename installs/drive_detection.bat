@echo off
setlocal enabledelayedexpansion

:detect_drive
set "driveUNCPath=%1"
rem https://stackoverflow.com/questions/1964192/removing-double-quotes-from-variables-in-batch-file-creates-problems-with-cmd-en
set driveUNCPath=%driveUNCPath:"=%
set "driveUNCPathEsc=%driveUNCPath:\=\\%"
rem echo driveUNCPath='%driveUNCPath%', driveUNCPathEsc='%driveUNCPathEsc%'

set "driveLetter="
for /f "tokens=* delims=" %%i in ('net use') do (
    echo %%i | findstr "%driveUNCPathEsc% " > NUL
    if not errorlevel 1 (
        set "dr=%%i"
        rem echo possible drive='!dr!'
        rem @echo on
        for /f "tokens=1,2,3 delims= " %%j in ('echo !dr!') do (
            rem echo drletter='%%j'
            set "f=%%j"
            if not "!f::=!" == "%%j" (
                rem echo 'drpath ='%%k'
                if "%%k" == "%driveUNCPath%" (
                    set "driveLetter=%%j"
                    goto:found
                )
            ) else (
                rem echo 'drpath ='%%k'
                if "%%l" == "%driveUNCPath%" (
                    set "driveLetter=%%k"
                    goto:found
                )
            )
        )
        rem @echo off
    )
)
:found
%_info% "Drive found for '%driveUNCPath%': '%driveLetter%'"
endlocal & set driveLetter=%driveLetter%