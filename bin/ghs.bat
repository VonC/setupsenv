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

set "mods=%GOBIN%\mods.exe"
set "EDITOR=%PRGS%\npps\current\notepad++.exe -multiInst -notabbar -nosession -noPlugin"

%_task% "Must analyze staged changes"
git diff --cached | "%mods%" --role=cm-shell
if %ERRORLEVEL% == 1 (
  %_fatal% "Failed to analyze staged changes" 12
)
%_ok% "Analyzed staged changes"
set "EDITOR="%PRGS%\npps\current\notepad++.exe" -multiInst -notabbar -nosession -noPlugin"
%_task% "Must commit staged changes with analyzed message"
mods -Sr | git commit -F -
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