@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "resumep_loop="
set "prg=%~1"
if not "%prg:loop=%"=="%prg%" (
  set "resumep_loop=%prg:loop_=%"
  if "!resumep_loop!"=="loop" (
    set "resumep_loop=5"
  )
  shift
)
set "prg=%~1"
rem echo prg=%prg%, resumep_loop=%resumep_loop%
rem goto:eof
call <NUL :rrun "%prg%"
endlocal
goto:eof

:rrun
:loop
bash -f "%script_dir%\resumep.sh" "%~1"
if defined resumep_loop (
  echo Waiting %resumep_loop% seconds before retrying
  ping -n %resumep_loop% 8.8.8.8 > nul || exit /b 0
  goto:loop
)
goto:eof