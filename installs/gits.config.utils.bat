REM Git global config utils
@echo off
setlocal enabledelayedexpansion
for %%i in ("%~dp0") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
cd /d "%script_dir%"
call "%senv_dir%\batcolors\echos_macros.bat"

if not exist "%PRGS%\gits\current\usr\bin\cat.exe" (
  %_info% "Skip gits.config.utils: cat non available in path"
  goto:eof
)

set "_cat=%PRGS%\gits\current\usr\bin\cat.exe"
set "_grep=%PRGS%\gits\current\usr\bin\grep.exe"

if "%1"==":save_gitconfig" (
    call :save_gitconfig %*
    goto:eof
)
if "%1"==":restore_gitconfig" (
    call :restore_gitconfig %*
    goto:eof
)

:save_and_restore_gitconfig
call :save_gitconfig %*
call :restore_gitconfig %*
goto:eof

:save_gitconfig
"%_cat%" %HOME%\.gitconfig >NUL
"%_grep%" "st = status" %HOME%\.gitconfig >NUL
if errorlevel 1 (
  %_fatal% "Unable to read %HOME%\.gitconfig: content corrupted (%*)" 666
)
copy /Y %HOME%\.gitconfig %HOME%\.gitconfig.ori >NUL
if errorlevel 1 (
  %_fatal% "Unable to copy %HOME%\.gitconfig: content corrupted (%*)" 667
)
%_ok% "%HOME%\.gitconfig copied to %HOME%\.gitconfig.ori (%*)"
goto:eof

:restore_gitconfig
if not exist "%HOME%\.gitconfig.ori" (
  %_info% "skip  gits.config.utils restore_gitconfig: no .gitconfig.ori"
  goto:eof
)
"%_grep%" "st = status" %HOME%\.gitconfig.ori >NUL
if errorlevel 1 (
  %_fatal% "Unable to read %HOME%\.gitconfig.ori: content corrupted (%*)" 668
)
copy /Y %HOME%\.gitconfig.ori %HOME%\.gitconfig >NUL
if errorlevel 1 (
  %_fatal% "Unable to copy %HOME%\.gitconfig.ori: content corrupted (%*)" 669
)
"%_grep%" "st = status" %HOME%\.gitconfig >NUL
if errorlevel 1 (
  %_fatal% "Unable to confirm read %HOME%\.gitconfig: content corrupted (%*)" 670
)
%_ok% "%HOME%\.gitconfig.ori copied to %HOME%\.gitconfig (%*)"
goto:eof