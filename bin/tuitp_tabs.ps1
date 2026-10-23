# Select a Windows Terminal tab by its title, for tuitp_watch.py.
# One JSON request per input line: {"title": "...", "siblings": ["...", ...]}.
# One JSON reply per request, after a first {"ready": true} line.
# siblings are the titles of the other tuitp tabs of its window: when several
# Windows Terminal windows hold a tab of that title, the one that holds the
# most of them is the tuitp window.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Its progress records would reach stderr as CLIXML.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TuitpForeground {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
'@
$A = [System.Windows.Automation.AutomationElement]
$Scope = [System.Windows.Automation.TreeScope]
$isWindow = New-Object System.Windows.Automation.PropertyCondition($A::ClassNameProperty, 'CASCADIA_HOSTING_WINDOW_CLASS')
$isTab = New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::TabItem)

function Select-Tab($request) {
    $found = $null
    $score = -1
    foreach ($window in $A::RootElement.FindAll($Scope::Children, $isWindow)) {
        $tabs = @($window.FindAll($Scope::Descendants, $isTab))
        $names = @($tabs | ForEach-Object { $_.Current.Name })
        $tab = $tabs | Where-Object { $_.Current.Name -ceq $request.title } | Select-Object -First 1
        if (-not $tab) { continue }
        $count = @($request.siblings | Where-Object { $names -ccontains $_ }).Count
        if ($count -gt $score) {
            $found = @($window, $tab)
            $score = $count
        }
    }
    if (-not $found) {
        return @{ ok = $false; error = "no Windows Terminal tab is titled $($request.title)" }
    }
    $window, $tab = $found
    $tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
    # A click on the rail leaves its window in front: raise only another one.
    $raised = [TuitpForeground]::GetForegroundWindow() -ne [IntPtr]$window.Current.NativeWindowHandle
    if ($raised) { $window.SetFocus() }
    return @{ ok = $true; raised = $raised }
}

[Console]::Out.WriteLine('{"ready": true}')
[Console]::Out.Flush()
while ($null -ne ($line = [Console]::In.ReadLine())) {
    try {
        $reply = Select-Tab ($line | ConvertFrom-Json)
    } catch {
        $reply = @{ ok = $false; error = $_.Exception.Message }
    }
    [Console]::Out.WriteLine(($reply | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
}
