@echo off
set "local_senv="
for %%i in ("%~dp0.") do SET "script_dir_bin=%%~fi"
where publish_profile.bat >NUL 2> NUL
if not errorlevel 1 (
   set "local_senv=(preserved local) "
)
if exist "%script_dir_bin%\..\adm" (
   set "local_senv=(local) "
)
for %%i in ("%script_dir_bin%\..\batcolors") do ( set "bc=%%~fi" )
call %bc%\echos_macros.bat export
rem if errorlevel 1 (
rem    echo Batcolors not available in '%bc%' && exit /b 1
rem )
set PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\

set "admPath="
if defined local_senv (
   set "admPath=%PRGS%\senv\adm;%PRGS%\senv\bin;%PRGS%\senv\installs;"
   doskey ba=build_all.bat $*
   doskey pb=publish.bat $*
   doskey pp=publish_profile.bat $*
)
if not exist "%script_dir_bin%\senv.local.pre.bat" (
   if "%HOME%"=="" (
      set "script_dir_bin=%USERPROFILE%\home_senv\bin"
   ) else (
      set "script_dir_bin=%HOME%\bin"
   )
)
if not exist "%script_dir_bin%\senv.local.pre.bat" (
   call:fatal "script_dir_bin '%script_dir_bin%' must be reference senv.local.pre.bat" 101
)
set PRGS=
set HOME=
call "%script_dir_bin%\senv.local.pre.bat"
if "%PRGS%"=="" ( call:fatal "PRGS (installation folder) must be defined" 102 )
if "%HOME%"=="" ( call:fatal "HOME must be defined" 103 )
if "%PROG%"=="" ( call:fatal "PROG (data folder) must be defined" 104 )

set GH=%PRGS%\gits\current
set "PATH=%script_dir_bin%;%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%GH%\mingw64\libexec\git-core;%PATH%"

set LANG=en_US.UTF-8
set LC_ALL=C.UTF-8
set TERM=msys

set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe

set "EDITOR=%PRGS%\vscodes\current\bin\code.cmd"


rem https://stackoverflow.com/questions/284776/how-to-convert-the-value-of-username-to-lowercase-within-a-windows-batch-scrip
set "senv_dir=%script_dir_bin%"
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
endlocal & set "usernamel=%_STRING%"

:setusernamel
for /f "delims=" %%x in (%USERPROFILE%\usernamel) do set "usernamel=%%x"

call %HOME%\bin\senv.custom.bat
call %HOME%\bin\senv.local.bat

if exist "%script_dir_bin%\profile" (
   if exist "%HOME%\bin\senv.custom.%senv_profile%.bat" (
      call %HOME%\bin\senv.custom.%senv_profile%.bat"
   )
)

set "PATH=%admPath%%PATH%"
set "admPath="

set "vscodei="

DOSKEY /MACROFILE="%HOME%\bin\senv.doskey"
if errorlevel 1 (
   %_warning% "Issue setting global (all) aliases from '%HOME%\bin\senv.doskey'"
)
DOSKEY /MACROFILE="%HOME%\bin\senv.custom.doskey"
if errorlevel 1 (
   %_warning% "Issue setting custom (team) aliases from '%HOME%\bin\senv.custom.doskey'"
)
DOSKEY /MACROFILE="%HOME%\bin\senv.local.doskey"
if errorlevel 1 (
   %_warning% "Issue setting local (personal) aliases from '%HOME%\bin\senv.local.doskey'"
)
if exist "%script_dir_bin%\profile" (
   for /f "delims=" %%x in (%script_dir_bin%\profile) do set senv_profile=%%x
)
if exist "%script_dir_bin%\profile" (
   if exist "%HOME%\bin\senv.custom.%senv_profile%.doskey" (
      DOSKEY /MACROFILE="%HOME%\bin\senv.custom.%senv_profile%.doskey"
      if errorlevel 1 (
         %_warning% "Issue setting custom (profile) aliases from '%HOME%\bin\senv.custom.%senv_profile%.doskey'"
      )
   )
)
set "script_dir_bin="
if "%internalsenvcall%"=="1" (
   set "bc="
   set "senv_dir="
   goto:eof
)
%_ok% "%local_senv%senv activated: senv_dir='%senv_dir%'"
set "senv_dir="
set ASCII27=
set local_senv=
call %bc%\echos_macros.bat unset
set "bc="
goto:eof

:fatal
set "bc="
set "script_dir_bin="
set "senv_dir="
set ASCII27=
set local_senv=
%_fatal% "%~1" %~2
goto:eof