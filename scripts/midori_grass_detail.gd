extends Node
const StartupTrace = preload("res://scripts/startup_trace.gd")

const FoliageMaterials = preload("res://scripts/midori_foliage_materials.gd")

const LakeGeometry = preload("res://scripts/midori_lake_geometry.gd")

# Midori Park lawn scatter. Upright grass is the near-ground silhouette;
# Meshy ground clumps are disabled so they cannot spill onto the sidewalk.

const GroundClumpScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_meshy_ground_clump_v1.glb")
const UprightGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/cosmic_dust_grass/grass_1k.glb")

const LAYOUT_SCALE := 2.0
const PARK_HALF := Vector2(220.0, 180.0)
const CLUMP_INSTANCE_COUNT := 0
const UPRIGHT_INSTANCE_COUNT := 60000
const CHUNKS_X := 8
const CHUNKS_Z := 6
const UPRIGHT_CHUNKS_X := 16
const UPRIGHT_CHUNKS_Z := 12
const TREE_INDEX_CELL_M := 8.0
const GROVE_GRASS_RADIUS_M := 6.0
const OPEN_THIN_GRASS_FRACTION := 0.98
const GROVE_THIN_GRASS_FRACTION := 0.35
const RNG_SEED := 20260916
const DETAIL_VERSION := 29
var _forest_cells: Dictionary = {}
const LAKE_SHORE_GRASS_BUFFER_M := 1.75
const OUTER_CIRCUIT: Array[Vector2] = [
	Vector2(-98,70),Vector2(-72,77),Vector2(-38,82),Vector2(0,84),
	Vector2(38,85),Vector2(70,85),Vector2(98,84),Vector2(105,70),
	Vector2(106,48),Vector2(105,25),Vector2(104,0),Vector2(103,-25),
	Vector2(101,-50),Vector2(98,-68),Vector2(91,-82),Vector2(62,-85),
	Vector2(25,-84),Vector2(-18,-82),Vector2(-55,-80),Vector2(-83,-76),
	Vector2(-103,-66),Vector2(-106,-42),Vector2(-106,-10),Vector2(-105,22),
	Vector2(-103,49),Vector2(-98,70),
]
const SOUTH_ARRIVAL_ROUTE: Array[Vector2] = [
	Vector2(0,90),Vector2(-4,80),Vector2(-12,68),Vector2(-18,54),
	Vector2(-22,42),Vector2(-10,34),Vector2(8,30),Vector2(18,29),
]
const WEST_DESTINATION_ROUTE: Array[Vector2] = [
	Vector2(-110,20),Vector2(-98,18),Vector2(-84,12),Vector2(-68,4),
	Vector2(-52,-2),Vector2(-36,-8),Vector2(-18,-10),Vector2(-2,-10),
	Vector2(9.5,-10.5),
]
const NORTH_ENTRY_ROUTE: Array[Vector2] = [
	Vector2(-38,-90),Vector2(-24,-82),Vector2(-8,-74),Vector2(12,-70),
	Vector2(30,-68),Vector2(47,-68.5),
]
const EAST_DECK_ROUTE: Array[Vector2] = [
	Vector2(110,-20),Vector2(98,-16),Vector2(88,-10),Vector2(82,-4),
	Vector2(80.5,-1),
]
const SPORTS_LINK_ROUTE: Array[Vector2] = [
	Vector2(-105,-20),Vector2(-92,-22),Vector2(-76,-24),Vector2(-58,-26),
	Vector2(-40,-28),Vector2(-22,-28),Vector2(15,-27),
]
const PLAYGROUND_LOOP: Array[Vector2] = [
	Vector2(-97,20),Vector2(-96,29),Vector2(-97,46),Vector2(-94,60),
	Vector2(-84,66),Vector2(-69,67),Vector2(-53,65),Vector2(-40,54),
	Vector2(-28,44),Vector2(-12,36),Vector2(13,28),Vector2(18,20),
	Vector2(10,21),Vector2(-5,25),Vector2(-18,28),Vector2(-34,34),
	Vector2(-50,30),Vector2(-66,28),Vector2(-82,26),Vector2(-92,24),
	Vector2(-97,20),
]
const NORTH_WOODLAND_LOOP: Array[Vector2] = [
	Vector2(15,-27),Vector2(8,-38),Vector2(4,-50),Vector2(2,-63),
	Vector2(10,-75),Vector2(20,-80),Vector2(28,-79),Vector2(30,-73),
	Vector2(20,-70),Vector2(12,-60),Vector2(10,-45),Vector2(15,-27),
]
const LAKE_PROMENADE_LOOP: Array[Vector2] = [
	Vector2(48,-75),Vector2(38,-73),Vector2(29,-68),Vector2(23,-60),
	Vector2(20,-51),Vector2(17,-42),Vector2(13,-33),Vector2(10,-22),
	Vector2(8,-9),Vector2(9,5),Vector2(13,18),Vector2(19,30),
	Vector2(27,43),Vector2(38,52),Vector2(50,56),Vector2(62,54),
	Vector2(72,48),Vector2(78,37),Vector2(80,25),Vector2(84,14),
	Vector2(86,1),Vector2(83,-12),Vector2(85,-24),Vector2(83,-37),
	Vector2(79,-48),Vector2(79,-57),Vector2(73,-67),Vector2(62,-73),
	Vector2(48,-75),
]
const PLAZA_ARRIVAL_ROUTE: Array[Vector2] = [
	Vector2(0,90),Vector2(18,86),Vector2(40,82),Vector2(58,78),
	Vector2(70,74),Vector2(76,72),Vector2(82,74),Vector2(88,72),
	Vector2(91,66),Vector2(92,60),
]
# The visible south plaza sidewalk begins west of its original planning route.
# Keep both corridors clear because the first is paved and the second remains
# the authored arrival/landmark clearance.
const PLAZA_PAVED_ROUTE: Array[Vector2] = [
	Vector2(-1,81),Vector2(12,80),Vector2(40,82),Vector2(58,78),
	Vector2(70,74),Vector2(76,72),Vector2(82,74),Vector2(88,72),
	Vector2(91,66),Vector2(92,60),
]
const SOUTH_BRIDGE_APPROACH: Array[Vector2] = [
	Vector2(76,72),Vector2(68,64),Vector2(58,54),Vector2(52,50),
	Vector2(48,49.5),
]
const PAVILION_LINK_ROUTE: Array[Vector2] = [
	Vector2(73,-69),Vector2(80,-74),Vector2(88,-75),Vector2(98,-68),
]
const VIEWING_DECK_APPROACH_ROUTE: Array[Vector2] = [
	Vector2(80.5,-1),Vector2(83,-6),Vector2(81,-13),
]
const LAKE_SHORELINE: Array[Vector2] = LakeGeometry.ANCHORS
var lake_contour: Array[Vector2] = LakeGeometry.contour()
const FUTURE_BRIDGE_WEST: Array[Vector2] = [
	Vector2(12,-19),Vector2(31,-19),Vector2(55,-19),Vector2(83,-19),
]
const FUTURE_BRIDGE_NORTH_EAST: Array[Vector2] = [
	Vector2(31,-57),Vector2(42,-57),Vector2(59,-57),Vector2(73,-57),
]
const FUTURE_BRIDGE_SOUTH: Array[Vector2] = [
	Vector2(22,24),Vector2(39,24),Vector2(60,24),Vector2(79,24),
]

# Measured from the imported GLB rather than assuming a centered one-metre mesh.
# Accurate bounds keep the leaves above the lawn as their scale changes.
const SOURCE_HEIGHT_M := 0.796875
const SOURCE_BOTTOM_Y := -0.378906
const MIN_CLUMP_HEIGHT_M := 0.15
const MAX_CLUMP_HEIGHT_M := 0.28
const GROUND_SURFACE_Y := 0.010
# A small fixed reveal prevents z-fighting without making the clumps float.
const EXPOSED_BASE_OFFSET_M := 0.035
const MIN_UPRIGHT_HEIGHT_M := 0.24
const MAX_UPRIGHT_HEIGHT_M := 0.42

var _installed_scene_id: int = 0
var _bridge_lawn_exclusions: Array[Dictionary] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_install_ground_clumps")


func _on_node_added(_node: Node) -> void:
	call_deferred("_install_ground_clumps")


func _install_ground_clumps() -> void:
	var _boot_tick := StartupTrace.begin()
	var scene := get_tree().current_scene
	if scene == null:
		return
	if String(scene.name) != "MidoriParkSizeBlockout":
		return

	var scene_id := scene.get_instance_id()
	if _installed_scene_id == scene_id:
		return

	var existing := scene.get_node_or_null("MidoriGrassDetail")
	if existing != null:
		if int(existing.get_meta("detail_version", 0)) == DETAIL_VERSION:
			_installed_scene_id = scene_id
			return
		existing.free()

	var clump_mesh := _extract_source_mesh()
	if clump_mesh == null:
		push_warning("Midori ground detail: Meshy clump mesh was not found")
		return
	var upright_mesh := _extract_upright_mesh()
	if upright_mesh == null:
		push_warning("Midori ground detail: upright grass mesh was not found")
		return
	var thin_upright_mesh := _extract_upright_mesh("Grass1_Grass2_Mat_0")
	if thin_upright_mesh == null:
		push_warning("Midori ground detail: thin upright grass mesh was not found")
		return

	var fallback_material: Material = null
	_build_bridge_lawn_exclusions(scene, upright_mesh, thin_upright_mesh)
	if not _mesh_has_material(clump_mesh):
		fallback_material = _build_fallback_material()

	var chunk_width := PARK_HALF.x * 2.0 / float(CHUNKS_X)
	var chunk_depth := PARK_HALF.y * 2.0 / float(CHUNKS_Z)
	var bucket_count := CHUNKS_X * CHUNKS_Z
	var buckets: Array = []
	for _bucket_index: int in range(bucket_count):
		buckets.append([])

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var placed := 0
	var attempts := 0
	var max_attempts := CLUMP_INSTANCE_COUNT * 24

	while placed < CLUMP_INSTANCE_COUNT and attempts < max_attempts:
		attempts += 1
		var x := rng.randf_range(-PARK_HALF.x + 2.0, PARK_HALF.x - 2.0)
		var z := rng.randf_range(-PARK_HALF.y + 2.0, PARK_HALF.y - 2.0)
		if not _is_lawn_position(x, z):
			continue

		# Gentle macro patching: some lawn areas stay sparse while nearby areas
		# gather more clumps, avoiding an artificial evenly-spaced look.
		var macro: float = 0.5
		macro += sin(x * 0.115) * 0.16
		macro += cos(z * 0.095) * 0.14
		macro += sin((x + z) * 0.061) * 0.12
		var keep_probability: float = clampf(0.44 + macro * 0.58, 0.34, 0.96)
		if rng.randf() > keep_probability:
			continue

		var chunk_x := clampi(int(floor((x + PARK_HALF.x) / chunk_width)), 0, CHUNKS_X - 1)
		var chunk_z := clampi(int(floor((z + PARK_HALF.y) / chunk_depth)), 0, CHUNKS_Z - 1)
		var chunk_index := chunk_z * CHUNKS_X + chunk_x
		var center_x := -PARK_HALF.x + (float(chunk_x) + 0.5) * chunk_width
		var center_z := -PARK_HALF.y + (float(chunk_z) + 0.5) * chunk_depth

		var target_height := rng.randf_range(MIN_CLUMP_HEIGHT_M, MAX_CLUMP_HEIGHT_M)
		var uniform_scale := target_height / SOURCE_HEIGHT_M
		var width_variation := rng.randf_range(2.0, 2.8)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw)
		basis = basis.scaled(Vector3(
			uniform_scale * width_variation,
			uniform_scale,
			uniform_scale * width_variation
		))

		# Plant the measured source base on the park surface, then expose it just
		# enough to remain legible over the detailed ground texture.
		var grounded_y := GROUND_SURFACE_Y - SOURCE_BOTTOM_Y * uniform_scale
		grounded_y += EXPOSED_BASE_OFFSET_M
		grounded_y += rng.randf_range(-0.002, 0.002)
		var local_position := Vector3(x - center_x, grounded_y, z - center_z)
		buckets[chunk_index].append(Transform3D(basis, local_position))
		placed += 1

	var root := Node3D.new()
	root.name = "MidoriGrassDetail"
	root.set_meta("detail_version", DETAIL_VERSION)
	scene.add_child(root)
	_add_forest_grass_drifts(root, thin_upright_mesh, scene)
	var upright_count := _add_upright_grass(root, upright_mesh, thin_upright_mesh, scene)

	for chunk_z: int in range(CHUNKS_Z):
		for chunk_x: int in range(CHUNKS_X):
			var chunk_index := chunk_z * CHUNKS_X + chunk_x
			var transforms: Array = buckets[chunk_index]
			if transforms.is_empty():
				continue

			var center_x := -PARK_HALF.x + (float(chunk_x) + 0.5) * chunk_width
			var center_z := -PARK_HALF.y + (float(chunk_z) + 0.5) * chunk_depth

			var chunk_root := Node3D.new()
			chunk_root.name = "GroundClumpChunk_%02d_%02d" % [chunk_x, chunk_z]
			chunk_root.position = Vector3(center_x, 0.0, center_z)
			root.add_child(chunk_root)

			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = clump_mesh
			multimesh.instance_count = transforms.size()
			multimesh.custom_aabb = AABB(
				Vector3(-chunk_width * 0.5 - 1.0, -0.02, -chunk_depth * 0.5 - 1.0),
				Vector3(chunk_width + 2.0, MAX_CLUMP_HEIGHT_M + 0.14, chunk_depth + 2.0)
			)

			for transform_index: int in range(transforms.size()):
				multimesh.set_instance_transform(transform_index, transforms[transform_index])

			var clumps := MultiMeshInstance3D.new()
			clumps.name = "MeshyGroundClumps"
			clumps.multimesh = multimesh
			clumps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			clumps.extra_cull_margin = 8.0
			# A chunk is at least 55 m wide. Fade distant chunks while preserving
			# the dense clumps around the player; this leaves the scatter unchanged.
			clumps.visibility_range_end = 80.0
			clumps.visibility_range_end_margin = 15.0
			clumps.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if fallback_material != null:
				clumps.material_override = fallback_material
			chunk_root.add_child(clumps)

	_installed_scene_id = scene_id
	_boot_tick = StartupTrace.finish("vegetation.grass_install",_boot_tick)
	print("Midori lawn detail installed: %d upright grass (%d thin, %d broad), %d ground clumps" % [
		upright_count,
		int(root.get_meta("thin_grass_count", 0)),
		int(root.get_meta("broad_grass_count", 0)),
		placed,
	])


func _add_upright_grass(root: Node3D, broad_mesh: Mesh, thin_mesh: Mesh, scene: Node) -> int:
	var chunk_width := PARK_HALF.x * 2.0 / float(UPRIGHT_CHUNKS_X)
	var chunk_depth := PARK_HALF.y * 2.0 / float(UPRIGHT_CHUNKS_Z)
	var broad_bounds := broad_mesh.get_aabb()
	var thin_bounds := thin_mesh.get_aabb()
	var broad_anchor := Vector3(
		broad_bounds.position.x + broad_bounds.size.x * 0.5,
		broad_bounds.position.y,
		broad_bounds.position.z + broad_bounds.size.z * 0.5
	)
	var thin_anchor := Vector3(
		thin_bounds.position.x + thin_bounds.size.x * 0.5,
		thin_bounds.position.y,
		thin_bounds.position.z + thin_bounds.size.z * 0.5
	)
	var tree_cells := _build_tree_spatial_index(scene)
	var planting_noise := FastNoiseLite.new()
	planting_noise.seed = RNG_SEED
	planting_noise.frequency = 0.13
	planting_noise.fractal_octaves = 2
	if tree_cells.is_empty():
		push_warning("Midori lawn detail: tree positions unavailable, keeping broad grass distribution")
	var chunk_count := UPRIGHT_CHUNKS_X * UPRIGHT_CHUNKS_Z
	var buckets: Array = []
	for _bucket_index: int in range(chunk_count * 2):
		buckets.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED + 101
	var placed := 0
	var thin_count := 0
	var replaced_count := 0
	var attempts := 0
	while placed < UPRIGHT_INSTANCE_COUNT and attempts < UPRIGHT_INSTANCE_COUNT * 22:
		attempts += 1
		var x := rng.randf_range(-PARK_HALF.x + 2.0, PARK_HALF.x - 2.0)
		var z := rng.randf_range(-PARK_HALF.y + 2.0, PARK_HALF.y - 2.0)
		if not _is_lawn_position(x, z):
			continue
		var patchiness := sin(x * 0.085 + 0.4) * 0.11 + cos(z * 0.074) * 0.10
		patchiness += sin((x - z) * 0.041) * 0.10
		if rng.randf() > clampf(0.81 + patchiness, 0.55, 0.98):
			continue
		var chunk_x := clampi(int(floor((x + PARK_HALF.x) / chunk_width)), 0, UPRIGHT_CHUNKS_X - 1)
		var chunk_z := clampi(int(floor((z + PARK_HALF.y) / chunk_depth)), 0, UPRIGHT_CHUNKS_Z - 1)
		var center_x := -PARK_HALF.x + (float(chunk_x) + 0.5) * chunk_width
		var center_z := -PARK_HALF.y + (float(chunk_z) + 0.5) * chunk_depth
		# Thin blades dominate open lawn. Broader blades remain under and between
		# trees so the grove floor still looks full rather than uniformly wispy.
		var grove_weight := _grove_weight(x, z, tree_cells)
		var pocket_weight := smoothstep(-0.25, 0.35, planting_noise.get_noise_2d(x,z))
		var broad_fraction := lerpf(1.0-OPEN_THIN_GRASS_FRACTION,1.0-GROVE_THIN_GRASS_FRACTION,grove_weight*pocket_weight)
		var use_thin := rng.randf() < 1.0-broad_fraction
		var bounds := thin_bounds if use_thin else broad_bounds
		var source_anchor := thin_anchor if use_thin else broad_anchor
		var min_height := lerpf(0.11,0.19,grove_weight) if use_thin else 0.22
		var max_height := lerpf(0.21,0.31,grove_weight) if use_thin else 0.36
		var height := rng.randf_range(min_height,max_height)
		var vertical_scale := height / bounds.size.y
		var width_scale := vertical_scale * rng.randf_range(0.95, 1.20) if use_thin else vertical_scale * rng.randf_range(1.10, 1.45)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(width_scale, vertical_scale, width_scale)
		)
		var ground_position := Vector3(x - center_x, GROUND_SURFACE_Y + 0.004, z - center_z)
		if _inside_forest_mound(Vector2(x,z)):
			replaced_count+=1
			placed+=1
			continue
		var variant_index := 1 if use_thin else 0
		buckets[variant_index * chunk_count + chunk_z * UPRIGHT_CHUNKS_X + chunk_x].append(Transform3D(
			basis, ground_position - basis * source_anchor
		))
		if use_thin:
			thin_count += 1
		placed += 1
	var broad_material := _build_upright_material(broad_mesh, false)
	var thin_material := _build_upright_material(thin_mesh, true)
	for variant_index: int in range(2):
		var mesh := thin_mesh if variant_index == 1 else broad_mesh
		var grass_material := thin_material if variant_index == 1 else broad_material
		var grass_name := "ThinUprightGrass" if variant_index == 1 else "UprightGrass"
		for chunk_z: int in range(UPRIGHT_CHUNKS_Z):
			for chunk_x: int in range(UPRIGHT_CHUNKS_X):
				var transforms: Array = buckets[variant_index * chunk_count + chunk_z * UPRIGHT_CHUNKS_X + chunk_x]
				if transforms.is_empty():
					continue
				var center_x := -PARK_HALF.x + (float(chunk_x) + 0.5) * chunk_width
				var center_z := -PARK_HALF.y + (float(chunk_z) + 0.5) * chunk_depth
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.mesh = mesh
				multimesh.instance_count = transforms.size()
				multimesh.custom_aabb = AABB(
					Vector3(-chunk_width * 0.5 - 1.0, -0.02, -chunk_depth * 0.5 - 1.0),
					Vector3(chunk_width + 2.0, MAX_UPRIGHT_HEIGHT_M + 0.06, chunk_depth + 2.0)
				)
				for transform_index: int in range(transforms.size()):
					multimesh.set_instance_transform(transform_index, transforms[transform_index])
				var grass := MultiMeshInstance3D.new()
				grass.name = "%s_%02d_%02d" % [grass_name, chunk_x, chunk_z]
				grass.position = Vector3(center_x, 0.0, center_z)
				grass.multimesh = multimesh
				grass.material_override = grass_material
				grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				grass.visibility_range_end = 85.0
				grass.visibility_range_end_margin = 16.0
				grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				root.add_child(grass)
	root.set_meta("thin_grass_count", thin_count)
	root.set_meta("broad_grass_count", placed - replaced_count - thin_count)
	root.set_meta("replaced_grass_clumps",replaced_count)
	print("FOREST_GRASS_REPLACED ",replaced_count)
	return placed-replaced_count


func _build_tree_spatial_index(scene: Node) -> Dictionary:
	var cells: Dictionary = {}
	var tree_positions: Variant = scene.get("occupied_tree_positions")
	if not tree_positions is Array:
		return cells
	for authored_tree_position: Vector2 in tree_positions:
		# The park root scales authored tree coordinates by two. Grass scatter
		# points are already world-space, so the index must use world positions.
		var tree_position := authored_tree_position * LAYOUT_SCALE
		var cell := Vector2i(
			floori(tree_position.x / TREE_INDEX_CELL_M),
			floori(tree_position.y / TREE_INDEX_CELL_M)
		)
		var positions: Array = cells.get(cell, [])
		positions.append(tree_position)
		cells[cell] = positions
	return cells


func _is_near_tree(x: float, z: float, tree_cells: Dictionary) -> bool:
	var cell_x := floori(x / TREE_INDEX_CELL_M)
	var cell_z := floori(z / TREE_INDEX_CELL_M)
	var radius_squared := GROVE_GRASS_RADIUS_M * GROVE_GRASS_RADIUS_M
	for offset_z: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var positions: Array = tree_cells.get(Vector2i(cell_x + offset_x, cell_z + offset_z), [])
			for tree_position: Vector2 in positions:
				if Vector2(x, z).distance_squared_to(tree_position) <= radius_squared:
					return true
	return false


func _extract_upright_mesh(mesh_name: String = "Grass1_Grass_Mat_0") -> Mesh:
	var source_root := UprightGrassScene.instantiate()
	if source_root == null:
		return null
	var mesh_instance := source_root.find_child(mesh_name, true, false) as MeshInstance3D
	var mesh: Mesh = mesh_instance.mesh if mesh_instance != null else null
	source_root.free()
	return mesh


func _build_upright_material(mesh: Mesh, use_thin_source_texture: bool) -> Material:
	var source := mesh.surface_get_material(0)
	var material: StandardMaterial3D
	if source is StandardMaterial3D:
		material = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()
	if use_thin_source_texture:
		# This blade uses its own cutout texture. Reusing the broad blade texture
		# here changes the alpha silhouette and makes it look like a leafy tuft.
		material.resource_name = "SHINRAI_ThinUprightLawnGrass"
		material.albedo_color = Color(0.84, 0.88, 0.80, 1.0)
	else:
		# Preserve the established broad grass material and its greener variant.
		var source_root := UprightGrassScene.instantiate()
		var lawn_mesh_instance := source_root.find_child("Grass1_Grass1_Mat_0", true, false) as MeshInstance3D
		if lawn_mesh_instance != null:
			var lawn_material := lawn_mesh_instance.mesh.surface_get_material(0)
			if lawn_material is StandardMaterial3D:
				material.albedo_texture = (lawn_material as StandardMaterial3D).albedo_texture
				# The greener photographed leaf is atlas 8, paired with normal 10.
				# Retaining the original leaf's normal 2 misaligns its veins.
				material.normal_enabled = (lawn_material as StandardMaterial3D).normal_enabled
				material.normal_texture = (lawn_material as StandardMaterial3D).normal_texture
				material.normal_scale = (lawn_material as StandardMaterial3D).normal_scale
		source_root.free()
		material.resource_name = "SHINRAI_UprightLawnGrass"
		material.albedo_color = Color(0.88, 0.86, 0.82, 1.0)
	material.ao_texture = null
	material.disable_receive_shadows = false
	material.metallic = 0.0
	material.metallic_specular = 0.15
	material.roughness = 0.94
	var adapted := FoliageMaterials.build(material) as StandardMaterial3D
	return _upright_leaf_detail(adapted, mesh, use_thin_source_texture)


func _upright_detail_fallback(source: StandardMaterial3D, reason: String) -> Material:
	source.set_meta("midori_grass_surface_fallback", reason)
	return source


func _upright_tip_direction(mesh: Mesh) -> float:
	# Read the imported mesh's UV convention rather than assuming an image
	# viewer's vertical orientation. UV endpoints follow drooping leaf tips too.
	var lower_sum := 0.0
	var upper_sum := 0.0
	var lower_count := 0
	var upper_count := 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if vertices.size() != uvs.size(): return 0.0
		for index: int in range(vertices.size()):
			if uvs[index].y <= .02:
				lower_sum += vertices[index].y
				lower_count += 1
			elif uvs[index].y >= .98:
				upper_sum += vertices[index].y
				upper_count += 1
	if lower_count == 0 or upper_count == 0: return 0.0
	var rise := upper_sum / upper_count - lower_sum / lower_count
	if absf(rise) < mesh.get_aabb().size.y * .01: return 0.0
	return 1.0 if rise > 0.0 else -1.0


func _upright_leaf_detail(source: StandardMaterial3D, mesh: Mesh, thin: bool) -> Material:
	# This adapter only supports the two known lawn-card families. Unknown
	# authored features keep the existing StandardMaterial rather than losing
	# their alpha, shading, or UV behavior during a conversion.
	if source == null or source.albedo_texture == null: return source
	var texture_path := source.albedo_texture.resource_path.replace("\\", "/")
	var expected_suffix := "/grass_1k_4.png" if thin else "/grass_1k_8.png"
	var known_embedded := texture_path.begins_with("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/cosmic_dust_grass/grass_1k.glb::")
	var expected_name := "SHINRAI_ThinUprightLawnGrass" if thin else "SHINRAI_UprightLawnGrass"
	if source.resource_name != expected_name or not (known_embedded or texture_path.ends_with(expected_suffix)):
		return _upright_detail_fallback(source, "Unknown leaf atlas")
	if source.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or source.alpha_antialiasing_mode != BaseMaterial3D.ALPHA_ANTIALIASING_OFF:
		return _upright_detail_fallback(source, "Unsupported alpha coverage")
	if source.next_pass != null or source.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or source.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		return _upright_detail_fallback(source, "Unsupported shading or pass")
	if source.diffuse_mode != BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode != BaseMaterial3D.SPECULAR_SCHLICK_GGX or source.metallic != 0.0:
		return _upright_detail_fallback(source, "Unsupported lighting model")
	if source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or source.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		return _upright_detail_fallback(source, "Unsupported material billboard/fade")
	for feature: String in ["vertex_color_use_as_albedo", "uv1_triplanar", "uv1_world_triplanar", "albedo_texture_force_srgb", "albedo_texture_msdf", "emission_enabled", "bent_normal_enabled", "detail_enabled", "heightmap_enabled", "refraction_enabled", "rim_enabled", "clearcoat_enabled", "anisotropy_enabled", "subsurf_scatter_enabled", "subsurf_scatter_transmittance_enabled", "proximity_fade_enabled", "grow", "fixed_size", "shadow_to_opacity", "no_depth_test"]:
		if source.get(feature) == true: return _upright_detail_fallback(source, "Unsupported feature: " + feature)
	if source.ao_enabled and source.ao_texture != null: return _upright_detail_fallback(source, "Active AO map")
	if source.backlight_enabled and source.backlight_texture != null: return _upright_detail_fallback(source, "Authored backlight map")
	var filters: Array[String] = ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
	if source.texture_filter < 0 or source.texture_filter >= filters.size(): return _upright_detail_fallback(source, "Unknown texture filter")
	var tip_direction := _upright_tip_direction(mesh)
	if tip_direction == 0.0: return _upright_detail_fallback(source, "Unverified leaf UV endpoints")
	var cull_modes: Array[String] = ["cull_back", "cull_front", "cull_disabled"]
	var depth_modes: Array[String] = ["depth_draw_opaque", "depth_draw_always", "depth_draw_never"]
	if source.cull_mode < 0 or source.cull_mode >= cull_modes.size() or source.depth_draw_mode < 0 or source.depth_draw_mode >= depth_modes.size():
		return _upright_detail_fallback(source, "Unknown culling/depth mode")
	var modes := "blend_mix, diffuse_burley, specular_schlick_ggx, " + cull_modes[source.cull_mode] + ", " + depth_modes[source.depth_draw_mode]
	if source.disable_receive_shadows: modes += ", shadows_disabled"
	if source.disable_ambient_light: modes += ", ambient_light_disabled"
	if source.disable_fog: modes += ", fog_disabled"
	var sampler_hint: String = filters[source.texture_filter] + (", repeat_enable" if source.texture_repeat else ", repeat_disable")
	var uses_normal := source.normal_enabled and source.normal_texture != null
	var uses_roughness := source.roughness_texture != null
	var channels: Array[Vector4] = [Vector4(1,0,0,0), Vector4(0,1,0,0), Vector4(0,0,1,0), Vector4(0,0,0,1), Vector4(1.0/3.0,1.0/3.0,1.0/3.0,0)]
	if source.roughness_texture_channel < 0 or source.roughness_texture_channel >= channels.size(): return _upright_detail_fallback(source, "Unknown roughness channel")
	var shader := Shader.new()
	var code := "shader_type spatial;\nrender_mode " + modes + ";\n"
	code += "uniform sampler2D source_albedo_texture : source_color, " + sampler_hint + ";\n"
	if uses_normal: code += "uniform sampler2D source_normal_texture : hint_normal, " + sampler_hint + ";\n"
	if uses_roughness: code += "uniform sampler2D source_roughness_texture : " + sampler_hint + ";\n"
	code += """
uniform vec4 source_albedo : source_color;
uniform vec3 source_uv_scale;
uniform vec3 source_uv_offset;
uniform vec3 blade_root_anchor;
uniform vec2 source_albedo_size;
uniform float source_alpha_cutoff;
uniform float source_roughness;
uniform vec4 source_roughness_channel;
uniform float source_specular;
uniform float source_normal_scale;
uniform vec4 source_backlight : source_color;
uniform float tip_direction;
varying vec2 tuft_variation;
varying float tuft_view_distance;
varying float lawn_field;
float lawn_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float lawn_noise(vec2 p) {
    vec2 c = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(lawn_hash(c), lawn_hash(c + vec2(1.0, 0.0)), u.x), mix(lawn_hash(c + vec2(0.0, 1.0)), lawn_hash(c + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
    vec2 root = (MODEL_MATRIX * vec4(blade_root_anchor, 1.0)).xz;
    // Broad lawn colour field (shared scale with the ground shader) so the
    // blades and the turf beneath them yellow and green together.
    lawn_field = lawn_noise(root * 0.045 + vec2(7.3, 2.8)) * 0.6 + lawn_noise(root * 0.16 + vec2(31.2, 17.6)) * 0.4;
    // Gentle wind: bend the blade tip, never the root, so the plant stays rooted.
    float tip = tip_direction > 0.0 ? UV.y : 1.0 - UV.y;
    float phase = root.x * 0.35 + root.y * 0.21;
    float gust = sin(TIME * 1.3 + phase) * 0.6 + sin(TIME * 2.9 + phase * 1.7) * 0.4;
    vec3 sway_world = vec3(0.9, 0.0, 0.45) * gust * 0.045 * tip * tip;
    VERTEX += (inverse(MODEL_MATRIX) * vec4(sway_world, 0.0)).xyz;
    vec3 seed = fract(vec3(root.x, root.y, root.x) * vec3(.1031, .11369, .13787));
    seed += dot(seed, seed.yzx + 19.19);
    tuft_variation = fract((seed.xx + seed.yz) * seed.zy);
    tuft_view_distance = length((MODELVIEW_MATRIX * vec4(blade_root_anchor, 1.0)).xyz);
}
void fragment() {
    vec2 leaf_uv = UV * source_uv_scale.xy + source_uv_offset.xy;
    vec4 source_texel = texture(source_albedo_texture, leaf_uv);
    vec3 leaf = source_texel.rgb * source_albedo.rgb;
    // Strengthen the existing photographed relief only while its texels resolve.
    // Mipmapped source reads and this derivative/distance fade avoid new shimmer.
    float footprint = max(length(dFdx(leaf_uv) * source_albedo_size), length(dFdy(leaf_uv) * source_albedo_size));
    float fine_detail = (1.0 - smoothstep(4.0, 10.0, footprint)) * (1.0 - smoothstep(8.0, 24.0, tuft_view_distance));
    float luminance = dot(source_texel.rgb, vec3(.2126, .7152, .0722));
    leaf *= 1.0 + clamp((luminance - .22) * .80, -.24, .24) * fine_detail;
"""
	if uses_normal:
		code += """
    vec3 source_normal = texture(source_normal_texture, leaf_uv).rgb;
    NORMAL_MAP = source_normal;
    NORMAL_MAP_DEPTH = source_normal_scale;
    leaf *= 1.0 + clamp(source_normal.r * 2.0 - 1.0, -.5, .5) * .24 * fine_detail;
"""
	code += """
    // Mostly living green: restrained olive variation, shaded roots and a few
    // tawny distal ends. Retain the photographed variation within every blade.
    leaf *= mix(vec3(.92, .98, .93), vec3(1.08, .98, .80), tuft_variation.x);
    leaf *= mix(.90, 1.04, tuft_variation.y);
    // Lush low pockets and sun-dried rises across the lawn.
    leaf *= mix(vec3(.86, 1.02, .88), vec3(1.10, 1.02, .78), smoothstep(.30, .75, lawn_field));
    leaf *= 1.12;
    float blade_height = tip_direction > 0.0 ? UV.y : 1.0 - UV.y;
    leaf *= mix(.88, 1.0, smoothstep(.01, .20, blade_height));
    float older_tip = smoothstep(.74, .98, blade_height) * smoothstep(.55, .95, tuft_variation.x);
    float leaf_light = dot(leaf, vec3(.2126, .7152, .0722));
    leaf = mix(leaf, leaf_light * vec3(1.10, .94, .68), older_tip * .36);
    ALBEDO = max(leaf, vec3(0.0));
    // Preserve engine-provided visibility-range fade, as StandardMaterial does.
    // Exact established atlas alpha and threshold; no new discard/fade path.
    ALPHA *= source_texel.a * source_albedo.a;
    ALPHA_SCISSOR_THRESHOLD = source_alpha_cutoff;
    METALLIC = 0.0;
    SPECULAR = source_specular;
    ROUGHNESS = source_roughness;
    BACKLIGHT = source_backlight.rgb;
"""
	if uses_roughness: code += "    ROUGHNESS *= dot(texture(source_roughness_texture, leaf_uv), source_roughness_channel);\n"
	code += "}\n"
	shader.code = code
	var result := ShaderMaterial.new()
	result.shader = shader
	result.resource_name = source.resource_name + "_LeafDetail"
	result.render_priority = source.render_priority
	result.set_shader_parameter("source_albedo_texture", source.albedo_texture)
	if uses_normal: result.set_shader_parameter("source_normal_texture", source.normal_texture)
	if uses_roughness: result.set_shader_parameter("source_roughness_texture", source.roughness_texture)
	result.set_shader_parameter("source_albedo", source.albedo_color)
	result.set_shader_parameter("source_uv_scale", source.uv1_scale)
	result.set_shader_parameter("source_uv_offset", source.uv1_offset)
	var box := mesh.get_aabb()
	result.set_shader_parameter("blade_root_anchor", Vector3(box.get_center().x, box.position.y, box.get_center().z))
	result.set_shader_parameter("source_albedo_size", Vector2(source.albedo_texture.get_width(), source.albedo_texture.get_height()))
	result.set_shader_parameter("source_alpha_cutoff", source.alpha_scissor_threshold)
	result.set_shader_parameter("source_roughness", source.roughness)
	result.set_shader_parameter("source_roughness_channel", channels[source.roughness_texture_channel])
	result.set_shader_parameter("source_specular", source.metallic_specular)
	result.set_shader_parameter("source_normal_scale", source.normal_scale)
	result.set_shader_parameter("source_backlight", source.backlight if source.backlight_enabled else Color.BLACK)
	result.set_shader_parameter("tip_direction", tip_direction)
	result.set_meta("midori_grass_surface_v1", true)
	result.set_meta("midori_grass_family", "thin" if thin else "broad")
	result.set_meta("source_material", source)
	result.set_meta("midori_grass_texture_reads", 1 + int(uses_normal) + int(uses_roughness))
	result.set_meta("midori_grass_tip_direction", tip_direction)
	return result


func _extract_source_mesh() -> Mesh:
	var source_root := GroundClumpScene.instantiate()
	if source_root == null:
		return null
	var mesh := _find_first_mesh(source_root)
	source_root.free()
	return mesh


func _find_first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			return mesh_instance.mesh

	for child: Node in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null


func _mesh_has_material(mesh: Mesh) -> bool:
	for surface_index: int in range(mesh.get_surface_count()):
		if mesh.surface_get_material(surface_index) != null:
			return true
	return false


func _build_fallback_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "SHINRAI_MeshyGroundClump_Fallback"
	material.albedo_color = Color(0.28, 0.50, 0.16, 1.0)
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _is_lawn_position(x: float, z: float) -> bool:
	# The authored route and lake data stays in the original 220 x 180 m layout
	# coordinates. Scatter candidates are world-space points in the doubled park.
	var authored_x := x / LAYOUT_SCALE
	var authored_z := z / LAYOUT_SCALE
	var point := Vector2(authored_x, authored_z)
	if not _lawn_index_ready: _build_lawn_index()
	if _near_indexed_lawn_boundary(point): return false
	if Geometry2D.is_point_in_polygon(point,_lawn_shoreline): return false

	# Keep the upright grass off the pitch, paved entrance pads and built zones.
	# The path centerline masks above do not cover the wide arrival pads.
	if _inside_box(authored_x, authored_z, -70.0, -43.0, 16.0, 12.0):
		return false
	if _inside_box(authored_x, authored_z, 0.0, 87.5, 11.0, 5.0):
		return false
	if _inside_box(authored_x, authored_z, -38.0, -87.5, 16.0, 9.0):
		return false
	if _inside_box(authored_x, authored_z, -107.5, 20.0, 9.0, 16.0):
		return false
	if _inside_box(authored_x, authored_z, 107.5, -20.0, 9.0, 16.0):
		return false
	if _inside_box(authored_x, authored_z, -45.0, -69.0, 18.0, 11.5):
		return false
	if _inside_box(authored_x, authored_z, -45.0, -76.5, 2.0, 4.5):
		return false
	if _inside_box(authored_x, authored_z, -72.0, 45.0, 21.0, 17.0):
		return false
	if _inside_box(authored_x, authored_z, 82.0, 68.0, 38.0, 30.0):
		return false
	if _inside_box(authored_x, authored_z, 76.0, -73.0, 24.0, 18.0):
		return false
	var world_point := Vector2(x,z)
	for exclusion: Dictionary in _bridge_lawn_exclusions:
		if (exclusion.bounds as Rect2).has_point(world_point) and Geometry2D.is_point_in_polygon(world_point,exclusion.polygon):
			return false

	return true


# Spatial candidates only: the final distance test remains identical to the
# original polyline predicate, including its inclusive boundary comparison.
const LAWN_INDEX_CELL := 4.0
var _lawn_index_ready := false
var _lawn_segment_cells: Dictionary = {}
var _lawn_shoreline := PackedVector2Array()

func _build_lawn_index() -> void:
	_lawn_segment_cells.clear()
	_lawn_shoreline=PackedVector2Array(lake_contour)
	var route_specs: Array[Dictionary] = [
		{"points":OUTER_CIRCUIT, "half_width":2.65},
		{"points":SOUTH_ARRIVAL_ROUTE, "half_width":2.75},
		{"points":WEST_DESTINATION_ROUTE, "half_width":2.75},
		{"points":NORTH_ENTRY_ROUTE, "half_width":2.55},
		{"points":EAST_DECK_ROUTE, "half_width":2.55},
		{"points":SPORTS_LINK_ROUTE, "half_width":2.05},
		{"points":PLAYGROUND_LOOP, "half_width":1.90},
		{"points":NORTH_WOODLAND_LOOP, "half_width":1.80},
		{"points":LAKE_PROMENADE_LOOP, "half_width":2.45},
		{"points":PLAZA_ARRIVAL_ROUTE, "half_width":2.65},
		{"points":PLAZA_PAVED_ROUTE, "half_width":2.65},
		{"points":SOUTH_BRIDGE_APPROACH, "half_width":2.15},
		{"points":PAVILION_LINK_ROUTE, "half_width":2.00},
		{"points":VIEWING_DECK_APPROACH_ROUTE, "half_width":2.05},
	]
	for spec: Dictionary in route_specs:
		_index_lawn_segments(spec.points,spec.half_width)
	_index_lawn_segments(lake_contour,LAKE_SHORE_GRASS_BUFFER_M,true)
	_index_lawn_segments(FUTURE_BRIDGE_WEST,2.6)
	_index_lawn_segments(FUTURE_BRIDGE_NORTH_EAST,2.6)
	_index_lawn_segments(FUTURE_BRIDGE_SOUTH,2.6)
	_lawn_index_ready=true

func _index_lawn_segments(points: Array[Vector2], width: float, closed: bool=false) -> void:
	for index in range(points.size() if closed else points.size()-1):
		var start:=points[index]
		var end:=points[(index+1)%points.size()]
		var segment:=end-start
		var length_squared:=segment.length_squared()
		if length_squared<=.0001: continue
		var entry: Dictionary={"start":start,"segment":segment,"length_squared":length_squared,"width":width}
		var bounds:=Rect2(start,Vector2.ZERO).expand(end).grow(width+.001)
		for z in range(floori(bounds.position.y/LAWN_INDEX_CELL),floori(bounds.end.y/LAWN_INDEX_CELL)+1):
			for x in range(floori(bounds.position.x/LAWN_INDEX_CELL),floori(bounds.end.x/LAWN_INDEX_CELL)+1):
				var cell:=Vector2i(x,z)
				if not _lawn_segment_cells.has(cell): _lawn_segment_cells[cell]=[]
				_lawn_segment_cells[cell].append(entry)

func _near_indexed_lawn_boundary(point: Vector2) -> bool:
	var cell:=Vector2i(floori(point.x/LAWN_INDEX_CELL),floori(point.y/LAWN_INDEX_CELL))
	for entry: Dictionary in _lawn_segment_cells.get(cell,[]):
		var start: Vector2=entry.start
		var segment: Vector2=entry.segment
		var t:=clampf((point-start).dot(segment)/float(entry.length_squared),0.0,1.0)
		if point.distance_to(start+segment*t)<=float(entry.width): return true
	return false

func _build_bridge_lawn_exclusions(scene: Node, broad_mesh: Mesh, thin_mesh: Mesh) -> void:
	_lawn_index_ready=false # Rebuild when a new scene installs its exclusions.
	_bridge_lawn_exclusions.clear()
	if not scene.has_method("bridge_surface_height"):
		return
	# Reserve the whole rotated grass silhouette, rather than just its root.
	var radius := 0.35
	for mesh: Mesh in [broad_mesh,thin_mesh]:
		var bounds := mesh.get_aabb()
		var source_radius := Vector2(bounds.size.x,bounds.size.z).length()*0.5
		radius = maxf(radius,source_radius*MAX_UPRIGHT_HEIGHT_M/bounds.size.y*1.85+0.08)
	for surface: Dictionary in scene.get("_bridge_walk_surfaces"):
		var spec: Dictionary = surface.spec
		var footprint := PackedVector2Array()
		if surface.kind == "landing":
			footprint = spec.footprint
		else:
			var side := Vector2(-spec.axis.y,spec.axis.x)*float(spec.width)*0.5
			footprint = PackedVector2Array([spec.start-side,spec.end-side,spec.end+side,spec.start+side])
		for polygon: PackedVector2Array in Geometry2D.offset_polygon(footprint,radius):
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon:
				bounds = bounds.expand(point)
			_bridge_lawn_exclusions.append({"polygon":polygon,"bounds":bounds.grow(0.001)})
	print("Midori bridge lawn clearance: %d footprints, %.3f m blade radius" % [_bridge_lawn_exclusions.size(),radius])


func _near_polyline(point: Vector2, points: Array[Vector2], half_width: float) -> bool:
	for index: int in range(points.size() - 1):
		var start := points[index]
		var end := points[index + 1]
		var segment := end - start
		var length_squared := segment.length_squared()
		if length_squared <= 0.0001:
			continue
		var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
		if point.distance_to(start + segment * t) <= half_width:
			return true
	return false


func _near_closed_polyline(point: Vector2, points: Array[Vector2], half_width: float) -> bool:
	for index: int in range(points.size()):
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		var segment := end - start
		var length_squared := segment.length_squared()
		if length_squared <= 0.0001:
			continue
		var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
		if point.distance_to(start + segment * t) <= half_width:
			return true
	return false


func _inside_ellipse(x: float, z: float, center_x: float, center_z: float, radius_x: float, radius_z: float) -> bool:
	var dx := (x - center_x) / radius_x
	var dz := (z - center_z) / radius_z
	return dx * dx + dz * dz <= 1.0


func _inside_box(x: float, z: float, center_x: float, center_z: float, width: float, depth: float) -> bool:
	return abs(x - center_x) <= width * 0.5 and abs(z - center_z) <= depth * 0.5


func _add_forest_grass_drifts(root: Node3D, mesh: Mesh, scene: Node) -> void:
	# Hakonechloa reference: low, arching green mounds in irregular woodland
	# drifts. Reuse the supplied grass mesh and alpha texture; no asset replacement.
	var rng := RandomNumberGenerator.new()
	rng.seed = 205010051
	_forest_cells.clear()
	mesh = _forest_grass_mesh(42,8)
	var lod_meshes:Array[Mesh]=[mesh,_forest_grass_mesh(28,5),_forest_grass_mesh(16,3)]
	var bounds := mesh.get_aabb()
	var anchor := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var material := _forest_grass_material()
	var centres: Array[Vector2] = []
	var count := 0
	var audit_min_height:=INF
	var audit_max_height:=0.0
	var grounding_errors:=0
	var trees: Array = scene.get("occupied_tree_positions")
	for i in range(0,trees.size(),4):
		var centre: Vector2 = trees[i]*LAYOUT_SCALE + Vector2(2.7,1.6).rotated(rng.randf_range(0,TAU))
		if not _is_lawn_position(centre.x,centre.y):
			continue
		var crowded := false
		for prior in centres:
			if prior.distance_to(centre)<7.0:
				crowded = true
				break
		if crowded:
			continue
		var transforms: Array[Transform3D] = []
		var angle := rng.randf_range(0,TAU)
		for z in range(-5,6):
			for x in range(-7,8):
				var offset := Vector2(x*0.50+rng.randf_range(-0.15,0.15),z*0.48+rng.randf_range(-0.15,0.15))
				var edge := pow(offset.x/3.5,2)+pow(offset.y/2.4,2)
				if edge>rng.randf_range(0.75,1.05):
					continue
				var p := centre+offset.rotated(angle)
				if not _is_lawn_position(p.x,p.y) or not scene._is_vegetation_clear(Vector3(p.x/2.0,0,p.y/2.0),0.40):
					continue
				var clear := true
				for trunk: Vector2 in trees:
					if p.distance_squared_to(trunk*2.0)<1.0:
						clear=false
						break
				if not clear:
					continue
				var h := rng.randf_range(0.45,0.62)*lerpf(1.0,0.8,clampf(edge,0,1))
				var sy := h/bounds.size.y
				var sx := rng.randf_range(0.82,1.12)/maxf(bounds.size.x,bounds.size.z)
				var basis := Basis(Vector3.UP,angle+rng.randf_range(-0.75,0.75)).scaled(Vector3(sx,sy,sx))
				transforms.append(Transform3D(basis,Vector3(p.x-centre.x,GROUND_SURFACE_Y+0.004,p.y-centre.y)-basis*anchor))
		if transforms.size()<15:
			continue
		for transform in transforms:
			var placed_bounds:AABB=transform*bounds
			audit_min_height=minf(audit_min_height,placed_bounds.size.y)
			audit_max_height=maxf(audit_max_height,placed_bounds.size.y)
			if absf(placed_bounds.position.y-(GROUND_SURFACE_Y+0.004))>0.002:
				grounding_errors+=1
			var p:=Vector2(transform.origin.x+centre.x,transform.origin.z+centre.y)
			var cell:=Vector2i(floori(p.x/2.0),floori(p.y/2.0))
			if not _forest_cells.has(cell):
				_forest_cells[cell]=[]
			_forest_cells[cell].append(p)
		for lod in range(3):
			var mm:=MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=lod_meshes[lod]
			mm.instance_count=transforms.size()
			for j in range(transforms.size()):
				mm.set_instance_transform(j,transforms[j])
			var batch:=MultiMeshInstance3D.new()
			batch.name="JapaneseForestGrassDrift_%03d"%centres.size() if lod==0 else "ForestGrassLOD%d_%03d"%[lod,centres.size()]
			batch.multimesh=mm
			batch.position=Vector3(centre.x,0,centre.y)
			batch.material_override=material
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_begin=[0.0,18.0,34.0][lod]
			batch.visibility_range_end=[18.0,34.0,62.0][lod]
			batch.visibility_range_begin_margin=2.0 if lod>0 else 0.0
			batch.visibility_range_end_margin=2.0 if lod<2 else 10.0
			batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			root.add_child(batch)
		centres.append(centre)
		count+=transforms.size()
		if centres.size()>=48:
			break
	root.set_meta("forest_grass_drifts",centres.size())
	root.set_meta("forest_grass_tufts",count)
	root.set_meta("forest_grass_audit",{"min_height":audit_min_height,"max_height":audit_max_height,"grounding_errors":grounding_errors})
	print("FOREST_GRASS_DRIFTS beds=",centres.size()," tufts=",count)

func _inside_forest_mound(p: Vector2) -> bool:
	var cell:=Vector2i(floori(p.x/2.0),floori(p.y/2.0))
	for z in range(-1,2):
		for x in range(-1,2):
			for centre:Vector2 in _forest_cells.get(cell+Vector2i(x,z),[]):
				if p.distance_squared_to(centre)<0.55*0.55:
					return true
	return false

func _forest_grass_mesh(leaves:int,segments:int) -> ArrayMesh:
	# Botanical silhouette study: narrow, keeled ribbons rising then cascading.
	# New mesh only for added beds; supplied files and base lawn stay untouched.
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new()
	rng.seed=205010053
	for leaf in range(leaves):
		var angle:=float(leaf)*2.399963
		var direction:=Vector3(cos(angle),0,sin(angle))
		var side:=Vector3(-sin(angle),0,cos(angle))
		var root_offset:=direction*rng.randf_range(0.008,0.045)
		var reach:=rng.randf_range(0.22,0.42)
		var rise:=rng.randf_range(0.40,0.65)
		var width:=rng.randf_range(0.010,0.019)
		var color:=Color(0.14,0.30,0.045).lerp(Color(0.29,0.46,0.11),rng.randf())
		var rows:Array[PackedVector3Array]=[]
		for j in range(segments+1):
			var t:=float(j)/float(segments)
			var centre:=root_offset+direction*reach*pow(t,1.5)+Vector3.UP*rise*(2.7*t-2.1*t*t)
			var half_width:=width*0.5*pow(sin(PI*t),0.65)
			rows.append(PackedVector3Array([centre-side*half_width,centre+Vector3.UP*half_width*0.26,centre+side*half_width]))
		for j in range(segments):
			for strip in range(2):
				var a:=rows[j][strip]
				var b:=rows[j+1][strip]
				var c:=rows[j+1][strip+1]
				var d:=rows[j][strip+1]
				var points:=[a,b,c,a,c,d]
				var uv0:=Vector2(float(strip)*0.5,float(j)/float(segments))
				var uv1:=Vector2(float(strip)*0.5,float(j+1)/float(segments))
				var uv2:=Vector2(float(strip+1)*0.5,float(j+1)/float(segments))
				var uv3:=Vector2(float(strip+1)*0.5,float(j)/float(segments))
				var uvs:=[uv0,uv1,uv2,uv0,uv2,uv3]
				for index in range(6):
					tool.set_color(color)
					tool.set_uv(uvs[index])
					tool.add_vertex(points[index])
	tool.generate_normals()
	tool.generate_tangents()
	tool.index()
	var material:=StandardMaterial3D.new()
	material.resource_name="Midori_Japanese_Forest_Grass_Green"
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=0.9
	material.metallic_specular=0.16
	tool.set_material(material)
	return tool.commit()

func _forest_grass_material() -> ShaderMaterial:
	# The ribbon is already the leaf silhouette. Read only an opaque interior
	# strip of one photographed blade; its atlas alpha never cuts our geometry.
	var reference_mesh := _extract_upright_mesh()
	if reference_mesh == null: return _forest_grass_procedural_material()
	var reference := reference_mesh.surface_get_material(0) as StandardMaterial3D
	if reference == null or reference.albedo_texture == null or reference.normal_texture == null or not reference.normal_enabled:
		return _forest_grass_procedural_material()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D source_albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D source_normal_texture : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec4 source_albedo : source_color;
uniform vec2 source_albedo_size;
uniform float source_normal_scale;
varying vec2 tuft_variation;
varying float blade_age;
varying float tuft_view_distance;
void vertex() {
    vec2 root = MODEL_MATRIX[3].xz;
    vec3 seed = fract(vec3(root.x, root.y, root.x) * vec3(.1031, .11369, .13787));
    seed += dot(seed, seed.yzx + 19.19);
    tuft_variation = fract((seed.xx + seed.yz) * seed.zy);
    // Existing vertex color is constant on each blade, so ageing stays stable
    // within a blade and between its authored mesh LODs.
    blade_age = fract(COLOR.r * 5.37 + COLOR.g * 7.91 + tuft_variation.y * .33);
    tuft_view_distance = length(MODELVIEW_MATRIX[3].xyz);
}
void fragment() {
    float t = clamp(UV.y, 0.0, 1.0);
    float photo_centre = mix(.63, .455, t);
    float photo_half_width = mix(.11, .035, smoothstep(.45, 1.0, t));
    vec2 photo_uv = vec2(photo_centre + (UV.x * 2.0 - 1.0) * photo_half_width, .10 + .73 * t);
    vec3 photograph = texture(source_albedo_texture, photo_uv).rgb * source_albedo.rgb;
    vec3 photographed_normal = texture(source_normal_texture, photo_uv).rgb;
    float photographed_light = dot(photograph, vec3(.2126, .7152, .0722));
    // Preserve the real broad surface variation through its source mipmaps.
    // Only the extra fine vein emphasis fades when individual texels disappear.
    float photo_contrast = clamp(1.0 + (photographed_light - .235) * 3.4, .65, 1.45);
    vec3 leaf = COLOR.rgb * vec3(.64, .76, .74) * photo_contrast;
    leaf *= mix(vec3(.82, .92, .90), vec3(1.12, .98, .82), tuft_variation.x);
    leaf *= mix(.93, 1.07, blade_age);
    float root = smoothstep(.01, .26, t);
    leaf *= mix(.60, 1.0, root);
    float footprint = max(length(dFdx(photo_uv) * source_albedo_size), length(dFdy(photo_uv) * source_albedo_size));
    float fine_detail = (1.0 - smoothstep(4.0, 12.0, footprint)) * (1.0 - smoothstep(10.0, 30.0, tuft_view_distance));
    leaf *= 1.0 + clamp(photographed_normal.r * 2.0 - 1.0, -.5, .5) * .20 * fine_detail;
    float aged_tip = smoothstep(.72, .98, t) * smoothstep(.55, .95, blade_age);
    float leaf_light = dot(leaf, vec3(.2126, .7152, .0722));
    leaf = mix(leaf, leaf_light * vec3(1.13, .94, .68), aged_tip * .42);
    ALBEDO = max(leaf, vec3(0.0));
    NORMAL_MAP = photographed_normal;
    NORMAL_MAP_DEPTH = source_normal_scale;
    ROUGHNESS = clamp(.76 + (1.0 - photographed_light) * .12 + aged_tip * .05, .76, .94);
    SPECULAR = .24;
    AO = mix(.52, 1.0, root);
    AO_LIGHT_AFFECT = .35;
    BACKLIGHT = leaf * .10 * root;
}
"""
	var result := ShaderMaterial.new()
	result.resource_name = "Midori_Forest_Grass_Leaf_Detail_Photographic"
	result.shader = shader
	result.set_shader_parameter("source_albedo_texture", reference.albedo_texture)
	result.set_shader_parameter("source_normal_texture", reference.normal_texture)
	result.set_shader_parameter("source_albedo", reference.albedo_color)
	result.set_shader_parameter("source_albedo_size", Vector2(reference.albedo_texture.get_width(),reference.albedo_texture.get_height()))
	result.set_shader_parameter("source_normal_scale", reference.normal_scale * .55)
	result.set_meta("midori_grass_surface_v2", true)
	result.set_meta("midori_grass_family", "forest")
	result.set_meta("source_material", reference)
	result.set_meta("midori_grass_texture_reads", 2)
	result.set_meta("midori_grass_tip_direction", 1.0)
	return result


func _forest_grass_procedural_material() -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Material-only ageing; all mesh vertices, density and LODs remain intact.
uniform float variation_strength : hint_range(0.0,1.0) = 1.0;
varying vec2 grass_world;
varying vec2 grass_root;
void vertex() {
    grass_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
    grass_root = MODEL_MATRIX[3].xz;
}

float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float smooth_noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0)),f.x),f.y);
}
void fragment() {
	float grain=smooth_noise(UV*vec2(31.0,240.0));
	float mottling=smooth_noise(UV*vec2(5.0,17.0)+COLOR.rg*117.0);
	float veins=sin(UV.x*94.2478+0.16*sin(UV.y*12.0));
	float centre=exp(-abs(UV.x-0.5)*60.0);
	float edge=pow(abs(UV.x*2.0-1.0),10.0);
	float root=smoothstep(0.01,0.30,UV.y);
	vec3 green=COLOR.rgb*vec3(0.67,0.80,0.70);
	green*=mix(0.48,1.0,root)*(0.92+0.12*mottling+0.04*grain+0.035*veins);
	green=mix(green,green*vec3(1.18,1.06,0.85),centre*0.27+edge*0.12);
	float dry_tip=smoothstep(0.92,1.0,UV.y)*step(0.72,hash21(COLOR.rg*77.0));
	ALBEDO=mix(green,vec3(0.19,0.20,0.055),dry_tip*0.35);

    // Broad, softly blended age zones break up repeated patch appearance.
    // Finer tuft variation avoids tinting every leaf in a bed identically.
    float age_zone=smooth_noise(grass_world*0.075+vec2(17.3,8.1));
    float soil_zone=smooth_noise(grass_world*0.22+vec2(4.7,31.2));
    float tuft=hash21(grass_root*1.73+vec2(19.0,7.0));
    float age=clamp(age_zone*0.78+soil_zone*0.22,0.0,1.0);
    float mature=smoothstep(0.40,0.73,age);
    float fresh=1.0-smoothstep(0.24,0.49,age);
    vec3 varied=ALBEDO*mix(vec3(0.83,0.89,0.79),vec3(1.12,1.07,0.91),soil_zone);
    varied=mix(varied,varied*vec3(0.85,1.07,0.85),fresh*0.55);
    varied=mix(varied,vec3(0.155,0.171,0.052),mature*0.32);
    // Older individual blades retain green bases and acquire tawny tips.
    float tired=smoothstep(0.52,0.79,age)*smoothstep(0.40,0.86,tuft);
    float aged_tip=smoothstep(0.58,0.98,UV.y)*tired;
    float sun_fade=smoothstep(0.64,0.91,UV.y)*step(0.86,tuft)*(0.35+mature*0.65);
    varied=mix(varied,vec3(0.25,0.205,0.082),clamp(aged_tip*0.68+sun_fade*0.28,0.0,0.7));
    varied*=mix(0.92,1.04,tuft);
    ALBEDO=mix(ALBEDO,varied,variation_strength);
    // Preserve every blade and its age variation while restraining the lime
    // cast that dominates the shoreline foreground in daylight.
    ALBEDO*=vec3(.88,.90,1.08);
    ROUGHNESS=clamp(0.60+grain*0.16+edge*0.04+variation_strength*(mature*0.12+aged_tip*0.06),0.0,1.0);
	SPECULAR=0.24;
	AO=mix(0.52,1.0,root);
	AO_LIGHT_AFFECT=0.35;
	NORMAL_MAP=vec3(0.5+veins*0.035,0.5+(grain-0.5)*0.025,1.0);
	NORMAL_MAP_DEPTH=0.28;
	BACKLIGHT=green*0.10*root;
}
"""
	var material:=ShaderMaterial.new()
	material.resource_name="Midori_Forest_Grass_Leaf_Detail"
	material.shader=shader
	return material

func _grove_weight(x: float, z: float, tree_cells: Dictionary) -> float:
	var cell_x := floori(x / TREE_INDEX_CELL_M)
	var cell_z := floori(z / TREE_INDEX_CELL_M)
	var nearest := GROVE_GRASS_RADIUS_M
	for offset_z: int in range(-1,2):
		for offset_x: int in range(-1,2):
			for trunk: Vector2 in tree_cells.get(Vector2i(cell_x+offset_x,cell_z+offset_z),[]):
				nearest = minf(nearest,Vector2(x,z).distance_to(trunk))
	return 1.0-smoothstep(1.4,GROVE_GRASS_RADIUS_M,nearest)
