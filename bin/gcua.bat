@echo off
setlocal enabledelayedexpansion

rem gcua.bat [folder] [hosts-list|-] [--force] [--dry-run]
rem
rem Applies the senv git identity (FULLNAME / USERMAIL) to every git
rem repository found one level under [folder] (default: %PROG%\git).
rem --dry-run reports what would be set without writing anything.
rem
rem A repository is left untouched when:
rem  - it already has a local user.email (unless --force),
rem  - a hosts list is active and at least one of its remote URLs does not
rem    match any listed host (external service, for example github.com),
rem  - a hosts list is active and it has no remote at all.
rem
rem Hosts list resolution:
rem  - second argument, if it is an existing file,
rem  - '-' as second argument disables the filter (stamp all, skip-if-set),
rem  - default: %HOME%\bin\senv.custom.<profile>.gcua.list for the active
rem    profile (%HOME%\bin\profile), and when the profile has none,
rem    %HOME%\bin\senv.custom.all_teams.gcua.list, the default shared by
rem    every profile. Without any list and without an explicit '-', gcua
rem    exits without touching anything: the list is the opt-in.
rem
rem setup.bat calls gcua with no argument at the end of each run, only when
rem the active profile ships a gcua list.

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
if exist "%senv_dir%\batcolors\echos_macros.bat" (
    call "%senv_dir%\batcolors\echos_macros.bat"
)

set "target_dir="
set "hosts_arg="
set "gcua_force="
set "gcua_dryrun="
:parse_args
if "%~1"=="" ( goto:args_done )
if /I "%~1"=="--force" ( set "gcua_force=1" & shift & goto:parse_args )
if /I "%~1"=="--dry-run" ( set "gcua_dryrun=1" & shift & goto:parse_args )
if "%target_dir%"=="" ( set "target_dir=%~1" & shift & goto:parse_args )
set "hosts_arg=%~1"
shift
goto:parse_args
:args_done

if "%target_dir%"=="" ( set "target_dir=%PROG%\git" )
if not exist "%target_dir%\" (
    %_fatal% "folder '%target_dir%' does not exist" 1
)

where git >NUL 2>NUL
if errorlevel 1 (
    %_fatal% "git not found on PATH" 2
)

rem --- identity ---------------------------------------------------------
rem Standalone runs (plain cmd, no senv session): fall back to the default
rem senv home when HOME is not set.
if "%USERMAIL%"=="" if exist "%HOME%\bin\senv.local.pre.bat" (
    call "%HOME%\bin\senv.local.pre.bat"
)
if "%USERMAIL%"=="" if exist "%USERPROFILE%\home_senv\bin\senv.local.pre.bat" (
    call "%USERPROFILE%\home_senv\bin\senv.local.pre.bat"
)
if "%USERMAIL%"=="" (
    %_fatal% "USERMAIL not set: register your identity in %%HOME%%\bin\senv.local.pre.bat, or set FULLNAME and USERMAIL before calling" 3
)
if "%FULLNAME%"=="" ( set "FULLNAME=%USERNAME%" )

rem --- hosts list -------------------------------------------------------
set "hosts_list="
set "use_filter="
if "%hosts_arg%"=="-" ( goto:hosts_done )
if not "%hosts_arg%"=="" (
    if not exist "%hosts_arg%" (
        %_fatal% "hosts list '%hosts_arg%' does not exist" 4
    )
    set "hosts_list=%hosts_arg%"
    goto:hosts_resolved
)
set "gcua_profile="
if exist "%HOME%\bin\profile" (
    for /f "delims=" %%x in ('type "%HOME%\bin\profile"') do ( set "gcua_profile=%%x" )
)
if not "%gcua_profile%"=="" if exist "%HOME%\bin\senv.custom.%gcua_profile%.gcua.list" (
    set "hosts_list=%HOME%\bin\senv.custom.%gcua_profile%.gcua.list"
    goto:hosts_resolved
)
if exist "%HOME%\bin\senv.custom.all_teams.gcua.list" (
    set "hosts_list=%HOME%\bin\senv.custom.all_teams.gcua.list"
    goto:hosts_resolved
)
%_info% "no hosts list found, neither per-profile nor senv.custom.all_teams.gcua.list: nothing to do (use 'gcua %target_dir% -' to stamp without filter)"
goto:eof
:hosts_resolved
set "use_filter=1"
set "hosts_tmp=%TEMP%\gcua_hosts_%RANDOM%.tmp"
findstr /V /R "^#" "%hosts_list%" 2>NUL | findstr /R "." > "%hosts_tmp%"
for %%z in ("%hosts_tmp%") do ( if "%%~zz"=="0" (
    del "%hosts_tmp%" 2>NUL
    %_warning% "hosts list '%hosts_list%' has no usable pattern: nothing applied"
    goto:eof
))
%_info% "hosts list: '%hosts_list%'"
:hosts_done

if defined gcua_dryrun (
    %_task% "Must preview git identity '%FULLNAME%' / '%USERMAIL%' under '%target_dir%' (dry-run)"
) else (
    %_task% "Must apply git identity '%FULLNAME%' / '%USERMAIL%' under '%target_dir%'"
)

set /a n_ok=0
set /a n_already=0
set /a n_external=0
set /a n_noremote=0
for /d %%d in ("%target_dir%\*") do ( call :process "%%~fd" )
if defined gcua_dryrun (
    %_ok% "git identity previewed under '%target_dir%': %n_ok% would be set, %n_already% already set, %n_external% external, %n_noremote% without remote"
) else (
    %_ok% "git identity applied under '%target_dir%': %n_ok% set, %n_already% already set, %n_external% external, %n_noremote% without remote"
)
if defined hosts_tmp ( del "%hosts_tmp%" 2>NUL )
goto:eof

rem -----------------------------------------------------------------------
:process
set "repo=%~1"
if not exist "%repo%\.git" ( goto:eof )

set "cur_mail="
for /f "delims=" %%e in ('git -C "%repo%" config --local user.email 2^>NUL') do ( set "cur_mail=%%e" )
if not defined gcua_force if defined cur_mail (
    %_info% "[already] '%repo%': '!cur_mail!' kept"
    set /a n_already+=1
    goto:eof
)

if defined use_filter (
    set "has_remote="
    set "has_external="
    for /f "tokens=2" %%u in ('git -C "%repo%" remote -v 2^>NUL') do (
        set "has_remote=1"
        echo %%u| findstr /I /G:"%hosts_tmp%" >NUL || set "has_external=1"
    )
    if not defined has_remote (
        %_warning% "[skip] '%repo%': no remote, cannot classify"
        set /a n_noremote+=1
        goto:eof
    )
    if defined has_external (
        %_warning% "[skip] '%repo%': remote outside the listed services"
        set /a n_external+=1
        goto:eof
    )
)

if defined gcua_dryrun (
    %_ok% "[dry-run] '%repo%': would set '%FULLNAME%' / '%USERMAIL%'"
    set /a n_ok+=1
    goto:eof
)
git -C "%repo%" config user.name "%FULLNAME%"
if errorlevel 1 (
    %_error% "unable to set user.name in '%repo%'"
    goto:eof
)
git -C "%repo%" config user.email "%USERMAIL%"
if errorlevel 1 (
    %_error% "unable to set user.email in '%repo%'"
    goto:eof
)
%_ok% "[set] '%repo%': '%FULLNAME%' / '%USERMAIL%'"
set /a n_ok+=1
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
