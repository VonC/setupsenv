@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
set "bc=%senv_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(build_all)='%script_dir%'"
set "custom_dir=%senv_dir%\custom"
set "builds_dir=%senv_dir%\builds"

cd "%custom_dir%"
if errorlevel 1 %_fatal% "Unable to access custom folder '%custom_dir%'" 1
for /F "delims=" %%f in ('pwd') do ( set cpwd=%%f )
%_info% "Custom folder full path: '%cpwd%'"

call:execcmd "ls -1 setupsdir*_*|cut -d _ -f 2|cut -d . -f 1"
for /L %%n in (1 1 !output_cnt!) DO (
    rem %_info% "profile exec(%%n)='!output[%%n]!'"
    set "profiles[%%n]=!output[%%n]!"
    rem %_info% "profile stored(%%n)='!profiles[%%n]!'"
)

set "build_all_log=%builds_dir%\build_all.log"
del /F "%build_all_log%" 2>NUL
for /L %%n in (1 1 !output_cnt!) DO (
    set "profile=!profiles[%%n]!"
    %_info% "profile='!profile!'"
    call build.bat !profile!
    if errorlevel 1 (
        echo build.bat !profile! failed>> "%build_all_log%"
    )
)

if not exist "%build_all_log%" (
    %_ok "Builds All done"
    goto:eof
)

%_warning% "Some Build failed:"
type "%build_all_log%"

goto:eof

:execcmd
rem echo aaa%~1
%~1 >a
set LF=^


REM The two empty lines are required here
rem ls -1 s*_*|xargs grep setupsdir|grep -i HLD|cut -d = -f 2|cut -d'^"' -f 1 | grep setups>a
rem https://stackoverflow.com/a/31046373/6309
rem https://stackoverflow.com/questions/31035636/batch-store-command-output-to-a-variable-multiple-lines
set "output_cnt=0"
for /F "delims=" %%f in (a) do (
    set /a output_cnt+=1
    set "output[!output_cnt!]=%%f"
)
del a
if errorlevel 1 (
    pwd
    %_fatal% "unable to delete a" 2
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
