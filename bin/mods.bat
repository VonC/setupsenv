@echo off
setlocal enabledelayedexpansion
set "mods=%GOBIN%\mods.exe"
set "EDITOR=%PRGS%\npps\current\notepad++.exe -multiInst -notabbar -nosession -noPlugin"
call "%mods%" %*