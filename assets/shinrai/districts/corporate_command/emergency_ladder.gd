extends Node3D
## Continuous physical climbing; dismounts only transfer onto supported landings.

const LAYOUT := preload("traversal_layout.gd")
const CLIMB_Z := -19.0
const EXIT_Z := -17.5
const GROUND_EXIT_Z := -20.0
const CLIMB_SPEED := 3.6
const TRANSFER_SPEED := 2.4
const FOOT_CLEARANCE := 0.045
const LANDINGS: Array[float] = [LAYOUT.LADDER_BOTTOM, 17.12, 20.62, 24.12, LAYOUT.LADDER_TOP]

var active_actor: CharacterBody3D
var _phase := ""
var _transfer_points: Array[Vector3] = []
var _transfer_stall := 0.0
var _exit_requested := false


func _ready() -> void:
	add_to_group("cantilever_ladder")
	_build_ladder()


func _build_ladder() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("a4bac4")
	steel.metallic = 0.75
	steel.roughness = 0.4
	var height := LAYOUT.LADDER_TOP - LAYOUT.LADDER_BOTTOM + 1.1
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.07, height, 0.09)
		rail.mesh = rail_mesh
		rail.position = Vector3(LAYOUT.LADDER_X + side * 0.46, LAYOUT.LADDER_BOTTOM + height * 0.5, LAYOUT.LADDER_Z)
		rail.material_override = steel
		add_child(rail)
	var rung_mesh := BoxMesh.new()
	rung_mesh.size = Vector3(0.86, 0.055, 0.07)
	var rungs := MultiMesh.new()
	rungs.transform_format = MultiMesh.TRANSFORM_3D
	rungs.mesh = rung_mesh
	rungs.instance_count = int(floor((LAYOUT.LADDER_TOP - LAYOUT.LADDER_BOTTOM) / 0.3)) + 1
	for index in range(rungs.instance_count):
		rungs.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(LAYOUT.LADDER_X, LAYOUT.LADDER_BOTTOM + index * 0.3, LAYOUT.LADDER_Z)))
	var rung_instance := MultiMeshInstance3D.new()
	rung_instance.name = "LadderRungs"
	rung_instance.multimesh = rungs
	rung_instance.material_override = steel
	add_child(rung_instance)


func is_climbing(actor: CharacterBody3D) -> bool:
	return is_instance_valid(active_actor) and active_actor == actor


func cancel_actor(actor: CharacterBody3D) -> void:
	# Production lifecycle cleanup: death/reset/unload must not retain an actor.
	if active_actor != actor:
		return
	if is_instance_valid(active_actor):
		active_actor.velocity = Vector3.ZERO
	active_actor = null
	_phase = ""
	_transfer_points.clear()
	_transfer_stall = 0.0
	_exit_requested = false


func is_ready_to_climb(actor: CharacterBody3D) -> bool:
	return is_climbing(actor) and _phase == "climb"


func get_interaction_distance(actor: CharacterBody3D) -> float:
	var local := to_local(actor.global_position)
	return Vector2(local.x - LAYOUT.LADDER_X, local.z - CLIMB_Z).length()


func get_prompt(actor: CharacterBody3D) -> String:
	if is_climbing(actor):
		if _phase != "climb":
			return "Moving onto landing…" if _exit_requested else "Taking hold of ladder…"
		var landing := _nearest_landing(to_local(actor.global_position).y - FOOT_CLEARANCE, 0.38)
		return "W / S  climb · E  step onto landing" if landing >= 0 else "W / S  climb · reach a landing to exit"
	if is_instance_valid(active_actor):
		return ""
	var local := to_local(actor.global_position)
	if get_interaction_distance(actor) > 2.15 or _nearest_landing(local.y, 0.55) < 0:
		return ""
	return "E  use emergency ladder"


func interact(actor: CharacterBody3D) -> bool:
	if is_climbing(actor):
		return release(actor)
	if get_prompt(actor).is_empty():
		return false
	var local := to_local(actor.global_position)
	var landing_index := _nearest_landing(local.y, 0.55)
	active_actor = actor
	_phase = "mount"
	_exit_requested = false
	_transfer_stall = 0.0
	_transfer_points = [Vector3(LAYOUT.LADDER_X, LANDINGS[landing_index] + FOOT_CLEARANCE, CLIMB_Z)]
	actor.velocity = Vector3.ZERO
	actor.look_at(actor.global_position + global_basis * Vector3.BACK, Vector3.UP)
	return true


func release(actor: CharacterBody3D) -> bool:
	if not is_climbing(actor):
		return true
	if _phase != "climb":
		return false
	var landing_index := _nearest_landing(to_local(actor.global_position).y - FOOT_CLEARANCE, 0.38)
	if landing_index < 0:
		return false
	return _begin_exit(actor, landing_index)


func _nearest_landing(height: float, tolerance: float) -> int:
	var best := -1
	var best_distance := tolerance
	for index in range(LANDINGS.size()):
		var distance := absf(height - LANDINGS[index])
		if distance <= best_distance:
			best = index
			best_distance = distance
	return best


func _begin_exit(actor: CharacterBody3D, landing_index: int) -> bool:
	var height := LANDINGS[landing_index] + FOOT_CLEARANCE
	var exit_z := GROUND_EXIT_Z if landing_index == 0 else EXIT_Z
	var exit_point := Vector3(LAYOUT.LADDER_X, height, exit_z)
	if not _landing_supported(actor, to_global(exit_point)):
		return false
	_phase = "exit"
	_exit_requested = true
	_transfer_stall = 0.0
	_transfer_points = [Vector3(LAYOUT.LADDER_X, height, CLIMB_Z), exit_point]
	return true


func _landing_supported(actor: CharacterBody3D, feet: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.2, feet - Vector3.UP * 0.25, actor.collision_mask, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > 0.7


func physics_actor(actor: CharacterBody3D, delta: float, input_axis: float) -> bool:
	if not is_climbing(actor):
		return false
	actor.velocity = Vector3.ZERO
	if _phase == "mount" or _phase == "exit":
		_advance_transfer(actor, delta)
		return true
	var local := to_local(actor.global_position)
	var height := clampf(local.y + clampf(input_axis, -1.0, 1.0) * CLIMB_SPEED * delta, LAYOUT.LADDER_BOTTOM + FOOT_CLEARANCE, LAYOUT.LADDER_TOP + FOOT_CLEARANCE)
	var target := to_global(Vector3(LAYOUT.LADDER_X, height, CLIMB_Z))
	actor.move_and_collide(target - actor.global_position)
	local = to_local(actor.global_position)
	if input_axis > 0.0 and local.y >= LAYOUT.LADDER_TOP + FOOT_CLEARANCE - 0.01:
		_begin_exit(actor, LANDINGS.size() - 1)
	elif input_axis < 0.0 and local.y <= LAYOUT.LADDER_BOTTOM + FOOT_CLEARANCE + 0.01:
		_begin_exit(actor, 0)
	return true


func _advance_transfer(actor: CharacterBody3D, delta: float) -> void:
	if _transfer_points.is_empty():
		if _exit_requested:
			active_actor = null
			_phase = ""
		else:
			_phase = "climb"
		return
	var target := to_global(_transfer_points[0])
	var before := actor.global_position
	var motion := (target - before).limit_length(TRANSFER_SPEED * delta)
	actor.move_and_collide(motion)
	if actor.global_position.distance_to(target) < 0.015:
		_transfer_points.pop_front()
		_transfer_stall = 0.0
	elif actor.global_position.distance_to(before) < 0.001:
		_transfer_stall += delta
		if _transfer_stall > 1.0:
			# Never force a dismount through an obstructed landing.
			_transfer_points.clear()
			_exit_requested = false
			_phase = "climb"
	else:
		_transfer_stall = 0.0
