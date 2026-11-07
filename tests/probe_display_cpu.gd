extends SceneTree

# In a real window with the main 3D view off, pauses each node that only runs
# with a display, plus each park child, to find the display-only CPU cost.
# godot --path . --script res://tests/probe_display_cpu.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_display_probe_qa.json"
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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _wait(5.0)
	var vp := root.get_viewport()
	vp.disable_3d = true
	await _wait(1.0)
	var base := await _median("3D off base")
	var candidates: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node == raid or node == raid.player or node == scene: continue
		if node.is_processing() or node.is_physics_processing() or node.is_processing_internal() or node.is_physics_processing_internal():
			candidates.append(node)
	var groups := {}
	for node: Node in candidates:
		var script: Script = node.get_script()
		var key: String = script.resource_path.get_file() if script != null else node.get_class()
		if key.is_empty(): key = "<inline>"
		if not groups.has(key): groups[key] = []
		groups[key].append(node)
	var keys := groups.keys()
	keys.sort_custom(func(a, b) -> bool: return groups[a].size() > groups[b].size())
	for key: String in keys.slice(0, 40):
		print("DISPLAY_GROUP %5d %s" % [groups[key].size(), key])
	for key: String in keys:
		var nodes: Array = groups[key]
		for node: Node in nodes:
			if is_instance_valid(node): node.set_meta("probe_mode", node.process_mode); node.process_mode = Node.PROCESS_MODE_DISABLED
		await _wait(.4)
		var result := await _median("", 1.4)
		for node: Node in nodes:
			if is_instance_valid(node): node.process_mode = node.get_meta("probe_mode")
		if base - result >= 1.0:
			print("DISPLAY_SAVE %-46s n=%d saved=%.1fms" % [key, nodes.size(), base - result])
	await _median("3D off end")
	print("DISPLAY_DONE")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _median(label: String, seconds: float = 3.0) -> float:
	var samples := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var median := samples[samples.size() / 2]
	if not label.is_empty(): print("DISPLAY %-20s median=%.1fms" % [label, median])
	return median
