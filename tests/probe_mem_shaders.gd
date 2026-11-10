extends SceneTree

# Shader / pipeline census for the boot memory work (fix 1 in the memory plan).
# Boots the real startup path (like tests/probe_mem_report.gd, throwaway QA profile)
# and prints:
#   SHADER_TICK   every second: pipeline compilation counters (mesh / surface / draw /
#                 specialization / canvas), the park's day-night and quality flags, the
#                 lake reflection viewport state and whether the shader warm-up is busy.
#   SHADER_STAGE  at every StartupTrace stage (needs --profile-startup): the same counters,
#                 so pipeline growth can be attributed to a build stage.
#   SHADER_BURST  when the specialization or surface counter jumps by >= 16 in one frame:
#                 what the scene state was (to pin what triggers specialization bursts).
#   SHADER_CENSUS at world_ready (+3 s): a walk of every GeometryInstance3D (overrides,
#                 overlays, every surface, next passes, particle draw passes): distinct
#                 Shader objects, distinct shader code texts (objects minus texts = pure
#                 duplicates), distinct .gdshader paths, distinct BaseMaterial3D feature
#                 keys (the engine shares one generated shader per key), each per owning
#                 top-level park module, and the duplicate groups with their owners.
#   godot --path . --script res://tests/probe_mem_shaders.gd -- --profile-startup
#         [--census-out=<abs path .json>] [--midori-fruit-seed=13]
# View attribution (opt-in; without these switches the run and its output are unchanged).
# Any of them adds SHADER_VIEW lines (and "view_marks" in the JSON) at world_ready,
# after the settle and after every later step, each with the counters, the delta since
# the previous SHADER_VIEW, soft-shadow lights in tree / in view, probes shown, and
# which SubViewports have drawn:
#   --view-marks             the marks only: the baseline boot to compare the others with.
#   --hold-lake-reflection   stop ONLY the planar reflection viewport from rendering
#                            (the lake keeps its shaders, banks and films, unlike
#                            enabled=false); released after the menu settle, so the delta
#                            at "lake_released" is the reflection-view-only pipelines.
#                            --hold-lake-reflection=run keeps it stopped through the raid
#                            and releases it last.
#   --hold-probes            hide every ReflectionProbe (not the feature latch's) until
#                            after world_ready + settle; delta at "probes_released".
#   --hard-shadows           every omni / spot light with light_size > 0 runs with
#                            light_size 0; restored last, delta at "soft_restored" (only
#                            meaningful if soft_in_view > 0 on that line).
#   --deploy                 press DEPLOY after the menu steps: deploy_pressed, raid_view,
#                            raid_5s (the +~150 at deploy).
#   --night-switch           flip day/night after the steps above: "night_switched".
#   --settle-ms=3000         wait before "settled" and after each release / switch.
#   --private-mb             add the process's private MB to each SHADER_VIEW line (asks
#                            PowerShell, about a second per mark; Windows only).
# Investigation only: edits nothing in the project and never touches the player's save.

const LoadState = preload("res://scripts/shinrai_load_state.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
const QA_PROFILE := "user://shinrai_shader_census_probe.json"
const LIMIT_MSEC := 900000
const BURST := 16

var started := 0
var args := PackedStringArray()
var out_path := ""
var _last_tick := 0
var _events_seen := 0
var _last := {}
var _park: Node3D = null
var _lake: SubViewport = null
var _lake_seen_active := false
var _lights_cached := -1
var _lights_at := 0
var _warmup: Script = null

# View attribution switches (see the header). All off by default.
var view_marks := false
var hold_lake := ""                 # "" | "menu" | "run"
var hold_probes := false
var hard_shadows := false
var do_deploy := false
var night_switch := false
var private_mb := false
var settle_ms := 3000
var _view_rows: Array = []
var _view_last := {}
var _lake_held := false
var _lake_blocked := 0              # frames in which the lake asked to render and was stopped
var _probes_held := false
var _probe_ids: Dictionary = {}     # ReflectionProbe instance id -> visibility the game asked for
var _light_ids: Dictionary = {}     # omni / spot light instance id -> true
var _soft_orig: Dictionary = {}     # light instance id -> light_size the game asked for
var _soft_held := false


func _initialize() -> void:
	started = Time.get_ticks_msec()
	args = OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--census-out="): out_path = a.get_slice("=", 1)
		elif a == "--view-marks": view_marks = true
		elif a == "--hold-lake-reflection" or a.begins_with("--hold-lake-reflection="): hold_lake = "run" if a.ends_with("=run") else "menu"
		elif a == "--hold-probes": hold_probes = true
		elif a == "--hard-shadows": hard_shadows = true
		elif a == "--deploy": do_deploy = true
		elif a == "--night-switch": night_switch = true
		elif a == "--private-mb": private_mb = true
		elif a.begins_with("--settle-ms="): settle_ms = maxi(0, int(a.get_slice("=", 1)))
	if hold_lake != "" or hold_probes or hard_shadows or do_deploy or night_switch or private_mb: view_marks = true
	_warmup = LoadState.warmup_script()
	_last = _counters()
	_view_last = _last
	if view_marks:
		_lake_held = hold_lake != ""
		_probes_held = hold_probes
		_soft_held = hard_shadows
		# Lights and probes are found as they enter the tree: a tree walk per frame
		# would be far too slow on the park.
		node_added.connect(_on_node_added)
		# After every node's _process and before the draw: the only point where the
		# lake's own UPDATE_ONCE request can be taken back for this frame.
		RenderingServer.frame_pre_draw.connect(_pre_draw)
		print("SHADER_VIEW switches ", JSON.stringify(_view_switches()))
	_run.call_deferred()


func _view_switches() -> Dictionary:
	return {"hold_lake": hold_lake, "hold_probes": hold_probes, "hard_shadows": hard_shadows, "deploy": do_deploy, "night_switch": night_switch, "settle_ms": settle_ms, "private_mb": private_mb}


## The feature latch renders its own tiny world on purpose (it fixes the renderer's
## precompile key); holding its probe or lights would change what is being measured.
func _in_latch(n: Node) -> bool:
	var at: Node = n
	while at != null:
		if at.name == &"ShinraiFeatureLatch": return true
		at = at.get_parent()
	return false


func _on_node_added(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		if not _in_latch(n): _light_ids[n.get_instance_id()] = true
	elif n is ReflectionProbe:
		if _in_latch(n): return
		var id := n.get_instance_id()
		var probe := n as ReflectionProbe
		# A probe re-entering the tree while held is hidden by us, not by the game.
		if not _probe_ids.has(id) or probe.visible: _probe_ids[id] = probe.visible
		if _probes_held: probe.visible = false
	elif hold_lake != "" and n is SubViewport and n.name == &"LakePlanarReflection":
		# Known from its first frame, so it cannot draw once before the hold finds it.
		_lake = n as SubViewport


## Re-applies the holds: game code may set light_size or show a probe at any time.
func _enforce() -> void:
	if _soft_held:
		for id: int in _light_ids.keys():
			var l := instance_from_id(id) as Light3D
			if l == null:
				_light_ids.erase(id)
				continue
			if l.light_size > 0.0:
				_soft_orig[id] = l.light_size
				l.light_size = 0.0
	if _probes_held:
		for id: int in _probe_ids.keys():
			var p := instance_from_id(id) as ReflectionProbe
			if p == null:
				_probe_ids.erase(id)
				continue
			if p.visible:
				_probe_ids[id] = true
				p.visible = false


func _pre_draw() -> void:
	var on_main := OS.get_thread_caller_id() == OS.get_main_thread_id()
	if on_main: _enforce()
	if _lake_held and _lake != null and is_instance_valid(_lake):
		if on_main:
			if _lake.render_target_update_mode != SubViewport.UPDATE_DISABLED: _lake_blocked += 1
			_lake.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# Straight to the server as well, in case the node skips an unchanged value.
		RenderingServer.viewport_set_update_mode(_lake.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_DISABLED)


func _release_probes() -> void:
	_probes_held = false
	var shown := 0
	for id: int in _probe_ids.keys():
		var p := instance_from_id(id) as ReflectionProbe
		if p != null and bool(_probe_ids[id]):
			p.visible = true
			shown += 1
	print("SHADER_VIEW probes released shown=%d tracked=%d" % [shown, _probe_ids.size()])


func _restore_soft() -> void:
	_soft_held = false
	var restored := 0
	for id: int in _soft_orig.keys():
		var l := instance_from_id(id) as Light3D
		if l != null:
			l.light_size = float(_soft_orig[id])
			restored += 1
	print("SHADER_VIEW soft shadows restored lights=%d" % restored)
	_soft_orig.clear()


## Private bytes of this process in MB, or -1. Engine monitors do not see driver
## memory, which is where pipelines live.
func _private_mb() -> float:
	if not private_mb or OS.get_name() != "Windows": return -1.0
	var out: Array = []
	var code := OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", "(Get-Process -Id %d).PrivateMemorySize64" % OS.get_process_id()], out)
	if code != 0 or out.is_empty(): return -1.0
	var text := String(out[0]).strip_edges()
	return float(text) / 1048576.0 if text.is_valid_int() else -1.0


## One SHADER_VIEW line: the counters, their growth since the previous line, and the
## view state that can explain that growth.
func _view_mark(label: String) -> void:
	if not view_marks: return
	var c := _counters()
	var cam := root.get_camera_3d()
	var soft_tree := 0
	var soft_shadow := 0
	var soft_view := 0
	var nearest := -1.0
	for id: int in _light_ids.keys():
		var l := instance_from_id(id) as Light3D
		if l == null:
			_light_ids.erase(id)
			continue
		# A light we zeroed still counts as soft: the question is where they are.
		if float(_soft_orig.get(id, l.light_size)) <= 0.0 or not l.is_inside_tree() or not l.is_visible_in_tree(): continue
		soft_tree += 1
		if not l.shadow_enabled: continue
		soft_shadow += 1
		if cam == null: continue
		var d := cam.global_position.distance_to(l.global_position)
		if nearest < 0.0 or d < nearest: nearest = d
		if cam.is_position_in_frustum(l.global_position): soft_view += 1
	var probes_shown := 0
	for id: int in _probe_ids.keys():
		var p := instance_from_id(id) as ReflectionProbe
		if p != null and p.is_inside_tree() and p.is_visible_in_tree(): probes_shown += 1
	# Objects in a SubViewport's last draw: 0 means it has never drawn anything.
	var drawn: Array = []
	var lake_objects := -1
	for v: Node in root.find_children("*", "SubViewport", true, false):
		var sv := v as SubViewport
		var objects := RenderingServer.viewport_get_render_info(sv.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		if sv == _lake: lake_objects = objects
		if objects > 0: drawn.append("%s@%dx%d:%d" % [sv.name, sv.size.x, sv.size.y, objects])
	var row := {
		"label": label, "t": (Time.get_ticks_msec() - started) / 1000.0, "counters": c,
		"d_spec": int(c.spec) - int(_view_last.spec), "d_surface": int(c.surface) - int(_view_last.surface), "d_mesh": int(c.mesh) - int(_view_last.mesh), "d_draw": int(c.draw) - int(_view_last.draw),
		"soft_in_tree": soft_tree, "soft_shadowed": soft_shadow, "soft_in_view": soft_view, "nearest_soft_m": snappedf(nearest, 0.1), "soft_zeroed": _soft_orig.size() if _soft_held else 0,
		"probes_shown": probes_shown, "probes_tracked": _probe_ids.size(), "probes_held": _probes_held,
		"lake_held": _lake_held, "lake_blocked_frames": _lake_blocked, "lake_objects_last_draw": lake_objects,
		"views_drawn": drawn, "private_mb": snappedf(_private_mb(), 0.1), "state": _state(),
	}
	_view_last = c
	_view_rows.append(row)
	print("SHADER_VIEW %s t=%.1f %s +spec=%d +surface=%d +mesh=%d +draw=%d soft_lights=%d/%d shadowed, %d in view (nearest %.1f m, zeroed %d) probes=%d/%d%s lake_held=%s blocked=%d lake_objects=%d private_mb=%.0f views_drawn=%s %s" % [
		label, row.t, _counters_text(c), row.d_spec, row.d_surface, row.d_mesh, row.d_draw, soft_shadow, soft_tree, soft_view, nearest, row.soft_zeroed,
		probes_shown, _probe_ids.size(), " (held)" if _probes_held else "", _lake_held, _lake_blocked, lake_objects, row.private_mb, ",".join(PackedStringArray(drawn)), row.state])


func _idle(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until: await process_frame


## A window without OS focus deploys straight into PAUSED (as in probe_menu_time.gd).
func _deployed(raid: Node) -> bool:
	return raid.phase == raid.Phase.RAID or (raid.phase == raid.Phase.PAUSED and not bool(raid.get("deployment_pending")))


## The steps after the census, in an order that keeps each delta attributable: the
## held views are released one at a time in the menu, then deploy, then night.
func _view_stages(raid: Node) -> void:
	await _idle(maxi(0, settle_ms - 3000))
	_view_mark("settled")
	if _probes_held:
		_release_probes()
		await _idle(settle_ms)
		_view_mark("probes_released")
	if _lake_held and hold_lake == "menu":
		_lake_held = false
		await _idle(settle_ms)
		_view_mark("lake_released")
	if do_deploy:
		if not raid.has_method("start_run"):
			print("SHADER_VIEW DEPLOY_UNAVAILABLE no start_run on the raid")
		else:
			raid.start_run()
			_view_mark("deploy_pressed")
			var deploy_started := Time.get_ticks_msec()
			while not _deployed(raid) and Time.get_ticks_msec() - deploy_started < 180000: await process_frame
			if not _deployed(raid):
				print("SHADER_VIEW DEPLOY_TIMEOUT")
			else:
				_view_mark("raid_view")
				if raid.phase == raid.Phase.PAUSED:
					print("SHADER_VIEW note: deployed into PAUSED (window focused=%s); resuming" % DisplayServer.window_is_focused())
					raid.resume_run()
				await _idle(5000)
				_view_mark("raid_5s")
	if night_switch:
		var park := _find_park()
		if park == null or not park.has_method("_apply_time_of_day"):
			print("SHADER_VIEW NIGHT_UNAVAILABLE")
		else:
			var to_night := not bool(park.get("is_night_mode"))
			park.set("is_night_mode", to_night)
			park.call("_apply_time_of_day")
			await _idle(maxi(settle_ms, 3000))
			_view_mark("night_switched_to_%s" % ("night" if to_night else "day"))
	if _lake_held:
		_lake_held = false
		await _idle(settle_ms)
		_view_mark("lake_released")
	if _soft_held:
		_restore_soft()
		await _idle(settle_ms)
		_view_mark("soft_restored")


func _counters() -> Dictionary:
	var rs := RenderingServer
	return {
		"canvas": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		"mesh": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		"surface": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		"draw": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		"spec": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
	}


func _counters_text(c: Dictionary) -> String:
	return "mesh=%d surface=%d draw=%d spec=%d canvas=%d" % [c.mesh, c.surface, c.draw, c.spec, c.canvas]


## Scene state that can change which pipelines a draw needs.
func _state() -> String:
	if _park == null or not is_instance_valid(_park): _park = _find_park()
	if _lake == null or not is_instance_valid(_lake):
		_lake = root.find_child("LakePlanarReflection", true, false) as SubViewport
	var night: Variant = _park.get("is_night_mode") if _park != null else null
	var high: Variant = _park.get("high_render_quality") if _park != null else null
	var lake := "none"
	if _lake != null:
		lake = "%s@%dx%d" % [["disabled", "once", "when_visible", "when_parent_visible", "always"][_lake.render_target_update_mode], _lake.size.x, _lake.size.y]
	var warm := false
	if _warmup != null: warm = bool(_warmup.call("is_busy"))
	var latch := root.get_node_or_null("ShinraiFeatureLatch") != null
	# Light counting walks the tree: at most once every 2 s.
	if Time.get_ticks_msec() - _lights_at >= 2000:
		_lights_at = Time.get_ticks_msec()
		var visible := 0
		var shadows := 0
		for l: Node in root.find_children("*", "Light3D", true, false):
			if (l as Light3D).is_visible_in_tree():
				visible += 1
				if (l as Light3D).shadow_enabled: shadows += 1
		_lights_cached = visible
		_lights_shadow_cached = shadows
	return "night=%s high=%s lake=%s warm_busy=%s latch=%s lights_visible=%d lights_shadow=%d" % [str(night), str(high), lake, warm, latch, _lights_cached, _lights_shadow_cached]
var _lights_shadow_cached := -1


func _process(_delta: float) -> bool:
	if view_marks: _enforce()
	var now := _counters()
	var t := (Time.get_ticks_msec() - started) / 1000.0
	var ds: int = int(now.spec) - int(_last.spec)
	var dsu: int = int(now.surface) - int(_last.surface)
	if ds >= BURST or dsu >= BURST:
		print("SHADER_BURST t=%.1f +spec=%d +surface=%d +mesh=%d stage='%s' %s" % [t, ds, dsu, int(now.mesh) - int(_last.mesh), LoadState.stage, _state()])
	_last = now
	if StartupTrace.enabled and StartupTrace.events.size() > _events_seen:
		var state := _state()
		for i: int in range(_events_seen, StartupTrace.events.size()):
			var ev: Dictionary = StartupTrace.events[i]
			print("SHADER_STAGE t=%.1f stage=%s dur_ms=%.0f %s %s" % [t, str(ev.get("stage", "")), float(ev.get("duration_ms", 0.0)), _counters_text(now), state])
		_events_seen = StartupTrace.events.size()
	if _lake != null and is_instance_valid(_lake) and not _lake_seen_active and _lake.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_lake_seen_active = true
		print("SHADER_LAKE_FIRST_RENDER t=%.1f %s %s" % [t, _counters_text(now), _state()])
	if Time.get_ticks_msec() - _last_tick >= 1000:
		_last_tick = Time.get_ticks_msec()
		print("SHADER_TICK t=%.1f wall=%s stage='%s' %s %s static_mb=%.0f vram_mb=%.0f tex_mb=%.0f buf_mb=%.0f" % [t, Time.get_time_string_from_system(), LoadState.stage, _counters_text(now), _state(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
	return false


func _timed_out() -> bool:
	return Time.get_ticks_msec() - started > LIMIT_MSEC


func _find_park() -> Node3D:
	for child: Node in root.get_children():
		if child is Node3D and (child.has_meta("shinrai_structure_pending") or child.has_method("_apply_time_of_day")): return child
	return null


func _find_raid() -> Node:
	var park := _find_park()
	return park.get_node_or_null("ExtractionRun") if park != null else null


func _run() -> void:
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var boot: Node = load(scene_path).instantiate()
	if not "profile_path" in boot:
		print("SHADER_PROBE ABORT no profile_path on boot scene")
		quit(1)
		return
	boot.profile_path = QA_PROFILE
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_PROFILE + suffix))
	print("SHADER_PROBE boot wall=%s driver=%s method=%s adapter=%s profile_startup=%s" % [Time.get_time_string_from_system(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), StartupTrace.enabled])
	root.add_child(boot)
	current_scene = boot
	await process_frame
	var raid: Node = null
	var stamped := {}
	while not _timed_out():
		if not stamped.has("menu") and LoadState.menu_shown:
			stamped.menu = true
			print("SHADER_MARK menu_visible t=%.1f %s %s" % [(Time.get_ticks_msec() - started) / 1000.0, _counters_text(_counters()), _state()])
		if not stamped.has("park") and _find_park() != null:
			stamped.park = true
			print("SHADER_MARK park_in_tree t=%.1f %s %s" % [(Time.get_ticks_msec() - started) / 1000.0, _counters_text(_counters()), _state()])
		if raid == null:
			raid = _find_raid()
			if raid != null: print("SHADER_MARK run_created t=%.1f %s %s" % [(Time.get_ticks_msec() - started) / 1000.0, _counters_text(_counters()), _state()])
		if raid != null and raid.world_ready(): break
		var loading := get_first_node_in_group("shinrai_loading_ui")
		var retry: Variant = loading.get("retry_button") if loading != null else null
		if retry is Control and (retry as Control).is_visible_in_tree():
			print("SHADER_MARK BOOT_FAILED")
			quit(1)
			return
		await process_frame
	if raid == null or not raid.world_ready():
		print("SHADER_MARK TIMEOUT")
		quit(1)
		return
	var ready_s := (Time.get_ticks_msec() - started) / 1000.0
	print("SHADER_MARK world_ready t=%.1f %s %s" % [ready_s, _counters_text(_counters()), _state()])
	_view_mark("world_ready")
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until: await process_frame
	var report := _census(_find_park())
	report["world_ready_s"] = ready_s
	report["pipelines_world_ready"] = _counters()
	report["pool"] = _pool_stats()
	print("SHADER_MARK after_census t=%.1f %s" % [(Time.get_ticks_msec() - started) / 1000.0, _counters_text(_counters())])
	if view_marks:
		await _view_stages(raid)
		report["view_switches"] = _view_switches()
		report["view_marks"] = _view_rows
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t", true))
			f.close()
			print("SHADER_PROBE wrote %s" % out_path)
	until = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until: await process_frame
	quit(0)


## The shader pool's counters, if the pool is in the tree. Defensive on purpose: this
## probe has one boot of budget, and a failed call here must not stop the census.
func _pool_stats() -> Dictionary:
	var path := "res://scripts/shinrai_shader_pool.gd"
	if not ResourceLoader.exists(path): return {"present": false}
	var pool: Script = load(path)
	if pool == null: return {"present": false}
	var has_stats := false
	for m: Dictionary in pool.get_script_method_list():
		if String(m.get("name", "")) == "stats":
			has_stats = true
			break
	if not has_stats: return {"present": true, "stats": "missing"}
	var stats: Variant = pool.call("stats")
	if not stats is Dictionary: return {"present": true, "stats": str(stats)}
	var out: Dictionary = stats
	out["present"] = true
	return out


# ---------------------------------------------------------------- census

## Properties that decide which generated shader a BaseMaterial3D uses (feature
## set, flags, modes, filters, which texture slots are in use), not its colours.
const FEATURE_KEYS: Array[String] = ["transparency", "alpha_antialiasing_mode", "blend_mode", "cull_mode", "depth_draw_mode", "no_depth_test", "shading_mode", "diffuse_mode", "specular_mode", "disable_ambient_light", "disable_fog", "disable_receive_shadows", "shadow_to_opacity", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "albedo_texture_force_srgb", "albedo_texture_msdf", "normal_enabled", "rim_enabled", "clearcoat_enabled", "anisotropy_enabled", "ao_enabled", "ao_on_uv2", "heightmap_enabled", "heightmap_deep_parallax", "subsurf_scatter_enabled", "subsurf_scatter_transmittance_enabled", "backlight_enabled", "refraction_enabled", "detail_enabled", "detail_uv_layer", "detail_blend_mode", "emission_enabled", "emission_operator", "emission_on_uv2", "uv1_triplanar", "uv1_world_triplanar", "uv2_triplanar", "uv2_world_triplanar", "texture_filter", "texture_repeat", "billboard_mode", "billboard_keep_scale", "grow", "fixed_size", "use_point_size", "use_particle_trails", "proximity_fade_enabled", "distance_fade_mode", "roughness_texture_channel", "metallic_texture_channel", "ao_texture_channel", "refraction_texture_channel", "bent_normal_enabled"]

var _mat_seen: Dictionary = {}       # material instance id -> true
var _shader_rows: Dictionary = {}    # shader instance id -> {code_hash, path, label, owners{}, materials}
var _code_groups: Dictionary = {}    # code md5 -> {shaders: n, materials: n, label, owners{}, len}
var _feature_groups: Dictionary = {} # feature key hash -> {materials: n, owners{}, sample}
var _modules: Dictionary = {}        # module -> row


func _module_row(module: String) -> Dictionary:
	if not _modules.has(module):
		_modules[module] = {"nodes": 0, "shader_materials": 0, "base_materials": 0, "other_materials": 0, "shader_objects": {}, "code_hashes": {}, "gdshader_paths": {}, "feature_keys": {}}
	return _modules[module]


func _module_of(node: Node, park: Node3D) -> String:
	var at: Node = node
	while at != null and at.get_parent() != null:
		if at.get_parent() == park: return "park/" + String(at.name)
		if at.get_parent() == root: return "root/" + String(at.name)
		at = at.get_parent()
	return "root/?"


func _census(park: Node3D) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var geometry := root.find_children("*", "GeometryInstance3D", true, false)
	var decals := root.find_children("*", "Decal", true, false).size()
	for g: Node in geometry:
		var gi := g as GeometryInstance3D
		var module := _module_of(gi, park)
		var row := _module_row(module)
		row.nodes += 1
		var mats: Array = []
		if gi.material_override != null: mats.append(gi.material_override)
		if gi.material_overlay != null: mats.append(gi.material_overlay)
		var meshes: Array = []
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh != null:
				meshes.append(mi.mesh)
				for s: int in range(mi.mesh.get_surface_count()):
					var o := mi.get_surface_override_material(s)
					if o != null: mats.append(o)
		elif gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh != null: meshes.append(mm.mesh)
		elif gi is GPUParticles3D:
			var gp := gi as GPUParticles3D
			for p: int in range(gp.draw_passes):
				var dm := gp.get_draw_pass_mesh(p)
				if dm != null: meshes.append(dm)
			if gp.process_material != null: mats.append(gp.process_material)
		elif gi is CPUParticles3D:
			var cp := gi as CPUParticles3D
			if cp.mesh != null: meshes.append(cp.mesh)
		for mesh: Mesh in meshes:
			for s: int in range(mesh.get_surface_count()):
				var m := mesh.surface_get_material(s)
				if m != null: mats.append(m)
		for m: Material in mats:
			var cur: Material = m
			var depth := 0
			while cur != null and depth < 4:
				_record_material(cur, module, row)
				cur = cur.next_pass
				depth += 1
	# Module totals as counts.
	var per_module: Dictionary = {}
	var keys: Array = _modules.keys()
	keys.sort()
	for k: String in keys:
		var r: Dictionary = _modules[k]
		per_module[k] = {"nodes": r.nodes, "shader_materials": r.shader_materials, "base_materials": r.base_materials, "other_materials": r.other_materials, "shader_objects": r.shader_objects.size(), "code_hashes": r.code_hashes.size(), "gdshader_paths": r.gdshader_paths.size(), "feature_keys": r.feature_keys.size()}
	var gdshader_paths: Dictionary = {}
	var shader_materials := 0
	var base_materials := 0
	for id: int in _shader_rows:
		var sr: Dictionary = _shader_rows[id]
		if sr.path != "": gdshader_paths[sr.path] = true
		shader_materials += int(sr.materials)
	for fk: int in _feature_groups: base_materials += int(_feature_groups[fk].materials)
	var dup_groups: Array = []
	for h: String in _code_groups:
		var cg: Dictionary = _code_groups[h]
		if int(cg.shaders) > 1:
			dup_groups.append({"code_md5": h, "shaders": cg.shaders, "materials": cg.materials, "len": cg.len, "label": cg.label, "owners": cg.owners.keys()})
	dup_groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.shaders) > int(b.shaders))
	var features: Array = []
	for fk: int in _feature_groups:
		var fg: Dictionary = _feature_groups[fk]
		features.append({"key": fk, "materials": fg.materials, "owners": fg.owners.keys(), "sample": fg.sample})
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.materials) > int(b.materials))
	var totals := {
		"geometry_nodes": geometry.size(), "decals": decals,
		"materials_seen": _mat_seen.size(), "shader_materials": shader_materials, "base_materials": base_materials,
		"shader_objects": _shader_rows.size(), "shader_code_texts": _code_groups.size(), "shader_duplicates": _shader_rows.size() - _code_groups.size(),
		"gdshader_paths": gdshader_paths.size(), "base_feature_keys": _feature_groups.size(),
	}
	var report := {"totals": totals, "per_module": per_module, "duplicate_groups": dup_groups, "feature_groups": features, "gdshader_paths": gdshader_paths.keys(), "census_ms": Time.get_ticks_msec() - t0}
	print("SHADER_CENSUS totals ", JSON.stringify(totals))
	for k: String in keys:
		var r: Dictionary = per_module[k]
		if int(r.shader_objects) == 0 and int(r.base_materials) == 0: continue
		print("SHADER_CENSUS module %-52s nodes=%6d shader_mats=%4d shader_objs=%4d code_texts=%4d gdshader_paths=%3d base_mats=%4d feature_keys=%3d" % [k, r.nodes, r.shader_materials, r.shader_objects, r.code_hashes, r.gdshader_paths, r.base_materials, r.feature_keys])
	for d: Dictionary in dup_groups.slice(0, 60):
		print("SHADER_CENSUS dup shaders=%3d materials=%4d len=%6d %s owners=%s" % [d.shaders, d.materials, d.len, d.label, ",".join(PackedStringArray(d.owners))])
	for f: Dictionary in features.slice(0, 40):
		print("SHADER_CENSUS feature materials=%4d %s owners=%d" % [f.materials, f.sample, f.owners.size()])
	print("SHADER_CENSUS pool ", JSON.stringify(_pool_stats()))
	print("SHADER_CENSUS census_ms=%d" % report.census_ms)
	return report


func _record_material(m: Material, module: String, row: Dictionary) -> void:
	var id := m.get_instance_id()
	var first := not _mat_seen.has(id)
	_mat_seen[id] = true
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if first: row.shader_materials += 1
		var sh := sm.shader
		if sh == null: return
		var sid := sh.get_instance_id()
		row.shader_objects[sid] = true
		if not _shader_rows.has(sid):
			var code := sh.code
			var h := code.md5_text()
			_shader_rows[sid] = {"code_md5": h, "path": sh.resource_path, "materials": 0, "owners": {}}
			if not _code_groups.has(h):
				_code_groups[h] = {"shaders": 0, "materials": 0, "len": code.length(), "label": _label(sh, code), "owners": {}}
			_code_groups[h].shaders += 1
		var sr: Dictionary = _shader_rows[sid]
		sr.owners[module] = true
		if first:
			sr.materials += 1
			_code_groups[sr.code_md5].materials += 1
		_code_groups[sr.code_md5].owners[module] = true
		row.code_hashes[sr.code_md5] = true
		if sr.path != "": row.gdshader_paths[sr.path] = true
	elif m is BaseMaterial3D:
		if first: row.base_materials += 1
		var bm := m as BaseMaterial3D
		var parts: Array = [m.get_class()]
		for k: String in FEATURE_KEYS: parts.append(bm.get(k))
		var slots := 0
		for p: int in BaseMaterial3D.TEXTURE_MAX:
			if bm.get_texture(p) != null: slots |= 1 << p
		parts.append(slots)
		var fk := hash(parts)
		row.feature_keys[fk] = true
		if not _feature_groups.has(fk):
			_feature_groups[fk] = {"materials": 0, "owners": {}, "sample": "%s transp=%d blend=%d cull=%d depth=%d shading=%d billboard=%d filter=%d normal=%s emission=%s rim=%s backlight=%s detail=%s triplanar=%s slots=%d name=%s" % [m.get_class(), bm.transparency, bm.blend_mode, bm.cull_mode, bm.depth_draw_mode, bm.shading_mode, bm.billboard_mode, bm.texture_filter, bm.normal_enabled, bm.emission_enabled, bm.rim_enabled, bm.backlight_enabled, bm.detail_enabled, bm.uv1_triplanar, slots, m.resource_name]}
		if first: _feature_groups[fk].materials += 1
		_feature_groups[fk].owners[module] = true
	else:
		if first: row.other_materials += 1


func _label(sh: Shader, code: String) -> String:
	if sh.resource_path != "": return sh.resource_path
	var lines := code.split("\n", false)
	var render_mode := ""
	var first_uniform := ""
	for l: String in lines:
		var s := l.strip_edges()
		if render_mode == "" and s.begins_with("render_mode"): render_mode = s.left(60)
		if first_uniform == "" and s.begins_with("uniform"): first_uniform = s.left(60)
		if render_mode != "" and first_uniform != "": break
	return "inline[%s | %s]" % [render_mode, first_uniform]
