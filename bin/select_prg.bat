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
    %_fatal% "gum.exe not found in '%PRGS%\gums\current'" 1
  )
  %_warning% "gum.exe not found in '%PRGS%\gums\current', but non-standalone call, so does not matter"
) else (
  set "PATH=%PRGS%\gums\current;%PATH%"
)

REM read the list of programs from script_dir, from %HOME% (%USERPROFILE%\senv_home) and %USERPROFILE%\senv_setups (the private setup folder): both are names prgs.list. The format is name,versions,folder,pattern. A name can be  with lower or uppercase letters and include spaces. A folder is in lowercase, without spaces, versions are separated by semicolon (there can be 0 to n versions, 0 meaning 'latest'), and the pattern is a glob expression intended to be use by a dir command. The end result is 4 arrays variables: prg_names, prg_versions, prg_folders, prg_patterns


REM Initialize arrays
set prg_names=
set prg_versions=
set prg_folders=
set prg_patterns=
set prg_is_global=

del "%script_dir%\prg_names.tmp" 2>NUL

REM Step 1: check if a program name is provided as argument

set "prg_name=%~1"
if "%prg_name%"=="" (
  if defined standalone_call (
    call:select_program
  ) else (
    %_fatal% "non-standalone call: prg_name first parameter is missing" 12
  )
)
if "%prg_name%"=="choose" (
  set "prg_name="
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
  call:parse_prgs_list_for_pattern "%script_dir%\prgs.list"
)
if not defined prg_line (
  if exist "%senv_home%\prgs.list" (
    call:parse_prgs_list_for_pattern "%senv_home%\prgs.list"
  )
)
if not defined prg_line (
  %_fatal% "prg_name '%prg_name%' not found in available program list" 11
)
%_ok% "prg_name '%prg_name%' matches prg_line '%prg_line%'"
for /f "tokens=1-5 delims=~" %%a in ('echo "%prg_line%"') do (
  set "prg_names=%%a"
  set "prg_versions=%%b"
  set "prg_folders=%%c"
  set "prg_patterns=%%d"
  set "prg_is_global=%%d"
)
if not defined prg_patterns (
  %_error% "Line should be Name/aliases~Major Versions or #~FolderName-with-s~pattern_*_file.ext[~global]"
  %_fatal% "Incomplete prg_line '%prg_line%', no pattern or other data" 126
)
set "prg_names=%prg_names:"=%"
if defined prg_versions ( set "prg_versions=%prg_versions:#=%" )
if defined prg_folders ( set "prg_folders=%prg_folders:#=%" )
if defined prg_patterns ( set "prg_patterns=%prg_patterns:"=%" )
if defined prg_patterns ( set "prg_patterns=%prg_patterns:#=%" )
for /f "tokens=1 delims=/" %%a in ('echo "%prg_names%"') do ( set "prg_name=%%a" )
set "prg_name=%prg_name:"=%"
if not defined prg_folders (
  %_fatal% "prg_folders not defined for '%prg_name%'" 15
)
set "prg_id=%prg_folders:~0,-1%"
%_info% "prg_name='%prg_name%': prg_names='%prg_names%', prg_versions='%prg_versions%', prg_folders='%prg_folders%', prg_patterns='%prg_patterns%'"

REM Step 2: check the version
set "prg_version=%~2"
if "%prg_version%"=="inst_prg" ( goto:prg_version_inst_prg )
if not defined prg_version (
  if "%prg_id%"=="node" ( set "prg_version=LTS" )
) else if "%prg_version%"=="lts" (
  set "prg_version=LTS"
)
if not defined prg_version (
  if defined prg_versions (
    if not defined standalone_call (
      %_fatal% "non-standalone call: prg_version second parameter is missing. Should be one of '%prg_versions%'" 13
    )
    call:select_version
    %_ok% "Selected version: latest of '!prg_version!'"
  ) else (
    %_info% "No version provided, and prg_versions not defined: assume 'latest'"
    set "prg_version=latest"
  )
) else if defined prg_versions (
  set "prg_version_found="
  set "latest_version="
  set "lts_version="
  for %%a in (%prg_versions%) do (
    if "%%a"=="%prg_version%" ( set "prg_version_found=true" )
    set "prg_version_item=%%a"
    set "prg_version_item=!prg_version_item:-LTS=!"
    set "prg_version=!prg_version:-LTS=!"
    if not "!prg_version_item!"=="%%a" (
      if "%prg_version%"=="LTS" ( set "prg_version_found=true" && set "lts_version=!prg_version_item!" )
    )
    if "%prg_version%"=="!prg_version_item!" (
      set "prg_version_found=true"
    )
    rem echo '%%a' for prg_version='%prg_version%', prg_version_found='!prg_version_found!', lts_version='!lts_version!'
    set "latest_version=%%a"
  )
  if not defined prg_version_found (
    if "%prg_version%"=="latest" (
      if defined latest_version (
        %_ok% "version '%prg_version%' means version !latest_version!"
        set "prg_version=!latest_version!"
        set "prg_version_found=true"
      )
    )
    if "%prg_version%"=="LTS" (
      %_fatal% "no version '%prg_version%' found for '%prg_name%', versions '%prg_versions%'" 19
    )
  )
  if not defined prg_version_found (
    if not defined standalone_call (
      %_fatal% "Invalid prg_version '!prg_version!', should be one of '%prg_versions%'" 14
    )
    %_error% "Invalid prg_version '!prg_version!', Select one of '%prg_versions%'"
    call:select_version
    %_ok% "Selected fixed version: latest of '!prg_version!'"
  ) else (
    if defined lts_version (
      %_ok% "LTS version selected: !lts_version!"
      set "prg_version=!lts_version!"
    )
    %_ok% "Valid version '!prg_version!', one of '%prg_versions%'"
  )
) else (
  %_ok% "prg_version '%prg_version%' preserved, since no prg_versions defined"
)
:prg_version_inst_prg
%_info% "prg_version='%prg_version%'"
endlocal & set "prg_name=%prg_name%" & set "prg_id=%prg_id%" & set "prg_version=%prg_version%" & set "prg_pattern=%prg_patterns%" & set "prg_folders=%prg_folders%" & set "senv_dir=%senv_dir%" & set "prg_is_global=%prg_is_global%"
if defined standalone_call (
  call %senv_dir%\batcolors\echos_macros.bat unset
  set "senv_dir="
  set "senv_home="
  set "standalone_call="
  set "prg_id="
  set "prg_pattern="
  set "prg_name="
  set "prg_version="
  set "prg_is_global="
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
  %_fatal% "No program version selected from '%prg_versions%'" 1
)
set "prg_version=%prg_version:-LTS=%"
%_ok% "Program version selected: %prg_version%"
goto:eof

:parse_prgs_list
for /f "delims=" %%p in ('findstr /I /R /C:"^%prg_name%[/~]" "%~1"') do set "prg_line=%%p"
if not defined prg_line (
  for /f "delims=" %%p in ('findstr /I /R /C:"/%prg_name%[/~]" "%~1"') do set "prg_line=%%p"
)
if defined prg_line (
  %_ok% "prg_name '%prg_name%' found in '%~1': prg_line '%prg_line%'"
)
goto:eof

:parse_prgs_list_for_pattern
set "prg_line="
set "prg_list_file=%~1"
for /f "tokens=* delims=" %%p in ('powershell -ExecutionPolicy Bypass -File "%script_dir%\parse_prgs_list_for_pattern.ps1" -prg_list_file "%prg_list_file%" -string_to_test "%prg_name%" 2^>nul') do set "prg_line=%%p"
goto:eof

:select_program
REM Select a program using gum
rem echo type %script_dir%\prg_names.tmp ^| "%PRGS%\gums\current\gum.exe" choose --limit=1
rem goto:eof
sed "s/[~#/,].*$//g" "%script_dir%\prgs.list" > "%script_dir%\prg_names.tmp"
for /f "delims=" %%p in ('bash -c "'%PRGS%\gums\current\gum.exe' choose --limit 1 $(sed "s/\S+.*?$\r\n/\n/g" '%script_dir%\prg_names.tmp')"') do set "prg_name=%%p"
if "%prg_name%"=="" (
  %_fatal% "No program selected" 1
)
%_ok% "Program selected: %prg_name%"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
