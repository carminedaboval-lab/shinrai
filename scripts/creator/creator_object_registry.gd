extends RefCounted
## Creator ownership is explicit: no collider-parent guessing or scene-root deletion.
## Scan only after generators, trimming and deferred Sakura replacement finish,
## before distance partition/shadow/reflection helpers cache the original batches.

const CELL_SIZE := 8.0
const MAX_INDEX_CELLS := 256
const FORMAT_VERSION := 1
var _world: Node3D
var _records: Dictionary = {}
var _claimed: Dictionary = {}
var _cells: Dictionary = {}
var _large: Dictionary = {}
var _owned_multimeshes: Dictionary = {}
var _batch_sources: Dictionary = {}
var _report: Dictionary = {}

func scan_world(world: Node3D) -> Dictionary:
	_records.clear(); _claimed.clear(); _cells.clear(); _large.clear()
	_owned_multimeshes.clear()
	_batch_sources.clear()
	_world = world
	_report = {"ok": false, "objects": 0, "node_objects": 0, "instance_objects": 0,
		"unsupported_meshes": 0, "unsupported_batches": [], "warnings": [],
		"coverage_notes": [
			"Only explicit source-confirmed logical-object adapters are editable; structural geometry is protected.",
			"Midori2050 rest pockets merge seat LED strips and planter foliage across objects; individual seats/planters require a producer adapter.",
			"Mixed-parts iris colonies, planted-bed batches, sparse-understory batches and island moss require producer membership maps.",
			"Scan before distance chunking. Repartitioned batches require explicit ID rebinding; rescan does not recover lost provenance.",
			"After changes core refreshes navigation, near-plant shadow proxies, reflection content and any source-specific cached positions."
		]}
	if not is_instance_valid(world) or not world.is_inside_tree():
		_report.warnings.append("World must be inside the scene tree.")
		return _report.duplicate(true)
	var nodes := _walk(world)
	for node: Node in nodes:
		if not node is Node3D or node == world or _claimed.has(node): continue
		var recipe := _node_recipe(node)
		if recipe.is_empty(): continue
		var members: Array[Node3D] = [node as Node3D]
		var valid := true
		for sibling_name: String in recipe.get("siblings", []):
			var sibling := node.get_parent().get_node_or_null(NodePath(sibling_name)) as Node3D
			if sibling == null:
				_report.warnings.append("Missing required member %s beside %s; object protected." % [sibling_name, world.get_path_to(node)])
				valid = false; break
			members.append(sibling)
		if valid and node.is_visible_in_tree():
			var stable_path := str(world.get_path_to(node))
			if recipe.has("stable_leaf"): stable_path = str(world.get_path_to(node.get_parent())).path_join(str(recipe.stable_leaf))
			_register_nodes("original:" + stable_path, str(recipe.name), members, false, "", str(recipe.adapter))
	for node: Node in nodes:
		if not node is MultiMeshInstance3D or _claimed.has(node): continue
		var batch := node as MultiMeshInstance3D
		if not batch.is_visible_in_tree() or batch.multimesh == null: continue
		if batch.multimesh.transform_format != MultiMesh.TRANSFORM_3D or batch.multimesh.mesh == null: continue
		var batch_name := str(batch.name)
		if _has_ancestor(batch, "MidoriGrassDetail") and (batch_name == "MeshyGroundClumps" or batch_name.begins_with("UprightGrass_") or batch_name.begins_with("ThinUprightGrass_")):
			_register_batch_family(batch, [], "Grass Tuft", "grass_single")
		elif _has_ancestor(batch, "MidoriGrassDetail") and batch_name.begins_with("JapaneseForestGrassDrift_"):
			var suffix := batch_name.trim_prefix("JapaneseForestGrassDrift_")
			var companions: Array[MultiMeshInstance3D] = []
			for prefix: String in ["ForestGrassLOD1_", "ForestGrassLOD2_"]:
				var companion := batch.get_parent().get_node_or_null(NodePath(prefix + suffix)) as MultiMeshInstance3D
				if companion != null: companions.append(companion)
			if companions.size() == 2:
				_register_batch_family(batch, companions, "Japanese Forest Grass", "forest_grass_three_lods")
			else: _report.warnings.append("Forest grass LOD members missing: " + str(world.get_path_to(batch)))
		elif batch.has_meta("creator_instance_family"):
			# Explicit opt-in for reviewed producer adapters and isolated fixtures.
			# Producer guarantees each instance is one complete object.
			_register_batch_family(batch, [], str(batch.get_meta("creator_display_name", "Plant")), "explicit_instance_family")
	for node: Node in nodes:
		if _claimed.has(node): continue
		if node is MultiMeshInstance3D and node.multimesh != null and node.is_visible_in_tree():
			_report.unsupported_batches.append({"path": str(world.get_path_to(node)), "instances": node.multimesh.instance_count,
				"reason": "No complete logical membership adapter; protected."})
		elif node is MeshInstance3D and node.is_visible_in_tree():
			_report.unsupported_meshes += 1
	_report.objects = _records.size()
	_report.ok = true
	return _report.duplicate(true)

func get_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _records: result.append(_public_record(_records[id]))
	return result

func get_record(object_id: String) -> Dictionary:
	return _public_record(_records[object_id]) if _records.has(object_id) else {}

func get_coverage() -> Dictionary:
	return _report.duplicate(true)

func ray_pick(origin: Vector3, direction: Vector3, max_distance: float, excluded_ids: Array[String] = []) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(max_distance) or max_distance <= 0: return {}
	var ray := direction.normalized()
	var end := origin + ray * minf(max_distance, 10000.0)
	var candidates: Dictionary = _large.duplicate()
	var first := _cell(Vector3(minf(origin.x,end.x),0,minf(origin.z,end.z)))
	var last := _cell(Vector3(maxf(origin.x,end.x),0,maxf(origin.z,end.z)))
	# Typical creator reach visits only a few X/Z bins, not every grass instance.
	for z: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			for id: String in _cells.get(Vector2i(x,z), {}): candidates[id] = true
	var best: Dictionary = {}
	var nearest := max_distance
	for id: String in candidates:
		if id in excluded_ids or not _records.has(id): continue
		var row: Dictionary = _records[id]
		if not row.visible or row.held or not _record_alive(row): continue
		var distance := _ray_aabb(origin, ray, row.bounds, nearest)
		if distance < 0: continue
		# Oriented per-mesh bounds narrow the broadphase without adding gameplay colliders.
		var hit := _ray_parts(row, origin, ray, nearest)
		if hit >= 0 and (best.is_empty() or hit < nearest):
			nearest = hit
			best = {"id": id, "name": row.name, "distance": hit, "position": origin + ray * hit}
	return best

func set_transform(object_id: String, value: Transform3D) -> bool:
	if not _records.has(object_id) or not _valid_transform(value): return false
	var row: Dictionary = _records[object_id]
	if not _record_alive(row): return false
	if (row.transform as Transform3D).is_equal_approx(value): return true
	_unindex(row)
	row.transform = value
	for member: Dictionary in row.node_members:
		var node: Node3D = member.node
		if is_instance_valid(node): node.global_transform = value * member.offset
	_write_instances(row)
	_update_bounds(row)
	_index(row)
	return true

func set_visible(object_id: String, visible: bool) -> bool:
	if not _records.has(object_id): return false
	var row: Dictionary = _records[object_id]
	if not _record_alive(row): return false
	if row.visible == visible: return true
	_capture_before_suppression(row)
	row.visible = visible
	_apply_state(row)
	return true

func register_added(node: Node3D, asset_id: String, object_id: String) -> String:
	if not is_instance_valid(_world) or not is_instance_valid(node) or not node.is_inside_tree() or not _world.is_ancestor_of(node): return ""
	if object_id.is_empty() or object_id.begins_with("original:") or _records.has(object_id) or asset_id.is_empty(): return ""
	var members: Array[Node3D] = [node]
	return _register_nodes(object_id, str(node.get_meta("creator_display_name", _friendly(str(node.name)))), members, true, asset_id, "catalog_addition")

func unregister_added(object_id: String) -> bool:
	if not _records.has(object_id) or not _records[object_id].added: return false
	var row: Dictionary = _records[object_id]
	# Core owns reversible history data. Cancelling an added preview really removes
	# its complete root, so no invisible orphan is left after reload or undo.
	_unindex(row)
	for state: Dictionary in row.states:
		if is_instance_valid(state.node): _claimed.erase(state.node)
	for member: Node3D in row.members:
		if not is_instance_valid(member): continue
		if member.get_parent() != null: member.get_parent().remove_child(member)
		member.queue_free()
	_records.erase(object_id)
	return true

func get_bounds(object_id: String) -> AABB:
	return _records[object_id].bounds if _records.has(object_id) else AABB()

func get_local_bounds(object_id: String) -> AABB:
	if not _records.has(object_id): return AABB()
	var bounds := AABB()
	var first := true
	for part: Dictionary in _records[object_id].parts:
		var box: AABB = part.offset * part.bounds
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

func get_excluded_rids(object_id: String) -> Array[RID]:
	var result: Array[RID] = []
	if not _records.has(object_id): return result
	for state: Dictionary in _records[object_id].states:
		if is_instance_valid(state.node) and state.node is CollisionObject3D: result.append(state.node.get_rid())
	return result

func set_held(object_id: String, held: bool) -> bool:
	if not _records.has(object_id): return false
	var row: Dictionary = _records[object_id]
	if not _record_alive(row) or (held and not row.visible): return false
	if row.held == held: return true
	_capture_before_suppression(row)
	if held:
		row.held_transform = row.transform
		row.held_visible = row.visible
	row.held = held
	_apply_state(row)
	return true

func sync_night_effects(is_night: bool) -> void:
	# The park toggles this group globally. Reconcile authored night visibility
	# with creator removal/holding, without changing non-night authored flags,
	# processing, collisions, or any unrelated object visibility.
	for id: String in _records:
		var row: Dictionary = _records[id]
		for state: Dictionary in row.states:
			var node: Node = state.node
			if not is_instance_valid(node) or not node is Node3D or not node.is_in_group("midori_night_effect"): continue
			state.visible = is_night
			node.visible = is_night and bool(row.visible) and not bool(row.held)

func export_overrides() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _records:
		var row: Dictionary = _records[id]
		if row.added: continue
		# Uncommitted held poses never leak into persistence, even if caller errs.
		var transform_value: Transform3D = row.held_transform if row.held else row.transform
		var visible: bool = row.held_visible if row.held else row.visible
		if not transform_value.is_equal_approx(row.original_transform) or visible != row.original_visible:
			result.append({"id": id, "transform": _encode(transform_value), "visible": visible})
	return result

func apply_overrides(overrides: Array) -> Dictionary:
	var errors: Array[String] = []
	var missing: Array[String] = []
	var validated: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value: Variant in overrides:
		if not value is Dictionary or not value.get("id") is String or not value.get("visible") is bool or not value.get("transform") is Array:
			errors.append("Invalid override record."); continue
		var id: String = value.id
		if seen.has(id): errors.append("Duplicate override: " + id); continue
		seen[id] = true
		if not _records.has(id): missing.append(id); continue
		if _records[id].added or _records[id].held or not _record_alive(_records[id]):
			errors.append("Override target unavailable or uncommitted: " + id); continue
		var decoded := _decode(value.transform)
		if decoded.is_empty(): errors.append("Invalid transform: " + id); continue
		validated.append({"id": id, "transform": decoded.value, "visible": value.visible})
	# Validation is atomic; missing or malformed identities do not partly change a world.
	if not errors.is_empty() or not missing.is_empty():
		return {"ok": false, "error": "; ".join(errors) + (" Missing object IDs: " + ", ".join(missing) if not missing.is_empty() else ""), "applied": 0, "errors": errors, "missing_ids": missing}
	for value: Dictionary in validated:
		set_transform(value.id, value.transform)
		set_visible(value.id, value.visible)
	return {"ok": true, "error": "", "applied": validated.size(), "errors": [], "missing_ids": []}

func _node_recipe(node: Node3D) -> Dictionary:
	if node.has_meta("creator_protected"): return {}
	if node.get_meta("creator_editable", false):
		return {"name": str(node.get_meta("creator_display_name", _friendly(str(node.name)))), "adapter": "explicit_producer_root"}
	var label := str(node.name)
	var parent := str(node.get_parent().name) if node.get_parent() != null else ""
	var suffix := label.get_slice("_", label.get_slice_count("_") - 1)
	if parent == "ParkBenches_6_TwoVariations" and (label.begins_with("NeonParkBench_") or label.begins_with("FuturisticEcoBench_")):
		return {"name": "Eco Park Bench" if label.begins_with("Futuristic") else "Neon Park Bench", "siblings": ["ParkBenchCollision_" + suffix], "adapter": "park_bench_sibling"}
	if parent == "LandmarkPlazaFurniture_3Benches_4PathLamps" and label.begins_with("PlazaBench_"):
		return {"name": "Plaza Bench", "siblings": ["PlazaBenchCollision_" + suffix], "adapter": "plaza_bench_sibling"}
	if parent.begins_with("HandPlacedSakuraAccentTrees_"):
		if node.has_meta("midori_jogoss_sakura"):
			# SakuraSwap adds the replacement before freeing its old same-name sibling;
			# Godot may rename it. Derive exact identity from the authored cylinder:
			# body.position = tree.position + UP * (cylinder.height / 2), not proximity.
			var matches: Array[String] = []
			for sibling: Node in node.get_parent().get_children():
				if not sibling is StaticBody3D or not str(sibling.name).begins_with("DenseSakuraCollision_"): continue
				for child: Node in sibling.get_children():
					if child is CollisionShape3D and child.shape is CylinderShape3D:
						var authored: Vector3 = sibling.position - Vector3.UP * child.shape.height * .5
						if authored.is_equal_approx(node.position): matches.append(str(sibling.name))
			if matches.size() == 1:
				return {"name": "Sakura Tree", "siblings": matches, "stable_leaf": matches[0].replace("DenseSakuraCollision_", "DenseSakura_"), "adapter": "swapped_sakura_exact_cylinder_anchor"}
			return {}
		if label.begins_with("DenseSakura_"):
			return {"name": "Sakura Tree", "siblings": ["DenseSakuraCollision_" + suffix], "adapter": "sakura_sibling"}
	if parent == "JapaneseMapleAccents_1Of2" and label == "Free3DJapaneseMaple_01":
		return {"name": "Japanese Maple", "siblings": ["JapaneseMapleCollision_01"], "adapter": "maple_sibling"}
	if parent == "MainlandDeadwood_7Logs_5Stumps_1Hollow":
		if label.begins_with("FallenBeechLog_"):
			return {"name": "Fallen Beech Log", "siblings": ["FallenLogCollision_" + suffix] if (int(suffix) - 1) % 2 == 0 else [], "adapter": "deadwood_log_sibling"}
		if label.begins_with("BeechStump_"):
			return {"name": "Beech Stump", "siblings": ["StumpCollision_" + suffix] if int(suffix) in [1,2,4] else [], "adapter": "deadwood_stump_sibling"}
		if label == "HeavyHollowBark_01": return {"name": "Hollow Bark", "siblings": ["HeavyHollowBarkCollision_01"], "adapter": "deadwood_hollow_sibling"}
	if parent in ["EmeraldHaloPathLamps_10", "LandmarkPlazaFurniture_3Benches_4PathLamps"] and (label.begins_with("EmeraldHaloLamp_") or label.begins_with("PlazaHaloLamp_")):
		var index := int(suffix) + (10 if label.begins_with("Plaza") else 0)
		var collision := ("PlazaHaloLampCollision_" if label.begins_with("Plaza") else "HaloLampCollision_") + suffix
		return {"name": "Halo Path Lamp", "siblings": [collision, "BlueHaloArea_%02d" % index, "BlueSlitPathLine_%02d" % index, "BlueSlitProjection_%02d" % index], "adapter": "halo_lamp_five_members"}
	if label == "PlazaArrivalLampPerimeter" and parent == "Midori2050Identity": return {"name": "Arrival Halo Lamp", "adapter": "relocated_halo_complete_root"}
	if parent == "MidoriParkProps" and label in ["PlazaNeonVending", "PlazaRecyclingStation", "PlazaDrinkingFountain", "LeftBehindTakeawayCup", "PlazaBicycleRack", "MainInformationBoard"]:
		return {"name": {"PlazaNeonVending":"Vending Machine", "PlazaRecyclingStation":"Recycling Station", "PlazaDrinkingFountain":"Drinking Fountain", "LeftBehindTakeawayCup":"Takeaway Cup", "PlazaBicycleRack":"Bicycle Rack", "MainInformationBoard":"Information Board"}[label], "adapter": "measured_prop_root"}
	if parent == "MidoriClubhouseCafeteria" and (label in ["IndoorCafeTable", "CafeVending", "ShelteredWaitingBench", "DrinkingFountain", "CafeRecycling", "TerraceTableWest", "TerraceTableEast", "RecentlyUsedCup", "PublicToiletFixture", "PublicWashbasinFixture"] or node.has_meta("sports_furniture")):
		return {"name": _friendly(label), "adapter": "cafe_fixture_root"}
	if (parent == "MidoriJapanesePathLamps" and label.begins_with("JapanesePathLamp_")) or (parent == "MidoriSecondaryPathLamps" and label.begins_with("SecondaryBollard_")):
		return {"name": "Japanese Path Lamp" if parent == "MidoriJapanesePathLamps" else "Path Bollard", "adapter": "measured_lamp_root"}
	if parent == "MidoriStoneLanterns" and label in ["LakesideGarden", "WoodedGarden", "NorthernIrisEdge", "NorthWoodlandTurn"]:
		return {"name": "Stone Lantern", "adapter": "stone_lantern_root"}
	if _has_ancestor(node, "MeasuredEntranceBollards") and label in ["WestMeasuredBollard", "EastMeasuredBollard"]:
		return {"name": "Entrance Bollard", "adapter": "entrance_bollard_root"}
	if parent == "OpenLawnBoulderCover" and label.begins_with("OpenBoulder_"): return {"name": "Mossy Boulder", "adapter": "boulder_root"}
	if parent == "MidoriSparseVegetation" and label.begins_with("SparseGapTree_"): return {"name": "Woodland Tree", "adapter": "sparse_tree_root"}
	if parent == "MidoriIslandNature" and (label.begins_with("IslandStone_") or label.begins_with("IslandFloor_") or label.begins_with("MainlandStoneCover_")):
		return {"name": "Garden Rock" if not label.begins_with("IslandFloor_") else "Island Plant", "adapter": "island_nature_root"}
	if _has_ancestor(node, "MidoriGardenSpots") and (label.begins_with("GardenStone_") or label.begins_with("GardenFloor_")):
		return {"name": "Garden Stone" if label.begins_with("GardenStone_") else "Garden Plant", "adapter": "garden_spot_root"}
	if parent == "WoodlandFallenWoodFragments" and label.begins_with("FallenWoodFragment_"): return {"name": "Fallen Wood", "adapter": "decorative_wood_root"}
	if parent == "MainlandMidnightFernPockets" and label.begins_with("MidnightFern_"): return {"name": "Midnight Fern", "adapter": "fern_root"}
	if parent == "MainlandEmeraldGrassClusters" and label.begins_with("EmeraldFountainGrass_"): return {"name": "Fountain Grass", "adapter": "fountain_grass_root"}
	# Reference prototypes include their complete imported descendants; no sibling
	# colliders are authored by _add_reference_plant (source lines 1865-1892).
	if parent in ["ArtworkReferenceCanopy", "ArtworkLilacUnderstory", "MainlandForestFloorBushPockets", "MainlandDenseGrassPatches", "OpenBoulderNativeFringe"]:
		for prefix: String in ["ReferenceBroadleaf_", "ReferencePine_", "MicroGrove", "MainlandPineSapling", "ReferenceLilacMass", "MixedTreeGapBush", "ForestFloorBush", "MainlandGroundcover", "BoulderFringe"]:
			if label.begins_with(prefix): return {"name": _friendly(label), "adapter": "reference_plant_root"}
	return {}

func _register_nodes(id: String, label: String, roots: Array[Node3D], added: bool, asset_id: String, adapter: String) -> String:
	if roots.is_empty() or _records.has(id): return ""
	var anchor := roots[0].global_transform
	if not _valid_transform(anchor): return ""
	var all: Array[Node] = []
	var root_members: Array[Dictionary] = []
	for root: Node3D in roots:
		if _claimed.has(root): return ""
		root_members.append({"node": root, "offset": anchor.affine_inverse() * root.global_transform})
		for node: Node in _walk(root):
			if _claimed.has(node): return ""
			all.append(node)
			if node != root and node is Node3D and node.top_level:
				root_members.append({"node": node, "offset": anchor.affine_inverse() * node.global_transform})
	var states: Array[Dictionary] = []
	var parts: Array[Dictionary] = []
	for node: Node in all:
		_claimed[node] = id
		states.append(_state(node))
		if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
			parts.append({"bounds": node.get_aabb(), "offset": anchor.affine_inverse() * node.global_transform})
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.is_visible_in_tree():
			parts.append({"bounds": node.multimesh.get_aabb(), "offset": anchor.affine_inverse() * node.global_transform})
	if parts.is_empty():
		for node: Node in all: _claimed.erase(node)
		return ""
	var row := _new_row(id, label, anchor, added, asset_id, adapter)
	row.members = roots
	row.node_members = root_members
	row.states = states
	row.parts = parts
	_records[id] = row
	_update_bounds(row); _index(row)
	_report.node_objects = int(_report.get("node_objects", 0)) + 1
	return id

func _register_batch_family(primary: MultiMeshInstance3D, companions: Array[MultiMeshInstance3D], label: String, adapter: String) -> void:
	var batches: Array[MultiMeshInstance3D] = [primary]
	batches.append_array(companions)
	var mm := primary.multimesh
	var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
	# Source-defined forest LOD families have identical original indices/transforms.
	# If trimming changed that invariant, refuse instead of affecting neighbours.
	for batch: MultiMeshInstance3D in companions:
		var other := batch.multimesh
		if other == null or other.transform_format != MultiMesh.TRANSFORM_3D or other.mesh == null or other.instance_count != mm.instance_count or other.visible_instance_count != mm.visible_instance_count:
			_report.warnings.append("LOD instance count drift; family protected: " + str(_world.get_path_to(primary))); return
		for i: int in count:
			if not (batch.global_transform * other.get_instance_transform(i)).is_equal_approx(primary.global_transform * mm.get_instance_transform(i)):
				_report.warnings.append("LOD transform drift; family protected: " + str(_world.get_path_to(primary))); return
	for index: int in count:
		var transform_value := primary.global_transform * mm.get_instance_transform(index)
		if not _valid_transform(transform_value): continue
		var id := "original:" + str(_world.get_path_to(primary)) + "#instance:%d" % index
		var row := _new_row(id, label, transform_value, false, "", adapter)
		for batch: MultiMeshInstance3D in batches:
			var world_transform := batch.global_transform * batch.multimesh.get_instance_transform(index)
			var offset := transform_value.affine_inverse() * world_transform
			row.instance_members.append({"node": batch, "index": index, "offset": offset})
			row.parts.append({"bounds": batch.multimesh.mesh.get_aabb(), "offset": offset})
		_records[id] = row
		_update_bounds(row); _index(row)
		_report.instance_objects += 1
	for batch: MultiMeshInstance3D in batches:
		_claimed[batch] = "instance_family"
		_batch_sources[batch] = batch.multimesh

func _new_row(id: String, label: String, transform_value: Transform3D, added: bool, asset_id: String, adapter: String) -> Dictionary:
	return {"id": id, "name": label, "transform": transform_value, "original_transform": transform_value,
		"visible": true, "original_visible": true, "added": added, "asset_id": asset_id,
		"members": [], "node_members": [], "instance_members": [], "states": [], "parts": [],
		"held": false, "held_transform": transform_value, "held_visible": true,
		"adapter": adapter, "bounds": AABB(), "index_cells": []}

func _state(node: Node) -> Dictionary:
	var result := {"node": node, "process_mode": node.process_mode}
	if node is Node3D: result.visible = node.visible
	if node is CollisionObject3D:
		result.layer = node.collision_layer; result.mask = node.collision_mask
	if node is CollisionShape3D or node is CollisionPolygon3D: result.disabled = node.disabled
	if node is GPUParticles3D or node is CPUParticles3D: result.emitting = node.emitting
	return result

func _capture_before_suppression(row: Dictionary) -> void:
	if not row.visible or row.held: return
	for index: int in row.states.size():
		var node: Node = row.states[index].node
		if is_instance_valid(node): row.states[index] = _state(node)

func _apply_state(row: Dictionary) -> void:
	var suppress: bool = not row.visible or row.held
	for state: Dictionary in row.states:
		var node: Node = state.node
		if not is_instance_valid(node): continue
		node.process_mode = Node.PROCESS_MODE_DISABLED if suppress else state.process_mode
		if node is Node3D:
			node.visible = bool(state.visible) and row.visible and not (row.held and node is Light3D)
		if node is CollisionObject3D:
			node.collision_layer = 0 if suppress else int(state.layer)
			node.collision_mask = 0 if suppress else int(state.mask)
		if node is CollisionShape3D or node is CollisionPolygon3D:
			node.set_deferred("disabled", true if suppress else bool(state.disabled))
		if node is GPUParticles3D or node is CPUParticles3D:
			node.emitting = false if suppress else bool(state.emitting)
	_write_instances(row)

func _write_instances(row: Dictionary) -> void:
	for member: Dictionary in row.instance_members:
		var batch: MultiMeshInstance3D = member.node
		if not is_instance_valid(batch) or batch.multimesh == null: continue
		if not _owned_multimeshes.has(batch):
			batch.multimesh = _clone_multimesh(batch.multimesh)
			# Old custom bounds would cull an edited instance moved outside its cell.
			batch.multimesh.custom_aabb = AABB()
			_owned_multimeshes[batch] = true
			_batch_sources[batch] = batch.multimesh
		var value: Transform3D = batch.global_transform.affine_inverse() * row.transform * member.offset
		if not row.visible: value.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		batch.multimesh.set_instance_transform(int(member.index), value)

func _clone_multimesh(source: MultiMesh) -> MultiMesh:
	# Resource.duplicate can copy the buffer before format/count are established.
	var result := MultiMesh.new()
	result.transform_format = source.transform_format
	result.use_colors = source.use_colors
	result.use_custom_data = source.use_custom_data
	result.mesh = source.mesh
	result.instance_count = source.instance_count
	for index: int in source.instance_count:
		result.set_instance_transform(index, source.get_instance_transform(index))
		if source.use_colors: result.set_instance_color(index, source.get_instance_color(index))
		if source.use_custom_data: result.set_instance_custom_data(index, source.get_instance_custom_data(index))
	result.visible_instance_count = source.visible_instance_count
	return result

func _record_alive(row: Dictionary) -> bool:
	for member: Dictionary in row.node_members:
		if not is_instance_valid(member.node) or not member.node.is_inside_tree() or member.node.is_queued_for_deletion(): return false
	for member: Dictionary in row.instance_members:
		if not is_instance_valid(member.node) or not member.node.is_inside_tree() or member.node.is_queued_for_deletion() or member.node.multimesh == null or member.node.multimesh != _batch_sources.get(member.node) or int(member.index) >= member.node.multimesh.instance_count: return false
	return true

func _public_record(row: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["id", "name", "transform", "original_transform", "visible", "original_visible", "added", "asset_id", "held", "adapter", "bounds"]: result[key] = row[key]
	result.members = row.members.duplicate()
	result.instance_members = row.instance_members.duplicate(true)
	result.editable = true
	return result

func _update_bounds(row: Dictionary) -> void:
	var first := true
	var bounds := AABB()
	for part: Dictionary in row.parts:
		var box: AABB = (row.transform * part.offset) * part.bounds
		bounds = box if first else bounds.merge(box)
		first = false
	row.bounds = bounds

func _index(row: Dictionary) -> void:
	var bounds: AABB = row.bounds
	var first := _cell(bounds.position)
	var last := _cell(bounds.end)
	var cells: Array[Vector2i] = []
	if (last.x - first.x + 1) * (last.y - first.y + 1) > MAX_INDEX_CELLS:
		_large[row.id] = true
	else:
		for z: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var key := Vector2i(x,z)
				if not _cells.has(key): _cells[key] = {}
				_cells[key][row.id] = true
				cells.append(key)
	row.index_cells = cells

func _unindex(row: Dictionary) -> void:
	_large.erase(row.id)
	for key: Vector2i in row.index_cells:
		if _cells.has(key):
			_cells[key].erase(row.id)
			if _cells[key].is_empty(): _cells.erase(key)

func _ray_parts(row: Dictionary, origin: Vector3, direction: Vector3, limit: float) -> float:
	var nearest := limit
	var found := false
	for part: Dictionary in row.parts:
		var transform_value: Transform3D = row.transform * part.offset
		var inverse := transform_value.affine_inverse()
		# Do not normalize local direction: the slab parameter remains world metres.
		var distance := _ray_aabb(inverse * origin, inverse.basis * direction, part.bounds, nearest)
		if distance >= 0 and (not found or distance < nearest): nearest = distance; found = true
	return nearest if found else -1.0

func _ray_aabb(origin: Vector3, direction: Vector3, bounds: AABB, limit: float) -> float:
	var near_value := 0.0
	var far_value := limit
	for axis: int in 3:
		if absf(direction[axis]) < 0.0000001:
			if origin[axis] < bounds.position[axis] or origin[axis] > bounds.end[axis]: return -1.0
		else:
			var a := (bounds.position[axis] - origin[axis]) / direction[axis]
			var b := (bounds.end[axis] - origin[axis]) / direction[axis]
			near_value = maxf(near_value, minf(a,b))
			far_value = minf(far_value, maxf(a,b))
			if near_value > far_value: return -1.0
	return near_value

func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.z / CELL_SIZE))

func _walk(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if not is_instance_valid(current) or current.is_queued_for_deletion(): continue
		result.append(current)
		var children := current.get_children()
		for index: int in range(children.size() - 1, -1, -1): pending.append(children[index])
	return result

func _has_ancestor(node: Node, label: String) -> bool:
	var cursor := node.get_parent()
	while cursor != null and cursor != _world:
		if str(cursor.name) == label: return true
		cursor = cursor.get_parent()
	return false

func _friendly(value: String) -> String:
	var expression := RegEx.new()
	expression.compile("([a-z])([A-Z])")
	return expression.sub(value, "$1 $2", true).replace("_", " ").strip_edges()

func _valid_transform(value: Transform3D) -> bool:
	if not value.origin.is_finite() or not value.basis.x.is_finite() or not value.basis.y.is_finite() or not value.basis.z.is_finite(): return false
	var determinant := value.basis.determinant()
	return is_finite(determinant) and absf(determinant) > 0.000000000001 and value.origin.length() < 1000000.0

func _encode(value: Transform3D) -> Array:
	return [value.basis.x.x,value.basis.x.y,value.basis.x.z,value.basis.y.x,value.basis.y.y,value.basis.y.z,value.basis.z.x,value.basis.z.y,value.basis.z.z,value.origin.x,value.origin.y,value.origin.z]

func _decode(value: Array) -> Dictionary:
	if value.size() != 12: return {}
	for number: Variant in value:
		if not (number is float or number is int) or not is_finite(float(number)): return {}
	var result := Transform3D(Basis(Vector3(value[0],value[1],value[2]),Vector3(value[3],value[4],value[5]),Vector3(value[6],value[7],value[8])),Vector3(value[9],value[10],value[11]))
	return {"value": result} if _valid_transform(result) else {}
