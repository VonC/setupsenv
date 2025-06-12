@echo off
setlocal enabledelayedexpansion

REM Get script directory for locating support files
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do (set senv_dir=%%f)
call %senv_dir%\batcolors\echos_macros.bat

REM Check if drive letter was provided
if "%~1"=="" (
    %_fatal% "No drive letter provided. Usage: refresh_drive.bat X:" 1
    exit /b 1
)

REM Get drive letter parameter and ensure it has proper format
set "driveLetter=%~1"
if "%driveLetter:~-1%" NEQ ":" set "driveLetter=%driveLetter%:"

%_info% "Checking drive letter '%driveLetter%'"

REM Extract UNC path for the drive regardless of Windows language
set "tempFile=%TEMP%\net_use_output.txt"
net use %driveLetter% > "%tempFile%" 2>NUL
if errorlevel 1 (
    del "%tempFile%" 2>NUL
    %_fatal% "Drive letter '%driveLetter%' is not mapped to a network location" 111
)
REM Get the second line which contains the UNC path regardless of language
for /f "skip=1 tokens=* delims=" %%a in (%tempFile%) do (
    set "line=%%a"
    goto :got_second_line
)
:got_second_line
del "%tempFile%" 2>NUL

REM Extract the UNC path (starts with \\)
for /f "tokens=1,* delims=\" %%b in ("%line%") do (
    set "uncPath=\\%%c"
)

%_info% "Drive '%driveLetter%' is mapped to UNC path: '%uncPath%'"

REM Check if drive is already accessible
dir "%driveLetter%" 1>NUL 2>NUL
if not errorlevel 1 (
    %_ok% "Drive letter '%driveLetter%' (%uncPath%) is already accessible"
    goto :eof
)

%_task% "Drive needs refreshing, attempting to refresh drive letter '%driveLetter%' (%uncPath%)"

REM Activate the mapped drive
call :ActivateMappedNetworkDrive "%driveLetter%"

REM Check if drive is accessible
dir "%driveLetter%" 1>NUL 2>NUL
if errorlevel 1 (
    %_fatal% "Unable to access drive letter '%driveLetter%' (%uncPath%)" 1
    exit /b 1
) else (
    %_ok% "Drive letter '%driveLetter%' (%uncPath%) refreshed and accessible"
)

exit /b 0

:ActivateMappedNetworkDrive
set PROCESS_NAME=explorer.exe
set PREFIX=start /min
set SUFFIX=%1

rem First save current pids with the wanted process name
set "RET_PIDS="
set "OLD_PIDS=p"
for /f "TOKENS=1" %%a in ('wmic PROCESS where "Name='%PROCESS_NAME%'" get ProcessID ^| findstr [0-9]') do (set "OLD_PIDS=!OLD_PIDS!%%ap")

rem Spawn new process(es)
%PREFIX% %PROCESS_NAME% %SUFFIX%

rem Wait for processes to start
C:\Windows\System32\timeout.exe /t 5 > NUL

rem Check and find processes missing in the old pid list
for /f "TOKENS=1" %%a in ('wmic PROCESS where "Name='%PROCESS_NAME%'" get ProcessID ^| findstr [0-9]') do (
if "!OLD_PIDS:p%%ap=zz!"=="%OLD_PIDS%" (set "RET_PIDS=/PID %%a !RET_PIDS!")
)

rem Kill the new threads (but no other)
taskkill %RET_PIDS% /T > NUL 2>&1
goto:eof