# Runs the robot and recharge station probe in the test yard and prints its pass / fail lines.
#   powershell -File tools/ai/run_robot_probe.ps1
#   powershell -File tools/ai/run_robot_probe.ps1 -Only approach,strip -Tag after
# Headless, no park. Raw output goes to reports/robots/probe_robots_<tag>.txt.
# The last check is made here: the run must not have printed a single SCRIPT ERROR.
param([string]$Only = "", [string]$Tag = "result")
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root
New-Item -ItemType Directory -Force "reports\robots" | Out-Null
$out = "reports\robots\probe_robots_$Tag.txt"
$extra = if ($Only) { " -- --only=$Only" } else { "" }
powershell -NoProfile -File tools\godot_locked.ps1 -Out $out -TimeoutSec 900 -GodotArgs "--headless --path . --fixed-fps 60 --script res://tests/probe_robots.gd$extra" | Out-Null
$lines = @(Select-String -Path $out -Pattern "^ROBOT_" | ForEach-Object { $_.Line })
$lines | Where-Object { $_ -notmatch "^ROBOT_DONE" }
$errors = @()
foreach ($log in @($out, "$out.err")) {
    if (Test-Path $log) { $errors += @(Select-String -Path $log -Pattern "SCRIPT ERROR" | ForEach-Object { $_.Line }) }
}
$passed = 0; $failed = 0; $finished = $false
foreach ($line in $lines) {
    if ($line -match "^ROBOT_DONE passed=(\d+) failed=(\d+)") { $passed = [int]$Matches[1]; $failed = [int]$Matches[2]; $finished = $true }
}
if (-not $finished) { "ROBOT_FAIL run: the probe did not finish (no ROBOT_DONE line)"; $failed++ }
if ($errors.Count -eq 0) { "ROBOT_PASS errors: nothing errored: no SCRIPT ERROR in the output"; $passed++ }
else { "ROBOT_FAIL errors: $($errors.Count) SCRIPT ERROR line(s) in the output"; $failed++ }
"ROBOT_DONE passed=$passed failed=$failed"
if ((Test-Path "$out.err") -and (Get-Item "$out.err").Length -gt 0) {
    "errors:"; Get-Content "$out.err" | Select-Object -First 30 | ForEach-Object { "  " + $_ }
}
