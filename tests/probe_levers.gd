extends SceneTree

# Tests each remaining render lever with median frame times, then all together.
# godot --path . --script res://tests/probe_levers.gd -- --view=grove

const VIEWS := {
	"grove": [Vector2(-82, -20), Vector2(-65, -12)],
	"lawn": [Vector2(-35, 54), Vector2(-21, 45)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view_name := "grove"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view_name = arg.substr(7)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_lever_probe_qa.json"
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
	var view: Array = VIEWS[view_name]
	raid.player.global_position = Vector3(view[0].x * 2.0, 0.2, view[0].y * 2.0)
	raid.player.look_at(Vector3(view[1].x * 2.0, 0.2, view[1].y * 2.0))
	await _wait(5.0)
	print("LEVER settings_before vsync=%d max_fps=%d" % [DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _wait(1.0)
	print("LEVER settings_probe vsync=%d max_fps=%d" % [DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	await _sample("base")
	var env: Environment = scene.park_environment
	var sun: DirectionalLight3D = scene.park_directional_light
	var vp := root.get_viewport()
	var detail := scene.get_node_or_null("MidoriDistanceDetail")
	var ranges := {}
	if detail != null:
		for chunk: Node in detail.get_children(): ranges[chunk] = (chunk as GeometryInstance3D).visibility_range_end
	var set_ssao := func(on: bool) -> void: env.ssao_enabled = on
	var set_taa := func(on: bool) -> void: vp.use_taa = on
	var set_scale := func(on: bool) -> void:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if on else Viewport.SCALING_3D_MODE_FSR2
		vp.scaling_3d_scale = 1.0 if on else .77
	var set_shadow := func(on: bool) -> void: sun.directional_shadow_max_distance = 60.0 if on else 40.0
	var set_lod := func(on: bool) -> void: vp.mesh_lod_threshold = 4.0 if on else 12.0
	var set_plant := func(on: bool) -> void:
		for chunk: Node in ranges: (chunk as GeometryInstance3D).visibility_range_end = ranges[chunk] * (1.0 if on else .7)
	var levers := {"ssao off": set_ssao, "taa off": set_taa, "FSR2 0.77": set_scale, "shadow 40m": set_shadow, "mesh lod 12": set_lod, "planting x0.7": set_plant}
	for label: String in levers:
		var lever: Callable = levers[label]
		lever.call(false)
		await _wait(1.5)
		await _sample(label)
		lever.call(true)
		await _wait(.5)
	await _sample("base again")
	for label: String in ["shadow 40m", "mesh lod 12", "planting x0.7"]:
		(levers[label] as Callable).call(false)
	await _wait(1.5)
	await _sample("shadow+lod+planting")
	set_ssao.call(false)
	await _wait(1.5)
	await _sample("  + ssao off")
	set_scale.call(false)
	await _wait(1.5)
	await _sample("  + FSR2 0.77")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _sample(label: String) -> void:
	var samples := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var median := samples[samples.size() / 2]
	print("LEVER %-26s median=%.1fms (%.0f fps) prims=%.1fM" % [label, median, 1000.0 / median, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0])
