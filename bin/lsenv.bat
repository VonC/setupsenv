@echo off
set "local_senv="
set "no_local_senv="
call "%PRGS%\senv\bin\senv.bat"
if errorlevel 1 (
  %_error% "Unable to activate local senv paths with lsenv"
)
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
