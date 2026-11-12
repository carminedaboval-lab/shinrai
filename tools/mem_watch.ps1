param([string]$Out, [int]$Seconds = 900, [int]$IntervalMs = 2000)
# Samples every Godot process (and only Godot): private bytes, working set, and the process's own
# GPU memory, plus system free RAM and commit for context. One CSV row per process per sample.
"wall,pid,priv_gb,ws_gb,free_ram_gb,commit_used_gb,commit_limit_gb,gpu_dedicated_gb,gpu_committed_gb" | Set-Content $Out
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    $os = Get-CimInstance Win32_OperatingSystem
    foreach ($p in @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue)) {
        $gd = 0.0; $gc = 0.0
        try {
            $c = Get-Counter -Counter "\GPU Process Memory(pid_$($p.Id)_*)\Dedicated Usage","\GPU Process Memory(pid_$($p.Id)_*)\Total Committed" -ErrorAction Stop
            foreach ($s in $c.CounterSamples) { if ($s.Path -like '*Dedicated Usage') { $gd += $s.CookedValue } else { $gc += $s.CookedValue } }
        } catch {}
        $p.Refresh()
        "{0},{1},{2:N3},{3:N3},{4:N2},{5:N2},{6:N2},{7:N3},{8:N3}" -f (Get-Date -Format HH:mm:ss), $p.Id, ($p.PrivateMemorySize64/1GB), ($p.WorkingSet64/1GB), ($os.FreePhysicalMemory/1MB), (($os.TotalVirtualMemorySize - $os.FreeVirtualMemory)/1MB), ($os.TotalVirtualMemorySize/1MB), ($gd/1GB), ($gc/1GB) | Add-Content $Out
    }
    Start-Sleep -Milliseconds $IntervalMs
}
