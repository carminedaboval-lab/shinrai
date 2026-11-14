@echo off
rem Start on the shop pavement, looking east past the diner towards the crossing.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\godot_locked.ps1" -Play -Out "%TEMP%\shinrai_wide_shop_row.log" -GodotArgs "--path . res://scenes/shinrai_map1_blockout.tscn -- --spawn=-384,-456,-90"
endlocal
