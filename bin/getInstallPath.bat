@echo off

setlocal enabledelayedexpansion

if "%script_dir%"=="" (
    for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
)
if exist !script_dir!\..\batcolors (
	call !script_dir!\..\batcolors\echos_macros.bat export
) else if exist !script_dir!\batcolors (
	call !script_dir!\batcolors\echos_macros.bat export
) else (
	echo "batcolor not found in script_dir '!script_dir!'" >&2
	exit /b 1
)

set "prgname=%~1"
set "prgpattern=%~2"
%_task% "Must get installation path 'instpath' of '%prgname%' pattern '%prgpattern%'"
if "%prgname%"=="" (
	%_fatal% "prgname must be provided" 1
)
if "%prgpattern%"=="" (
	%_fatal% "prgpattern must be provided" 2
)
goto:eof

set reg=HKCU
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i code 1>NUL
if not errorlevel 1 (
		rem %_info% "VSCode is installed"
) else (
		rem %_info% "VSCode is NOT installed"
		set reg=HKLM
)
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i code 1>NUL
if not errorlevel 1 (
		rem %_info% "VSCode is installed"
) else (
		%_fatal% "VSCode is NOT installed" 1
)
for /f "tokens=3*" %%a in ('reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s ^| findstr /i code') do (
    set "vscodei=%%a"
	rem echo vscodei 0 '%vscodei%' '!vscodei!'
	if not exist "!vscodei!" ( set "vscodei=%%a %%b")
	rem echo vscodei 1 '%vscodei%' '!vscodei!'
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c")
	rem echo vscodei 2 '%vscodei%' '!vscodei!'
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c %%d")
	rem echo vscodei 3 '%vscodei%' '!vscodei!'
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c %%d %%e")
	rem echo vscodei 4 '%vscodei%' '!vscodei!'
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c %%d %%e %%f")
	rem echo vscodei 5 '%vscodei%' '!vscodei!'
)
rem echo vscodei final='%vscodei%' '!vscodei!'
endlocal & set vscodei=%vscodei%

for /f  %%a in ('alias vscode') do (
	set vv=%%a
)
rem echo vv='%vv%' '%vscodei%'

if not exist "%vscodei%" (
	if "%ignorevscode%"=="" (
		echo "VSCode '%vscodei%' incorrect path, as determined by '%HOME%\bin\setvscodei.bat', from reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v 'InstallLocation' (or HKLM). Try and set env var 'vscodei' to the right path in User environment variable"
		exit /b 13
	)
)
