@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "setup_ini_standalone="
if exist "echos_macros.bat" (
    call "echos_macros.bat"
) else if exist ..\batcolors\echos_macros.bat (
    call ..\batcolors\echos_macros.bat
    set "setup_ini_standalone=true"
) else (
    echo echos_macros is missing 1>&2
    exit /b 1
)
%_info% "script_dir='%script_dir%'"

if not "%HOME%"=="" (
	%_info% "HOME already set to '%HOME%': is HOME registered in senv.local.pre.bat?"
	rem dir "%HOME%\bin\senv.local.pre.bat"
	if not exist "%HOME%\bin\senv.local.pre.bat" ( 
		%_info% "No check: '%HOME%\bin\senv.local.pre.bat' does not exist yet"
		goto:check_home_created
	)
	:: Test if file is empty
	findstr /r "." "%HOME%\bin\senv.local.pre.bat" >nul || (
		%_info% "No check: '%HOME%\bin\senv.local.pre.bat' is empty"
		goto:check_home_created
	)
	%_task% "senv.local.pre.bat exists and is not empty: must check its registers HOME"
)
rem @echo on
set "vch="
%_info% "HOME is '%HOME%'"
if "%HOME%"=="" (
	set "HOME=%USERPROFILE%\home_senv"
	%_info% "HOME was empty, set to default value '%HOME%'"
	goto:check_home_created
)
for /f "tokens=1,2 delims==" %%i in ('type "%HOME%\bin\senv.local.pre.bat" ^| findstr /R /C:"set [^_]*HOME=.*"') do SET "vch_key=%%i" && SET "vch=%%j" )
rem %_info% "vch -1 is '%vch%'"
rem @echo on
set "vch_key=%vch_key:"=%"
set "vch_key=%vch_key:set =%"
set "vch=%vch:"=%"
%_info% "vch 0 is '%vch%' for key '%vch_key%' in senv.local.pre.bat"
if not "%vch_key%"=="HOME" (
	%_fatal% "HOME '%vch%' registered in senv.local.pre.bat for wrong key '%vch_key%' in senv.local.pre.bat" 2
)

if not "%vch%"=="%HOME%" (
	%_error% "vch ='%vch%'"
	%_error% "HOME='%HOME%'"
	%_fatal% "Existing HOME '%HOME%' differs from registered HOME '%vch%'" 2
)
%_ok% "HOME '%HOME%' confirmed in '%HOME%\bin\senv.local.pre.bat'"
call "%HOME%\bin\senv.local.pre.bat"

:check_home_created
if not exist "%HOME%" (
	%_info% "Create '%HOME%' folder"
	mkdir "%HOME%"
	if not exist "%HOME%" (
		%_fatal% "Unable to create HOME '%HOME%'" 1
	)
	%_ok% "HOME '%HOME% created"
) else (
	%_ok% "HOME '%HOME%' already created"
)

if exist "%HOME%\bin\senv.bat" (
    if not "%PRGS%"=="" (
        if not "%PROG%"=="" (
            %_ok% "PRGS '%PRGS%' and PROG '%PROG%' already set: senv_noconfirm set."
            set senv_noconfirm=1
        )
    )
)

%_info% "HOME0 is '%HOME%', REMOTE_HOME is '%REMOTE_HOME%' before detection"

if "%REMOTE_HOME%"=="" (
	set "REMOTE_HOME=%HOMEDRIVE%\remote_home_senv"
	if not exist "!REMOTE_HOME!" (
		%_task% "Must create REMOTE_HOME on '%HOMEDRIVE%\remote_home_senv'"
		mkdir "!REMOTE_HOME!"
		if not exist "!REMOTE_HOME!" (
			%_error% "Unable to create REMOTE_HOME '!REMOTE_HOME!' on HOMEDRIVE='%HOMEDRIVE%', try USERPROFILE"
			set "REMOTE_HOME=%USERPROFILE%\remote_home_senv"
			%_task% "Must create REMOTE_HOME on '!REMOTE_HOME!' using USERPROFILE"
			mkdir "!REMOTE_HOME!"
			if not exist "!REMOTE_HOME!" (
				%_fatal% "Unable to create REMOTE_HOME '!REMOTE_HOME!' on USERPROFILE='%USERPROFILE%'" 12
			)
		)
		%_ok% "REMOTE_HOME '!REMOTE_HOME!' created"
	) else (
		%_ok% "REMOTE_HOME '!REMOTE_HOME!' already exists"
	)
)

%_info% "HOME is '%HOME%'"
%_info% "REMOTE_HOME is '%REMOTE_HOME%'"
%_info% "PRGS0 is '%PRGS%'"

if "%PRGS%"=="" ( call :set_prgs "C:\Public" )
if "%PRGS%"=="" ( call :set_prgs "%USERPROFILE%" )
if "%PRGS%"=="" ( %_fatal% "PRGS environment variable '%PRGS%' not set" 1 )
%_info% "PRGS set to '%PRGS%'"

if "%PROG%"=="" ( call :set_prog "%USERPROFILE%" )
if "%PROG%"=="" ( %_fatal% "PROG environment variable '%PROG%' not set" 1 )
%_info% "PROG set to '%PROG%'"

if not "%1"=="" (
	%_warning% "Skip HOME/PRGS/PROG detection/confirmation, because of non-empty first parameter '%1'"
	goto:set_environment_variables
)
:PROMPT
if not "%senv_noconfirm%"=="" (
	%_ok% "Skip HOME/PRGS/PROG detection/confirmation, because of non-empty senv_noconfirm '%senv_noconfirm%'"
	goto:set_environment_variables
)
SET /P AREYOUSURE=Do you confirm HOME ('%HOME%'), REMOTE_HOME ('%REMOTE_HOME%'), PRGS ('%PRGS%') and PROG ('%PROG%') (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" (
	set HOME=
	set PRGS=
	set PROG=
	exit /b 1
)
goto:set_environment_variables

:set_prgs
set "drive=%~1"
set PRGS=
set "prefix=%drive%:"
if "%drive%"=="C:\Public" (
	set "prefix=%drive%"
	set "drive=C"
)
if "%drive%"=="%USERPROFILE%" (
	set "prefix=%drive%"
	set "drive=C"
)
if not exist "%prefix%\" (%_warning% "Skip non-existant PRGS prefix %prefix%\ for PRGS"&& goto:eof )
if exist %prefix%\nosoft ( %_warning% "Skip drive %drive%:\ for PRGS"&& goto:eof )
if exist %prefix%\SOFTWARE ( set "PRGS=%prefix%\SOFTWARE"&& %_ok% "Use existing '%prefix%\SOFTWARE' for PRGS"&& goto:eof )
if "%PRGS%"=="" (
	mkdir "%prefix%\SOFTWARE"
	if errorlevel 1 ( %_warning% "Unable to create SOFTWARE in '%prefix%' for PRGS"; goto:eof )
	set "PRGS=%prefix%\SOFTWARE"
)
dir "%PRGS%" 1>NUL: 2>NUL:
if errorlevel 1 (
    %_warning% "Unable to access %prefix%\SOFTWARE path for PRGS '%PRGS%'"
	set PRGS=
)
goto:eof

:set_prog
set "drive=%~1"
set PROG=
set "prefix=%drive%:"
if "%drive%"=="%USERPROFILE%" (
	set "prefix=C:\Users"
	set "drive=C"
)
if not exist "%prefix%\" (%_warning% "Skip non-existant prefix %prefix%\ for PROG"&& goto:eof )
if exist %prefix%\nodata ( %_warning% "Skip drive %drive%:\ for PROG"&& goto:eof )
if exist %prefix%\%USERNAME% ( set "PROG=%prefix%\%USERNAME%"&& %_ok% "Use existing '%prefix%\%USERNAME%' for PROG" )
if "%PROG%"=="" (
	mkdir "%prefix%\%USERNAME%"
	if errorlevel 1 ( %_warning% "Unable to create PROG '%USERNAME%' in prefix '%prefix%:\'"&& goto:eof )
	set "PROG=%prefix%\%USERNAME%"
)
dir "%PROG%" 1>NUL: 2>NUL:
if errorlevel 1 (
    %_warning% "Unable to access prefix '%prefix%\%USERNAME%' path for PROG '%PROG%'"
	set PROG=
)
goto:eof

:set_environment_variables
rem Always export the four location variables to the caller: setup.bat,
rem remote_setup.bat and getstarted.bat all rely on them after this call.
endlocal & set "HOME=%HOME%" & set "REMOTE_HOME=%REMOTE_HOME%" & set "PRGS=%PRGS%" & set "PROG=%PROG%"
goto:eof


:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
