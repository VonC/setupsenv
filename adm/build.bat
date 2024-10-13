@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1
for %%i in ("%script_dir%") do (
    set "script_dir=%%~fi"
)
for %%i in ("%script_dir%\..\batcolors") do ( set "bc=%%~fi" )
call "%bc%\echos_macros.bat"
%_info% "script_dir(bundle)='%script_dir%'"

if "%1"=="" (
    %_fatal% "Must have setupsdir profile xx, for calling setupsdir_xx.bat" 1
)

set "profile=%1"

set "custom_dir=%script_dir%\..\custom"
cd "%custom_dir%" || %_fatal% "Unable to access custom folder" 1
for /F "delims=" %%f in ('cd') do ( set "custom_dir=%%f" )
%_info% "Custom folder full path: '%custom_dir%'"

set s="setupsdir_%profile%.bat"
if not exist "%custom_dir%\%s%" (
    %_fatal% "setupsdir script '%s%' does not exist" 2
)

echo %profile%>profile

cd ..
if not exist custom (
    %_fatal% "current folder must be named custom" 1
)
for /F "delims=" %%f in ('cd') do ( set senv_dir=%%f)
%_info% "senv folder full path: '%senv_dir%'"

if not exist builds (
    %_fatal% "builds must be in senv folder" 1
)
set "builds_dir=%senv_dir%\builds"
%_info% "builds folder full path: '%builds_dir%'"

set "sbem=SENV_BUILD_ERROR_MODE='%SENV_BUILD_ERROR_MODE%'"
for /f "delims=" %%x in ('git -C "%custom_dir%" status --porcelain') do set "st=%%x"
rem goto:skipcl
if not "%st%"=="" (
    if "%SENV_BUILD_ERROR_MODE%"=="custom" (
        %_error% "Not a clean git status in custom '%custom_dir%' (%sbem%)"
    ) else if "%SENV_BUILD_ERROR_MODE%"=="both" (
        %_error% "Not a clean git status in custom '%custom_dir%' (%sbem%)"
    ) else (
        %_fatal% "Not a clean git status in custom '%custom_dir%' (%sbem%)" 1
    )
)
for /f "delims=" %%x in ('git -C "%senv_dir%" status --porcelain') do set "st=%%x"
if not "%st%"=="" (
    if "%SENV_BUILD_ERROR_MODE%"=="senv" (
        %_error% "Not a clean git status in senv '%senv_dir%' (%sbem%)"
    ) else if "%SENV_BUILD_ERROR_MODE%"=="both" (
        %_error% "Not a clean git status in senv '%senv_dir%' (%sbem%)"
    ) else (
        %_fatal% "Not a clean git status in senv '%senv_dir%' (%sbem%)" 1
    )
)
rem @echo on

:skipcl
for /f "tokens=* delims=" %%i in ('git -C "%custom_dir%" describe --long --all HEAD') do SET "vcsenv=%%i"
for /f "tokens=* delims=" %%i in ('git -C "%custom_dir%\.." describe --long --all HEAD') do SET "vcsenv=!vcsenv! - %%i"
echo %vcsenv%>"%custom_dir%\version"
rem %_fatal% "stop for now" 1

if exist "%builds_dir%\build.pre.bat" ( call "%builds_dir%\build.pre.bat" )

cd %senv_dir%
call gcuvc
cd %custom_dir%
call gcuu
call "%custom_dir%\setupsdir_%profile%.bat" %2
if errorlevel 1 (
    %_error% "Unable to call '%custom_dir%\setupsdir_%profile%.bat'" && exit /b 1)
)
%_info% "setupsdir='%setupsdir%'"
goto:eof
if not exist "%setupsdir%\..\version" (
    %_ok% "New publication"
    goto:build_and_publish
)
for /f "delims=" %%a in ('type "%setupsdir%\..\version"') do (
    if "%%a"=="%vcsenv%" (
        %_ok% "Already published senv '%profile%' with '%vcsenv%'"
        goto:eof
    ) else (
        %_task% "Update senv '%profile%' with '%vcsenv%' (from '%%a')"
    )
    goto :build_and_publish
)

:build_and_publish
cd "%custom_dir%\..\.."
del "senv_%profile%-zip.exe"
%_info% "zip '%custom_dir%\..\..\senv' to 'senv_%profile%.zip'"
%sz% a -sfx7z.sfx senv_%profile%-zip.exe senv
if not "%ERRORLEVEL%"=="0" (
     %_fatal% "Unable 7z '%custom_dir%\..\..\senv' to '%CD%' 'senv_%profile%-zip.exe'" && exit /b 1
)
cd "%custom_dir%"

%_task% "Must update 'senv_%profile%-zip.exe' from '%custom_dir%\..\..' to '%setupsdir%'"
rem @echo on
set OK="KO"
robocopy "%custom_dir%\..\.." "%setupsdir%" "senv_%profile%-zip.exe" /Z /R:2 /W:2 /TBD /MT:16 /NJH /NJS 
IF %ERRORLEVEL% LSS 8 (
    echo "ERRORLEVEL='%ERRORLEVEL%'"
    SET "OK=ok"
) else (
    set OK=%ERRORLEVEL%
)
echo "OK='%OK%' '!OK!'"
if not "%OK%"=="ok" ( %_error% "Unable to robocopy '%custom_dir%\..\..\senv_%profile%-zip.exe' to '%setupsdir%': errorlevel '%OK%'" && goto:eof)
%_ok% "senv_%profile%-zip.exe updated from '%custom_dir%\..\..' to '%setupsdir%'"

copy /Y "%custom_dir%\version" "%setupsdir%\..\version"
if errorlevel 1 (
    %_fatal% "Unable to copy 'version' from '%custom_dir%' to '%setupsdir%\..'" && exit /b 1)
)

copy /Y "%custom_dir%\echos_macros.bat" "%setupsdir%\..\echos_macros.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'echos_macros.bat' from '%custom_dir%' to '%setupsdir%\..'" && exit /b 1)
)
copy /Y "%custom_dir%\echos.bat" "%setupsdir%\..\echos.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'echos.bat' from '%custom_dir%' to '%setupsdir%\..'" && exit /b 1)
)

copy /Y "%custom_dir%\remote_setup.bat" "%setupsdir%\..\remote_setup.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'remote_setup.bat' from '%custom_dir%' to '%setupsdir%\..'" && exit /b 1)
)

copy /Y "%custom_dir%\setup.ini.bat" "%setupsdir%\..\setup.ini.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'setup.ini.bat' from '%custom_dir%' to '%setupsdir%\..'" && exit /b 1)
)
copy /Y "%custom_dir%\detection_VDI.bat" "%setupsdir%\..\detection_VDI.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'detection_VDI.bat' from '%custom_dir%' to '%setupsdir%\..'" && exit /b 1)
)
copy /Y "%custom_dir%\ss.bat" "%setupsdir%\s.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 's.bat' from '%custom_dir%' to '%setupsdir%'" && exit /b 1)
)
copy /Y "%custom_dir%\..\check_migrate_home.bat" "%setupsdir%\check_migrate_home.bat"
if errorlevel 1 (
    %_fatal% "Unable to copy 'check_migrate_home.bat' from '%custom_dir%\..' to '%setupsdir%'" && exit /b 1)
)


if "%setupsdirsenv%"=="" (
    %_fatal% "setupsdirsenv empty. Check '%custom_dir%\setupsdir_%profile%.bat'" && exit /b 1)
)

echo call remote_setup.bat %profile%>%setupsdirsenv%\s.bat
rem echo call %setupsdirsenv%\remote_setup.bat %profile%>%setupsdir%\s.bat
echo deep>profile

if exist "%custom_dir%\..\..\build.post.bat" ( call "%custom_dir%\..\..\build.post.bat" )