@echo off
setlocal enabledelayedexpansion
title (S) %1
grep -Ei "^Host %1$" "%HOME%\.ssh\config"
if not "%ERRORLEVEL%"=="0" (
    echo "No 'Host %1' in '%HOME%\.ssh\config'"
    grep -Ei "%1" "%HOME%\.ssh\config"
    exit /b 1
)
for /F "delims=" %%f in ('grep %1_cd ~/.ssh/config ^| xargs ^| tr -s ' ' ^| cut -d ' ' -f 2') do (
    set "p=%%f"
)
echo p='%p%'
for /F "delims=" %%f in ('grep %1_env ~/.ssh/config ^| xargs ^| tr -s ' ' ^| cut -d ' ' -f 2') do (
    set "e=%%f"
)
if "%e%"=="" ( set "e=.env" )
if "%SSHE_USE_POWERSHELL%"=="" ( set "SSHE_USE_POWERSHELL=0" )

set "SSHCMD=ssh.exe"
if not "%SSHGIT%"=="" (
    set "SSHCMD=%PRGS%\gits\%SSHGIT%\usr\bin\ssh.exe"
    set "GH=%PRGS%\gits\%SSHGIT%"
    set "PATH=C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\"
    set "PATH=%GH%\bin;%GH%\cmd;%GH%\usr\bin;%GH%\mingw64\bin;%GH%\mingw64\libexec\git-core;%PATH%"
)
if not "%SSHDIR%"=="" ( set "SSHCMD=%SSHDIR%\ssh.exe" )
echo SSHCMD='%SSHCMD%' param '%1' p='%p%' e='%e%'
echo SSHE_USE_POWERSHELL='%SSHE_USE_POWERSHELL%'

if "%p%"=="" (
    set "INIT_BODY=pwd; if [ -f %e% ]; then source %e%; fi"
) else (
    set "INIT_BODY=cd %p%;pwd; if [ -f %e% ]; then source %e%; fi"
)
set "INIT_BASH=/bin/bash --init-file <(echo '!INIT_BODY!')"

if /I "%SSHE_USE_POWERSHELL%"=="1" (
    if "%p%" == "forced" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
            "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Utility; & '%SSHCMD%' '%~1'; exit $LASTEXITCODE"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
            "$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Utility; & '%SSHCMD%' '%~1' -t \"!INIT_BASH!\"; exit $LASTEXITCODE"
    )
) else (
    if "%p%" == "forced" (
        :: Use start "" /b /wait to run in same window but detach signal handler
        start "ssh %~1" /b /wait "%SSHCMD%" %~1
    ) else (
        :: The empty quotes "" are required as the first argument to define the title
        start "ssh %~1" /b /wait "%SSHCMD%" %~1 -t "!INIT_BASH!"
    )
)
exit /b %ERRORLEVEL%
