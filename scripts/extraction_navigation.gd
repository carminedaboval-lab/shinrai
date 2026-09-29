extends RefCounted

const CELL := 4.0
const ORIGIN := Vector2(-220, -180)
var grid := AStarGrid2D.new()
var walk_graph := AStar2D.new()
var shoreline := PackedVector2Array()
var bridge_corridors: Array[PackedVector2Array] = []
var ready := false

func build(park: Node3D) -> void:
	ready = false
	walk_graph.clear()
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
				walk_graph.add_point(_cell_id(cell), p, grid.get_point_weight_scale(cell))
	# Clear endpoints do not imply a clear edge: sweep a player-sized capsule
	# between cells so routes cannot cut through a lamp, tree or boulder.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	query.shape = capsule
	for y: int in range(2, 89):
		for x: int in range(2, 109):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell):
				continue
			var a := grid.get_point_position(cell)
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
				var next := cell + direction
				if not grid.region.has_point(next) or grid.is_point_solid(next):
					continue
				if direction.x != 0 and direction.y != 0:
					if grid.is_point_solid(cell + Vector2i(direction.x, 0)) or grid.is_point_solid(cell + Vector2i(0, direction.y)):
						continue
				var b := grid.get_point_position(next)
				if is_water(a.lerp(b, 0.25)) or is_water(a.lerp(b, 0.5)) or is_water(a.lerp(b, 0.75)):
					continue
				query.transform = Transform3D(Basis.IDENTITY, Vector3(a.x, 1.1, a.y))
				query.motion = Vector3(b.x - a.x, 0, b.y - a.y)
				if not space.intersect_shape(query, 1).is_empty():
					continue
				var clearance := space.cast_motion(query)
				if clearance[0] >= 0.9999:
					walk_graph.connect_points(_cell_id(cell), _cell_id(next))
	ready = true

func _cell_id(cell: Vector2i) -> int:
	return cell.y * 111 + cell.x

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
		var best := Vector2i(-1, -1)
		var distance := INF
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var candidate := raw + Vector2i(x, y)
				if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
					var squared := grid.get_point_position(candidate).distance_squared_to(Vector2(point.x, point.z))
					if squared < distance:
						distance = squared
						best = candidate
		if best.x >= 0:
			return best
	return Vector2i(55, 85)

func nearest(point: Vector3) -> Vector3:
	var p := grid.get_point_position(nearest_cell(point))
	return Vector3(p.x, 0.2, p.y)

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var output := PackedVector3Array()
	if not ready:
		return output
	for p: Vector2 in walk_graph.get_point_path(_cell_id(nearest_cell(from)), _cell_id(nearest_cell(to))):
		output.append(Vector3(p.x, 0.2, p.y))
	return output
