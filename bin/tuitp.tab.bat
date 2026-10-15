@echo off
rem The launcher normally starts tuitp_host.py directly in Windows Terminal.
rem This helper accepts its generated manifest, not a raw session name.
python.exe "%~dp0tuitp_host.py" "%~1"
exit /b %errorlevel%
