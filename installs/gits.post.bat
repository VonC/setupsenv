@echo off
if "%script_dir%"=="" (
    setlocal enabledelayedexpansion
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
    call "!script_dir!\custom\echos_macros.bat"
    set "prgtoinstall=test"
    set "f=test"
)
%_info% "[%~nx0] ~~~~~~~~~~~~"
set "HOMEBIN=%HOME%\bin"
%_info% "[%~nx0]  Checking/updating '%HOMEBIN%' content, script_dir='%script_dir%', prgtoinstall='%prgtoinstall%', f='%f%'"
set "internalsenvcall=1"
call "%HOMEBIN%\senv.bat"
set "internalsenvcall="
%_info% "[%~nx0]    [senv called]"
cd /d "%HOMEBIN%"
if errorlevel 1 (%_fatal% "[%~nx0] Unable to cd to %HOMEBIN%" 111)
set FIRSTNAME=
set LASTNAME=
call "%HOMEBIN%\senv.local.pre.bat"
%_info% "[%~nx0]    [senv.local.pre.bat called]"
grep FIRSTNAME "%HOMEBIN%\senv.local.pre.bat">NUL
if "%ERRORLEVEL%"=="0" ( goto:userset )
if "%FIRSTNAME%"=="" (
    set /P FIRSTNAME="Enter your first name (no quotes needed, can be empty): "
)
if "%LASTNAME%"=="" (
    set /P LASTNAME="Enter your Last name (no quotes needed, default '%USERNAME%'): "
)
if "%LASTNAME%"=="" (
    set "LASTNAME=%USERNAME%"
)
call "%script_dir%\bin\check_trailing_newline.bat" "%HOMEBIN%\senv.local.pre.bat"
if "%ERRORLEVEL%"=="2" ( echo.>> "%HOMEBIN%\senv.local.pre.bat" )
echo set ^"FIRSTNAME=%FIRSTNAME%^"%NL%set ^"LASTNAME=%LASTNAME%^"%NL%>> "%HOMEBIN%\senv.local.pre.bat"
set "FULLNAME=%LASTNAME%"
if not "%FIRSTNAME%"=="" (
    set "FULLNAME=%FIRSTNAME% %LASTNAME%"
)
echo set ^"FULLNAME=%FULLNAME%^"%NL%>> "%HOMEBIN%\senv.local.pre.bat"

if "%USERMAIL%"=="" (
    set /P USERMAIL="Enter your email (no quotes needed): "
)
if "%USERMAIL%"=="" (
    %_fatal% "[%~nx0] User email cannot be empty"&& exit /b 1
)
echo set ^"USERMAIL=%USERMAIL%^"%NL%>> "%HOMEBIN%\senv.local.pre.bat"
echo git config user.name ^"%FULLNAME%^"%NL%git config user.email ^"%USERMAIL%^"%NL%> "%HOMEBIN%\gcu.bat"

:userset
if not exist "%USERPROFILE%\git" ( mkdir "%USERPROFILE%\git" )
if not exist "%HOMEBIN%\gcu.bat" (
    echo git config user.name ^"%FULLNAME%^"%NL%git config user.email ^"%USERMAIL%^"%NL%> "%HOMEBIN%\gcu.bat"
    unix2dos "%HOMEBIN%\gcu.bat"
)
if not "%prgtoinstall%"=="" (
    if not "%prgtoinstall%"=="%f%" (
        %_warning% "[%~nx0] Skip '%f%' installation (for '%prgtoinstall%')"
        goto:eof
    )
)

@echo off
set "mgrname=manager"
:: The command to get the version string
for /f "tokens=2 delims= " %%a in ('type "%PRGS%\gits\current\etc\package-versions.txt" ^| findstr "mingw-w64-x86_64-git-doc-html"') do (
    set "fullversion=%%a"
)
:: Extract the major and minor version numbers
for /f "tokens=1,2 delims=." %%b in ("!fullversion!") do (
    set "major=%%b"
    set "minor=%%c"
)

if !major! LEQ 2 (
    if !minor! LEQ 39 (
        %_info% "[%~nx0] Install: Keep 'manager-core' as credential helper for Git !major!.!minor!"
        set "mgrname=manager-core"
    )
)
if "%mgrname%"=="manager" (
    %_info% "[%~nx0] Install: Keep 'manager' as credential helper for Git !major!.!minor!"
)

git config --system credential.helper 1>NUL 2>NUL
if errorlevel 1 (
    git config --system credential.helper %mgrname%
) else (
    git config --system credential.helper | grep -i "selector" 1>NUL 2>NUL
    if errorlevel 0 (
        git config --system credential.helper %mgrname%
    ) else (
        git config --system credential.helper | grep "credential-manager" 1>NUL 2>NUL
        if errorlevel 0 (
            git config --system credential.helper %mgrname%
        ) else (
            git config --system credential.helper | grep "bin" 1>NUL 2>NUL
            if errorlevel 0 (
                git config --system credential.helper %mgrname%
            ) else (
                git config --system credential.helper | grep "git-core" 1>NUL 2>NUL
                if errorlevel 0 (
                    git config --system credential.helper %mgrname%
                )
            )
        )
    )
)
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
git config --global credential.helper %mgrname%
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
git config --global credential.helperselector.selected %mgrname%

:gitpath
set "GITPATH=%HOME%"
set "GITNOPATH=%HOMEBIN%"

REM Get the first two characters of PATH
set "firstTwo=%PATH:~0,2%"

REM Check if it starts with C: or c:
if not "%firstTwo%"=="C:" (
    if not "%firstTwo%"=="c:" (
        set "GITPATH=%HOMEBIN%"
        set "GITNOPATH=%HOME%"
    )
)

%_info% "[%~nx0] GITPATH='%GITPATH%' (no Git repo in GITNOPATH='%GITNOPATH%', firstTwo='%firstTwo%')"

if exist "%GITNOPATH%\.git\config" (
    %_warning% "[%~nx0] Git repository in '%GITNOPATH%' instead of '%GITPATH%'"
    %_task% "[%~nx0] Must delete '%GITNOPATH%\.git'"
    rmdir /S /Q "%GITNOPATH%\.git"
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to delete Git repository in '%GITNOPATH%'"
    )
    ok "Git repository in '%GITNOPATH%' deleted"
)

"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL 2>NUL
if exist "%GITPATH%\.git\config" (
    grep bare "%GITPATH%\.git\config" 1>NUL 2>NUL
    if errorlevel 1 (
        %_warning% "[%~nx0] %GITPATH%\.git\config incomplete: delete and redo"
        del /Q "%GITPATH%\.git\config"
        if errorlevel 1 (
            %_error% "[%~nx0] %GITPATH%\.git\config unable to be deleted"
        )
    )
)

if not exist "%GITPATH%\.git\config" (
    %_info% "[%~nx0] Initialize git repository in '%GITPATH%'"
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    git init "%GITPATH%"
)
if not exist "%GITPATH%\.git\objects" (
    mkdir "%GITPATH%\.git\objects"
)
grep bare "%GITPATH%\.git\config" 1>NUL 2>NUL
if errorlevel 1 (
    copy /Y "%script_dir%\.gitconfig" "%GITPATH%\.git\config"
)
if not exist "%GITPATH%\.gitignore" (
    copy "%script_dir%\bin\.gitignore" "%GITPATH%" )
%_task% "[%~nx0] Must check if '/batcolors/' is in '%GITPATH%\.gitignore'"
findstr /BC:/batcolors/ "%GITPATH%\.gitignore" 1>NUL 2>NUL
if not errorlevel 1 (
    %_ok% "[%~nx0] '/batcolors/' already in '%GITPATH%\.gitignore'"
    goto:cd_gitpath
)
%_task% "[%~nx0] Must add '/batcolors/' in '%GITPATH%\.gitignore'"
call "%script_dir%\bin\check_trailing_newline.bat" "%GITPATH%\.gitignore"
if "%ERRORLEVEL%"=="2" ( echo.>> "%GITPATH%\.gitignore" )
echo /batcolors>>"%GITPATH%\.gitignore"
echo /batcolors/>>"%GITPATH%\.gitignore"

:cd_gitpath
cd /d "%GITPATH%"
if errorlevel 1 (%_fatal% "[%~nx0] Unable to cd to '%GITPATH%'" 111)
%_info% "[%~nx0]    [Check 'git config --local user.name' in '%GITPATH%']"
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
git -C "%GITPATH%" config --local user.name>NUL
if errorlevel 1 ( "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL && call "%HOMEBIN%\gcu.bat" )
%_info% "[%~nx0]    [Check 'git config --local user.email' in '%GITPATH%']"
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
git -C "%GITPATH%" config --local user.email>NUL
if errorlevel 1 ( "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL && call "%HOMEBIN%\gcu.bat" )
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL

call:check_gitdate
%_info% "[%~nx0]    [nomodif='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipfirststatus)
if exist "%GITPATH%\.git\index.lock" (sleep 1)
if exist "%GITPATH%\.git\index.lock" (%_fatal% "[%~nx0] '%GITPATH%' used by other Git process (close VSCode if opened) and relaunch setup" 11)
%_info% "[%~nx0]    [Calling first git status --porcelain in '%GITPATH%']"
set st=
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_info% "[%~nx0] Save local modification of '%GITPATH%'"
    rem %_fatal% "[%~nx0] no local save" 111
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
    git add .
    git commit -m "pre-update"
)
:skipfirststatus
%_task% "[%~nx0] Must update HOMEBIN '%HOMEBIN%'"
cd /d "%HOMEBIN%"
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to access HOMEBIN '%HOMEBIN%'" 111
)
%_info% "[%~nx0]    [copy script_dir\bin '%script_dir%\bin\*' in HOMEBIN '%HOMEBIN%']"
copy /Y "%script_dir%\bin\*" . > NUL:
%_info% "[%~nx0]    [Copy senv.doskey in '%HOMEBIN%']"
copy /Y "%script_dir%\bin\senv.doskey" . > NUL: 
%_info% "[%~nx0]    [Delete s.bat in '%HOMEBIN%']"
if exist s.bat ( del s.bat > NUL: )
if exist setup.bat ( del setup.bat > NUL: )
%_info% "[%~nx0]    [Copy custom\*.custom in '%HOMEBIN%']"
copy /Y "%script_dir%\custom\*.custom.*" "%HOMEBIN%" 1>NUL: 2>NUL:
%_info% "[%~nx0]    [Copy custom\bin in '%HOMEBIN%']"
copy /Y "%script_dir%\custom\bin\*" "%HOMEBIN%" > NUL:


call:check_gitdate
%_info% "[%~nx0]    [nomodif(2)='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipsecondstatus)
%_info% "[%~nx0]    [Calling Second git status --porcelain in '%HOMEBIN%']"
set st=
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_info% "[%~nx0] Save new updates of '%GITPATH%'"
    rem %_fatal% "[%~nx0] no new update save" 112
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
    git add --renormalize .
    git commit -m "post-update"
)
:skipsecondstatus
touch .git\COMMIT_EDITMSG
%_info% "[%~nx0] ~~~~~~~~~~~~"
call "%script_dir%\installs\gits.config.utils.bat" :restore_gitconfig system gits.post.bat

if not exist "%HOME%\.ssh" ( mkdir "%HOME%\.ssh" )

if exist "%setupsdir%\gitcred.exe" (
    %_info% "[%~nx0] Copy/update '%HOMEBIN%\gitcred.exe' from %setupsdir%"
    (robocopy "%setupsdir%" "%HOMEBIN%" "gitcred.exe" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
    if not "%ERRORLEVEL%"=="0" ( %_warning% "[%~nx0] Unable to copy '%setupsdir%\gitcred.exe' to '%HOMEBIN%\'" && exit /b 0)
    copy /Y "%HOMEBIN%\gitcred.exe" "%HOMEBIN%\git-cred.exe"
    %_ok% "[%~nx0] 'gitcred.exe' in '%HOMEBIN%\' updated from '%setupsdir%'"
)
rem script_dir
%_info% "[%~nx0] Copy/update '%HOME%\batcolors\' from %script_dir%"
if not exist "%HOME%\batcolors" ( mkdir "%HOME%\batcolors" )
(robocopy "%script_dir%\batcolors " "%HOME%\batcolors" /e /dcopy:T /mt /r:5 /NJH /NJS /NFL) ^& set rbc_errorlevel=%ERRORLEVEL%
IF %rbc_errorlevel% LSS 8 SET rbc_errorlevel = 0
if not "%rbc_errorlevel%"=="0" ( %_error% "[%~nx0] Unable to copy '%script_dir%\batcolors' to '%HOME%\': rbc_errorlevel='%rbc_errorlevel%'" && exit /b 0)
%_ok% "[%~nx0] 'batcolors/' in '%HOME%\' updated from '%script_dir%'"

exit /b 0
goto:eof

:check_gitdate
set nomodif=
set newest=
if not exist .git\COMMIT_EDITMSG (goto:eof)
copy .git\COMMIT_EDITMSG . >NUL
for /f "tokens=*" %%a in ('dir /b /od') do set newest=%%a
%_info% "[%~nx0] newest=%newest% !newest!"
if "%newest%"=="COMMIT_EDITMSG" ( set "nomodif=1" )
set newest=
del COMMIT_EDITMSG
goto:eof

