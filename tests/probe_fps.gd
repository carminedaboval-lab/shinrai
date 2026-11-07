extends SceneTree

# Frame-cost breakdown at the slow west grove view (daytime, Balanced).
# For each top-level park child and a few render features, it disables that
# piece, measures, and restores it, then prints the biggest savings.
# godot --path . --script res://tests/probe_fps.gd

var viewport_rid: RID

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_fps_probe_qa.json"
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
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	await _wait_seconds(4.0)
	var base := await _measure()
	print("FPS_BASE fps=%.1f cpu_render=%.1fms gpu=%.1fms process=%.1fms physics=%.1fms draws=%d prims=%d objects=%d" % [base.fps, base.cpu, base.gpu, base.process, base.physics, base.draws, base.prims, base.objects])

	var env: Environment = scene.park_environment
	var sun: DirectionalLight3D = scene.park_directional_light
	var toggles := {
		"sun_shadows": func(on: bool) -> void: sun.shadow_enabled = on,
		"ssao": func(on: bool) -> void: env.ssao_enabled = on,
		"glow": func(on: bool) -> void: env.glow_enabled = on,
		"fog": func(on: bool) -> void: env.fog_enabled = on,
	}
	for label: String in toggles:
		var toggle: Callable = toggles[label]
		toggle.call(false)
		await _wait_seconds(1.0)
		var result := await _measure()
		toggle.call(true)
		_report(label, base, result)

	var candidates: Array[Node] = []
	for child: Node in scene.get_children():
		candidates.append(child)
	for autoload: String in ["MidoriSakuraSwap", "MidoriGrassDetail", "MidoriGroundTexture"]:
		var node := root.get_node_or_null(autoload)
		if node != null: candidates.append(node)
	print("FPS_CANDIDATES %d" % candidates.size())
	for node: Node in candidates:
		if node == raid or node == raid.player:
			continue
		var was_visible := true
		if node is Node3D:
			was_visible = (node as Node3D).visible
			if not was_visible: continue
			(node as Node3D).visible = false
		var previous_mode := node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		await _wait_seconds(0.6)
		var result := await _measure(1.2)
		node.process_mode = previous_mode
		if node is Node3D: (node as Node3D).visible = was_visible
		_report("%s (%s, %d children)" % [node.name, node.get_class(), node.get_child_count()], base, result)
	print("FPS_DONE")
	quit()

func _report(label: String, base: Dictionary, result: Dictionary) -> void:
	var saved := 1000.0 / maxf(base.fps, 0.1) - 1000.0 / maxf(result.fps, 0.1)
	if absf(saved) >= 4.0 or result.prims < base.prims * 0.85:
		print("FPS_TOGGLE %-60s fps=%.1f saved=%.1fms gpu=%.1fms prims=%d draws=%d" % [label, result.fps, saved, result.gpu, result.prims, result.draws])

func _wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _measure(seconds: float = 2.0) -> Dictionary:
	var frames := 0
	var cpu := 0.0
	var gpu := 0.0
	var process := 0.0
	var physics := 0.0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until or frames < 3:
		await process_frame
		frames += 1
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	return {
		"fps": frames / elapsed,
		"cpu": cpu / frames,
		"gpu": gpu / frames,
		"process": process / frames,
		"physics": physics / frames,
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}
