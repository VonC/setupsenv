@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(check_migrate_home)='%script_dir%'"

where grep >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    %_fatal% "check_migrate_home: grep.exe is not referenced in the PATH" 1
)

set "LOCAL_HOME=%USERPROFILE%\home_senv"
if "%HOME%"=="%LOCAL_HOME%" (
    %_ok% "HOME is already set to local private folder '%HOME%'"
    if "%REMOTE_HOME%"=="" (
        %_fatal% "REMOTE_HOME is not defined" 1
    )
    REM if FORCE is not set, end the program right there
    if "%FORCE%"=="" (
        goto:eof
    )
) else (
    %_task% "HOME '%HOME%' must be migrated to is '%LOCAL_HOME%'"
)
mkdir "%LOCAL_HOME%" 2>NUL:

rem if REMOTE_HOME is not defined or empty, set it to home which is still a remote one
if "%REMOTE_HOME%"=="" (
    set "REMOTE_HOME=%HOME%"
)
rem At this point, REMOTE_HOME mut NOT be equal to LOCAL_HOME
if "%REMOTE_HOME%"=="%LOCAL_HOME%" (
    %_fatal% "REMOTE_HOME '%REMOTE_HOME%' must not be equal to LOCAL_HOME '%LOCAL_HOME%'" 1
)

call:get_state
if not "%state%"=="%state:_copied_=%" (
    %_ok% "Skip copy/update '%HOME%' to '%LOCAL_HOME%' because state '%state%'"
    goto :nocopy 
)

%_info% "Copy/update '%HOME%' to '%LOCAL_HOME%'"
rem echo robocopy "%HOME%" "%LOCAL_HOME%" /XD "*.git"  /E /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS
(robocopy "%REMOTE_HOME%" "%LOCAL_HOME%" /XD "*.git" /XD "old" /E /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL=0
if not "%ERRORLEVEL%"=="0" ( 
    %_fatal% "Unable to copy REMOTE_HOME '%REMOTE_HOME%' to '%LOCAL_HOME%': errorlevel '%ERRORLEVEL%'" 1 
)
call:set_state _copied_

:nocopy

REM Check if LOCAL_HOME is a Git repository
cd "%LOCAL_HOME%" || echo "unable to cd to LOCAL_HOME '%LOCAL_HOME%'"&& exit /b 1
if not exist "%LOCAL_HOME%\.git" (
    %_task% "Initialize git in '%LOCAL_HOME%'"
    git init
    git add .
    call "%LOCAL_HOME%\bin\gcu.bat"
    git commit -m "initial commit"
    if not "%ERRORLEVEL%"=="0" ( %_fatal% "Unable to create first commit in local HOME '%LOCAL_HOME%\bin'" 1 )
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
        if not "%ERRORLEVEL%"=="0" ( %_fatal% "Unable to add commit in local HOME '%LOCAL_HOME%\bin'" 1 )
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
    if not "%ERRORLEVEL%"=="0" ( %_fatal% "Unable to create remote home '%REMOTE_HOME_REPO%' bare Git repository" 1 )
) else (
    %_ok% "Remote home '%REMOTE_HOME_REPO%' already exists"
)

rem @echo on
call:get_state
if not "%state%"=="%state:_updated_=%" (
    %_ok% "Skip env update '%LOCAL_HOME%\bin\senv.local.pre.bat'"
    goto :noupdate
)

REM make sure senv.local.pre.bat include the correct HOME path, as well as REMOTE_HOME
set "escLOCAL_HOME=%LOCAL_HOME:\=\\\\%"
grep -q "set \"HOME=%escLOCAL_HOME%" "%LOCAL_HOME%\bin\senv.local.pre.bat"
if not "%ERRORLEVEL%"=="0" (
    grep -Eq "set.*\"?HOME\s*?=" "%LOCAL_HOME%\bin\senv.local.pre.bat"
    if not "!ERRORLEVEL!"=="0" (
        %_task% "Must add LOCAL_HOME '%LOCAL_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
        call "%script_dir%\bin\check_trailing_newline.bat" "%LOCAL_HOME%\bin\senv.local.pre.bat"
        if "%ERRORLEVEL%"=="2" ( echo.>> "%LOCAL_HOME%\bin\senv.local.pre.bat" )
        echo. >> "%LOCAL_HOME%\bin\senv.local.pre.bat" & echo set "HOME=%LOCAL_HOME%" >> "%LOCAL_HOME%\bin\senv.local.pre.bat"
        if not "!ERRORLEVEL!"=="0" (
            %_fatal% "Unable to add LOCAL_HOME '%LOCAL_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'" 1
        ) else (
            %_ok% "LOCAL_HOME '%LOCAL_HOME%' added in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
        )
    ) else (
        %_task% "Must replace REMOTE_HOME '%REMOTE_HOME%' by LOCAL_HOME '%LOCAL_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
        sed -i "s/set\s*HOME=.*/set \"HOME=%escLOCAL_HOME%\"/" "%LOCAL_HOME%\bin\senv.local.pre.bat"
        set "el=!ERRORLEVEL!"
        sed -i "s/set\s*\"HOME=.*/set \"HOME=%escLOCAL_HOME%\"/" "%LOCAL_HOME%\bin\senv.local.pre.bat"
        set "el="!el!!ERRORLEVEL!"
        if "!el!"=="11" (
            %_fatal% "Unable to replace REMOTE_HOME '%REMOTE_HOME%' by LOCAL_HOME '%LOCAL_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'" 1
        ) else (
            %_ok% "REMOTE_HOME '%REMOTE_HOME%' replaced by LOCAL_HOME '%LOCAL_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
        )
    )
) else (
    %_ok% "HOME is correctly set to LOCAL_HOME '%LOCAL_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
)

set "escREMOTE_HOME=%REMOTE_HOME:\=\\\\%"
grep -q "set \"REMOTE_HOME=%escREMOTE_HOME%" "%LOCAL_HOME%\bin\senv.local.pre.bat"
if not "%ERRORLEVEL%"=="0" (
    %_task% "Must add REMOTE_HOME '%REMOTE_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
    echo. >> "%LOCAL_HOME%\bin\senv.local.pre.bat" & echo set "REMOTE_HOME=%REMOTE_HOME%" >> "%LOCAL_HOME%\bin\senv.local.pre.bat"
    if not "!ERRORLEVEL!"=="0" (
        %_fatal% "Unable to add REMOTE_HOME '%REMOTE_HOME%' in '%LOCAL_HOME%\bin\senv.local.pre.bat'" 1
    ) else (
        %_ok% "REMOTE_HOME '%REMOTE_HOME%' added in '%LOCAL_HOME%\bin\senv.local.pre.bat'"
    )
)
call:set_state _updated_

:noupdate

call:get_state
if not "%state%"=="%state:_nosenvupdate_=%" (
    %_ok% "Skip env update '%LOCAL_HOME%\bin\senv.local.pre.bat'"
    goto :nosenvupdate
)
rem @echo on
set "escLOCAL_HOME=%LOCAL_HOME:\=\\\\%"
grep -q "call \"%escLOCAL_HOME%\\\\bin\\\\senv.bat" "%USERPROFILE%\senv.bat"
if not "%ERRORLEVEL%"=="0" (
        %_task% "Must replace REMOTE_HOME '%REMOTE_HOME%' path by LOCAL_HOME '%LOCAL_HOME%' path in '%USERPROFILE%\senv.bat'"
        sed -i "s/call.*/call \"%escLOCAL_HOME%\\\\bin\\\\senv.bat\"/" "%USERPROFILE%\senv.bat"
) else (
    %_ok% "'%USERPROFILE%\senv.bat' already references senv.bat from LOCAL_HOME '%LOCAL_HOME%\bin'"
)
call:set_state _nosenvupdate_

:nosenvupdate

call:get_state
if not "%state%"=="%state:_cleaned_=%" (
    %_ok% "Skip cleaning out REMOTE_HOME '%REMOTE_HOME%' because state '%state%'"
    goto :cleandone
)

%_info% "Check cleanup REMOTE_HOME '%REMOTE_HOME%'"

if not exist "%REMOTE_HOME%\bin" (
    %_ok% "REMOTE_HOME '%REMOTE_HOME%' is clean"
    call:set_state _cleaned_
    goto :cleandone
)
%_task% "REMOTE_HOME '%REMOTE_HOME%' must be cleaned out" 1
if not exist "%REMOTE_HOME%\old" (
    mkdir "%REMOTE_HOME%\old"
    if not "%ERRORLEVEL%"=="0" ( %_fatal% "Unable to create remote home old '%REMOTE_HOME%\old' folder" 1 )
    %_ok% "Remote home old '%REMOTE_HOME%\old' folder created"
) else (
    %_ok% "Remote home old '%REMOTE_HOME%\old' folder already exists"
)
(robocopy "%REMOTE_HOME%" "%REMOTE_HOME%\old" /E /MOVE /XF state /XD old /XD home_senv.git /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET OKRC=0 else set OKRC=%ERRORLEVEL%
if not "%OKRC%"=="0" (
    %_fatal% "Unable to copy REMOTE_HOME '%REMOTE_HOME%' to '%LOCAL_HOME%': errorlevel '%OKRC%'" 1
)
%_ok% "REMOTE_HOME '%REMOTE_HOME%' cleaned out"
call:set_state _cleaned_

:cleandone
goto:eof

:get_state
REM read %REMOTE_HOME%\state file content, store it in %state% local environment variable
set "state="
if not exist "%REMOTE_HOME%\state" (
    echo._none_> "%REMOTE_HOME%\state"
)
for /f "delims=" %%i in (%REMOTE_HOME%\state) do set "state=!state! %%i"
%_info% "The content of '%REMOTE_HOME%\state' is: '!state!'"
goto:eof

:set_state
REM write the current local %state% environment variable to %REMOTE_HOME%\state, after having removed any space in it.
set "state=%state: =%%1"
echo %state%> "%REMOTE_HOME%\state
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
