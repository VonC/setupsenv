%_info% "~~~~~~~~~~~~"
%_info% " Checking/updating '%HOME%\bin' content"
call "%HOME%\bin\senv.bat"
cd /d "%HOME%\bin"
set FIRSTNAME=
set LASTNAME=
call %HOME%\bin\senv.local.pre.bat
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
set st=
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%" == "" (
    %_info% "Save local modification of '%HOME%\bin'"
    git add .
    git commit -m "pre-update"
)
copy /Y "%script_dir%\bin\*" . > NUL:
copy /Y "%script_dir%\bin\senv.doskey" . > NUL: 
if exist s.bat ( del s.bat > NUL: )
if exist setup.bat ( del setup.bat > NUL: )
copy /Y "%script_dir%\custom\*.custom.*" "%HOME%\bin" > NUL:
copy /Y "%script_dir%\custom\bin\*" "%HOME%\bin" > NUL:

git config --local user.name>NUL
if errorlevel 1 ( call gcu.bat )

set st=
for /f "delims=" %%x in ('git status --porcelain') do set "st=%%x"
if not "%st%" == "" (
    %_info% "Save new updates of '%HOME%\bin'"
    git add --renormalize .
    git commit -m "post-update"
)
%_info% "~~~~~~~~~~~~"

if not exist "%HOME%\.ssh" ( mkdir "%HOME%\.ssh" )
exit /b 0
