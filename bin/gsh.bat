@REM ********************************************************************
@REM * GSH - Git Smart Helper
@REM * 
@REM * This script enhances Git workflow by using AI to analyze changes
@REM * and generate meaningful commit messages. It integrates with the
@REM * 'mods' tool to leverage AI models (primarily Gemini) for analyzing
@REM * Git diffs and producing contextual commit messages or release notes.
@REM *
@REM * Key features:
@REM * - Analyzes code changes to create smart commit messages
@REM * - Special handling for documentation changes
@REM * - Release notes generation from Git history
@REM * - Automatic language detection for better AI context
@REM * - Configurable AI model selection
@REM *
@REM * Usage:
@REM *   gsh         - Analyze staged changes and create commit
@REM *                 SKip txt and md unless txt or/and md are specified
@REM *   gsh doc     - Analyze documentation changes only
@REM *   gsh docs    - Analyze documentation changes only
@REM *   gsh rel     - Analyze changes for release notes
@REM *   gsh context - Provide additional context for the AI analysis
@REM *                 Can be combined with any mode: gsh context doc
@REM *   gsh prompt  - Just dump the prompt (for debugging)
@REM *                 Can be combined with doc or rel: gsh doc prompt
@REM *   gsh dump    - Synonym for 'prompt', dumps the prompt to clipboard
@REM *                 Can be combined with doc or rel: gsh doc dump
@REM ********************************************************************

@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

REM Check for help parameters in any position
:check_help_params
set "arg_count=0"
:next_help_param
if "%~1"=="" goto:help_check_done
set /a "arg_count+=1"
if /i "%~1"=="--help" goto:usage
if /i "%~1"=="-h" goto:usage
shift
goto:next_help_param
:help_check_done

set "rel="
set "context_mode="

@REM Check for context mode
if /i "%~1"=="context" (
  set "context_mode=true"
  shift
)

if "%~1"=="rel" (
  set "rel=true"
  goto:skip_index_check
)
git diff -w --cached --quiet
if %ERRORLEVEL% == 0 (
  %_fatal% "No changes to commit" 11
)

@REM Skip checking for staged changes when in release mode
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
@REM Continue execution after checking for mods tool availability
:after_mods_checks

set "role=commit_diff"
set "file_filter="
set "include_txt="
set "include_md="
if "%~1"=="txt" (
  set "include_txt=true"
  shift
)
if "%~1"=="md" (
  set "include_md=true"
  shift
)
if "%~1"=="txt" (
  set "include_txt=true"
  shift
)
if not defined include_md if not defined include_txt goto:exclude_both
if not defined include_md if defined include_txt goto:exclude_md
if defined include_md if not defined include_txt goto:exclude_txt
goto:no_exclude

:exclude_both
set "file_filter=":(exclude)*.md" ":(exclude)*.txt""
goto:filter_done

:exclude_md
set "file_filter=":(exclude)*.md""
goto:filter_done

:exclude_txt
set "file_filter=":(exclude)*.txt""
goto:filter_done

:no_exclude
set "file_filter="

:filter_done
if not "%~1"=="doc" (
  if not "%~1"=="docs" (
    goto:arg_check_rel
  )
)
set "role=commit_documentation"
set "file_filter=":(glob)**/*.md" ":(glob)**/*.txt""
shift
@REM Check for 'doc' argument and set appropriate role and file filter
:arg_check_rel
if not "%~1"=="rel" ( goto:arg_check_done )
set "role=analyze_release"
set "file_filter=":(exclude)*.md""
shift

@REM Continue after argument parsing
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

set "SENV_EI_DONE="
call "%script_dir%\ensure_internet.bat"
if errorlevel 1 (
  %_fatal% "Internet connection is required to use mods" 10
)
set "SENV_EI_DONE=1"
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

@REM Perform the actual Git commit with AI-generated message
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
del tmp.txt 2>NUL
del tmp.lg 2>NUL
del tmp.context 2>NUL
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: write_prompt
@REM
@REM Prepares the AI prompt by combining a role-specific template with Git diff or
@REM log information. It loads the appropriate prompt template based on the current
@REM role (commit_diff, commit_documentation, or analyze_release), then appends
@REM the relevant Git information (diff or log).
@REM
@REM The function also handles language detection and replaces placeholders in the
@REM prompt template with the detected programming languages.
@REM
@REM Parameters: None
@REM Returns: None (writes to tmp.txt)
@REM -----------------------------------------------------------------------------
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
  echo git diff -w --cached %file_filter%
  for %%A in (tmp.txt) do set before_size=%%~zA
  git diff -w --cached %file_filter% >> tmp.txt
  if errorlevel 1 (
    %_fatal% "Failed to append Git diff to tmp.txt" 22
  )
  for %%A in (tmp.txt) do set after_size=%%~zA
  if !before_size! equ !after_size! (
    %_fatal% "No changes to commit - git diff is empty" 25
  )
  %_ok% "Git diff appended to tmp.txt"
) else (
  bash -c "$(cygpath -u '%script_dir%/git-log-filtered.sh')" >> tmp.txt
  if errorlevel 1 (
    %_fatal% "Failed to append Git log to tmp.txt" 122
  )
)
echo ``` >> tmp.txt

@REM Handle additional context if context mode is enabled
if defined context_mode (
  call:create_context_file
  if exist tmp.context (
    echo. >> tmp.txt
    type tmp.context >> tmp.txt
    %_ok% "Additional context appended to analysis"
  )
)

call:list_languages
sed -i "s/,languages,/%languages%/g" tmp.txt >nul 2>&1
if errorlevel 1 (
  %_fatal% "Failed to replace languages in tmp.txt" 23
)
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: create_context_file
@REM
@REM Creates a temporary file for the user to add additional context information
@REM for the AI analysis. The introduction text varies based on the current mode.
@REM
@REM Parameters: None
@REM Returns: None (creates tmp.context file)
@REM -----------------------------------------------------------------------------
:create_context_file
del tmp.context 2>NUL

@REM Create appropriate introduction based on current role
if "%role%"=="commit_diff" (
  echo To help in your analysis of code changes, consider also the following context:> tmp.context
) else if "%role%"=="commit_documentation" (
  echo To help in your analysis of documentation changes, consider also the following context:> tmp.context
) else if "%role%"=="analyze_release" (
  echo To help in your analysis for release notes, consider also the following context:> tmp.context
)

%_info% "Please add your context in the opening editor and save+close when done."
%EDITOR% tmp.context
if not exist tmp.context (
  %_warning% "Context file was not saved, continuing without additional context"
)
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: list_languages
@REM
@REM Identifies programming languages used in the changed files by analyzing file
@REM extensions. Creates a formatted list of languages to inform the AI about
@REM the technical context of the changes.
@REM
@REM For regular and doc modes, it analyzes file extensions in the staged changes.
@REM For release mode, it analyzes file extensions in the Git log.
@REM
@REM The function handles proper comma and "and" formatting for the language list.
@REM
@REM Parameters: None
@REM Returns: Sets %languages% environment variable with the formatted list
@REM -----------------------------------------------------------------------------
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

@REM -----------------------------------------------------------------------------
@REM Function: dump_prompt
@REM
@REM Copies the generated AI prompt to the system clipboard for inspection or
@REM manual processing. This function is used when:
@REM - The mods tool is unavailable
@REM - The user explicitly requests the prompt (via 'prompt' or 'dump' argument)
@REM - For debugging purposes
@REM
@REM It also cleans up temporary files after copying.
@REM
@REM Parameters: None
@REM Returns: None (outputs message to console, copies to clipboard)
@REM -----------------------------------------------------------------------------
:dump_prompt
powershell -ExecutionPolicy Bypass -Command "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management; Get-Content tmp.txt | Set-Clipboard"
echo Prompt and Git diff --cached copied to the clipboard.
del tmp.txt 2>NUL
del tmp.lg 2>NUL
del tmp.context 2>NUL
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: configure_mods
@REM
@REM Ensures that the mods tool is properly configured with:
@REM 1. The git-diff role - Adds it if missing
@REM 2. The specified AI model - Adds model configuration if missing
@REM 3. Sets the default model - Updates if needed
@REM
@REM This function modifies the mods configuration file (mods.yml) as needed
@REM to ensure the script can properly interface with the AI model.
@REM
@REM Parameters: None
@REM Returns: None
@REM -----------------------------------------------------------------------------
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

@REM Check if the specified model is configured in mods
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

@REM Check/set the default model in mods configuration
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

@REM Configuration of mods is complete
:configure_mods_done
%_info% "'%MODS_SETTINGS%' setting all set (model '%model%'): ready to use"
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: call_echos_stack
@REM
@REM Handles script tracing and logging by integrating with an external echo
@REM utility for better debugging and error reporting. It checks if the ECHOS_STACK
@REM variable is defined and either sets the current script name or calls the
@REM echos.bat script with the current script name.
@REM
@REM Parameters: None
@REM Returns: None
@REM -----------------------------------------------------------------------------
:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" && goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof

@REM -----------------------------------------------------------------------------
@REM Function: usage
@REM
@REM Displays help information about the GSH (Git Smart Helper) script, 
@REM including its purpose and available command-line options.
@REM
@REM Parameters: None
@REM Returns: None (outputs help to console and exits)
@REM -----------------------------------------------------------------------------
:usage
echo.
%_info% "GSH - Git Smart Helper"
echo.
echo   This script enhances Git workflow by using AI to analyze changes
echo   and generate meaningful commit messages. It integrates with the
echo   'mods' tool to leverage AI models (primarily Gemini) for analyzing
echo   Git diffs and producing contextual commit messages or release notes.
echo.
echo Key features:
echo   - Analyzes code changes to create smart commit messages
echo   - Special handling for documentation changes
echo   - Release notes generation from Git history
echo   - Automatic language detection for better AI context
echo   - Configurable AI model selection
echo.
echo Usage:
echo   gsh                - Analyze staged changes and create commit
echo                          (Skip txt and md unless txt or/and md are specified)
echo   gsh txt            - Include .txt files in analysis
echo   gsh md             - Include .md files in analysis
echo   gsh doc/docs       - Analyze documentation changes only (txt/md files)
echo   gsh rel            - Analyze changes for release notes (between last tagged commit and HEAD)
echo   gsh context        - Provide additional context for the AI analysis
echo                          (Can be combined with any mode: gsh context doc)
echo   gsh prompt/dump    - Just dump the prompt (in clipboard, for copy/pasting elsewhere)
echo                          (Can be combined with doc or rel: gsh doc prompt)
echo   gsh -h, --help     - Display this help information
echo.
exit /b 0
goto:eof
