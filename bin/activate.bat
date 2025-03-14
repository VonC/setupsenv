@echo off
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

:: Find Python 3.x.y folders
set PYTHON_ROOT=%PRGS%\pythons

set "ccd=%CD%"
for %%j in ("%cd%") do ( set "project_name=%%~nxj" )
set "project_name=%project_name: =_%"

if not exist venvs (
    call:fatal "[%~nx0] execute activate where venvs\xxx has been created by switchpy.bat" 1
)
set "venv_name="
if defined VIRTUAL_ENV (
    for %%j in ("%VIRTUAL_ENV%") do ( set "venv_name=%%~nxj" )
)
if defined venv_name (
    %_info% "Current venv activated: '%venv_name%'"
    if exist "venvs\%venv_name%" (
        %_ok% "Venv '%venv_name%' already! activated for project '%project_name%'"
        where python.exe 1>nul 2>nul
        if errorlevel 1 (
            %_warning% "VIRTUAL_ENV set, but not added to the PATH: re-activating."
            goto:activate
        )
        goto:eof
    )
    %_task% "Must deactivate old current venv '%venv_name%' before activating the one from '%project_name%'"
    call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
    if errorlevel 1 (
        call:fatal "[%~nx0] Unable to deactivate old current venv '%venv_name%' while in project '%project_name%'" 2
    )
    %_ok% "Old current venv '%venv_name%' deactivated"
)

:activate
set "VIRTUAL_ENV="
set "VIRTUAL_ENV_PROMPT="

:: List and count python_* folders
for /f "tokens=*" %%i in ('dir /b /ad "venvs\python_*" 2^>nul') do (
    set /a folder_count+=1
    set "last_folder=%%i"
)

if %folder_count% == 0 (
    call:fatal "[%~nx0] No venv found in 'venvs' folder for project '%project_name%'" 3
)

if not %folder_count% == 1 (
    call:fatal "[%~nx0] More than one venv found in 'venvs' folder for project '%project_name%'" 4
)

%_ok% "Venv detected '%last_folder%'"

%_task% "Must activate venv '%last_folder%'"
call venvs\%last_folder%\Scripts\activate.bat
if errorlevel 1 (
    call:fatal "Unable to activate venv '%last_folder%' for project '%project_name%'" 5
)
%_ok% "Venv '%last_folder%' activated for project '%project_name%'"
doskey deactivate=%ccd%\venvs\%last_folder%\Scripts\deactivate.bat

call:unset
goto:eof

:fatal
set "msg=%~1"
set "error=%~2"
call:unset
call "%HOME%\batcolors\echos.bat" :fatal "%msg%" %error%
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof

:unset
set "ccd="
set "project_name="
set "PYTHON_ROOT="
set "folder_count="
call %senv_dir%\batcolors\echos_macros.bat unset
set "senv_dir="
set "script_dir="
set "last_folder="
set "error="
set "batdir="
set "__fatal="