@echo off
setlocal enabledelayedexpansion

set "p=%~1"
if "%p:node-v=%" == "%p%" ( endlocal && goto:eof )

set "p=%p:node-v=%"
for /f "tokens=1 delims=." %%a in ("%p%") do (
    set "firstToken=%%a"
)
if not "%firstToken%"=="" (
    echo node%firstToken%
)
endlocal