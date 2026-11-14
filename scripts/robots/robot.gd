extends CharacterBody3D
## The first robot: a plain, upright maintenance machine that stands dormant in a bay of a
## recharge station (scripts/robots/station.gd) until the station wakes it.
##
## It is NOT built on scripts/enemy.gd. That script is a gunman: it loads the K17 drone model
## in _ready(), patrols, looks through a sight cone, shoots, and deletes itself when it dies.
## A robot does none of those (it sleeps in a bay, has no gun, and its body must stay where it
## fell), so every part of the base would have had to be switched off. It answers the same
## calls instead, so the gun, the doors and the raid treat it like any other enemy:
## take_damage(), receive_bullet_hit(), hear_noise(), is_in_combat_with(), the collision
## layer of an enemy, and the group "extraction_hostiles" while it is awake.
##
## What robots are for is never explained: no text, no voice. It only acts.
##
## Its own axes: it faces -z, y is up, the origin is between its feet.

const RobotParts := preload("res://scripts/robots/robot_parts.gd")
const RobotMesh := preload("res://scripts/robots/robot_mesh.gd")
const KitNoise := preload("res://scripts/interior_kit/noise.gd")

enum State { DORMANT, WAKING, CHASE, STRIKE, HOLD, RETURN, DOCKING, DOWN }

# ---- defaults (all open to change; whether robots are hostile at all is still open) ------
## Seconds from waking to standing clear of the bay, ready to walk.
const WAKE_SECONDS := 2.0
## Of those, the first part is the sensor coming on and the head lifting, before it moves.
const WAKE_STIR_SECONDS := 0.5
## How far in front of its bay it steps out to.
const STEP_OUT_DISTANCE := 1.45
## A steady walk. The player walks at 3.85 m/s, runs at 6.65 and backs away at 2.8.
const WALK_SPEED := 3.0
const WALK_ACCELERATION := 5.0
const TURN_SPEED := 5.0
## One full walking cycle (two steps) covers this much ground.
const STRIDE := 1.5
## It strikes when the player is this close (middle to middle): arm's reach.
const STRIKE_REACH := 1.5
## The blow lands this long after the arm starts to rise, and only if the player is still
## within STRIKE_LAND_REACH.
const STRIKE_WINDUP := 0.45
const STRIKE_LAND_REACH := 1.8
const STRIKE_RECOVER := 0.75
const STRIKE_DAMAGE := 22.0
## Beyond this it has lost the player: it stops and waits ...
const LOSE_DISTANCE := 40.0
## ... and after this long with the player still beyond it, it walks back to its bay.
const LOSE_SECONDS := 20.0
## Stepping back into the bay and going dormant.
const DOCK_SECONDS := 2.0
const HEALTH := 240.0
## A hit on the head (the sensor) counts this many times over.
const HEAD_MULTIPLIER := 2.0
const HEAD_FROM_HEIGHT := 1.66
## Stripping a downed robot: hold for this long per part ...
const STRIP_SECONDS := 4.0
const STRIP_REACH := 2.0
## ... and it is heard this far away, once when a part is started and again this often.
const STRIP_NOISE_RADIUS := 25.0
const STRIP_NOISE_INTERVAL := 1.0
## The interact key counts as let go when hold_interact() misses this many physics ticks.
const HOLD_GAP_TICKS := 3
const FALL_SECONDS := 1.1
const PATH_REFRESH := 0.5
const GRAVITY := 18.0

# ---- its size (metres) -------------------------------------------------------------------
const HEIGHT := 1.95
const HIP := 1.03
const THIGH := 0.48
const SHIN := 0.55
const SHOULDER := Vector2(0.255, 0.54) # out from the middle, up from the hip
const UPPER_ARM := 0.33
const NECK := 0.64 # up from the hip
const BODY_RADIUS := 0.3
const WHITE := Color(0.93, 0.94, 0.95)
const JOINT := Color(0.115, 0.12, 0.13)
const LENS_ASLEEP := Color(0.05, 0.06, 0.07)
const LENS_AWAKE := Color(1.0, 0.66, 0.24)
const LENS_ENERGY := 3.2

signal woke(robot: Node3D)
signal stepped_out(robot: Node3D)
signal struck(robot: Node3D, victim: Node3D, damage: float)
signal downed(robot: Node3D)
signal docked(robot: Node3D)
signal part_stripped(robot: Node3D, actor: Node, part: StringName)

var station: Node3D
var bay := -1
## Where it stands in its bay and where it steps out to, in the station's own metres.
var home_local := Vector3.ZERO
var out_local := Vector3.ZERO
var home_yaw_local := 0.0
## What stripping it gives, in order. Whatever is left is still in the body.
var parts: Array[StringName] = []
var stripped: Array[StringName] = []
var target: Node3D
## Anything with get_path_world(from, to) or path(from, to). Without one it walks straight.
var navigation_source: Object
var state: int = State.DORMANT
var state_time := 0.0
var health := HEALTH
var visuals := true
var strikes := 0
var hits_taken := 0
var strip_seconds := 0.0
var lost_seconds := 0.0
## True once it has finished falling.
var fallen := false
var triangles := 0
var mesh_count := 0

var _wake_delay := 0.0
var _phase := 0.0
var _gait := 0.0
var _struck_this_swing := false
var _fall_drop := 0.0
var _hold_frame := -1000
var _noise_at := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _path_clock := 0.0
var _dock_from := Vector3.ZERO
var _dock_yaw := 0.0
var _seed := 0.0

var rig: Node3D
var hips: Node3D
var head: Node3D
var lens: MeshInstance3D
var _arms: Array[Node3D] = []
var _forearms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _lens_material: StandardMaterial3D

static var _meshes: Dictionary = {}
static var _lens_asleep: StandardMaterial3D


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	shape.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	add_to_group("robots")
	set_physics_process(false)


func _ready() -> void:
	_seed = float(get_instance_id() % 997) / 997.0
	if visuals: build_rig()
	_pose()
	# Godot switches a node's tick on when it enters the world. A dormant robot has none.
	set_physics_process(state != State.DORMANT)


# ---- what the station and the raid ask of it ---------------------------------------------

func home_point() -> Vector3:
	return station.to_global(home_local) if is_instance_valid(station) else global_position


func out_point() -> Vector3:
	return station.to_global(out_local) if is_instance_valid(station) else global_position


func is_dormant() -> bool:
	return state == State.DORMANT


func is_down() -> bool:
	return state == State.DOWN


## Awake and not yet back in its bay.
func is_out() -> bool:
	return state != State.DORMANT and state != State.DOWN


## The station wakes it. `delay` staggers a row of robots so they do not move as one.
func wake(who: Node3D, delay: float = 0.0) -> bool:
	if state != State.DORMANT: return false
	target = who
	_wake_delay = maxf(delay, 0.0)
	_enter(State.WAKING)
	add_to_group("extraction_hostiles")
	set_physics_process(true)
	RobotParts.sound(&"robot_wake", global_position)
	woke.emit(self)
	return true


func take_damage(amount: float, source: Node = null) -> void:
	if state == State.DOWN or not is_finite(amount) or amount <= 0.0: return
	hits_taken += 1
	health = maxf(0.0, health - amount)
	if state == State.DORMANT and is_instance_valid(station): station.wake(source)
	elif is_instance_valid(source) and source is Node3D and (state == State.HOLD or state == State.RETURN):
		target = source as Node3D
		_enter(State.CHASE)
	if health > 0.0: return
	if is_instance_valid(source) and source.has_method("notify_kill"): source.notify_kill()
	_go_down()


## A bullet, the way player.gd delivers one. A hit on the head counts HEAD_MULTIPLIER times.
func receive_bullet_hit(damage: float, source: Node, at: Vector3, _direction: Vector3) -> bool:
	if state == State.DOWN or damage <= 0.0: return false
	var height := at.y - global_position.y
	take_damage(damage * (HEAD_MULTIPLIER if height >= HEAD_FROM_HEIGHT else 1.0), source)
	return true


## The raid tells every hostile about noises. A robot does not act on them (default).
func hear_noise(_point: Vector3, _radius: float) -> void:
	pass


func is_in_combat_with(body: Node) -> bool:
	return body == target and (state == State.CHASE or state == State.STRIKE)


# ---- stripping a downed robot (the yard's and the raid's interaction calls) --------------

## The middle of the body where it lies.
func body_centre() -> Vector3:
	return global_position - global_basis.z * (HEIGHT * 0.45) if fallen else global_position


func interaction_distance(actor: Node3D) -> float:
	if state != State.DOWN or not fallen or parts.is_empty() or not is_instance_valid(actor): return INF
	var offset := actor.global_position - body_centre()
	if absf(offset.y) > 1.6: return INF
	var distance := Vector2(offset.x, offset.z).length()
	return distance if distance <= STRIP_REACH else INF


func interaction_prompt(actor: Node3D) -> String:
	if interaction_distance(actor) == INF: return ""
	return "Hold E  ·  Strip the robot: %s (%d left in it)" % [RobotParts.label(parts[0]), parts.size()]


## A press does nothing: stripping is a hold.
func interact(_actor: Node3D) -> bool:
	return false


## Call once every tick while `actor` holds the interact key on the downed robot. Returns how
## far the part in hand has got, 0 to 1; at 1 the part is the actor's. Letting go starts that
## part again from 0.
func hold_interact(actor: Node3D, delta: float) -> float:
	if interaction_distance(actor) == INF:
		strip_seconds = 0.0
		return 0.0
	var frame := Engine.get_physics_frames()
	if frame - _hold_frame > HOLD_GAP_TICKS:
		strip_seconds = 0.0
		_noise_at = 0.0
	_hold_frame = frame
	if strip_seconds >= _noise_at:
		_noise_at += STRIP_NOISE_INTERVAL
		RobotParts.sound(&"robot_strip", body_centre())
		KitNoise.emit(self, body_centre(), STRIP_NOISE_RADIUS, &"robot_strip")
	strip_seconds += delta
	if strip_seconds < STRIP_SECONDS - 0.0001: return strip_seconds / STRIP_SECONDS
	var part: StringName = parts.pop_front()
	stripped.append(part)
	strip_seconds = 0.0
	_noise_at = 0.0
	RobotParts.give(actor, part)
	RobotParts.sound(&"robot_part_out", body_centre())
	part_stripped.emit(self, actor, part)
	if parts.is_empty(): remove_from_group("building_access_targets")
	return 1.0


# ---- the tick ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.WAKING: _tick_waking(delta)
		State.CHASE: _tick_chase(delta)
		State.STRIKE: _tick_strike(delta)
		State.HOLD: _tick_hold(delta)
		State.RETURN: _tick_return(delta)
		State.DOCKING: _tick_docking()
		State.DOWN: _tick_down()
	_pose()


func _enter(next: int) -> void:
	state = next
	state_time = 0.0
	_path = PackedVector3Array()
	_path_clock = 0.0
	if is_instance_valid(station) and station.has_method("robot_changed"): station.robot_changed(self)


func _target_gap() -> float:
	if not is_instance_valid(target) or not target.is_inside_tree(): return INF
	if target.has_method("is_combat_alive") and not target.is_combat_alive(): return INF
	var offset := target.global_position - global_position
	return Vector2(offset.x, offset.z).length()


func _tick_waking(delta: float) -> void:
	if _wake_delay > 0.0:
		_wake_delay -= delta
		state_time = 0.0
		return
	var walk := clampf((state_time - WAKE_STIR_SECONDS) / (WAKE_SECONDS - WAKE_STIR_SECONDS), 0.0, 1.0)
	# Slow off the mark and slow to a stop, like something heavy starting to move.
	var eased := walk * walk * (3.0 - 2.0 * walk)
	var before := global_position
	global_position = home_point().lerp(out_point(), eased)
	_advance_gait(before.distance_to(global_position), 0.75 if walk > 0.0 and walk < 1.0 else 0.0, delta)
	if state_time < WAKE_SECONDS: return
	velocity = Vector3.ZERO
	RobotParts.sound(&"robot_step_out", global_position)
	_enter(State.CHASE)
	stepped_out.emit(self)


func _tick_chase(delta: float) -> void:
	var gap := _target_gap()
	if gap == INF:
		_enter(State.RETURN)
		return
	if gap > LOSE_DISTANCE:
		lost_seconds = 0.0
		_enter(State.HOLD)
		return
	if gap <= STRIKE_REACH:
		_struck_this_swing = false
		_enter(State.STRIKE)
		return
	_walk_towards(target.global_position, delta)


func _tick_strike(delta: float) -> void:
	_stand(delta)
	if is_instance_valid(target): _face(target.global_position - global_position, delta)
	if not _struck_this_swing and state_time >= STRIKE_WINDUP:
		_struck_this_swing = true
		strikes += 1
		RobotParts.sound(&"robot_strike", global_position)
		if _target_gap() <= STRIKE_LAND_REACH and target.has_method("take_damage"):
			target.take_damage(STRIKE_DAMAGE)
			struck.emit(self, target, STRIKE_DAMAGE)
	if state_time >= STRIKE_WINDUP + STRIKE_RECOVER: _enter(State.CHASE)


## The player is out of its reach of sense: it stands where it is and waits.
func _tick_hold(delta: float) -> void:
	_stand(delta)
	var gap := _target_gap()
	if gap <= LOSE_DISTANCE:
		_enter(State.CHASE)
		return
	lost_seconds += delta
	if gap == INF or lost_seconds >= LOSE_SECONDS: _enter(State.RETURN)


func _tick_return(delta: float) -> void:
	if _target_gap() <= LOSE_DISTANCE:
		_enter(State.CHASE)
		return
	var goal := out_point()
	var offset := goal - global_position
	if Vector2(offset.x, offset.z).length() > 0.25:
		_walk_towards(goal, delta)
		return
	velocity = Vector3.ZERO
	_dock_from = global_position
	_dock_yaw = global_rotation.y
	_enter(State.DOCKING)


func _tick_docking() -> void:
	var t := clampf(state_time / DOCK_SECONDS, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var before := global_position
	global_position = _dock_from.lerp(home_point(), eased)
	global_rotation.y = lerp_angle(_dock_yaw, _home_yaw(), clampf(t * 1.6, 0.0, 1.0))
	_advance_gait(before.distance_to(global_position), 0.75 if t < 1.0 else 0.0, 1.0 / 60.0)
	if t < 1.0: return
	global_position = home_point()
	_gait = 0.0
	target = null
	remove_from_group("extraction_hostiles")
	RobotParts.sound(&"robot_dock", global_position)
	_enter(State.DORMANT)
	_pose()
	set_physics_process(false)
	docked.emit(self)


func _tick_down() -> void:
	if state_time < FALL_SECONDS: return
	fallen = true
	_pose()
	set_physics_process(false)


func _go_down() -> void:
	velocity = Vector3.ZERO
	target = null
	remove_from_group("extraction_hostiles")
	collision_layer = 0
	collision_mask = 0
	# Where its head will come to rest may be lower than its feet (it can fall off the
	# station's plinth): measure the ground there so it lies on it, not in the air.
	var reach := HEIGHT * 0.9
	var above := global_position - global_basis.z * reach + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query) if is_inside_tree() else {}
	_fall_drop = clampf(global_position.y - float(hit.position.y), -0.5, 0.5) if not hit.is_empty() else 0.0
	_enter(State.DOWN)
	set_physics_process(true)
	if not parts.is_empty(): add_to_group("building_access_targets")
	RobotParts.sound(&"robot_down", global_position)
	downed.emit(self)


# ---- moving ------------------------------------------------------------------------------

func _home_yaw() -> float:
	return (station.global_rotation.y if is_instance_valid(station) else 0.0) + home_yaw_local


func _stand(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, WALK_ACCELERATION * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, WALK_ACCELERATION * 2.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_advance_gait(0.0, 0.0, delta)


func _walk_towards(goal: Vector3, delta: float) -> void:
	var direction := _direction_to(goal, delta)
	var wish := direction * WALK_SPEED
	velocity.x = move_toward(velocity.x, wish.x, WALK_ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, wish.z, WALK_ACCELERATION * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var before := global_position
	move_and_slide()
	_face(direction, delta)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_advance_gait(moved, 1.0, delta)


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001: return
	global_rotation.y = lerp_angle(global_rotation.y, atan2(-direction.x, -direction.z), clampf(TURN_SPEED * delta, 0.0, 1.0))


## The way to walk now: along the navigation's route when there is one, else straight.
func _direction_to(goal: Vector3, delta: float) -> Vector3:
	var straight := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if navigation_source == null or not is_instance_valid(navigation_source): return straight.normalized()
	_path_clock -= delta
	if _path_clock <= 0.0:
		_path_clock = PATH_REFRESH
		var found: Variant = null
		if navigation_source.has_method("get_path_world"): found = navigation_source.get_path_world(global_position, goal)
		elif navigation_source.has_method("path"): found = navigation_source.path(global_position, goal)
		_path = found if found is PackedVector3Array else PackedVector3Array()
		_path_index = 0
	while _path_index < _path.size():
		var step := Vector3(_path[_path_index].x - global_position.x, 0.0, _path[_path_index].z - global_position.z)
		if step.length() > 0.5: return step.normalized()
		_path_index += 1
	return straight.normalized()


func _advance_gait(moved: float, wanted: float, delta: float) -> void:
	_phase = fmod(_phase + moved / STRIDE * TAU, TAU)
	_gait = move_toward(_gait, wanted, delta * 3.0)


# ---- how it looks (first pass, made in code) ---------------------------------------------

static func _mesh(part: String) -> ArrayMesh:
	if _meshes.has(part): return _meshes[part]
	var b := RobotMesh.new()
	match part:
		"body": # origin: the middle of the hips
			b.ball(Vector3(0.0, 0.03, 0.0), Vector3(0.31, 0.19, 0.21), JOINT, 14)
			b.cylinder(Vector3(0.0, 0.16, 0.0), 0.10, 0.085, 0.16, JOINT)
			b.capsule(Vector3(0.0, 0.41, 0.0), 0.2, 0.5, WHITE, Vector2(1.08, 0.68))
			# The housing on its back is where the power cell sits.
			b.box(Vector3(0.0, 0.40, 0.145), Vector3(0.25, 0.30, 0.07), Color(0.80, 0.81, 0.83))
			for side: float in [-1.0, 1.0]: b.ball(Vector3(side * SHOULDER.x, SHOULDER.y, 0.0), Vector3(0.13, 0.13, 0.13), JOINT)
			b.cylinder(Vector3(0.0, NECK - 0.02, 0.0), 0.05, 0.045, 0.12, JOINT)
		"head": # origin: the top of the neck
			b.ball(Vector3(0.0, 0.155, 0.0), Vector3(0.19, 0.25, 0.23), WHITE, 16)
			# The dark plate on the front of the head houses the sensor.
			b.ball(Vector3(0.0, 0.16, -0.07), Vector3(0.15, 0.155, 0.105), JOINT, 14)
		"lens":
			b.ball(Vector3(0.0, 0.165, -0.118), Vector3(0.052, 0.052, 0.022), Color.WHITE)
		"upper_arm": # origin: the shoulder
			b.capsule(Vector3(0.0, -UPPER_ARM * 0.5, 0.0), 0.046, UPPER_ARM, WHITE)
			b.ball(Vector3(0.0, -UPPER_ARM, 0.0), Vector3(0.088, 0.088, 0.088), JOINT)
		"forearm": # origin: the elbow
			b.capsule(Vector3(0.0, -0.15, 0.0), 0.041, 0.30, WHITE)
			b.ball(Vector3(0.0, -0.37, 0.0), Vector3(0.05, 0.17, 0.09), JOINT)
		"thigh": # origin: the hip joint
			b.capsule(Vector3(0.0, -THIGH * 0.5, 0.0), 0.072, THIGH + 0.03, WHITE)
			b.ball(Vector3(0.0, -THIGH, 0.0), Vector3(0.125, 0.125, 0.125), JOINT)
		"shin": # origin: the knee
			b.capsule(Vector3(0.0, -0.25, 0.0), 0.057, 0.47, WHITE)
			b.box(Vector3(0.0, -SHIN + 0.035, -0.05), Vector3(0.105, 0.07, 0.27), JOINT)
	var mesh := b.commit()
	mesh.set_meta("triangles", b.triangle_count())
	_meshes[part] = mesh
	return mesh


func _add(parent: Node3D, label: String, part: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = at
	parent.add_child(pivot)
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh(part)
	pivot.add_child(instance)
	triangles += int(instance.mesh.get_meta("triangles"))
	mesh_count += 1
	return pivot


func build_rig() -> void:
	if rig != null: return
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	hips = _add(rig, "Hips", "body", Vector3(0.0, HIP, 0.0))
	head = _add(hips, "Head", "head", Vector3(0.0, NECK + 0.03, 0.0))
	if _lens_asleep == null:
		_lens_asleep = StandardMaterial3D.new()
		_lens_asleep.albedo_color = LENS_ASLEEP
		_lens_asleep.roughness = 0.12
	lens = MeshInstance3D.new()
	lens.name = "Sensor"
	lens.mesh = _mesh("lens")
	lens.material_override = _lens_asleep
	head.add_child(lens)
	triangles += int(lens.mesh.get_meta("triangles"))
	mesh_count += 1
	for side: float in [-1.0, 1.0]:
		var which := "L" if side < 0.0 else "R"
		var arm := _add(hips, "Arm" + which, "upper_arm", Vector3(side * SHOULDER.x, SHOULDER.y, 0.0))
		_arms.append(arm)
		_forearms.append(_add(arm, "Forearm" + which, "forearm", Vector3(0.0, -UPPER_ARM, 0.0)))
		var leg := _add(hips, "Leg" + which, "thigh", Vector3(side * 0.095, 0.0, 0.0))
		_legs.append(leg)
		_shins.append(_add(leg, "Shin" + which, "shin", Vector3(0.0, -THIGH, 0.0)))


## The sensor's light: 0 asleep, 1 awake. Each waking robot gets its own material only while
## it is awake; every sleeping robot shares one.
func _set_lens(amount: float) -> void:
	if amount <= 0.0:
		lens.material_override = _lens_asleep
		return
	if _lens_material == null:
		_lens_material = StandardMaterial3D.new()
		_lens_material.roughness = 0.12
		_lens_material.emission_enabled = true
		_lens_material.emission = LENS_AWAKE
	_lens_material.albedo_color = LENS_ASLEEP.lerp(LENS_AWAKE, amount)
	_lens_material.emission_energy_multiplier = LENS_ENERGY * amount
	lens.material_override = _lens_material


## How lit the sensor is right now, 0 to 1 (readable without anything being drawn).
func lens_level() -> float:
	match state:
		State.DORMANT: return 0.0
		State.WAKING: return clampf(state_time / WAKE_STIR_SECONDS, 0.0, 1.0) if _wake_delay <= 0.0 else 0.0
		State.DOCKING: return 1.0 - clampf((state_time - DOCK_SECONDS * 0.7) / (DOCK_SECONDS * 0.3), 0.0, 1.0)
		State.DOWN: return 1.0 - clampf(state_time / 0.6, 0.0, 1.0)
	return 1.0


func _pose() -> void:
	if rig == null: return
	_set_lens(lens_level())
	if state == State.DOWN:
		_pose_down()
		return
	var g := _gait
	var swing := sin(_phase)
	var lift := cos(_phase)
	rig.rotation = Vector3.ZERO
	rig.position = Vector3.ZERO
	hips.position = Vector3(0.0, HIP - 0.028 * g * (0.5 + 0.5 * cos(_phase * 2.0)), 0.0)
	hips.rotation = Vector3(-0.05 * g, 0.0, 0.03 * swing * g)
	for index: int in 2:
		var side := -1.0 if index == 0 else 1.0
		_legs[index].rotation = Vector3(0.40 * swing * side * g, 0.0, 0.0)
		_shins[index].rotation = Vector3(-(0.05 + 0.8 * maxf(0.0, lift * side) * g), 0.0, 0.0)
		_arms[index].rotation = Vector3(-0.26 * swing * side * g, 0.0, side * 0.035)
		_forearms[index].rotation = Vector3(0.10 + 0.14 * g, 0.0, 0.0)
	var bow := 0.0
	match state:
		State.DORMANT: bow = 1.0
		State.WAKING: bow = 1.0 - lens_level()
		State.DOCKING: bow = clampf((state_time - DOCK_SECONDS * 0.7) / (DOCK_SECONDS * 0.3), 0.0, 1.0)
	head.rotation = Vector3(-0.24 * bow, 0.0, 0.0)
	if state == State.STRIKE:
		# The right arm goes up over the shoulder and comes down hard.
		var up := clampf(state_time / STRIKE_WINDUP, 0.0, 1.0)
		var down := clampf((state_time - STRIKE_WINDUP) / 0.14, 0.0, 1.0)
		var back := clampf((state_time - STRIKE_WINDUP - 0.25) / (STRIKE_RECOVER - 0.25), 0.0, 1.0)
		var raise := 2.5 * up * up * (3.0 - 2.0 * up) - 1.6 * down
		raise *= 1.0 - back * back * (3.0 - 2.0 * back)
		_arms[1].rotation = Vector3(raise, 0.0, 0.035)
		_forearms[1].rotation = Vector3(0.10 + 0.9 * up * (1.0 - down), 0.0, 0.0)
		hips.rotation.x = -0.05 - 0.16 * down * (1.0 - back)


## Going down: the knees give first, then the whole machine tips forward onto its front.
func _pose_down() -> void:
	var t := clampf(state_time / FALL_SECONDS, 0.0, 1.0) if not fallen else 1.0
	var buckle := clampf(t / 0.38, 0.0, 1.0)
	var tip := clampf((t - 0.25) / 0.75, 0.0, 1.0)
	tip = tip * tip # it speeds up as it falls
	buckle = buckle * (1.0 - tip)
	var thigh := 0.9 * buckle - 0.10 * tip
	var knee := 1.5 * buckle + (0.30 + 0.25 * _seed) * tip
	hips.position = Vector3(0.0, THIGH * cos(thigh) + SHIN * cos(knee - thigh), (THIGH * sin(thigh) - SHIN * sin(knee - thigh)) * (1.0 - tip))
	hips.rotation = Vector3(-0.35 * buckle, 0.0, 0.0)
	rig.rotation.x = -(PI * 0.5 + asin(clampf(_fall_drop / (HEIGHT * 0.9), -0.6, 0.6))) * tip
	rig.position.y = 0.15 * tip
	for index: int in 2:
		var side := -1.0 if index == 0 else 1.0
		_legs[index].rotation = Vector3(thigh, 0.0, side * 0.06 * tip)
		_shins[index].rotation = Vector3(-knee * (1.0 if index == 0 else 0.55 + 0.45 * (1.0 - tip)), 0.0, 0.0)
	# One arm ends up flung ahead of it, the other under its side.
	_arms[0].rotation = Vector3((2.3 + 0.5 * _seed) * tip + 0.5 * buckle, 0.0, -0.25 * tip)
	_forearms[0].rotation = Vector3(0.5 * tip, 0.0, 0.0)
	_arms[1].rotation = Vector3(0.35 * tip + 0.5 * buckle, 0.0, 0.3 * tip)
	_forearms[1].rotation = Vector3(0.9 * tip, 0.0, 0.0)
	head.rotation = Vector3(0.0, (0.5 + 0.4 * _seed) * tip, 0.0)
