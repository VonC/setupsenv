<#
codexu-prune.ps1 - remove the Codex package releases that codexu no longer
needs, run by codexu.bat.

The Codex installer puts each version in its own folder and never removes
one: packages\standalone\releases grows by about 450 MB per update. In that
folder and in packages\app-server-daemon\releases, this script keeps the Keep
newest versions, read from each release's codex-package.json, and the release
that 'current' points to, then removes the others. A release whose version
cannot be read is left alone.

A release in use is kept: a file Codex runs or holds open cannot be opened
here for exclusive access. Its folder is renamed to .prune.<name> before it is
removed, so that a removal stopped half way never looks like a release; the
next run removes what is left. A .staging.* folder older than a day is an
update that never finished: it goes too.

  codexu-prune.ps1 -CodexHome <folder> [-Keep 2] [-DryRun]

Exit codes: 0 done (releases in use are kept), 1 a folder could not be
removed.
#>
param(
    [Parameter(Mandatory = $true)][string]$CodexHome,
    [ValidateRange(1, 100)][int]$Keep = 2,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$script:failed = 0
$script:freed = 0L
$staleBefore = (Get-Date).AddDays(-1)

function Get-FolderSize([string]$Path) {
    $size = 0L
    foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue) {
        $size += $file.Length
    }
    $size
}

function Get-VersionKey([string]$Text) {
    if ($Text -notmatch '^(\d+(?:\.\d+){1,3})(-.+)?$') { return $null }
    # A pre-release such as 0.167.0-alpha.2 comes before 0.167.0.
    [pscustomobject]@{ Number = [version]$Matches[1]; Final = [int](-not $Matches[2]); Text = $Text }
}

# Returns the first file of Path that cannot be opened for exclusive access.
function Find-FileInUse([string]$Path) {
    foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -Force -File) {
        try {
            $stream = [System.IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None')
            $stream.Close()
        } catch {
            return $file.FullName
        }
    }
    $null
}

function Remove-Release([string]$Path, [string]$Label) {
    $mb = [math]::Round((Get-FolderSize $Path) / 1MB)
    $busy = Find-FileInUse $Path
    if ($busy) {
        "keep $Label, in use: '$busy'"
        return
    }
    if ($DryRun) {
        "would remove $Label ($mb MB)"
        $script:freed += $mb
        return
    }
    $name = Split-Path -Leaf $Path
    $doomed = $Path
    if (-not $name.StartsWith('.prune.')) {
        $doomed = Join-Path (Split-Path -Parent $Path) ('.prune.' + $name)
        try {
            Rename-Item -LiteralPath $Path -NewName ('.prune.' + $name)
        } catch {
            "could not remove ${Label}: $($_.Exception.Message)"
            $script:failed++
            return
        }
    }
    try {
        Remove-Item -LiteralPath $doomed -Recurse -Force
    } catch {
        "could not remove all of $Label, the rest is in '$doomed': $($_.Exception.Message)"
        $script:failed++
        return
    }
    "removed $Label ($mb MB)"
    $script:freed += $mb
}

foreach ($kind in 'standalone', 'app-server-daemon') {
    $package = Join-Path $CodexHome "packages\$kind"
    $releases = Join-Path $package 'releases'
    if (-not (Test-Path -LiteralPath $releases -PathType Container)) { continue }

    # 'current' is a junction to a folder of releases: compared by name, which
    # keeps one release too many rather than too few.
    $currentName = $null
    $current = Join-Path $package 'current'
    if (Test-Path -LiteralPath $current) {
        $target = (Get-Item -LiteralPath $current -Force).Target | Select-Object -First 1
        if ($target) { $currentName = Split-Path -Leaf $target }
    }

    $found = @()
    foreach ($folder in Get-ChildItem -LiteralPath $releases -Directory -Force) {
        if ($folder.Name.StartsWith('.prune.')) {
            Remove-Release $folder.FullName "$kind leftover $($folder.Name)"
            continue
        }
        if ($folder.Name.StartsWith('.staging.')) {
            if ($folder.LastWriteTime -lt $staleBefore) {
                Remove-Release $folder.FullName "$kind leftover $($folder.Name)"
            }
            continue
        }
        if ($folder.Name.StartsWith('.')) { continue }
        $version = $null
        try {
            $json = Get-Content -Raw -LiteralPath (Join-Path $folder.FullName 'codex-package.json')
            $version = ($json | ConvertFrom-Json).version
        } catch {
            $version = $null
        }
        $key = $null
        if ($version) { $key = Get-VersionKey ([string]$version) }
        if (-not $key) {
            "keep $kind $($folder.Name), no version in its codex-package.json"
            continue
        }
        $found += [pscustomobject]@{ Folder = $folder; Key = $key }
    }

    $sorted = @($found | Sort-Object -Descending -Property @{ Expression = { $_.Key.Number } },
        @{ Expression = { $_.Key.Final } }, @{ Expression = { $_.Key.Text } })
    for ($i = 0; $i -lt $sorted.Count; $i++) {
        $label = "$kind $($sorted[$i].Key.Text)"
        $folder = $sorted[$i].Folder
        if ($i -lt $Keep) {
            "keep $label, one of the $Keep newest"
        } elseif ($currentName -and $folder.Name -ieq $currentName) {
            "keep $label, 'current' points to it"
        } else {
            Remove-Release $folder.FullName $label
        }
    }
}

if ($DryRun) {
    "would free $($script:freed) MB"
} else {
    "freed $($script:freed) MB"
}
if ($script:failed -gt 0) { exit 1 }
exit 0
