@echo off
setlocal ENABLEDELAYEDEXPANSION
FOR /F %%i IN ('cat %HOME%\bin\profile') DO set profileName=%%i
echo profile name='%profileName%'
FOR /F "tokens=3,* delims= " %%i IN ('alias cdis') DO set profileFolder=%%i
set "profileFolder=%profileFolder:~0,-1%"
echo from profile folder '%profileFolder%'
