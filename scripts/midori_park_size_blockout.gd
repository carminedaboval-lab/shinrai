extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const SakuraTreeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_sakura_winter_sentinel_clean_v2.glb")
const FountainGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_green_fountain_grass_v1.glb")
const MeadowGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_swaying_meadow_grass_v1.glb")
const MossyBoulderScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_mossy_boulder_cluster_v1.glb")
const MainBridgeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_main_arched_bridge_v1.glb")
const SecondaryBridgeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_secondary_footbridge_v1.glb")
const ViewingDeckScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_lakeside_viewing_deck_v1.glb")
const BroadleafTreePack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/realistic_trees_collection/scene.glb")
const PineTreePack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/pine_trees_pack/scene.glb")
const LilacBushPack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/lilac_bush_pack/scene.glb")
const DenseGrassPack: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/cosmic_dust_grass/grass_1k.glb")
const DeadwoodTrunkScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/mistrzjang1_tree_trunk/tree_trunk_002.fbx")
const HollowBarkScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/michaeldebbarma_hollow_bark/hollow_bark.fbx")
const MidnightFernScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/midnight_fern/midnight_fern.glb")
const EmeraldFountainGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/emerald_fountain_grass/emerald_fountain_grass.glb")
const JapaneseMapleMesh: Mesh = preload("res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/Tree Japanese maple N030123.obj")

const PARK_SIZE_M := Vector2(220.0, 180.0)
const PARK_HALF := Vector2(PARK_SIZE_M.x * 0.5, PARK_SIZE_M.y * 0.5)
const LAKE_SIZE_M := Vector2(110.0, 72.0)
const SHOW_PLANNING_LABELS := false
const MATURE_TREE_MIN_SPACING_M := 3.0
const SKINNY_TREE_MIN_SPACING_M := 2.3
const SKINNY_TO_SKINNY_MIN_SPACING_M := 1.2
const SHRUB_PATH_CLEARANCE_M := 1.3
const SAKURA_TREE_COUNT := 24

var mat_grass: StandardMaterial3D
var mat_path: StandardMaterial3D
var mat_water: StandardMaterial3D
var mat_sports: StandardMaterial3D
var mat_playground: StandardMaterial3D
var mat_plaza: StandardMaterial3D
var mat_pavilion: StandardMaterial3D
var mat_boundary: StandardMaterial3D
var mat_entry: StandardMaterial3D
var mat_island: StandardMaterial3D
var mat_plan_marker: StandardMaterial3D
var broadleaf_prototypes: Array[Node3D] = []
var pine_prototypes: Array[Node3D] = []
var pine_sapling_prototypes: Array[Node3D] = []
var forest_floor_bush_prototypes: Array[Node3D] = []
var lilac_prototypes: Array[Node3D] = []
var dense_grass_prototypes: Array[Node3D] = []
var deadwood_trunk_prototype: Node3D
var hollow_bark_prototype: Node3D
var midnight_fern_prototype: Node3D
var emerald_fountain_grass_prototype: Node3D
var japanese_maple_prototype: Node3D
var occupied_tree_positions: Array[Vector2] = []
var occupied_tree_is_skinny: Array[bool] = []

func _ready() -> void:
	_create_materials()
	_create_environment()
	_prepare_reference_vegetation()
	_build_park_footprint()
	_spawn_scale_review_player()
	_build_size_hud()
	print("Midori Park size blockout: %.0f m x %.0f m | diagonal %.1f m" % [
		PARK_SIZE_M.x, PARK_SIZE_M.y, PARK_SIZE_M.length()
	])

func _create_materials() -> void:
	mat_grass = _make_material(Color("#344f38"), 0.98)
	mat_path = _make_material(Color("#77756f"), 0.92)
	mat_water = _make_material(Color("#315d70"), 0.30, 0.12)
	mat_sports = _make_material(Color("#536d61"), 0.88)
	mat_playground = _make_material(Color("#8b6255"), 0.91)
	mat_plaza = _make_material(Color("#9a9589"), 0.94)
	mat_pavilion = _make_material(Color("#8a755e"), 0.88)
	mat_boundary = _make_material(Color("#d6d0bf"), 0.82)
	mat_entry = _make_material(Color("#e3a14c"), 0.74)
	mat_island = _make_material(Color("#405d3d"), 0.98)
	mat_plan_marker = _make_material(Color(0.20, 0.78, 0.92, 0.55), 0.76, 0.08)

func _make_material(color_value: Color, roughness_value: float, metallic_value: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = roughness_value
	material.metallic = metallic_value
	return material

func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ParkReviewEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#65727a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a8b3b7")
	environment.ambient_light_energy = 0.40
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#778489")
	environment.fog_light_energy = 0.46
	environment.fog_density = 0.0105
	environment.fog_sky_affect = 0.72
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "ParkReviewSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("#fff0d1")
	sun.light_energy = 0.84
	sun.shadow_enabled = true
	add_child(sun)

func _build_park_footprint() -> void:
	var root := Node3D.new()
	root.name = "MidoriPark_220x180m_Blockout"
	add_child(root)

	_add_collidable_box(root, "ParkGround_220x180m", Vector3(0.0, -0.12, 0.0), Vector3(PARK_SIZE_M.x, 0.24, PARK_SIZE_M.y), mat_grass)
	_build_boundary(root)
	_build_paths(root)
	_build_curved_promenades(root)
	_build_zone_placeholders(root)
	_build_artwork_assets(root)
	_build_prop_placement_plan(root)
	if SHOW_PLANNING_LABELS:
		_build_scale_ticks(root)
	_build_sakura_trees(root)
	_build_reference_canopy(root)
	_build_deadwood_pass(root)
	_build_japanese_maple_pass(root)

func _build_boundary(parent: Node3D) -> void:
	var edge_t := 0.32
	_add_visual_box(parent, "NorthBoundary", Vector3(0.0, 0.04, -PARK_HALF.y), Vector3(PARK_SIZE_M.x, 0.08, edge_t), mat_boundary)
	_add_visual_box(parent, "SouthBoundary", Vector3(0.0, 0.04, PARK_HALF.y), Vector3(PARK_SIZE_M.x, 0.08, edge_t), mat_boundary)
	_add_visual_box(parent, "WestBoundary", Vector3(-PARK_HALF.x, 0.04, 0.0), Vector3(edge_t, 0.08, PARK_SIZE_M.y), mat_boundary)
	_add_visual_box(parent, "EastBoundary", Vector3(PARK_HALF.x, 0.04, 0.0), Vector3(edge_t, 0.08, PARK_SIZE_M.y), mat_boundary)

	# Four broad entrances make the footprint readable before detailed paths exist.
	for entry in [
		{"name": "MainSouthEntrance", "position": Vector3(0.0, 0.09, PARK_HALF.y - 2.5), "size": Vector3(16.0, 0.10, 5.0)},
		{"name": "NorthEntrance", "position": Vector3(-38.0, 0.09, -PARK_HALF.y + 2.5), "size": Vector3(12.0, 0.10, 5.0)},
		{"name": "WestEntrance", "position": Vector3(-PARK_HALF.x + 2.5, 0.09, 20.0), "size": Vector3(5.0, 0.10, 12.0)},
		{"name": "EastEntrance", "position": Vector3(PARK_HALF.x - 2.5, 0.09, -20.0), "size": Vector3(5.0, 0.10, 12.0)},
	]:
		_add_visual_box(parent, entry["name"], entry["position"], entry["size"], mat_entry)

func _build_paths(parent: Node3D) -> void:
	var loop_half_x := PARK_HALF.x - 13.0
	var loop_half_z := PARK_HALF.y - 13.0
	var loop_width := 5.0
	_add_visual_box(parent, "LoopPathNorth", Vector3(0.0, 0.075, -loop_half_z), Vector3(loop_half_x * 2.0, 0.05, loop_width), mat_path)
	_add_visual_box(parent, "LoopPathSouth", Vector3(0.0, 0.075, loop_half_z), Vector3(loop_half_x * 2.0, 0.05, loop_width), mat_path)
	_add_visual_box(parent, "LoopPathWest", Vector3(-loop_half_x, 0.075, 0.0), Vector3(loop_width, 0.05, loop_half_z * 2.0), mat_path)
	_add_visual_box(parent, "LoopPathEast", Vector3(loop_half_x, 0.075, 0.0), Vector3(loop_width, 0.05, loop_half_z * 2.0), mat_path)
	_add_visual_box(parent, "MainNorthSouthPath", Vector3(-37.0, 0.078, 0.0), Vector3(5.0, 0.055, 150.0), mat_path)
	_add_visual_box(parent, "MainEastWestPath", Vector3(0.0, 0.079, 42.0), Vector3(190.0, 0.055, 5.0), mat_path)

func _build_curved_promenades(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ArtworkCurvedPromenades"
	parent.add_child(root)
	_add_path_strip(root, "WestLakePromenade", [
		Vector3(-37.0, 0.112, 42.0), Vector3(-27.0, 0.112, 31.0),
		Vector3(-23.0, 0.112, 14.0), Vector3(-27.0, 0.112, -4.0),
		Vector3(-31.0, 0.112, -24.0), Vector3(-37.0, 0.112, -42.0),
	], 4.2, mat_path)
	_add_path_strip(root, "EastLakePromenade", [
		Vector3(43.0, 0.114, 42.0), Vector3(59.0, 0.114, 34.0),
		Vector3(72.0, 0.114, 21.0), Vector3(80.0, 0.114, 3.0),
		Vector3(80.0, 0.114, -15.0), Vector3(84.0, 0.114, -35.0),
		Vector3(78.0, 0.114, -54.0), Vector3(76.0, 0.114, -64.0),
	], 4.4, mat_path)
	_add_path_strip(root, "NorthLakePromenade", [
		Vector3(-37.0, 0.113, -42.0), Vector3(-18.0, 0.113, -53.0),
		Vector3(5.0, 0.113, -61.0), Vector3(28.0, 0.113, -65.0),
		Vector3(47.0, 0.113, -64.0), Vector3(65.0, 0.113, -66.0),
		Vector3(76.0, 0.113, -64.0),
	], 4.0, mat_path)

func _add_path_strip(parent: Node3D, node_name: String, points: Array[Vector3], width: float, material: Material) -> void:
	if points.size() < 2:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travelled := 0.0
	for index: int in range(points.size() - 1):
		var p0 := points[index]
		var p1 := points[index + 1]
		var direction := (p1 - p0).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x) * width * 0.5
		var segment_length := p0.distance_to(p1)
		var u0 := travelled / 4.0
		var u1 := (travelled + segment_length) / 4.0
		_add_path_vertex(surface, p0 - side, Vector2(u0, 0.0))
		_add_path_vertex(surface, p1 + side, Vector2(u1, 1.0))
		_add_path_vertex(surface, p1 - side, Vector2(u1, 0.0))
		_add_path_vertex(surface, p0 - side, Vector2(u0, 0.0))
		_add_path_vertex(surface, p0 + side, Vector2(u0, 1.0))
		_add_path_vertex(surface, p1 + side, Vector2(u1, 1.0))
		travelled += segment_length
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_path_vertex(surface: SurfaceTool, position_value: Vector3, uv_value: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv_value)
	surface.add_vertex(position_value)

func _build_zone_placeholders(parent: Node3D) -> void:
	# The lake uses overlapping broad forms only to judge scale. Its final shoreline will be irregular.
	_add_cylinder_zone(parent, "LakeMain", Vector3(27.0, 0.10, -10.0), Vector2(LAKE_SIZE_M.x * 0.50, LAKE_SIZE_M.y * 0.50), mat_water)
	_add_cylinder_zone(parent, "LakeNorthLobe", Vector3(47.0, 0.102, -42.0), Vector2(34.0, 23.0), mat_water)
	_add_cylinder_zone(parent, "LakeSouthLobe", Vector3(8.0, 0.104, 20.0), Vector2(30.0, 20.0), mat_water)
	_add_cylinder_zone(parent, "LakeCentralIsland", Vector3(24.0, 0.145, -12.0), Vector2(8.5, 6.5), mat_island)
	_add_cylinder_zone(parent, "LakeNorthIsland", Vector3(56.0, 0.146, -36.0), Vector2(5.0, 3.8), mat_island)
	_add_zone_label(parent, "LAKE 110 x 72 m", Vector3(28.0, 1.0, -10.0), Color("#d4eff7"))

	_add_zone_box(parent, "SportsZone", Vector3(-70.0, 0.105, -43.0), Vector2(55.0, 36.0), mat_sports)
	_add_zone_label(parent, "SPORTS 55 x 36 m", Vector3(-70.0, 1.0, -43.0), Color.WHITE)

	_add_zone_box(parent, "PlaygroundZone", Vector3(-72.0, 0.106, 45.0), Vector2(32.0, 26.0), mat_playground)
	_add_zone_label(parent, "PLAYGROUND 32 x 26 m", Vector3(-72.0, 1.0, 45.0), Color.WHITE)

	_add_zone_box(parent, "CentralPlazaZone", Vector3(62.0, 0.107, 51.0), Vector2(44.0, 34.0), mat_plaza)
	_add_zone_label(parent, "PLAZA 44 x 34 m", Vector3(62.0, 1.0, 51.0), Color("#252525"))

	_add_zone_box(parent, "PavilionZone", Vector3(76.0, 0.108, -64.0), Vector2(20.0, 14.0), mat_pavilion)
	_add_zone_label(parent, "PAVILION 20 x 14 m", Vector3(76.0, 1.0, -64.0), Color.WHITE)

func _build_artwork_assets(parent: Node3D) -> void:
	var structures := Node3D.new()
	structures.name = "ArtworkMatchedStructures"
	parent.add_child(structures)

	# The arched crossing is the park's visual anchor and the shortest route
	# between the south entrance and the central lake island.
	_instance_park_asset(
		structures, MainBridgeScene, "WAT01_MainArchedBridge",
		Vector3(8.0, 2.15, 38.0), 0.0, Vector3.ONE * 26.0
	)
	_add_invisible_collision_box(
		structures, "WAT01_WalkwayCollision",
		Vector3(8.0, 2.05, 38.0), Vector3(25.0, 0.45, 4.6), 0.0
	)

	# A flatter tactical route crosses the north lake lobe and gives two ways
	# around the pavilion side of the park.
	_instance_park_asset(
		structures, SecondaryBridgeScene, "WAT02_SecondaryFootbridge",
		Vector3(47.0, 1.25, -64.0), 0.0, Vector3.ONE * 20.0
	)
	_add_invisible_collision_box(
		structures, "WAT02_WalkwayCollision",
		Vector3(47.0, 1.28, -64.0), Vector3(19.5, 0.40, 4.2), 0.0
	)

	_instance_park_asset(
		structures, ViewingDeckScene, "WAT03_EastViewingDeck",
		Vector3(80.0, 1.75, -15.0), 90.0, Vector3.ONE * 13.0
	)
	_add_invisible_collision_box(
		structures, "WAT03_DeckCollision",
		Vector3(80.0, 1.55, -15.0), Vector3(12.5, 0.45, 11.5), 90.0
	)

	_build_mossy_shoreline_cover(parent)
	_build_waterside_grasses(parent)

func _build_mossy_shoreline_cover(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MossyShorelineCover_9"
	parent.add_child(root)
	var placements: Array[Dictionary] = [
		{"p": Vector3(-20.0, 1.45, -4.0), "r": 18.0, "s": 5.6},
		{"p": Vector3(-8.0, 1.20, 27.0), "r": 205.0, "s": 4.8},
		{"p": Vector3(31.0, 1.30, 30.0), "r": 146.0, "s": 5.0},
		{"p": Vector3(67.0, 1.40, 5.0), "r": 74.0, "s": 5.4},
		{"p": Vector3(72.0, 1.10, -42.0), "r": 251.0, "s": 4.3},
		{"p": Vector3(23.0, 1.00, -12.0), "r": 323.0, "s": 3.8},
		{"p": Vector3(55.0, 0.95, -36.0), "r": 102.0, "s": 3.4},
		{"p": Vector3(-28.0, 1.05, -26.0), "r": 287.0, "s": 4.1},
		{"p": Vector3(48.0, 1.05, 22.0), "r": 41.0, "s": 4.0},
	]
	for index: int in range(placements.size()):
		var placement: Dictionary = placements[index]
		_instance_park_asset(
			root, MossyBoulderScene, "VEG07_MossyBoulders_%02d" % (index + 1),
			placement["p"], placement["r"], Vector3.ONE * placement["s"]
		)
		_add_invisible_collision_box(
			root, "VEG07_Collision_%02d" % (index + 1),
			placement["p"], Vector3(placement["s"] * 0.78, placement["s"] * 0.42, placement["s"] * 0.58), placement["r"]
		)

func _build_waterside_grasses(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "WatersideVegetation_36Reed_9DenseGrass"
	parent.add_child(root)
	var edge_points: Array[Vector3] = [
		Vector3(-24.0, 0.55, -17.0), Vector3(-18.0, 0.55, 5.0), Vector3(-12.0, 0.55, 23.0),
		Vector3(1.0, 0.55, 34.0), Vector3(22.0, 0.55, 36.0), Vector3(43.0, 0.55, 28.0),
		Vector3(61.0, 0.55, 18.0), Vector3(75.0, 0.55, 2.0), Vector3(79.0, 0.55, -18.0),
		Vector3(73.0, 0.55, -39.0), Vector3(61.0, 0.55, -58.0), Vector3(40.0, 0.55, -64.0),
		Vector3(18.0, 0.55, -51.0), Vector3(1.0, 0.55, -40.0), Vector3(-13.0, 0.55, -30.0),
		Vector3(17.0, 0.55, -5.0), Vector3(30.0, 0.55, -18.0), Vector3(52.0, 0.55, -31.0),
	]
	for index: int in range(edge_points.size()):
		for variant: int in range(2):
			var offset_angle := float(index * 73 + variant * 149)
			var offset := Vector3(cos(deg_to_rad(offset_angle)), 0.0, sin(deg_to_rad(offset_angle))) * (0.7 + variant * 0.9)
			var source := FountainGrassScene if (index + variant) % 2 == 0 else MeadowGrassScene
			var scale_value := 1.00 + float((index + variant) % 5) * 0.10
			_instance_park_asset(
				root, source, "VEG06_WatersideGrass_%02d_%d" % [index + 1, variant + 1],
				edge_points[index] + offset, fmod(float(index * 97 + variant * 43), 360.0), Vector3.ONE * scale_value
			)

	if dense_grass_prototypes.is_empty():
		return
	var lake_center := Vector3(28.0, 0.0, -14.0)
	var dense_patch_indices: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14, 16]
	# Keep the very dense Grass1 variant out of the open shoreline. Its layered
	# blades are reserved for a few reduced-scale deep-woodland accents.
	var dense_variant_sequence: Array[int] = [1, 1, 2, 1, 2, 1, 1, 2, 1]
	for patch_index: int in range(dense_patch_indices.size()):
		var edge_index: int = dense_patch_indices[patch_index]
		var edge_position: Vector3 = edge_points[edge_index]
		var landward := Vector3(edge_position.x - lake_center.x, 0.0, edge_position.z - lake_center.z).normalized()
		var dense_position := edge_position + landward * (1.15 + float(patch_index % 3) * 0.35)
		dense_position.y = 0.12
		var prototype_index: int = dense_variant_sequence[patch_index] % dense_grass_prototypes.size()
		var prototype: Node3D = dense_grass_prototypes[prototype_index]
		var patch := prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		patch.name = "VEG06_DenseGrass_%02d" % (patch_index + 1)
		patch.position = dense_position
		patch.rotation_degrees.y = fmod(float(patch_index * 137 + 23), 360.0)
		patch.scale = Vector3.ONE * (0.86 + float(patch_index % 4) * 0.07)
		root.add_child(patch)
		_configure_vegetation_visibility(patch)

func _build_prop_placement_plan(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PlannedPropSockets"
	parent.add_child(root)
	var sockets: Array[Dictionary] = [
		{"id": "ARC01_Pavilion", "category": "architecture", "p": Vector3(76.0, 0.1, -64.0), "yaw": 90.0},
		{"id": "ARC02_MaintenanceRestroom", "category": "architecture", "p": Vector3(-88.0, 0.1, -63.0), "yaw": 0.0},
		{"id": "ARC03_MainEntranceMarker", "category": "architecture", "p": Vector3(0.0, 0.1, 84.0), "yaw": 0.0},
		{"id": "ACT01_PlaygroundSet", "category": "activity", "p": Vector3(-72.0, 0.1, 45.0), "yaw": -12.0},
		{"id": "ACT02_BasketballHoopWest", "category": "activity", "p": Vector3(-92.0, 0.1, -43.0), "yaw": 90.0},
		{"id": "ACT02_BasketballHoopEast", "category": "activity", "p": Vector3(-48.0, 0.1, -43.0), "yaw": -90.0},
		{"id": "ACT03_TennisNet", "category": "activity", "p": Vector3(-70.0, 0.1, -43.0), "yaw": 0.0},
		{"id": "FUR06_MainInformationBoard", "category": "furniture", "p": Vector3(-7.0, 0.1, 79.0), "yaw": 0.0},
		{"id": "FUR08_DrinkingFountain", "category": "furniture", "p": Vector3(-54.0, 0.1, 57.0), "yaw": 90.0},
		{"id": "FUR09_BicycleRack", "category": "furniture", "p": Vector3(57.0, 0.1, 68.0), "yaw": 0.0},
		{"id": "FUR10_VendingMachine", "category": "furniture", "p": Vector3(69.0, 0.1, 62.0), "yaw": 180.0},
		{"id": "FUR13_EmergencyPoint", "category": "furniture", "p": Vector3(88.0, 0.1, -23.0), "yaw": -90.0},
		{"id": "GAM01_PlazaPlanterA", "category": "cover", "p": Vector3(50.0, 0.1, 44.0), "yaw": 15.0},
		{"id": "GAM01_PlazaPlanterB", "category": "cover", "p": Vector3(72.0, 0.1, 44.0), "yaw": -12.0},
		{"id": "GAM03_UtilityCabinet", "category": "cover", "p": Vector3(-96.0, 0.1, -68.0), "yaw": 90.0},
		{"id": "GAM04_SecurityCamera", "category": "security", "p": Vector3(87.0, 0.1, 66.0), "yaw": 215.0},
		{"id": "GAMEPLAY_Loot_Pavilion", "category": "gameplay", "p": Vector3(78.0, 0.1, -62.0), "yaw": 0.0},
		{"id": "GAMEPLAY_Loot_Playground", "category": "gameplay", "p": Vector3(-67.0, 0.1, 51.0), "yaw": 0.0},
		{"id": "GAMEPLAY_Loot_Deck", "category": "gameplay", "p": Vector3(80.0, 0.1, -15.0), "yaw": 0.0},
		{"id": "GAMEPLAY_Extraction_Plaza", "category": "gameplay", "p": Vector3(62.0, 0.1, 51.0), "yaw": 0.0},
	]
	var bench_points: Array[Vector3] = [
		Vector3(-55.0, 0.1, 34.0), Vector3(-21.0, 0.1, 48.0), Vector3(9.0, 0.1, 47.0),
		Vector3(40.0, 0.1, 42.0), Vector3(83.0, 0.1, 29.0), Vector3(84.0, 0.1, -48.0),
		Vector3(32.0, 0.1, -68.0), Vector3(-23.0, 0.1, -68.0), Vector3(-91.0, 0.1, 7.0),
	]
	for index: int in range(bench_points.size()):
		sockets.append({"id": "FUR01_Bench_%02d" % (index + 1), "category": "furniture", "p": bench_points[index], "yaw": fmod(float(index) * 90.0, 360.0)})

	var lamp_points: Array[Vector3] = [
		Vector3(-75.0, 0.1, 42.0), Vector3(-37.0, 0.1, 42.0), Vector3(0.0, 0.1, 42.0),
		Vector3(38.0, 0.1, 42.0), Vector3(78.0, 0.1, 42.0), Vector3(-37.0, 0.1, 12.0),
		Vector3(-37.0, 0.1, -20.0), Vector3(-37.0, 0.1, -54.0), Vector3(97.0, 0.1, 5.0),
		Vector3(97.0, 0.1, -38.0), Vector3(-97.0, 0.1, 44.0), Vector3(-97.0, 0.1, -35.0),
	]
	for index: int in range(lamp_points.size()):
		sockets.append({"id": "FUR04_PathLamp_%02d" % (index + 1), "category": "lighting", "p": lamp_points[index], "yaw": 0.0})

	for socket: Dictionary in sockets:
		var marker := Marker3D.new()
		marker.name = socket["id"]
		marker.position = socket["p"]
		marker.rotation_degrees.y = socket["yaw"]
		marker.set_meta("asset_id", socket["id"])
		marker.set_meta("category", socket["category"])
		root.add_child(marker)
		if SHOW_PLANNING_LABELS:
			_add_visual_box(marker, "PlanningMarker", Vector3(0.0, 0.25, 0.0), Vector3(0.35, 0.5, 0.35), mat_plan_marker)
			_add_zone_label(marker, socket["id"], Vector3(0.0, 0.7, 0.0), Color("#8ee6ff"))

func _instance_park_asset(parent: Node3D, source: PackedScene, node_name: String, position_value: Vector3, yaw_degrees: float, scale_value: Vector3) -> Node3D:
	var instance := source.instantiate() as Node3D
	if instance == null:
		push_warning("Midori Park asset could not be instantiated: %s" % node_name)
		return null
	instance.name = node_name
	instance.position = position_value
	instance.rotation_degrees.y = yaw_degrees
	instance.scale = scale_value
	parent.add_child(instance)
	_configure_park_asset_visibility(instance)
	return instance

func _configure_park_asset_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = 145.0
	for child: Node in node.get_children():
		_configure_park_asset_visibility(child)

func _add_invisible_collision_box(parent: Node3D, node_name: String, position_value: Vector3, size_value: Vector3, yaw_degrees: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees.y = yaw_degrees
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

func _build_scale_ticks(parent: Node3D) -> void:
	for x_value: int in range(-100, 101, 20):
		_add_visual_box(parent, "SouthScaleTick_%d" % x_value, Vector3(float(x_value), 0.18, PARK_HALF.y - 1.0), Vector3(0.28, 0.28, 2.0), mat_entry)
		if x_value % 40 == 0:
			_add_zone_label(parent, "%d m" % x_value, Vector3(float(x_value), 0.75, PARK_HALF.y - 4.5), Color("#fff1ca"))

func _prepare_reference_vegetation() -> void:
	var broadleaf_specs: Array = [
		["Tree EZTree0.Large", 7.8], ["Tree EZTree0.Medium010", 6.4],
		["Tree EZTree0.Medium011", 6.1], ["Tree EZTree1.Large001", 7.4],
		["Tree EZTree1.Medium002", 6.0],
	]
	var pine_specs: Array = [
		["Pine_big_1_LOD1", 9.0], ["Pine_large_2_LOD1", 7.6],
		["Pine_medium_3_LOD1", 6.2],
	]
	var pine_sapling_specs: Array = [
		["Pine_sapling_1_LOD1", 3.0], ["Pine_sapling_2_LOD1", 2.7],
		["Pine_sapling_3_LOD1", 3.2],
	]
	var forest_floor_bush_specs: Array = [
		["Tree EZTree1.Bush006", 0.90],
	]
	var lilac_specs: Array = [
		["Lilac_bush_1_LOD1", 1.65], ["Lilac_bush_2_LOD1", 1.50],
	]
	var dense_grass_specs: Array = [
		["Grass1", 0.95], ["GrassLawnAutumn", 0.72], ["GrassAutumn3", 0.55],
	]
	for spec: Array in broadleaf_specs:
		var prototype := _extract_vegetation_prototype(BroadleafTreePack, spec[0], spec[1])
		if prototype != null:
			broadleaf_prototypes.append(prototype)
	for spec: Array in pine_specs:
		var prototype := _extract_vegetation_prototype(PineTreePack, spec[0], spec[1])
		if prototype != null:
			pine_prototypes.append(prototype)
	for spec: Array in pine_sapling_specs:
		var prototype := _extract_vegetation_prototype(PineTreePack, spec[0], spec[1])
		if prototype != null:
			pine_sapling_prototypes.append(prototype)
	for spec: Array in forest_floor_bush_specs:
		var prototype := _extract_vegetation_prototype(BroadleafTreePack, spec[0], spec[1])
		if prototype != null:
			forest_floor_bush_prototypes.append(prototype)
	for spec: Array in lilac_specs:
		var prototype := _extract_vegetation_prototype(LilacBushPack, spec[0], spec[1])
		if prototype != null:
			lilac_prototypes.append(prototype)
	for spec: Array in dense_grass_specs:
		var prototype := _extract_vegetation_prototype(DenseGrassPack, spec[0], spec[1])
		if prototype != null:
			_naturalize_dense_grass_prototype(prototype)
			dense_grass_prototypes.append(prototype)
	print("Midori reference vegetation: %d broadleaf | %d pine | %d pine sapling | %d floor bush | %d lilac | %d dense grass" % [
		broadleaf_prototypes.size(), pine_prototypes.size(), pine_sapling_prototypes.size(), forest_floor_bush_prototypes.size(), lilac_prototypes.size(), dense_grass_prototypes.size(),
	])
	deadwood_trunk_prototype = _extract_whole_scene_prototype(DeadwoodTrunkScene, "BeechDeadwood")
	hollow_bark_prototype = _extract_whole_scene_prototype(HollowBarkScene, "HeavyHollowBark")
	midnight_fern_prototype = _extract_whole_scene_prototype(MidnightFernScene, "MidnightFern")
	emerald_fountain_grass_prototype = _extract_whole_scene_prototype(EmeraldFountainGrassScene, "EmeraldFountainGrass")
	japanese_maple_prototype = _extract_mesh_prototype(JapaneseMapleMesh, "Free3DJapaneseMaple", 6.4)

func _extract_vegetation_prototype(pack: PackedScene, source_name: String, target_height: float) -> Node3D:
	var source_root := pack.instantiate() as Node3D
	if source_root == null:
		push_warning("Midori vegetation pack failed to instantiate: %s" % source_name)
		return null
	var source_node := _find_vegetation_source(source_root, source_name)
	if source_node == null:
		push_warning("Midori vegetation model not found: %s" % source_name)
		source_root.free()
		return null

	var retained_transform := _vegetation_relative_transform(source_node, source_root)
	var prototype := Node3D.new()
	prototype.name = source_name.replace(" ", "_").replace(".", "_")
	var content := Node3D.new()
	content.name = "Content"
	prototype.add_child(content)
	_clear_vegetation_owner(source_node)
	source_node.reparent(content, false)
	source_node.transform = retained_transform
	source_root.free()

	var bounds_data := _vegetation_visual_bounds(content)
	if not bounds_data["valid"]:
		prototype.free()
		return null
	var bounds: AABB = bounds_data["bounds"]
	var height_scale := target_height / maxf(bounds.size.y, 0.001)
	content.scale = Vector3.ONE * height_scale
	content.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	) * height_scale
	_configure_vegetation_visibility(content)
	return prototype

func _extract_whole_scene_prototype(pack: PackedScene, prototype_name: String) -> Node3D:
	var source_root := pack.instantiate() as Node3D
	if source_root == null:
		push_warning("Midori deadwood source failed to instantiate: %s" % prototype_name)
		return null
	var prototype := Node3D.new()
	prototype.name = prototype_name
	var content := Node3D.new()
	content.name = "Content"
	prototype.add_child(content)
	_clear_vegetation_owner(source_root)
	content.add_child(source_root)
	var bounds_data := _vegetation_visual_bounds(content)
	if not bounds_data["valid"]:
		prototype.free()
		return null
	var bounds: AABB = bounds_data["bounds"]
	content.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	)
	_configure_vegetation_visibility(content)
	return prototype

func _extract_mesh_prototype(mesh: Mesh, prototype_name: String, target_height: float) -> Node3D:
	if mesh == null:
		return null
	var bounds := mesh.get_aabb()
	if bounds.size.y <= 0.001:
		return null
	var prototype := Node3D.new()
	prototype.name = prototype_name
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	var scale_factor := target_height / bounds.size.y
	visual.position = -Vector3(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y,
		bounds.position.z + bounds.size.z * 0.5
	) * scale_factor
	visual.scale = Vector3.ONE * scale_factor
	prototype.add_child(visual)
	_configure_vegetation_visibility(visual)
	return prototype

func _naturalize_dense_grass_prototype(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# Hundreds of overlapping transparent blades were receiving and casting
		# near-black self-shadows. Keep their texture, but remove that artificial
		# occlusion while preserving ordinary light response.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate() as StandardMaterial3D
				material.ao_texture = null
				material.disable_receive_shadows = true
				material.metallic = 0.0
				material.metallic_specular = 0.15
				material.roughness = 0.94
				material.albedo_color = Color(0.82, 0.94, 0.78, 1.0)
				mesh_instance.set_surface_override_material(surface_index, material)
	for child: Node in node.get_children():
		_naturalize_dense_grass_prototype(child)

func _find_vegetation_source(root: Node, source_name: String) -> Node3D:
	var wanted := _normalized_vegetation_name(source_name)
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Node3D and _normalized_vegetation_name(str(current.name)) == wanted:
			return current as Node3D
		for child: Node in current.get_children():
			pending.append(child)
	return null

func _normalized_vegetation_name(value: String) -> String:
	return value.to_lower().replace(" ", "").replace(".", "").replace("_", "").replace("-", "")

func _clear_vegetation_owner(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_vegetation_owner(child)

func _vegetation_relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent_node := node.get_parent()
	while parent_node != null:
		if parent_node is Node3D:
			result = (parent_node as Node3D).transform * result
		if parent_node == ancestor:
			break
		parent_node = parent_node.get_parent()
	return result

func _vegetation_visual_bounds(root: Node3D) -> Dictionary:
	var combined := AABB()
	var has_bounds := false
	var pending: Array[Dictionary] = [{"node": root, "transform": Transform3D.IDENTITY}]
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_back()
		var current: Node = entry["node"]
		var current_transform: Transform3D = entry["transform"]
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh != null:
				var mesh_bounds: AABB = current_transform * mesh_instance.get_aabb()
				combined = mesh_bounds if not has_bounds else combined.merge(mesh_bounds)
				has_bounds = true
		for child: Node in current.get_children():
			var child_transform := current_transform
			if child is Node3D:
				child_transform = current_transform * (child as Node3D).transform
			pending.append({"node": child, "transform": child_transform})
	return {"valid": has_bounds, "bounds": combined}

func _add_reference_plant(
	parent: Node3D,
	prototypes: Array[Node3D],
	position_value: Vector3,
	scale_value: float,
	serial: int,
	node_prefix: String
) -> void:
	if prototypes.is_empty():
		return
	var instance := prototypes[posmod(serial, prototypes.size())].duplicate() as Node3D
	if instance == null:
		return
	instance.name = "%s_%03d" % [node_prefix, serial]
	instance.position = position_value
	if node_prefix.begins_with("ReferenceBroadleaf") or node_prefix.begins_with("ReferencePine") or node_prefix.begins_with("MicroGrove") or node_prefix.begins_with("MainlandPineSapling"):
		# Extracted prototypes already have their visual base at local Y=0. Settle
		# mainland trunks slightly into the lawn instead of floating 8–14 cm.
		instance.position.y = -0.035
	instance.rotation_degrees.y = fmod(float(serial) * 137.507, 360.0)
	instance.scale = Vector3.ONE * scale_value
	parent.add_child(instance)

func _add_reference_tree_cluster(
	parent: Node3D,
	center: Vector2,
	radius_value: float,
	count: int,
	serial_offset: int,
	strict_three_meter_spacing: bool = false,
	pine_stride: int = 9
) -> void:
	var placed := 0
	var attempt := 0
	while placed < count and attempt < count * 8:
		var radial_t := sqrt((float(attempt % count) + 0.42) / float(count))
		var angle := float(attempt) * 2.399963 + float(serial_offset) * 0.31
		var position_value := Vector3(
			center.x + cos(angle) * radius_value * radial_t,
			0.14,
			center.y + sin(angle) * radius_value * radial_t * 0.72
		)
		attempt += 1
		if not _is_vegetation_clear(position_value, 3.2):
			continue
		var serial := serial_offset * 20 + placed
		var scale_value := 0.82 + 0.055 * float(serial % 6)
		var safe_pine_stride := maxi(pine_stride, 3)
		var is_skinny_tree := serial % safe_pine_stride == 2
		var has_tree_spacing := (
			_is_tree_spaced(position_value, MATURE_TREE_MIN_SPACING_M)
			if strict_three_meter_spacing
			else _is_tree_spaced_for_type(position_value, is_skinny_tree)
		)
		if not has_tree_spacing:
			continue
		if is_skinny_tree:
			_add_reference_plant(parent, pine_prototypes, position_value, scale_value, serial, "ReferencePine")
		else:
			_add_reference_plant(parent, broadleaf_prototypes, position_value, scale_value, serial, "ReferenceBroadleaf")
		occupied_tree_positions.append(Vector2(position_value.x, position_value.z))
		occupied_tree_is_skinny.append(is_skinny_tree)
		placed += 1

func _is_tree_spaced(position_value: Vector3, minimum_distance: float) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	var minimum_distance_squared := minimum_distance * minimum_distance
	for occupied: Vector2 in occupied_tree_positions:
		if point.distance_squared_to(occupied) < minimum_distance_squared:
			return false
	return true

func _is_tree_spaced_for_type(position_value: Vector3, is_skinny_tree: bool) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	for occupied_index: int in range(occupied_tree_positions.size()):
		var occupied_is_skinny := (
			occupied_tree_is_skinny[occupied_index]
			if occupied_index < occupied_tree_is_skinny.size()
			else false
		)
		var minimum_distance := MATURE_TREE_MIN_SPACING_M
		if is_skinny_tree and occupied_is_skinny:
			minimum_distance = SKINNY_TO_SKINNY_MIN_SPACING_M
		elif is_skinny_tree or occupied_is_skinny:
			minimum_distance = SKINNY_TREE_MIN_SPACING_M
		if point.distance_squared_to(occupied_tree_positions[occupied_index]) < minimum_distance * minimum_distance:
			return false
	return true

func _distance_to_park_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * t)

func _is_vegetation_clear(position_value: Vector3, padding: float) -> bool:
	var point := Vector2(position_value.x, position_value.z)
	if absf(point.x) > PARK_HALF.x - padding or absf(point.y) > PARK_HALF.y - padding:
		return false
	# Straight circulation: perimeter loop, central spine, and main cross path.
	if absf(absf(point.x) - 97.0) < 2.5 + padding and absf(point.y) < 80.0:
		return false
	if absf(absf(point.y) - 77.0) < 2.5 + padding and absf(point.x) < 100.0:
		return false
	if absf(point.x + 37.0) < 2.5 + padding and absf(point.y) < 77.0:
		return false
	if absf(point.y - 42.0) < 2.5 + padding and absf(point.x) < 98.0:
		return false

	# Curved lake promenades use the same authored control points as the meshes.
	var promenade_sets: Array = [
		[Vector2(-37,42),Vector2(-27,31),Vector2(-23,14),Vector2(-27,-4),Vector2(-31,-24),Vector2(-37,-42)],
		[Vector2(43,42),Vector2(59,34),Vector2(72,21),Vector2(80,3),Vector2(80,-15),Vector2(84,-35),Vector2(78,-54),Vector2(76,-64)],
		[Vector2(-37,-42),Vector2(-18,-53),Vector2(5,-61),Vector2(28,-65),Vector2(47,-64),Vector2(65,-66),Vector2(76,-64)],
	]
	for promenade: Array in promenade_sets:
		for index: int in range(promenade.size() - 1):
			if _distance_to_park_segment(point, promenade[index], promenade[index + 1]) < 2.4 + padding:
				return false

	# Keep activity surfaces, plaza, pavilion, and all four entrances open.
	var reserved_rects: Array[Vector4] = [
		Vector4(-70,-43,30.7,21.2),Vector4(-72,45,20.0,17.0),
		Vector4(62,51,26.0,22.0),Vector4(76,-64,14.0,11.0),
		Vector4(0,86,11.0,7.0),Vector4(-38,-86,9.0,7.0),
		Vector4(-106,20,7.0,9.0),Vector4(106,-20,7.0,9.0),
	]
	for rect: Vector4 in reserved_rects:
		if absf(point.x - rect.x) < rect.z + padding and absf(point.y - rect.y) < rect.w + padding:
			return false
	return true

func _build_reference_canopy(parent: Node3D) -> void:
	var canopy_root := Node3D.new()
	canopy_root.name = "ArtworkReferenceCanopy"
	parent.add_child(canopy_root)
	# Dense outer woodland and the internal seams match the aerial reference while
	# preserving the sports field, playground, plaza, promenades, and entrances.
	var clusters: Array[Vector4] = [
		Vector4(-88,-85,6,8),Vector4(-66,-85,7,10),Vector4(-39,-85,7,10),
		Vector4(-10,-85,7,9),Vector4(20,-85,7,9),Vector4(86,-84,6,8),
		Vector4(-105,-58,5,8),Vector4(-105,-28,5,9),Vector4(-105,3,5,9),
		Vector4(-105,39,5,9),Vector4(-105,67,5,8),Vector4(-85,85,6,8),
		Vector4(-58,85,7,9),Vector4(-29,85,7,9),Vector4(4,85,7,8),
		Vector4(88,85,6,7),Vector4(105,58,5,7),Vector4(105,28,5,7),
		Vector4(105,4,5,7),Vector4(105,-42,5,8),Vector4(104,-68,5,7),
		Vector4(-51,-55,6,7),Vector4(-50,-27,6,8),Vector4(-50,1,6,7),
		Vector4(-50,26,6,7),Vector4(-52,58,6,8),Vector4(1,57,8,6),
		Vector4(35,57,8,6),Vector4(81,31,8,6),Vector4(84,-50,8,6),
	]
	for cluster_index: int in range(clusters.size()):
		var cluster := clusters[cluster_index]
		_add_reference_tree_cluster(
			canopy_root, Vector2(cluster.x, cluster.y), cluster.z,
			int(cluster.w), cluster_index
		)

	# Mainland infill groves occupy the large empty lawn panels seen from ground
	# level. These use a strict 3 m trunk spacing and a more frequent skinny pine
	# to break up the broadleaf rhythm without touching either lake island.
	var mainland_infill_clusters: Array[Vector4] = [
		Vector4(-86,-16,11,9),Vector4(-63,-14,10,8),
		Vector4(-86,17,11,9),Vector4(-63,18,10,8),
		Vector4(-28,61,11,9),Vector4(23,63,11,9),
		Vector4(-18,-66,11,9),Vector4(4,-69,10,8),
	]
	for cluster_index: int in range(mainland_infill_clusters.size()):
		var cluster := mainland_infill_clusters[cluster_index]
		_add_reference_tree_cluster(
			canopy_root, Vector2(cluster.x, cluster.y), cluster.z,
			int(cluster.w), 200 + cluster_index, true, 4
		)

	# Four small, hand-authored edge groves interrupt the remaining broad lawn
	# gaps without filling their centres. Uneven points avoid circular procedural
	# silhouettes; each group has exactly one skinny pine and strict 3 m spacing.
	var mainland_micro_groves: Array = [
		[
			Vector3(-28.2,0.14,-37.0),Vector3(-20.4,0.14,-33.7),
			Vector3(-26.6,0.14,-29.9),Vector3(-26.1,0.14,-33.7),
			Vector3(-20.0,0.14,-37.4),
		],
		[
			Vector3(-4.1,0.14,-46.3),Vector3(-10.5,0.14,-46.7),
			Vector3(-16.9,0.14,-44.7),Vector3(-16.6,0.14,-41.1),
			Vector3(-9.5,0.14,-42.3),
		],
		[
			Vector3(-69.8,0.14,6.0),Vector3(-78.3,0.14,-0.4),
			Vector3(-67.7,0.14,3.2),Vector3(-68.4,0.14,-1.7),
			Vector3(-77.1,0.14,4.1),
		],
		[
			Vector3(88.5,0.14,-12.7),Vector3(88.6,0.14,-18.9),
			Vector3(88.4,0.14,-9.2),Vector3(86.4,0.14,-16.1),
			Vector3(90.8,0.14,-16.1),
		],
	]
	var micro_grove_pine_indices: Array[int] = [1,3,0,2]
	for grove_index: int in range(mainland_micro_groves.size()):
		_add_authored_mainland_micro_grove(
			canopy_root, mainland_micro_groves[grove_index],
			micro_grove_pine_indices[grove_index], 600 + grove_index
		)
	_build_mainland_pine_saplings(canopy_root)

	# Each green island has a small vertical silhouette in the screenshot.
	var island_trees: Array[Vector4] = [
		Vector4(21,-13,0.86,0),Vector4(26,-10,0.74,1),Vector4(57,-37,0.72,1),
		Vector4(53,-35,0.68,0),Vector4(-10,19,0.72,0),Vector4(3,25,0.70,1),
		Vector4(46,19,0.78,0),Vector4(68,-4,0.76,1),
	]
	for index: int in range(island_trees.size()):
		var item := island_trees[index]
		var island_position := Vector3(item.x, 0.20, item.y)
		var is_skinny_tree := int(item.w) == 1
		if not _is_tree_spaced_for_type(island_position, is_skinny_tree):
			continue
		var prototypes: Array[Node3D] = pine_prototypes if is_skinny_tree else broadleaf_prototypes
		_add_reference_plant(
			canopy_root, prototypes, island_position,
			item.z, 800 + index, "IslandTree"
		)
		occupied_tree_positions.append(Vector2(island_position.x, island_position.z))
		occupied_tree_is_skinny.append(is_skinny_tree)

	var understory_root := Node3D.new()
	understory_root.name = "ArtworkLilacUnderstory"
	parent.add_child(understory_root)
	_add_mixed_tree_pair_shrubs(understory_root)

	# Irregular groups replace the former evenly spaced single-shrub lines. Each
	# mass stays within 5–7 plants and preserves a 1.3 m path-side shoulder.
	var shrub_clusters: Array[Vector4] = [
		Vector4(-82,-84,9,6),Vector4(-50,-84,9,6),Vector4(-17,-84,9,6),
		Vector4(16,-84,9,6),Vector4(78,-83,8,6),Vector4(-106,-48,7,6),
		Vector4(-106,-8,7,6),Vector4(-106,53,7,6),Vector4(-72,84,8,6),
		Vector4(-35,84,8,6),Vector4(3,84,8,6),Vector4(104,48,7,6),
		Vector4(104,8,7,6),Vector4(103,-48,7,6),Vector4(-52,-15,8,6),
		Vector4(-52,20,8,6),Vector4(-54,57,7,5),Vector4(2,56,7,5),
		Vector4(34,56,7,5),Vector4(86,-48,6,5),
		Vector4(-86,-16,12,7),Vector4(-63,-14,11,7),
		Vector4(-86,17,12,7),Vector4(-63,18,11,7),
		Vector4(-28,61,12,7),Vector4(23,63,12,7),
		Vector4(-18,-66,12,7),Vector4(4,-69,11,7),
	]
	for cluster_index: int in range(shrub_clusters.size()):
		var cluster := shrub_clusters[cluster_index]
		_add_reference_shrub_cluster(
			understory_root, Vector2(cluster.x, cluster.y), cluster.z,
			int(cluster.w), 1000 + cluster_index * 20
		)
	_build_mainland_groundcover_patches(parent)
	_build_mainland_meadow_transitions(parent)
	_build_forest_floor_bush_pockets(parent)
	_build_midnight_fern_pockets(parent)
	_build_emerald_grass_clusters(parent)

func _build_midnight_fern_pockets(parent: Node3D) -> void:
	if midnight_fern_prototype == null:
		return
	var root := Node3D.new()
	root.name = "MainlandMidnightFernPockets"
	parent.add_child(root)
	var centers: Array[Vector2] = [
		Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
		Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
		Vector2(-26,-34),Vector2(-11,-44),Vector2(-72,3),Vector2(87,-16),
	]
	var serial := 0
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		for plant_index: int in range(4):
			var angle := float(center_index) * 1.57 + float(plant_index) * 2.33
			var radius_value := 2.6 + float((center_index + plant_index * 2) % 4) * 1.2
			var position_value := Vector3(
				center.x + cos(angle) * radius_value,
				-0.015,
				center.y + sin(angle) * radius_value * 0.70
			)
			if not _is_vegetation_clear(position_value, 0.50):
				continue
			var fern := midnight_fern_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
			fern.name = "MidnightFern_%03d" % (serial + 1)
			fern.position = position_value
			fern.rotation_degrees.y = fmod(float(serial * 137 + center_index * 29), 360.0)
			fern.scale = Vector3.ONE * (0.42 + float((serial * 3 + center_index) % 6) * 0.055)
			root.add_child(fern)
			serial += 1

func _build_emerald_grass_clusters(parent: Node3D) -> void:
	if emerald_fountain_grass_prototype == null:
		return
	var root := Node3D.new()
	root.name = "MainlandEmeraldGrassClusters"
	parent.add_child(root)
	# Mid-height grass bridges the tiny clumps and knee-height shrubs. Uneven
	# 3–6 plant groups keep the supplied silhouette readable without carpeting
	# the park or repeating a regular scatter pattern.
	var clusters: Array[Vector4] = [
		Vector4(-91,-29,5.2,5),Vector4(-71,-24,4.8,4),
		Vector4(-91,31,5.6,6),Vector4(-65,34,4.4,3),
		Vector4(-36,59,5.0,5),Vector4(13,65,5.4,6),
		Vector4(-28,-66,4.7,4),Vector4(16,-70,5.2,5),
		Vector4(-19,-39,4.5,4),Vector4(84,-27,4.8,5),
	]
	var serial := 0
	for cluster_index: int in range(clusters.size()):
		var cluster := clusters[cluster_index]
		for plant_index: int in range(int(cluster.w)):
			var angle := float(cluster_index) * 1.83 + float(plant_index) * 2.399963
			var radius_value := 0.9 + sqrt(float(plant_index + 1) / cluster.w) * cluster.z
			var position_value := Vector3(
				cluster.x + cos(angle) * radius_value,
				-0.018,
				cluster.y + sin(angle) * radius_value * 0.68
			)
			if not _is_vegetation_clear(position_value, 0.62):
				continue
			var grass := emerald_fountain_grass_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
			grass.name = "EmeraldFountainGrass_%03d" % (serial + 1)
			grass.position = position_value
			grass.rotation_degrees.y = fmod(float(serial * 137 + cluster_index * 41), 360.0)
			var scale_value := 0.62 + float((serial * 5 + cluster_index) % 7) * 0.043
			grass.scale = Vector3.ONE * scale_value
			root.add_child(grass)
			serial += 1

func _build_forest_floor_bush_pockets(parent: Node3D) -> void:
	if forest_floor_bush_prototypes.is_empty():
		return
	var root := Node3D.new()
	root.name = "MainlandForestFloorBushPockets"
	parent.add_child(root)
	# Low woodland plants sit in uneven five-plant pockets around the main groves.
	# They remain decorative, avoid routes, and never form isolated specimen rows.
	var centers: Array[Vector2] = [
		Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
		Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
		Vector2(-26,-34),Vector2(-11,-44),Vector2(88,-15),Vector2(84,-49),
	]
	var serial := 0
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		for plant_index: int in range(5):
			var angle := float(center_index) * 1.43 + float(plant_index) * 2.17
			var radius_value := 2.1 + float((plant_index * 3 + center_index) % 5) * 1.05
			var position_value := Vector3(
				center.x + cos(angle) * radius_value,
				-0.018,
				center.y + sin(angle) * radius_value * 0.72
			)
			if not _is_vegetation_clear(position_value, 0.55):
				continue
			_add_reference_plant(
				root, forest_floor_bush_prototypes, position_value,
				0.72 + float((serial * 5 + center_index) % 6) * 0.045,
				5200 + serial, "ForestFloorBush"
			)
			serial += 1

func _build_mainland_pine_saplings(parent: Node3D) -> void:
	if pine_sapling_prototypes.is_empty():
		return
	var candidates: Array[Vector2] = [
		Vector2(-94,-31),Vector2(-91,-27),Vector2(-84,-29),Vector2(-76,-25),
		Vector2(-71,-5),Vector2(-67,-2),Vector2(-58,-5),Vector2(-56,-9),
		Vector2(-94,30),Vector2(-90,27),Vector2(-82,29),Vector2(-75,27),
		Vector2(-56,30),Vector2(-51,32),Vector2(-47,28),Vector2(-44,33),
		Vector2(-42,69),Vector2(-38,72),Vector2(-34,68),Vector2(-9,69),
		Vector2(11,71),Vector2(15,74),Vector2(30,70),Vector2(34,68),
		Vector2(-31,-73),Vector2(-27,-70),Vector2(-23,-74),Vector2(-10,-72),
		Vector2(12,-72),Vector2(16,-75),Vector2(22,-71),Vector2(29,-73),
	]
	var placed := 0
	for candidate_index: int in range(candidates.size()):
		if placed >= 16:
			break
		var point := candidates[candidate_index]
		var position_value := Vector3(point.x, 0.08, point.y)
		if not _is_vegetation_clear(position_value, 1.2):
			continue
		if not _is_tree_spaced_for_type(position_value, true):
			continue
		_add_reference_plant(
			parent, pine_sapling_prototypes, position_value,
			0.86 + float((candidate_index * 3) % 5) * 0.045,
			4200 + candidate_index, "MainlandPineSapling"
		)
		occupied_tree_positions.append(point)
		occupied_tree_is_skinny.append(true)
		placed += 1

func _add_authored_mainland_micro_grove(
	parent: Node3D,
	positions: Array,
	pine_index: int,
	serial_offset: int
) -> void:
	for point_index: int in range(positions.size()):
		var position_value: Vector3 = positions[point_index]
		if not _is_vegetation_clear(position_value, 3.2):
			push_warning("Midori micro-grove point entered a reserved route: %s" % position_value)
			continue
		if not _is_tree_spaced(position_value, MATURE_TREE_MIN_SPACING_M):
			push_warning("Midori micro-grove point is below 3 m trunk spacing: %s" % position_value)
			continue
		var is_skinny_tree := point_index == pine_index
		var prototypes: Array[Node3D] = pine_prototypes if is_skinny_tree else broadleaf_prototypes
		var serial := serial_offset * 20 + point_index
		var scale_value := 0.80 + 0.045 * float((point_index + serial_offset) % 6)
		_add_reference_plant(
			parent, prototypes, position_value, scale_value, serial,
			"MicroGrovePine" if is_skinny_tree else "MicroGroveBroadleaf"
		)
		occupied_tree_positions.append(Vector2(position_value.x, position_value.z))
		occupied_tree_is_skinny.append(is_skinny_tree)

func _build_mainland_groundcover_patches(parent: Node3D) -> void:
	if dense_grass_prototypes.is_empty():
		return
	var root := Node3D.new()
	root.name = "MainlandDenseGrassPatches_24"
	parent.add_child(root)
	# These are the mainland infill groves only. Three offset patches per grove
	# create a readable knee-height layer without raising the 18k clump count or
	# changing the lake islands.
	var centers: Array[Vector2] = [
		Vector2(-86,-16),Vector2(-63,-14),Vector2(-86,17),Vector2(-63,18),
		Vector2(-28,61),Vector2(23,63),Vector2(-18,-66),Vector2(4,-69),
	]
	var heavy_patch_serials: Array[int] = [2,8,15,21]
	var serial := 0
	for center_index: int in range(centers.size()):
		var center := centers[center_index]
		for patch_index: int in range(3):
			var angle := float(center_index) * 1.31 + float(patch_index) * 2.17
			var radius_value := 3.4 + float(patch_index) * 2.1
			var position_value := Vector3(
				center.x + cos(angle) * radius_value,
				0.025,
				center.y + sin(angle) * radius_value * 0.72
			)
			if not _is_vegetation_clear(position_value, 0.35):
				continue
			var is_heavy_patch := serial in heavy_patch_serials
			var prototype_index := 0 if is_heavy_patch else 1 + serial % maxi(dense_grass_prototypes.size() - 1, 1)
			prototype_index %= dense_grass_prototypes.size()
			var selected_prototypes: Array[Node3D] = [dense_grass_prototypes[prototype_index]]
			_add_reference_plant(
				root, selected_prototypes, position_value,
				(0.36 + float(serial % 3) * 0.035) if is_heavy_patch else (0.58 + float(serial % 4) * 0.055),
				3000 + serial,
				"MainlandDenseGrass"
			)
			serial += 1

func _build_mainland_meadow_transitions(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MainlandMeadowTransitions_25"
	parent.add_child(root)
	# Light fountain and meadow grasses bridge the visual gap between the 18k
	# near-ground clumps and the shrub/tree layer. Uneven groups avoid a tiled
	# field while leaving the important routes and open plaza readable.
	var clusters: Array[Vector4] = [
		Vector4(-89,-22,4.8,4),Vector4(-63,-8,4.2,3),
		Vector4(-90,22,4.6,4),Vector4(-59,23,4.0,3),
		Vector4(-31,66,4.8,4),Vector4(20,69,4.6,4),
		Vector4(-22,-70,4.4,4),Vector4(8,-73,4.1,4),
	]
	var serial := 0
	for cluster_index: int in range(clusters.size()):
		var cluster := clusters[cluster_index]
		for plant_index: int in range(int(cluster.w)):
			var angle := float(cluster_index) * 1.71 + float(plant_index) * 2.29
			var radius_value := 1.25 + float(plant_index % 3) * cluster.z * 0.42
			var position_value := Vector3(
				cluster.x + cos(angle) * radius_value,
				0.035,
				cluster.y + sin(angle) * radius_value * 0.68
			)
			if not _is_vegetation_clear(position_value, 0.55):
				continue
			var source := FountainGrassScene if (serial + cluster_index) % 3 == 0 else MeadowGrassScene
			var scale_value := 0.62 + float((serial * 7 + cluster_index) % 5) * 0.075
			_instance_park_asset(
				root, source, "VEG06_MainlandTransition_%02d" % (serial + 1),
				position_value, fmod(float(serial * 137 + cluster_index * 31), 360.0),
				Vector3.ONE * scale_value
			)
			serial += 1

func _build_deadwood_pass(parent: Node3D) -> void:
	if deadwood_trunk_prototype == null or hollow_bark_prototype == null:
		push_warning("Midori deadwood pass skipped because a staged source is unavailable")
		return
	var root := Node3D.new()
	root.name = "MainlandDeadwood_7Logs_5Stumps_1Hollow"
	parent.add_child(root)

	# The retopologized beech trunk is reused with varied proportions and angles
	# to form seven separate fallen pieces. Four of the longer pieces affect
	# movement; the smaller three remain decorative ground detail.
	var log_specs: Array[Vector4] = [
		Vector4(-82,-6,18,1.18),Vector4(-72,10,127,1.34),
		Vector4(-56,7,246,1.08),Vector4(-21,54,73,1.42),
		Vector4(10,57,311,1.24),Vector4(-4,-52,154,1.12),
		Vector4(87,-6,38,1.38),
	]
	for index: int in range(log_specs.size()):
		var spec := log_specs[index]
		var position_value := Vector3(spec.x, 0.48 + float(index % 3) * 0.025, spec.y)
		if not _is_vegetation_clear(position_value, SHRUB_PATH_CLEARANCE_M):
			push_warning("Midori fallen log entered a reserved route: %s" % position_value)
			continue
		var cross_scale := 0.38 + float(index % 4) * 0.025
		var log_instance := deadwood_trunk_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		log_instance.name = "FallenBeechLog_%02d" % (index + 1)
		log_instance.position = position_value
		log_instance.rotation_degrees = Vector3(0.0, spec.z, 90.0 + float(index % 3 - 1) * 2.5)
		log_instance.scale = Vector3(cross_scale, spec.w, cross_scale)
		root.add_child(log_instance)
		if index % 2 == 0:
			_add_deadwood_box_collision(
				root, "FallenLogCollision_%02d" % (index + 1), position_value,
				log_instance.rotation_degrees,
				Vector3(0.92, 2.72 * spec.w, 0.92)
			)

	# Upright copies retain the scanned root flare and read as broken stump bases.
	var stump_specs: Array[Vector4] = [
		Vector4(-88,64,42,0.52),Vector4(-60,0,173,0.62),
		Vector4(-16,56,286,0.48),Vector4(88,16,104,0.58),
		Vector4(-52,-8,229,0.54),
	]
	for index: int in range(stump_specs.size()):
		var spec := stump_specs[index]
		var position_value := Vector3(spec.x, -0.055, spec.y)
		if not _is_vegetation_clear(position_value, SHRUB_PATH_CLEARANCE_M):
			push_warning("Midori stump entered a reserved route: %s" % position_value)
			continue
		var stump_instance := deadwood_trunk_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		stump_instance.name = "BeechStump_%02d" % (index + 1)
		stump_instance.position = position_value
		stump_instance.rotation_degrees.y = spec.z
		stump_instance.scale = Vector3(0.46 + float(index % 3) * 0.035, spec.w, 0.46 + float(index % 3) * 0.035)
		root.add_child(stump_instance)
		if index in [0,1,3]:
			var stump_height := 2.78 * spec.w
			_add_deadwood_stump_collision(
				root, "StumpCollision_%02d" % (index + 1),
				position_value + Vector3(0.0, stump_height * 0.5, 0.0),
				0.58, stump_height
			)

	# The 220k-polygon hollow bark remains a single focal prop.
	var hollow_position := Vector3(-75.0, -0.065, -7.0)
	if _is_vegetation_clear(hollow_position, SHRUB_PATH_CLEARANCE_M):
		var hollow := hollow_bark_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
		hollow.name = "HeavyHollowBark_01"
		hollow.position = hollow_position
		hollow.rotation_degrees.y = 23.0
		hollow.scale = Vector3.ONE * 0.48
		root.add_child(hollow)
		_add_deadwood_box_collision(
			root, "HeavyHollowBarkCollision_01",
			hollow_position + Vector3(0.0, 0.38, 0.0), Vector3(0.0,23.0,0.0),
			Vector3(3.55,0.76,2.55)
		)

func _build_japanese_maple_pass(parent: Node3D) -> void:
	if japanese_maple_prototype == null:
		push_warning("Midori Japanese maple pass skipped because its source is unavailable")
		return
	var candidates: Array[Vector3] = [
		Vector3(-17.0,-0.055,52.0),Vector3(-8.0,-0.055,54.0),
		Vector3(-25.0,-0.055,53.0),Vector3(12.0,-0.055,53.0),
		Vector3(-17.0,-0.055,63.0),
	]
	var maple_position := Vector3.ZERO
	var found := false
	for candidate: Vector3 in candidates:
		if _is_vegetation_clear(candidate, 3.6) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
			maple_position = candidate
			found = true
			break
	if not found:
		push_warning("Midori Japanese maple has no clear authored position")
		return
	var root := Node3D.new()
	root.name = "JapaneseMapleAccents_1Of2"
	parent.add_child(root)
	var maple := japanese_maple_prototype.duplicate(DUPLICATE_USE_INSTANTIATION) as Node3D
	maple.name = "Free3DJapaneseMaple_01"
	maple.position = maple_position
	maple.rotation_degrees.y = 214.0
	root.add_child(maple)
	occupied_tree_positions.append(Vector2(maple_position.x, maple_position.z))
	occupied_tree_is_skinny.append(false)
	_add_deadwood_stump_collision(
		root, "JapaneseMapleCollision_01",
		maple_position + Vector3(0.0,1.25,0.0), 0.48, 2.5
	)

func _add_deadwood_box_collision(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	rotation_degrees_value: Vector3,
	size_value: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees = rotation_degrees_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

func _add_deadwood_stump_collision(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius_value: float,
	height_value: float
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius_value
	shape.height = height_value
	collision.shape = shape
	body.add_child(collision)

func _add_mixed_tree_pair_shrubs(parent: Node3D) -> void:
	# Give each skinny pine's nearest mature neighbour a soft three-bush pocket.
	# The asymmetric offsets fill the eye-level gap without forming a hedge line.
	var shrub_serial := 2000
	for skinny_index: int in range(occupied_tree_positions.size()):
		if skinny_index >= occupied_tree_is_skinny.size() or not occupied_tree_is_skinny[skinny_index]:
			continue
		var skinny_position := occupied_tree_positions[skinny_index]
		var nearest_mature := Vector2.ZERO
		var nearest_distance_squared := 5.5 * 5.5
		var found_mature := false
		for mature_index: int in range(occupied_tree_positions.size()):
			if mature_index == skinny_index:
				continue
			if mature_index < occupied_tree_is_skinny.size() and occupied_tree_is_skinny[mature_index]:
				continue
			var distance_squared := skinny_position.distance_squared_to(occupied_tree_positions[mature_index])
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				nearest_mature = occupied_tree_positions[mature_index]
				found_mature = true
		if not found_mature:
			continue
		var direction := (nearest_mature - skinny_position).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		var midpoint := (skinny_position + nearest_mature) * 0.5
		var bush_offsets: Array[Vector2] = [
			perpendicular * -0.58,
			perpendicular * 0.52 + direction * 0.18,
			direction * 0.72 + perpendicular * 0.10,
		]
		for offset: Vector2 in bush_offsets:
			var bush_point := midpoint + offset
			var bush_position := Vector3(bush_point.x, 0.12, bush_point.y)
			if not _is_vegetation_clear(bush_position, SHRUB_PATH_CLEARANCE_M):
				continue
			_add_reference_plant(
				parent, lilac_prototypes, bush_position,
				0.62 + float(posmod(shrub_serial * 7, 6)) * 0.06,
				shrub_serial, "MixedTreeGapBush"
			)
			shrub_serial += 1

func _add_reference_shrub_cluster(
	parent: Node3D,
	center: Vector2,
	radius_value: float,
	count: int,
	serial_offset: int
) -> void:
	var placed := 0
	var attempt := 0
	while placed < count and attempt < count * 8:
		var radial_t := sqrt((float(attempt % count) + 0.18) / float(count))
		var angle := float(attempt) * 2.399963 + float(serial_offset) * 0.017
		var position_value := Vector3(
			center.x + cos(angle) * radius_value * radial_t,
			0.11,
			center.y + sin(angle) * radius_value * radial_t * 0.72
		)
		attempt += 1
		if not _is_vegetation_clear(position_value, SHRUB_PATH_CLEARANCE_M):
			continue
		var serial := serial_offset + placed
		_add_reference_plant(
			parent, lilac_prototypes, position_value,
			0.58 + float(posmod(serial * 7, 6)) * 0.065,
			serial, "ReferenceLilacMass"
		)
		placed += 1

func _build_wildflower_groundcover(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ColorfulWildflowerMeadows"
	parent.add_child(root)
	var palettes: Array[Color] = [
		Color("#f2b9cf"), Color("#f0d978"), Color("#bfa7e8"),
		Color("#e8eee4"), Color("#e99a78"),
	]
	var transforms_by_color: Array = []
	for color: Color in palettes:
		transforms_by_color.append([])
	var stem_transforms: Array[Transform3D] = []
	var patches: Array[Vector4] = [
		Vector4(-78,7,15,55),Vector4(-70,68,13,45),Vector4(-18,18,13,50),
		Vector4(-12,55,12,45),Vector4(25,52,11,42),Vector4(67,73,10,36),
		Vector4(89,10,9,34),Vector4(87,-35,10,36),Vector4(8,-73,11,40),
		Vector4(45,-72,10,38),Vector4(70,-57,9,34),
	]
	var flower_serial := 0
	for patch: Vector4 in patches:
		var desired := int(patch.w)
		var placed := 0
		var attempt := 0
		while placed < desired and attempt < desired * 10:
			var radial_t := sqrt((float(attempt % desired) + 0.30) / float(desired))
			var angle := float(attempt) * 2.399963 + patch.x * 0.03
			var position_value := Vector3(
				patch.x + cos(angle) * patch.z * radial_t,
				0.0,
				patch.y + sin(angle) * patch.z * radial_t * 0.68
			)
			attempt += 1
			if not _is_vegetation_clear(position_value, 0.35):
				continue
			var height := 0.24 + 0.035 * float(flower_serial % 5)
			var head_transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.70 + 0.08 * float(flower_serial % 4))), position_value + Vector3(0,height,0))
			transforms_by_color[flower_serial % palettes.size()].append(head_transform)
			stem_transforms.append(Transform3D(Basis.IDENTITY, position_value + Vector3(0,height * 0.5,0)).scaled_local(Vector3(1,height / 0.30,1)))
			flower_serial += 1
			placed += 1

	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.012
	stem_mesh.bottom_radius = 0.015
	stem_mesh.height = 0.30
	stem_mesh.radial_segments = 5
	_add_flower_multimesh(root, "WildflowerStems", stem_mesh, stem_transforms, _make_material(Color("#496d3e"), 0.96))
	for color_index: int in range(palettes.size()):
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.095
		head_mesh.height = 0.13
		head_mesh.radial_segments = 6
		head_mesh.rings = 4
		_add_flower_multimesh(
			root, "WildflowerHeads_%d" % color_index, head_mesh,
			transforms_by_color[color_index], _make_material(palettes[color_index], 0.82)
		)

func _add_flower_multimesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	transforms: Array,
	material: Material
) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = 90.0
	parent.add_child(instance)

func _build_sakura_trees(parent: Node3D) -> void:
	var trees_root := Node3D.new()
	trees_root.name = "HandPlacedSakuraAccentTrees_%d" % SAKURA_TREE_COUNT
	parent.add_child(trees_root)
	occupied_tree_positions.clear()
	occupied_tree_is_skinny.clear()
	var placements: Array[Vector3] = [
		Vector3(-92.0, 0.0, -66.0), Vector3(-68.0, 0.0, -70.0), Vector3(-43.0, 0.0, -67.0),
		Vector3(-15.0, 0.0, -71.0), Vector3(15.0, 0.0, -70.0), Vector3(58.0, 0.0, -72.0),
		Vector3(94.0, 0.0, -62.0), Vector3(-103.0, 0.0, -42.0), Vector3(-92.0, 0.0, -12.0),
		Vector3(-93.0, 0.0, 18.0), Vector3(-92.0, 0.0, 48.0), Vector3(-90.0, 0.0, 70.0),
		Vector3(94.0, 0.0, -45.0), Vector3(93.0, 0.0, -12.0), Vector3(92.0, 0.0, 18.0),
		Vector3(94.0, 0.0, 48.0), Vector3(93.0, 0.0, 70.0), Vector3(-70.0, 0.0, 70.0),
		Vector3(-42.0, 0.0, 68.0), Vector3(-12.0, 0.0, 70.0), Vector3(18.0, 0.0, 69.0),
		Vector3(45.0, 0.0, 72.0), Vector3(70.0, 0.0, 72.0), Vector3(-30.0, 0.0, -45.0),
		Vector3(-30.0, 0.0, -15.0), Vector3(-22.0, 0.0, 18.0), Vector3(-12.0, 0.0, 32.0),
		Vector3(29.0, 0.0, 47.0), Vector3(58.0, 0.0, 31.0), Vector3(82.0, 0.0, 17.0),
		Vector3(86.0, 0.0, 5.0), Vector3(82.0, 0.0, -36.0), Vector3(55.0, 0.0, -53.0),
		Vector3(15.0, 0.0, -62.0), Vector3(-20.0, 0.0, -58.0), Vector3(-38.0, 0.0, 48.0),
		Vector3(-55.0, 0.0, -65.0), Vector3(-40.0, 0.0, -45.0), Vector3(-38.0, 0.0, -18.0),
		Vector3(-42.0, 0.0, 8.0), Vector3(-45.0, 0.0, 25.0), Vector3(-52.0, 0.0, 64.0),
		Vector3(-28.0, 0.0, 58.0), Vector3(2.0, 0.0, 58.0), Vector3(32.0, 0.0, 60.0),
		Vector3(90.0, 0.0, 35.0), Vector3(90.0, 0.0, -55.0), Vector3(30.0, 0.0, -70.0),
	]
	for index: int in range(mini(placements.size(), SAKURA_TREE_COUNT)):
		var scale_value: float = 0.80 + float(index % 7) * 0.04
		var tree_position := _clear_sakura_position(placements[index])
		var tree := SakuraTreeScene.instantiate() as Node3D
		tree.name = "DenseSakura_%02d" % (index + 1)
		tree.position = tree_position
		tree.rotation_degrees.y = fmod(float(index) * 137.5, 360.0)
		tree.scale = Vector3.ONE * scale_value
		trees_root.add_child(tree)
		_configure_vegetation_visibility(tree)
		_add_sakura_trunk_collision(trees_root, index, tree_position, scale_value)
		occupied_tree_positions.append(Vector2(tree_position.x, tree_position.z))
		occupied_tree_is_skinny.append(false)

func _clear_sakura_position(authored_position: Vector3) -> Vector3:
	if _is_vegetation_clear(authored_position, 3.6) and _is_tree_spaced(authored_position, MATURE_TREE_MIN_SPACING_M):
		return authored_position
	var offsets: Array[Vector3] = [
		Vector3(-9,0,0),Vector3(9,0,0),Vector3(0,0,-9),Vector3(0,0,9),
		Vector3(-9,0,-9),Vector3(9,0,-9),Vector3(-9,0,9),Vector3(9,0,9),
		Vector3(-15,0,0),Vector3(15,0,0),Vector3(0,0,-15),Vector3(0,0,15),
		Vector3(-20,0,-10),Vector3(20,0,-10),Vector3(-20,0,10),Vector3(20,0,10),
	]
	for offset: Vector3 in offsets:
		var candidate := authored_position + offset
		if _is_vegetation_clear(candidate, 3.6) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
			return candidate
	for ring: int in range(5, 16):
		var radius_value := float(ring) * 4.0
		for step: int in range(ring * 8):
			var angle := TAU * float(step) / float(ring * 8)
			var candidate := authored_position + Vector3(
				cos(angle) * radius_value, 0.0, sin(angle) * radius_value
			)
			if _is_vegetation_clear(candidate, 3.6) and _is_tree_spaced(candidate, MATURE_TREE_MIN_SPACING_M):
				return candidate
	push_warning("Midori sakura has no unoccupied park position near %s" % str(authored_position))
	return authored_position

func _add_sakura_trunk_collision(parent: Node3D, index: int, position_value: Vector3, scale_value: float) -> void:
	var body := StaticBody3D.new()
	body.name = "DenseSakuraCollision_%02d" % (index + 1)
	body.position = position_value + Vector3(0.0, 1.85 * scale_value, 0.0)
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.58 * scale_value
	shape.height = 3.7 * scale_value
	collision.shape = shape
	body.add_child(collision)

func _configure_vegetation_visibility(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = 150.0
	for child: Node in node.get_children():
		_configure_vegetation_visibility(child)

func _add_zone_box(parent: Node3D, node_name: String, center: Vector3, size_2d: Vector2, material: Material) -> void:
	_add_visual_box(parent, node_name, center, Vector3(size_2d.x, 0.07, size_2d.y), material)

func _add_cylinder_zone(parent: Node3D, node_name: String, center: Vector3, radii: Vector2, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.055
	mesh.radial_segments = 48
	mesh_instance.mesh = mesh
	mesh_instance.position = center
	mesh_instance.scale = Vector3(radii.x, 1.0, radii.y)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_zone_label(parent: Node3D, text_value: String, position_value: Vector3, color_value: Color) -> void:
	if not SHOW_PLANNING_LABELS:
		return
	var label := Label3D.new()
	label.name = text_value.replace(" ", "_")
	label.text = text_value
	label.position = position_value
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = 72
	label.pixel_size = 0.012
	label.modulate = color_value
	label.outline_modulate = Color(0.02, 0.03, 0.035, 0.92)
	label.outline_size = 10
	parent.add_child(label)

func _add_visual_box(parent: Node3D, node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_collidable_box(parent: Node3D, node_name: String, position_value: Vector3, size_value: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

func _spawn_scale_review_player() -> void:
	var player := PlayerScript.new()
	player.name = "ParkScaleReviewPlayer"
	player.position = Vector3(0.0, 0.05, PARK_HALF.y - 10.0)
	player.rotation.y = 0.0
	add_child(player)

func _build_size_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(22.0, 18.0)
	label.text = "MIDORI PARK — ARTWORK COMPOSITION PASS\n220 m x 180 m | fog-limited urban landmark park\n2 lake crossings | east viewing deck | 9 stone cover groups\n24 sakura accents | dense mainland groves | clustered understory\nProp sockets are planned and hidden until their assets arrive."
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#f4f1e8"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)

