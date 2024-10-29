param (
    [int]$n = 100
)

$PSModuleAutoloadingPreference = 'None'
# powershell -ExecutionPolicy Bypass -File progress_bar.ps1 -n 50
# Load necessary assembly (suppress output)
# [void][Reflection.Assembly]::LoadWithPartialName("System.Select-Object")
Import-Module CimCmdlets
Import-Module Microsoft.PowerShell.Utility

function Show-ProgressBar {
    param (
        [int]$current,
        [int]$total
    )

    $percent = [math]::Round(($current / $total) * 100)
    $barLength = 50
    $filledLength = [math]::Round(($barLength * $percent) / 100)
    $bar = ("#" * $filledLength).PadRight($barLength)

    Write-Host -NoNewline "`r[$bar] $percent% ($current/$total)"
}

for ($i = 0; $i -le $n; $i++) {
    Show-ProgressBar -current $i -total $n
    Start-Sleep -Milliseconds 100
}

Write-Host "`r[$(" " * 50)] 100% ($n/$n)"