extends RefCounted
## Boot integration only. Geometry/material/range policy belongs to the renderer.
const RESULT_META := &"midori_distance_boot"
const DETAIL_PATH := "res://scripts/midori_distance_detail.gd"
const WAIT_LIMIT_MS := 120000
const COMPLETE_NODES := [
	"MidoriTerrain", "MidoriJapaneseFlowers", "MidoriIslandNature",
	"MidoriGardenSpots", "MidoriSparseVegetation", "MidoriAmbientLife",
	"MidoriStoneLanterns", "MidoriJapanesePathLamps", "MidoriSecondaryPathLamps",
]
const COMPLETE_PARK_META := [
	"understory_placement", "woodland_companions", "woodland_diversity",
]

static func pending_producers(park: Node3D) -> Array[String]:
	var pending: Array[String] = []
	# Optional bounded exterior producer must finish before caches/layout scanning.
	var street := park.get_node_or_null("MidoriSouthStreet")
	if street != null and street.get("installed") != true: pending.append("MidoriSouthStreet")
	# Civic fixtures must exist before geometry caches and Creator scanning.
	var civic := park.get_node_or_null("MidoriCivicLighting")
	if civic != null and civic.get("installed") != true: pending.append("MidoriCivicLighting")
	var grass := park.get_tree().root.get_node_or_null("MidoriGrassDetail")
	# The autoload sets this only after all synchronous grass batches are built.
	if grass == null or int(grass.get("_installed_scene_id")) != park.get_instance_id():
		pending.append("MidoriGrassDetail scene completion")
	for name: String in COMPLETE_NODES:
		var node := park.get_node_or_null(NodePath(name))
		if node == null or node.get("installed") != true:
			pending.append(name)
	for key: String in COMPLETE_PARK_META:
		if not park.has_meta(key): pending.append(key)
	var paths := park.get_node_or_null("MidoriDesirePaths")
	if paths == null or paths.get("finished") != true or paths.get("installed") != true:
		pending.append("MidoriDesirePaths completed successfully")
	var beds := park.get_node_or_null("MidoriPlantedBeds")
	if beds == null or not beds.has_meta("reference_pond_report"):
		pending.append("MidoriPlantedBeds pond completion")
	var cafe := park.get_node_or_null("MidoriClubhouseCafeteria")
	if cafe == null or cafe.get("_grass_clear_done") != true:
		pending.append("MidoriClubhouseCafeteria final grass clearance")
	return pending

static func install_before_hq(park: Node3D) -> Dictionary:
	if not is_instance_valid(park) or not park.is_inside_tree():
		return {"error": "Park is unavailable", "status": "native_fallback"}
	if park.has_meta(RESULT_META): return park.get_meta(RESULT_META)
	var tree := park.get_tree()
	var started := Time.get_ticks_msec()
	while true:
		if not is_instance_valid(park) or park.is_queued_for_deletion() or not park.is_inside_tree():
			return {"error": "Park closed before detail preparation", "status": "cancelled"}
		# Concurrent callers that were waiting reuse the first completed result.
		if park.has_meta(RESULT_META): return park.get_meta(RESULT_META)
		var pending := pending_producers(park)
		if pending.is_empty(): break
		var paths := park.get_node_or_null("MidoriDesirePaths")
		if paths != null and paths.get("finished") == true and paths.get("installed") != true:
			return _fallback(park, "Path preparation failed; original planting retained", pending)
		if Time.get_ticks_msec() - started >= WAIT_LIMIT_MS:
			return _fallback(park, "Planting completion timed out; original planting retained", pending)
		await tree.process_frame
	# Preparation yields; the renderer publishes its validated replacement atomically.
	if park.has_meta("midori_distance_detail"):
		var existing: Dictionary = park.get_meta("midori_distance_detail").duplicate()
		existing["status"] = "reused"
		existing["before_hq"] = true
		park.set_meta(RESULT_META, existing)
		return existing
	if not ResourceLoader.exists(DETAIL_PATH):
		return _fallback(park, "Distance helper unavailable; original planting retained", [])
	var detail: Script = load(DETAIL_PATH)
	if detail == null:
		return _fallback(park, "Distance helper invalid; original planting retained", [])
	# Reserve preparation before yielding so another caller cannot duplicate the partition.
	if park.get_meta("shinrai_distance_preparing",false):
		while not park.has_meta(RESULT_META): await tree.process_frame
		return park.get_meta(RESULT_META)
	park.set_meta("shinrai_distance_preparing",true)
	var ready_at := Time.get_ticks_msec()
	var result: Dictionary = await detail.install(park, "distance")
	result["boot_wait_ms"] = ready_at - started
	result["partition_ms"] = Time.get_ticks_msec() - ready_at
	result["before_hq"] = true
	result["status"] = "native_fallback" if result.has("error") else "installed"
	# The park's Bush006 shrubs (copied detail cells and the azalea bases under
	# the Japanese flower beds) become clipped shrubs, as round the homes.
	var shrubs: Script = load("res://scripts/midori_clipped_shrubs.gd")
	for owner_name: String in ["MidoriDistanceDetail", "MidoriJapaneseFlowers"]:
		var owner := park.get_node_or_null(owner_name) as Node3D
		if owner != null: result["clipped_shrubs_" + owner_name] = shrubs.apply(owner)
	shrubs.apply_after_boot(park)
	load("res://scripts/midori_worn_paths.gd").install(park)
	park.set_meta(RESULT_META, result)
	return result

static func _fallback(park: Node3D, message: String, pending: Array) -> Dictionary:
	var result: Dictionary = {"error": message, "pending_producers": pending, "status": "native_fallback", "before_hq": true}
	park.set_meta(RESULT_META, result)
	return result
