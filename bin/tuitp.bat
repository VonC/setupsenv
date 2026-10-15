@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem tuitp [dry] [--list path] - reconcile the adjacent tuitp.list.
where python.exe >nul 2>&1
if errorlevel 1 call "%USERPROFILE%\senv.bat" global
where python.exe >nul 2>&1
if errorlevel 1 (echo ERROR: Python 3.10 or newer is required. Run senv first. & exit /b 1)
python.exe "%~dp0tuitp.py" %*
exit /b %errorlevel%
