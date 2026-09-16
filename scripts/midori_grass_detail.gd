extends Node

# Midori Park near-ground vegetation scatter.
# The former procedural blade cards are replaced by the uploaded Meshy clump.
# The source model is optimized for repeated use, then instanced through
# spatially chunked MultiMeshes so only nearby areas need to render.

const GroundClumpScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_meshy_ground_clump_v1.glb")

const PARK_HALF := Vector2(110.0, 90.0)
const CLUMP_INSTANCE_COUNT := 9000
const CHUNKS_X := 8
const CHUNKS_Z := 6
const VISIBILITY_RANGE_M := 52.0
const VISIBILITY_MARGIN_M := 10.0
const RNG_SEED := 20260916

# Measured from the optimized uploaded GLB.
const SOURCE_HEIGHT_M := 0.796875
const SOURCE_BOTTOM_Y := -0.378906
const MIN_CLUMP_HEIGHT_M := 0.055
const MAX_CLUMP_HEIGHT_M := 0.120
const GROUND_SURFACE_Y := 0.008

var _installed := false


func _ready() -> void:
	call_deferred("_install_ground_clumps")


func _install_ground_clumps() -> void:
	if _installed:
		return

	var scene := get_tree().current_scene
	if scene == null:
		call_deferred("_install_ground_clumps")
		return
	if String(scene.name) != "MidoriParkSizeBlockout":
		return

	var existing := scene.get_node_or_null("MidoriGrassDetail")
	if existing != null:
		_installed = true
		return

	var clump_mesh := _extract_source_mesh()
	if clump_mesh == null:
		push_warning("Midori ground detail: Meshy clump mesh was not found")
		return

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
	var max_attempts := CLUMP_INSTANCE_COUNT * 20

	while placed < CLUMP_INSTANCE_COUNT and attempts < max_attempts:
		attempts += 1
		var x := rng.randf_range(-PARK_HALF.x + 2.0, PARK_HALF.x - 2.0)
		var z := rng.randf_range(-PARK_HALF.y + 2.0, PARK_HALF.y - 2.0)
		if not _is_lawn_position(x, z):
			continue

		var chunk_x := clampi(int(floor((x + PARK_HALF.x) / chunk_width)), 0, CHUNKS_X - 1)
		var chunk_z := clampi(int(floor((z + PARK_HALF.y) / chunk_depth)), 0, CHUNKS_Z - 1)
		var chunk_index := chunk_z * CHUNKS_X + chunk_x
		var center_x := -PARK_HALF.x + (float(chunk_x) + 0.5) * chunk_width
		var center_z := -PARK_HALF.y + (float(chunk_z) + 0.5) * chunk_depth

		var target_height := rng.randf_range(MIN_CLUMP_HEIGHT_M, MAX_CLUMP_HEIGHT_M)
		var uniform_scale := target_height / SOURCE_HEIGHT_M
		var width_variation := rng.randf_range(0.86, 1.16)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw)
		basis = basis.scaled(Vector3(
			uniform_scale * width_variation,
			uniform_scale,
			uniform_scale * width_variation
		))

		# The Meshy model pivot is near its center. Lift each instance by the
		# measured source-bottom offset so the leaves sit on the forest ground.
		var grounded_y := GROUND_SURFACE_Y - SOURCE_BOTTOM_Y * uniform_scale
		grounded_y += rng.randf_range(-0.002, 0.002)
		var local_position := Vector3(x - center_x, grounded_y, z - center_z)
		buckets[chunk_index].append(Transform3D(basis, local_position))
		placed += 1

	var root := Node3D.new()
	root.name = "MidoriGrassDetail"
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
				Vector3(chunk_width + 2.0, MAX_CLUMP_HEIGHT_M + 0.08, chunk_depth + 2.0)
			)

			for transform_index: int in range(transforms.size()):
				multimesh.set_instance_transform(transform_index, transforms[transform_index])

			var clumps := MultiMeshInstance3D.new()
			clumps.name = "MeshyGroundClumps"
			clumps.multimesh = multimesh
			clumps.visibility_range_end = VISIBILITY_RANGE_M
			clumps.visibility_range_end_margin = VISIBILITY_MARGIN_M
			clumps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			clumps.extra_cull_margin = 3.0
			chunk_root.add_child(clumps)

	_installed = true
	print("Midori Meshy ground clumps installed: %d instances" % placed)


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


func _is_lawn_position(x: float, z: float) -> bool:
	# Perimeter loop path.
	if abs(z + 77.0) < 3.4 and abs(x) < 99.5:
		return false
	if abs(z - 77.0) < 3.4 and abs(x) < 99.5:
		return false
	if abs(x + 97.0) < 3.4 and abs(z) < 79.5:
		return false
	if abs(x - 97.0) < 3.4 and abs(z) < 79.5:
		return false

	# Main cross paths.
	if abs(x + 37.0) < 3.2 and abs(z) < 77.0:
		return false
	if abs(z - 42.0) < 3.2 and abs(x) < 97.0:
		return false

	# Lake lobes, with a safety margin around their visible surfaces.
	if _inside_ellipse(x, z, 27.0, -10.0, 57.0, 38.0):
		return false
	if _inside_ellipse(x, z, 47.0, -42.0, 37.0, 26.0):
		return false
	if _inside_ellipse(x, z, 8.0, 20.0, 33.0, 23.0):
		return false

	# Current colored zone placeholders.
	if _inside_box(x, z, -70.0, -43.0, 59.0, 40.0):
		return false
	if _inside_box(x, z, -72.0, 45.0, 36.0, 30.0):
		return false
	if _inside_box(x, z, 62.0, 51.0, 48.0, 38.0):
		return false
	if _inside_box(x, z, 76.0, -64.0, 24.0, 18.0):
		return false

	return true


func _inside_ellipse(x: float, z: float, center_x: float, center_z: float, radius_x: float, radius_z: float) -> bool:
	var dx := (x - center_x) / radius_x
	var dz := (z - center_z) / radius_z
	return dx * dx + dz * dz <= 1.0


func _inside_box(x: float, z: float, center_x: float, center_z: float, width: float, depth: float) -> bool:
	return abs(x - center_x) <= width * 0.5 and abs(z - center_z) <= depth * 0.5
