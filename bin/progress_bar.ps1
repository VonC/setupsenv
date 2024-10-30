param (
    [int]$current = -1,
    [int]$total = 100
)
$PSModuleAutoloadingPreference = 'None'
# powershell -ExecutionPolicy Bypass -File progress_bar.ps1 -current 50 -total 100
#
# powershell -ExecutionPolicy Bypass -File %PRGS%\senv\bin\progress_bar.ps1 -total 50
# powershell -ExecutionPolicy Bypass -File %PRGS%\senv\bin\progress_bar.ps1 -total 50 -current 12
# 
# Load necessary assembly (suppress output)
# [void][Reflection.Assembly]::LoadWithPartialName("System.Select-Object")
Import-Module CimCmdlets
Import-Module Microsoft.PowerShell.Utility

trap {
  Write-Host "CTRL-C detected. Exiting gracefully..."
  exit
}

# Define the escape character
$e = [char]27

function Show-ProgressBar {
    param (
        [int]$current,
        [int]$total
    )

    $percent = [math]::Round(($current / $total) * 100)
    $barLength = 50
    $filledLength = [math]::Round(($barLength * $percent) / 100)

    # Determine color based on percentage
    if ($percent -le 10) {
        $color = "$e[38;5;196m"  # Deep Red
    } elseif ($percent -le 20) {
        $color = "$e[38;5;202m"  # Light Red
    } elseif ($percent -le 30) {
        $color = "$e[38;5;208m"  # Light Orange
    } elseif ($percent -le 40) {
        $color = "$e[38;5;214m"  # Orange
    } elseif ($percent -le 50) {
        $color = "$e[38;5;226m"  # Yellow
    } elseif ($percent -le 60) {
        $color = "$e[38;5;228m"  # Light Yellow
    } elseif ($percent -le 70) {
        $color = "$e[38;5;154m"  # Light Green
    } elseif ($percent -le 80) {
        $color = "$e[38;5;118m"  # Green
    } else {
        $color = "$e[38;5;34m"   # Dark Green
    }

    $bar = "$color" + ("#" * $filledLength) + "$e[0m"
    $paddingLength = $barLength - $filledLength
    $padding = " " * $paddingLength

    Write-Host -NoNewline "`r[$bar$padding] $percent% ($current/$total)"
}

if ($current -eq -1) {
    for ($i = 0; $i -le $total; $i++) {
        Show-ProgressBar -current $i -total $total
        Start-Sleep -Milliseconds 100
    }
} else {
    Show-ProgressBar -current $current -total $total
}