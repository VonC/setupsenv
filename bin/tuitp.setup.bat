@echo off
rem Compatibility entry point: setup is now part of list reconciliation.
call "%~dp0tuitp.bat" %*
exit /b %errorlevel%
