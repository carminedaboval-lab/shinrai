@echo off
setlocal
set "P=%~dp0."
set "G=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
if exist "%P%\startup_profile_events.log" del "%P%\startup_profile_events.log"
start "" /D "%P%" "%G%" --path "%P%" -- --profile-startup
