@echo off
setlocal enabledelayedexpansion
rem https://stackoverflow.com/questions/7712661/windows-bat-cmd-function-library-in-own-file
rem https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
rem https://superuser.com/questions/749561/batch-file-change-color-of-specific-part-of-text
rem https://stackoverflow.com/questions/10534911/how-can-i-exit-a-batch-file-from-within-a-function
rem https://stackoverflow.com/questions/2048509/how-to-echo-with-different-colors-in-the-windows-command-line
rem https://stackoverflow.com/questions/28810194/how-to-pass-a-list-of-strings-to-a-batch-script-as-a-parameter

@SET ASCII27=
rem @SET ASCII27=← 
if "%1"=="" ( goto:eof )

set "p=%~1"
set "f=%~2"
set "sln=%~3"
if "%sln%"=="" ( set "sln=current" )

set drive=%PRGS:~0,1%
if not drive=="C" (
    if not drive=="c" (
        if not drive=="D" (
            if not drive=="d" (
                goto:network
            )
        )
    )
)

if not exist "%PRGS%\%f%\%sln%" (
    %_info% "Must create '%sln%' to reference '%p%'"
    goto:create
)
rem @echo on
for /f "tokens=2 delims=[" %%a in ('dir "%PRGS%\%f%"^|C:\Windows\System32\findstr current') do (set s=%%a)
rem echo "s='%s%'"
echo "%s%" | C:\Windows\System32\findstr "%p%" 1>NUL: 2>NUL:
if errorlevel 1 (
    %_info% "Must update '%sln%' to reference '%p%'"
    rmdir "%PRGS%\%f%\%sln%"
    goto:create
)
goto:eof

:create
call :check_subdir
mklink /J "%PRGS%\%f%\%sln%" "!tpath!"
if errorlevel 1 (
    %_warning% "Unable to create %sln% symlink for '%f%\%p%' (!tpath!)"
)
goto:eof


:network
%_warning% "Check if '%p%' exists on network drive '%drive%' (%PRGS%)"
if exist "%PRGS%\%f%\%p%" (
    if exist "%PRGS%\%f%\%sln%" (
        call :is_directory "%PRGS%\%f%\%p%"
                                            rem echo errorlevel = '!errorlevel!'
            if "!errorlevel!" == "0" (
            %_warning% "Must delete '%sln%' before renaming '%p%' to '%sln%'"
            rmdir /S /Q "%PRGS%\%f%\%sln%"
            if errorlevel 1 (
                %_fatal% "Must delete '%sln%' in folder '%f%', needed to rename '%p%' to '%sln%'" 1
            )
        ) else (
            %_ok% "Symlink '%sln%' already reference program '%p%'"
            goto:eof
        )
    )
    call :check_subdir
    %_warning% "Must rename program '%p%' (!tpath!) to '%sln%'"
    rem %_fatal% "stop" 1
    move "!tpath!" "%PRGS%\%f%\%sln%"
    if errorlevel 1 (
        %_fatal% "Unable to rename program '%p%' to '%sln%' in folder '%f%'" 2
    )
    if exist "%p%" (
        rmdir "%p%"
        if errorlevel 1 (
            %_fatal% "Unable to delete empty directory '%p%' in folder '%f%'" 6
        )
    )
    echo "%p%"> "%PRGS%\%f%\%p%"
                            if errorlevel 1 (
        %_fatal% "Unable to create file '%p%' in folder '%f%'" 5
    )
) else (
    if not exist "%PRGS%\%f%\%sln%" (
        %_fatal% "'%sln%' as well as program '%p%' are missing in folder '%f%'" 3
    )
    %_fatal% "'%p%' is missing in folder '%f%'" 3
)
goto:eof


:check_subdir
REM https://stackoverflow.com/questions/11004045/batch-file-counting-number-of-files-in-folder-and-storing-in-a-variable
REM https://stackoverflow.com/questions/25702814/code-to-determine-target-of-remote-junction
rem if not target=="%pname% (
set "tpath=%PRGS%\%f%\%p%"
rem dir "%tpath%"
for /f %%A in ('dir "%tpath%" ^| C:\Windows\System32\find "(s)"') do (
    if "!cnt!"=="" ( set cnt=%%A ) else ( set cntd=%%A )
)
rem echo "File count = '%cnt%'"
rem echo "Dir. count = '%cntd%'"
if "%cnt%"=="0 " ( if "%cntd%"=="3 " (
    for /f "tokens=*" %%A in ('dir /B "%tpath%"') do ( set subdir=%%A )
    rem echo "subdir='!subdir!'"
    set "tpath=%tpath%\!subdir!"
) )
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
