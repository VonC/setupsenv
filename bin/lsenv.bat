@echo off
set "local_senv="
set "no_local_senv="
call "%PRGS%\senv\bin\senv.bat"
if errorlevel 1 (
  %_error% "Unable to activate local senv paths with lsenv"
)