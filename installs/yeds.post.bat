@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
%_info% "~~~~~~~~~~~~ yEd post installation ~~~~~~~~~~~~"
%_task% "Must check presence of i4jruntime.jar in '%PRGS%\yEds\current\.install4j'"
if exist "%PRGS%\yEds\current\.install4j\i4jruntime.jar" (
    %_ok% "i4jruntime.jar exists in '%PRGS%\yEds\current\.install4j'"
    goto:endlocal
)
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)
rem endlocal && call:fatal test 3

if exist "%setup_dir%\i4jruntime.jar" (
    %_task% "Must copy i4jruntime.jar from local setup dir '%setup_dir%' to '%PRGS%\yEds\current\.install4j'"
    copy "%setup_dir%\i4jruntime.jar" "%PRGS%\yEds\current\.install4j"
    if errorlevel 1 (
        %_error% "Unable to copy i4jruntime.jar from local setup dir '%setup_dir%' to '%PRGS%\yEds\current\.install4j'"
    ) else (
        %_ok% "i4jruntime.jar copied from local setup dir '%setup_dir%' to '%PRGS%\yEds\current\.install4j'"
        goto:endlocal
    )
) else (
    %_error% "i4jruntime.jar not found in local setup dir '%setup_dir%'"
)

set "custom_dir=%PRGS%\senv\custom"
if not exist "%custom_dir%\profile" (
    endlocal && call:fatal "[%~nx0] Must have '%custom_dir%\profile' file with a declared 'xx' profile, for calling setupsdir_xx.bat" 1
    rem %_fatal% "Must have a profile file in custom folder" 1
) else (
    for /F "delims=" %%f in ('type "%custom_dir%\profile"') do ( set "profile=%%f" )
)
set s="setupsdir_%profile%.bat"
if not exist "%custom_dir%\%s%" (
    endlocal && call:fatal "[%~nx0] setupsdir script '%s%' does not exist in custom_dir '%custom_dir%'" 2
)
%_task% "Must retrieve remote setupsdir"
call "%custom_dir%\setupsdir_%profile%.bat" %2 >NUL
if errorlevel 1 (
    endlocal && call:fatal "[%~nx0] Unable to call '%custom_dir%\setupsdir_%profile%.bat'" 11)
)
set "remote_setup_dir=%setupsdir%"
%_ok% "remote_setup_dir='%remote_setup_dir%'"

if not exist "%remote_setup_dir%\i4jruntime.jar" (
    endlocal && call:fatal "[%~nx0] i4jruntime.jar does not exist in remote setup dir '%remote_setup_dir%'" 3
)


%_task% "Must copy i4jruntime.jar from remote setup dir '%remote_setup_dir%' to '%PRGS%\yEds\current\.install4j'"
copy "%remote_setup_dir%\i4jruntime.jar" "%PRGS%\yEds\current\.install4j"
if errorlevel 1 (
    endlocal && call:fatal "[%~nx0] Unable to copy i4jruntime.jar from remote_setup_dir '%remote_setup_dir%' to '%PRGS%\yEds\current\.install4j'" 4
) else (
    %_ok% "i4jruntime.jar copied from remote_setup_dir '%remote_setup_dir%' to '%PRGS%\yEds\current\.install4j'"
    goto:endlocal
)

goto:endlocal

:endlocal
endlocal
if defined standalone_%~nx0 ( 
    call "%PRGS%\senv\batcolors\echos_macros.bat" unset
    set "standalone_%~nx0="
    set "setup_dir="
    set "senv_dir="
    set "prgname="
    set "batdir="
)
set "standalone_%~nx0="
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof

:fatal
call:endlocal
call "%PRGS%\senv\batcolors\echos.bat" :fatal "%~1" %~2