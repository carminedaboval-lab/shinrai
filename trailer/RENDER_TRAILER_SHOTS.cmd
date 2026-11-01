@echo off
setlocal EnableExtensions
rem Renders the engine shots for the showcase trailer.
rem   RENDER_TRAILER_SHOTS.cmd                -> free-camera stills only (fast framing check)
rem   RENDER_TRAILER_SHOTS.cmd clips          -> free-camera stills + every frame as 1080p JPEG, then clips\*.mp4
rem   RENDER_TRAILER_SHOTS.cmd staged         -> HQ menu stills, HUD plates, first-person staged stills
rem   RENDER_TRAILER_SHOTS.cmd staged clips   -> the same with every frame dumped, then clips\*.mp4
set "PROJECT=%~dp0.."
set "GODOT=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (echo Godot 4.7.2 not found at %GODOT% & exit /b 1)
set "OUT=%APPDATA%\Godot\app_userdata\Shinrai\trailer"
if not exist "%OUT%" mkdir "%OUT%"

if /I "%~1"=="staged" (
	set "FRAMES="
	if /I "%~2"=="clips" set "FRAMES=--frames"
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_staged_capture.gd --fixed-fps 30 -- --hq
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_staged_capture.gd --fixed-fps 30 -- --plates
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_staged_capture.gd --fixed-fps 30 -- --shots %FRAMES%
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_staged_capture.gd --fixed-fps 30 -- --shots --night %FRAMES%
	if /I "%~2"=="clips" python "%~dp0cut_trailer_shots.py" --delete-frames
) else if /I "%~1"=="clips" (
	if exist "%OUT%\frames" rmdir /S /Q "%OUT%\frames"
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_capture.gd --fixed-fps 30 -- --frames
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_capture.gd --fixed-fps 30 -- --frames --night
	python "%~dp0cut_trailer_shots.py" --delete-frames
) else (
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_capture.gd
	start "" /WAIT "%GODOT%" --path "%PROJECT%" --script res://tests/trailer_capture.gd -- --night
)
echo Output: %OUT%
