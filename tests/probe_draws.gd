extends SceneTree

# Measures draw calls and FPS at the west grove, then tries render-budget
# policies on small meshes (no shadows, distance culling) and reports each.
# godot --path . --script res://tests/probe_draws.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_draws_probe_qa.json"
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
	raid.player.global_position = Vector3(-164, 0.2, -40)
	raid.player.look_at(Vector3(-130, 0.2, -24))
	await _wait(4.0)
	var instances: Array[GeometryInstance3D] = []
	var by_owner := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			var geometry := node as GeometryInstance3D
			if not geometry.is_visible_in_tree(): continue
			instances.append(geometry)
			var top := node
			while top.get_parent() != scene and top.get_parent() != root and top.get_parent() != null: top = top.get_parent()
			by_owner[top.name] = int(by_owner.get(top.name, 0)) + 1
	var owners := by_owner.keys()
	owners.sort_custom(func(a, b) -> bool: return by_owner[a] > by_owner[b])
	for owner: String in owners.slice(0, 15):
		print("DRAW_OWNER %6d  %s" % [by_owner[owner], owner])
	var sizes := {"tiny<0.6": 0, "small<1.5": 0, "medium<4": 0, "large": 0}
	var shadowed := 0
	var ranged := 0
	for geometry: GeometryInstance3D in instances:
		var extent := _extent(geometry)
		if extent < .6: sizes["tiny<0.6"] += 1
		elif extent < 1.5: sizes["small<1.5"] += 1
		elif extent < 4.0: sizes["medium<4"] += 1
		else: sizes["large"] += 1
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadowed += 1
		if geometry.visibility_range_end > 0.0: ranged += 1
	print("DRAW_SIZES %s instances=%d shadowed=%d with_range=%d" % [sizes, instances.size(), shadowed, ranged])
	_report("baseline", await _measure())
	var saved := []
	for geometry: GeometryInstance3D in instances:
		saved.append([geometry.cast_shadow, geometry.visibility_range_end, geometry.visibility_range_end_margin, geometry.visibility_range_fade_mode])
	# A: small things stop casting sun shadows.
	for geometry: GeometryInstance3D in instances:
		if _extent(geometry) < 1.5: geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _wait(1.0)
	_report("A small no shadow", await _measure())
	# B: plus distance culling for small and medium things.
	for geometry: GeometryInstance3D in instances:
		var extent := _extent(geometry)
		var limit := 45.0 if extent < .6 else 70.0 if extent < 1.5 else 140.0 if extent < 4.0 else 0.0
		if limit > 0.0 and (geometry.visibility_range_end <= 0.0 or geometry.visibility_range_end > limit):
			geometry.visibility_range_end = limit
			geometry.visibility_range_end_margin = limit * .12
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	await _wait(1.0)
	_report("B + distance culling", await _measure())
	print("DRAW_DONE")
	quit()

func _extent(geometry: GeometryInstance3D) -> float:
	var box := geometry.get_aabb()
	var scale := geometry.global_transform.basis.get_scale()
	return (box.size * scale).length()

func _report(label: String, result: Dictionary) -> void:
	print("DRAW_RESULT %-22s fps=%.1f draws=%d prims=%d objects=%d" % [label, result.fps, result.draws, result.prims, result.objects])

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _measure(seconds: float = 3.0) -> Dictionary:
	var frames := 0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until or frames < 4:
		await process_frame
		frames += 1
	return {
		"fps": frames / ((Time.get_ticks_usec() - started) / 1000000.0),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}
