@echo off
setlocal enabledelayedexpansion

set "p=%~1"
set "res="
if not "%p:wildfly-=%" == "%p%" ( 
    set "res=%p:wildfly-=%"
)
for /f "tokens=1 delims=." %%a in ("%res%") do (
    set "res=%%a"
)
if not "%res%"=="" (
    echo wildfly%res%
    endlocal
    goto:eof
)
endlocal