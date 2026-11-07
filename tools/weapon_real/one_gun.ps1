# Rebuild one gun, import, render the shared before/after cameras, make its sheet.
#   powershell -File tools/weapon_real/one_gun.ps1 -Key akane -Builder akane_glock17
param([string]$Key, [string]$Builder)
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$godot = "$env:USERPROFILE\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
& $blender --background --factory-startup --python "tools/weapon_real/$Builder.py" 2>&1 | Select-String -Pattern 'Traceback|Error:|verts'
function Run([string[]]$a) {
    $p = Start-Process -FilePath $godot -ArgumentList $a -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\og.txt" -RedirectStandardError "$env:TEMP\og_err.txt"
    $p.WaitForExit(900000) | Out-Null
    Get-Content "$env:TEMP\og_err.txt" | Select-String 'SCRIPT ERROR' | Select-Object -First 5
}
Run @('--headless', '--path', '.', '--import')
Run @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', 'after', '--only', $Key)
Run @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', 'before', '--only', $Key, '--assets-root', 'res://docs/weapon_realism_20261107/before_assets')
python tools/weapon_realism_sheet.py compare $Key
