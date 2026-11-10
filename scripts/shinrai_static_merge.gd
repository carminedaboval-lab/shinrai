extends RefCounted
## End-of-boot static mesh merge (one sub-step of shinrai_consolidate.gd).
##
## Direct3D 12 rounds every GPU buffer up to 64 KB, so a unique one-surface
## mesh costs at least 192 KB. The corporate district is built from about
## 6,000 single-use BoxMesh nodes. This step bakes groups of them into one
## ArrayMesh per (material, render settings, map cell) with the SAME triangles,
## the SAME Material object and the same shadow / layer / draw-distance
## settings, then retires the sources.
##
## Must run AFTER the render budget (draw distance already assigned, see
## scripts/midori_draw_distance.gd:29) and before phase = HQ, raid path only.
## Generic merger + per-module rule table; enabled for the corporate district.
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

const META := &"shinrai_static_merge"
const CONTAINER_NAME := "ShinraiStaticMerge"
const MERGED_NAME := "Merged_%04d"
## A merged mesh replaces at least this many sources (one source gains nothing).
const MIN_GROUP := 2
## Map cell (m) per draw-distance class of the sources: [largest range end, cell].
## Sources with no range end use UNRANGED_CELL.
const RANGE_CELLS := [[70.0, 12.0], [INF, 24.0]]
const UNRANGED_CELL := 48.0

## Per-module rules. Paths are relative to the module root (a child of the park).
##  mode "children":    only the root's direct MeshInstance3D children, plus every
##                      mesh below direct children whose name contains a `within` word.
##  mode "descendants": every MeshInstance3D below the root, never entering a
##                      subtree named in `skip_subtrees` / member of `skip_groups`,
##                      an AnimatableBody3D, or an instanced .glb / .gltf scene.
##  array_meshes:       also take script-built single-use ArrayMesh (ramps).
const MODULES := [
	{
		"module": "MidoriCorporateDistrict",
		"requires_installed": true,
		"primitives": ["BoxMesh", "CylinderMesh", "TorusMesh"],
		# Never merged, whatever else holds (name contains). Road slabs carry
		# per-instance shader parameters (midori_tokyo_roads.gd:161-163); glass is
		# transparent; the rest are shared-mesh batches or already merged.
		"exclude_names": [
			"MergedWindows", "DistrictSupportedGround",
			"NorthSouthRoad", "DistrictAvenue", "GarageAccessDrive", "PolicePatrolDrive",
			"JunctionRoadSkin", "MainRoadContinuation", "ConnectorTurn", "RoadWidening", "DistrictRoadTransition",
			"FrontWestGlazing", "FrontEastGlazing",
			"WalkStones", "LawnShell", "Bamboo", "StreetEdge_", "CorporateTree",
		],
		# Invisible for good, kept only for the StaticBody3D child: mesh released.
		"hidden_colliders": ["TreeTrunk", "StreamBlock", "PoolBlock", "RecyclingBlock"],
		"roots": [
			{"path": "CorporateParcel/CorporateDistrict", "mode": "children", "within": ["ParkedEV"], "array_meshes": false},
			{"path": "CorporateParcel/CorporateDistrict/CorporateGarage", "mode": "descendants", "array_meshes": true},
			{"path": "CorporateParcel/CorporateDistrict/PoliceStation", "mode": "descendants", "array_meshes": true},
			{"path": "CorporateParcel/CorporateDistrict/CorporateGardenFeatures", "mode": "descendants", "array_meshes": false},
			{"path": "CorporateRoadConnection", "mode": "descendants", "array_meshes": false},
			# Tower circulation: floors, rails, posts and the Staircases child. The lift
			# moves every physics frame and the ladder is a MultiMesh: both left alone.
			{"path": "CorporateParcel/CantileverCommand/Traversal", "mode": "descendants", "array_meshes": true,
				"skip_subtrees": ["Elevator", "EmergencyLadder"], "skip_groups": ["cantilever_elevator", "cantilever_ladder"]},
		],
	},
]

## Arrays this merger can carry. A source with any other array is left alone.
const CARRIED_FORMAT := Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_INDEX
const KEY_FORMAT := Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2
const PRIMITIVE_FORMAT := Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_INDEX

## Shader text that makes a baked (moved-origin) mesh render differently, or
## that puts the material in the alpha pass. Any hit leaves the node alone.
const SHADER_ORIGIN_WORDS := ["instance uniform", "NODE_POSITION_WORLD", "NODE_POSITION_VIEW", "MODEL_MATRIX[3]", "INSTANCE_CUSTOM", "INSTANCE_ID"]
const SHADER_ALPHA_WORDS := ["blend_add", "blend_sub", "blend_mul", "blend_premul_alpha", "hint_screen_texture", "hint_depth_texture", "SCREEN_TEXTURE", "DEPTH_TEXTURE", "depth_test_disabled", "depth_draw_never"]

## Coroutine. Returns the report (also stored in park meta "shinrai_static_merge").
static func run(park: Node3D) -> Dictionary:
	if not is_instance_valid(park) or not park.is_inside_tree(): return {"skipped": "no park"}
	if park.has_meta(META): return park.get_meta(META)
	# Creator Mode never reaches this step; the district does not build there.
	if park.get("creator_ready") != null: return {"skipped": "creator"}
	var started := Time.get_ticks_msec()
	var report := {
		"modules": {}, "sources_merged": 0, "merged_meshes": 0,
		"nodes_freed": 0, "nodes_kept_without_mesh": 0,
		"hidden_collision_meshes_released": 0, "hidden_tris_released": 0,
		"meshes_before": 0, "meshes_after": 0,
		"tris_before": 0, "tris_after": 0, "tris_equal": true,
		"groups_failed": 0, "errors": [],
	}
	var state := {"unit_box": {}, "unit_box_tried": false, "templates": {}, "materials": {}, "shaders": {}, "ref_baseline": _ref_baseline()}
	for rules: Dictionary in MODULES:
		var module := park.get_node_or_null(NodePath(str(rules.module))) as Node3D
		if module == null:
			report.modules[rules.module] = {"skipped": "module not found"}
			continue
		if rules.get("requires_installed", false) and module.get("installed") != true:
			report.modules[rules.module] = {"skipped": "module not installed"}
			continue
		var row: Dictionary = await _run_module(park, module, rules, state)
		if not is_instance_valid(park) or not park.is_inside_tree(): return {"skipped": "park left the tree"}
		report.modules[rules.module] = row
		for field: String in ["sources_merged", "merged_meshes", "nodes_freed", "nodes_kept_without_mesh", "hidden_collision_meshes_released", "hidden_tris_released", "meshes_before", "meshes_after", "tris_before", "tris_after", "groups_failed"]:
			report[field] += int(row.get(field, 0))
		if not row.get("tris_equal", true): report.tris_equal = false
		for message: String in row.get("errors", []): report.errors.append(str(rules.module) + ": " + message)
	state.clear()
	report["ms"] = Time.get_ticks_msec() - started
	if not report.tris_equal: push_warning("SHINRAI_STATIC_MERGE: triangle totals differ " + JSON.stringify(report.errors))
	park.set_meta(META, report)
	print("SHINRAI_STATIC_MERGE ", JSON.stringify(report))
	return report

static func _run_module(park: Node3D, module: Node3D, rules: Dictionary, state: Dictionary) -> Dictionary:
	var started := Time.get_ticks_msec()
	var row := {
		"sources_merged": 0, "merged_meshes": 0, "nodes_freed": 0, "nodes_kept_without_mesh": 0,
		"hidden_collision_meshes_released": 0, "hidden_tris_released": 0,
		"mesh_nodes_before": 0, "meshes_before": 0, "meshes_after": 0,
		"tris_before": 0, "tris_after": 0, "tris_equal": true,
		"candidates": 0, "groups": 0, "groups_single": 0, "groups_failed": 0,
		"skipped": {}, "errors": [],
	}
	# One walk of the module: how many nodes use each mesh (ids only, so the
	# reference counts read below are not disturbed), and the hidden collision boxes.
	var uses := {}
	var hidden: Array[MeshInstance3D] = []
	var hidden_words: Array = rules.get("hidden_colliders", [])
	var all_meshes := module.find_children("*", "MeshInstance3D", true, false)
	for index: int in range(all_meshes.size()):
		var visual := all_meshes[index] as MeshInstance3D
		if visual == null or visual.mesh == null: continue
		row.mesh_nodes_before += 1
		var mesh_id := visual.mesh.get_instance_id()
		uses[mesh_id] = int(uses.get(mesh_id, 0)) + 1
		if not visual.visible and _name_has(visual, hidden_words) and _has_static_body_child(visual): hidden.append(visual)
	all_meshes.clear()
	row.meshes_before = uses.size()
	await LoadingBudget.checkpoint(park)
	if not is_instance_valid(module): return row

	# 1. Hidden-for-good collision boxes: free the mesh, keep the node and its body.
	for visual: MeshInstance3D in hidden:
		if not is_instance_valid(visual) or visual.mesh == null: continue
		var single := int(uses.get(visual.mesh.get_instance_id(), 0)) == 1
		row.hidden_tris_released += _triangles(visual.mesh)
		visual.mesh = null
		row.hidden_collision_meshes_released += 1
		if single: row.meshes_after -= 1
	hidden.clear()

	# 2. Candidates, grouped by the full key.
	var candidates: Array[MeshInstance3D] = []
	var seen := {}
	for root_rule: Dictionary in rules.roots:
		var root := module.get_node_or_null(NodePath(str(root_rule.path)))
		if root == null:
			_count(row.skipped, "root_missing:" + str(root_rule.path))
			continue
		var found: Array[MeshInstance3D] = []
		_collect(root, root_rule, found)
		for visual: MeshInstance3D in found:
			var id := visual.get_instance_id()
			if seen.has(id): continue
			seen[id] = root_rule
			candidates.append(visual)
	var groups := {}
	var order: Array = []
	var animatable_memo := {}
	for index: int in range(candidates.size()):
		if index % 32 == 31:
			await LoadingBudget.checkpoint(park)
			if not is_instance_valid(module): return row
		var visual := candidates[index]
		if not is_instance_valid(visual): continue
		var root_rule: Dictionary = seen[visual.get_instance_id()]
		var info := _qualify(visual, module, rules, root_rule, uses, state, animatable_memo)
		if info.has("skip"):
			_count(row.skipped, str(info.skip))
			continue
		row.candidates += 1
		var key: String = info.key
		if not groups.has(key):
			groups[key] = {"sources": [], "material": info.material, "format": info.format}
			order.append(key)
		groups[key].sources.append(visual)
	candidates.clear()
	seen.clear()
	row.groups = order.size()

	# 3. One merged mesh per group. Building, checking, adding the merged node and
	# retiring its sources happen without a yield in between.
	var container: Node3D = null
	var merged_count := 0
	for key: String in order:
		await LoadingBudget.checkpoint(park)
		if not is_instance_valid(module) or not module.is_inside_tree(): return row
		var group: Dictionary = groups[key]
		var sources: Array = group.sources
		if sources.size() < MIN_GROUP:
			row.groups_single += 1
			continue
		var built := _build(sources, int(group.format), state)
		if built.has("error"):
			row.groups_failed += 1
			if row.errors.size() < 12: row.errors.append(str(built.error))
			continue
		row.tris_before += int(built.tris_before)
		row.tris_after += int(built.tris_after)
		if int(built.tris_before) != int(built.tris_after):
			# Never publish a mesh whose triangle count differs: sources stay as built.
			row.tris_equal = false
			row.groups_failed += 1
			row.tris_before -= int(built.tris_before)
			row.tris_after -= int(built.tris_after)
			if row.errors.size() < 12: row.errors.append("triangles %d -> %d in a group of %d" % [built.tris_before, built.tris_after, sources.size()])
			continue
		if container == null:
			container = module.get_node_or_null(CONTAINER_NAME) as Node3D
			if container == null:
				container = Node3D.new()
				container.name = CONTAINER_NAME
				container.set_meta("creator_protected", true)
				container.set_meta("creator_editable", false)
				module.add_child(container)
		var first := sources[0] as MeshInstance3D
		var merged := MeshInstance3D.new()
		merged.name = MERGED_NAME % merged_count
		merged.mesh = built.mesh
		# The very Material object the sources drew with (night mode and presets
		# change materials in place).
		merged.material_override = group.material
		merged.material_overlay = first.material_overlay
		merged.cast_shadow = first.cast_shadow
		merged.layers = first.layers
		merged.gi_mode = first.gi_mode
		merged.gi_lightmap_scale = first.gi_lightmap_scale
		merged.lod_bias = first.lod_bias
		merged.extra_cull_margin = first.extra_cull_margin
		merged.ignore_occlusion_culling = first.ignore_occlusion_culling
		merged.transparency = first.transparency
		merged.sorting_offset = first.sorting_offset
		merged.sorting_use_aabb_center = first.sorting_use_aabb_center
		merged.visibility_range_begin = first.visibility_range_begin
		merged.visibility_range_begin_margin = first.visibility_range_begin_margin
		merged.visibility_range_end_margin = first.visibility_range_end_margin
		merged.visibility_range_fade_mode = first.visibility_range_fade_mode
		# Nothing may vanish earlier than today: the range is measured from the
		# merged bounds centre, so it grows by the farthest source centre.
		merged.visibility_range_end = first.visibility_range_end + float(built.reach) if first.visibility_range_end > 0.0 else 0.0
		merged.set_meta("merged_sources", sources.size())
		container.add_child(merged)
		merged.global_transform = Transform3D(Basis.IDENTITY, built.origin)
		merged_count += 1
		row.merged_meshes += 1
		row.sources_merged += sources.size()
		for source: MeshInstance3D in sources:
			if source.get_child_count() > 0:
				# A collision body (or anything else) lives under it: keep the node.
				source.mesh = null
				row.nodes_kept_without_mesh += 1
			else:
				source.get_parent().remove_child(source)
				source.queue_free()
				row.nodes_freed += 1
		sources.clear()
	groups.clear()
	# Every merged source owned its mesh alone, so each one retired a mesh.
	row.meshes_after += int(row.meshes_before) - int(row.sources_merged) + int(row.merged_meshes)
	row["mesh_nodes_after"] = int(row.mesh_nodes_before) - int(row.sources_merged) - int(row.hidden_collision_meshes_released) + int(row.merged_meshes)
	row["ms"] = Time.get_ticks_msec() - started
	return row

# ------------------------------------------------------------------ collecting

static func _collect(root: Node, root_rule: Dictionary, out: Array[MeshInstance3D]) -> void:
	if str(root_rule.get("mode", "descendants")) == "children":
		var within: Array = root_rule.get("within", [])
		for child: Node in root.get_children():
			if child is MeshInstance3D: out.append(child as MeshInstance3D)
			elif not within.is_empty() and _name_has(child, within) and not _closed_subtree(child, root_rule): _collect_below(child, root_rule, out)
	else:
		_collect_below(root, root_rule, out)

static func _collect_below(root: Node, root_rule: Dictionary, out: Array[MeshInstance3D]) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			if _closed_subtree(child, root_rule): continue
			if child is MeshInstance3D: out.append(child as MeshInstance3D)
			stack.append(child)

## Subtrees the merger never enters: moving bodies, the lift and ladder, the
## merged container itself and instanced model scenes (their meshes are shared).
static func _closed_subtree(node: Node, root_rule: Dictionary) -> bool:
	if node is AnimatableBody3D or node is MultiMeshInstance3D or node is Light3D or node is Label3D: return true
	if str(node.name) == CONTAINER_NAME: return true
	if _name_has(node, root_rule.get("skip_subtrees", [])): return true
	for group: String in root_rule.get("skip_groups", []):
		if node.is_in_group(group): return true
	var scene := node.scene_file_path.to_lower()
	if scene.ends_with(".glb") or scene.ends_with(".gltf"): return true
	return false

static func _name_has(node: Node, words: Array) -> bool:
	if words.is_empty(): return false
	var name := str(node.name)
	for word: String in words:
		if name.contains(word): return true
	return false

static func _has_static_body_child(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is StaticBody3D: return true
	return false

static func _count(tally: Dictionary, reason: String) -> void:
	tally[reason] = int(tally.get(reason, 0)) + 1

## References a single-use mesh shows through this exact expression (measured
## on a throw-away node, so it does not depend on engine internals).
static func _ref_baseline() -> int:
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	var count := _refs(probe)
	probe.free()
	return count

static func _refs(visual: MeshInstance3D) -> int:
	return visual.mesh.get_reference_count()

static func _animatable_above(node: Node, stop: Node, memo: Dictionary) -> bool:
	var walked: Array[int] = []
	var current := node.get_parent()
	var result := false
	while current != null and current != stop:
		var id := current.get_instance_id()
		if memo.has(id):
			result = memo[id]
			break
		walked.append(id)
		if current is AnimatableBody3D:
			result = true
			break
		current = current.get_parent()
	for id: int in walked: memo[id] = result
	return result

## {"skip": reason} or {"key", "material", "format"}.
static func _qualify(visual: MeshInstance3D, module: Node3D, rules: Dictionary, root_rule: Dictionary, uses: Dictionary, state: Dictionary, animatable_memo: Dictionary) -> Dictionary:
	if visual.mesh == null: return {"skip": "no_mesh"}
	# "Used by one node" comes from the park-wide use count below. The raw
	# reference count is no test: a mesh in the tree carries engine-side
	# references a throw-away probe node does not (every candidate read as shared).
	var mesh := visual.mesh
	if int(uses.get(mesh.get_instance_id(), 0)) != 1: return {"skip": "shared_mesh"}
	if not visual.is_visible_in_tree(): return {"skip": "hidden"}
	if visual.get_script() != null: return {"skip": "scripted"}
	# Group readers (night effects, walk surfaces) look nodes up by group.
	if not visual.get_groups().is_empty(): return {"skip": "grouped"}
	if visual.skin != null: return {"skip": "skinned"}
	if visual.visibility_parent != NodePath(): return {"skip": "visibility_parent"}
	if visual.visibility_range_begin != 0.0: return {"skip": "range_begin"}
	if visual.custom_aabb.has_volume() or visual.custom_aabb.has_surface(): return {"skip": "custom_aabb"}
	if _name_has(visual, rules.get("exclude_names", [])): return {"skip": "excluded_name"}
	if _animatable_above(visual, module, animatable_memo): return {"skip": "moving_body"}
	if mesh.get_surface_count() != 1: return {"skip": "surfaces"}
	var format := 0
	if mesh is PrimitiveMesh:
		if not mesh.get_class() in rules.get("primitives", []): return {"skip": "mesh_class:" + mesh.get_class()}
		format = PRIMITIVE_FORMAT
		if (mesh as PrimitiveMesh).add_uv2: format |= Mesh.ARRAY_FORMAT_TEX_UV2
	elif mesh is ArrayMesh:
		if not root_rule.get("array_meshes", false): return {"skip": "array_mesh"}
		# Script-built only: an imported mesh is a shared resource and may carry LODs.
		if not mesh.resource_path.is_empty(): return {"skip": "imported_mesh"}
		var array_mesh := mesh as ArrayMesh
		if array_mesh.get_blend_shape_count() > 0: return {"skip": "blend_shapes"}
		if array_mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES: return {"skip": "primitive_type"}
		format = array_mesh.surface_get_format(0) & ((1 << Mesh.ARRAY_MAX) - 1)
		if (format & ~CARRIED_FORMAT) != 0: return {"skip": "extra_arrays"}
	else:
		return {"skip": "mesh_class:" + mesh.get_class()}
	if absf(visual.global_transform.basis.determinant()) < 1e-9: return {"skip": "flat_transform"}
	# The material the surface really draws with.
	var material: Material = visual.material_override
	if material == null: material = visual.get_surface_override_material(0)
	if material == null: material = mesh.surface_get_material(0)
	var verdict := _material_verdict(material, state)
	if not verdict.is_empty(): return {"skip": verdict}
	verdict = _material_verdict(visual.material_overlay, state)
	if not verdict.is_empty(): return {"skip": "overlay_" + verdict}
	if visual.transparency > 0.0: return {"skip": "transparent"}
	# Per-instance shader parameters cannot survive a merge (Tokyo road slabs).
	if _has_instance_parameters(visual): return {"skip": "instance_parameters"}
	var centre: Vector3 = visual.global_transform * mesh.get_aabb().get_center()
	var cell := _cell_size(visual.visibility_range_end)
	var key := str([
		material.get_instance_id() if material != null else 0,
		visual.material_overlay.get_instance_id() if visual.material_overlay != null else 0,
		visual.cast_shadow, visual.layers, visual.gi_mode, visual.gi_lightmap_scale, visual.lod_bias,
		visual.visibility_range_begin, visual.visibility_range_end, visual.visibility_range_begin_margin, visual.visibility_range_end_margin, visual.visibility_range_fade_mode,
		visual.extra_cull_margin, visual.ignore_occlusion_culling, visual.transparency, visual.sorting_offset, visual.sorting_use_aabb_center,
		format & KEY_FORMAT, cell, floori(centre.x / cell), floori(centre.y / cell), floori(centre.z / cell),
	])
	return {"key": key, "material": material, "format": format}

static func _cell_size(range_end: float) -> float:
	if range_end <= 0.0: return UNRANGED_CELL
	for tier: Array in RANGE_CELLS:
		if range_end <= float(tier[0]): return float(tier[1])
	return UNRANGED_CELL

static func _has_instance_parameters(visual: MeshInstance3D) -> bool:
	for property: Dictionary in visual.get_property_list():
		var name := str(property.name)
		if name.begins_with("instance_shader_parameters/") and visual.get(name) != null: return true
	return false

## "" when the material is opaque and independent of the node origin, else why
## not. Remembered per material (the answer never depends on emission or tint).
static func _material_verdict(material: Material, state: Dictionary) -> String:
	if material == null: return ""
	var memo: Dictionary = state.materials
	var id := material.get_instance_id()
	if memo.has(id): return memo[id]
	memo[id] = ""
	var verdict := ""
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: verdict = "transparent"
		elif base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX: verdict = "transparent"
		elif base.refraction_enabled or base.proximity_fade_enabled or base.no_depth_test: verdict = "transparent"
		elif base.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: verdict = "distance_fade"
		elif base.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED: verdict = "billboard"
		# Object-space triplanar reads the vertex position inside the node.
		elif base.uv1_triplanar and not base.uv1_world_triplanar: verdict = "local_triplanar"
		elif base.uv2_triplanar and not base.uv2_world_triplanar: verdict = "local_triplanar"
	elif material is ShaderMaterial:
		verdict = _shader_verdict((material as ShaderMaterial).shader, state)
	else:
		verdict = "material_class:" + material.get_class()
	if verdict.is_empty() and material.next_pass != null:
		var next := _material_verdict(material.next_pass, state)
		if not next.is_empty(): verdict = "next_pass_" + next
	memo[id] = verdict
	return verdict

static func _shader_verdict(shader: Shader, state: Dictionary) -> String:
	if shader == null: return ""
	var memo: Dictionary = state.shaders
	var id := shader.get_instance_id()
	if memo.has(id): return memo[id]
	var verdict := ""
	if shader.get_mode() != Shader.MODE_SPATIAL:
		verdict = "shader_mode"
	else:
		var code := shader.code
		for word: String in SHADER_ORIGIN_WORDS:
			if code.contains(word):
				verdict = "shader_instance_data"
				break
		if verdict.is_empty():
			for word: String in SHADER_ALPHA_WORDS:
				if code.contains(word):
					verdict = "transparent"
					break
		if verdict.is_empty():
			# Any write to ALPHA (also ALPHA_SCISSOR users) is treated as not opaque.
			var alpha := RegEx.create_from_string("\\bALPHA\\s*[-+*/]?=[^=]")
			if alpha != null and alpha.search(code) != null: verdict = "transparent"
	memo[id] = verdict
	return verdict

# -------------------------------------------------------------------- geometry

## Triangles of a mesh without reading it back from the GPU where it is known.
static func _triangles(mesh: Mesh) -> int:
	if mesh is BoxMesh:
		var box := mesh as BoxMesh
		var w := box.subdivide_width + 1
		var h := box.subdivide_height + 1
		var d := box.subdivide_depth + 1
		return 4 * (w * h + d * h + d * w)
	if mesh is ArrayMesh:
		var count := 0
		for surface: int in range(mesh.get_surface_count()):
			var indices: int = (mesh as ArrayMesh).surface_get_array_index_len(surface)
			count += (indices if indices > 0 else (mesh as ArrayMesh).surface_get_array_len(surface)) / 3
		return count
	return mesh.get_faces().size() / 3

## The 1 m BoxMesh as the engine builds it, read once. Every plain box is this
## template scaled by its size: BoxMesh corners are exactly +-size/2 and its
## normals, tangents, UVs and indices do not depend on the size.
static func _unit_box(state: Dictionary) -> Dictionary:
	if state.unit_box_tried: return state.unit_box
	state.unit_box_tried = true
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var template := _template(unit.get_mesh_arrays())
	if template.is_empty() or int(template.vertices) != 24 or int(template.triangles) != 12: return state.unit_box
	for vertex: Vector3 in template.arrays[Mesh.ARRAY_VERTEX]:
		if not is_equal_approx(absf(vertex.x), .5) or not is_equal_approx(absf(vertex.y), .5) or not is_equal_approx(absf(vertex.z), .5): return state.unit_box
	state.unit_box = template
	return template

## Mesh arrays prepared for baking: {} when there is no vertex data.
static func _template(arrays: Array) -> Dictionary:
	if arrays.size() < Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array: return {}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count := vertices.size()
	if count == 0: return {}
	var template := {"arrays": arrays, "vertices": count}
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(count)
		for i: int in range(count): indices[i] = i
	if indices.size() % 3 != 0: return {}
	template["indices"] = indices
	template["triangles"] = indices.size() / 3
	# Tangents as direction + sign, so the directions can be turned in one call.
	if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array and (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() == count * 4:
		var packed: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var directions := PackedVector3Array()
		directions.resize(count)
		var signs := PackedFloat32Array()
		signs.resize(count)
		for i: int in range(count):
			directions[i] = Vector3(packed[i * 4], packed[i * 4 + 1], packed[i * 4 + 2])
			signs[i] = packed[i * 4 + 3]
		template["tangent_directions"] = directions
		template["tangent_signs"] = signs
	return template

## {"template", "scale", "triangles"} for one source mesh, or {} when unreadable.
static func _source_template(mesh: Mesh, state: Dictionary) -> Dictionary:
	if mesh is BoxMesh:
		var box := mesh as BoxMesh
		if box.subdivide_width == 0 and box.subdivide_height == 0 and box.subdivide_depth == 0 and not box.add_uv2 and not box.flip_faces:
			var unit := _unit_box(state)
			if not unit.is_empty(): return {"template": unit, "scale": box.size, "triangles": 12}
	var template := {}
	if mesh is PrimitiveMesh:
		# Identical primitives (72 car wheels, ...) are read back once.
		var signature := _primitive_signature(mesh as PrimitiveMesh)
		var cache: Dictionary = state.templates
		if not signature.is_empty() and cache.has(signature): template = cache[signature]
		else:
			template = _template((mesh as PrimitiveMesh).get_mesh_arrays())
			if not signature.is_empty(): cache[signature] = template
	elif mesh is ArrayMesh:
		template = _template((mesh as ArrayMesh).surface_get_arrays(0))
	if template.is_empty(): return {}
	return {"template": template, "scale": Vector3.ONE, "triangles": int(template.triangles)}

## Every stored parameter that shapes the primitive ("" = do not share).
static func _primitive_signature(mesh: PrimitiveMesh) -> String:
	var parts: Array = [mesh.get_class()]
	for property: Dictionary in mesh.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0: continue
		var name := str(property.name)
		if name in ["resource_local_to_scene", "resource_path", "resource_name", "resource_scene_unique_id", "script", "material", "custom_aabb"]: continue
		var value: Variant = mesh.get(name)
		if value is Object: return ""
		parts.append(name)
		parts.append(value)
	return var_to_str(parts)

## Bakes the sources into one indexed surface in the space of a node placed at
## `origin` (whole metres near the group, no rotation or scale).
## {"mesh", "origin", "reach", "tris_before", "tris_after"} or {"error"}.
static func _build(sources: Array, format: int, state: Dictionary) -> Dictionary:
	var want_normals := (format & Mesh.ARRAY_FORMAT_NORMAL) != 0
	var want_tangents := (format & Mesh.ARRAY_FORMAT_TANGENT) != 0
	var want_colors := (format & Mesh.ARRAY_FORMAT_COLOR) != 0
	var want_uv := (format & Mesh.ARRAY_FORMAT_TEX_UV) != 0
	var want_uv2 := (format & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
	var centres := PackedVector3Array()
	var sum := Vector3.ZERO
	for source: MeshInstance3D in sources:
		if not is_instance_valid(source) or source.mesh == null or not source.is_inside_tree(): return {"error": "a source changed before the merge"}
		var centre: Vector3 = source.global_transform * source.mesh.get_aabb().get_center()
		centres.append(centre)
		sum += centre
	var origin := (sum / float(sources.size())).floor()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var tris_before := 0
	for source: MeshInstance3D in sources:
		var entry := _source_template(source.mesh, state)
		if entry.is_empty(): return {"error": "no readable arrays for " + str(source.name)}
		var template: Dictionary = entry.template
		var arrays: Array = template.arrays
		var count: int = template.vertices
		tris_before += int(entry.triangles)
		var world := source.global_transform
		world.origin -= origin
		var basis := world.basis
		var rigid := basis.is_equal_approx(basis.orthonormalized())
		var base := vertices.size()
		vertices.append_array(Transform3D(basis * Basis.from_scale(entry.scale), world.origin) *(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		if want_normals:
			if not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() != count: return {"error": "normals missing on " + str(source.name)}
			# Normals turn with the inverse transpose (equal to the basis when rigid).
			var turned: PackedVector3Array = Transform3D(basis if rigid else basis.inverse().transposed(), Vector3.ZERO) * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			if not rigid:
				for i: int in range(count): turned[i] = turned[i].normalized()
			normals.append_array(turned)
		if want_tangents:
			if not template.has("tangent_directions"): return {"error": "tangents missing on " + str(source.name)}
			var directions: PackedVector3Array = Transform3D(basis, Vector3.ZERO) * (template.tangent_directions as PackedVector3Array)
			var signs: PackedFloat32Array = template.tangent_signs
			var at := tangents.size()
			tangents.resize(at + count * 4)
			for i: int in range(count):
				var direction := directions[i] if rigid else directions[i].normalized()
				tangents[at] = direction.x
				tangents[at + 1] = direction.y
				tangents[at + 2] = direction.z
				# A mirrored source flips cross(N, T), so the bitangent sign flips with it.
				tangents[at + 3] = signs[i] * (-1.0 if basis.determinant() < 0.0 else 1.0)
				at += 4
		if want_colors:
			if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray or (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() != count: return {"error": "colours missing on " + str(source.name)}
			colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if want_uv:
			if not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() != count: return {"error": "UVs missing on " + str(source.name)}
			uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if want_uv2:
			if not arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array or (arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size() != count: return {"error": "UV2 missing on " + str(source.name)}
			uv2s.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		var source_indices: PackedInt32Array = template.indices
		var index_at := indices.size()
		var index_count := source_indices.size()
		indices.resize(index_at + index_count)
		if basis.determinant() < 0.0:
			# A mirrored node draws with reversed winding: bake the same faces.
			for i: int in range(0, index_count, 3):
				indices[index_at + i] = base + source_indices[i]
				indices[index_at + i + 1] = base + source_indices[i + 2]
				indices[index_at + i + 2] = base + source_indices[i + 1]
		else:
			for i: int in range(index_count): indices[index_at + i] = base + source_indices[i]
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = vertices
	if want_normals: arrays_out[Mesh.ARRAY_NORMAL] = normals
	if want_tangents: arrays_out[Mesh.ARRAY_TANGENT] = tangents
	if want_colors: arrays_out[Mesh.ARRAY_COLOR] = colors
	if want_uv: arrays_out[Mesh.ARRAY_TEX_UV] = uvs
	if want_uv2: arrays_out[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays_out[Mesh.ARRAY_INDEX] = indices
	var merged := ArrayMesh.new()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	if merged.get_surface_count() != 1: return {"error": "the merged surface was rejected"}
	var tris_after: int = merged.surface_get_array_index_len(0) / 3
	if merged.surface_get_array_len(0) != vertices.size(): tris_after = -1
	# Farthest source centre from the merged bounds centre (world metres).
	var merged_centre := origin + merged.get_aabb().get_center()
	var reach := 0.0
	for centre: Vector3 in centres: reach = maxf(reach, merged_centre.distance_to(centre))
	arrays_out.clear()
	return {"mesh": merged, "origin": origin, "reach": reach, "tris_before": tris_before, "tris_after": tris_after}
