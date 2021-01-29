rem https://stackoverflow.com/questions/42582230/how-to-install-visual-studio-code-silently-without-auto-open-when-installation
rem VSCodeSetup-1.10.1.exe /VERYSILENT /MERGETASKS=!runcode

%_info% "install vscode %PRGS%\setup\%fs%"
set install_ok=true
"%PRGS%\setup\%fs%" /DIR="%PRGS%\vscode" /VERYSILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /MERGETASKS=!runcode
if errorlevel 1 ( %_fatal% "Issue when installing vscode"&& exit /b 1 )
call "%script_dir%\installs\vscodes.pre.bat"
call "%script_dir%\installs\vscodes.post.bat"
