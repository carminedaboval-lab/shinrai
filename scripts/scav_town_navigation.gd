extends RefCounted
## Human-only town links. Original park graph and bot routes remain untouched.
const AREA:=Rect2i(-31,168,63,51)
var raid: Node
var park: Node3D
var walk_graph:=AStar2D.new()
var ready:=false
var town_ids: Dictionary={}
var heights: Dictionary={}
var excluded: Array[RID]=[]
var query: PhysicsShapeQueryParameters3D
var obstacles: Array[AABB]=[]
var report: Dictionary={}

func build(owner_raid: Node, display_bounds: Array[AABB]) -> void:
	raid=owner_raid;park=raid.park;obstacles=display_bounds
	excluded=[raid.player.get_rid()]
	var shape:=CapsuleShape3D.new();shape.radius=.36;shape.height=1.72
	query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1|2;query.exclude=excluded
	var source: AStar2D=raid.navigation.walk_graph
	for id: int in source.get_point_ids():
		walk_graph.add_point(id,source.get_point_position(id),source.get_point_weight_scale(id))
	for id: int in source.get_point_ids():
		for peer: int in source.get_point_connections(id):
			if peer>id:walk_graph.connect_points(id,peer)
	var budget:=0
	var next_id:=100000
	for z: int in range(AREA.position.y,AREA.end.y):
		for x: int in range(AREA.position.x,AREA.end.x):
			var p:=Vector2(x,z);var floor:=floor_at(p)
			if floor.is_finite() and clear(floor):
				walk_graph.add_point(next_id,p);town_ids[Vector2i(x,z)]=next_id;heights[p]=floor.y;next_id+=1
			budget+=1
			if budget>=96:budget=0;await park.get_tree().process_frame
	var edges:=0
	for cell: Vector2i in town_ids:
		for shift: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(-1,1)]:
			var other:=cell+shift
			if not town_ids.has(other):continue
			if shift.x!=0 and shift.y!=0 and (not town_ids.has(cell+Vector2i(shift.x,0)) or not town_ids.has(cell+Vector2i(0,shift.y))):continue
			if _can_walk_edge(Vector2(cell),Vector2(other)):
				walk_graph.connect_points(town_ids[cell],town_ids[other]);edges+=1
		budget+=1
		if budget>=64:budget=0;await park.get_tree().process_frame
	var links:=0
	for cell: Vector2i in town_ids:
		if cell.y>176 or cell.x%2!=0 or cell.y%2!=0:continue
		var p:=Vector2(cell);var old:=source.get_closest_point(p)
		if old<0 or source.get_point_connections(old).is_empty():continue
		var q:=source.get_point_position(old)
		if p.distance_to(q)<=5.8 and _can_walk_edge(p,q):
			walk_graph.connect_points(town_ids[cell],old);links+=1
	ready=not town_ids.is_empty() and edges>0 and links>0
	report={"town_vertices":town_ids.size(),"town_edges":edges,"park_links":links,"ready":ready,"bounds":str(AREA)}

func floor_at(p: Vector2) -> Vector3:
	var expected: float=raid.navigation._floor_height(p) if p.y<176 else .1
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(p.x,expected+2,p.y),Vector3(p.x,expected-3,p.y),1)
	ray.exclude=excluded
	var hit:=park.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.72:return Vector3.INF
	return hit.position+Vector3.UP*.025

func clear(point: Vector3) -> bool:
	for bounds: AABB in obstacles:
		var grown:=bounds.grow(.4)
		if point.x>grown.position.x and point.x<grown.end.x and point.z>grown.position.z and point.z<grown.end.z:return false
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.875)
	var moving_exclusions: Array[RID]=excluded.duplicate()
	for human: Node in park.get_tree().get_nodes_in_group("human_scavs"):
		if human is CollisionObject3D:moving_exclusions.append(human.get_rid())
	query.exclude=moving_exclusions
	return park.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _can_walk_edge(a: Vector2,b: Vector2) -> bool:
	if a.y<168 and b.y<168:return raid.navigation._can_walk_edge(a,b)
	var count:=maxi(1,ceili(a.distance_to(b)/.25));var previous:=Vector3.INF
	for i: int in range(count+1):
		var floor:=floor_at(a.lerp(b,float(i)/count))
		if not floor.is_finite() or not clear(floor):return false
		if previous.is_finite() and absf(floor.y-previous.y)>.18:return false
		previous=floor
	return true

func nearest_id(point: Vector3) -> int:
	if not point.is_finite():return -1
	var p:=Vector2(point.x,point.z);var nearest:=walk_graph.get_closest_point(p)
	if nearest>=0 and not walk_graph.get_point_connections(nearest).is_empty() and _can_walk_edge(p,walk_graph.get_point_position(nearest)):return nearest
	var best: int=-1;var distance:=9.0
	for id: int in walk_graph.get_point_ids():
		var q:=walk_graph.get_point_position(id);var d:=p.distance_squared_to(q)
		if d>=distance or walk_graph.get_point_connections(id).is_empty():continue
		if _can_walk_edge(p,q):best=id;distance=d
	return best

func nearest(point: Vector3) -> Vector3:
	if not point.is_finite():return Vector3.INF
	# Project a requested goal out of a facade/post onto a valid nearby vertex.
	# Route endpoints still use nearest_id and verify their actual walking edge.
	var p:=Vector2(point.x,point.z);var closest:=walk_graph.get_closest_point(p)
	if closest>=0 and not walk_graph.get_point_connections(closest).is_empty():
		var q:=walk_graph.get_point_position(closest)
		var floor:=Vector3(q.x,heights.get(q,raid.navigation._floor_height(q)+.2),q.y)
		if q.distance_squared_to(p)<=16.0 and clear(floor):return floor
	var best:=Vector3.INF;var distance:=16.0
	for id: int in walk_graph.get_point_ids():
		var q:=walk_graph.get_point_position(id);var d:=p.distance_squared_to(q)
		if d>=distance or walk_graph.get_point_connections(id).is_empty():continue
		var floor:=Vector3(q.x,heights.get(q,raid.navigation._floor_height(q)+.2),q.y)
		if clear(floor):best=floor;distance=d
	return best

func path(from: Vector3,to: Vector3) -> PackedVector3Array:
	if from.z<168 and to.z<168:return raid.get_path_world(from,to)
	var output:=PackedVector3Array()
	var start:=nearest_id(from);var finish:=nearest_id(to)
	if start<0 or finish<0:return output
	for p: Vector2 in walk_graph.get_point_path(start,finish):output.append(Vector3(p.x,heights.get(p,raid.navigation._floor_height(p)+.2),p.y))
	if output.is_empty():return output
	if _can_walk_edge(Vector2(output[-1].x,output[-1].z),Vector2(to.x,to.z)):output.append(to)
	return output
