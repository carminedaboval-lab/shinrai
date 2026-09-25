extends Node

const LakeGeometry = preload("res://scripts/midori_lake_geometry.gd")

# Midori Park near-ground vegetation scatter using the uploaded Meshy clump.
# The clumps are kept short and broad so they read as natural lawn/forest-floor
# detail rather than isolated weeds. Distribution is slightly patchy instead of
# perfectly uniform, while its masks follow the final path, lake, and zone plan.

const GroundClumpScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_meshy_ground_clump_v1.glb")

const LAYOUT_SCALE := 2.0
const PARK_HALF := Vector2(220.0, 180.0)
const CLUMP_INSTANCE_COUNT := 22000
const CHUNKS_X := 8
const CHUNKS_Z := 6
const RNG_SEED := 20260916
const DETAIL_VERSION := 20
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

var _installed_scene_id: int = 0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_install_ground_clumps")


func _on_node_added(_node: Node) -> void:
	call_deferred("_install_ground_clumps")


func _install_ground_clumps() -> void:
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

	var fallback_material: Material = null
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
			if fallback_material != null:
				clumps.material_override = fallback_material
			chunk_root.add_child(clumps)

	_installed_scene_id = scene_id
	print("Midori Meshy ground clumps installed: %d naturalized instances" % placed)


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
		{"points":SOUTH_BRIDGE_APPROACH, "half_width":2.15},
		{"points":PAVILION_LINK_ROUTE, "half_width":2.00},
		{"points":VIEWING_DECK_APPROACH_ROUTE, "half_width":2.05},
	]
	for spec: Dictionary in route_specs:
		if _near_polyline(point, spec["points"], float(spec["half_width"])):
			return false

	# One concept-matched shoreline replaces the three legacy ellipse masks.
	if Geometry2D.is_point_in_polygon(point, PackedVector2Array(lake_contour)):
		return false
	if _near_closed_polyline(point, lake_contour, LAKE_SHORE_GRASS_BUFFER_M):
		return false
	if _near_polyline(point, FUTURE_BRIDGE_WEST, 2.6):
		return false
	if _near_polyline(point, FUTURE_BRIDGE_NORTH_EAST, 2.6):
		return false
	if _near_polyline(point, FUTURE_BRIDGE_SOUTH, 2.6):
		return false

	# Keep clumps off the pitch and its immediate player approach, while letting
	# the wider sports lawn read as meadow rather than a bare rectangle.
	if _inside_box(authored_x, authored_z, -70.0, -43.0, 13.0, 9.5):
		return false
	if _inside_box(authored_x, authored_z, -72.0, 45.0, 36.0, 30.0):
		return false
	if _inside_box(authored_x, authored_z, 82.0, 68.0, 38.0, 30.0):
		return false
	if _inside_box(authored_x, authored_z, 76.0, -73.0, 24.0, 18.0):
		return false

	return true


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
