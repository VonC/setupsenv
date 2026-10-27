[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Folder,

    [string]$Instance = 'senv-lsc-watch',

    [switch]$NoClipboard
)

# The tray worker of `lsc watch`: when a new image lands in $Folder, its quoted
# path goes to the clipboard as Unicode text, beside the bitmap the capture tool
# put there. `lsc stop` signals the named stop event; the tray menu pauses,
# resumes or exits.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$ImageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp')
# The capture tool writes the file and the clipboard itself: copying right after
# the file is complete could come before its own clipboard write and be lost.
$SettleMs = 400
$GiveUpMs = 10000
$LogFolder = Join-Path $env:LOCALAPPDATA 'senv'
$LogPath = Join-Path $LogFolder "$Instance.log"

function Write-Log([string]$message) {
    try {
        Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + ' ' + $message)
    } catch { }
}

function New-StateIcon([bool]$paused) {
    $bitmap = New-Object Drawing.Bitmap 32, 32
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    if ($paused) { $back = [Drawing.Color]::FromArgb(117, 117, 117) } else { $back = [Drawing.Color]::FromArgb(46, 125, 50) }
    $graphics.FillRectangle((New-Object Drawing.SolidBrush $back), 1, 1, 30, 30)
    $white = [Drawing.Color]::White
    if ($paused) {
        $bars = New-Object Drawing.SolidBrush $white
        $graphics.FillRectangle($bars, 10, 8, 4, 16)
        $graphics.FillRectangle($bars, 18, 8, 4, 16)
    } else {
        # The four corners of a snip frame.
        $pen = New-Object Drawing.Pen $white, 3
        foreach ($corner in @(@(6, 6, 1, 1), @(26, 6, -1, 1), @(6, 26, 1, -1), @(26, 26, -1, -1))) {
            $x, $y, $dx, $dy = $corner
            $graphics.DrawLine($pen, $x, $y, $x + 7 * $dx, $y)
            $graphics.DrawLine($pen, $x, $y, $x, $y + 7 * $dy)
        }
    }
    $graphics.Dispose()
    return [Drawing.Icon]::FromHandle($bitmap.GetHicon())
}

$script:paused = $false
$script:lastCopy = ''
$script:pending = @{}
$watchingIcon = New-StateIcon $false
$pausedIcon = New-StateIcon $true

$notify = New-Object Windows.Forms.NotifyIcon
$menu = New-Object Windows.Forms.ContextMenuStrip
$pauseItem = New-Object Windows.Forms.ToolStripMenuItem 'Pause'
$resumeItem = New-Object Windows.Forms.ToolStripMenuItem 'Resume'
$exitItem = New-Object Windows.Forms.ToolStripMenuItem 'Exit'
[void]$menu.Items.Add($pauseItem)
[void]$menu.Items.Add($resumeItem)
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
[void]$menu.Items.Add($exitItem)
$notify.ContextMenuStrip = $menu

# NotifyIcon.Text holds 63 characters at most.
function Update-Tray {
    if ($script:paused) { $state = 'paused' } else { $state = 'watching screenshots' }
    $text = "lsc watch: $state"
    if ($script:lastCopy) { $text += "`nlast copy $($script:lastCopy)" }
    $notify.Text = $text.Substring(0, [Math]::Min(63, $text.Length))
    if ($script:paused) { $notify.Icon = $pausedIcon } else { $notify.Icon = $watchingIcon }
    $pauseItem.Enabled = -not $script:paused
    $resumeItem.Enabled = $script:paused
}

function Set-Paused([bool]$paused) {
    $script:paused = $paused
    $script:pending.Clear()
    if ($paused) { Write-Log 'paused' } else { Write-Log 'resumed' }
    Update-Tray
}

function Test-Complete([string]$path) {
    try {
        $stream = [IO.File]::Open($path, 'Open', 'Read', 'None')
        $stream.Close()
        return $true
    } catch {
        return $false
    }
}

function Copy-ImagePath([string]$path) {
    $text = '"' + $path + '"'
    if (-not $NoClipboard) {
        $data = New-Object Windows.Forms.DataObject
        if ([Windows.Forms.Clipboard]::ContainsImage()) { $data.SetImage([Windows.Forms.Clipboard]::GetImage()) }
        $data.SetText($text, [Windows.Forms.TextDataFormat]::UnicodeText)
        [Windows.Forms.Clipboard]::SetDataObject($data, $true, 10, 100)
    }
    $script:lastCopy = Get-Date -Format 'HH:mm:ss'
    Write-Log "copied $text"
    Update-Tray
}

function Receive-Changes {
    foreach ($change in @(Get-Event)) {
        Remove-Event -EventIdentifier $change.EventIdentifier
        if ($change.SourceIdentifier -notlike "$Instance-*") { continue }
        $path = $change.SourceEventArgs.FullPath
        if ($script:paused) { continue }
        if ($ImageExtensions -notcontains [IO.Path]::GetExtension($path).ToLowerInvariant()) { continue }
        $script:pending[$path] = [DateTime]::UtcNow
    }
}

function Copy-ReadyImages {
    foreach ($path in @($script:pending.Keys)) {
        $waited = ([DateTime]::UtcNow - $script:pending[$path]).TotalMilliseconds
        if ($waited -lt $SettleMs) { continue }
        if (Test-Complete $path) {
            $script:pending.Remove($path)
            Copy-ImagePath $path
        } elseif ($waited -gt $GiveUpMs) {
            $script:pending.Remove($path)
            Write-Log "skipped, still busy: $path"
        }
    }
}

$watcher = New-Object IO.FileSystemWatcher $Folder
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName'
Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "$Instance-created" | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier "$Instance-renamed" | Out-Null
$watcher.EnableRaisingEvents = $true

# `lsc` reads the mutex as "running", so it is taken once the folder is
# watched, and the stop event exists before it: neither a file nor a stop
# request can arrive in between. A second worker gives up here.
$stopSignal = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::AutoReset, "Local\$Instance-stop")
$mutex = New-Object Threading.Mutex($false, "Local\$Instance")
try {
    $owned = $mutex.WaitOne(0)
} catch [Threading.AbandonedMutexException] {
    # A worker killed without cleanup leaves its mutex abandoned, and owned now.
    $owned = $true
}
if (-not $owned) {
    $watcher.Dispose()
    exit 0
}
New-Item -ItemType Directory -Force -Path $LogFolder | Out-Null
Set-Content -LiteralPath $LogPath -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + " watching $Folder")

# The file events queue up while the message loop runs; a UI timer drains them
# on this thread, which owns the clipboard and the tray icon.
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 200
$timer.add_Tick({
    try {
        if ($stopSignal.WaitOne(0)) {
            Write-Log 'stop requested'
            [Windows.Forms.Application]::Exit()
            return
        }
        Receive-Changes
        Copy-ReadyImages
    } catch {
        Write-Log "error: $($_.Exception.Message)"
    }
})
$pauseItem.add_Click({ Set-Paused $true })
$resumeItem.add_Click({ Set-Paused $false })
$exitItem.add_Click({
    Write-Log 'exit from the tray menu'
    [Windows.Forms.Application]::Exit()
})

Update-Tray
$notify.Visible = $true
$timer.Start()
try {
    [Windows.Forms.Application]::Run()
} finally {
    $timer.Stop()
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    $notify.Visible = $false
    $notify.Dispose()
    Write-Log 'stopped'
    $mutex.ReleaseMutex()
    $mutex.Dispose()
    $stopSignal.Dispose()
}
exit 0
