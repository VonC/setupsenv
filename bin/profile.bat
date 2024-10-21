@echo off
setlocal ENABLEDELAYEDEXPANSION

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "home_dir=%%~fi" )
call %home_dir%\batcolors\echos_macros.bat

FOR /F %%i IN ('cat %HOME%\bin\profile') DO set profileName=%%i
%_info% "[%~nx0] profile name='%profileName%'"
FOR /F "tokens=3,* delims= " %%i IN ('alias cdis') DO set profileFolder=%%i
set "profileFolder=%profileFolder:~0,-1%"
%_info% "[%~nx0] from profile folder '%profileFolder%'"


rem for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv\custom" describe --long --all HEAD') do SET "vcsenv=%%i"
rem for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv" describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
for /f "tokens=* delims=" %%i in ('type "%PRGS%\senv\custom\version"') do SET "vc=%%i"
%_info% "[%~nx0] version '%vc%', locale, at '%PRGS%\senv\custom'"

for %%i in ("%profileFolder%\..") do ( set "remote_senv=%%~fi" )
for /f "tokens=* delims=" %%i in ('type "%remote_senv%\version"') do SET "remote_vc=%%i"
%_info% "[%~nx0] version '%vc%', remote, at '%remote_senv%'"

if "%vc%"=="%remote_vc%" (
    %_ok% "[%~nx0] senv is up to date"
) else (
    %_warning% "[%~nx0] senv is not up to date"
    goto:update_senv
)