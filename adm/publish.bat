@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\..\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(publish)='%script_dir%'"

cd ../custom || %_fatal% "Unable to access custom folder" 1
for /F "delims=" %%f in ('pwd') do ( set cpwd=%%f )
%_info% "Custom folder full path: '%cpwd%'"

dir ..\..\setup > NUL
if errorlevel 1 (
    %_fatal%  "../../setup unavailable" 3
)

dir ..\..\dl > NUL
if errorlevel 1 (
    %_fatal%  "../../dl unavailable (should symlink to C:\%USERNAME%\Downloads)" 5
)

if "%1"=="" (
    %_fatal%  "Usage: publish xxx (pattern to search for in Downloads or setup)" 4
)

set "sfound=setup"
dir /b ..\..\setup|findstr %1 > a
if errorlevel 1 (
    dir /b ..\..\dl|findstr %1 > a
    if errorlevel 1 (
        %_fatal%  "No '%1' pattern found in setup or Downloads" 6
    )
    set "sfound=Downloads"
)

rem https://stackoverflow.com/questions/42000037/how-to-count-the-occurrence-of-a-variable-in-log-file-matching-a-pattern-regex-i
set COUNT=0
for /F "tokens=*" %%N in (a) do set /a COUNT+=1
if not "%count%" == "1" (
        type a
        del a 2>NUL
        %_fatal%  "'%count%' (More than one match) in '%sfound%' for pattern '%1'" 7
)
for /F "delims=" %%f in (a) do ( set fname=%%f )
%_info% "One match found in '%sfound%': '%fname%'"
del a

if "%sfound%" == "Downloads" (
    %_info% "Must copy match '%fname%' from Downloads to setup"
    call:rbc ..\..\setup ..\..\dl
)

call:execcmd "ls -1 s*_*|xargs grep setupsdir|grep -i HLD| grep \\setup|cut -d . -f 1|cut -d _ -f 2"
for /L %%n in (1 1 !output_cnt!) DO (
    rem %_info% "profile exec(%%n)='!output[%%n]!'"
    set "profiles[%%n]=!output[%%n]!"
    rem %_info% "profile stored(%%n)='!profiles[%%n]!'"
)

rem @echo on
set "name=%2"
if not "%name%" == "" ( goto:execrbcs )
if not "%fname:go1=%" == "%fname%" ( set "name=gos" )
if "%name%" == "" ( %_fatal% "Unknown name for fname '%fname%'" 22 )

:execrbcs
call:execcmd "ls -1 s*_*|xargs grep setupsdir|grep -i HLD|cut -d = -f 2| grep setups"
for /L %%n in (1 1 !output_cnt!) DO (
    set "spath=!output[%%n]!"
    set "spath=!spath:"=!"
    set "profile=!profiles[%%n]!"
    %_info% "profile='!profile!', name='%name%', spath='!spath!'"
    dir "!spath!" > NUL
    if errorlevel 1 (
        %_error% "Target path '!spath!' not accessible: skipped"
    ) else (
        grep %name% install_!profile!.list
        if errorlevel 1 (
            %_warning% "Name '%name%' not part of intall_!profile!.list: skip copy"
            if exist "!spath!\%fname%" (
                %_warning% "Must delete '%fname%' in '!spath!'"
                del "!spath!\%fname%"
                if errorlevel 1 (
                    %_fatal% "Unable to delete '!spath!\%fname%'" 23
                )
            )
        ) else (
            call:rbc "!spath!"
        )
    )
)
goto:eof

:rbc
set "dst=%1"
set "src=%2"
if "%src%" == "" ( set "src=..\..\setup" )
%_info% Robocopy '%fname%' from '%src%' to '%dst%'
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%
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
