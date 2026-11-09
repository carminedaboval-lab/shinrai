extends SceneTree

# Memory probe: boots the real startup path (like tests/probe_menu_time.gd, with a
# throwaway QA profile), prints an engine-side memory sample every second during the
# build (MEM_TICK lines, wall-clock stamped so an OS-side sampler can be aligned), and
# at world_ready writes a full report (MEM_REPORT lines + JSON):
#   Performance monitors, RenderingServer totals, node counts by class, lights and
#   shadows, colliders, the biggest meshes and textures, and a per-top-level-park-node
#   attribution of mesh / multimesh / texture bytes plus an estimate of the GDScript
#   data (arrays, dictionaries, packed arrays, images) held by every park node, the
#   raid, the autoloads and every loaded script's static variables.
#   godot --path . --script res://tests/probe_mem_report.gd -- [--profile-startup]
#         [--mem-out=<abs path .json>] [--direct-raid] [--tick-ms=1000]
# --direct-raid: boot scenes/shinrai_extraction.tscn directly (test_extraction style),
#   for headless runs where the menu-first bootstrap cannot be used.
# Investigation only: edits nothing in the project and never touches the player's save.

const LoadState = preload("res://scripts/shinrai_load_state.gd")
const QA_PROFILE := "user://shinrai_mem_probe.json"
const LIMIT_MSEC := 900000

var started := 0
var args := PackedStringArray()
var out_path := ""
var tick_ms := 1000
var _last_tick := 0
var _frames := 0
var _worst_frame_ms := 0.0
var _last_frame := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	args = OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--mem-out="): out_path = a.get_slice("=", 1)
		if a.begins_with("--tick-ms="): tick_ms = int(a.get_slice("=", 1))
	_run.call_deferred()

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last_frame > 0: _worst_frame_ms = maxf(_worst_frame_ms, (now - _last_frame) / 1000.0)
	_last_frame = now
	_frames += 1
	if Time.get_ticks_msec() - _last_tick >= tick_ms:
		_last_tick = Time.get_ticks_msec()
		_tick("tick")
	return false

func _mb(b: float) -> float:
	return snappedf(b / 1048576.0, 0.1)

func _tick(label: String) -> void:
	var mi := OS.get_memory_info()
	print("MEM_TICK %s wall=%s t=%.1f stage='%s' load=%.0f%% static_mb=%.1f static_max_mb=%.1f vram_mb=%.1f tex_mb=%.1f buf_mb=%.1f objects=%d nodes=%d resources=%d orphans=%d phys_active=%d phys_pairs=%d phys_islands=%d os_free_mb=%.0f os_avail_mb=%.0f worst_frame_ms=%.0f" % [
		label, Time.get_time_string_from_system(), (Time.get_ticks_msec() - started) / 1000.0, LoadState.stage, LoadState.fraction * 100.0,
		_mb(Performance.get_monitor(Performance.MEMORY_STATIC)), _mb(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		_mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), _mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), _mb(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)), int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)),
		float(mi.get("free", 0)) / 1048576.0, float(mi.get("available", 0)) / 1048576.0, _worst_frame_ms])
	_worst_frame_ms = 0.0

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
	var direct := "--direct-raid" in args
	var scene_path: String = "res://scenes/shinrai_extraction.tscn" if direct else ProjectSettings.get_setting("application/run/main_scene")
	var boot: Node = load(scene_path).instantiate()
	if not "profile_path" in boot:
		print("MEM_PROBE ABORT no profile_path on boot scene")
		quit(1)
		return
	boot.profile_path = QA_PROFILE
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_PROFILE + suffix))
	print("MEM_PROBE boot wall=%s scene=%s headless=%s driver=%s video_adapter=%s" % [Time.get_time_string_from_system(), scene_path, DisplayServer.get_name() == "headless", RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()])
	_tick("before_scene")
	root.add_child(boot)
	current_scene = boot
	await process_frame
	_tick("first_frame")
	var raid: Node = null
	var park_seen := false
	var menu_seen := false
	while not _timed_out():
		if not menu_seen and LoadState.menu_shown:
			menu_seen = true
			_tick("menu_visible")
		if not park_seen and _find_park() != null:
			park_seen = true
			_tick("park_in_tree")
		if raid == null:
			raid = _find_raid()
			if raid != null: _tick("run_created")
		if raid != null and raid.world_ready(): break
		var loading := get_first_node_in_group("shinrai_loading_ui")
		var retry: Variant = loading.get("retry_button") if loading != null else null
		if retry is Control and (retry as Control).is_visible_in_tree():
			_tick("BOOT_FAILED")
			quit(1)
			return
		await process_frame
	if raid == null or not raid.world_ready():
		_tick("TIMEOUT")
		quit(1)
		return
	_tick("world_ready")
	print("MEM_PROBE world_ready at %.1f s wall=%s" % [(Time.get_ticks_msec() - started) / 1000.0, Time.get_time_string_from_system()])
	# Let the menu settle so the report sees the resting state, not the last build frame.
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until: await process_frame
	_tick("menu_idle_3s")
	var report := _report(_find_park(), raid)
	_tick("after_report")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t", true))
			f.close()
			print("MEM_PROBE wrote %s" % out_path)
	# Hold a few seconds so the OS sampler catches the resting process.
	until = Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < until: await process_frame
	_tick("exit")
	quit(0)

# ---------------------------------------------------------------- report

var _mesh_seen: Dictionary = {}      # mesh instance id -> row dictionary
var _tex_seen: Dictionary = {}       # texture instance id -> row dictionary
var _mat_seen: Dictionary = {}       # material instance id -> true
var _obj_seen: Dictionary = {}       # objects visited by the GDScript data walk

func _report(park: Node3D, raid: Node) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var rep: Dictionary = {}
	rep["wall"] = Time.get_time_string_from_system()
	rep["t_s"] = (Time.get_ticks_msec() - started) / 1000.0
	rep["monitors"] = _monitors()
	rep["rendering_info"] = _rendering_info()
	var classes: Dictionary = {}
	var lights: Dictionary = {}
	var shapes: Dictionary = {}
	var totals := {"nodes": 0, "mesh_instances": 0, "mesh_instances_visible": 0, "mmi": 0, "mm_instances": 0, "mm_instances_visible_nodes": 0, "collision_shapes": 0, "static_bodies": 0, "rigid_bodies": 0, "character_bodies": 0, "areas": 0, "particles": 0, "decals": 0, "reflection_probes": 0, "voxel_gi": 0, "lights": 0, "lights_shadow": 0, "concave_faces": 0, "heightmap_cells": 0, "convex_points": 0, "mesh_bytes_unique": 0, "mm_buffer_bytes": 0, "tex_bytes_unique": 0}
	var per_top: Dictionary = {}
	# The park's top-level nodes, then every other root child as its own bucket.
	var buckets: Array = []
	if park != null:
		for top: Node in park.get_children(): buckets.append(["park/" + String(top.name), top])
	for child: Node in root.get_children():
		if child != park: buckets.append(["root/" + String(child.name), child])
	for b: Array in buckets:
		var key: String = b[0]
		var row := {"nodes": 0, "mesh_instances": 0, "mmi": 0, "mm_instances": 0, "mesh_bytes_first_owner": 0, "mesh_bytes_shared_refs": 0, "mm_buffer_bytes": 0, "tex_bytes_first_owner": 0, "collision_shapes": 0, "concave_faces": 0, "lights": 0, "lights_shadow": 0, "tris": 0}
		var stack: Array[Node] = [b[1]]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for c: Node in node.get_children(): stack.append(c)
			row.nodes += 1
			totals.nodes += 1
			var cls := node.get_class()
			classes[cls] = int(classes.get(cls, 0)) + 1
			if node is MeshInstance3D:
				var mi := node as MeshInstance3D
				row.mesh_instances += 1
				totals.mesh_instances += 1
				if mi.is_visible_in_tree(): totals.mesh_instances_visible += 1
				var mrow := _mesh_row(mi.mesh, node.get_path())
				if mrow.is_empty(): continue
				row.tris += int(mrow.tris)
				if mrow.first:
					row.mesh_bytes_first_owner += int(mrow.bytes)
					totals.mesh_bytes_unique += int(mrow.bytes)
				else:
					row.mesh_bytes_shared_refs += int(mrow.bytes)
				row.tex_bytes_first_owner += _materials_of(mi, mi.mesh, node.get_path())
			elif node is MultiMeshInstance3D:
				var mmi := node as MultiMeshInstance3D
				row.mmi += 1
				totals.mmi += 1
				var mm := mmi.multimesh
				if mm != null:
					var n := mm.instance_count
					var vis := mm.visible_instance_count if mm.visible_instance_count >= 0 else n
					row.mm_instances += n
					totals.mm_instances += n
					if mmi.is_visible_in_tree(): totals.mm_instances_visible_nodes += vis
					var floats := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
					if mm.transform_format == MultiMesh.TRANSFORM_2D: floats -= 4
					var bytes := n * floats * 4
					row.mm_buffer_bytes += bytes
					totals.mm_buffer_bytes += bytes
					var mrow := _mesh_row(mm.mesh, node.get_path())
					if not mrow.is_empty():
						row.tris += vis * int(mrow.tris)
						if mrow.first:
							row.mesh_bytes_first_owner += int(mrow.bytes)
							totals.mesh_bytes_unique += int(mrow.bytes)
						else:
							row.mesh_bytes_shared_refs += int(mrow.bytes)
					row.tex_bytes_first_owner += _materials_of(mmi, mm.mesh, node.get_path())
			elif node is CollisionShape3D:
				row.collision_shapes += 1
				totals.collision_shapes += 1
				var sh := (node as CollisionShape3D).shape
				var scls := sh.get_class() if sh != null else "null"
				shapes[scls] = int(shapes.get(scls, 0)) + 1
				if sh is ConcavePolygonShape3D:
					var faces := (sh as ConcavePolygonShape3D).get_faces().size() / 3
					row.concave_faces += faces
					totals.concave_faces += faces
				elif sh is HeightMapShape3D:
					var hm := sh as HeightMapShape3D
					totals.heightmap_cells += hm.map_width * hm.map_depth
				elif sh is ConvexPolygonShape3D:
					totals.convex_points += (sh as ConvexPolygonShape3D).points.size()
			elif node is StaticBody3D: totals.static_bodies += 1
			elif node is RigidBody3D: totals.rigid_bodies += 1
			elif node is CharacterBody3D: totals.character_bodies += 1
			elif node is Area3D: totals.areas += 1
			elif node is GPUParticles3D or node is CPUParticles3D: totals.particles += 1
			elif node is Decal: totals.decals += 1
			elif node is ReflectionProbe: totals.reflection_probes += 1
			elif node is VoxelGI: totals.voxel_gi += 1
			elif node is Light3D:
				var l := node as Light3D
				row.lights += 1
				totals.lights += 1
				var lk := cls + ("/shadow" if l.shadow_enabled else "") + ("/hidden" if not l.is_visible_in_tree() else "")
				lights[lk] = int(lights.get(lk, 0)) + 1
				if l.shadow_enabled:
					row.lights_shadow += 1
					totals.lights_shadow += 1
			elif node is WorldEnvironment:
				var env := (node as WorldEnvironment).environment
				if env != null:
					rep["environment"] = {"sdfgi": env.sdfgi_enabled, "ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "ssr": env.ssr_enabled, "glow": env.glow_enabled, "volumetric_fog": env.volumetric_fog_enabled, "background": env.background_mode, "sky": env.sky != null and env.sky.sky_material != null, "sky_material": env.sky.sky_material.get_class() if env.sky != null and env.sky.sky_material != null else ""}
		row["script_data_bytes_est"] = _script_data_of_node(b[1])
		per_top[key] = row
	for id: int in _tex_seen: totals.tex_bytes_unique += int(_tex_seen[id].bytes)
	rep["totals"] = totals
	rep["classes"] = classes
	rep["lights"] = lights
	rep["shapes"] = shapes
	rep["per_top"] = per_top
	# Biggest meshes / textures.
	var meshes: Array = _mesh_seen.values()
	meshes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.bytes) > int(b.bytes))
	rep["top_meshes"] = meshes.slice(0, 40)
	rep["unique_meshes"] = meshes.size()
	var texes: Array = _tex_seen.values()
	texes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.bytes) > int(b.bytes))
	rep["top_textures"] = texes.slice(0, 40)
	rep["unique_textures"] = texes.size()
	var tex_by_format: Dictionary = {}
	for t: Dictionary in texes:
		var k: String = str(t.format) + ("/mip" if t.mipmaps > 1 else "/nomip")
		var e: Dictionary = tex_by_format.get(k, {"count": 0, "bytes": 0})
		e.count += 1
		e.bytes += int(t.bytes)
		tex_by_format[k] = e
	rep["textures_by_format"] = tex_by_format
	rep["unique_materials"] = _mat_seen.size()
	# Static variables of every loaded script.
	rep["script_statics"] = _script_statics()
	# Viewports and their sizes (render targets).
	var vps: Array = []
	for vp: Node in root.find_children("*", "Viewport", true, false):
		vps.append({"path": String(vp.get_path()), "size": str((vp as Viewport).get_visible_rect().size), "msaa": (vp as Viewport).msaa_3d, "scaling": (vp as Viewport).scaling_3d_scale})
	vps.append({"path": "root", "size": str(root.get_visible_rect().size), "msaa": root.msaa_3d, "scaling": root.scaling_3d_scale, "window": str(root.size), "taa": root.use_taa})
	rep["viewports"] = vps
	rep["report_ms"] = Time.get_ticks_msec() - t0
	rep["monitors_after"] = _monitors()
	_print_report(rep)
	return rep

func _monitors() -> Dictionary:
	return {
		"memory_static_mb": _mb(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"memory_static_max_mb": _mb(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"memory_message_buffer_max_mb": _mb(Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"object_node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"object_orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"render_total_objects_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"render_total_primitives_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"render_total_draw_calls_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_video_mem_mb": _mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"render_texture_mem_mb": _mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"render_buffer_mem_mb": _mb(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"physics_3d_active_objects": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"physics_3d_collision_pairs": int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		"physics_3d_island_count": int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)),
		"os_static_memory_usage_mb": _mb(OS.get_static_memory_usage()),
		"os_static_memory_peak_mb": _mb(OS.get_static_memory_peak_usage()),
		"os_memory_info": OS.get_memory_info(),
	}

func _rendering_info() -> Dictionary:
	var rs := RenderingServer
	return {
		"total_objects_in_frame": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"total_primitives_in_frame": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"total_draw_calls_in_frame": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_mem_mb": _mb(rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)),
		"texture_mem_mb": _mb(rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)),
		"buffer_mem_mb": _mb(rs.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)),
		"pipeline_compilations_mesh": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		"pipeline_compilations_surface": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		"pipeline_compilations_specialization": rs.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		"driver": rs.get_current_rendering_driver_name(),
		"method": rs.get_current_rendering_method(),
		"adapter": rs.get_video_adapter_name(),
	}

## One row per unique mesh: vertex / index counts and the GPU byte estimate
## (Godot's packed vertex strides, plus 16- or 32-bit indices).
func _mesh_row(mesh: Mesh, owner: NodePath) -> Dictionary:
	if mesh == null: return {}
	var id := mesh.get_instance_id()
	if _mesh_seen.has(id):
		var seen: Dictionary = _mesh_seen[id]
		seen.refs += 1
		return {"bytes": seen.bytes, "tris": seen.tris, "first": false}
	var verts := 0
	var idx := 0
	var bytes := 0
	var surfaces := mesh.get_surface_count()
	if mesh is ArrayMesh:
		var am := mesh as ArrayMesh
		for s: int in surfaces:
			var v := am.surface_get_array_len(s)
			var i := am.surface_get_array_index_len(s)
			var fmt := am.surface_get_format(s)
			verts += v
			idx += i
			var stride := RenderingServer.mesh_surface_get_format_vertex_stride(fmt, v) + RenderingServer.mesh_surface_get_format_normal_tangent_stride(fmt, v) + RenderingServer.mesh_surface_get_format_attribute_stride(fmt, v) + RenderingServer.mesh_surface_get_format_skin_stride(fmt, v)
			bytes += v * stride + i * (2 if v <= 65536 else 4)
	else:
		var arrays: Array = (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else []
		if not arrays.is_empty():
			var vv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			verts = vv.size()
			var ii: Variant = arrays[Mesh.ARRAY_INDEX]
			idx = (ii as PackedInt32Array).size() if ii is PackedInt32Array else 0
			bytes = verts * 36 + idx * 4
		else:
			verts = mesh.get_faces().size()
			bytes = verts * 36
	var tris := (idx if idx > 0 else verts) / 3
	var row := {"id": id, "class": mesh.get_class(), "path": mesh.resource_path, "name": mesh.resource_name, "owner": String(owner), "surfaces": surfaces, "verts": verts, "indices": idx, "tris": tris, "bytes": bytes, "refs": 1}
	_mesh_seen[id] = row
	return {"bytes": bytes, "tris": tris, "first": true}

## Texture bytes first seen through this node's materials (override, surface overrides,
## mesh surface materials, next passes).
func _materials_of(gi: GeometryInstance3D, mesh: Mesh, owner: NodePath) -> int:
	var total := 0
	var mats: Array = []
	if gi.material_override != null: mats.append(gi.material_override)
	if gi.material_overlay != null: mats.append(gi.material_overlay)
	if mesh != null:
		for s: int in mesh.get_surface_count():
			if gi is MeshInstance3D:
				var o := (gi as MeshInstance3D).get_surface_override_material(s)
				if o != null: mats.append(o)
			var m := mesh.surface_get_material(s)
			if m != null: mats.append(m)
	for m: Material in mats:
		var depth := 0
		var cur: Material = m
		while cur != null and depth < 4:
			total += _textures_of_material(cur, owner)
			cur = cur.next_pass
			depth += 1
	return total

func _textures_of_material(m: Material, owner: NodePath) -> int:
	var id := m.get_instance_id()
	if _mat_seen.has(id): return 0
	_mat_seen[id] = true
	var total := 0
	if m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		for p: int in BaseMaterial3D.TEXTURE_MAX:
			var t := bm.get_texture(p)
			if t != null: total += _tex_row(t, owner)
	elif m is ShaderMaterial:
		var sm := m as ShaderMaterial
		if sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list(true):
				if int(u.get("type", 0)) == TYPE_OBJECT:
					var v: Variant = sm.get_shader_parameter(u.name)
					if v is Texture2D: total += _tex_row(v, owner)
					elif v is Texture2DArray or v is Texture3D or v is TextureLayered:
						total += _tex_layered_row(v, owner)
	return total

const _BPP := {
	Image.FORMAT_L8: 1.0, Image.FORMAT_LA8: 2.0, Image.FORMAT_R8: 1.0, Image.FORMAT_RG8: 2.0, Image.FORMAT_RGB8: 3.0, Image.FORMAT_RGBA8: 4.0, Image.FORMAT_RGBA4444: 2.0, Image.FORMAT_RGB565: 2.0,
	Image.FORMAT_RF: 4.0, Image.FORMAT_RGF: 8.0, Image.FORMAT_RGBF: 12.0, Image.FORMAT_RGBAF: 16.0, Image.FORMAT_RH: 2.0, Image.FORMAT_RGH: 4.0, Image.FORMAT_RGBH: 6.0, Image.FORMAT_RGBAH: 8.0, Image.FORMAT_RGBE9995: 4.0,
	Image.FORMAT_DXT1: 0.5, Image.FORMAT_DXT3: 1.0, Image.FORMAT_DXT5: 1.0, Image.FORMAT_RGTC_R: 0.5, Image.FORMAT_RGTC_RG: 1.0, Image.FORMAT_BPTC_RGBA: 1.0, Image.FORMAT_BPTC_RGBF: 1.0, Image.FORMAT_BPTC_RGBFU: 1.0,
	Image.FORMAT_ETC: 0.5, Image.FORMAT_ETC2_R11: 0.5, Image.FORMAT_ETC2_RG11: 1.0, Image.FORMAT_ETC2_RGB8: 0.5, Image.FORMAT_ETC2_RGBA8: 1.0, Image.FORMAT_ETC2_RGB8A1: 0.5, Image.FORMAT_ETC2_RA_AS_RG: 1.0, Image.FORMAT_DXT5_RA_AS_RG: 1.0, Image.FORMAT_ASTC_4x4: 1.0, Image.FORMAT_ASTC_8x8: 0.25,
}
const _COMPRESSED := [Image.FORMAT_DXT1, Image.FORMAT_DXT3, Image.FORMAT_DXT5, Image.FORMAT_RGTC_R, Image.FORMAT_RGTC_RG, Image.FORMAT_BPTC_RGBA, Image.FORMAT_BPTC_RGBF, Image.FORMAT_BPTC_RGBFU, Image.FORMAT_ETC, Image.FORMAT_ETC2_R11, Image.FORMAT_ETC2_RG11, Image.FORMAT_ETC2_RGB8, Image.FORMAT_ETC2_RGBA8, Image.FORMAT_ETC2_RGB8A1, Image.FORMAT_ETC2_RA_AS_RG, Image.FORMAT_DXT5_RA_AS_RG, Image.FORMAT_ASTC_4x4, Image.FORMAT_ASTC_8x8]

func _rd_format(rid: RID) -> Dictionary:
	# Mipmap count and layers through the RenderingDevice texture (no readback).
	var rd := RenderingServer.get_rendering_device()
	if rd == null: return {}
	var rd_rid := RenderingServer.texture_get_rd_texture(rid)
	if not rd_rid.is_valid(): return {}
	var f := rd.texture_get_format(rd_rid)
	if f == null: return {}
	return {"mipmaps": f.mipmaps, "layers": f.array_layers, "depth": f.depth, "rd_format": f.format, "w": f.width, "h": f.height}

func _tex_row(t: Texture2D, owner: NodePath) -> int:
	var id := t.get_instance_id()
	if _tex_seen.has(id):
		_tex_seen[id].refs += 1
		return 0
	var w := t.get_width()
	var h := t.get_height()
	var fmt := RenderingServer.texture_get_format(t.get_rid())
	var rdf := _rd_format(t.get_rid())
	var mips: int = int(rdf.get("mipmaps", 1))
	var bpp: float = _BPP.get(fmt, 4.0)
	var bytes := int(w * h * bpp * (1.3333 if mips > 1 else 1.0))
	_tex_seen[id] = {"id": id, "class": t.get_class(), "path": t.resource_path, "name": t.resource_name, "owner": String(owner), "w": w, "h": h, "format": fmt, "compressed": fmt in _COMPRESSED, "mipmaps": mips, "bytes": bytes, "refs": 1}
	return bytes

func _tex_layered_row(t: Texture, owner: NodePath) -> int:
	var id := t.get_instance_id()
	if _tex_seen.has(id):
		_tex_seen[id].refs += 1
		return 0
	var rdf := _rd_format(t.get_rid())
	var w: int = int(rdf.get("w", 0))
	var h: int = int(rdf.get("h", 0))
	var layers: int = int(rdf.get("layers", 1)) * maxi(1, int(rdf.get("depth", 1)))
	var mips: int = int(rdf.get("mipmaps", 1))
	var fmt := Image.FORMAT_RGBA8
	if t is TextureLayered: fmt = (t as TextureLayered).get_format()
	var bpp: float = _BPP.get(fmt, 4.0)
	var bytes := int(w * h * layers * bpp * (1.3333 if mips > 1 else 1.0))
	_tex_seen[id] = {"id": id, "class": t.get_class(), "path": t.resource_path, "name": t.resource_name, "owner": String(owner), "w": w, "h": h, "layers": layers, "format": fmt, "compressed": fmt in _COMPRESSED, "mipmaps": mips, "bytes": bytes, "refs": 1}
	return bytes

# ------------------------------------------------- GDScript data estimate

const MAX_DEPTH := 5
const SAMPLE := 256

## Rough byte estimate of a Variant's heap footprint. Packed arrays are exact
## (element size * count); Arrays and Dictionaries count 24 bytes per Variant slot
## plus their contents (sampled past SAMPLE elements); Strings 4 bytes a char;
## Images their data size; script objects recurse into their script variables once.
func _var_bytes(v: Variant, depth: int) -> int:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_RECT2, TYPE_RECT2I, TYPE_PLANE, TYPE_QUATERNION, TYPE_COLOR, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL:
			return 0
		TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_BASIS, TYPE_AABB, TYPE_PROJECTION: return 64
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH: return 24 + str(v).length() * 4
		TYPE_PACKED_BYTE_ARRAY: return 24 + (v as PackedByteArray).size()
		TYPE_PACKED_INT32_ARRAY: return 24 + (v as PackedInt32Array).size() * 4
		TYPE_PACKED_INT64_ARRAY: return 24 + (v as PackedInt64Array).size() * 8
		TYPE_PACKED_FLOAT32_ARRAY: return 24 + (v as PackedFloat32Array).size() * 4
		TYPE_PACKED_FLOAT64_ARRAY: return 24 + (v as PackedFloat64Array).size() * 8
		TYPE_PACKED_VECTOR2_ARRAY: return 24 + (v as PackedVector2Array).size() * 8
		TYPE_PACKED_VECTOR3_ARRAY: return 24 + (v as PackedVector3Array).size() * 12
		TYPE_PACKED_VECTOR4_ARRAY: return 24 + (v as PackedVector4Array).size() * 16
		TYPE_PACKED_COLOR_ARRAY: return 24 + (v as PackedColorArray).size() * 16
		TYPE_PACKED_STRING_ARRAY:
			var total := 24
			for s: String in (v as PackedStringArray): total += 24 + s.length() * 4
			return total
		TYPE_ARRAY:
			var arr := v as Array
			var n := arr.size()
			var total := 32 + n * 24
			if depth >= MAX_DEPTH or n == 0: return total
			var take := mini(n, SAMPLE)
			var inner := 0
			for i: int in take: inner += _var_bytes(arr[i], depth + 1)
			return total + int(float(inner) * float(n) / float(take))
		TYPE_DICTIONARY:
			var d := v as Dictionary
			var n := d.size()
			var total := 64 + n * 72
			if depth >= MAX_DEPTH or n == 0: return total
			var keys := d.keys()
			var take := mini(n, SAMPLE)
			var inner := 0
			for i: int in take:
				inner += _var_bytes(keys[i], depth + 1) + _var_bytes(d[keys[i]], depth + 1)
			return total + int(float(inner) * float(n) / float(take))
		TYPE_OBJECT:
			var o := v as Object
			if o == null or not is_instance_valid(o): return 0
			if o is Image: return (o as Image).get_data_size()
			if o is Mesh or o is Texture or o is Material or o is Shader or o is Node: return 0
			if o is MultiMesh: return 0
			if depth >= MAX_DEPTH: return 0
			return _object_script_bytes(o, depth + 1)
	return 0

func _object_script_bytes(o: Object, depth: int) -> int:
	var id := o.get_instance_id()
	if _obj_seen.has(id): return 0
	_obj_seen[id] = true
	var total := 0
	var script: Script = o.get_script()
	if script == null: return 0
	for p: Dictionary in o.get_property_list():
		if int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var name: String = p.name
		var v: Variant = o.get(name)
		var b := _var_bytes(v, depth)
		if b >= 1048576:
			_big_fields.append({"owner": _owner_label(o), "field": name, "type": type_string(typeof(v)), "bytes": b})
		total += b
	return total

var _big_fields: Array = []

func _owner_label(o: Object) -> String:
	if o is Node: return String((o as Node).get_path())
	var s: Script = o.get_script()
	return (s.resource_path if s != null else o.get_class()) + "#" + str(o.get_instance_id())

## Script variables of a node and every descendant with a script (each object once).
func _script_data_of_node(n: Node) -> int:
	var total := 0
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c: Node in node.get_children(): stack.append(c)
		if node.get_script() != null: total += _object_script_bytes(node, 1)
	return total

## `static var` values of every script under res://scripts that is already loaded.
func _script_statics() -> Dictionary:
	var rows: Array = []
	var total := 0
	var files: Array[String] = []
	_collect_gd("res://scripts", files)
	var re := RegEx.new()
	re.compile("(?m)^static\\s+var\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for path: String in files:
		if not ResourceLoader.has_cached(path): continue
		var src := FileAccess.get_file_as_string(path)
		if src == "": continue
		var names: Array[String] = []
		for m: RegExMatch in re.search_all(src): names.append(m.get_string(1))
		if names.is_empty(): continue
		var script: Script = ResourceLoader.load(path)
		if script == null: continue
		var script_total := 0
		var fields: Dictionary = {}
		for name: String in names:
			var v: Variant = script.get(name)
			var b := _var_bytes(v, 1)
			if b >= 262144: fields[name] = {"type": type_string(typeof(v)), "bytes": b}
			script_total += b
		if script_total >= 262144: rows.append({"script": path, "bytes": script_total, "fields": fields})
		total += script_total
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.bytes) > int(b.bytes))
	return {"total_bytes": total, "scripts": rows}

func _collect_gd(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."): _collect_gd(full, out)
		elif name.ends_with(".gd"): out.append(full)
		name = d.get_next()
	d.list_dir_end()

func _print_report(rep: Dictionary) -> void:
	print("MEM_REPORT monitors ", JSON.stringify(rep.monitors))
	print("MEM_REPORT rendering ", JSON.stringify(rep.rendering_info))
	print("MEM_REPORT totals ", JSON.stringify(rep.totals))
	print("MEM_REPORT lights ", JSON.stringify(rep.lights))
	print("MEM_REPORT shapes ", JSON.stringify(rep.shapes))
	print("MEM_REPORT environment ", JSON.stringify(rep.get("environment", {})))
	print("MEM_REPORT viewports ", JSON.stringify(rep.viewports))
	var cls: Array = rep.classes.keys()
	cls.sort_custom(func(a: String, b: String) -> bool: return int(rep.classes[a]) > int(rep.classes[b]))
	var top_cls: Dictionary = {}
	for c: String in cls.slice(0, 30): top_cls[c] = rep.classes[c]
	print("MEM_REPORT classes_top30 ", JSON.stringify(top_cls))
	var keys: Array = rep.per_top.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ra: Dictionary = rep.per_top[a]
		var rb: Dictionary = rep.per_top[b]
		return (int(ra.mesh_bytes_first_owner) + int(ra.mm_buffer_bytes) + int(ra.tex_bytes_first_owner) + int(ra.script_data_bytes_est)) > (int(rb.mesh_bytes_first_owner) + int(rb.mm_buffer_bytes) + int(rb.tex_bytes_first_owner) + int(rb.script_data_bytes_est)))
	for k: String in keys:
		var r: Dictionary = rep.per_top[k]
		var sum := int(r.mesh_bytes_first_owner) + int(r.mm_buffer_bytes) + int(r.tex_bytes_first_owner) + int(r.script_data_bytes_est)
		if sum < 2097152 and int(r.nodes) < 50: continue
		print("MEM_REPORT top %-48s total=%7.1f MB mesh=%7.1f MB (shared refs %6.1f) mm_buf=%7.1f MB tex=%7.1f MB script=%7.1f MB nodes=%6d mi=%5d mmi=%4d mm_inst=%8d tris=%10d colliders=%5d concave_faces=%8d lights=%3d shadow=%3d" % [
			k, sum / 1048576.0, r.mesh_bytes_first_owner / 1048576.0, r.mesh_bytes_shared_refs / 1048576.0, r.mm_buffer_bytes / 1048576.0, r.tex_bytes_first_owner / 1048576.0, r.script_data_bytes_est / 1048576.0,
			r.nodes, r.mesh_instances, r.mmi, r.mm_instances, r.tris, r.collision_shapes, r.concave_faces, r.lights, r.lights_shadow])
	print("MEM_REPORT unique meshes=%d materials=%d textures=%d" % [rep.unique_meshes, rep.unique_materials, rep.unique_textures])
	for m: Dictionary in rep.top_meshes.slice(0, 25):
		print("MEM_REPORT mesh %7.1f MB verts=%9d idx=%9d surfaces=%3d refs=%5d %s %s owner=%s" % [m.bytes / 1048576.0, m.verts, m.indices, m.surfaces, m.refs, m.class, m.path if m.path != "" else m.name, m.owner])
	for t: Dictionary in rep.top_textures.slice(0, 25):
		print("MEM_REPORT texture %7.1f MB %dx%d fmt=%d compressed=%s mips=%d refs=%d %s %s owner=%s" % [t.bytes / 1048576.0, t.w, t.h, t.format, t.compressed, t.mipmaps, t.refs, t.class, t.path if t.path != "" else t.name, t.owner])
	print("MEM_REPORT textures_by_format ", JSON.stringify(rep.textures_by_format))
	_big_fields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.bytes) > int(b.bytes))
	for f: Dictionary in _big_fields.slice(0, 40):
		print("MEM_REPORT field %7.1f MB %-20s %s.%s" % [f.bytes / 1048576.0, f.type, f.owner, f.field])
	rep["big_fields"] = _big_fields.slice(0, 200)
	print("MEM_REPORT script_statics total=%.1f MB" % (rep.script_statics.total_bytes / 1048576.0))
	for s: Dictionary in rep.script_statics.scripts.slice(0, 20):
		print("MEM_REPORT static %7.1f MB %s %s" % [s.bytes / 1048576.0, s.script, JSON.stringify(s.fields)])
	print("MEM_REPORT report_ms=%d" % rep.report_ms)
	print("MEM_REPORT monitors_after ", JSON.stringify(rep.monitors_after))
