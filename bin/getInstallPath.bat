@echo off

setlocal enabledelayedexpansion

set "standaloneGetInstallPath="
if "%script_dir%"=="" (
    for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
		set "standaloneGetInstallPath=true"
)
if exist !script_dir!\..\batcolors (
	call !script_dir!\..\batcolors\echos_macros.bat export
) else if exist !script_dir!\batcolors (
	call !script_dir!\batcolors\echos_macros.bat export
) else (
	echo "batcolor not found in script_dir '!script_dir!'" >&2
	exit /b 1
)
@echo on
set "prgname=%~1"
set "prgpattern=%~2"
if "%standaloneGetInstallPath%"=="" (
	set "standaloneGetInstallPath=%~3"
)
%_task% "Must get installation path instpath of '%prgname%' pattern '%prgpattern%' standaloneGetInstallPath '%standaloneGetInstallPath%'"
rem @echo on
if "%prgname%"=="" (
	%_fatal% "prgname must be provided (ex: VSCode)" 1
)
if "%prgpattern%"=="" (
	%_fatal% "prgpattern (searched in HKCU/HKLM) must be provided (ex: code)" 2
)

set reg=HKCU
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i %prgpattern% 1>NUL
if not errorlevel 1 (
		rem %_info% "%prgname% is installed"
) else (
		rem %_info% "%prgname% is NOT installed"
		set reg=HKLM
)
reg query %reg%\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s | findstr /i %prgpattern% 1>NUL
if not errorlevel 1 (
		rem %_info% "%prgname% is installed"
) else (
		%_fatal% "%prgname% is NOT installed for pattern '%prgpattern%'" 1
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
	if "%ignoreNoInstPath%"=="" (
		set "instPath="
		set "standaloneGetInstallPath="
		%_fatal% "%prgname% '%instPath%' incorrect path, as determined by '%HOME%\bin\getInstallPath.bat', from reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v 'InstallLocation' (or HKLM) for '%prgpattern%'." 13
	) else (
		if "%standaloneGetInstallPath%"=="true" (
			%_error% "%prgname% '%instPath%' incorrect path, as determined by '%HOME%\bin\getInstallPath.bat', from reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v 'InstallLocation' (or HKLM) for '%prgpattern%'."
		)
	)
)
endlocal & set "instPath=%instPath%" & set "standaloneGetInstallPath=%standaloneGetInstallPath%"
rem if instPath ends with a trailing backslash, remove trailing backslash
if "%instPath:~-1%"=="\" ( set "instPath=%instPath:~0,-1%" )
rem echo getInstallPath: instPath='%instPath%'
rem echo getInstallPath: standaloneGetInstallPath='%standaloneGetInstallPath%'
set ASCII27=
rem set ASCII27=← 

if "%standaloneGetInstallPath%"=="true" (

	echo %ASCII27%[106;30m INFO  %ASCII27%[0m: instPath='%instPath%'
	set "instPath="
	set "standaloneGetInstallPath="
	set "ASCII27="
)
set "standaloneGetInstallPath="
echo RES instPath='%instPath%'