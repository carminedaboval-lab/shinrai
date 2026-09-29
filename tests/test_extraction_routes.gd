extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_walks")

func run_walks() -> void:
	# Accelerate wall time while retaining the normal 1/60s simulation step.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var scene: Node3D = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_route_qa_only.json"
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var extracts_before: int = raid.profile.data.extracts
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await physics_frame
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		push_error("Route test could not deploy")
		quit(1)
		return
	# This test isolates player traversal and relay interaction. Combat is
	# exercised by test_k17_integration.gd; walking unarmed past six patrols
	# would measure survival instead of path connectivity.
	raid._clear_enemies()
	await physics_frame
	var destinations: Array[Vector3] = []
	for site: Dictionary in raid.sites:
		if site.kind == "relay":
			destinations.append(site.position)
	destinations.append(raid.exits[0].position)
	var origin: Vector3 = raid.player.position
	for goal: Vector3 in destinations:
		raid.player.position = origin
		raid.player.velocity = Vector3.ZERO
		var route: PackedVector3Array = raid.navigation.path(origin, goal)
		var ok := not route.is_empty()
		var waypoint := 1
		var ticks := 0
		var stagnant := 0
		var previous: Vector3 = raid.player.position
		var key := InputEventKey.new()
		key.keycode = KEY_W
		key.physical_keycode = KEY_W
		key.pressed = true
		Input.parse_input_event(key)
		while waypoint < route.size() and ticks < 18000:
			var point: Vector3 = route[waypoint]
			if Vector2(raid.player.position.x, raid.player.position.z).distance_to(Vector2(point.x, point.z)) < 0.65:
				waypoint += 1
				continue
			raid.player.look_at(Vector3(point.x, raid.player.position.y, point.z))
			await physics_frame
			ticks += 1
			if raid.player.position.distance_to(previous) < 0.008:
				stagnant += 1
			else:
				stagnant = 0
			previous = raid.player.position
			if stagnant > 90:
				ok = false
				print("ROUTE_STUCK: ", raid.player.position, " next ", point)
				break
		key.pressed = false
		Input.parse_input_event(key)
		ok = ok and waypoint >= route.size()
		if not ok:
			failures += 1
		print("WALK_", "PASS" if ok else "FAIL", ": ", origin, " -> ", goal, " ticks=", ticks)
		for site: Dictionary in raid.sites:
			if site.kind == "relay" and site.position == goal and ok:
				var interact := InputEventKey.new()
				interact.keycode = KEY_E
				interact.physical_keycode = KEY_E
				interact.pressed = true
				Input.parse_input_event(interact)
				for tick: int in range(270):
					await physics_frame
				interact.pressed = false
				Input.parse_input_event(interact)
				print("RELAY_", "PASS" if site.done else "FAIL", ": ", site.id)
				if not site.done:
					failures += 1
		origin = raid.player.position
	for tick: int in range(1000):
		if raid.phase == raid.Phase.RESULT:
			break
		await physics_frame
	var extracted: bool = raid.phase == raid.Phase.RESULT and raid.relays == 3 and int(raid.profile.data.extracts) == extracts_before + 1
	print("FULL_RUN_EXTRACTION: ", "PASS" if extracted else "FAIL")
	if not extracted:
		failures += 1
		raid.finish_run(false, "Automated route test completed")
	print("ROUTE_WALK_RESULT: ", failures, " failures")
	quit(0 if failures == 0 else 1)
