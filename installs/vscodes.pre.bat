@echo off
echo pre: vscode
set "vscodei="
setlocal enabledelayedexpansion
for /f "tokens=3*" %%a in ('reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s ^| grep -i code') do (
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

if exist "%vscodei%" (
    set pre_ok=true
	if "%1"=="" (
		%_ok% "VSCode already installed in '%vscodei%"
	)
	exit /b 0
)
