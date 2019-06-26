@echo off
set PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\

set PRGS=
set HOME=
for %%i in ("%~dp0.") do SET "script_dir_bin=%%~fi"
call "%script_dir_bin%\senv.local.pre.bat"
if "%PRGS%"=="" ( echo "PRGS (installation folder) must be defined" && exit /b 1 )
if "%HOME%"=="" ( echo "HOME must be defined" && exit /b 1 )
if "%PROG%"=="" ( %_fatal% "PROG (installation folder) must be defined" && exit /b 1 )

set GH=%PRGS%\gits\current
set PATH=%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%PATH%

set LANG=en_US.UTF-8
set LC_ALL=C.UTF-8
set TERM=msys

set PATH=%script_dir_bin%;%PATH%

set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe

DOSKEY /MACROFILE="%HOME%\bin\senv.doskey"
DOSKEY /MACROFILE="%HOME%\bin\senv.custom.doskey"
DOSKEY /MACROFILE="%HOME%\bin\senv.local.doskey"

rem https://stackoverflow.com/questions/284776/how-to-convert-the-value-of-username-to-lowercase-within-a-windows-batch-scrip

if exist "%USERPROFILE%\usernamel" goto:setusernamel
setlocal enabledelayedexpansion

set "_STRING=%USERNAME%"
set "_UCASE=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
set "_LCASE=abcdefghijklmnopqrstuvwxyz"

for /l %%a in (0,1,25) do (
   call set "_FROM=%%_UCASE:~%%a,1%%
   call set "_TO=%%_LCASE:~%%a,1%%
   call set "_STRING=%%_STRING:!_FROM!=!_TO!%%
)
echo %_STRING%>"%USERPROFILE%\usernamel"
endlocal & set usernamel=%_STRING%

:setusernamel
for /f "delims=" %%x in (%USERPROFILE%\usernamel) do set usernamel=%%x

call %HOME%\bin\senv.custom.bat
call %HOME%\bin\senv.local.bat
