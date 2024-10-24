
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
    %_task% "[%~nx0] Must create '%PRGS%\%prgs_folder%' for '%sln%' to reference '%prg_folder%'"
    mkdir "%PRGS%\%prgs_folder%"
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to create '%PRGS%\%prgs_folder%' for '%sln%' to reference '%prg_folder%'" 1
    )
) else (
    %_ok% "[%~nx0] Folder '%prgs_folder%' already exists"
)

if not exist "%PRGS%\%prgs_folder%\%sln%" (
    %_info% "[%~nx0] Must create '%sln%' to reference '%prg_folder%'"
    goto:create
)
%_task% "[%~nx0] Must check if symlink '%sln%' does reference p '%prg_folder%'"
rem @echo on
for /f "tokens=2 delims=[" %%a in ('dir "%PRGS%\%prgs_folder%"^|C:\Windows\System32\findstr %sln%') do (set s=%%a)
rem echo "s='%s%'"
echo "%s%" | C:\Windows\System32\findstr "%prg_folder%" 1>NUL: 2>NUL:
if errorlevel 1 (
    %_info% "[%~nx0] Must update '%sln%' to reference '%prg_folder%' from '%s%'"
    rmdir "%PRGS%\%prgs_folder%\%sln%"
    goto:create
)
%_ok% "[%~nx0] symlink '%sln%' already exist, and references p '%prg_folder%'"
goto:eof

:create
if "%instPath%"=="" (
    call :check_subdir
) else (
    set "tpath=%prg_folder%"
)
mklink /J "%PRGS%\%prgs_folder%\%sln%" "!tpath!"
if errorlevel 1 (
    %_warning% "[%~nx0] Unable to create %sln% symlink for '%prgs_folder%\%prg_folder%' (!tpath!)"
)
goto:eof


:network
%_warning% "[%~nx0] Check if '%prg_folder%' exists on network drive '%drive%' (%PRGS%)"
if exist "%PRGS%\%prgs_folder%\%sln%" (
    if not exist "%PRGS%\%prgs_folder%\_%prg_folder%" (
        %_warning% "[%~nx0] Must delete '%sln%' before renaming '%prg_folder%' to '%sln%'"
        rmdir /S /Q "%PRGS%\%prgs_folder%\%sln%"
        if errorlevel 1 (
            %_fatal% "[%~nx0] Must delete '%sln%' in folder '%prgs_folder%', needed to rename '%prg_folder%' to '%sln%'" 1
        )
        ping 127.0.0.1 -n 4 > nul
    ) else (
        %_ok% "[%~nx0] Symlink '%sln%' already reference program '%prg_folder%'"
        goto:eof
    )
)
if not exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_fatal% "[%~nx0] '%prg_folder%' is missing in folder '%prgs_folder%'" 3
)
call :check_subdir
%_warning% "[%~nx0] Must rename program '%prg_folder%' (!tpath!) to '%sln%'"
rem %_fatal% "[%~nx0] stop" 1
move "!tpath!" "%PRGS%\%prgs_folder%\%sln%"
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to rename program '%prg_folder%' to '%sln%' in folder '%prgs_folder%'" 2
)
ping 127.0.0.1 -n 4 > nul
if exist "%prg_folder%" (
    rmdir "%prg_folder%"
    if errorlevel 1 (
        %_warning% "[%~nx0] Unable to delete empty directory '%prg_folder%' in folder '%prgs_folder%'" 6
    )
    ping 127.0.0.1 -n 4 > nul
)
echo "%prg_folder%"> "%PRGS%\%prgs_folder%\_%prg_folder%"
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to create file '%prg_folder%' in folder '%prgs_folder%'" 5
)
if not exist "%PRGS%\%prgs_folder%\%sln%" (
    %_fatal% "[%~nx0] '%sln%' is still missing in folder '%prgs_folder%'" 3
)
goto:eof


:check_subdir
REM https://stackoverflow.com/questions/11004045/batch-file-counting-number-of-files-in-folder-and-storing-in-a-variable
REM https://stackoverflow.com/questions/25702814/code-to-determine-target-of-remote-junction
rem if not target=="%pname% (
set "tpath=%PRGS%\%prgs_folder%\%prg_folder%"
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
EndLocal & set tpath=%tpath%
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
