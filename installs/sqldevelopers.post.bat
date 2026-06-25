@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"

%_info% "~~~~~~~~~~~~ SQL Developer post installation ~~~~~~~~~~~~"

if not defined PRGS (
    %_fatal% "PRGS is not defined" 70
)
if not defined prgs_folder (
    set "prgs_folder=sqldevelopers"
)

if defined prg_folder (
    set "sqldeveloper_dir=%PRGS%\%prgs_folder%\%prg_folder%"
    if exist "!sqldeveloper_dir!" goto:sqldeveloper_dir_found
)

for /f "delims=" %%d in ('dir /ad /b /o-d "%PRGS%\%prgs_folder%\sqldeveloper-*-x64" 2^>nul') do (
    set "prg_folder=%%d"
    set "sqldeveloper_dir=%PRGS%\%prgs_folder%\%%d"
    goto:sqldeveloper_dir_found
)

%_fatal% "Unable to find versioned SQL Developer installation directory in '%PRGS%\%prgs_folder%'" 71

:sqldeveloper_dir_found
set "sqldeveloper_version=%prg_folder:sqldeveloper-=%"
set "sqldeveloper_version=%sqldeveloper_version:-x64=%"
if "%sqldeveloper_version%"=="%prg_folder%" (
    %_fatal% "Unable to derive SQL Developer version from install folder '%prg_folder%'" 72
)
if "%sqldeveloper_version%"=="latest" (
    %_fatal% "SQL Developer install folder must be versioned, not '%prg_folder%'" 73
)
echo.%sqldeveloper_version%| findstr /R /C:"^[0-9]" >nul
if errorlevel 1 (
    %_fatal% "SQL Developer install folder '%prg_folder%' does not expose a numeric Oracle version" 74
)

set "sqldeveloper_exe=%sqldeveloper_dir%\sqldeveloper.exe"
if exist "%sqldeveloper_exe%" goto:sqldeveloper_exe_found

set "sqldeveloper_exe=%sqldeveloper_dir%\sqldeveloper\sqldeveloper.exe"
if exist "%sqldeveloper_exe%" goto:sqldeveloper_exe_found

%_fatal% "Unable to find sqldeveloper.exe under '%sqldeveloper_dir%'" 75

:sqldeveloper_exe_found
%_ok% "SQL Developer version '%sqldeveloper_version%' installed from versioned archive folder '%prg_folder%'"
%_ok% "SQL Developer executable found at '%sqldeveloper_exe%'"

endlocal
if defined standalone_%~nx0 (
    call "%~dp0..\batcolors\echos_macros.bat" unset
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
