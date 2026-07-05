@echo off

if /I "%~1"=="global" (
  call _HOME_\bin\senv.bat
  goto :eof
)
if /I "%~1"=="all" (
  call _HOME_\bin\senv.bat
  if /I not "%CD%"=="_HOME_" if exist "%CD%\senv.bat" if /I not "%~f0"=="%CD%\senv.bat" (
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
if /I not "%~f0"=="%CD%\senv.bat" (
  call "%CD%\senv.bat"
  goto :eof
)
call _HOME_\bin\senv.bat
goto:eof
