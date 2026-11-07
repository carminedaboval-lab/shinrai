<#
.EXAMPLE
./tools/render_midori_biomes.ps1 -OutputDirectory D:/captures/coppice-01 -Only north_coppice -Views north_coppice,north_coppice_deep,north_coppice_west
.EXAMPLE
./tools/render_midori_biomes.ps1 -OutputDirectory D:/captures/off-01 -Off
.EXAMPLE
./tools/render_midori_biomes.ps1 -OutputDirectory D:/captures/paired-01 -Paired -Views north_coppice,north_coppice_deep,north_coppice_west
#>
[CmdletBinding()]
param(
    [string]$Godot = (Join-Path $env:USERPROFILE 'OneDrive/Desktop/Godot_v4.7.2-stable_win64.exe'),
    [string]$ProjectPath = (Join-Path $PSScriptRoot '..'),
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidatePattern('^[a-z0-9_]+(,[a-z0-9_]+)*$')][string[]]$Only = @(),
    [ValidatePattern('^[a-z0-9_]+(,[a-z0-9_]+)*$')][string[]]$Views = @(),
    [switch]$Off,
    [switch]$Paired
)
$ErrorActionPreference = 'Stop'
$builders = @($Only | ForEach-Object { $_ -split ',' })
$cameras = @($Views | ForEach-Object { $_ -split ',' })
if ($Paired -and $Off) { throw '-Paired runs both phases and cannot be combined with -Off.' }
if ($Off -and $builders.Count) { throw '-Off and -Only cannot be combined.' }

function Assert-SameNames([string[]]$Expected, [string[]]$Actual, [string]$Label) {
    $sortedExpected = ($Expected | Sort-Object) -join ','
    $sortedActual = ($Actual | Sort-Object) -join ','
    if ($Expected.Count -ne $Actual.Count -or $sortedExpected -cne $sortedActual) {
        throw "$Label mismatch. Expected [$($Expected -join ',')], received [$($Actual -join ',')]."
    }
}
function Confirm-CaptureImages {
    param([string]$ImageDirectory, [string]$LogPath, [string]$ShotMarker, [bool]$ExpectOff,
          [string[]]$ExpectedBuilders, [string[]]$RequestedViews)
    $record = Get-Content -LiteralPath (Join-Path $ImageDirectory 'capture.json') -Raw | ConvertFrom-Json
    if ($record.off -isnot [bool] -or $record.off -ne $ExpectOff) { throw 'Manifest has the wrong biomes-off setting.' }
    Assert-SameNames $ExpectedBuilders $record.only 'Captured builders'
    $expected = @($record.requested_views)
    if (!$expected.Count -or @($expected | Where-Object { $_ -cnotmatch '^[a-z0-9_]+$' }).Count) { throw 'Invalid camera plan in capture.json.' }
    if ($RequestedViews.Count) { Assert-SameNames $RequestedViews $expected 'Requested cameras' }
    Assert-SameNames $expected @($record.views.PSObject.Properties.Name) 'Manifest views'
    $shots = @(Select-String -LiteralPath $LogPath -CaseSensitive -Pattern ("^" + $ShotMarker + ' ([a-z0-9_]+) steady_fps=[0-9]+(?:\.[0-9]+)?$') | ForEach-Object { $_.Matches[0].Groups[1].Value })
    Assert-SameNames $expected $shots 'SHOT markers'
    Assert-SameNames $expected @((Get-ChildItem -LiteralPath $ImageDirectory -File -Filter '*.png').BaseName) 'Saved PNGs'

    Add-Type -AssemblyName System.Drawing
    foreach ($name in $expected) {
        $row = $record.views.$name
        if ($row.view -cne $name -or $row.png_saved -ne $true -or $row.visible.median_ms -le 0) { throw "Invalid capture record for $name" }
        $stream = [IO.File]::OpenRead((Join-Path $ImageDirectory "$name.png"))
        try {
            $image = [Drawing.Image]::FromStream($stream, $false, $true)
            try {
                if ($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or $image.Width -ne 1920 -or $image.Height -ne 1080 -or $row.width -ne $image.Width -or $row.height -ne $image.Height) { throw "Invalid PNG or dimensions for $name" }
            } finally { $image.Dispose() }
        } finally { $stream.Dispose() }
    }
    return $expected
}

Assert-SameNames @($builders | Sort-Object -Unique) $builders 'Builder selection'
Assert-SameNames @($cameras | Sort-Object -Unique) $cameras 'Camera selection'

$destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$project = (Get-Item -LiteralPath $ProjectPath).FullName
$executable = (Get-Item -LiteralPath $Godot).FullName
$driverName = if ($Paired) { 'biome_paired_capture.gd' } else { 'biome_capture.gd' }
$driver = (Get-Item -LiteralPath (Join-Path $PSScriptRoot $driverName)).FullName
if (!(Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw "Missing project.godot in $project" }
if (Test-Path -LiteralPath $destination) { throw "Output directory already exists. Choose a new path: $destination" }

# Cooperating launchers share the mutex. The process check also catches editors and direct CLI launches.
$guard = [Threading.Mutex]::new($false, 'Local\ShinraiMidoriGpuCapture')
$held = $false
try {
    try { $held = $guard.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
    if (!$held) { throw 'Another Midori capture owns the GPU capture lock.' }
    $running = @(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue)
    if ($running.Count) { throw "Godot is already running (PID $($running.Id -join ', ')). Finish it before starting this capture." }

    $null = New-Item -ItemType Directory -Path $destination
    $stdout = Join-Path $destination 'stdout.txt'
    $stderr = Join-Path $destination 'stderr.txt'
    $engineLog = Join-Path $destination 'engine.log'
    $arguments = @('--path', "`"$project`"", '--disable-vsync', '--script', "`"$driver`"", '--log-file', "`"$engineLog`"")
    $variables = @{
        ROUND4_CAPTURE_DIR = $destination
        BIOME_VIEWS = $cameras -join ','
        MIDORI_BIOMES_ONLY = $builders -join ','
        MIDORI_BIOMES_OFF = [string][int]$Off.IsPresent
    }
    $saved = @{}
    try {
        foreach ($key in $variables.Keys) {
            $saved[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $variables[$key])
        }
        $process = Start-Process -FilePath $executable -ArgumentList $arguments -WorkingDirectory $project -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        # Windows PowerShell 5 releases the child handle on exit unless it is opened here.
        $null = $process.Handle
    } finally {
        foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key]) }
    }
    Write-Output "Capturing with Godot PID $($process.Id). Logs and images: $destination"
    try {
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "Godot exited with $($process.ExitCode). See $stderr" }
    } finally { $process.Dispose() }

    $failures = Select-String -LiteralPath $stdout,$stderr -Pattern '^(SCRIPT ERROR|SHADER ERROR|ROUND4_FAILED|CrashHandlerException)|Vulkan fence \(VkResult error -4\)' | Select-Object -First 1
    if ($failures) { throw "Godot reported a capture error: $($failures.Line)" }
    if (@(Select-String -LiteralPath $stdout -CaseSensitive -Pattern '^BUILD_DONE$').Count -ne 1) { throw "Missing or repeated BUILD_DONE in $stdout" }
    $expected = @(Confirm-CaptureImages -ImageDirectory $destination -LogPath $stdout -ShotMarker 'SHOT' -ExpectOff $Off.IsPresent -ExpectedBuilders $builders -RequestedViews $cameras)
    if ($Paired) {
        if (@(Select-String -LiteralPath $stdout -CaseSensitive -Pattern '^PAIRED_CONTROL_DONE$').Count -ne 1) { throw "Missing or repeated PAIRED_CONTROL_DONE in $stdout" }
        $controlDirectory = Join-Path $destination 'off'
        $control = @(Confirm-CaptureImages -ImageDirectory $controlDirectory -LogPath $stdout -ShotMarker 'CONTROL_SHOT' -ExpectOff $true -ExpectedBuilders @() -RequestedViews $expected)
        Write-Output "Verified $($control.Count) OFF controls in $controlDirectory"
    }
    Write-Output "Verified $($expected.Count) camera captures in $destination"
} finally {
    if ($held) { $guard.ReleaseMutex() }
    $guard.Dispose()
}
