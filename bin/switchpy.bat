@echo off
set "PYTHON_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

:: Find Python 3.x.y folders
set PYTHON_ROOT=%PRGS%\pythons
pushd %PYTHON_ROOT%

set "switchver_todelete=python"
call "%script_dir%\switchver.bat" pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python "%~1"
set "switchver_todelete="
%_ok% "[%~nx0] Python version chosen: '%SELECTED_VERSION%'"
set "PYTHON_HOME=%PRGS%\pythons\%SELECTED_VERSION%"
set "PYTHON_VERSION=3%SELECTED_VERSION:*3=%"
popd

endlocal & set "PYTHON_HOME=%PYTHON_HOME%" & set "PYTHON_VERSION=%PYTHON_VERSION%" & set "PATH=%newPath%"

rem experiment with calling batcolors export and unset
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat export

rem echo PYTHON_HOME='%PYTHON_HOME%'
rem echo CLEANED PATH='%PATH%'
set PYTHON_ROOT=%PRGS%\pythons
set "_OLD_VIRTUAL_PATH=%PATH%"

set PYTHON_MAIN_VERSION=
:: Split PYTHON_VERSION by '.' and keep the first two segments
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "PYTHON_MAIN_VERSION=%%a.%%b"
)
set "ccd=%CD%"
for %%j in ("%cd%") do ( set "project_name=%%~nxj" )
%_info% "[%~nx0] PYTHON_MAIN_VERSION='%PYTHON_MAIN_VERSION%'"
if not "%VIRTUAL_ENV%" == "" (
    echo %VIRTUAL_ENV%>>"%ccd%\switchpy_virtual_env.tmp"
    ping -n 1 -w 300 127.0.0.1 > nul
    findstr /c:"python_%PYTHON_VERSION%_%project_name%" "%ccd%\switchpy_virtual_env.tmp" >nul
    if errorlevel 1 (
        del "%ccd%\switchpy_virtual_env.tmp"
        %_task% "[%~nx0] Must deactivate: different venv activated: '%VIRTUAL_ENV%'"
        set "OLD_PYTHON_VERSION=%VIRTUAL_ENV:*python_=%"
        call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
        if errorlevel 1 (
            %_error% "[%~nx0] Unable to deactivate Py env for 'Python %OLD_PYTHON_VERSION%'"
            call :unset
            exit /b 1
        ) else (
            %_ok% "[%~nx0] Py env for 'Python %OLD_PYTHON_VERSION%' deactivated"
        )
    ) else (
        del "%ccd%\switchpy_virtual_env.tmp"
        %_ok% "[%~nx0] Py env for 'Python %PYTHON_VERSION%' already activated"
        call :unset
        goto:eof
    )
)

rem unset any doskey alias for deactivate.bat
doskey deactivate=
rem Propose with gum.exe 3 choices: 1) no venv 2) venv on %PYTHON_ROOT%\venvs 3) venv on %CD%\venvs

set "project_name=%project_name: =_%"
if defined SWITCHPY_CHOICE (
    set "choice=%SWITCHPY_CHOICE%"
) else (
    set "choice="
)
if not defined choice (
    "%PRGS%\gums\current\gum.exe" choose "No venv" "venv on %PYTHON_ROOT%\venvs" "venv on %ccd%\venvs"> "%ccd%\switchpy.tmp"
    ping -n 1 -w 300 127.0.0.1 > nul
    for /f "tokens=*" %%a in ('type "%ccd%\switchpy.tmp"') do set choice=%%a
)
rem echo choice='%choice%'
set "venv_name=python_%PYTHON_VERSION%"
rem if venv, then do not set PATH: activate will do it.
if "%choice%" == "No venv" (
    %_ok% "[%~nx0] No virtual environment will be used."
    del "%ccd%\switchpy.tmp" 2>nul
    set "PATH=%PYTHON_ROOT%\python%PYTHON_VERSION%;%PYTHON_ROOT%\python%PYTHON_VERSION%\Scripts;%PATH%"
    call :unset
    goto:eof
) else if "%choice%" == "venv on %PYTHON_ROOT%\venvs" (
    set "VENV_LOCATION=%PYTHON_ROOT%\venvs"
) else if "%choice%" == "venv on %ccd%\venvs" (
    set "VENV_LOCATION=%ccd%\venvs"
    set "venv_name=python_%PYTHON_VERSION%_%project_name%"
) else (
    %_error% "[%~nx0] Invalid choice."
    del "%ccd%\switchpy.tmp" 2>nul
    call :unset
    exit /b 1
)
ping -n 1 -w 300 127.0.0.1 > nul
del "%ccd%\switchpy.tmp" 2>nul

rem use existing code to create or activate venv in the chosen location
set PYTHON_VENVS="%VENV_LOCATION%"
mkdir "%PYTHON_VENVS%" 2>nul
pushd %PYTHON_VENVS%
if not exist "%venv_name%" (
    %_task% "[%~nx0] Must create virtual env '%venv_name%' for 'Python %PYTHON_VERSION%'"
    "%PYTHON_ROOT%\python%PYTHON_VERSION%\python.exe" -m venv %venv_name%
    if errorlevel 1 (
        %_error% "[%~nx0] Unable to create virtual env for 'Python %PYTHON_VERSION%'"
        popd
        call :unset
        exit /b 1
    ) else (
        %_ok% "[%~nx0] 'Python %PYTHON_VERSION%' virtual env created in '%PYTHON_VENVS%\%venv_name%'"
    )
) else (
    %_ok% "[%~nx0] Py env for '%PYTHON_VERSION%' already created"
)
%_info% "[%~nx0] Active venv '%venv_name%'"
popd
%_info% "[%~nx0] PATH BEFORE activation: '%PATH%'"
call "%PYTHON_VENVS%\%venv_name%\Scripts\activate.bat"
if errorlevel 1 (
    %_error% "[%~nx0] Unable to activate Py env '%venv_name%' for 'Python %PYTHON_VERSION%'"
    call :unset
    exit /b 1
) else (
    %_ok% "[%~nx0] Py env '%venv_name%' for 'Python %PYTHON_VERSION%' activated"
)
rem set doskey alias %VIRTUAL_ENV%\Scripts\deactivate.bat is a venv is chosen
doskey deactivate=call "%VIRTUAL_ENV%\Scripts\deactivate.bat" $*
set PYTHON_ROOT=
call :unset

goto:eof

:unset
call "%senv_dir%\batcolors\echos_macros.bat" unset
rem cleanup any variable PY...
set "senv_dir="
set "script_dir="
set "PYTHON_HOME="
set "PYTHON_VERSION="
set "PYTHON_ROOT="
set "PYTHON_MAIN_VERSION="
rem set "VIRTUAL_ENV="
set "OLD_PYTHON_VERSION="
set "PYTHON_VENVS="
set "VENV_LOCATION="
set "choice="
set "_OLD_VIRTUAL_PATH="
set "newPath="
set "switchver_todelete="
