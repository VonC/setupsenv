[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArguments
)

$ErrorActionPreference = 'Stop'
if (-not $env:PRGS) {
    throw 'PRGS is not defined; activate senv before running copy-team-chat.'
}

$pythonRoot = Join-Path $env:PRGS 'pythons'
$python = Get-ChildItem -LiteralPath $pythonRoot -Directory -ErrorAction Stop |
    ForEach-Object {
        if ($_.Name -match '3\.13\.(\d+)') {
            $version = [version]::new(3, 13, [int]$Matches[1])
            $executable = Get-ChildItem -LiteralPath $_.FullName -Filter python.exe -File -Recurse |
                Select-Object -First 1
            if ($executable) {
                [pscustomobject]@{ Version = $version; Path = $executable.FullName }
            }
        }
    } |
    Sort-Object Version -Descending |
    Select-Object -First 1
if (-not $python) {
    throw "No Python 3.13.x installation with python.exe was found under '$pythonRoot'."
}

$source = if ($env:COPY_TEAM_CHAT_SOURCE) {
    $env:COPY_TEAM_CHAT_SOURCE
} else {
    Join-Path $env:PRGS 'senv\tools\copy-team-chat\copy_team_chat.py'
}
if (-not (Test-Path -LiteralPath $source)) {
    throw "copy-team-chat source not found at '$source'. Set COPY_TEAM_CHAT_SOURCE to override it."
}

& $python.Path -B $source @ToolArguments
exit $LASTEXITCODE
