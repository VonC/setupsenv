@echo off
rem https://stackoverflow.com/questions/42582230/how-to-install-visual-studio-code-silently-without-auto-open-when-installation
rem VSCodeSetup-1.10.1.exe /VERYSILENT /MERGETASKS=!runcode
set install_ok=
if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion
set "echos_standalone=%~dp0standalone_%~nx0.flag"

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& goto:eof
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
set "installs_dir=%senv_dir%\installs"
call %senv_dir%\batcolors\echos_macros.bat

if not defined NO_DRY_RUN (
    %_warning% "NO_DRY_RUN is not set. Running in dry-run mode. No changes will be made."
)

if defined fs goto:proceed_python_install

set "python_version=%~1"
if not defined python_version (
    %_fatal% "pythons.install.bat requires a python version argument (e.g. 3.13.9 or python3.13.9)" 21
)
set "python_version=%python_version:python=%"
set "fs=python-%python_version%-amd64.exe"
%_info% "Manual installation of exe python version '%python_version%' as '%fs%'"
if exist "%PRGS%\setup\python-%python_version%-amd64.zip" (
    %_ok% "Zip 'python-%python_version%-amd64.zip' already in '%PRGS%\setup': installer exe not required"
    goto:proceed_python_install
)
if not exist "%PRGS%\setup\%fs%" (
    if not exist "%DWL%\%fs%" (
        %_fatal% "'%fs%' not seen in '%PRGS%\setup' or '%DWL%'" 22
    )
    if defined NO_DRY_RUN (
        call "%senv_dir%\bin\rbc.bat" "%DWL%" "%PRGS%\setup" "%fs%"
    ) else (
        %_info% "DRY-RUN: Would copy '%fs%' from '%DWL%' to '%PRGS%\setup'"
    )
)

:proceed_python_install
if not "%fs:.zip=%"=="%fs%" (
    %_ok% "Zip '%fs%' means no installation required beside regular unzip"
    set "install_ok=false"
    goto:endlocal
)
set "py_version=%fs:python-=%"
set "py_version=%py_version:-amd64.exe=%"
set "py_minor_version=%py_version:~0,4%"
set "target=%PRGS%\pythons\python-%py_version%-amd64"
set "fz=%fs:.exe=.zip%"
set "target_zip=%PRGS%\setup\%fz%"
set "target_symlink=%PRGS%\pythons\python%py_version%"
rem The installer and the uninstaller both derive their sibling _NNN_ logs from
rem the path given to /log. Point that path at a pythons_logs subfolder, so that
rem neither '%PRGS%\pythons' nor '%PRGS%\setup' collects twenty log files a run.
set "pythons_logs=%PRGS%\pythons\pythons_logs"
set "setup_logs=%PRGS%\setup\pythons_logs"
call :_move_stray_python_logs "%PRGS%\pythons" "%pythons_logs%"
call :_move_stray_python_logs "%PRGS%\setup" "%setup_logs%"

%_task% "Must install Python %py_version% from '%fs%'"

call :_get_registered_python_version %py_minor_version%
call :_get_target_install_state

if exist "%target_zip%" (
    call :_handle_zip_present
) else (
    call :_handle_zip_absent
)

call :_create_python_symlink

set "install_ok=true"
goto:endlocal

:: =============================================================================
:: Subroutines
:: =============================================================================

:_get_registered_python_version
set "registered_version="
for /f "tokens=3" %%v in ('reg query "HKEY_CURRENT_USER\Software\Python\PythonCore\%~1" /v Version 2^>nul ^| C:\Windows\System32\find.exe "Version"') do (
    set "registered_version=%%v"
)
if defined registered_version (
    %_info% "Found registered Python %~1 version: '%registered_version%'"
) else (
    %_info% "No Python %~1 version registered in HKCU"
)
goto:eof

:_get_target_install_state
set "target_installed="
set "target_version_correct="
if not exist "%target%\Lib\site-packages\pip\_vendor\distlib\w64-arm.exe" (
    %_info% "Python not installed in target '%target%'"
    goto:eof
)
set "target_installed=true"
for /f "tokens=5" %%v in ('C:\Windows\System32\find.exe "What''s New in Python" "%target%\NEWS.txt"') do (
    if "%%v"=="%py_version%" (
        set "target_version_correct=true"
        %_ok% "Python %py_version% is correctly installed in '%target%'"
    ) else (
        %_warning% "Wrong Python version in '%target%'. Expected '%py_version%', found '%%v'"
    )
    goto:eof
)
goto:eof

:_handle_zip_present
%_info% "Zip file '%target_zip%' exists. Proceeding with zip-based installation."
if defined registered_version (
    call :_uninstall_python %registered_version%
)
if not defined target_version_correct (
    call :_unzip_to_target
)
goto:eof

:_handle_zip_absent
%_info% "Zip file '%target_zip%' not found. Will build it."
if not exist "%PRGS%\setup\%fs%" (
    %_fatal% "Installer '%fs%' not found in '%PRGS%\setup', cannot build zip." 23
)
if defined registered_version (
    if "%registered_version%"=="%py_version%" (
        if not defined target_version_correct (
            call :_uninstall_python %registered_version%
            call :_install_from_exe
        )
    ) else (
        call :_uninstall_python %registered_version%
        call :_install_from_exe
    )
) else (
    call :_install_from_exe
)
call :_create_python_zip
call :_uninstall_python %py_version%
call :_unzip_to_target
goto:eof

:_install_from_exe
%_task% "Installing Python %py_version% from exe to '%target%'"
if defined NO_DRY_RUN (
    if exist "%target%" rd /s /q "%target%"
    if not exist "%pythons_logs%" mkdir "%pythons_logs%"
    "%PRGS%\setup\%fs%" /passive /quiet /log "%pythons_logs%\python-%py_version%-amd64.log" InstallAllUsers=0 TargetDir="%target%" DefaultJustForMeTargetDir="%target%" Shortcuts=0 Include_launcher=1 CompileAll=1 Include_debug=1 Include_symbols=1
    if errorlevel 1 ( %_fatal% "Issue when installing Python from exe" 1 )
) else (
    %_info% "DRY-RUN: Would delete folder '%target%'"
    %_info% "DRY-RUN: Would run installer '%PRGS%\setup\%fs%'"
)
%_ok% "Python installed from exe."
goto:eof

:_uninstall_python
set "version_to_uninstall=%~1"
%_task% "Uninstalling registered Python version '%version_to_uninstall%'"
set "uninstall_exe=%PRGS%\setup\python-%version_to_uninstall%-amd64.exe"
if not exist "%uninstall_exe%" (
    %_fatal% "Cannot find installer '%uninstall_exe%' to uninstall version '%version_to_uninstall%'" 24
)
if defined NO_DRY_RUN (
    if not exist "%setup_logs%" mkdir "%setup_logs%"
    "%uninstall_exe%" /uninstall /quiet /log "%setup_logs%\python-%version_to_uninstall%-uninstall.log"
    if errorlevel 1 ( %_fatal% "Issue when uninstalling Python '%version_to_uninstall%'" 4 )
    set "registered_version="
) else (
    %_info% "DRY-RUN: Would run uninstaller '%uninstall_exe%'"
)
%_ok% "Python '%version_to_uninstall%' uninstalled."
goto:eof

:_create_python_zip
%_task% "Must compress '%target%' to '%target_zip%'"
if exist "%target_zip%" (
    %_ok% "Zip '%target_zip%' already created"
    goto:eof
)
if defined NO_DRY_RUN (
    %sz% a -tzip -mm=Deflate -mmt=on -mx5 -w "%target_zip%" "%target%"
    if errorlevel 1 ( %_fatal% "Issue when compressing Python '%py_version%'" 2 )
) else (
    %_info% "DRY-RUN: Would compress '%target%' to '%target_zip%'"
)
%_ok% "Zip file created."
goto:eof

:_unzip_to_target
%_task% "Unzipping '%target_zip%' to '%target%'"
if defined NO_DRY_RUN (
    if exist "%target%" rd /s /q "%target%"
    %sz% x -o"%PRGS%\pythons" "%target_zip%"
    if errorlevel 1 ( %_fatal% "Issue when unzipping '%target_zip%'" 5 )
) else (
    %_info% "DRY-RUN: Would delete folder '%target%'"
    %_info% "DRY-RUN: Would unzip '%target_zip%' to '%PRGS%\pythons'"
)
%_ok% "Unzipped to target."
goto:eof

:_move_stray_python_logs
rem Move the Python logs left directly in '%~1' by earlier runs into '%~2'. Only
rem leftovers are seen here: since the /log paths moved, the installer writes its
rem logs straight into that subfolder.
set "logs_from=%~1"
set "logs_to=%~2"
set "logs_count=0"
for %%l in ("%logs_from%\python-*.log") do ( set /a "logs_count+=1" )
if "%logs_count%"=="0" ( goto:eof )
%_task% "Must move %logs_count% stray Python log(s) from '%logs_from%' to '%logs_to%'"
if not defined NO_DRY_RUN (
    %_info% "DRY-RUN: Would move '%logs_from%\python-*.log' to '%logs_to%'"
    goto:eof
)
if not exist "%logs_to%" (
    mkdir "%logs_to%"
    if errorlevel 1 (
        %_warning% "Unable to create Python log folder '%logs_to%'"
        goto:eof
    )
)
move /y "%logs_from%\python-*.log" "%logs_to%" >nul
if errorlevel 1 (
    %_warning% "Unable to move Python logs from '%logs_from%' to '%logs_to%'"
    goto:eof
)
%_ok% "%logs_count% Python log(s) moved to '%logs_to%'"
goto:eof

:_create_python_symlink
%_task% "Must create symlink '%target_symlink%'"
if exist "%target_symlink%" (
    %_ok% "Symlink '%target_symlink%' already exists"
    goto:eof
)
if defined NO_DRY_RUN (
    mklink /J "%target_symlink%" "%target%"
    if errorlevel 1 ( %_fatal% "Issue when symlinking Python '%py_version%'" 3 )
) else (
    %_info% "DRY-RUN: Would create symlink from '%target_symlink%' to '%target%'"
)
%_ok% "Symlink created."
goto:eof

:endlocal
endlocal & set "install_ok=%install_ok%"
if exist "%~dp0standalone_%~nx0.flag" (
    echo install_ok='%install_ok%'
        set "install_ok="
    del "%~dp0standalone_%~nx0.flag"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
