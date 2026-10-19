@echo off
rem tct [N]: cached Teams chats from N days ago (0 is today), today by default.
if "%~1"=="" (
    call "%~dp0team-chat.bat" today
) else (
    call "%~dp0team-chat.bat" %*
)
exit /b %ERRORLEVEL%
