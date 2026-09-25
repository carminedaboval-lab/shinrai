extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	if OS.get_cmdline_user_args().has("--no-msaa"):
		root.msaa_3d = Viewport.MSAA_DISABLED
	print("PERF_AA: msaa=%s taa=%s" % [root.msaa_3d, root.use_taa])
	print("PERF_RESOLUTION: %s" % root.size)
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_bridge_walk_qa.json"
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		push_error("Bridge walk: park did not reach HQ")
		quit(1)
		return
	raid.start_run()
	print("BRIDGE_SETUP: phase=%s nav_ready=%s player_process=%s alive=%s" % [raid.phase, raid.navigation.ready, raid.player.process_mode, raid.player.alive])
	if raid.phase != raid.Phase.RAID:
		quit(1)
		return
	raid.player.global_position = Vector3(15.0, 0.2, -38.0)
	raid.player.look_at(Vector3(180.0, 0.2, -38.0))
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	var sprint := InputEventKey.new()
	sprint.keycode = KEY_SHIFT
	sprint.physical_keycode = KEY_SHIFT
	sprint.pressed = true
	Input.parse_input_event(sprint)
	var best_x: float = raid.player.global_position.x
	var fps_sum := 0.0
	var fps_samples := 0
	var fps_min := 10000.0
	for frame: int in range(2400):
		await physics_frame
		best_x = maxf(best_x, raid.player.global_position.x)
		if frame % 120 == 0:
			var fps: float = Engine.get_frames_per_second()
			print("BRIDGE_WALK: x=%.1f y=%.2f on_floor=%s fps=%.0f" % [raid.player.global_position.x, raid.player.global_position.y, raid.player.is_on_floor(), fps])
			if frame > 120 and fps > 0.0:
				fps_sum += fps
				fps_samples += 1
				fps_min = minf(fps_min, fps)
		if raid.player.global_position.x > 175.0:
			break
	forward.pressed = false
	sprint.pressed = false
	Input.parse_input_event(forward)
	Input.parse_input_event(sprint)
	var passed: bool = raid.player.global_position.x > 175.0 and raid.player.is_on_floor()
	print("BRIDGE_WALK_RESULT: %s best_x=%.1f" % ["PASS" if passed else "FAIL", best_x])
	if fps_samples > 0:
		print("BRIDGE_WALK_FPS: mean=%.1f min=%.1f samples=%d" % [fps_sum / fps_samples, fps_min, fps_samples])
	if OS.get_cmdline_user_args().has("--benchmark-cover"):
		var cover_point: Vector3 = raid.approach_cover.placements[0]
		raid.player.global_position = cover_point + Vector3(7.0, 0.2, 10.0)
		raid.player.velocity = Vector3.ZERO
		raid.player.look_at(Vector3(cover_point.x, raid.player.global_position.y, cover_point.z))
		var cover_sum := 0.0
		var cover_min := 10000.0
		for frame: int in range(480):
			await process_frame
			if frame >= 120 and frame % 60 == 0:
				var fps: float = Engine.get_frames_per_second()
				cover_sum += fps
				cover_min = minf(cover_min, fps)
				print("COVER_FPS: %.0f" % fps)
		print("COVER_FPS_RESULT: mean=%.1f min=%.1f" % [cover_sum / 6.0, cover_min])
	quit(0 if passed else 1)
