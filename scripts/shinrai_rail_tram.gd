extends Node3D

## The loop tram: two low-floor cars joined by a gangway, doors on the park side only.
## Built from code so it needs no imported model. Each car is its own body placed on the
## track; a car's origin sits at rail level under its centre, -Z toward the front.

const Track := preload("res://scripts/shinrai_rail_track.gd")

const CAR_LENGTH := 10.4
const GAP := 0.9
const HALF_W := 1.25
const HALF_L := CAR_LENGTH * 0.5
const FLOOR_Y := 0.35
const SILL_Y := 1.15
const GLASS_TOP := 2.3
const CEILING_Y := 2.55
const ROOF_Y := 2.75
const WALL := 0.08
const DOOR_Z: Array[float] = [-2.6, 2.6]
const DOOR_HALF := 0.65
const DOOR_TOP := 2.35
const RAMP_REACH := 1.45
const CAR_SPACING := CAR_LENGTH + GAP

var cars: Array[AnimatableBody3D] = []
var door_ratio := 0.0
var _placed_s := NAN
var _leaves: Array[Dictionary] = []
var _door_blocks: Array[CollisionShape3D] = []
var _ramps: Array[Dictionary] = []
var _lamps: Array[OmniLight3D] = []
var _mat := {}


func _init() -> void:
	name = "ShinraiTram"
	_materials()
	for index: int in 2:
		var car := AnimatableBody3D.new()
		car.name = "Car%d" % index
		car.sync_to_physics = false
		car.collision_layer = 1
		car.collision_mask = 0
		add_child(car)
		cars.append(car)
		_build_car(car, index)
	set_doors(0.0)


func _materials() -> void:
	_mat.shell = _solid(Color(0.80, 0.80, 0.77), 0.42, 0.15)
	_mat.skirt = _solid(Color(0.10, 0.11, 0.12), 0.6, 0.2)
	_mat.accent = _solid(Color(0.16, 0.30, 0.27), 0.45, 0.2)
	_mat.dark = _solid(Color(0.05, 0.05, 0.055), 0.8, 0.0)
	_mat.floor = _solid(Color(0.17, 0.18, 0.19), 0.85, 0.0)
	_mat.seat = _solid(Color(0.20, 0.29, 0.27), 0.9, 0.0)
	_mat.inner = _solid(Color(0.70, 0.70, 0.67), 0.6, 0.0)
	_mat.steel = _solid(Color(0.62, 0.63, 0.64), 0.28, 0.9)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.09, 0.13, 0.13, 0.42)
	glass.roughness = 0.06
	glass.metallic = 0.3
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.glass = glass
	_mat.light = _glow(Color(1.0, 0.94, 0.82), 1.6)
	_mat.head = _glow(Color(1.0, 0.97, 0.9), 3.0)
	_mat.tail = _glow(Color(0.9, 0.08, 0.05), 2.0)


func _solid(colour: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _span(parent: Node3D, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, material: Material) -> MeshInstance3D:
	return _box(parent, Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), material)


func _rod(parent: Node3D, radius: float, from: Vector3, to: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 10
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = (from + to) * 0.5
	var along := (to - from).normalized()
	if absf(along.dot(Vector3.UP)) < 0.999:
		instance.basis = Basis(Quaternion(Vector3.UP, along))


func _solid_shape(car: AnimatableBody3D, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0))
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	car.add_child(shape)
	return shape


func _build_car(car: AnimatableBody3D, index: int) -> void:
	var lead := index == 0
	# The second car carries the gangway on its front end.
	var z_front := -HALF_L if lead else -HALF_L - GAP
	var z_back := HALF_L
	# Floor, underframe and skirts.
	_span(car, -HALF_W, HALF_W, FLOOR_Y - 0.1, FLOOR_Y, z_front, z_back, _mat.floor)
	_span(car, -HALF_W + 0.05, HALF_W - 0.05, 0.16, FLOOR_Y - 0.1, -HALF_L + 0.3, HALF_L - 0.3, _mat.skirt)
	for side: float in [-1.0, 1.0]:
		_span(car, side * (HALF_W - 0.04), side * HALF_W, 0.09, FLOOR_Y, -HALF_L, HALF_L, _mat.skirt)
	for bogie_z: float in [-3.3, 3.3]:
		_span(car, -0.95, 0.95, 0.07, 0.3, bogie_z - 1.0, bogie_z + 1.0, _mat.dark)
		for axle_z: float in [bogie_z - 0.62, bogie_z + 0.62]:
			_rod(car, 0.3, Vector3(-0.78, 0.3, axle_z), Vector3(0.78, 0.3, axle_z), _mat.steel)
	# Side walls.
	_side(car, -1.0, [])
	_side(car, 1.0, DOOR_Z)
	# Roof, ceiling and the equipment housing on top.
	_span(car, -HALF_W, HALF_W, CEILING_Y, ROOF_Y, z_front, z_back, _mat.shell)
	_span(car, -HALF_W + WALL, HALF_W - WALL, CEILING_Y - 0.03, CEILING_Y, -HALF_L, HALF_L, _mat.inner)
	_span(car, -0.85, 0.85, ROOF_Y, ROOF_Y + 0.26, -3.4, 3.4, _mat.skirt)
	_span(car, -0.7, 0.7, ROOF_Y + 0.26, ROOF_Y + 0.32, -3.0, 3.0, _mat.dark)
	for panel_z: float in [-2.6, 2.6]:
		_span(car, -0.16, 0.16, CEILING_Y - 0.045, CEILING_Y - 0.03, panel_z - 1.6, panel_z + 1.6, _mat.light)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.2, 0.0)
	lamp.omni_range = 7.0
	lamp.light_energy = 0.7
	lamp.light_color = Color(1.0, 0.93, 0.82)
	lamp.shadow_enabled = false
	car.add_child(lamp)
	_lamps.append(lamp)
	# The outer end: cab face. The inner end stays open to the gangway.
	var end_z := -HALF_L if lead else HALF_L
	var out := -1.0 if lead else 1.0
	_span(car, -HALF_W, HALF_W, FLOOR_Y, 1.05, end_z, end_z - out * WALL, _mat.shell)
	_span(car, -HALF_W, HALF_W, DOOR_TOP, CEILING_Y, end_z, end_z - out * WALL, _mat.shell)
	_span(car, -HALF_W + 0.1, HALF_W - 0.1, 1.05, DOOR_TOP, end_z, end_z - out * 0.03, _mat.glass)
	for side: float in [-1.0, 1.0]:
		_span(car, side * (HALF_W - 0.1), side * HALF_W, 1.05, DOOR_TOP, end_z, end_z - out * WALL, _mat.shell)
	_span(car, -1.12, 1.12, 0.14, 0.62, end_z, end_z + out * 0.28, _mat.skirt)
	_span(car, -0.95, 0.95, 0.68, 0.76, end_z + out * 0.005, end_z + out * 0.03, _mat.head if lead else _mat.tail)
	_span(car, -0.8, 0.8, 2.37, 2.52, end_z + out * 0.005, end_z + out * 0.02, _mat.dark)
	var sign := Label3D.new()
	sign.text = "MIDORI LINE"
	sign.font_size = 56
	sign.pixel_size = 0.0022
	sign.modulate = Color(1.0, 0.72, 0.25)
	sign.outline_size = 0
	sign.shaded = false
	sign.position = Vector3(0.0, 2.445, end_z + out * 0.025)
	sign.rotation.y = 0.0 if not lead else PI
	car.add_child(sign)
	_solid_shape(car, -HALF_W, HALF_W, FLOOR_Y, ROOF_Y, end_z, end_z - out * WALL)
	# Gangway on the second car's front: floor is already there, add its sides and top.
	if not lead:
		for side: float in [-1.0, 1.0]:
			_span(car, side * 1.0, side * 1.08, FLOOR_Y, CEILING_Y, -HALF_L - GAP, -HALF_L, _mat.dark)
			_solid_shape(car, side * 1.0, side * 1.08, FLOOR_Y, CEILING_Y, -HALF_L - GAP, -HALF_L)
			# The inner end frames beside the gangway on both cars.
		_span(car, -1.08, 1.08, CEILING_Y - 0.35, CEILING_Y, -HALF_L - GAP, -HALF_L, _mat.dark)
	var inner_z := HALF_L if lead else -HALF_L
	for side: float in [-1.0, 1.0]:
		_span(car, side * 1.0, side * HALF_W, FLOOR_Y, CEILING_Y, inner_z - 0.04, inner_z + 0.04, _mat.inner)
		_solid_shape(car, side * 1.0, side * HALF_W, FLOOR_Y, CEILING_Y, inner_z - 0.04, inner_z + 0.04)
	# Seats: a long bench on the far wall, a short one between the doors.
	_bench(car, -1.0, -4.5, 4.5)
	_bench(car, 1.0, -1.7, 1.7)
	# Handrails along the ceiling and a post beside each door.
	for side: float in [-1.0, 1.0]:
		_rod(car, 0.016, Vector3(side * 0.72, 2.22, -4.6), Vector3(side * 0.72, 2.22, 4.6), _mat.steel)
	for door_z: float in DOOR_Z:
		for offset: float in [-0.82, 0.82]:
			_rod(car, 0.018, Vector3(0.82, FLOOR_Y, door_z + offset), Vector3(0.82, CEILING_Y - 0.03, door_z + offset), _mat.steel)
	# Collision: floor, roof, far wall.
	_solid_shape(car, -HALF_W, HALF_W, FLOOR_Y - 0.25, FLOOR_Y, z_front, z_back)
	_solid_shape(car, -HALF_W, HALF_W, CEILING_Y, ROOF_Y, z_front, z_back)
	_solid_shape(car, -HALF_W, -HALF_W + WALL, FLOOR_Y, CEILING_Y, -HALF_L, HALF_L)


## One side wall. Door openings get sliding leaves, a blocker while shut and a boarding ramp.
func _side(car: AnimatableBody3D, side: float, doors: Array) -> void:
	var x_out := side * HALF_W
	var x_in := side * (HALF_W - WALL)
	var cursor := -HALF_L
	var edges: Array[float] = []
	for door_z: float in doors:
		edges.append(door_z - DOOR_HALF)
		edges.append(door_z + DOOR_HALF)
	edges.append(HALF_L)
	var solid := true
	for edge: float in edges:
		if solid:
			_wall_run(car, x_out, x_in, cursor, edge)
			_solid_shape(car, x_out, x_in, FLOOR_Y, CEILING_Y, cursor, edge)
		else:
			_span(car, x_out, x_in, DOOR_TOP, CEILING_Y, cursor, edge, _mat.shell)
			_solid_shape(car, x_out, x_in, DOOR_TOP, CEILING_Y, cursor, edge)
			_door(car, side, (cursor + edge) * 0.5)
		cursor = edge
		solid = not solid


func _wall_run(car: AnimatableBody3D, x_out: float, x_in: float, z0: float, z1: float) -> void:
	_span(car, x_out, x_in, FLOOR_Y, SILL_Y, z0, z1, _mat.shell)
	_span(car, x_out, x_in, GLASS_TOP, CEILING_Y, z0, z1, _mat.shell)
	_span(car, x_out + signf(x_out) * 0.004, x_out, 0.62, 0.9, z0, z1, _mat.accent)
	# Window posts every 1.5 m or so, glass between them.
	var count := maxi(1, roundi((z1 - z0) / 1.5))
	var pitch := (z1 - z0) / float(count)
	for step: int in count + 1:
		var post_z := z0 + pitch * float(step)
		_span(car, x_out, x_in, SILL_Y, GLASS_TOP, clampf(post_z - 0.05, z0, z1), clampf(post_z + 0.05, z0, z1), _mat.shell)
	var mid := (x_out + x_in) * 0.5
	_span(car, mid - 0.012, mid + 0.012, SILL_Y, GLASS_TOP, z0 + 0.05, z1 - 0.05, _mat.glass)


func _door(car: AnimatableBody3D, side: float, door_z: float) -> void:
	for half: float in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * (HALF_W - WALL * 0.5), 0.0, door_z + half * DOOR_HALF * 0.5)
		car.add_child(leaf)
		_span(leaf, -0.03, 0.03, FLOOR_Y, 1.1, -DOOR_HALF * 0.5, DOOR_HALF * 0.5, _mat.accent)
		_span(leaf, -0.03, 0.03, 2.22, DOOR_TOP, -DOOR_HALF * 0.5, DOOR_HALF * 0.5, _mat.accent)
		_span(leaf, -0.03, 0.03, 1.1, 2.22, half * DOOR_HALF * 0.5 - half * 0.05, half * DOOR_HALF * 0.5, _mat.accent)
		_span(leaf, -0.012, 0.012, 1.1, 2.22, -DOOR_HALF * 0.5, DOOR_HALF * 0.5, _mat.glass)
		_leaves.append({"node": leaf, "home": leaf.position, "slide": half, "side": side})
	_door_blocks.append(_solid_shape(car, side * HALF_W, side * (HALF_W - WALL), FLOOR_Y, DOOR_TOP, door_z - DOOR_HALF, door_z + DOOR_HALF))
	# Boarding ramp: slides out from under the sill down to the ground.
	var drop := FLOOR_Y + 0.02
	var slope := atan2(drop, RAMP_REACH)
	var run := sqrt(drop * drop + RAMP_REACH * RAMP_REACH)
	var plate := Node3D.new()
	car.add_child(plate)
	plate.position = Vector3(side * (HALF_W + RAMP_REACH * 0.5), FLOOR_Y - drop * 0.5 - 0.02, door_z)
	plate.rotation.z = -side * slope
	var visual := _box(plate, Vector3(run, 0.035, DOOR_HALF * 2.0 - 0.1), Vector3.ZERO, _mat.steel)
	var box := BoxShape3D.new()
	box.size = Vector3(run, 0.06, DOOR_HALF * 2.0 - 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = plate.position
	shape.rotation = plate.rotation
	car.add_child(shape)
	_ramps.append({"visual": visual, "shape": shape, "plate": plate, "home": plate.position, "side": side})


func _bench(car: AnimatableBody3D, side: float, z0: float, z1: float) -> void:
	var wall_x := side * (HALF_W - WALL)
	_span(car, wall_x, wall_x - side * 0.46, FLOOR_Y + 0.36, FLOOR_Y + 0.46, z0, z1, _mat.seat)
	_span(car, wall_x, wall_x - side * 0.42, FLOOR_Y, FLOOR_Y + 0.36, z0 + 0.1, z1 - 0.1, _mat.inner)
	_span(car, wall_x, wall_x - side * 0.09, FLOOR_Y + 0.46, FLOOR_Y + 0.92, z0, z1, _mat.seat)
	_solid_shape(car, wall_x, wall_x - side * 0.46, FLOOR_Y, FLOOR_Y + 0.46, z0, z1)


## 0 = shut, 1 = fully open with the ramps out.
func set_doors(ratio: float) -> void:
	door_ratio = clampf(ratio, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, door_ratio)
	for leaf: Dictionary in _leaves:
		var home: Vector3 = leaf.home
		leaf.node.position = home + Vector3(leaf.side * 0.07 * minf(1.0, eased * 4.0), 0.0, leaf.slide * (DOOR_HALF - 0.03) * eased)
	# Passable once the gap between the leaves is wider than a person.
	var open := 2.0 * (DOOR_HALF - 0.03) * eased > 0.8
	for block: CollisionShape3D in _door_blocks:
		block.disabled = open
	for ramp: Dictionary in _ramps:
		var home: Vector3 = ramp.home
		ramp.plate.position = home - Vector3(ramp.side * RAMP_REACH * (1.0 - eased), 0.0, 0.0)
		ramp.visual.visible = door_ratio > 0.05
		ramp.shape.disabled = not open


## Puts the lead car's centre at distance s; the second car follows behind it.
func place(s: float) -> void:
	if s == _placed_s: return
	_placed_s = s
	for index: int in cars.size():
		cars[index].global_transform = Track.frame_at(s - CAR_SPACING * float(index))


func set_lit(lit: bool) -> void:
	for lamp: OmniLight3D in _lamps:
		lamp.visible = lit


## The car whose cabin holds this world point, or null.
func car_holding(point: Vector3) -> AnimatableBody3D:
	for index: int in cars.size():
		var local := cars[index].global_transform.affine_inverse() * point
		var front := -HALF_L if index == 0 else -HALF_L - GAP
		if absf(local.x) <= HALF_W - WALL and local.z >= front and local.z <= HALF_L and local.y >= FLOOR_Y - 0.3 and local.y <= CEILING_Y:
			return cars[index]
	return null


## True when this world point is in a doorway or on a boarding ramp, outside the cabin.
func door_blocked(point: Vector3) -> bool:
	for car: AnimatableBody3D in cars:
		var local := car.global_transform.affine_inverse() * point
		if local.x <= HALF_W - WALL or local.x > HALF_W + RAMP_REACH or local.y < -0.4 or local.y > CEILING_Y: continue
		for door_z: float in DOOR_Z:
			if absf(local.z - door_z) <= DOOR_HALF + 0.36: return true
	return false


## World point just outside a door at ground level (car 0, front door by default).
func door_ground(car_index: int = 0, door_index: int = 0) -> Vector3:
	return cars[car_index].global_transform * Vector3(HALF_W + RAMP_REACH + 0.6, 0.1, DOOR_Z[door_index])
