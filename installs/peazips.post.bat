@echo off

if "%script_dir%"=="" (
    setlocal enabledelayedexpansion
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
    call "!script_dir!\custom\echos_macros.bat"
)
%_info% "Peazips post install"

if not exist "%PRGS%\peazips\current\res" (
    %_fatal% "'%PRGS%\peazips\current\res' folder missing"
)

if not exist "%PRGS%\peazips\current\res\7z" (
    %_task% "Must add missing symlink 7z in '%PRGS%\peazips\current\res'"
    mklink /J "%PRGS%\peazips\current\res\7z" "%PRGS%\peazips\current\res\bin\7z"
    if errorlevel 1 (
        %_fatal% "unable to add symlink 7z in '%PRGS%\peazips\current\res' to '%PRGS%\peazips\current\res\bin\7z'" 1
    )
    %_ok% "symlink 7z created in '%PRGS%\peazips\current\res' to '%PRGS%\peazips\current\res\bin\7z'"
)

if not exist "%PRGS%\peazips\current\res\7z\7z.exe" (
    %_fatal% "unable to access 7z.exe in '%PRGS%\peazips\current\res\7z'" 1
)
%_ok% " 7z.exe in '%PRGS%\peazips\current\res\7z' is accessible"
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
