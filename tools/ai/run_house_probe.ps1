# Runs the house probe in the test yard and prints its pass / fail lines.
#   powershell -File tools/ai/run_house_probe.ps1
#   powershell -File tools/ai/run_house_probe.ps1 -Only window_shot,locked_crowbar -Tag after
# Headless, no park. Raw output goes to reports/interiors/probe_house_<tag>.txt.
# The last check is made here: the run must not have printed a single SCRIPT ERROR.
param([string]$Only = "", [string]$Tag = "result")
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root
New-Item -ItemType Directory -Force "reports\interiors" | Out-Null
$out = "reports\interiors\probe_house_$Tag.txt"
$extra = if ($Only) { " -- --only=$Only" } else { "" }
powershell -NoProfile -File tools\godot_locked.ps1 -Out $out -TimeoutSec 900 -GodotArgs "--headless --path . --fixed-fps 60 --script res://tests/probe_house.gd$extra" | Out-Null
$lines = @(Select-String -Path $out -Pattern "^HOUSE_" | ForEach-Object { $_.Line })
$lines | Where-Object { $_ -notmatch "^HOUSE_DONE" }
$errors = @()
foreach ($log in @($out, "$out.err")) {
    if (Test-Path $log) { $errors += @(Select-String -Path $log -Pattern "SCRIPT ERROR" | ForEach-Object { $_.Line }) }
}
$passed = 0; $failed = 0; $finished = $false
foreach ($line in $lines) {
    if ($line -match "^HOUSE_DONE passed=(\d+) failed=(\d+)") { $passed = [int]$Matches[1]; $failed = [int]$Matches[2]; $finished = $true }
}
if (-not $finished) { "HOUSE_FAIL run: the probe did not finish (no HOUSE_DONE line)"; $failed++ }
if ($errors.Count -eq 0) { "HOUSE_PASS errors: nothing errored: no SCRIPT ERROR in the output"; $passed++ }
else { "HOUSE_FAIL errors: $($errors.Count) SCRIPT ERROR line(s) in the output"; $failed++ }
"HOUSE_DONE passed=$passed failed=$failed"
if ((Test-Path "$out.err") -and (Get-Item "$out.err").Length -gt 0) {
    "errors:"; Get-Content "$out.err" | Select-Object -First 30 | ForEach-Object { "  " + $_ }
}
