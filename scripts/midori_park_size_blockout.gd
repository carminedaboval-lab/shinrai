extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const SakuraTreeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_sakura_winter_sentinel_clean_v2.glb")
const EvergreenShrubScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_evergreen_shrub_v1.glb")
const FountainGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_green_fountain_grass_v1.glb")
const MeadowGrassScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_swaying_meadow_grass_v1.glb")
const MossyBoulderScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/vegetation/midori_mossy_boulder_cluster_v1.glb")
const MainBridgeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_main_arched_bridge_v1.glb")
const SecondaryBridgeScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_secondary_footbridge_v1.glb")
const ViewingDeckScene: PackedScene = preload("res://assets/shinrai/parks/midori_park/models/structures/midori_lakeside_viewing_deck_v1.glb")

const PARK_SIZE_M := Vector2(220.0, 180.0)
const PARK_HALF := Vector2(PARK_SIZE_M.x * 0.5, PARK_SIZE_M.y * 0.5)
const LAKE_SIZE_M := Vector2(110.0, 72.0)
const SHOW_PLANNING_LABELS := false

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

func _ready() -> void:
	_create_materials()
	_create_environment()
	_build_park_footprint()
	_spawn_scale_review_player()
	_build_size_hud()
	print("Midori Park size blockout: %.0f m x %.0f m | diagonal %.1f m" % [
		PARK_SIZE_M.x, PARK_SIZE_M.y, PARK_SIZE_M.length()
	])

func _create_materials() -> void:
	mat_grass = _make_material(Color("#4a6a45"), 0.96)
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
	environment.ambient_light_color = Color("#b9c4c8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#9da9ac")
	environment.fog_light_energy = 0.78
	environment.fog_density = 0.0105
	environment.fog_sky_affect = 0.72
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "ParkReviewSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("#fff0d1")
	sun.light_energy = 1.25
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
	_build_evergreen_shrubs(root)

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
	root.name = "WatersideGrassClusters_36"
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

func _build_sakura_trees(parent: Node3D) -> void:
	var trees_root := Node3D.new()
	trees_root.name = "HandPlacedDenseSakuraTrees_48"
	parent.add_child(trees_root)
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
	for index: int in range(placements.size()):
		var scale_value: float = 0.80 + float(index % 7) * 0.04
		var tree := SakuraTreeScene.instantiate() as Node3D
		tree.name = "DenseSakura_%02d" % (index + 1)
		tree.position = placements[index]
		tree.rotation_degrees.y = fmod(float(index) * 137.5, 360.0)
		tree.scale = Vector3.ONE * scale_value
		trees_root.add_child(tree)
		_configure_vegetation_visibility(tree)
		_add_sakura_trunk_collision(trees_root, index, placements[index], scale_value)

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

func _build_evergreen_shrubs(parent: Node3D) -> void:
	var shrubs_root := Node3D.new()
	shrubs_root.name = "HandPlacedEvergreenShrubs_30"
	parent.add_child(shrubs_root)
	var placements: Array[Vector3] = [
		Vector3(-100.0, 0.02, -55.0), Vector3(-100.0, 0.02, -25.0), Vector3(-100.0, 0.02, 5.0),
		Vector3(-100.0, 0.02, 34.0), Vector3(-100.0, 0.02, 62.0), Vector3(100.0, 0.02, -52.0),
		Vector3(100.0, 0.02, -25.0), Vector3(100.0, 0.02, 5.0), Vector3(100.0, 0.02, 34.0),
		Vector3(100.0, 0.02, 62.0), Vector3(-36.0, 0.02, -38.0), Vector3(-35.0, 0.02, -5.0),
		Vector3(-28.0, 0.02, 28.0), Vector3(-10.0, 0.02, 44.0), Vector3(12.0, 0.02, 47.0),
		Vector3(38.0, 0.02, 45.0), Vector3(67.0, 0.02, 36.0), Vector3(88.0, 0.02, 24.0),
		Vector3(91.0, 0.02, -2.0), Vector3(88.0, 0.02, -28.0), Vector3(72.0, 0.02, -48.0),
		Vector3(48.0, 0.02, -58.0), Vector3(18.0, 0.02, -67.0), Vector3(-10.0, 0.02, -65.0),
		Vector3(-42.0, 0.02, -52.0), Vector3(-38.0, 0.02, -28.0), Vector3(-50.0, 0.02, 30.0),
		Vector3(-48.0, 0.02, 60.0), Vector3(38.0, 0.02, 63.0), Vector3(87.0, 0.02, 60.0),
	]
	for index: int in range(placements.size()):
		var scale_value: float = 0.78 + float(index % 6) * 0.065
		var shrub := EvergreenShrubScene.instantiate() as Node3D
		shrub.name = "EvergreenShrub_%02d" % (index + 1)
		shrub.position = placements[index]
		shrub.rotation_degrees.y = fmod(float(index) * 111.7, 360.0)
		shrub.scale = Vector3.ONE * scale_value
		shrubs_root.add_child(shrub)
		_configure_vegetation_visibility(shrub)

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
	label.text = "MIDORI PARK — ARTWORK COMPOSITION PASS\n220 m x 180 m | fog-limited urban landmark park\n2 lake crossings | east viewing deck | 9 stone cover groups\n48 sakura | 30 shrubs | 36 waterside grass clusters\nProp sockets are planned and hidden until their assets arrive."
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#f4f1e8"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)

