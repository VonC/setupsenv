@echo off
setlocal enabledelayedexpansion

rem codexu.bat - make sure Internet access is there (ensure_internet.bat), then
rem update the Codex CLI, then the Codex app-server daemon that every Codex
rem session connects to, so that both run the same version.
rem
rem   codexu       update the CLI, then the daemon when it runs another version
rem   codexu dry   print the versions and what would be done, change nothing
rem
rem aiup.bat runs it for Codex, after Claude, with the PATH aiup was called
rem with.
rem
rem The daemon cannot update itself under senv. It keeps the environment of
rem the Codex that started it, where Git's GNU tar comes before Windows' own:
rem its hourly installer run fails to extract the package, GNU tar reading the
rem 'C:' of the archive path as a remote host. A newer Codex then warns that
rem "a background Codex service is running" an older version.
rem 'codex app-server daemon update --from-cli' selects the CLI package just
rem installed instead: nothing to download or extract. It also pins the daemon
rem to it, which stops the hourly attempts: codexu is what updates the daemon.
rem Replacing the daemon package can interrupt the work of running Codex
rem sessions, and Codex asks first: codexu answers with --yes, so that it asks
rem nothing.

for %%i in ("%~dp0.") do set "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do set "senv_dir=%%~fi"
call "%senv_dir%\batcolors\echos_macros.bat"

set "codexu_dry="

:parse_args
if "%~1"=="" goto:args_parsed
if /I "%~1"=="dry" ( set "codexu_dry=1" & shift & goto:parse_args )
%_fatal% "Unknown argument '%~1'; expected nothing or 'dry'" 41

:args_parsed
set "codexu_home=%USERPROFILE%\.codex"
if defined CODEX_HOME set "codexu_home=%CODEX_HOME%"
set "codexu_cli=%codexu_home%\packages\standalone\current\bin\codex.exe"

rem The daemon update can restart the daemon from this script, and the
rem daemon keeps the environment it starts with: :update_daemon gives it back
rem the PATH a Codex pane gives it.
set "codexu_path=%PATH%"
rem The installer downloads through curl.exe and powershell.exe, and extracts
rem with tar.exe: all three from System32, not Git's GNU tar.
set "PATH=%WINDIR%\System32;%PATH%"

rem Invoke-WebRequest ignores HTTPS_PROXY: when one is set, it is handed to
rem PowerShell explicitly, as aiup.bat does (see :run_installer).
set "codexu_proxy=%HTTPS_PROXY%"
set "codexu_through="
if defined codexu_proxy set "codexu_through= through proxy '%HTTPS_PROXY%'"

call :versions
if defined codexu_dry goto:dry

call :ensure_internet
if errorlevel 1 exit /b %ERRORLEVEL%
call :update_cli
if errorlevel 1 exit /b %ERRORLEVEL%
call :update_daemon
if errorlevel 1 exit /b %ERRORLEVEL%
%_ok% "codexu finished"
exit /b 0


:dry
%_info% "dry: ensure_internet.bat"
%_info% "dry: curl.exe -L https://chatgpt.com/codex/install.ps1 -o '%TEMP%\codex-install.ps1'"
%_info% "dry: CODEX_NON_INTERACTIVE=1 powershell.exe -File '%TEMP%\codex-install.ps1'!codexu_through!"
%_info% "dry: codex app-server daemon update --from-cli --yes, unless the daemon then runs the CLI version"
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


:update_cli
%_task% "Must download the Codex installer"
curl.exe --progress-bar -L https://chatgpt.com/codex/install.ps1 -o "%TEMP%\codex-install.ps1"
if errorlevel 1 (
   %_error% "Unable to download the Codex installer"
   exit /b 44
)

rem With CODEX_NON_INTERACTIVE=1, the installer's Prompt-YesNo answers 'no'
rem without asking, which both skips the [y/N] questions and keeps the
rem installer from launching Codex once it is done.
%_task% "Must run the Codex installer without any confirmation!codexu_through!"
set "CODEX_NON_INTERACTIVE=1"
call :run_installer "%TEMP%\codex-install.ps1"
set "codexu_step=!ERRORLEVEL!"
set "CODEX_NON_INTERACTIVE="
if not "!codexu_step!"=="0" (
   %_error% "Codex installer failed with errorlevel '!codexu_step!'"
   exit /b 45
)
if not exist "%codexu_cli%" (
   %_error% "No Codex CLI at '%codexu_cli%' after the installer"
   exit /b 47
)
%_ok% "The Codex CLI is up to date"
exit /b 0


:update_daemon
call :versions
set "codexu_same="
if not "!codexu_cli_v!"=="-" if "!codexu_pkg_v!"=="!codexu_cli_v!" (
   if "!codexu_run_v!"=="!codexu_cli_v!" set "codexu_same=1"
   if "!codexu_run_v!"=="-" set "codexu_same=1"
)
if defined codexu_same (
   %_ok% "The Codex daemon package is already !codexu_cli_v!"
   exit /b 0
)

%_task% "Must select the CLI package !codexu_cli_v! for the Codex daemon"
rem As in a Codex pane: senv's PATH, and no certificate bundle, which breaks
rem the TLS connections of Codex.
set "PATH=%codexu_path%"
set "SSL_CERT_FILE="
set "CODEX_CA_CERTIFICATE="
"%codexu_cli%" app-server daemon update --from-cli --yes
set "codexu_step=!ERRORLEVEL!"
if not "!codexu_step!"=="0" (
   %_error% "The Codex daemon was not updated: errorlevel '!codexu_step!'"
   exit /b 46
)
call :versions
%_ok% "The Codex daemon package is !codexu_pkg_v!"
exit /b 0


rem Sets codexu_cli_v, codexu_pkg_v and codexu_run_v to the versions of the
rem CLI, of the daemon package and of the running daemon, '-' when unknown.
rem 'daemon version' fails when no daemon runs, so the two package versions
rem come from their codex-package.json, and only the running one from it.
:versions
set "codexu_cli_v=-"
set "codexu_pkg_v=-"
set "codexu_run_v=-"
if not exist "%codexu_cli%" (
   %_info% "No Codex CLI yet at '%codexu_cli%'"
   exit /b 0
)
for /f "usebackq tokens=1-3" %%a in (`powershell.exe -NoProfile -Command "function V($f) { try { $v = (Get-Content -Raw -LiteralPath (Join-Path $env:codexu_home $f) -ErrorAction Stop | ConvertFrom-Json).version } catch { $v = $null }; if ($v) { $v } else { '-' } }; $r = $null; $j = & $env:codexu_cli app-server daemon version 2>$null; if ($LASTEXITCODE -eq 0) { try { $r = ($j | ConvertFrom-Json).appServerVersion } catch {} }; if (-not $r) { $r = '-' }; (V 'packages\standalone\current\codex-package.json'), (V 'packages\app-server-daemon\current\codex-package.json'), $r -join ' '"`) do (
   set "codexu_cli_v=%%a"
   set "codexu_pkg_v=%%b"
   set "codexu_run_v=%%c"
)
%_info% "Codex CLI !codexu_cli_v!, daemon package !codexu_pkg_v!, running daemon !codexu_run_v!"
exit /b 0


rem Runs the PowerShell installer %1, with codexu_proxy as its default web
rem proxy when one is set.
:run_installer
if not defined codexu_proxy (
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~1"
   exit /b !ERRORLEVEL!
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy('!codexu_proxy!'); & '%~1'"
exit /b %ERRORLEVEL%


rem The echos macros call this label to name the script logging each line.
:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
