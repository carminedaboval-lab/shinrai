extends RefCounted
## Walk graph for the test yard: a one-metre grid over flat ground, with the same calls
## the park's navigation gives the scav crew (walk_graph, nearest, path, _can_walk_edge,
## _floor_height). Built in well under a second.

const SAMPLE := 0.25
var walk_graph := AStar2D.new()
var half := 44
var world: World3D
var excluded: Array[RID] = []
var _query: PhysicsShapeQueryParameters3D
var _ids: Dictionary = {}


func build(yard: Node3D, half_size: int) -> void:
	half = half_size
	world = yard.get_world_3d()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.72
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = shape
	# Static world only: people (layer 2) and the player are excluded so a body standing on a
	# cell never makes it unwalkable.
	_query.collision_mask = 1
	_query.exclude = excluded
	var next_id := 0
	for z: int in range(-half, half + 1):
		for x: int in range(-half, half + 1):
			if not clear(Vector3(x, 0.025, z)): continue
			walk_graph.add_point(next_id, Vector2(x, z))
			_ids[Vector2i(x, z)] = next_id
			next_id += 1
	for cell: Vector2i in _ids:
		for shift: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
			var other := cell + shift
			if not _ids.has(other): continue
			if shift.x != 0 and shift.y != 0 and (not _ids.has(cell + Vector2i(shift.x, 0)) or not _ids.has(cell + Vector2i(0, shift.y))): continue
			if _can_walk_edge(Vector2(cell), Vector2(other)): walk_graph.connect_points(_ids[cell], _ids[other])


func exclude(body: CollisionObject3D) -> void:
	excluded.append(body.get_rid())
	_query.exclude = excluded


func clear(point: Vector3) -> bool:
	if absf(point.x) > half or absf(point.z) > half: return false
	_query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, 0.9, point.z))
	return world.direct_space_state.intersect_shape(_query, 1).is_empty()


func _floor_height(_p: Vector2) -> float:
	return 0.0


func is_water(_p: Vector2) -> bool:
	return false


func _can_walk_edge(a: Vector2, b: Vector2) -> bool:
	var count := maxi(1, ceili(a.distance_to(b) / SAMPLE))
	for i: int in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		if not clear(Vector3(p.x, 0.025, p.y)): return false
	return true


func _nearest_id(point: Vector3) -> int:
	if not point.is_finite(): return -1
	var p := Vector2(point.x, point.z)
	var cell := Vector2i(roundi(p.x), roundi(p.y))
	var best := -1
	var best_distance := 16.0
	# The eight cells round the point first: the closest one that can actually be walked to.
	for dz: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var id: int = _ids.get(cell + Vector2i(dx, dz), -1)
			if id < 0 or walk_graph.get_point_connections(id).is_empty(): continue
			var q := walk_graph.get_point_position(id)
			var d := p.distance_squared_to(q)
			if d < best_distance and _can_walk_edge(p, q):
				best = id
				best_distance = d
	if best >= 0: return best
	# A body pressed against cover fails the full-width check from where it stands. Take the
	# closest cell it has a clear line to instead.
	best_distance = 6.25
	for dz: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var id: int = _ids.get(cell + Vector2i(dx, dz), -1)
			if id < 0 or walk_graph.get_point_connections(id).is_empty(): continue
			var q := walk_graph.get_point_position(id)
			var d := p.distance_squared_to(q)
			if d >= best_distance: continue
			var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 0.5, p.y), Vector3(q.x, 0.5, q.y), 1)
			ray.exclude = excluded
			if world.direct_space_state.intersect_ray(ray).is_empty():
				best = id
				best_distance = d
	return best


func nearest(point: Vector3) -> Vector3:
	if not point.is_finite(): return Vector3.INF
	var id := _nearest_id(point)
	if id < 0:
		id = walk_graph.get_closest_point(Vector2(point.x, point.z))
		if id < 0: return Vector3.INF
	var q := walk_graph.get_point_position(id)
	return Vector3(q.x, 0.025, q.y)


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var output := PackedVector3Array()
	var start := _nearest_id(from)
	var finish := _nearest_id(to)
	if start < 0 or finish < 0: return output
	for p: Vector2 in walk_graph.get_point_path(start, finish):
		output.append(Vector3(p.x, 0.025, p.y))
	if output.is_empty(): return output
	if Vector2(output[-1].x, output[-1].z).distance_to(Vector2(to.x, to.z)) > 0.05 and _can_walk_edge(Vector2(output[-1].x, output[-1].z), Vector2(to.x, to.z)):
		output.append(Vector3(to.x, 0.025, to.z))
	return output
