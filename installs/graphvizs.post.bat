@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"

%_info% "~~~~~~~~~~~~ Graphviz post installation ~~~~~~~~~~~~"

if not defined PRGS (
    %_fatal% "PRGS is not defined" 70
)
if not defined prgs_folder (
    set "prgs_folder=graphvizs"
)

if defined prg_folder (
    set "graphviz_dir=%PRGS%\%prgs_folder%\%prg_folder%"
    if exist "!graphviz_dir!" goto:graphviz_dir_found
)

for /f "delims=" %%d in ('dir /ad /b /o-d "%PRGS%\%prgs_folder%\graphviz-*-win64" 2^>nul') do (
    set "prg_folder=%%d"
    set "graphviz_dir=%PRGS%\%prgs_folder%\%%d"
    goto:graphviz_dir_found
)

%_fatal% "Unable to find versioned Graphviz installation directory in '%PRGS%\%prgs_folder%'" 71

:graphviz_dir_found
set "dot_exe="
set "neato_exe="

if exist "%graphviz_dir%\bin\dot.exe" (
    set "dot_exe=%graphviz_dir%\bin\dot.exe"
)
if exist "%graphviz_dir%\bin\neato.exe" (
    set "neato_exe=%graphviz_dir%\bin\neato.exe"
)

if defined dot_exe goto:dot_found
for /f "delims=" %%f in ('dir /b /s "%graphviz_dir%\dot.exe" 2^>nul') do (
    set "dot_exe=%%f"
    goto:dot_found
)

:dot_found
if not defined dot_exe (
    %_fatal% "Unable to find dot.exe under '%graphviz_dir%'" 72
)

if defined neato_exe goto:neato_found
for /f "delims=" %%f in ('dir /b /s "%graphviz_dir%\neato.exe" 2^>nul') do (
    set "neato_exe=%%f"
    goto:neato_found
)

:neato_found
if not defined neato_exe (
    %_fatal% "Unable to find neato.exe under '%graphviz_dir%'" 73
)

%_task% "Must create Graphviz plugin configuration with '%dot_exe% -c'"
"%dot_exe%" -c
if errorlevel 1 (
    %_fatal% "Unable to create Graphviz plugin configuration with '%dot_exe% -c'" 74
)

%_ok% "Graphviz plugin configuration created with '%dot_exe% -c'"
%_ok% "Graphviz neato executable found at '%neato_exe%'"

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
