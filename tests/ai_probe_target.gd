extends CharacterBody3D
## A scripted stand-in for the player, for measuring enemy AI without a person at the keys.
## It has the properties the scav crew reads from the real player (crouching, sprinting, ads,
## camera, is_weapon_lowered, take_damage) and walks where the test tells it.

var crouching := false
var sprinting := false
var is_swimming := false
var ads := false
var weapon_lowered := true
var health := 100.0
var camera: Camera3D
var hits_taken: Array[Dictionary] = []
var clock := 0.0
var _goal := Vector3.INF
var _speed := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.6
	add_child(camera)


func is_weapon_lowered() -> bool:
	return weapon_lowered


func take_damage(amount: float, _source: Node = null) -> void:
	hits_taken.append({"time": clock, "amount": amount})


func register_damage_source(_point: Vector3, _strength: float = 1.0) -> void:
	pass


func notify_kill() -> void:
	pass


var _route := PackedVector3Array()


func walk_to(point: Vector3, speed: float) -> void:
	_route = PackedVector3Array()
	_goal = point
	_speed = speed
	sprinting = speed > 4.5


## Walks a list of points in order (a navigation route), so cover does not snag the body.
func follow(points: PackedVector3Array, speed: float) -> void:
	if points.is_empty(): return
	_route = points.duplicate()
	_goal = _route[0]
	_route.remove_at(0)
	_speed = speed
	sprinting = speed > 4.5


func stop() -> void:
	if not _route.is_empty():
		_goal = _route[0]
		_route.remove_at(0)
		return
	_goal = Vector3.INF
	sprinting = false


func halt() -> void:
	_route = PackedVector3Array()
	_goal = Vector3.INF
	sprinting = false


func arrived() -> bool:
	return not _goal.is_finite()


## Points the camera (the "aim line" the crew reads) at a world point.
func aim_at(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if flat.length_squared() > 0.001: rotation.y = atan2(-flat.x, -flat.z)
	camera.look_at(point)


func _physics_process(delta: float) -> void:
	clock += delta
	var wish := Vector3.ZERO
	if _goal.is_finite():
		var offset := Vector3(_goal.x - global_position.x, 0, _goal.z - global_position.z)
		if offset.length() < 0.25: stop()
		else: wish = offset.normalized() * _speed
	velocity.x = wish.x
	velocity.z = wish.z
	# A steady downward push keeps floor contact every tick (the crew only hears footsteps
	# from a body that is on the floor).
	velocity.y = -1.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
