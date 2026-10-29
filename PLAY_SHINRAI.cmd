@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "SHINRAI_PROJECT=%~dp0."
if not exist "%SHINRAI_PROJECT%\project.godot" goto missing_project
set "SHINRAI_GODOT=%USERPROFILE%\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
if not exist "%SHINRAI_GODOT%" set "SHINRAI_GODOT=%SHINRAI_PROJECT%\..\..\ChatGPT\shinrai\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%SHINRAI_GODOT%" goto missing_engine
start "" /D "%SHINRAI_PROJECT%" "%SHINRAI_GODOT%" --path "%SHINRAI_PROJECT%"
if errorlevel 1 goto launch_failed
exit /b 0

:missing_project
echo ERROR: Place PLAY_SHINRAI.cmd beside Shinrai's project.godot.
goto failed

:missing_engine
echo ERROR: Godot 4.7.2 was not found on the OneDrive Desktop or in the sibling ChatGPT\shinrai\.tools folder.
goto failed

:launch_failed
echo ERROR: Godot could not be started.

:failed
pause
exit /b 1
