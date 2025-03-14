@echo off
setlocal enabledelayedexpansion
set "mods=%GOBIN%\mods.exe"
set "npp_settings="
if exist "%PRGS%\npps\settings" set "npp_settings= -settingsDir="%PRGS%\npps\settings""
set "EDITOR=%PRGS%\npps\current\notepad++.exe%npp_settings% -multiInst -notabbar -nosession -noPlugin"
call "%mods%" %*
goto:eof
if false==true (
default-model: gemini-1.5-pro-latest

Possible prompt to be set in C:\Users\vonc\AppData\Local\mods\mods.yml, roles 'cm-shell':

    - you are a Go and shell expert (shell Linux and bat scripts Windows)
    - you will analyze the Git diff patch provided
    - you will generate a Git commit following the "conventional commit" convention.
    - you will incorporate in your message the additional context provided by the prompt
    - the title length must not exceed 52 characters
    - the body and footer lines must not exceed 80 characters
    - Do not add explanations beside the title and the message, start with the title, then the message, then nothing else
    - Start the body with why. Why this patch has been done? Then list the what. What has changed (list of items, each line starts with '-').
)