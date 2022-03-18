@echo off
setlocal ENABLEDELAYEDEXPANSION

for /F "delims=" %%i in ('hostname') do set "hostname=%%i"

rem echo hostname='%hostname%'

for /F "delims=" %%i in ('ping -4 -n 1 %hostname%') do (
    if "!fhostname!" == "" (
        set "fhostname=%%i"
    )
)

set "fhostname=!fhostname:*%hostname%=%hostname%!"
rem set "fhostname=%fhostname:*ping' sur =%"
rem set "fhostname=%fhostname:*Pinging =%"
rem set "fhostname=%fhostname:]*=]a%"
rem echo %fhostname% | sed "s/*%hostname%/aa/g" # https://unix.stackexchange.com/questions/196780/is-there-an-alternative-to-sed-that-supports-unicode
for /F "delims=]" %%i in ('echo %fhostname%') do set "fhostname=%%i]"
rem echo fhostname='%fhostname%'
echo %fhostname%
