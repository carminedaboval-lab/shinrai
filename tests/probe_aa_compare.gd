extends "res://tests/probe_shader_warmup.gd"

# Boots the real park with one anti-aliasing setting and takes the same four pictures each time,
# with render times. Sample the process from outside for memory (scratchpad run_probe.ps1).
#   godot --path . --script res://tests/probe_aa_compare.gd -- --aa=taa|off|msaa2|msaa4|msaa8 [--filter=none|fxaa|smaa] --out=<folder>
# The setting is applied to the main view before the park exists and held there; the project's
# default is not changed. Uses a QA profile, never the player's save.

const VIEWS := [
	["fence_street", Vector3(-40, 1.6, -187), Vector3(60, 1.4, -186)],
	["corner_city", Vector3(200, 9, -160), Vector3(226, 0, -186)],
	["park_trees", Vector3(-100, 1.7, -100), Vector3(-150, 4.0, -150)],
	["park_lake", Vector3(0, 1.7, 70), Vector3(60, 1.5, -20)]]

var aa := "taa"
var filter := "none"
var overrides := 0


func _apply() -> void:
	var want_taa := aa == "taa"
	var want_msaa: int = {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X, "msaa8": Viewport.MSAA_8X}.get(aa, Viewport.MSAA_DISABLED)
	var want_filter: int = {"fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}.get(filter, Viewport.SCREEN_SPACE_AA_DISABLED)
	if root.use_taa != want_taa or root.msaa_3d != want_msaa or root.screen_space_aa != want_filter:
		overrides += 1
		root.use_taa = want_taa
		root.msaa_3d = want_msaa
		root.screen_space_aa = want_filter


func _run() -> void:
	var out := "user://aa_compare"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aa="): aa = arg.trim_prefix("--aa=")
		if arg.begins_with("--filter="): filter = arg.trim_prefix("--filter=")
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	var tag := aa if filter == "none" else "%s_%s" % [aa, filter]
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	# This probe drives the view's smoothing itself; the park must not apply the saved setting over it.
	root.set_meta(&"shinrai_aa_external", true)
	_apply()
	overrides = 0
	process_frame.connect(_apply)
	Warmup.suppressed = true
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	root.disable_3d = true
	Engine.max_fps = 120
	var park := (load(WORLD) as PackedScene).instantiate() as Node3D
	park.set("profile_path", PROFILE)
	preload("res://scripts/creator/creator_game_integration.gd").prepare_world(park, LAYOUT)
	park.set_meta("shinrai_incremental_loading", true)
	park.set_meta("shinrai_structure_pending", true)
	root.add_child(park)
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending", false):
		await process_frame
	current_scene = park
	var raid: Node = null
	var deadline := Time.get_ticks_msec() + 900000
	while Time.get_ticks_msec() < deadline:
		raid = park.get_node_or_null("ExtractionRun")
		if raid != null and int(raid.get("phase")) == 1 and raid.world_ready(): break
		await process_frame
	print("AA_PROBE %s ready t=%.1f overrides=%d" % [tag, (Time.get_ticks_msec() - started) / 1000.0, overrides])
	var hud := raid.get("hud") as CanvasLayer
	if hud != null: hud.visible = false
	root.disable_3d = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 900.0
	park.add_child(camera)
	camera.make_current()
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for view: Array in VIEWS:
		camera.look_at_from_position(view[1], view[2])
		for i: int in 120: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s__%s.png" % [out, view[0], tag])
		var cpu := 0.0
		var gpu := 0.0
		var began := Time.get_ticks_usec()
		for i: int in 60:
			await RenderingServer.frame_post_draw
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var wall := (Time.get_ticks_usec() - began) / 60000.0
		print("AA_PROBE %s view=%s cpu_ms=%.2f gpu_ms=%.2f wall_ms=%.2f" % [tag, view[0], cpu / 60.0, gpu / 60.0, wall])
	print("AA_PROBE %s done t=%.1f overrides=%d pipelines=%s" % [tag, (Time.get_ticks_msec() - started) / 1000.0, overrides, JSON.stringify(Warmup.pipeline_counters())])
	quit(0)
