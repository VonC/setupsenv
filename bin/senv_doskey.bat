@echo off
rem senv_doskey.bat: load the doskey aliases kept beside this file, in %HOME%\bin:
rem senv.doskey (global), senv.custom.doskey (team), senv.local.doskey (personal),
rem then senv.custom.<profile>.doskey when the profile file there names one.
rem
rem Doskey macros belong to one console: a new console inherits the variables of
rem the one that opened it, never its macros. A console where only a project
rem senv.bat ran, such as a tuitp pane or 'senv' typed in a project folder, had
rem none of these aliases ('ll' among them) although its PATH worked. senv.bat
rem calls this file, and so does the %USERPROFILE%\senv.bat launcher: alone for
rem 'senv aliases', and before a project senv.bat, so the project's own aliases,
rem loaded after, still win.
rem
rem DOSKEY /MACROFILE adds and replaces macros, never deletes one. Each file adds
rem its "time=step" mark to senv_t_m, but only inside a timed senv.bat run: the
rem variable is cleared once senv.bat ends. A missing file is reported, not fatal.
set "senv_doskey_profile="
if exist "%~dp0profile" (
   for /f "usebackq delims=" %%x in ("%~dp0profile") do set "senv_doskey_profile=%%x"
)
DOSKEY /MACROFILE="%~dp0senv.doskey"
if errorlevel 1 call:warn "Issue setting global (all) aliases from '%~dp0senv.doskey'"
if defined senv_t_m set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.doskey"
DOSKEY /MACROFILE="%~dp0senv.custom.doskey"
if errorlevel 1 call:warn "Issue setting custom (team) aliases from '%~dp0senv.custom.doskey'"
if defined senv_t_m set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.custom.doskey"
DOSKEY /MACROFILE="%~dp0senv.local.doskey"
if errorlevel 1 call:warn "Issue setting local (personal) aliases from '%~dp0senv.local.doskey'"
if defined senv_t_m set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.local.doskey"
if defined senv_doskey_profile if exist "%~dp0senv.custom.%senv_doskey_profile%.doskey" (
   DOSKEY /MACROFILE="%~dp0senv.custom.%senv_doskey_profile%.doskey"
   if errorlevel 1 call:warn "Issue setting custom (profile) aliases from '%~dp0senv.custom.%senv_doskey_profile%.doskey'"
)
if defined senv_t_m set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.custom.profile.doskey"
set "senv_doskey_profile="
exit /b 0

:warn
rem The batcolors macros exist inside senv.bat only; the launcher calls this file
rem without them.
if defined _warning %_warning% %1
if not defined _warning echo WARNING: %~1
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
