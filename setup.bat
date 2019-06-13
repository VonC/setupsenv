@echo off
setlocal enabledelayedexpansion

set "prgtoinstall=%1"
rem echo "prgtoinstall='%prgtoinstall%'"

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\batcolors"
call %bc%\echos_macros.bat
%_info% "script_dir='%script_dir%'"

if not exist "%USERPROFILE%\git" ( mkdir "%USERPROFILE%\git" )

rem cd setups || %_fatal% "fatal!" && echo "nope." && exit /b 1
rem %_ok% "ok..."
rem goto:eof

REM https://stackoverflow.com/questions/132799/how-can-i-echo-a-newline-in-a-batch-file
set NLM=^


set NL=^^^%NLM%%NLM%^%NLM%%NLM%

if not exist custom ( mkdir custom )
if not exist custom\setup.ini.bat (
    echo @echo off%NL%set PRGS=%NL%set HOME=%NL%> custom\setup.ini.bat
    %_warning% "Fill out first %script_dir%\custom\setup.ini.bat (PRGS, HOME)"
    goto:eof
)

call custom\setup.ini.bat || %_fatal% "custom/setup.ini.bat missing" && exit /b 1

if "%PRGS%"=="" ( %_fatal% "PRGS (installation folder) must be defined" && exit /b 1 )
if "%HOME%"=="" ( %_fatal% "HOME must be defined" && exit /b 1 )

echo @echo off%NL%call %HOME%\bin\senv.bat> "%USERPROFILE%\senv.bat"
echo @echo off%NL%call %HOME%\bin\gsenv.bat> "%USERPROFILE%\gsenv.bat"
doskey senv=

%_info% "PRGS='%PRGS%'"
%_info% "HOME='%HOME%'"

if not exist "%HOME%\bin" (
    mkdir "%HOME%\bin"
    copy "%script_dir%\bin\*" "%HOME%\bin"
    copy "%script_dir%\custom\*.custom.*" "%HOME%\bin"
)

if not exist "%HOME%\bin\senv.local.bat" ( echo @echo off%NL%%NL%REM Custom settings go here> "%HOME%\bin\senv.local.bat")
if not exist "%HOME%\bin\senv.local.pre.bat" ( echo @echo off%NL%set PRGS=%PRGS%%NL%set HOME=%HOME%%NL%rem ---> "%HOME%\bin\senv.local.pre.bat"  )
if not exist "%HOME%\bin\senv.local.doskey" ( echo cdi=cd /d "%script_dir%"> "%HOME%\bin\senv.local.doskey" )
if not exist "%HOME%\bin\gsenv.local.bat" ( echo @echo off%NL%%NL%REM Custom gsenv settings go here> "%HOME%\bin\gsenv.local.bat")
if not exist "%HOME%\.gitconfig" ( copy "%script_dir%\.gitconfig" "%HOME%\.gitconfig" )

rem @echo on
set "locald=%USERPROFILE%\senv_setup"
set "setupsdir=%script_dir%\setups"
call:install "peazip_portable-*" "peazips" || exit /b 1
set szdone="true"
call:install "PortableGit-*" "gits" || exit /b 1
call:install "VSCodeUserSetup-x64-*" "vscodes" || exit /b 1
if not exist "%script_dir%\custom\install.list" (
    goto:alldone
)
%_info% "=========="
%_info% "processing custom installation list"
@echo off
for /f "tokens=1,2 delims= " %%a in ('type "%script_dir%\custom\install.list"') do (
  set fnpl=%%a
  set fl=%%b
  call:install "!fnpl!" "!fl!" || exit /b 1
  if "%prgtoinstall%"=="!fl!" ( goto:alldone )
)
if not exist "%locald%\install.list" ( goto:alldone )
set "setupsdir=%locald%\setups"
%_info% "=========="
%_info% "processing local installation list in %locald%"
for /f "tokens=1,2 delims= " %%a in ('type "%locald%\install.list"') do (
  set fnpl=%%a
  set fl=%%b
  call:install "!fnpl!" "!fl!" || exit /b 1
  if "%prgtoinstall%"=="!fl!" ( goto:alldone )
)


:alldone
%_ok% "All done"
cd /d "%script_dir%"
ENDLOCAL
call custom\setup.ini.bat || %_fatal% "custom/setup.ini.bat still missing" && exit /b 1
echo "HOME='%HOME%'"
call "%HOME%\bin\senv.bat"


goto:eof

:install
set "p=%~1"
set "f=%~2"
if not "%prgtoinstall%"=="" (
    if not "%prgtoinstall%"=="%f%" (
        %_warning% "Skip '%f%' installation (for '%prgtoinstall%')"
        goto:eof
    )
)

set pname=
rem echo "p='%p%', f='%f%'"
rem http://steve-jansen.github.io/guides/windows-batch-scripting/part-2-variables.html
rem https://stackoverflow.com/questions/3215501/batch-remove-file-extension
for /F "usebackq" %%i in (`dir /OD /B "%setupsdir%\%p%"`) do set "fname=%%~nxi"&& set "pname=%%~ni"
rem echo "fname='%fname%'"
rem echo "pname='%pname%'"
if "%pname%"=="" (
    %_fatal% "No setup file found in '%setupsdir%' for '%f%', pattern '%p%'" && exit /b 1
)
%_info% "--------------"
%_info% "'%f%': '%pname%'"
%_info% "--------------"
set pre_ok=false
call :check_pre "%f%" "%fname%" "%pname%" || exit /b 1
if "%pre_ok%"=="true" (
    %_ok% "pre-check ok for %f%: nothing more to do"&& exit /b 0
)
set "tpath=%PRGS%\%f%\%pname%"
if exist "%tpath%" (
    %_ok% "Program '%pname%' already installed in '%PRGS%\%f%'"
    call "%script_dir%\check_symlink.bat" "%pname%" "%f%"
    call:check_post "%f%" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
if not exist "%PRGS%\setup\" (
    mkdir "%PRGS%\setup\"
)
if not exist "%PRGS%\setup\%fname%" (
    %_info% "Copying '%fname%' from '%setupsdir%'"
    copy "%setupsdir%\%fname%" "%PRGS%\setup\" || ( %_fatal% "Unable to copy '%setupsdir%\%fname%' to '%PRGS%\setup\'" && exit /b 1)
    %_ok% "Setup '%fname%' copied locally"
)
set install_ok=false
call:check_install "%f%" "%fname%" "%pname%" || exit /b 1
if "%install_ok%"=="true" (
    %_ok% "install ok for %f%: nothing more to do"&& exit /b 0
)
if "%install_ok%"=="check_symlink" (
    call "%script_dir%\check_symlink.bat" "%pname%" "%f%"
    exit /b 0
)
if "%f%"=="vscodes" (
    %_warning% "should not be here"&& exit /b 1
)
if not exist "%PRGS%\setup" ( mkdir "%PRGS%\setup")
if not exist "%PRGS%\%f%" ( mkdir "%PRGS%\%f%" )

rem https://stackoverflow.com/questions/17546016/how-can-you-zip-or-unzip-from-the-script-using-only-windows-built-in-capabiliti/26843122#26843122
rem powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('foo.zip', 'bar'); }"
if not exist "%PRGS%\peazips\current\res\7z\7z.exe" (
    if "%szdone%"=="true" ( %fatal% "7z should be here" && exit /b 1 )
    %_info% "Uncompressing with powershell '%fname%' to '%tpath%'"
    rem https://stackoverflow.com/questions/33729801/returning-exit-code-from-a-batch-file-in-a-powershell-script-block#comment55261380_33730519
    powershell.exe -nologo -noprofile -ExecutionPolicy UnRestricted; $var = "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('%PRGS%\setup\%fname%', '%tpath%'); $res=$?; Write-Host \"LASTEXITCODE='$res'\";if (-not $res) { return 1; }; return 0;}"; exit $var
    if errorlevel 1 ( %_fatal% "Error on powershell uncompression"&& exit /b 1 )
    %_ok% "'%fname%' uncompressed (powershell) to '%tpath%'"
    call "%script_dir%\check_symlink.bat" "%pname%" "%f%"
    call:check_post "%f%" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe
cd /d "%PRGS%\%f%"
%_info% "Uncompressing with 7z '%fname%' to '%tpath%'"
call "%HOME%\bin\pzxx.bat" "%PRGS%\setup\%fname%"
if errorlevel 1 ( %_fatal% "Error on 7z uncompression"&& exit /b 1 )
%_ok% "'%fname%' uncompressed (7z) to '%tpath%'"
call "%script_dir%\check_symlink.bat" "%pname%" "%f%"
call:check_post "%f%" || exit /b 1
cd /d "%script_dir%"
goto:eof



:check_post
set "f=%~1"
if exist "%script_dir%\installs\%f%.post.bat" (
    call "%script_dir%\installs\%f%.post.bat" || exit /b 1
)
if exist "%script_dir%\custom\%f%.post.bat" (
    call "%script_dir%\custom\%f%.post.bat" || exit /b 1
)
if exist "%locald%\%f%.post.bat" (
    call "%locald%\%f%.post.bat" || exit /b 1
)
goto:eof

:check_install
set "f=%~1"
set "fs=%~2"
set "pfs=%~3"
if exist "%script_dir%\installs\%f%.install.bat" (
    call "%script_dir%\installs\%f%.install.bat" "%fs%" "%pfs%" || exit /b 1
)
if exist "%script_dir%\custom\%f%.install.bat" (
    call "%script_dir%\custom\%f%.install.bat" "%fs%" "%pfs%" || exit /b 1
)
if exist "%locald%\%f%.install.bat" (
    call "%locald%\%f%.install.bat" "%fs%" "%pfs%" || exit /b 1
)
goto:eof

:check_pre
set "f=%~1"
set "fs=%~2"
set "pfs=%~3"
if exist "%script_dir%\installs\%f%.pre.bat" (
    call "%script_dir%\installs\%f%.pre.bat" "%fs%" "%pfs%" || exit /b 1
)
if exist "%script_dir%\custom\%f%.pre.bat" (
    call "%script_dir%\custom\%f%.pre.bat" "%fs%" "%pfs%" || exit /b 1
)
if exist "%locald%\%f%.pre.bat" (
    call "%locald%\%f%.pre.bat" "%fs%" "%pfs%" || exit /b 1
)
goto:eof

