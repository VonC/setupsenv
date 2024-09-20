@echo off
set "PYTHON_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
call %script_dir%\echos_macros.bat

:: Find Python 3.x.y folders
set PYTHON_ROOT=%PRGS%\pythons
pushd %PYTHON_ROOT%

set PYTHON_VERSIONS=
for /d %%f in (python3.*) do (
    set PYTHON_VERSIONS=!PYTHON_VERSIONS! "%%f"
)
popd

:: Use gum for selection
set "gum=%PRGS%\gums\current\gum.exe"
for /f "tokens=*" %%a in ('%gum% choose %PYTHON_VERSIONS%') do set SELECTED_VERSION=%%a

%_ok% "Python version chosen: '%SELECTED_VERSION%'"

:clean_path
rem set "SELECTED_VERSION=python3.7.5"
set "PYTHON_HOME=%PRGS%\pythons\%SELECTED_VERSION%"
set "current_path="
echo PATH='%PATH%'
rem for /f "tokens=*" %%a in ('set PATH ^| sed "s,%PRGS%\pythons,,g"') do ( set "newPath=%%a" )
:: Split the PATH variable at semicolons and echo each part
set newPath=
for %%a in ("%PATH:;=" "%") do (
    set "current_path=%%~a"
    echo !current_path!| findstr /C:"%PRGS%\python" >nul
    if not !errorlevel! equ 0 (
        if "!newPath!" == "" (
            set "newPath=!current_path!"
        ) else (
            set "newPath=!newPath!;!current_path!"
        )
    )
)
rem echo newPath='%newPath%'
set "newPath=%PYTHON_HOME%;%PYTHON_HOME%\Scripts;%newPath%"
set "current_path="
endlocal & set "PYTHON_HOME=%PRGS%\pythons\%SELECTED_VERSION%" & set "PATH=%newPath%" & set "PYTHON_VERSION=3%SELECTED_VERSION:*3=%"
echo PYTHON_HOME='%PYTHON_HOME%'
echo PATH='%PATH%'
set PYTHON_ROOT=%PRGS%\pythons
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