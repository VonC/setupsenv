@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

rem @echo on
set "arg=%~1"
if "%arg%"=="" ( goto:dwl_from_github)
if not "%arg::=%"=="%arg%" ( goto%arg% )
echo nope
goto:eof

:dwl_from_github
set "repo=git-for-windows/git"
set "prgname=git"
%_info% "[%~nx0] Dwl '%repo%'"
call "%script_dir%\dwl_from_github.bat" "%repo%" "%prgname%"
goto:eof

:get_filename
rem https://github.com/charmbracelet/gum/releases/download/v0.14.1/gum_0.14.1_Windows_x86_64.zip
set "version=%~2"
set "file=PortableGit-%version%-64-bit.7z.exe"
set "file=%file:.windows.1=%"
set "file=%file:.windows.=.%"
echo.%file%
goto:eof

