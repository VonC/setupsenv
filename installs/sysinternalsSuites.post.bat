@echo off

REM From https://hahndorf.eu/blog/post/2010/03/07/WorkAroundSysinternalsLicensePopups

setlocal enabledelayedexpansion
for %%i in ("%~dp0") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

%_task% "Must check EulaAccepted for Sysinternals"

reg query HKCU\Software\Sysinternals /v EulaAccepted 2> NUL
if not errorlevel 1 (
  %_ok% "Sysinternals EulaAccepted already present"
  goto:eof
)
%_warning% "Sysinternals EulaAccepted missing"
%_task% "Must set EulaAccepted for Sysinternals"
reg.exe ADD HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f
if errorlevel 1 (
  %_fatal% "Unable to set EulaAccepted for Sysinternals" 98
)
%_ok% "EulaAccepted for Sysinternals now set"
goto:eof