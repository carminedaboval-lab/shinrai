@echo off
rem Start looking west towards the terrace and neighbourhood police office.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\godot_locked.ps1" -Play -Out "%TEMP%\shinrai_koban_lane_play.log" -GodotArgs "--path . res://scenes/shinrai_map1_blockout.tscn -- --spawn=48,412.25,90"
endlocal
