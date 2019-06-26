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
mklink /J "%PRGS%\%f%\%sln%" "%tpath%"
if errorlevel 1 (
    %_warning% "Unable to create %sln% symlink for '%f%\%p%'"
)
goto:eof

REM https://stackoverflow.com/questions/3001999/how-to-remove-trailing-and-leading-whitespace-for-user-provided-input-in-a-batch
rem not needed if SET tpath=%tpath:~0,-1%x
:Trim
SetLocal EnableDelayedExpansion
set Params=%*
for /f "tokens=1*" %%a in ("!Params!") do EndLocal & set %1=%%b
exit /b
goto:eof
