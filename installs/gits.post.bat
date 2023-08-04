@echo off
if "%script_dir%"=="" (
    setlocal enabledelayedexpansion
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
    call "!script_dir!\custom\echos_macros.bat"
)
%_info% "~~~~~~~~~~~~"
%_info% " Checking/updating '%HOME%\bin' content"
set ignorevscode=1
call "%HOME%\bin\senv.bat"
set ignorevscode=
%_info% "   [senv called]"
cd /d "%HOME%\bin"
if errorlevel 1 (%_fatal% "Unable to cd to %HOME%\bin" 111)
set FIRSTNAME=
set LASTNAME=
call %HOME%\bin\senv.local.pre.bat
%_info% "   [senv.local.pre.bat called]"
grep FIRSTNAME "%HOME%\bin\senv.local.pre.bat">NUL
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
echo set ^"FIRSTNAME=%FIRSTNAME%^"%NL%set ^"LASTNAME=%LASTNAME%^"%NL%>> "%HOME%\bin\senv.local.pre.bat"
set "FULLNAME=%LASTNAME%"
if not "%FIRSTNAME%"=="" (
    set "FULLNAME=%FIRSTNAME% %LASTNAME%"
)
echo set ^"FULLNAME=%FULLNAME%^"%NL%>> "%HOME%\bin\senv.local.pre.bat"

if "%USERMAIL%"=="" (
    set /P USERMAIL="Enter your email (no quotes needed): "
)
if "%USERMAIL%"=="" (
    %_fatal% "User email cannot be empty"&& exit /b 1
)
echo set ^"USERMAIL=%USERMAIL%^"%NL%>> "%HOME%\bin\senv.local.pre.bat"
echo git config user.name ^"%FULLNAME%^"%NL%git config user.email ^"%USERMAIL%^"%NL%> "%HOME%\bin\gcu.bat"

:userset
if not exist "%USERPROFILE%\git" ( mkdir "%USERPROFILE%\git" )
if not exist "%HOME%\bin\gcu.bat" (
    echo git config user.name ^"%FULLNAME%^"%NL%git config user.email ^"%USERMAIL%^"%NL%> "%HOME%\bin\gcu.bat"
    unix2dos "%HOME%\bin\gcu.bat"
)
if not "%prgtoinstall%"=="" (
    if not "%prgtoinstall%"=="%f%" (
        %_warning% "Skip '%f%' installation (for '%prgtoinstall%')"
        goto:eof
    )
)


git config --system credential.helper 1>NUL 2>NUL
if errorlevel 1 (
    git config --system credential.helper manager-core
) else (
    git config --system credential.helper | grep -i "selector" 1>NUL 2>NUL
    if errorlevel 0 (
        git config --system credential.helper manager-core
    ) else (
        git config --system credential.helper | grep "credential-manager" 1>NUL 2>NUL
        if errorlevel 0 (
            git config --system credential.helper manager-core
        ) else (
            git config --system credential.helper | grep "bin" 1>NUL 2>NUL
            if errorlevel 0 (
                git config --system credential.helper manager-core
            ) else (
                git config --system credential.helper | grep "git-core" 1>NUL 2>NUL
                if errorlevel 0 (
                    git config --system credential.helper manager-core
                )
            )
        )
    )
)
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
git config --global credential.helper manager-core
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
git config --global credential.helperselector.selected manager-core


"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL 2>NUL
if exist "%HOME%\bin\.git\config" (
    grep bare "%HOME%\bin\.git\config" 1>NUL 2>NUL
    if errorlevel 1 (
        %_warning% "%HOME%\bin\.git\config incomplete: delete and redo"
        del /Q .git\config
        if errorlevel 1 (
            %_error% "%HOME%\bin\.git\config unable to be deleted"
        )
    )
)
if not exist "%HOME%\bin\.git\config" (
    %_info% "Initialize git repository in %HOME%\bin"
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    git init "%HOME%\bin"
)
if not exist "%HOME%\bin\.git\objects" (
    mkdir "%HOME%\bin\.git\objects"
)
grep bare "%HOME%\bin\.git\config" 1>NUL 2>NUL
if errorlevel 1 (
    copy /Y "%script_dir%\bin\.git_config" "%HOME%\bin\.git\config"
)
if not exist "%HOME%\bin\.gitignore" (  copy "%script_dir%\bin\.gitignore" "%HOME%\bin" )

cd /d "%HOME%\bin"
if errorlevel 1 (%_fatal% "Unable to cd to %HOME%\bin" 111)
%_info% "   [Check 'git config --local user.name' in '%HOME%\bin']"
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL
git -C "%HOME%\bin" config --local user.name>NUL
if errorlevel 1 ( "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL && call "%HOME%\bin\gcu.bat" )
%_info% "   [Check 'git config --local user.email' in '%HOME%\bin']"
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL
git -C "%HOME%\bin" config --local user.email>NUL
if errorlevel 1 ( "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL && call "%HOME%\bin\gcu.bat" )
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL

call:check_gitdate
%_info% "   [nomodif='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipfirststatus)
if exist "%HOME%\bin\.git\index.lock" (sleep 1)
if exist "%HOME%\bin\.git\index.lock" (%_fatal% "%HOME%\bin used by other Git process (close VSCode if opened) and relaunch setup" 11)
%_info% "   [Calling first git status --porcelain in '%HOME%\bin']"
set st=
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_info% "Save local modification of '%HOME%\bin'"
    rem %_fatal% "no local save" 111
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL
    git add .
    git commit -m "pre-update"
)
:skipfirststatus
%_info% "   [copy bin in '%HOME%\bin']"
copy /Y "%script_dir%\bin\*" . > NUL:
%_info% "   [Copy senv.doskey in '%HOME%\bin']"
copy /Y "%script_dir%\bin\senv.doskey" . > NUL: 
%_info% "   [Delete s.bat in '%HOME%\bin']"
if exist s.bat ( del s.bat > NUL: )
if exist setup.bat ( del setup.bat > NUL: )
%_info% "   [Copy custom\*.custom in '%HOME%\bin']"
copy /Y "%script_dir%\custom\*.custom.*" "%HOME%\bin" 1>NUL: 2>NUL:
%_info% "   [Copy custom\bin in '%HOME%\bin']"
copy /Y "%script_dir%\custom\bin\*" "%HOME%\bin" > NUL:


call:check_gitdate
%_info% "   [nomodif(2)='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipsecondstatus)
%_info% "   [Calling Second git status --porcelain in '%HOME%\bin']"
set st=
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_info% "Save new updates of '%HOME%\bin'"
    rem %_fatal% "no new update save" 112
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\bin\.git\config" 1>NUL
    git add --renormalize .
    git commit -m "post-update"
)
:skipsecondstatus
touch .git\COMMIT_EDITMSG
%_info% "~~~~~~~~~~~~"
call "%script_dir%\installs\gits.config.utils.bat" :restore_gitconfig system gits.post.bat

if not exist "%HOME%\.ssh" ( mkdir "%HOME%\.ssh" )

if exist "%setupsdir%\gitcred.exe" (
    %_info% "Copy/update %HOME%\bin\gitcred.exe from %setupsdir%"
    (robocopy "%setupsdir%" "%HOME%\bin" "gitcred.exe" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
    if not "%ERRORLEVEL%"=="0" ( %_warning% "Unable to copy '%setupsdir%\gitcred.exe' to '%HOME%\bin\'" && exit /b 0)
    copy /Y "%HOME%\bin\gitcred.exe" "%HOME%\bin\git-cred.exe"
    %_ok% "'gitcred.exe' in '%HOME%\bin\' updated from '%setupsdir%'"
)

exit /b 0
goto:eof

:check_gitdate
set nomodif=
set newest=
if not exist .git\COMMIT_EDITMSG (goto:eof)
copy .git\COMMIT_EDITMSG . >NUL
for /f "tokens=*" %%a in ('dir /b /od') do set newest=%%a
%_info% "newest=%newest% !newest!"
if "%newest%"=="COMMIT_EDITMSG" ( set "nomodif=1" )
set newest=
del COMMIT_EDITMSG
goto:eof

