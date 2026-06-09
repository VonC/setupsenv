@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "installs_dir=%%~fi"
cd /d "%installs_dir%" || echo "unable to cd to '%installs_dir%'"&& exit /b 1

call "%installs_dir%\..\bin\ensure_internet.bat" || exit /b 1

powershell -ExecutionPolicy Bypass -File "%installs_dir%\terminals.post.wrapper.ps1"
set "err=%ERRORLEVEL%"

endlocal & exit /b %err%
