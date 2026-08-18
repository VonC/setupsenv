@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
set "bc=%senv_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(publish)='%script_dir%'"

cd "%senv_dir%\..\setup"
if errorlevel 1 %_fatal% "Unable to access setup folder at '%senv_dir%/../setup'" 3
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd "%senv_dir%\..\dl"
if errorlevel 1 %_fatal% "Unable to access dl folder at '%senv_dir%/../dl (must link to %USERPROFILE%\Downloads)'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)

set "custom_dir=%senv_dir%\custom"
cd "%custom_dir%"
if errorlevel 1 %_fatal% "Unable to access custom folder" 1
%_info% "Custom folder full path: '%custom_dir%', setup_dir='%setup_dir%', dl_dir='%dl_dir%'"

if "%1"=="" (
    %_fatal%  "Usage: publish xxx [profile/local/all] [force] (pattern to search for in Downloads or setup). No profile means publish to local only. A file matching no program of prgs.list (a font, a certificate, ...) is published as is." 4
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
    %_info% "Must move match '%fname%' from Downloads to setup"
    call:rbc "%setup_dir%" "%dl_dir%"
    del "%dl_dir%\%fname%"
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

set "forcePB="
if "%~3"=="force" (
    set "forcePB=true"
    %_ok% "third 'force' param: force publish activated"
) else (
    %_warning% "No third 'force' param: force publish not activated"
)

pushd "%custom_dir%"
if errorlevel 1 %_fatal% "Unable to access custom folder" 1
REM https://stackoverflow.com/questions/4956873/how-to-cut-first-n-and-last-n-columns/51005303#51005303
call:execcmd "ls -1 setupsdir*_*|cut -d'_' -f2-|cut -d'.' -f 1"
for /L %%n in (1 1 !output_cnt!) DO (
    rem %_info% "profile exec(%%n)='!output[%%n]!'"
    set "profiles[%%n]=!output[%%n]!"
    rem %_info% "profile stored(%%n)='!profiles[%%n]!'"
)

rem @echo on
set "name="
set "plain_file="
set "file_subfolder="
set "prg_id="
set "prg_is_global="
rem A file published on its own (a font, a certificate, ...) matches no program of
rem prgs.list, and select_prg.bat is fatal in that case, which would kill this script.
rem The pattern matcher of prgs.list decides first, since it reports a miss without
rem exiting, and select_prg.bat is only called for a file it recognizes.
call:match_prgs_list
if defined prg_line (
    call "%senv_dir%\bin\select_prg.bat" "%fname%" "inst_prg"
    if errorlevel 1 (
        popd
        %_fatal% "Unable to select program for '%fname%'" 101
    )
    set "name=!prg_id!"
) else (
    %_warning% "'%fname%' matches no program of prgs.list: published as a plain file"
    set "plain_file=true"
    set "name=%fname%"
    call:set_file_subfolder
)
if "%name%"=="" ( popd && %_fatal% "Unknown name for fname for publish: '%fname%'" 228 )

if not defined SENV_FORCE_PB (
    %_warning% "SENV_FORCE_PB not defined: force publish not activated unless its value includes '-%name%-'"
    goto:noSenv_force_pb
)
for %%i in (%SENV_FORCE_PB:-= %) do (
    %_info% "Process '%%i' or '%%is' from SENV_FORCE_PB='%SENV_FORCE_PB%' for name '%name%'"
    if "%%i"=="%name%" (
        %_ok% "'%name%' is in SENV_FORCE_PB: force publish activated"
        set "forcePB=true"
    )
    if "%%is"=="%name%" (
        %_ok% "'%name%' is in SENV_FORCE_PB: force publish activated"
        set "forcePB=true"
    )
)
if not defined forcePB (
    %_warning% "SENV_FORCE_PB does not include '%name%': force publish not activated"
)
:noSenv_force_pb

call:execcmd "ls -1 setupsdir*_*"
%_info% "output_cnt='%output_cnt%' or '!output_cnt!'"
if "%output_cnt%"=="0" (
    cd
    popd
    %_fatal% "No s*_* detected in custom" 1
)
rem One profile per iteration, each handled by a subroutine: a 'goto' inside a for
rem block ends the whole loop, which used to stop the publication at the first share
rem already holding the file.
for /L %%n in (1 1 !output_cnt!) DO (
    set "sc=!output[%%n]!"
    set "profile=!profiles[%%n]!"
    call:publish_to_profile
)
popd
goto:eof

:publish_to_profile
if not "%team%"=="all" (
    if not "%team%"=="%profile%" (
        %_warning% "Team '%team%' does not match profile '%profile%': skipping."
        goto:eof
    )
    %_ok% "Team matches profile"
)
set "setupsdir="
call "%custom_dir%\%sc%"
set "spath=%setupsdir%"
%_info% "sc='%sc%', profile='%profile%', team='%team%', name='%name%', spath='%spath%'"
if "%spath%"=="" (
    %_error% "spath is empty: skipped"
    goto:eof
)
dir "%spath%" > NUL
if errorlevel 1 (
    %_error% "Target path '%spath%' not accessible: skipped"
    goto:eof
)
if defined plain_file (
    rem No install list mentions a plain file: publish it to every target share.
    set "dstdir=%spath%"
    if defined file_subfolder ( set "dstdir=%spath%\%file_subfolder%" )
    call:publish_file "!dstdir!"
    goto:eof
)
%_task% "Check name '%name%' (fname='%fname%')"
call:check_name
if "%name_ok%"=="false" (
    %_warning% "Name '%name%' not part of install_%profile%.list: skip copy"
    if exist "%spath%\%fname%" (
        %_warning% "Must delete '%fname%' in '%spath%'"
        del "%spath%\%fname%"
        if errorlevel 1 (
            popd
            %_fatal% "Unable to delete '%spath%\%fname%'" 23
        )
    )
    goto:eof
)
call:publish_file "%spath%"
goto:eof

:publish_file
set "dstdir=%~1"
if exist "%dstdir%\%fname%" (
    %_ok% "File '%fname%' already exists in '%dstdir%'"
    rem Check if remote file size is the same as the local one
    for %%A in ("%setup_dir%\%fname%") do set "size1=%%~zA"
    for %%A in ("%dstdir%\%fname%") do set "size2=%%~zA"
    if !size1! EQU !size2! (
        %_ok% "The files are the same size."
        goto:eof
    )
    %_warning% "The files are different sizes."
    %_warning% "Must delete '%fname%' in '%dstdir%'"
    del "%dstdir%\%fname%"
    if errorlevel 1 (
        popd
        %_fatal% "Unable to delete '%dstdir%\%fname%'" 23
    )
)
%_task% "Must copy '%name%' to '%dstdir%'"
call:rbc "%dstdir%"
goto:eof

:match_prgs_list
rem Same two lists as select_prg.bat, in the same order.
set "prg_line="
call:match_one_prgs_list "%senv_dir%\bin\prgs.list"
if defined prg_line ( goto:eof )
if exist "%USERPROFILE%\senv_home\prgs.list" (
    call:match_one_prgs_list "%USERPROFILE%\senv_home\prgs.list"
)
goto:eof

:match_one_prgs_list
rem One file per call: the same name twice in a row can still be held by the previous
rem redirection, and a failed capture would read as 'no match'.
set "match_err=%TEMP%\senv_publish_prgs_match_%RANDOM%.err"
for /f "tokens=* delims=" %%p in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%senv_dir%\bin\parse_prgs_list_for_pattern.ps1" -prg_list_file "%~1" -string_to_test "%fname%" 2^>"%match_err%"') do ( set "prg_line=%%p" )
findstr /C:"Multiple matching lines" "%match_err%" >NUL 2>&1
if not errorlevel 1 (
    del "%match_err%" 2>NUL
    popd
    %_fatal% "'%fname%' matches several lines of '%~1': fix that list first" 102
)
del "%match_err%" 2>NUL
if defined prg_line (
    %_ok% "'%fname%' matches the program line '%prg_line%' of '%~1'"
)
goto:eof

:set_file_subfolder
rem A font goes to the 'fonts' subfolder of the setups folder, where
rem installs\terminals.post.ps1 looks for it, to keep the setups folder itself for
rem the program archives.
set "fext="
for %%e in ("%fname%") do ( set "fext=%%~xe" )
if /i "%fext%"==".ttf" ( set "file_subfolder=fonts" )
if /i "%fext%"==".otf" ( set "file_subfolder=fonts" )
if defined file_subfolder (
    %_info% "'%fext%' file: published to the '%file_subfolder%' subfolder of each setups folder"
)
goto:eof

:check_name
set "name_ok=false"
grep "%name%" "install_!profile!.list"
if not errorlevel 1 (
    set "name_ok=true"
    %_ok% "Name '%name%' is part of install_!profile!.list"
) else if defined prg_is_global (
    set "name_ok=true"
    %_ok% "Name '%name%' is global"
)
if defined forcePB (
    %_ok% "Force published activated for name '%name%': check_name OK"
    set "name_ok=true"
)
rem %_info% "name_ok='%name_ok%'"
goto:eof

:rbc
cd
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=%setup_dir%" )
%_task% "  (%profile%) Must robocopy '%name%': '%fname%' from '%src%' to '%dst%'"
%_info% "Robocopy '%fname%' from '%src%' to '%dst%'"
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%
IF %ERRORLEVEL% LSS 8 (
    rem echo "ERRORLEVEL='%ERRORLEVEL%'"
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
rem echo "OK='%OK%' '!OK!'"
if not "%OK%"=="ok" ( %_error% "Unable to robocopy '%src%\%name%' to '%dst%': errorlevel '%OK%'" && goto:eof)
%_ok% "%name% updated from '%src%' to '%dst%'"
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
