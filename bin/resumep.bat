@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "resumep_loop="
set "prg=%~1"
if not defined prg ( goto:call_run )
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
:call_run
call <NUL :rrun "%prg%"
endlocal
goto:eof

:rrun
:loop
bash -f "%script_dir%\resumep.sh" "%~1" %resumep_loop%
if errorlevel 1 (
  echo Errorlevel: %errorlevel%
  goto:eof
)
if defined resumep_loop ( goto:loop )
goto:eof