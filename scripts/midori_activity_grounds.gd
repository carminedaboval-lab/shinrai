extends Node3D
## Seats the basketball court and playground into the park after planting has
## finished: clears what stands on them, then replants their edges with copies
## of plants already placed in the park so the species and scale match.
## Runs after generation so the seeded tree layout elsewhere stays unchanged.
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const Kit = preload("res://scripts/midori_park_kit.gd")

const SITES := [
	{"node":"MidoriBasketballCourt", "clear":Vector2(18.0,11.5), "edge":Vector2(19.0,12.5), "gate":Vector2(0.0,12.5), "fill":.85, "spacing":3.0},
	{"node":"MidoriKidsPlayground", "clear":Vector2(18.5,14.5), "edge":Vector2(20.0,16.0), "gate":Vector2(0.0,99.0), "fill":.6, "spacing":3.0},
]
const GROUND_COVER := ["ArtworkReferenceCanopy","ArtworkLilacUnderstory","MainlandDenseGrassPatches",
	"MainlandMeadowTransitions","MainlandForestFloorBushPockets","MainlandEmeraldGrassClusters",
	"WoodlandFallenWoodFragments","OpenLawnBoulderCover","OpenBoulderNativeFringe"]
const HEDGE_SOURCES := ["ReferenceLilacMass_1000","ForestFloorBush_5200","ReferenceLilacMass_1001","ForestFloorBush_5201"]
const TUFT_SOURCE := "EmeraldFountainGrass_033"
const MAPLE_SOURCE := "Free3DJapaneseMaple_01"
const PATH_CLEARANCE_M := 1.4
const RNG_SEED := 205010411

var installed := false
var report := {"cleared":0, "planted":0, "maples":0}
var park: Node3D
var terrain: Node
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	park = get_parent()
	await LoadingBudget.wait_structure(park)
	var sparse := park.get_node_or_null("MidoriSparseVegetation")
	while sparse == null or sparse.get("installed") != true:
		await get_tree().process_frame
		sparse = park.get_node_or_null("MidoriSparseVegetation")
	var garden := park.get_node_or_null("MidoriGardenSpots")
	while garden != null and garden.get("installed") == false:
		await get_tree().process_frame
	terrain = park.get_node_or_null("MidoriTerrain")
	rng.seed = RNG_SEED
	var sources := _plant_sources()
	_clear_sites(sparse)
	await get_tree().process_frame
	var zone := park.find_child("PlaygroundZone", true, false) as Node3D
	if zone != null: zone.hide()
	for site: Dictionary in SITES:
		_plant_edge(site, sources)
	_build_court_walk()
	installed = true
	print("MIDORI_ACTIVITY_GROUNDS: ", JSON.stringify(report))

func _site_frame(site: Dictionary) -> Transform2D:
	# Maps a site's local XZ to world XZ. Godot yaw turns +X toward -Z.
	var area := park.get_node(String(site.node)) as Node3D
	return Transform2D(-area.rotation.y, Vector2(area.global_position.x, area.global_position.z))

func _plant_sources() -> Dictionary:
	# Duplicated before clearing, so a source standing on a site still works.
	var hedges: Array[Node3D] = []
	for label: String in HEDGE_SOURCES:
		var node := park.find_child(label, true, false) as Node3D
		if node != null: hedges.append(node.duplicate() as Node3D)
	var found := {"hedges":hedges, "tuft":null, "maple":null}
	var tuft := park.find_child(TUFT_SOURCE, true, false) as Node3D
	if tuft != null: found.tuft = tuft.duplicate()
	var maple := park.find_child(MAPLE_SOURCE, true, false) as Node3D
	if maple != null: found.maple = maple.duplicate()
	return found

func _clear_sites(sparse: Node) -> void:
	var frames: Array[Transform2D] = []
	for site: Dictionary in SITES:
		frames.append(_site_frame(site).affine_inverse())
	for node: Node in park.find_children("*", "Node3D", true, false):
		var plant := node as Node3D
		if plant.is_queued_for_deletion(): continue
		var holder := plant.get_parent()
		var in_garden := holder != park and String(holder.get_parent().name) == "MidoriGardenSpots"
		if not (in_garden or sparse.tree_root(plant) or String(holder.name) in GROUND_COVER): continue
		var world := Vector2(plant.global_position.x, plant.global_position.z)
		for i: int in range(SITES.size()):
			var local: Vector2 = frames[i] * world
			var half: Vector2 = SITES[i].clear
			if absf(local.x) < half.x and absf(local.y) < half.y:
				plant.queue_free()
				report.cleared += 1
				break

func _plant_edge(site: Dictionary, sources: Dictionary) -> void:
	var frame := _site_frame(site)
	var root := Node3D.new()
	root.name = String(site.node) + "Planting"
	add_child(root)
	var edge: Vector2 = site.edge
	var hedges: Array = sources.hedges
	var corners: Array[Vector2] = [Vector2(-edge.x,-edge.y), Vector2(edge.x,-edge.y), Vector2(edge.x,edge.y), Vector2(-edge.x,edge.y)]
	for side: int in range(4):
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var steps := int(a.distance_to(b) / float(site.spacing))
		for i: int in range(steps):
			var local := a.lerp(b, (float(i) + .5) / float(steps))
			if local.distance_to(site.gate) < 4.0: continue
			if rng.randf() > float(site.fill): continue
			local += Vector2(rng.randf_range(-.7, .7), rng.randf_range(-.7, .7))
			var world: Vector2 = frame * local
			if hedges.is_empty() or not _plantable(world): continue
			_set_plant(root, hedges[rng.randi() % hedges.size()], world, rng.randf_range(1.1, 1.6))
			if sources.tuft != null and rng.randf() < .4:
				var beside := world + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
				if _plantable(beside): _set_plant(root, sources.tuft, beside, rng.randf_range(.8, 1.1))
	if sources.maple == null: return
	for corner: Vector2 in corners:
		var world: Vector2 = frame * (corner * Vector2(1.14, 1.2))
		if _plantable(world):
			_set_plant(root, sources.maple, world, rng.randf_range(.85, 1.1))
			report.maples += 1

func _plantable(world: Vector2) -> bool:
	if park.path_edge_distance_world(world) < PATH_CLEARANCE_M: return false
	if park._is_point_in_or_near_lake(world * .5, 2.0): return false
	for site: Dictionary in SITES:
		var local: Vector2 = _site_frame(site).affine_inverse() * world
		var half: Vector2 = site.clear
		if absf(local.x) < half.x and absf(local.y) < half.y: return false
	return true

func _set_plant(root: Node3D, source: Node3D, world: Vector2, size: float) -> void:
	var plant := source.duplicate() as Node3D
	plant.name = "ActivityEdgePlant_%d" % report.planted
	root.add_child(plant)
	var height: float = terrain.height_at(world) if terrain != null else 0.0
	# Sources sit in the 2x layout, so their world scale is the true plant size.
	plant.scale = _true_scale(source) * size
	plant.rotation.y = rng.randf() * TAU
	plant.global_position = Vector3(world.x, height, world.y)
	report.planted += 1

func _true_scale(source: Node3D) -> Vector3:
	var scale_value := source.scale
	var uniform := maxf(scale_value.x, maxf(scale_value.y, scale_value.z))
	return Vector3.ONE * uniform

func _build_court_walk() -> void:
	# Concrete link from the court gate north to the outer walking circuit.
	var court := park.get_node("MidoriBasketballCourt") as Node3D
	var start := Vector2(court.global_position.x, court.global_position.z - 9.8)
	var end := start
	for step: int in range(40):
		end.y -= .5
		if park.path_edge_distance_world(end) < .1: break
	var mid := (start + end) * .5
	var concrete := Kit.mat(Color("#6d6e6a"), .9)
	var size := Vector3(3.2, .2, absf(end.y - start.y) + .4)
	Kit.box(self, "CourtGateWalk", size, Vector3(mid.x, .0, mid.y), concrete)
	Kit.solid(self, "CourtGateWalkFloor", size, Vector3(mid.x, .0, mid.y))
