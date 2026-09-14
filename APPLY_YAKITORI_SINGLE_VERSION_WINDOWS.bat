@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "REPO=%CD%"
set "SHOP=%REPO%\assets\shinrai\buildings\yakitori_shop"
set "CURRENT=%SHOP%\artwork_replica_v5"
set "INPUTS=%CURRENT%\source_inputs"

if not exist "%REPO%\project.godot" (
  echo ERROR: Extract this package into the SHINRAI folder containing project.godot.
  pause
  exit /b 1
)

if not exist "%CURRENT%\ProjectShinrai_YakitoriShop_ArtworkReplica_v5.tscn" (
  echo ERROR: The current V5 Yakitori scene is missing. No cleanup was performed.
  pause
  exit /b 1
)

echo This will keep Artwork Replica V5 and remove the obsolete V2, V3, V4,
echo duplicated package folders, and Godot's generated import cache.
choice /C YN /N /M "Continue? [Y/N] "
if errorlevel 2 exit /b 0

if not exist "%INPUTS%" mkdir "%INPUTS%"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2.glb"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_AgedPlaster_BaseColor.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_AgedPlaster_NormalGL.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_AgedPlaster_ORM.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkCedar_BaseColor.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkCedar_NormalGL.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkCedar_ORM.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkRoof_BaseColor.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkRoof_NormalGL.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkRoof_ORM.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_ThresholdConcrete_BaseColor.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_ThresholdConcrete_NormalGL.png"
call :move_input "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_ThresholdConcrete_ORM.png"

call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2.tscn"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2.glb.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_AgedPlaster_BaseColor.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_AgedPlaster_NormalGL.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_AgedPlaster_ORM.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkCedar_BaseColor.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkCedar_NormalGL.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkCedar_ORM.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkRoof_BaseColor.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkRoof_NormalGL.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_DarkRoof_ORM.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_ThresholdConcrete_BaseColor.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_ThresholdConcrete_NormalGL.png.import"
call :delete_shop_file "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_ThresholdConcrete_ORM.png.import"

if exist "%SHOP%\artwork_replica_v3" rmdir /S /Q "%SHOP%\artwork_replica_v3"
if exist "%SHOP%\artwork_replica_v4" rmdir /S /Q "%SHOP%\artwork_replica_v4"
if exist "%REPO%\assets\assets" rmdir /S /Q "%REPO%\assets\assets"
if exist "%REPO%\scripts\assets" rmdir /S /Q "%REPO%\scripts\assets"
if exist "%REPO%\scripts\scripts" rmdir /S /Q "%REPO%\scripts\scripts"
if exist "%REPO%\assets\scenes\main.tscn" del /F /Q "%REPO%\assets\scenes\main.tscn"
if exist "%REPO%\scripts\scenes\main.tscn" del /F /Q "%REPO%\scripts\scenes\main.tscn"
if exist "%REPO%\assets\town_main.gd" del /F /Q "%REPO%\assets\town_main.gd"
if exist "%REPO%\INSTALL_YAKITORI_ARTWORK_REPLICA_V4.md" del /F /Q "%REPO%\INSTALL_YAKITORI_ARTWORK_REPLICA_V4.md"
if exist "%REPO%\Shinrai_v10_26w_Physical_Curb_Drain_Test_FULL_GODOT_PROJECT" rmdir /S /Q "%REPO%\Shinrai_v10_26w_Physical_Curb_Drain_Test_FULL_GODOT_PROJECT"
if exist "%REPO%\.godot" rmdir /S /Q "%REPO%\.godot"

echo.
echo CLEANUP COMPLETE: Artwork Replica V5 is now the only Yakitori shop scene.
echo Reopen Godot and allow the project to import its assets.
pause
exit /b 0

:move_input
if exist "%SHOP%\%~1" move /Y "%SHOP%\%~1" "%INPUTS%\%~1" >nul
exit /b 0

:delete_shop_file
if exist "%SHOP%\%~1" del /F /Q "%SHOP%\%~1"
exit /b 0
