@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi\custom"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\..\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(publish)='%script_dir%'"

cd ../custom || %_fatal% "Unable to access custom folder" 1
for /F "delims=" %%f in ('pwd') do ( set cpwd=%%f )
%_info% "Custom folder full path: '%cpwd%'"

call:execcmd "ls -1 setupsdir*_*|cut -d _ -f 2|cut -d . -f 1"
for /L %%n in (1 1 !output_cnt!) DO (
    rem %_info% "profile exec(%%n)='!output[%%n]!'"
    set "profiles[%%n]=!output[%%n]!"
    rem %_info% "profile stored(%%n)='!profiles[%%n]!'"
)

del /F "%script_dir%"\build_all.log 2>NUL
for /L %%n in (1 1 !output_cnt!) DO (
    set "profile=!profiles[%%n]!"
    %_info% "profile='!profile!'"
    call build.bat !profile!
    if errorlevel 1 (
        %_error% "build.bat !profile! failed" >> "%script_dir%"\build_all.log
    )
)

if not exist "%script_dir%"\build_all.log (
    %_ok "Builds All done"
    goto:eof
)

%_warning% "Some Build failed:"
type "%script_dir%"\build_all.log

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
