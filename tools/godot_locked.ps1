# Run one Godot command while holding the project-wide render lock
# (same lock as tools/weapon_real/one_gun_locked.ps1) and with no other Godot running.
#   powershell -File tools/godot_locked.ps1 -Out <log> -GodotArgs "--path . --script res://tests/x.gd -- --flag"
param([string]$Out = "$env:TEMP\godot_locked.txt", [int]$TimeoutSec = 900, [string]$GodotArgs)
$godot = "$env:USERPROFILE\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$root = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $root
$lockPath = Join-Path $root ".godot_render.lock"
# Headless parse checks (--check-only) load no park, use no GPU and finish in seconds:
# run them at once instead of queueing behind multi-minute park builds.
if ($GodotArgs -match '--check-only' -and $GodotArgs -match '--headless') {
    $p = Start-Process -FilePath $godot -ArgumentList $GodotArgs -NoNewWindow -PassThru -RedirectStandardOutput $Out -RedirectStandardError "$Out.err"
    if (-not $p.WaitForExit(120000)) { $p.Kill(); "TIMEOUT after 120 s" }
    "exit code: $($p.ExitCode)"
    exit
}
$lock = $null; $waited = 0
while ($null -eq $lock) {
    try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { if ($waited % 60 -eq 0) { "waiting for Godot lock ($waited s)" }; Start-Sleep 10; $waited += 10 }
}
try {
    while (Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue) { if ($waited % 60 -eq 0) { "another Godot is running; waiting ($waited s)" }; Start-Sleep 10; $waited += 10 }
    $p = Start-Process -FilePath $godot -ArgumentList $GodotArgs -NoNewWindow -PassThru -RedirectStandardOutput $Out -RedirectStandardError "$Out.err"
    # Test boots run below normal priority so they take CPU only when the user's own apps are idle.
    try { $p.PriorityClass = 'BelowNormal' } catch {}
    # Hang watchdog: a Godot that uses no CPU and writes no output for 120 s is stuck
    # (seen after a probe calls quit() mid-load); kill it so the queue behind the lock moves.
    $deadline = (Get-Date).AddSeconds($TimeoutSec); $lastCpu = -1.0; $lastLen = -1; $idleSince = Get-Date
    while (-not $p.WaitForExit(10000)) {
        if ((Get-Date) -gt $deadline) { $p.Kill(); "TIMEOUT after $TimeoutSec s"; break }
        $p.Refresh(); $cpu = $p.TotalProcessorTime.TotalSeconds
        $len = 0; foreach ($f in @($Out, "$Out.err")) { if (Test-Path $f) { $len += (Get-Item $f).Length } }
        if ($cpu -ne $lastCpu -or $len -ne $lastLen) { $lastCpu = $cpu; $lastLen = $len; $idleSince = Get-Date }
        elseif (((Get-Date) - $idleSince).TotalSeconds -ge 120) { $p.Kill(); "HUNG: no CPU or output for 120 s, killed"; break }
    }
    "exit code: $($p.ExitCode)"
} finally { $lock.Close() }
