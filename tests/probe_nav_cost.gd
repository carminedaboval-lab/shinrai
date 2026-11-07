extends SceneTree

# Times the police-drone route calls on live drones. Headless.
# godot --headless --path . --script res://tests/probe_nav_cost.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_nav_probe_qa.json"
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
	var drones: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("patrol_actor.gd"): drones.append(node)
	var navigation: RefCounted = raid.navigation
	print("NAV graph_points=%d shoreline_vertices=%d" % [navigation.walk_graph.get_point_count(), navigation.shoreline.size()])
	var totals := {}
	var counts := {}
	var worst := {}
	var statuses := {}
	var note := func(label: String, us: int) -> void:
		totals[label] = int(totals.get(label, 0)) + us
		counts[label] = int(counts.get(label, 0)) + 1
		worst[label] = maxi(int(worst.get(label, 0)), us)
	for round_index: int in 25:
		for i in 60:
			await physics_frame
		for drone: Node in drones:
			if not is_instance_valid(drone): continue
			var status := str(drone.get("nav_status"))
			statuses[status] = int(statuses.get(status, 0)) + 1
			var goal: Vector3 = drone.get("nav_goal")
			if not goal.is_finite(): continue
			var from: Vector3 = drone.global_position
			var t0 := Time.get_ticks_usec()
			var id: int = navigation._nearest_graph_point(from)
			note.call("nearest_graph_point(from)", Time.get_ticks_usec() - t0)
			t0 = Time.get_ticks_usec()
			var goal_id: int = navigation._nearest_graph_point(goal)
			note.call("nearest_graph_point(goal)", Time.get_ticks_usec() - t0)
			t0 = Time.get_ticks_usec()
			if id >= 0 and goal_id >= 0: navigation.walk_graph.get_point_path(id, goal_id)
			note.call("astar get_point_path", Time.get_ticks_usec() - t0)
			t0 = Time.get_ticks_usec()
			var route: PackedVector3Array = raid.get_path_world(from, goal)
			note.call("get_path_world total", Time.get_ticks_usec() - t0)
			if route.size() > 0:
				t0 = Time.get_ticks_usec()
				drone._navigation_link_clear(from, route[0])
				note.call("navigation_link_clear", Time.get_ticks_usec() - t0)
			var nav_path: PackedVector3Array = drone.get("nav_path")
			if nav_path.size() > 0:
				t0 = Time.get_ticks_usec()
				drone.obstacle_routes.plan(drone, nav_path)
				note.call("obstacle_routes.plan", Time.get_ticks_usec() - t0)
	print("NAV statuses=%s" % statuses)
	for label: String in totals:
		print("NAV %-30s calls=%d mean=%.2fms worst=%.2fms" % [label, counts[label], totals[label] / 1000.0 / counts[label], worst[label] / 1000.0])
	quit()
