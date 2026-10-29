extends Node3D
## Standalone lift: physical moving cab, collision-backed landing gates, no actor teleport.
const Layout = preload("res://assets/shinrai/districts/corporate_command/traversal_layout.gd")
const SHAFT_Z := -0.25
const DOOR_Z := 1.25
const CAB_DOOR_Z := 1.075
const CLOSED_X: Array[float] = [-0.54, -0.18, 0.18, 0.54]
const OPEN_X: Array[float] = [-0.91, -0.91, 0.91, 0.91]

@export var travel_speed := 3.0
@export var acceleration := 2.0
@export var door_speed := 1.15
@export var door_hold_seconds := 2.5
var current_floor: int = 0
var target_floor: int = 0
var state: String = "OPEN"
var door_fraction: float = 1.0
var landing_door_fraction: Array[float] = []
var cab: AnimatableBody3D
var _cab_doors: Array[AnimatableBody3D] = []
var _landing_doors: Array = []
var _queue: Array[int] = []
var _owned_bodies: Array[RID] = []
var _travel_y: float = 0.8
var _speed: float = 0.0
var _hold: float = 2.5
var _sensor: BoxShape3D
var _ui: CanvasLayer
var _ui_actor: CharacterBody3D
var _mouse_before_ui: int = Input.MOUSE_MODE_VISIBLE
var _status: Label3D
var _landing_labels: Array[Label3D] = []
var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
var _warm: StandardMaterial3D

func _ready() -> void:
	add_to_group("cantilever_elevator")
	process_physics_priority = -10
	_travel_y = Layout.FLOORS[0]
	_hold = door_hold_seconds
	_metal = _material(Color(0.22, 0.25, 0.29), 0.65)
	_dark = _material(Color(0.045, 0.055, 0.07), 0.25)
	_warm = _material(Color(0.8, 0.49, 0.18), 0.1)
	_warm.emission_enabled = true
	_warm.emission = Color(1.0, 0.54, 0.20)
	_warm.emission_energy_multiplier = 1.2
	_sensor = BoxShape3D.new()
	_sensor.size = Vector3(1.8, 2.7, 1.1)
	_build_cab()
	_build_landings()
	_apply_doors()
	_update_labels()

func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.42
	return mat

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, collidable: bool = true) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	if collidable:
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		collision.position = at
		parent.add_child(collision)

func _body(parent: Node3D, body_name: String, at: Vector3, moving: bool) -> PhysicsBody3D:
	var body: PhysicsBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = body_name
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	if body is AnimatableBody3D:
		body.sync_to_physics = true
	parent.add_child(body)
	_owned_bodies.append(body.get_rid())
	return body

func _build_cab() -> void:
	cab = _body(self, "MovingCab", Vector3(0, _travel_y, 0), true) as AnimatableBody3D
	_box(cab, Vector3(0, -0.08, SHAFT_Z), Vector3(2.2, 0.16, 2.7), _metal)
	_box(cab, Vector3(0, 2.85, SHAFT_Z), Vector3(2.2, 0.10, 2.7), _metal)
	_box(cab, Vector3(0, 1.4, -1.55), Vector3(2.2, 2.8, 0.10), _dark)
	for side in [-1.0, 1.0]:
		_box(cab, Vector3(side * 1.05, 1.4, SHAFT_Z), Vector3(0.10, 2.8, 2.7), _metal)
		_box(cab, Vector3(side * 0.94, 1.3, 1.065), Vector3(0.32, 2.6, 0.10), _metal)
	_box(cab, Vector3(0, 2.68, 1.065), Vector3(2.2, 0.24, 0.10), _metal)
	_box(cab, Vector3(0, 2.78, SHAFT_Z), Vector3(1.55, 0.035, 1.5), _warm, false)
	# Keep illumination with the moving cab; the emissive ceiling alone casts no light.
	var cabin_light := OmniLight3D.new()
	cabin_light.name = "CabinLight"
	cabin_light.position = Vector3(0, 2.35, SHAFT_Z)
	cabin_light.light_color = Color("ffd5a3")
	cabin_light.light_energy = 6.0
	cabin_light.omni_range = 4.5
	cabin_light.omni_attenuation = 1.0
	cabin_light.light_specular = 0.15
	cabin_light.shadow_enabled = true
	cab.add_child(cabin_light)
	_cab_doors = _make_doors(cab, "CabDoor", 0.0, CAB_DOOR_Z)
	_status = Label3D.new()
	_status.position = Vector3(0, 2.35, -1.48)
	_status.font_size = 32
	_status.pixel_size = 0.003
	_status.modulate = Color(1, 0.8, 0.46)
	cab.add_child(_status)

func _make_doors(parent: Node3D, prefix: String, y: float, z: float) -> Array[AnimatableBody3D]:
	var doors: Array[AnimatableBody3D] = []
	for index in range(4):
		# Four telescoping leaves fit a 1.44 m opening inside the 2.2 m cab.
		var leaf := _body(parent, prefix + str(index), Vector3(CLOSED_X[index], y, z + (index % 2) * 0.045), true) as AnimatableBody3D
		_box(leaf, Vector3(0, 1.28, 0), Vector3(0.36, 2.56, 0.035), _metal)
		doors.append(leaf)
	return doors

func _build_landings() -> void:
	var top: float = Layout.FLOORS[-1] + 3.2
	var shaft := _body(self, "ShaftGuards", Vector3.ZERO, false)
	for x in [-1.18, 1.18]:
		_box(shaft, Vector3(x, top * 0.5, SHAFT_Z), Vector3(0.10, top, 2.95), _dark)
	_box(shaft, Vector3(0, top * 0.5, -1.70), Vector3(2.46, top, 0.10), _dark)
	for index in range(Layout.FLOORS.size()):
		var floor_y: float = Layout.FLOORS[index]
		landing_door_fraction.append(0.0)
		_landing_doors.append(_make_doors(self, "Landing%dDoor" % index, floor_y, DOOR_Z))
		var frame := _body(self, "Landing%dFrame" % index, Vector3(0, floor_y, 0), false)
		for x in [-0.98, 0.98]:
			_box(frame, Vector3(x, 1.3, DOOR_Z), Vector3(0.40, 2.6, 0.15), _metal)
		_box(frame, Vector3(0, -0.08, 1.245), Vector3(2.4, 0.16, 0.25), _metal)
		var next_y: float = Layout.FLOORS[index + 1] if index + 1 < Layout.FLOORS.size() else top
		var header_height: float = next_y - floor_y - 2.56
		_box(frame, Vector3(0, 2.56 + header_height * 0.5, DOOR_Z), Vector3(2.46, header_height, 0.15), _dark)
		_box(frame, Vector3(1.025, 1.25, 1.36), Vector3(0.15, 0.24, 0.035), _warm, false)
		var label := Label3D.new()
		label.position = Vector3(0, 2.72, 1.35)
		label.font_size = 26
		label.pixel_size = 0.0025
		frame.add_child(label)
		_landing_labels.append(label)

func request_floor(index: int) -> void:
	if index < 0 or index >= Layout.FLOORS.size():
		return
	if index == current_floor and state != "MOVING":
		if state in ["IDLE", "CLOSING"]:
			state = "OPENING"
		_hold = door_hold_seconds
	elif index != target_floor or state != "MOVING":
		if not _queue.has(index):
			_queue.append(index)
	_update_labels()

func _physics_process(delta: float) -> void:
	if is_ui_open() and (not is_instance_valid(_ui_actor) or not _inside_cab(_ui_actor)):
		close_ui()
	match state:
		"OPEN":
			if _doorway_blocked() or is_ui_open():
				_hold = door_hold_seconds
			else:
				_hold -= delta
				if _hold <= 0:
					state = "CLOSING"
		"OPENING":
			door_fraction = move_toward(door_fraction, 1.0, door_speed * delta)
			if door_fraction >= 1.0:
				state = "OPEN"
				_hold = door_hold_seconds
		"CLOSING":
			if _doorway_blocked():
				state = "OPENING"
			else:
				door_fraction = move_toward(door_fraction, 0.0, door_speed * delta)
				if door_fraction <= 0.0:
					state = "IDLE"
		"IDLE":
			if not _queue.is_empty():
				target_floor = _queue.pop_front()
				if target_floor == current_floor:
					state = "OPENING"
				else:
					_speed = 0.0
					state = "MOVING"
		"MOVING":
			var remaining: float = Layout.FLOORS[target_floor] - _travel_y
			var desired: float = minf(travel_speed, sqrt(2.0 * acceleration * absf(remaining)))
			_speed = move_toward(_speed, desired, acceleration * delta)
			var step: float = minf(absf(remaining), _speed * delta)
			_travel_y += signf(remaining) * step
			cab.position.y = _travel_y
			if absf(Layout.FLOORS[target_floor] - _travel_y) < 0.0001:
				current_floor = target_floor
				_speed = 0.0
				state = "OPENING"
	_apply_doors()
	_update_labels()

func _apply_doors() -> void:
	for index in range(4):
		_cab_doors[index].position.x = lerpf(CLOSED_X[index], OPEN_X[index], door_fraction)
	for landing in range(_landing_doors.size()):
		var fraction: float = door_fraction if landing == current_floor and state != "MOVING" else 0.0
		landing_door_fraction[landing] = fraction
		for index in range(4):
			_landing_doors[landing][index].position.x = lerpf(CLOSED_X[index], OPEN_X[index], fraction)

func _doorway_blocked() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sensor
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, Layout.FLOORS[current_floor] + 1.35, 1.20))
	query.collision_mask = 0xFFFFFFFF
	query.exclude = _owned_bodies
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		if hit.collider is CharacterBody3D or hit.collider is RigidBody3D:
			return true
	return false

func _inside_cab(actor: Node3D) -> bool:
	if not is_instance_valid(actor):
		return false
	var point := to_local(actor.global_position)
	return absf(point.x) < 0.99 and point.z > -1.50 and point.z < 1.05 and point.y >= _travel_y - 0.12 and point.y < _travel_y + 2.8

func _near_landing(actor: Node3D) -> int:
	var point := to_local(actor.global_position)
	if absf(point.x) > 1.6 or point.z < 1.05 or point.z > 3.6:
		return -1
	for index in range(Layout.FLOORS.size()):
		if point.y >= Layout.FLOORS[index] - 0.2 and point.y < Layout.FLOORS[index] + 1.9:
			return index
	return -1

func get_prompt(actor: Node3D) -> String:
	if is_ui_open():
		return ""
	if _inside_cab(actor):
		return "E · Select lift floor"
	var landing := _near_landing(actor)
	if landing < 0:
		return ""
	if _queue.has(landing) or (state == "MOVING" and target_floor == landing):
		return "Lift called · " + Layout.LABELS[landing]
	return "E · Call lift — " + Layout.LABELS[landing]

func get_interaction_distance(actor: Node3D) -> float:
	if _inside_cab(actor):
		return 0.0
	var landing := _near_landing(actor)
	if landing < 0:
		return INF
	return actor.global_position.distance_to(to_global(Vector3(0, Layout.FLOORS[landing], 1.5)))

func interact(actor: CharacterBody3D) -> void:
	if is_ui_open():
		return
	if _inside_cab(actor):
		_open_ui(actor)
	else:
		var landing := _near_landing(actor)
		if landing >= 0:
			request_floor(landing)

func is_ui_open() -> bool:
	return is_instance_valid(_ui) and _ui.visible

func _open_ui(actor: CharacterBody3D) -> void:
	_ui_actor = actor
	_mouse_before_ui = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui = CanvasLayer.new()
	_ui.name = "LiftFloorSelection"
	_ui.layer = 40
	add_child(_ui)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.03, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(centre)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_constant_override("separation", 8)
	centre.add_child(panel)
	var title := Label.new()
	title.text = "CANTILEVER · LIFT\nChoose a floor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	panel.add_child(title)
	for index in range(Layout.FLOORS.size()):
		var button := Button.new()
		button.text = "%s%s" % [Layout.LABELS[index], " · here" if index == current_floor and state != "MOVING" else ""]
		button.custom_minimum_size.y = 40
		button.pressed.connect(_select_floor.bind(index))
		panel.add_child(button)
	var cancel := Button.new()
	cancel.text = "Close · Esc"
	cancel.pressed.connect(close_ui)
	panel.add_child(cancel)
	panel.get_child(1).grab_focus()

func _select_floor(index: int) -> void:
	request_floor(index)
	close_ui()
	_hold = minf(_hold, 0.8)

func close_ui(restore_mouse: bool = true) -> void:
	if is_instance_valid(_ui):
		_ui.hide()
		_ui.queue_free()
		_ui = null
		if restore_mouse:
			Input.mouse_mode = _mouse_before_ui
	_ui_actor = null

func _unhandled_key_input(event: InputEvent) -> void:
	if is_ui_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_ui()
		get_viewport().set_input_as_handled()

func _update_labels() -> void:
	var text := Layout.LABELS[target_floor] if state == "MOVING" else Layout.LABELS[current_floor]
	_status.text = ("→ " if state == "MOVING" else "") + text
	for index in range(_landing_labels.size()):
		_landing_labels[index].text = Layout.LABELS[index] + "  ·  " + ("CALLED" if _queue.has(index) else text)

func _exit_tree() -> void:
	close_ui()
