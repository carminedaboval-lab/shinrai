extends SceneTree

# Frame budget at one view. Lists every SubViewport, then tries each candidate
# saving in turn and reports true average frame time. Restores after each one.
# godot --path . --script res://tests/probe_budget.gd -- --view=grove

const VIEWS := {
	"grove": [Vector2(-82, -20), Vector2(-65, -12)],
	"lawn": [Vector2(-35, 54), Vector2(-21, 45)],
}

var rid: RID
var scene: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view_name := "grove"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view_name = arg.substr(7)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_budget_probe_qa.json"
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
	rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _wait(6.0)
	var viewports: Array[SubViewport] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is SubViewport:
			viewports.append(node)
			print("BUDGET_VIEWPORT %s size=%s update=%d path=%s" % [node.name, node.size, node.render_target_update_mode, node.get_path()])
	var base := await _sample("base")
	var env: Environment = scene.park_environment
	var sun: DirectionalLight3D = scene.park_directional_light
	var vp := root.get_viewport()
	for sub: SubViewport in viewports:
		if sub.render_target_update_mode == SubViewport.UPDATE_DISABLED: continue
		var mode := sub.render_target_update_mode
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await _wait(.8)
		await _sample("subviewport off " + sub.name)
		sub.render_target_update_mode = mode
	env.ssao_enabled = false
	await _wait(.8)
	await _sample("ssao off")
	env.ssao_enabled = true
	vp.use_taa = false
	await _wait(.8)
	await _sample("taa off")
	vp.use_taa = true
	var lod := vp.mesh_lod_threshold
	for value: float in [8.0, 16.0]:
		vp.mesh_lod_threshold = value
		await _wait(.8)
		await _sample("mesh lod threshold %d" % int(value))
	vp.mesh_lod_threshold = lod
	var detail := scene.get_node_or_null("MidoriDistanceDetail")
	if detail != null:
		var ranges := []
		for chunk: Node in detail.get_children():
			var geometry := chunk as GeometryInstance3D
			ranges.append(geometry.visibility_range_end)
			geometry.visibility_range_end *= .7
		await _wait(.8)
		await _sample("planting range x0.7")
		var index := 0
		for chunk: Node in detail.get_children():
			(chunk as GeometryInstance3D).visibility_range_end = ranges[index]
			index += 1
	var distance := sun.directional_shadow_max_distance
	sun.directional_shadow_max_distance = 45.0
	await _wait(.8)
	await _sample("shadow distance 45")
	sun.directional_shadow_max_distance = distance
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	vp.scaling_3d_scale = .77
	await _wait(1.5)
	await _sample("FSR2 at 0.77 (resolution option)")
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 1.0
	print("BUDGET_DONE base_ms=%.1f" % base)
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _sample(label: String) -> float:
	var frames := 0
	var gpu := 0.0
	var cpu := 0.0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until or frames < 4:
		await process_frame
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var frame_ms := (Time.get_ticks_usec() - started) / 1000.0 / frames
	print("BUDGET %-42s frame=%.1fms (%.0f fps) gpu=%.1fms cpu_render=%.1fms prims=%d draws=%d" % [label, frame_ms, 1000.0 / frame_ms, gpu / frames, cpu / frames, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	return frame_ms
