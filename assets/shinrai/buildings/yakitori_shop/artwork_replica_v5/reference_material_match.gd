extends Node3D

# The artwork sheet was rendered in a dark studio, while the playable town uses
# a brighter WorldEnvironment. Keep the authored PBR textures and compensate
# their material response locally so the building matches the reference without
# changing the lighting or materials used by the rest of the map.
const PLASTER_EXPOSURE_TINT := Color(0.43, 0.41, 0.38, 1.0)
const STONE_EXPOSURE_TINT := Color(0.36, 0.34, 0.31, 1.0)
const INTERIOR_FLOOR_TINT := Color(0.45, 0.38, 0.31, 1.0)
const ROOF_EXPOSURE_TINT := Color(0.55, 0.55, 0.58, 1.0)
const EDGE_METAL_TINT := Color(0.42, 0.42, 0.46, 1.0)


func _ready() -> void:
	var corrected_count: int = 0
	if _calibrate_mesh(
		"SM_YakitoriShop_ContinuousArtworkPlaster",
		PLASTER_EXPOSURE_TINT,
		0.88,
		0.12
	):
		corrected_count += 1
	if _calibrate_mesh(
		"SM_YakitoriShop_StoneThreshold",
		STONE_EXPOSURE_TINT,
		0.84,
		0.12
	):
		corrected_count += 1
	if _calibrate_mesh(
		"SM_YakitoriShop_InteriorPlaceholder",
		INTERIOR_FLOOR_TINT,
		0.94,
		0.08
	):
		corrected_count += 1
	if _calibrate_mesh(
		"SM_YakitoriShop_MatteRoofSurface",
		ROOF_EXPOSURE_TINT,
		0.92,
		0.10
	):
		corrected_count += 1
	if _calibrate_mesh(
		"SM_YakitoriShop_ArchitecturalMetal",
		EDGE_METAL_TINT,
		0.56,
		0.20,
		0.86
	):
		corrected_count += 1

	set_meta("reference_materials_calibrated", corrected_count == 5)
	if corrected_count != 5:
		push_warning(
			"Yakitori reference match found %d of 5 expected material meshes." %
			corrected_count
		)


func _calibrate_mesh(
	mesh_name: String,
	exposure_tint: Color,
	roughness_value: float,
	specular_value: float,
	metallic_value: float = -1.0
) -> bool:
	var target_mesh: MeshInstance3D = find_child(
		mesh_name, true, false
	) as MeshInstance3D
	if target_mesh == null:
		return false

	var source_material: StandardMaterial3D = target_mesh.get_active_material(
		0
	) as StandardMaterial3D
	if source_material == null:
		return false

	var material: StandardMaterial3D = source_material.duplicate(
		true
	) as StandardMaterial3D
	if material == null:
		return false

	material.resource_local_to_scene = true
	var source_color: Color = material.albedo_color
	material.albedo_color = Color(
		source_color.r * exposure_tint.r,
		source_color.g * exposure_tint.g,
		source_color.b * exposure_tint.b,
		source_color.a
	)
	material.roughness = roughness_value
	material.metallic_specular = specular_value
	if metallic_value >= 0.0:
		material.metallic = metallic_value
	target_mesh.material_override = material
	return true
