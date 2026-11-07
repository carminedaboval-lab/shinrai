# Reimport changed assets, then render the fixed review cameras.
#   powershell -File tools/weapon_real/capture.ps1 -Only akane -Tag wip
param([string]$Only = "", [string]$Tag = "wip", [switch]$SkipImport)
$godot = "$env:USERPROFILE\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
$log = "$env:TEMP\weapon_real_capture.txt"
if (-not $SkipImport) {
    $p = Start-Process -FilePath $godot -ArgumentList '--headless', '--path', '.', '--import' -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\weapon_real_import.txt" -RedirectStandardError "$env:TEMP\weapon_real_import_err.txt"
    $p.WaitForExit(900000) | Out-Null
    Get-Content "$env:TEMP\weapon_real_import_err.txt" | Select-String -Pattern 'akane|weapon|ERROR' | Select-Object -First 15
}
$args2 = @('--path', '.', '--script', 'res://tests/weapon_realism_capture.gd', '--', '--tag', $Tag)
if ($Only) { $args2 += @('--only', $Only) }
$p = Start-Process -FilePath $godot -ArgumentList $args2 -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
$p.WaitForExit(900000) | Out-Null
Get-Content $log | Select-String -Pattern 'WEAPON'
Get-Content "$log.err" | Select-String -Pattern 'ERROR|SCRIPT' | Select-Object -First 15
