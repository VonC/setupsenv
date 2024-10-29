@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
cd ..
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
set "bc=%senv_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "[%~nx0] script_dir(profile)='%script_dir%'"

cd "%senv_dir%\..\setup" || %_fatal% "[%~nx0] Unable to access setup folder at '%senv_dir%/../setup'" 3
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd "%senv_dir%\..\dl" || %_fatal% "[%~nx0] Unable to access dl folder at '%senv_dir%/../dl (must link to C:\%USERNAME%\Downloads)'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)

set "custom_dir=%senv_dir%\custom"
cd "%custom_dir%" || %_fatal% "[%~nx0] Unable to access custom folder" 1
%_info% "[%~nx0] Custom folder full path: '%custom_dir%', setup_dir='%setup_dir%', dl_dir='%dl_dir%'"

if exist "%custom_dir%\profile" (
    for /f "delims=" %%x in (%custom_dir%\profile) do set profile=%%x
)
if "%profile%"=="" (
    if "%1"=="" (
        %_fatal%  "Usage: publish xxx (profile whose list is to be published)" 4
    )
)
if not "%1"=="" ( set "profile=%1" )

set "publish_all="
if "%~1"=="all" (
    set "publish_all=true"
    for /F "delims=" %%f in ('dir /b "%custom_dir%\install_*.list"') do (
        set "profile=%%~nf"
        set "profile=!profile:install_=!"
        set "profile=!profile:.list=!"
        call :publish_profile
    )
    goto:eof
)
if defined publish_all ( goto:eof )

:publish_profile
set "fprofile=%custom_dir%\install_%profile%.list"
if not exist "%fprofile%" (
    call:error_or_fatal "'%fprofile%' does not exist (list of tools to install for profile '%profile%')" 44
    if defined publish_all ( goto:eof )
)

%_info% "[%~nx0] Profile '%profile%' to be published from setup_dir '%setup_dir%'"
set "spath="
set "fsetupsdir=setupsdir_%profile%.bat"
set "UNCPathOnly=1"
call "%fsetupsdir%"
set "UNCPathOnly="
set "spath=!setupsdir!"
if "%spath%"=="" (
    call:error_or_fatal "[%~nx0](%profile%) No target spath found in '%fsetupsdir%'" 111
    if defined publish_all ( goto:eof )
)
%_info% "[%~nx0] Target path spath: '%spath%'"

call:is_system_tool "peazips"
if errorlevel 1 ( call:publishOne "peazip_portable-*.zip" "peazips" )
call:is_system_tool "gits"
if errorlevel 1 ( call:publishOne "PortableGit-*.7z.exe" "gits" )
call:publishOne "VSCodeUserSetup-x64-*.exe" "vscodes"
call:publishOne "gum_*.zip" "gums"
call:is_system_tool "sysinternalsSuites"
set "system_list=peazips#gits#vscodes#gums#sysinternalsSuites#"
echo %system_list%>"%custom_dir%\system.list.tmp"
if errorlevel 1 ( call:publishOne "SysinternalsSuite-*.zip" "sysinternalsSuites" )

for /F "tokens=1,2 delims= " %%f in ('type "%fprofile%"') do (
    set "pattern=%%f"
    set "name=%%g"
    if not "!pattern!"=="system" (
        call:publishOne "!pattern!" "!name!"
    ) else (
        set "mandatory="
        for /F %%f in ('findstr /i /c:"!name!#" "%custom_dir%\system.list.tmp"') do ( set "mandatory=%%f" )
        if "!mandatory!"=="" (
            %_ok% "[%~nx0] Skip system tool '!name!'"
        )
    )
)
del "%custom_dir%\system.list.tmp" 2>NUL
endlocal
goto:eof

:error_or_fatal
set "msg=%~1"
set "code_error=%~2"
if defined publish_all (
    %_error% "%msg%"
    goto:eof
)
%_fatal% "%msg%" %code_error%
goto:eof

:publishOne
set "pattern=%~1"
set "name=%~2"

set "fname="
for /F "delims=" %%f in ('dir /OD /b "%setup_dir%\%pattern%" 2^>NUL^|tail -1') do ( set fname=%%f)
if "%fname%"=="" (
    del "%custom_dir%\system.list.tmp" 2>NUL
    echo dir /OD /b "%setup_dir%\%pattern%"^|tail -1
    call:error_or_fatal "[%~nx0](%profile%) Unknown name pattern '%pattern%'" 23
    if defined publish_all ( goto:eof )
)
%_task% "[%~nx0](%profile%) Must check/publish fname: '%fname%' for pattern '%pattern%' in setup_dir '%setup_dir%'"

if "%name%"=="" (
    del "%custom_dir%\system.list.tmp" 2>NUL
    call:error_or_fatal "[%~nx0](%profile%) name not provided for fname: '%fname%'" 222
    if defined publish_all ( goto:eof )
)

if exist "!spath!\%fname%" (
    %_ok% "[%~nx0] Skip '%name% '%fname%': already in '!spath!'"
) else (
    call:rbc "!spath!"
)
goto:eof

:rbc
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=%setup_dir%" )
%_task% "  [%~nx0](%profile%) Must robocopy '%name%': '%fname%' from '%src%' to '%dst%'"
REM Explain the robocopy options:
REM /Z: copy in restartable mode (survive network glitches)
REM /R:5: retry 5 times
REM /W:5: wait 5 seconds between retries
REM /TBD: wait for sharenames to be defined (useful for network drives)
REM /MT:16: use 16 threads
REM /NJH: no job header
REM /NJS: no job summary
robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%
IF %ERRORLEVEL% LSS 8 (
    echo "ERRORLEVEL='%ERRORLEVEL%'"
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
rem echo "OK='%OK%' '!OK!'"
if not "%OK%"=="ok" ( %_error% "[%~nx0] Unable to robocopy '%src%\%name%' to '%dst%': errorlevel '%OK%'" && goto:eof)
%_ok% "[%~nx0] %name% updated from '%src%' to '%dst%'"
goto:eof

:is_system_tool
set "name=%~1"
for /f "tokens=1,2 delims= " %%f in ('findstr /i /c:" %name%" "%fprofile%"') do (
    set "pattern=%%f"
)
if "%pattern%"=="system" (
    %_ok% "[%~nx0] Skip mandatory tool '%name%' (system)"
    exit /b 0
)
exit /b 1
goto:eof
