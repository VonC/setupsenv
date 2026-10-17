@echo off
rem senv_t_m: one "time=step" mark appended after each step, reported by senv_t_end.
rem A mark is a single set line on purpose: here every call costs ~20ms and every
rem append to a file ~30ms (the antivirus inspects each open of the file), so a
rem mark that called a subroutine or wrote a log line would distort what it times.
rem The total always shows in the final OK message. SENV_TIMING (set SENV_TIMING=1)
rem also prints each step, flagging [slow] from 0.5s and [REALLY SLOW] from 2s, and
rem appends the same lines to %TEMP%\senv.timing.log, where a tab opened among many
rem others can be read afterwards: each line starts with the #start time of its run.
set "senv_t_m=%TIME%=start"
set "local_senv="
for %%i in ("%~dp0.") do SET "script_dir_bin=%%~fi"
rem Same lookup as 'where publish_profile.bat' (current folder, then PATH), but
rem without starting where.exe, which took 0.13s.
for %%i in (publish_profile.bat) do if exist "%%i" set "local_senv=(preserved local) "
for %%i in (publish_profile.bat) do if not "%%~$PATH:i"=="" set "local_senv=(preserved local) "
if exist "%script_dir_bin%\..\adm" (
   set "local_senv=(local) "
)
if defined no_local_senv (
   set "no_local_senv=(reset) "
   set "local_senv="
)
set "senv_t_m=%senv_t_m%;%TIME%=detect local senv"
for %%i in ("%script_dir_bin%\..\batcolors") do ( set "bc=%%~fi" )
call %bc%\echos_macros.bat export
set "senv_t_m=%senv_t_m%;%TIME%=batcolors macros"
rem if errorlevel 1 (
rem    echo Batcolors not available in '%bc%' && exit /b 1
rem )
set PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\

rem SENV_UID: id unique per console for the switch* and ppath temp files. A console
rem inherits it from the console that opened it, so it is cleared here, and
rem senv_uid.bat looks the real one up the first time a script needs it: the lookup
rem costs 1.5 to 2.5s, which made it 70% of every senv run. See senv_uid.bat.
set "SENV_UID="

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
set "senv_t_m=%senv_t_m%;%TIME%=senv.local.pre.bat"

set "GH=%PRGS%\gits\current"
set "PATH=%script_dir_bin%;%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%GH%\mingw64\libexec\git-core;%PATH%"

set LANG=en_US.UTF-8
set LC_ALL=C.UTF-8
set TERM=msys

set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe

set "EDITOR=%PRGS%\vscodes\current\bin\code.cmd"
set "EDITOR="%PRGS%\npps\current\notepad++.exe" -multiInst -notabbar -nosession -noPlugin"

set "DL=%USERPROFILE%\Downloads"
set "DWL=%USERPROFILE%\Downloads"

rem One doskey call either way: each one starts doskey.exe, ~0.1s.
if exist "%PRGS%\npps\settings" (
   set "EDITOR="%PRGS%\npps\current\notepad++.exe" -settingsDir="%PRGS%\npps\settings" -multiInst -notabbar -nosession -noPlugin"
   doskey npp="%PRGS%\npps\current\notepad++.exe" -settingsDir="%PRGS%\npps\settings" $*
) else (
   doskey npp="%PRGS%\npps\current\notepad++.exe" $*
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
rem 'senv' is the profile installs\terminals.post.ps1 creates and sets as the
rem default one, so every machine senv installed has it, and naming it gives a
rem whole layout the same font and colours. Only the look is taken: wtp passes
rem its own command line and its own folder over the ones the profile carries.
rem An empty value passes no profile at all and the tabs fall back to whatever
rem Windows Terminal has as its default, which is what a machine whose profile
rem was renamed or removed needs. This file is read before senv.custom.bat and
rem senv.local.bat, so either of them overrides the value, the way
rem senv.custom.bat overrides the GOPROXY above: senv.custom.bat for a team
rem that shares its profiles, senv.local.bat for a single machine.
set "WTP_PROFILE=senv"
set "senv_t_m=%senv_t_m%;%TIME%=base variables, npp alias, Go"

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
set "senv_t_m=%senv_t_m%;%TIME%=usernamel"

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
set "senv_t_m=%senv_t_m%;%TIME%=senv.custom.bat"
set "senv_custom="
set "senv_profile_pre="
call %HOME%\bin\senv.local.bat
set "senv_t_m=%senv_t_m%;%TIME%=senv.local.bat"

if exist "%script_dir_bin%\profile" (
   if exist "%HOME%\bin\senv.custom.%senv_profile%.bat" (
      call %HOME%\bin\senv.custom.%senv_profile%.bat"
   )
)
set "senv_t_m=%senv_t_m%;%TIME%=senv.custom.profile.bat"

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
set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.doskey"
DOSKEY /MACROFILE="%HOME%\bin\senv.custom.doskey"
if errorlevel 1 (
   %_warning% "Issue setting custom (team) aliases from '%HOME%\bin\senv.custom.doskey'"
)
set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.custom.doskey"
DOSKEY /MACROFILE="%HOME%\bin\senv.local.doskey"
if errorlevel 1 (
   %_warning% "Issue setting local (personal) aliases from '%HOME%\bin\senv.local.doskey'"
)
set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.local.doskey"
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
set "senv_t_m=%senv_t_m%;%TIME%=doskey senv.custom.profile.doskey"
set "script_dir_bin="
call:senv_t_end
if "%internalsenvcall%"=="1" (
   set "bc="
   set "senv_dir="
   set "senv_t_elapsed="
   goto:eof
)
%_ok% "%local_senv%%no_local_senv%senv activated in %senv_t_elapsed%: senv_dir='%senv_dir%'"
set "senv_t_elapsed="
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
call:senv_t_end
set "senv_t_elapsed="
%_fatal% "%~1" %~2
goto:eof

:senv_t_end
rem Sets senv_t_elapsed to the time since the start mark, prints every step when
rem SENV_TIMING is defined, and clears the other senv_t_* variables.
set "senv_t_m=%senv_t_m%;%TIME%=end"
set "senv_t_id="
if defined SENV_TIMING (
   for %%m in ("%senv_t_m:;=" "%") do call:senv_t_step "%%~m"
) else (
   for /f "delims==" %%a in ("%senv_t_m%") do call:senv_t_step "%%a=start"
   call:senv_t_step "%TIME%=end"
)
call:senv_t_fmt %senv_t_total% senv_t_elapsed
set "senv_t_elapsed=%senv_t_elapsed: =%"
for %%v in (senv_t_m senv_t_id senv_t_start senv_t_last senv_t_now senv_t_step senv_t_total senv_t_label senv_t_step_s senv_t_total_s senv_t_flag senv_t_s senv_t_c senv_t_f) do set "%%v="
goto:eof

:senv_t_step
rem %1: one "time=step" mark. The first one starts the clock; each next one is
rem timed against the previous one and, with SENV_TIMING, printed and logged.
for /f "tokens=1* delims==" %%a in ("%~1") do (
   set "senv_t_now=%%a"
   set "senv_t_label=%%b"
)
rem %TIME% reads h:mm:ss,cc or h:mm:ss.cc depending on the locale, with a space
rem instead of a 0 before 10:00; 1xx-100 keeps 08 and 09 from reading as octal.
set "senv_t_now=%senv_t_now: =0%"
if not defined senv_t_id set "senv_t_id=%senv_t_now%"
set /a "senv_t_now=(((1%senv_t_now:~0,2%-100)*60+(1%senv_t_now:~3,2%-100))*60+(1%senv_t_now:~6,2%-100))*100+(1%senv_t_now:~9,2%-100)"
if defined senv_t_start goto:senv_t_next
set "senv_t_start=%senv_t_now%"
set "senv_t_last=%senv_t_now%"
set "senv_t_total=0"
if defined SENV_TIMING >>"%TEMP%\senv.timing.log" echo #%senv_t_id% ==== %DATE% senv.bat in %CD%
goto:eof
:senv_t_next
set /a "senv_t_step=senv_t_now-senv_t_last, senv_t_total=senv_t_now-senv_t_start"
set "senv_t_last=%senv_t_now%"
rem A run that crosses midnight.
if %senv_t_step% lss 0 set /a "senv_t_step+=8640000"
if %senv_t_total% lss 0 set /a "senv_t_total+=8640000"
if not defined SENV_TIMING goto:eof
call:senv_t_fmt %senv_t_step% senv_t_step_s
call:senv_t_fmt %senv_t_total% senv_t_total_s
set "senv_t_flag="
if %senv_t_step% geq 50 set "senv_t_flag=  [slow]"
if %senv_t_step% geq 200 set "senv_t_flag=  [REALLY SLOW]"
echo [senv timing] %senv_t_step_s% (total %senv_t_total_s%) %senv_t_label%%senv_t_flag%
>>"%TEMP%\senv.timing.log" echo #%senv_t_id% %senv_t_step_s% (total %senv_t_total_s%) %senv_t_label%%senv_t_flag%
goto:eof

:senv_t_fmt
rem %1 centiseconds, %2 variable receiving them as seconds, right-aligned: "  1.05s"
set /a "senv_t_s=%~1/100, senv_t_c=%~1%%100+100"
set "senv_t_f=      %senv_t_s%.%senv_t_c:~1%s"
set "%~2=%senv_t_f:~-7%"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
