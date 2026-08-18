$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility

<#
.SYNOPSIS
Install Hack Nerd Font (per-user) and create/update a dedicated Windows Terminal profile "senv",
then set it as the default profile.

.NOTES
- PowerShell script (.ps1), not a .bat script.
- Installs font for current user only (no admin rights required).
- The font comes from a setups folder when one holds it, and is downloaded only
  as a last resort: the nerd-fonts repository is often unreachable.
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

# Subfolder a setups folder may use to keep fonts apart from the program archives.
$FontSetupsSubFolder = "fonts"

# Command launched by the terminal profile
$SenvBatPath  = Join-Path $env:USERPROFILE "senv.bat"
$CommandLine  = "cmd /k `"$SenvBatPath`""

function Write-Info([string]$Message)    { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message)      { Write-Host $Message -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host $Message -ForegroundColor Yellow }

function Get-WindowsTerminalSettingsCandidates {
    @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
    )
}

function Get-WindowsTerminalSettingsPath {
    $candidates = Get-WindowsTerminalSettingsCandidates

    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Get-WindowsTerminalExecutablePath {
    $candidates = @()

    if ($env:PRGS) {
        $candidates += (Join-Path $env:PRGS "terminals\current\WindowsTerminal.exe")
    }

    $candidates += (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe")
    $candidates += "wt.exe"

    foreach ($p in $candidates) {
        try {
            if ($p -eq "wt.exe") {
                $cmd = Get-Command wt.exe -ErrorAction Stop
                if ($cmd -and $cmd.Source) { return $cmd.Source }
            } elseif (Test-Path -LiteralPath $p) {
                return $p
            }
        } catch {
            # Continue trying other candidates.
        }
    }

    return $null
}

function Initialize-WindowsTerminalSettingsIfMissing {
    $existing = Get-WindowsTerminalSettingsPath
    if ($existing) { return $existing }

    $wtExe = Get-WindowsTerminalExecutablePath
    if ($wtExe) {
        Write-Info "settings.json is missing. Bootstrapping Windows Terminal with a hidden one-shot launch..."
        try {
            $proc = Start-Process -FilePath $wtExe -ArgumentList @("new-tab", "cmd /c exit") -WindowStyle Hidden -PassThru -ErrorAction Stop

            # Wait briefly for first-run initialization.
            $deadline = (Get-Date).AddSeconds(10)
            do {
                Start-Sleep -Milliseconds 250
                $existing = Get-WindowsTerminalSettingsPath
                if ($existing) {
                    Write-Ok "Windows Terminal generated settings.json."
                    return $existing
                }
            } while ((Get-Date) -lt $deadline)

            if ($proc -and -not $proc.HasExited) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-WarnMsg "Unable to start Windows Terminal silently: $($_.Exception.Message)"
        }
    } else {
        Write-WarnMsg "No Windows Terminal executable found in known locations."
    }

    # Fallback: create a minimal valid settings file so post-install can proceed unattended.
    $fallbackPath = (Get-WindowsTerminalSettingsCandidates)[2]
    $parentDir = Split-Path -Parent $fallbackPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $fallbackPath)) {
        Write-Info "Creating a bootstrap settings.json at: $fallbackPath"
        $bootstrapSettings = [pscustomobject]@{
            '$schema' = 'https://aka.ms/terminal-profiles-schema'
            profiles  = [pscustomobject]@{ list = @() }
        }
        $bootstrapSettings |
            ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $fallbackPath -Encoding UTF8
    }

    return $fallbackPath
}

function Get-SetupsFolders {
    # Same lookup order as inst_prg.bat: local setup folder, Downloads, remote
    # profile setups folder, user setups folder. setup.bat and inst_prg.bat both
    # define setupsdir before calling this hook, and terminals.post.bat resolves
    # it from the active profile when this script runs on its own.
    $folders = @()

    if ($env:PRGS)        { $folders += (Join-Path $env:PRGS "setup") }
    if ($env:USERPROFILE) { $folders += (Join-Path $env:USERPROFILE "Downloads") }
    if ($env:setupsdir)   { $folders += $env:setupsdir }
    if ($env:USERPROFILE) { $folders += (Join-Path $env:USERPROFILE "senv_setups\setups") }

    return $folders
}

function Find-FontInSetupsFolders {
    param([Parameter(Mandatory)] [string]$FontFile)

    foreach ($folder in Get-SetupsFolders) {
        if ([string]::IsNullOrWhiteSpace($folder)) { continue }

        $candidates = @(
            (Join-Path $folder $FontFile),
            (Join-Path (Join-Path $folder $FontSetupsSubFolder) $FontFile)
        )

        foreach ($candidate in $candidates) {
            try {
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    Write-Ok "Font '$FontFile' found in a setups folder: $candidate"
                    return $candidate
                }
            } catch {
                # An unreachable setups folder must not stop the lookup.
                Write-WarnMsg "Unable to read '$candidate': $($_.Exception.Message)"
            }
        }
    }

    Write-Info "Font '$FontFile' found in no setups folder"
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
        # A setups folder copy comes first: the nerd-fonts repository is the least
        # reliable source, and a team share usually already holds that file.
        $sourcePath = Find-FontInSetupsFolders -FontFile $FontFile
        if ($sourcePath) {
            Write-Info "Copying font '$FontRegDisplayName' from '$sourcePath'..."
            try {
                Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
                $targetPresent = Test-Path -LiteralPath $targetPath
                Write-Ok "Font file installed from a setups folder: $targetPath"
            } catch {
                Write-WarnMsg "Unable to copy '$sourcePath' to '$targetPath': $($_.Exception.Message)"
            }
        }
    }

    if (-not $targetPresent) {
        if ($env:SENV_INTERNET_OK -eq "0") {
            Write-WarnMsg "No Internet access: skipping the font download from '$DownloadUrl'"
        } else {
            Write-Info "Downloading font '$FontRegDisplayName' from '$DownloadUrl'..."
            try {
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $tempPath
                Copy-Item -LiteralPath $tempPath -Destination $targetPath -Force
                $targetPresent = Test-Path -LiteralPath $targetPath
                Write-Ok "Font file installed successfully: $targetPath"
            } catch {
                Write-WarnMsg "Unable to download the font from '$DownloadUrl': $($_.Exception.Message)"
            }
        }
    }

    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }

    if (-not $targetPresent) {
        # A font is not worth failing the whole Windows Terminal post install on:
        # the 'senv' profile still opens, with the default font face.
        Write-WarnMsg "Font '$FontRegDisplayName' not installed: put '$FontFile' in a setups folder (or in its '$FontSetupsSubFolder' subfolder) to install it without any download."
        return
    }

    if ($registeredPath -eq $targetPath) {
        Write-Ok "Font already installed: $regValueName"
        return
    }

    Write-Info "Registering font '$FontRegDisplayName' (user-level)..."
    New-ItemProperty `
        -Path $fontRegistryPath `
        -Name $regValueName `
        -Value $targetPath `
        -PropertyType String `
        -Force | Out-Null

    Write-Ok "Font registered successfully: $targetPath"
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
$settingsPath = Initialize-WindowsTerminalSettingsIfMissing
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
