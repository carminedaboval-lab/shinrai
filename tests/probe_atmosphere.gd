extends SceneTree

# Renders two park views in day Balanced, day High and night Balanced with FPS
# samples, to check the atmosphere pass. Allows a slow park load (5 minutes).
# godot --path . --script res://tests/probe_atmosphere.gd

const VIEWS: Array[Dictionary] = [
	{"name": "west_grove", "eye": Vector2(-82, -20), "target": Vector2(-65, -12)},
	{"name": "south_lawn", "eye": Vector2(-35, 54), "target": Vector2(-21, 45)},
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_atmosphere_probe_qa.json"
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
	for pass_name: String in ["day_balanced", "day_high", "night_balanced"]:
		scene.is_night_mode = pass_name.begins_with("night")
		scene.high_render_quality = pass_name.ends_with("high")
		scene._apply_time_of_day()
		for view: Dictionary in VIEWS:
			var eye: Vector2 = view["eye"]
			var target: Vector2 = view["target"]
			raid.player.global_position = Vector3(eye.x * 2.0, 0.2, eye.y * 2.0)
			raid.player.velocity = Vector3.ZERO
			raid.player.look_at(Vector3(target.x * 2.0, raid.player.global_position.y, target.y * 2.0))
			await _sample("%s_%s" % [view["name"], pass_name])
	quit()

func _sample(label: String) -> void:
	var fps_sum := 0.0
	var fps_min := 10000.0
	var count := 0
	for frame: int in range(300):
		await process_frame
		if frame >= 120 and frame % 30 == 0:
			var fps: float = Engine.get_frames_per_second()
			fps_sum += fps
			fps_min = minf(fps_min, fps)
			count += 1
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://visual_fx_qa")
	root.get_texture().get_image().save_png("user://visual_fx_qa/atmosphere_%s.png" % label)
	print("ATMOSPHERE: %s mean=%.1f min=%.1f samples=%d" % [label, fps_sum / float(count), fps_min, count])
