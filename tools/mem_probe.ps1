# Runs one Godot script through the project lock with the Godot-only memory sampler beside it,
# and prints the game's own peak memory (other apps are not counted).
#   powershell -File tools/mem_probe.ps1 -Tag name -OutDir <folder> -Script res://tests/x.gd [-ProbeArgs "..."] [-Extra "--fixed-fps 60"]
param([string]$Tag, [string]$OutDir, [string]$Script = "res://tests/probe_shader_warmup.gd", [string]$ProbeArgs = "", [string]$Extra = "", [int]$TimeoutSec = 900)
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
New-Item -ItemType Directory -Force $OutDir | Out-Null
$csv = Join-Path $OutDir "mem_$Tag.csv"
$log = Join-Path $OutDir "$Tag.txt"
$job = Start-Process powershell -ArgumentList "-NoProfile -File `"$PSScriptRoot\mem_watch.ps1`" -Out `"$csv`" -Seconds $TimeoutSec" -WindowStyle Hidden -PassThru
try {
    powershell -NoProfile -File "$PSScriptRoot\godot_locked.ps1" -Out $log -TimeoutSec $TimeoutSec -GodotArgs "--path . $Extra --script $Script -- $ProbeArgs" | Select-Object -Last 2
} finally {
    if (-not $job.HasExited) { Stop-Process -Id $job.Id -Force }
}
$rows = Import-Csv $csv | Where-Object { $_.priv_gb -ne '' }
if ($rows) {
    $peak = ($rows | ForEach-Object { [double]$_.priv_gb } | Measure-Object -Maximum).Maximum
    $gpu = ($rows | ForEach-Object { [double]$_.gpu_committed_gb } | Measure-Object -Maximum).Maximum
    "RESULT $Tag game_peak_gb=$peak game_gpu_committed_gb=$gpu samples=$($rows.Count)"
} else { "RESULT $Tag no samples" }
