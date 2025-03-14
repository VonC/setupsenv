@echo off
set "PYTHON_HOME="
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

:: Find Python 3.x.y folders
set "PYTHON_ROOT=%PRGS%\pythons"
pushd %PYTHON_ROOT%

set "switchver_todelete=python"
call "%script_dir%\switchver.bat" pythons python "python[2-9]\.[0-9]*\.[0-9]*$" python "%~1"
set "switchver_todelete="
%_ok% "Python version chosen: '%SELECTED_VERSION%'"
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
set "PYTHON_ROOT=%PRGS%\pythons"
set "_OLD_VIRTUAL_PATH=%PATH%"

set "PYTHON_MAIN_VERSION="
:: Split PYTHON_VERSION by '.' and keep the first two segments
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "PYTHON_MAIN_VERSION=%%a.%%b"
)
set "ccd=%CD%"
for %%j in ("%cd%") do ( set "project_name=%%~nxj" )
%_info% "PYTHON_MAIN_VERSION='%PYTHON_MAIN_VERSION%'"
if defined VIRTUAL_ENV (
    if not exist "%VIRTUAL_ENV%" (
        %_task% "Must deactivate non-existing path VIRTUAL_ENV='%VIRTUAL_ENV%'"
        if defined _OLD_VIRTUAL_PROMPT (
            set "PROMPT=%_OLD_VIRTUAL_PROMPT%"
        )
        if defined _OLD_VIRTUAL_PATH (
            set "PATH=%_OLD_VIRTUAL_PATH%"
        )
        set "_OLD_VIRTUAL_PATH="
        set "_OLD_VIRTUAL_PROMPT="
        set "VIRTUAL_ENV="
        set "VIRTUAL_ENV_PROMPT="
        %_ok% "Non-existent VIRTUAL_ENV deactivated"
        goto:activate
    )

    rem echo %VIRTUAL_ENV%>>"%ccd%\switchpy_virtual_env.tmp"
    rem ping -n 1 -w 300 127.0.0.1 > nul
    rem findstr /c:"python_%PYTHON_VERSION%_%project_name%" "%ccd%\switchpy_virtual_env.tmp" >nul
    if not "%VIRTUAL_ENV%"=="%ccd%\venvs\python_%PYTHON_VERSION%_%project_name%" (
        %_task% "Must deactivate: different venv activated: '%VIRTUAL_ENV%'"
        set "OLD_PYTHON_VERSION=%VIRTUAL_ENV:*python_=%"
        call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
        if errorlevel 1 (
            %_error% "Unable to deactivate Py env for 'Python %OLD_PYTHON_VERSION%'"
            call :unset
            exit /b 1
        ) else (
            %_ok% "Py env for 'Python %OLD_PYTHON_VERSION%' deactivated"
        )
    ) else (
        del "%ccd%\switchpy_virtual_env.tmp"
        %_ok% "Py env for 'Python %PYTHON_VERSION%' already activated"
        where python.exe >NUL 2>NUL
        if errorlevel 1 (
            %_warning% "VIRTUAL_ENV set, but not added to the PATH: re-activating."
            %_task% "Must re-activating VIRTUAL_ENV='%VIRTUAL_ENV%'."
            rem call sed -i "s,VIRTUAL_ENV=.*$,VIRTUAL_ENV=%VIRTUAL_ENV%,g" "%VIRTUAL_ENV%\Scripts\activate.bat"
            call sed -i "s,VIRTUAL_ENV=.*$,VIRTUAL_ENV=%VIRTUAL_ENV:\=\\\\%,g" "%VIRTUAL_ENV%\Scripts\activate.bat"
            call "%VIRTUAL_ENV%\Scripts\activate.bat"
            if errorlevel 1 (
                %_error% "Unable to re-activate Py env '%venv_name%' for 'Python %PYTHON_VERSION%'"
                call :unset
                exit /b 1
            ) else (
                %_ok% "Py env '%venv_name%' for 'Python %PYTHON_VERSION%' re-activated"
            )
        ) else (
            %_ok% "PATH for 'Python %PYTHON_VERSION%' already set"
        )
        call :unset
        goto:eof
    )
)
:activate
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
    set "choice=%~2"
)
if "%choice%"=="no" ( set "choice=No venv")
if "%choice%"=="global" ( set "choice=venv on %PYTHON_ROOT%\venvs")
if "%choice%"=="local" ( set "choice=venv on %ccd%\venvs")
if not defined choice (
    "%PRGS%\gums\current\gum.exe" choose "No venv" "venv on %PYTHON_ROOT%\venvs" "venv on %ccd%\venvs"> "%ccd%\switchpy.tmp"
    ping -n 1 -w 300 127.0.0.1 > nul
    for /f "tokens=*" %%a in ('type "%ccd%\switchpy.tmp"') do set "choice=%%a"
)
rem echo choice='%choice%'
set "venv_name=python_%PYTHON_VERSION%"
rem if venv, then do not set PATH: activate will do it.
if "%choice%" == "No venv" (
    %_ok% "No virtual environment will be used."
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
    %_error% "Invalid choice."
    del "%ccd%\switchpy.tmp" 2>nul
    call :unset
    exit /b 1
)
ping -n 1 -w 300 127.0.0.1 > nul
del "%ccd%\switchpy.tmp" 2>nul

rem use existing code to create or activate venv in the chosen location
set "PYTHON_VENVS=%VENV_LOCATION%"
mkdir "%PYTHON_VENVS%" 2>nul
pushd %PYTHON_VENVS%
if not exist "%venv_name%" (
    %_task% "Must create virtual env '%venv_name%' for 'Python %PYTHON_VERSION%'"
    "%PYTHON_ROOT%\python%PYTHON_VERSION%\python.exe" -m venv %venv_name%
    if errorlevel 1 (
        %_error% "Unable to create virtual env for 'Python %PYTHON_VERSION%' using '%PYTHON_ROOT%\python%PYTHON_VERSION%\python.exe'"
        popd
        call :unset
        exit /b 1
    ) else (
        %_ok% "'Python %PYTHON_VERSION%' virtual env created in '%PYTHON_VENVS%\%venv_name%'"
    )
) else (
    %_ok% "Py env for '%PYTHON_VERSION%' already created"
)
%_info% "Active venv '%venv_name%'"
popd
%_info% "PATH BEFORE activation: '%PATH%'"
echo sed -i "s,VIRTUAL_ENV=.*$,VIRTUAL_ENV=%PYTHON_VENVS%\%venv_name%,g" "%PYTHON_VENVS%\%venv_name%\Scripts\activate.bat"
rem @echo on
rem call bash -c "sed -i "s,VIRTUAL_ENV=.*$,VIRTUAL_ENV=%PYTHON_VENVS:\=\\\\\\\\%\\\\\\\\%venv_name%,g" '%PYTHON_VENVS%\%venv_name%\Scripts\activate.bat'"
call sed -i "s,VIRTUAL_ENV=.*$,VIRTUAL_ENV=%PYTHON_VENVS:\=\\\\%\\\\%venv_name%,g" "%PYTHON_VENVS%\%venv_name%\Scripts\activate.bat"
rem grep "VIRTUAL_ENV=" "%PYTHON_VENVS%\%venv_name%\Scripts\activate.bat"
rem %_fatal% "stop" 1
call "%PYTHON_VENVS%\%venv_name%\Scripts\activate.bat"
if errorlevel 1 (
    %_error% "Unable to activate Py env '%venv_name%' for 'Python %PYTHON_VERSION%'"
    call :unset
    exit /b 1
) else (
    %_ok% "Py env '%venv_name%' for 'Python %PYTHON_VERSION%' activated"
)
rem set doskey alias %VIRTUAL_ENV%\Scripts\deactivate.bat is a venv is chosen
doskey deactivate=call "%VIRTUAL_ENV%\Scripts\deactivate.bat" $*
set "PYTHON_ROOT="
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
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
