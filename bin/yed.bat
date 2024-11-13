@echo off
call "%HOME%\bin\switchjdk.bat" 22
if errorlevel 1 (
    call:unset && call "%HOME%\batcolors\echos.bat" :fatal "Unable to switch to JDK 22" 11
)
for "tokens=1 delims=-" %%a in ('ls -l "%PRGS%\yeds\current"') do ( set "yed_version=%%a" )
start "yed" /B cmd /C %PRGS%\yeds\current\yed.exe %*
if errorlevel 1 (
    call:unset && call "%HOME%\batcolors\echos.bat" :fatal "Unable to launch yEd version '%yed_version%'" 12
)
call "%HOME%\batcolors\echos.bat" :ok "yEd version '%yed_version%' launched"
call:unset
goto:eof


:unset
call "%HOME%\batcolors\echos_macros.bat" unset
rem cleanup any variable PY...
set "senv_dir="
set "script_dir="
set "choice="
set "_OLD_VIRTUAL_PATH="
set "newPath="
set "switchver_todelete="
goto:eof