# parse_prgs_list_for_pattern.ps1

Param(
    [Parameter(Mandatory = $true)]
    [string]$prg_list_file,

    [Parameter(Mandatory = $true)]
    [string]$string_to_test,

    [Parameter(Mandatory = $false)]
    [switch]$showDebug
)

$PSModuleAutoloadingPreference = 'None'

Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop

function Write-ErrorAndExit {
    param (
        [string]$Message,
        [int]$ExitCode = 1
    )
    Write-Error $Message
    exit $ExitCode
}

function Write-DebugMessage {
  param (
      [string]$Message
  )
  if ($showDebug) {
      Write-Host $Message
  }
}

if (-not (Test-Path -Path $prg_list_file)) {
    Write-ErrorAndExit -Message "The file '$prg_list_file' does not exist."
}

$matchingLines = @()

Get-Content -Path $prg_list_file | ForEach-Object {
    $prg_line = $_.Trim()

    if ([string]::IsNullOrWhiteSpace($prg_line)) {
        return
    }

    $tokens = $prg_line -split '~'

    if ($tokens.Count -ge 4) {
        $pattern = $tokens[3].Trim()

        if (-not [string]::IsNullOrWhiteSpace($pattern)) {
            # Escape regex special characters except for * and ?
            $escapedPattern = ''
            foreach ($char in $pattern.ToCharArray()) {
                if ($char -in ('*', '?')) {
                    $escapedPattern += $char
                } elseif ('\.+()|[]{}^$'.Contains($char)) {
                    $escapedPattern += '\'+$char
                } else {
                    $escapedPattern += $char
                }
            }

            # Replace glob wildcards with regex equivalents
            $regexPattern = $escapedPattern -replace '\*', '.*' -replace '\?', '.'

            # Add anchors to match the entire string
            $regexPattern = '^' + $regexPattern + '$'

            # Debug output
            Write-DebugMessage "Testing pattern: '$pattern'"
            Write-DebugMessage "Escaped pattern: '$escapedPattern'"
            Write-DebugMessage "Converted regex: '$regexPattern'"
            Write-DebugMessage "String to test: '$string_to_test'"

            # Test if the string matches the pattern
            if ($string_to_test -match $regexPattern) {
              Write-DebugMessage "Match found."
                $matchingLines += $prg_line
            } else {
              Write-DebugMessage "No match."
            }
        }
    }
}

switch ($matchingLines.Count) {
    0 {
        Write-ErrorAndExit -Message "No matching lines found in '$prg_list_file' for string '$string_to_test'."
    }
    1 {
        Write-Output $matchingLines[0]
        exit 0
    }
    default {
        Write-ErrorAndExit -Message "Multiple matching lines found in '$prg_list_file' for string '$string_to_test'. Expected only one."
    }
}
