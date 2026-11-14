@echo off
rem Opens the Map 1 blockout with you standing on the trial homes street (kerbs, pavements,
rem asphalt, white line, drain grate, utility pole), looking east along it.
rem F3 = fly, Shift = fast, Esc = free the mouse.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\godot_locked.ps1" -Play -Out "%TEMP%\shinrai_trial_street_play.log" -GodotArgs "--path . res://scenes/shinrai_map1_blockout.tscn -- --spawn=99,448.2,-90"
endlocal
