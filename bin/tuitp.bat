@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem tuitp [dry] [stop] [--list path] - reconcile the adjacent tuitp.list,
rem or close every managed tab, delete every TUIOS session and stop the
rem TUIOS daemon (stop).
rem It runs from any CMD: for itself only, it switches to the highest
rem %PRGS%\pythons\pythonX.Y.Z, without a venv. senv global puts no Python
rem on the PATH, and a Python found there could be a venv or too old.
if not defined PRGS set "PRGS=C:\Public\SOFTWARE"
set "python_key="
set "python_version="
for /f "delims=" %%d in ('dir /b /ad "%PRGS%\pythons\python*" 2^>nul ^| findstr /r /i "^python[2-9]\.[0-9]*\.[0-9]*$"') do call :keep_highest "%%d"
if not defined python_version (echo ERROR: No pythonX.Y.Z folder found in "%PRGS%\pythons". & exit /b 1)
rem switchpy takes seconds: skip it when that Python already comes first.
set "python_exe="
for /f "delims=" %%p in ('where python.exe 2^>nul') do if not defined python_exe set "python_exe=%%p"
if /i "%python_exe%"=="%PRGS%\pythons\python%python_version%\python.exe" goto :run
rem switchpy keeps an active venv of the current project and syncs its
rem dependencies: leave any venv first, so that tuitp runs the plain Python.
if defined VIRTUAL_ENV if exist "%VIRTUAL_ENV%\Scripts\deactivate.bat" call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
set "SWITCHPY_CHOICE=No venv"
call "%~dp0switchpy.bat" "%python_version%"
where python.exe >nul 2>&1
if errorlevel 1 (echo ERROR: switchpy %python_version% put no python.exe on the PATH. & exit /b 1)
:run
python.exe "%~dp0tuitp.py" %*
exit /b %errorlevel%

:keep_highest
rem Pad each version part, so that 3.13.15 ranks above 3.13.9 and 3.9.20.
set "candidate=%~1"
set "candidate=%candidate:~6%"
for /f "tokens=1-3 delims=." %%a in ("%candidate%") do (
    set "part1=0000%%a"
    set "part2=0000%%b"
    set "part3=0000%%c"
)
set "candidate_key=%part1:~-4%.%part2:~-4%.%part3:~-4%"
if "%candidate_key%" GTR "%python_key%" (
    set "python_key=%candidate_key%"
    set "python_version=%candidate%"
)
exit /b 0
