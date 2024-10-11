@echo off
setlocal enabledelayedexpansion

set "file=%~1"
if "%file%"=="" (
    echo "Usage: %~nx0 <file>"
    exit /b 1
)
if not exist "%file%" (
    echo "[%~nx0] File '%file%' does not exist"
    exit /b 1
)
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
rem cd /d "%script_dir%" || echo "[%~nx0] unable to cd to '%script_dir%'"&& exit /b 1

for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%script_dir%\check_trailing_newline.ps1" "%file%"') do set "result=%%i"
if "%result%"=="0A" (
  exit /b 0
)
endlocal
exit /b 2