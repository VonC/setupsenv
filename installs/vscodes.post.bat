rem https://stackoverflow.com/questions/42582230/how-to-install-visual-studio-code-silently-without-auto-open-when-installation
rem VSCodeSetup-1.10.1.exe /VERYSILENT /MERGETASKS=!runcode

%_info% "Check vscode path '%vscodei%'"

if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" ( %_ok% "Standard path"&& exit /b 0 )
if "%vscodei%"=="" ( %_warning% "No VSCode Installation path detected"&& exit /b 0 )
if not exist "%vscodei%" ( %_warning% "VSCode Installation path does not exist"&& exit /b 0 )
set "f=%HOME%\bin\senv.local.doskey"
if not exist "%f%"  ( %_warning% "VSCode alias: no '%f%' alias file present"&& exit /b 0 )
grep vscode "%f%">NUL
if errorlevel 1 (
    %_info% "Add VSCode alias to '%f%'"
    echo vscode="%vscodei%bin\code.cmd" $*>>"%f%"
    echo aliase="%vscodei%bin\code.cmd" "%HOME%\bin\senv.local.doskey">>"%f%"
) else (
    %_info% "Update VSCode alias to '%f%'"
    sed -i "/^vscode=.*$/d" "%f%"
    sed -i "/^aliase=.*$/d" "%f%"
    echo vscode="%vscodei%bin\code.cmd" $*>>"%f%"
    echo aliase="%vscodei%bin\code.cmd" "%HOME%\bin\senv.local.doskey">>"%f%"
)