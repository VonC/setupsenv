@echo off

:loop
tasklist /FI "IMAGENAME eq px.exe" | findstr /I "px.exe" > nul
if errorlevel 1 (
    echo No more instances of px.exe found.
    exit /b
)

echo Killing px.exe...
taskkill /F /IM px.exe >nul 2>&1
C:\Windows\System32\timeout.exe /t 1 >nul
goto loop
