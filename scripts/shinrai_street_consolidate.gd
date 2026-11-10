extends RefCounted
## End-of-boot consolidation of park/MidoriSouthStreet (third sub-step of
## scripts/shinrai_consolidate.gd; raid boot only, after the render budget and
## before HQ). On Direct3D 12 every GPU buffer is rounded up to 64 KB, so a
## 24-vertex box with a mesh of its own costs about 192 KB. Two things here,
## neither of which changes a pixel:
##   1. SHARE: every unscripted primitive mesh (BoxMesh, CylinderMesh, ...) that
##      only street nodes hold is replaced by one shared instance per set of
##      generating properties. No node, transform, material, layer or range
##      changes; equal properties generate equal arrays.
##   2. FREE: visuals that are hidden for good are freed: the Bush006 sources the
##      clipped shrubs hid (scripts/midori_clipped_shrubs.gd) and the hidden
##      stand-in furniture of each home (scripts/building_access/geometry.gd
##      furnish(): HomeLowSofa, HomeDiningTable, DiningTableLeg x4). Their
##      colliders are separate sibling bodies and stay.
## Nothing is merged here (merging inside creator roots, door leaves and window
## sashes, and MidoriHorizon, are later rounds).
##
## RULE THIS ADDS (like the pooled-shader rule): a primitive mesh under the street
## may be shown by many nodes after boot. Never edit one in place (mesh.size = ...,
## mesh.material = ...); assign the node a new mesh instead. A mesh that anything
## but street MeshInstance3D nodes still references at this point is left alone,
## so a script that keeps its own mesh in a variable keeps a private one.
##
## A/B switches (user arguments, after "--"): --no-consolidate-street-share,
## --no-consolidate-street-free. The orchestrator owns --no-consolidate and
## --no-consolidate-street.
const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const RESULT_META := &"shinrai_street_consolidated"
const STREET := "MidoriSouthStreet"
## Late producers that are not in the distance boot's wait list. Past this wait
## the whole step is skipped (nothing touched), never run on a half-built street.
const WAIT_MSEC := 15000
## Primitive classes that generate one surface from their stored properties
## (the street's own list, midori_south_street.gd _TRIANGLE_PRIMITIVES).
const SHARED_CLASSES := ["BoxMesh", "CylinderMesh", "SphereMesh", "TorusMesh", "PrismMesh", "QuadMesh", "PlaneMesh", "CapsuleMesh"]
## Stored properties that do not shape the generated arrays (the street's list).
## custom_aabb and resource_name are appended to the key here, so meshes that
## differ in either are never shared.
const KEY_SKIP := ["material", "resource_name", "resource_path", "resource_local_to_scene", "resource_scene_unique_id", "script", "custom_aabb"]
const STAND_INS := ["HomeLowSofa", "HomeDiningTable", "DiningTableLeg"]
const LEAF_TEXTURE := "scene_9.png"

static func run(park: Node3D) -> Dictionary:
	var started := Time.get_ticks_msec()
	if not is_instance_valid(park) or not park.is_inside_tree():
		return {"status": "skipped", "reason": "park unavailable"}
	if park.has_meta(RESULT_META): return park.get_meta(RESULT_META)
	# Marks the step as taken at once: a second caller gets this row, never a second pass.
	park.set_meta(RESULT_META, {"status": "running"})
	var street := park.get_node_or_null(STREET) as Node3D
	if street == null: return _finish(park, {"status": "skipped", "reason": "no " + STREET}, started)
	var waited := Time.get_ticks_msec()
	var not_ready: String = await _wait_ready(park, street)
	if not is_instance_valid(park) or not park.is_inside_tree(): return {"status": "cancelled"}
	if not not_ready.is_empty(): return _finish(park, {"status": "skipped", "reason": not_ready}, started)
	var args := OS.get_cmdline_user_args()
	var report := {"status": "complete", "wait_ms": Time.get_ticks_msec() - waited}
	var before: Dictionary = await _census(park, street)
	if not is_instance_valid(street): return _finish(park, {"status": "cancelled"}, started)
	report["before"] = before

	var tick := Time.get_ticks_msec()
	if "--no-consolidate-street-share" in args: report["share"] = {"skipped": "switched off"}
	else: report["share"] = await _share_primitives(park, street)
	(report["share"] as Dictionary)["ms"] = Time.get_ticks_msec() - tick
	if not is_instance_valid(street) or not is_instance_valid(park): return _finish(park, {"status": "cancelled"}, started)

	tick = Time.get_ticks_msec()
	if "--no-consolidate-street-free" in args: report["hidden"] = {"skipped": "switched off"}
	else: report["hidden"] = await _free_hidden(park, street)
	(report["hidden"] as Dictionary)["ms"] = Time.get_ticks_msec() - tick
	if not is_instance_valid(street) or not is_instance_valid(park): return _finish(park, {"status": "cancelled"}, started)

	# Freed nodes leave the tree at once (remove_child), so the census is exact now.
	var after: Dictionary = await _census(park, street)
	report["after"] = after
	report["nodes_freed"] = int(before.get("nodes", 0)) - int(after.get("nodes", 0))
	report["meshes_before"] = int(before.get("unique_meshes", 0))
	report["meshes_after"] = int(after.get("unique_meshes", 0))
	report["tris_before"] = int(before.get("tris", 0))
	report["tris_after"] = int(after.get("tris", 0))
	return _finish(park, report, started)

static func _finish(park: Node3D, report: Dictionary, started: int) -> Dictionary:
	report["ms"] = Time.get_ticks_msec() - started
	if is_instance_valid(park): park.set_meta(RESULT_META, report)
	print("SHINRAI_STREET_CONSOLIDATE ", JSON.stringify(report))
	return report

## "" once every producer that still adds street geometry has finished, else why not.
static func _wait_ready(park: Node3D, street: Node3D) -> String:
	var deadline := Time.get_ticks_msec() + WAIT_MSEC
	while true:
		if not is_instance_valid(park) or not park.is_inside_tree() or not is_instance_valid(street): return "park went away"
		var pending := _pending(park, street)
		if pending.is_empty(): return ""
		if Time.get_ticks_msec() >= deadline: return "not ready: " + ", ".join(pending)
		await park.get_tree().process_frame
	return ""

static func _pending(park: Node3D, street: Node3D) -> PackedStringArray:
	var pending := PackedStringArray()
	if street.get("installed") != true: pending.append(STREET)
	# Adds the shop retrofits, interiors and home exteriors under the street, and
	# scans the street's materials (midori_neon_street.gd _ready, :62-97).
	var neon := park.get_node_or_null("MidoriNeonStreet")
	if neon != null and neon.get_script() != null and neon.get("installed") != true: pending.append("MidoriNeonStreet")
	# Measures mesh bounds of the hand-built city while it builds (not the street's,
	# but the consolidation steps wait for it as one rule). An alley life that gave
	# up (no near city) reports an error and never installs: that counts as finished.
	var alley := park.get_node_or_null("MidoriAlleyLife")
	if alley != null and alley.get_script() != null and alley.get("installed") != true:
		var alley_report: Variant = alley.get("report")
		if not (alley_report is Dictionary and (alley_report as Dictionary).has("error")): pending.append("MidoriAlleyLife")
	return pending

# ---------------------------------------------------------------- 1. share

static func _share_primitives(park: Node3D, street: Node3D) -> Dictionary:
	var report := {"primitive_nodes": 0, "meshes_before": 0, "meshes_after": 0, "nodes_repointed": 0,
		"kept_mesh_material": 0, "kept_named_or_saved": 0, "kept_other_class": 0, "kept_scripted": 0, "kept_referenced_elsewhere": 0}
	# What one node and one row of the table below add to a mesh's reference count,
	# measured, not assumed: any mesh with more references than that is also held
	# by something else (a script variable, a MultiMesh, a static cache such as
	# midori_park_kit.gd _unit_tubes, a node outside the street) and is left alone.
	var baseline := _reference_baseline()
	var by_mesh: Dictionary = await _collect_primitives(park, street, report)
	if not is_instance_valid(street): return report
	report["meshes_before"] = by_mesh.size()
	# The street's own key (midori_south_street.gd _primitive_key) when reachable.
	# It refills the street's property-name table, which release_build_data()
	# emptied at the end of the world-complete step: emptied again below.
	var street_key := street.has_method("_primitive_key")
	var props_before: Variant = street.get("_primitive_props")
	var props_were_empty: bool = props_before is Dictionary and (props_before as Dictionary).is_empty()
	var own_props: Dictionary = {}
	var shared: Dictionary = {}
	var done := 0
	for entry: Dictionary in by_mesh.values():
		if _extra_references(entry) != baseline:
			report["kept_referenced_elsewhere"] = int(report["kept_referenced_elsewhere"]) + 1
			continue
		var key := _key_of(street, street_key, own_props, entry)
		if not shared.has(key):
			shared[key] = entry
			continue
		var keeper: Dictionary = shared[key]
		for visual: MeshInstance3D in entry["nodes"]:
			if not is_instance_valid(visual): continue
			_repoint(visual, keeper)
			report["nodes_repointed"] = int(report["nodes_repointed"]) + 1
			done += 1
			if done % 128 == 127:
				await Budget.checkpoint(park)
				if not is_instance_valid(street): return report
	report["meshes_after"] = by_mesh.size() - (int(report["meshes_before"]) - int(report["kept_referenced_elsewhere"]) - shared.size())
	report["shared_keys"] = shared.size()
	report["key"] = "street._primitive_key" if street_key else "own property list"
	if street_key and props_were_empty:
		var props_now: Variant = street.get("_primitive_props")
		if props_now is Dictionary: (props_now as Dictionary).clear()
	return report

## Mesh instance id -> {"mesh": PrimitiveMesh, "nodes": [MeshInstance3D]} for every
## shareable primitive under the street. In its own function so that no local of
## the walk still references a mesh when the reference counts are read.
static func _collect_primitives(park: Node3D, street: Node3D, report: Dictionary) -> Dictionary:
	var by_mesh: Dictionary = {}
	var visuals := street.find_children("*", "MeshInstance3D", true, false)
	await Budget.checkpoint(park)
	for index: int in range(visuals.size()):
		if index % 256 == 255:
			await Budget.checkpoint(park)
			if not is_instance_valid(street): return {}
		var visual := visuals[index] as MeshInstance3D
		if not is_instance_valid(visual) or visual.is_queued_for_deletion() or not visual.mesh is PrimitiveMesh: continue
		report["primitive_nodes"] = int(report["primitive_nodes"]) + 1
		# A scripted visual may own and animate its mesh: it is not counted as a
		# holder, so its mesh has one reference too many below and stays private.
		if visual.get_script() != null:
			report["kept_scripted"] = int(report["kept_scripted"]) + 1
			continue
		var id := visual.mesh.get_instance_id()
		if by_mesh.has(id):
			(by_mesh[id]["nodes"] as Array).append(visual)
			continue
		var reason := _unshareable(visual.mesh as PrimitiveMesh)
		if not reason.is_empty():
			report[reason] = int(report[reason]) + 1
			# Remembered as unshareable (empty holder list never matches the baseline).
			by_mesh[id] = {"mesh": null, "nodes": []}
			continue
		by_mesh[id] = {"mesh": visual.mesh, "nodes": [visual]}
	for id: int in by_mesh.keys():
		if by_mesh[id]["mesh"] == null: by_mesh.erase(id)
	return by_mesh

## "" when the mesh may be shared, else the report counter it falls under.
static func _unshareable(mesh: PrimitiveMesh) -> String:
	if mesh.get_script() != null: return "kept_scripted"
	if not mesh.get_class() in SHARED_CLASSES: return "kept_other_class"
	# A material on the mesh is per-mesh state some builders use instead of an
	# override (and one could be set later): those meshes stay private.
	if mesh.material != null: return "kept_mesh_material"
	if not mesh.resource_path.is_empty() or mesh.resource_local_to_scene or not mesh.get_meta_list().is_empty(): return "kept_named_or_saved"
	return ""

static func _extra_references(entry: Dictionary) -> int:
	var mesh: Variant = entry["mesh"]
	if not mesh is RefCounted: return -1
	return (mesh as RefCounted).get_reference_count() - (entry["nodes"] as Array).size()

static func _reference_baseline() -> int:
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	var entry := {"mesh": probe.mesh, "nodes": [probe]}
	var extra := _extra_references(entry)
	probe.free()
	return extra

static func _key_of(street: Node3D, street_key: bool, own_props: Dictionary, entry: Dictionary) -> Array:
	var mesh := entry["mesh"] as PrimitiveMesh
	var key: Array = []
	if street_key:
		var made: Variant = street.call("_primitive_key", mesh)
		if made is Array: key = (made as Array).duplicate()
	if key.is_empty():
		var kind := mesh.get_class()
		if not own_props.has(kind):
			# Every stored property except the material shapes the generated arrays.
			var names: Array[String] = []
			for prop: Dictionary in mesh.get_property_list():
				if not int(prop.usage) & PROPERTY_USAGE_STORAGE: continue
				if String(prop.name) in KEY_SKIP: continue
				names.append(String(prop.name))
			own_props[kind] = names
		key = [kind]
		for prop_name: String in own_props[kind]: key.append(mesh.get(prop_name))
	key.append(mesh.custom_aabb)
	key.append(mesh.resource_name)
	return key

## Shows the keeper's mesh on this node. Same class, same properties, so the same
## single surface: the node's surface override (if any) is put back as it was.
static func _repoint(visual: MeshInstance3D, keeper: Dictionary) -> void:
	var overrides: Array[Material] = []
	for surface: int in range(visual.get_surface_override_material_count()):
		overrides.append(visual.get_surface_override_material(surface))
	visual.mesh = keeper["mesh"] as PrimitiveMesh
	for surface: int in range(mini(overrides.size(), visual.get_surface_override_material_count())):
		if visual.get_surface_override_material(surface) != overrides[surface]:
			visual.set_surface_override_material(surface, overrides[surface])

# ----------------------------------------------------------------- 2. free

static func _free_hidden(park: Node3D, street: Node3D) -> Dictionary:
	var report := {"bush_mesh_nodes": 0, "bush_multimesh_nodes": 0, "bush_instances": 0, "stand_in_nodes": 0,
		"stand_ins_kept_no_collider": 0, "tris_freed": 0}
	# A saved Creator layout applied to this raid hides and shows whole roots by
	# writing every descendant's visible flag (creator_object_registry.gd
	# _apply_state): "hidden" is then not proof of "hidden for good".
	if park.get_node_or_null("CreatorLayoutLighting") != null:
		report["skipped"] = "a Creator layout is applied"
		return report
	var shrub_passes := _shrub_passes(park, street)
	var stand_ins: Array[MeshInstance3D] = []
	var bushes: Array[GeometryInstance3D] = []
	var parts: Dictionary = {}
	var leaves: Dictionary = {}
	# The same source list the clipped shrubs build (midori_clipped_shrubs.gd
	# _collect_begin): the meshes of the visuals named Bush006.
	var visuals := street.find_children("*", "MeshInstance3D", true, false)
	await Budget.checkpoint(park)
	if not is_instance_valid(street): return report
	for node: Node in visuals:
		var visual := node as MeshInstance3D
		if not is_instance_valid(visual) or visual.mesh == null or not String(visual.name).contains("Bush006"): continue
		parts[visual.mesh] = true
		if String(visual.name).contains("leaves"): leaves[visual.mesh] = true
	var geometries := street.find_children("*", "GeometryInstance3D", true, false)
	await Budget.checkpoint(park)
	for index: int in range(geometries.size()):
		if index % 256 == 255:
			await Budget.checkpoint(park)
			if not is_instance_valid(street): return report
		var geometry := geometries[index] as GeometryInstance3D
		if not is_instance_valid(geometry) or not _hidden_leaf(geometry, street): continue
		if geometry is MeshInstance3D and _base_name(geometry) in STAND_INS:
			if _has_own_collider(geometry as MeshInstance3D): stand_ins.append(geometry as MeshInstance3D)
			else: report["stand_ins_kept_no_collider"] = int(report["stand_ins_kept_no_collider"]) + 1
		elif shrub_passes >= 0 and _is_bush_source(geometry, parts, leaves):
			bushes.append(geometry)
	# The shrub passes count what they hid. More hidden Bush006 nodes than that
	# means something else hid some of them: none is freed then.
	if shrub_passes < 0:
		report["bush_skipped"] = "the clipped-shrub passes have not both finished"
		bushes.clear()
	elif bushes.size() > shrub_passes:
		report["bush_skipped"] = "%d hidden Bush006 nodes, the shrub passes hid %d" % [bushes.size(), shrub_passes]
		bushes.clear()
	report["shrub_passes_hid"] = shrub_passes
	var tris_cache: Dictionary = {}
	var done := 0
	for visual: MeshInstance3D in stand_ins:
		if not is_instance_valid(visual): continue
		report["tris_freed"] = int(report["tris_freed"]) + _tris(visual.mesh, tris_cache)
		report["stand_in_nodes"] = int(report["stand_in_nodes"]) + 1
		_drop(visual)
	for geometry: GeometryInstance3D in bushes:
		if not is_instance_valid(geometry): continue
		if geometry is MultiMeshInstance3D:
			var many: MultiMesh = (geometry as MultiMeshInstance3D).multimesh
			var count := many.visible_instance_count if many.visible_instance_count >= 0 else many.instance_count
			report["bush_multimesh_nodes"] = int(report["bush_multimesh_nodes"]) + 1
			report["bush_instances"] = int(report["bush_instances"]) + count
			report["tris_freed"] = int(report["tris_freed"]) + count * _tris(many.mesh, tris_cache)
		else:
			report["bush_mesh_nodes"] = int(report["bush_mesh_nodes"]) + 1
			report["tris_freed"] = int(report["tris_freed"]) + _tris((geometry as MeshInstance3D).mesh, tris_cache)
		_drop(geometry)
		done += 1
		if done % 64 == 63:
			await Budget.checkpoint(park)
			if not is_instance_valid(street): return report
	report["nodes_freed"] = int(report["stand_in_nodes"]) + int(report["bush_mesh_nodes"]) + int(report["bush_multimesh_nodes"])
	return report

## How many Bush006 nodes the two clipped-shrub passes hid (the street's own pass
## and the whole-park sweep of the world-complete step), or -1 while either has
## not finished: the sweep reads the Bush006 visuals this step frees.
static func _shrub_passes(park: Node3D, street: Node3D) -> int:
	if not street.has_meta("clipped_shrubs") or not park.has_meta("clipped_shrubs_after_boot"): return -1
	var own: Variant = street.get_meta("clipped_shrubs")
	var sweep: Variant = park.get_meta("clipped_shrubs_after_boot")
	if not own is Dictionary or not sweep is Dictionary: return -1
	return int((own as Dictionary).get("hidden_bush006_nodes", 0)) + int((sweep as Dictionary).get("hidden_bush006_nodes", 0))

## A leaf visual switched off by its own flag under a shown parent, that nothing
## toggles: no script, no group (midori_night_effect is switched by group), no
## children (a visual that parents a collider or socket stays), not under a body
## or a night effect. Under a hidden parent (a broken-glass group, a root hidden
## by Creator) the own flag is on, or the parent test fails: never a candidate.
static func _hidden_leaf(geometry: GeometryInstance3D, street: Node3D) -> bool:
	if geometry.visible or geometry.get_child_count() > 0 or geometry.get_script() != null or geometry.top_level: return false
	if geometry.is_queued_for_deletion() or not geometry.get_groups().is_empty() or geometry.has_meta("creator_instance_family"): return false
	var parent := geometry.get_parent() as Node3D
	if parent == null or not parent.is_visible_in_tree(): return false
	var ancestor: Node = parent
	while ancestor != null and ancestor != street:
		if ancestor is CollisionObject3D or ancestor is Light3D or ancestor.is_in_group("midori_night_effect") or ancestor.is_in_group("building_access_targets"): return false
		ancestor = ancestor.get_parent()
	return ancestor == street

## Godot renames a second child of the same name "@Name@123" (or "Name2").
static func _base_name(node: Node) -> String:
	var label := String(node.name)
	if label.begins_with("@"): label = label.substr(1).get_slice("@", 0)
	return label.rstrip("0123456789")

## street._box(..., collide = true) adds the visual and, beside it, a StaticBody3D
## at the same position (midori_south_street.gd _solid): the stand-in's collision
## and loot surface. Only a stand-in that has it is freed.
static func _has_own_collider(visual: MeshInstance3D) -> bool:
	if visual.material_override == null or visual.mesh == null: return false
	for sibling: Node in visual.get_parent().get_children():
		if sibling is StaticBody3D and (sibling as StaticBody3D).position.is_equal_approx(visual.position) and String(sibling.name).contains("Collision"): return true
	return false

## The test of midori_clipped_shrubs.gd _collect_one, on a node it has hidden.
static func _is_bush_source(geometry: GeometryInstance3D, parts: Dictionary, leaves: Dictionary) -> bool:
	var mesh: Mesh = null
	if geometry is MeshInstance3D: mesh = (geometry as MeshInstance3D).mesh
	elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null: mesh = (geometry as MultiMeshInstance3D).multimesh.mesh
	if mesh == null: return false
	if mesh.resource_name.contains("Bush006") or parts.has(mesh) or leaves.has(mesh): return true
	var look: Material = geometry.material_override
	if look == null and mesh.get_surface_count() > 0:
		look = (geometry as MeshInstance3D).get_active_material(0) if geometry is MeshInstance3D else mesh.surface_get_material(0)
	return look is BaseMaterial3D and (look as BaseMaterial3D).albedo_texture != null and (look as BaseMaterial3D).albedo_texture.resource_path.get_file() == LEAF_TEXTURE

static func _drop(node: Node) -> void:
	var parent := node.get_parent()
	if parent != null: parent.remove_child(node)
	node.queue_free()

# ------------------------------------------------------------------ counts

## Nodes, MeshInstance3D, MultiMeshInstance3D, distinct mesh resources and
## triangles (hidden nodes included, as tests/probe_world_fingerprint.gd counts).
static func _census(park: Node3D, street: Node3D) -> Dictionary:
	var row := {"nodes": 0, "mesh_instances": 0, "visible_mesh_instances": 0, "multimesh_instances": 0, "unique_meshes": 0, "unique_primitive_meshes": 0, "tris": 0}
	var meshes: Dictionary = {}
	var tris_cache: Dictionary = {}
	var stack: Array[Node] = [street]
	var seen := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if not is_instance_valid(node): continue
		for child: Node in node.get_children(): stack.append(child)
		row["nodes"] = int(row["nodes"]) + 1
		seen += 1
		if seen % 1024 == 1023:
			await Budget.checkpoint(park)
			if not is_instance_valid(street): return row
		if node is MeshInstance3D:
			var visual := node as MeshInstance3D
			row["mesh_instances"] = int(row["mesh_instances"]) + 1
			if visual.is_visible_in_tree(): row["visible_mesh_instances"] = int(row["visible_mesh_instances"]) + 1
			if visual.mesh != null:
				meshes[visual.mesh.get_instance_id()] = visual.mesh is PrimitiveMesh
				row["tris"] = int(row["tris"]) + _tris(visual.mesh, tris_cache)
		elif node is MultiMeshInstance3D:
			row["multimesh_instances"] = int(row["multimesh_instances"]) + 1
			var many: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if many != null and many.mesh != null:
				meshes[many.mesh.get_instance_id()] = many.mesh is PrimitiveMesh
				var count := many.visible_instance_count if many.visible_instance_count >= 0 else many.instance_count
				row["tris"] = int(row["tris"]) + count * _tris(many.mesh, tris_cache)
	row["unique_meshes"] = meshes.size()
	var primitives := 0
	for is_primitive: bool in meshes.values():
		if is_primitive: primitives += 1
	row["unique_primitive_meshes"] = primitives
	return row

## Triangle count without a GPU read-back: an ArrayMesh knows its lengths, a
## primitive generates its arrays on the CPU. Other mesh classes count as 0.
static func _tris(mesh: Mesh, cache: Dictionary) -> int:
	if mesh == null: return 0
	var id := mesh.get_instance_id()
	if cache.has(id): return cache[id]
	var count := 0
	if mesh is ArrayMesh:
		var array_mesh := mesh as ArrayMesh
		for surface: int in range(array_mesh.get_surface_count()):
			if array_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
			var indices := array_mesh.surface_get_array_index_len(surface)
			count += (indices if indices > 0 else array_mesh.surface_get_array_len(surface)) / 3
	elif mesh is BoxMesh and (mesh as BoxMesh).subdivide_width == 0 and (mesh as BoxMesh).subdivide_height == 0 and (mesh as BoxMesh).subdivide_depth == 0:
		count = 12
	elif mesh is PrimitiveMesh:
		var arrays: Array = (mesh as PrimitiveMesh).get_mesh_arrays()
		if arrays.size() == Mesh.ARRAY_MAX:
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var points: Variant = arrays[Mesh.ARRAY_VERTEX]
			if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty(): count = (indices as PackedInt32Array).size() / 3
			elif points is PackedVector3Array: count = (points as PackedVector3Array).size() / 3
	cache[id] = count
	return count
