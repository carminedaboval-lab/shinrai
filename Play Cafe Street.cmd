@echo off
rem Starts on the residential street facing Kissa Aoi's coffee window.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\godot_locked.ps1" -Play -Out "%TEMP%\shinrai_cafe_street.log" -GodotArgs "--path . res://scenes/shinrai_map1_blockout.tscn -- --spawn=228.2,357.7,-99"
endlocal
