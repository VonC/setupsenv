@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

set "rel="
if "%~1"=="rel" (
  set "rel=true"
  goto:skip_index_check
)
git diff -w --cached --quiet
if %ERRORLEVEL% == 0 (
  %_fatal% "No changes to commit" 11
)

:skip_index_check
set "NO_MODS="
set "MODS_SETTINGS=%LOCALAPPDATA%\mods\mods.yml"
set "MODS=%GOBIN%\mods.exe"
if exist "%MODS%" (
  if exist "%MODS_SETTINGS%" (
    goto:after_mods_checks
  ) else (
    %_warning% "Mods settings are missing at LOCALAPPDATA: '%MODS_SETTINGS%'"
  )
) else (
  %_warning% "Mods executable is missing at GOBIN: '%MODS%'"
)
set "NO_MODS=true"
:after_mods_checks

set "role=commit_diff"
set "file_filter=":(exclude)*.md" ":(exclude)*.txt""
if not "%~1"=="doc" ( goto:arg_check_rel )
set "role=commit_documentation"
set "file_filter=":(glob)**/*.md" ":(glob)**/*.txt""
shift
:arg_check_rel
if not "%~1"=="rel" ( goto:arg_check_done )
set "role=analyze_release"
set "file_filter=":(exclude)*.md""
shift

:arg_check_done
call:write_prompt

if "%~1" == "prompt" ( call:dump_prompt && exit /b 0 )
if "%~1" == "dump" ( call:dump_prompt && exit /b 0 )
if defined NO_MODS (
  %_info% "No mods means dump prompt mode (will be copied to the clipboard)"
  call:dump_prompt && exit /b 0
)

set model=2.5-flash
if defined GEMINI_MODEL (
  %_warning% "GEMINI_MODEL is defined: '%GEMINI_MODEL%'"
  set "model=%GEMINI_MODEL%"
) else (
  %_warning% "GEMINI_MODEL is not defined: use "%model%", alias for 'gemini-2.5-flash-preview-05-20'"
)
call:configure_mods

call "%script_dir%\ensure_internet.bat"
if errorlevel 1 (
  %_fatal% "Internet connection is required to use mods" 10
)
%_task% "Must analyze changes with mods role '%role%' and model '%model%'"
type tmp.txt | "%mods%" --role=git-diff --model=%model%
if %ERRORLEVEL% == 1 (
  %_fatal% "Failed to analyze staged changes with mods" 12
)
%_ok% "Analyzed staged changes with mods role '%role%' and model '%model%'"
set "EDITOR="%PRGS%\npps\current\notepad++.exe"%npp_settings% -multiInst -notabbar -nosession -noPlugin"

if not defined rel ( goto:commit_changes )
%_task% "Must copy release notes to the clipboard"
mods.bat -Sr | awk 'index($0, "**Assistant**: ")==1 { found=1; sub(/^\*\*Assistant\*\*: /, ""); print; next; } found == 1 { print }' | sed -e :a -e '/^^\n*$/{$d;N;ba' -e '}' | head -c -1 > tmp.txt
if errorlevel 1 (
  %_fatal% "Failed to write release notes analysis to tmp.txt" 22
)
powershell -ExecutionPolicy Bypass -Command "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management; Get-Content tmp.txt | Set-Clipboard"
%_ok% "release notes analysis copied to the clipboard"
del tmp.txt 2>NUL
del tmp.lg 2>NUL
goto:eof

:commit_changes
%_task% "Must commit staged changes with analyzed message"
rem echo gsh: '%EDITOR%'
mods.bat -Sr | awk 'index($0, "**Assistant**: ")==1 { found=1; sub(/^\*\*Assistant\*\*: /, ""); if (index($0, "```")==0) { print $0 }; next; } found == 1 { if (index($0, "```")==0) { print $0 } }' | sed -e :a -e '/^^\n*$/{$d;N;ba' -e '}' | head -c -1 | git commit -F -
if %ERRORLEVEL% == 1 (
  %_fatal% "Failed to commit staged changes with analyzed message" 13
)
%_ok% "Committed staged changes with analyzed message"
%_task% "Must edit committed changes message"
git commit --amend
if %ERRORLEVEL% == 1 (
  %_fatal% "Failed to edit committed changes message" 14
)
%_ok% "Committed changes message edited"
goto:eof

:write_prompt
del tmp.txt 2>NUL
if not exist "%script_dir%\mods_role_%role%.md" (
  %_fatal% "Role file '%script_dir%\mods_role_%role%.txt' is missing" 20
)
cat "%script_dir%\mods_role_%role%.md" > tmp.txt
if errorlevel 1 (
  %_fatal% "Failed to write role prompt to tmp.txt" 21
)
if not defined rel (
  git diff -w --cached %file_filter% >> tmp.txt
  if errorlevel 1 (
    %_fatal% "Failed to append Git diff to tmp.txt" 22
  )
) else (
  bash -c "$(cygpath -u '%script_dir%/git-log-filtered.sh')" >> tmp.txt
  if errorlevel 1 (
    %_fatal% "Failed to append Git log to tmp.txt" 122
  )
)
echo ``` >> tmp.txt
call:list_languages
sed -i "s/,languages,/%languages%/g" tmp.txt >nul 2>&1
if errorlevel 1 (
  %_fatal% "Failed to replace languages in tmp.txt" 23
)
goto:eof

:list_languages
set "languages="
if not defined rel (
  git diff -w --name-only --cached %file_filter% | awk -F"." "{if (NF>1) {print $NF}}" | sort -u > tmp.lg
  if errorlevel 1 (
    %_fatal% "Failed to list languages from Git diff" 24
  )
) else (
  bash -c "$(cygpath -u '%script_dir%/git-log-filtered.sh' log)" | awk -F"." "{if (NF>1) {print $NF}}" | sort -u > tmp.lg
  if errorlevel 1 (
    %_fatal% "Failed to list languages from Git log" 124
  )
)
REM Count non-empty lines to determine the last item
set count=0
for /f "usebackq tokens=*" %%a in (tmp.lg) do (
  if not "%%a"=="" set /a count+=1
)

REM Process each line with appropriate separators
set current=0
for /f "usebackq tokens=*" %%a in (tmp.lg) do (
  if not "%%a"=="" (
    set /a current+=1
    if !current! equ !count! (
      if !count! gtr 1 (
        set "languages=!languages! and %%a"
      ) else (
        set "languages=%%a"
      )
    ) else (
      if defined languages (
        set "languages=!languages!, %%a"
      ) else (
        set "languages=%%a"
      )
    )
  )
)
if defined languages (
  set "languages=, also expert in languages like: !languages!"
)
goto:eof

:dump_prompt
powershell -ExecutionPolicy Bypass -Command "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management; Get-Content tmp.txt | Set-Clipboard"
echo Prompt and Git diff --cached copied to the clipboard.
del tmp.txt 2>NUL
del tmp.lg 2>NUL
goto:eof

:configure_mods
%_task% "Must check or configure mods settings at '%MODS_SETTINGS%'"
grep "git-diff" "%MODS_SETTINGS%" >nul 2>&1
if not errorlevel 1 (
  %_ok% "git-diff role is already configured in '%MODS_SETTINGS%'"
  goto:check_model
)
awk -f "%script_dir%\mods_add_git-diff_role.awk" "%LOCALAPPDATA%\mods\mods.yml" > "%LOCALAPPDATA%\mods\mods.yml.new"
if errorlevel 1 (
  %_fatal% "Failed to add git-diff role in '%MODS_SETTINGS%'" 15
)
copy /Y "%LOCALAPPDATA%\mods\mods.yml.new" "%MODS_SETTINGS%" >nul 2>&1
if errorlevel 1 (
  %_fatal% "Failed to copy new mods settings with 'git-diff' role to '%MODS_SETTINGS%'" 16
)
%_ok% "git-diff role added in '%MODS_SETTINGS%'"

:check_model
%_task% "Must check or configure model '%model%' in '%MODS_SETTINGS%'"
grep -E "aliases:.*%model%" "%MODS_SETTINGS%" >nul 2>&1
if not errorlevel 1 (
  %_ok% "Model '%model%' is already configured in '%MODS_SETTINGS%'"
  goto:check_default_model
)
awk -f "%script_dir%\mods_add_gemini_model.awk" "%LOCALAPPDATA%\mods\mods.yml" > "%LOCALAPPDATA%\mods\mods.yml.new"
if errorlevel 1 (
  %_fatal% "Failed to add model '%model%' in '%MODS_SETTINGS%'" 15
)
copy /Y "%LOCALAPPDATA%\mods\mods.yml.new" "%MODS_SETTINGS%" >nul 2>&1
if errorlevel 1 (
  %_fatal% "Failed to copy new mods settings with model '%model%' to '%MODS_SETTINGS%'" 16
)
%_ok% "Model '%model%' added in '%MODS_SETTINGS%'"

:check_default_model
%_task% "Must check/set default model to '%model%'"
grep "default-model: %model%" "%MODS_SETTINGS%" >nul 2>&1
if not errorlevel 1 (
  %_ok% "Default model '%model%' is already set in '%MODS_SETTINGS%'"
  goto:configure_mods_done
)
sed -i "s/^default-model: .*$/default-model: %model%/g" "%MODS_SETTINGS%" >nul 2>&1
if errorlevel 1 (
  %_fatal% "Failed to set default model '%model%' in '%MODS_SETTINGS%'" 17
)
%_ok% "Default model '%model%' set in '%MODS_SETTINGS%'"

:configure_mods_done
%_info% "'%MODS_SETTINGS%' setting all set (model '%model%'): ready to use"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" && goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
