@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat
for %%i in ("%PRGS%\setup") do (
    set "setup_dir=%%~fi"
)

set "repo="
set "version="
set "file="
set "target_local_file="
set "url="
set "cmd="

if "%~1"=="--get-latest-version" (
  %_info% "[%~nx0] get latest version"
  shift
  call :get_latest_version "%~2" "%~3"
  goto:eof
)

%_info% "[%~nx0] dwl prg_name [version] (default latest)"

if not exist "%PRGS%\gums\current\gum.exe" (
  %_fatal% "[%~nx0] gum.exe not found in '%PRGS%\gums\current'" 1
)
set "PATH=%PRGS%\gums\current;%PATH%"

set "prgname=%~1"
if not defined prgname (
  set "prgname=choose"
)

set "version=%~2"
if not defined version (
  set "version=latest"
)
call "%script_dir%\select_prg.bat" "%prgname%" "%version%"
if not defined prg_id (
    %_fatal% "[%~nx0] empty prg_id after selecting prg from '%prg_name%'" 9
)

if "%prgname%"=="" (
  %_fatal% "[%~nx0] No program selected" 1
)
set "prgname=%prg_id%"
set "version=%prg_version%"
if not "%version%"=="" (
  if "%prgname%"=="jdk" (
    set "jdk_version=%version%"
  )
  if "%prgname%"=="java" (
    set "jdk_version=%version%"
  )
  if "%prgname%"=="python" (
    set "python_cycle=%version%"
    set "version=latest"
  )
  goto:proceed
)
set "version=latest"

if not "%prgname%"=="jdk" ( goto:not_jdk )
set "jdk_versions=11 13 15 17 19 20 21 22 23"
for /f "delims=" %%p in ('gum choose --limit=1 %jdk_versions%') do set "jdk_version=%%p"
if "%jdk_version%"=="" (
  %_fatal% "[%~nx0] No JDK version selected" 1
)

:not_jdk
if not "%prgname%"=="python" ( goto:not_python )
set "python_cycles=3.11 3.12 3.13"
for /f "delims=" %%p in ('gum choose --limit=1 %python_cycles%') do set "python_cycle=%%p"
if "%python_cycle%"=="" (
  %_fatal% "[%~nx0] No Python cycle version selected" 1
)

:not_python
:proceed
%_info% "[%~nx0] Dwl '%prgname%' version '%version%'"
:: findstr /R /C:"dwl_gum" "%PRGS%\senv\bin\dwl.bat" || echo %ERRORLEVEL%
findstr /R "^:dwl_%prgname% $" "%script_dir%\dwl.bat" >nul
if errorlevel 1 (
  %_fatal% "[%~nx0] Program '%prgname%' not supported by '%script_dir%\dwl.bat'" 1
)
call :dwl_%prgname%
goto:eof

:: dwl --get-latest-version github charmbracelet/gum
:get_latest_version
if "%~1"=="" (
  %_fatal% "[%~nx0] --get-latest-version means method and mean (github and repo charmbracelet/gum or grep and url,pattern)" 1
)
if "%~1"=="github" (
  %_info% "[%~nx0] get latest version from github"
  shift
  call :get_latest_version_from_github "%~2"
  goto:eof
)
%_fatal% "[%~nx0] --get-latest-version method not recognized" 1
goto:eof

:get_latest_version_from_github
if not "%~1"=="" (
  set "repo=%~1"
)
if not defined repo (
  %_fatal% "[%~nx0] --get-latest-version github means repo (ex: charmbracelet/gum)" 1
)
echo.%repo%| findstr /R /C:"^[a-Z0-9_-]*/[a-Z0-9_-]*$" >nul
rem echo %ERRORLEVEL%
if errorlevel 1 (
    %_fatal% "[%~nx0] repo must be in the format org/repo (ex: charmbracelet/gum), not '%repo%'" 1
)
%_task% "[%~nx0] Must get latest version from github for repo '%repo%'"
set "url=https://api.github.com/repos/%repo%/releases/latest"
set "version="
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://github.com/%repo%/releases/latest"
rem echo.%cmd%
for /f "tokens=* delims=" %%a in ('%cmd%') do ( set gu=%%a)
if errorlevel 1 (
    %_fatal% "[%~nx0] Cannot get latest version from github for repo '%repo%' with cmd '%cmd%'" 1
)
rem echo.Latest version URL='%gu%'
for /f "tokens=1,2,3,4,5,6,7,8 delims=/" %%a in ("%gu%") do set version=%%g
set "tag=%version%"
set "version=%version:v=%"
%_ok% "[%~nx0] version '%version%' is latest for repo '%repo%'"
set "url="
goto:eof

:template
if not defined file ( %_fatal% "[%~nx0] [template] file must be defined for '%prgname%'" 1 )
if not defined url ( %_fatal% "[%~nx0] [template] url must be defined for '%prgname%'" 1 )
if "%target_local_file%"=="" ( set "target_local_file=%file%")
CALL:ReplaceText "!file!" "[v]" "%version%"  file
CALL:ReplaceText "!target_local_file!" "[v]" "%version%"  target_local_file
if not "%prgname%"=="jdk" ( CALL:ReplaceText "!url!" "[v]" "%version%"  url )
goto:eof

:curl
call :template
%_info% "[%~nx0] URL file='%file%', target file '%target_local_file%'"

if exist "%setup_dir%\%target_local_file%" (
    %_ok% "[%~nx0] '%target_local_file%' Already downloaded in setup_dir '%setup_dir%'"
    goto:eof
)

%_task% "[%~nx0] Download latest to '%setup_dir%\%target_local_file%' from URL '!url!'"
rem bash -c "a="2,3"; echo _${a/,/%}_"
rem @echo on
rem for /f "delims=" %%a in ('cygpath -u "%setup_dir%\%target_local_file%"') do set "target_full_unix_path=%%a"
rem bash -c "url="%url%"; url="${url/,/^%%}"; echo "url='${url}'"; dst="%target_full_unix_path%"; curl -fkL "${url}" -o "${dst}""
curl -fkL "%url%" -o "%setup_dir%\%target_local_file%"
if not "%ERRORLEVEL%" == "0" (
  if not defined next_url (
    %_fatal% "[%~nx0] Unable to download '%setup_dir%\%target_local_file%' from latest, URL '%url%'" 191
  ) else (
    %_error% "[%~nx0] Unable to download '%setup_dir%\%target_local_file%' from latest, URL '%url%'
    exit /b 1
  )
)
%_ok% "[%~nx0] '%target_local_file%' downloaded to '%setup_dir%'"
goto:eof

:ReplaceText
:: https://stackoverflow.com/questions/2772456/string-replacement-in-batch-file
:: https://stackoverflow.com/a/62597777/6309
:: CALL:ReplaceText "!OriginalText!" OldWordToReplace NewWordToUse  Result
::Example
::SET "MYTEXT=jump over the chair"
::  echo !MYTEXT!
::  call:ReplaceText "!MYTEXT!" chair table RESULT
::  echo !RESULT!
:: Remember to use the "! on the input text, but NOT on the Output text.
:: Remember to add quotes "" around the MYTEXT Variable when calling.
::
set "OriginalText=%~1"
set "OldWord=%~2"
set "NewWord=%~3"
call set OriginalText=%%OriginalText:!OldWord!=!NewWord!%%
SET %4=!OriginalText!
GOTO:EOF

:dwl_gum
set "repo=charmbracelet/gum"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl 'charmbracelet/gum' version '%version%'"
set "file=%prgname%_%version%_Windows_x86_64.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_firefox
if not "%version%"=="latest" ( %_fatal% "[%~nx0] Firefox version '%version%' not supported: only latest" 1 )
set "cmd=curl -IkLs -o NUL -w %%{url_effective} https://softaro.net/download-file/21759/?version=English 2^>^&1"
%_task% "[%~nx0] Must check latest Firefox version"
for /f "tokens=* delims=" %%a in ('%cmd%^|grep Firefox') do ( set gu=%%a)
if errorlevel 1 (
    %_fatal% "[%~nx0] Cannot get latest version from softaro.net for Firefox with cmd '%cmd%'" 1
)
set "gu=%gu:HTTP/1.1 403 Forbidden=%"
if not "%gu:Japanese=%"=="%gu%" (
  set "gu=%gu:Japanese=English%"
)
for /f "tokens=2 delims=:" %%a in ("%gu%") do set gu=https:%%a
set "gu=%gu:exehttp=exe%"
%_ok% "[%~nx0] Latest Firefox version URL='%gu%'"
for /f "tokens=1,2,3,4,5 delims=/" %%a in ("%gu%") do set version=%%e
set "version=%version:HTTP=%"
set "version=%version:*FirefoxPortable_=%"
set "version=%version:_English.paf.exe=%"
set "url=%gu%"
set "file=FirefoxPortable_%version%_English.paf.exe"
call :curl
goto:eof

:dwl_chrome
:dwl_chromium
set "repo=Hibbiki/chromium-win64"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl '%prgname%' version '%version%'"
set "file=chrome.sync.7z"
set "target_local_file=chromev%version%.7z"
rem https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.sync.7z
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_gh
set "repo=cli/cli"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
set "file=gh_%version%_windows_amd64.zip"
rem https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_git
set "repo=git-for-windows/git"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
set "file=PortableGit-%version%-64-bit.7z.exe"
set "file=%file:.windows.1=%"
set "file=%file:.windows.=.%"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_go
rem <td class="filename"><a class="download" href="/dl/go1.23.2.windows-amd64.zip">go1.23.2.windows-amd64.zip</a></td>
if defined version ( if not "%version%"=="latest" ( goto:go_version_set ) )
%_task% "[%~nx0] Must get latest Go version"
curl -sLk https://go.dev/dl/ 2>&1 | findstr .windows-amd64.zip > "%script_dir%\go_vers.txt"
if errorlevel 1 (
    %_fatal% "[%~nx0] Cannot get latest version from go.dev for Go with cmd '%cmd%'" 1
)
for /f "delims=" %%a in ('sed -e "s/.*zip.>//" -e "s/<.*//" "%script_dir%\go_vers.txt"') do (
  set "file=%%a"
  goto :go_file_set
)
:go_file_set
set "version=%file:go=%"
set "version=%version:.windows-amd64.zip=%"
del "%script_dir%\go_vers.txt"
%_ok% "[%~nx0] Latest Go version URL='%version%' for file '%file%'"
:go_version_set
if not defined file (
  rem https://go.dev/dl/go1.19.windows-amd64.zip
  rem https://mirrors.aliyun.com/golang/go1.19.windows-amd64.zip
  rem https://studygolang.com/dl/golang/go1.19.windows-amd64.zip
  set "file=go%version%.windows-amd64.zip"
)
%_info% "[%~nx0] Dwl (%prgname%) version '%version%'"
set "url=https://fossies.org/windows/misc/%file%"
set "next_url=https://studygolang.com/dl/golang/%file%"
call :curl
if errorlevel 1 (
  set "url=%next_url%"
  %_task% "[%~nx0] Must try withURL from studygolang.com for Go version '%version%'"
  set "next_url=https://mirrors.aliyun.com/golang/%file%"
  call :curl
)
if errorlevel 1 (
  set "url=%next_url%"
  set "next_url="
  %_task% "[%~nx0] Must try withURL from mirrors.aliyun.com for Go version '%version%'"
  call :curl
)
set "next_url="
goto:eof

:dwl_java
:dwl_jdk
if "%jdk_version%"=="" ( %_fatal% "[%~nx0] jdk_version needs to be set (17, 21, ...)" 11 )
rem https://adoptium.net/docs/faq/#_can_i_automate_the_download_of_temurin_binaries
rem https://api.adoptium.net/q/swagger-ui/#/Assets/getLatestAssets
rem https://github.com/adoptium/api.adoptium.net/blob/main/docs/cookbook.adoc#example-three-scripting-a-download-using-the-adoptium-api
rem https://github.com/adoptium/api.adoptium.net/blob/main/docs/cookbook.adoc#example-two
rem curl -sLk "https://api.adoptium.net/v3/assets/latest/%jdk_version%/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse"
%_task% "[%~nx0] Must get latest version from adoptium.net for jdk version '%jdk_version%'"
for /f "delims=" %%a in ('curl -sLk "https://api.adoptium.net/v3/assets/latest/%jdk_version%/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse" ^| findstr /R /C:"name.*zip"') do ( set "version=%%a" )
if errorlevel 1 (
    %_fatal% "[%~nx0] Cannot get latest version from adoptium.net for jdk with cmd '%cmd%'" 1
)
%_ok% "[%~nx0] Latest jdk version '%jdk_version%' means initially: '%version%'"
set "version=%version:*hotspot_=%"
set "version=%version:.zip=%"
set "version=%version:~0,-2%"
set "replacement=+"
set "dVersion=!version:_=%replacement%!"
%_ok% "[%~nx0] Latest jdk version '%jdk_version%' means: '%version%', dVersion: '!dVersion!'"
set "file=OpenJDK%jdk_version%U-jdk_x64_windows_hotspot_%version%.zip"
rem https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U_x64_windows_hotspot_21.0.5_11.zip
rem https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.25%2B9/OpenJDK11U-jdk_x64_windows_hotspot_11.0.25_9.zip
set "url=https://github.com/adoptium/temurin%jdk_version%-binaries/releases/download/%dVersion%/%file%"
%_ok% "[%~nx0] Built latest jdk version URL='%url%'"

%_task% "[%~nx0] Must get latest URL from adoptium.net for jdk version '%jdk_version%', url='%url%'"
rem @echo on
for /f "delims=" %%a in ('curl -sLk "https://api.adoptium.net/v3/assets/latest/%jdk_version%/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse" ^| findstr /R /C:"[^_]link.*zip"') do ( set "gu=%%a" )
set "gu=%gu:*: =%"
set "gu=%gu:,=%"
set "url=%gu:"=%"
set "url=%url:2B=+%"
%_ok% "[%~nx0] Latest jdk version URL='%url%'"
call :curl
goto:eof

:dwl_lg
set "repo=jesseduffield/lazygit"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
set "file=lazygit_%version%_Windows_x86_64.zip"
rem https://github.com/jesseduffield/lazygit/releases/download/v0.38.0/lazygit_0.38.0_Windows_x86_64.zip
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_node
set "repo=nodejs/node"
if "%version%"=="latest" (
  call :get_latest_version_from_github
  goto:dwl_node_with_version
)
echo %version% | findstr "\." >nul
if %ERRORLEVEL%==0 ( goto:dwl_node_with_version )

set "cmd=curl -skL https://nodejs.org/download/release/"
%cmd% > "%script_dir%\dwl_node.tmp"
if errorlevel 1 (
  del "%script_dir%\dwl_node.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from nodejs.org/download/release/ for Node with cmd '%cmd%'" 101
)
grep -oP "(?<=>)(v.*?)(?=/)" "%script_dir%\dwl_node.tmp" > "%script_dir%\dwl_node1.tmp"
sort -V "%script_dir%\dwl_node1.tmp" > "%script_dir%\dwl_node.tmp"
for /f "delims=" %%a in ('grep "v%version%\." "%script_dir%\dwl_node.tmp"') do ( set "version=%%a" )
del "%script_dir%\dwl_node.tmp"
del "%script_dir%\dwl_node1.tmp"
set "version=%version:v=%"
:dwl_node_with_version
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
set "file=node-v%version%-win-x64.zip"
rem https://nodejs.org/download/release/v22.9.0/node-v22.9.0-win-x64.zip
set "url=https://nodejs.org/download/release/v%version%/%file%"
call :curl
goto:eof

:dwl_python
if "%python_cycle%"=="" ( %_fatal% "[%~nx0] python_cycle needs to be set (11, 12, 13, ...)" 12 )
set "repo=python/cpython"
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' python_cycle '%python_cycle%'"
%_task% "[%~nx0] Must get latest version from endoflife.date for python cycle '%python_cycle%'"
rem @echo on
set "cmd=curl -skL --request GET --url https://endoflife.date/api/python/%python_cycle%.json --header "Accept: application/json""
for /f "tokens=3 delims=," %%a in ('%cmd% ^|^| touch "%script_dir%\dwl_error_curl"') do ( set "version=%%a" )
if exist "%script_dir%\dwl_error_curl" (
  del "%script_dir%\dwl_error_curl"
  %_fatal% "[%~nx0] Cannot get latest version from endoflife.date for Python cycle '%python_cycle%' with cmd '%cmd%'" 1
)
set "version=%version:*latest=%"
set "version=%version:"=%"
set "version=%version::=%"
%_ok% "[%~nx0] Latest Python version '%version%' for cycle '%python_cycle%'"
rem https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe
set "file=python-%version%-amd64.exe"
set "url=https://www.python.org/ftp/python/%version%/%file%"
call :curl
goto:eof

:dwl_sysinternals
set "cmd=curl -skL https://learn.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite"
%cmd% > "%script_dir%\sysinternalsSuite.tmp"
if errorlevel 1 (
  del "%script_dir%\sysinternalsSuite.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from learn.microsoft.com for Sysinternals Suite with cmd '%cmd%'" 1
)
for /f "delims=" %%a in ('findstr "calculated" "%script_dir%\sysinternalsSuite.tmp"') do ( set "version=%%a" )
set "version=%version:>=%"
set "version=%version:<=%"
set "version=%version:*calculated=%"
set "version=%version:"=%"
echo %version%> "%script_dir%\sysinternalsSuite.tmp"
for /f "tokens=1,2,3 delims=/" %%a in ('type "%script_dir%\sysinternalsSuite.tmp"') do ( set "version=%%c%%a%%b" )
rem https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe
set "file=SysinternalsSuite.zip"
set "url=https://download.sysinternals.com/files/%file%"
set "target_local_file=SysinternalsSuite-%version%.zip"
del "%script_dir%\sysinternalsSuite.tmp"
call :curl
goto:eof

:dwl_vscode
set "repo=microsoft/vscode"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://update.code.visualstudio.com/{version}/win32-x64-user/stable
set "file=VSCodeUserSetup-x64-%version%.exe"
set "url=https://update.code.visualstudio.com/%version%/win32-x64-user/stable"
call :curl
goto:eof

:dwl_sqldeveloper
set "cmd=curl -skL https://www.oracle.com/database/sqldeveloper/technologies/download/"
%cmd% > "%script_dir%\dwl_sqldeveloper.tmp"
if errorlevel 1 (
  del "%script_dir%\dwl_sqldeveloper.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from oracle/database/sqldeveloper for SQL Developer with cmd '%cmd%'" 1
)
for /f "tokens=2 delims=><" %%a in ('findstr /R /C:"Version .* - "  "%script_dir%\dwl_sqldeveloper.tmp"') do ( set "version=%%a" )
for /f "tokens=2 delims=- " %%a in ('echo %version%') do ( set "version=%%a" )
%_ok% "[%~nx0] Latest SQL Developer version '%version%'"
rem https://download.oracle.com/otn_software/java/sqldeveloper/sqldeveloper-23.1.1.345.2114-x64.zip
set "file=sqldeveloper-%version%-x64.zip"
set "url=https://download.oracle.com/otn_software/java/sqldeveloper/%file%"
call :curl
del "%script_dir%\dwl_sqldeveloper.tmp"
goto:eof

:dwl_maven:
rem https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip
rem https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.3.9/apache-maven-3.3.9-bin.zip
if not "%version%"=="latest" ( goto:dwl_maven_with_version )
set "cmd=curl -skL https://maven.apache.org/download.cgi"
%cmd% > "%script_dir%\dwl_maven.tmp"
if errorlevel 1 (
  del "%script_dir%\dwl_maven.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from maven.apache.org/download.cgi for Maven with cmd '%cmd%'" 101
)
for /f "tokens=2 delims=><" %%a in ('findstr /R /C:"Downloading Apache Maven "  "%script_dir%\dwl_maven.tmp"') do ( set "version=%%a" )
for /f "tokens=4 delims=- " %%a in ('echo %version%') do ( set "version=%%a" )
%_ok% "[%~nx0] Latest Maven version '%version%'"
rem %_fatal% "[%~nx0] :dwl_maven stop" 1
:dwl_maven_with_version
set "file=apache-maven-%version%-bin.zip"
set "url=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/%version%/%file%"
call :curl
del "%script_dir%\dwl_maven.tmp"
goto:eof

:dwl_wildfly:
set "repo=wildfly/wildfly"
set "version=%version:.Final=%"
set "version=%version:.final=%"
if "%version%"=="latest" ( call :get_latest_version_from_github ) else ( set "version=%version%.Final")
rem %_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
set "file=wildfly-%version%.zip"
rem https://github.com/wildfly/wildfly/releases/download/34.0.0.Final/wildfly-34.0.0.Final.zip
set "url=https://github.com/wildfly/wildfly/releases/download/%version%/%file%"
call :curl
goto:eof

:dwl_yed
rem <button class="material-button material-button-theme  zip-download" data-meta="{&quot;displayName&quot;:&quot;yEd&quot;,&quot;filePath&quot;:&quot;/resources/yed/demo/yEd-3.24.zip&quot;,&quot;licensePath&quot;:&quot;/resources/yed/license_without-jre.html&quot;}">Download .zip file<svg xmlns="http://www.w3.org/2000/svg" width="20" height="1em" viewBox="-1 0 10 10" style="margin-left: .35em;"><use href="#icon-download-top" style="fill: currentColor"></use><use href="#icon-download-bottom" style="fill: currentColor"></use></svg></button>
rem https://www.yworks.com/downloads
rem https://www.yworks.com/resources/yed/demo/yEd-3.24_without-JRE_64-bit_setup.exe

set "cmd=curl -skL https://www.yworks.com/downloads"
%cmd% > "%script_dir%\dwl_yed.tmp"
if errorlevel 1 (
  del "%script_dir%\dwl_yed.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from www.yworks.com/downloads for yEd Graph Editor with cmd '%cmd%'" 1
)
for /f "tokens=2 delims=><" %%a in ('sed "s/.*<a href=\"\/products\/yed\"/xxxxxxx/g" "%script_dir%\dwl_yed.tmp" ^| grep xxxx') do ( set "version=%%a" )
set "version=%version:yEd Graph Editor =%"
%_info% "Yed version='%version%'"
set "file=yEd-%version%_without-JRE_64-bit_setup.exe"
rem https://www.yworks.com/resources/yed/demo/yEd-3.24_without-JRE_64-bit_setup.exe
set "url=www.yworks.com/resources/yed/demo/%file%"
call :curl
del "%script_dir%\dwl_yed.tmp"
goto:eof

:dwl_eclipse
set "cmd=curl -skL https://www.eclipse.org/downloads/packages/"
%cmd% > "%script_dir%\dwl_eclipse.tmp"
if errorlevel 1 (
  del "%script_dir%\dwl_eclipse.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from www.eclipse.org/downloads/packages for Eclipse IDE for Enterprise Java and Web Developers with cmd '%cmd%'" 1
)
for /f "tokens=3 delims=><" %%a in ('findstr /R /C:"Eclipse IDE .* Packages"  "%script_dir%\dwl_eclipse.tmp"') do ( set "version=%%a" )
set "version=%version:*Eclipse IDE =%"
set "version=%version: Packages=%"
%_ok% "[%~nx0] Latest Eclipse IDE for Enterprise Java and Web Developers version '%version%'"
set "file=eclipse-jee-%version: =-%-win32-x86_64.zip"
rem https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-09/R/eclipse-jee-2024-09-R-win32-x86_64.zip&mirror_id=1321
rem https://eclipse.mirror.wearetriple.com//technology/epp/downloads/release/2024-09/R/eclipse-jee-2024-09-R-win32-x86_64.zip
set "url=https://eclipse.mirror.wearetriple.com/technology/epp/downloads/release/%version: =/%/%file%"
rem          https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-09/R/eclipse-jee-2024-09-R-win32-x86_64.zip
rem set "url=https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2024-09/R/eclipse-jee-2024-09-R-win32-x86_64.zip"
call :curl
del "%script_dir%\dwl_eclipse.tmp"
goto:eof

:dwl_terminal
set "repo=microsoft/terminal"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/microsoft/terminal/releases/download/v1.21.2911.0/Microsoft.WindowsTerminal_1.21.2911.0_x64.zip
set "file=Microsoft.WindowsTerminal_%version%_x64.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_superfile
set "repo=yorukot/superfile"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/yorukot/superfile/releases/download/v1.1.6/superfile-windows-v1.1.6-amd64.zip
set "file=%prgname%-windows-v%version%-amd64.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_filezilla
rem https://filezilla-project.org/download.php?platform=win64
rem https://dl2.cdn.filezilla-project.org/client/FileZilla_3.68.1_win64.zip?h=fwla0ZPpullR4IvFXVmZEw&x=1732628710
set "cmd=curl -skL https://filezilla-project.org/download.php?type=client"
%cmd% > "%script_dir%\dwl_filezilla.tmp"
if errorlevel 1 (
  del "%script_dir%\dwl_filezilla.tmp"
  %_fatal% "[%~nx0] Cannot get latest version from filezilla-project.org/download.php?type=client for Eclipse IDE for Enterprise Java and Web Developers with cmd '%cmd%'" 1
)
for /f "tokens=3 delims=><" %%a in ('findstr /R /C:"The latest stable version of FileZilla Client is"  "%script_dir%\dwl_filezilla.tmp"') do ( set "version=%%a" )
set "version=%version:*Eclipse IDE =%"
goto:eof

:dwl_git-cliff
set "repo=orhun/git-cliff"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/orhun/git-cliff/releases/download/v2.7.0/git-cliff-2.7.0-x86_64-pc-windows-msvc.zip
set "file=%prgname%-%version%-x86_64-pc-windows-msvc.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_ripgrep
set "repo=BurntSushi/ripgrep"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-pc-windows-msvc.zip
set "file=%prgname%-%version%-x86_64-pc-windows-msvc.zip"
set "url=https://github.com/%repo%/releases/download/%version%/%file%"
call :curl
goto:eof

:dwl_shellcheck
set "repo=koalaman/shellcheck"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.zip
set "file=%prgname%-v%version%.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_wildfly
set "repo=wildfly/wildfly"
rem https://github.com/wildfly/wildfly/releases/download/35.0.0.Final/wildfly-35.0.0.Final.zip
set "file=%prgname%-%version%.Final.zip"
set "url=https://github.com/%repo%/releases/download/%version%.Final/%file%"
call :curl
goto:eof

:dwl_idea
rem https://www.zenrows.com/blog/curl-bypass-cloudflare#set-real-http-headers
curl -sL -o NUL -w "Final URL: %%{url_effective}\n" ^
-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8" ^
-H "Accept-Encoding: gzip, deflate" ^
-H "Accept-Language: en-US,en;q=0.5" ^
-H "Connection: keep-alive" ^
-H "Sec-Ch-Ua: 'Chromium';v='128', 'Not;A=Brand';v='24', 'Brave';v='128'" ^
-H "Sec-Ch-Ua-Mobile: ?0" ^
-H "Sec-Ch-Ua-Platform: 'Windows'" ^
-H "Sec-Fetch-Dest: document" ^
-H "Sec-Fetch-Mode: navigate" ^
-H "Sec-Fetch-Site: none" ^
-H "Sec-Fetch-User: ?1" ^
-H "Sec-Gpc: 1" ^
-H "Upgrade-Insecure-Requests: 1" ^
-H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36" ^
https://mvnrepository.com/artifact/com.jetbrains.intellij.idea/ideaIC/latest > "%script_dir%\dwl_idea.tmp" 2>&1
for /f "usebackq delims=" %%a in ("%script_dir%\dwl_idea.tmp") do set "url_latest=%%a"
set "version=%url_latest:*/ideaIC/=%"
%_info% "[%~nx0] Dwl (%prgname%) version '%version%'"
rem https://download.jetbrains.com/idea/ideaIU-2024.3.2.2.win.zip
set "file=ideaIC-%version%.win.zip"
set "url=https://download.jetbrains.com/idea/%file%"
call :curl
goto:eof

:dwl_npp
set "repo=notepad-plus-plus/notepad-plus-plus"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.7.6/npp.8.7.6.portable.x64.zip
set "file=%prgname%.%version%.portable.x64.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl
goto:eof

:dwl_lsd
set "repo=lsd-rs/lsd"
if "%version%"=="latest" ( call :get_latest_version_from_github )
%_info% "[%~nx0] Dwl (%prgname%)'%repo%' version '%version%'"
rem https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-v1.1.5-x86_64-pc-windows-msvc.zip
set "file=%prgname%-v%version%-x86_64-pc-windows-msvc.zip"
set "url=https://github.com/%repo%/releases/download/v%version%/%file%"
call :curl