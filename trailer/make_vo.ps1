# Placeholder narration for the showcase assembly cut, one WAV per beat.
# Uses the Windows SAPI voice so the edit can be timed before a real VO session.
#   powershell -ExecutionPolicy Bypass -File trailer\make_vo.ps1 [-Voice "Microsoft Zira Desktop"] [-Rate 0]
param([string]$Voice = "Microsoft David Desktop", [int]$Rate = 0)
$dir = Join-Path $PSScriptRoot "build\vo"
New-Item -ItemType Directory -Force $dir | Out-Null
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice($Voice)
$s.Rate = $Rate
$lines = [ordered]@{
"b0"  = "New Tokyo. Twenty fifty. Eight months ago, the city's A.I. stopped taking orders. It kept the lights on, the trains running, and the police drones patrolling. It just stopped asking anyone what they wanted. Midori Park was the first place it sealed. It has been open for business ever since."
"b1"  = "Shinrai is a twelve-player extraction shooter. You drop into the park as a squad of four. Three telemetry relays are hidden on the lamp network. Recover one, and you've earned your ticket out. Recover all three, and the contract pays. Everything you carry out is yours. Everything you carry in, you can lose."
"b2"  = "Four hundred and forty metres of park. A lake, seven islands, the groves, the pitches, the plaza under the torii. By day, the gates stand open. By night, they're chained, the main gate is down, and the only ways in are the holes someone else cut before you."
"b3"  = "Movement has weight. You sprint, and you feel it when you stop. You mantle with your weapon up, and you can shoot before your feet are down. Lean around a corner before you commit to it. The anchor puts you on any roof in the park, and you can fight on the way up. Jump, and your sights still work. Fast, but never floaty."
"b3b" = "Nearly every building in and around the park opens. Shops, the clubhouse, the pavilion, the apartments over the street. Every floor is a route, a loot run, or a place to hold."
"b4"  = "The scav crews who live in the park now are not targets. They watch the approaches, they flank, they pull back when it goes wrong, and they fight the drones too. The drones answer whoever shoots first. Use that. Recover the relay while the park argues with itself."
"b5"  = "And every other squad in the park wants the same three relays. Three squads per raid. Kill a carrier, and their cargo is yours. A raid can run two hours. You can leave after ten minutes. The question is whether you can afford to."
"b5b" = "Extraction is the Line. One way out, every ten minutes, twelve stops around and outside the city. Two minutes before each departure, some of the city's screens will show you where you are, and where the nearest platform is. Some. And everyone else can read them too. Every platform is a meeting place, and nobody on it wants to share the carriage. Miss the train, and you have ten more minutes in the park."
"b6"  = "Sell what you extract. Buy cargo, buy medical. Everything else, you find out there. And the better it is, the harder it is to bring home. Your stash survives. Your kit does not."
"b7"  = "Shinrai. Wishlist now."
}
foreach ($k in $lines.Keys) {
	$s.SetOutputToWaveFile((Join-Path $dir "$k.wav"))
	$s.Speak($lines[$k])
	$s.SetOutputToNull()
}
$s.Dispose()
Write-Output "VO written to $dir"
