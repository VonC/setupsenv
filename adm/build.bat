@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\..\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(bundle)='%script_dir%'"

if "%1"=="" (
    %_fatal% "Must have setupsdir profile xx, for calling setupsdir_xx.bat" 1
)

set "profile=%1"

set s="setupsdir_%profile%.bat"
if not exist "%script_dir%\%s%" (
    %_fatal% "setupsdir script '%s%' does not exist" 2
)

echo %profile%>profile

git config --unset user.name
git config --unset user.email

cd ..
if not exist custom (
    %_fatal% "current folder must be named custom" 1
)
git config --unset user.name
git config --unset user.email
cd ..
if not exist senv (
    %_fatal% "custom must be in senv folder" 1
)

for /f "delims=" %%x in ('git -C "%script_dir%" status --porcelain') do set "st=%%x"
rem goto:skipcl
if not "%st%"=="" (
    %_fatal% "Not a clean git status in '%script_dir%'" 1
    rem %_error% "Not a clean git status in '%script_dir%'" 1
)
for /f "delims=" %%x in ('git -C "%script_dir%\.." status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    %_fatal% "Not a clean git status in '%script_dir%\..'" 1
    rem %_error% "Not a clean git status in '%script_dir%\..'" 1
)
:skipcl
for /f "tokens=* delims=" %%i in ('git -C "%script_dir%" describe --long --all HEAD') do SET "vcsenv=%%i"
for /f "tokens=* delims=" %%i in ('git -C "%script_dir%\.." describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
echo %vcsenv%>"%script_dir%\version"
rem %_fatal% "stop for now" 1

if exist "%script_dir%\..\..\build.pre.bat" ( call "%script_dir%\..\..\build.pre.bat" )

cd senv
call gcuvc
cd custom
call gcu
call "%script_dir%\setupsdir_%profile%.bat" %2
%_info% "setupsdir='%setupsdir%'"
if not exist "%setupsdir%\..\version" (
    %_ok% "New publication"
    goto:build_and_publish
)
for /f "delims=" %%a in ('type "%setupsdir%\..\version"') do (
    if "%%a"=="%vcsenv%" (
        %_ok% "Already published senv '%profile%' with '%vcsenv%'"
        goto:eof
    ) else (
        %_task% "Update senv '%profile%' with '%vcsenv%' (from '%%a')"
    )
    goto :build_and_publish
)

:build_and_publish
cd "%script_dir%\..\.."
del "senv_%profile%-zip.exe"
%_info% "zip '%script_dir%\..\..\senv' to 'senv_%profile%.zip'"
%sz% a -sfx7z.sfx senv_%profile%-zip.exe senv
if not "%ERRORLEVEL%"=="0" (
     %_fatal% "Unable 7z '%script_dir%\..\..\senv' to '%CD%' 'senv_%profile%-zip.exe'" && exit /b 1
)
cd "%script_dir%"

%_task% "Must update 'senv_%profile%-zip.exe' from '%script_dir%\..\..' to '%setupsdir%'"
rem @echo on
set OK="KO"
robocopy "%script_dir%\..\.." "%setupsdir%" "senv_%profile%-zip.exe" /Z /R:2 /W:2 /TBD /MT:16 /NJH /NJS 
IF %ERRORLEVEL% LSS 8 (
    echo "ERRORLEVEL='%ERRORLEVEL%'"
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
echo "OK='%OK%' '!OK!'"
if not "%OK%"=="ok" ( %_error% "Unable to robocopy '%script_dir%\..\..\senv_%profile%-zip.exe' to '%setupsdir%': errorlevel '%OK%'" && goto:eof)
%_ok% "senv_%profile%-zip.exe updated from '%script_dir%\..\..' to '%setupsdir%'"

copy /Y "%script_dir%\version" "%setupsdir%\..\version"
if errorlevel 1 (
    %_fatal% "Unable to copy 'version' from '%script_dir%' to '%setupsdir%\..'" && exit /b 1)
)

copy /Y "%script_dir%\echos_macros.bat" "%setupsdir%\..\echos_macros.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'echos_macros.bat' from '%script_dir%' to '%setupsdir%\..'" && exit /b 1)
)
copy /Y "%script_dir%\echos.bat" "%setupsdir%\..\echos.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'echos.bat' from '%script_dir%' to '%setupsdir%\..'" && exit /b 1)
)

copy /Y "%script_dir%\remote_setup.bat" "%setupsdir%\..\remote_setup.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'remote_setup.bat' from '%script_dir%' to '%setupsdir%\..'" && exit /b 1)
)

copy /Y "%script_dir%\setup.ini.bat" "%setupsdir%\..\setup.ini.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'setup.ini.bat' from '%script_dir%' to '%setupsdir%\..'" && exit /b 1)
)
copy /Y "%script_dir%\detection_VDI.bat" "%setupsdir%\..\detection_VDI.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'detection_VDI.bat' from '%script_dir%' to '%setupsdir%\..'" && exit /b 1)
)
copy /Y "%script_dir%\ss.bat" "%setupsdir%\s.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 's.bat' from '%script_dir%' to '%setupsdir%'" && exit /b 1)
)
copy /Y "%script_dir%\..\check_migrate_home.bat" "%setupsdir%\check_migrate_home.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'check_migrate_home.bat' from '%script_dir%\..' to '%setupsdir%'" && exit /b 1)
)


if "%setupsdirsenv%"=="" (
    %_fatal% "setupsdirsenv empty. Check '%script_dir%\setupsdir_%profile%.bat'" && exit /b 1)
)

echo call remote_setup.bat %profile%>%setupsdirsenv%\s.bat
rem echo call %setupsdirsenv%\remote_setup.bat %profile%>%setupsdir%\s.bat
echo deep>profile

if exist "%script_dir%\..\..\build.post.bat" ( call "%script_dir%\..\..\build.post.bat" )