%_info% "pre: vscode"
for /f "tokens=3*" %%a in ('reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /v "InstallLocation" /s ^| grep -i code') do (
    set "vscodei=%%a"
	if not exist "!vscodei!" ( set "vscodei=%%a %%b" )
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c" )
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c %%d" )
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c %%d %%e" )
	if not exist "!vscodei!" ( set "vscodei=%%a %%b %%c %%d %%e %%f" )
)
rem echo "vscodei 2='%vscodei%'"

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
