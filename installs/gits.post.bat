%_info% "~~~~~~~~~~~~"
%_info% " Checking/updating '%HOME%\bin' content"
set ignorevscode=1
call "%HOME%\bin\senv.bat"
set ignorevscode=
%_info% "   [senv called]"
cd /d "%HOME%\bin"
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

if not exist .git ( git init . && call gcu.bat )
if not exist .gitignore (  copy "%script_dir%\bin\.gitignore" "%HOME%\bin" )

call:check_gitdate
%_info% "   [nomodif='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipfirststatus)
if exist "%HOME%\bin\.git\index.lock" (sleep 1)
if exist "%HOME%\bin\.git\index.lock" (%_fatal% "%HOME%\bin used by other Git process (close VSCode if opened) and relaunch setup" 11)
%_info% "   [Calling first git status --porcelain in '%HOME%\bin']"
set st=
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%" == "" (
    %_info% "Save local modification of '%HOME%\bin'"
    rem %_fatal% "no local save" 111
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

%_info% "   [Check 'git config --local user.name' in '%HOME%\bin']"
git config --local user.name>NUL
if errorlevel 1 ( call gcu.bat )

call:check_gitdate
%_info% "   [nomodif(2)='%nomodif%' '!nomodif!']"
if "%nomodif%"=="1" ( goto:skipsecondstatus)
%_info% "   [Calling Second git status --porcelain in '%HOME%\bin']"
set st=
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%" == "" (
    %_info% "Save new updates of '%HOME%\bin'"
    rem %_fatal% "no new update save" 112
    git add --renormalize .
    git commit -m "post-update"
)
:skipsecondstatus
touch .git\COMMIT_EDITMSG
%_info% "~~~~~~~~~~~~"
call "%script_dir%\installs\gits.config.utils.bat" :restore_gitconfig system gits.post.bat

if not exist "%HOME%\.ssh" ( mkdir "%HOME%\.ssh" )
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
