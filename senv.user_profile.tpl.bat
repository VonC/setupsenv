@echo off

rem Doskey macros belong to one console and a new console inherits none, so a
rem project senv.bat run without the global activation would leave the global,
rem team and personal aliases undefined. 'aliases' loads only them, and the
rem project branch below loads them before the project senv.bat, whose own
rem aliases then win.
if /I "%~1"=="aliases" (
  if exist "_HOME_\bin\senv_doskey.bat" call "_HOME_\bin\senv_doskey.bat"
  goto :eof
)
if /I "%~1"=="global" (
  call _HOME_\bin\senv.bat
  goto :eof
)
if /I "%~1"=="all" (
  call _HOME_\bin\senv.bat
  if /I not "%CD%"=="_HOME_" if /I not "%CD%"=="%HOMEDRIVE%\" if exist "%CD%\senv.bat" if /I not "%~f0"=="%CD%\senv.bat" (
    call "%CD%\senv.bat"
  )
  goto :eof
)
if not exist "%CD%\senv.bat" (
  call _HOME_\bin\senv.bat
  goto :eof
)
if /I "%CD%"=="_HOME_" (
  call _HOME_\bin\senv.bat
  goto :eof
)
if /I "%CD%"=="%HOMEDRIVE%\" (
  call _HOME_\bin\senv.bat
  goto :eof
)
if /I not "%~f0"=="%CD%\senv.bat" (
  if exist "_HOME_\bin\senv_doskey.bat" call "_HOME_\bin\senv_doskey.bat"
  call "%CD%\senv.bat"
  goto :eof
)
call _HOME_\bin\senv.bat
goto:eof
