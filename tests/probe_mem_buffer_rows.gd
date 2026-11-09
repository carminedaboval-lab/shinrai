extends SceneTree

# Memory-fix probe (BUFFERS role): checks, under the real renderer and without a
# park, that the MultiMesh TRANSFORM_3D buffer row layout the terrain lift and the
# desire-path trim rely on is the one the renderer uses, and that reading a buffer
# once and assigning a buffer once gives bit-identical rows to the per-instance
# setters. Prints BUFFER_ROWS lines and quits 0 (all true) or 1.
#   godot --path . --script res://tests/probe_mem_buffer_rows.gd
# Investigation only: edits nothing, touches no save.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var Terrain: Script = load("res://scripts/midori_terrain.gd")
	var Trails: Script = load("res://scripts/midori_desire_paths.gd")
	var terrain_ok: bool = Terrain.call("_buffer_rows_verified")
	var trails_ok: bool = Trails.call("_buffer_rows_verified")
	# Round trip on a batch with colours and custom data: per-instance setters on
	# one MultiMesh, the whole buffer assigned once on another, same floats.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var count := 64
	# A mesh on both batches: per-instance setters make the renderer rebuild the
	# batch AABB, which logs an error for a mesh-less MultiMesh.
	var mesh := BoxMesh.new()
	var a := MultiMesh.new()
	a.transform_format = MultiMesh.TRANSFORM_3D
	a.use_colors = true
	a.use_custom_data = true
	a.mesh = mesh
	a.instance_count = count
	var expected: Array[Transform3D] = []
	for i in range(count):
		var basis := Basis.from_euler(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-PI, PI), rng.randf_range(-1.0, 1.0))).scaled(Vector3.ONE * rng.randf_range(0.6, 1.7))
		var t := Transform3D(basis, Vector3(rng.randf_range(-200.0, 200.0), rng.randf_range(-5.0, 30.0), rng.randf_range(-200.0, 200.0)))
		a.set_instance_transform(i, t)
		a.set_instance_color(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
		a.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
		expected.append(t)
	var buffer: PackedFloat32Array = a.buffer
	var stride := 20
	var size_ok := buffer.size() == stride * count
	var rows_ok := size_ok
	if size_ok:
		for i in range(count):
			var from_rows: Transform3D = Trails.call("_row_transform", buffer, i * stride)
			if from_rows != a.get_instance_transform(i): rows_ok = false
	var b := MultiMesh.new()
	b.transform_format = MultiMesh.TRANSFORM_3D
	b.use_colors = true
	b.use_custom_data = true
	b.mesh = mesh
	b.instance_count = count
	if size_ok: b.buffer = buffer
	var copy_ok := size_ok and b.buffer == buffer
	if copy_ok:
		for i in range(count):
			if b.get_instance_transform(i) != a.get_instance_transform(i) or b.get_instance_color(i) != a.get_instance_color(i) or b.get_instance_custom_data(i) != a.get_instance_custom_data(i): copy_ok = false
	print("BUFFER_ROWS terrain_verified=%s trails_verified=%s stride20_size_ok=%s row_transform_matches_getter=%s buffer_copy_bit_identical=%s" % [terrain_ok, trails_ok, size_ok, rows_ok, copy_ok])
	var all_ok := terrain_ok and trails_ok and size_ok and rows_ok and copy_ok
	print("BUFFER_ROWS result=%s" % ("PASS" if all_ok else "FAIL"))
	quit(0 if all_ok else 1)
