@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo "unable to cd to '%script_dir%'"&& exit /b 1

set "bc=%script_dir%\batcolors"
call "%bc%\echos_macros.bat"
%_info% "script_dir='%script_dir%', batdir='%batdir%'"
set "senv_dir=%script_dir%"
if not exist "%senv_dir%\..\setup" (
    mkdir "%senv_dir%\..\setup"
    if errorlevel 1 (
        %_fatal% "Unable to create setup folder at '%senv_dir%/../setup'" 3
    )
)
if not exist "%senv_dir%\..\dl" (
    %_task% "Must create dl junction '%senv_dir%\..\dl' to '%USERPROFILE%\Downloads'"
    mklink /J "%senv_dir%\..\dl" "%USERPROFILE%\Downloads"
    if errorlevel 1 (
        %_fatal% "Unable to create dl junction at '%senv_dir%/../dl' to '%USERPROFILE%\Downloads'" 5
    )
    %_ok% "dl junction '%senv_dir%\..\dl' created, linked to '%USERPROFILE%\Downloads'"
)
cd "%senv_dir%\..\setup"
if errorlevel 1 ( %_fatal% "Unable to access setup folder at '%senv_dir%/../setup'" 3 )
for /F "delims=" %%f in ('cd') do ( set setup_dir=%%f)
cd /d "%script_dir%"
if errorlevel 1 ( %_fatal% "unable to cd again to '%script_dir%'" 2 )
set profile=
set profil=
set script_dir_bin=
set setupsdir=
set setupsdirbat=
set "prgtoinstall=%~1"
set instlist="install.list"
if /i "%prgtoinstall:~0,1%"=="_" (
    set profile=!prgtoinstall:~1!
    set instlist=install_!profile!.list
    set "prgtoinstall=%~2"
) else (
    if exist "%script_dir%\custom\profile" (
        for /f "delims=" %%x in (%script_dir%\custom\profile) do set profile=%%x
    )
    set instlist=install_!profile!.list
)
%_info% "profile='%profile%', instlist='%instlist%' prgtoinstall='%prgtoinstall%'"
if not exist custom\%instlist% (
    %_fatal% "Installation instlist '%instlist%' does not exist in '%script_dir%\custom" 1
)
rem echo "prgtoinstall='%prgtoinstall%'"

rem cd setups
rem if errorlevel 1 %_fatal% "fatal!" && echo "nope." && exit /b 1
rem %_ok% "ok..."
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

%_info% "senv_noconfirm='%senv_noconfirm%' '!senv_noconfirm!'"
call custom\setup.ini.bat
if errorlevel 1 %_fatal% "custom/setup.ini.bat error" 2

if "%PRGS%"=="" ( %_fatal% "PRGS (installation folder) must be defined in custom/setup.ini.bat" && exit /b 1 )
if "%HOME%"=="" ( %_fatal% "HOME must be defined in custom/setup.ini.bat" && exit /b 1 )
if "%PROG%"=="" ( %_fatal% "PROG (installation folder) must be defined in custom/setup.ini.bat" && exit /b 1 )
if "%REMOTE_HOME%"=="" ( %_fatal% "REMOTE_HOME (installation folder) must be defined in custom/setup.ini.bat" && exit /b 1 )

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management; $templatePath = '%script_dir%\senv.user_profile.tpl.bat'; $targetPath = '%USERPROFILE%\senv.bat'; $content = Get-Content -LiteralPath $templatePath -Raw; [System.IO.File]::WriteAllText($targetPath, $content.Replace('_HOME_', '%HOME%'), [System.Text.UTF8Encoding]::new($false))"
if errorlevel 1 (
    %_fatal% "Unable to write '%USERPROFILE%\senv.bat' from '%script_dir%\senv.user_profile.tpl.bat'" 24
)
echo @echo off%NL%call %HOME%\bin\gsenv.bat> "%USERPROFILE%\gsenv.bat"
echo @echo off%NL%call "%%USERPROFILE%%\senv.bat"> "%HOME%\senv.bat"
echo @echo off%NL%call "%%USERPROFILE%%\gsenv.bat"> "%HOME%\gsenv.bat"
REM useful when HOMEDRIVE is U: or other than C:
if not "%HOMEDRIVE%"=="C:" (
    echo @echo off%NL%call "%%USERPROFILE%%\senv.bat"> "%HOMEDRIVE%\senv.bat"
    echo @echo off%NL%call "%%USERPROFILE%%\gsenv.bat"> "%HOMEDRIVE%\gsenv.bat"
)
doskey senv=

%_info% "PRGS='%PRGS%'"
%_info% "HOME='%HOME%'"
%_info% "PROG='%PROG%'"

if not exist "%HOME%\bin" (
    mkdir "%HOME%\bin"
)

%_task% "Must copy script_dir\bin '%script_dir%\bin\' to HOME\bin '%HOME%\bin'"
copy "%script_dir%\bin\*" "%HOME%\bin" 1>NUL:
if errorlevel 1 (
    %_fatal% "Unable to copy '%script_dir%\bin\*' to '%HOME%\bin'" 231
)
%_ok% "script_dir\bin '%script_dir%\bin\' COPIED to HOME\bin '%HOME%\bin'"
%_task% "Must copy script_dir\custom\ custom-files '%script_dir%\custom\' to HOME\bin '%HOME%\bin'"
copy "%script_dir%\custom\*.custom.*" "%HOME%\bin" 1>NUL:
if errorlevel 1 (
    %_fatal% "Unable to copy '%script_dir%\custom\*.custom.*' to '%HOME%\bin'" 231
)
%_ok% "'%script_dir%\custom\*.custom.*' COPIED to '%HOME%\bin'"

if not defined profile ( goto:skip_custom_cleanup)

%_task% "Must cleanup custom.[profile].[bat,doskey] files"
dir /B "%HOME%\bin\*.custom.*.bat" > "%script_dir%\setup_cleanup.tmp"
if errorlevel 1 (
  %_fatal% "Unable to list custom bat files in %HOME%\bin" 51
)
dir /B "%HOME%\bin\*.custom.*.doskey" >> "%script_dir%\setup_cleanup.tmp"
if errorlevel 1 (
  %_fatal% "Unable to list custom doskey files in %HOME%\bin" 52
)
findstr /R /V /C:".*custom\.%profile%\..*" "%script_dir%\setup_cleanup.tmp" > "%script_dir%\setup_cleanup_filtered.tmp"
if errorlevel 1 (
  %_info% "No other profile than '%profile%' in '%script_dir%\setup_cleanup.tmp'"
)
for /f "delims=" %%a in ('type "%script_dir%\setup_cleanup_filtered.tmp"') do (
  set "custom_file_to_delete=%%a"
  rem echo Must delete '!custom_file_to_delete!'
  del "%HOME%\bin\!custom_file_to_delete!"
  if errorlevel 1 (
    %_fatal% "Unable to delete custom file '!custom_file_to_delete!' in %HOME%\bin" 54
  )
)
del "%script_dir%\setup_cleanup.tmp"
del "%script_dir%\setup_cleanup_filtered.tmp"
%_ok% "All custom file from different profiles than '%profile%' have been deleted from HOME\bin '%HOME%\bin'"

rem %_fatal% "stop for now" 22

:skip_custom_cleanup
if not exist "%HOME%\.config" ( mkdir "%HOME%\.config" )
if not exist "%HOME%\.config\git" ( mkdir "%HOME%\.config\git" )
if not exist "%HOME%\.config\git\config" ( copy "%script_dir%\.config.git.config" "%HOME%\.config\git\config" )

if exist "%script_dir%\custom\profile" (
    %_task% "Copy/Update '%HOME%\bin\profile' with '%script_dir%\custom\profile'"
    copy /Y "%script_dir%\custom\profile" "%HOME%\bin" 1>NUL:
    if errorlevel 1 (
        %_fatal% "Unable to copy '%script_dir%\custom\profile' to '%HOME%\bin'" 23
    )
    %_ok% "Profile custom aliases updated '%HOME%\bin\profile'"
)

if not exist "%script_dir%\custom\senv.custom.doskey" (
    %_info% "No Custom alias file '%script_dir%\custom\senv.custom.doskey'"
) else (
    %_task% "Copy/Update '%HOME%\bin\senv.custom.doskey' with '%script_dir%\custom\senv.custom.doskey'"
    copy /Y "%script_dir%\custom\senv.custom.doskey" "%HOME%\bin" 1>NUL:
    if errorlevel 1 (
        %_fatal% "Unable to copy '%script_dir%\custom\senv.custom.doskey' to '%HOME%\bin'" 23
    )
    %_ok% "Profile custom aliases updated '%HOME%\bin\senv.custom.doskey'"
)

if not exist "%script_dir%\custom\senv.custom.%profile%.doskey" (
    %_info% "No Custom alias file '%script_dir%\custom\senv.custom.%profile%.doskey'"
) else (
    %_task% "Copy/Update '%HOME%\bin\senv.custom.%profile%.doskey' with '%script_dir%\custom\senv.custom.%profile%.doskey'"
    copy /Y "%script_dir%\custom\senv.custom.%profile%.doskey" "%HOME%\bin" 1>NUL:
    if errorlevel 1 (
        %_fatal% "Unable to copy '%script_dir%\custom\senv.custom.%profile%.doskey' to '%HOME%\bin'" 23
    )
    %_ok% "Profile custom '%profile%' aliases updated '%HOME%\bin\senv.custom.%profile%.doskey'"
)

if not exist "%HOME%\bin\senv.local.bat" ( echo @echo off%NL%%NL%REM Custom settings go here> "%HOME%\bin\senv.local.bat")
if not exist "%HOME%\bin\senv.local.pre.bat" ( echo @echo off%NL%set "PRGS=%PRGS%"%NL%set "PROG=%PROG%"%NL%set "REMOTE_HOME=%REMOTE_HOME%"%NL%set "HOME=%HOME%"%NL%rem ---> "%HOME%\bin\senv.local.pre.bat"  )
set "sslpb=%script_dir%\adm\custom\setup.senv.local.pre.bat"
if exist "%script_dir%\custom\setup.senv.local.pre.bat" ( set "sslpb=%script_dir%\custom\setup.senv.local.pre.bat" )
if not exist "%sslpb%" (
    %_info% "No '%sslpb%' found"
) else (
    %_info% "Call "%sslpb%"
    call "%sslpb%"
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
        %_info% "call '%script_dir%\custom\%setupsdirbat%'"
        call "%script_dir%\custom\%setupsdirbat%"
    )
    if "!setupsdir!"=="" (
        %_fatal% "Define '%script_dir%\custom\%setupsdirbat%' with in it 'set setupsdir=/path/to/setups/archives'" && exit /b 1
    )
)
%_info% "setupsdir='%setupsdir%'"
cd /d "%script_dir%"
if exist installs\python.install.bat (
    %_task% "Must delete installs\python.install.bat in '%script_dir%'"
    del installs\python.install.bat
    if errorlevel 1 (
        %_fatal% "Unable to delete installs\python.install.bat in '%script_dir%'" 165
    )
    %_ok% "installs\python.install.bat in '%script_dir%' deleted"
)
rem goto:alldone
findstr /i "peazips" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=peazip_portable-*" )
call:install "%pattern%" "peazips" || exit /b 1
set szdone="true"
cd /d "%script_dir%"
findstr /i "gits" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=PortableGit-*" )
call:install "%pattern%" "gits" || exit /b 1
if "%prgtoinstall%"=="" (
    call:activate_git_path || exit /b 1
) else if /i "%prgtoinstall%"=="gits" (
    call:activate_git_path || exit /b 1
) else if exist "%PRGS%\gits\current\bin\git.exe" (
    call:activate_git_path || exit /b 1
)


if exist "%script_dir%\custom\senv.custom.full.%profile%.bat" (
    %_info% "REPLACE '%HOME%\bin\senv.custom.bat' content with '%script_dir%\custom\senv.custom.full.%profile%.bat'"
    type "%script_dir%\custom\senv.custom.full.%profile%.bat" > "%HOME%\bin\senv.custom.bat"
)
cd /d "%script_dir%"
call:install "px-*" "pxs" || exit /b 1
if exist "%PRGS%\pxs\current\px.exe" (
    call:activate_proxy_env || exit /b 1
)
call:install "VSCodeUserSetup-x64-*" "vscodes" "system-code" || exit /b 1
findstr /i "npps" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=npp.*.portable.x64.zip" )
call:install "%pattern%" "npps" || exit /b
call:install "gum_*_Windows_x86_64.zip" "gums" || exit /b 1

findstr /i "sysinternalsSuites" "custom\%instlist%" >nul
if %errorlevel% equ 0 ( set "pattern=system" ) else ( set "pattern=SysinternalsSuite-*.zip" )
call:install "%pattern%" "sysinternalsSuites" || exit /b 1
call:install "Microsoft.WindowsTerminal_*_x64.zip" "terminals" || exit /b 1
call:install "git-cliff-*-x86_64-pc-windows-msvc.zip" "git-cliffs" || exit /b 1
call:install "jq-*-win64.zip" "jqs" || exit /b 1

if not exist "%script_dir%\custom\%instlist%" (
    goto:alldone
)

%_info% "=========="
%_info% "processing custom installation list '%instlist%'"
@echo off
for /f "tokens=1,2 delims= " %%a in ('type "%script_dir%\custom\%instlist%"') do (
  set fnpl=%%a
  set fl=%%b
  set "cil_install=true"
  if "!fl!"=="peazips" ( set "cil_install=false" )
  if "!fl!"=="gits" ( set "cil_install=false" )
  if "!fl!"=="vscodes" ( set "cil_install=false" )
  if "!fl!"=="gums" ( set "cil_install=false" )
  if "!fl!"=="pxs" ( set "cil_install=false" )
  if "!fl!"=="sysinternalsSuites" ( set "cil_install=false" )
  if "!fl!"=="npps" ( set "cil_install=false" )
  if "!fl!"=="terminals" ( set "cil_install=false" )
  if "!fl!"=="git-cliffs" ( set "cil_install=false" )
  if "!fl!"=="jqs" ( set "cil_install=false" )
  if "!cil_install!"=="true" (
      call:install "!fnpl!" "!fl!" || exit /b 1
  )
)
if not exist "%locald%\install.list" (
    %_ok% "no local install list '%locald%\install.list', so no more list to process"
    goto:alldone
)
set "setupsdir=%locald%\setups"
%_info% "=========="
%_info% "processing local installation list in '%locald%\install.list'"
for /f "tokens=1,2 delims= " %%a in ('type "%locald%\install.list"') do (
  set fnpl=%%a
  set fl=%%b
  call:install "!fnpl!" "!fl!" || exit /b 1
)


:alldone
set "gcua_hosts_name="
if exist "%HOME%\bin\senv.custom.all_teams.gcua.list" ( set "gcua_hosts_name=senv.custom.all_teams.gcua.list" )
if not "%profile%"=="" if exist "%HOME%\bin\senv.custom.%profile%.gcua.list" ( set "gcua_hosts_name=senv.custom.%profile%.gcua.list" )
if defined gcua_hosts_name (
    if exist "%PRGS%\gits\current\cmd\git.exe" (
        %_task% "Must apply the team git identity, per %gcua_hosts_name%"
        call "%HOME%\bin\gcua.bat"
        if errorlevel 1 (
            %_warning% "team git identity pass failed: run 'gcua' manually to diagnose"
        ) else (
            %_ok% "team git identity pass done, per %gcua_hosts_name%"
        )
    )
)
set "gcua_hosts_name="
%_ok% "All done"
ENDLOCAL
for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%"
cd
call custom\setup.ini.bat "set"
set "err=%ERRORLEVEL%"
if not "%err%"=="0" (
 %_fatal% "custom/setup.ini.bat still missing" %err%
)
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
set "_sed="
if exist "%PRGS%\gits\current\usr\bin\sed.exe" (
    set "_sed=%PRGS%\gits\current\usr\bin\sed.exe"
)
if defined _sed (
    "%_sed%" -i "s/^\s\+[\r\n]*$//g" "%script_dir%\tmp"
)
rem sed writes LF endings: restore CRLF, or git flags senv.local.doskey
rem as modified against the eol=crlf attribute of the HOME repository
where unix2dos >NUL 2>NUL
if not errorlevel 1 ( unix2dos -q "%script_dir%\tmp" )
del "%HOME%\bin\senv.local.doskey"
move "%script_dir%\tmp" "%HOME%\bin\senv.local.doskey" >NUL
cd /d "%script_dir%"
rem del /F "%script_dir%\tmp" 2>NUL

set script_dir=
set profile=
set setupsdirbat=
set setupsdir=
echo calling senv.bat: You are good to go!
call "%HOME%\bin\senv.bat"
goto:eof

:install
set "p=%~1"
set "f=%~2"
set "sys=%~3"
if not "%prgtoinstall%"=="" (
    if not "%prgtoinstall%"=="%f%" (
        %_warning% "Skip '%f%' installation (for '%prgtoinstall%')"
        rem @echo on
        goto:eof
    )
)

if "%p%"=="system" ( set "pname=system" && set "fname=" && goto:info )
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
        %_warning% "Skip '%f%' installation (test found) in '%setupsdir%\_%f%'"
        goto:eof
    )
    %_warning% "No setup file found in '%setupsdir%' for '%f%', pattern '%p%'"
) else ( goto:info )
%_task% "Must check if '%f%', pattern '%p%' is in local setup dir '%setup_dir%'"
if exist "%setup_dir%\%p%" (
    for /F "usebackq" %%i in (`dir /OD /B "%setup_dir%\%p%"`) do set "fname=%%~nxi"&& set "pname=%%~ni"
)
if "%pname%"=="" (
    if exist "%setup_dir%\_%f%" (
        %_warning% "Skip '%f%' installation (test found) in local '%setup_dir%\_%f%'"
        goto:eof
    )
    %_fatal% "No setup file found in local '%setup_dir%' for '%f%', pattern '%p%'" 112
)
:info
%_info% "--------------"
%_info% "folder: '%f%': pattern '%pname%' system: '%sys%'"
%_info% "--------------"
set "sln="
if exist "%HOME%\.gitconfig" (
    call "%script_dir%\installs\gits.config.utils.bat" :save_gitconfig Install '%f%': '%pname%'
)
set pre_ok=false
call :check_pre "%f%" "%fname%" "%pname%" || exit /b 1
%_info% "pname='%pname%', f='%f%', fname='%fname%' means sys='%sys%'"
if "%pre_ok%"=="true" (
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    %_ok% "pre-check ok for %f%: nothing more to do"&& exit /b 0
)
set "tpath=%PRGS%\%f%\_%pname%"
if exist "%tpath%" (
    %_ok% "Program '%pname%' already installed in '%PRGS%\%f%'"
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    call:check_post "%f%" "!sln!" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
set "tpath=%PRGS%\%f%\%pname%"
if exist "%tpath%" (
    %_ok% "Program '%pname%' already installed2 in '%PRGS%\%f%', sln '%sys%'"
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    call:check_post "%f%" "!sln!" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
if not exist "%PRGS%\setup\" (
    mkdir "%PRGS%\setup\"
)
if not exist "%PRGS%\setup\%fname%" (
    %_info% "Copying '%fname%' from '%setupsdir%'"
    (robocopy "%setupsdir%" "%PRGS%\setup" "%fname%" /Z /R:5 /W:5 /TBD /MT:16 /NJH /NJS) ^& IF %ERRORLEVEL% LSS 8 SET ERRORLEVEL = 0
    if not "%ERRORLEVEL%"=="0" ( %_fatal% "Unable to copy '%setupsdir%\%fname%' to '%PRGS%\setup\'" && exit /b 1)
    %_ok% "Setup '%fname%' copied locally"
)
set install_ok=false
call:check_install "%f%" "%fname%" "%pname%" || exit /b 1
if "%install_ok%"=="true" (
    %_ok% "install ok for %f%: nothing more to do"&& exit /b 0
)
if "%install_ok%"=="check_symlink" (
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    exit /b 0
)
if "%f%"=="vscodes" (
    %_warning% "should not be here"&& exit /b 1
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
    %_task% "Must uncompress with powershell '%fname%' to '%tpath%'"
    rem https://stackoverflow.com/questions/33729801/returning-exit-code-from-a-batch-file-in-a-powershell-script-block#comment55261380_33730519
    powershell.exe -nologo -noprofile -ExecutionPolicy UnRestricted; $var = "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('%PRGS%\setup\%fname%', '%tpath%'); $res=$?; Write-Host \"LASTEXITCODE='$res'\";if (-not $res) { return 1; }; return 0;}"; exit $var
    if errorlevel 1 ( %_fatal% "Error on powershell uncompression"&& exit /b 1 )
    %_ok% "'%fname%' uncompressed (powershell) to '%tpath%'"
    call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
    call:check_post "%f%" "!sln!" || exit /b 1
    cd /d "%script_dir%"
    goto:eof
)
set pz=%PRGS%\peazips\current
set sz=%pz%\res\7z\7z.exe
cd /d "%PRGS%\%f%"
%_task% "Must uncompress with 7z '%PRGS%\setup\%fname%' to '%tpath%'"
call "%HOME%\bin\pzxx.bat" "%PRGS%\setup\%fname%"
if errorlevel 1 (
    rmdir /s /q "%tpath%"
    %_fatal% "Error on 7z uncompression" 1
)
%_ok% "'%fname%' uncompressed (7z) to '%tpath%'"
:postinstall
call "%script_dir%\installs\check_symlink.bat" "%pname%" "%f%" "%sys%"
call:check_post "%f%" "!sln!" || exit /b 1
cd /d "%script_dir%"
goto:eof



:check_post
set "f=%~1"
set "sln=%~2"
if not defined sln (
    %_fatal% "No symlink name defined for '%f%' check_post" 79
)
%_info% "check_post for '%f%' sln '%sln%'"
if exist "%script_dir%\installs\%f%.post.bat" (
    call "%script_dir%\installs\%f%.post.bat" "%sln%" || exit /b 1
)
if /i "%f%"=="gits" (
    call:activate_git_path || exit /b 1
)
if exist "%script_dir%\custom\%f%.post.bat" (
    call "%script_dir%\custom\%f%.post.bat" "%sln%" || exit /b 1
)
if exist "%locald%\%f%.post.bat" (
    call "%locald%\%f%.post.bat" "%sln%" || exit /b 1
)
goto:eof

:activate_git_path
if not defined PRGS (
    %_fatal% "PRGS not defined: unable to activate Git PATH" 94
)
if not defined HOME (
    %_fatal% "HOME not defined: unable to activate Git PATH" 95
)
set "GH=%PRGS%\gits\current"
if not exist "%GH%\bin\git.exe" (
    %_fatal% "git.exe missing at '%GH%\bin': unable to activate Git PATH" 96
)
set "PATH=%HOME%\bin;%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%GH%\mingw64\libexec\git-core;%PATH%"
where git >NUL 2>NUL
if errorlevel 1 (
    %_fatal% "git.exe still not found on PATH after activating '%GH%'" 97
)
where awk >NUL 2>NUL
if errorlevel 1 (
    %_fatal% "awk.exe still not found on PATH after activating '%GH%\usr\bin'" 98
)
%_ok% "Git PATH activated from '%GH%'"
goto:eof

:activate_proxy_env
if not defined HOME (
    %_fatal% "HOME not defined: unable to activate proxy environment" 99
)
if not exist "%HOME%\bin\senv.custom.bat" (
    %_fatal% "senv.custom.bat missing at '%HOME%\bin': unable to activate proxy environment" 100
)
call "%HOME%\bin\senv.custom.bat"
if not defined HTTP_PROXY (
    %_fatal% "HTTP_PROXY not defined after calling '%HOME%\bin\senv.custom.bat'" 101
)
if not defined HTTPS_PROXY (
    %_fatal% "HTTPS_PROXY not defined after calling '%HOME%\bin\senv.custom.bat'" 102
)
%_ok% "Proxy environment activated: HTTP_PROXY='%HTTP_PROXY%', HTTPS_PROXY='%HTTPS_PROXY%'"
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

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
