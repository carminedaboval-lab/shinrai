# Runs the Map 1 checks that are gates - the ones that must pass - and prints one summary.
#   powershell -File tools/ai/run_map1_checks.ps1
#   powershell -File tools/ai/run_map1_checks.ps1 -Fast     (only the ones that need no world)
#
# They were written one at a time over a long session and were only ever run by remembering
# their filenames, which is a suite nobody inherits. Everything here is headless, goes through
# the shared Godot lock one at a time, and exits non-zero if any gate fails.
#
# NOT run here, on purpose:
#   tests/probe_map1_world.gd        the big one; it has its own runner, run_map1_world_probe.ps1
#   tests/probe_look_build_time.gd   a measurement, not a gate: prints a distribution
#   tests/probe_house_both_ways.gd   a diagnostic; compares at half a millimetre, so it reports
#                                    the float-level differences the world probe's tolerance allows
#   tests/probe_sight_change.gd      a reproduction attempt for an open question, not a rule
#   tests/probe_find_gates.gd        a finder: prints where the gates with leaves are
#   tests/probe_crown_poles.gd       a staging comparison for a change that is not made yet,
#                                    and which currently FAILS by design on the normals question
param([switch]$Fast)
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root

# name, script, what it answers, needs a built world (slow)
$checks = @(
    @{ n = "matcher";     s = "tests/probe_matcher.gd";             w = $false; q = "the triangle matcher against hand-known answers" },
    @{ n = "kerb marks";  s = "tests/probe_map1_kerb_marks.gd";     w = $false; q = "the kerb height marking and the corner tones" },
    @{ n = "sign shapes"; s = "tests/probe_sign_shape.gd";          w = $false; q = "every sign text cuts whole, and what a first cut costs" },
    @{ n = "tree cost";   s = "tests/probe_tree_cost.gd";           w = $false; q = "tree triangles, and that no face points inward" },
    @{ n = "trial street";s = "tests/probe_map1_street.gd";         w = $true;  q = "the trial kerb, gutter, footway and its gate" },
    @{ n = "gate clear";  s = "tests/probe_gate_clear.gd";          w = $true;  q = "gate leaves hang on their pillars and foul nothing" },
    @{ n = "circle road"; s = "tests/probe_circle_asphalt.gd";      w = $true;  q = "the turning circle's surface is actually built" },
    @{ n = "sign warm";   s = "tests/probe_sign_warm_cost.gd";      w = $true;  q = "every sign the map draws is cut before play" }
)

$failed = 0
$ran = 0
foreach ($check in $checks) {
    if ($Fast -and $check.w) { continue }
    $out = Join-Path $env:TEMP ("map1_check_" + ($check.n -replace '\s','_') + ".txt")
    if (Test-Path "$out.err") { Remove-Item "$out.err" }
    powershell -NoProfile -File tools\godot_locked.ps1 -Out $out -TimeoutSec 900 -GodotArgs "--headless --path . --script res://$($check.s)" | Out-Null
    $ran += 1
    $done = @(Select-String -Path $out -Pattern "_DONE" | ForEach-Object { $_.Line })
    $bad = @(Select-String -Path $out -Pattern "_FAIL" | ForEach-Object { $_.Line })
    # A probe that printed no DONE line did not finish, which is a failure however quiet.
    if ($done.Count -eq 0) {
        $failed += 1
        "FAIL  {0,-13} did not finish - no DONE line ({1})" -f $check.n, $check.s
        continue
    }
    if ($bad.Count -gt 0) {
        $failed += 1
        "FAIL  {0,-13} {1}" -f $check.n, $done[-1]
        foreach ($line in $bad) { "        " + $line.Trim() }
    } else {
        "ok    {0,-13} {1}" -f $check.n, $done[-1]
    }
}
""
"MAP1_CHECKS ran=$ran failed=$failed" + $(if ($Fast) { " (fast: the ones needing no world were run)" } else { "" })
if ($failed -gt 0) { exit 1 }
