@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "prgs_folder=%~1"
set "prg_folder=%~2"
set "sln=%~3"

if not defined sln (
    %_fatal%  "Usage: check_prg_symlink (prgs_folder) (prg_folder) (symlink_name)" 44
)

if not exist "%PRGS%\%prgs_folder%\" (
    %_task% "Must create '%PRGS%\%prgs_folder%' for '%sln%' to reference '%prg_folder%'"
    mkdir "%PRGS%\%prgs_folder%"
    if errorlevel 1 (
        %_fatal% "Unable to create '%PRGS%\%prgs_folder%' for '%sln%' to reference '%prg_folder%'" 1
    )
    %_ok% "Folder '%prgs_folder%' created"
) else (
    %_ok% "Folder '%prgs_folder%' already exists"
)

if not exist "%PRGS%\%prgs_folder%\%sln%" (
    %_info% "Must create '%sln%' to reference '%prg_folder%'"
    goto:create
)
%_task% "Must check if symlink '%sln%' does reference p '%prg_folder%'"
rem @echo on
set "s="
for /f "tokens=2 delims=[" %%a in ('dir "%PRGS%\%prgs_folder%"^|C:\Windows\System32\findstr %sln%') do (set s=%%a)
rem echo "s='%s%'"
echo "%s%" | C:\Windows\System32\findstr "%prg_folder%" 1>NUL: 2>NUL:
if errorlevel 1 (
    %_info% "Must update '%sln%' to reference '%prg_folder%' from '%s%'"
    %_task% "Must delete '%sln%' before creating '%sln%' for '%prg_folder%'"
    rmdir "%PRGS%\%prgs_folder%\%sln%" 2>nul
    if exist "%PRGS%\%prgs_folder%\%sln%\" ( goto:keep_aside )
    %_ok% "Symlink '%PRGS%\%prgs_folder%\%sln%' rmdir successfully"
    goto:create
)
%_ok% "symlink '%sln%' already exist, and references p '%prg_folder%'"
goto:eof

:keep_aside
rem '%sln%' is a real directory (previous installation), not a junction: a
rem plain rmdir cannot remove it, and mklink would fail on the existing name.
%_warning% "'%sln%' in '%PRGS%\%prgs_folder%' is a real directory (previous installation), not a junction"
if exist "%PRGS%\%prgs_folder%\%sln%.old\" (
    %_task% "Must delete previous backup '%sln%.old' in '%PRGS%\%prgs_folder%'"
    rmdir /S /Q "%PRGS%\%prgs_folder%\%sln%.old"
)
%_task% "Must keep real directory '%sln%' aside as '%sln%.old' in '%PRGS%\%prgs_folder%'"
move "%PRGS%\%prgs_folder%\%sln%" "%PRGS%\%prgs_folder%\%sln%.old" 1>NUL:
if errorlevel 1 (
    %_fatal% "Unable to move '%sln%' aside to '%sln%.old' in '%PRGS%\%prgs_folder%': close any program using it and relaunch" 43
)
%_ok% "'%sln%' kept aside as '%sln%.old' in '%PRGS%\%prgs_folder%': delete it manually once the new installation is validated"
goto:create

:create
if not "%instPath%"=="" (
    set "tpath=%prg_folder%"
    goto:mklink_tpath
)

set "tpath=%PRGS%\%prgs_folder%\%prg_folder%"
:loop_check_subdir
set "subdir="
%_info% "Check subdirectory for tpath '%tpath%'"
call :check_subdir "%tpath%"
if defined subdir (
    %_warning% "one subdirectory detected '%subdir%': looping on tpath '%tpath%'"
    goto:loop_check_subdir
)
:mklink_tpath
%_task% "Must create %sln% symlink for '!tpath!'"
mklink /J "%PRGS%\%prgs_folder%\%sln%" "!tpath!"
if errorlevel 1 (
    %_warning% "Unable to create %sln% symlink for '!tpath!')"
) else (
    %_ok% "symlink '%sln%' created for '!tpath!'"
)
goto:eof


:network
%_warning% "Check if '%prg_folder%' exists on network drive '%drive%' (%PRGS%)"
if exist "%PRGS%\%prgs_folder%\%sln%" (
    if not exist "%PRGS%\%prgs_folder%\_%prg_folder%" (
        %_warning% "Must delete folder '%sln%' before renaming '%prg_folder%' to '%sln%'"
        rmdir /S /Q "%PRGS%\%prgs_folder%\%sln%"
        if errorlevel 1 (
            %_fatal% "Must delete '%sln%' in folder '%prgs_folder%', needed to rename '%prg_folder%' to '%sln%'" 1
        )
        ping 127.0.0.1 -n 4 > nul
    ) else (
        %_ok% "Symlink '%sln%' already reference program '%prg_folder%'"
        goto:eof
    )
)
if not exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_fatal% "'%prg_folder%' is missing in folder '%prgs_folder%'" 3
)
set "tpath=%PRGS%\%prgs_folder%\%prg_folder%"
:loop_network_check_subdir
set "subdir="
call :check_subdir "%tpath%"
if defined subdir (
    %_warning% "(network) one subdirectory detected '%subdir%': looping"
    goto:loop_network_check_subdir
)
%_task% "Must rename program '%prg_folder%' (!tpath!) to '%sln%'"
%_fatal% "stop" 1
move "!tpath!" "%PRGS%\%prgs_folder%\%sln%"
if errorlevel 1 (
    %_fatal% "Unable to rename program '%prg_folder%' to '%sln%' in folder '%prgs_folder%'" 2
)
%_ok% "Program '%prg_folder%' renamed to '%sln%' in folder '%prgs_folder%'"
ping 127.0.0.1 -n 4 > nul
if exist "%prg_folder%" (
    rmdir "%prg_folder%"
    if errorlevel 1 (
        %_warning% "Unable to delete empty directory '%prg_folder%' in folder '%prgs_folder%'" 6
    )
    ping 127.0.0.1 -n 4 > nul
)
echo "%prg_folder%"> "%PRGS%\%prgs_folder%\_%prg_folder%"
if errorlevel 1 (
    %_fatal% "Unable to create file '%prg_folder%' in folder '%prgs_folder%'" 5
)
if not exist "%PRGS%\%prgs_folder%\%sln%" (
    %_fatal% "'%sln%' is still missing in folder '%prgs_folder%'" 3
)
goto:eof


:check_subdir
REM https://stackoverflow.com/questions/11004045/batch-file-counting-number-of-files-in-folder-and-storing-in-a-variable
REM https://stackoverflow.com/questions/25702814/code-to-determine-target-of-remote-junction
rem if not target=="%pname% (
set "tpath=%~1%"
rem dir "%tpath%"
for /f %%A in ('dir "%tpath%" ^| C:\Windows\System32\find " "') do (
    set "cnt=!cntd!"
    set "cntd=%%A"
)
rem echo "File count = '%cnt%'"
rem echo "Dir. count = '%cntd%'"
set "subdir="
if "%cnt%"=="0" ( if "%cntd%"=="3" (
    for /f "tokens=*" %%A in ('dir /B "%tpath%"') do ( set subdir=%%A )
    rem echo "subdir='!subdir!'"
) )
if not "%subdir%"=="" (
    set "tpath=%tpath%\!subdir!"
)
rem echo "path with subdir='%tpath%'"
call :Trim tpath %tpath%
rem set stpath=%tpath:~0,-1%
rem echo "final tpath='%tpath%'"
EndLocal & set "tpath=%tpath%" & set "subdir=%subdir%"
exit /b
GOTO :EOF

:is_directory
    SETLOCAL
    ECHO Test if '%1' is a directory
    type %1 1>NUL: 2>NUL:
    IF errorlevel 1 (
        ECHO '%1' is a directory
        exit /b 0
    ) ELSE (
        ECHO '%1' is NOT a directory
        exit /b 1
    )
    ENDLOCAL
    GOTO :EOF

REM https://stackoverflow.com/questions/3001999/how-to-remove-trailing-and-leading-whitespace-for-user-provided-input-in-a-batch
rem not needed if SET tpath=%tpath:~0,-1%x
:Trim
SetLocal EnableDelayedExpansion
set Params=%*
for /f "tokens=1*" %%a in ("!Params!") do EndLocal & set %1=%%b
exit /b
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
