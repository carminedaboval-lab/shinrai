extends SceneTree

# Logs CPU frame time and enemy state over a raid with an idle player, then
# pauses each enemy group to see what the slow phase is made of.
# godot --headless --path . --script res://tests/probe_timeline.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_timeline_probe_qa.json"
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
	for step: int in 30:
		var ms := await _frame_ms(3.0)
		var states := {}
		var nearest := INF
		for hostile: Node in get_nodes_in_group("extraction_hostiles"):
			var awareness := hostile.get_node_or_null("Awareness")
			var state := str(awareness.get("state")) if awareness != null else str(hostile.get("state"))
			states[state] = int(states.get(state, 0)) + 1
			nearest = minf(nearest, (hostile as Node3D).global_position.distance_to(raid.player.global_position))
		print("TIMELINE t=%02ds frame=%.1fms phase=%s hp=%.0f nearest=%.0fm states=%s" % [step * 3, ms, raid.phase, raid.player.health, nearest, states])
	var groups := {"PoliceDroneGroups": scene.get_node_or_null("PoliceDroneGroups"), "ScavPatrolCrew": scene.get_node_or_null("ScavPatrolCrew")}
	print("TIMELINE_END frame=%.1fms" % await _frame_ms(3.0))
	for label: String in groups:
		var group: Node = groups[label]
		if group == null: continue
		group.process_mode = Node.PROCESS_MODE_DISABLED
		print("TIMELINE_OFF %s frame=%.1fms" % [label, await _frame_ms(3.0)])
		group.process_mode = Node.PROCESS_MODE_INHERIT
	quit()

func _frame_ms(seconds: float) -> float:
	var frames := 0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		frames += 1
	return (Time.get_ticks_usec() - started) / 1000.0 / maxi(frames, 1)
