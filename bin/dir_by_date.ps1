param (
    [string]$folder,
    [string]$pattern,
    [string]$envVarName = "RESULT"
)

if (-not $folder -or -not $pattern) {
    Write-Host "Usage: .\dir_by_date.ps1 -folder <folder> -pattern <pattern>"
    exit 1
}

$PSModuleAutoloadingPreference = 'None'
# Load necessary assembly (suppress output)
# [void][Reflection.Assembly]::LoadWithPartialName("System.Select-Object")
Import-Module Microsoft.PowerShell.Management
#Import-Module CimCmdlets
Import-Module Microsoft.PowerShell.Utility

# Collect the formatted results
$result = Get-ChildItem -Path $folder -Filter $pattern | ForEach-Object {
  $creationDate = $_.CreationTime
  $formattedDate = $creationDate.ToString("yyyyMMdd-HHmm")
  "$formattedDate $($_.Name)"
}

# Join the results into a single string
$resultString = $result -join "`n"

# Check if the environment variable is already set
if (Test-Path "env:$envVarName") {
  $currentValue = Get-Item -Path "env:$envVarName"
  Set-Item -Path "env:$envVarName" -Value "$($currentValue.Value)`n$resultString"
} else {
  Set-Item -Path "env:$envVarName" -Value $resultString
}

# Output the result for verification
$finalValue = (Get-Item -Path "env:$envVarName").Value -replace "`n", [System.Environment]::NewLine
#Write-Host "Environment variable '$envVarName' set to:"
#Write-Host $finalValue

# Output the final value for CMD to capture
Write-Output $finalValue