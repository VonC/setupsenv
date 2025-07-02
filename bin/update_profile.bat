@echo off
setlocal ENABLEDELAYEDEXPANSION

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "home_dir=%%~fi" )
call %home_dir%\batcolors\echos_macros.bat

FOR /F %%i IN ('cat %HOME%\bin\profile') DO set profileName=%%i
set "localmsg="
where publish_setname.bat >NUL 2>NUL
if not errorlevel 1 (
    set "localmsg= [LOCAL path activated]"
)
%_info% "profile name='%profileName%'%localmsg%"
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
%_info% "from profile setups full folder  '%profileFolder%'"
for /f "tokens=1 delims=:" %%i in ('echo %profileFolder%') do SET "driveLetter=%%i"
%_info% "from profile setups drive letter '%driveLetter%'"

call "%script_dir%\drive_refresh.bat" "%driveLetter%"
if errorlevel 1 (
    %_fatal% "Failed to refresh drive '%driveLetter%'"
    goto:eof
)

%_task% "Must access profile setups at '%profileFolder%'"
pushd "%profileFolder%" || (
    %_fatal% "Unable to access profile setups at '%profileFolder%'" 112
    goto:eof
)
%_ok% "Successfully accessed profile setups at '%profileFolder%'"

set "s_args=gits"
REM Compute arguments for s.bat
if "%~1"=="all" (
    REM Special case: one argument that is "all"
    set "s_args="
    %_info% "'all': Will call s.bat without arguments"
) else (
    if "%~1"=="" (
        REM No arguments: install gits only
        set "s_args=gits"
        %_info% "Will call s.bat with gits only, update HOME and install HOME/bin utilities"
    ) else (
        REM Normal case: pass all arguments
        set "s_args=%*"
        %_info% "Will call s.bat with arguments: '%s_args%'"
    )
)
rem popd
rem %_fatal% "s_args='%s_args%' stop for now" 98

REM Call s.bat once with computed arguments
%_task% "Executing remote profile setups upgrade at '%profileFolder%' with arguments '%s_args%'"
call s.bat %s_args%
if errorlevel 1 (
    %_error% "Failed to execute profile setups at '%profileFolder%'"
    popd || (
        %_fatal% "Failed to return from profile setups at '%profileFolder%'" 115
        goto:eof
    )
    exit /b 114
    goto:eof
)
popd || (
    %_fatal% "Failed to return from profile setups at '%profileFolder%'" 113
    goto:eof
)
%_ok% "Successfully executed profile setups upgrade at '%profileFolder%'"
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
