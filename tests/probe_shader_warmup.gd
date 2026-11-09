extends SceneTree

# Measures the render-pipeline side of loading on the real park, windowed:
#   godot --path . --script res://tests/probe_shader_warmup.gd -- [--no-warm] [--no-latch] [--label=x]
# 1. latch_features() before the park exists (time + pipeline counters).
# 2. Builds the park like shinrai_bootstrap.gd (threaded load, 3D off on the main view) up to Phase.HQ.
# 3. Unless --no-warm: warm() for menu + spawn poses (current variant).
# 4. Turns the main view's 3D on and splits its first frames into
#    pre-draw (scripts/physics/process) vs draw (RenderingServer.draw, incl. pipeline waits),
#    plus the root viewport's measured render CPU/GPU time and RenderingServer frame setup time.
# 5. Spawn pose on the main view, then the night and night+high variants (each warmed first unless --no-warm).
# Prints WARMUP_PROBE <label> <seconds> <json> lines. Uses a QA profile, never the player's save.

const Warmup := preload("res://scripts/shinrai_shader_warmup.gd")
const WORLD := "res://scenes/shinrai_extraction.tscn"
const PROFILE := "user://shinrai_shader_warmup_probe_qa.json"
const LAYOUT := "user://creator_layouts/midori_default.json"

var started := 0
var args: PackedStringArray
var label := "run"
var use_warm := true
var use_latch := true
# Per-frame timeline from RenderingServer's draw signals.
var pre_draw_us := 0
var post_draw_us := 0
var last_post_draw_us := 0
var frame_log: Array = []
var boot_worst_ms := 0.0
# Whole-run sums (pre-draw = scripts/physics/process, draw = RenderingServer.draw) and frames > 250 ms.
var boot_pre_ms := 0.0
var boot_draw_ms := 0.0
var long_frames := 0
var long_pre_ms := 0.0
var long_draw_ms := 0.0


func _initialize() -> void:
	started = Time.get_ticks_msec()
	args = OS.get_cmdline_user_args()
	use_warm = not args.has("--no-warm")
	use_latch = not args.has("--no-latch")
	for arg: String in args:
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_run.call_deferred()


func _on_pre_draw() -> void:
	pre_draw_us = Time.get_ticks_usec()


func _on_post_draw() -> void:
	post_draw_us = Time.get_ticks_usec()
	if last_post_draw_us > 0 and pre_draw_us > 0:
		var entry := {
			"pre_ms": snappedf((pre_draw_us - last_post_draw_us) / 1000.0, 0.1),
			"draw_ms": snappedf((post_draw_us - pre_draw_us) / 1000.0, 0.1),
		}
		frame_log.append(entry)
		boot_worst_ms = maxf(boot_worst_ms, (post_draw_us - last_post_draw_us) / 1000.0)
		boot_pre_ms += entry.pre_ms
		boot_draw_ms += entry.draw_ms
		if entry.pre_ms + entry.draw_ms > 250.0:
			long_frames += 1
			long_pre_ms += entry.pre_ms
			long_draw_ms += entry.draw_ms
	last_post_draw_us = post_draw_us


func _log(what: String, data: Dictionary = {}) -> void:
	print("WARMUP_PROBE %s %s %.1f %s" % [label, what, (Time.get_ticks_msec() - started) / 1000.0, JSON.stringify(data)])


func _run() -> void:
	Warmup.suppressed = true # game code calling the warm-up must not mix into the measurement
	_log("start", {"warm": use_warm, "latch": use_latch, "first_launch": Warmup.is_first_launch(), "caches": Warmup.cache_state(),
		"msaa_setting": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"), "adapter": RenderingServer.get_video_adapter_name(),
		"window": DisplayServer.window_get_size()})
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	# Mirror the bootstrap's loading state: 3D off on the main view, 120 fps, vsync off.
	root.disable_3d = true
	Engine.max_fps = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await RenderingServer.frame_post_draw
	_log("first_frame", Warmup.pipeline_counters())

	if use_latch:
		Warmup.suppressed = false
		var latch: Dictionary = await Warmup.latch_features(root)
		Warmup.suppressed = true
		_log("latch", latch)

	var error := ResourceLoader.load_threaded_request(WORLD, "PackedScene", false)
	if error != OK:
		_log("FAIL", {"error": "load_threaded_request %d" % error}); quit(1); return
	while ResourceLoader.load_threaded_get_status(WORLD) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame
	var scene := ResourceLoader.load_threaded_get(WORLD) as PackedScene
	if scene == null:
		_log("FAIL", {"error": "scene not loaded"}); quit(1); return
	_log("resources_loaded", Warmup.pipeline_counters())
	var park := scene.instantiate() as Node3D
	park.set("profile_path", PROFILE)
	preload("res://scripts/creator/creator_game_integration.gd").prepare_world(park, LAYOUT)
	park.set_meta("shinrai_incremental_loading", true)
	park.set_meta("shinrai_structure_pending", true)
	root.add_child(park)
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending", false):
		await process_frame
	current_scene = park
	for service_name: String in ["MidoriGrassDetail", "MidoriGroundTexture"]:
		var service := root.get_node_or_null(NodePath(service_name))
		if service != null: service.call_deferred("_install_ground_clumps" if service_name == "MidoriGrassDetail" else "_try_install")
	_log("structure_done", Warmup.pipeline_counters())
	var raid: Node = null
	var deadline := Time.get_ticks_msec() + 900000
	while Time.get_ticks_msec() < deadline:
		if not is_instance_valid(park):
			_log("FAIL", {"error": "park freed"}); quit(1); return
		raid = park.get_node_or_null("ExtractionRun")
		if raid != null and int(raid.get("phase")) != 0: break
		await process_frame
	if raid == null or int(raid.get("phase")) == 0:
		_log("TIMEOUT", Warmup.pipeline_counters()); quit(1); return
	var hq_data := Warmup.pipeline_counters()
	hq_data["boot_worst_frame_ms"] = snappedf(boot_worst_ms, 0.1)
	hq_data["frames"] = frame_log.size()
	hq_data["pre_s"] = snappedf(boot_pre_ms / 1000.0, 0.1)
	hq_data["draw_s"] = snappedf(boot_draw_ms / 1000.0, 0.1)
	hq_data["long_frames"] = long_frames
	hq_data["long_pre_s"] = snappedf(long_pre_ms / 1000.0, 0.1)
	hq_data["long_draw_s"] = snappedf(long_draw_ms / 1000.0, 0.1)
	hq_data["caches_now"] = Warmup.cache_state()
	_log("hq", hq_data)

	var poses := Warmup.default_poses(park, raid)
	var menu_pose: Transform3D = poses[0]
	var spawn_pose: Transform3D = poses[1]
	var day_night: bool = bool(park.get("is_night_mode"))
	var high: bool = bool(park.get("high_render_quality"))
	var two_poses: Array[Transform3D] = [menu_pose, spawn_pose]

	if use_warm:
		await _warm("warm_default", park, two_poses, day_night, high)

	# The real freeze point: the main view's first 3D frame (bootstrap.gd turns 3D on here).
	await _measure_main("first_main_view", func() -> void: root.disable_3d = false, 10)

	# Spawn view on the main viewport (deploy's first raid frame).
	var spawn_camera := Camera3D.new()
	var menu_camera: Camera3D = root.get_camera_3d()
	if menu_camera != null:
		spawn_camera.fov = 75.0
		spawn_camera.near = menu_camera.near
		spawn_camera.far = menu_camera.far
		spawn_camera.attributes = menu_camera.attributes
	park.add_child(spawn_camera)
	spawn_camera.global_transform = spawn_pose
	await _measure_main("main_spawn_view", func() -> void: spawn_camera.make_current(), 8)
	if menu_camera != null and is_instance_valid(menu_camera): menu_camera.make_current()
	await _settle(30)

	# Night variant (deploy at night), then night + High quality.
	for variant: Array in [[true, false, "night"], [true, true, "night_high"], [false, true, "day_high"]]:
		if use_warm:
			await _warm("warm_" + variant[2], park, two_poses, variant[0], variant[1])
		var switch_variant := func() -> void:
			park.set("is_night_mode", variant[0])
			park.set("high_render_quality", variant[1])
			park.call("_apply_time_of_day")
		await _measure_main("main_" + variant[2], switch_variant, 8)
		await _settle(20)
	park.set("is_night_mode", day_night); park.set("high_render_quality", high); park.call("_apply_time_of_day")
	await _settle(10)
	_log("done", {"total_s": (Time.get_ticks_msec() - started) / 1000.0, "pipelines": Warmup.pipeline_counters(), "first_launch_after": Warmup.is_first_launch()})
	if use_warm: Warmup.mark_done()
	quit()


func _warm(what: String, park: Node3D, poses: Array[Transform3D], night: bool, high: bool) -> void:
	var mark := frame_log.size()
	Warmup.suppressed = false
	var report: Dictionary = await Warmup.warm(park, poses, night, high)
	Warmup.suppressed = true
	report["frame_split"] = _split(mark)
	_log(what, report)


func _settle(frames: int) -> void:
	for i: int in frames: await process_frame


## Applies `change` and records the next `frames` frames of the main viewport.
func _measure_main(what: String, change: Callable, frames: int) -> void:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await RenderingServer.frame_post_draw
	var before := Warmup.pipeline_counters()
	var series: Array = []
	var mark := frame_log.size()
	var last := before
	var changed_at := Time.get_ticks_usec()
	change.call()
	for i: int in frames:
		await RenderingServer.frame_post_draw
		var now := Warmup.pipeline_counters()
		var entry: Dictionary = frame_log[frame_log.size() - 1].duplicate() if frame_log.size() > mark else {}
		entry["vp_cpu_ms"] = snappedf(RenderingServer.viewport_get_measured_render_time_cpu(rid), 0.1)
		entry["vp_gpu_ms"] = snappedf(RenderingServer.viewport_get_measured_render_time_gpu(rid), 0.1)
		entry["setup_ms"] = snappedf(RenderingServer.get_frame_setup_time_cpu(), 0.1)
		entry["d"] = counters_compact(Warmup.counters_delta(now, last))
		last = now
		series.append(entry)
	var first_ms := 0.0
	if frame_log.size() > mark:
		first_ms = (frame_log[mark].pre_ms + frame_log[mark].draw_ms)
	_log(what, {
		"first_frame_ms": snappedf(first_ms, 0.1),
		"first_pre_ms": frame_log[mark].pre_ms if frame_log.size() > mark else -1.0,
		"first_draw_ms": frame_log[mark].draw_ms if frame_log.size() > mark else -1.0,
		"since_change_ms": snappedf((Time.get_ticks_usec() - changed_at) / 1000.0, 0.1),
		"max_vp_cpu_ms": series.map(func(e: Dictionary) -> float: return e.vp_cpu_ms).max(),
		"max_vp_gpu_ms": series.map(func(e: Dictionary) -> float: return e.vp_gpu_ms).max(),
		"pipelines": Warmup.counters_delta(Warmup.pipeline_counters(), before),
		"series": series,
	})


func counters_compact(delta: Dictionary) -> String:
	return "s%d d%d p%d m%d" % [delta.surface, delta.draw, delta.spec, delta.mesh]


func _split(mark: int) -> Dictionary:
	var pre := 0.0
	var draw := 0.0
	var worst_pre := 0.0
	var worst_draw := 0.0
	for i: int in range(mark, frame_log.size()):
		pre += frame_log[i].pre_ms
		draw += frame_log[i].draw_ms
		worst_pre = maxf(worst_pre, frame_log[i].pre_ms)
		worst_draw = maxf(worst_draw, frame_log[i].draw_ms)
	return {"frames": frame_log.size() - mark, "pre_ms": snappedf(pre, 0.1), "draw_ms": snappedf(draw, 0.1),
		"worst_pre_ms": snappedf(worst_pre, 0.1), "worst_draw_ms": snappedf(worst_draw, 0.1)}
