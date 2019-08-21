@echo off
setlocal enabledelayedexpansion

for /f "tokens=1,2" %%a in ('tasklist^|grep -ai %1') do ( set pname=%%a&& set pid=%%b )
echo "pname='%pname%' => pid='%pid%'

if not "%pid%"=="" (
    taskkill /F /PID %pid%
)
