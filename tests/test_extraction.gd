extends SceneTree

var failures: Array[String] = []
var stage := ""
var render := false

func _initialize() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	call_deferred("run_tests")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error("TEST FAILED: " + description)
	else:
		print("PASS: ", description)

func run_tests() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_extraction_automated_test.json"
	# This test owns only its uniquely named QA save, never the player's profile.
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	check(raid.phase == raid.Phase.HQ, "Park prepares and reaches HQ")
	check(raid.sites.filter(func(s: Dictionary) -> bool: return s.kind == "relay").size() == 3, "Three real lamp relays registered")
	check(raid.sites.size() >= 9, "Existing benches provide searchable sites")
	check(raid.enemy_visual == null, "No placeholder or invisible enemy is spawned")
	check(raid.approach_cover.placements.size() >= 6 and raid.approach_cover.placements.size() <= 12, "Bounded supplied-asset cover pass installed")
	var cover_clear := true
	for point: Vector3 in raid.approach_cover.placements:
		cover_clear = cover_clear and scene._is_vegetation_clear(Vector3(point.x / 2.0, 0, point.z / 2.0), 1.4)
		for site: Dictionary in raid.sites:
			cover_clear = cover_clear and point.distance_to(site.position) >= 9.0
	check(cover_clear, "Cover keeps routes, shorelines and interaction approaches clear")
	check(not raid.approach_cover.find_children("*", "CollisionShape3D", true, false).is_empty(), "Supplied rock meshes have physical collision")
	var cover_hits := 0
	for point: Vector3 in raid.approach_cover.placements:
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point - Vector3.UP, 1)
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and raid.approach_cover.is_ancestor_of(hit.collider):
			cover_hits += 1
	check(cover_hits == raid.approach_cover.placements.size(), "Raycasts hit all placed cover clusters, not the ground underneath")
	for crossing: Dictionary in [
		{"id": "Main", "route": scene.FUTURE_BRIDGE_WEST},
		{"id": "North", "route": scene.FUTURE_BRIDGE_NORTH_EAST},
		{"id": "South", "route": scene.FUTURE_BRIDGE_SOUTH},
	]:
		var route: Array[Vector2] = crossing.route
		var midpoint: Vector2 = (route[0] + route[route.size() - 1]) * scene.LAYOUT_SCALE * 0.5
		var walkway := scene.find_child("BridgeWalkway_%s" % crossing.id, true, false)
		check(walkway != null, "%s bridge has a collision walkway" % crossing.id)
		check(not raid.navigation.is_water(midpoint), "%s bridge crossing stays traversable" % crossing.id)
		check(raid.navigation.is_water(midpoint + Vector2(0, 16)), "%s crossing does not open nearby water" % crossing.id)
		var bridge_ray := PhysicsRayQueryParameters3D.create(Vector3(midpoint.x, 4.0, midpoint.y), Vector3(midpoint.x, -1.0, midpoint.y), 1)
		var bridge_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(bridge_ray)
		check(not bridge_hit.is_empty() and bridge_hit.collider == walkway, "%s bridge deck is physically present" % crossing.id)
	# Compare navigation to the actual rendered mesh, not its source anchors.
	var water := scene.find_child("LakeWaterSurface", true, false) as MeshInstance3D
	var water_vertices: PackedVector3Array = water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var outline_matches := true
	for shore_point: Vector2 in raid.navigation.shoreline:
		var found := false
		for vertex: Vector3 in water_vertices:
			var world_vertex: Vector3 = water.global_transform * vertex
			if shore_point.distance_to(Vector2(world_vertex.x, world_vertex.z)) < 0.01:
				found = true
				break
		outline_matches = outline_matches and found
	check(outline_matches, "Water safety boundary matches the rendered shoreline")
	for site: Dictionary in raid.sites:
		check(not raid.navigation.path(Vector3(0, 0.2, 160), site.position).is_empty(), "Navigation reaches " + String(site.id))
	if render:
		await capture("hq")
	raid.start_run()
	check(raid.phase == raid.Phase.RAID and raid.profile.data.active_run, "Deployment starts and persists active run")
	check(raid.player.ammo == 30 and raid.player.reserve == 90 and raid.medkits == 1, "Free starter kit allocated")
	check(raid.player.extraction_mode, "Review fly/restart cheats disabled in game mode")
	check(raid.guidance_path.size() > 1 and raid.guidance_distance > 0, "Deployment computes walking guidance")
	var guidance_dry := true
	for point: Vector3 in raid.guidance_path:
		guidance_dry = guidance_dry and not raid.navigation.is_water(Vector2(point.x, point.z))
	check(guidance_dry, "Guidance stays on dry navigation cells")
	if render:
		await capture("gameplay")
	raid.pause_run(true)
	check(raid.phase == raid.Phase.PAUSED and raid.player.process_mode == Node.PROCESS_MODE_DISABLED, "Pause freezes player")
	var clock_before: float = raid.remaining
	for frame: int in range(10):
		await process_frame
	check(raid.remaining == clock_before, "Paused raid clock does not advance")
	var optional_cache: Dictionary = raid.sites.filter(func(s: Dictionary) -> bool: return s.kind == "cache")[0]
	# Exercise the actual field-map click handler, not just the controller API.
	var chart: Control = raid.hud.map_view
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = chart.project(Vector2(optional_cache.position.x, optional_cache.position.z))
	chart._gui_input(click)
	check(raid.tracked_objective().id == optional_cache.id, "Field map click selects a salvage destination")
	raid.selected_destination = ""
	raid.refresh_guidance()
	raid.hud.show_pause(raid, true)
	if render:
		await capture("map")
		# Fixed ground-level visual review of the supplied cover asset.
		var saved_transform: Transform3D = raid.player.transform
		var saved_head: Transform3D = raid.player.head.transform
		var point: Vector3 = raid.approach_cover.placements[0]
		raid.player.position = point + Vector3(7, 0.2, 10)
		raid.player.look_at(Vector3(point.x, raid.player.position.y, point.z))
		raid.hud.overlay.hide()
		await capture("approach_cover")
		raid.park.high_render_quality = false
		raid.park._apply_render_quality()
		await capture("approach_cover_balanced")
		raid.park.high_render_quality = true
		raid.park._apply_render_quality()
		var visibility_limits: Dictionary = {}
		for geometry: GeometryInstance3D in scene.find_children("*", "GeometryInstance3D", true, false):
			if geometry.visibility_range_end > 0.0:
				visibility_limits[geometry] = geometry.visibility_range_end
				geometry.visibility_range_end = 600.0
		var review_camera := Camera3D.new()
		scene.add_child(review_camera)
		review_camera.position = Vector3(-90, 300, 180)
		review_camera.look_at(Vector3(0, 0, 0))
		review_camera.fov = 55.0
		review_camera.make_current()
		await capture("park_aerial")
		for geometry: GeometryInstance3D in visibility_limits:
			if is_instance_valid(geometry):
				geometry.visibility_range_end = visibility_limits[geometry]
		review_camera.position = Vector3(6, 4, -52)
		review_camera.look_at(Vector3(100, 1, -38))
		await capture("main_bridge")
		raid.park.high_render_quality = false
		raid.park._apply_render_quality()
		await capture("main_bridge_balanced")
		raid.park.high_render_quality = true
		raid.park._apply_render_quality()
		review_camera.queue_free()
		raid.player.camera.make_current()
		raid.player.transform = saved_transform
		raid.player.head.transform = saved_head
	raid.resume_run()
	raid.set_physics_process(false)
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	var relay: Dictionary = raid.sites[0]
	raid.player.position = relay.position + Vector3(2, 0.2, 0)
	check(raid.complete_site(relay), "Telemetry can be recovered nearby")
	check(raid.track_extraction and not raid.guidance_path.is_empty(), "Relay recovery immediately guides toward extraction")
	check(not raid.complete_site(relay) and raid.relays == 1, "Relay reward cannot be duplicated")
	var cache: Dictionary = raid.sites.filter(func(s: Dictionary) -> bool: return s.kind == "cache")[0]
	raid.player.position = cache.position + Vector3(2, 0.2, 0)
	check(raid.complete_site(cache) and raid.bag.size() == 1, "Search adds cargo")
	var duplicate: Dictionary = cache.duplicate(true)
	duplicate.done = false
	while raid.bag.size() < raid.capacity():
		raid.bag.append(raid.ITEMS[0].duplicate())
	check(not raid.complete_site(duplicate), "Full bag blocks additional loot")
	raid.player.position = raid.exits[0].position
	raid._update_extraction(8.0)
	check(raid.extraction_progress == 8.0, "Extraction countdown begins in zone")
	raid.player.position += Vector3(25, 0, 0)
	raid._update_extraction(0.1)
	check(raid.extraction_progress == 0.0, "Leaving zone cancels extraction")
	raid.player.position = raid.exits[0].position
	raid._update_extraction(10.0)
	raid._on_damage(5)
	raid._update_extraction(0.1)
	check(raid.extraction_progress == 0.0, "Damage interrupts extraction")
	raid.run_time += 3.0
	raid._update_extraction(15.1)
	check(raid.phase == raid.Phase.RESULT and raid.profile.data.extracts == 1, "Successful extraction completes run")
	check(raid.profile.data.credits == 150 and not raid.profile.data.stash.is_empty(), "Only extracted cargo and contract reward persist")
	if render:
		await capture("result")
	var credits_before: int = raid.profile.data.credits
	raid.finish_run(true, "Repeated call")
	check(raid.profile.data.credits == credits_before, "Result cannot pay twice")
	var Profile = load("res://scripts/extraction_profile.gd")
	var reloaded = Profile.new()
	reloaded.save_path = scene.profile_path
	reloaded.load_profile()
	check(reloaded.data.credits == 150 and reloaded.data.extracts == 1, "Save reload preserves progression")
	raid._on_action("hq")
	raid.start_run()
	raid.bag.append(raid.ITEMS[0].duplicate())
	var stash_before: Dictionary = raid.profile.data.stash.duplicate()
	raid.player.take_damage(200)
	check(raid.phase == raid.Phase.RESULT and raid.profile.data.stash == stash_before, "Death loses carried loot and preserves banked stash")
	raid._on_action("hq")
	raid.start_run()
	raid.remaining = 0.01
	raid._physics_process(0.02)
	check(raid.phase == raid.Phase.RESULT, "Lockdown fails the run")
	raid.profile.sell_stash(raid.PRICES)
	check(raid.profile.data.stash.is_empty(), "Stash can be sold")
	var run_credit: int = raid.profile.data.credits
	check(raid.profile.buy_upgrade(), "Cargo upgrade can be purchased")
	check(raid.capacity() == 8 and raid.profile.data.credits == run_credit - 450, "Upgrade charges correct amount and expands pack")
	raid.profile.begin_run()
	reloaded.load_profile()
	check(reloaded.recovered_interrupted_run and not reloaded.data.active_run, "Interrupted run is marked lost on next launch")
	print("EXTRACTION_TEST_RESULT: ", failures.size(), " failures")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	for frame: int in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://extraction_qa")
	root.get_texture().get_image().save_png("user://extraction_qa/extraction_" + label + ".png")
	print("RENDER_FPS: ", label, " ", Engine.get_frames_per_second())
