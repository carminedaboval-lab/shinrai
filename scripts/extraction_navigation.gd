extends RefCounted
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")

const CELL := 4.0
const ORIGIN := Vector2(-220, -180)
const FLOOR_NODE_START := 20000
const FLOOR_NODE_SPACING := 0.75
const FLOOR_SAMPLE_SPACING := 0.25
const MAX_FLOOR_STEP := 0.065
var grid := AStarGrid2D.new()
var walk_graph := AStar2D.new()
var shoreline := PackedVector2Array()
var ready := false
var _park: Node3D
var _floor_heights: Dictionary = {}
var _paving_cells: Dictionary = {}
var _space: PhysicsDirectSpaceState3D
var _edge_query: PhysicsShapeQueryParameters3D

func build(park: Node3D) -> void:
	var _boot_tick := StartupTrace.begin()
	_park = park
	_floor_heights.clear()
	_paving_cells.clear()
	ready = false
	walk_graph.clear()
	shoreline.clear()
	for point: Vector2 in park.lake_contour:
		await LoadingBudget.checkpoint(park)
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
	var excluded: Array[RID] = [player.get_rid()]
	# Walkable deck/ramp supports are floors. Keep prop and obstacle bodies in the query.
	for support: Node in park.get_tree().get_nodes_in_group("midori_walk_surface"):
		await LoadingBudget.checkpoint(park)
		if support is StaticBody3D and park.is_ancestor_of(support):
			excluded.append(support.get_rid())
	query.exclude = excluded
	_space = park.get_world_3d().direct_space_state
	# The graph only depends on the built park, so it is cached on disk. The key
	# changes whenever any project file or the Creator layout changes.
	var cache_key := _cache_key()
	if _load_cache(cache_key):
		var cached_capsule := CapsuleShape3D.new()
		cached_capsule.radius = 0.42
		cached_capsule.height = 1.75
		query.shape = cached_capsule
		_edge_query = query
		_boot_tick = StartupTrace.finish("navigation.cache_load",_boot_tick)
		ready = true
		return
	for y: int in range(91):
		await LoadingBudget.checkpoint(park)
		for x: int in range(111):
			await LoadingBudget.checkpoint(park)
			var cell := Vector2i(x, y)
			_sample_ground_cell(cell, query)
	_boot_tick = StartupTrace.finish("navigation.vertices",_boot_tick)
	# Clear endpoints do not imply a clear edge: sweep a player-sized capsule
	# between cells so routes cannot cut through a lamp, tree or boulder.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	query.shape = capsule
	_edge_query = query
	for y: int in range(2, 89):
		await LoadingBudget.checkpoint(park)
		for x: int in range(2, 109):
			await LoadingBudget.checkpoint(park)
			var cell := Vector2i(x, y)
			for direction: Vector2i in GRID_EDGES:
				if _ground_edge_open(cell, direction):
					walk_graph.connect_points(_cell_id(cell), _cell_id(cell + direction))
	_boot_tick = StartupTrace.finish("navigation.edges",_boot_tick)
	await _add_bridge_floor_routes()
	_boot_tick = StartupTrace.finish("navigation.bridge_links",_boot_tick)
	_save_cache(cache_key)
	ready = true

const GRID_EDGES := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]

func _sample_ground_cell(cell: Vector2i, query: PhysicsShapeQueryParameters3D) -> void:
	var p := grid.get_point_position(cell)
	var blocked := cell.x < 2 or cell.y < 2 or cell.x > 108 or cell.y > 88 or is_water(p)
	if not blocked:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, _floor_height(p) + 0.85, p.y))
		blocked = not _space.intersect_shape(query, 1).is_empty()
	grid.set_point_solid(cell, blocked)
	var id := _cell_id(cell)
	if blocked:
		if walk_graph.has_point(id): walk_graph.remove_point(id)
		return
	var on_path: bool = is_finite(float(_park.bridge_surface_height(p))) or _park._is_near_destination_path(p / _park.LAYOUT_SCALE, 0.4)
	var weight := 1.0 if on_path else 1.65
	grid.set_point_weight_scale(cell, weight)
	if walk_graph.has_point(id): walk_graph.set_point_weight_scale(id, weight)
	else: _add_walk_point(id, p, weight)

func _ground_edge_open(cell: Vector2i, direction: Vector2i) -> bool:
	var next := cell + direction
	if not grid.region.has_point(next) or grid.is_point_solid(cell) or grid.is_point_solid(next): return false
	if direction.x != 0 and direction.y != 0:
		if grid.is_point_solid(cell + Vector2i(direction.x, 0)) or grid.is_point_solid(cell + Vector2i(0, direction.y)): return false
	return _can_walk_edge(grid.get_point_position(cell), grid.get_point_position(next))

## Sweep the real navigation capsule along the full straight, terrain-following
## path. Short contiguous segments follow changes of terrain and paving elevation.
func inspect_ground_corridor(start: Vector2, end: Vector2) -> Dictionary:
	if not ready or _space == null: return {"pass": false, "error": "Navigation unavailable"}
	var segments := maxi(1, ceili(start.distance_to(end)))
	var supported := 0
	for i in range(segments + 1):
		var p := start.lerp(end, float(i) / segments)
		var ground := _floor_height(p)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,ground + 0.5,p.y), Vector3(p.x,ground - 1.5,p.y),1)
		var hit := _space.intersect_ray(ray)
		if hit.is_empty() or absf(hit.position.y - ground) >= .36 or hit.normal.y <= .7:
			return {"pass": false,"reason": "unsupported","point": str(p)}
		supported += 1
		if i == segments: break
		var next := start.lerp(end, float(i + 1) / segments)
		if not _can_walk_edge(p,next) or not _can_walk_edge(next,p):
			return {"pass": false,"reason": "capsule or slope","point": str(p),"next": str(next)}
	return {"pass": true,"from":str(start),"to":str(end),"metres":start.distance_to(end),"capsule_radius":0.42,"support_probes":supported,"swept_both_ways":true}

## The shrine replaces two solid posts after the park graph is loaded. Re-sample the
## footprint in memory, including every edge whose clearance or diagonal corner
## can change. Other cells, links, bridge nodes and the on-disk boot cache persist.
func refresh_plaza_gate(centre: Vector2) -> Dictionary:
	if not ready or _space == null or _edge_query == null: return {"error": "Navigation unavailable"}
	var middle := Vector2i(((centre - ORIGIN) / CELL).round())
	var cells := Rect2i(middle - Vector2i(2, 2), Vector2i(5, 5))
	var edge_cells := cells.grow(1)
	if not grid.region.encloses(edge_cells.grow(2)): return {"error": "Gate outside park navigation grid"}
	var reference: Array[int] = []
	# On the west or east edge outside the refresh, find a genuinely traversable control link.
	for x: int in [edge_cells.position.x - 1, edge_cells.end.x]:
		for y: int in range(edge_cells.position.y, edge_cells.end.y):
			var c := Vector2i(x, y)
			var next := c + Vector2i.DOWN
			if not walk_graph.has_point(_cell_id(c)) or not walk_graph.has_point(_cell_id(next)): continue
			if walk_graph.are_points_connected(_cell_id(c), _cell_id(next)) and _ground_edge_open(c, Vector2i.DOWN):
				reference = [_cell_id(c), _cell_id(next)]
				break
		if not reference.is_empty(): break
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	var sample := PhysicsShapeQueryParameters3D.new()
	sample.shape = sphere
	sample.collision_mask = _edge_query.collision_mask
	sample.collide_with_areas = false
	sample.exclude = _edge_query.exclude
	for y: int in range(cells.position.y, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			_sample_ground_cell(Vector2i(x, y), sample)
	var changed_edges := 0
	for y: int in range(edge_cells.position.y, edge_cells.end.y):
		for x: int in range(edge_cells.position.x, edge_cells.end.x):
			var c := Vector2i(x, y)
			for delta: Vector2i in GRID_EDGES:
				var next := c + delta
				if not cells.has_point(c) and not cells.has_point(next) and not cells.has_point(c + Vector2i(delta.x, 0)) and not cells.has_point(c + Vector2i(0, delta.y)): continue
				var a := _cell_id(c)
				var b := _cell_id(next)
				if not walk_graph.has_point(a) or not walk_graph.has_point(b): continue
				var connected := walk_graph.are_points_connected(a, b)
				var open := _ground_edge_open(c, delta)
				if connected == open: continue
				if open: walk_graph.connect_points(a, b)
				else: walk_graph.disconnect_points(a, b)
				changed_edges += 1
	var north := grid.get_point_position(middle - Vector2i(0, 1))
	var south := grid.get_point_position(middle + Vector2i(0, 1))
	var at_n := Vector3(north.x, _floor_height(north), north.y)
	var at_s := Vector3(south.x, _floor_height(south), south.y)
	var forward := path(at_n, at_s)
	var reverse := path(at_s, at_n)
	var corridor_ok := _can_walk_edge(north, south) and _can_walk_edge(south, north)
	for outbound: bool in [true, false]:
		var route := forward if outbound else reverse
		if route.size() < 2:
			corridor_ok = false
			continue
		var first := at_n if outbound else at_s
		var last := at_s if outbound else at_n
		corridor_ok = corridor_ok and first.distance_to(route[0]) < 0.5 and last.distance_to(route[-1]) < 0.5
		for step: Vector3 in route:
			if absf(step.x - centre.x) > 1.0: corridor_ok = false
	var ground := _floor_height(centre)
	var support := _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(centre.x, ground + 0.5, centre.y), Vector3(centre.x, ground - 1.5, centre.y), 1))
	var support_ok: bool = not support.is_empty() and absf(support.position.y - ground) < 0.36 and support.normal.y > 0.7
	var reference_ok := reference.size() == 2 and walk_graph.are_points_connected(reference[0], reference[1])
	if reference_ok:
		reference_ok = _can_walk_edge(walk_graph.get_point_position(reference[0]), walk_graph.get_point_position(reference[1]))
	return {"resampled_cells": cells.size.x * cells.size.y, "changed_edges": changed_edges,
		"forward": str(forward), "reverse": str(reverse), "capsule_radius": 0.42,
		"corridor_clear": corridor_ok, "supported": support_ok, "outer_edge_ids": reference, "outer_edge_passed": reference_ok}

func _add_walk_point(id: int, p: Vector2, weight: float = 1.0) -> void:
	walk_graph.add_point(id, p, weight)
	# Cache graph vertices only. Dense edge probes must not cache the whole lawn.
	_floor_heights[p] = maxf(float(_park.bridge_surface_height(p)), _terrain_height(p))

func _add_bridge_floor_routes() -> void:
	var next_id := FLOOR_NODE_START
	var deck_ends: Array[int] = []
	var landing_ends: Array[int] = []
	var floor_nodes: Array[int] = []
	for surface: Dictionary in _park._bridge_walk_surfaces:
		await LoadingBudget.checkpoint(_park)
		var points: Array[Vector2] = []
		if surface.kind == "deck":
			for sample: Vector2 in surface.spec.samples:
				points.append(surface.spec.start + surface.spec.axis * sample.x)
		else:
			for point: Vector3 in surface.spec.points:
				points.append(Vector2(point.x, point.z))
		var route := _resample_floor_route(points)
		var ids: Array[int] = []
		for p: Vector2 in route:
			await LoadingBudget.checkpoint(_park)
			_add_walk_point(next_id, p)
			ids.append(next_id)
			floor_nodes.append(next_id)
			next_id += 1
		for index: int in range(ids.size() - 1):
			await LoadingBudget.checkpoint(_park)
			_connect_walk_points(ids[index], ids[index + 1])
		if ids.is_empty():
			continue
		if surface.kind == "deck":
			deck_ends.append(ids[0])
			deck_ends.append(ids[-1])
		else:
			landing_ends.append(ids[-1])
	# The mouths overlap the front treads by 20cm; connect the exact floor chains.
	for landing_id: int in landing_ends:
		await LoadingBudget.checkpoint(_park)
		var mouth := walk_graph.get_point_position(landing_id)
		for deck_id: int in deck_ends:
			await LoadingBudget.checkpoint(_park)
			if mouth.distance_to(walk_graph.get_point_position(deck_id)) <= 1.5:
				_connect_walk_points(landing_id, deck_id)
	# Join the coarse park grid only across genuinely walkable floor transitions.
	# Checking the whole link prevents shore nodes entering a raised deck's side.
	for id: int in floor_nodes:
		await LoadingBudget.checkpoint(_park)
		var p := walk_graph.get_point_position(id)
		var raw := Vector2i(((p - ORIGIN) / CELL).round())
		for y: int in range(-2, 3):
			await LoadingBudget.checkpoint(_park)
			for x: int in range(-2, 3):
				var cell := raw + Vector2i(x, y)
				if not grid.region.has_point(cell) or grid.is_point_solid(cell):
					continue
				var grid_id := _cell_id(cell)
				if not walk_graph.has_point(grid_id):
					continue
				if p.distance_to(walk_graph.get_point_position(grid_id)) <= CELL * 1.5:
					_connect_walk_points(id, grid_id)
	print("BRIDGE_NAV_FLOORS: nodes=%d deck_ends=%d landing_mouths=%d cached_heights=%d" % [floor_nodes.size(), deck_ends.size(), landing_ends.size(), _floor_heights.size()])

func _resample_floor_route(points: Array[Vector2]) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if points.is_empty():
		return route
	route.append(points[0])
	# Keep the supplied curve shape while making long toe/deck segments dense.
	for index: int in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var sections := maxi(1, ceili(a.distance_to(b) / FLOOR_NODE_SPACING))
		for section: int in range(1, sections + 1):
			var p := a.lerp(b, float(section) / float(sections))
			if section == sections and index < points.size() - 2 and route[-1].distance_to(p) < FLOOR_NODE_SPACING * 0.5:
				continue
			route.append(p)
	return route

func _connect_walk_points(a_id: int, b_id: int) -> void:
	if a_id == b_id or walk_graph.are_points_connected(a_id, b_id):
		return
	if _can_walk_edge(walk_graph.get_point_position(a_id), walk_graph.get_point_position(b_id)):
		walk_graph.connect_points(a_id, b_id)

func _can_walk_edge(a: Vector2, b: Vector2) -> bool:
	if not _can_walk_floor(a, b):
		return false
	_edge_query.transform = Transform3D(Basis.IDENTITY, Vector3(a.x, _floor_height(a) + 1.1, a.y))
	_edge_query.motion = Vector3(b.x - a.x, _floor_height(b) - _floor_height(a), b.y - a.y)
	if not _space.intersect_shape(_edge_query, 1).is_empty():
		return false
	return _space.cast_motion(_edge_query)[0] >= 0.9999

func _cell_id(cell: Vector2i) -> int:
	return cell.y * 111 + cell.x

func is_water(p: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(p, shoreline):
		return false
	if _park != null and is_finite(float(_park.bridge_surface_height(p))):
		return false
	# Only actual installed floor footprints make water traversable.
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
	# Spawn/patrol anchors snap onto a real floor, including requests in the lake.
	var id := _closest_graph_point(Vector2(point.x, point.z))
	if id < 0:
		return point
	var p := walk_graph.get_point_position(id)
	return Vector3(p.x, _floor_height(p)+0.2, p.y)

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var output := PackedVector3Array()
	if not ready:
		return output
	var from_id := _nearest_graph_point(from)
	var to_id := _nearest_graph_point(to)
	if from_id < 0 or to_id < 0:
		return output
	for p: Vector2 in walk_graph.get_point_path(from_id, to_id):
		output.append(Vector3(p.x, _floor_height(p)+0.2, p.y))
	# On a fitted floor, replanning can snap to a nearby grid node behind the
	# actor. Start farther along only when the complete live-position link passes
	# the same floor continuity and obstacle capsule checks as every graph edge.
	var live_start := Vector2(from.x,from.z)
	if is_finite(float(_park.bridge_surface_height(live_start))):
		var advance := 0
		for index: int in range(mini(6,output.size())):
			var candidate := Vector2(output[index].x,output[index].z)
			if live_start.distance_to(candidate) > CELL*2.0:
				break
			if _can_walk_edge(live_start,candidate):
				advance = index
		if advance > 0:
			output = output.slice(advance)
	return output

func _nearest_graph_point(point: Vector3) -> int:
	if walk_graph.get_point_count() == 0:
		return -1
	var p := Vector2(point.x, point.z)
	var closest := walk_graph.get_closest_point(p)
	# Interactive goals can be inside a lamp/relay collider. Snap them to a clear
	# connected graph vertex; only the floor transition must be reachable here.
	# The actual graph edges already passed full obstacle capsule sweeps.
	if not walk_graph.get_point_connections(closest).is_empty() and _can_walk_floor(p, walk_graph.get_point_position(closest)):
		return closest
	# A nearby floor node across a tall side cannot be the start of a walking route.
	# Nearest passing node wins, so test nearest-first and stop at the first pass;
	# the floor check is far too expensive to run on every node in range.
	var nearby: Array[Dictionary] = []
	for id: int in walk_graph.get_point_ids():
		var candidate := walk_graph.get_point_position(id)
		var distance := p.distance_squared_to(candidate)
		if distance <= CELL * CELL * 4.0:
			nearby.append({"id": id, "point": candidate, "distance": distance})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for row: Dictionary in nearby:
		if walk_graph.get_point_connections(row.id).is_empty():
			continue
		if _can_walk_floor(p, row.point):
			return row.id
	return -1

func _closest_graph_point(p: Vector2) -> int:
	if walk_graph.get_point_count() == 0:
		return -1
	var closest := walk_graph.get_closest_point(p)
	if not walk_graph.get_point_connections(closest).is_empty():
		return closest
	var best := -1
	var best_distance := INF
	for id: int in walk_graph.get_point_ids():
		var distance := p.distance_squared_to(walk_graph.get_point_position(id))
		if distance < best_distance and not walk_graph.get_point_connections(id).is_empty():
			best = id
			best_distance = distance
	return best

func _floor_height(p: Vector2) -> float:
	if _park == null:
		return 0.0
	if _floor_heights.has(p):
		return _floor_heights[p]
	return maxf(float(_park.bridge_surface_height(p)), _terrain_height(p))

func _can_walk_floor(a: Vector2, b: Vector2) -> bool:
	if not _can_walk_floor_centre(a,b):
		return false
	if is_finite(float(_park.bridge_surface_height(a))) or is_finite(float(_park.bridge_surface_height(b))):
		# A centre line grazing a curved ramp edge is too fragile for an actor.
		# Check floor continuity across the navigation capsule's width as well.
		var side := Vector2(-(b-a).y,(b-a).x).normalized()*0.45
		if not _can_walk_floor_centre(a+side,b+side) or not _can_walk_floor_centre(a-side,b-side):
			return false
	return true

func _can_walk_floor_centre(a: Vector2, b: Vector2) -> bool:
	# Excluded floors must still be entered through their shallow approaches.
	# A clear capsule sweep above a deck does not make its raised sides walkable.
	var steps := maxi(1, ceili(a.distance_to(b) / FLOOR_SAMPLE_SPACING))
	if is_water(a):
		return false
	var previous := _floor_height(a)
	var previous_bridge := float(_park.bridge_surface_height(a))
	for index: int in range(1, steps + 1):
		var p := a.lerp(b, float(index) / float(steps))
		# Reuse the same exact height for water, support and transition checks.
		# No quantization or persistent cache: changed floors are still read live.
		var bridge_height := float(_park.bridge_surface_height(p))
		if not is_finite(bridge_height) and Geometry2D.is_point_in_polygon(p,shoreline):
			return false
		var height := float(_floor_heights[p]) if _floor_heights.has(p) else maxf(bridge_height,_terrain_height(p))
		var previous_point := a.lerp(b, float(index-1)/float(steps))
		var bridge_transition := is_finite(bridge_height) or is_finite(previous_bridge)
		var allowed_step := MAX_FLOOR_STEP if bridge_transition else maxf(MAX_FLOOR_STEP, p.distance_to(previous_point)*0.60)
		if absf(height - previous) > allowed_step:
			return false
		previous = height
		previous_bridge = bridge_height
	return true

func _terrain_height(p: Vector2) -> float:
	var terrain := _park.get_node_or_null("MidoriTerrain")
	var base: float = terrain.height_at(p) if terrain != null and terrain.installed else 0.0
	if _space == null:
		return base
	return maxf(base, _paving_height(p))

# Draped paving stands about 0.1 m proud of the terrain it follows. Reading only
# the terrain invents a step at every path edge. -INF means no paving here.
func _paving_height(p: Vector2) -> float:
	var cell := Vector2i((p * 4.0).round())
	if _paving_cells.has(cell):
		return _paving_cells[cell]
	var height := -INF
	# The path-edge scan is slow, so it runs once per cell, after the lookup above.
	if float(_park.path_edge_distance_world(p)) > .3:
		_paving_cells[cell] = height
		return height
	var query :=PhysicsRayQueryParameters3D.create(Vector3(p.x, 6.0, p.y), Vector3(p.x, -3.0, p.y), 1)
	var excluded: Array[RID] = []
	for attempt: int in range(5):
		query.exclude = excluded
		var hit := _space.intersect_ray(query)
		if hit.is_empty():
			break
		var body: Object = hit.collider
		if body is Node and (body as Node).is_in_group("midori_terrain_paving"):
			height = hit.position.y
			break
		if body is Node and (body as Node).is_in_group("midori_terrain_floor"):
			break
		excluded.append(hit.rid)
	_paving_cells[cell] = height
	return height

const NAV_CACHE_DIR := "user://shinrai_cache/"
const NAV_CACHE_VERSION := 2

static func _cache_key() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([NAV_CACHE_VERSION, CELL, ORIGIN, FLOOR_NODE_SPACING, MAX_FLOOR_STEP]))
	var pending: Array[String] = ["res://"]
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			if sub.begins_with("."): continue
			pending.append(dir.path_join(sub))
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".log") or file.ends_with(".tmp"): continue
			var path := dir.path_join(file)
			ctx.update(("%s|%d\n" % [path, FileAccess.get_modified_time(path)]).to_utf8_buffer())
	var layout := "user://creator_layouts/midori_default.json"
	if FileAccess.file_exists(layout):
		ctx.update(FileAccess.get_sha256(layout).to_utf8_buffer())
	return ctx.finish().hex_encode()

func _load_cache(key: String) -> bool:
	var path := NAV_CACHE_DIR + "navigation_" + key + ".bin"
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var data: Variant = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != NAV_CACHE_VERSION: return false
	var solids: PackedByteArray = data.solids
	var weights: PackedFloat32Array = data.grid_weights
	if solids.size() != 111 * 91 or weights.size() != 111 * 91: return false
	for y: int in range(91):
		for x: int in range(111):
			var i := y * 111 + x
			grid.set_point_solid(Vector2i(x, y), solids[i] == 1)
			if solids[i] == 0: grid.set_point_weight_scale(Vector2i(x, y), weights[i])
	var ids: PackedInt64Array = data.point_ids
	var positions: PackedVector2Array = data.point_positions
	var point_weights: PackedFloat32Array = data.point_weights
	for i: int in range(ids.size()):
		walk_graph.add_point(ids[i], positions[i], point_weights[i])
	var links: PackedInt64Array = data.links
	for i: int in range(0, links.size(), 2):
		walk_graph.connect_points(links[i], links[i + 1])
	var height_keys: PackedVector2Array = data.height_keys
	var height_values: PackedFloat32Array = data.height_values
	for i: int in range(height_keys.size()):
		_floor_heights[height_keys[i]] = height_values[i]
	print("NAVIGATION_CACHE: loaded %d points, %d links" % [ids.size(), links.size() / 2])
	return true

func _save_cache(key: String) -> void:
	var solids := PackedByteArray()
	var weights := PackedFloat32Array()
	solids.resize(111 * 91)
	weights.resize(111 * 91)
	for y: int in range(91):
		for x: int in range(111):
			var i := y * 111 + x
			var solid := grid.is_point_solid(Vector2i(x, y))
			solids[i] = 1 if solid else 0
			weights[i] = 1.0 if solid else grid.get_point_weight_scale(Vector2i(x, y))
	var ids := PackedInt64Array()
	var positions := PackedVector2Array()
	var point_weights := PackedFloat32Array()
	var links := PackedInt64Array()
	for id: int in walk_graph.get_point_ids():
		ids.append(id)
		positions.append(walk_graph.get_point_position(id))
		point_weights.append(walk_graph.get_point_weight_scale(id))
		for other: int in walk_graph.get_point_connections(id):
			if other > id:
				links.append(id)
				links.append(other)
	var height_keys := PackedVector2Array()
	var height_values := PackedFloat32Array()
	for k: Vector2 in _floor_heights:
		height_keys.append(k)
		height_values.append(float(_floor_heights[k]))
	DirAccess.make_dir_recursive_absolute(NAV_CACHE_DIR)
	for name: String in DirAccess.get_files_at(NAV_CACHE_DIR):
		if name.begins_with("navigation_"): DirAccess.remove_absolute(NAV_CACHE_DIR + name)
	var file := FileAccess.open(NAV_CACHE_DIR + "navigation_" + key + ".bin", FileAccess.WRITE)
	if file == null: return
	file.store_var({"version": NAV_CACHE_VERSION, "solids": solids, "grid_weights": weights, "point_ids": ids, "point_positions": positions, "point_weights": point_weights, "links": links, "height_keys": height_keys, "height_values": height_values})
	file.close()

