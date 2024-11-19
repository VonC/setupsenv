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

set "profile_filename="
if exist "%HOME%\bin\profile" ( set "profile_filename=%HOME%\bin\profile")
if not defined profile_filename (
    if exist "%PRGS%\senv\custom\profile"  ( set "profile_filename=%PRGS%\senv\custom\profile")
)

set "profile_name="
if defined profile_filename (
    for /f %%a in (%profile_filename%) do ( set profile_name=%%a)
    %_info% "[%~nx0] profile name found: '!profile_name!'"
)
if not defined profile_name ( goto:proceed)
set s="setupsdir_%profile_name%.bat"
set "custom_dir=%PRGS%\senv\custom"
if not exist "%custom_dir%\%s%" (
    %_fatal% "[%~nx0] setupsdir script '%s%' does not exist" 2
)
call "%custom_dir%\%s%"
if errorlevel 1 (
    %_error% "[%~nx0] Unable to call '%custom_dir%\%s%'" && exit /b 1)
)

:proceed
%_info% "[%~nx0] Install '%~2', dl_dir='%dl_dir%', setup_dir='%setup_dir%', remote setupsdir='%setupsdir%'"

if "%~2"=="" (
    %_fatal%  "Usage: inst_prg (prgname) (pattern) (pattern to search for in Downloads or local setup or remote setup) (symlink name, default to current)." 4
)

call "%script_dir%\select_prg.bat" "%~1"
if not defined prg_id (
    %_fatal% "[%~nx0] empty prg_id after selecting prg from '%prg_name%'" 9
)

set "sfound=setup"
set "sfound_path=%setup_dir%"
call:check_folder "%sfound_path%" "%~2"
if not errorlevel 1 ( goto:count )
set "sfound=Downloads"
set "sfound_path=%dl_dir%"
call:check_folder "%sfound_path%" "%~2"
if not errorlevel 1 ( goto:count )
set "sfound=remote setup"
set "sfound_path=%setupsdir%"
call:check_folder "%sfound_path%" "%~2"
if not errorlevel 1 ( goto:count )
if not exist "%USERPROFILE%\senv_setups\setups" (goto:not_found)
set "sfound=user setup"
set "sfound_path=%USERPROFILE%\senv_setups\setups"
call:check_folder "%sfound_path%" "%~2"
if not errorlevel 1 ( goto:count )
:not_found
%_fatal%  "No '%~2' pattern found in Downloads or local or remote setup dirs" 6

:count
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

if not "%sfound%"=="setup" (
    %_task% "[%~nx0] Must move match '%fname%' from '%sfound%' to local setup"
    rem call:rbc dst src
    call:rbc "%setup_dir%" "%sfound_path%"
    %_ok% "[%~nx0] '%fname%' moved from '%sfound%' ('%sfound_path%') to local setup ('%%')"
)
if exist "%dl_dir%\%fname%" (
    del "%dl_dir%\%fname%" || %_fatal% "[%~nx0] Unable to delete '%dl_dir%\%fname%'" 88
)

set "prg_name=%~1"

:: Symlink name, default to current if no name returned by :symlink_name
set "sln=%~3"
if not defined sln ( call:symlink_name "%fname%" )
if not defined sln ( set "sln=current" )

set "prgs_folder=%prg_id%s"

if not exist "%PRGS%\%prgs_folder%" (
    %_task% "[%~nx0] Must create folder '%PRGS%\%prgs_folder%'"
    mkdir "%PRGS%\%prgs_folder%" || %_fatal% "[%~nx0] Unable to create folder '%PRGS%\%prgs_folder%'" 3
    %_ok% "[%~nx0] Folder '%PRGS%\%prgs_folder%' created"
)

if not exist "%PRGS%\%prgs_folder%" (
    %_fatal% "[%~nx0] Target folder '%PRGS%\%prgs_folder%' does not exist"
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
set "dst=%~1"
set "src=%~2"
if "%src%"=="" ( set "src=%setup_dir%" )
call "%script_dir%\rbc.bat" "%src%" "%dst%" "%fname%"
if not "%ERRORLEVEL%"=="0" ( %_fatal% "[%~nx0] Unable to copy '%src%\%fname%' to '%dst%\' errorlevel '%ERRORLEVEL%'" && exit /b 1)
%_ok% "[%~nx0] Setup '%fname%' copied locally to '%dst%'"
goto:eof

:symlink_name
set "fname=%~1"
if not "%fname:node-v=%"=="%fname%" (
    set "sln=%fname:node-v=%"
    for /f "tokens=1 delims=." %%f in ('echo !sln!') do ( set "sln=node%%f" )
    goto:eof
)
if not "%fname:python-=%"=="%fname%" (
    set "sln=%fname:python-=%"
    for /f "tokens=1 delims=-" %%f in ('echo !sln!') do ( set "sln=python%%f" )
    goto:eof
)
if not "%fname:jdk8u=%"=="%fname%" (
    set "sln=jdk8"
    goto:eof
)
if not "%fname:OpenJDK=%"=="%fname%" (
    set "sln=%fname:OpenJDK=%"
    for /f "tokens=1 delims=U" %%f in ('echo !sln!') do ( set "sln=jdk%%f" )
    goto:eof
)
if not "%fname:apache-maven-=%"=="%fname%" (
    set "sln=mvn%fname:apache-maven-%"
    goto:eof
)
set "sln="
goto:eof

:check_folder
set "folder=%~1"
set "pattern=%~2"
%_info% "[%~nx0]   Check folder '%folder%' for pattern '%pattern%'"
dir /b "%folder%\%pattern%" >a 2>NUL
if not errorlevel 1 ( goto:eof )
rem if env var pattern value does not start with '*', add '*' at its beginning
set "start_pattern="
if not "%pattern:~0,1%"=="*" set "start_pattern=*%pattern%"
if defined start_pattern (
    %_info% "[%~nx0]   Check folder '%folder%' for start pattern '%start_pattern%'"
    dir /b "%folder%\%start_pattern%" >a 2>NUL
    if not errorlevel 1 (
        set "pattern=%start_pattern%"
        goto:eof
    )
)
rem if env var pattern value does not end with '*', add '*' at its end
set "end_pattern="
if not "%pattern:~-1%"=="*" set "end_pattern=%pattern%*"
if defined end_pattern (
    %_info% "[%~nx0]   Check folder '%folder%' for end pattern '%end_pattern%'"
    dir /b "%folder%\%end_pattern%" >a 2>NUL
    if not errorlevel 1 (
        set "pattern=%end_pattern%"
        goto:eof
    )
)
if defined start_pattern (
    if defined end_pattern (
        set "pattern=*%pattern%*"
        %_info% "[%~nx0]   Check folder '%folder%' for start-end pattern '!pattern!'"
        dir /b "%folder%\!pattern!" >a 2>NUL
        if not errorlevel 1 ( goto:eof )
    )
)
set "pattern="
exit /b 1