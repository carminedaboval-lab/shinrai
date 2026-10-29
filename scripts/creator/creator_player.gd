extends CharacterBody3D
## First-person creator movement; no weapon, survival or profile dependencies.
const WALK_SPEED := 3.772
const SPRINT_SPEED := 6.96
const SENSITIVITY := 0.00215
var camera: Camera3D
var head: Node3D
var capsule: CapsuleShape3D
var shape_node: CollisionShape3D
var controls_enabled := false
var last_safe := Vector3(0, 0.2, 160)
var _blocked_keys: Dictionary = {}
var _jump_down := false
var _crouching := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 3
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(48.0)
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.75
	shape_node = CollisionShape3D.new()
	shape_node.shape = capsule
	shape_node.position.y = 0.9
	add_child(shape_node)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.58
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 73.0
	camera.near = 0.05
	camera.far = 1000.0
	head.add_child(camera)
	camera.make_current()
	last_safe = global_position

func set_controls_enabled(enabled: bool) -> void:
	if enabled and not controls_enabled:
		for key: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_CTRL, KEY_SPACE]:
			if Input.is_physical_key_pressed(key): _blocked_keys[key] = true
	controls_enabled = enabled
	velocity.x = 0.0
	velocity.z = 0.0
	_jump_down = Input.is_physical_key_pressed(KEY_SPACE)

func _key(key: int) -> bool:
	if _blocked_keys.has(key):
		if not Input.is_physical_key_pressed(key): _blocked_keys.erase(key)
		return false
	return Input.is_physical_key_pressed(key)

func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * SENSITIVITY, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if not controls_enabled: return
	var input := Vector2(float(_key(KEY_D)) - float(_key(KEY_A)), float(_key(KEY_S)) - float(_key(KEY_W))).normalized()
	var crouch := _key(KEY_CTRL)
	if not crouch and _crouching: crouch = not _can_stand()
	_crouching = crouch
	capsule.height = 1.10 if crouch else 1.75
	shape_node.position.y = 0.575 if crouch else 0.9
	head.position.y = move_toward(head.position.y, 0.93 if crouch else 1.58, delta * 5.0)
	var direction := global_basis * Vector3(input.x, 0, input.y)
	var speed := 2.8 if crouch else (SPRINT_SPEED if _key(KEY_SHIFT) else WALK_SPEED)
	var rate := 18.0 if input.length_squared() > 0.01 else 22.0
	velocity.x = move_toward(velocity.x, direction.x * speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, rate * delta)
	var jump := _key(KEY_SPACE)
	if is_on_floor():
		velocity.y = 6.2 if jump and not _jump_down else -0.1
		if global_position.y > -0.5: last_safe = global_position
	else:
		velocity.y -= 18.0 * delta
	_jump_down = jump
	move_and_slide()
	if global_position.y < -12.0 or absf(global_position.x) > 260.0 or absf(global_position.z) > 220.0:
		global_position = last_safe + Vector3.UP * 0.1
		velocity = Vector3.ZERO

func _can_stand() -> bool:
	var standing := CapsuleShape3D.new()
	standing.radius = 0.35
	standing.height = 1.73
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.91, 0))
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func camera_state() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "yaw": rotation.y, "pitch": head.rotation.x}

func restore_camera(state: Dictionary) -> bool:
	var position_data: Array = state.get("position", [])
	if position_data.size() != 3: return false
	var point := Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	if not point.is_finite() or absf(point.x) > 220 or absf(point.z) > 180 or point.y < -1 or point.y > 50: return false
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 6.0, collision_mask, [get_rid()])
	var ground := get_world_3d().direct_space_state.intersect_ray(ray)
	if ground.is_empty() or ground.normal.y < 0.5: return false
	var safe_point := Vector3(point.x, float(ground.position.y) + 0.08, point.z)
	var check_shape := CapsuleShape3D.new()
	check_shape.radius = 0.36
	check_shape.height = 1.75
	var check := PhysicsShapeQueryParameters3D.new()
	check.shape = check_shape
	check.transform.origin = safe_point + Vector3(0, 0.9, 0)
	check.exclude = [get_rid()]
	check.collision_mask = collision_mask
	if not get_world_3d().direct_space_state.intersect_shape(check, 1).is_empty(): return false
	global_position = safe_point
	rotation.y = float(state.get("yaw", 0.0))
	head.rotation.x = clampf(float(state.get("pitch", 0.0)), -1.45, 1.45)
	last_safe = global_position
	return true
