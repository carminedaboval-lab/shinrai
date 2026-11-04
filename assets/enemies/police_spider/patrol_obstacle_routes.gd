extends RefCounted
## Bounded local routes around actual static collider footprints.
## The actor calls this only after its ordinary navigation wrapper accepted a route.
const CLEARANCE_MARGIN := .28
const MAX_CHECKS := 180
const ALERT_MAX_CHECKS := 96
const CALM_MAX_CHECKS := 48
const MAX_BODIES := 2
const FAILED_SECONDS := 8.0
var failed_points: Array[Dictionary] = []
var last_checks := 0
var check_limit := MAX_CHECKS
var last_escape := Vector3.INF
var last_obstacles := PackedStringArray()
var _query: PhysicsShapeQueryParameters3D

func remember_failure(point: Vector3) -> void:
	if not point.is_finite(): return
	_expire_failures()
	failed_points.append({"point":point,"until":Time.get_ticks_msec()+int(FAILED_SECONDS*1000.0)})
	if failed_points.size()>8: failed_points.pop_front()

func _expire_failures() -> void:
	var now:=Time.get_ticks_msec()
	for index: int in range(failed_points.size()-1,-1,-1):
		if int(failed_points[index].until)<=now: failed_points.remove_at(index)

func _failed(point: Vector3) -> bool:
	for entry: Dictionary in failed_points:
		if Vector2(point.x-entry.point.x,point.z-entry.point.z).length()<.55: return true
	return false

func _clear(actor: CharacterBody3D, from: Vector3, to: Vector3, heading: Vector3 = Vector3.ZERO, fixed: bool = false) -> bool:
	if last_checks>=check_limit: return false
	last_checks+=1
	return actor._navigation_link_clear(from,to,heading,fixed)

func plan(actor: CharacterBody3D, accepted: PackedVector3Array) -> Dictionary:
	last_checks=0;last_escape=Vector3.INF;last_obstacles.clear();_expire_failures()
	if accepted.is_empty() or actor.nav_query==null: return {}
	# A failed search is the costliest thing a calm drone does, so bound it harder.
	check_limit=CALM_MAX_CHECKS if actor._is_calm_patrol() else (MAX_CHECKS if actor.nav_urgent else ALERT_MAX_CHECKS)
	var destinations: Array[Dictionary]=[]
	# Look past a route point sitting inside an obstacle's margin. Each leg of the
	# detour is still limited to 8 m by the link check.
	for index: int in range(mini(6,accepted.size())-1,-1,-1):
		var point: Vector3=accepted[index]
		var distance:=Vector2(point.x-actor.global_position.x,point.z-actor.global_position.z).length()
		if distance>.2 and distance<=12.0: destinations.append({"index":index,"point":point})
	for item: Dictionary in destinations:
		var route:=_around(actor,actor.global_position,item.point)
		if not route.is_empty(): return {"points":route,"rejoin":item.index,"escape":Vector3.INF}
	# A snug rectangular chassis may have a clear reverse/side translation even
	# though every in-place turn is blocked. Require a checked continuation too.
	for item: Dictionary in destinations:
		var bodies:=_footprints(actor,actor.global_position,item.point)
		if bodies.is_empty(): continue
		var nearest: Rect2=bodies[0]
		var p:=Vector2(actor.global_position.x,actor.global_position.z)
		var closest:=p.clamp(nearest.position,nearest.end)
		var away:=Vector3(p.x-closest.x,0,p.y-closest.y).normalized()
		if away.length()<.1: away=actor.global_position-Vector3(nearest.get_center().x,actor.global_position.y,nearest.get_center().y)
		var directions: Array[Vector3]=[-actor.global_basis.z,actor.global_basis.x,-actor.global_basis.x]
		directions.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.dot(away)>b.dot(away))
		for distance: float in [.6,1.2]:
			for direction: Vector3 in directions:
				if direction.dot(away)<-.1: continue
				var escape:=actor.global_position+direction*distance
				if _failed(escape) or not _clear(actor,actor.global_position,escape,actor.global_basis.z,true): continue
				# Re-run the wrapper from the proposed endpoint; a closed route is
				# never converted into permission to back out or cross a doorway.
				if actor.navigation_source.get_path_world(escape,actor.nav_goal).is_empty(): continue
				var route:=_around(actor,escape,item.point)
				if route.is_empty(): continue
				route.insert(0,escape);last_escape=escape
				return {"points":route,"rejoin":item.index,"escape":escape}
	return {}

func _footprints(actor: CharacterBody3D, from: Vector3, to: Vector3) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	if _query==null:
		_query=PhysicsShapeQueryParameters3D.new();_query.collide_with_areas=false
	_query.collision_mask=1;_query.exclude=actor.nav_query.exclude
	var reach:=2.0
	var shape:=BoxShape3D.new()
	shape.size=Vector3(absf(to.x-from.x)+reach*2.0,2.0+absf(to.y-from.y),absf(to.z-from.z)+reach*2.0)
	_query.shape=shape;_query.motion=Vector3.ZERO
	_query.transform=Transform3D(Basis.IDENTITY,from.lerp(to,.5)+Vector3.UP*.7)
	var hits:=actor.get_world_3d().direct_space_state.intersect_shape(_query,12)
	hits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a.collider as Node3D).global_position.distance_squared_to(from)<(b.collider as Node3D).global_position.distance_squared_to(from))
	for hit: Dictionary in hits:
		var body:=hit.collider as StaticBody3D
		if body==null: continue
		var bounds:=AABB();var found:=false
		for collision: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
			if collision.disabled or collision.shape==null: continue
			var world_bounds: AABB=collision.global_transform*collision.shape.get_debug_mesh().get_aabb()
			bounds=world_bounds if not found else bounds.merge(world_bounds);found=true
		if not found: continue
		result.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
		last_obstacles.append(str(body.get_path()))
		if result.size()>=MAX_BODIES: break
	return result

func _around(actor: CharacterBody3D, from: Vector3, to: Vector3) -> PackedVector3Array:
	if _clear(actor,from,to): return PackedVector3Array([to])
	var box:=actor.collider.shape as BoxShape3D
	if box==null: return PackedVector3Array()
	var padding:=Vector2(box.size.x,box.size.z).length()*.5+CLEARANCE_MARGIN
	var navigation: RefCounted=actor.navigation_source.get("navigation")
	var alternatives: Array[PackedVector3Array]=[]
	for footprint: Rect2 in _footprints(actor,from,to):
		var rect:=footprint.grow(padding)
		var corners:=PackedVector3Array()
		for p: Vector2 in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
			corners.append(Vector3(p.x,float(navigation._floor_height(p)),p.y))
		for index: int in 4:
			alternatives.append(PackedVector3Array([corners[index],to]))
			for step: int in [-1,1]:
				alternatives.append(PackedVector3Array([corners[index],corners[posmod(index+step,4)],to]))
	alternatives.sort_custom(func(a: PackedVector3Array,b: PackedVector3Array) -> bool: return _length(from,a)<_length(from,b))
	var first_links: Dictionary={}
	for route: PackedVector3Array in alternatives:
		if _length(from,route)>18.0: continue
		var blocked:=false
		for index: int in range(route.size()-1):
			if _failed(route[index]): blocked=true;break
		if blocked: continue
		var previous:=from;var heading:=Vector3.ZERO
		for index: int in route.size():
			var point:=route[index]
			var clear:=false
			if index==0 and first_links.has(point): clear=first_links[point]
			else:
				clear=_clear(actor,previous,point,heading)
				if index==0: first_links[point]=clear
			if not clear: blocked=true;break
			heading=point-previous;previous=point
		if not blocked: return route
	return PackedVector3Array()

func _length(from: Vector3, route: PackedVector3Array) -> float:
	var length:=0.0;var previous:=from
	for point: Vector3 in route:
		length+=Vector2(point.x-previous.x,point.z-previous.z).length();previous=point
	return length
