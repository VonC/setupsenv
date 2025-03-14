@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

set "tag_name=%1"
if not defined tag_name (
  %_fatal% "A tag name is needed" 1
)

if defined REPLACE_DATE ( goto:replace_date )
bash -c 'res=$(git show -s --format=%%N "${tag_name}" ^| tail -n +4); echo -n "${res}"'
goto:eof

:replace_date
bash -c 'res=$(git show -s --format=%%N "${tag_name}" ^| tail -n +4 ^| sed "1s/^.*\? --/${tag_name} --/"); echo -n "${res}"'
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
