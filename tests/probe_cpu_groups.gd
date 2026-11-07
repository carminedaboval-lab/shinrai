extends SceneTree

# Median frame time with each script group's own process callbacks turned off
# (children keep running). Medians ignore stalls, so small costs are visible.
# godot --headless --path . --script res://tests/probe_cpu_groups.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_cpu_group_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.global_position = Vector3(-164, 0.2, -40)
	await _median(5.0)
	var groups := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not (node.is_processing() or node.is_physics_processing()): continue
		var script: Script = node.get_script()
		var key: String = script.resource_path if script != null else node.get_class()
		if key.is_empty(): key = "<inline>"
		if not groups.has(key): groups[key] = []
		groups[key].append(node)
	var base := await _median(5.0)
	print("CPU_BASE median=%.2fms" % base)
	for key: String in groups:
		var nodes: Array = groups[key]
		var states := []
		for node: Node in nodes:
			states.append([node.is_processing(), node.is_physics_processing()])
			node.set_process(false)
			node.set_physics_process(false)
		var result := await _median(3.0)
		for i in nodes.size():
			if is_instance_valid(nodes[i]):
				nodes[i].set_process(states[i][0])
				nodes[i].set_physics_process(states[i][1])
		var saved := base - result
		if absf(saved) >= .25:
			print("CPU_GROUP %-72s n=%d saved=%.2fms" % [key, nodes.size(), saved])
	print("CPU_END median=%.2fms" % await _median(5.0))
	quit()

func _median(seconds: float) -> float:
	var samples := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	return samples[samples.size() / 2] if not samples.is_empty() else 0.0
