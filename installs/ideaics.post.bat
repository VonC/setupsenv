@echo off
if "%script_dir%"=="" (
    setlocal enabledelayedexpansion
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
    call "!script_dir!\custom\echos_macros.bat"
)
%_info% "[%~nx0] ~~~~~~~~~~~~ IdeaICs post installation ~~~~~~~~~~~~"
%_task% "[%~nx0] Must extract IntelliJ IDEA IC version from %PRGS%\ideaics\current\product-info.json"
REM extract version from %PRGS%\ideaics\current\product-info.json, line "-Didea.paths.selector=IdeaIC2022.3", version should be '2022.3'
set "version="
for /f "usebackq tokens=2 delims=C " %%i in (`findstr /r /c:"-Didea.paths.selector=IdeaIC" "%PRGS%\ideaics\current\product-info.json"`) do (
    set "version=%%i"
    set "version=!version: =!"
    set "version=!version:~0,-2!"
    goto:versionfound
)
:versionfound
if "%version%"=="" (
    %_fatal% "[%~nx0] Unable to extract version from %PRGS%\ideaics\current\product-info.json" 1
)
%_info% "[%~nx0] IdeaIC version extracted!: %version%"
%_task% "[%~nx0] Must check if %APPDATA%\JetBrains\IdeaIC%version%\idea.properties exist"
if exist "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties" (
    REM Check if org.bouncycastle.asn1.allow_unsafe_integer if present in the file
    %_task% "[%~nx0] File exist, so must check if it includes org.bouncycastle.asn1.allow_unsafe_integer=true in the file"
    findstr /r /c:"org.bouncycastle.asn1.allow_unsafe_integer" "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties" >nul
    if errorlevel 1 (
        %_info% "[%~nx0] org.bouncycastle.asn1.allow_unsafe_integer is not present in the file"
        %_task% "[%~nx0] Add org.bouncycastle.asn1.allow_unsafe_integer=true in the file"
        echo "org.bouncycastle.asn1.allow_unsafe_integer=true" >> "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties"
        if errorlevel 1 (
            %_fatal% "[%~nx0] Unable to add org.bouncycastle.asn1.allow_unsafe_integer=true in the file" 1
        ) else (
            %_ok% "[%~nx0] org.bouncycastle.asn1.allow_unsafe_integer=true added in the file"
        )
    ) else (
        %_ok% "[%~nx0] org.bouncycastle.asn1.allow_unsafe_integer is already present in the file"
    )
) else (
    %_info% "[%~nx0] No file '%APPDATA%\JetBrains\IdeaIC%version%\idea.properties' found"
    REM create the parent folder structure, then copy the file there
    mkdir "%APPDATA%\JetBrains\IdeaIC%version%"
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to create '%APPDATA%\JetBrains\IdeaIC%version%' folder" 1
    ) else (
        %_ok% "[%~nx0] Folder '%APPDATA%\JetBrains\IdeaIC%version%' created"
    )
    %_task% "[%~nx0] Copy 'idea.properties' file to '%APPDATA%\JetBrains\IdeaIC%version%'"
    copy /y "%script_dir%\installs\idea.properties" "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties" >nul
    if errorlevel 1 (
        %_fatal% "[%~nx0] Unable to copy 'idea.properties' file to '%APPDATA%\JetBrains\IdeaIC%version%'" 1
    ) else (
        %_ok% "[%~nx0] 'idea.properties' file copied to '%APPDATA%\JetBrains\IdeaIC%version%'"
    )
)
