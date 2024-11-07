@echo off

set "standalone_call=true"
if defined script_dir (
  set "standalone_call="
)
setlocal enabledelayedexpansion

rem https://www.yworks.com/resources/yed/demo/yEd-3.24.zip
rem <a href="/products/yed">yEd Graph Editor 3.24</a> at https://www.yworks.com/downloads#yEd

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)
set "senv_home=%USERPROFILE%\senv_home"

if not exist "%PRGS%\gums\current\gum.exe" (
  if defined standalone_call (
    %_fatal% "[%~nx0] gum.exe not found in '%PRGS%\gums\current'" 1
  )
  %_warning% "[%~nx0] gum.exe not found in '%PRGS%\gums\current', but non-standalone call, so does not matter"
) else (
  set "PATH=%PRGS%\gums\current;%PATH%"
)

REM read the list of programs from script_dir, from %HOME% (%USERPROFILE%\senv_home) and %USERPROFILE%\senv_setups (the private setup folder): both are names prgs.list. The format is name,versions,folder,pattern. A name can be  with lower or upercase letters and include spaces. A folder is in lowercase, without spaces, versions are separated by semicolon (there can be 0 to n versions, 0 meaning 'latest'), and the pattern is a glob expression intended to be use by a dir command. The end result is 4 arrays variables: prg_names, prg_versions, prg_folders, prg_patterns


REM Initialize arrays
set prg_names=
set prg_versions=
set prg_folders=
set prg_patterns=

del "%script_dir%\prg_names.tmp" 2>NUL

REM Step 1: check if a program name is provided as argument

set "prg_name=%~1"
if "%prg_name%"=="" (
  if defined standalone_call (
    call:select_program
  ) else (
    %_fatal% "[%~nx0] non-standalone call: prg_name first parameter is missing" 12
  )
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
for /f "tokens=1-4 delims=~" %%a in ('echo "%prg_line%"') do (
  set "prg_names=%%a"
  set "prg_versions=%%b"
  set "prg_folders=%%c"
  set "prg_patterns=%%d"
)
set "prg_names=%prg_names:"=%"
if defined prg_versions ( set "prg_versions=%prg_versions:#=%" )
if defined prg_folders ( set "prg_folders=%prg_folders:#=%" )
if defined prg_patterns ( set "prg_patterns=%prg_patterns:"=%" )
if defined prg_patterns ( set "prg_patterns=%prg_patterns:#=%" )
for /f "tokens=1 delims=/" %%a in ('echo "%prg_names%"') do ( set "prg_name=%%a" )
set "prg_name=%prg_name:"=%"
if not defined prg_folders (
  %_fatal% "[%~nx0] prg_folders not defined for '%prg_name%'" 15
)
set "prg_id=%prg_folders:~0,-1%"
%_info% "[%~nx0] prg_name='%prg_name%': prg_names='%prg_names%', prg_versions='%prg_versions%', prg_folders='%prg_folders%', prg_patterns='%prg_patterns%'"

REM Step 2: check the version

set "prg_version=%~2"
if not defined prg_version (
  if defined prg_versions (
    if not defined standalone_call (
      %_fatal% "[%~nx0] non-standalone call: prg_version second parameter is missing. Should be one of '%prg_versions%'" 13
    )
    call:select_version
    %_ok% "[%~nx0] Selected version: latest of '!prg_version!'"
  ) else (
    %_info% "[%~nx0] No version provided, and prg_versions not defined: assume 'latest'"
    set "prg_version=latest"
  )
) else if defined prgs_versions (
  set "prg_version_found="
  for /f "usebackq" %%a in ('%prg_versions%') do (
    if "%%a"=="%prg_version%" ( set "prg_version_found=true" )
  )
  if not defined prg_version_found (
    if not defined standalone_call (
      %_fatal% "[%~nx0] Invalid prg_version '%prg_version%', should be one of '%prg_versions%'" 14
    )
    %_error% "[%~nx0] Invalid prg_version '%prg_version%', Select one of '%prg_versions%'"
    call:select_version
    %_ok% "[%~nx0] Selected fixed version: latest of '!prg_version!'"
  ) else (
    %_ok% "[%~nx0] Valid version '%prg_version%', one of '%prg_versions%'"
  )
)
%_info% "[%~nx0] prg_version='%prg_version%'"
endlocal & set "prg_name=%prg_name%" & set "prg_id=%prg_id%" & set "prg_version=%prg_version%" & set "prg_patterns=%prg_patterns%" & set "prg_folders=%prg_folders%" & set "senv_dir=%senv_dir%"
if defined standalone_call (
  call %senv_dir%\batcolors\echos_macros.bat unset
  set "senv_dir="
  set "senv_home="
  set "standalone_call="
  set "prg_id="
  set "prg_name="
  set "prg_version="
  set "setup_dir="
  set "batdir="
  set "ASCII27="
  set "a="
)
set "prg_folders="
set "prg_line="
set "prg_names="
set "prg_versions="
set "file1="
set "file2="
rem set prg_
goto:eof

:select_version
for /f "delims=" %%p in ('bash -c "'%PRGS%\gums\current\gum.exe' choose %prg_versions%"') do ( set "prg_version=%%p" )
if "%prg_version%"=="" (
  %_fatal% "[%~nx0] No program version selected from '%prg_versions%'" 1
)
%_ok% "[%~nx0] Program version selected: %prg_version%"
goto:eof

:parse_prgs_list
for /f "delims=" %%p in ('findstr /I /R /C:"^%prg_name%[/~]" "%~1"') do set "prg_line=%%p"
if not defined prg_line (
  for /f "delims=" %%p in ('findstr /I /R /C:"/%prg_name%[/~]" "%~1"') do set "prg_line=%%p"
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
