extends RefCounted
## Render-pipeline preparation for the park (see loading_map/shaders.md).
##
## Use through preload (no class_name, so it works without an editor class-cache scan):
##   const ShaderWarmup := preload("res://scripts/shinrai_shader_warmup.gd")
##   await ShaderWarmup.latch_features(get_tree().root)      # boot, BEFORE the park is instantiated
##   var report: Dictionary = await ShaderWarmup.warm(park, poses, night, high)   # last loading step / deploy cover
##   if ShaderWarmup.is_first_launch(): stage text "Preparing shaders (first launch)"
##   ShaderWarmup.mark_done()                                  # after the first successful warm
##
## Why two steps (Godot 4.4+ ubershader pipeline precompilation):
## - Surface pipelines are precompiled on worker threads when a mesh surface first enters the scene,
##   for the feature set in the renderer's global "required" key (MSAA from the project setting,
##   motion vectors (TAA), normal-roughness (SSAO/SSR/SSIL), separate specular (SSR), reflection probes,
##   omni cubemap / dual-paraboloid shadows). A feature first seen later changes the key and every
##   surface is precompiled again. latch_features() renders every feature the park can use once, in a
##   tiny private world, before the ~2000+ park surfaces arrive, so they compile once, during the load.
## - Pipelines a draw needs that were not precompiled (or not finished) block that draw. warm() draws
##   the finished park from the poses the player will see first, offscreen, until the counters settle,
##   so those stalls happen behind the loading screen instead of on the first menu or raid frame.
## Neither function changes the main viewport; warm() restores the park's time-of-day/quality and
## the root viewport settings it may touch through the park, and frees its SubViewport.

const STAMP_PATH_DEFAULT := "user://shader_stamp.json"
## Bump when runtime-generated shaders change a lot (forces the first-launch label and extra poses).
const PROJECT_SHADER_VERSION := 1
const LATCH_SIZE := Vector2i(64, 64)
const WARM_SIZE := Vector2i(480, 270)
const LATCH_FRAMES := 3
const LATCH_CAP_MS := 1500
const CAP_MS := 3000
const CAP_FIRST_LAUNCH_MS := 9000
const POSE_MIN_FRAMES := 3
const POSE_MAX_FRAMES := 120
## Frames in a row with no new surface/draw/mesh compilations and a settled render.
const STABLE_FRAMES := 4
## The offscreen viewport's own render CPU time below which a frame counts as settled.
const SETTLED_RENDER_MS := 40.0

## Tests may point the stamp elsewhere.
static var stamp_path := STAMP_PATH_DEFAULT
## When true, latch_features()/warm() return {"status":"suppressed"} at once (probes use it to
## measure "without warm-up" while game code still calls the functions).
static var suppressed := false
## Optional progress callback for warm(): func(fraction: float, label: String). 0..1 for this call.
static var on_progress: Callable = Callable()
## > 0 overrides the time cap of warm() in ms.
static var cap_override_ms := 0
static var last_latch_report: Dictionary = {}
static var last_warm_report: Dictionary = {}
static var _busy := false
static var _driver_info_cache := ""
static var _first_launch_cached := -1


# ---------------------------------------------------------------- counters

static func pipeline_counters() -> Dictionary:
	return {
		"canvas": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		"mesh": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		"surface": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		"draw": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		"spec": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
	}


static func counters_delta(after: Dictionary, before: Dictionary) -> Dictionary:
	var out := {}
	for key: String in after:
		out[key] = int(after[key]) - int(before.get(key, 0))
	return out


# ---------------------------------------------------------------- first-launch stamp

static func stamp_key() -> Dictionary:
	var version := Engine.get_version_info()
	if _driver_info_cache == "":
		_driver_info_cache = "|".join(OS.get_video_adapter_driver_info())
		if _driver_info_cache == "": _driver_info_cache = "-"
	return {
		"engine": "%s|%s" % [str(version.get("string", "")), str(version.get("hash", ""))],
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"driver": _driver_info_cache,
		"method": RenderingServer.get_current_rendering_method(),
		"project_shaders": str(PROJECT_SHADER_VERSION), # strings only: JSON turns ints into floats
		"build": str(ProjectSettings.get_setting("application/config/version", "")),
	}


## Godot's own caches. The engine creates both folders at start-up (measured: the folders and
## ~190 small built-in shader files exist before the first script runs on a cold launch), so
## "exists" means nothing: count scene-shader entries and the pipeline cache size instead.
const WARM_SCENE_SHADER_FILES := 48
const WARM_PIPELINE_CACHE_BYTES := 16 * 1024 * 1024

## Direct3D 12 leaves no pipeline cache file (seen 2026-11-09: after Direct3D 12 boots
## user://vulkan held only the Vulkan run's file), and its scene shaders sit in the same folders as Vulkan's, named
## *.d3d12.cache. Judged by the Vulkan file, a Direct3D 12 run looked like a first launch on
## every boot (or was "warm" only thanks to Vulkan's files). So Direct3D 12 counts its own
## shader files, skips the pipeline-file test and keeps its own stamp. Every other driver is
## checked exactly as before.
static func _is_d3d12() -> bool:
	return RenderingServer.get_current_rendering_driver_name() == "d3d12"


## The stamp the running driver reads and writes. The stamp key holds the graphics API version,
## so one shared file would turn every switch between drivers into a first launch.
static func stamp_file() -> String:
	if _is_d3d12() and stamp_path.get_extension() != "":
		return "%s.d3d12.%s" % [stamp_path.get_basename(), stamp_path.get_extension()]
	return stamp_path


static func cache_state() -> Dictionary:
	var d3d12 := _is_d3d12()
	var scene_files := _count_files("user://shader_cache/SceneForwardClusteredShaderRD", 2, ".d3d12.cache" if d3d12 else "")
	var pipeline_bytes := 0
	var vulkan := DirAccess.open("user://vulkan")
	if vulkan != null:
		for file: String in vulkan.get_files():
			if file.begins_with("pipelines.") and file.ends_with(".cache") and not file.ends_with(".editor.cache"):
				var handle := FileAccess.open("user://vulkan/" + file, FileAccess.READ)
				if handle != null:
					pipeline_bytes = maxi(pipeline_bytes, handle.get_length())
					handle.close()
	return {
		"scene_shader_files": scene_files, "pipeline_cache_mb": snappedf(pipeline_bytes / 1048576.0, 0.1),
		"shader_cache": scene_files >= WARM_SCENE_SHADER_FILES,
		"pipeline_cache": pipeline_bytes >= WARM_PIPELINE_CACHE_BYTES,
		"pipeline_cache_checked": not d3d12,
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
	}


## `suffix` "" counts every file; otherwise only names ending in it.
static func _count_files(path: String, depth: int, suffix: String = "") -> int:
	var dir := DirAccess.open(path)
	if dir == null: return 0
	var total := 0
	if suffix == "":
		total = dir.get_files().size()
	else:
		for file: String in dir.get_files():
			if file.ends_with(suffix): total += 1
	if depth > 0:
		for sub: String in dir.get_directories():
			total += _count_files(path.path_join(sub), depth - 1, suffix)
	return total


## Evaluated once per session (the caches grow past the thresholds during a cold boot, so a
## later check would say "warm"); mark_done() clears it.
static func is_first_launch() -> bool:
	if _first_launch_cached < 0:
		_first_launch_cached = 1 if _evaluate_first_launch() else 0
	return _first_launch_cached == 1


static func _evaluate_first_launch() -> bool:
	var caches := cache_state()
	if not bool(caches.shader_cache): return true
	if RenderingServer.get_current_rendering_method() != "gl_compatibility" and bool(caches.pipeline_cache_checked) and not bool(caches.pipeline_cache):
		return true
	var path := stamp_file()
	if not FileAccess.file_exists(path): return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return true
	var stored: Dictionary = (parsed as Dictionary).get("key", {})
	var key := stamp_key()
	for field: String in key:
		if str(stored.get(field, "")) != str(key[field]): return true
	return false


static func mark_done() -> void:
	var path := stamp_file()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SHADER_WARMUP: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify({"key": stamp_key(), "written": Time.get_datetime_string_from_system()}, "\t"))
	file.close()
	_first_launch_cached = 0


# ---------------------------------------------------------------- viewport settings

## Copies everything that can change which pipelines a draw needs (or how the scene is culled).
static func _copy_view_settings(source: Viewport, target: SubViewport) -> void:
	target.msaa_3d = source.msaa_3d
	target.use_taa = source.use_taa
	target.screen_space_aa = source.screen_space_aa
	target.use_debanding = source.use_debanding
	target.use_occlusion_culling = source.use_occlusion_culling
	target.mesh_lod_threshold = source.mesh_lod_threshold
	target.scaling_3d_mode = source.scaling_3d_mode
	target.scaling_3d_scale = source.scaling_3d_scale
	target.fsr_sharpness = source.fsr_sharpness
	target.texture_mipmap_bias = source.texture_mipmap_bias
	target.anisotropic_filtering_level = source.anisotropic_filtering_level
	target.vrs_mode = source.vrs_mode
	target.positional_shadow_atlas_size = source.positional_shadow_atlas_size
	target.positional_shadow_atlas_16_bits = source.positional_shadow_atlas_16_bits
	for quadrant: int in 4:
		target.set_positional_shadow_atlas_quadrant_subdiv(quadrant, source.get_positional_shadow_atlas_quadrant_subdiv(quadrant))


## Not disable_3d: warm() never changes it, and the boot flow turns 3D on while a
## long first-launch warm may still be running (a late restore turned it off).
static func _snapshot_view(view: Viewport) -> Dictionary:
	return {
		"msaa_3d": view.msaa_3d, "use_taa": view.use_taa,
		"screen_space_aa": view.screen_space_aa, "mesh_lod_threshold": view.mesh_lod_threshold,
		"scaling_3d_mode": view.scaling_3d_mode, "scaling_3d_scale": view.scaling_3d_scale,
	}


static func _restore_view(view: Viewport, snapshot: Dictionary) -> void:
	if view == null or not is_instance_valid(view): return
	for property: String in snapshot:
		if view.get(property) != snapshot[property]:
			view.set(property, snapshot[property])


# ---------------------------------------------------------------- feature latch

## Renders a tiny private scene that uses every feature the park can use (TAA motion vectors,
## SSAO/SSIL/SSR normal-roughness + separate specular, volumetric fog, glow, a reflection probe,
## directional PSSM, omni cubemap + dual-paraboloid and spot shadows). The renderer's global
## precompile key is then final before the park's surfaces arrive. Superset on purpose: the
## player can switch High/Night later and that must not trigger a full re-precompile.
static func latch_features(root_node: Node) -> Dictionary:
	if suppressed: return {"status": "suppressed"}
	if root_node == null or not is_instance_valid(root_node) or not root_node.is_inside_tree():
		return {"status": "no_tree"}
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return {"status": "skipped", "reason": "compatibility renderer"}
	var tree := root_node.get_tree()
	var started := Time.get_ticks_usec()
	var before := pipeline_counters()
	var view := SubViewport.new()
	view.name = "ShinraiFeatureLatch"
	view.size = LATCH_SIZE
	view.world_3d = World3D.new()
	_copy_view_settings(tree.root, view)
	view.use_taa = true # motion vectors are wanted even if a test root has TAA off
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.world_3d.environment = _latch_environment()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.52, 0.5)
	material.roughness = 0.4
	var cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	cube.mesh = box
	cube.position = Vector3(0, 0.5, 0)
	view.add_child(cube)
	var floor_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	plane.material = material
	floor_instance.mesh = plane
	view.add_child(floor_instance)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.rotation_degrees = Vector3(-40, -30, 0)
	view.add_child(sun)
	var omni_cube := OmniLight3D.new()
	omni_cube.shadow_enabled = true
	omni_cube.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	omni_cube.omni_range = 6.0
	omni_cube.position = Vector3(1.2, 1.4, 1.0)
	view.add_child(omni_cube)
	var omni_dual := OmniLight3D.new()
	omni_dual.shadow_enabled = true
	omni_dual.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	omni_dual.omni_range = 6.0
	omni_dual.position = Vector3(-1.2, 1.4, 1.0)
	view.add_child(omni_dual)
	var spot := SpotLight3D.new()
	spot.shadow_enabled = true
	spot.spot_range = 8.0
	spot.position = Vector3(0, 3.5, 0.5)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	view.add_child(spot)
	var probe := ReflectionProbe.new()
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	probe.size = Vector3(8, 4, 8)
	probe.position = Vector3(0, 1.5, 0)
	probe.enable_shadows = true
	view.add_child(probe)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.6, 3.2)
	view.add_child(camera)
	tree.root.add_child(view)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true

	var frames := 0
	while frames < LATCH_FRAMES and (Time.get_ticks_usec() - started) / 1000.0 < LATCH_CAP_MS:
		await RenderingServer.frame_post_draw
		frames += 1
		if not is_instance_valid(view): break
	if is_instance_valid(view):
		view.get_parent().remove_child(view)
		view.queue_free()
	last_latch_report = {
		"status": "ok",
		"ms": snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.1),
		"frames": frames,
		"pipelines": counters_delta(pipeline_counters(), before),
	}
	return last_latch_report


static func _latch_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.volumetric_fog_enabled = true
	env.adjustment_enabled = true
	return env


# ---------------------------------------------------------------- warm render

## Poses the game sees first: the HQ menu camera and the raid spawn view. On a first launch it adds
## the spawn view turned to the other three directions. `raid` is the ExtractionRun (may be null).
static func default_poses(park: Node3D, raid: Node = null) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	var menu_camera: Camera3D = raid.get("menu_camera") if raid != null else null
	if menu_camera != null and is_instance_valid(menu_camera) and menu_camera.is_inside_tree():
		poses.append(menu_camera.global_transform)
	else:
		poses.append(Transform3D.IDENTITY.translated(Vector3(142, 9, 160)).looking_at(Vector3(164, 3, 135)))
	var spawn := Vector3(70.0, 0.1, -201.5)
	var look := Vector3(120.0, 1.4, -203.5)
	if raid != null:
		var constants: Dictionary = raid.get_script().get_script_constant_map() if raid.get_script() != null else {}
		spawn = constants.get("RAID_SPAWN", spawn)
		look = constants.get("RAID_SPAWN_LOOK", look)
	var eye := spawn + Vector3(0, 1.6, 0)
	var forward := Vector3(look.x, eye.y, look.z)
	poses.append(Transform3D.IDENTITY.translated(eye).looking_at(forward))
	if is_first_launch():
		var dir := forward - eye
		for turn: int in [1, 2, 3]:
			poses.append(Transform3D.IDENTITY.translated(eye).looking_at(eye + dir.rotated(Vector3.UP, PI * 0.5 * turn)))
	return poses


## Draws the park from `poses` into a small offscreen SubViewport that shares the park's world and
## copies the main view's pipeline-relevant settings, for the given time of day and quality, until
## no new surface/draw/mesh pipelines appear and the render has settled (or the time cap is hit).
## The park's own night/quality state and the root viewport settings are restored afterwards.
## True while a warm() is rendering (callers that stopped waiting can wait for it).
static func is_busy() -> bool:
	return _busy

static func warm(park: Node3D, poses: Array[Transform3D], night: bool, high_quality: bool) -> Dictionary:
	if suppressed: return {"status": "suppressed"}
	if park == null or not is_instance_valid(park) or not park.is_inside_tree():
		return {"status": "no_park"}
	var tree := park.get_tree()
	var queued := 0
	while _busy and queued < 1200:
		await tree.process_frame
		queued += 1
	if not is_instance_valid(park) or not park.is_inside_tree(): return {"status": "no_park"}
	_busy = true
	var first_launch := is_first_launch()
	var cap := cap_override_ms if cap_override_ms > 0 else (CAP_FIRST_LAUNCH_MS if first_launch else CAP_MS)
	var started := Time.get_ticks_usec()
	var before := pipeline_counters()
	var root := tree.root
	var root_snapshot := _snapshot_view(root)

	# Time of day / quality variant (the park owns the environment, lights and lamp visibility).
	var restore_variant := {}
	if "is_night_mode" in park and "high_render_quality" in park and park.has_method("_apply_time_of_day"):
		if bool(park.get("is_night_mode")) != night or bool(park.get("high_render_quality")) != high_quality:
			restore_variant = {"night": park.get("is_night_mode"), "high": park.get("high_render_quality")}
			park.set("is_night_mode", night)
			park.set("high_render_quality", high_quality)
			park.call("_apply_time_of_day")

	var view := SubViewport.new()
	view.name = "ShinraiShaderWarmup"
	view.size = WARM_SIZE
	_copy_view_settings(root, view)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new()
	var source_camera := root.get_camera_3d()
	if source_camera != null:
		camera.fov = source_camera.fov
		camera.near = source_camera.near
		camera.far = source_camera.far
		camera.cull_mask = source_camera.cull_mask
		camera.attributes = source_camera.attributes
		camera.environment = source_camera.environment
		camera.keep_aspect = source_camera.keep_aspect
	else:
		camera.fov = 70.0
		camera.far = 1500.0
	view.add_child(camera)
	root.add_child(view)
	camera.current = true
	var view_rid := view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(view_rid, true)

	var pose_reports: Array = []
	var frames_total := 0
	var worst_frame_ms := 0.0
	var worst_render_ms := 0.0
	var capped := false
	var aborted := false
	for pose_index: int in poses.size():
		if aborted or capped: break
		camera.global_transform = poses[pose_index]
		var pose_before := pipeline_counters()
		var pose_started := Time.get_ticks_usec()
		var last := pose_before
		var stable := 0
		var frames := 0
		while true:
			var frame_started := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			if not is_instance_valid(view) or not is_instance_valid(park) or not park.is_inside_tree():
				aborted = true
				break
			frames += 1
			var frame_ms := (Time.get_ticks_usec() - frame_started) / 1000.0
			worst_frame_ms = maxf(worst_frame_ms, frame_ms)
			var render_ms := maxf(RenderingServer.viewport_get_measured_render_time_cpu(view_rid), RenderingServer.viewport_get_measured_render_time_gpu(view_rid))
			worst_render_ms = maxf(worst_render_ms, render_ms)
			var now := pipeline_counters()
			var grew: bool = now.surface != last.surface or now.draw != last.draw or now.mesh != last.mesh
			last = now
			stable = 0 if grew or render_ms > SETTLED_RENDER_MS else stable + 1
			if on_progress.is_valid():
				on_progress.call(clampf((pose_index + minf(frames / float(POSE_MIN_FRAMES + STABLE_FRAMES), 0.95)) / maxf(poses.size(), 1), 0.0, 1.0), "pose %d" % pose_index)
			if frames >= POSE_MIN_FRAMES and stable >= STABLE_FRAMES: break
			if frames >= POSE_MAX_FRAMES: break
			if (Time.get_ticks_usec() - started) / 1000.0 > cap:
				capped = true
				break
		frames_total += frames
		pose_reports.append({
			"pose": pose_index, "frames": frames,
			"ms": snappedf((Time.get_ticks_usec() - pose_started) / 1000.0, 0.1),
			"pipelines": counters_delta(pipeline_counters(), pose_before),
		})

	if is_instance_valid(view):
		RenderingServer.viewport_set_measure_render_time(view_rid, false)
		view.get_parent().remove_child(view)
		view.queue_free()
	if not restore_variant.is_empty() and is_instance_valid(park):
		park.set("is_night_mode", restore_variant.night)
		park.set("high_render_quality", restore_variant.high)
		park.call("_apply_time_of_day")
	_restore_view(root, root_snapshot)
	if on_progress.is_valid(): on_progress.call(1.0, "done")
	_busy = false
	last_warm_report = {
		"status": "aborted" if aborted else ("capped" if capped else "ok"),
		"ms": snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.1),
		"cap_ms": cap,
		"first_launch": first_launch,
		"night": night, "high": high_quality,
		"variant_switched": not restore_variant.is_empty(),
		"frames": frames_total,
		"worst_frame_ms": snappedf(worst_frame_ms, 0.1),
		"worst_view_render_ms": snappedf(worst_render_ms, 0.1),
		"poses": pose_reports,
		"pipelines": counters_delta(pipeline_counters(), before),
	}
	return last_warm_report
