extends SceneTree
## Same-camera A/B captures and GPU frame times for scripts/shinrai_graphics.gd.
## One raid boot; at each view every config is rendered from the identical camera transform.
## Vsync is off and GPU time is read from the renderer, so numbers are not capped at 60.
##
##   GFX_CAPTURE_DIR=<abs dir>  (required)   GFX_VIEWS=a,b (default below)   GFX_CONFIGS=a,b
##   GFX_HIGH=1  start from the High preset instead of Balanced
##   godot --path . --script res://tools/graphics_ab_capture.gd
## Writes <dir>/<view>__<config>.png and <dir>/capture.json.

const VIEWS_SOURCE := preload("res://tools/biome_capture.gd")
const GFX := preload("res://scripts/shinrai_graphics.gd")
const SIZE := Vector2i(1920, 1080)
const DEFAULT_VIEWS := ["pine_woods", "sakura_lawn", "iris_shore", "spawn_street", "moss_garden"]

var scene: Node
var gfx: Node
var camera: Camera3D
var view_rid: RID
var configs := {}
var ae_attributes: CameraAttributesPractical


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n: await process_frame


func _measure(warm: int) -> Dictionary:
	await _frames(warm)
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var frame: Array[float] = []
	var last := Time.get_ticks_usec()
	for i: int in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		frame.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view_rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(view_rid))
	return {"gpu_ms": _median(gpu), "gpu_p95_ms": _pct(gpu, 0.95), "frame_ms": _median(frame),
			"frame_p95_ms": _pct(frame, 0.95), "render_cpu_ms": _median(cpu),
			"vram_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 1),
			"tex_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0, 1),
			"buf_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0, 1),
			"prims": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}


func _median(a: Array[float]) -> float: return _pct(a, 0.5)
func _pct(a: Array[float], p: float) -> float:
	var s := a.duplicate()
	s.sort()
	return snappedf(s[clampi(int(round(p * (s.size() - 1))), 0, s.size() - 1)], 0.01)


func _reset() -> void:
	# Back to the plain park preset with the module off and no experiments.
	var env: Environment = scene.park_environment
	env.sdfgi_enabled = false
	camera.attributes = null
	gfx.set_enabled(false)
	for key: String in GFX.FEATURES: gfx.active[key] = true


func _only(keys: Array) -> void:
	for key: String in GFX.FEATURES: gfx.active[key] = keys.has(key)
	gfx.set_enabled(true)
	gfx.set_feature(keys[0] if not keys.is_empty() else "fsr2", not keys.is_empty())


func _build_configs() -> void:
	configs["before"] = func() -> void: pass
	configs["after"] = func() -> void: _only(GFX.FEATURES.duplicate())
	configs["after_no_atlas"] = func() -> void:
		var keys := GFX.FEATURES.duplicate()
		keys.erase("shadow_atlas")
		_only(keys)
	for key: String in GFX.FEATURES:
		configs["only_" + key] = func() -> void: _only([key])
	configs["exp_fsr2_077"] = func() -> void:
		_only(["fsr2"])
		gfx.enabled = false # freeze the module so the experiment's scale sticks
		root.scaling_3d_scale = 0.77
	configs["exp_sdfgi"] = func() -> void:
		var env: Environment = scene.park_environment
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_read_sky_light = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.2
		env.sdfgi_energy = 1.0
	configs["exp_auto_exposure"] = func() -> void:
		camera.attributes = ae_attributes


func _run() -> void:
	var out := OS.get_environment("GFX_CAPTURE_DIR")
	if not out.is_absolute_path() or DirAccess.make_dir_recursive_absolute(out) != OK:
		_fail("Missing or inaccessible GFX_CAPTURE_DIR")
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	gfx = root.get_node_or_null("ShinraiGraphics")
	var attach_late := gfx == null and OS.get_environment("GFX_ATTACH_LATE") == "1"
	if gfx == null and not attach_late: _attach()
	# Workaround (probe only): the uncommitted threaded preload in midori_park_floor.gd crashes in
	# surface_get_arrays. Loading its sources here first makes it take its cached load() path.
	var floor_script: GDScript = load("res://scripts/midori_park_floor.gd")
	var floor_consts := floor_script.get_script_constant_map()
	var keep: Array = []
	if floor_consts.has("SOURCE_FILES") and OS.get_environment("GFX_NO_FLOOR_PRELOAD") != "1":
		for filename: String in floor_consts.SOURCE_FILES:
			keep.append(load(String(floor_consts.ASSETS) + filename))
	set_meta("kept_floor_sources", keep)
	# Same as shinrai_bootstrap.gd: no 3D rendering while the park builds. Rendering the
	# half-built park every frame ran the 8 GB GPU out of memory (VkResult -2).
	root.disable_3d = true
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_perf_probe.json"
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var started := Time.get_ticks_msec()
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() - started < 900000:
		await process_frame
	while not scene.has_meta("midori_biomes") and Time.get_ticks_msec() - started < 1200000:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		_fail("Raid failed to boot into HQ")
		return
	print("BOOTED_MS ", Time.get_ticks_msec() - started)
	root.disable_3d = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if gfx == null: _attach()
	if OS.get_environment("GFX_HIGH") == "1":
		scene.high_render_quality = true
		scene._apply_time_of_day()
	raid.hud.hide()
	if raid.get("player") != null and is_instance_valid(raid.player): raid.player.visible = false
	view_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(view_rid, true)
	camera = Camera3D.new()
	camera.fov = 70
	scene.add_child(camera)
	camera.make_current()
	ae_attributes = CameraAttributesPractical.new()
	ae_attributes.auto_exposure_enabled = true
	ae_attributes.auto_exposure_scale = 0.4
	ae_attributes.auto_exposure_speed = 4.0
	ae_attributes.auto_exposure_min_sensitivity = 50.0
	ae_attributes.auto_exposure_max_sensitivity = 400.0
	_build_configs()
	var wanted_configs := OS.get_environment("GFX_CONFIGS").split(",", false)
	# Ordered; "name#2" repeats a config (e.g. before#2 between features to catch drift).
	var config_names: Array = Array(wanted_configs) if not wanted_configs.is_empty() else configs.keys()
	for name: String in config_names:
		if not configs.has(name.get_slice("#", 0)):
			_fail("Unknown config " + name)
			return
	var views: Array = Array(OS.get_environment("GFX_VIEWS").split(",", false))
	if views.is_empty(): views = DEFAULT_VIEWS
	var terrain: Node = scene.get_node("MidoriTerrain")
	print("GFX_STATE before: scaling=%d scale=%.2f taa=%s aniso=%d deband=%s spec_occ=%s" % [root.scaling_3d_mode,
			root.scaling_3d_scale, root.use_taa, root.anisotropic_filtering_level, root.use_debanding,
			ProjectSettings.get_setting("rendering/reflections/specular_occlusion/enabled")])
	var results := {}
	for view: String in views:
		var pose: Array = VIEWS_SOURCE.VIEWS[view]
		var eye: Vector3 = pose[0]
		eye.y = terrain.height_at(Vector2(eye.x, eye.z)) + 1.7
		var target: Vector3 = pose[1]
		target.y += terrain.height_at(Vector2(target.x, target.z))
		camera.global_position = eye
		camera.look_at(target)
		camera.reset_physics_interpolation()
		var transform := camera.global_transform
		results[view] = {}
		for config: String in config_names:
			_reset()
			await _frames(4)
			configs[config.get_slice("#", 0)].call()
			var warm := 260 if config == "exp_sdfgi" else 90
			var stats := await _measure(warm)
			await RenderingServer.frame_post_draw
			if not camera.global_transform.is_equal_approx(transform) or root.get_camera_3d() != camera:
				_fail("Camera moved during " + view + "/" + config)
				return
			var image := root.get_texture().get_image()
			var file := out.path_join("%s__%s.png" % [view, config])
			if image == null or image.save_png(file) != OK:
				_fail("Could not save " + file)
				return
			stats["state"] = "scaling=%d scale=%.2f taa=%s aniso=%d ssil=%s ssr=%s sdfgi=%s" % [root.scaling_3d_mode,
					root.scaling_3d_scale, root.use_taa, root.anisotropic_filtering_level,
					scene.park_environment.ssil_enabled, scene.park_environment.ssr_enabled, scene.park_environment.sdfgi_enabled]
			results[view][config] = stats
			print("GFX ", view, " ", config, " ", JSON.stringify(stats))
	_reset()
	var manifest := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"high": OS.get_environment("GFX_HIGH") == "1", "views": results,
			"method": "same camera transform per view; vsync off; 90 warm frames (260 for SDFGI) then median of 120"}, "\t"))
	manifest.close()
	print("GFX_DONE")
	quit()


func _attach() -> void:
	gfx = GFX.new()
	gfx.name = "ShinraiGraphics"
	root.add_child(gfx)


func _fail(reason: String) -> void:
	printerr("GFX_FAILED ", reason)
	quit(1)
