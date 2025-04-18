@echo off
setlocal enabledelayedexpansion
rem goto:clean_path

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

REM define URL as the one line in testinternet.urls with a '* ' at the beginning of its line
set "url=https://www.cloudflare.com/cdn-cgi/trace"
if exist "%script_dir%\testinternet.urls" (
    for /f "tokens=* usebackq" %%a in (`awk "/^\* / {print substr($0, 3)}" "%script_dir%\testinternet.urls"`) do (
        set "url=%%a"
        goto :got_url
    )
)
:got_url

%_task% "Must check HTTP code by querying %url%"
for /f "tokens=*" %%i in ('curl -Lks -o /dev/null -m 3 -w %%{http_code} %url%') do ( set "code=%%i" )
if "%code%" == "200" (
  %_ok% "Internet connection is working"
  goto:eof
)
set "warning="
REM Any of these codes means we can reach servers
if "%code%" == "301" call:internet_ok "Redirection[301]: Moved Permanently"
if "%code%" == "302" call:internet_ok "Redirection[302]: Found/Temporary Redirect"
if "%code%" == "307" call:internet_ok "Redirection[307]: Temporary Redirect"
if "%code%" == "308" call:internet_ok "Redirection[308]: Permanent Redirect"
if "%code%" == "400" call:internet_ok "Client Error[400]: Bad Request"
if "%code%" == "401" call:internet_ok "Client Error[401]: Unauthorized"
if "%code%" == "403" call:internet_ok "Client Error[403]: Forbidden"
if "%code%" == "404" call:internet_ok "Client Error[404]: Not Found"
if "%code%" == "429" call:internet_ok "Client Error[429]: Too Many Requests"
if "%code%" == "500" call:internet_ok "Server Error[500]: Internal Server Error"
if "%code%" == "502" call:internet_ok "Server Error[502]: Bad Gateway"
if "%code%" == "503" call:internet_ok "Server Error[503]: Service Unavailable"
if "%code%" == "504" call:internet_ok "Server Error[504]: Gateway Timeout"
if defined warning ( goto:eof )

%_warning% "Code HTTP '%code%', check errorlevel:"
curl -Lks -o /dev/null -m 3 -w %%{http_code}\n %url%
set "err=%ERRORLEVEL%"
%_error% "Code HTTP '%code%', errorlevel '%err%'"
if not "%err%" == "0" (
  exit /b 1
)
goto:eof


:internet_ok
set "warning=%~1"
if defined warning (
    %_warning% "%warning%"
    call:rotate_test_url
)
%_ok% "Internet connection there. Proceed"
goto:eof

:rotate_test_url
if not exist "%script_dir%\testinternet.urls" goto:eof

%_task% "Rotating URL for next test"

REM Create a temporary file
set "tempfile=%TEMP%\testinternet_temp.urls"
if exist "%tempfile%" del "%tempfile%"

REM Use awk to handle the URL rotation
REM Use awk to handle the URL rotation with external script
awk -f "%script_dir%\testinternet.awk" "%script_dir%\testinternet.urls" > "%tempfile%"

REM If the marked line was the last one, mark the first http line
grep -E "^\* " "%tempfile%" > nul
if %ERRORLEVEL% neq 0 (
    REM Mark the first http line using sed
    sed -i "0,/^http/s/^http/* http/" "%tempfile%"
)

REM Replace the original file with our modified version
copy /y "%tempfile%" "%script_dir%\testinternet.urls" >nul
rem if exist "%tempfile%" del "%tempfile%"
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
