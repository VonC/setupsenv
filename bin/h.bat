@echo off
if "%1"=="" (
	DOSKEY /HISTORY
	goto :EOF
)
DOSKEY /HISTORY|grep -i %1
