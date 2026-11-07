extends SceneTree

# At one view, hides each top-level park group in turn and reports how many
# draw calls and primitives it accounts for (exact counts, not noisy FPS).
# godot --path . --script res://tests/probe_view_owners.gd -- --view=lawn

const VIEWS := {
	"grove": [Vector2(-82, -20), Vector2(-65, -12)],
	"lawn": [Vector2(-35, 54), Vector2(-21, 45)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view_name := "lawn"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view_name = arg.substr(7)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_view_owner_qa.json"
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
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await _wait(4.0)
	var base := await _stats()
	print("OWNER_BASE %s fps=%.1f draws=%d prims=%d" % [view_name, base.fps, base.draws, base.prims])
	print("OWNER_TIME cpu_render=%.1fms gpu=%.1fms process=%.1fms physics=%.1fms objects=%d lights=%s" % [
		RenderingServer.viewport_get_measured_render_time_cpu(rid),
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		scene.get_viewport().mesh_lod_threshold])
	var sun: DirectionalLight3D = scene.park_directional_light
	sun.shadow_enabled = false
	await _wait(1.0)
	var no_shadow := await _stats()
	sun.shadow_enabled = true
	print("OWNER sun_shadows draws=-%d prims=-%d fps=%.1f" % [base.draws - no_shadow.draws, base.prims - no_shadow.prims, no_shadow.fps])
	for child: Node in scene.get_children():
		if not child is Node3D or not (child as Node3D).visible or child == raid.player: continue
		(child as Node3D).visible = false
		await _wait(.3)
		var result := await _stats(.6)
		(child as Node3D).visible = true
		var draws: int = base.draws - result.draws
		var prims: int = base.prims - result.prims
		if draws > 150 or prims > 300000:
			print("OWNER %-45s draws=-%d prims=-%d" % [child.name, draws, prims])
	print("OWNER_DONE")
	quit()

func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _stats(seconds: float = 2.0) -> Dictionary:
	var frames := 0
	var started := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until or frames < 3:
		await process_frame
		frames += 1
	return {
		"fps": frames / ((Time.get_ticks_usec() - started) / 1000000.0),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}
