@echo off
setlocal
rem ghwatched.bat - list the starred GitHub repositories watched with a custom
rem setting (releases, security alerts...), filtered by words if any are given.
rem The work is done by ghwatched.ps1; 'ghwatched -h' prints its usage.
rem PowerShell reads -h and --help as parameter names: both become /?.
if /i "%~1"=="-h" goto:usage
if /i "%~1"=="--help" goto:usage
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ghwatched.ps1" %*
exit /b %ERRORLEVEL%

:usage
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ghwatched.ps1" /?
exit /b %ERRORLEVEL%
