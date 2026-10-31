extends RefCounted
## Garden planting after Tokyo Midtown Garden in Roppongi: an open lawn framed by
## massed planting, a cherry promenade along the path and tall canopy trees at the
## edge as Musashino columnar zelkova, the species Midtown preserved. 25 cherries
## in all, as there. The edge hedges are visual only. Trees get an invisible trunk
## collision. Each species
## is one MultiMesh per garden. Coordinates are district space.
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const Lawn = preload("res://scripts/midori_corporate_lawn.gd")
const VEGETATION := "res://assets/shinrai/parks/midori_park/models/vegetation/"
const CANOPY_NAME := "Tree EZTree1.Large001"
const BENCH_X: Array[float] = [-23.0, -9.0, 9.0, 23.0]  # GardenWalk benches sit at walk z + 5
const WALK_GAP := 4.5
const CHERRIES: Array[int] = [13, 12]  # 25 in all, by garden
const COLUMNAR := .55  # crown width of the Musashino zelkova against a spreading tree
const TREE_RANGE := 155.0  # measured to the middle of a garden; the other garden drops out
const HEDGE_RANGE := 110.0

const Blossom = preload("res://scripts/midori_corporate_blossom.gdshader")
const BLOSSOM_TEXTURE := "res://assets/shinrai/vegetation/sakura/jogoss_sakura_01/Sakura_RGBA.png"
const BLOSSOMS_PER_TREE := 2000
const BLOSSOM_CARD := .62  # metres tall; a spray of some ten flowers
const BLOOM_FROM := .34  # share of the tree's height where the flowering branches begin
const TRUNK_CORE_TOP := .72  # below this height, a column around the trunk stays bare
const TRUNK_CORE_RADIUS := .16  # as a share of the tree's width
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
		var beds := _layout(Lawn.GARDENS[i], Lawn.WALK_Z[i], CHERRIES[i], rng)
		for species: String in beds:
			if prototypes[species] == null: continue
			var spots: Array = beds[species]
			var placements := _mass(root, species, prototypes[species], spots)
			if species == "sakura": _bloom(root, prototypes[species], placements)
			counts[species] = counts.get(species, 0) + spots.size()
			if species in ["canopy", "sakura"]:
				for spot: Vector4 in spots:
					var trunk: Node3D = district.call("box", "TreeTrunk", Vector3(.3, 3.0, .3), Vector3(spot.x, 1.5, spot.z), null, true)
					trunk.visible = false
	for prototype: Variant in prototypes.values():
		if prototype != null: (prototype as Node3D).free()
	return counts

## {species: [Vector4(x, ground y, z, height)]}
static func _layout(garden: Rect2, walk_z: float, cherries: int, rng: RandomNumberGenerator) -> Dictionary:
	var beds := {"canopy":[], "sakura":[], "hedge":[]}
	var y := Lawn.GROUND_Y
	# Cherry promenade, clear of the benches on the south side of the walk.
	var x := garden.position.x + 4.0
	while x < garden.end.x - 3.0:
		if absf(x - Lawn.STREAM_X) > 3.0: beds.sakura.append(Vector4(x, y, walk_z - 4.4, rng.randf_range(7.6, 9.2)))
		if not _near_bench(x) and absf(x + 4.0 - Lawn.STREAM_X) > 6.0: beds.sakura.append(Vector4(x + 4.0, y, walk_z + 4.2, rng.randf_range(7.6, 9.2)))
		x += 5.5
	beds.sakura = beds.sakura.slice(0, cherries)
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
static func _mass(root: Node3D, species: String, prototype: Node3D, spots: Array) -> Array[Transform3D]:
	if spots.is_empty(): return []
	var bounds: AABB = prototype.get_meta("source_bounds")
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED + spots.size()
	var placements: Array[Transform3D] = []
	for spot: Vector4 in spots:
		var factor: float = spot.w / maxf(bounds.size.y, .001)
		var narrow := COLUMNAR if species == "canopy" else 1.0
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(narrow, 1.0, narrow) * factor)
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
	return placements

## A full canopy of blossom sprays. They root only on the model's branch-attached
## canopy mesh, never the trunk, keep clear of the trunk's core, and grow outward
## and slightly down from their twig. The model's own flowers are far too sparse.
static func _bloom(root: Node3D, prototype: Node3D, placements: Array[Transform3D]) -> void:
	if placements.is_empty(): return
	var bounds: AABB = prototype.get_meta("source_bounds")
	var crown := bounds.get_center() + Vector3(0, bounds.size.y * .1, 0)
	var floor_y := bounds.position.y + bounds.size.y * BLOOM_FROM
	var core_top := bounds.position.y + bounds.size.y * TRUNK_CORE_TOP
	var core := Vector2(bounds.get_center().x, bounds.get_center().z)
	var core_radius := bounds.size.x * TRUNK_CORE_RADIUS
	for visual: MeshInstance3D in prototype.get_children():
		if str(visual.name).contains("Trunk"):
			var trunk: Vector3 = visual.transform * visual.mesh.get_aabb().get_center()
			core = Vector2(trunk.x, trunk.z)
	var branches := PackedVector3Array()
	for visual: MeshInstance3D in prototype.get_children():
		if not str(visual.name).contains("Canopy"): continue
		for surface: int in range(visual.mesh.get_surface_count()):
			var points: PackedVector3Array = visual.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				var at: Vector3 = visual.transform * point
				if at.y < floor_y: continue
				if at.y < core_top and Vector2(at.x, at.z).distance_to(core) < core_radius: continue
				branches.append(at)
	if branches.is_empty(): return
	var card := QuadMesh.new()
	card.size = Vector2(BLOSSOM_CARD * .5, BLOSSOM_CARD)
	var material := ShaderMaterial.new()
	material.resource_name = "CorporateCherryBlossom"
	material.shader = Blossom
	material.set_shader_parameter("blossom", load(BLOSSOM_TEXTURE))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = card
	multimesh.instance_count = placements.size() * BLOSSOMS_PER_TREE
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var index := 0
	for placement: Transform3D in placements:
		for i: int in range(BLOSSOMS_PER_TREE):
			var at: Vector3 = branches[rng.randi_range(0, branches.size() - 1)]
			var out := ((at - crown) * Vector3(1, 1.3, 1)).normalized()
			var turned := (placement.basis.orthonormalized() * out).normalized()
			var noise := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * .4
			var grows := (turned + Vector3(0, -.3, 0) + noise).normalized()
			var side := grows.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))).normalized()
			var size := rng.randf_range(.8, 1.25)
			var basis := Basis(side, grows, side.cross(grows).normalized()).scaled(Vector3.ONE * size)
			# The card's foot sits on the twig, so the spray grows from it.
			var foot := placement * at
			multimesh.set_instance_transform(index, Transform3D(basis, foot + grows * BLOSSOM_CARD * .5 * size))
			var pale := rng.randf()
			multimesh.set_instance_color(index, Color(1, .9 + pale * .1, .91 + pale * .09) * rng.randf_range(.9, 1.1))
			multimesh.set_instance_custom_data(index, Color(turned.x * .5 + .5, turned.y * .5 + .5, turned.z * .5 + .5, rng.randf()))
			index += 1
	var group := MultiMeshInstance3D.new()
	group.name = "CherryBlossom"
	group.multimesh = multimesh
	group.material_override = material
	group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.visibility_range_end = TREE_RANGE
	root.add_child(group)
