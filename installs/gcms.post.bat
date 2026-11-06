@echo off
rem Puts the standalone Git Credential Manager of %PRGS%\gcms\current ('dwl gcm',
rem 'inst gcm') in use by the current Git, when it is newer than the GCM Git for
rem Windows bundles (Git for Windows 2.56.0.4 bundles GCM 2.9.1, and Bitbucket
rem Cloud refuses a GCM older than 3.0.0 from 2026-11-30).
rem
rem The credential helper stays 'manager': Git runs it as 'git credential-manager'
rem and looks for git-credential-manager.exe in its own folders (libexec\git-core,
rem then ucrt64\bin) before PATH. A standalone GCM put first on PATH is ignored,
rem so this hook copies it over the bundled one in ucrt64\bin (mingw64\bin before
rem Git for Windows 2.56), after renaming each replaced file to <name>.bundled.
rem
rem Called after 'inst gcm' (inst_prg.bat, setup.bat), and by gits.post.bat after
rem each Git installation, since a new Git folder starts with its bundled GCM.
rem Running it again changes nothing: the .bundled copies are made once, and
rem robocopy skips the files already copied.
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"

%_info% "~~~~~~~~~~~~ Git Credential Manager post installation ~~~~~~~~~~~~"

if not defined PRGS (
    %_fatal% "PRGS is not defined" 80
)
set "gcm_rc=0"
set "gcm_dir=%PRGS%\gcms\current"
set "gcm_exe=%gcm_dir%\git-credential-manager.exe"
if not exist "%gcm_exe%" (
    %_info% "No standalone GCM in '%gcm_dir%': Git keeps its bundled GCM"
    goto:endlocal
)
set "GH=%PRGS%\gits\current"
set "GH_MINGW=%GH%\ucrt64"
if not exist "%GH_MINGW%\bin\git.exe" set "GH_MINGW=%GH%\mingw64"
if not exist "%GH_MINGW%\bin\git.exe" (
    %_warning% "No Git in '%GH%' yet: gits.post.bat puts the standalone GCM in use once Git is installed"
    goto:endlocal
)
set "git_bin=%GH_MINGW%\bin"

rem The standalone version: 'git-credential-manager --version' prints 3.0.2+<commit>.
set "gcm_version="
for /f "tokens=1 delims=+" %%v in ('""%gcm_exe%" --version 2^>NUL"') do set "gcm_version=%%v"
if not defined gcm_version (
    %_error% "Unable to get the version of '%gcm_exe%'"
    set "gcm_rc=81"
    goto:endlocal
)
rem The bundled version, from the package list, which still names the bundled
rem GCM after a copy: mingw-w64-ucrt-x86_64-git-credential-manager 2.9.1-1
set "bundled_version=0.0.0"
for /f "tokens=2 delims= " %%v in ('findstr /C:"-git-credential-manager " "%GH%\etc\package-versions.txt" 2^>NUL') do set "bundled_version=%%v"
for /f "tokens=1 delims=-" %%v in ("%bundled_version%") do set "bundled_version=%%v"
call:version_number "%gcm_version%" gcm_number
call:version_number "%bundled_version%" bundled_number
if !bundled_number! GEQ !gcm_number! (
    %_ok% "Git bundles GCM %bundled_version%, not older than the standalone GCM %gcm_version%: Git keeps its bundled GCM, '%PRGS%\gcms' can go"
    goto:endlocal
)

%_task% "Must replace the bundled GCM %bundled_version% in '%git_bin%' by the standalone GCM %gcm_version%"
rem Rename, not delete: a GCM running at that moment keeps its file, and the
rem bundled GCM can come back by renaming the .bundled files.
for %%f in ("%gcm_dir%\*.exe" "%gcm_dir%\*.dll") do (
    if exist "%git_bin%\%%~nxf" if not exist "%git_bin%\%%~nxf.bundled" (
        move "%git_bin%\%%~nxf" "%git_bin%\%%~nxf.bundled" >NUL
        if errorlevel 1 (
            %_error% "Unable to rename '%git_bin%\%%~nxf' to '%%~nxf.bundled'"
            set "gcm_rc=82"
        )
    )
)
if not "%gcm_rc%"=="0" goto:endlocal
robocopy "%gcm_dir%" "%git_bin%" *.exe *.dll /R:2 /W:2 /NJH /NJS /NFL /NDL /NP >NUL
if errorlevel 8 (
    %_error% "Unable to copy the standalone GCM from '%gcm_dir%' to '%git_bin%'"
    set "gcm_rc=83"
    goto:endlocal
)

rem What Git itself runs for the 'manager' helper.
set "git_gcm_version="
for /f "tokens=1 delims=+" %%v in ('""%GH%\cmd\git.exe" credential-manager --version 2^>NUL"') do set "git_gcm_version=%%v"
if not "%git_gcm_version%"=="%gcm_version%" (
    %_error% "'git credential-manager --version' gives '%git_gcm_version%', not the standalone GCM %gcm_version%"
    set "gcm_rc=84"
    goto:endlocal
)
%_ok% "Git runs the standalone GCM %gcm_version% for its 'manager' credential helper (bundled GCM %bundled_version% kept as *.bundled in '%git_bin%')"

:endlocal
endlocal & set "gcm_rc=%gcm_rc%"
if defined standalone_%~nx0 (
    call "%PRGS%\senv\batcolors\echos_macros.bat" unset
    set "standalone_%~nx0="
    set "setup_dir="
    set "senv_dir="
    set "prgname="
    set "batdir="
)
set "standalone_%~nx0="
for %%r in (%gcm_rc%) do set "gcm_rc=" & exit /b %%r

:version_number
rem 3.0.2 gives 3000002, for a numeric comparison.
set "vn_major="
set "vn_minor="
set "vn_patch="
for /f "tokens=1-3 delims=." %%a in ("%~1") do (
    set "vn_major=%%a"
    set "vn_minor=%%b"
    set "vn_patch=%%c"
)
set /a "%~2=vn_major*1000000+vn_minor*1000+vn_patch"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
