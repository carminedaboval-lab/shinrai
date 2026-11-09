extends SceneTree

# Rendering-side duplication audit for one park boot (investigation probe; changes nothing).
# Boots the real main scene with a throwaway QA profile (never the player's save), waits for
# world_ready, then prints:
#   RDUP geo     identical geometry held as several distinct Mesh resources (same surface
#                vertex/index counts and AABB) -> bytes that sharing one copy would save
#   RDUP mat     distinct Material objects / distinct shaders
#   RDUP tex     uncompressed (RGB8/RGBA8) textures reachable from materials, with paths
#   RDUP shadow  shadow-casting geometry instances per top-level park module
#   RDUP lights  lights by type/shadow/visible and distance-fade state
#   godot --path . --script res://tests/probe_mem_render_dupes.gd -- [--top=40]

const LoadState = preload("res://scripts/shinrai_load_state.gd")
const QA_PROFILE := "user://shinrai_menu_probe_mem_dupes.json"
const LIMIT_MSEC := 900000

var started := 0
var top_n := 40

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--top="): top_n = int(a.substr(6))
	_run.call_deferred()

func _find_raid() -> Node:
	for child: Node in root.get_children():
		var r := child.get_node_or_null("ExtractionRun")
		if r != null: return r
	return null

func _find_park() -> Node:
	for child: Node in root.get_children():
		if child is Node3D and child.has_method("_apply_time_of_day"): return child
	return null

func _run() -> void:
	var boot: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	if not "profile_path" in boot:
		print("RDUP NO_PROFILE_PATH")
		quit(1)
		return
	boot.profile_path = QA_PROFILE
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_PROFILE + suffix))
	root.add_child(boot)
	current_scene = boot
	var raid: Node = null
	while Time.get_ticks_msec() - started < LIMIT_MSEC:
		if raid == null: raid = _find_raid()
		if raid != null and raid.world_ready(): break
		await process_frame
	if raid == null or not raid.world_ready():
		print("RDUP TIMEOUT")
		quit(1)
		return
	for i: int in 10: await process_frame
	_report()
	quit(0)

var meshes := {}     # mesh id -> [signature, bytes, label]
var mats := {}
var shaders := {}
var textures := {}   # texture id -> true
var shadow_by_module := {}
var light_rows := {}

func _mesh_bytes(mesh: ArrayMesh) -> int:
	var b := 0
	for s: int in mesh.get_surface_count():
		var v := mesh.surface_get_array_len(s)
		var fmt := mesh.surface_get_format(s)
		var per := 12 + 8 # position + packed normal/tangent
		if fmt & Mesh.ARRAY_FORMAT_COLOR: per += 4
		if fmt & Mesh.ARRAY_FORMAT_TEX_UV: per += 8
		if fmt & Mesh.ARRAY_FORMAT_TEX_UV2: per += 8
		b += per * v + mesh.surface_get_array_index_len(s) * (2 if v <= 65535 else 4)
	return b

func _note_mesh(mesh: Mesh) -> void:
	if mesh == null or not (mesh is ArrayMesh): return
	var id := mesh.get_instance_id()
	if meshes.has(id): return
	var am := mesh as ArrayMesh
	var sig := "%d|%s" % [am.get_surface_count(), am.get_aabb()]
	for s: int in am.get_surface_count():
		sig += "|%d/%d" % [am.surface_get_array_len(s), am.surface_get_array_index_len(s)]
	meshes[id] = [sig, _mesh_bytes(am), mesh.resource_path if mesh.resource_path != "" else mesh.resource_name]
	for s: int in am.get_surface_count(): _note_mat(am.surface_get_material(s))

func _note_mat(m: Material) -> void:
	if m == null or mats.has(m.get_instance_id()): return
	mats[m.get_instance_id()] = true
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		shaders[(m as ShaderMaterial).shader.get_instance_id()] = true
		for p: Dictionary in RenderingServer.get_shader_parameter_list((m as ShaderMaterial).shader.get_rid()):
			var t: Variant = (m as ShaderMaterial).get_shader_parameter(p.name)
			if t is Texture: textures[(t as Texture).get_instance_id()] = true
	elif m is BaseMaterial3D:
		for p: Dictionary in m.get_property_list():
			if String(p.name).ends_with("_texture"):
				var t: Variant = m.get(p.name)
				if t is Texture: textures[(t as Texture).get_instance_id()] = true
	if m.next_pass != null: _note_mat(m.next_pass)

func _walk(n: Node, module: String) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		_note_mat(g.material_override)
		_note_mat(g.material_overlay)
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and g.is_visible_in_tree():
			var row: Array = shadow_by_module.get(module, [0, 0, 0])
			row[0] += 1
			if g.visibility_range_end <= 0.0: row[1] += 1 # casts at any distance
			if g is MultiMeshInstance3D: row[2] += 1
			shadow_by_module[module] = row
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			_note_mesh(mi.mesh)
			if mi.mesh != null:
				for s: int in mi.mesh.get_surface_count(): _note_mat(mi.get_surface_override_material(s))
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			_note_mesh((g as MultiMeshInstance3D).multimesh.mesh)
	elif n is Light3D:
		var l := n as Light3D
		var k := "%s shadow=%s visible=%s fade=%s" % [l.get_class(), l.shadow_enabled, l.is_visible_in_tree(), l.distance_fade_enabled]
		light_rows[k] = int(light_rows.get(k, 0)) + 1
	for c: Node in n.get_children(true): _walk(c, module)

func _report() -> void:
	var park := _find_park()
	for c: Node in root.get_children():
		if c == park:
			for pc: Node in park.get_children(true): _walk(pc, str(pc.name))
		else:
			_walk(c, "<root>/" + str(c.name))
	# Identical geometry held more than once.
	var by_sig := {}
	for id: int in meshes:
		var m: Array = meshes[id]
		if not by_sig.has(m[0]): by_sig[m[0]] = []
		by_sig[m[0]].append(id)
	var dup_rows: Array = []
	var dup_bytes := 0
	for sig: String in by_sig:
		var ids: Array = by_sig[sig]
		if ids.size() < 2: continue
		var b: int = meshes[ids[0]][1]
		dup_bytes += b * (ids.size() - 1)
		dup_rows.append([b * (ids.size() - 1), ids.size(), b, meshes[ids[0]][2]])
	dup_rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("RDUP geo unique_mesh_objects=%d distinct_geometry=%d duplicate_copies_mb=%.1f" % [meshes.size(), by_sig.size(), dup_bytes / 1048576.0])
	for r: Array in dup_rows.slice(0, top_n):
		print("RDUP geo dup %7.1f MB  copies=%4d each=%6.2f MB  %s" % [r[0] / 1048576.0, r[1], r[2] / 1048576.0, r[3]])
	print("RDUP mat materials=%d shaders=%d textures=%d" % [mats.size(), shaders.size(), textures.size()])
	var raw: Array = []
	var raw_bytes := 0
	for id: int in textures:
		var t: Texture = instance_from_id(id)
		if t == null or not (t is Texture2D): continue
		var fmt := -1
		if t.has_method("get_format"): fmt = int(t.call("get_format"))
		if fmt != Image.FORMAT_RGB8 and fmt != Image.FORMAT_RGBA8: continue
		var b := int((t as Texture2D).get_width() * (t as Texture2D).get_height() * 4 * 1.33)
		raw_bytes += b
		raw.append([b, (t as Texture2D).get_width(), (t as Texture2D).get_height(), fmt, t.get_class(), t.resource_path])
	raw.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("RDUP tex uncompressed_count=%d uncompressed_mb=%.1f (as BC1/BC7 about %.1f MB)" % [raw.size(), raw_bytes / 1048576.0, raw_bytes / 4.0 / 1048576.0])
	for r: Array in raw.slice(0, top_n * 3):
		print("RDUP tex %6.1f MB %dx%d fmt=%d %s %s" % [r[0] / 1048576.0, r[1], r[2], r[3], r[4], r[5]])
	var mods: Array = shadow_by_module.keys()
	mods.sort_custom(func(a: String, b: String) -> bool: return shadow_by_module[a][0] > shadow_by_module[b][0])
	for m: String in mods.slice(0, top_n):
		var row: Array = shadow_by_module[m]
		print("RDUP shadow %-42s casters=%6d no_range_limit=%6d multimesh=%6d" % [m, row[0], row[1], row[2]])
	for k: String in light_rows: print("RDUP lights %s : %d" % [k, light_rows[k]])
	print("RDUP done")
