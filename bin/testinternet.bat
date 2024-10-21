@echo off
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

%_task% "[%~nx0] Must check HTTP code by querying www.google.com"
for /f "tokens=*" %%i in ('curl -Lks -o /dev/null -m 3 -w %%{http_code} https://www.google.com') do ( set "code=%%i" )
if "%code%" == "200" (
  %_ok% "[%~nx0] Internet connection is working"
  goto:eof
)
%_warning% "[%~nx0] Code HTTP '%code%', check errorlevel:"
curl -Lks -o /dev/null -m 3 -w %%{http_code}\n https://www.google.com
set "err=%ERRORLEVEL%"
%_error% "[%~nx0] Code HTTP '%code%', errorlevel '%err%'"
if not "%err%" == "0" (
  exit /b 1
)