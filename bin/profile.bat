@echo off
setlocal ENABLEDELAYEDEXPANSION

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "home_dir=%%~fi" )
call %home_dir%\batcolors\echos_macros.bat

FOR /F %%i IN ('cat %HOME%\bin\profile') DO set profileName=%%i
set "localmsg="
where publish_setname.bat >NUL 2>NUL
if not errorlevel 1 (
    set "localmsg= [LOCAL path activated]"
)
%_info% "profile name='%profileName%'%localmsg%"
:: Use FOR /F to capture all tokens starting from the third one, managing spaces in the profile folder name
FOR /F "tokens=3* delims= " %%i IN ('alias cdis') DO (
    set "profileFolder=%%i"
    set "rest=%%j"
    if defined rest (
        for %%k in (!rest!) do (
            set "profileFolder=!profileFolder! %%k"
        )
    )
)
set "profileFolder=%profileFolder:"=%"
%_info% "from profile setups folder '%profileFolder%'"


for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv\custom" describe --long --all HEAD') do SET "vcsenv=%%i"
for /f "tokens=* delims=" %%i in ('git -C "%PRGS%\senv" describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
for /f "tokens=* delims=" %%i in ('type "%PRGS%\senv\custom\version"') do SET "vc=%%i"
%_info% "version '%vc%', locale, at '%PRGS%\senv\custom\version'"

for %%i in ("%profileFolder%\..") do ( set "remote_senv=%%~fi" )
if exist "%remote_senv%\version" (
    for /f "tokens=* delims=" %%i in ('type "%remote_senv%\version"') do SET "remote_vc=%%i"
    %_info% "version '!remote_vc!', remote, at '%remote_senv%\version'"
) else (
    %_warning% "No version found at remote senv '%remote_senv%'"
)

rem https://stackoverflow.com/questions/2657935/checking-for-a-dirty-index-or-untracked-files-with-git
rem https://stackoverflow.com/a/2659808/6309
set "dirty_message="
git -C "%PRGS%\senv" diff-index --quiet HEAD --
if errorlevel 1 (
    set "dirty_message=local senv dirty"
)
git -C "%PRGS%\senv\custom" diff-index --quiet HEAD --
if errorlevel 1 (
    if defined dirty_message (
        set "dirty_message=%dirty_message%, and "
    )
    set "dirty_message=!dirty_message!local custom dirty"
)
if defined dirty_message (
    %_error% "%dirty_message%"
)

if "%vc%"=="%remote_vc%" (
    %_ok% "recorded senv version is up to date"
) else (
    %_warning% "recorded senv version is not up to date"
)
if "%vcsenv%"=="%remote_vc%" (
    %_ok% "local  `git describe` senv and senv/custom unchanged from remote recorded version"
    goto:eof
)

%_warning% "local `git describe` senv differs from recorded one"
for /f "tokens=3,6 delims=- " %%a in ('echo %remote_vc%') do (
    set "remote_senv_commit=%%b"
    set "remote_senv_custom_commit=%%a"
)
set "remote_senv_commit=%remote_senv_commit:g=%"
set "remote_senv_custom_commit=%remote_senv_custom_commit:g=%"
%_info% "Remote senv commit='%remote_senv_commit%', remote senv custom commit='%remote_senv_custom_commit%'"
for /f "tokens=3,6 delims=- " %%a in ('echo %vcsenv%') do (
    set "senv_commit=%%b"
    set "senv_custom_commit=%%a"
)
set "senv_commit=%senv_commit:g=%"
set "senv_custom_commit=%senv_custom_commit:g=%"
%_info% "Local  senv commit='%senv_commit%', local  senv custom commit='%senv_custom_commit%'"
set "update_message="
set "publish_message="
git -C "%PRGS%\senv" branch --contain %remote_senv_commit% >nul 2>nul
if errorlevel 1 (
    set "update_message=new remote commit in remote senv"
) else (
    set "publish_message=new local commit in senv"
)
git -C "%PRGS%\senv\custom" branch --contain %remote_senv_custom_commit% >nul 2>nul
if errorlevel 1 (
    if defined update_message (
        set "update_message=%update_message%, and "
    )
    set "update_message=!update_message!new remote commit in remote custom"
) else (
    if defined publish_message (
        set "publish_message=%publish_message%, and "
    )
    set "publish_message=!publish_message!new local commit in custom"
)
if defined publish_message (
    %_warning% "%publish_message%"
    %_task% "Must publish local senv to remote_senv '%remote_senv%'"
)
if defined update_message (
    %_warning% "%update_message%"
    %_task% "Should update local senv from remote_senv '%remote_senv%'"
    %_task% "Type upg, for a quick update of your senv, upa for a full update"
    %_task% "For older senv, type cdis, then s when you want to update your senv"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
