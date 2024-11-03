@echo off
setlocal enabledelayedexpansion

rem https://www.yworks.com/resources/yed/demo/yEd-3.24.zip
rem <a href="/products/yed">yEd Graph Editor 3.24</a> at https://www.yworks.com/downloads#yEd

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

%_info% "[%~nx0] select prg_name"

if not exist "%PRGS%\gums\current\gum.exe" (
  %_fatal% "[%~nx0] gum.exe not found in '%PRGS%\gums\current'" 1
)
set "PATH=%PRGS%\gums\current;%PATH%"

set "prgname=%~1"
if not "%prgname%"=="" (
  goto:set_version
)
REM read the list of programs from two files: one from script_dir, and one from %USERPROFILE%\senv_home (the personal/private senv directory): both are names prgs.list. The format is name,versions,folder,pattern. A name can be  with lower or upercase letters and include spaces. A folder is in lowercase, without spaces, versions are separated by semicolon (there can be 0 to n versions, 0 meaning 'latest'), and the pattern is a glob expression intended to be use by a dir command. The end result is 4 arrays variables: prg_names, prg_versions, prg_folders, prg_patterns

set "senv_home=%USERPROFILE%\senv_home"
set "file1=%script_dir%\prgs.list"
set "file2=%senv_home%\prgs.list"

REM Initialize arrays
set prg_names=
set prg_versions=
set prg_folders=
set prg_patterns=

del "%script_dir%\prg_names.tmp" 2>NUL
REM Read and parse both files
call :read_file %file1%
call :read_file %file2%

REM Select a program using gum
echo type %script_dir%\prg_names.tmp ^| "%PRGS%\gums\current\gum.exe" choose --limit=1
rem goto:eof
for /f "delims=" %%p in ('type "%script_dir%\prg_names.tmp" ^| "%PRGS%\gums\current\gum.exe" choose --limit=1') do set "prgname=%%p"
if "%prgname%"=="" (
  %_fatal% "[%~nx0] No program selected" 1
)
%_ok% "[%~nx0] Program selected: %prgname%"
goto:eof

REM Function to read and parse a file
:read_file
if not exist "%1" (
    %_warning% "[%~nx0] File '%1' not found"
    goto:eof
)
%_task% "[%~nx0] Must read file '%1'"
for /f "tokens=1-4 delims=," %%a in (%1) do (
    echo %%a>> "%script_dir%\prg_names.tmp"
    set "prg_versions=!prg_versions!%%b|"
    set "prg_folders=!prg_folders!%%c|"
    set "prg_patterns=!prg_patterns!%%d|"
)
%_ok% "[%~nx0] File '%1' read"
goto:eof