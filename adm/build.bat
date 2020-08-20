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
cd senv
call gcuvc
cd custom
call gcu
