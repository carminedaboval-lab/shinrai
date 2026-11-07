extends SceneTree

# Counts long frames over a fixed window with each suspect paused in turn, to
# find what causes the multi-hundred-millisecond stalls in a raid.
# godot --headless --path . --script res://tests/probe_stalls.gd

const WINDOW := 50.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_stall_probe_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	raid.player.global_position = Vector3(-164, 0.2, -40)
	await _window("warmup (ignored)", 8.0)
	await _window("everything on", WINDOW)
	for name: String in ["PoliceDroneGroups", "ScavPatrolCrew", "MidoriCloudCache", "MidoriNearPlantShadows"]:
		var node := scene.get_node_or_null(name)
		if node == null:
			print("STALL missing %s" % name)
			continue
		node.process_mode = Node.PROCESS_MODE_DISABLED
		await _window(name + " paused", WINDOW)
		node.process_mode = Node.PROCESS_MODE_INHERIT
	await _window("everything on again", WINDOW)
	quit()

func _window(label: String, seconds: float) -> void:
	var over_50 := 0
	var over_250 := 0
	var worst := 0.0
	var stalled := 0.0
	var frames := 0
	var previous := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - previous) / 1000.0
		previous = now
		frames += 1
		worst = maxf(worst, ms)
		if ms > 50.0:
			over_50 += 1
			stalled += ms
		if ms > 250.0: over_250 += 1
	print("STALL %-36s frames=%d >50ms=%d >250ms=%d worst=%.0fms stalled=%.1fs" % [label, frames, over_50, over_250, worst, stalled / 1000.0])
