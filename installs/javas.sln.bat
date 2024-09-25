@echo off
setlocal enabledelayedexpansion

if "%script_dir%"=="" (
    for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
    call !script_dir!\..\batcolors\echos_macros.bat export
)

set "p=%~1"
if not "%p:jdk-8u=%" == "%p%" ( echo jdk8)
if not "%p:hotspot_11.=%" == "%p%" ( echo jdk11)
if not "%p:hotspot_17.=%" == "%p%" ( echo jdk17)
