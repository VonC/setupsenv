REM Git global config utils

if "%1" == ":save_gitconfig" (
    call :save_gitconfig %*
    goto:eof
)
if "%1" == ":restore_gitconfig" (
    call :restore_gitconfig %*
    goto:eof
)

:save_and_restore_gitconfig
call :save_gitconfig %*
call :restore_gitconfig %*
goto:eof

:save_gitconfig
cat %HOME%\.gitconfig >NUL
grep "email = " %HOME%\.gitconfig >NUL
if errorlevel 1 (
  %_fatal% "Unable to read %HOME%\.gitconfig: content corrupted (%*)" 666
)
copy /Y %HOME%\.gitconfig %HOME%\.gitconfig.ori >NUL
if errorlevel 1 (
  %_fatal% "Unable to copy %HOME%\.gitconfig: content corrupted (%*)" 667
)
%_ok% "%HOME%\.gitconfig copied to %HOME%\.gitconfig.ori (%*)"
goto:eof

:restore_gitconfig
grep "email = " %HOME%\.gitconfig.ori >NUL
if errorlevel 1 (
  %_fatal% "Unable to read %HOME%\.gitconfig.ori: content corrupted (%*)" 668
)
copy /Y %HOME%\.gitconfig.ori %HOME%\.gitconfig >NUL
if errorlevel 1 (
  %_fatal% "Unable to copy %HOME%\.gitconfig.ori: content corrupted (%*)" 669
)
grep "email = " %HOME%\.gitconfig >NUL
if errorlevel 1 (
  %_fatal% "Unable to confirm read %HOME%\.gitconfig: content corrupted (%*)" 670
)
%_ok% "%HOME%\.gitconfig.ori copied to %HOME%\.gitconfig (%*)"
goto:eof