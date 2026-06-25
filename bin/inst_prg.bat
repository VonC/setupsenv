@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

%_info% "'script_dir(inst_prg)='%script_dir%'"
set "install_dir=%senv_dir%\installs"
rem set "custom_install_dir=%senv_dir%\custom\installs"

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
    %_info% "Usage:"
    del "%script_dir%\%man_file%" 2>NUL
    set "ECHOS_POST_FILE="
    goto:eof
)

set "prg_name=%~1"
echo %prg_name% | findstr /C:"*" >nul 2>&1
if errorlevel 1 (
    call "%script_dir%\select_prg.bat" "%~1" "inst_prg"
    if not defined prg_id (
        %_fatal% "empty prg_id after selecting prg from '%prg_name%'" 9
    )
    if defined prg_pattern (
        if not "!prg_pattern!"=="%~2" (
            if not "%~2"=="latest" (
                if not "%~2"=="" (
                    for /f "tokens=1,2 delims=*" %%p in ('echo !prg_pattern!') do (
                        set "prg_pattern=%%p*%~2*%%q"
                    )
                ) else ( set "prg_pattern=!prg_pattern!-latest" )
            ) else (
                set "prg_pattern=!prg_pattern!-latest"
            )
        )
    ) else (
        if not "%~2"=="" ( set "prg_pattern=%~2" ) else ( set "prg_pattern=latest" )
    )
) else (
    set "prg_name=ls"
    set "prg_pattern=%~1"
    %_info% "Mode 'ls' activated: prg_pattern='!prg_pattern!'"
)
if "%prg_id%"=="sqldeveloper" (
    if "%~2"=="" ( set "prg_pattern=sqldeveloper-*.*-x64.zip-latest" )
    if "%~2"=="latest" ( set "prg_pattern=sqldeveloper-*.*-x64.zip-latest" )
)
%_info% "prg_name='%prg_name%', prg_pattern='%prg_pattern%'"

pushd "%USERPROFILE%\Downloads"
if errorlevel 1 %_fatal% "Unable to access '%USERPROFILE%\Downloads')'" 5
for /F "delims=" %%f in ('cd') do ( set dl_dir=%%f)
popd

if defined INST_PRG_DEBUG (
    %_ok% "INST_PRG_DEBUG defined, all intermediate messages will be displayed"
) else (
    %_warning% "INST_PRG_DEBUG not defined, only final profile and folder names will be displayed"
    set "ECHOS_OFF=1"
)
set "profile_filename="
if exist "%HOME%\bin\profile" ( set "profile_filename=%HOME%\bin\profile")
if not defined profile_filename (
    if exist "%PRGS%\senv\custom\profile"  ( set "profile_filename=%PRGS%\senv\custom\profile")
)

set "profile_name="
if not defined profile_filename ( goto:check_profile_name )
for /f %%a in (%profile_filename%) do ( set "profile_name=%%a" )
%_info% "profile name found: '%profile_name%'"

:check_profile_name
if not defined profile_name ( goto:_proceed)
echo calling 'setupsdir_%profile_name%.bat'
set "s=setupsdir_%profile_name%.bat"
set "custom_dir=%PRGS%\senv\custom"
if not exist "%custom_dir%\%s%" (
    %_fatal% "setupsdir script '%s%' does not exist" 2
)
call "%custom_dir%\%s%"
if errorlevel 1 (
    %_fatal% "Unable to call '%custom_dir%\%s%'" 111)
)

:_proceed
set "ECHOS_OFF="
(
echo - dl_dir          ='%dl_dir%'
echo - setup_dir       ='%setup_dir%'
echo - remote setupsdir='%setupsdir%'
echo -------------------------------------
) > "post_FILE.txt"
set "ECHOS_POST_FILE=post_FILE.txt"
%_info% "Install '%prg_name%' for profile '%profile_name%', pattern '%prg_pattern%'"
set "ECHOS_POST_FILE="
del "post_FILE.txt"

set "sfound=setup"
set "sfound_path=%setup_dir%"
set "sfound_most_recent="
set "sfound_most_recent_folder="
set "sfound_most_recent_name="
call:check_patterns "%sfound_path%" "%prg_pattern%"
if "%check_patterns_res%"=="0" ( goto:_count )
set "sfound=Downloads"
set "sfound_path=%dl_dir%"
call:check_patterns "%sfound_path%" "%prg_pattern%"
if "%check_patterns_res%"=="0" ( goto:_count )
set "sfound=remote setup"
set "sfound_path=%setupsdir%"
call:check_patterns "%sfound_path%" "%prg_pattern%"
if "%check_patterns_res%"=="0" ( goto:_count )
if not exist "%USERPROFILE%\senv_setups\setups" (goto:_not_found)
set "sfound=user setup"
set "sfound_path=%USERPROFILE%\senv_setups\setups"
call:check_patterns "%sfound_path%" "%prg_pattern%"
if "%check_patterns_res%"=="0" ( goto:_count )
:_not_found
if defined sfound_most_recent (
    %_info% "sfound_most_recent='%sfound_most_recent%' in '%sfound_most_recent_folder%'"
    set "sfound_path=%sfound_most_recent_folder%"
    set "sfound=%sfound_most_recent_name%"
    %_info% "One latest match found in '!sfound!': fname '%fname%' in '!sfound_path!'"
    goto:_proceed_install
)
if not "%prg_pattern:python-=%"=="%prg_pattern%" (
    if not "%prg_pattern:.zip=%"=="%prg_pattern%" (
        %_error% "No '%prg_pattern%' pattern found in Downloads or local or remote setup dirs"
        %_info% "try pythons.install %~2"
        pythons.install.bat %~2
        if not errorlevel 1 (
             %_ok% "Python %~2 installed"
            goto:_skip_checks
        )
    )
)
%_fatal%  "No '%prg_pattern%' pattern found in Downloads or local or remote setup dirs" 6

:_count
rem https://stackoverflow.com/questions/42000037/how-to-count-the-occurrence-of-a-variable-in-log-file-matching-a-pattern-regex-i
set COUNT=0
for /F "tokens=*" %%N in (a) do set /a COUNT+=1
if not "%count%"=="1" (
        type a
        del a 2>NUL
        %_fatal%  "'%count%' (More than one match) in '%sfound%' for pattern '%~2'" 7
)
for /F "delims=" %%f in (a) do ( set fname=%%f)
%_info% "One match found in '%sfound%': '%fname%'"
del a
:_proceed_install
if not "%sfound%"=="setup" (
    %_task% "Must move match '%fname%' from '%sfound%' to local setup"
    rem call:rbc dst src
    call:rbc "%setup_dir%" "%sfound_path%"
    %_ok% "'%fname%' moved from '%sfound%' ('%sfound_path%') to local setup ('%%')"
)
if exist "%dl_dir%\%fname%" (
    del "%dl_dir%\%fname%"
    if errorlevel 1 %_fatal% "Unable to delete '%dl_dir%\%fname%'" 88
)

set "prg_name=%~1"

:: Symlink name, default to current if no name returned by :symlink_name
set "sln=%~3"
if not defined sln ( call:symlink_name "%fname%" )
if not defined sln ( set "sln=current" )

set "prgs_folder=%prg_id%s"

if not exist "%PRGS%\%prgs_folder%" (
    %_task% "Must create folder '%PRGS%\%prgs_folder%'"
    mkdir "%PRGS%\%prgs_folder%"
    if errorlevel 1 %_fatal% "Unable to create folder '%PRGS%\%prgs_folder%'" 3
    %_ok% "Folder '%PRGS%\%prgs_folder%' created"
)

if not exist "%PRGS%\%prgs_folder%" (
    %_fatal% "Target folder '%PRGS%\%prgs_folder%' does not exist"
)

for /F "usebackq" %%i in (`dir /OD /B "%setup_dir%\%fname%"`) do set "prg_folder=%%~ni"
if "%prgs_folder%"=="sqldevelopers" ( call:check_sqldeveloper_archive )

%_task% "'%prg_name%': Must check/install fname '%fname%' from '%setup_dir%' to '%PRGS%\%prgs_folder%\%prg_folder%' with symlink name '%sln%'"

if exist "%PRGS%\%prgs_folder%\%prg_folder%" (
    %_ok% "Program '%prg_folder%' already exists in '%PRGS%\%prgs_folder%'"
    goto:_check_post_install
)

set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe
pushd "%PRGS%\%prgs_folder%"
if errorlevel 1 %_fatal% "Unable to access '%PRGS%\%prgs_folder%'" 8
if not exist "%fname%" (
    call:rbc "%PRGS%\%prgs_folder%"
)

if exist "%install_dir%\%prgs_folder%.install.bat" (
    %_task% "Must use custom '%install_dir%' for '%prgs_folder%' arg sln '%sln%'"
    set "NO_DRY_RUN=1"
    call "%install_dir%\%prgs_folder%.install.bat" "%sln%"
    set "NO_DRY_RUN="
    goto:_check_symlink
) else (
    %_ok% "No custom install '%prgs_folder%.install.bat' in '%install_dir%' for '%prgs_folder%'"
)

if exist "%PRGS%\senv\installs\%prgs_folder%.install.bat" (
    %_task% "Must use PRGS senv custom '%PRGS%\senv\installs' for '%prgs_folder%'"
    call "%PRGS%\senv\installs\%prgs_folder%.install.bat"
    goto:_check_symlink
) else (
    %_ok% "No custom install '%prgs_folder%.install.bat' in '%PRGS%\senv\installs' for '%prgs_folder%'"
)

%_task% "Must uncompress with 7z '%PRGS%\setup\%fname%' to '%PRGS%\%prgs_folder%'"
call "%HOME%\bin\pzxx.bat" "%PRGS%\%prgs_folder%\%fname%"
if errorlevel 1 (
    rm -Rf "%PRGS%\%prgs_folder%\%prgs_folder%"
    popd
    %_fatal% "Error on 7z uncompression of '%fname%' to '%PRGS%\%prgs_folder%\%prgs_folder%'" 1
)
%_ok% "'%fname%' uncompressed (7z) to '%PRGS%\%prgs_folder%\%prgs_folder%'"

rem Check if we're dealing with a .tar.xz file that needs additional extraction
if not "%fname:~-7%"==".tar.xz" goto:_skip_tar_extraction

set "tar_folder=%fname:.tar.xz=.tar%"
if exist "%PRGS%\%prgs_folder%\%tar_folder%" (
    %_task% "Found .tar.xz file, must extract the .tar file in '%tar_folder%' folder"
    pushd "%PRGS%\%prgs_folder%\%tar_folder%"
    
    rem Find the .tar file in the folder
    for /f "delims=" %%t in ('dir /b *.tar 2^>nul') do (
        %_task% "Extracting %%t in the current directory"
        call "%HOME%\bin\pzxx.bat" "%%t"
        if errorlevel 1 (
            popd
            %_fatal% "Error on 7z uncompression of '%%t' in '%PRGS%\%prgs_folder%\%tar_folder%'" 1
        )
        %_ok% "Successfully extracted the tar file '%%t'"
        %_task% "Removing the tar file '%%t' after extraction"
        del "%%t"
        if errorlevel 1 (
            popd
            %_fatal% "Unable to delete '%%t' in '%PRGS%\%prgs_folder%\%tar_folder%'" 1
        )
        %_ok% "Tar file '%%t' removed after extraction"
    )
    popd
)

:_skip_tar_extraction

:_check_post_install
if exist "%install_dir%\%prgs_folder%.post.bat" (
    %_task% "Must use post-install in '%install_dir%' for '%prgs_folder%'"
    call "%install_dir%\%prgs_folder%.post.bat"
    goto:_check_symlink
)

:_check_symlink
%_task% "Must check symlink '%sln%' for '%prg_folder%' in '%PRGS%\%prgs_folder%'"
call "%script_dir%\check_prg_symlink.bat" "%prgs_folder%" "%prg_folder%" "%sln%"

if exist "%install_dir%\%prgs_folder%.alias.bat" (
    %_task% "Must check alias in '%install_dir%' for '%prgs_folder%'"
    call "%install_dir%\%prgs_folder%.alias.bat"
)
:_skip_checks

popd
endlocal
DOSKEY /MACROFILE="%HOME%\bin\senv.local.doskey"
goto:eof

:rbc
cd
set "dst=%~1"
set "src=%~2"
if "%src%"=="" ( set "src=%setup_dir%" )
call "%script_dir%\rbc.bat" "%src%" "%dst%" "%fname%"
set "rbc_res=%ERRORLEVEL%"
if not "%rbc_res%"=="0" ( %_fatal% "Unable to copy '%src%\%fname%' to '%dst%\' errorlevel '%rbc_res%'" && exit /b 1 && goto:eof )
%_ok% "Setup '%fname%' copied locally to '%dst%'"
goto:eof

:check_sqldeveloper_archive
if "%fname:sqldeveloper-=%"=="%fname%" (
    %_fatal% "SQL Developer installation requires a sqldeveloper archive, not '%fname%'" 93
)
if "%fname:-x64.zip=%"=="%fname%" (
    %_fatal% "SQL Developer installation requires a Windows x64 zip archive with a version, not '%fname%'" 94
)
set "sqldeveloper_version=%fname:sqldeveloper-=%"
set "sqldeveloper_version=%sqldeveloper_version:-x64.zip=%"
if "%sqldeveloper_version%"=="latest" (
    %_fatal% "SQL Developer installation requires the versioned Oracle archive, not '%fname%'" 95
)
echo.%sqldeveloper_version%| findstr /R /C:"^[0-9]" >nul
if errorlevel 1 (
    %_fatal% "SQL Developer archive '%fname%' does not expose a numeric Oracle version" 96
)
set "prg_folder=sqldeveloper-%sqldeveloper_version%-x64"
%_ok% "SQL Developer version '%sqldeveloper_version%' derived from archive '%fname%'"
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
    set "sln=mvn%fname:apache-maven-=%"
    set "sln=!sln:-bin.zip=!"
    goto:eof
)
if not "%fname:wildfly-=%"=="%fname%" (
    set "sln=%fname:wildfly-=%"
    for /f "tokens=1 delims=." %%a in ("!sln!") do (
        set "sln=wildfly%%a"
    )
    goto:eof
)
set "sln="
goto:eof

:check_folder
set "folder=%~1"
set "pattern=%~2"
set "check_folder_res=1"
if not "%pattern:latest=%"=="%pattern%" ( goto:record_latest )
if "%prg_name%"=="ls" ( %_task% "Ls: Must look for '%prg_pattern%' in '%folder%'" ) else (
    %_info% "  Check folder '%folder%' for pattern '%pattern%'" )
dir /b "%folder%\%pattern%" >a 2>NUL
if not errorlevel 1 (
    if not "%prg_name%"=="ls" (
        set "check_folder_res=0"
        exit /b 0
        goto:eof
    )
    %_ok% "Ls: pattern '%pattern%' found in '%folder%'"
    dir /B /OD "%folder%\%pattern%"
    exit /b 1
    goto:eof
)
if "%prg_name%"=="ls" (
    %_error% "Ls: No '%prg_pattern%' pattern found in '%folder%'"
    exit /b 1
    goto:eof
)
rem if env var pattern value does not start with '*', add '*' at its beginning
set "start_pattern="
if not "%pattern:~0,1%"=="*" set "start_pattern=*%pattern%"
if defined start_pattern (
    %_info% "  Check folder '%folder%' for start pattern '%start_pattern%'"
    dir /b "%folder%\%start_pattern%" >a 2>NUL
    if not errorlevel 1 (
        set "pattern=%start_pattern%"
        set "check_folder_res=0"
        exit /b 0
        goto:eof
    )
)
rem if env var pattern value does not end with '*', add '*' at its end
set "end_pattern="
if not "%pattern:~-1%"=="*" set "end_pattern=%pattern%*"
if defined end_pattern (
    %_info% "  Check folder '%folder%' for end pattern '%end_pattern%'"
    dir /b "%folder%\%end_pattern%" >a 2>NUL
    if not errorlevel 1 (
        set "pattern=%end_pattern%"
        set "check_folder_res=0"
        exit /b 0
        goto:eof
    )
)
if defined start_pattern (
    if defined end_pattern (
        set "pattern=*%pattern%*"
        %_info% "  Check folder '%folder%' for start-end pattern '!pattern!'"
        dir /b "%folder%\!pattern!" >a 2>NUL
        if not errorlevel 1 ( exit /b 0 && goto:eof )
    )
)
set "pattern="
exit /b 1
goto:eof

:record_latest
if "%pattern:latest=%"=="" ( set "pattern=%prg_pattern%" ) else ( set "pattern=%pattern:-latest=%" )
if not defined pattern ( %_fatal% "check_folder/record_latest: pattern empty from '%~2'" 33 )
%_info% "  Record latest from folder '%folder%' for pattern '%pattern%', prg_pattern='%prg_pattern%'"
for /f "tokens=*" %%a in ('powershell -ExecutionPolicy Bypass -File "%script_dir%\dir_by_date.ps1" "%folder%" "%pattern%" "%sfound_most_recent%"') do (
    %_info% "Found most recent '%%a' in '%folder%' for pattern '%pattern%', vs. sfound_most_recent '%sfound_most_recent%'"
    if defined sfound_most_recent (
        if not "!sfound_most_recent!"=="%%a" (
            set "sfound_most_recent_folder=%folder%"
            set "fname=%%a"
            set "fname=!fname:* =!"
            set "sfound_most_recent_name=%sfound%"
            %_ok% "set new sfound_most_recent_folder '!sfound_most_recent_folder!' (!sfound_most_recent_name!), fname '!fname!'"
        ) else (
            %_warning% "sfound_most_recent unchanged ('%%a'), keep '!sfound_most_recent_folder!' (!sfound_most_recent_name!), fname '!fname!'"
        )
    ) else (
        set "sfound_most_recent_folder=%folder%"
        set "fname=%%a"
        set "fname=!fname:* =!"
        set "sfound_most_recent_name=%sfound%"
        %_ok% "sfound_most_recent not defined, set sfound_most_recent_folder '!sfound_most_recent_folder!' (!sfound_most_recent_name!), fname '!fname!'"
    )
    set "sfound_most_recent=%%a"
)
exit /b 1
goto:eof


// Add this new subroutine before the :eof

:check_patterns
set "folder=%~1"
set "pattern_list=%~2"
set "check_patterns_res=1"
%_info% "Checking patterns '%pattern_list%' in folder '%folder%'"

REM Check if pattern contains multiple patterns separated by /
echo %pattern_list% | findstr /C:"/" >nul
if errorlevel 1 (
    REM No / separator found, use the original check_folder
    call:check_folder "%folder%" "%pattern_list%"
    set "check_patterns_res=!check_folder_res!"
    exit /b !check_folder_res!
    goto:eof
)

REM Process each pattern separated by /
for /F "tokens=1* delims=/" %%a in ("%pattern_list%") do (
    %_info% "Trying pattern '%%a' in '%folder%'"
    call:check_folder "%folder%" "%%a"
    if "!check_folder_res!"=="0" (
        set "check_patterns_res=!check_folder_res!"
        exit /b 0
        goto:eof
    )
    
    if not "%%b"=="" (
        REM More patterns to check
        call:check_patterns "%folder%" "%%b"
        exit /b !check_patterns_res!
        goto:eof
    )
)

exit /b 1
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
