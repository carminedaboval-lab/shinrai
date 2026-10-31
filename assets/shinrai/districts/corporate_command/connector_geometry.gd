extends "district_geometry.gd"
## World-metre connection, parent at identity; the district itself is at (220,0,330).
const WALK_Y := 0.09
const ROAD_Y := 0.02
const SUPPORTED_RECTS: Array[Rect2] = [Rect2(32.5,180.5,144.5,17),Rect2(158.5,197.5,20,8.7)]
var report: Dictionary = {}
var asphalt: Material
var paint: Material
var _lamps: Array[OmniLight3D] = []
var _lamp_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("corporate_road_connection")
	asphalt = mat(Color("515c61"),0.94)
	var paving := mat(Color("969f99"),0.91)
	var subgrade := mat(Color("505b58"),0.95)
	paint = mat(Color("e2dfca"),0.8)
	var metal := mat(Color("334344"),0.65)
	_lamp_material = mat(Color("d9e3d5"),0.5,0.0)
	# Exact supported ground is narrow and remains completely outside park Z<=180.
	for i in range(SUPPORTED_RECTS.size()):
		var r := SUPPORTED_RECTS[i]
		slab("ConnectorFoundation%d"%i,r.position.x,r.end.x,r.position.y,r.end.y,-0.04,subgrade,0.42)
	slab("MainRoadContinuation",38.5,150,183,190,ROAD_Y,asphalt,0.06)
	_quad("RoadWidening",[Vector3(150,ROAD_Y,183),Vector3(162.5,ROAD_Y,183),Vector3(162.5,ROAD_Y,195),Vector3(150,ROAD_Y,190)],asphalt)
	slab("ConnectorTurn",162.5,174.5,183,195,ROAD_Y,asphalt,0.06)
	ramp("DistrictRoadTransition",Vector3(168.5,ROAD_Y,195),Vector3(168.5,-0.018,206.2),12,asphalt)
	# Existing east sidewalk is split in the guarded context candidate. Actual
	# one-metre ramps retain its pedestrian crossing without a hidden .09m lip.
	slab("NorthWalkWest",32.5,38.5,180.5,183,WALK_Y,paving,0.1)
	slab("NorthWalkCrossingBack",38.5,40.5,180.5,182,WALK_Y,paving,0.1)
	slab("NorthWalkEast",40.5,177,180.5,183,WALK_Y,paving,0.1)
	ramp("ExistingWalkNorthDrop",Vector3(39.5,WALK_Y,182),Vector3(39.5,ROAD_Y,183),2,paving)
	ramp("ExistingWalkSouthDrop",Vector3(39.5,ROAD_Y,190),Vector3(39.5,WALK_Y,191),2,paving)
	slab("SouthWalkCrossingReturn",38.5,40.5,191,192.5,WALK_Y,paving,0.1)
	slab("SouthWalkContinuation",40.5,150,190,192.5,WALK_Y,paving,0.1)
	_quad("SouthWalkWidening",[Vector3(150,WALK_Y,190),Vector3(162.5,WALK_Y,195),Vector3(160,WALK_Y,197.5),Vector3(150,WALK_Y,192.5)],paving)
	slab("EastTurnWalk",174.5,177,183,204,WALK_Y,paving,0.1)
	slab("WestTurnWalk",158.5,162.5,197.5,204,WALK_Y,paving,0.1)
	ramp("EastDistrictWalkTransition",Vector3(175.75,WALK_Y,204),Vector3(175.75,0,206.2),2.5,paving)
	ramp("WestDistrictWalkTransition",Vector3(160.5,WALK_Y,204),Vector3(160.5,0,206.2),4,paving)
	# The road remains open at both junctions. Thin markings are visual only.
	for x in range(56,156,8):
		box("ConnectorCentreDash",Vector3(3.1,.012,.12),Vector3(x,ROAD_Y+.008,186.5),paint,false)
	# The centre line follows the bend toward the district road.
	for degrees in [15.0,45.0,75.0]:
		var bend := deg_to_rad(degrees)
		var dash := box("ConnectorCentreDash",Vector3(3.1,.012,.12),Vector3(160.5+8.0*sin(bend),ROAD_Y+.008,194.5-8.0*cos(bend)),paint,false)
		dash.rotation.y = -bend
	for z in [183.45,189.55]:
		box("ConnectorEdgeLine",Vector3(107,.012,.1),Vector3(96,ROAD_Y+.008,z),paint,false)
	for i in range(7):
		box("ExistingWalkCrossing",Vector3(2.2,.012,.38),Vector3(39.5,ROAD_Y+.008,183.5+i*.9),paint,false)
	for x in [62.0,95.0,128.0,172.0]:
		var p := Vector3(x,0,181.05)
		box("ConnectionLampPole",Vector3(.10,4.7,.10),p+Vector3.UP*2.35,metal,false)
		box("ConnectionLampHead",Vector3(.65,.10,.26),p+Vector3.UP*4.72,paving,false)
		box("ConnectionLampLens",Vector3(.52,.035,.18),p+Vector3.UP*4.65,_lamp_material,false)
		_lamps.append(light(p+Vector3.UP*4.55,Color("e5dfc9"),2.5,10.0,false))
	for z in [183.1,192.4]:
		# Posts stand at the retained parcel-wall ends, outside the passage.
		box("OpeningMarker",Vector3(.12,.74,.12),Vector3(52.25,.37,z),metal,false)
	box("CorporateDirectionBoard",Vector3(3.3,.52,.10),Vector3(57.0,2.0,181.0),metal,false)
	sign_text("COMMAND DISTRICT  >",Vector3(57.0,2.0,181.07),0,2.9,Color("dce9df"))
	report = {"world_coordinates":true,"district_origin":Vector3(220,0,330),
		"supported_rectangles":SUPPORTED_RECTS,"road_start":Vector3(38.5,ROAD_Y,186.5),
		"road_corner":Vector3(168.5,ROAD_Y,186.5),"road_end":Vector3(168.5,-.018,206.2),
		"road_width_start_m":7.0,"road_width_end_m":12.0,"walkway_min_width_m":2.0,
		"road_opening":Rect2(38.5,180.5,13.5,12.5),"north_walk_extension":Rect2(32.5,180.5,6,2.5),
		"existing_east_wall_retained_z":[Vector2(174,180.5),Vector2(193,242)],
		"existing_walk_removed_z":Vector2(182,191),"existing_walk_replacement":"two 1m ramps and road crossing",
		"meshes":geometry_count,"colliders":collider_count,"scope":"new connector plus bounded context opening; no house or parking edits"}
	set_night_enabled(false)
	print("CORPORATE_CONNECTOR_READY meshes=",geometry_count," colliders=",collider_count," source_opening=38.5..52,180.5..193")

func _quad(label: String,corners: Array[Vector3],material: Material) -> void:
	var hull := PackedVector3Array()
	for point in corners:
		hull.append(point)
		hull.append(point-Vector3.UP*.10)
	var body := StaticBody3D.new()
	body.name = label
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	collider_count += 1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,2,1,0,3,2]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(corners[index])
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	body.add_child(mesh)
	geometry_count += 1

func contains_world_point(point: Vector3) -> bool:
	if not point.is_finite():
		return false
	for area in SUPPORTED_RECTS:
		if area.has_point(Vector2(point.x,point.z)):
			return true
	return false

func set_night_enabled(enabled: bool) -> void:
	for lamp in _lamps:
		lamp.light_energy = 2.5 if enabled else 0.0
	if _lamp_material != null:
		_lamp_material.emission_enabled = enabled
		_lamp_material.emission = Color("d9e3d5")
		_lamp_material.emission_energy_multiplier = .8 if enabled else 0.0

func get_route_waypoints(route: String = "to_tower") -> Array[Vector3]:
	# Starts on the retained park-side pavement, not inside an existing garden.
	var points: Array[Vector3] = [Vector3(30,WALK_Y,181.75),Vector3(34,WALK_Y,181.75),
		Vector3(55,WALK_Y,181.75),Vector3(170,WALK_Y,181.75),Vector3(176,WALK_Y,181.75),
		Vector3(176,WALK_Y,202),Vector3(176,WALK_Y,204),Vector3(176,0,206.2)]
	if route in ["to_tower","from_tower"]:
		points.append_array([Vector3(176.5,0,266),Vector3(178.2,0,270),Vector3(178.2,0,290),
			Vector3(176.5,0,294),Vector3(176.5,0,364),Vector3(240.15,0,364),Vector3(240.15,0,357.5)])
	if route in ["from_tower","from_district"]:
		points.reverse()
	return points
