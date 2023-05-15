@echo off
setlocal enabledelayedexpansion

if "%script_dir%" == "" (
    for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
    call !script_dir!\..\batcolors\echos_macros.bat export
)

:detect_drive
set "driveUNCPath=%1"
rem https://stackoverflow.com/questions/1964192/removing-double-quotes-from-variables-in-batch-file-creates-problems-with-cmd-en
set driveUNCPath=%driveUNCPath:"=%
set "driveUNCPathEsc=%driveUNCPath:\=\\%"
set "driveUNCPathEsc=%driveUNCPathEsc:$=\$%"
rem echo driveUNCPath='%driveUNCPath%', driveUNCPathEsc='%driveUNCPathEsc%'

:search_driveLetter
set "driveLetter="
set "drRefresh="
for /f "tokens=* delims=" %%i in ('net use') do (
    set "drRefresh="
    echo %%i | findstr "%driveUNCPathEsc% " > NUL
    if not errorlevel 1 (
        rem @echo on
        set "dr=%%i"
        rem echo possible drive='!dr!'
        set "drRefresh="
        for /f "tokens=1,2,3,4 delims= " %%j in ('echo !dr!') do (
            rem echo j='%%j', k='%%k', l='%%l', m='%%m'
            set "f=%%j"
            set "drl=%%j"
            set "drp=%%k"
            set "drRefresh="
            if "!f!" == "Non" (
                set "drRefresh=1"
                set "drl=%%l"
                set "drp=%%m"
            ) else (
                if "!f::=!" == "%%j" (
                    set "drRefresh=1"
                    set "drl=%%k"
                    set "drp=%%l"
                )
            )
            if "%%j" == "OK" (
                set "drRefresh="
            )
            rem set "res=!dr::=" & set "res=!!"
            call :substr "!dr!" "!drl!"
            set "eeee=!eeee:"=!"
            rem echo "eeee1='!eeee!'"
            set "eeee=!eeee:Microsoft Windows Network=!"
            rem echo "eeee2='!eeee!'"
            call :trimSpace "!eeee!"
            rem echo xxxx2 xxxx '!eeee!'
            set "drp=!eeee!"
        )
        rem @echo off
        rem echo drl='!drl!', drp='!drp!' ^(drRefresh='!drRefresh!'^) vs driveUNCPath '%driveUNCPath%'
        if "!drp!" == "%driveUNCPath%" (
            set "driveLetter=!drl!"
            goto:found
        )
    )
)
:found
if not "%driveLetter%" == "" ( goto:drive_found )
%_warning% "No drive letter found for driveUNCPath '%driveUNCPath%'"
:: Test if UNC path is accessible by using dir command
dir /b "%unc_path%" >nul 2>nul || ( %_fatal% "Directory '%driveUNCPath%' is not accessible." 119 )
%_task% "Directory '%driveUNCPath%' is accessible. Attempting to map drive..."
net use * "%driveUNCPath%" >nul 2>nul
set "NEEL=%ERRORLEVEL%"
if "%NEEL%"=="0" (
    %_ok% "Drive mapped successfully for driveUNCPath '%driveUNCPath%'."
    goto:search_driveLetter
) else (
    %_fatal% "Failed to map drive for driveUNCPath '%driveUNCPath%'. Exiting..." %NEEL%
)

:drive_found
%_info% "Drive found for '%driveUNCPath%': '%driveLetter%'"
if not "%drRefresh%" == "" (
    %_task% "Must refresh '%driveLetter%'"
    call :ActivateMappedNetworkDrive "%driveLetter%"
    dir "%driveLetter%" 1>NUL 2>NUL
    if errorlevel 1 (
        %_fatal% "Unable to access drive letter '%driveLetter%' for driveUNCPath '%driveUNCPath%'" 118
    )
    %_ok% "Drive letter '%driveLetter%' for driveUNCPath '%driveUNCPath%' refreshed and accessible"
)

set "dl=%script_dir:\custom=%\driverLetter.bat"
echo @echo off>"%dl%"
echo set "driveLetter=%driveLetter%">>"%dl%"
endlocal & set driveLetter=%driveLetter%

goto:eof

rem https://stackoverflow.com/questions/1964192/removing-double-quotes-from-variables-in-batch-file-creates-problems-with-cmd-en
:substr
set "s=%1"
set s=%s:"=%"
set "res=%s::=" & set "res=%%"
rem https://stackoverflow.com/questions/3001999/how-to-remove-trailing-and-leading-whitespace-for-user-provided-input-in-a-batch
set "eeee=%res%"
rem echo ==== '%eeee%'
goto:eof


:ActivateMappedNetworkDrive
set PROCESSNAME=explorer.exe
set PREFIX=start /min
set SUFFIX=%1

rem echo ~~~~~~~~~~~~~~~azerty
rem First save current pids with the wanted process name
set "RETPIDS="
set "OLDPIDS=p"
for /f "TOKENS=1" %%a in ('wmic PROCESS where "Name='%PROCESSNAME%'" get ProcessID ^| findstr [0-9]') do (set "OLDPIDS=!OLDPIDS!%%ap")

rem Spawn new process(es)
%PREFIX% %PROCESSNAME% %SUFFIX%

rem Wait for a second (may be optional)
REM choice /c x /d x /t 1 > nul
C:\Windows\System32\timeout.exe /t 5 > NUL

rem Check and find processes missing in the old pid list
for /f "TOKENS=1" %%a in ('wmic PROCESS where "Name='%PROCESSNAME%'" get ProcessID ^| findstr [0-9]') do (
if "!OLDPIDS:p%%ap=zz!"=="%OLDPIDS%" (set "RETPIDS=/PID %%a !RETPIDS!")
)

rem Kill the new threads (but no other)
taskkill %RETPIDS% /T > NUL 2>&1
goto:eof

:trimSpace
set "s=%1"
set "s=%s:"=%"
rem echo TRIM '%s%'
rem for /f "tokens=*" %%i in ('echo %s%') do set trimmed=%%~nxi
rem https://stackoverflow.com/questions/3001999/how-to-remove-trailing-and-leading-whitespace-for-user-provided-input-in-a-batch
for /f "tokens=*" %%i in ('echo %s%') do set j=%%i
set trimmed=%j:~0,-1%
set "eeee=%trimmed%"
rem echo TRIMMED '%eeee%'
goto:eof
