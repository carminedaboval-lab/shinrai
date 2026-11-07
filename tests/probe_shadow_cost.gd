extends SceneTree

# At the south lawn, turns off sun-shadow casting for one group at a time and
# reports the triangles and FPS it saves. No game files are modified.
# godot --path . --script res://tests/probe_shadow_cost.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_shadow_probe_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	raid.player.global_position = Vector3(-70, 0.2, 108)
	raid.player.look_at(Vector3(-42, 0.2, 90))
	await _wait(4.0)
	var base := await _stats()
	print("SHADOW_BASE fps=%.1f draws=%d prims=%d" % [base.fps, base.draws, base.prims])
	for group_name: String in ["MidoriDistanceDetail", "MidoriPark_440x360m_ProceduralLayout", "FullerWalkShoulders", "MidoriSouthStreet", "MidoriJapanesePathLamps", "PoliceDroneGroups", "Midori2050Identity"]:
		var group := scene.get_node_or_null(group_name)
		if group == null: continue
		var touched := []
		for node: Node in group.find_children("*", "GeometryInstance3D", true, false):
			var geometry := node as GeometryInstance3D
			if geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
			touched.append([geometry, geometry.cast_shadow])
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await _wait(1.5)
		var result := await _stats()
		for entry: Array in touched:
			if is_instance_valid(entry[0]): entry[0].cast_shadow = entry[1]
		print("SHADOW %-42s casters=%d prims=-%d fps=%.1f" % [group_name, touched.size(), base.prims - result.prims, result.fps])
		await _wait(1.0)
	var sun: DirectionalLight3D = scene.park_directional_light
	for distance: float in [60.0, 45.0]:
		sun.directional_shadow_max_distance = distance
		await _wait(1.5)
		var result := await _stats()
		print("SHADOW max_distance_%d prims=-%d fps=%.1f" % [int(distance), base.prims - result.prims, result.fps])
	print("SHADOW_DONE")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _stats(seconds: float = 2.5) -> Dictionary:
	var frames := 0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until or frames < 3:
		await process_frame
		frames += 1
	return {
		"fps": frames / ((Time.get_ticks_usec() - started) / 1000000.0),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}
