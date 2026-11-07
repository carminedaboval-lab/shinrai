# Same-camera before/after renders for the real-counterpart weapon rebuilds.
# The archived ("before") weapon folders are rendered from a temporary copy
# inside docs/ and are never swapped back into assets/.
param([string]$Backup, [string[]]$Weapons = @('akane', 'shigure', 'kite', 'raiden_r56', 'tobikage', 'hayate', 'yuzuru'))
$ErrorActionPreference = 'Stop'
$godot = "$env:USERPROFILE\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$out = 'docs/weapon_realism_20261107'
$arch = "$out/before_assets"
$renders = "$out/renders"

function Run-Godot([string[]]$a, [string]$log) {
    $p = Start-Process -FilePath $godot -ArgumentList $a -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $p.WaitForExit(1500000) | Out-Null
}

# 1. Archive copy of the old weapon folders with their res:// paths rewritten.
foreach ($w in $Weapons) {
    $dst = "$arch/$w"
    New-Item -ItemType Directory -Force $dst | Out-Null
    Get-ChildItem "$Backup/$w" -File | Where-Object { $_.Extension -notin '.import', '.uid' } | ForEach-Object {
        Copy-Item $_.FullName "$dst/$($_.Name)" -Force
    }
    Get-ChildItem $dst -Filter *.tscn | ForEach-Object {
        $t = [IO.File]::ReadAllText($_.FullName).Replace("res://assets/weapons/$w/", "res://$arch/$w/")
        [IO.File]::WriteAllText($_.FullName, $t)
    }
    if (-not (Test-Path "$renders/${w}_camera_before.json")) { Copy-Item "$renders/${w}_camera.json" "$renders/${w}_camera_before.json" }
}
Run-Godot @('--headless', '--path', '.', '--import') "$env:TEMP\ba_import.txt"

# 2. Bounds of the new models, then a camera that frames old and new alike.
Run-Godot @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', 'probe', '--only', ($Weapons -join ',')) "$env:TEMP\ba_probe.txt"
$live = @{}
Get-Content "$env:TEMP\ba_probe.txt" | Where-Object { $_ -like 'LIVE *' } | ForEach-Object {
    $parts = $_.Split(' ', 3)
    $live[$parts[1]] = $parts[2] | ConvertFrom-Json
}
foreach ($w in $Weapons) {
    $b = Get-Content "$renders/${w}_camera_before.json" -Raw | ConvertFrom-Json
    $a = $live[$w]
    $lo = 0..2 | ForEach-Object { [Math]::Min($b[$_], $a[$_]) }
    $hi = 0..2 | ForEach-Object { [Math]::Max($b[$_] + $b[$_ + 3], $a[$_] + $a[$_ + 3]) }
    $u = @($lo[0], $lo[1], $lo[2], ($hi[0] - $lo[0]), ($hi[1] - $lo[1]), ($hi[2] - $lo[2]))
    [IO.File]::WriteAllText("$renders/${w}_camera.json", ($u | ConvertTo-Json -Compress))
}

# 3. Final renders through the shared cameras.
Run-Godot @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', 'after', '--only', ($Weapons -join ',')) "$env:TEMP\ba_after.txt"
Run-Godot @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', 'before', '--only', ($Weapons -join ','), '--assets-root', "res://$arch") "$env:TEMP\ba_before.txt"
Get-Content "$env:TEMP\ba_before.txt", "$env:TEMP\ba_after.txt" | Select-String 'WEAPON'
Get-Content "$env:TEMP\ba_before.txt.err", "$env:TEMP\ba_after.txt.err" | Select-String 'ERROR|SCRIPT' | Select-Object -First 20
