@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
set "bc=%senv_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "[%~nx0] script_dir(publish)='%script_dir%'"

cd "%senv_dir%\..\setup" || %_fatal% "[%~nx0] Unable to access setup folder at '%senv_dir%/../setup'" 3
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd "%senv_dir%\..\dl" || %_fatal% "[%~nx0] Unable to access dl folder at '%senv_dir%/../dl (must link to %USERPROFILE%\Downloads)'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)

set "custom_dir=%senv_dir%\custom"
cd "%custom_dir%" || %_fatal% "[%~nx0] Unable to access custom folder" 1
%_info% "[%~nx0] Custom folder full path: '%custom_dir%', setup_dir='%setup_dir%', dl_dir='%dl_dir%'"

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
%_info% "[%~nx0] One match found in '%sfound%': '%fname%'"
del a

if "%sfound%"=="Downloads" (
    %_info% "[%~nx0] Must move match '%fname%' from Downloads to setup"
    call:rbc "%setup_dir%" "%dl_dir%"
    del "%dl_dir%\%fname%"
)

if not "%2"=="" (
    set "team=%2"
) else (
    set "team=local"
)
if "%team%"=="local" (
    %_ok% "[%~nx0] '%fname% published only for local setup '%setup_dir%'"
    goto:eof
)
if "%team%"=="all" (
    %_task% "[%~nx0] Must publish '%fname%' for all teams"
) else (
    %_task% "[%~nx0] Must publish '%fname%' for team '%team%'"
)

pushd "%custom_dir%" || %_fatal% "[%~nx0] Unable to access custom folder" 1
REM https://stackoverflow.com/questions/4956873/how-to-cut-first-n-and-last-n-columns/51005303#51005303
call:execcmd "ls -1 setupsdir*_*|cut -d'_' -f2-|cut -d'.' -f 1"
for /L %%n in (1 1 !output_cnt!) DO (
    rem %_info% "[%~nx0] profile exec(%%n)='!output[%%n]!'"
    set "profiles[%%n]=!output[%%n]!"
    rem %_info% "[%~nx0] profile stored(%%n)='!profiles[%%n]!'"
)

rem @echo on
set "name="
call %script_dir%\publish_setname.bat
if "%name%"=="" ( podp && %_fatal% "[%~nx0] Unknown name for fname for publish: '%fname%'" 228 )

:execrbcs
call:execcmd "ls -1 setupsdir*_*"
%_info% "[%~nx0] output_cnt='%output_cnt%' or '!output_cnt!'"
if "%output_cnt%"=="0" (
    cd
    popd
    %_fatal% "[%~nx0] No s*_* detected in custom" 1
)
for /L %%n in (1 1 !output_cnt!) DO (
    set "sc=!output[%%n]!"
    rem set "sc=setupsdir_calx_tesys.bat"
    set "UNCPathOnly=1"
    rem dir %cpwd%\!sc!
    rem echo call "%cpwd%\!sc!"
    set "profile=!profiles[%%n]!"
    rem set "profile=calx_tesys"
    set "skip="
    if not "%team%"=="all" (
        if not "%team%"=="!profile!" (
            %_warning% "[%~nx0] Team '%team%' does not match profile '!profile!': skipping."
            set "skip=1"
        ) else (
            %_ok% "[%~nx0] Team matches profile"
        )
    )
    if "!skip!"=="" (
        call "%custom_dir%\!sc!"
        set "UNCPathOnly="
        set "spath=!setupsdir!"
        %_info% "[%~nx0] sc='!sc!', profile='!profile!', team='%team%', name='%name%', spath='!spath!'"
        if "!spath!"=="" (
            %_error% "[%~nx0] spath is empty: skipped"
            set "skip=1"
        )
        dir "!spath!" > NUL
        if errorlevel 1 (
            %_error% "[%~nx0] Target path '!spath!' not accessible: skipped"
            set "skip=1"
        )
    )
    if "!skip!"=="" (
        %_task% "[%~nx0] Check name '%name%' (fname='%fname%')"
        call:check_name
        rem %_info% "[%~nx0] name_ok2='!name_ok!'"
        if "!name_ok!"=="false" (
            %_warning% "[%~nx0] Name '%name%' not part of install_!profile!.list: skip copy"
            if exist "!spath!\%fname%" (
                %_warning% "[%~nx0] Must delete '%fname%' in '!spath!'"
                del "!spath!\%fname%"
                if errorlevel 1 (
                    popd
                    %_fatal% "[%~nx0] Unable to delete '!spath!\%fname%'" 23
                )
            )
        ) else (
            rem Check if file exists
            if exist "!spath!\%fname%" (
                %_ok% "[%~nx0] File '%fname%' already exists in '!spath!'"
                rem Check if remote file size is the same as the local one
                :: Get the file sizes
                for %%A in ("..\..\setup\%fname%") do set "size1=%%~zA"
                for %%A in ("!spath!\%fname%") do set "size2=%%~zA"
                :: Compare size
                if !size1! EQU !size2! (
                    %_ok% "[%~nx0] The files are the same size."
                    goto:continue
                )
                %_warning% "[%~nx0] The files are different sizes."
                %_warning% "[%~nx0] Must delete '%fname%' in '!spath!'"
                del "!spath!\%fname%"
                if errorlevel 1 (
                    popd
                    %_fatal% "[%~nx0] Unable to delete '!spath!\%fname%'" 23
                )
            )
            %_task% "[%~nx0] Must copy '%name%' to '!spath!'"
            call:rbc "!spath!"
        )
    )
    :continue
    rem goto:eof
)
popd
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
rem %_info% "[%~nx0] name_ok='%name_ok%'"
goto:eof

:rbc
cd
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=%setup_dir%" )
%_task% "  [%~nx0](%profile%) Must robocopy '%name%': '%fname%' from '%src%' to '%dst%'"
%_info% "[%~nx0] Robocopy '%fname%' from '%src%' to '%dst%'"
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%
IF %ERRORLEVEL% LSS 8 (
    rem echo "ERRORLEVEL='%ERRORLEVEL%'"
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
rem echo "OK='%OK%' '!OK!'"
if not "%OK%"=="ok" ( %_error% "[%~nx0] Unable to robocopy '%src%\%name%' to '%dst%': errorlevel '%OK%'" && goto:eof)
%_ok% "[%~nx0] %name% updated from '%src%' to '%dst%'"
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
    %_fatal% "[%~nx0] unable to delete a" 2
)
