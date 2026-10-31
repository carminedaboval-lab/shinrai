extends RefCounted
## Garden planting after Tokyo Midtown Garden in Roppongi: an open lawn framed by
## massed planting, a cherry promenade along the path and tall canopy trees at the
## edge, the role camphor and zelkova play in Tokyo's corporate plazas. The edge
## hedges are visual only. Trees get an invisible trunk collision. Each species
## is one MultiMesh per garden. Coordinates are district space.
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const Lawn = preload("res://scripts/midori_corporate_lawn.gd")
const VEGETATION := "res://assets/shinrai/parks/midori_park/models/vegetation/"
const CANOPY_NAME := "Tree EZTree1.Large001"
const BENCH_X: Array[float] = [-23.0, -9.0, 9.0, 23.0]  # GardenWalk benches sit at walk z + 5
const WALK_GAP := 4.5
const TREE_RANGE := 320.0
const HEDGE_RANGE := 160.0
const RNG_SEED := 20261031

static func plant(district: Node3D) -> Dictionary:
	var prototypes := {
		"canopy": Landscape._prototype(Landscape.TREE_PACK, CANOPY_NAME),
		"sakura": Landscape._prototype(VEGETATION + "midori_sakura_winter_sentinel_clean_v2.glb", ""),
		"hedge": Landscape._prototype(Landscape.TREE_PACK, Landscape.SHRUB_NAME),
	}
	var root := Node3D.new()
	root.name = "CorporateGardenPlanting"
	root.set_meta("creator_protected", true)
	district.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var counts := {}
	for i: int in range(Lawn.GARDENS.size()):
		var beds := _layout(Lawn.GARDENS[i], Lawn.WALK_Z[i], rng)
		for species: String in beds:
			if prototypes[species] == null: continue
			var spots: Array = beds[species]
			_mass(root, species, prototypes[species], spots)
			counts[species] = counts.get(species, 0) + spots.size()
			if species in ["canopy", "sakura"]:
				for spot: Vector4 in spots:
					var trunk: Node3D = district.call("box", "TreeTrunk", Vector3(.3, 3.0, .3), Vector3(spot.x, 1.5, spot.z), null, true)
					trunk.visible = false
	for prototype: Variant in prototypes.values():
		if prototype != null: (prototype as Node3D).free()
	return counts

## {species: [Vector4(x, ground y, z, height)]}
static func _layout(garden: Rect2, walk_z: float, rng: RandomNumberGenerator) -> Dictionary:
	var beds := {"canopy":[], "sakura":[], "hedge":[]}
	var y := Lawn.GROUND_Y
	# Cherry promenade, clear of the benches on the south side of the walk.
	var x := garden.position.x + 4.0
	while x < garden.end.x - 3.0:
		beds.sakura.append(Vector4(x, y, walk_z - 4.4, rng.randf_range(6.4, 7.6)))
		if not _near_bench(x): beds.sakura.append(Vector4(x + 4.0, y, walk_z + 4.2, rng.randf_range(6.4, 7.6)))
		x += 8.0
	# Tall canopy along the two long edges, leaving the lawn open between them.
	x = garden.position.x + 2.5
	while x < garden.end.x:
		for z: float in [garden.position.y + 3.4, garden.end.y - 3.4]:
			beds.canopy.append(Vector4(x + rng.randf_range(-1.2, 1.2), y, z + rng.randf_range(-.8, .8), rng.randf_range(12.0, 15.5)))
		x += 11.0
	# Massed beds around the whole edge, broken only where the walk comes through.
	_bed_edge(beds, Vector2(garden.position.x, garden.position.y + .9), Vector2(garden.end.x, garden.position.y + .9), walk_z, rng)
	_bed_edge(beds, Vector2(garden.position.x, garden.end.y - .9), Vector2(garden.end.x, garden.end.y - .9), walk_z, rng)
	_bed_edge(beds, Vector2(garden.position.x + .9, garden.position.y), Vector2(garden.position.x + .9, garden.end.y), walk_z, rng)
	_bed_edge(beds, Vector2(garden.end.x - .9, garden.position.y), Vector2(garden.end.x - .9, garden.end.y), walk_z, rng)
	return beds

static func _bed_edge(beds: Dictionary, from: Vector2, to: Vector2, walk_z: float, rng: RandomNumberGenerator) -> void:
	var length := from.distance_to(to)
	var along := (to - from) / length
	var s := .8
	while s < length:
		var at := from + along * s
		s += rng.randf_range(1.2, 1.7)
		if absf(at.y - walk_z) < WALK_GAP and absf(along.y) > .5: continue
		beds.hedge.append(Vector4(at.x, Lawn.GROUND_Y, at.y, rng.randf_range(.95, 1.3)))

static func _near_bench(x: float) -> bool:
	for bench: float in BENCH_X:
		if absf(x + 4.0 - bench) < 2.2: return true
	return false

## One MultiMesh for each mesh of the model, with a random yaw on every plant.
static func _mass(root: Node3D, species: String, prototype: Node3D, spots: Array) -> void:
	if spots.is_empty(): return
	var bounds: AABB = prototype.get_meta("source_bounds")
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED + spots.size()
	var placements: Array[Transform3D] = []
	for spot: Vector4 in spots:
		var factor: float = spot.w / maxf(bounds.size.y, .001)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * factor)
		placements.append(Transform3D(basis, Vector3(spot.x, spot.y, spot.z) - basis * pivot))
	for visual: MeshInstance3D in prototype.get_children():
		var mesh: Mesh = visual.mesh.duplicate()
		if mesh is ArrayMesh:
			for surface: int in range(mesh.get_surface_count()):
				var override := visual.get_surface_override_material(surface)
				if override != null: (mesh as ArrayMesh).surface_set_material(surface, override)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = placements.size()
		for i: int in range(placements.size()):
			multimesh.set_instance_transform(i, placements[i] * visual.transform)
		var group := MultiMeshInstance3D.new()
		group.name = species.capitalize().replace(" ", "")
		group.multimesh = multimesh
		group.material_override = visual.material_override
		group.visibility_range_end = TREE_RANGE
		if species == "hedge":
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.visibility_range_end = HEDGE_RANGE
		root.add_child(group)
