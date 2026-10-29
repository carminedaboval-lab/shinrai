@echo off
setlocal
set "SHINRAI_PROJECT=%~dp0."
set "SHINRAI_GODOT=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
if not exist "%SHINRAI_GODOT%" set "SHINRAI_GODOT=%SHINRAI_PROJECT%\..\..\ChatGPT\shinrai\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
start "" /D "%SHINRAI_PROJECT%" "%SHINRAI_GODOT%" --path "%SHINRAI_PROJECT%" res://scenes/creator/creator_bootstrap.tscn
