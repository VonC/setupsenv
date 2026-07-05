@echo off
setlocal enabledelayedexpansion

rem getstarted.bat [profile] ["Full Name"] [email]
rem
rem Unattended onboarding for a new senv user, no admin rights needed:
rem  - seeds the custom\ nested repository from custom_example\
rem  - registers a minimal profile, default name 'perso'
rem  - registers locations and git identity, so nothing prompts
rem  - downloads a minimal portable tool set with the Windows curl
rem  - runs setup.bat, which installs the tools and creates the senv HOME
rem  - makes custom\ a local git repository
rem
rem Optional overrides, to set before calling:
rem   set "PRGS=D:\SOFTWARE"     (programs root)
rem   set "HOME=..."             (senv user home)
rem   set "PROG=..."             (work folder, for git repositories)
rem   set "HTTPS_PROXY=..."      (if downloads must go through a proxy)
rem
rem Skipped on onboarding (marker files in setups\): pxs, terminals,
rem git-cliffs, jqs. Delete the setups\_<name> marker and run 'div <tool>'
rem later to add one of them.

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
cd /d "%script_dir%" || echo unable to cd to '%~dp0'&& exit /b 1

if not exist "%script_dir%\batcolors\echos_macros.bat" (
    where git >NUL 2>NUL
    if errorlevel 1 (
        echo [ERROR] 'batcolors\' is missing and git is not available to fetch it.
        echo         Clone with: git clone --recurse-submodules https://github.com/VonC/setupsenv senv
        exit /b 1
    )
    git -C "%script_dir%" submodule update --init batcolors
    if errorlevel 1 (
        echo [ERROR] unable to fetch the batcolors submodule
        exit /b 1
    )
)
call "%script_dir%\batcolors\echos_macros.bat"

set "syscurl=%SystemRoot%\System32\curl.exe"
if not exist "%syscurl%" (
    %_fatal% "curl.exe not found in System32: Windows 10 1803 or more recent is required" 2
)

set "gs_profile=%~1"
if "%gs_profile%"=="" ( set "gs_profile=perso" )
set "gs_fullname=%~2"
if "%gs_fullname%"=="" ( set "gs_fullname=%USERNAME%" )
set "gs_usermail=%~3"
if "%gs_usermail%"=="" ( set "gs_usermail=%USERNAME%@%COMPUTERNAME%" )
%_info% "Onboarding: profile '%gs_profile%', git identity '%gs_fullname% <%gs_usermail%>'"

rem ---------------------------------------------------------------- 1. custom
if not exist "%script_dir%\custom" (
    %_task% "Must create custom\ from custom_example\"
    mkdir "%script_dir%\custom"
    copy "%script_dir%\custom_example\*" "%script_dir%\custom" >NUL
    if errorlevel 1 ( %_fatal% "unable to seed custom\ from custom_example\" 3 )
    %_ok% "custom\ created from custom_example\"
)
if not exist "%script_dir%\custom\profile" (
    echo|set /p="%gs_profile%"> "%script_dir%\custom\profile"
    %_ok% "active profile '%gs_profile%' written to custom\profile"
)
for /f "delims=" %%x in (%script_dir%\custom\profile) do set "gs_profile=%%x"
if not exist "%script_dir%\custom\install_%gs_profile%.list" (
    type NUL > "%script_dir%\custom\install_%gs_profile%.list"
    %_ok% "empty application list custom\install_%gs_profile%.list created: base tools only"
)
if not exist "%script_dir%\custom\setupsdir_%gs_profile%.bat" (
    (
        echo @echo off
        echo set "setupsdir=%%~dp0..\setups"
    ) > "%script_dir%\custom\setupsdir_%gs_profile%.bat"
    %_ok% "custom\setupsdir_%gs_profile%.bat created: archives read from senv\setups"
)
set "setup_dl=%script_dir%\setups"
if not exist "%setup_dl%" ( mkdir "%setup_dl%" )
for %%m in (pxs terminals git-cliffs jqs) do (
    if not exist "%setup_dl%\_%%m" ( type NUL > "%setup_dl%\_%%m" )
)

rem ------------------------------------------------------------- 2. locations
set "senv_noconfirm=1"
call "%script_dir%\custom\setup.ini.bat"
if errorlevel 1 ( %_fatal% "custom\setup.ini.bat failed" 4 )
if "%PRGS%"=="" ( %_fatal% "PRGS not set by custom\setup.ini.bat" 4 )
if "%HOME%"=="" ( %_fatal% "HOME not set by custom\setup.ini.bat" 4 )
if "%PROG%"=="" ( %_fatal% "PROG not set by custom\setup.ini.bat" 4 )
%_ok% "PRGS='%PRGS%', HOME='%HOME%', PROG='%PROG%', REMOTE_HOME='%REMOTE_HOME%'"

rem ------------------------------------------- 3. locations and git identity
rem senv.local.pre.bat is a create-once file: setup.bat will keep it, and the
rem registered identity keeps the git install hook from prompting.
if not exist "%HOME%\bin" ( mkdir "%HOME%\bin" )
if not exist "%HOME%\bin\senv.local.pre.bat" (
    (
        echo @echo off
        echo set "PRGS=%PRGS%"
        echo set "PROG=%PROG%"
        echo set "REMOTE_HOME=%REMOTE_HOME%"
        echo set "HOME=%HOME%"
        echo set "FIRSTNAME="
        echo set "LASTNAME=%gs_fullname%"
        echo set "FULLNAME=%gs_fullname%"
        echo set "USERMAIL=%gs_usermail%"
        echo rem ---
    ) > "%HOME%\bin\senv.local.pre.bat"
    %_ok% "senv.local.pre.bat pre-seeded with locations and git identity"
)

rem ------------------------------------------------------ 4. minimal tool set
%_info% "Downloading the minimal tool set into '%setup_dl%'"

if exist "%setup_dl%\peazip_portable-*" (
    %_ok% "peazip archive already present"
) else (
    call :get_tag "peazip/PeaZip" || exit /b 5
    call :dl "https://github.com/peazip/PeaZip/releases/download/!gh_tag!/peazip_portable-!gh_ver!.WIN64.zip" "peazip_portable-!gh_ver!.WIN64.zip" || exit /b 5
)

if exist "%setup_dl%\PortableGit-*" (
    %_ok% "PortableGit archive already present"
) else (
    call :get_tag "git-for-windows/git" || exit /b 5
    rem tag v2.55.0.windows.1 -> asset 2.55.0, tag v2.55.0.windows.2 -> asset 2.55.0.2
    if "!gh_ver:~-10!"==".windows.1" (
        set "gitver=!gh_ver:~0,-10!"
    ) else (
        set "gitver=!gh_ver:.windows.=.!"
    )
    call :dl "https://github.com/git-for-windows/git/releases/download/!gh_tag!/PortableGit-!gitver!-64-bit.7z.exe" "PortableGit-!gitver!-64-bit.7z.exe" || exit /b 5
)

if exist "%setup_dl%\gum_*_Windows_x86_64.zip" (
    %_ok% "gum archive already present"
) else (
    call :get_tag "charmbracelet/gum" || exit /b 5
    call :dl "https://github.com/charmbracelet/gum/releases/download/!gh_tag!/gum_!gh_ver!_Windows_x86_64.zip" "gum_!gh_ver!_Windows_x86_64.zip" || exit /b 5
)

if exist "%setup_dl%\npp.*.portable.x64.zip" (
    %_ok% "Notepad++ archive already present"
) else (
    call :get_tag "notepad-plus-plus/notepad-plus-plus" || exit /b 5
    call :dl "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/!gh_tag!/npp.!gh_ver!.portable.x64.zip" "npp.!gh_ver!.portable.x64.zip" || exit /b 5
)

if exist "%setup_dl%\SysinternalsSuite-*.zip" (
    %_ok% "Sysinternals archive already present"
) else (
    call :dl "https://download.sysinternals.com/files/SysinternalsSuite.zip" "SysinternalsSuite-latest.zip" || exit /b 5
)

if exist "%setup_dl%\VSCodeUserSetup-x64-*" (
    %_ok% "VSCode setup already present"
) else (
    call :dl "https://update.code.visualstudio.com/latest/win32-x64-user/stable" "VSCodeUserSetup-x64-stable.exe" || exit /b 5
)

rem ------------------------------------------------------------------ 5. setup
%_info% "=========================================="
%_info% "Running setup.bat, profile '%gs_profile%'"
%_info% "=========================================="
call "%script_dir%\setup.bat"
if errorlevel 1 ( %_fatal% "setup.bat failed" 6 )

rem --------------------------------------------------- 6. custom as a git repo
set "gitexe=%PRGS%\gits\current\cmd\git.exe"
if not exist "%gitexe%" ( set "gitexe=git" )
if not exist "%script_dir%\custom\.git" (
    %_task% "Must turn custom\ into a git repository"
    "%gitexe%" -C "%script_dir%\custom" init
    "%gitexe%" -C "%script_dir%\custom" add -A
    "%gitexe%" -C "%script_dir%\custom" -c user.name="%gs_fullname%" -c user.email="%gs_usermail%" commit -m "chore: initial custom configuration"
    if errorlevel 1 (
        %_warning% "custom\ initialized, but the first commit failed: commit it manually"
    ) else (
        %_ok% "custom\ is now a git repository, first commit done"
    )
)
"%gitexe%" config --file "%HOME%\.gitconfig" user.name >NUL 2>NUL
if errorlevel 1 ( "%gitexe%" config --file "%HOME%\.gitconfig" user.name "%gs_fullname%" )
"%gitexe%" config --file "%HOME%\.gitconfig" user.email >NUL 2>NUL
if errorlevel 1 ( "%gitexe%" config --file "%HOME%\.gitconfig" user.email "%gs_usermail%" )

rem -------------------------------------------------------------------- 7. done
echo.
%_ok% "senv is ready."
echo.
echo   Open a NEW terminal and type:  senv
echo.
echo   Next steps:
echo    - add a tool on demand:            div node     or: dwl jdk 21 + inst jdk
echo    - personal variables:              senve, then senv to reload all
echo    - personal aliases:                aliase, then aliasr to reload them
echo    - give custom\ a private remote:   git -C custom remote add origin your-private-url
echo    - team profiles and distribution:  wiki\how-to\create-a-team-profile.md
echo    - full documentation:              wiki\README.md
echo.
endlocal
goto:eof

rem ---------------------------------------------------------------------------
rem :get_tag org/repo  -- resolves the latest GitHub release: gh_tag, gh_ver
:get_tag
set "gt_repo=%~1"
set "gh_tag="
set "gh_ver="
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/%gt_repo%/releases/latest"
for /f "tokens=* delims=" %%a in ('%cmd%') do ( set "gu=%%a" )
for /f "tokens=7 delims=/" %%a in ("%gu%") do ( set "gh_tag=%%a" )
if "%gh_tag%"=="" (
    %_error% "unable to resolve the latest release of '%gt_repo%'"
    exit /b 1
)
if "%gh_tag:~0,1%"=="v" ( set "gh_ver=%gh_tag:~1%" ) else ( set "gh_ver=%gh_tag%" )
%_info% "latest %gt_repo%: '%gh_tag%'"
goto:eof

rem :dl url filename  -- downloads url into setups\filename
:dl
set "dl_url=%~1"
set "dl_fname=%~2"
%_task% "Must download '%dl_fname%'"
"%syscurl%" -fkL --retry 3 -o "%setup_dl%\%dl_fname%.part" "%dl_url%"
if errorlevel 1 (
    del "%setup_dl%\%dl_fname%.part" 2>NUL
    %_error% "download failed: '%dl_url%'"
    %_error% "download the file manually into '%setup_dl%', then rerun getstarted.bat"
    exit /b 1
)
move /y "%setup_dl%\%dl_fname%.part" "%setup_dl%\%dl_fname%" >NUL
%_ok% "'%dl_fname%' downloaded"
goto:eof
