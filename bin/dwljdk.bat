@echo off
setlocal enabledelayedexpansion

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

rem @echo on
set "arg=%~1"
if "%arg%"=="" ( goto:dwl_prg)
if not "%arg::=%"=="%arg%" ( goto%arg% )
echo nope
goto:eof

:dwl_prg
set "SENV_DWL_ASK_FOR_LATEST_VERSION=1"
if defined SENV_DWL_DEBUG (
  set "SENV_DWL_VERSION=131.0.3"
  set "SENV_DWL_URL=https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe"
  ::                https://storage.googleapis.com/cdn.softaro.net/m/FirefoxPortable_131.0.3_English.paf.exe
  %_info% "[%~nx0] SENV_DWL_DEBUG set: SENV_DWL_VERSION '%SENV_DWL_VERSION%' and SENV_DWL_URL '%SENV_DWL_URL%'"
) else (
  %_info% "[%~nx0] SENV_DWL_DEBUG not set: version (SENV_DWL_VERSION) and URL (SENV_DWL_URL) to be fetched"
)
set "repo=adoptium/net"
set "prgname=java"
:: The download script is called dwljdk.bat, but the archives must go 
set "SENV_DWL_SCRIPT_NAME=jdk"

%_info% "[%~nx0] Dwl '%repo%' for '%prgname%'"
set "jdk_version=17"
call "%script_dir%\dwl_from_github.bat" "%repo%" "%prgname%"
set "jdk_version=21"
call "%script_dir%\dwl_from_github.bat" "%repo%" "%prgname%"
goto:eof

:get_latest_version
rem @echo on
if "%jdk_version%"=="" ( %_fatal% "[%~nx0] jdk_version needs to be set (17, 21, ...)" 11 )
rem https://adoptium.net/docs/faq/#_can_i_automate_the_download_of_temurin_binaries
rem https://api.adoptium.net/q/swagger-ui/#/Assets/getLatestAssets
rem https://github.com/adoptium/api.adoptium.net/blob/main/docs/cookbook.adoc#example-three-scripting-a-download-using-the-adoptium-api
rem https://github.com/adoptium/api.adoptium.net/blob/main/docs/cookbook.adoc#example-two
rem curl -sLk "https://api.adoptium.net/v3/assets/latest/%jdk_version%/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse"
for /f "delims=" %%a in ('curl -sLk "https://api.adoptium.net/v3/assets/latest/%jdk_version%/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse" ^| findstr /R /C:"name.*zip"') do ( set "version=%%a" )
rem https://fossies.org/windows/misc/go1.23.2.windows-amd64.zip
rem set "gu=https://fossies.org/windows/misc/go%version%.windows-amd64.zip"
set "version=%version:*hotspot_=%"
set "version=%version:.zip=%"
set "version=%version:~0,-2%" 
for /f "delims=" %%a in ('curl -sLk "https://api.adoptium.net/v3/assets/latest/%jdk_version%/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse" ^| findstr /R /C:"[^_]link.*zip"') do ( set "gu=%%a" )
set "gu=%gu:*: =%"
set "gu=%gu:,=%"
set "gu=%gu:"=%"
echo.%version%#%gu%
endlocal
goto:eof

:get_filename
rem "name": "OpenJDK17U-jdk_x64_windows_hotspot_17.0.12_7.zip"
set "version=%~2"
echo OpenJDK%jdk_version%U-jdk_x64_windows_hotspot_%version%.zip
goto:eof
