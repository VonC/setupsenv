@echo off
for %%i in ("%~dp0.") do SET "script_dir_bin=%%~fi"
call %script_dir_bin%\senv.bat

<nul set /p =VSCode...
tasklist /FI "IMAGENAME eq Code.exe" /FO CSV|grep Code.exe >NUL
IF ERRORLEVEL 1 (
	call "%PRGS%\senv\installs\vscodes.pre.bat" "check"
	call "%vscodei%bin\code.cmd"
	echo VSCode launched
) else (
		echo already launched
)

call %HOME%\bin\gsenv.custom.bat
call %HOME%\bin\gsenv.local.bat

echo All gsenv done
