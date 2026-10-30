extends RefCounted
## Original metre-scale connected parcels. New protected geometry only.
const Buildings = preload("res://scripts/midori_neighbourhood_buildings.gd")
const Architecture = preload("res://scripts/midori_south_street_architecture.gd")
const Finishes = preload("res://scripts/midori_court_finishes.gd")
const Landscape = preload("res://scripts/midori_south_street_landscape.gd")
const Ground = preload("res://scripts/midori_neighbourhood_ground.gd")
const AREA := Rect2(-52,174,104,68)
const CORPORATE_ROAD_OPENING := Rect2(38.5,180.5,13.5,12.5)

static func build(street: Node3D, landscape: Dictionary, neighbourhood: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "ConnectedNeighbourhoodContext"
	root.set_meta("creator_protected",true)
	root.set_meta("creator_editable",false)
	root.set_meta("source_provenance","Original constructed context; existing licensed materials and residential construction reused without modifying sources")
	street.add_child(root)
	# Full below-grade support also closes the original rear landscape's lateral
	# foundation gaps. Its top remains below all original finished surfaces.
	_part(street,root,"ConnectedContinuousSubgrade",Vector3(0,-.18,208),Vector3(104,.28,68),"land_joint",true)
	var supports: Array[Dictionary] = [{"rect":AREA,"top_y":-.04,"role":"continuous_supported_subgrade"}]
	var roads: Array[Rect2] = [Rect2(-38.5,183,6,43.5),Rect2(32.5,183,6,43.5),Rect2(-32.5,220.5,5,6),Rect2(27.5,220.5,5,6)]
	for i: int in range(roads.size()):
		_surface(street,root,"ConnectedAsphalt_%d"%i,roads[i],.02,"land_asphalt",supports)
	# Retain the east walk on both sides of the new main-road continuation.
	var walks: Array[Rect2] = [Rect2(-40.5,182,2,46),Rect2(38.5,191,2,37),Rect2(-52,226.5,24.5,1.5),Rect2(27.5,226.5,24.5,1.5),Rect2(-41.5,208.0,3,1.5),Rect2(40.5,228,7.5,0.5)]
	var pavers := 0
	for i: int in range(walks.size()):
		pavers += Landscape._paving(street,root,walks[i],920+i)
		supports.append({"rect":walks[i],"top_y":.09,"role":"context_paved_walk"})
	# Land is modelled around real footprints rather than across routes or roofs.
	var footprints: Array[Rect2] = [Rect2(-50.5,207.4,9,7.2),Rect2(40.4,228.5,7.2,9)]
	var exclusions: Array[Rect2] = roads.duplicate()
	exclusions.append_array(walks)
	exclusions.append_array(footprints)
	# Connector owns this small opening's support and ramps. Existing foliage
	# producers already require whole crowns to fit remaining soil rectangles.
	exclusions.append(CORPORATE_ROAD_OPENING)
	exclusions.append(Rect2(32.5,180.5,6,2.5))
	var soil: Array[Rect2] = []
	for strip: Rect2 in [Rect2(-52,174,24.5,68),Rect2(27.5,174,24.5,68)]:
		soil.append_array(Ground._difference_rects(strip,exclusions))
	for i: int in range(soil.size()):
		_surface(street,root,"ContextSoil_%d"%i,soil[i],-.015,"court_forest_soil",supports)
	var garden_edges := _parcel_garden_edges(street,root,soil)
	# Outer parcel boundaries stay low and have genuine returns; no horizon screen.
	for side: float in [-1.0,1.0]:
		var boundary_spans: Array[Vector2] = []
		if side < 0:
			boundary_spans.append(Vector2(174,242))
		else:
			boundary_spans.append(Vector2(174,180.5))
			boundary_spans.append(Vector2(193,242))
		for span: Vector2 in boundary_spans:
			_part(street,root,"OuterGardenBoundary",Vector3(side*51.85,.23,(span.x+span.y)*.5),Vector3(.22,.54,span.y-span.x),"land_curb",true)
			_part(street,root,"OuterBoundaryCoping",Vector3(side*51.85,.52,(span.x+span.y)*.5),Vector3(.28,.045,span.y-span.x),"arch_stone",false)
		# Side street inner kerb stops at both junctions and never crosses a route.
		for span: Vector2 in [Vector2(190.15,218.45)]:
			_curb(street,root,side*32.44,span.x,span.y)
		# Flush outer edge permits easy access to the broad pedestrian strip.
		for span: Vector2 in [Vector2(183,220.5),Vector2(226.5,228)]:
			_gutter_run(street,root,side*38.4,span.x,span.y)
		# Quiet lane now terminates in a connected north-south street, with a
		# modest planted parcel beyond the road instead of a dead-end barrier.
		_part(street,root,"NorthParcelReturn",Vector3(side*45.5,.18,174.15),Vector3(12.8,.44,.22),"land_curb",true)
	var buildings: Array[Dictionary] = []
	buildings.append(_building(street,root,{"id":"WestCornerWorkshopResidence","x":-41.5,"z":211.0,"height":5.85,"rise":.48,"door":-2.25,"wall":"arch_mineral","roof":"mono","cedar":true},-PI*.5,footprints[0]))
	buildings.append(_building(street,root,{"id":"EastGardenResidence","x":44.0,"z":228.5,"height":6.05,"rise":1.1,"door":-2.25,"wall":"arch_plaster","roof":"gable","cedar":false},0.0,footprints[1]))
	var counts := _counts(root)
	var report := {"ok":true,"root":root,"bounds":AREA,"added_walkable_rects":roads+walks,"road_rectangles":roads,"paved_rectangles":walks,"supports":supports,"soil_rectangles":soil,"garden_edge_rectangles":garden_edges,"soil_material":"court_forest_soil","soil_support_top_y":-.015,"building_footprints":footprints,"buildings":buildings,"physical_members":counts.solids,"mesh_members":counts.meshes,"paver_count":pavers,"source_assets_modified":false,"original_buildings_modified":false,"creator_protected":true,"routes":{"west_main_to_lane":[Vector3(-35.5,.02,186.5),Vector3(-35.5,.02,223.5),Vector3(-24,.02,223.5)],"east_main_to_lane":[Vector3(35.5,.02,186.5),Vector3(35.5,.02,223.5),Vector3(24,.02,223.5)],"west_entry":Vector3(-41.12,.09,208.75),"east_entry":Vector3(41.75,.09,228.12)},"barriers_parent_must_remove":["NeighbourhoodGround/LaneEndWall at X=-27.35","NeighbourhoodGround/LaneEndWall at X=27.35"],"source_provenance":"Original geometry; existing Buildings shell/roof and licensed CourtFinishes; no source resources edited"}
	report["corporate_road_opening"] = CORPORATE_ROAD_OPENING
	# Publish only extents backed by the continuous physical subgrade above.
	var original_landscape_bounds: Rect2 = landscape.get("world_bounds",Rect2(-32.5,180,65,40))
	var minimum_z := minf(174.0,original_landscape_bounds.position.y)
	# Do not enlarge towards an existing sampled approach beyond our foundation.
	if minimum_z < 174.0:
		report["preserved_approach_minimum_z"] = minimum_z
	landscape["world_bounds"] = Rect2(-52,174,104,46)
	landscape["bounds"] = landscape["world_bounds"]
	neighbourhood["bounds"] = Rect2(-52,218.5,104,23.5)
	root.set_meta("context_construction",{"bounds":AREA,"supports":supports,"building_footprints":footprints,"creator_protected":true,"mesh_members":counts.meshes,"physical_members":counts.solids})
	return report

static func _part(street: Node3D,parent: Node3D,label: String,pos: Vector3,size: Vector3,key: String,collision: bool) -> void:
	street.call("_box",parent,label,pos,size,key,collision)

static func _surface(street: Node3D,parent: Node3D,label: String,rect: Rect2,top: float,key: String,supports: Array[Dictionary]) -> void:
	_part(street,parent,label,Vector3(rect.get_center().x,top-.025,rect.get_center().y),Vector3(rect.size.x,.05,rect.size.y),key,true)
	supports.append({"rect":rect,"top_y":top,"role":key})

## Precast flush gutter laid in 0.9m units with 8mm joints, instead of one
## 37.5m box whose stretched texture read as an elongated drain.
static func _gutter_run(street: Node3D,parent: Node3D,x: float,z0: float,z1: float) -> void:
	var z := z0
	while z < z1-.001:
		var length := minf(.9,z1-z)
		_part(street,parent,"FlushGutterUnit",Vector3(x,.025,z+length*.5),Vector3(.18,.01,length-.008),"land_gutter",false)
		z += length

static func _curb(street: Node3D,parent: Node3D,x: float,z0: float,z1: float) -> void:
	var z := z0
	while z < z1-.001:
		var length := minf(.9,z1-z)
		_part(street,parent,"ContextKerbUnit",Vector3(x,.045,z+length*.5),Vector3(.12,.09,length-.008),"land_curb",true)
		z += length

static func _building(street: Node3D,parent: Node3D,spec: Dictionary,yaw: float,footprint: Rect2) -> Dictionary:
	var house := Node3D.new()
	house.name = String(spec.id)
	house.position = Vector3(float(spec.x),.09,float(spec.z))
	house.rotation.y = yaw
	house.set_meta("creator_protected",true)
	house.set_meta("creator_editable",false)
	house.set_meta("creator_object_kind","building")
	parent.add_child(house)
	Buildings._shell(street,house,spec)
	Buildings._roof(street,house,spec)
	if String(spec.id) == "WestCornerWorkshopResidence":
		_workshop_pier(street,house)
	Finishes.apply(street,house)
	var counts := _counts(house)
	return {"id":spec.id,"footprint":footprint,"position":house.position,"yaw":yaw,"enterable":false,"mesh_members":counts.meshes,"physical_members":counts.solids,"construction":"closed shell, full roof, deep front/side/rear windows, eaves, gutters and downpipes"}

static func _counts(node: Node) -> Dictionary:
	var result := {"meshes":int(node is MeshInstance3D),"solids":int(node is StaticBody3D)}
	for child: Node in node.get_children():
		var sub := _counts(child)
		result.meshes += int(sub.meshes)
		result.solids += int(sub.solids)
	return result




static func _parcel_garden_edges(street: Node3D,parent: Node3D,soils: Array[Rect2]) -> Array[Rect2]:
	var edges: Array[Rect2] = []
	# Slim embedded stone margins make the outer gardens deliberate parcels.
	# Intersect with actual soil to retain every path and building opening.
	var candidates: Array[Rect2] = [Rect2(-40.59,182,.09,46),Rect2(40.50,182,.09,44.5),Rect2(-52,228,24.5,.09),Rect2(27.5,228,24.5,.09)]
	for desired: Rect2 in candidates:
		for soil: Rect2 in soils:
			var edge := desired.intersection(soil)
			if not edge.has_area(): continue
			edges.append(edge)
			# Base touches soilY-.015; top .045 remains below pavementY .09.
			_part(street,parent,"EmbeddedParcelGardenMargin",Vector3(edge.get_center().x,.015,edge.get_center().y),Vector3(edge.size.x,.06,edge.size.y),"land_curb",false)
	return edges

static func _workshop_pier(street: Node3D,house: Node3D) -> void:
	# Existing masonry right pier carries the drained cedar field; window/door
	# openings and all collision envelopes remain precisely as constructed.
	Architecture._clad_wall(street,house,"WorkshopCedarPier",Vector3(2.92,1.65,-.05),Vector3(.9,2.5,.12))
	_part(street,house,"WorkshopCladdingBaseDrip",Vector3(2.92,.39,-.065),Vector3(.96,.04,.16),"arch_metal",false)
	_part(street,house,"WorkshopCladdingHeadCap",Vector3(2.92,2.92,-.065),Vector3(.96,.04,.16),"arch_metal",false)
	for x: float in [2.435,3.405]:
		_part(street,house,"WorkshopCedarEdgeBatten",Vector3(x,1.65,-.065),Vector3(.045,2.5,.15),"arch_cedar",false)
	_part(street,house,"WorkshopMakerNameplate",Vector3(2.92,1.76,-.15),Vector3(.59,.18,.035),"arch_metal",false)
	street.call("_text",house,"WorkshopMakerLettering","KADO / STUDIO",Vector3(2.92,1.76,-.17),.034,Color("#dfd8c5"))
	house.set_meta("context_workshop_frontage",{"cladding_bounds":AABB(Vector3(2.4125,.37,-.1875),Vector3(1.015,2.57,.2225)),"bearing":"original solid right masonry pier","original_windows_retained":13,"entrance_unchanged":true,"new_collision":0})


