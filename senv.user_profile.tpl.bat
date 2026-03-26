@echo off

if not exist "%CD%\senv.bat" (
  call _HOME_\bin\senv.bat
  goto :eof
)
if /I not "%~f0"=="%CD%\senv.bat" (
  call "%CD%\senv.bat"
  goto :eof
)
call _HOME_\bin\senv.bat
goto:eof
