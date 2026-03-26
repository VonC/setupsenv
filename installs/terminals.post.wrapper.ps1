$PSModuleAutoloadingPreference = 'None'; Import-Module Microsoft.PowerShell.Management

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$terminalsPostPath = Join-Path $scriptDir 'terminals.post.ps1'

if (-not (Test-Path -LiteralPath $terminalsPostPath)) {
    throw "Script not found: $terminalsPostPath"
}

& $terminalsPostPath @args
