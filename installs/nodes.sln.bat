@echo off
setlocal enabledelayedexpansion

if "%script_dir%"=="" (
    for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
    call !script_dir!\..\batcolors\echos_macros.bat export
)

set "p=%~1"
if not "%p:node-v10.=%" == "%p%" ( echo node10)
if not "%p:node-v14.=%" == "%p%" ( echo node14)
