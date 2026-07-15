[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArguments
)

$ErrorActionPreference = 'Stop'
if (-not $env:HOME) {
    throw 'HOME is not defined; activate senv before running copy-team-chat-reset.'
}

$transcript = Join-Path $env:HOME 'a.tc.copy'
[IO.File]::WriteAllText($transcript, '', [Text.UTF8Encoding]::new($false))
Write-Host "Reset `"$transcript`"."

& (Join-Path $PSScriptRoot 'copy-team-chat.ps1') @ToolArguments
exit $LASTEXITCODE
