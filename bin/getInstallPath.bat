@echo off

if "%script_dir%"=="" ( echo.>>"%~dp0standalone_%~nx0.flag")
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
set "echos_standalone=%~dp0standalone_%~nx0.flag"

rem @echo on
set "prgname=%~1"
set "prgpattern=%~2"
%_task% "[%~nx0] Must get installation path instpath of '%prgname%' pattern '%prgpattern%'"
rem @echo on
if "%prgname%"=="" (
	%_fatal% "[%~nx0] prgname must be provided (ex: VSCode)" 1
)
if "%prgpattern%"=="" (
	%_fatal% "[%~nx0] prgpattern (searched in HKCU/HKLM) must be provided (ex: code)" 2
)

if "%prgname%"=="ghs" (
	set "instPath=C:\Program Files\GitHub CLI"
	goto:endlocal
)

set reg=HKCU
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i %prgpattern% 1>NUL
if not errorlevel 1 (
		rem %_info% "[%~nx0] %prgname% is installed"
) else (
		rem %_info% "[%~nx0] %prgname% is NOT installed"
		set reg=HKLM
)
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i %prgpattern% 1>NUL
if not errorlevel 1 (
		rem %_info% "[%~nx0] %prgname% is installed"
) else (
		%_fatal% "[%~nx0] %prgname% is NOT installed for pattern '%prgpattern%'" 1
)
for /f "tokens=3*" %%a in ('reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s ^| findstr /i %prgpattern%') do (
    set "instPath=%%a"
	rem echo instPath 0 '%instPath%' '!instPath!'
	if not exist "!instPath!" ( set "instPath=%%a %%b")
	rem echo instPath 1 '%instPath%' '!instPath!'
	if not exist "!instPath!" ( set "instPath=%%a %%b %%c")
	rem echo instPath 2 '%instPath%' '!instPath!'
	if not exist "!instPath!" ( set "instPath=%%a %%b %%c %%d")
	rem echo instPath 3 '%instPath%' '!instPath!'
	if not exist "!instPath!" ( set "instPath=%%a %%b %%c %%d %%e")
	rem echo instPath 4 '%instPath%' '!instPath!'
	if not exist "!instPath!" ( set "instPath=%%a %%b %%c %%d %%e %%f")
	rem echo instPath 5 '%instPath%' '!instPath!'
)
rem echo instPath final='%instPath%' '!instPath!'

if not exist "%instPath%" (
	if not defined ignoreNoInstPath (
		set "instPath="
		%_fatal% "[%~nx0] %prgname% '%instPath%' incorrect path, as determined by '%HOME%\bin\getInstallPath.bat', from reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v 'InstallLocation' (or HKLM) for '%prgpattern%'." 13
	) else (
		if exist "%echos_standalone%" (
			%_error% "[%~nx0] %prgname% '%instPath%' incorrect path, as determined by '%HOME%\bin\getInstallPath.bat', from reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v 'InstallLocation' (or HKLM) for '%prgpattern%'."
		)
	)
)
:endlocal
endlocal & set "instPath=%instPath%"
rem if instPath ends with a trailing backslash, remove trailing backslash
if "%instPath:~-1%"=="\" ( set "instPath=%instPath:~0,-1%" )
rem echo getInstallPath: instPath='%instPath%'
rem echo getInstallPath: standaloneGetInstallPath='%standaloneGetInstallPath%'
set ASCII27=
rem set ASCII27=← 

if exist "%~dp0standalone_%~nx0.flag" (

	echo %ASCII27%[106;30m INFO  %ASCII27%[0m: instPath='%instPath%'
	set "instPath="
	set "standaloneGetInstallPath="
	set "ASCII27="
	del "%~dp0standalone_%~nx0.flag"
)
rem echo RES instPath='%instPath%'