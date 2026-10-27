@echo off
setlocal
rem PowerShell reads -h and --help as parameter names: both become /?.
if /i "%~1"=="-h" goto:usage
if /i "%~1"=="--help" goto:usage
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0last-screenshots.ps1" %*
exit /b %ERRORLEVEL%

:usage
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0last-screenshots.ps1" /?
exit /b %ERRORLEVEL%
