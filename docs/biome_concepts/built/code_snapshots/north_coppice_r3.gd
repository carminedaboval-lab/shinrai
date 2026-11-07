extends RefCounted
## Zoki-bayashi 雑木林, the north coppice (docs/biome_concepts/after_north_coppice.png).
## The darkest, most layered broadleaf ground in the park: the even beds of
## spiky fountain grass give way to ferns, woodland shrubs, fallen logs and
## periwinkle carpets over leaf litter. Paths and lamps stay as they are.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ID := "zoki"
const RECT := Rect2(-100, -192, 154, 156)
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeNorthCoppice"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501102
	var inventory_before := Kit.inventory(park, RECT)
	var thinned := _thin_spiky_beds(park, terrain)
	var fern := Kit.prototype_parts(park, park.get("midnight_fern_prototype"))
	var bushes: Array = park.get("forest_floor_bush_prototypes")
	var bush := Kit.prototype_parts(park, bushes[0] if not bushes.is_empty() else null)
	var bush_b := Kit.prototype_parts(park, bushes[1] if bushes.size() > 1 else (bushes[0] if not bushes.is_empty() else null))
	var shrubs_b: Array = []
	var log := Kit.prototype_parts(park, park.get("deadwood_trunk_prototype"))
	var cover: Array[Dictionary] = []
	for i: int in range(6): cover.append(Kit.file_parts(FLOOR + "groundcover_%02d.glb" % i))
	var ferns: Array = []
	var shrubs: Array = []
	var logs: Array = []
	var carpets: Array = []
	var log_spots: Array[Vector2] = []
	# Walk the coppice on a jittered 2 m grid; shade near trunks is fullest.
	for z: int in range(int(RECT.position.y), int(RECT.end.y), 2):
		for x: int in range(int(RECT.position.x), int(RECT.end.x), 2):
			var p := Vector2(x + rng.randf() * 2.0, z + rng.randf() * 2.0)
			var w := Biomes.weight(p, ID, terrain)
			if w < 0.15: continue
			var roll := rng.randf()
			var shade := 1.0 - smoothstep(3.0, 12.0, Kit.trunk_distance(park, p))
			if not Kit.open_ground(park, terrain, p, 1.1): continue
			# Ferns: drifts in shade, scattered in the open.
			var drift := 0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * 2.3)
			if roll < w * (0.12 + 0.22 * shade) * (0.5 + drift):
				ferns.append(Kit.seat(fern, terrain, p, rng.randf_range(0.6, 1.15), rng.randf() * TAU, 0.0))
			elif roll < w * (0.36 + 0.6 * shade) * (0.5 + drift) + 0.06 * w * shade and bush.parts.size() > 0:
				if (x + z) % 3 == 0 and bush_b.parts.size() > 0: shrubs_b.append(Kit.seat(bush_b, terrain, p, rng.randf_range(0.7, 1.4), rng.randf() * TAU, 0.05))
				else: shrubs.append(Kit.seat(bush, terrain, p, rng.randf_range(0.7, 1.7), rng.randf() * TAU, 0.05))
			# Periwinkle carpets in their own patches.
			var patch := Biomes.noise().get_noise_2dv(p * 1.3 + Vector2(40, 9))
			if patch > 0.18 and rng.randf() < w * 0.9:
				for k: int in range(3):
					var q := p + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
					var c: Dictionary = cover[(absi(x * 7 + z * 3) / 2 + k) % cover.size()]
					if c.parts.is_empty(): continue
					carpets.append([c, Kit.seat(c, terrain, q, rng.randf_range(0.14, 0.24), rng.randf() * TAU)])
			# Fallen logs, well apart.
			if log.parts.size() > 0 and rng.randf() < 0.012 * w * (0.5 + shade):
				var near := false
				for other: Vector2 in log_spots: if other.distance_to(p) < 9.0: near = true
				if not near and Kit.open_ground(park, terrain, p, 2.2, 2.5):
					var lie := Basis(Vector3.FORWARD, PI * 0.5)
					var log_box: AABB = log.box
					var rotated: AABB = Transform3D(lie, Vector3.ZERO) * log_box
					var length := rng.randf_range(2.2, 3.6)
					var t := Kit.seat(log, terrain, p, length * log_box.size.y / maxf(rotated.size.x, rotated.size.z), rng.randf() * TAU, 0.06, lie)
					logs.append(t)
					log_spots.append(p)
		if z % 6 == 0: await park.get_tree().process_frame
	Kit.batch_parts(root, "CoppiceFerns", fern, ferns, 24.0, 70.0)
	Kit.batch_parts(root, "CoppiceShrubs", bush, shrubs, 24.0, 110.0)
	Kit.batch_parts(root, "CoppiceShrubsB", bush_b, shrubs_b, 24.0, 110.0)
	Kit.batch_parts(root, "CoppiceLogs", log, logs, 32.0, 90.0)
	# Carpets grouped by source piece.
	var by_piece := {}
	for row: Array in carpets:
		var key: int = cover.find(row[0])
		if not by_piece.has(key): by_piece[key] = []
		by_piece[key].append(row[1])
	for key: int in by_piece: Kit.batch_parts(root, "CoppicePeriwinkle%d" % key, cover[key], by_piece[key], 16.0, 45.0, false)
	var leaves := await Kit.leaf_floor(park, terrain, root, rng, RECT, func(p: Vector2) -> float:
		var w := Biomes.weight(p, ID, terrain)
		if w < 0.1: return 0.0
		return w * (1.5 + 3.5 * (0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * 2.7))), 0.35, "CoppiceLeaves")
	return {"ferns": ferns.size(), "shrubs": shrubs.size() + shrubs_b.size(), "logs": logs.size(), "periwinkle": carpets.size(), "leaves": leaves, "thinned": thinned, "inventory": inventory_before}

## The regular beds of tall spiky fountain grass are the plainest thing in the
## coppice today; most of them go, the rest stay as odd clumps.
static func _thin_spiky_beds(park: Node3D, terrain: Node) -> Dictionary:
	var filter := func(label: String) -> bool:
		var l := label.to_lower()
		return l.contains("woodlandfill") or l.contains("emerald_fountain_grass") or l.contains("fountain") or l.begins_with("shoulder") or l.begins_with("sparseunderstory") or l.begins_with("parkfloor_grass") or l.contains("uprightgrass") or l.contains("grass1")
	var keep := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		return not Biomes.pick(p, smoothstep(0.3, 0.8, Biomes.weight(p, ID, terrain)) * 0.85, 23)
	if ResourceLoader.exists("res://scripts/biomes/thin_all.gd"):
		return load("res://scripts/biomes/thin_all.gd").hide_low_planting(park, filter, keep, RECT)
	return {"fallback": Kit.thin_multimeshes([park], func(n: MultiMeshInstance3D) -> bool: return filter.call(String(n.name) + " " + (n.multimesh.mesh.resource_name if n.multimesh.mesh else "")), keep)}