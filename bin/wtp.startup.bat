@echo off

rem wtp.startup.bat - the command wtp.bat hands to the startup tab, which it
rem opens only when a startup.bat sits next to it. A tab opened by Windows
rem Terminal starts from a bare cmd, where HOME and PRGS do not exist yet, so
rem the global environment has to be activated before startup.bat, which reads
rem both, can run.

call "%USERPROFILE%\senv.bat" global
call "%~dp0startup.bat" %*
