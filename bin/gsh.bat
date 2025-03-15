@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

git diff --cached --quiet
if %ERRORLEVEL% == 0 (
  %_fatal% "No changes to commit" 11
)

if "%~1"=="prompt" ( call:dump_prompt && exit /b 0 )

set "npp_settings="
if exist "%PRGS%\npps\settings" set "npp_settings= -settingsDir="%PRGS%\npps\settings""

set "mods=%GOBIN%\mods.exe"
set "EDITOR=%PRGS%\npps\current\notepad++.exe%npp_settings% -multiInst -notabbar -nosession -noPlugin"

set model=gemini
if defined GEMINI_MODEL (
  %_warning% "GEMINI_MODEL is defined: '%GEMINI_MODEL%'"
  set "model=%GEMINI_MODEL%"
) else (
  %_warning% "GEMINI_MODEL is not defined: use gemini, alias for 'gemini-1.5-pro-latest'"
)
set "param=%~1"
if defined param ( goto:commit_with_analyzed_message )
%_task% "Must analyze staged changes"
git diff --cached | "%mods%" --role=cm-shell --model=%model%
if %ERRORLEVEL% == 1 (
  %_fatal% "Failed to analyze staged changes" 12
)
%_ok% "Analyzed staged changes"
:commit_with_analyzed_message
set "EDITOR="%PRGS%\npps\current\notepad++.exe"%npp_settings% -multiInst -notabbar -nosession -noPlugin"
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

:dump_prompt
for /f "tokens=2* delims=:" %%a in ('mods --dirs ^| findstr "Configuration"') do (
    set "config_path=%%a:%%b"
)
REM Optionally remove any leading space
set "config_path=%config_path:~1%"
echo %config_path%
if not exist "%config_path%\mods.yml" (
    %_fatal% "Configuration directory not found: '%config_path%\mods.yml'" 15
)
awk -ve= "/cm-shell:/ { flag=1 } flag { if ($0 ~ /^[[:space:]]*#/) exit; if ($0 ~ /^[[:space:]]*-[[:space:]]/) { line=$0; sub(/^[[:space:]]*-[[:space:]]/, e, line); if (line ^!= e) print line } }" "%config_path%\mods.yml" > tmp.txt
echo Reminder: conventional commit means: the title must start with `^<type^>[optional scope]: description`, with 52 characters max>> tmp.txt
echo Types other than `fix:` and `feat:` are `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, and others.>> tmp.txt
echo Do not add a footer. Do not add an introduction like 'The title should be...'. Just print the title and the body of the commit message without any other comment.>> tmp.txt
echo the title must not exceed 52 characters>> tmp.txt
echo the body and footer lines must not exceed 80 characters, and must not be indented, no prefix spaces.>> tmp.txt
echo If I provide an additional prompt explaining the context of this diff, do include that into your generated commit message.>> tmp.txt
echo Make sure the body includes two sections, Why and What.>> tmp.txt
echo In the 'why' section, do not use generic 'Improved xxx' without explaining why xxx is improved.>> tmp.txt
echo In the 'what' section, make a list of modifications, each line starting with a dash.>> tmp.txt
echo.>> tmp.txt
echo The following git diff, with its lines starting with plus or minus, does contain changes to the codebase:>> tmp.txt
echo.>> tmp.txt
echo ```>> tmp.txt
git diff --cached>> tmp.txt
echo ```>> tmp.txt
powershell -ExecutionPolicy Bypass -Command "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management; Get-Content tmp.txt | Set-Clipboard"
echo Prompt and Git diff --cached copied to the clipboard.
del tmp.txt
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
