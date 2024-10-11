param (
    [string]$filePath
)

if (-not $filePath) {
    Write-Host "Usage: .\check_trailing_newline.ps1 <filePath>"
    exit
}

$PSModuleAutoloadingPreference = 'None'
# Load necessary assembly (suppress output)
# [void][Reflection.Assembly]::LoadWithPartialName("System.Select-Object")
Import-Module CimCmdlets
Import-Module Microsoft.PowerShell.Utility

# Create a FileStream object
$fs = New-Object System.IO.FileStream $filePath, 'Open', 'Read'

# Seek to the last byte of the file
$fs.Seek(-1, 'End') | Out-Null

# Read the last byte
$lastByte = $fs.ReadByte()

# Convert the byte to a hexadecimal string
$hexString = "{0:X2}" -f $lastByte

# Output the hexadecimal string
Write-Output $hexString

# Close the FileStream
$fs.Close()