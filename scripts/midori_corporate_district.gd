extends Node3D
## Corporate expansion in world metres; never parent this to the 2x park layout.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const Geometry = preload("res://assets/shinrai/districts/corporate_command/district_geometry.gd")
const StreetEdges = preload("res://scripts/midori_corporate_street_edges.gd")
const WalkPaving = preload("res://scripts/midori_corporate_paving.gd")
const Trees = preload("res://scripts/midori_corporate_trees.gd")
const Lawn = preload("res://scripts/midori_corporate_lawn.gd")
const Planting = preload("res://scripts/midori_corporate_planting.gd")
const GardenFeatures = preload("res://scripts/midori_corporate_garden_features.gd")
const PACKAGE := "res://assets/shinrai/districts/corporate_command/"
const ORIGIN := Vector3(220,0,330)
const DISTRICT_FOOTPRINT := Rect2(60,190,320,280)

var installed := false
var report: Dictionary = {}
var park: Node3D
var parcel: Node3D
var district: Node3D
var tower: Node3D
var connector: Node3D
var interactions: Node
var _night := false

func _ready() -> void:
	park = get_parent() as Node3D
	set_meta("creator_protected",true)
	set_meta("creator_editable",false)
	await Budget.wait_structure(park)
	var street := park.get_node_or_null("MidoriSouthStreet")
	while street != null and street.get("installed") != true:
		await get_tree().process_frame
	Budget.stage(park,"Connecting the corporate neighbourhood")
	parcel = Geometry.new()
	parcel.name = "CorporateParcel"
	parcel.position = ORIGIN
	add_child(parcel)
	# Continuous solid ground supports every road, plaza, lobby and stair gateway.
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://assets/shinrai/districts/corporate_command/wet_paving.gdshader")
	var platform: MeshInstance3D = parcel.box("DistrictSupportedGround",Vector3(320,.5,280),Vector3(0,-.285,0),ground)
	platform.layers = 2
	district = load(PACKAGE+"district.tscn").instantiate()
	parcel.add_child(district)
	await Budget.checkpoint(park)
	tower = load(PACKAGE+"building.tscn").instantiate()
	parcel.add_child(tower)
	connector = load(PACKAGE+"connector_geometry.gd").new()
	connector.name = "CorporateRoadConnection"
	add_child(connector)
	await Budget.checkpoint(park)
	# Every road here wears the main street's real asphalt and paint.
	var street_mats: Dictionary = street.get("materials")
	_replace_material(district,district.get("asphalt"),street_mats.land_asphalt)
	district.set("asphalt",street_mats.land_asphalt)
	_replace_material(connector,connector.get("asphalt"),street_mats.land_asphalt)
	_replace_material(connector,connector.get("paint"),street_mats.land_paint)
	# Curbs, gutters and gullies along the district streets and the connector,
	# in the main street's precast finish.
	var street_edges: Dictionary = StreetEdges.build(self, street, parcel)
	await Budget.checkpoint(park)
	var walk_paving: Dictionary = WalkPaving.build(self, street, parcel, district)
	await Budget.checkpoint(park)
	var trees: Dictionary = Trees.plant(district)
	await Budget.checkpoint(park)
	_replace_material(district,district.get("leaf"),Lawn.surface())
	var lawn: Dictionary = Lawn.grow(district)
	await Budget.checkpoint(park)
	var planting: Dictionary = Planting.plant(district)
	await Budget.checkpoint(park)
	var garden_features: Dictionary = GardenFeatures.build(district)
	await Budget.checkpoint(park)
	interactions = load(PACKAGE+"shinrai_interactions.gd").new()
	interactions.name = "CorporateTraversalInteractions"
	# Children receive input before their raid parent, so Escape closes this
	# panel before the raid can interpret the same press as its pause command.
	var raid := park.get_node_or_null("ExtractionRun")
	while raid == null:
		await get_tree().process_frame
		raid = park.get_node_or_null("ExtractionRun")
	raid.add_child(interactions)
	interactions.configure(park,tower)
	_night = park.get("is_night_mode") == true
	_sync_lighting()
	report = {"origin":ORIGIN,"scale":Vector3.ONE,"yaw_degrees":0.0,
		"world_bounds":DISTRICT_FOOTPRINT,"road_connection":connector.get("report"),
		"tower_floors":8,"garage_levels":3,"police_station":true,
		"context_buildings":12,"source_revision":5,"player_access":true,
		"enemy_navigation_extended":false}
	report["street_edges"] = street_edges
	report["walk_paving"] = walk_paving
	report["trees"] = trees
	report["lawn"] = lawn
	report["planting"] = planting
	report["garden_features"] = garden_features
	installed = true
	add_to_group("midori_corporate_district")
	print("MIDORI_CORPORATE_DISTRICT_READY origin=",ORIGIN," scale=1 garage_levels=3 police=1 road_connected=true")

func _replace_material(node: Node,from: Material,to: Material) -> void:
	if node is GeometryInstance3D and node.material_override == from:
		node.material_override = to
	for child: Node in node.get_children():
		_replace_material(child,from,to)

func contains_world_point(point: Vector3) -> bool:
	if not installed or not point.is_finite(): return false
	var flat := Vector2(point.x,point.z)
	if DISTRICT_FOOTPRINT.has_point(flat): return true
	return connector.contains_world_point(point) if is_instance_valid(connector) else false

func get_route_waypoints(route: String) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not installed or route not in ["park_to_district","district_to_park"]: return points
	# From the original southern park insertion, use the existing exit and
	# park-side pavement before following the supported connector walkway.
	# Stay between the fitted planting beds and the existing raised kerb.
	points = [Vector3(0,.12,171),Vector3(0,.09,181.75),
		Vector3(0,.09,182.35),Vector3(30,.09,182.35)]
	points.append_array(connector.get_route_waypoints("to_tower"))
	if route == "district_to_park": points.reverse()
	return points

func _process(_delta: float) -> void:
	if not installed: return
	var night: bool = park.get("is_night_mode") == true
	if night != _night:
		_night = night
		_sync_lighting()

func _sync_lighting() -> void:
	district.set_night_enabled(_night)
	tower.get_node("ArchitecturalLighting").set_night_enabled(_night)
	if connector.has_method("set_night_enabled"): connector.set_night_enabled(_night)
