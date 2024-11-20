@echo off
for %%i in ("%~dp0.") do SET "script_dir_bin=%%~fi"
call %script_dir_bin%\senv.bat

call %HOME%\bin\gsenv.custom.bat
call %HOME%\bin\gsenv.local.bat

<nul set /p =VSCode...
tasklist /FI "IMAGENAME eq Code.exe" /FO CSV|grep Code.exe >NUL
IF ERRORLEVEL 1 (
	call "%PRGS%\senv\installs\vscodes.pre.bat" "check"
	set "pre_ok="
	call "%PRGS%\vscodes\current\bin\code.cmd"
	echo VSCode launched
) else (
		echo already launched
)

echo All gsenv done
