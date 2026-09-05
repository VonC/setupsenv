@echo off

rem wtp.tab.bat - the command wtp.bat hands to a project tab. Its only argument
rem is the slot the tab fills, which is what makes the tab recognisable from
rem outside: the argument stays in the command line of this cmd.exe for as long
rem as the tab lives, and a later wtp.bat run reads it back to decide the tab is
rem already open. The slot is taken from %* rather than %1, so a folder holding
rem a space needs no quoting on the way in.
rem
rem A tab opened by Windows Terminal starts from a bare cmd, so the environment
rem is built here: the global senv.bat followed by the senv.bat of the folder
rem the tab sits in, which is what 'senv.bat all' does.

set "WTP_TAB=%*"
call "%USERPROFILE%\senv.bat" all
