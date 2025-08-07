@REM ********************************************************************
@REM * Modsi - Mods Interactive Batch Script
@REM *
@REM * This script opens a notepad++ session to allow the user to write
@REM * their question. if a local mods_i.id file exists, the notepad++
@REM * session starts with "(continue conversion ID <id>)" text.
@REM * If the file does not exist, it starts with "(new conversion)" text.
@REM *
@REM * When the user saves and closes the notepad++ session,
@REM * the script reads the content of the file and passes it to the
@REM * mods.exe tool for processing.
@REM * If the file starts with "(continue conversion ID <id>)", mods.exe
@REM * is called with the `-C` option to continue the last conversation.
@REM * If not, mods_i.id is deleted and a new conversation is started.
@REM *
@REM * Once the mods.exe tool returns a response, it is displayed in
@REM * the console, but mods.exe -Sr is also called to
@REM * save the response to a file in the current directory.
@REM * The response is also copied to the clipboard. Look for the last prompt
@REM * in the console output and copy only that part to the clipboard.
@REM * Open also a notepad++ session with the response (from the last prompt included).
@REM *
@REM * Usage:
@REM *   modsi      - Launch or resume an interactive session with mods
@REM ********************************************************************

@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

set "NO_MODS="
set "MODS_SETTINGS=%LOCALAPPDATA%\mods\mods.yml"
set "MODS=%GOBIN%\mods.exe"
set "question_file=mods_i_question.txt"
set "title_file=mods_i.title"

REM Check if mods tool exists
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
if defined NO_MODS (
  %_fatal% "Mods tool is required for this script to work" 10
  exit /b 10
)

REM Set up Notepad++ editor command
set "EDITOR=%PRGS%\npps\current\notepad++.exe -multiInst -notabbar -nosession -noPlugin"

REM Create question file with appropriate initial text
if exist "%title_file%" (
  set /p conversation_title=<"%title_file%"
  set "msg=Current recorded conversation title '!conversation_title!'"
) else (
  set "msg=Starting new conversation: replace this line with a PROPER TITLE"
)

%_info% "%msg%"

if exist "%question_file%" (
  goto:_skip_create_question_file
)
if defined conversation_title (
  echo %conversation_title%>"%question_file%"
  echo.>>"%question_file%"
  echo Or replace this line with a PROPER TITLE to start a new conversation>>"%question_file%"
) else (
  echo %msg%>"%question_file%"
  echo.>>"%question_file%"
)
:_skip_create_question_file

REM Open editor for user to write question
:_open_editor
%_task% "Opening editor for you to write your question. Save and close when done."
%EDITOR% "%question_file%"

REM Read the content of the question file
if not exist "%question_file%" (
  %_fatal% "Question file was not saved properly" 11
  exit /b 11
)

REM check a proper title in the question file
set "first_line="
for /f "usebackq delims=" %%a in ("%question_file%") do (
  set "first_line=%%a"
  goto:after_first_line
)
:after_first_line
if not defined first_line (
  %_fatal% "Question file is empty or not properly formatted" 12
  exit /b 12
)
REM Check if the first line includes "new conversation": if so, goto back to :_open_editor after a warning
set "warning_msg="
if not "%first_line:new conversation=%"=="%first_line%" (
  set "warning_msg=Please provide a proper title for your question in the first line."
)
if not "%first_line:PROPER TITLE=%"=="%first_line%" (
  set "warning_msg=Please provide a proper title for your question in the first line."
)
if "%first_line: =%"=="" (
  set "warning_msg=Mandatory: a proper title for your question in the first line."
)

if defined warning_msg (
  %_warning% "%warning_msg%"
  %_info% "Opening editor again for you to set the title."
  goto:_open_editor
)

REM Check first line compared to title to determine if this is a continuation
if "%first_line%"=="%conversation_title%" (
  %_info% "Continuing existing conversation '%conversation_title%'"
  set "continue_flag=-C"
) else (
  %_info% "Starting new conversation '%first_line%'"
  set "continue_flag="
  echo %first_line%> "%title_file%"
)

REM Check internet connection
call "%script_dir%\ensure_internet.bat"
if errorlevel 1 (
  %_fatal% "Internet connection is required to use mods" 10
  exit /b 10
)

REM Process the question with mods
%_task% "Processing your question with mods..."
if defined continue_flag (
  type "%question_file%" | "%MODS%" %continue_flag% 2>&1
) else (
  type "%question_file%" | "%MODS%" 2>&1
)

REM Save response to file
%_task% "Saving response to file..."
"%MODS%" -Sr > mods_i_response.txt
if errorlevel 1 (
  %_warning% "Failed to save response to file"
)
del "%question_file%" 2>NUL

REM Extract last prompt response and copy to clipboard
%_task% "Copying response to clipboard..."
for /f "tokens=1 delims=:" %%a in ('grep -n "^\*\*Assistant\*\*: " mods_i_response.txt') do set "last_line=%%a"
type mods_i_response.txt | awk 'NR ^>= %last_line% ^&^& ^(index^($0, "**Assistant**: "^)==1 || found^) { if (index($0, "**Assistant**: ")==1) { found=1; sub(/^\*\*Assistant\*\*: /, ""); } if (found) print; }' | sed -e :a -e '/^^\n*$/{$d;N;ba' -e '}' | head -c -1 > clipboard.txt
powershell -ExecutionPolicy Bypass -Command "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management; Get-Content clipboard.txt | Set-Clipboard"
if errorlevel 1 (
  %_warning% "Failed to copy response to clipboard"
) else (
  %_ok% "Response copied to clipboard"
)

REM Open response in Notepad++
%_task% "Opening response in editor..."
%EDITOR% clipboard.txt

REM Cleanup clipboard file
del clipboard.txt 2>NUL

%_ok% "Mods interactive session completed successfully"
goto:eof

REM -----------------------------------------------------------------------------
REM Function: call_echos_stack
REM
REM Handles script tracing and logging by integrating with an external echo
REM utility for better debugging and error reporting.
REM -----------------------------------------------------------------------------
:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" && goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
