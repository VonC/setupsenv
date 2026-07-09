@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
%_info% "~~~~~~~~~~~~ Tailwind CSS post installation prg_folder='%prg_folder%' ~~~~~~~~~~~~"
rem cSpell:disable-next-line
set | grep -i tailw

if not exist "%PRGS%\setup\%fname%" (
    %_fatal% "File '%fname%' does not exist in '%PRGS%\setup'" 70
)

if not exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_task% "Must create Directory '%PRGS%\%prgs_folder%\%prg_folder%'"
    mkdir "%PRGS%\%prgs_folder%\%prg_folder%"
    if errorlevel 1 (
        %_fatal% "Unable to create Directory '%PRGS%\%prgs_folder%\%prg_folder%'" 71
    )
    %_ok% "Directory '%PRGS%\%prgs_folder%\%prg_folder%' created successfully"
) else (
    %_ok% "Directory '%PRGS%\%prgs_folder%\%prg_folder%' already exists"
)

call:copy_fname
call:copy_fname tailwindcss-windows-x64.exe
call:copy_fname tailwindcss.exe

set "local_aliases=%HOME%\bin\senv.local.doskey"

%_task% "Checking if Tailwind CSS alias already exists in %local_aliases%"
if not exist "%local_aliases%" (
    %_warning% "Local aliases file not found, creating it"
    type nul > "%local_aliases%"
)

awk -f "%script_dir%\installs\tailwindcsss.install.awk" "%local_aliases%" > "%local_aliases%.tmp"
set "awk_exit_code=%errorlevel%"

if "%awk_exit_code%"=="2" (
    %_ok% "Tailwind CSS alias already exists in %local_aliases%"
    del "%local_aliases%.tmp"
) else if "%awk_exit_code%"=="1" (
    %_fatal% "Could not find a suitable position to add Tailwind CSS alias in %local_aliases%" 73
    del "%local_aliases%.tmp"
) else (
    move /y "%local_aliases%.tmp" "%local_aliases%" > nul
    %_ok% "Added Tailwind CSS alias to %local_aliases%"
)

goto:eof

:copy_fname
set "fname_target=%~1"
if not defined fname_target ( set "fname_target=%fname%" )
if not exist "%PRGS%\%prgs_folder%\%prg_folder%\%fname_target%" (
    %_task% "Must copy '%fname%' from '%PRGS%\setup' to '%prgs_folder%\%prg_folder%' subfolder as '%fname_target%'"
    copy "%PRGS%\setup\%fname%" "%PRGS%\%prgs_folder%\%prg_folder%\%fname_target%"
    if errorlevel 1 (
        %_fatal% "Unable to copy '%fname%' from '%PRGS%\setup' to '%PRGS%\%prgs_folder%\%prg_folder%' as '%fname_target%'" 72
    )
    %_ok% "File '%fname%' copied successfully to '%PRGS%\%prgs_folder%\%prg_folder%' as '%fname_target%'"
) else (
    %_ok% "File '%fname%' already exists in '%PRGS%\%prgs_folder%\%prg_folder%' as '%fname_target%'"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
