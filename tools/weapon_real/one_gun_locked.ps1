# Rebuild one gun, then (holding a project-wide Godot lock) import, render the
# fixed review cameras and make its before/after sheet. Safe to run for several
# guns at once: Blender builds run in parallel, Godot steps run one at a time.
#   powershell -File tools/weapon_real/one_gun_locked.ps1 -Key akane -Builder akane_glock17 [-Tag after] [-SkipBuild] [-WithBefore]
param([string]$Key, [string]$Builder, [string]$Tag = "after", [switch]$SkipBuild, [switch]$WithBefore)
$ErrorActionPreference = 'Continue'
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$godot = "$env:USERPROFILE\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root
if (-not $SkipBuild) {
    "[$Key] blender build"
    & $blender --background --factory-startup --python "tools/weapon_real/$Builder.py" 2>&1 | Select-String -Pattern 'Traceback|Error:|verts'
}
# Exclusive lock: the open handle is the lock, so a crashed holder releases it.
$lockPath = Join-Path $root ".godot_render.lock"
$lock = $null
$waited = 0
while ($null -eq $lock) {
    try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { if ($waited % 60 -eq 0) { "[$Key] waiting for Godot lock ($waited s)" }; Start-Sleep 10; $waited += 10 }
}
try {
    # Never overlap with a Godot process started outside this lock (editor, another tool).
    while (Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue) { "[$Key] another Godot is running; waiting"; Start-Sleep 15 }
    function Run([string[]]$a, [string]$name) {
        $out = "$env:TEMP\og_${Key}_$name.txt"
        $p = Start-Process -FilePath $godot -ArgumentList $a -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError "$out.err"
        $p.WaitForExit(1800000) | Out-Null
        Get-Content "$out.err" -ErrorAction SilentlyContinue | Select-String 'SCRIPT ERROR|Parse Error' | Select-Object -First 5
        Get-Content $out -ErrorAction SilentlyContinue | Select-String 'WEAPON|RESULT|FAIL' | Select-Object -First 10
    }
    "[$Key] godot import"
    Run @('--headless', '--path', '.', '--import') 'import'
    "[$Key] godot capture ($Tag)"
    Run @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', $Tag, '--only', $Key) 'capture'
    if ($WithBefore) {
        Run @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', 'before', '--only', $Key, '--assets-root', 'res://docs/weapon_realism_20261107/before_assets') 'before'
    }
} finally {
    $lock.Close()
}
"[$Key] sheet"
python tools/weapon_realism_sheet.py compare $Key
"[$Key] DONE"
