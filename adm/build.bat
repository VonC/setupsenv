@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\..\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir(bundle)='%script_dir%'"

if "%1" == "" (
    %_fatal% "Must have setupsdir profile xx, for calling setupsdir_xx.bat" 1
)

set s="setupsdir_%1.bat"
if not exist "%script_dir%\%s%" (
    %_fatal% "setupsdir script '%s%' does not exist" 2
)

echo %1>profile

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

del senv_%1-zip.exe
%_info% "zip '%script_dir%\..\..\senv' to 'senv_%1.zip'"
%sz% a -sfx7z.sfx senv_%1-zip.exe senv
if not "%ERRORLEVEL%" == "0" (
     %_fatal% "Unable 7z '%script_dir%\..\..\senv' to '%CD%' 'senv_%1-zip.exe'" && exit /b 1
)

set profile=%1
cd senv
call gcuvc
cd custom
call gcu

call setupsdir_%profile%.bat
%_info% "setupsdir='%setupsdir%'"
%_warning% "Update 'senv_%profile%-zip.exe' from '%script_dir%\..\..' to '%setupsdir%'"
set OK="KO"
(robocopy "%script_dir%\..\.." "%setupsdir%" "senv_%profile%-zip.exe" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 (
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
REM echo "OK='%OK%' '!OK!'"
if not "%OK%" == "ok" ( %_fatal% "Unable to robocopy '%script_dir%\..\..\senv_%profile%-zip.exe' to '%setupsdir%': errorlevel '%OK%'" && exit /b 1)

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

if "%setupsdirsenv%" == "" (
    %_fatal% "setupsdirsenv empty. Check '%script_dir%\setupsdir_%1.bat'" && exit /b 1)
)

echo call %setupsdirsenv%\remote_setup.bat %1>%setupsdirsenv%\s.bat
echo call %setupsdirsenv%\remote_setup.bat %1>%setupsdir%\s.bat
echo deep>profile