@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"

%_info% "~~~~~~~~~~~~ Codex post installation ~~~~~~~~~~~~"

if not defined PRGS (
    %_fatal% "PRGS is not defined" 70
)
if not defined prgs_folder (
    set "prgs_folder=codexs"
)

if defined prg_folder (
    set "codex_dir=%PRGS%\%prgs_folder%\%prg_folder%"
    if exist "!codex_dir!" goto:codex_dir_found
)

for /f "delims=" %%d in ('dir /ad /b /o-d "%PRGS%\%prgs_folder%\codex-rust-v*-x86_64-pc-windows-msvc*" 2^>nul') do (
    set "prg_folder=%%d"
    set "codex_dir=%PRGS%\%prgs_folder%\%%d"
    goto:codex_dir_found
)

%_fatal% "Unable to find Codex installation directory in '%PRGS%\%prgs_folder%'" 71

:codex_dir_found
%_task% "Must check Codex executable rename in '%codex_dir%'"

if exist "%codex_dir%\codex.exe" (
    %_ok% "codex.exe already exists in '%codex_dir%'"
    goto:endlocal
)

set "source_exe=%codex_dir%\codex-x86_64-pc-windows-msvc.exe"
if not exist "%source_exe%" (
    %_fatal% "Unable to find '%source_exe%' to create codex.exe" 72
)

copy "%source_exe%" "%codex_dir%\codex.exe" >nul
if errorlevel 1 (
    %_fatal% "Unable to copy '%source_exe%' to '%codex_dir%\codex.exe'" 73
)
%_ok% "codex.exe created in '%codex_dir%'"

:endlocal
endlocal
if defined standalone_%~nx0 (
    call "%PRGS%\senv\batcolors\echos_macros.bat" unset
    set "standalone_%~nx0="
    set "setup_dir="
    set "senv_dir="
    set "prgname="
    set "batdir="
)
set "standalone_%~nx0="
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
