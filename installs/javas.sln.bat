@echo off
setlocal enabledelayedexpansion

set "p=%~1"
set "res="
if not "%p:jdk-=%" == "%p%" ( 
    set "res=%p:jdk-=%"
)
for /f "tokens=1 delims=u" %%a in ("%res%") do (
    set "res=%%a"
)
if not "%res%"=="" (
    echo jdk%res%
    endlocal
    goto:eof
)

if "%p:OpenJDK=%" == "%p%" ( endlocal && goto:eof )
set "p=%p:OpenJDK=%"
for /f "tokens=1 delims=U" %%a in ("%p%") do (
    set "firstToken=%%a"
)

if not "%firstToken%"=="" (
    echo jdk%firstToken%
)
endlocal