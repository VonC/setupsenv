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

# Latest means the highest version, not the last file created: an older release
# downloaded after a newer one must not win. Padding each digit run puts names in
# natural order (0.10.1 after 0.10.0 and 0.9.5), and the creation date only
# decides between names of the same version.
function Get-VersionKey([string]$name) {
    return [regex]::Replace($name, '\d+', { param($m) $m.Value.PadLeft(20, '0') })
}

function Compare-Version([string]$left, [string]$right) {
    return [string]::Compare((Get-VersionKey $left), (Get-VersionKey $right), [StringComparison]::OrdinalIgnoreCase)
}

# Collect the formatted results
$newestFile = $null
foreach ($file in Get-ChildItem -Path $folder -Filter $pattern) {
    if ($newestFile) {
        $byVersion = Compare-Version $file.Name $newestFile.Name
        if ($byVersion -lt 0) { continue }
        if ($byVersion -eq 0 -and $file.CreationTime -le $newestFile.CreationTime) { continue }
    }
    $newestFile = $file
}

if ($newestFile) {
  $creationDate = $newestFile.CreationTime
  $formattedDate = $creationDate.ToString("yyyyMMdd-HHmm")
  $resultString = "$formattedDate $($newestFile.Name)"

  # Compare resultString with existingFile
  if (-not $existingFile) {
    # If existingFile is empty, return resultString
    Write-Output $resultString
  } else {
    # Extract the date and name parts from existingFile
    $existingDate, $existingName = $existingFile.Split(' ', 2)

    # Compare the versions, then the dates
    $byVersion = Compare-Version $newestFile.Name $existingName
    if ($byVersion -gt 0 -or ($byVersion -eq 0 -and $formattedDate -gt $existingDate)) {
        Write-Output $resultString
    } else {
        Write-Output $existingFile
    }
  }
} else {
  exit 1
}
