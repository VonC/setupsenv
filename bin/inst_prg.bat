@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

%_info% "[%~nx0] 'script_dir(inst_prg)='%script_dir%'"

pushd "%USERPROFILE%\Downloads" || %_fatal% "[%~nx0] Unable to access '%USERPROFILE%\Downloads')'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)
popd

%_info% "[%~nx0] Install '%~2', setup_dir='%setup_dir%', dl_dir='%dl_dir%'"

if "%~2"=="" (
    %_fatal%  "Usage: inst_prg (prgname) (pattern) (pattern to search for in Downloads or setup)." 4
)

set "sfound=setup"
dir /b "%setup_dir%"|findstr "%~2" > a
if errorlevel 1 (
    dir /b "%dl_dir%"|findstr "%~2" > a
    if errorlevel 1 (
        %_fatal%  "No '%~2' pattern found in setup or Downloads" 6
    )
    set "sfound=Downloads"
)

rem https://stackoverflow.com/questions/42000037/how-to-count-the-occurrence-of-a-variable-in-log-file-matching-a-pattern-regex-i
set COUNT=0
for /F "tokens=*" %%N in (a) do set /a COUNT+=1
if not "%count%"=="1" (
        type a
        del a 2>NUL
        %_fatal%  "'%count%' (More than one match) in '%sfound%' for pattern '%~2'" 7
)
for /F "delims=" %%f in (a) do ( set fname=%%f)
%_info% "[%~nx0] One match found in '%sfound%': '%fname%'"
del a

if "%sfound%"=="Downloads" (
    %_task% "[%~nx0] Must move match '%fname%' from Downloads to setup"
    call:rbc "%dl_dir%"
    del "%dl_dir%\%fname%" || %_fatal% "[%~nx0] Unable to delete '%dl_dir%\%fname%'" 88
    %_ok% "'%fname%' moved from Downloads to setup"
)

set "prg_name=%~1"
set "prgs_folder=%~1"
:: Symlink name, defautl to current if no name returned by :symlink_name
set "sln=%~3"
if not defined sln ( call:symlink_name "%fname%" )
if not defined sln ( set "sln=current" )

rem https://stackoverflow.com/questions/284776/how-to-convert-the-value-of-username-to-lowercase-within-a-windows-batch-scrip
set "_UCASE=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
set "_LCASE=abcdefghijklmnopqrstuvwxyz"
for /l %%a in (0,1,25) do (
   call set "_FROM=%%_UCASE:~%%a,1%%
   call set "_TO=%%_LCASE:~%%a,1%%
   call set "prgs_folder=%%prgs_folder:!_FROM!=!_TO!%%
)
set "prgs_folder=%prgs_folder%s"

if not exist "%PRGS%\%prgs_folder%" (
    %_fatal% "Target folder '%PRGS%\%prgs_folder%' does not exist"
)

for /F "usebackq" %%i in (`dir /OD /B "%setup_dir%\%fname%"`) do set "prg_folder=%%~ni"

%_task% "[%~nx0] '%prg_name%': Must check/install '%fname%' from '%setup_dir%' to '%PRGS%\%prgs_folder%\%prg_folder%' with symlink name '%sln%'"

if exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_ok% "[%~nx0] Program '%prg_folder%' already exists in '%PRGS%\%prgs_folder%'"
    goto:check_symlink
)

set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe
pushd "%PRGS%\%prgs_folder%" || %_fatal% "[%~nx0] Unable to access '%PRGS%\%prgs_folder%'" 8
if not exist "%fname%" (
    call:rbc "%PRGS%\%prgs_folder%"
)
%_task% "[%~nx0] Must uncompress with 7z '%PRGS%\setup\%fname%' to '%PRGS%\%prgs_folder%'"
call "%HOME%\bin\pzxx.bat" "%PRGS%\%prgs_folder%\%fname%"
if errorlevel 1 (
    rm -Rf "%PRGS%\%prgs_folder%\%prgs_folder%"
    popd
    %_fatal% "[%~nx0] Error on 7z uncompression of '%fname%' to '%PRGS%\%prgs_folder%\%prgs_folder%'" 1
)
%_ok% "[%~nx0] '%fname%' uncompressed (7z) to '%PRGS%\%prgs_folder%\%prgs_folder%'"
:check_symlink
%_task% "[%~nx0] Must check symlink '%sln%' for '%prg_folder%' in '%PRGS%\%prgs_folder%'"
call "%script_dir%\check_prg_symlink.bat" "%prgs_folder%" "%prg_folder%" "%sln%"
popd
goto:eof

:rbc
cd
set "dst=%1"
set "src=%2"
if "%src%"=="" ( set "src=%setup_dir%" )
%_task% "[%~nx0] Must robocopy '%fname%' from '%src%' to '%dst%'"
(robocopy /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS %src% %dst% %fname%) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
if not "%ERRORLEVEL%"=="0" ( %_fatal% "[%~nx0] Unable to copy '%setup_dir%\%fname%' to '%PRGS%\setup\' errorlevel '%ERRORLEVEL%'" && exit /b 1)
%_ok% "[%~nx0] Setup '%fname%' copied locally"
goto:eof

:symlink_name
set "fname=%~1"
if not "%fname:node-v=%"=="" (
    set "sln=%fname:node-v=%"
    for /f "tokens=1 delims=." %%f in ('echo !sln!') do ( set "sln=node%%f" )
    goto:eof
)
if not "%fname:python-=%"=="" (
    set "sln=%fname:python-=%"
    for /f "tokens=1 delims=-" %%f in ('echo !sln!') do ( set "sln=python%%f" )
    goto:eof
)
if not "%fname:jdk8u=%"=="" (
    set "sln=jdk8"
    goto:eof
)
if not "%fname:OpenJDK=%"=="" (
    set "sln=%fname:OpenJDK=%"
    for /f "tokens=1 delims=U" %%f in ('echo !sln!') do ( set "sln=jdk%%f" )
    goto:eof
)
if not "%fname:apache-maven-=%"=="" (
    set "sln=mvn%fname:apache-maven-%"
    goto:eof
)
set "sln="
goto:eof