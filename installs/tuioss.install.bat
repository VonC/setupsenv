@echo off
rem TUIOS ships a .tar.gz: 7-Zip turns the .gz into an inner .tar, which needs
rem a second extraction. Both land in %PRGS%\tuioss\tuios_<version>_Windows_x86_64,
rem tuios.exe at its root, and that folder goes back to inst_prg.bat as
rem prg_folder, the target of the 'current' junction (tuitp starts
rem %PRGS%\tuioss\current\tuios.exe).
if "%script_dir%"=="" ( set "standalone_%~nx0=true" ) else ( set "standalone_%~nx0=" )
setlocal enabledelayedexpansion
for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
call "%script_dir%\batcolors\echos_macros.bat"
%_info% "~~~~~~~~~~~~ TUIOS installation fname='%fname%' ~~~~~~~~~~~~"

if not exist "%PRGS%\setup\%fname%" (
    %_fatal% "File '%fname%' does not exist in '%PRGS%\setup'" 70
)
set "target=%fname:.tar.gz=%"
set "target_dir=%PRGS%\%prgs_folder%\%target%"

if exist "%target_dir%\tuios.exe" (
    %_ok% "'%target%' already installed in '%PRGS%\%prgs_folder%'"
    goto:done
)

set "work=%TEMP%\tuios_install_%RANDOM%"
%_task% "Must extract '%fname%' to '%work%'"
"%sz%" x -aos "%PRGS%\setup\%fname%" -o"%work%" -bso0 -bsp1
if errorlevel 1 (
    rmdir /s /q "%work%" 2>nul
    %_fatal% "Unable to extract '%fname%' to '%work%'" 71
)
set "tar_file="
for %%t in ("%work%\*.tar") do set "tar_file=%%~ft"
if not defined tar_file (
    rmdir /s /q "%work%" 2>nul
    %_fatal% "No .tar file found in '%work%' after extracting '%fname%'" 72
)
%_task% "Must extract '!tar_file!' to '%target_dir%'"
"%sz%" x -aos "!tar_file!" -o"%target_dir%" -bso0 -bsp1
if errorlevel 1 (
    rmdir /s /q "%work%" 2>nul
    %_fatal% "Unable to extract '!tar_file!' to '%target_dir%'" 73
)
rmdir /s /q "%work%" 2>nul
if not exist "%target_dir%\tuios.exe" (
    %_fatal% "No tuios.exe at the root of '%target_dir%'" 74
)
%_ok% "'%target%' installed in '%PRGS%\%prgs_folder%'"

:done
endlocal & set "prg_folder=%target%"
exit /b 0
