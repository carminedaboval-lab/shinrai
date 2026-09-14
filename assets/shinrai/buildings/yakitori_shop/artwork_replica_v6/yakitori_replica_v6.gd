extends Node3D

# Final building-only presentation pass for the supplied artwork reference.
# The authored V5 GLB remains the real mesh source. This script replaces only
# the combined metal edge/interior placeholder groups with clean architectural
# pieces and calibrates the existing PBR materials for the playable environment.
const ROOF_PITCH_RAD: float = -0.0610865238
const CANOPY_PITCH_RAD: float = -0.0349065850

const PLASTER_TINT := Color(0.43, 0.41, 0.38, 1.0)
const STONE_TINT := Color(0.36, 0.34, 0.31, 1.0)
const EXTERIOR_WOOD_TINT := Color(0.68, 0.62, 0.56, 1.0)
const CANOPY_WOOD_TINT := Color(0.78, 0.70, 0.62, 1.0)
const UPPER_WOOD_TINT := Color(0.68, 0.62, 0.56, 1.0)
const FRAME_WOOD_TINT := Color(0.64, 0.58, 0.52, 1.0)
const GLASS_TINT := Color(0.58, 0.53, 0.46, 1.0)
const INTERIOR_TINT := Color(0.45, 0.38, 0.31, 1.0)
const ROOF_TINT := Color(0.55, 0.55, 0.58, 1.0)
const EDGE_METAL_TINT := Color(0.42, 0.42, 0.46, 1.0)


func _ready() -> void:
	var corrected_count: int = 0

	var plaster_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_ContinuousArtworkPlaster",
		PLASTER_TINT,
		0.88,
		0.12
	)
	if plaster_material != null:
		corrected_count += 1

	var stone_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_StoneThreshold",
		STONE_TINT,
		0.84,
		0.12
	)
	if stone_material != null:
		corrected_count += 1

	var exterior_wood_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_ExteriorWoodMain",
		EXTERIOR_WOOD_TINT,
		0.56,
		0.18
	)
	if exterior_wood_material != null:
		corrected_count += 1

	var canopy_wood_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_CanopyEaveWood",
		CANOPY_WOOD_TINT,
		0.46,
		0.18
	)
	if canopy_wood_material != null:
		corrected_count += 1

	var upper_wood_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_UpperWoodCladding",
		UPPER_WOOD_TINT,
		0.58,
		0.18
	)
	if upper_wood_material != null:
		corrected_count += 1

	var frame_wood_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_WoodFrames",
		FRAME_WOOD_TINT,
		0.50,
		0.20
	)
	if frame_wood_material != null:
		corrected_count += 1

	var glass_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_GlazingPlaceholder",
		GLASS_TINT,
		0.10,
		0.24,
		0.0
	)
	if glass_material != null:
		corrected_count += 1
		_finish_glazing(glass_material)

	var interior_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_InteriorPlaceholder",
		INTERIOR_TINT,
		0.92,
		0.08,
		0.0
	)
	if interior_material != null:
		corrected_count += 1
		_finish_interior_material(interior_material)

	var roof_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_MatteRoofSurface",
		ROOF_TINT,
		0.92,
		0.10,
		0.0
	)
	if roof_material != null:
		corrected_count += 1

	var edge_material: BaseMaterial3D = _calibrate_mesh(
		"SM_YakitoriShop_ArchitecturalMetal",
		EDGE_METAL_TINT,
		0.56,
		0.20,
		0.86
	)
	if edge_material != null:
		corrected_count += 1

	_replace_combined_edge_mesh(edge_material)
	_replace_placeholder_interior(interior_material, frame_wood_material)

	set_meta("reference_finish_version", 6)
	set_meta("reference_materials_calibrated", corrected_count == 10)
	if corrected_count != 10:
		push_warning(
			"Yakitori V6 found %d of 10 expected authored material meshes." %
			corrected_count
		)


func _calibrate_mesh(
	mesh_name: String,
	exposure_tint: Color,
	roughness_value: float,
	specular_value: float,
	metallic_value: float = -1.0
) -> BaseMaterial3D:
	var target_mesh: MeshInstance3D = find_child(
		mesh_name, true, false
	) as MeshInstance3D
	if target_mesh == null:
		return null

	var source_material: BaseMaterial3D = target_mesh.get_active_material(
		0
	) as BaseMaterial3D
	if source_material == null:
		return null

	var material: BaseMaterial3D = source_material.duplicate(
		true
	) as BaseMaterial3D
	if material == null:
		return null

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
	return material


func _finish_glazing(material: BaseMaterial3D) -> void:
	var glass_color: Color = material.albedo_color
	glass_color.a = 0.22
	material.albedo_color = glass_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.refraction_enabled = true
	material.refraction_scale = 0.008


func _finish_interior_material(material: BaseMaterial3D) -> void:
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(0.16, 0.055, 0.014, 1.0)
	material.emission_energy_multiplier = 0.42


func _model_root() -> Node3D:
	return get_node_or_null("Model") as Node3D


func _hide_authored_mesh(mesh_name: String) -> void:
	var target_mesh: MeshInstance3D = find_child(
		mesh_name, true, false
	) as MeshInstance3D
	if target_mesh != null:
		target_mesh.visible = false


func _replace_combined_edge_mesh(material: Material) -> void:
	if material == null:
		return
	var model: Node3D = _model_root()
	if model == null or model.get_node_or_null("ReferenceEdgeFinish") != null:
		return

	_hide_authored_mesh("SM_YakitoriShop_ArchitecturalMetal")
	var edge_root: Node3D = Node3D.new()
	edge_root.name = "ReferenceEdgeFinish"
	model.add_child(edge_root)

	# Ground-floor canopy: four thin, closed flashing returns with no open ends.
	_add_box(edge_root, "CanopyFlashingFront",
		Vector3(0.0, 2.655, -1.405), Vector3(4.40, 0.055, 0.045), material)
	_add_box(edge_root, "CanopyFlashingRear",
		Vector3(0.0, 2.692, -0.638), Vector3(4.30, 0.035, 0.035), material)
	for side_index in range(2):
		var side_x: float = -2.18 if side_index == 0 else 2.18
		_add_box(edge_root, "CanopyFlashingSide_%02d" % side_index,
			Vector3(side_x, 2.68, -1.02), Vector3(0.035, 0.045, 0.72),
			material, Vector3(CANOPY_PITCH_RAD, 0.0, 0.0))

	# Compact paired handles, matching the reference instead of long bar pulls.
	for pull_index in range(2):
		var pull_x: float = -0.18 if pull_index == 0 else 0.18
		_add_cylinder(edge_root, "DoorPullGrip_%02d" % pull_index,
			Vector3(pull_x, 1.28, -0.850), 0.018, 0.240, material)
		for mount_index in range(2):
			var mount_y: float = 1.18 if mount_index == 0 else 1.38
			_add_cylinder(edge_root,
				"DoorPullStandoff_%02d_%02d" % [pull_index, mount_index],
				Vector3(pull_x, mount_y, -0.795), 0.014, 0.080, material,
				Vector3(PI * 0.5, 0.0, 0.0))
			_add_cylinder(edge_root,
				"DoorPullRosette_%02d_%02d" % [pull_index, mount_index],
				Vector3(pull_x, mount_y, -0.752), 0.030, 0.018, material,
				Vector3(PI * 0.5, 0.0, 0.0))

	# Upper roof flashing is continuous on all four sides and closes the corner gaps.
	_add_box(edge_root, "UpperRoofFrontEdge",
		Vector3(0.0, 5.54, -0.965), Vector3(4.40, 0.065, 0.045), material)
	_add_box(edge_root, "UpperRoofFrontCap",
		Vector3(0.0, 5.59, -0.950), Vector3(4.42, 0.028, 0.090), material)
	for side_index in range(2):
		var side_x: float = -2.19 if side_index == 0 else 2.19
		_add_box(edge_root, "UpperRoofSideEdge_%02d" % side_index,
			Vector3(side_x, 5.69, 1.57), Vector3(0.035, 0.055, 4.42),
			material, Vector3(ROOF_PITCH_RAD, 0.0, 0.0))
	_add_box(edge_root, "UpperRoofRearEdge",
		Vector3(0.0, 5.84, 3.79), Vector3(4.38, 0.050, 0.045), material)

	# Rear window reveal and masonry-pier caps.
	_add_box(edge_root, "RearWindowReveal",
		Vector3(0.86, 4.22, 3.862), Vector3(0.76, 1.02, 0.030), material)
	_add_box(edge_root, "RoofPierCapLeft",
		Vector3(-1.91, 6.365, 3.48), Vector3(0.29, 0.05, 0.42), material)
	_add_box(edge_root, "RoofPierCapRight",
		Vector3(1.91, 6.205, 3.48), Vector3(0.29, 0.05, 0.42), material)

	# Fine perimeter guard: close to the roof edge, seated on the pitched roof,
	# and joined at every corner. The older rail sat too far inward.
	var rail_x: float = 1.90
	var rail_front_z: float = -0.48
	var rail_rear_z: float = 3.34
	var rail_mid_z: float = (rail_front_z + rail_rear_z) * 0.5
	var rail_height: float = 0.30
	for side_index in range(2):
		var side_x: float = -rail_x if side_index == 0 else rail_x
		for post_index in range(3):
			var post_z: float = rail_front_z
			if post_index == 1:
				post_z = rail_mid_z
			elif post_index == 2:
				post_z = rail_rear_z
			_add_box(edge_root,
				"RoofRailSidePost_%02d_%02d" % [side_index, post_index],
				Vector3(side_x, _roof_top(post_z) + rail_height * 0.5, post_z),
				Vector3(0.035, rail_height, 0.035), material)
		for rail_index in range(2):
			var rail_offset: float = 0.12 if rail_index == 0 else rail_height
			_add_box(edge_root,
				"RoofRailSide_%02d_%02d" % [side_index, rail_index],
				Vector3(side_x, _roof_top(rail_mid_z) + rail_offset, rail_mid_z),
				Vector3(0.035, 0.035, rail_rear_z - rail_front_z), material,
				Vector3(ROOF_PITCH_RAD, 0.0, 0.0))

	for end_index in range(2):
		var end_z: float = rail_front_z if end_index == 0 else rail_rear_z
		for post_index in range(3):
			var post_x: float = -rail_x + float(post_index) * rail_x
			_add_box(edge_root,
				"RoofRailEndPost_%02d_%02d" % [end_index, post_index],
				Vector3(post_x, _roof_top(end_z) + rail_height * 0.5, end_z),
				Vector3(0.035, rail_height, 0.035), material)
		for rail_index in range(2):
			var rail_offset: float = 0.12 if rail_index == 0 else rail_height
			_add_box(edge_root,
				"RoofRailEnd_%02d_%02d" % [end_index, rail_index],
				Vector3(0.0, _roof_top(end_z) + rail_offset, end_z),
				Vector3(rail_x * 2.0, 0.035, 0.035), material)

	# Slim rear downpipes complete the side/rear silhouette without adding props.
	for pipe_index in range(2):
		var pipe_x: float = -2.135 if pipe_index == 0 else 2.135
		_add_cylinder(edge_root, "RearDownpipe_%02d" % pipe_index,
			Vector3(pipe_x, 2.80, 3.43), 0.030, 5.05, material)
		_add_cylinder(edge_root, "RearDownpipeElbow_%02d" % pipe_index,
			Vector3(pipe_x, 5.34, 3.30), 0.030, 0.30, material,
			Vector3(PI * 0.5, 0.0, 0.0))


func _replace_placeholder_interior(
	interior_material: BaseMaterial3D,
	frame_material: BaseMaterial3D
) -> void:
	if interior_material == null or frame_material == null:
		return
	var model: Node3D = _model_root()
	if model == null or model.get_node_or_null("FinishedInteriorShell") != null:
		return

	_hide_authored_mesh("SM_YakitoriShop_InteriorPlaceholder")
	var interior_root: Node3D = Node3D.new()
	interior_root.name = "FinishedInteriorShell"
	model.add_child(interior_root)

	var floor_material: BaseMaterial3D = frame_material.duplicate(
		true
	) as BaseMaterial3D
	floor_material.resource_local_to_scene = true
	var floor_color: Color = floor_material.albedo_color
	floor_material.albedo_color = Color(
		floor_color.r * 0.72,
		floor_color.g * 0.64,
		floor_color.b * 0.56,
		1.0
	)
	floor_material.roughness = 0.54
	floor_material.metallic_specular = 0.16
	floor_material.uv1_scale = Vector3(0.48, 0.48, 0.48)

	# Finished architectural shell only: floor, ceiling, side returns and rear
	# walls. The space remains prop-free as requested.
	_add_box(interior_root, "GroundFloor",
		Vector3(0.0, 0.225, 1.50), Vector3(3.68, 0.045, 4.08),
		floor_material)
	_add_box(interior_root, "GroundCeiling",
		Vector3(0.0, 2.60, 1.50), Vector3(3.68, 0.055, 4.08),
		interior_material)
	_add_box(interior_root, "GroundRearWall",
		Vector3(0.0, 1.42, 3.48), Vector3(3.68, 2.36, 0.080),
		interior_material)
	for side_index in range(2):
		var side_x: float = -1.83 if side_index == 0 else 1.83
		_add_box(interior_root, "GroundSideWall_%02d" % side_index,
			Vector3(side_x, 1.42, 1.50), Vector3(0.055, 2.36, 4.02),
			interior_material)

	_add_box(interior_root, "UpperFloor",
		Vector3(0.0, 3.13, 1.48), Vector3(3.66, 0.050, 4.02),
		floor_material)
	_add_box(interior_root, "UpperRearWall",
		Vector3(0.0, 4.32, 3.47), Vector3(3.66, 2.30, 0.080),
		interior_material)
	for side_index in range(2):
		var side_x: float = -1.82 if side_index == 0 else 1.82
		_add_box(interior_root, "UpperSideWall_%02d" % side_index,
			Vector3(side_x, 4.32, 1.48), Vector3(0.050, 2.30, 3.98),
			interior_material)

	_add_warm_interior_light(
		interior_root, "GroundArchitecturalGlow",
		Vector3(0.0, 1.55, 0.65), 0.24, 3.15
	)
	_add_warm_interior_light(
		interior_root, "UpperArchitecturalGlow",
		Vector3(0.0, 4.35, 0.55), 0.17, 2.65
	)


func _add_warm_interior_light(
	parent: Node3D,
	light_name: String,
	position_value: Vector3,
	energy: float,
	range_value: float
) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.position = position_value
	light.light_color = Color(1.0, 0.72, 0.47, 1.0)
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.85
	light.shadow_enabled = false
	light.add_to_group("shinrai_yakitori_interior_light")
	parent.add_child(light)


func _roof_top(z_value: float) -> float:
	return 5.68 - sin(ROOF_PITCH_RAD) * (z_value - 1.57) + 0.052


func _add_box(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size_value

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = box_mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_cylinder(
	parent: Node3D,
	part_name: String,
	position_value: Vector3,
	radius: float,
	height_value: float,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height_value
	cylinder_mesh.radial_segments = 16
	cylinder_mesh.rings = 1

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = part_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = cylinder_mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
