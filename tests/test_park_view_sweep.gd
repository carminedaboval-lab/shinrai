extends SceneTree

const VIEWS: Array[Dictionary] = [
	{"name": "west_grove", "eye": Vector2(-82, -20), "target": Vector2(-65, -12)},
	{"name": "open_cover", "eye": Vector2(-1, 13), "target": Vector2(-1, 5)},
	{"name": "south_lawn", "eye": Vector2(-35, 54), "target": Vector2(-21, 45)},
	{"name": "lake_edge", "eye": Vector2(9, -13), "target": Vector2(40, -13)},
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_view_sweep_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		push_error("View sweep: scene did not reach HQ")
		quit(1)
		return
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		push_error("View sweep: raid did not start")
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	for view: Dictionary in VIEWS:
		var eye: Vector2 = view["eye"]
		var target: Vector2 = view["target"]
		raid.player.global_position = Vector3(eye.x * 2.0, 0.2, eye.y * 2.0)
		raid.player.velocity = Vector3.ZERO
		raid.player.look_at(Vector3(target.x * 2.0, raid.player.global_position.y, target.y * 2.0))
		await sample(view["name"] + "_final_day")
	scene.is_night_mode = true
	scene._apply_time_of_day()
	for view: Dictionary in VIEWS.slice(0, 2):
		var eye: Vector2 = view["eye"]
		var target: Vector2 = view["target"]
		raid.player.global_position = Vector3(eye.x * 2.0, 0.2, eye.y * 2.0)
		raid.player.look_at(Vector3(target.x * 2.0, raid.player.global_position.y, target.y * 2.0))
		await sample(view["name"] + "_final_night")
	quit()
	quit()

func sample(label: String) -> void:
		var fps_sum := 0.0
		var fps_min := 10000.0
		var count := 0
		for frame: int in range(360):
			await process_frame
			if frame >= 150 and frame % 30 == 0:
				var fps: float = Engine.get_frames_per_second()
				fps_sum += fps
				fps_min = minf(fps_min, fps)
				count += 1
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://extraction_qa")
		root.get_texture().get_image().save_png("user://extraction_qa/view_sweep_%s.png" % label)
		print("VIEW_SWEEP: %s mean=%.1f min=%.1f samples=%d" % [label, fps_sum / float(count), fps_min, count])
