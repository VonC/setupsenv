@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "[%~nx0] script_dir='%script_dir%'"
set "senv_dir=%script_dir%"
cd "%senv_dir%\..\setup" || %_fatal% "[%~nx0] Unable to access setup folder at '%senv_dir%/../setup'" 3
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd /d "%script_dir%" || echo "unable to cd again to '%script_dir%'"&& exit /b 2
set profile=
set profil=
set script_dir_bin=
set setupsdir=
set setupsdirbat=
set "prgtoinstall=%1"
set instlist="install.list"
if /i "%prgtoinstall:~0,1%"=="_" (
    set profile=!prgtoinstall:~1!
    set instlist=install_!profile!.list
    set "prgtoinstall=%2"
) else (
    if exist "%script_dir%\custom\profile" (
        for /f "delims=" %%x in (%script_dir%\custom\profile) do set profile=%%x
    )
    set instlist=install_!profile!.list
)
%_info% "[%~nx0] profile='%profile%', instlist='%instlist%' prgtoinstall='%prgtoinstall%'"
if not exist custom\%instlist% (
    %_fatal% "[%~nx0] Installation instlist '%instlist%' does not exist in '%script_dir%\custom" 1
)
rem echo "prgtoinstall='%prgtoinstall%'"

rem cd setups || %_fatal% "[%~nx0] fatal!" && echo "nope." && exit /b 1
rem %_ok% "[%~nx0] ok..."
rem goto:eof

REM https://stackoverflow.com/questions/132799/how-can-i-echo-a-newline-in-a-batch-file
set NLM=^


set NL=^^^%NLM%%NLM%^%NLM%%NLM%

if not exist custom (
    mkdir custom
    copy custom_example\* custom
)
if not "%HOME%"=="" (
    if not "%PRGS%"=="" (
        if not "%PROG%"=="" (
            set senv_noconfirm=1
            where grep >nul 2>&1
            if "!ERRORLEVEL!"=="0" (
                call check_migrate_home
            )
        )
    )
)
if not exist custom\setup.ini.bat (
    echo @echo off%NL%set PRGS=%NL%set HOME=%NL%> custom\setup.ini.bat
    %_fatal%  "Fill out first %script_dir%\custom\setup.ini.bat (PRGS, HOME, PROG)" 1
)

%_info% "[%~nx0] senv_noconfirm='%senv_noconfirm%' '!senv_noconfirm!'"
call custom\setup.ini.bat || %_fatal% "[%~nx0] custom/setup.ini.bat error" 2

if "%PRGS%"=="" ( %_fatal% "[%~nx0] PRGS (installation folder) must be defined in custom/setup.ini.bat" && exit /b 1 )
if "%HOME%"=="" ( %_fatal% "[%~nx0] HOME must be defined in custom/setup.ini.bat" && exit /b 1 )
if "%PROG%"=="" ( %_fatal% "[%~nx0] PROG (installation folder) must be defined in custom/setup.ini.bat" && exit /b 1 )
if "%REMOTE_HOME%"=="" ( %_fatal% "[%~nx0] REMOTE_HOME (installation folder) must be defined in custom/setup.ini.bat" && exit /b 1 )

echo @echo off%NL%call %HOME%\bin\senv.bat> "%USERPROFILE%\senv.bat"
echo @echo off%NL%call %HOME%\bin\gsenv.bat> "%USERPROFILE%\gsenv.bat"
echo @echo off%NL%call "%%USERPROFILE%%\senv.bat"> "%HOME%\senv.bat"
echo @echo off%NL%call "%%USERPROFILE%%\gsenv.bat"> "%HOME%\gsenv.bat"
REM usefull when HOMEDRIVE is U: or other than C:
if not "%HOMEDRIVE%"=="C:" (
    echo @echo off%NL%call "%%USERPROFILE%%\senv.bat"> "%HOMEDRIVE%\senv.bat"
    echo @echo off%NL%call "%%USERPROFILE%%\gsenv.bat"> "%HOMEDRIVE%\gsenv.bat"
)
doskey senv=

%_info% "[%~nx0] PRGS='%PRGS%'"
%_info% "[%~nx0] HOME='%HOME%'"
%_info% "[%~nx0] PROG='%PROG%'"

if not exist "%HOME%\bin" (
    mkdir "%HOME%\bin"
)

%_task% "[%~nx0] Must copy script_dir\bin '%script_dir%\bin\' to HOME\bin '%HOME%\bin'"
copy "%script_dir%\bin\*" "%HOME%\bin" 1>NUL:
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to copy '%script_dir%\bin\*' to '%HOME%\bin'" 231
)
%_ok% "[%~nx0] script_dir\bin '%script_dir%\bin\' COPIED to HOME\bin '%HOME%\bin'"
%_task% "[%~nx0] Must copy script_dir\custom\ custom-files '%script_dir%\custom\' to HOME\bin '%HOME%\bin'"
copy "%script_dir%\custom\*.custom.*" "%HOME%\bin" 1>NUL:
if errorlevel 1 (
    %_fatal% "[%~nx0] Unable to copy '%script_dir%\custom\*.custom.*' to '%HOME%\bin'" 231
)
%_ok% "[%~nx0] '%script_dir%\custom\*.custom.*' COPIED to '%HOME%\bin'"

if not exist "%HOME%\.config" ( mkdir "%HOME%\.config" )
if not exist "%HOME%\.config\git" ( mkdir "%HOME%\.config\git" )
if not exist "%HOME%\.config\git\config" ( copy "%script_dir%\.config.git.config" "%HOME%\.config\git\config" )

if exist "%script_dir%\custom\profile" (
    %_task% "[%~nx0] Copy/Update '%HOME%\bin\profile' with '%script_dir%\custom\profile'"
    copy /Y "%script_dir%\custom\profile" "%HOME%\bin" 1>NUL:
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to copy '%script_dir%\custom\profile' to '%HOME%\bin'" 23
    )
    %_ok% "[%~nx0] Profile custom aliases updated '%HOME%\bin\profile'"
)

if not exist "%script_dir%\custom\senv.custom.doskey" (
    %_info% "[%~nx0] No Custom alias file '%script_dir%\custom\senv.custom.doskey'"
) else (
    %_task% "[%~nx0] Copy/Update '%HOME%\bin\senv.custom.doskey' with '%script_dir%\custom\senv.custom.doskey'"
    copy /Y "%script_dir%\custom\senv.custom.doskey" "%HOME%\bin" 1>NUL:
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to copy '%script_dir%\custom\senv.custom.doskey' to '%HOME%\bin'" 23
    )
    %_ok% "[%~nx0] Profile custom aliases updated '%HOME%\bin\senv.custom.doskey'"
)

if not exist "%script_dir%\custom\senv.custom.%profile%.doskey" (
    %_info% "[%~nx0] No Custom alias file '%script_dir%\custom\senv.custom.%profile%.doskey'"
) else (
    %_task% "[%~nx0] Copy/Update '%HOME%\bin\senv.custom.%profile%.doskey' with '%script_dir%\custom\senv.custom.%profile%.doskey'"
    copy /Y "%script_dir%\custom\senv.custom.%profile%.doskey" "%HOME%\bin" 1>NUL:
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to copy '%script_dir%\custom\senv.custom.%profile%.doskey' to '%HOME%\bin'" 23
    )
    %_ok% "[%~nx0] Profile custom '%profile%' aliases updated '%HOME%\bin\senv.custom.%profile%.doskey'"
)

if not exist "%HOME%\bin\senv.local.bat" ( echo @echo off%NL%%NL%REM Custom settings go here> "%HOME%\bin\senv.local.bat")
if not exist "%HOME%\bin\senv.local.pre.bat" ( echo @echo off%NL%set "PRGS=%PRGS%"%NL%set "PROG=%PROG%"%NL%set "REMOTE_HOME=%REMOTE_HOME%"%NL%set "HOME=%HOME%"%NL%rem ---> "%HOME%\bin\senv.local.pre.bat"  )
if not exist "%script_dir%\custom\setup.senv.local.pre.bat" (
    %_info% "[%~nx0] No '%script_dir%\custom\setup.senv.local.pre.bat' found"
) else (
    %_info% "[%~nx0] Call "%script_dir%\custom\setup.senv.local.pre.bat"
    call "%script_dir%\custom\setup.senv.local.pre.bat"
)
if not exist "%HOME%\bin\senv.local.doskey" ( echo cdi=cd /d "%script_dir%"> "%HOME%\bin\senv.local.doskey" )
if not exist "%HOME%\bin\gsenv.local.bat" ( echo @echo off%NL%%NL%REM Custom gsenv settings go here> "%HOME%\bin\gsenv.local.bat")
if not exist "%HOME%\.gitconfig" ( copy "%script_dir%\.gitconfig" "%HOME%\.gitconfig" )

if not exist "%PROG%\git" ( mkdir "%PROG%\git" )
set "bc=%PROG%\git\batcolors"
if not exist "%PROG%\git\batcolors" ( mkdir "%bc%" )
if not exist "%bc%\echos_macros.bat"  (copy "%script_dir%\batcolors\*" "%bc%" )

rem @echo on
set setupsdirbat="setupsdir.bat"
if not "%profile%"=="" (
    set "setupsdirbat=setupsdir_%profile%.bat"
)
set "locald=%PROG%\senv_setups"
if "%setupsdir%"=="" (
    if exist "%script_dir%\setups" (
        set "setupsdir=%script_dir%\setups"
    ) else if exist "%script_dir%\custom\%setupsdirbat%" (
        %_info% "[%~nx0] call '%script_dir%\custom\%setupsdirbat%'"
        call "%script_dir%\custom\%setupsdirbat%"
    )
    if "!setupsdir!"=="" (
        %_fatal% "[%~nx0] Define '%script_dir%\custom\%setupsdirbat%' with in it 'set setupsdir=/path/to/setups/archives'" && exit /b 1
    )
)
%_info% "[%~nx0] setupsdir='%setupsdir%'"
cd /d "%script_dir%"
rem goto:alldone
findstr /i "peazips" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=peazip_portable-*" )
call:install "%pattern%" "peazips" || exit /b 1
set szdone="true"
cd /d "%script_dir%"
findstr /i "gits" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=PortableGit-*" )
call:install "%pattern%" "gits" || exit /b 1


if exist "%script_dir%\custom\senv.custom.full.%profile%.bat" (
    %_info% "[%~nx0] REPLACE '%HOME%\bin\senv.custom.bat' content with '%script_dir%\custom\senv.custom.full.%profile%.bat'"
    type "%script_dir%\custom\senv.custom.full.%profile%.bat" > "%HOME%\bin\senv.custom.bat"
)
cd /d "%script_dir%"
call:install "VSCodeUserSetup-x64-*" "vscodes" "system-code" || exit /b 1
if not exist "%script_dir%\custom\%instlist%" (
    goto:alldone
)

call:install "gum_*_Windows_x86_64.zip" "gums" || exit /b 1

findstr /i "sysinternalsSuites" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=SysinternalsSuite-*.zip" )
call:install "%pattern%" "sysinternalsSuites" || exit /b 1

%_info% "[%~nx0] =========="
%_info% "[%~nx0] processing custom installation list '%instlist%'"
@echo off
for /f "tokens=1,2 delims= " %%a in ('type "%script_dir%\custom\%instlist%"') do (
  set fnpl=%%a
  set fl=%%b
  set "cil_install=true"
  if "!fl!"=="peazips" ( set "cil_install=false" )
  if "!fl!"=="gits" ( set "cil_install=false" )
  if "!fl!"=="vscodes" ( set "cil_install=false" )
  if "!fl!"=="gums" ( set "cil_install=false" )
  if "!fl!"=="sysinternals" ( set "cil_install=false" )
  if "!cil_install!"=="true" (
      call:install "!fnpl!" "!fl!" || exit /b 1
  )
)
if not exist "%locald%\install.list" (
    %_ok% "[%~nx0] no local install list '%locald%\install.list', so no more list to process"
    goto:alldone
)
set "setupsdir=%locald%\setups"
%_info% "[%~nx0] =========="
%_info% "[%~nx0] processing local installation list in '%locald%\install.list'"
for /f "tokens=1,2 delims= " %%a in ('type "%locald%\install.list"') do (
  set fnpl=%%a
  set fl=%%b
  call:install "!fnpl!" "!fl!" || exit /b 1
)


:alldone
%_ok% "[%~nx0] All done"
ENDLOCAL
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
rem cd
call custom\setup.ini.bat "set" || %_fatal% "[%~nx0] custom/setup.ini.bat still missing" && exit /b 1
echo HOME='%HOME%'
echo script_dir='%script_dir%'
rem set "script_dir=%cd%"
findstr /V "cdi= cdis=" "%HOME%\bin\senv.local.doskey" > "%script_dir%\tmp"
call "%script_dir%\bin\check_trailing_newline.bat" "%script_dir%\tmp"
if "%ERRORLEVEL%"=="2" ( echo.>> "%script_dir%\tmp" )
echo cdi=cd /d %script_dir%>> "%script_dir%\tmp"
for /f "delims=" %%x in (%script_dir%\custom\profile) do set profile=%%x
set "setupsdirbat=setupsdir_%profile%.bat"
call "%script_dir%\custom\%setupsdirbat%"
echo cdis=cd /d %setupsdir%>> "%script_dir%\tmp"
del "%HOME%\bin\senv.local.doskey"
move "%script_dir%\tmp" "%HOME%\bin\senv.local.doskey"
cd /d "%script_dir%"
rem del /F "%script_dir%\tmp" 2>NUL

set script_dir=
set profile=
set setupsdirbat=
set setupsdir=
%_ok% "[%~nx0] calling senv.bat: You are good to go"
call "%HOME%\bin\senv.bat"
goto:eof

:install
set "p=%~1"
set "f=%~2"
set "sys=%~3"
if not "%prgtoinstall%"=="" (
    if not "%prgtoinstall%"=="%f%" (
        %_warning% "[%~nx0] Skip '%f%' installation (for '%prgtoinstall%')"
        rem @echo on
        goto:eof
    )
)

if "%p%"=="system" ( set "pname=system" && goto:info )
rem echo Check path in setupsdir/p: '%setupsdir%'\'%p%'
set pname=
rem echo "p='%p%', f='%f%'"
rem http://steve-jansen.github.io/guides/windows-batch-scripting/part-2-variables.html
rem https://stackoverflow.com/questions/3215501/batch-remove-file-extension
if exist "%setupsdir%\%p%" (
    for /F "usebackq" %%i in (`dir /OD /B "%setupsdir%\%p%"`) do set "fname=%%~nxi"&& set "pname=%%~ni"
)
rem echo fname='%fname%'
rem echo pname='%pname%'
if "%pname%"=="" (
    if exist "%setupsdir%\_%f%" (
        %_warning% "[%~nx0] Skip '%f%' installation (test found) in '%setupsdir%\_%f%'"
        goto:eof
    )
    %_warning% "[%~nx0] No setup file found in '%setupsdir%' for '%f%', pattern '%p%'"
) else ( goto:info )
%_task% "[%~nx0] Must check if '%f%', pattern '%p%' is in local setup dir '%setup_dir%'"
if exist "%setup_dir%\%p%" (
    for /F "usebackq" %%i in (`dir /OD /B "%setup_dir%\%p%"`) do set "fname=%%~nxi"&& set "pname=%%~ni"
)
if "%pname%"=="" (
    if exist "%setup_dir%\_%f%" (
        %_warning% "[%~nx0] Skip '%f%' installation (test found) in local '%setup_dir%\_%f%'"
        goto:eof
    )
    %_fatal% "[%~nx0] No setup file found in local '%setup_dir%' for '%f%', pattern '%p%'" 112
)
:info
%_info% "[%~nx0] --------------"
%_info% "[%~nx0] folder: '%f%': pattern '%pname%' system: '%sys%'"
%_info% "[%~nx0] --------------"

if exist "%HOME%\.gitconfig" (
    call "%script_dir%\installs\gits.config.utils.bat" :save_gitconfig Install '%f%': '%pname%'
)
set pre_ok=false
call :check_pre "%f%" "%fname%" "%pname%" || exit /b 1
%_info% "[%~nx0] pname='%pname%', f='%f%', fname='%fname%' means sys='%sys%'"
if "%pre_ok%"=="true" (
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    %_ok% "[%~nx0] pre-check ok for %f%: nothing more to do"&& exit /b 0
)
set "tpath=%PRGS%\%f%\_%pname%"
if exist "%tpath%" (
    %_ok% "[%~nx0] Program '%pname%' already installed in '%PRGS%\%f%'"
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    call:check_post "%f%" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
set "tpath=%PRGS%\%f%\%pname%"
if exist "%tpath%" (
    %_ok% "[%~nx0] Program '%pname%' already installed2 in '%PRGS%\%f%'"
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    call:check_post "%f%" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
if not exist "%PRGS%\setup\" (
    mkdir "%PRGS%\setup\"
)
if not exist "%PRGS%\setup\%fname%" (
    %_info% "[%~nx0] Copying '%fname%' from '%setupsdir%'"
    (robocopy "%setupsdir%" "%PRGS%\setup" "%fname%" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
    if not "%ERRORLEVEL%"=="0" ( %_fatal% "[%~nx0] Unable to copy '%setupsdir%\%fname%' to '%PRGS%\setup\'" && exit /b 1)
    %_ok% "[%~nx0] Setup '%fname%' copied locally"
)
set install_ok=false
call:check_install "%f%" "%fname%" "%pname%" || exit /b 1
if "%install_ok%"=="true" (
    %_ok% "[%~nx0] install ok for %f%: nothing more to do"&& exit /b 0
)
if "%install_ok%"=="check_symlink" (
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    exit /b 0
)
if "%f%"=="vscodes" (
    %_warning% "[%~nx0] should not be here"&& exit /b 1
)
if not exist "%PRGS%\setup" ( mkdir "%PRGS%\setup")
if not exist "%PRGS%\%f%" ( mkdir "%PRGS%\%f%" )
if not "%pname:system=%"=="%pname%" (
    goto:postinstall
)

rem https://stackoverflow.com/questions/17546016/how-can-you-zip-or-unzip-from-the-script-using-only-windows-built-in-capabiliti/26843122#26843122
rem powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('foo.zip', 'bar'); }"
if not exist "%PRGS%\peazips\current\res\7z\7z.exe" (
    if "%szdone%"=="true" ( %fatal% "7z should be here" && exit /b 1 )
    %_task% "[%~nx0] Must uncompress with powershell '%fname%' to '%tpath%'"
    rem https://stackoverflow.com/questions/33729801/returning-exit-code-from-a-batch-file-in-a-powershell-script-block#comment55261380_33730519
    powershell.exe -nologo -noprofile -ExecutionPolicy UnRestricted; $var = "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('%PRGS%\setup\%fname%', '%tpath%'); $res=$?; Write-Host \"LASTEXITCODE='$res'\";if (-not $res) { return 1; }; return 0;}"; exit $var
    if errorlevel 1 ( %_fatal% "[%~nx0] Error on powershell uncompression"&& exit /b 1 )
    %_ok% "[%~nx0] '%fname%' uncompressed (powershell) to '%tpath%'"
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    call:check_post "%f%" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe
cd /d "%PRGS%\%f%"
%_task% "[%~nx0] Must uncompress with 7z '%PRGS%\setup\%fname%' to '%tpath%'"
call "%HOME%\bin\pzxx.bat" "%PRGS%\setup\%fname%"
if errorlevel 1 (
    rm -Rf "%tpath%"
    %_fatal% "[%~nx0] Error on 7z uncompression" 1
)
%_ok% "[%~nx0] '%fname%' uncompressed (7z) to '%tpath%'"
:postinstall
call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
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

