@echo off
if "%script_dir%"=="" (
    setlocal enabledelayedexpansion
    for %%i in ("%~dp0..") do SET "script_dir=%%~fi"
    call "!script_dir!\custom\echos_macros.bat"
)
%_info% "~~~~~~~~~~~~ IdeaICs post installation ~~~~~~~~~~~~"
%_task% "Must extract IntelliJ IDEA IC version from %PRGS%\ideaics\current\product-info.json"
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
    %_fatal% "Unable to extract version from %PRGS%\ideaics\current\product-info.json" 1
)
%_info% "IdeaIC version extracted!: %version%"
%_task% "Must check if %APPDATA%\JetBrains\IdeaIC%version%\idea.properties exist"
if exist "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties" (
    REM Check if org.bouncycastle.asn1.allow_unsafe_integer if present in the file
    %_task% "File exist, so must check if it includes org.bouncycastle.asn1.allow_unsafe_integer=true in the file"
    findstr /r /c:"org.bouncycastle.asn1.allow_unsafe_integer" "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties" >nul
    if errorlevel 1 (
        %_info% "org.bouncycastle.asn1.allow_unsafe_integer is not present in the file"
        %_task% "Add org.bouncycastle.asn1.allow_unsafe_integer=true in the file"
        echo "org.bouncycastle.asn1.allow_unsafe_integer=true" >> "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties"
        if errorlevel 1 (
            %_fatal% "Unable to add org.bouncycastle.asn1.allow_unsafe_integer=true in the file" 1
        ) else (
            %_ok% "org.bouncycastle.asn1.allow_unsafe_integer=true added in the file"
        )
    ) else (
        %_ok% "org.bouncycastle.asn1.allow_unsafe_integer is already present in the file"
    )
) else (
    %_info% "No file '%APPDATA%\JetBrains\IdeaIC%version%\idea.properties' found"
    REM create the parent folder structure, then copy the file there
    if not exist "%APPDATA%\JetBrains\IdeaIC%version%" (
        mkdir "%APPDATA%\JetBrains\IdeaIC%version%"
        if errorlevel 1 (
            %_fatal% "Unable to create '%APPDATA%\JetBrains\IdeaIC%version%' folder" 1
        ) else (
            %_ok% "Folder '%APPDATA%\JetBrains\IdeaIC%version%' created"
        )
    ) else (
        %_ok% "Folder '%APPDATA%\JetBrains\IdeaIC%version%' already exists"
    )
    %_task% "Copy 'idea.properties' file to '%APPDATA%\JetBrains\IdeaIC%version%'"
    copy /y "%script_dir%\installs\idea.properties" "%APPDATA%\JetBrains\IdeaIC%version%\idea.properties" >nul
    if errorlevel 1 (
        %_fatal% "Unable to copy 'idea.properties' file to '%APPDATA%\JetBrains\IdeaIC%version%'" 1
    ) else (
        %_ok% "'idea.properties' file copied to '%APPDATA%\JetBrains\IdeaIC%version%'"
    )
)
