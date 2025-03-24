@echo off

setlocal enabledelayedexpansion
for %%i in ("%~dp0") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "custom_dir=%senv_dir%\custom"
set "bin_dir=%senv_dir%\bin"
set "installs_dir=%senv_dir%\installs"

if not defined profile (
    if not defined senv_profile (
        %_fatal% "no profile defined (senv_profile not set)" 19
    )
    set "profile=%senv_profile%"
)

if not defined HOME (
    %_fatal% "HOME not defined" 20
)

%_info% "for profile '%profile%' ~~~~~~~~~~~~"
set "HOMEBIN=%HOME%\bin"
%_info% " Checking/updating '%HOMEBIN%' content, script_dir='%script_dir%', prgtoinstall='%prgtoinstall%', f='%f%'"
set "internalsenvcall=1"
call "%HOMEBIN%\senv.bat"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "internalsenvcall="
%_info% "   [senv called]"
cd /d "%HOMEBIN%"
if errorlevel 1 (%_fatal% "Unable to cd to %HOMEBIN%" 111)
set FIRSTNAME=
set LASTNAME=
call "%HOMEBIN%\senv.local.pre.bat"
%_info% "   [senv.local.pre.bat called]"
grep FIRSTNAME "%HOMEBIN%\senv.local.pre.bat">NUL
rem if "%ERRORLEVEL%"=="0" ( goto:userset )
for /f "tokens=* usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$input = '%USERNAME%'; $input.ToLower()"`) do ( set "usernamel=%%a" )
set "USERMAIL="
if exist "%custom_dir%\bin\get_name_email.bat" (
    %_task% "Must get name email from custom script"
    for /f "tokens=* usebackq delims=" %%a in (`call "%custom_dir%\bin\get_name_email.bat" "%usernamel%"`) do (
        set /a "line_count+=1"
        if !line_count! EQU 1 (
            set "FIRSTNAME=%%a"
        ) else if !line_count! EQU 2 (
            set "LASTNAME=%%a"
        ) else if !line_count! EQU 3 (
            set "FULLNAME=%%a"
        ) else if !line_count! EQU 4 (
            set "USERMAIL=%%a"
            goto :break_loop
        )
    )
)
:break_loop
if exist "%custom_dir%\bin\get_name_email.bat" (
    if not defined USERMAIL (
        %_error% "Unable to find name through custom/bin/get_name_email.bat, will ask the user directly"
    )
)
%_info% "'%usernamel%': FIRSTNAME='%FIRSTNAME%', LASTNAME='%LASTNAME%', FULLNAME='%FULLNAME%' and USERMAIL='%USERMAIL%'"
if "%FIRSTNAME%"=="" (
    set /P FIRSTNAME="Enter your first name (no quotes needed, can be empty): "
)
if "%LASTNAME%"=="" (
    set /P LASTNAME="Enter your Last name (no quotes needed, default '%USERNAME%'): "
)
if "%LASTNAME%"=="" (
    set "LASTNAME=%USERNAME%"
)
rem %_fatal% "stop" 11
call "%bin_dir%\check_trailing_newline.bat" "%HOMEBIN%\senv.local.pre.bat"
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
    %_fatal% "User email cannot be empty"&& exit /b 1
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
        %_warning% "Skip '%f%' installation (for '%prgtoinstall%')"
        goto:eof
    )
)

if not defined PRGS (
    %_fatal% "PRGS not defined" 21
)

@echo off
set "mgrname=manager"
:: The command to get the version string
for /f "tokens=2 delims= " %%a in ('findstr "mingw-w64-x86_64-git-doc-html" "%PRGS%\gits\current\etc\package-versions.txt"') do (
    set "fullversion=%%a"
)
:: Extract the major and minor version numbers
for /f "tokens=1,2 delims=." %%b in ("!fullversion!") do (
    set "major=%%b"
    set "minor=%%c"
)

if !major! LEQ 2 (
    if !minor! LEQ 39 (
        %_info% "Install: Keep 'manager-core' as credential helper for Git !major!.!minor!"
        set "mgrname=manager-core"
    )
)
if "%mgrname%"=="manager" (
    %_info% "Install: Keep 'manager' as credential helper for Git !major!.!minor!"
)

if not exist "%PRGS%\gits\current\bin\git.exe" %_fatal% "git.exe missing at '%PRGS%\gits\current\bin'" 23
where git >NUL 2>NUL
if errorlevel 1 (
    set "GH=%PRGS%\gits\current"
    set "PATH=%script_dir_bin%;%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%GH%\mingw64\libexec\git-core;%PATH%"
) else (
    %_ok% "git.exe is on the PATH"
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

%_info% "GITPATH='%GITPATH%' (no Git repo in GITNOPATH='%GITNOPATH%', firstTwo='%firstTwo%')"

if exist "%GITNOPATH%\.git\config" (
    %_warning% "Git repository in '%GITNOPATH%' instead of '%GITPATH%'"
    %_task% "Must delete '%GITNOPATH%\.git'"
    rmdir /S /Q "%GITNOPATH%\.git"
    if errorlevel 1 (
        %_fatal% "Unable to delete Git repository in '%GITNOPATH%'"
    )
    ok "Git repository in '%GITNOPATH%' deleted"
)

"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL 2>NUL
if exist "%GITPATH%\.git\config" (
    grep bare "%GITPATH%\.git\config" 1>NUL 2>NUL
    if errorlevel 1 (
        %_warning% "%GITPATH%\.git\config incomplete: delete and redo"
        del /Q "%GITPATH%\.git\config"
        if errorlevel 1 (
            %_error% "%GITPATH%\.git\config unable to be deleted"
        )
    )
)

if not exist "%GITPATH%\.git\config" (
    %_info% "Initialize git repository in '%GITPATH%'"
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    git init "%GITPATH%"
)
if not exist "%GITPATH%\.git\objects" (
    mkdir "%GITPATH%\.git\objects"
)
grep bare "%GITPATH%\.git\config" 1>NUL 2>NUL
if errorlevel 1 (
    copy /Y "%senv_dir%\.gitconfig" "%GITPATH%\.git\config"
)
if not exist "%GITPATH%\.gitignore" (
    copy "%bin_dir%\.gitignore" "%GITPATH%" )
%_task% "Must check if '/batcolors/' is in '%GITPATH%\.gitignore'"
findstr /BC:/batcolors/ "%GITPATH%\.gitignore" 1>NUL 2>NUL
if not errorlevel 1 (
    %_ok% "'/batcolors/' already in '%GITPATH%\.gitignore'"
    goto:cd_gitpath
)
%_task% "Must add '/batcolors/' in '%GITPATH%\.gitignore'"
call "%bin_dir%\check_trailing_newline.bat" "%GITPATH%\.gitignore"
if "%ERRORLEVEL%"=="2" ( echo.>> "%GITPATH%\.gitignore" )
echo /batcolors>>"%GITPATH%\.gitignore"
echo /batcolors/>>"%GITPATH%\.gitignore"

:cd_gitpath
cd /d "%GITPATH%"
if errorlevel 1 (%_fatal% "Unable to cd to '%GITPATH%'" 111)
%_info% "   [Check 'git config --local user.name' in '%GITPATH%']"
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
git -C "%GITPATH%" config --local user.name>NUL
if errorlevel 1 ( "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL && call "%HOMEBIN%\gcu.bat" )
%_info% "   [Check 'git config --local user.email' in '%GITPATH%']"
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
git -C "%GITPATH%" config --local user.email>NUL
if errorlevel 1 ( "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL && call "%HOMEBIN%\gcu.bat" )
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL

call:check_gitdate
%_info% "   [nomodif='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipfirststatus)
if exist "%GITPATH%\.git\index.lock" (sleep 1)
if exist "%GITPATH%\.git\index.lock" (%_fatal% "'%GITPATH%' used by other Git process (close VSCode if opened) and relaunch setup" 11)
%_info% "   [Calling first git status --porcelain in '%GITPATH%']"
set st=
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
%_task% "Must Check Git status in '%CD%'"
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_info% "Save local modification of '%GITPATH%'"
    rem %_fatal% "no local save" 111
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
    git add .
    git commit -m "pre-update"
    %_ok% "pre-update commit done in '%CD%'"
) else (
    %_ok% "No Git local modification in '%CD%'"
)
:skipfirststatus
%_task% "Must update HOMEBIN '%HOMEBIN%'"
cd /d "%HOMEBIN%"
if errorlevel 1 (
    %_fatal% "Unable to access HOMEBIN '%HOMEBIN%'" 111
)
%_info% "   [copy senv_dir\bin '%bin_dir%\*' in HOMEBIN '%HOMEBIN%']"
copy /Y "%bin_dir%\*" . > NUL:
%_info% "   [Copy senv.doskey in '%HOMEBIN%']"
copy /Y "%bin_dir%\senv.doskey" . > NUL: 
%_info% "   [Delete s.bat in '%HOMEBIN%']"
if exist s.bat ( del s.bat > NUL: )
if exist setup.bat ( del setup.bat > NUL: )
%_info% "   [Copy custom\*.custom in '%HOMEBIN%']"
copy /Y "%custom_dir%\*.custom.*" "%HOMEBIN%" 1>NUL: 2>NUL:
%_info% "   [Copy custom\bin in '%HOMEBIN%']"
copy /Y "%custom_dir%\bin\*" "%HOMEBIN%" > NUL:

%_task% "Must cleanup custom.[profile].[bat,doskey] files"
dir /B "%HOME%\bin\*.custom.*.bat" > "%script_dir%\setup_cleanup.tmp"
if errorlevel 1 (
  %_fatal% "Unable to list custom bat files in %HOME%\bin" 51
)
dir /B "%HOME%\bin\*.custom.*.doskey" >> "%script_dir%\setup_cleanup.tmp"
if errorlevel 1 (
  %_fatal% "Unable to list custom doskey files in %HOME%\bin" 52
)
findstr /R /V /C:".*custom\.%profile%\..*" "%script_dir%\setup_cleanup.tmp" > "%script_dir%\setup_cleanup_filtered.tmp"
if errorlevel 1 (
  %_info% "No other profile than '%profile%' in '%script_dir%\setup_cleanup.tmp'"
)
for /f "delims=" %%a in ('type "%script_dir%\setup_cleanup_filtered.tmp"') do (
  set "custom_file_to_delete=%%a"
  rem echo Must delete '!custom_file_to_delete!'
  del "%HOME%\bin\!custom_file_to_delete!"
  if errorlevel 1 (
    %_fatal% "Unable to delete custom file '!custom_file_to_delete!' in %HOME%\bin" 54
  )
)
del "%script_dir%\setup_cleanup.tmp"
del "%script_dir%\setup_cleanup_filtered.tmp"
%_ok% "All custom file from different profiles than '%profile%' have been deleted from HOME\bin '%HOME%\bin'"

call:check_gitdate
%_info% "   [nomodif(2)='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipsecondstatus)
%_info% "   [Calling Second git status --porcelain in '%HOMEBIN%']"
set st=
"%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
"%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
%_task% "Must Check second Git status in '%CD%'"
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_info% "Save new updates of '%GITPATH%'"
    rem %_fatal% "no new update save" 112
    "%PRGS%\gits\current\usr\bin\cat.exe" "%HOME%\.gitconfig" 1>NUL
    "%PRGS%\gits\current\usr\bin\cat.exe" "%GITPATH%\.git\config" 1>NUL
    git add --renormalize .
    git commit -m "post-update"
    %_ok% "pre-update second commit done in '%CD%'"
) else (
    %_ok% "No second Git local modification in '%CD%'"
)
:skipsecondstatus
if exist "%HOME%\.git\COMMIT_EDITMSG" ( touch "%HOME%\.git\COMMIT_EDITMSG" )
%_info% "~~~~~~~~~~~~"
call "%installs_dir%\gits.config.utils.bat" :restore_gitconfig system gits.post.bat

if not exist "%HOME%\.ssh" ( mkdir "%HOME%\.ssh" )

if exist "%setupsdir%\gitcred.exe" (
    %_info% "Copy/update '%HOMEBIN%\gitcred.exe' from %setupsdir%"
    (robocopy "%setupsdir%" "%HOMEBIN%" "gitcred.exe" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
    if not "%ERRORLEVEL%"=="0" ( %_warning% "Unable to copy '%setupsdir%\gitcred.exe' to '%HOMEBIN%\'" && exit /b 0)
    copy /Y "%HOMEBIN%\gitcred.exe" "%HOMEBIN%\git-cred.exe"
    %_ok% "'gitcred.exe' in '%HOMEBIN%\' updated from '%setupsdir%'"
)
rem senv_dir
%_info% "Copy/update '%HOME%\batcolors\' from %senv_dir%"
if not exist "%HOME%\batcolors" ( mkdir "%HOME%\batcolors" )
(robocopy "%senv_dir%\batcolors " "%HOME%\batcolors" /e /dcopy:T /mt /r:5 /NJH /NJS /NFL) ^& set rbc_errorlevel=%ERRORLEVEL%
IF %rbc_errorlevel% LSS 8 SET rbc_errorlevel = 0
if not "%rbc_errorlevel%"=="0" ( %_error% "Unable to copy '%senv_dir%\batcolors' to '%HOME%\': rbc_errorlevel='%rbc_errorlevel%'" && exit /b 0)
%_ok% "'batcolors/' in '%HOME%\' updated from '%senv_dir%'"
endlocal
exit /b 0
goto:eof

:check_gitdate
set nomodif=
set newest=
if not exist "%HOME%\.git\COMMIT_EDITMSG" (goto:eof)
copy "%HOME%\.git\COMMIT_EDITMSG" "%HOMEBIN%" >NUL
for /f "tokens=*" %%a in ('dir /b /od "%HOMEBIN%"') do set newest=%%a
%_info% "newest=%newest% !newest!"
if "%newest%"=="COMMIT_EDITMSG" ( set "nomodif=1" )
set newest=
del "%HOMEBIN%\COMMIT_EDITMSG"
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
