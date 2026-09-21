@echo off
setlocal enabledelayedexpansion

rem aiup.bat - make sure Internet access is there (ensure_internet.bat), then
rem update the Codex and Claude CLIs. A CLI that still has a running process is
rem left alone: replacing the binary under a live session is what 'force' is for.
rem
rem   aiup           ensure_internet, then update both when they are idle
rem   aiup codex     only Codex
rem   aiup claude    only Claude
rem   aiup force     update even when a session is running
rem   aiup dry       report what would be done, change nothing
rem
rem The Codex installer is driven with CODEX_NON_INTERACTIVE=1: its Prompt-YesNo
rem then answers 'no' without asking, which both skips the [y/N] questions and
rem keeps the installer from launching Codex once it is done.
rem
rem Beware: run from inside a Claude session, 'aiup' always sees claude.exe
rem running and skips it. Update Claude from a plain cmd tab, or use
rem 'aiup claude force'.

for %%i in ("%~dp0.") do set "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do set "senv_dir=%%~fi"
call "%senv_dir%\batcolors\echos_macros.bat"

set "aiup_want_codex="
set "aiup_want_claude="
set "aiup_force="
set "aiup_dry="
set "aiup_rc=0"

:parse_args
if "%~1"=="" goto:args_parsed
if /I "%~1"=="codex" ( set "aiup_want_codex=1" & shift & goto:parse_args )
if /I "%~1"=="claude" ( set "aiup_want_claude=1" & shift & goto:parse_args )
if /I "%~1"=="force" ( set "aiup_force=1" & shift & goto:parse_args )
if /I "%~1"=="dry" ( set "aiup_dry=1" & shift & goto:parse_args )
%_fatal% "Unknown argument '%~1'; expected 'codex', 'claude', 'force' or 'dry'" 41

:args_parsed
if not defined aiup_want_codex if not defined aiup_want_claude (
   set "aiup_want_codex=1"
   set "aiup_want_claude=1"
)

rem The installers reach the network through curl.exe and powershell.exe, both
rem of which live in System32; senv rebuilds PATH, so make sure it is in front.
set "PATH=%WINDIR%\System32;%PATH%"

rem Both installers download through Invoke-WebRequest, which ignores HTTPS_PROXY:
rem when one is set, it has to be handed to PowerShell explicitly (see
rem :run_installer). Without it, the Codex installer cannot reach
rem releases.openai.com behind a proxy and falls back to the GitHub API, whose
rem 60 unauthenticated calls per hour a shared proxy address spends quickly.
set "aiup_proxy=%HTTPS_PROXY%"
set "aiup_through="
if defined aiup_proxy set "aiup_through= through proxy '%HTTPS_PROXY%'"

call :ensure_internet
if errorlevel 1 exit /b %ERRORLEVEL%

if defined aiup_want_codex call :update_codex
if defined aiup_want_claude call :update_claude

if not "%aiup_rc%"=="0" (
   %_error% "aiup finished with errorlevel '%aiup_rc%'"
   exit /b %aiup_rc%
)
%_ok% "aiup finished"
exit /b 0


:ensure_internet
%_task% "Must ensure Internet access is available"
if not exist "%script_dir%\ensure_internet.bat" (
   %_fatal% "Missing Internet check: '%script_dir%\ensure_internet.bat'" 42
)
call "%script_dir%\ensure_internet.bat"
if errorlevel 1 (
   %_fatal% "Internet access is not available; no update possible" 43
)
exit /b 0


:update_codex
call :running "codex.exe"
if not errorlevel 1 (
   if not defined aiup_force (
      %_warning% "Codex is running (PID !aiup_pids!); leaving it alone. Use 'aiup codex force' to update anyway"
      exit /b 0
   )
   %_warning% "Codex is running (PID !aiup_pids!); updating anyway because 'force' was given"
)

if defined aiup_dry (
   %_info% "dry: curl.exe -L https://chatgpt.com/codex/install.ps1 -o '%TEMP%\codex-install.ps1'"
   %_info% "dry: CODEX_NON_INTERACTIVE=1 powershell.exe -File '%TEMP%\codex-install.ps1'!aiup_through!"
   exit /b 0
)

%_task% "Must download the Codex installer"
curl.exe --progress-bar -L https://chatgpt.com/codex/install.ps1 -o "%TEMP%\codex-install.ps1"
if errorlevel 1 (
   %_error% "Unable to download the Codex installer"
   set "aiup_rc=44"
   exit /b 44
)

%_task% "Must run the Codex installer without any confirmation!aiup_through!"
set "CODEX_NON_INTERACTIVE=1"
call :run_installer "%TEMP%\codex-install.ps1"
set "aiup_step=!ERRORLEVEL!"
set "CODEX_NON_INTERACTIVE="
if not "!aiup_step!"=="0" (
   %_error% "Codex installer failed with errorlevel '!aiup_step!'"
   set "aiup_rc=45"
   exit /b 45
)
%_ok% "Codex is up to date"
exit /b 0


:update_claude
call :running "claude.exe"
if not errorlevel 1 (
   if not defined aiup_force (
      %_warning% "Claude is running (PID !aiup_pids!); leaving it alone. Use 'aiup claude force' to update anyway"
      exit /b 0
   )
   %_warning% "Claude is running (PID !aiup_pids!); updating anyway because 'force' was given"
)

if defined aiup_dry (
   %_info% "dry: curl.exe -L https://claude.ai/install.ps1 -o '%TEMP%\claude-install.ps1'"
   %_info% "dry: powershell.exe -File '%TEMP%\claude-install.ps1'!aiup_through!"
   exit /b 0
)

%_task% "Must download the Claude installer"
curl.exe --progress-bar -L https://claude.ai/install.ps1 -o "%TEMP%\claude-install.ps1"
if errorlevel 1 (
   %_error% "Unable to download the Claude installer"
   set "aiup_rc=46"
   exit /b 46
)

%_task% "Must run the Claude installer!aiup_through!"
call :run_installer "%TEMP%\claude-install.ps1"
set "aiup_step=!ERRORLEVEL!"
if not "!aiup_step!"=="0" (
   %_error% "Claude installer failed with errorlevel '!aiup_step!'"
   set "aiup_rc=47"
   exit /b 47
)
%_ok% "Claude is up to date"
exit /b 0


rem Runs the PowerShell installer %1, with aiup_proxy as its default web proxy
rem when one is set.
:run_installer
if not defined aiup_proxy (
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~1"
   exit /b !ERRORLEVEL!
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy('!aiup_proxy!'); & '%~1'"
exit /b %ERRORLEVEL%


rem The echos macros call this label to name the script logging each line.
:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof


rem Sets aiup_pids to the PID list of the running processes named %1, and
rem returns 0 when at least one was found, 1 when none was.
:running
set "aiup_pids="
for /f "usebackq tokens=2 delims=," %%p in (`tasklist.exe /FI "IMAGENAME eq %~1" /NH /FO CSV 2^>NUL`) do (
   if defined aiup_pids (
      set "aiup_pids=!aiup_pids! %%~p"
   ) else (
      set "aiup_pids=%%~p"
   )
)
if defined aiup_pids exit /b 0
exit /b 1
