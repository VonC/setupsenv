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

if not exist "%PRGS%\gums\current\gum.exe" (
  %_fatal% "[%~nx0] gum.exe not found in '%PRGS%\gums\current'" 1
)
set "PATH=%PRGS%\gums\current;%PATH%"

REM read the list of programs from script_dir, from %HOME% (%USERPROFILE%\senv_home) and %USERPROFILE%\senv_setups (the private setup folder): both are names prgs.list. The format is name,versions,folder,pattern. A name can be  with lower or upercase letters and include spaces. A folder is in lowercase, without spaces, versions are separated by semicolon (there can be 0 to n versions, 0 meaning 'latest'), and the pattern is a glob expression intended to be use by a dir command. The end result is 4 arrays variables: prg_names, prg_versions, prg_folders, prg_patterns

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

REM Step 1: check if a program name is provided as argument

set "prg_name=%~1"
if "%prg_name%"=="" (
  call:select_program
)
set "prg_line="
call:parse_prgs_list "%script_dir%\prgs.list"
if not defined prg_line (
  if exist "%senv_home%\prgs.list" (
    call:parse_prgs_list "%script_dir%\prgs.list"
  )
)
if not defined prg_line (
  %_fatal% "[%~nx0] prg_name '%prg_name%' not found in available program list" 11
)
%_ok% "[%~nx0] prg_name '%prg_name%' matches prg_line '%prg_line%'"

for /f "tokens=1-4 delims=~" %%a in ('echo %prg_line%') do (
  set "prg_names=%%a"
  set "prg_versions=%%b"
  set "prg_folders=%%c"
  set "prg_patterns=%%d"
)
if defined prg_versions ( set "prg_versions=%prg_versions:#=%" )
if defined prg_folders ( set "prg_folders=%prg_folders:#=%" )
if defined prg_patterns ( set "prg_patterns=%prg_patterns:#=%" )
%_info% "[%~nx0] prg_names='%prg_names%', prg_versions='%prg_versions%', prg_folders='%prg_folders%', prg_patterns='%prg_patterns%'"


goto:eof
rem findstr /R /C:"^Git/" prgs.list
rem findstr /R /C:"/git[/,]" prgs.list
rem TODO for /f "delims=" %%p in ('findstr /R /C:"/git[/,]" %script_dir%\prgs.list') do set "prg_name=%%p"
rem if p not nul, goto:select_version

:parse_prgs_list
for /f "delims=" %%p in ('findstr /I /R /C:"^%prg_name%[/,]" "%~1"') do set "prg_line=%%p"
if not defined prg_line (
  for /f "delims=" %%p in ('findstr /I /R /C:"/%prg_name%[/,]" "%~1"') do set "prg_line=%%p"
)
goto:eof

:select_program
REM Select a program using gum
rem echo type %script_dir%\prg_names.tmp ^| "%PRGS%\gums\current\gum.exe" choose --limit=1
rem goto:eof
sed "s/[/,].*$//g" prgs.list > prg_names.tmp
for /f "delims=" %%p in ('bash -c "'%PRGS%\gums\current\gum.exe' choose --limit 1 $(sed "s/\S+.*?$\r\n/\n/g" prg_names.tmp)"') do set "prg_name=%%p"
if "%prg_name%"=="" (
  %_fatal% "[%~nx0] No program selected" 1
)
%_ok% "[%~nx0] Program selected: %prg_name%"
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