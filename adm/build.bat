@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
for %%i in ("%script_dir%") do (
    set "script_dir=%%~fi"
)
for %%i in ("%script_dir%\..\batcolors") do ( set "bc=%%~fi" )
call "%bc%\echos_macros.bat"
%_info% "script_dir(bundle)='%script_dir%'"
rem @echo on
for %%i in ("%~dp0..\custom") do SET "custom_dir=%%~fi"
cd "%custom_dir%"
if errorlevel 1  ( %_fatal% "Unable to access custom folder" 1 )
for /F "delims=" %%f in ('cd') do ( set "custom_dir=%%f" )
%_info% "Custom folder full path: '%custom_dir%'"

if "%1"=="" (
    if not exist "%custom_dir%\profile" (
        %_fatal% "Must have setupsdir profile xx, for calling setupsdir_xx.bat" 1
        rem %_fatal% "Must have a profile file in custom folder" 1
    ) else (
        for /F "delims=" %%f in ('type "%custom_dir%\profile"') do ( set "profile=%%f" )
    )
) else (
    set "profile=%1"
)

cd ..
if not exist custom (
    %_fatal% "current folder must be named custom" 1
)
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
%_info% "senv folder full path: '%senv_dir%'"

if not exist builds (
    %_fatal% "builds must be in senv folder" 1
)
set "builds_dir=%senv_dir%\builds"
%_info% "builds folder full path: '%builds_dir%'"

set "sbem=SENV_BUILD_ERROR_MODE='%SENV_BUILD_ERROR_MODE%'"
for /f "delims=" %%x in ('git -C "%custom_dir%" status --porcelain') do set "st=%%x"
if defined SENV_BUILD_SKIP_STATUS (
    %_warning% "Skip git status check, SENV_BUILD_SKIP_STATUS set"
    goto:skipcl
)
%_info% "SENV_BUILD_SKIP_STATUS not set: check git status in senv and senv\custom"
if not "%st%"=="" (
    if "%SENV_BUILD_ERROR_MODE%"=="custom" (
        %_error% "Not a clean git status in custom '%custom_dir%' (%sbem%)"
    ) else if "%SENV_BUILD_ERROR_MODE%"=="both" (
        %_error% "Not a clean git status in custom '%custom_dir%' (%sbem%)"
    ) else (
        %_fatal% "Not a clean git status in custom '%custom_dir%' (%sbem%)" 1
    )
)
for /f "delims=" %%x in ('git -C "%senv_dir%" status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    if "%SENV_BUILD_ERROR_MODE%"=="senv" (
        %_error% "Not a clean git status in senv '%senv_dir%' (%sbem%)"
    ) else if "%SENV_BUILD_ERROR_MODE%"=="both" (
        %_error% "Not a clean git status in senv '%senv_dir%' (%sbem%)"
    ) else (
        %_fatal% "Not a clean git status in senv '%senv_dir%' (%sbem%)" 1
    )
)
rem @echo on

:skipcl
for /f "tokens=* delims=" %%i in ('git -C "%custom_dir%" describe --long --all HEAD') do SET "vcsenv=%%i"
for /f "tokens=* delims=" %%i in ('git -C "%custom_dir%\.." describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
echo %vcsenv%>"%custom_dir%\version"
rem %_fatal% "stop for now" 1

if exist "%builds_dir%\build.pre.bat" ( call "%builds_dir%\build.pre.bat" )

cd %senv_dir%
call gcuvc
cd %custom_dir%
call gcuu

set s="setupsdir_%profile%.bat"
if exist "%custom_dir%\%s%" (
    call:build_for_profile
    goto:eof
)
%_warning% "setupsdir script '%s%' does not exist"
%_task% "Must look for any 'setupsdir_%profile%*.bat' script in '%custom_dir%'"

set "foundMatch="
for %%F in ("%custom_dir%\setupsdir_%profile%*.bat") do (
    set "fname=%%~nxF"
    rem Remove the "setupsdir_" prefix and ".bat" suffix to form the new profile value
    set "newProfile=!fname:setupsdir_=!"
    set "newProfile=!newProfile:.bat=!"
    %_info% "Found alternative setupsdir: %%F, setting profile to '!newProfile!'"
    set "profile=!newProfile!"
    call :build_for_profile
    set "foundMatch=1"
)
if not defined foundMatch (
    %_fatal% "No setupsdir script matching 'setupsdir_%profile%*.bat' exists" 22
)
goto:eof

:build_for_profile
call "%custom_dir%\setupsdir_%profile%.bat"
if errorlevel 1 (
    %_error% "Unable to call '%custom_dir%\setupsdir_%profile%.bat'" && exit /b 1)
)
%_info% "setupsdir='%setupsdir%'"
for %%i in ("%setupsdir%\..") do ( set "remote_senv_dir=%%~fi" )

if not exist "%remote_senv_dir%\version" (
    %_ok% "New publication"
    goto:build_and_publish
)
if defined senv_force_build (
    %_warning% "senv_force_build env var is defined"
    %_task% "Force build senv '%profile%' with '%vcsenv%'"
    goto:build_and_publish
)
for /f "delims=" %%a in ('type "%remote_senv_dir%\version"') do (
    if "%%a"=="%vcsenv%" (
        %_ok% "Already published senv '%profile%' with '%vcsenv%' (senv_force_build not defined)"
        goto:eof
    ) else (
        %_task% "Update senv '%profile%' with '%vcsenv%' (from '%%a')"
    )
    goto :build_and_publish
)

:build_and_publish
cd "%builds_dir%"
del "senv_%profile%-zip.exe"
%_info% "zip '[%PRGS%\]senv' to '%builds_dir%\senv_%profile%.zip'"
copy "%senv_dir%\.git\config" "%builds_dir%\senv_git_config.bkp"
copy "%builds_dir%\senv_git_config.fixed" "%senv_dir%\.git\config"
copy "%custom_dir%\.git\config" "%builds_dir%\custom_git_config.bkp"
copy "%custom_dir%\custom_git_config.fixed" "%custom_dir%\.git\config"
copy "%custom_dir%\profile" "%builds_dir%\profile.bkp"
echo %profile%>"%custom_dir%\profile"
rem https://stackoverflow.com/questions/38297172/7-zip-command-line-incorrect-wildcard-type-marker
%sz% a -sfx7z.sfx "%builds_dir%\senv_%profile%-zip.exe" "%PRGS%\senv" -x^^!*.fixed -x^^!\*.bkp -xr^^!venvs -xr^^!builds\ -x^^!\*.zip.exe
rem C:\Users\vonc\prgs\senv\builds>%sz% e senv_home-zip.exe senv\.git\config -so
if not "%ERRORLEVEL%"=="0" (
    copy "%builds_dir%\profile.bkp" "%custom_dir%\profile"
    copy "%builds_dir%\custom_git_config.bkp" "%custom_dir%\.git\config"
    copy "%builds_dir%\senv_git_config.bkp" "%senv_dir%\.git\config"
    %_fatal% "Unable 7z '%builds_dir%\senv' to '%CD%' 'senv_%profile%-zip.exe'" && exit /b 1
)
copy "%builds_dir%\profile.bkp" "%custom_dir%\profile"
copy "%builds_dir%\custom_git_config.bkp" "%custom_dir%\.git\config"
copy "%builds_dir%\senv_git_config.bkp" "%senv_dir%\.git\config"
cd "%custom_dir%"

%_task% "Must update 'senv_%profile%-zip.exe' from '%builds_dir%' to '%setupsdir%'"
rem @echo on
set OK="KO"
robocopy "%builds_dir%" "%setupsdir%" "senv_%profile%-zip.exe" /Z /R:2 /W:2 /TBD /MT:16 /NJH /NJS
IF %ERRORLEVEL% LSS 8 (
    rem echo "ERRORLEVEL='%ERRORLEVEL%'"
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
rem echo "OK='%OK%' '!OK!'"
if not "%OK%"=="ok" ( %_error% "Unable to robocopy '%builds_dir%\senv_%profile%-zip.exe' to '%setupsdir%': errorlevel '%OK%'" && goto:eof)
%_ok% "senv_%profile%-zip.exe updated from '%builds_dir%' to '%setupsdir%'"

copy /Y "%custom_dir%\version" "%remote_senv_dir%\version"
if errorlevel 1 (
    %_fatal% "Unable to copy 'version' from '%custom_dir%' to '%remote_senv_dir%'" && exit /b 1)
)

copy /Y "%bc%\echos_macros.bat" "%remote_senv_dir%\echos_macros.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'echos_macros.bat' from '%custom_dir%' to '%remote_senv_dir%'" && exit /b 1)
)
copy /Y "%bc%\echos.bat" "%remote_senv_dir%\echos.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'echos.bat' from '%custom_dir%' to '%remote_senv_dir%'" && exit /b 1)
)

copy /Y "%custom_dir%\remote_setup.bat" "%remote_senv_dir%\remote_setup.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'remote_setup.bat' from '%custom_dir%' to '%remote_senv_dir%'" && exit /b 1)
)

copy /Y "%custom_dir%\setup.ini.bat" "%remote_senv_dir%\setup.ini.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'setup.ini.bat' from '%custom_dir%' to '%remote_senv_dir%'" && exit /b 1)
)
copy /Y "%custom_dir%\detection_VDI.bat" "%remote_senv_dir%\detection_VDI.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'detection_VDI.bat' from '%custom_dir%' to '%remote_senv_dir%'" && exit /b 1)
)
copy /Y "%custom_dir%\ss.bat" "%setupsdir%\s.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 's.bat' from '%custom_dir%' to '%setupsdir%'" && exit /b 1)
)
copy /Y "%custom_dir%\..\check_migrate_home.bat" "%setupsdir%\check_migrate_home.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'check_migrate_home.bat' from '%custom_dir%\..' to '%setupsdir%'" && exit /b 1)
)


if "%setupsdirsenv%"=="" (
    %_fatal% "setupsdirsenv empty. Check '%custom_dir%\setupsdir_%profile%.bat'" && exit /b 1)
)
echo call remote_setup.bat %profile%>"%setupsdirsenv%\s.bat"
rem echo call %setupsdirsenv%\remote_setup.bat %profile%>%setupsdir%\s.bat
if exist "%builds_dir%\build.post.bat" ( call "%builds_dir%\build.post.bat" )
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof