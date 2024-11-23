@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

%_info% "[%~nx0] 'script_dir(inst_prg)='%script_dir%'"

:: Define the output file
set "man_file=man_inst_prg.txt"

:: Echo the man-like usage message into the file
(
echo _
echo NAME
echo     inst_prg.bat - Install a program from a specified source
echo _
echo SYNOPSIS
echo     inst_prg.bat [prgname] [pattern or latest] [symlink name]
echo -
echo DESCRIPTION
echo     This script installs a program by searching for the specified pattern in various directories and optionally creates a symlink.
echo _
echo     prgname
echo         ^(Optional^) The name of the program to install. Display the list of programs to choose from if not specified.
echo _
echo     pattern or latest
echo         ^(Optional^) The pattern to search for in the specified directories or the keyword 'latest' to use the most recent version. Defaults to 'latest' if not specified.
echo _
echo     symlink name
echo         ^(Optional^) The name of the symlink to create. Defaults to 'current' if not specified.
echo _
echo EXAMPLES
echo     inst_prg.bat myprogram
echo         Install the latest version of 'myprogram' and create a symlink named 'current'.
echo _
echo     inst_prg.bat myprogram "myprogram-1.0.*"
echo         Install 'myprogram' version 1.0 from the specified pattern and create a symlink named 'current'.
echo _
echo     inst_prg.bat myprogram "myprogram-1.0.*" myprogram_symlink
echo         Install 'myprogram' version 1.0 from the specified pattern and create a symlink named 'myprogram_symlink'.
echo _
echo AUTHOR
echo     VonC
) > "%script_dir%\%man_file%"

set "ECHOS_POST_FILE="
if "%~1"=="/?" ( set "ECHOS_POST_FILE=%script_dir%\%man_file%" )
if "%~1"=="-h" ( set "ECHOS_POST_FILE=%script_dir%\%man_file%" )
if "%~1"=="--help" ( set "ECHOS_POST_FILE=%script_dir%\%man_file%" )
if defined ECHOS_POST_FILE (
    %_info% "[%~nx0] Usage:"
    del "%script_dir%\%man_file%" 2>NUL
    set "ECHOS_POST_FILE="
    goto:eof
)

set "prg_name=%~1"
echo %prg_name% | findstr /C:"*" >nul 2>&1
if errorlevel 1 (
    call "%script_dir%\select_prg.bat" "%~1"
    if not defined prg_id (
        %_fatal% "[%~nx0] empty prg_id after selecting prg from '%prg_name%'" 9
    )
    if defined prg_pattern (
        if not "!prg_pattern!"=="%~2" (
            if not "%~2"=="" ( set "prg_pattern=%~2" ) else ( set "prg_pattern=!prg_pattern!-latest" )
        )
    ) else (
        if not "%~2"=="" ( set "prg_pattern=%~2" ) else ( set "prg_pattern=latest" )
    )
) else (
    set "prg_name=ls"
    set "prg_pattern=%~1"
    %_info% "[%~nx0] Mode 'ls' activated: prg_pattern='!prg_pattern!'"
)
rem %_info% "[%~nx0] prg_name='%prg_name%', prg_pattern='%prg_pattern%'"
rem goto:eof

pushd "%USERPROFILE%\Downloads" || %_fatal% "[%~nx0] Unable to access '%USERPROFILE%\Downloads')'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)
popd

if defined INST_PRG_DEBUG (
    %_ok% "[%~nx0] INST_PRG_DEBUG defined, all intermediate messages will be displayed"
) else (
    %_warning% "[%~nx0] INST_PRG_DEBUG not defined, only final profile and folder names will be displayed"
    set "ECHOS_OFF=1"
)
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
set "s=setupsdir_%profile_name%.bat"
set "custom_dir=%PRGS%\senv\custom"
if not exist "%custom_dir%\%s%" (
    %_fatal% "[%~nx0] setupsdir script '%s%' does not exist" 2
)
call "%custom_dir%\%s%"
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to call '%custom_dir%\%s%'" 111)
)

:proceed
set "ECHOS_OFF="
(
echo - dl_dir          ='%dl_dir%'
echo - setup_dir       ='%setup_dir%'
echo - remote setupsdir='%setupsdir%'
echo -------------------------------------
) > "post_FILE.txt"
set "ECHOS_POST_FILE=post_FILE.txt"
%_info% "[%~nx0] Install '%prg_name%' for profile '%profile_name%', pattern '%prg_pattern%'"
set "ECHOS_POST_FILE="
del "post_FILE.txt"

set "sfound=setup"
set "sfound_path=%setup_dir%"
set "sfound_most_recent="
set "sfound_most_recent_folder="
set "sfound_most_recent_name="
call:check_folder "%sfound_path%" "%prg_pattern%"
if not errorlevel 1 ( goto:count )
set "sfound=Downloads"
set "sfound_path=%dl_dir%"
call:check_folder "%sfound_path%" "%prg_pattern%"
if not errorlevel 1 ( goto:count )
set "sfound=remote setup"
set "sfound_path=%setupsdir%"
call:check_folder "%sfound_path%" "%prg_pattern%"
if not errorlevel 1 ( goto:count )
if not exist "%USERPROFILE%\senv_setups\setups" (goto:not_found)
set "sfound=user setup"
set "sfound_path=%USERPROFILE%\senv_setups\setups"
call:check_folder "%sfound_path%" "%prg_pattern%"
if not errorlevel 1 ( goto:count )
:not_found
if defined sfound_most_recent (
    %_info% "[%~nx0] sfound_most_recent='%sfound_most_recent%' in '%sfound_most_recent_folder%'"
    set "sfound_path=%sfound_most_recent_folder%"
    set "sfound=%sfound_most_recent_name%"
    %_info% "[%~nx0] One lastest match found in '!sfound!': '%fname%' in '!sfound_path!'"
    goto:proceed_install
)
%_fatal%  "No '%prg_pattern%' pattern found in Downloads or local or remote setup dirs" 6

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
:proceed_install
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
goto:eof

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
if not "%pattern:latest=%"=="%pattern%" ( goto:record_latest )
if "%prg_name%"=="ls" ( %_task% "[%~nx0] Ls: Must look for '%prg_pattern%' in '%folder%'" ) else (
    %_info% "[%~nx0]   Check folder '%folder%' for pattern '%pattern%'" )
dir /b "%folder%\%pattern%" >a 2>NUL
if not errorlevel 1 (
    if not "%prg_name%"=="ls" ( goto:eof )
    %_ok% "[%~nx0] Ls: pattern '%pattern%' found in '%folder%'"
    dir /B /OD "%folder%\%pattern%"
    exit /b 1
)
if "%prg_name%"=="ls" (
    %_error% "[%~nx0] Ls: No '%prg_pattern%' pattern found in '%folder%'"
    exit /b 1
)
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
:record_latest
if "%pattern:latest=%"=="" ( set "pattern=%prg_pattern%" ) else ( set "pattern=%pattern:-latest=%" )
if not defined pattern ( %_fatal% "[%~nx0] check_folder/record_latest: pattern empty from '%~2'" 33 )
%_info% "[%~nx0]   Record latest from folder '%folder%' for pattern '%pattern%'"
for /f "tokens=*" %%a in ('powershell -ExecutionPolicy Bypass -File "%script_dir%\dir_by_date.ps1" "%folder%" "%pattern%" "%sfound_most_recent%"') do (
    %_info% "[%~nx0] Found most recent '%%a' in '%folder%' for pattern '%pattern%', vs. sfound_most_recent '%sfound_most_recent%'"
    if defined sfound_most_recent (
        if not "!sfound_most_recent!"=="%%a" (
            set "sfound_most_recent_folder=%folder%"
            set "fname=%%a"
            set "sfound_most_recent_name=%sfound%"
            %_ok% "[%~nx0] set new sfound_most_recent_folder '!sfound_most_recent_folder!' (!sfound_most_recent_name!), fname '!fname!'"
        ) else (
            %_warning% "[%~nx0] sfound_most_recent unchanged ('%%a'), keep '!sfound_most_recent_folder!' (!sfound_most_recent_name!), fname '!fname!'"
        )
    ) else (
        set "sfound_most_recent_folder=%folder%"
        set "fname=%%a"
        set "sfound_most_recent_name=%sfound%"
        %_ok% "[%~nx0] sfound_most_recent not defined, set sfound_most_recent_folder '!sfound_most_recent_folder!' (!sfound_most_recent_name!), fname '!fname!'"
    )
    set "sfound_most_recent=%%a"
)
exit /b 1