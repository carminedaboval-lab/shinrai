extends RefCounted

const CELL := 4.0
const ORIGIN := Vector2(-220, -180)
var grid := AStarGrid2D.new()
var shoreline := PackedVector2Array()
var bridge_corridors: Array[PackedVector2Array] = []
var ready := false

func build(park: Node3D) -> void:
	ready = false
	shoreline.clear()
	bridge_corridors.clear()
	for route: Array[Vector2] in [park.FUTURE_BRIDGE_WEST, park.FUTURE_BRIDGE_NORTH_EAST, park.FUTURE_BRIDGE_SOUTH]:
		var corridor := PackedVector2Array()
		for point: Vector2 in route:
			corridor.append(point * park.LAYOUT_SCALE)
		bridge_corridors.append(corridor)
	for point: Vector2 in park.lake_contour:
		shoreline.append(point * park.LAYOUT_SCALE)
	grid.region = Rect2i(0, 0, 111, 91)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = ORIGIN
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.collide_with_areas = false
	var player: CharacterBody3D = park.get_node("ParkScaleReviewPlayer")
	query.exclude = [player.get_rid()]
	var space := park.get_world_3d().direct_space_state
	for y: int in range(91):
		for x: int in range(111):
			var cell := Vector2i(x, y)
			var p := grid.get_point_position(cell)
			var blocked := x < 2 or y < 2 or x > 108 or y > 88 or is_water(p)
			if not blocked:
				query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 0.85, p.y))
				blocked = not space.intersect_shape(query, 1).is_empty()
			grid.set_point_solid(cell, blocked)
			if not blocked:
				# Prefer the authored park paths without forbidding grass flanks.
				var on_path: bool = park._is_near_destination_path(p / park.LAYOUT_SCALE, 0.4)
				grid.set_point_weight_scale(cell, 1.0 if on_path else 1.65)
	ready = true

func is_water(p: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(p, shoreline):
		return false
	# Only the installed bridge decks are dry traversable corridors.
	for corridor: PackedVector2Array in bridge_corridors:
		for index: int in range(corridor.size() - 1):
			var a := corridor[index]
			var b := corridor[index + 1]
			var segment := b - a
			var t := clampf((p - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
			if p.distance_to(a + segment * t) <= 2.6:
				return false
	return true

func nearest_cell(point: Vector3) -> Vector2i:
	var raw := Vector2i(((Vector2(point.x, point.z) - ORIGIN) / CELL).round())
	raw = raw.clamp(Vector2i(2, 2), Vector2i(108, 88))
	if not grid.is_point_solid(raw):
		return raw
	for radius: int in range(1, 112):
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var candidate := raw + Vector2i(x, y)
				if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return Vector2i(55, 85)

func nearest(point: Vector3) -> Vector3:
	var p := grid.get_point_position(nearest_cell(point))
	return Vector3(p.x, 0.2, p.y)

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var output := PackedVector3Array()
	if not ready:
		return output
	for cell: Vector2i in grid.get_id_path(nearest_cell(from), nearest_cell(to)):
		var p := grid.get_point_position(cell)
		output.append(Vector3(p.x, 0.2, p.y))
	return output

func interaction_path(from: Vector3, target: Vector3, radius: float) -> PackedVector3Array:
	# Furniture centres can be solid. End within interaction range on a reachable
	# cell, instead of snapping to an arbitrary cell outside the usable radius.
	var best := PackedVector3Array()
	if not ready:
		return best
	var target_2d := Vector2(target.x, target.z)
	var centre := Vector2i(((target_2d - ORIGIN) / CELL).round())
	var reach := ceili(radius / CELL) + 1
	var start := nearest_cell(from)
	var best_length := INF
	for y: int in range(-reach, reach + 1):
		for x: int in range(-reach, reach + 1):
			var candidate := centre + Vector2i(x, y)
			if not grid.region.has_point(candidate) or grid.is_point_solid(candidate):
				continue
			if grid.get_point_position(candidate).distance_to(target_2d) > radius:
				continue
			var cells := grid.get_id_path(start, candidate)
			if cells.is_empty():
				continue
			var route := PackedVector3Array()
			var length := 0.0
			var previous := from
			for cell: Vector2i in cells:
				var p := grid.get_point_position(cell)
				var point := Vector3(p.x, 0.2, p.y)
				length += previous.distance_to(point)
				previous = point
				route.append(point)
			if length < best_length:
				best_length = length
				best = route
	return best
