# Windows PowerShell 5.1 helper for sshagent.bat. No service or administrator needed.
[CmdletBinding()]
param(
    [ValidateSet('load', 'status')][string]$Mode = 'load',
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$agentMutex = $null
$locked = $false

function Expand-LocalPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { throw 'An absolute path is required.' }
    $expanded = [Environment]::ExpandEnvironmentVariables($Value)
    if ($expanded -notmatch '^(?:[A-Za-z]:[\\/]|\\\\)') {
        throw 'Use an absolute Windows path, optionally with %ENVIRONMENT_VARIABLES%.'
    }
    return [IO.Path]::GetFullPath($expanded)
}

function Resolve-PhysicalPath([string]$Path, [int]$Depth = 0) {
    # Resolve junctions in every parent: Resolve-Path alone preserves them.
    if ($Depth -gt 64) { throw 'Too many links in the Git installation path.' }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = @($item.Target)[0]
        if (-not $target) { throw 'Cannot resolve the Git installation link.' }
        if (-not [IO.Path]::IsPathRooted($target)) {
            $target = Join-Path (Split-Path -Parent $item.FullName) $target
        }
        return Resolve-PhysicalPath $target ($Depth + 1)
    }
    $parent = Split-Path -Parent $item.FullName
    if (-not $parent) { return $item.FullName }
    return Join-Path (Resolve-PhysicalPath $parent ($Depth + 1)) $item.Name
}

function Get-AgentKeys {
    # ssh-add: 0 = identities, 1 = empty agent, 2 = unreachable agent.
    $ErrorActionPreference = 'Continue'
    $lines = @(& $script:agentAdd -L 2>$null)
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Alive = ($code -eq 0 -or $code -eq 1); Keys = $lines }
}

function Test-ConfiguredKey($Keys) {
    foreach ($line in $Keys) {
        $parts = "$line" -split '\s+', 3
        if ($parts.Count -ge 2 -and ($parts[0..1] -join ' ') -ceq $script:keyIdentity) {
            return $true
        }
    }
    return $false
}

function Assert-AgentEnvironment {
    # These values are imported into CMD, never executed as a generated script.
    # Reject expansion/control characters, including when inherited from a caller.
    if (-not $env:SSH_AUTH_SOCK -or $env:SSH_AUTH_SOCK -match '[\x00-\x1f"%!^]') {
        throw 'Agent socket path contains characters that cannot be exported safely to CMD.'
    }
    if ($env:SSH_AGENT_PID -and $env:SSH_AGENT_PID -notmatch '^\d+$') {
        throw 'Invalid SSH agent process identifier.'
    }
}

function Save-AgentState {
    Assert-AgentEnvironment
    $state = [ordered]@{ socket = $env:SSH_AUTH_SOCK; pid = $env:SSH_AGENT_PID }
    $temporary = "$script:statePath.$PID.tmp"
    try {
        [IO.File]::WriteAllText($temporary, ($state | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $script:statePath -Force
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}

function Assert-IgnoredByGit([string]$Path) {
    # A passphrase file inside a Git working tree must be ignored there, or the
    # next git add -A would commit it and the next push publish it.
    $git = Join-Path (Split-Path -Parent (Split-Path -Parent $script:gitBin)) 'cmd\git.exe'
    if (-not (Test-Path -LiteralPath $git -PathType Leaf)) {
        $git = (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if (-not $git) { return }
    }
    $ErrorActionPreference = 'Continue'
    $folder = Split-Path -Parent $Path
    $inside = & $git -C $folder rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or "$inside" -ne 'true') { return }
    # 0 = ignored; 1 = not ignored, or tracked (a tracked file is never ignored).
    & $git -C $folder check-ignore -q -- $Path 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Passphrase file $Path is in a Git working tree and not ignored there: add it to that repository's .git/info/exclude."
    }
}

function Add-KeyWithPassphraseFile([string]$Key, [string]$PassphraseFile, [int]$Lifetime) {
    # ssh-add reads a passphrase only from a terminal or an SSH_ASKPASS program:
    # a throwaway askpass script answers it. The passphrase itself goes through
    # this process's environment, never through a file or a command line.
    $passphrase = Get-Content -LiteralPath $PassphraseFile -TotalCount 1 -Encoding UTF8
    if ([string]::IsNullOrEmpty($passphrase)) { throw "Passphrase file is empty: $PassphraseFile" }
    $askpass = Join-Path ([IO.Path]::GetTempPath()) ("senv-askpass-" + [Guid]::NewGuid().ToString('N') + '.sh')
    $saved = @{}
    foreach ($name in @('SSH_ASKPASS', 'SSH_ASKPASS_REQUIRE', 'SENV_SSHAGENT_PASSPHRASE')) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    # Only the first prompt is answered: after a wrong passphrase ssh-add asks
    # again ("Bad passphrase, try again"), and the same answer would loop.
    $helper = @'
#!/bin/sh
case "$1" in Bad*) exit 1 ;; esac
printf '%s\n' "$SENV_SSHAGENT_PASSPHRASE"
'@
    $code = 1
    try {
        [IO.File]::WriteAllText($askpass, $helper.Replace("`r", ''), [Text.UTF8Encoding]::new($false))
        $env:SSH_ASKPASS = $askpass.Replace('\', '/')
        $env:SSH_ASKPASS_REQUIRE = 'force'
        $env:SENV_SSHAGENT_PASSPHRASE = $passphrase
        & $script:agentAdd -t $Lifetime $Key
        $code = $LASTEXITCODE
    } finally {
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
        if (Test-Path -LiteralPath $askpass) { Remove-Item -LiteralPath $askpass }
    }
    if ($code -ne 0) { throw "The passphrase in $PassphraseFile does not unlock the key: correct or delete that file." }
}

function Start-UserAgent {
    # Give the daemon its own handles. Inheriting a calling script's pipes can
    # otherwise keep subprocess.communicate() waiting after this launcher exits.
    $prefix = Join-Path ([IO.Path]::GetTempPath()) ("senv-agent-start-" + [Guid]::NewGuid().ToString('N'))
    $process = $null
    try {
        $env:SENV_AGENT_START_EXE = Join-Path $script:gitBin 'ssh-agent.exe'
        $env:SENV_AGENT_START_OUT = "$prefix.out"
        $env:SENV_AGENT_START_ERR = "$prefix.err"
        # ShellExecute starts a separate hidden console without inherited pipes.
        # Redirect in that console, not via Start-Process's inherited handles.
        $process = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
            -ArgumentList '/d /v:off /s /c ""%SENV_AGENT_START_EXE%" -s >"%SENV_AGENT_START_OUT%" 2>"%SENV_AGENT_START_ERR%""' `
            -WindowStyle Hidden -PassThru
        # Start-Process -Wait waits for the daemon too; wait only for its parent.
        if (-not $process.WaitForExit(10000)) { throw 'SSH agent startup timed out.' }
        if ($process.ExitCode -ne 0) { throw 'Git for Windows ssh-agent failed to start.' }
        return [IO.File]::ReadAllText("$prefix.out")
    } finally {
        if ($process) { $process.Dispose() }
        foreach ($suffix in @('.out', '.err')) {
            if (Test-Path -LiteralPath "$prefix$suffix") { Remove-Item -LiteralPath "$prefix$suffix" }
        }
    }
}

try {
    $ConfigPath = Expand-LocalPath $ConfigPath
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Private config missing: $ConfigPath. Copy sshagent.example.json there and set privateKey."
    }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $keyPath = Expand-LocalPath $config.privateKey
    if ($keyPath.EndsWith('.pub', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'privateKey must name the private key, not the .pub file.'
    }
    foreach ($path in @($keyPath, "$keyPath.pub")) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Key file missing: $path" }
    }
    $gitBin = $config.gitBin
    if (-not $gitBin) { $gitBin = '%PRGS%\gits\current\usr\bin' }
    $gitBin = Resolve-PhysicalPath (Expand-LocalPath $gitBin)
    foreach ($tool in @('ssh-agent.exe', 'ssh-add.exe', 'ssh-keygen.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $gitBin $tool) -PathType Leaf)) {
            throw "Git for Windows tool missing: $tool in $gitBin"
        }
    }
    $script:agentAdd = Join-Path $gitBin 'ssh-add.exe'
    $lifetime = 3600
    if ($null -ne $config.lifetimeSeconds) {
        if ("$($config.lifetimeSeconds)" -notmatch '^[1-9][0-9]*$') {
            throw 'lifetimeSeconds must be a positive integer.'
        }
        $lifetime = [int]$config.lifetimeSeconds
    }
    $publicKey = (Get-Content -LiteralPath "$keyPath.pub" -Raw -Encoding UTF8).Trim() -split '\s+', 3
    if ($publicKey.Count -lt 2) { throw 'Invalid public key file.' }
    $script:keyIdentity = $publicKey[0..1] -join ' '
    $fingerprint = & (Join-Path $gitBin 'ssh-keygen.exe') -l -E sha256 -f "$keyPath.pub"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the public key fingerprint.' }
    $fingerprint = ("$fingerprint" -split '\s+')[1]

    $script:statePath = "$ConfigPath.state.json"
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $id = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($ConfigPath.ToLowerInvariant()))).Replace('-', '')
    } finally { $hash.Dispose() }
    $agentMutex = [Threading.Mutex]::new($false, "Local\senv-sshagent-$id")
    try { $locked = $agentMutex.WaitOne(30000) }
    catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Another sshagent invocation is still running. Finish its prompt, then retry.' }

    $inheritedSocket = $env:SSH_AUTH_SOCK
    $inheritedPid = $env:SSH_AGENT_PID
    $agent = [pscustomobject]@{ Alive = $false; Keys = @() }
    if (Test-Path -LiteralPath $statePath) {
        try {
            $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $env:SSH_AUTH_SOCK = $state.socket
            $env:SSH_AGENT_PID = $state.pid
            Assert-AgentEnvironment
            $agent = Get-AgentKeys
        } catch { Write-Host 'sshagent: ignoring invalid saved agent state.' }
    }
    if (-not $agent.Alive -and $inheritedSocket) {
        $env:SSH_AUTH_SOCK = $inheritedSocket
        $env:SSH_AGENT_PID = $inheritedPid
        Assert-AgentEnvironment
        $agent = Get-AgentKeys
    }
    if (-not $agent.Alive) {
        if ($Mode -eq 'status') { throw 'No reachable agent. Run sshagent to start one and load the key.' }
        # Let OpenSSH choose a fresh socket; never remove sockets or kill other agents.
        $startup = Start-UserAgent
        if ($startup -notmatch '(?m)^SSH_AUTH_SOCK=([^;\r\n]+);') { throw 'Missing agent socket in startup output.' }
        $env:SSH_AUTH_SOCK = $Matches[1]
        if ($startup -notmatch '(?m)^SSH_AGENT_PID=(\d+);') { throw 'Missing agent PID in startup output.' }
        $env:SSH_AGENT_PID = $Matches[1]
        Assert-AgentEnvironment
        $agent = Get-AgentKeys
        if (-not $agent.Alive) { throw 'The new SSH agent is not reachable.' }
        Write-Host 'sshagent: started a user agent.'
    } else { Write-Host 'sshagent: reusing the running agent.' }

    # Save before a possible prompt failure, so the next attempt reuses this agent.
    if ($Mode -ne 'status') { Save-AgentState }
    if (-not (Test-ConfiguredKey $agent.Keys)) {
        if ($Mode -eq 'status') { throw "Agent is running; configured key $fingerprint is not loaded. Run sshagent." }
        # A private passphrase file named after the key replaces the prompt.
        $passphrasePath = "$keyPath.passphrase"
        if (Test-Path -LiteralPath $passphrasePath -PathType Leaf) {
            Assert-IgnoredByGit $passphrasePath
            Write-Host "sshagent: loading $fingerprint for $lifetime seconds with the passphrase in $passphrasePath."
            Add-KeyWithPassphraseFile $keyPath $passphrasePath $lifetime
        } else {
            Write-Host "sshagent: loading $fingerprint for $lifetime seconds. Enter the passphrase locally if asked."
            & $script:agentAdd -t $lifetime $keyPath
            if ($LASTEXITCODE -ne 0) { throw 'Key loading failed or was cancelled. Run sshagent to retry.' }
        }
        $agent = Get-AgentKeys
        if (-not $agent.Alive -or -not (Test-ConfiguredKey $agent.Keys)) {
            throw 'The configured public key does not match a key loaded into the agent.'
        }
    } else { Write-Host "sshagent: configured key $fingerprint is already loaded." }
    Assert-AgentEnvironment
    [IO.File]::WriteAllLines($OutputPath, @("SSH_AUTH_SOCK=$env:SSH_AUTH_SOCK", "SSH_AGENT_PID=$env:SSH_AGENT_PID"), [Text.UTF8Encoding]::new($false))
    exit 0
} catch {
    [Console]::Error.WriteLine("sshagent: ERROR: " + $_.Exception.Message)
    exit 1
} finally {
    if ($locked) { $agentMutex.ReleaseMutex() }
    if ($agentMutex) { $agentMutex.Dispose() }
}
