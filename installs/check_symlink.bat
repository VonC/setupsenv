@echo off
setlocal enabledelayedexpansion
rem https://stackoverflow.com/questions/7712661/windows-bat-cmd-function-library-in-own-file
rem https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
rem https://superuser.com/questions/749561/batch-file-change-color-of-specific-part-of-text
rem https://stackoverflow.com/questions/10534911/how-can-i-exit-a-batch-file-from-within-a-function
rem https://stackoverflow.com/questions/2048509/how-to-echo-with-different-colors-in-the-windows-command-line
rem https://stackoverflow.com/questions/28810194/how-to-pass-a-list-of-strings-to-a-batch-script-as-a-parameter

if "%1"=="" ( goto:eof )

for %%i in ("%~dp0") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "p=%~1"
set "msgp='%p%'"
set "f=%~2"
set "sln=%~3"
set "msgsln='%sln%'"

if "%p%"=="system" (
    rem %_fatal% "Pre-check 'system' must be followed by pattern to be searched in registry: ex 'system-code'" 31
    set "p=system-%f:~0,-1%"
)
if "%sln%"=="system" (
    rem %_fatal% "Post-check symlink 'system' must be followed by pattern to be searched in registry: ex 'system-code'" 32
    set "sln=system-%f:~0,-1%"
)
if not "%p:system-=%"=="%p%" (
    set "ipattern=%p:system-=%"
    %_task% "check_symlink (p): Must get installation path 'instpath' of '%p%' pattern '!ipattern!'"
    call "%senv_dir%\bin\getInstallPath.bat" "%f%" "!ipattern!"
    if errorlevel 1 (
        %_fatal% "Pre-check 'system' unable to get installation for '%f%' pattern '!ipattern!'" 32
    )
    set "p=!instPath!"
    if "!p!"=="" (
        %_fatal% "Pre-check 'system' empty instaPath unable to get installation for '%f%' pattern '!ipattern!'" 33
    )
    set "msgp='!p!' [system]"
    rem %_fatal% "instPath='!instPath!',p='!p!', msgp='!msgp!'" 320
    rem set "instPath="
)
echo sln='%sln%', p='%p%'
rem %_fatal% "instPath='%instPath%',sln='%sln%', msgsln='%msgsln%'" 321
rem @echo on
rem echo sln minus system='%sln:system-=%'
rem echo sln='%sln%'
if "%sln%"=="" ( set "sln=current" )
set "msgsln='%sln%'"
if not "%sln:system-=%"=="%sln%" (
    set "ipattern=%sln:system-=%"
    %_task% "check_symlink (sln): Must get installation path 'instpath' of '%p%' pattern '!ipattern!'"
    call "%senv_dir%\bin\getInstallPath.bat" "%f%" "!ipattern!"
    if errorlevel 1 (
        %_fatal% "Post-check 'system' unable to get installation for '%f%' pattern '!ipattern!'" 42
    )
    set "sln=current"
    if "!instPath!"=="" (
        %_fatal% "Post-check 'system' empty instPath unable to get installation for '%f%' pattern '!ipattern!'" 43
    )
    set "msgsln='!sln!' [system to instPath '!instPath!']"
)

%_info% "Check symlink with p=%msgp%, f='%f%' and sln=%msgsln%"
rem @echo on

if exist "%script_dir%\%f%.sln.bat" (
    for /f "tokens=*" %%i in ('call "%script_dir%\%f%.sln.bat" "%p%"') do ( set "sln=%%i" )
)
if exist "%senv_dir%\custom\installs\%f%.sln.bat" (
    for /f "tokens=*" %%i in ('call "%senv_dir%\custom\installs\%f%.sln.bat" "%p%"') do ( set "sln=%%i" )
)
if "%sln%"=="" ( set "sln=current" )
rem @echo off
if "%PRGS%"=="" ( %_fatal% "No PRGS defined" 1 )

set "drive=%PRGS:~0,1%"
rem %_info% "drive '%drive%'" 1
if not "%drive%"=="C" (
    if not "%drive%"=="c" (
        if not "%drive%"=="D" (
            if not "%drive%"=="d" (
                goto:network
            )
        )
    )
)

if not "%instPath%"=="" (
    %_info% "For system installation, change p '%p%' to '%instPath%'"
    set "p=%instPath%"
)

if not exist "%PRGS%\%f%\" (
    %_task% "Must create '%PRGS%\%f%' for '%sln%' to reference '%p%'"
    mkdir "%PRGS%\%f%"
    if errorlevel 1 (
        %_fatal% "Unable to create '%PRGS%\%f%' for '%sln%' to reference '%p%'" 1
    )
) else (
    %_ok% "Folder '%f%' already exists"
)

if not exist "%PRGS%\%f%\%sln%" (
    %_info% "Must create '%sln%' to reference '%p%'"
    goto:create
)
%_task% "Must check if symlink '%sln%' does reference p '%p%' in '%PRGS%\%f%'"
for /f "tokens=2 delims=[" %%a in ('dir "%PRGS%\%f%"^|C:\Windows\System32\findstr /C:%sln%') do (set s=%%a)
echo "s='%s%'"
echo "%s%" | C:\Windows\System32\findstr /C:"%p%" 1>NUL: 2>NUL:
if errorlevel 1 (
    %_info% "Must update '%sln%' to reference '%p%' from '%s%' in '%PRGS%\%f%'"
    rmdir "%PRGS%\%f%\%sln%"
    goto:create
)
%_ok% "symlink '%sln%' already exist, and references p '%p%' in '%PRGS%\%f%'"
goto:endlocal_sln

:create
if "%instPath%"=="" (
    call :check_subdir
) else (
    set "tpath=%p%"
)
mklink /J "%PRGS%\%f%\%sln%" "!tpath!"
if errorlevel 1 (
    %_warning% "Unable to create %sln% symlink for '%f%\%p%' (!tpath!)"
    set "sln="
)
goto:endlocal_sln


:network
%_warning% "Check if '%p%' exists on network drive '%drive%' (%PRGS%)"
if exist "%PRGS%\%f%\%sln%" (
    if not exist "%PRGS%\%f%\_%p%" (
        %_warning% "Must delete '%sln%' before renaming '%p%' to '%sln%'"
        rmdir /S /Q "%PRGS%\%f%\%sln%"
        if errorlevel 1 (
            %_fatal% "Must delete '%sln%' in folder '%f%', needed to rename '%p%' to '%sln%'" 1
        )
        ping 127.0.0.1 -n 4 > nul
    ) else (
        %_ok% "Symlink '%sln%' already reference program '%p%'"
        goto:endlocal_sln
    )
)
if not exist "%PRGS%\%f%\%p%" (
    %_fatal% "'%p%' is missing in folder '%f%'" 3
)
call :check_subdir
%_warning% "Must rename program '%p%' (!tpath!) to '%sln%'"
rem %_fatal% "stop" 1
move "!tpath!" "%PRGS%\%f%\%sln%"
if errorlevel 1 (
    %_fatal% "Unable to rename program '%p%' to '%sln%' in folder '%f%'" 2
)
ping 127.0.0.1 -n 4 > nul
if exist "%p%" (
    rmdir "%p%"
    if errorlevel 1 (
        %_warning% "Unable to delete empty directory '%p%' in folder '%f%'" 6
    )
    ping 127.0.0.1 -n 4 > nul
)
echo "%p%"> "%PRGS%\%f%\_%p%"
if errorlevel 1 (
    %_fatal% "Unable to create file '%p%' in folder '%f%'" 5
)
if not exist "%PRGS%\%f%\%sln%" (
    %_fatal% "'%sln%' is still missing in folder '%f%'" 3
)

goto:endlocal_sln

:check_subdir
REM https://stackoverflow.com/questions/11004045/batch-file-counting-number-of-files-in-folder-and-storing-in-a-variable
REM https://stackoverflow.com/questions/25702814/code-to-determine-target-of-remote-junction
rem if not target=="%pname% (
set "tpath=%PRGS%\%f%\%p%"
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

:endlocal_sln
%_info% "pre-endlocal symlink '%sln%' for '%f%'"
endlocal & set "sln=%sln%"
%_info% "post-endlocal symlink '%sln%' for '%f%'"
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
