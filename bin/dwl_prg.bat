@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%senv_dir%\..\setup") do (
    set "setup_dir=%%~fi"
)
if not defined SENV_DWL_SETUP_DIR (
    %_info% "[%~nx0] setup_dir='%setup_dir%' (SENV_DWL_SETUP_DIR not defined)"
) else (
    set "setup_dir=%SENV_DWL_SETUP_DIR%"
)
set "repo=%~1"
set "prgname=%~2"
set "template=%~3"

if "%repo%"=="" (
    %_fatal% "[%~nx0] repo must be provided (ex: charmbracelet/gum)" 1
)
rem @echo on
echo.%repo%| findstr /R /C:"^[a-Z0-9_-]*/[a-Z0-9_-]*$" >nul
rem echo %ERRORLEVEL%
if errorlevel 1 (
    %_fatal% "[%~nx0] repo must be in the format org/repo (ex: charmbracelet/gum)" 1
)

if "%prgname%"=="" (
    %_fatal% "[%~nx0] prgname must be provided (ex: gum)" 1
)
echo.%prgname%| findstr /R /C:"^[a-Z0-9_-]*$" >nul
rem echo %ERRORLEVEL%
if errorlevel 1 (
    %_fatal% "[%~nx0] prgname must be composed of letter, digits or _ (ex: gum)" 1
)
if not defined SENV_DWL_SCRIPT_NAME (
    set "SENV_DWL_SCRIPT_NAME=%prgname%"
)

set "SENV_DWL_FILE="
for /f "tokens=1,2 delims=~" %%i in ('echo %template%') do ( set "SENV_DWL_FILE=%%i" & set "SENV_DWL_URL=%%j" )
%_info% "[%~nx0] SENV_DWL_FILE='%SENV_DWL_FILE%', SENV_DWL_URL='%SENV_DWL_URL%'"

mkdir "%PRGS%\%prgsfolder%" 2> nul

call "%script_dir%\ensure_internet.bat"

:proceed
if defined SENV_DWL_VERSION (
    %_warning% "[%~nx0] SENV_DWL_VERSION set to '%SENV_DWL_VERSION%': no latest check"
    set "version=%SENV_DWL_VERSION%"
    goto:dr
)

%_info% "[%~nx0] Check latest '%repo%' version for '%prgname%' (SENV_DWL_VERSION not set)"
if not defined SENV_DWL_ASK_FOR_LATEST_VERSION ( goto:github_latest_version )
%_info% "[%~nx0] SENV_DWL_ASK_FOR_LATEST_VERSION defined, so ask latest version to 'dwl%SENV_DWL_SCRIPT_NAME%'"
for /f "delims=" %%i in ('call "%script_dir%\dwl%SENV_DWL_SCRIPT_NAME%.bat" :get_latest_version') do ( set "version=%%i" )
for /f "tokens=1,2 delims=#" %%i in ('echo %version%') do ( set "version=%%i" & set "SENV_DWL_URL=%%j" )
goto:dr


:github_latest_version
%_info% "[%~nx0] SENV_DWL_ASK_FOR_LATEST_VERSION not defined, so ask GitHub '%repo%' for latest version"
rem @echo on
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/%repo%/releases/latest"
echo.%cmd%

for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
echo.Latest version URL='%gu%'

for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
set "tag=%version%"
set "version=%version:v=%"

:dr
if defined SENV_DWL_ASK_FOR_URL (
    %_info% "SENV_DWL_ASK_FOR_URL is defined, ask 'dwl%SENV_DWL_SCRIPT_NAME%.bat' for URL"
    for /f "delims=" %%i in ('call "%script_dir%\dwl%SENV_DWL_SCRIPT_NAME%.bat" :get_url %version%') do ( set "SENV_DWL_URL=%%i" )
)
if not defined SENV_DWL_URL (
    if defined SENV_DWL_ASK_FOR_LATEST_VERSION (
        %_fatal% "[%~nx0] SENV_DWL_URL not defined when it should be after SENV_DWL_ASK_FOR_LATEST_VERSION" 11
    )
    if defined SENV_DWL_ASK_FOR_URL (
        %_fatal% "[%~nx0] SENV_DWL_URL not defined when it should be after SENV_DWL_ASK_FOR_URL (version='%version%')" 11
    )
)
rem set "version=2.35.1.windows.2"
%_info% "[%~nx0] Latest version='%version%'"

rem Call the script and capture its output
if not defined SENV_DWL_FILE (
    %_info% "SENV_DWL_FILE not defined: ask dwl%SENV_DWL_SCRIPT_NAME%.bat for filename#target_local_filename"
    for /f "delims=" %%i in ('call "%script_dir%\dwl%SENV_DWL_SCRIPT_NAME%.bat" :get_filename %version%') do set "file=%%i"
    for /f "tokens=1,2 delims=#" %%a in ('echo !file!') do ( set "file=%%a" & set "target_local_file=%%b" )
) else (
    %_info% "SENV_DWL_FILE defined as '%SENV_DWL_FILE%'"
    for /f "tokens=1,2 delims=#" %%a in ('echo %SENV_DWL_FILE%') do ( set "file=%%a" & set "target_local_file=%%b" )
)
if "%target_local_file%"=="" ( set "target_local_file=%file%")
CALL:ReplaceText "!file!" "[v]" "%version%"  file
CALL:ReplaceText "!target_local_file!" "[v]" "%version%"  target_local_file
%_info% "[%~nx0] URL file='%file%', target file '%target_local_file%'"

if exist "%setup_dir%\%target_local_file%" (
    %_ok% "[%~nx0] '%target_local_file%' Already downloaded in setup_dir '%setup_dir%'"
    goto:eof
)

if not defined SENV_DWL_URL (
    set "url=https://github.com/%repo%/releases/download/%tag%/%file%"
    %_task% "[%~nx0] Download latest to '%setup_dir%\%target_local_file%' from GitHub URL '!url!' (SENV_DWL_URL not defined)"
) else (
    set "url=%SENV_DWL_URL%"
    CALL:ReplaceText "!url!" "[v]" "%version%"  url
    %_task% "[%~nx0] Download latest to '%setup_dir%\%target_local_file%' from Custom URL '!url!' (SENV_DWL_URL defined)"
)
curl -fkL %url% -o "%setup_dir%\%target_local_file%"
if not "%ERRORLEVEL%" == "0" (
    %_fatal% "[%~nx0] Unable to download '%setup_dir%\%target_local_file%' from latest, URL '%url%'" 1
)
%_ok% "[%~nx0] '%target_local_file%' downloaded to '%setup_dir%'"
goto:eof


:ReplaceText
:: https://stackoverflow.com/questions/2772456/string-replacement-in-batch-file
:: https://stackoverflow.com/a/62597777/6309
:: CALL:ReplaceText "!OrginalText!" OldWordToReplace NewWordToUse  Result
::Example
::SET "MYTEXT=jump over the chair"
::  echo !MYTEXT!
::  call:ReplaceText "!MYTEXT!" chair table RESULT
::  echo !RESULT!
:: Remember to use the "! on the input text, but NOT on the Output text.
:: Remember to add quotes "" around the MYTEXT Variable when calling.
::
set "OrginalText=%~1"
set "OldWord=%~2"
set "NewWord=%~3"
call set OrginalText=%%OrginalText:!OldWord!=!NewWord!%%
SET %4=!OrginalText!
GOTO:EOF
