@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "installs_dir=%%~fi"
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
cd /d "%installs_dir%" || echo "unable to cd to '%installs_dir%'"&& exit /b 1

call:check_internet
call:resolve_setupsdir

powershell -ExecutionPolicy Bypass -File "%installs_dir%\terminals.post.wrapper.ps1"
set "err=%ERRORLEVEL%"

endlocal & exit /b %err%

:check_internet
rem The font download is the only Internet-bound step, and a setups folder may
rem already hold that font: a missing connection is reported to the PowerShell
rem script through SENV_INTERNET_OK instead of failing the whole post install.
set "SENV_INTERNET_OK=1"
call "%script_dir%\bin\testinternet.bat"
if not errorlevel 1 ( goto:eof )
if defined HTTPS_PROXY (
    %_task% "Must reset the proxy before the font download"
    rem ensure_internet.bat is fatal by design: keep it from killing this hook.
    set "FATALNOEXIT=1"
    call "%script_dir%\bin\ensure_internet.bat"
    set "FATALNOEXIT="
    call "%script_dir%\bin\testinternet.bat"
    if not errorlevel 1 ( goto:eof )
)
set "SENV_INTERNET_OK=0"
%_warning% "No Internet access: the font can only come from a setups folder"
goto:eof

:resolve_setupsdir
rem setup.bat and inst_prg.bat both define setupsdir before calling this hook.
rem Resolve it here only for a standalone run, through the same profile mechanism
rem as dwl.bat :find_setups_zip, so the font lookup still sees the remote setups
rem folder. Each skip prints its reason: a silent fall-through here reads as
rem "no remote setups folder exists" and hides the cause.
if defined setupsdir (
    %_info% "Remote setups folder already known: '%setupsdir%'"
    goto:eof
)
set "profile_filename="
if exist "%HOME%\bin\profile" ( set "profile_filename=%HOME%\bin\profile" )
if not defined profile_filename (
    if exist "%script_dir%\custom\profile" ( set "profile_filename=%script_dir%\custom\profile" )
)
if not defined profile_filename (
    %_info% "No profile file: no remote setups folder for the font lookup"
    goto:eof
)
set "profile_name="
for /f "usebackq" %%a in ("%profile_filename%") do ( set "profile_name=%%a" )
if not defined profile_name (
    %_info% "Empty profile '%profile_filename%': no remote setups folder for the font lookup"
    goto:eof
)
if not exist "%script_dir%\custom\setupsdir_%profile_name%.bat" (
    %_info% "No 'setupsdir_%profile_name%.bat' in '%script_dir%\custom': no remote setups folder for the font lookup"
    goto:eof
)
call "%script_dir%\custom\setupsdir_%profile_name%.bat"
if not defined setupsdir (
    %_info% "'setupsdir_%profile_name%.bat' left setupsdir empty: no remote setups folder for the font lookup"
    goto:eof
)
%_ok% "Remote setups folder of profile '%profile_name%': '%setupsdir%'"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
