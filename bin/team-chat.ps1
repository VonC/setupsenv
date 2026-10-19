[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Day,

    [int]$MinPerConversation = 1
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    $exampleDay = (Get-Date).AddDays(-2)
    Write-Host 'Copy locally cached Teams chats to the clipboard.'
    Write-Host ''
    Write-Host 'Usage: tc <today|yesterday|N|yyyy-MM-dd|yyyyMMdd>'
    Write-Host ''
    Write-Host '  N is a number of days ago, up to 4 digits: 0 is today, 1 is yesterday.'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host '  tc today'
    Write-Host ("  tc {0}" -f $exampleDay.ToString('yyyy-MM-dd'))
    Write-Host ("  tc {0}       (same day, compact form)" -f $exampleDay.ToString('yyyyMMdd'))
    Write-Host '  tc 2              (same day, as days ago)'
    Write-Host '  tc yesterday'
    Write-Host '  tct               (today shortcut)'
    Write-Host '  tct 2             (two days ago; tct 0 is today)'
    Write-Host '  tcy               (yesterday shortcut)'
}

if (-not $Day) {
    Show-Usage
    exit 0
}

switch ($Day.ToLowerInvariant()) {
    'today'     { $date = (Get-Date).Date }
    'yesterday' { $date = (Get-Date).Date.AddDays(-1) }
    default {
        $date = [datetime]::MinValue
        if ($Day -match '^\d{1,4}$') {
            $date = (Get-Date).Date.AddDays(-[int]$Day)
        } elseif (-not [datetime]::TryParseExact(
            $Day,
            [string[]]@('yyyy-MM-dd', 'yyyyMMdd'),
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$date
        )) {
            Show-Usage
            Write-Error "Invalid day '$Day'. Expected today, yesterday, a number of days ago, yyyy-MM-dd, or yyyyMMdd."
        }
    }
}

$repoRoot = if ($env:PRGS) {
    Join-Path $env:PRGS 'senv'
} else {
    Split-Path -Parent $PSScriptRoot
}
$sourceDir = if ($env:TEAM_CHAT_SOURCE) {
    $env:TEAM_CHAT_SOURCE
} else {
    Join-Path $repoRoot 'tools\team-chat'
}
$managedReader = -not $env:TEAM_CHAT_READER
$reader = if (-not $managedReader) {
    $env:TEAM_CHAT_READER
} else {
    $deployDir = if ($env:HOME) { Join-Path $env:HOME 'bin' } else { $PSScriptRoot }
    Join-Path $deployDir 'teams-reader.exe'
}

if ($managedReader) {
    if (-not (Test-Path -LiteralPath $sourceDir)) {
        throw "Teams cache reader source not found at '$sourceDir'. Set TEAM_CHAT_SOURCE to override it."
    }
    $sourceFiles = Get-ChildItem -LiteralPath $sourceDir -File | Where-Object {
        $_.Extension -eq '.go' -or $_.Name -in @('go.mod', 'go.sum')
    }
    $needsBuild = -not (Test-Path -LiteralPath $reader)
    if (-not $needsBuild) {
        $readerTime = (Get-Item -LiteralPath $reader).LastWriteTimeUtc
        $needsBuild = $null -ne ($sourceFiles | Where-Object { $_.LastWriteTimeUtc -gt $readerTime } | Select-Object -First 1)
    }
    if ($needsBuild) {
        if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
            throw "Teams cache reader needs rebuilding, but 'go' is not on PATH."
        }
        $readerDir = Split-Path -Parent $reader
        if (-not (Test-Path -LiteralPath $readerDir)) {
            New-Item -ItemType Directory -Path $readerDir -Force | Out-Null
        }
        Write-Host "Building and deploying Teams cache reader to '$reader'..."
        Push-Location $sourceDir
        try {
            & go build -buildvcs=false -trimpath -o $reader .
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to build Teams cache reader (exit code $LASTEXITCODE)."
            }
        } finally {
            Pop-Location
        }
    }
}
if (-not (Test-Path -LiteralPath $reader)) {
    throw "Teams cache reader not found at '$reader'. Set TEAM_CHAT_READER to override it."
}

$readerArgs = @(
    '-stdout',
    '-date', $date.ToString('yyyy-MM-dd'),
    '-min', $MinPerConversation.ToString([Globalization.CultureInfo]::InvariantCulture)
)
if ($env:TEAM_CHAT_DB_PATH) {
    $readerArgs += @('-db', $env:TEAM_CHAT_DB_PATH)
}

$previousEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    $lines = @(& $reader @readerArgs)
    if ($LASTEXITCODE -ne 0) {
        throw "Teams cache reader failed with exit code $LASTEXITCODE."
    }
} finally {
    [Console]::OutputEncoding = $previousEncoding
}

$transcript = [string]::Join("`r`n", $lines) + "`r`n"
Import-Module Microsoft.PowerShell.Management
Set-Clipboard -Value $transcript
Write-Host ("Copied {0} Teams chat transcript to the clipboard." -f $date.ToString('yyyy-MM-dd'))
