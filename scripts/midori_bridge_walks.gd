extends RefCounted
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

# Runtime collision follows the supplied bridge artwork; no render meshes or
# imported resources are changed. Sample distance starts at the visual front.
const SUPPORT_GROUP: StringName = &"midori_walk_surface"
const SAMPLE_INTERVAL := 1.0
const LATERAL_SAMPLE_OFFSET := 0.75
const ENDPOINT_INSET := 0.15
const FLOOR_MARGIN := 0.06
const OUTLIER_MARGIN := 0.045
const SLAB_DEPTH := 0.20

static func align_front_tread(bridge: Node3D, world_a: Vector2, world_b: Vector2, width: float, target_height: float, boot_park: Node = null) -> void:
	var triangles: Array[Dictionary] = await _collect_triangles(bridge,world_a,(world_b-world_a).normalized(),boot_park)
	var triangle_index: Dictionary = await _index_triangles(triangles,boot_park)
	var start := INF
	var end := -INF
	for triangle: Dictionary in triangles:
		start = minf(start,float(triangle.min_along))
		end = maxf(end,float(triangle.max_along))
	var front := _endpoint_height(triangles,start,end,minf(LATERAL_SAMPLE_OFFSET,width*0.18),false,triangle_index)
	if is_finite(front):
		bridge.global_position.y += target_height-front
	else:
		push_error("Midori bridge front tread could not be aligned")

static func install_deck(
	bridge: Node3D,
	parent: Node3D,
	id: String,
	world_a: Vector2,
	world_b: Vector2,
	width: float,
	boot_park: Node = null
) -> Dictionary:
	var authored_delta := world_b - world_a
	if bridge == null or parent == null or authored_delta.length() < 0.01 or width <= 0.0:
		push_error("BRIDGE_WALK_PROFILE: invalid inputs for %s" % id)
		return {}
	var axis := authored_delta.normalized()
	var triangles: Array[Dictionary] = await _collect_triangles(bridge, world_a, axis,boot_park)
	var triangle_index: Dictionary = await _index_triangles(triangles,boot_park)
	if triangles.is_empty():
		push_error("BRIDGE_WALK_PROFILE: no upward source triangles for %s" % id)
		return {}
	var min_along := INF
	var max_along := -INF
	for triangle: Dictionary in triangles:
		min_along = minf(min_along, float(triangle.min_along))
		max_along = maxf(max_along, float(triangle.max_along))
	var span := max_along - min_along
	if span < 0.1:
		push_error("BRIDGE_WALK_PROFILE: invalid source span for %s" % id)
		return {}
	var lane_offset := minf(LATERAL_SAMPLE_OFFSET, width * 0.18)
	var front_height := _endpoint_height(triangles, min_along, max_along, lane_offset, false,triangle_index)
	var back_height := _endpoint_height(triangles, min_along, max_along, lane_offset, true,triangle_index)
	if front_height == -INF or back_height == -INF:
		push_error("BRIDGE_WALK_PROFILE: source tread endpoints could not be sampled for %s" % id)
		return {}
	var minimum_floor := minf(front_height, back_height) - FLOOR_MARGIN
	var section_count := maxi(1, int(ceil(span / SAMPLE_INTERVAL)))
	var step := span / float(section_count)
	var raw: Array[float] = []
	var missing_samples := 0
	for index: int in range(section_count + 1):
		await LoadingBudget.checkpoint(boot_park)
		var along := min_along + float(index) * step
		var sample_along := clampf(along, min_along + ENDPOINT_INSET, max_along - ENDPOINT_INSET)
		var height := _sample_height(triangles, sample_along, lane_offset, minimum_floor,triangle_index)
		if height == -INF:
			missing_samples += 1
		raw.append(height)
	# The near-edge tread, rather than a thin bevel or plank gap, anchors ramps.
	raw[0] = front_height
	raw[-1] = back_height
	var original_gap := _maximum_gap(raw, step)
	var rejected_outliers := _filter_outliers(raw, step)
	var maximum_gap := _maximum_gap(raw, step)
	_fill_gaps(raw)
	_smooth_profile(raw)
	var samples: Array[Vector2] = []
	var highest_height := -INF
	for index: int in range(raw.size()):
		samples.append(Vector2(float(index) * step, raw[index]))
		highest_height = maxf(highest_height, raw[index])
	var start := world_a + axis * min_along
	var end := world_a + axis * max_along
	var floor := _build_floor(parent, id, start, axis, width, samples)
	var guard: StaticBody3D = await _build_artwork_collision(bridge,parent,id,start,axis,width,boot_park)
	var spec := {
		"centre": (start + end) * 0.5,
		"axis": axis,
		"width": width,
		"span": span,
		"start": start,
		"end": end,
		"world_a": world_a,
		"world_b": world_b,
		"samples": samples,
		"floor": floor,
		"guard": guard,
		"front_height": front_height,
		"back_height": back_height,
		"highest_height": highest_height,
		"missing_samples": missing_samples,
		"rejected_outliers": rejected_outliers,
		"max_sample_gap": maximum_gap,
	}
	print("BRIDGE_WALK_PROFILE: id=%s source_triangles=%d sections=%d start=%s end=%s front_y=%.4f back_y=%.4f highest_y=%.4f missing=%d rejected=%d original_gap_m=%.3f max_sampling_gap_m=%.3f" % [
		id, triangles.size(), section_count, start, end, front_height, back_height,
		highest_height, missing_samples, rejected_outliers, original_gap, maximum_gap,
	])
	return spec

static func _build_artwork_collision(bridge: Node3D, parent: Node3D, id: String, start: Vector2, axis: Vector2, width: float, boot_park: Node = null) -> StaticBody3D:
	# The supplied low-poly structure supplies exact rail/post barriers. The
	# separate fitted floor closes plank gaps without changing the visible art.
	var faces := PackedVector3Array()
	var lateral := Vector2(-axis.y,axis.x)
	# Each mesh's faces are read here; the per-triangle filter runs on workers, one
	# mesh per task, and the kept faces are joined in mesh order (as the serial loop).
	var units: Array = []
	for node: Node in bridge.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		if visual.mesh == null:
			continue
		units.append({"source": visual.mesh.get_faces(), "xform": visual.global_transform, "start": start, "lateral": lateral, "width": width, "faces": PackedVector3Array()})
	await _run_group(_artwork_unit.bind(units), units.size(), boot_park, "bridge.artwork_collision")
	for unit: Dictionary in units:
		faces.append_array(unit.faces)
	var body := StaticBody3D.new()
	body.name = "Bridge_%s_ArtworkBarriers" % id
	body.top_level = true
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.global_transform = Transform3D.IDENTITY
	print("BRIDGE_ARTWORK_COLLISION: id=%s triangles=%d" % [id,faces.size()/3])
	return body

static func height_at(spec: Dictionary, world_p: Vector2) -> float:
	if spec.is_empty() or not spec.has("samples"):
		return -INF
	var axis: Vector2 = spec.axis
	var start: Vector2 = spec.start
	var relative := world_p - start
	var along := relative.dot(axis)
	var lateral := relative.dot(Vector2(-axis.y, axis.x))
	if along < -0.001 or along > float(spec.span) + 0.001 or absf(lateral) > float(spec.width) * 0.5:
		return -INF
	var samples: Array[Vector2] = spec.samples
	if samples.size() < 2:
		return -INF
	along = clampf(along, 0.0, float(spec.span))
	var step := samples[1].x - samples[0].x
	var index := mini(int(floor(along / step)), samples.size() - 2)
	var a := samples[index]
	var b := samples[index + 1]
	return lerpf(a.y, b.y, clampf((along - a.x) / (b.x - a.x), 0.0, 1.0))

static func _collect_triangles(bridge: Node3D, origin: Vector2, axis: Vector2, boot_park: Node = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visuals: Array[MeshInstance3D] = []
	if bridge is MeshInstance3D:
		visuals.append(bridge as MeshInstance3D)
	for child: Node in bridge.find_children("*", "MeshInstance3D", true, false):
		visuals.append(child as MeshInstance3D)
	var perpendicular := Vector2(-axis.y, axis.x)
	# Each surface's arrays and its mesh's transform are read here; the triangle loop
	# runs on workers, one surface per task, and the results are joined in surface
	# order (as the serial loop produced them).
	var units: Array = []
	for visual: MeshInstance3D in visuals:
		if visual.mesh == null:
			continue
		var xform := visual.global_transform
		var normal_basis := xform.basis.inverse().transposed()
		for surface: int in range(visual.mesh.get_surface_count()):
			var triangles: Array[Dictionary] = []
			units.append({"arrays": visual.mesh.surface_get_arrays(surface), "xform": xform, "normal_basis": normal_basis,
				"origin": origin, "axis": axis, "perpendicular": perpendicular, "triangles": triangles})
	await _run_group(_collect_unit.bind(units), units.size(), boot_park, "bridge.collect_triangles")
	for unit: Dictionary in units:
		result.append_array(unit.triangles)
	return result

## Worker: the upward triangles of one surface (the former loop body). Only `unit`.
static func _collect_unit(index: int, units: Array) -> void:
	var unit: Dictionary = units[index]
	var arrays: Array = unit.arrays
	var xform: Transform3D = unit.xform
	var normal_basis: Basis = unit.normal_basis
	var origin: Vector2 = unit.origin
	var axis: Vector2 = unit.axis
	var perpendicular: Vector2 = unit.perpendicular
	var result: Array[Dictionary] = unit.triangles
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		normals = arrays[Mesh.ARRAY_NORMAL]
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else positions.size()
	for first: int in range(0, count - 2, 3):
		var ia := indices[first] if not indices.is_empty() else first
		var ib := indices[first + 1] if not indices.is_empty() else first + 1
		var ic := indices[first + 2] if not indices.is_empty() else first + 2
		var a_world := xform * positions[ia]
		var b_world := xform * positions[ib]
		var c_world := xform * positions[ic]
		var normal: Vector3
		if normals.size() == positions.size():
			normal = (normal_basis * (normals[ia] + normals[ib] + normals[ic])).normalized()
		else:
			# Godot's front-face index winding is clockwise.
			normal = (c_world - a_world).cross(b_world - a_world).normalized()
		if normal.y < 0.60:
			continue
		var a := _project_vertex(a_world, origin, axis, perpendicular)
		var b := _project_vertex(b_world, origin, axis, perpendicular)
		var c := _project_vertex(c_world, origin, axis, perpendicular)
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(denominator) < 0.00000001:
			continue
		result.append({
			"a": a, "b": b, "c": c, "denominator": denominator,
			"min_along": minf(a.x, minf(b.x, c.x)),
			"max_along": maxf(a.x, maxf(b.x, c.x)),
			"min_lateral": minf(a.z, minf(b.z, c.z)),
			"max_lateral": maxf(a.z, maxf(b.z, c.z)),
		})

## Worker: one mesh's rail/post faces for the barrier collision (the former loop body).
static func _artwork_unit(index: int, units: Array) -> void:
	var unit: Dictionary = units[index]
	var source: PackedVector3Array = unit.source
	var xform: Transform3D = unit.xform
	var start: Vector2 = unit.start
	var lateral: Vector2 = unit.lateral
	var width: float = unit.width
	var faces: PackedVector3Array = unit.faces
	for index_face: int in range(0,source.size(),3):
		var triangle := PackedVector3Array()
		var min_side := INF
		var max_side := -INF
		for corner: int in range(3):
			var p := xform*source[index_face+corner]
			var side := (Vector2(p.x,p.z)-start).dot(lateral)
			min_side = minf(min_side,side)
			max_side = maxf(max_side,side)
			triangle.append(p)
		# Keep exact side rail/post geometry; the central tread remains on
		# its smooth fitted floor instead of catching individual plank edges.
		if min_side >= width*0.32 or max_side <= -width*0.32:
			faces.append_array(triangle)
	unit.faces = faces

## fn(index) for index in [0, count) on all worker threads, waited for at once:
## the parallel loop is short (~0.1 s), and yielding a frame per wait cost more
## (measured: +1.1 s over the three bridges) than it gave back. A budget turn first.
static func _run_group(fn: Callable, count: int, boot_park: Node, label: String) -> void:
	if count <= 0: return
	await LoadingBudget.checkpoint(boot_park)
	var task := WorkerThreadPool.add_group_task(fn, count, -1, true, label)
	WorkerThreadPool.wait_for_group_task_completion(task)

static func _project_vertex(point: Vector3, origin: Vector2, axis: Vector2, perpendicular: Vector2) -> Vector3:
	var relative := Vector2(point.x, point.z) - origin
	return Vector3(relative.dot(axis), point.y, relative.dot(perpendicular))

static func _endpoint_height(triangles: Array[Dictionary], low: float, high: float, lane: float, at_back: bool, triangle_index: Dictionary = {}) -> float:
	for inset: float in [ENDPOINT_INSET, 0.35, 0.60, 1.0, 1.5]:
		var along := high - inset if at_back else low + inset
		if along <= low or along >= high:
			continue
		var height := _sample_height(triangles, along, lane, -INF,triangle_index)
		if height != -INF:
			return height
	return -INF

static func _sample_height(triangles: Array[Dictionary], along: float, lane: float, floor_minimum: float, triangle_index: Dictionary = {}) -> float:
	var heights: Array[float] = []
	var candidates: Array = triangles if triangle_index.is_empty() else triangle_index.get(floori(along),[])
	for lateral: float in [-lane, 0.0, lane]:
		var highest := -INF
		for triangle: Dictionary in candidates:
			if along < float(triangle.min_along) - 0.0001 or along > float(triangle.max_along) + 0.0001:
				continue
			if lateral < float(triangle.min_lateral) - 0.0001 or lateral > float(triangle.max_lateral) + 0.0001:
				continue
			var a: Vector3 = triangle.a
			var b: Vector3 = triangle.b
			var c: Vector3 = triangle.c
			var denominator: float = triangle.denominator
			var u := ((b.z - c.z) * (along - c.x) + (c.x - b.x) * (lateral - c.z)) / denominator
			var v := ((c.z - a.z) * (along - c.x) + (a.x - c.x) * (lateral - c.z)) / denominator
			var w := 1.0 - u - v
			if minf(u, minf(v, w)) < -0.00001:
				continue
			var height := u * a.y + v * b.y + w * c.y
			if height >= floor_minimum:
				highest = maxf(highest, height)
		if highest != -INF:
			heights.append(highest)
	if heights.size() < 2:
		return -INF
	heights.sort()
	return heights[1] if heights.size() == 3 else (heights[0] + heights[1]) * 0.5

static func _filter_outliers(heights: Array[float], step: float) -> int:
	var source: Array[float] = heights.duplicate()
	var rejected := 0
	for index: int in range(1, heights.size() - 1):
		if source[index] == -INF:
			continue
		var left := index - 1
		var right := index + 1
		while left > 0 and source[left] == -INF:
			left -= 1
		while right < source.size() - 1 and source[right] == -INF:
			right += 1
		if source[left] == -INF or source[right] == -INF:
			continue
		# Wide plank gaps should be interpolated, not used to judge curvature.
		if float(index - left) * step > 3.0 or float(right - index) * step > 3.0:
			continue
		var predicted := lerpf(source[left], source[right], float(index - left) / float(right - left))
		if absf(source[index] - predicted) > OUTLIER_MARGIN:
			heights[index] = -INF
			rejected += 1
	return rejected

static func _maximum_gap(heights: Array[float], step: float) -> float:
	var run := 0
	var maximum := 0
	for height: float in heights:
		if height == -INF:
			run += 1
			maximum = maxi(maximum, run)
		else:
			run = 0
	return float(maximum + 1) * step if maximum > 0 else 0.0

static func _fill_gaps(heights: Array[float]) -> void:
	var left := 0
	for right: int in range(1, heights.size()):
		if heights[right] == -INF:
			continue
		for index: int in range(left + 1, right):
			heights[index] = lerpf(heights[left], heights[right], float(index - left) / float(right - left))
		left = right

static func _smooth_profile(heights: Array[float]) -> void:
	var source: Array[float] = heights.duplicate()
	for index: int in range(1, heights.size() - 1):
		var smoothed := (source[index - 1] + source[index] * 2.0 + source[index + 1]) * 0.25
		if absf(smoothed - source[index]) <= 0.025:
			heights[index] = smoothed

static func _build_floor(parent: Node3D, id: String, start: Vector2, axis: Vector2, width: float, samples: Array[Vector2]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BridgeWalkway_%s" % id
	body.top_level = true
	body.collision_layer = 1
	body.collision_mask = 1
	body.transform = Transform3D(Basis(
		Vector3(axis.x, 0.0, axis.y), Vector3.UP, Vector3(-axis.y, 0.0, axis.x)
	), Vector3(start.x, 0.0, start.y))
	parent.add_child(body)
	body.add_to_group(SUPPORT_GROUP)
	for index: int in range(samples.size() - 1):
		var a := samples[index]
		var b := samples[index + 1]
		var points := PackedVector3Array()
		for side: float in [-1.0, 1.0]:
			var lateral := side * width * 0.5
			points.append(Vector3(a.x, a.y, lateral))
			points.append(Vector3(b.x, b.y, lateral))
			points.append(Vector3(a.x, a.y - SLAB_DEPTH, lateral))
			points.append(Vector3(b.x, b.y - SLAB_DEPTH, lateral))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.name = "DeckSection_%03d" % index
		collision.shape = shape
		body.add_child(collision)
	return body

static func _index_triangles(triangles: Array[Dictionary], boot_park: Node) -> Dictionary:
	var result: Dictionary = {}
	for index: int in triangles.size():
		if index % 256 == 0: await LoadingBudget.checkpoint(boot_park)
		var triangle: Dictionary = triangles[index]
		for cell: int in range(floori(float(triangle.min_along)-0.0001),floori(float(triangle.max_along)+0.0001)+1):
			if not result.has(cell): result[cell]=[]
			result[cell].append(triangle)
	return result
