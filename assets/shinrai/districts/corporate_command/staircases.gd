extends Node3D
## Two independent stair cores. Geometry and foot-space routes use traversal_layout.gd.
const Layout := preload("res://assets/shinrai/districts/corporate_command/traversal_layout.gd")
const FLIGHT_WIDTH := 2.2
const FLIGHT_OFFSET := 1.3
const FRONT_Z := 3.8
const REAR_Z := -0.4
const RUN := FRONT_Z - REAR_Z
const MAX_RISER := 0.18
const GUARD_HEIGHT := 1.1
const LANDING_THICKNESS := 0.18

var flight_records: Array[Dictionary] = []
var _tread_material: StandardMaterial3D
var _rail_material: StandardMaterial3D
var _landing_material: StandardMaterial3D


func _ready() -> void:
	_tread_material = _material(Color(0.24, 0.28, 0.31), 0.25)
	_rail_material = _material(Color(0.09, 0.12, 0.15), 0.65)
	_landing_material = _material(Color(0.32, 0.35, 0.37), 0.15)
	for core_index in range(Layout.CORE_CENTRES.size()):
		_build_core(core_index)
	set_meta("stair_levels", Layout.STAIR_LEVELS)
	set_meta("max_riser_metres", MAX_RISER)
	set_meta("collision_contract", "Continuous convex ramps under visible treads; 1.1m side guards; open inner front landing")


func _material(colour: Color, metallic: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.metallic = metallic
	result.roughness = 0.55
	return result


func _visual_box(label: String, centre: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.position = centre
	add_child(mesh_instance)
	return mesh_instance


func _solid_box(label: String, centre: Vector3, size: Vector3, material: Material) -> void:
	_visual_box(label, centre, size, material)
	var body := StaticBody3D.new()
	body.name = label + "_Body"
	body.position = centre
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _convex_collision(label: String, points: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _beam(label: String, start: Vector3, finish: Vector3, thickness: float) -> void:
	var result := _visual_box(label, (start + finish) * 0.5,
		Vector3(thickness, thickness, start.distance_to(finish)), _rail_material)
	# start and finish are local to the staircase, so orient in local space;
	# look_at_from_position would read them as world points and strand the rail.
	var along := (finish - start).normalized()
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	result.transform = Transform3D(Basis.looking_at(along, up), (start + finish) * 0.5)


func _flight_guard(label: String, x: float, start_z: float, end_z: float, start_y: float, end_y: float) -> void:
	var points := PackedVector3Array()
	for side in [-0.045, 0.045]:
		points.append(Vector3(x + side, start_y, start_z))
		points.append(Vector3(x + side, start_y + GUARD_HEIGHT, start_z))
		points.append(Vector3(x + side, end_y, end_z))
		points.append(Vector3(x + side, end_y + GUARD_HEIGHT, end_z))
	_convex_collision(label + "_Guard", points)
	_beam(label + "_Handrail", Vector3(x, start_y + GUARD_HEIGHT, start_z),
		Vector3(x, end_y + GUARD_HEIGHT, end_z), 0.065)
	_beam(label + "_Midrail", Vector3(x, start_y + 0.55, start_z),
		Vector3(x, end_y + 0.55, end_z), 0.035)
	for index in range(6):
		var fraction := float(index) / 5.0
		var base := Vector3(x, lerpf(start_y, end_y, fraction), lerpf(start_z, end_z, fraction))
		_visual_box(label + "_Post_%d" % index, base + Vector3.UP * GUARD_HEIGHT * 0.5,
			Vector3(0.045, GUARD_HEIGHT, 0.045), _rail_material)


func _landing_guard(label: String, centre: Vector3, size: Vector3) -> void:
	# The guard plane is collision-solid; slim rails/posts provide its visible boundary.
	var body := StaticBody3D.new()
	body.name = label + "_Guard"
	body.position = centre
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var along_x := size.x > size.z
	var direction := Vector3.RIGHT if along_x else Vector3.BACK
	var length := size.x if along_x else size.z
	_beam(label + "_Handrail", centre + Vector3.UP * GUARD_HEIGHT * 0.5 - direction * length * 0.5,
		centre + Vector3.UP * GUARD_HEIGHT * 0.5 + direction * length * 0.5, 0.065)
	for index in range(4):
		var at := centre + direction * (float(index) / 3.0 - 0.5) * length
		_visual_box(label + "_Post_%d" % index, at, Vector3(0.045, GUARD_HEIGHT, 0.045), _rail_material)


func _build_flight(core_index: int, interval: int, lane: String, centre_x: float,
		start_z: float, end_z: float, low_y: float, high_y: float) -> void:
	var prefix := "Core%d_Level%d_%s" % [core_index, interval, lane]
	var rise := high_y - low_y
	var steps := int(ceil(rise / MAX_RISER))
	var riser := rise / float(steps)
	var tread_depth := RUN / float(steps)
	for index in range(steps):
		var fraction := (float(index) + 0.5) / float(steps)
		var top := low_y + riser * float(index + 1)
		_visual_box(prefix + "_Tread_%02d" % index,
			Vector3(centre_x, top - 0.06, lerpf(start_z, end_z, fraction)),
			Vector3(FLIGHT_WIDTH, 0.12, tread_depth + 0.008), _tread_material)
	var points := PackedVector3Array()
	# A thin sloping slab preserves headroom under the next flight. A wedge filled
	# to low_y along its whole run would obstruct the 3.5 m floor intervals.
	for x in [centre_x - FLIGHT_WIDTH * 0.5, centre_x + FLIGHT_WIDTH * 0.5]:
		points.append(Vector3(x, low_y - 0.2, start_z))
		points.append(Vector3(x, low_y, start_z))
		points.append(Vector3(x, high_y - 0.2, end_z))
		points.append(Vector3(x, high_y, end_z))
	_convex_collision(prefix + "_SmoothRamp", points)
	_flight_guard(prefix + "_Left", centre_x - 1.16, start_z, end_z, low_y, high_y)
	_flight_guard(prefix + "_Right", centre_x + 1.16, start_z, end_z, low_y, high_y)
	flight_records.append({"core": core_index, "interval": interval, "lane": lane,
		"bottom_y": low_y, "top_y": high_y, "riser": riser, "tread_depth": tread_depth,
		"steps": steps, "slope_degrees": rad_to_deg(atan2(rise, RUN)),
		"bounds": AABB(Vector3(centre_x - 1.1, low_y - 0.2, REAR_Z), Vector3(2.2, rise + 0.2, RUN))})


func _build_core(core_index: int) -> void:
	var cx: float = Layout.CORE_CENTRES[core_index]
	for level_index in range(Layout.STAIR_LEVELS.size()):
		var height: float = Layout.STAIR_LEVELS[level_index]
		_solid_box("Core%d_Landing%d" % [core_index, level_index],
			Vector3(cx, height - LANDING_THICKNESS * 0.5, 4.65),
			Vector3(5.2, LANDING_THICKNESS, 1.7), _landing_material)
		_landing_guard("Core%d_FrontGuard%d" % [core_index, level_index],
			Vector3(cx, height + GUARD_HEIGHT * 0.5, 5.47), Vector3(5.12, GUARD_HEIGHT, 0.06))
		_landing_guard("Core%d_CentreFrontGuard%d" % [core_index, level_index],
			Vector3(cx, height + GUARD_HEIGHT * 0.5, FRONT_Z), Vector3(0.28, GUARD_HEIGHT, 0.06))
		if level_index == 0:
			_landing_guard("Core%d_GroundVoidGuard" % core_index,
				Vector3(cx + FLIGHT_OFFSET, height + GUARD_HEIGHT * 0.5, FRONT_Z), Vector3(2.32, GUARD_HEIGHT, 0.06))
		if level_index == Layout.STAIR_LEVELS.size() - 1:
			_landing_guard("Core%d_RoofVoidGuard" % core_index,
				Vector3(cx - FLIGHT_OFFSET, height + GUARD_HEIGHT * 0.5, FRONT_Z), Vector3(2.32, GUARD_HEIGHT, 0.06))
		# Outside edge only: the inner side must remain open to the shared core foyer.
		var outside_x := cx - 2.55 if core_index == 0 else cx + 2.55
		_landing_guard("Core%d_OuterFrontGuard%d" % [core_index, level_index],
			Vector3(outside_x, height + GUARD_HEIGHT * 0.5, 4.65), Vector3(0.06, GUARD_HEIGHT, 1.7))
		if level_index >= Layout.STAIR_LEVELS.size() - 1:
			continue
		var next_height: float = Layout.STAIR_LEVELS[level_index + 1]
		var mid_height := (height + next_height) * 0.5
		_solid_box("Core%d_MidLanding%d" % [core_index, level_index],
			Vector3(cx, mid_height - LANDING_THICKNESS * 0.5, -1.3),
			Vector3(5.2, LANDING_THICKNESS, 1.8), _landing_material)
		_landing_guard("Core%d_BackGuard%d" % [core_index, level_index],
			Vector3(cx, mid_height + GUARD_HEIGHT * 0.5, -2.17), Vector3(5.12, GUARD_HEIGHT, 0.06))
		_landing_guard("Core%d_CentreMidGuard%d" % [core_index, level_index],
			Vector3(cx, mid_height + GUARD_HEIGHT * 0.5, REAR_Z), Vector3(0.28, GUARD_HEIGHT, 0.06))
		for side in [-1.0, 1.0]:
			_landing_guard("Core%d_MidSide%d_%s" % [core_index, level_index, str(side)],
				Vector3(cx + side * 2.55, mid_height + GUARD_HEIGHT * 0.5, -1.3),
				Vector3(0.06, GUARD_HEIGHT, 1.8))
		_build_flight(core_index, level_index, "LeftUp", cx - FLIGHT_OFFSET, FRONT_Z, REAR_Z, height, mid_height)
		_build_flight(core_index, level_index, "RightUp", cx + FLIGHT_OFFSET, REAR_Z, FRONT_Z, mid_height, next_height)


func _level_index(height: float) -> int:
	for index in range(Layout.STAIR_LEVELS.size()):
		if absf(Layout.STAIR_LEVELS[index] - height) < 0.03:
			return index
	return -1


func route_waypoints(core_index: int, from_level: float, to_level: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var first := _level_index(minf(from_level, to_level))
	var last := _level_index(maxf(from_level, to_level))
	if core_index < 0 or core_index >= Layout.CORE_CENTRES.size() or first < 0 or last < 0:
		push_error("Stair route requires a core index and actual STAIR_LEVELS elevations.")
		return result
	var cx: float = Layout.CORE_CENTRES[core_index]
	result.append(to_global(Vector3(cx, Layout.STAIR_LEVELS[first], 4.65)))
	for index in range(first, last):
		var low: float = Layout.STAIR_LEVELS[index]
		var high: float = Layout.STAIR_LEVELS[index + 1]
		var middle := (low + high) * 0.5
		result.append(to_global(Vector3(cx - FLIGHT_OFFSET, low, 4.65)))
		result.append(to_global(Vector3(cx - FLIGHT_OFFSET, middle, -1.3)))
		result.append(to_global(Vector3(cx + FLIGHT_OFFSET, middle, -1.3)))
		result.append(to_global(Vector3(cx + FLIGHT_OFFSET, high, 4.65)))
	result.append(to_global(Vector3(cx, Layout.STAIR_LEVELS[last], 4.65)))
	if from_level > to_level:
		result.reverse()
	return result


func geometry_bounds(core_index: int) -> AABB:
	var cx: float = Layout.CORE_CENTRES[core_index]
	return AABB(Vector3(cx - 2.6, Layout.STAIR_LEVELS[0] - LANDING_THICKNESS, -2.2),
		Vector3(5.2, Layout.STAIR_LEVELS[-1] - Layout.STAIR_LEVELS[0] + LANDING_THICKNESS + GUARD_HEIGHT, 7.7))


func flight_bounds() -> Array[Dictionary]:
	return flight_records.duplicate(true)
