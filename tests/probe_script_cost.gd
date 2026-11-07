extends SceneTree

# Groups every node that runs _process/_physics_process by script, then pauses
# each heavy group in turn to measure its script and physics cost per frame.
# godot --path . --script res://tests/probe_script_cost.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_script_probe_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	raid.player.global_position = Vector3(-164, 0.2, -40)
	raid.player.look_at(Vector3(-130, 0.2, -24))
	await _wait(4.0)
	print("PHYS active=%d pairs=%d islands=%d nodes=%d" % [
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var groups := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not (node.is_processing() or node.is_physics_processing()):
			continue
		var script: Script = node.get_script()
		var key: String = script.resource_path if script != null else node.get_class()
		if key.is_empty(): key = "<inline>"
		if not groups.has(key): groups[key] = []
		groups[key].append(node)
	var keys := groups.keys()
	keys.sort_custom(func(a, b) -> bool: return groups[a].size() > groups[b].size())
	for key: String in keys.slice(0, 25):
		print("PROC_GROUP %5d  %s" % [groups[key].size(), key])
	var base := await _measure()
	print("SCRIPT_BASE fps=%.1f process=%.1fms physics=%.1fms" % [base.fps, base.process, base.physics])
	for key: String in keys:
		var nodes: Array = groups[key]
		if key.ends_with("extraction_run.gd") or key.ends_with("player.gd"):
			continue
		var modes := []
		for node: Node in nodes:
			modes.append(node.process_mode)
			node.process_mode = Node.PROCESS_MODE_DISABLED
		await _wait(0.5)
		var result := await _measure()
		for i in nodes.size():
			if is_instance_valid(nodes[i]): nodes[i].process_mode = modes[i]
		var saved_process: float = base.process - result.process
		var saved_physics: float = base.physics - result.physics
		if saved_process > 2.0 or saved_physics > 2.0:
			print("SCRIPT_COST %-75s n=%d process-%.1fms physics-%.1fms fps=%.1f" % [key, nodes.size(), saved_process, saved_physics, result.fps])
	print("SCRIPT_DONE")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _measure(seconds: float = 1.5) -> Dictionary:
	var frames := 0
	var process := 0.0
	var physics := 0.0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until or frames < 4:
		await process_frame
		frames += 1
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return {"fps": frames / ((Time.get_ticks_usec() - started) / 1000000.0), "process": process / frames, "physics": physics / frames}
