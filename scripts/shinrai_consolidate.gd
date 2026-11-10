extends RefCounted
## End-of-boot consolidation: fewer GPU buffers for the same picture.
## On Direct3D 12 every GPU buffer is rounded up to 64 KB, so a MultiMesh costs
## at least 64 KB and a unique mesh at least 192 KB per surface, however small.
## ExtractionRun._prepare_park awaits run() once per park, AFTER the render
## budget (the draw-distance pass has then ranged every original node, and the
## plant-shadow budget has captured its chunks) and BEFORE phase = HQ.
## Raid boot only: Creator Mode has no ExtractionRun and never reaches this.
##   1. plants: the hidden-for-good MultiMeshes are released (this file).
##   2. merge:  scripts/shinrai_static_merge.gd
##   3. street: scripts/shinrai_street_consolidate.gd
## Each step runs on its own: a missing script, a missing node or a script error
## in one step leaves the park as that step found it and never stops the boot or
## the other steps. Each yields on the shared loading budget.
## A/B switches (user arguments, after `--`): --no-consolidate (all three),
## --no-consolidate-plants, --no-consolidate-merge, --no-consolidate-street.
## The file name starts with shinrai_, not midori_: every scripts/midori*.gd is
## hashed into the saved Creator layout's world revision.
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const Trace := preload("res://scripts/startup_trace.gd")
const STARTED_META := &"shinrai_consolidation_started"
## The combined report: {status, ms, plants: {...}, merge: {...}, street: {...}}.
const RESULT_META := &"shinrai_consolidation"
const MERGE_PATH := "res://scripts/shinrai_static_merge.gd"
const STREET_PATH := "res://scripts/shinrai_street_consolidate.gd"
## [report key, off switch, script ("" = the plant release in this file)].
const STEPS := [
	["plants", "--no-consolidate-plants", ""],
	["merge", "--no-consolidate-merge", MERGE_PATH],
	["street", "--no-consolidate-street", STREET_PATH],
]
## A step that has returned nothing after this long is left behind (GDScript has
## no exceptions: a script error ends the step's coroutine without a result).
## --consolidate-timeout-s=<n> replaces it.
## Long enough that only a dead step reaches it (the menu's 14 ms budget share
## makes a healthy step slow), short of the boot host's 300 s stall watchdog.
const STEP_LIMIT_MS := 240000

## Instance ids of the planting batches midori_distance_detail.gd copied into its
## cells and then hid (published there, next to the hide).
const HIDDEN_META := &"midori_distance_hidden_sources"
const DETAIL_META := &"midori_distance_detail"
const DETAIL_NODE := "MidoriDistanceDetail"
## Kept as nodes with their mesh, ranges and material: the plant-shadow budget
## reads them on every (re)capture (midori_near_plant_shadows.gd:97-104).
const KEEP_NODE_PREFIX := "JapaneseForestGrassDrift_"
## Direct3D 12 placed-resource granularity: the least one MultiMesh buffer costs.
const D3D12_BUFFER_FLOOR := 65536

static func run(park: Node3D) -> Dictionary:
	if not is_instance_valid(park) or not park.is_inside_tree(): return {"status": "cancelled"}
	if park.has_meta(RESULT_META): return park.get_meta(RESULT_META)
	var tree := park.get_tree()
	if park.get_meta(STARTED_META, false):
		# A second caller waits for the first one's result; nothing runs twice.
		while is_instance_valid(park) and park.is_inside_tree() and not park.has_meta(RESULT_META): await tree.process_frame
		return park.get_meta(RESULT_META) if is_instance_valid(park) and park.has_meta(RESULT_META) else {"status": "cancelled"}
	park.set_meta(STARTED_META, true)
	var started := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var report := {"status": "complete"}
	if "--no-consolidate" in args:
		report = {"status": "disabled", "by": "--no-consolidate", "ms": 0}
		park.set_meta(RESULT_META, report)
		return report
	var limit_ms := STEP_LIMIT_MS
	for arg: String in args:
		if arg.begins_with("--consolidate-timeout-s="): limit_ms = clampi(int(arg.get_slice("=", 1)), 1, 280) * 1000
	for step: Array in STEPS:
		var key: String = step[0]
		if String(step[1]) in args:
			report[key] = {"skipped": String(step[1])}
			continue
		await Budget.checkpoint(park)
		if not is_instance_valid(park) or not park.is_inside_tree(): return {"status": "cancelled"}
		# Reported per step so each one restarts the boot host's stall watchdog.
		Budget.stage(park, "Tidying the park")
		var tick := Trace.begin()
		var step_started := Time.get_ticks_msec()
		var result: Dictionary = await _guarded(park, String(step[2]), limit_ms)
		Trace.finish("consolidate." + key, tick)
		if String(result.get("status", "")) == "cancelled": return {"status": "cancelled"}
		result["wall_ms"] = Time.get_ticks_msec() - step_started
		if result.has("error"):
			report["status"] = "partial"
			push_warning("SHINRAI_CONSOLIDATE %s: %s" % [key, str(result.error)])
		report[key] = result
	report["ms"] = Time.get_ticks_msec() - started
	park.set_meta(RESULT_META, report)
	return report

## Runs one step detached and waits for its report, the park's end or the limit,
## whichever comes first, so a step that dies on a script error (its coroutine
## simply never returns) costs the boot the limit at most, never a hang.
static func _guarded(park: Node3D, path: String, limit_ms: int) -> Dictionary:
	var script: Script = null
	if not path.is_empty():
		if not ResourceLoader.exists(path): return {"skipped": "script not present", "path": path}
		script = load(path) as Script
		if script == null or not script.can_instantiate(): return {"error": "script did not load", "path": path}
		var has_run := false
		for method: Dictionary in script.get_script_method_list():
			if String(method.get("name", "")) == "run": has_run = true; break
		if not has_run: return {"error": "script has no run(park)", "path": path}
	var box := {"done": false, "report": {}}
	_boxed(park, script, box)
	var tree := park.get_tree()
	var started := Time.get_ticks_msec()
	while not bool(box.done):
		if not is_instance_valid(park) or not park.is_inside_tree(): return {"status": "cancelled"}
		if Time.get_ticks_msec() - started >= limit_ms:
			return {"error": "no report after %d s (script error, or still running: see the log)" % [limit_ms / 1000], "status": "abandoned"}
		await tree.process_frame
	return box.report

static func _boxed(park: Node3D, script: Script, box: Dictionary) -> void:
	var result: Variant
	if script == null: result = await release_hidden_plants(park)
	else: result = await script.call("run", park)
	box.report = (result as Dictionary) if result is Dictionary else {"error": "step returned no report (script error inside it?)"}
	box.done = true

## Step 1. Two sets of MultiMeshInstance3D nodes are hidden for good and still
## hold a GPU buffer each:
##   A. the planting batches midori_distance_detail.gd copied into its 12 m
##      cells and hid (the list it publishes; never re-derived from "invisible
##      planting", which would also catch nodes hidden for other reasons);
##   B. the distance-detail cells the Bush006 swap hid (midori_clipped_shrubs.gd
##      :108 is the only code that hides a cell, and nothing shows one again).
## Their node is freed and their MultiMesh emptied. Nothing drawn changes: only
## nodes whose own `visible` is false are touched, and no visible node's
## MultiMesh, mesh, material, name, range or shadow setting is.
## Left alone, counted under "kept":
##   - a node that is visible again, has a script, a visibility parent or children;
##   - a node the plant-shadow budget holds (its rows, its visibility list);
##   - a node whose MultiMesh any node outside the two sets uses (a visible
##     batch, a PooledPlantShadow proxy);
##   - JapaneseForestGrassDrift_*: the node, its mesh, ranges and material stay
##     (KEEP_NODE_PREFIX); only its instances go.
## Releasing the buffer does not depend on one engine behaviour: the node drops
## its MultiMesh reference and is freed (a MultiMesh nothing else holds dies with
## it, buffer included), and the MultiMesh is also emptied (instance_count = 0)
## for the case where something still holds it (the in-raid Creator registry
## keeps the grass batches' MultiMeshes: creator_object_registry.gd:381).
static func release_hidden_plants(park: Node3D) -> Dictionary:
	var started := Time.get_ticks_msec()
	var detail: Variant = park.get_meta(DETAIL_META, null)
	# A fallback boot (no cells, or the copy failed validation) hid no source.
	if not (detail is Dictionary) or (detail as Dictionary).has("error"): return {"skipped": "distance detail not installed"}
	var container := park.get_node_or_null(DETAIL_NODE) as Node3D
	if container == null or not container.visible or container.is_queued_for_deletion(): return {"skipped": "distance detail cells missing or hidden"}
	var listed := PackedInt64Array()
	var raw: Variant = park.get_meta(HIDDEN_META, null)
	if raw is PackedInt64Array: listed = raw
	# What the plant-shadow budget holds by reference (visible cells in practice).
	var held := {}
	var shadows := park.get_node_or_null("MidoriNearPlantShadows")
	if shadows != null:
		var rows: Variant = shadows.get("rows")
		if rows is Array:
			for row: Variant in (rows as Array):
				if row is Dictionary and is_instance_valid((row as Dictionary).get("node")):
					held[((row as Dictionary).node as Object).get_instance_id()] = true
		var watched: Variant = shadows.get("visibility_sources")
		if watched is Array:
			for node: Variant in (watched as Array):
				if is_instance_valid(node): held[(node as Object).get_instance_id()] = true
	await Budget.checkpoint(park)
	if not is_instance_valid(park): return {"status": "cancelled"}
	if not is_instance_valid(container): return {"skipped": "distance detail cells went away"}
	# How many nodes in the park use each MultiMesh (one walk).
	var users := {}
	var everything := park.find_children("*", "MultiMeshInstance3D", true, false)
	var mmi_before := everything.size()
	for index: int in range(everything.size()):
		if index % 512 == 511: await Budget.checkpoint(park)
		var any := everything[index] as MultiMeshInstance3D
		if not is_instance_valid(any) or any.multimesh == null: continue
		var mm_id := any.multimesh.get_instance_id()
		users[mm_id] = int(users.get(mm_id, 0)) + 1
	everything.clear()
	if not is_instance_valid(park): return {"status": "cancelled"}
	if not is_instance_valid(container): return {"skipped": "distance detail cells went away"}
	var kept := {"gone": 0, "visible": 0, "scripted": 0, "has_children": 0, "held_by_plant_shadows": 0, "shared_multimesh": 0}
	var candidates: Array[MultiMeshInstance3D] = []
	var is_cell: Array[bool] = []
	var chosen := {}
	var set_users := {}
	# A: the published sources, in the order they were copied.
	for index: int in range(listed.size()):
		if index % 512 == 511: await Budget.checkpoint(park)
		var source := instance_from_id(listed[index]) as MultiMeshInstance3D
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree() or not park.is_ancestor_of(source):
			kept.gone += 1
			continue
		var why := _keep_reason(source, held)
		if not why.is_empty():
			kept[why] += 1
			continue
		chosen[source.get_instance_id()] = true
		candidates.append(source)
		is_cell.append(false)
	# B: the cells hidden by the Bush006 swap (direct children only: the clipped
	# shrubs that replaced them hang one level lower and are visible).
	if is_instance_valid(container):
		for child: Node in container.get_children():
			var cell := child as MultiMeshInstance3D
			if cell == null or cell.visible or chosen.has(cell.get_instance_id()): continue
			var why := _keep_reason(cell, held)
			if not why.is_empty():
				kept[why] += 1
				continue
			chosen[cell.get_instance_id()] = true
			candidates.append(cell)
			is_cell.append(true)
	for node: MultiMeshInstance3D in candidates:
		if node.multimesh == null: continue
		var mm_id := node.multimesh.get_instance_id()
		set_users[mm_id] = int(set_users.get(mm_id, 0)) + 1
	var freed_sources := 0
	var freed_cells := 0
	var emptied_kept_nodes := 0
	var emptied := {}
	var instances := 0
	var triangles := 0
	var buffer_bytes := 0
	var by_module := {}
	var triangle_memo := {}
	for index: int in range(candidates.size()):
		# Nothing is held across a yield: each node is judged again when its turn comes.
		if index % 64 == 63: await Budget.checkpoint(park)
		var node := candidates[index]
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
			kept.gone += 1
			continue
		var why := _keep_reason(node, held)
		if not why.is_empty():
			kept[why] += 1
			continue
		var mm := node.multimesh
		if mm != null and int(users.get(mm.get_instance_id(), 0)) > int(set_users.get(mm.get_instance_id(), 0)):
			# A node outside the two sets draws from this MultiMesh: not ours to empty.
			kept.shared_multimesh += 1
			continue
		var module := String(park.get_path_to(node).get_name(0))
		by_module[module] = int(by_module.get(module, 0)) + 1
		if mm != null and not emptied.has(mm.get_instance_id()):
			var count := mm.instance_count
			instances += count
			triangles += count * _triangles(mm.mesh, triangle_memo)
			buffer_bytes += count * (12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)) * 4
		if String(node.name).begins_with(KEEP_NODE_PREFIX):
			# The node stays, with the same mesh, ranges and material; no instances.
			if mm != null: node.multimesh = _empty_like(mm)
			emptied_kept_nodes += 1
		else:
			node.multimesh = null
			node.get_parent().remove_child(node)
			node.queue_free()
			if is_cell[index]: freed_cells += 1
			else: freed_sources += 1
		if mm != null and not emptied.has(mm.get_instance_id()):
			emptied[mm.get_instance_id()] = true
			# Every user was in the two sets (checked above) and has let go of it.
			mm.visible_instance_count = -1
			mm.instance_count = 0
	if is_instance_valid(park) and park.has_meta(HIDDEN_META): park.remove_meta(HIDDEN_META)
	var released := freed_sources + freed_cells + emptied_kept_nodes
	return {
		"status": "released",
		"listed_sources": listed.size(),
		"copied_source_batches": int((detail as Dictionary).get("source_batches", -1)),
		"freed_source_nodes": freed_sources,
		"freed_hidden_cells": freed_cells,
		"emptied_kept_nodes": emptied_kept_nodes,
		"multimeshes_emptied": emptied.size(),
		"kept": kept,
		"by_module": by_module,
		"mmi_before": mmi_before,
		"mmi_after": mmi_before - freed_sources - freed_cells,
		# Hidden geometry only: what a census that counts hidden nodes will miss.
		"hidden_instances_released": instances,
		"hidden_triangles_released": triangles,
		"visible_triangles_changed": 0,
		"instance_data_bytes": buffer_bytes,
		"d3d12_floor_bytes_estimate": released * D3D12_BUFFER_FLOOR,
		"ms": Time.get_ticks_msec() - started,
	}

## "" when the node may be released, else the "kept" counter it belongs to.
static func _keep_reason(node: MultiMeshInstance3D, held: Dictionary) -> String:
	# Its own flag, not the tree's: a batch someone has shown again is in use
	# even while an ancestor happens to be hidden.
	if node.visible: return "visible"
	if node.get_script() != null or node.visibility_parent != NodePath(): return "scripted"
	if node.get_child_count() > 0: return "has_children"
	if held.has(node.get_instance_id()): return "held_by_plant_shadows"
	return ""

## An empty MultiMesh of the same mesh and layout (no instances, so no buffer).
static func _empty_like(source: MultiMesh) -> MultiMesh:
	var empty := MultiMesh.new()
	empty.transform_format = source.transform_format
	empty.use_colors = source.use_colors
	empty.use_custom_data = source.use_custom_data
	empty.mesh = source.mesh
	return empty

## Triangles of one instance, from the surface headers (no GPU read-back).
## Report only; a mesh that is not an ArrayMesh counts 0.
static func _triangles(mesh: Mesh, memo: Dictionary) -> int:
	if mesh == null: return 0
	var id := mesh.get_instance_id()
	if memo.has(id): return int(memo[id])
	var count := 0
	var arrays := mesh as ArrayMesh
	if arrays != null:
		for surface: int in range(arrays.get_surface_count()):
			var indices := arrays.surface_get_array_index_len(surface)
			count += int((indices if indices > 0 else arrays.surface_get_array_len(surface)) / 3.0)
	memo[id] = count
	return count
