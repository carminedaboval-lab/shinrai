@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\godot_locked.ps1" -Play -Out "%TEMP%\shinrai_upstairs_cafe.log" -GodotArgs "--path . res://scenes/shinrai_map1_blockout.tscn -- --spawn=176.55,492.8,180"
endlocal
