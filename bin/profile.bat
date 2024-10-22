@echo off
setlocal ENABLEDELAYEDEXPANSION

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "home_dir=%%~fi" )
call %home_dir%\batcolors\echos_macros.bat

FOR /F %%i IN ('cat %HOME%\bin\profile') DO set profileName=%%i
%_info% "[%~nx0] profile name='%profileName%'"
:: Use FOR /F to capture all tokens starting from the third one, managing spaces in the profile folder name
FOR /F "tokens=3* delims= " %%i IN ('alias cdis') DO (
    set "profileFolder=%%i"
    set "rest=%%j"
    if defined rest (
        for %%k in (!rest!) do (
            set "profileFolder=!profileFolder! %%k"
        )
    )
)
set "profileFolder=%profileFolder:"=%"
%_info% "[%~nx0] from profile setups folder '%profileFolder%'"


for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv\custom" describe --long --all HEAD') do SET "vcsenv=%%i"
for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv" describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
for /f "tokens=* delims=" %%i in ('type "%PRGS%\senv\custom\version"') do SET "vc=%%i"
%_info% "[%~nx0] version '%vc%', locale, at '%PRGS%\senv\custom'"

for %%i in ("%profileFolder%\..") do ( set "remote_senv=%%~fi" )
if exist "%remote_senv%\version" (
    for /f "tokens=* delims=" %%i in ('type "%remote_senv%\version"') do SET "remote_vc=%%i"
    %_info% "[%~nx0] version '!remote_vc!', remote, at '%remote_senv%'"
) else (
    %_warning% "No version found at remote senv '%remote_senv%'"
)
if "%vc%"=="%remote_vc%" (
    %_ok% "[%~nx0] senv is up to date"
) else (
    %_warning% "[%~nx0] senv is not up to date"
)

if not "%vcsenv%"=="%remote_vc%" (
    %_warning% "[%~nx0] local senv updated: needs to be published"
) else (
    %_ok% "[%~nx0] local senv unchanged"
)