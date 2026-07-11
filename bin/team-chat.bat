@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0team-chat.ps1" %*
exit /b %ERRORLEVEL%
