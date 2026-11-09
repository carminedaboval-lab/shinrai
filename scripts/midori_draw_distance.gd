extends RefCounted
## Gives small and medium scenery a draw distance when it has none, so the
## park stops issuing tens of thousands of draws for detail too far to see.
## Measured at the west grove: 48.6k -> 9.7k draws, 7 -> 16 FPS.

const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
# World-space AABB diagonal (m) -> draw distance (m).
const TIERS := [[.6, 45.0], [1.5, 70.0], [4.0, 140.0]]
# Lights read from afar at night; actors and held items must never vanish.
const KEEP := ["lamp", "lantern", "light", "neon", "hologram", "police", "drone", "scav", "enemy", "player", "viewmodel", "k17"]
# Buildings are assembled from many medium pieces, so theirs reach further to
# keep silhouettes whole. Exempting them entirely cost 15 FPS at the grove.
const ARCHITECTURE := ["building", "tower", "parcel", "district", "house", "residence", "townhouse", "shop", "cafeteria", "clubhouse", "station", "garage", "bridge"]
const ARCHITECTURE_MEDIUM_RANGE := 220.0

static func apply(park: Node3D) -> Dictionary:
	var changed := 0
	var scanned := 0
	# Geometry the world-complete step added (biomes, clipped shrubs) is left as
	# built: it never had a range when this pass ran before it (extraction_run.gd).
	var before: Dictionary = park.get_meta(&"shinrai_render_budget_before", {})
	var visited := 0
	var keep_memo := {}
	var architecture_memo := {}
	for node: Node in park.find_children("*", "GeometryInstance3D", true, false):
		visited += 1
		if visited % 512 == 0: await LoadingBudget.checkpoint(park)
		if not is_instance_valid(node): continue
		if not before.is_empty() and not before.has(node.get_instance_id()): continue
		scanned += 1
		var geometry := node as GeometryInstance3D
		# Far-LOD stand-ins (range begin) and HLOD children already manage themselves.
		if geometry.visibility_range_begin > 0.0 or geometry.visibility_parent != NodePath(): continue
		# Tier from the bounds it had before that step (thinning shrinks MultiMesh bounds).
		var limit := _limit_for(float(before[node.get_instance_id()][1])) if not before.is_empty() else _limit(geometry)
		if limit <= 0.0: continue
		if geometry.visibility_range_end > 0.0 and geometry.visibility_range_end <= limit: continue
		if _kept(geometry, park, KEEP, keep_memo): continue
		if limit >= float(TIERS[-1][1]) and _kept(geometry, park, ARCHITECTURE, architecture_memo):
			limit = ARCHITECTURE_MEDIUM_RANGE
			if geometry.visibility_range_end > 0.0 and geometry.visibility_range_end <= limit: continue
		geometry.visibility_range_end = limit
		geometry.visibility_range_end_margin = limit * .12
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		changed += 1
	return {"scanned": scanned, "ranged": changed}

static func _extent(geometry: GeometryInstance3D) -> float:
	return (geometry.get_aabb().size * geometry.global_transform.basis.get_scale()).length()

static func _limit(geometry: GeometryInstance3D) -> float:
	return _limit_for(_extent(geometry))

static func _limit_for(extent: float) -> float:
	for tier: Array in TIERS:
		if extent < float(tier[0]): return float(tier[1])
	return 0.0

static func _kept(node: Node, park: Node, words: Array, memo: Dictionary = {}) -> bool:
	# True when the node or an ancestor below the park has one of the words in its
	# name. Ancestors are shared by thousands of geometries: each one's answer is
	# remembered for this pass (memo, keyed by instance id), the result unchanged.
	var current := node
	var walked: Array[int] = []
	var result := false
	while current != null and current != park:
		var id := current.get_instance_id()
		if memo.has(id):
			result = memo[id]
			break
		walked.append(id)
		var name := str(current.name).to_lower()
		for word: String in words:
			if word in name:
				result = true
				break
		if result: break
		current = current.get_parent()
	# Every node walked shares the answer: a word above it, or none up to the park.
	# (A node with the word itself is true; those below it are true through it.)
	for id: int in walked: memo[id] = result
	return result
