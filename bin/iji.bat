@echo off

set "standalone_call=true"
if defined script_dir (
  set "standalone_call="
)

rem https://www.yworks.com/resources/yed/demo/yEd-3.24.zip
rem <a href="/products/yed">yEd Graph Editor 3.24</a> at https://www.yworks.com/downloads#yEd

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
set "bc=%senv_dir%\batcolors"
call %bc%\echos_macros.bat

rem Check if PRGS environment variable is set
if not defined PRGS (
  call:unset && call "%bc%\echos.bat" :fatal "The PRGS environment variable is not defined. Cannot locate IntelliJ IDEA." 12
)

for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)
rem get the name of the current folder (pwd, or %cd%)
for %%i in ("%cd%") do (
    set "current_folder=%%~nxi"
)

rem --- Define IDEA Executable Path based on %PRGS% ---
mkdir "%PRGS%\ideaics" 2>nul
set "IDEA_BASE_PATH=%PRGS%\ideaics\current"
set "IDEA_EXECUTABLE=%IDEA_BASE_PATH%\bin\idea64.exe"
set "IDEA_ALT_EXECUTABLE=%IDEA_BASE_PATH%\bin\idea.bat" ' Optional fallback

rem Check if the primary executable exists
if exist "%IDEA_EXECUTABLE%" ( goto:idea_does_exit )
set "IDEA_EXECUTABLE="

rem Common locations - check Program Files first, then potentially Toolbox
if exist "%ProgramFiles%\JetBrains\IntelliJ IDEA Community Edition\bin\idea64.exe" (
    set "IDEA_EXECUTABLE=%ProgramFiles%\JetBrains\IntelliJ IDEA Community Edition\bin\idea64.exe"
) else if exist "%ProgramFiles%\JetBrains\IntelliJ IDEA Ultimate Edition\bin\idea64.exe" (
    set "IDEA_EXECUTABLE=%ProgramFiles%\JetBrains\IntelliJ IDEA Ultimate Edition\bin\idea64.exe"
) else if exist "%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-C\ch-0\" (
    rem Attempt to find the latest Community version in Toolbox default path - might need refinement
    for /f "delims=" %%d in ('dir /b /ad /o-d "%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-C\ch-0\*"') do (
        if exist "%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-C\ch-0\%%d\bin\idea64.exe" (
            set "IDEA_EXECUTABLE=%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-C\ch-0\%%d\bin\idea64.exe"
            goto :FoundIdeaToolbox
        )
    )
) else if exist "%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-U\ch-0\" (
     rem Attempt to find the latest Ultimate version in Toolbox default path - might need refinement
    for /f "delims=" %%d in ('dir /b /ad /o-d "%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-U\ch-0\*"') do (
        if exist "%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-U\ch-0\%%d\bin\idea64.exe" (
            set "IDEA_EXECUTABLE=%LOCALAPPDATA%\JetBrains\Toolbox\apps\IDEA-U\ch-0\%%d\bin\idea64.exe"
            goto :FoundIdeaToolbox
        )
    )
)
:FoundIdeaToolbox

rem Fallback: Expect idea.bat to be in PATH (less reliable)
if not defined IDEA_EXECUTABLE (
    for /f "delims=" %%i in ('where idea.bat 2^>nul') do (
        if not errorlevel 1 (
            set "IDEA_EXECUTABLE=%%i"
            goto :FoundIdeaBat
        )
    )
)
:FoundIdeaBat

rmdir "%PRGS%\ideaics\current" /q 2>nul
if defined IDEA_EXECUTABLE (
    for /f "delims=" %%i in ("%IDEA_EXECUTABLE%") do (
        set "IDEA_BIN_DIR=%%~dpi"
    )
    for %%i in ("%IDEA_BIN_DIR%..") do (
        set "IDEA_PARENT_DIR=%%~fi"
    )
    %_task% "Creating junction %PRGS%\ideaics\current pointing to %IDEA_PARENT_DIR%"
    mklink /J "%PRGS%\ideaics\current" "%IDEA_PARENT_DIR%"
    if errorlevel 1 (
        %_error% "Failed to create junction for IntelliJ IDEA installation"
        set "IDEA_EXECUTABLE="
    ) else (
        %_ok% "Created junction for IntelliJ IDEA installation"
    )
)

if not exist "%IDEA_EXECUTABLE%" (
    call:unset
    call "%bc%\echos.bat" :post "Check the PRGS variable and the junction/path at '%IDEA_BASE_PATH%'."
    call "%bc%\echos.bat" :fatal "IntelliJ IDEA executable not found at expected locations" 13
)

:idea_does_exit
rem Get the current project directory
set "project_dir=%cd%"

%_info% "Using IDEA executable: '%IDEA_EXECUTABLE%'"

rem Check if it looks like an IDEA project (optional, but good practice)
if not exist "%project_dir%\.idea" (
  %_warn% "Directory '%project_dir%' does not contain an '.idea' subfolder. IDEA will prompt to create/import project."
  rem You might choose to exit here if an existing project is strictly required
  rem call:unset && call "%bc%\echos.bat" :fatal "Not an existing IDEA project: '%project_dir%'" 3
  rem goto :unset
)

rem Call pre-launch scripts (same as before)
if exist "%project_dir%\senv.bat" (
  %_task% "Must call '%project_dir%\senv.bat'"
  call "%project_dir%\senv.bat"
  if errorlevel 1 (
    call:unset && call "%bc%\echos.bat" :fatal "error calling '%project_dir%\senv.bat'" 4
  ) else (
    call "%bc%\echos_macros.bat"
    %_ok% "called '%project_dir%\senv.bat'"
  )
)

if exist "%project_dir%\tools\init.bat" (
  %_task% "Must call '%project_dir%\tools\init.bat'"
  call "%project_dir%\tools\init.bat"
  if errorlevel 1 (
    call:unset && call "%bc%\echos.bat" :fatal "error calling '%project_dir%\tools\init.bat'" 5
  ) else (
    call "%bc%\echos_macros.bat"
    %_ok% "called '%project_dir%\tools\init.bat'"
  )
)

%_info% "Project directory: '%project_dir%'"
%_task% "Must open project directory in IntelliJ IDEA: '%project_dir%'"

rem Launch IntelliJ IDEA with the project directory
rem Using start /b prevents the batch script from waiting for IDEA to close
start "IntelliJ IDEA" /B "%IDEA_EXECUTABLE%" "%project_dir%"

rem Check errorlevel immediately after start is tricky, as it launches async.
rem Basic check if the command itself failed to launch. IDEA errors happen later.
if errorlevel 1 (
  call:unset && call "%bc%\echos.bat" :fatal "error launching IntelliJ IDEA command for project: '%project_dir%'" 2
)

%_ok% "Launched IntelliJ IDEA command for project: '%project_dir%'"
call:unset
goto:eof

:unset
%_info% "Cleaning up script variables..."
call "%bc%\echos_macros.bat" unset
if defined standalone_call (
  set "script_dir="
)
set "standalone_call="
set "project_dir="
set "IDEA_EXECUTABLE="
set "IDEA_BASE_PATH="
set "IDEA_ALT_EXECUTABLE="
rem Keep other unset variables if needed
set "senv_dir="
set "setup_dir="
rem Unset echo macros if they were defined as fallbacks
if defined _info (
    set "_info="
    set "_task="
    set "_ok="
    set "_warning="
    set "_warn="
    set "_error="
    set "_fatal="
)
goto:eof


:call_echos_stack
rem Your echos stack logic remains the same
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    rem Assuming batdir is defined correctly by your echos setup
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof