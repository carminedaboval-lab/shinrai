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
	for node: Node in park.find_children("*", "GeometryInstance3D", true, false):
		scanned += 1
		if scanned % 512 == 0: await LoadingBudget.checkpoint(park)
		if not is_instance_valid(node): continue
		var geometry := node as GeometryInstance3D
		# Far-LOD stand-ins (range begin) and HLOD children already manage themselves.
		if geometry.visibility_range_begin > 0.0 or geometry.visibility_parent != NodePath(): continue
		var limit := _limit(geometry)
		if limit <= 0.0: continue
		if geometry.visibility_range_end > 0.0 and geometry.visibility_range_end <= limit: continue
		if _kept(geometry, park, KEEP): continue
		if limit >= float(TIERS[-1][1]) and _kept(geometry, park, ARCHITECTURE):
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
	var extent := _extent(geometry)
	for tier: Array in TIERS:
		if extent < float(tier[0]): return float(tier[1])
	return 0.0

static func _kept(node: Node, park: Node, words: Array) -> bool:
	var current := node
	while current != null and current != park:
		var name := str(current.name).to_lower()
		for word: String in words:
			if word in name: return true
		current = current.get_parent()
	return false
