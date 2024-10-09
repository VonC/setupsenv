@echo off
setlocal enabledelayedexpansion

set "p=%~1"
if not "%p:apache-maven-=%" == "%p%" ( 
    set "name=%p:apache-maven-=%" 
    set "name=!name:-bin=!"
    echo mvn!name!
)