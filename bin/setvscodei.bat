@echo off

if exist "%vscodei%" (
    rem %_info% "VScode is supposed to be installed at '%vscodei%'"
    goto:eof
)
set "vscodei="
setlocal enabledelayedexpansion
set reg=HKCU
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i code 1>NUL
if not errorlevel 1 (
		rem %_info% "VSCode is installed"
) else (
		rem %_info% "VSCode is NOT installed"
		set reg=
)
if not "%reg%"=="" ( goto:forfind)
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i code 1>NUL
if not errorlevel 1 (
		rem %_info% "VSCode is installed"
) else (
		%_fatal% "VSCode is NOT installed in HKCU or HKLM" 1
)
:forfind
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
