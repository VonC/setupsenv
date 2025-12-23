@echo off
setlocal enabledelayedexpansion
set "mods=%GOBIN%\mods.exe"
set "npp_settings="
if exist "%PRGS%\npps\settings" set "npp_settings= -settingsDir=settings"
set "EDITOR=.\current\notepad++.exe%npp_settings% -multiInst -notabbar -nosession -noPlugin"
@pushd "%PRGS%\npps\"

for %%i in ("%~dp0.") do SET "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do ( set "senv_dir=%%~fi" )
call %senv_dir%\batcolors\echos_macros.bat

if defined SENV_EI_DONE ( goto:call_mods )
call "%script_dir%\ensure_internet.bat"
if errorlevel 1 (
  %_fatal% "Internet connection is required to use mods" 10
)
SET "SENV_EI_DONE="

:call_mods
rem echo mods EDITORS: '%EDITOR%'
if defined HTTPS_PROXY (
  %_info% "HTTPS_PROXY is defined: '%HTTPS_PROXY%': switch to 8081 for mods"
  set "HTTPS_PROXY=http://127.0.0.1:8081"
  set "HTTP_PROXY=http://127.0.0.1:8081"
)
call "%mods%" %*
@popd
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
