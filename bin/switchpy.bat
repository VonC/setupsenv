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

call "%script_dir%\switchver.bat" pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python
echo done
%_ok% "[%~nx0] Python version chosen: '%SELECTED_VERSION%'"
set "PYTHON_HOME=%PRGS%\pythons\%SELECTED_VERSION%"
set "PYTHON_VERSION=3%SELECTED_VERSION:*3=%"

endlocal & set "PYTHON_HOME=%PYTHON_HOME%" & set "PYTHON_VERSION=%PYTHON_VERSION%" & set "PATH=%newPath%"

echo PYTHON_HOME='%PYTHON_HOME%'
echo CLEANED PATH='%PATH%'
set PYTHON_ROOT=%PRGS%\pythons
set "_OLD_VIRTUAL_PATH=%PATH%"

mkdir "%PYTHON_ROOT%\venvs" 2>nul
pushd %PYTHON_ROOT%\venvs
set PYTHON_MAIN_VERSION=
:: Split PYTHON_VERSION by '.' and keep the first two segments
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "PYTHON_MAIN_VERSION=%%a.%%b"
)
echo PYTHON_MAIN_VERSION='%PYTHON_MAIN_VERSION%'
if not "%VIRTUAL_ENV%" == "" (
    if "%VIRTUAL_ENV%" == "%PRGS%\pythons\venvs\python_%PYTHON_VERSION%" (
        echo OK: Py env for 'Python %PYTHON_VERSION%' already activated
        popd
        exit /b 0
    ) else (
        echo deactivate: different venv activated: '%VIRTUAL_ENV%'
        call "%PRGS%\pythons\venvs\python_%PYTHON_VERSION%\Scripts\deactivate.bat"
        if errorlevel 1 (
            echo ERROR: Unable to deactivate Py env for 'Python %PYTHON_VERSION%'
            popd
            exit /b 1
        ) else (
            echo OK: Py env for 'Python %PYTHON_VERSION%' deactivated
        )
    )
)
if not exist "python_%PYTHON_VERSION%" (
    echo Must create py env for 'Python %PYTHON_VERSION%'
    py -%PYTHON_MAIN_VERSION% -m venv python_%PYTHON_VERSION%
    if errorlevel 1 (
        echo ERROR: Unable to create Py env for 'Python %PYTHON_VERSION%'
        popd
        exit /b 1
    ) else (
        echo OK: Py env for 'Python %PYTHON_VERSION%' created
    )
) else (
    echo OK: Py env for '%PYTHON_VERSION%' already created
)
echo Active venv python_%PYTHON_VERSION%
popd
echo.PATH BEFORE activation: '%PATH%'
call "%PRGS%\pythons\venvs\python_%PYTHON_VERSION%\Scripts\activate.bat"
if errorlevel 1 (
    echo ERROR: Unable to activate Py env for 'Python %PYTHON_VERSION%'
    popd
    exit /b 1
) else (
    echo OK: Py env for 'Python %PYTHON_VERSION%' activated
)
popd
set PYTHON_ROOT=