@echo off
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
%_info% "~~~~~~~~~~~~ Msys2 post installation prg_folder='%prg_folder%' ~~~~~~~~~~~~"
set | grep msys


%_task% "Looking for a subfolder in %PRGS%\%prgs_folder%\%prg_folder%"
pushd "%PRGS%\%prgs_folder%\%prg_folder%"
if errorlevel 1 (
    %_fatal% "Failed to change directory to %PRGS%\%prgs_folder%\%prg_folder%" 1
)

for /f "delims=" %%f in ('dir /AD /B') do (
    set "subfolder=%%f"
    %_ok% "Found subfolder: %%f"
    goto :found_subfolder
)

:found_subfolder
if not defined subfolder (
    %_fatal% "No subfolder found in %PRGS%\%prgs_folder%\%prg_folder%" 1
)

%_warning% "No symlink possible from %prg_folder% to subfolder '%subfolder%' to prgs_folder '%prgs_folder%' for ucrt4: abort for now"
popd
goto:eof

%_task% "Changing to subfolder\msys64 directory"
cd "!subfolder!\msys64"
if errorlevel 1 (
    %_fatal% "Failed to change directory to !subfolder!\msys64" 1
)
%_ok% "Changed to !subfolder!\msys64 directory"

%_task% "Checking if %PRGS%\%prgs_folder%\ucrt64 exists"
if not exist "%PRGS%\%prgs_folder%\ucrt64" (
    %_task% "Moving ucrt64 from current directory to %PRGS%\%prgs_folder%"
    move ucrt64 "%PRGS%\%prgs_folder%\"
    if errorlevel 1 (
        %_fatal% "Failed to move ucrt64 to %PRGS%\%prgs_folder%" 1
    )
    %_ok% "Successfully moved ucrt64 to %PRGS%\%prgs_folder%"
) else (
    %_ok% "ucrt64 already exists in %PRGS%\%prgs_folder%"
    %_task% "Checking if ucrt64 in current directory is a junction"
    set "is_junction=yes"
    dir|grep ucrt64|grep JUNCTION >NUL 2>NUL
    if errorlevel 1 (
        set "is_junction=no"
    )
    
    if "!is_junction!"=="no" (
        %_task% "Removing existing ucrt64 folder (not a junction)"
        rmdir /s /q ucrt64
        if errorlevel 1 (
            %_fatal% "Failed to remove existing ucrt64 folder" 1
        )
        %_ok% "Successfully removed ucrt64 folder"
        
        %_task% "Creating junction link from ucrt64 to %PRGS%\%prgs_folder%\ucrt64"
        mklink /J ucrt64 "%PRGS%\%prgs_folder%\ucrt64"
        if errorlevel 1 (
            %_fatal% "Failed to create junction link for ucrt64" 1
        )
        %_ok% "Successfully created junction link for ucrt64"
    ) else (
        %_ok% "ucrt64 is already a junction link"
    )
)

popd
%_ok% "Msys2 post-installation completed successfully"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
