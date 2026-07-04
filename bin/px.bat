@echo off

tasklist /FI "IMAGENAME eq px.exe" | findstr /I "px.exe" > nul
@REM if errorlevel 0 and if not errorlevel 1 are not the same. 
@REM In batch scripts, if errorlevel N checks if the error level is N or greater. So, if errorlevel 0 would always be true because the error level is always 0 or greater.
@REM On the other hand, if not errorlevel 1 checks if the error level is less than 1. This means that it will only be true when the error level is 0.
@REM So, to check for an error level of exactly 0, you should use if not errorlevel 1.
if not errorlevel 1 (
    echo px.exe is already running.
    goto:eof
)
echo Starting px.exe...
start /b %PRGS%\pxs\current\px.exe --config=%HOME%\px.ini

goto:waitone

wscript //B //nologo px.vbs %*

where powershell >nul 2>&1
if errorlevel 1 (
    echo PowerShell not found. Please install PowerShell or add it to your PATH.
    exit /b 1
)

powershell.exe -ExecutionPolicy Bypass -File .\px.ps1 %*

:waitone
C:\Windows\System32\timeout.exe /t 4 >nul
echo.
