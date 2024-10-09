@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
set "bc=%senv_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(publish)='%script_dir%'"

cd "%senv_dir%\..\setup" || %_fatal% "Unable to access setup folder at '%senv_dir%/../setup'" 3
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd "%senv_dir%\..\dl" || %_fatal% "Unable to access dl folder at '%senv_dir%/../dl (must link to C:\%USERNAME%\Downloads)'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)

set "custom_dir=%senv_dir%\custom"
cd "%custom_dir%" || %_fatal% "Unable to access custom folder" 1
%_info% "Custom folder full path: '%custom_dir%', setup_dir='%setup_dir%', dl_dir='%dl_dir%'"

if "%1"=="" (
    %_fatal%  "Usage: publish xxx [profile/local/all] (pattern to search for in Downloads or setup). No profile means publish to local only." 4
)

set "sfound=setup"
dir /b "%setup_dir%"|findstr %1 > a
if errorlevel 1 (
    dir /b "%dl_dir%"|findstr %1 > a
    if errorlevel 1 (
        %_fatal%  "No '%1' pattern found in setup or Downloads" 6
    )
    set "sfound=Downloads"
)

rem https://stackoverflow.com/questions/42000037/how-to-count-the-occurrence-of-a-variable-in-log-file-matching-a-pattern-regex-i
set COUNT=0
for /F "tokens=*" %%N in (a) do set /a COUNT+=1
if not "%count%"=="1" (
        type a
        del a 2>NUL
        %_fatal%  "'%count%' (More than one match) in '%sfound%' for pattern '%1'" 7
)
for /F "delims=" %%f in (a) do ( set fname=%%f)
%_info% "One match found in '%sfound%': '%fname%'"
del a

if "%sfound%"=="Downloads" (
    %_info% "Must copy match '%fname%' from Downloads to setup"
    call:rbc "%setup_dir%" "%dl_dir%"
)

if not "%2"=="" (
    set "team=%2"
) else (
    set "team=local"
)
if "%team%"=="local" (
    %_ok% "'%fname% published only for local setup '%setup_dir%'"
    goto:eof
)
if "%team%"=="all" (
    %_task% "Must publish '%fname%' for all teams"
) else (
    %_task% "Must publish '%fname%' for team '%team%'"
)

REM https://stackoverflow.com/questions/4956873/how-to-cut-first-n-and-last-n-columns/51005303#51005303
call:execcmd "ls -1 setupsdir*_*|cut -d'_' -f2-|cut -d'.' -f 1"
for /L %%n in (1 1 !output_cnt!) DO (
    rem %_info% "profile exec(%%n)='!output[%%n]!'"
    set "profiles[%%n]=!output[%%n]!"
    rem %_info% "profile stored(%%n)='!profiles[%%n]!'"
)

rem @echo on
set "name="
call %script_dir%\publish_setname.bat
if "%name%"=="" ( %_fatal% "Unknown name for fname for publish: '%fname%'" 228 )

:execrbcs
call:execcmd "ls -1 setupsdir*_*"
%_info% "output_cnt='%output_cnt%' or '!output_cnt!'"
if "%output_cnt%"=="0" (
    cd
    %_fatal% "No s*_* detected in custom" 1
)
for /L %%n in (1 1 !output_cnt!) DO (
    set "sc=!output[%%n]!"
    rem set "sc=setupsdir_calx_tesys.bat"
    set "UNCPathOnly=1"
    rem dir %cpwd%\!sc!
    rem echo call "%cpwd%\!sc!"
    call "%cpwd%\!sc!"
    set "UNCPathOnly="
    set "spath=!setupsdir!"
    set "profile=!profiles[%%n]!"
    rem set "profile=calx_tesys"
    set "skip="
    %_info% "sc='!sc!', profile='!profile!', team='%team%', name='%name%', spath='!spath!'"
    if not "%team%"=="all" (
        if not "%team%"=="!profile!" (
            %_warning% "Team '%team%' does not match profile '!profile!': skipping."
            set "skip=1"
        ) else (
            %_ok% "Team matches profile"
        )
    )
    if "!skip!"=="" (
        dir "!spath!" > NUL
        if errorlevel 1 (
            %_error% "Target path '!spath!' not accessible: skipped"
            set "skip=1"
        )
    )
    if "!skip!"=="" (
        %_task% "Check name"
        call:check_name
        rem %_info% "name_ok2='!name_ok!'"
        if "!name_ok!"=="false" (
            %_warning% "Name '%name%' not part of install_!profile!.list: skip copy"
            if exist "!spath!\%fname%" (
                %_warning% "Must delete '%fname%' in '!spath!'"
                del "!spath!\%fname%"
                if errorlevel 1 (
                    %_fatal% "Unable to delete '!spath!\%fname%'" 23
                )
            )
        ) else (
            rem Check if file exists
            if exist "!spath!\%fname%" (
                %_ok% "File '%fname%' already exists in '!spath!'"
                rem Check if remote file size is the same as the local one
                :: Get the file sizes
                for %%A in ("..\..\setup\%fname%") do set "size1=%%~zA"
                for %%A in ("!spath!\%fname%") do set "size2=%%~zA"
                :: Compare size
                if !size1! EQU !size2! (
                    %_ok% "The files are the same size."
                    goto:continue
                )
                %_warning% "The files are different sizes."
                %_warning% "Must delete '%fname%' in '!spath!'"
                del "!spath!\%fname%"
                if errorlevel 1 (
                    %_fatal% "Unable to delete '!spath!\%fname%'" 23
                )
            )
            %_task% "Must copy '%name%' to '!spath!'"
            call:rbc "!spath!"
        )
    )
    :continue
    rem goto:eof
)
goto:eof

:check_name
set "name_ok=false"
grep "%name%" "install_!profile!.list"
if not errorlevel 1 (
    set "name_ok=true"
) else if "%name%"=="gits" (
    set "name_ok=true"
) else if "%name%"=="vscodes" (
    set "name_ok=true"
) else if "%name%"=="peazips" (
    set "name_ok=true"
)
rem %_info% "name_ok='%name_ok%'"
goto:eof

:rbc
cd
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=..\..\setup" )
%_info% "Robocopy '%fname%' from '%src%' to '%dst%'"
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
