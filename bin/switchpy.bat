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
call "%script_dir%\switchver.bat" pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python
set "switchver_todelete="
%_ok% "[%~nx0] Python version chosen: '%SELECTED_VERSION%'"
set "PYTHON_HOME=%PRGS%\pythons\%SELECTED_VERSION%"
set "PYTHON_VERSION=3%SELECTED_VERSION:*3=%"
popd

endlocal & set "PYTHON_HOME=%PYTHON_HOME%" & set "PYTHON_VERSION=%PYTHON_VERSION%" & set "PATH=%newPath%"

rem echo PYTHON_HOME='%PYTHON_HOME%'
rem echo CLEANED PATH='%PATH%'
set PYTHON_ROOT=%PRGS%\pythons
set "_OLD_VIRTUAL_PATH=%PATH%"

set PYTHON_MAIN_VERSION=
:: Split PYTHON_VERSION by '.' and keep the first two segments
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "PYTHON_MAIN_VERSION=%%a.%%b"
)
echo PYTHON_MAIN_VERSION='%PYTHON_MAIN_VERSION%'
if not "%VIRTUAL_ENV%" == "" (
    echo %VIRTUAL_ENV%>>"%CD%\switchpy_virtual_env.tmp"
    ping -n 1 -w 300 127.0.0.1 > nul
    findstr /c:"python_%PYTHON_VERSION%" "%CD%\switchpy_virtual_env.tmp" >nul
    if errorlevel 1 (
        del "%CD%\switchpy_virtual_env.tmp"
        echo deactivate: different venv activated: '%VIRTUAL_ENV%'
        set "OLD_PYTHON_VERSION=%VIRTUAL_ENV:*python_=%"
        call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
        if errorlevel 1 (
            echo ERROR: Unable to deactivate Py env for 'Python %OLD_PYTHON_VERSION%'
            exit /b 1
        ) else (
            echo OK: Py env for 'Python %OLD_PYTHON_VERSION%' deactivated
        )
    ) else (
        del "%CD%\switchpy_virtual_env.tmp"
        echo OK: Py env for 'Python %PYTHON_VERSION%' already activated
        exit /b 0
    )
)
set "PATH=%PYTHON_ROOT%\python%PYTHON_VERSION%;%PYTHON_ROOT%\python%PYTHON_VERSION%\Scripts;%PATH%"

rem unset any doskey alias for deactivate.bat
doskey deactivate=
rem Propose with gum.exe 3 choices: 1) no venv 2) venv on %PYTHON_ROOT%\venvs 3) venv on %CD%\venvs
set choice=
echo cd='%CD%'
"%PRGS%\gums\current\gum.exe" choose "No venv" "venv on %PYTHON_ROOT%\venvs" "venv on %CD%\venvs"> "%CD%\switchpy.tmp"
ping -n 1 -w 300 127.0.0.1 > nul
for /f "tokens=*" %%a in ('type "%CD%\switchpy.tmp"') do set choice=%%a
echo choice='%choice%'
if "%choice%" == "No venv" (
    echo No virtual environment will be used.
    del "%CD%\switchpy.tmp"
    exit /b 0
) else if "%choice%" == "venv on %PYTHON_ROOT%\venvs" (
    set "VENV_LOCATION=%PYTHON_ROOT%\venvs"
) else if "%choice%" == "venv on %CD%\venvs" (
    set "VENV_LOCATION=%CD%\venvs"
) else (
    echo Invalid choice.
    del "%CD%\switchpy.tmp"
    exit /b 1
)
ping -n 1 -w 300 127.0.0.1 > nul
del "%CD%\switchpy.tmp"

rem TODO use existing code to create or activate venv in the chosen location
rem TODO set doskey alias %VIRTUAL_ENV%\Scripts\deactivate.bat is a venv is chosen

set PYTHON_VENVS="%VENV_LOCATION%"
mkdir "%PYTHON_VENVS%" 2>nul
pushd %PYTHON_VENVS%
if not exist "python_%PYTHON_VERSION%" (
    echo Must create virtual env for 'Python %PYTHON_VERSION%'
    python -m venv python_%PYTHON_VERSION%
    if errorlevel 1 (
        echo ERROR: Unable to create virtual env for 'Python %PYTHON_VERSION%'
        popd
        exit /b 1
    ) else (
        echo OK: 'Python %PYTHON_VERSION%' virtual env created in '%PYTHON_VENVS%\python_%PYTHON_VERSION%'
    )
) else (
    echo OK: Py env for '%PYTHON_VERSION%' already created
)
echo Active venv python_%PYTHON_VERSION%
popd
echo.PATH BEFORE activation: '%PATH%'
call "%PYTHON_VENVS%\python_%PYTHON_VERSION%\Scripts\activate.bat"
if errorlevel 1 (
    echo ERROR: Unable to activate Py env for 'Python %PYTHON_VERSION%'
    exit /b 1
) else (
    echo OK: Py env for 'Python %PYTHON_VERSION%' activated
)
doskey deactivate=call "%VIRTUAL_ENV%\Scripts\deactivate.bat" $*
set PYTHON_ROOT=