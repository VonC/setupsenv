@echo off
set "local_senv="
for %%i in ("%~dp0.") do SET "script_dir_bin=%%~fi"
set "no_local_senv=true"
call "%script_dir_bin%\senv.bat"
