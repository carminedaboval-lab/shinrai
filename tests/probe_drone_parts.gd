extends SceneTree

# Inside every police drone, pauses one kind of node at a time (animation,
# skeleton, lights...) and measures headless FPS, to find what costs the most.
# godot --headless --path . --script res://tests/probe_drone_parts.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_drone_parts_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.global_position = Vector3(-164, 0.2, -40)
	await _wait(3.0)
	var drones: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("patrol_actor.gd"): drones.append(node)
	var by_class := {}
	var by_script := {}
	for drone: Node in drones:
		var inner: Array[Node] = [drone]
		while not inner.is_empty():
			var node: Node = inner.pop_back()
			inner.append_array(node.get_children())
			if node == drone: continue
			if not by_class.has(node.get_class()): by_class[node.get_class()] = []
			by_class[node.get_class()].append(node)
			var script: Script = node.get_script()
			if script != null and (node.is_processing() or node.is_physics_processing()):
				if not by_script.has(script.resource_path): by_script[script.resource_path] = []
				by_script[script.resource_path].append(node)
	for key: String in by_class:
		print("PART_CLASS %-28s %d" % [key, by_class[key].size()])
	var base := await _fps()
	print("PART_BASE fps=%.1f" % base)
	var groups := {}
	for key: String in ["AnimationPlayer", "AnimationTree", "Skeleton3D", "OmniLight3D", "SpotLight3D", "GPUParticles3D", "CPUParticles3D", "AudioStreamPlayer3D", "Area3D"]:
		if by_class.has(key): groups["class " + key] = by_class[key]
	for key: String in by_script:
		groups["script " + key] = by_script[key]
	for label: String in groups:
		var nodes: Array = groups[label]
		var modes := []
		for node: Node in nodes:
			modes.append(node.process_mode)
			node.process_mode = Node.PROCESS_MODE_DISABLED
		await _wait(0.5)
		var fps := await _fps()
		for i in nodes.size():
			if is_instance_valid(nodes[i]): nodes[i].process_mode = modes[i]
		print("PART_TOGGLE %-70s n=%d fps=%.1f" % [label, nodes.size(), fps])
	var all_modes := []
	for drone: Node in drones:
		all_modes.append(drone.process_mode)
		drone.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(0.5)
	print("PART_TOGGLE %-70s n=%d fps=%.1f" % ["whole drones", drones.size(), await _fps()])
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _fps(seconds: float = 2.5) -> float:
	var frames := 0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - started) / 1000000.0)
