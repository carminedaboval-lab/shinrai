extends SceneTree

# WORLD-build QA probe: boots the real main scene with a throwaway QA profile,
# logs every long frame once the park is in the tree (with the StartupTrace
# stages that ended inside it), waits until the world is complete (HQ plus the
# post-boot passes), then writes a fingerprint of the built park so two builds
# can be compared for "same result" (node / instance / triangle counts and
# order-independent content hashes per top-level park node).
#   godot --path . --script res://tests/probe_world_fingerprint.gd -- --profile-startup --fp-out=C:/x/fp.json [--long-ms=250] [--interactive]
# --interactive calls LoadingBudget.set_interactive(true) once the park is in
# the tree (the menu-visible budget), when that function exists.

const Trace := preload("res://scripts/startup_trace.gd")
var started := 0
var last_frame := 0
var park_seen_at := 0
var long_ms := 250.0
var long_frames: Array[Dictionary] = []
var worst := 0.0
var frames_after_park := 0
var over_250 := 0
var over_500 := 0
var trace_seen := 0
var watching := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--long-ms="): long_ms = float(arg.get_slice("=", 1))
	root.child_entered_tree.connect(_on_root_child)
	_run.call_deferred()

## The park's first frames (near city, structure) count from the moment it enters the tree.
func _on_root_child(node: Node) -> void:
	if watching or not node is Node3D or not node.has_meta("shinrai_structure_pending"): return
	watching = true
	park_seen_at = Time.get_ticks_msec()
	_stamp("park_entered_tree")
	if "--interactive" in OS.get_cmdline_user_args():
		var budget: Script = load("res://scripts/shinrai_loading_budget.gd")
		if budget.has_method("set_interactive"): budget.set_interactive(true)

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if watching and last_frame > 0:
		var ms := (now - last_frame) / 1000.0
		frames_after_park += 1
		if ms > 250.0: over_250 += 1
		if ms > 500.0: over_500 += 1
		worst = maxf(worst, ms)
		var ended: Array[String] = []
		for i: int in range(trace_seen, Trace.events.size()):
			ended.append("%s(%.0f)" % [Trace.events[i].stage, Trace.events[i].duration_ms])
		trace_seen = Trace.events.size()
		if ms > long_ms:
			var ui := root.get_tree().get_first_node_in_group("shinrai_loading_ui")
			var stage := ""
			if ui != null and ui.get("stage_label") != null: stage = str(ui.stage_label.text)
			var row := {"ms": snappedf(ms, 1.0), "at_s": snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1), "ui_stage": stage, "trace_ended": ended}
			long_frames.append(row)
			print("LONG_FRAME ", JSON.stringify(row))
	else:
		trace_seen = Trace.events.size()
	last_frame = now
	return false

func _stamp(label: String) -> void:
	print("FP_PROBE %s at %.1f s  frames_after_park=%d worst=%.0f ms >250=%d >500=%d" % [label, (Time.get_ticks_msec() - started) / 1000.0, frames_after_park, worst, over_250, over_500])

func _run() -> void:
	var main: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var boot: Node = main.instantiate() if main != null else null
	# A half-edited main scene must not hold the shared Godot lock for 15 minutes.
	if boot == null or boot.get_script() == null or not (boot.get_script() as Script).can_instantiate():
		print("FP_PROBE ABORT main scene or its script failed to load")
		quit(2)
		return
	if "profile_path" in boot:
		boot.profile_path = "user://shinrai_world_fp_probe.json"
		for suffix: String in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(boot.profile_path + suffix)
	root.add_child(boot)
	current_scene = boot
	var park: Node3D = null
	var raid: Node = null
	while Time.get_ticks_msec() - started < 420000:
		# No park after 90 s means the boot flow failed (a script error elsewhere).
		if park == null and Time.get_ticks_msec() - started > 90000:
			_stamp("ABORT no park after 90 s")
			quit(3)
			return
		if park == null:
			for child: Node in root.get_children():
				if child is Node3D and child.has_meta("shinrai_structure_pending"): park = child
			if park != null and not watching: _on_root_child(park)
		if park != null and raid == null:
			raid = park.get_node_or_null("ExtractionRun")
		if raid != null and raid.phase == raid.Phase.HQ: break
		await process_frame
	if raid == null or raid.phase != raid.Phase.HQ:
		_stamp("TIMEOUT_HQ")
		quit(1)
		return
	_stamp("hq")
	# Old code finishes the post-boot passes after HQ; new code before it.
	var wait_from := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wait_from < 600000:
		if _post_boot_done(park): break
		await process_frame
	_stamp("world_complete" if _post_boot_done(park) else "TIMEOUT_POST_BOOT")
	print("FP_POST_BOOT ", JSON.stringify(_post_boot_state(park)))
	watching = false
	for i: int in range(10): await process_frame
	var fp_from := Time.get_ticks_msec()
	var fp := fingerprint(park, raid)
	fp["long_frames"] = long_frames
	fp["timing"] = {"hq_s": 0.0, "worst_frame_ms": worst, "frames_after_park": frames_after_park, "over_250": over_250, "over_500": over_500, "fingerprint_ms": Time.get_ticks_msec() - fp_from, "unique_meshes": _vtx_cache.size(), "unique_materials": _mat_cache.size(), "unique_textures": _tex_cache.size()}
	print("FP_PROBE fingerprint took %d ms (meshes %d, materials %d, textures %d)" % [fp.timing.fingerprint_ms, _vtx_cache.size(), _mat_cache.size(), _tex_cache.size()])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fp-out="):
			var file := FileAccess.open(arg.get_slice("=", 1), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(fp, "\t", true))
				file.close()
	print("FP_TOTALS ", JSON.stringify(fp.totals))
	quit()

func _post_boot_state(park: Node3D) -> Dictionary:
	var roads := park.get_node_or_null("MidoriTokyoRoads")
	return {
		"biomes": park.has_meta("midori_biomes"),
		"worn_paths": park.has_meta("worn_paths"),
		"clipped_after_boot": park.has_meta("clipped_shrubs_after_boot"),
		"roads_resurfaced": roads == null or (roads.get("report") is Dictionary and roads.report.has("resurfaced_roads")),
		"world_complete": park.get_meta("shinrai_world_complete", {}),
	}

func _post_boot_done(park: Node3D) -> bool:
	var s := _post_boot_state(park)
	return s.biomes and s.worn_paths and s.clipped_after_boot and s.roads_resurfaced

var _tri_cache: Dictionary = {}
func _tris(mesh: Mesh) -> int:
	if mesh == null: return 0
	var id := mesh.get_instance_id()
	if _tri_cache.has(id): return _tri_cache[id]
	var count := 0
	if mesh is ArrayMesh:
		for s: int in range(mesh.get_surface_count()):
			var idx: int = mesh.surface_get_array_index_len(s)
			count += (idx if idx > 0 else mesh.surface_get_array_len(s)) / 3
	else:
		count = mesh.get_faces().size() / 3
	_tri_cache[id] = count
	return count

static func _mix(total: int, value: int) -> int:
	return (total + (value & 0x7fffffff)) % 2147483629

func fingerprint(park: Node3D, raid: Node) -> Dictionary:
	var groups: Dictionary = {}
	var totals := {"nodes": 0, "meshes": 0, "visible_meshes": 0, "mmi": 0, "mm_instances": 0, "tris": 0, "colliders": 0, "lights": 0, "hash": 0}
	for top: Node in park.get_children():
		var key := String(top.name)
		if key.begins_with("@"): key = top.get_class() + "@"
		var row: Dictionary = groups.get(key, {"nodes": 0, "meshes": 0, "visible_meshes": 0, "mmi": 0, "mm_instances": 0, "tris": 0, "colliders": 0, "lights": 0, "hash": 0, "mm_hash": 0})
		var stack: Array[Node] = [top]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child: Node in node.get_children(): stack.append(child)
			row.nodes += 1
			if node is MeshInstance3D:
				var mi := node as MeshInstance3D
				row.meshes += 1
				var vis := mi.is_visible_in_tree()
				if vis: row.visible_meshes += 1
				var t := _tris(mi.mesh)
				row.tris += t
				var o := mi.global_position.snapped(Vector3.ONE * 0.001)
				var mat := ""
				if mi.material_override != null:
					mat = mi.material_override.get_class()
					if mi.material_override is ShaderMaterial and mi.material_override.shader != null:
						mat += mi.material_override.shader.resource_path
				row.hash = _mix(row.hash, hash([t, o, vis, mi.layers, mat]))
				# Geometry only (no visibility, layers or material): what builders generated.
				row.geo_hash = _mix(row.get("geo_hash", 0), hash([t, o]))
				# Render policy (draw distance, render layers): kept out of `hash` so
				# older fingerprints still compare; compare render_hash run to run.
				row.render_hash = _mix(row.get("render_hash", 0), hash([o, mi.layers, snappedf(mi.visibility_range_end, 0.01), mi.cast_shadow]))
				# Pass-2 fields: material identity per surface, and the mesh's vertex data.
				row.mat_hash = _mix(row.get("mat_hash", 0), hash([o, _geo_mats(mi, mi.mesh)]))
				row.vtx_hash = _mix(row.get("vtx_hash", 0), hash([o, _vtx(mi.mesh)]))
			elif node is MultiMeshInstance3D:
				var mmi := node as MultiMeshInstance3D
				row.mmi += 1
				row.render_hash = _mix(row.get("render_hash", 0), hash([mmi.global_position.snapped(Vector3.ONE * 0.001), mmi.layers, snappedf(mmi.visibility_range_end, 0.01), mmi.cast_shadow]))
				var mm := mmi.multimesh
				if mm != null:
					var n := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
					row.mm_instances += n
					row.tris += n * _tris(mm.mesh)
					row.mm_hash = _mix(row.mm_hash, hash([n, mm.buffer.size(), hash(mm.buffer), mmi.global_position.snapped(Vector3.ONE * 0.001), mmi.is_visible_in_tree()]))
					row.mm_geo_hash = _mix(row.get("mm_geo_hash", 0), hash([n, hash(mm.buffer), mmi.global_position.snapped(Vector3.ONE * 0.001)]))
				var mo := mmi.global_position.snapped(Vector3.ONE * 0.001)
				var mmesh: Mesh = mm.mesh if mm != null else null
				row.mat_hash = _mix(row.get("mat_hash", 0), hash([mo, _geo_mats(mmi, mmesh)]))
				row.vtx_hash = _mix(row.get("vtx_hash", 0), hash([mo, _vtx(mmesh)]))
			elif node is CollisionShape3D:
				row.colliders += 1
				var cs := node as CollisionShape3D
				row.hash = _mix(row.hash, hash([cs.global_position.snapped(Vector3.ONE * 0.001), cs.shape.get_class() if cs.shape != null else "", cs.disabled]))
			elif node is Light3D:
				row.lights += 1
				row.light_hash = _mix(row.get("light_hash", 0), _light(node as Light3D))
		groups[key] = row
	for key: String in groups:
		for field: String in ["nodes", "meshes", "visible_meshes", "mmi", "mm_instances", "tris", "colliders", "lights"]:
			totals[field] += groups[key][field]
		totals.hash = _mix(totals.hash, hash([key, groups[key].hash, groups[key].mm_hash]))
	var terrain_shader := ""
	var terrain := park.get_node_or_null("MidoriTerrain")
	if terrain != null:
		for child: Node in terrain.get_children():
			if child is MeshInstance3D and child.material_override is ShaderMaterial:
				var code: String = child.material_override.shader.code
				terrain_shader = str(code.length()) + ":" + str(code.hash())
				# Sorted lines: equal when only the order of injected blocks differs.
				var lines := code.split("\n")
				lines.sort()
				terrain_shader += " sorted:" + str("\n".join(lines).hash())
				for arg: String in OS.get_cmdline_user_args():
					if arg.begins_with("--shader-out="):
						var out := FileAccess.open(arg.get_slice("=", 1), FileAccess.WRITE)
						if out != null: out.store_string(code); out.close()
				break
	var nav := {}
	var navigation: Variant = raid.get("navigation")
	if navigation != null:
		var graph: AStar2D = navigation.walk_graph
		var links := 0
		var point_hash := 0
		for id: int in graph.get_point_ids():
			var conns := graph.get_point_connections(id)
			links += conns.size()
			point_hash = _mix(point_hash, hash([id, graph.get_point_position(id), conns.size()]))
		var solid := 0
		for y: int in range(91):
			for x: int in range(111):
				if navigation.grid.is_point_solid(Vector2i(x, y)): solid += 1
		nav = {"points": graph.get_point_count(), "links": links / 2, "solid_cells": solid, "hash": point_hash}
	return {"totals": totals, "groups": groups, "terrain_shader": terrain_shader, "navigation": nav, "sites": (raid.get("sites") as Array).size() if raid.get("sites") is Array else -1, "post_boot": _post_boot_state(park), "ground_texture": _ground_texture()}

# ---- Pass-2 extensions (new fields only; the fields above keep their meaning) ----
# mat_hash   per group: every mesh / multimesh node's position + the identity of each
#            material it draws with (material_override, overlay, every surface).
# vtx_hash   per group: every mesh / multimesh node's position + its mesh's vertex data
#            (positions and normals rounded to 1e-3, sampled deterministically).
# light_hash per group: every Light3D's type, transform, energy, range, angle, colour, shadow.
# ground_texture: the MidoriGroundTexture landscape_tex image bytes once the park is ready.
const VTX_SAMPLES := 256
var _mat_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _vtx_cache: Dictionary = {}

## Quantised float (1e-4 for material and light scalars, 1e-3 for transforms and vertices).
static func _q(v: float, scale: float = 10000.0) -> int:
	return roundi(v * scale)

func _norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT: return _q(v)
		TYPE_VECTOR2: return [_q(v.x), _q(v.y)]
		TYPE_VECTOR3: return [_q(v.x), _q(v.y), _q(v.z)]
		TYPE_VECTOR4, TYPE_QUATERNION: return [_q(v.x), _q(v.y), _q(v.z), _q(v.w)]
		TYPE_COLOR: return [_q(v.r), _q(v.g), _q(v.b), _q(v.a)]
		TYPE_BASIS: return [_norm(v.x), _norm(v.y), _norm(v.z)]
		TYPE_TRANSFORM3D: return [_norm(v.basis), _norm(v.origin)]
		TYPE_TRANSFORM2D: return [_norm(v.x), _norm(v.y), _norm(v.origin)]
		TYPE_OBJECT:
			if v == null: return 0
			if v is Texture: return _tex_id(v)
			if v is Material: return _mat_id(v)
			if v is Resource: return [v.get_class(), (v as Resource).resource_path]
			return v.get_class()
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in v: out.append(_norm(item))
			return out
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			if v.size() > 1024: return [v.size(), hash(v)]
			var out: Array = []
			for item: Variant in v: out.append(_norm(item))
			return out
	return v

const BASE_MATERIAL_KEYS: Array[String] = ["albedo_color", "albedo_texture", "metallic", "metallic_specular", "metallic_texture", "roughness", "roughness_texture", "normal_enabled", "normal_texture", "normal_scale", "emission_enabled", "emission", "emission_energy_multiplier", "emission_texture", "transparency", "alpha_scissor_threshold", "blend_mode", "cull_mode", "depth_draw_mode", "no_depth_test", "shading_mode", "diffuse_mode", "specular_mode", "disable_receive_shadows", "disable_ambient_light", "shadow_to_opacity", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "uv1_scale", "uv1_offset", "uv1_triplanar", "uv2_scale", "texture_filter", "texture_repeat", "billboard_mode", "rim_enabled", "clearcoat_enabled", "ao_enabled", "ao_texture", "heightmap_enabled", "subsurf_scatter_enabled", "backlight_enabled", "backlight", "refraction_enabled", "detail_enabled", "grow", "grow_amount", "render_priority", "proximity_fade_enabled", "distance_fade_mode", "use_point_size", "fixed_size"]

## Material identity: class, resource path, shader (path + code) and every sorted
## shader parameter, or the key StandardMaterial3D properties; next_pass included.
func _mat_id(m: Material) -> int:
	if m == null: return 0
	var id := m.get_instance_id()
	if _mat_cache.has(id): return _mat_cache[id]
	_mat_cache[id] = 1 # cycle guard
	var parts: Array = [m.get_class(), m.resource_path, m.render_priority]
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		parts.append(sh.resource_path if sh != null else "")
		if sh != null:
			parts.append(sh.code.hash())
			var names: Array[String] = []
			for u: Dictionary in sh.get_shader_uniform_list(): names.append(String(u.name))
			names.sort()
			for n: String in names: parts.append([n, _norm((m as ShaderMaterial).get_shader_parameter(n))])
	elif m is BaseMaterial3D:
		for k: String in BASE_MATERIAL_KEYS: parts.append([k, _norm(m.get(k))])
	parts.append(_mat_id(m.next_pass))
	var h := hash(parts)
	_mat_cache[id] = h
	return h

## Texture identity: class + path; generated (unsaved) 2D textures also hash their image bytes.
func _tex_id(t: Texture) -> int:
	var id := t.get_instance_id()
	if _tex_cache.has(id): return _tex_cache[id]
	var parts: Array = [t.get_class(), t.resource_path]
	if t is Texture2D:
		parts.append([(t as Texture2D).get_width(), (t as Texture2D).get_height()])
		if t.resource_path == "" and not t is ViewportTexture:
			var img: Image = (t as Texture2D).get_image()
			if img != null: parts.append([img.get_format(), img.has_mipmaps(), hash(img.get_data())])
	var h := hash(parts)
	_tex_cache[id] = h
	return h

## Materials a geometry node draws with: override, overlay and each surface's active one.
func _geo_mats(g: GeometryInstance3D, mesh: Mesh) -> Array:
	var out: Array = [_mat_id(g.material_override), _mat_id(g.material_overlay)]
	if mesh != null:
		for s: int in range(mesh.get_surface_count()):
			var m: Material = null
			if g is MeshInstance3D: m = (g as MeshInstance3D).get_surface_override_material(s)
			if m == null: m = mesh.surface_get_material(s)
			out.append(_mat_id(m))
	return out

## Vertex data of one mesh (cached per mesh): per surface the vertex / index counts, an exact
## index hash and up to VTX_SAMPLES evenly strided positions + normals rounded to 1e-3, plus
## the mesh AABB (built from every vertex) rounded to 1e-3.
func _vtx(mesh: Mesh) -> int:
	if mesh == null: return 0
	var id := mesh.get_instance_id()
	if _vtx_cache.has(id): return _vtx_cache[id]
	var box := mesh.get_aabb()
	var parts: Array = [mesh.get_class(), mesh.get_surface_count(), [_q(box.position.x, 1000.0), _q(box.position.y, 1000.0), _q(box.position.z, 1000.0), _q(box.size.x, 1000.0), _q(box.size.y, 1000.0), _q(box.size.z, 1000.0)]]
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = []
		if mesh is ArrayMesh:
			parts.append((mesh as ArrayMesh).surface_get_primitive_type(s))
			arrays = (mesh as ArrayMesh).surface_get_arrays(s)
		elif mesh is PrimitiveMesh and s == 0:
			arrays = (mesh as PrimitiveMesh).get_mesh_arrays()
		if arrays.size() <= Mesh.ARRAY_INDEX or arrays[Mesh.ARRAY_VERTEX] == null:
			parts.append(-1)
			continue
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var n := pos.size()
		var with_normals := nrm.size() == n
		var q := PackedInt32Array()
		var step := maxi(1, (n + VTX_SAMPLES - 1) / VTX_SAMPLES)
		for i: int in range(0, n, step):
			var p := pos[i]
			q.append(roundi(p.x * 1000.0)); q.append(roundi(p.y * 1000.0)); q.append(roundi(p.z * 1000.0))
			if with_normals:
				var nn := nrm[i]
				q.append(roundi(nn.x * 1000.0)); q.append(roundi(nn.y * 1000.0)); q.append(roundi(nn.z * 1000.0))
		parts.append([n, with_normals, idx.size(), hash(idx), hash(q)])
	var h := hash(parts)
	_vtx_cache[id] = h
	return h

func _light(l: Light3D) -> int:
	var t := l.global_transform
	var parts: Array = [l.get_class(), [_q(t.origin.x, 1000.0), _q(t.origin.y, 1000.0), _q(t.origin.z, 1000.0)], _norm(t.basis), _q(l.light_energy), _q(l.light_indirect_energy), _norm(l.light_color), l.shadow_enabled, l.light_negative, l.light_cull_mask, l.light_bake_mode, l.is_visible_in_tree()]
	if l is OmniLight3D: parts.append([_q((l as OmniLight3D).omni_range), _q((l as OmniLight3D).omni_attenuation)])
	elif l is SpotLight3D: parts.append([_q((l as SpotLight3D).spot_range), _q((l as SpotLight3D).spot_angle), _q((l as SpotLight3D).spot_attenuation)])
	return hash(parts)

## The ground landscape mask (scripts/midori_ground_texture.gd, landscape_tex): its image
## bytes, size, per-channel sums and the counts the mask producer reported (tree_count is
## the timing-sensitive read: which trees existed when the mask was built).
func _ground_texture() -> Dictionary:
	var gt := root.get_node_or_null("MidoriGroundTexture")
	if gt == null: return {"present": false}
	var out := {"present": true, "landscape_ready": gt.get("landscape_ready") == true}
	var report: Variant = gt.get("landscape_report")
	if report is Dictionary:
		for k: String in ["version", "tree_count", "lawn_samples", "woodland_samples", "worn_or_protected_samples", "held_shoulder_samples", "blended_shoulder_samples"]:
			out[k] = report.get(k, -1)
	var mat: Variant = gt.get("_active_ground_material")
	if mat is ShaderMaterial:
		out["material"] = _mat_id(mat)
		var tex: Variant = (mat as ShaderMaterial).get_shader_parameter("landscape_tex")
		if tex is Texture2D:
			var img: Image = (tex as Texture2D).get_image()
			if img != null:
				var data := img.get_data()
				var sums := [0, 0, 0, 0]
				for i: int in range(data.size()): sums[i & 3] += data[i]
				out["size"] = [img.get_width(), img.get_height(), img.get_format()]
				out["image_hash"] = hash(data)
				out["channel_sums"] = sums
		else:
			out["image_hash"] = "no landscape_tex"
	return out
