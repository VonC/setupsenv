@echo off

setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

set "SWITCHPY_CHOICE=No venv"
call %script_dir%\switchpy.bat 3.12.7

python -V
where python
set path