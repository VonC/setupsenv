$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility

<#
.SYNOPSIS
Install Hack Nerd Font (per-user) and create/update a dedicated Windows Terminal profile "senv",
then set it as the default profile.

.NOTES
- PowerShell script (.ps1), not a .bat script.
- Installs font for current user only (no admin rights required).
- Upserts profile by GUID first, then by name (to avoid duplicates).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Config ---
$ProfileName  = "senv"
$ProfileGuid  = "{6bef82be-26cd-46c7-9ab1-a04054d9eac2}"

$FontRegName  = "Hack Nerd Font Regular"  # registry display name
$FontFaceName = "Hack Nerd Font"          # Windows Terminal font face
$FontFileName = "HackNerdFont-Regular.ttf"
$FontUrl      = "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf"

# Command launched by the terminal profile
$SenvBatPath  = Join-Path $env:USERPROFILE "senv.bat"
$CommandLine  = "cmd /k `"$SenvBatPath`""

function Write-Info([string]$Message)    { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message)      { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }

function Get-WindowsTerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
    )

    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Install-UserFontIfMissing {
    param(
        [Parameter(Mandatory)] [string]$FontRegDisplayName,
        [Parameter(Mandatory)] [string]$FontFile,
        [Parameter(Mandatory)] [string]$DownloadUrl
    )

    $userFontFolder = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    if (-not (Test-Path -LiteralPath $userFontFolder)) {
        New-Item -Path $userFontFolder -ItemType Directory | Out-Null
    }

    $targetPath = Join-Path $userFontFolder $FontFile
    $tempPath   = Join-Path $env:TEMP $FontFile

    $fontRegistryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    $regValueName = "$FontRegDisplayName (TrueType)"
    $targetPresent = Test-Path -LiteralPath $targetPath
    $registeredPath = $null

    try {
        $registeredPath = Get-ItemPropertyValue -Path $fontRegistryPath -Name $regValueName -ErrorAction Stop
    } catch {
        $registeredPath = $null
    }

    if (-not $targetPresent) {
        Write-Info "Downloading font '$FontRegDisplayName'..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $tempPath
        Copy-Item -Path $tempPath -Destination $targetPath -Force
        $targetPresent = $true
        Write-Ok "Font file installed successfully: $targetPath"
    }

    if ($registeredPath -eq $targetPath -and $targetPresent) {
        Write-Ok "Font already installed: $regValueName"
    } else {
        Write-Info "Registering font '$FontRegDisplayName' (user-level)..."
        New-ItemProperty `
            -Path $fontRegistryPath `
            -Name $regValueName `
            -Value $targetPath `
            -PropertyType String `
            -Force | Out-Null

        Write-Ok "Font registered successfully: $targetPath"
    }

    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}

function New-FileBackup {
    param([Parameter(Mandatory)] [string]$Path)
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.$stamp.bak"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Ok "Backup created: $backupPath"
}

function Initialize-SettingsProfilesList {
    param([Parameter(Mandatory)] [object]$Settings)

    if (-not $Settings.PSObject.Properties.Name.Contains("profiles") -or $null -eq $Settings.profiles) {
        $Settings | Add-Member -MemberType NoteProperty -Name profiles -Value ([pscustomobject]@{ list = @() }) -Force
    }

    if (-not $Settings.profiles.PSObject.Properties.Name.Contains("list") -or $null -eq $Settings.profiles.list) {
        $Settings.profiles | Add-Member -MemberType NoteProperty -Name list -Value @() -Force
    }
}

# --- 1) Ensure font is installed ---
Install-UserFontIfMissing -FontRegDisplayName $FontRegName -FontFile $FontFileName -DownloadUrl $FontUrl

# --- 2) Locate Windows Terminal settings ---
$settingsPath = Get-WindowsTerminalSettingsPath
if (-not $settingsPath) {
    throw "Windows Terminal settings.json not found. Open Windows Terminal once, then rerun this script."
}
Write-Info "Using settings file: $settingsPath"

# --- 3) Load settings JSON ---
try {
    $raw = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8
    $settings = $raw | ConvertFrom-Json
} catch {
    throw "Failed to parse settings.json. If it contains comments/trailing commas (JSONC), remove them temporarily or re-save via Windows Terminal UI first. Error: $($_.Exception.Message)"
}

# --- 4) Build dedicated senv profile ---
if (-not (Test-Path -LiteralPath $SenvBatPath)) {
    Write-WarnMsg "Note: '$SenvBatPath' does not exist yet. The profile will be created, but launching it will fail until that file exists."
}

$newProfile = [pscustomobject]@{
    altGrAliasing     = $true
    antialiasingMode  = "grayscale"
    closeOnExit       = "automatic"
    colorScheme       = "Campbell"
    commandline       = $CommandLine
    cursorShape       = "bar"
    font              = [pscustomobject]@{
        face = $FontFaceName
        size = 12
    }
    guid              = $ProfileGuid
    hidden            = $false
    name              = $ProfileName
    startingDirectory = "%USERPROFILE%"
}

# --- 5) Ensure profiles/list exists ---
Initialize-SettingsProfilesList -Settings $settings
$profiles = @($settings.profiles.list)

# --- 6) Upsert by GUID first, then by name (dedicated senv profile) ---
$updated = $false

for ($i = 0; $i -lt $profiles.Count; $i++) {
    if ($profiles[$i].guid -eq $ProfileGuid) {
        $profiles[$i] = $newProfile
        $updated = $true
        Write-Ok "Updated existing profile by GUID: $ProfileName"
        break
    }
}

if (-not $updated) {
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        if ($profiles[$i].name -eq $ProfileName) {
            $profiles[$i] = $newProfile
            $updated = $true
            Write-Ok "Updated existing profile by name: $ProfileName"
            break
        }
    }
}

if (-not $updated) {
    $profiles += $newProfile
    Write-Ok "Added new dedicated profile: $ProfileName"
}

$settings.profiles.list = $profiles

# --- 7) Set senv as default (always) ---
$settings.defaultProfile = $ProfileGuid
Write-Ok "Set '$ProfileName' as the default Windows Terminal profile."

# --- 8) Backup + save ---
New-FileBackup -Path $settingsPath

# WARNING: ConvertTo-Json rewrites formatting and removes comments.
$settings |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $settingsPath -Encoding UTF8

Write-Ok "Windows Terminal settings saved successfully."
Write-Info "Done."
