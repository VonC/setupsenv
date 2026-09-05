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
if defined no_local_senv (
   set "no_local_senv=(reset) "
   set "local_senv="
)
for %%i in ("%script_dir_bin%\..\batcolors") do ( set "bc=%%~fi" )
call %bc%\echos_macros.bat export
rem if errorlevel 1 (
rem    echo Batcolors not available in '%bc%' && exit /b 1
rem )
set PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\

rem SENV_UID: id unique per console, so that concurrent tabs never share the same
rem switch* temp files. It is recomputed on every run and never taken from the
rem environment: a console inherits SENV_UID from the console that opened it, so a
rem batch of tabs opened at once all carried one id, and one tab deleted the temp
rem file another one was still reading. %RANDOM% is no better on its own: tabs
rem opened by one command start the same second and can draw identical values.
rem The lookup climbs two levels: for /f runs its command through a throwaway
rem cmd.exe of its own, so the parent of the powershell process is that helper and
rem the grandparent is this console.
set "SENV_UID="
for /f "usebackq delims=" %%p in (`powershell -NoProfile -Command "$h=(Get-CimInstance Win32_Process -Filter ('ProcessId=' + $PID)).ParentProcessId; (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $h)).ParentProcessId"`) do set "SENV_UID=%%p"
if not defined SENV_UID set "SENV_UID=%RANDOM%%RANDOM%"

set "admPath="
if defined local_senv (
   set "admPath=%PRGS%\senv\adm;%PRGS%\senv\bin;%PRGS%\senv\installs;;%PRGS%\senv\custom\bin;"
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

set "GH=%PRGS%\gits\current"
set "PATH=%script_dir_bin%;%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%GH%\mingw64\libexec\git-core;%PATH%"

set LANG=en_US.UTF-8
set LC_ALL=C.UTF-8
set TERM=msys

set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe

set "EDITOR=%PRGS%\vscodes\current\bin\code.cmd"
set "EDITOR="%PRGS%\npps\current\notepad++.exe" -multiInst -notabbar -nosession -noPlugin"
doskey npp="%PRGS%\npps\current\notepad++.exe" $*

set "DL=%USERPROFILE%\Downloads"
set "DWL=%USERPROFILE%\Downloads"

if exist "%PRGS%\npps\settings" (
   set "EDITOR="%PRGS%\npps\current\notepad++.exe" -settingsDir="%PRGS%\npps\settings" -multiInst -notabbar -nosession -noPlugin"
   doskey npp="%PRGS%\npps\current\notepad++.exe" -settingsDir="%PRGS%\npps\settings" $*
)

if exist "%PRGS%\gos\current" (
   set CGO_ENABLED=
   set "GOOGLE_API_KEY="
   set GO111MODULE=on
   set "GOROOT=%PRGS%\gos\current"
   set "GOBIN=%USERPROFILE%\go\bin"
   set "GOROOT=%PRGS%\gos\current"
)

if exist "%PRGS%\gos\current" (
   set "PATH=%PATH%;%GOROOT%\bin;%GOBIN%"
)
set GOPROXY=https://proxy.golang.org

rem WTP_PROFILE: the Windows Terminal profile wtp gives the tabs it opens.
rem Empty here on purpose. wtp then passes no profile at all, and every tab it
rem opens inherits the profile of the window wtp was called from, so a Terminal
rem nobody configured still works: naming a profile that does not exist is what
rem makes wt.exe refuse the tab. Name one to give a whole layout the same font,
rem colours and starting size. This file is read before senv.custom.bat and
rem senv.local.bat, so either of them overrides the value, the way
rem senv.custom.bat overrides the GOPROXY above: senv.custom.bat when every
rem machine of a team ships that profile, senv.local.bat for a single machine.
set "WTP_PROFILE="

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

rem A profile that ships a senv.custom.full.<profile>.bat sources it INSTEAD
rem of the team-shared senv.custom.bat: the shared file keeps the same
rem content on every machine of the HOME repository, while a machine
rem profile like 'home' gets its own full environment.
set "senv_custom=%HOME%\bin\senv.custom.bat"
set "senv_profile_pre="
if exist "%script_dir_bin%\profile" (
   for /f "delims=" %%x in (%script_dir_bin%\profile) do set "senv_profile_pre=%%x"
)
if defined senv_profile_pre if exist "%HOME%\bin\senv.custom.full.%senv_profile_pre%.bat" (
   set "senv_custom=%HOME%\bin\senv.custom.full.%senv_profile_pre%.bat"
)
call "%senv_custom%"
set "senv_custom="
set "senv_profile_pre="
call %HOME%\bin\senv.local.bat

if exist "%script_dir_bin%\profile" (
   if exist "%HOME%\bin\senv.custom.%senv_profile%.bat" (
      call %HOME%\bin\senv.custom.%senv_profile%.bat"
   )
)

if not defined local_senv (
   if exist "%PRGS%\senv\installs" ( set "admPath=%PRGS%\senv\installs;" )
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
%_ok% "%local_senv%%no_local_senv%senv activated: senv_dir='%senv_dir%'"
set "senv_dir="
set ASCII27=
set "local_senv="
set "no_local_senv="
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

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
