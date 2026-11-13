# Runs the scav AI probe several times in the test yard and prints the averages.
#   powershell -File tools/ai/run_scav_probe.ps1 -Runs 5 -Tag after
#   powershell -File tools/ai/run_scav_probe.ps1 -Runs 5 -Tag after -Only open_fight,gone
# Headless, no park, about 20 s per run. Raw output goes to reports/ai/<tag>_runN.txt.
# A value of -1 in the probe means "never happened"; those are counted, not averaged.
param([int]$Runs = 5, [string]$Tag = "run", [string]$Only = "")
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root
New-Item -ItemType Directory -Force "reports\ai" | Out-Null
$results = @{}
for ($i = 1; $i -le $Runs; $i++) {
    $out = "reports\ai\${Tag}_run$i.txt"
    $extra = if ($Only) { " --only=$Only" } else { "" }
    powershell -NoProfile -File tools\godot_locked.ps1 -Out $out -TimeoutSec 600 -GodotArgs "--headless --path . --fixed-fps 60 --script res://tests/probe_scav_ai.gd --$extra" | Out-Null
    if ((Test-Path "$out.err") -and (Select-String -Path "$out.err" -Pattern "SCRIPT ERROR" -Quiet)) {
        "run $i had script errors:"; Select-String -Path "$out.err" -Pattern "SCRIPT ERROR|at:" | Select-Object -First 6 | ForEach-Object { "  " + $_.Line }
    }
    foreach ($line in (Select-String -Path $out -Pattern "^AI_RESULT " | ForEach-Object { $_.Line })) {
        $data = $line.Substring(10) | ConvertFrom-Json
        if (-not $results.ContainsKey($data.scenario)) { $results[$data.scenario] = @() }
        $results[$data.scenario] += $data
    }
}
function Add-Value($table, $key, $value) {
    if (-not $table.ContainsKey($key)) { $table[$key] = New-Object System.Collections.ArrayList }
    [void]$table[$key].Add($value)
}
foreach ($scenario in ($results.Keys | Sort-Object)) {
    "== $scenario ($($results[$scenario].Count) runs)"
    $values = @{}
    foreach ($run in $results[$scenario]) {
        foreach ($property in $run.PSObject.Properties) {
            $v = $property.Value
            if ($v -is [bool]) { Add-Value $values $property.Name ([int]$v) }
            elseif ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]) { Add-Value $values $property.Name ([double]$v) }
            elseif ($v -is [System.Management.Automation.PSCustomObject] -and $property.Name -in @("rounds", "exposed_share")) {
                foreach ($inner in $v.PSObject.Properties) { Add-Value $values "$($property.Name).$($inner.Name)" ([double]$inner.Value) }
            }
        }
    }
    foreach ($key in ($values.Keys | Sort-Object)) {
        $all = $values[$key]
        $real = @($all | Where-Object { $_ -ne -1 })
        $never = $all.Count - $real.Count
        if ($real.Count -eq 0) { "   {0,-34} never" -f $key; continue }
        $mean = ($real | Measure-Object -Average).Average
        $min = ($real | Measure-Object -Minimum).Minimum
        $max = ($real | Measure-Object -Maximum).Maximum
        $note = if ($never -gt 0) { "   (never in $never of $($all.Count))" } else { "" }
        "   {0,-34} {1,7:N2}   range {2:N2} to {3:N2}{4}" -f $key, $mean, $min, $max, $note
    }
}
