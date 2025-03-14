@echo off

setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "SWITCHPY_CHOICE=No venv"
call %script_dir%\switchpy.bat 3.12.7

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

if exist "%script_dir%\git-filter-repo.py" (
  if not defined GIT_FILTER_REPO_CHECK_UPDATE (
    %_info% "Skipping git-filter-repo.py update check, GIT_FILTER_REPO_CHECK_UPDATE not set"
    goto:proceed
  )
)

call "%script_dir%\ensure_internet.bat"
%_ok% "Internet connection there. Proceed with dowload/update check"

REM Check if git-filter-repo.py exists
if not exist "%script_dir%\git-filter-repo.py" (
    %_task% "git-filter-repo.py not found in '%script_dir%'. Must download it..."
    curl -L -o "%script_dir%\git-filter-repo.py" "https://github.com/newren/git-filter-repo/blob/main/git-filter-repo"
    if errorlevel 1 (
        %_fatal% "Failed to download git-filter-repo.py" 1
    ) else (
        %_ok% "git-filter-repo.py downloaded successfully to '%script_dir%'."
    )
)

REM Get SHA1 of local file
rem echo certutil -hashfile "%script_dir%\git-filter-repo.py" SHA1 ^| findstr /V /R "[CS]"
certutil -hashfile "%script_dir%\git-filter-repo.py" SHA1 | findstr /V /R "[CS]"> "%script_dir%\git-filter-repo.py.sha1"
for /f "delims=" %%i in ('type "%script_dir%\git-filter-repo.py.sha1"') do set "local_sha1=%%i"

REM Get SHA1 of remote file
curl -L -s "https://raw.githubusercontent.com/newren/git-filter-repo/refs/heads/main/git-filter-repo" -o "%script_dir%\git-filter-repo.py.tmp"
if errorlevel 1 (
    %_fatal% "Failed to download temp git-filter-repo.py" 1
)
rem echo certutil -hashfile "%script_dir%\git-filter-repo.py.tmp" SHA1 ^| findstr /V /R "[CS]"
certutil -hashfile "%script_dir%\git-filter-repo.py.tmp" SHA1 | findstr /V /R "[CS]"> "%script_dir%\git-filter-repo.py.tmp.sha1"
for /f "delims=" %%i in ('type "%script_dir%\git-filter-repo.py.tmp.sha1"') do set "remote_sha1=%%i"

REM Compare SHA1 hashes
if not "%local_sha1%"=="%remote_sha1%" (
    %_task% "git-filter-repo.py is outdated (local_sha1='%local_sha1%', remote_sha1='%remote_sha1%'). Must update it..."
    curl -L -o "%script_dir%\git-filter-repo.py" "https://raw.githubusercontent.com/newren/git-filter-repo/refs/heads/main/git-filter-repo"
    if errorlevel 1 (
        %_fatal% "Failed to download/update git-filter-repo.py" 1
    ) else (
        %_ok% "git-filter-repo.py updated successfully."
    )
) else (
    %_ok% "git-filter-repo.py is up to date (local_sha1='%local_sha1%', remote_sha1='%remote_sha1%')."
)

REM Clean up temporary file
del "%script_dir%\git-filter-repo.py.tmp"
del "%script_dir%\git-filter-repo.py.sha1"
del "%script_dir%\git-filter-repo.py.tmp.sha1"

:proceed
%_ok% "git-filter-repo.py is ready to use."

python "%script_dir%\git-filter-repo.py" %*

endlocal
set "GIT_FILTER_REPO_CHECK_UPDATE="
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
