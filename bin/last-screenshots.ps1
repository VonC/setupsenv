[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Count = '1',

    [string]$Ini,

    [switch]$NoClipboard
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell leaves $PSScriptRoot empty in parameter defaults.
if (-not $Ini) { $Ini = Join-Path $PSScriptRoot 'lsc.custom.ini' }

# Claude Code turns a quoted image path pasted in a prompt into an attachment,
# so the paths go out quoted, in the order they were taken.
$ImageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp')
# FOLDERID_Screenshots: the value is present once the folder is redirected,
# by OneDrive for instance, under a localized name.
$ScreenshotsFolderId = '{B7BEDE81-DF94-4682-A7D8-57A52620B86F}'
$ShellFoldersKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'

function Show-Usage {
    Write-Host 'Copy the paths of the newest screenshots, quoted, to the clipboard.'
    Write-Host ''
    Write-Host 'Usage: lsc [N]'
    Write-Host ''
    Write-Host '  N is how many of the newest images to copy, 1 by default.'
    Write-Host '  Several paths are separated by one space, oldest first.'
    Write-Host ''
    Write-Host ("The folder is read from '{0}':" -f $Ini)
    Write-Host '  [screenshots]'
    Write-Host '  folder = %USERPROFILE%\Pictures\Screenshots'
    Write-Host 'Without that key, the Windows Screenshots folder is used.'
}

function Write-Problem([string]$message) {
    [Console]::Error.WriteLine("lsc: $message")
}

# The ini is UTF-8, with or without a BOM, because a localized folder name
# rarely survives an ANSI code page.
function Get-IniFolder([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $section = ''
    foreach ($line in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) { continue }
        if ($trimmed -match '^\[(.+)\]$') {
            $section = $Matches[1].Trim()
            continue
        }
        if ($section -eq 'screenshots' -and $trimmed -match '^folder\s*=\s*(.*)$') {
            return [Environment]::ExpandEnvironmentVariables($Matches[1].Trim().Trim('"'))
        }
    }
    return $null
}

function Get-KnownScreenshotsFolder {
    $folders = Get-ItemProperty -LiteralPath $ShellFoldersKey -ErrorAction SilentlyContinue
    if ($folders -and $folders.$ScreenshotsFolderId) { return $folders.$ScreenshotsFolderId }
    if ($folders -and $folders.'My Pictures') {
        $default = Join-Path $folders.'My Pictures' 'Screenshots'
        if (Test-Path -LiteralPath $default -PathType Container) { return $default }
    }
    return $null
}

function Invoke-Lsc {
    if ($Count -match '^(/\?|-\?|/h|help|--help)$') {
        Show-Usage
        return 0
    }
    if ($Count -notmatch '^\d+$' -or [int64]$Count -lt 1) {
        Write-Problem "N must be a whole number of 1 or more, not '$Count'"
        return 1
    }
    $wanted = [int]$Count

    $folder = Get-IniFolder $Ini
    if (-not $folder) {
        $folder = Get-KnownScreenshotsFolder
        if (-not $folder) {
            Write-Problem "no screenshots folder: set 'folder' under [screenshots] in '$Ini'"
            return 2
        }
    }
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        Write-Problem "screenshots folder not found: '$folder'"
        return 2
    }

    $images = @(Get-ChildItem -LiteralPath $folder -File |
        Where-Object { $ImageExtensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object -Property @{ Expression = 'LastWriteTimeUtc'; Descending = $true },
                              @{ Expression = 'Name'; Descending = $true } |
        Select-Object -First $wanted)
    if ($images.Count -eq 0) {
        Write-Problem "no image in '$folder'"
        return 3
    }
    if ($images.Count -lt $wanted) {
        Write-Problem ("only {0} image(s) in '{1}', {2} asked" -f $images.Count, $folder, $wanted)
    }

    [array]::Reverse($images)
    $text = ($images | ForEach-Object { '"' + $_.FullName + '"' }) -join ' '
    if (-not $NoClipboard) { Set-Clipboard -Value $text }
    # Written to the stream, not returned, so the exit code stays alone.
    [Console]::Out.WriteLine($text)
    return 0
}

# A redirected stream is decoded by its reader, not by a console, so it gets
# UTF-8; the console code page is restored before exiting.
$previousEncoding = [Console]::OutputEncoding
$redirected = [Console]::IsOutputRedirected -or [Console]::IsErrorRedirected
try {
    if ($redirected) { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) }
    $code = Invoke-Lsc
}
finally {
    if ($redirected) { [Console]::OutputEncoding = $previousEncoding }
}
exit $code
