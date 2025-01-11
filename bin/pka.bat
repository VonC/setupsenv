@echo off

:loop
tasklist /FI "IMAGENAME eq %~1" | findstr /I "%~1%" > nul
if errorlevel 1 (
    echo No more instances of '%~1' found.
    exit /b
)

echo Killing '%~1'...
taskkill /F /IM "%~1" >nul 2>&1
C:\Windows\System32\timeout.exe /t 1 >nul
goto loop
