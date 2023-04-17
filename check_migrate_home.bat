@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(check_migrate_home)='%script_dir%'"

where grep >nul 2>&1
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "check_migrate_home: grep.exe is not referenced in the PATH" 1
)

set "LOCAL_HOME=%USERPROFILE%\home_senv"
if "%HOME%"=="%LOCAL_HOME%" (
    %_ok% "HOME is already set to local private folder '%HOME%'"    
    if "%REMOTE_HOME%" == "" (
        %_fatal% "REMOTE_HOME is not defined" 1
    )
    goto:eof
) else (
    %_task% "HOME '%HOME%' must be migrated to is '%LOCAL_HOME%'"
)
mkdir "%LOCAL_HOME%" 2>NUL:
set "REMOTE_HOME=%HOME%"
call:get_state
if not "%state%"=="%state:_copied_=%" (
    %_info% "Skip copy/update '%HOME%' to '%LOCAL_HOME%' because state '%state%'"
    goto :nocopy 
)

%_info% "Copy/update '%HOME%' to '%LOCAL_HOME%'"
rem echo robocopy "%HOME%" "%LOCAL_HOME%" /XD "*.git" /E /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS
(robocopy "%REMOTE_HOME%" "%LOCAL_HOME%" /XD "*.git" /E /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL=0
if not "%ERRORLEVEL%" == "0" ( 
    %_fatal% "Unable to copy REMOTE_HOME '%REMOTE_HOME%' to '%LOCAL_HOME%': errorlevel '%ERRORLEVEL%'" 1 
)
echo %state%_copied_ > "%REMOTE_HOME%\state

:nocopy

REM Check if LOCAL_HOME is a Git repository
cd "%LOCAL_HOME%" || echo "unable to cd to LOCAL_HOME '%LOCAL_HOME%'"&& exit /b 1
if not exist "%LOCAL_HOME%\.git" (
    %_task% "Initialize git in '%LOCAL_HOME%'"
    git init
    git add .
    call "%LOCAL_HOME%\bin\gcu.bat"
    git commit -m "initial commit"
    if not "%ERRORLEVEL%" == "0" ( %_fatal% "Unable to create first commit in local HOME '%LOCAL_HOME%\bin'" 1 )
    %_ok% "Git repository initialized in local HOME '%LOCAL_HOME%\bin' with first commmit done"
) else (
    %_ok% "git already initialized in '%LOCAL_HOME%'"
    cd
    REM Check if there is any file to be added to existing Git repository
    for /f "tokens=* delims=" %%a in ('git status --porcelain') do (
        set "gitstatus=!gitstatus!%%a"
    )
    if not "!gitstatus!"=="" (
        %_task% "Must update '%LOCAL_HOME%' Git repository because gitstatus='!gitstatus!'"
        set gitstatus=
        git add .
        git commit -m "Update '%LOCAL_HOME%' Git repository"
        if not "%ERRORLEVEL%" == "0" ( %_fatal% "Unable to add commit in local HOME '%LOCAL_HOME%\bin'" 1 )
        %_ok% "Git repository '%LOCAL_HOME%\bin' updated with new commit done"
    ) else (
        %_ok% "Git repository is clean"
    )
)

REM Make sure the REMOTE_HOME bare repository is ready
set "REMOTE_HOME_REPO=%REMOTE_HOME%\home_senv.git"
if not exist "%REMOTE_HOME_REPO%" (
    %_task% "Create remote home '%REMOTE_HOME_REPO%' bare repository"
    git init --bare "%REMOTE_HOME_REPO%" 2>NUL:
    if not "%ERRORLEVEL%" == "0" ( %_fatal% "Unable to create remote home '%REMOTE_HOME_REPO%' bare Git repository" 1 )
) else (
    %_ok% "Remote home '%REMOTE_HOME_REPO%' already exists"
)

@echo on
call "%script_dir%\replace_or_add_line_in_file.bat" "set HOME=%REMOTE_HOME%" 'set "HOME=%LOCAL_HOME%"' "%HOME%\bin\senv.local.pre.bat"
goto:eof

if exist "%REMOTE_HOME%\bin" (
    %_task% "REMOTE_HOME '%REMOTE_HOME%' must be cleaned out" 1
    if not exist "%REMOTE_HOME%\old" (
        mkdir "%REMOTE_HOME%\old"
        if not "%ERRORLEVEL%" == "0" ( %_fatal% "Unable to create remote home old '%REMOTE_HOME%\old' folder" 1 )
        %_ok% "Remote home old '%REMOTE_HOME%\old' folder created"
    ) else (
        %_ok% "Remote home old '%REMOTE_HOME%\old' folder already exists"
    )
) else (
    %_ok% "REMOTE_HOME '%REMOTE_HOME%' is clean"
)


goto:eof

:get_state
REM read %HOME%\state file content, store it in %state% local environment variable
set "state="
if not exist "%REMOTE_HOME%\state" (
    echo._none_> "%REMOTE_HOME%\state"
)
for /f "delims=" %%i in (%REMOTE_HOME%\state) do set "state=!state! %%i"
echo The content of '%REMOTE_HOME%\state' is: '%state%'
goto:eof