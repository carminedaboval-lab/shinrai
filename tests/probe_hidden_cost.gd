extends SceneTree

# With the main 3D view off, removes each off-screen render source in turn to
# find the hidden per-frame cost. Then repeats the saving with 3D back on.
# godot --path . --script res://tests/probe_hidden_cost.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_hidden_probe_qa.json"
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
	raid.player.global_position = Vector3(-164, 0.2, -40)
	raid.player.look_at(Vector3(-130, 0.2, -24))
	await _wait(6.0)
	var reflection := scene.find_child("LakePlanarReflection", true, false) as SubViewport
	var clouds := scene.find_child("MidoriCloudCache", true, false)
	var dome := scene.find_child("MidoriCalmClouds", true, false)
	var hud: CanvasLayer = raid.hud
	print("HIDDEN found reflection=%s clouds=%s dome=%s" % [reflection != null, clouds != null, dome != null])
	await _sample("base")
	var vp := root.get_viewport()
	vp.disable_3d = true
	await _wait(1.0)
	await _sample("3D off")
	var reflection_mode := reflection.render_target_update_mode if reflection != null else 0
	if reflection != null:
		reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await _wait(1.0)
		await _sample("3D off + lake reflection off")
	if clouds != null:
		clouds.process_mode = Node.PROCESS_MODE_DISABLED
		clouds.set_process(false)
		await _wait(1.0)
		await _sample("  + cloud cache paused")
	hud.visible = false
	await _wait(1.0)
	await _sample("  + HUD hidden")
	hud.visible = true
	vp.disable_3d = false
	await _wait(1.5)
	await _sample("3D on, reflection+clouds off")
	if clouds != null:
		clouds.process_mode = Node.PROCESS_MODE_INHERIT
		clouds.set_process(true)
		await _wait(1.0)
		await _sample("3D on, reflection off only")
	if reflection != null: reflection.render_target_update_mode = reflection_mode
	await _wait(1.0)
	await _sample("base end")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _sample(label: String) -> void:
	var samples := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var median := samples[samples.size() / 2]
	print("HIDDEN %-34s median=%.1fms (%.0f fps) frames=%d" % [label, median, 1000.0 / median, samples.size()])
