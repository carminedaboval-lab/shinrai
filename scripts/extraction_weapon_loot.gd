extends RefCounted
## Fictional loot tiers, not real-world armour or firearm classifications.
const Supply=preload("./extraction_weapon_supplies.gd")
const TIERS=Supply.TIERS
const Context=preload("./extraction_context_loot.gd")
const Containers=preload("./extraction_loot_containers.gd")
## Cases are placed after navigation is built, so they must not sit on a route.
## Most routes run along the sides and diagonals of the 4 m grid. These insets are
## the pockets between those lines, where a case lying along X clears them. Links
## such as bridge joins ignore that pattern, so the real routes are measured too.
const LANE_INSETS: Array[float] = [0.83, 3.17]
const LANE_CENTRE := 2.0
const CASE_HALF := Vector2(0.5, 0.2)
## The AI capsule is 0.42 m in radius, so this leaves it room to pass.
const MIN_ROUTE_GAP := 0.5
const ROUTE_SAMPLE_M := 0.25
## Far enough that E beside a lamp recovers the relay, not the case.
const MIN_RELAY_GAP := 3.5
## Far enough that no case hides another from the player's eye line.
const MIN_CASE_GAP := 2.6
const MIN_PATH_GAP := 0.9
const SEARCH_CELLS := 5
const APPROACH := Vector3(0, 0, -1.2)
const EYE_HEIGHT := 1.58

static func install(raid: Node) -> int:
	var relays: Array = raid.sites.filter(func(site: Dictionary)->bool:return site.get("kind","")=="relay")
	var ids: Array[String] = ["uzi","shigure","kite","raiden_r56","tobikage","hayate","yuzuru"]
	if relays.is_empty(): return 0
	var installed := 0
	var taken: Array[Vector2] = []
	for index: int in range(ids.size()):
		var id := ids[index]
		var site_id := "security_arms_"+id
		if raid.sites.any(func(site: Dictionary)->bool:return site.id==site_id):continue
		var origin: Vector3 = relays[index % relays.size()].position
		var preferred: Vector3 = origin+Vector3(2.5+2.4*floori(float(index)/float(relays.size())),0,1.5)
		var spot: Variant = _find_spot(raid,preferred,relays,taken)
		if spot == null:
			push_warning("WEAPON_LOOT: no clear spot for "+site_id)
			continue
		var location: Vector3 = spot
		taken.append(Vector2(location.x,location.z))
		var anchor := Node3D.new()
		anchor.name = "SecuritySupplyAnchor_"+id
		raid.park.add_child(anchor)
		anchor.global_transform = Transform3D(Basis.IDENTITY,location)
		var case_spec := {"id":site_id,"at":Vector3.ZERO,"style":"tool","label":"SECURITY · TIER %d" % int(TIERS[id])}
		var model: Node3D = Context._case(anchor,case_spec)
		model.scale = Vector3(1.6,1,1)
		var context := "security_"+id
		# Guns and magazines are generated only by the residential spawner.
		raid.sites.append({"id":site_id,"title":"Search security supply case","container_title":str(case_spec.label),"empty_title":"Empty security supply case","kind":"cache","position":model.global_position+Vector3(0,.2,0),"container_type":Containers.CONTEXT_TYPE,"loot_context":context,"guaranteed":[Supply.ammunition_id(id)]+(["optic_scope_01"] if id in ["hayate","yuzuru"] else []),"prop_node":model,"approach":location+APPROACH,"spawn_chance":1.0,"ammo_bonus":0,"done":true,"spawned":false,"discovered":false,"contents":[],"loot":{}})
		installed += 1
	return installed

## The nearest clear pocket to where the case would like to be, or null.
static func _find_spot(raid: Node, preferred: Vector3, relays: Array, taken: Array[Vector2]) -> Variant:
	var cell: float = raid.navigation.CELL
	var grid_origin: Vector2 = raid.navigation.ORIGIN
	var base := ((Vector2(preferred.x,preferred.z)-grid_origin)/cell).floor()
	var candidates: Array[Vector2] = []
	for z: int in range(-SEARCH_CELLS,SEARCH_CELLS+1):
		for x: int in range(-SEARCH_CELLS,SEARCH_CELLS+1):
			var corner := grid_origin+(base+Vector2(x,z))*cell
			for inset: float in LANE_INSETS:
				candidates.append(corner+Vector2(LANE_CENTRE,inset))
	var wanted := Vector2(preferred.x,preferred.z)
	candidates.sort_custom(func(a: Vector2, b: Vector2)->bool:return a.distance_squared_to(wanted)<b.distance_squared_to(wanted))
	var routes: Array[PackedVector2Array] = _routes_near(raid,wanted,cell*float(SEARCH_CELLS+3))
	for point: Vector2 in candidates:
		var location: Variant = _clear_spot(raid,point,relays,taken,routes)
		if location != null: return location
	return null

## Every graph edge near a point, read once per case rather than per candidate.
static func _routes_near(raid: Node, centre: Vector2, radius: float) -> Array[PackedVector2Array]:
	var graph: AStar2D = raid.navigation.walk_graph
	var routes: Array[PackedVector2Array] = []
	for id: int in graph.get_point_ids():
		var a: Vector2 = graph.get_point_position(id)
		if a.distance_to(centre) > radius: continue
		for link: int in graph.get_point_connections(id):
			if link > id: routes.append(PackedVector2Array([a,graph.get_point_position(link)]))
	return routes

## Shortest distance from any route to the case footprint at this point.
static func _route_gap(point: Vector2, routes: Array[PackedVector2Array]) -> float:
	var gap := INF
	for route: PackedVector2Array in routes:
		var steps := maxi(1,ceili(route[0].distance_to(route[1])/ROUTE_SAMPLE_M))
		for step: int in range(steps+1):
			var outside: Vector2 = (route[0].lerp(route[1],float(step)/float(steps))-point).abs()-CASE_HALF
			gap = minf(gap,Vector2(maxf(outside.x,0.0),maxf(outside.y,0.0)).length())
	return gap

## Returns the supported ground position, or null when anything rules it out.
static func _clear_spot(raid: Node, point: Vector2, relays: Array, taken: Array[Vector2], routes: Array[PackedVector2Array]) -> Variant:
	var park: Node3D = raid.park
	var navigation = raid.navigation
	if navigation.is_water(point) or is_finite(float(park.bridge_surface_height(point))): return null
	for relay: Dictionary in relays:
		var at: Vector3 = relay.position
		if Vector2(at.x,at.z).distance_to(point) < MIN_RELAY_GAP: return null
	for other: Vector2 in taken:
		if other.distance_to(point) < MIN_CASE_GAP: return null
	if float(park.path_edge_distance_world(point)) < MIN_PATH_GAP: return null
	if _route_gap(point,routes) < MIN_ROUTE_GAP: return null
	# A ray confirms terrain support before a case is installed.
	var floor_height: float = navigation._floor_height(point)
	var space: PhysicsDirectSpaceState3D = park.get_world_3d().direct_space_state
	var top := Vector3(point.x,floor_height+3.0,point.y)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top,top+Vector3.DOWN*5.0,1))
	if hit.is_empty() or absf(float(hit.position.y)-floor_height) > 0.3 or hit.normal.y < 0.9: return null
	var location: Vector3 = hit.position
	var stand: Vector3 = location+APPROACH
	if navigation.is_water(Vector2(stand.x,stand.z)): return null
	if not _open(raid,location+Vector3.UP*1.0,Vector3(1.5,1.3,0.9)): return null
	if not _open(raid,stand+Vector3.UP*1.15,Vector3(0.8,1.6,0.8)): return null
	var eye: Vector3 = stand+Vector3.UP*EYE_HEIGHT
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,location+Vector3.UP*0.3,1)).is_empty(): return null
	return location

static func _open(raid: Node, centre: Vector3, size: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY,centre)
	query.collision_mask = 1
	return raid.park.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
