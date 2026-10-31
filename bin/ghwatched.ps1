[CmdletBinding()]
param(
    # Words looked for in the name, topics and description; one match is
    # enough. 'a,b' holds two words, '@name' a word list.
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Words = @(),

    # Print only owner/name, one per line.
    [switch]$Names,

    # The gh to drive: senv's own gh.exe first, one on PATH otherwise.
    [string]$Gh
)

$ErrorActionPreference = 'Stop'

# GitHub's API lists only the full watches ('All activity'). A custom watch,
# releases or security alerts only, never shows in GET /user/subscriptions, and
# GET /repos/{owner}/{repo}/subscription answers 404 as for an unwatched repo.
# GraphQL tells the custom watch apart in its own way: viewerSubscription is
# SUBSCRIBED for a full watch, UNSUBSCRIBED for none, and null for a custom
# one. No connection lists the custom watches, so they are found among the
# starred repositories: one watched without a star stays out of reach.
$Query = 'query($endCursor: String) { viewer { starredRepositories(first: 100, after: $endCursor) { pageInfo { hasNextPage endCursor } nodes { nameWithOwner isArchived viewerSubscription description repositoryTopics(first: 20) { nodes { topic { name } } } } } } }'

function Show-Usage {
    Write-Host 'List the starred GitHub repositories you watch with a custom setting'
    Write-Host '(releases, security alerts...), optionally filtered by words.'
    Write-Host ''
    Write-Host 'Usage: ghwatched [-Names] [<word>|=<word>|<word>,<word>|@<list>] ...'
    Write-Host ''
    Write-Host '  One line per repository: owner/name | topics | description.'
    Write-Host '  With words, only the repositories where at least one of them'
    Write-Host '  matches the name, a topic or the description. A word matches'
    Write-Host '  where a word of the text starts with it, ignoring case: vuln'
    Write-Host '  finds vulnerability, not invulnerable.'
    Write-Host '  =<word> matches that whole word only: =pip finds pip, not pipeline.'
    Write-Host '  @<list> reads words from a file, one per line, # for comments:'
    Write-Host '  a path, or the name of a ghwatched.<list>.txt next to this script'
    Write-Host '  (@security is shipped).'
    Write-Host '  -Names prints only owner/name.'
    Write-Host ''
    Write-Host 'The count goes to standard error, so the list can be redirected.'
    Write-Host 'Only starred repositories are seen: the API lists no custom watch.'
}

function Write-Problem([string]$message) {
    [Console]::Error.WriteLine("ghwatched: $message")
}

# The count goes where the problems go, keeping standard output to the list.
function Write-Note([string]$message) {
    [Console]::Error.WriteLine($message)
}

# Splits on commas, trims, drops the blanks: 'a, b,' gives a and b. A lone
# '=' is a blank as well: there is no word left to match exactly.
function Split-Words([string]$text) {
    foreach ($part in $text.Split(',')) {
        $word = $part.Trim()
        if ($word -and $word -ne '=') { $word }
    }
}

# '@name' is a path when one exists, ghwatched.<name>.txt beside the script
# otherwise; the deployed copy lives in %HOME%\bin, where custom lists go too.
function Read-WordList([string]$spec) {
    $name = $spec.Substring(1)
    $paths = @($name, (Join-Path $PSScriptRoot "ghwatched.$name.txt"))
    $path = $paths | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if (-not $path) {
        Write-Problem ("No word list '{0}': neither that file nor '{1}'" -f $name, $paths[1])
        exit 41
    }
    foreach ($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $path).ProviderPath, [Text.Encoding]::UTF8)) {
        $text = $line.Trim()
        if ($text -and -not $text.StartsWith('#')) { Split-Words $text }
    }
}

function Find-Gh {
    if ($Gh) {
        if (Test-Path -LiteralPath $Gh -PathType Leaf) { return $Gh }
        Write-Problem "No gh at '$Gh'"
        exit 42
    }
    if ($env:PRGS) {
        $senvGh = Join-Path $env:PRGS 'ghs\gh-cli\bin\gh.exe'
        if (Test-Path -LiteralPath $senvGh -PathType Leaf) { return $senvGh }
    }
    $onPath = Get-Command gh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    Write-Problem "No gh.exe found, neither '$env:PRGS\ghs\gh-cli\bin\gh.exe' nor one on PATH"
    exit 42
}

# One compact JSON object per starred repository, from every page. Windows
# PowerShell decodes what gh prints with the console code page, and wraps each
# stderr line of a native command in an error that 'Stop' would throw: both
# are set aside for the call.
function Read-Starred([string]$gh) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $gh api graphql --paginate -f "query=$Query" --jq '.data.viewer.starredRepositories.nodes[]' 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $saved
    }
    $lines = @($output | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] })
    if ($code -ne 0) {
        Write-Problem 'Unable to read the starred repositories; gh said:'
        $output | Where-Object { $_ -is [Management.Automation.ErrorRecord] } | ForEach-Object {
            [Console]::Error.WriteLine($_.ToString())
        }
        exit 44
    }
    $json = @($lines | Where-Object { $_.Trim() })
    if ($json.Count -eq 0) { return }
    # Windows PowerShell hands a JSON array back as one object: it is unrolled
    # here so the caller sees one repository at a time.
    foreach ($repo in (ConvertFrom-Json ('[' + ($json -join ',') + ']'))) { $repo }
}

# A word matches at the start of a word of the text: nothing alphanumeric
# right before it. 'auth' finds authentication but not oauth, 'ids' not kids.
# '=word' also wants nothing alphanumeric right after: '=pip' finds the pip
# topic, where 'pip' would find pipeline as well.
function New-Matcher([string[]]$words) {
    $alternatives = foreach ($word in $words) {
        if ($word.StartsWith('=')) {
            [Regex]::Escape($word.Substring(1)) + '(?![\p{L}\p{N}])'
        } else {
            [Regex]::Escape($word)
        }
    }
    $pattern = '(?<![\p{L}\p{N}])(?:' + ($alternatives -join '|') + ')'
    New-Object Regex($pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

if ($Words -contains '/?') {
    Show-Usage
    exit 0
}

$wanted = New-Object Collections.Generic.List[string]
foreach ($arg in $Words) {
    if ($arg.StartsWith('@')) {
        foreach ($word in (Read-WordList $arg)) { $wanted.Add($word) }
    } else {
        foreach ($word in (Split-Words $arg)) { $wanted.Add($word) }
    }
}
if ($Words.Count -gt 0 -and $wanted.Count -eq 0) {
    Write-Problem 'The arguments hold no word to look for'
    exit 41
}

$gh = Find-Gh
$savedEncoding = $null
try {
    $savedEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
} catch {
    # No console to set: the run goes on with the current code page.
    $savedEncoding = $null
}

try {
    $custom = @(Read-Starred $gh | Where-Object { $null -eq $_.viewerSubscription })
    $matcher = $null
    if ($wanted.Count -gt 0) { $matcher = New-Matcher $wanted.ToArray() }

    $shown = 0
    foreach ($repo in $custom) {
        $topics = @($repo.repositoryTopics.nodes | ForEach-Object { $_.topic.name }) -join ', '
        $description = ''
        if ($repo.description) { $description = ($repo.description -replace '\s+', ' ').Trim() }
        if ($matcher) {
            # Newlines keep a word from matching across two fields.
            $text = $repo.nameWithOwner + "`n" + $topics + "`n" + $description
            if (-not $matcher.IsMatch($text)) { continue }
        }
        $shown++
        if ($Names) {
            Write-Output $repo.nameWithOwner
            continue
        }
        $name = $repo.nameWithOwner
        if ($repo.isArchived) { $name += ' (archived)' }
        Write-Output ('{0} | {1} | {2}' -f $name, $topics, $description)
    }

    if ($matcher) {
        Write-Note ('{0} of {1} custom-watched repositories match' -f $shown, $custom.Count)
        if ($shown -eq 0) { exit 1 }
    } else {
        Write-Note ('{0} custom-watched repositories' -f $custom.Count)
    }
    exit 0
} finally {
    if ($savedEncoding) {
        try { [Console]::OutputEncoding = $savedEncoding } catch { }
    }
}
