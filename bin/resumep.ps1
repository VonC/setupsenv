$PSModuleAutoloadingPreference = 'None'
# Load necessary assembly (suppress output)
# [void][Reflection.Assembly]::LoadWithPartialName("System.Select-Object")
Import-Module CimCmdlets
Import-Module Microsoft.PowerShell.Utility
Get-CimInstance Win32_Process -Filter "processid=$($args[0])" | Select-Object -ExpandProperty CommandLine
