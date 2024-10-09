@echo off
setlocal enabledelayedexpansion

set "p=%~1"
if not "%p:python-=%" == "%p%" ( 
    set "name=%p:python-=%" 
    set "name=!name:-amd64=!"
    echo python!name!
)