param (
    [string]$folder,
    [string]$pattern,
    [string]$existingFile=""
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
$newestFile = Get-ChildItem -Path $folder -Filter $pattern | Sort-Object CreationTime | Select-Object -Last 1

if ($newestFile) {
  $creationDate = $newestFile.CreationTime
  $formattedDate = $creationDate.ToString("yyyyMMdd-HHmm")
  $resultString = "$formattedDate $($newestFile.Name)"

  # Compare resultString with existingFile
  if (-not $existingFile) {
    # If existingFile is empty, return resultString
    Write-Output $resultString
  } else {
    # Extract the date part from existingFile
    $existingDate = $existingFile.Split(' ')[0]

    # Compare the dates
    if ($formattedDate -gt $existingDate) {
        Write-Output $resultString
    } else {
        Write-Output $existingFile
    }
  }
} else {
  exit 1
}
