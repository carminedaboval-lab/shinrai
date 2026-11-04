extends SceneTree

var checks := 0
var failures: Array[String] = []
var actor: FixturePlayer
var world: Node3D
var obstacle: StaticBody3D
const DT := 1.0 / 60.0

class FixturePlayer extends "res://scripts/player.gd":
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 3
		_build_collision()
		_build_camera()
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box("Floor", Vector3(20, 0.2, 20), Vector3(0, -0.1, 0))
	_box("Ledge", Vector3(3, 1, 2), Vector3(0, 0.5, -2))
	obstacle = _box("Overhang", Vector3(3, 0.2, 3), Vector3(6, 2.2, -0.5))
	actor = FixturePlayer.new()
	actor.extraction_mode = true
	world.add_child(actor)
	await physics_frame
	await physics_frame
	await _reset()
	var before: float = actor.stamina
	var started: bool = actor._advance_ground_movement(DT, Vector2(0, -1), false, false, true)
	_check(started and actor.mantle_active, "fresh jump press starts mantle onto reachable 1m ledge")
	_check(is_equal_approx(before - actor.stamina, 18.0), "successful mantle consumes18 without also charging jump12")
	_check(actor.collision_layer == 0 and actor.collision_mask == 0, "mantle uses authored collision-disabled traversal only after clearance checks")
	var ammo_before := actor.ammo
	actor.shoot()
	_check(actor.ammo == ammo_before, "active mantle rejects direct firing without spending ammunition")
	actor.ammo = 12
	actor.start_reload()
	_check(not actor.reloading and is_zero_approx(actor.reload_time), "active mantle rejects reload without starting timer")
	var aim := InputEventMouseButton.new()
	aim.button_index = MOUSE_BUTTON_RIGHT
	aim.pressed = true
	actor._unhandled_input(aim)
	_check(not actor.ads, "active mantle rejects right-click ADS")
	var overlap := false
	var completed := false
	# A mantle takes 0.48 to 0.95 s by ledge height, and up to 1.12 s fully loaded.
	for index: int in range(72):
		actor._advance_ground_movement(DT, Vector2.ZERO, false, false, true)
		await physics_frame
		if _world_overlap():
			overlap = true
		if not actor.mantle_active:
			completed = true
			break
	_check(completed and actor.global_position.y > 1.0 and actor.global_position.z < -1.0, "mantle physically reaches top of ledge")
	_check(not overlap, "actual lift-then-cross capsule trajectory never overlaps ledge geometry")
	_check(actor.collision_layer == 1 and actor.collision_mask == 3, "completed mantle restores gameplay collision layers")
	await _reset()
	obstacle.position = Vector3(0, 2.2, -0.5)
	await physics_frame
	await physics_frame
	before = actor.stamina
	_check(not actor._try_start_mantle(Vector3.FORWARD), "low overhang rejects unsafe mantle even with reachable ledge")
	_check(not actor.mantle_active and is_equal_approx(actor.stamina, before), "rejected overhang mantle charges no stamina and preserves collisions")
	# An offset shoulder overhang leaves the centre rays unobstructed.
	obstacle.position = Vector3(0.44, 2.2, -0.5)
	(obstacle.get_child(0).shape as BoxShape3D).size = Vector3(0.30, 0.2, 3)
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.82, -0.2), Vector3(0, 1.82, -1.35), 1, [actor.get_rid()])
	_check(actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "shoulder overhang fixture leaves centre clearance ray unobstructed")
	_check(not actor._try_start_mantle(Vector3.FORWARD) and is_equal_approx(actor.stamina, before), "capsule sweep rejects offset shoulder overhang without charge")
	obstacle.position.x = 6
	await physics_frame
	await _reset()
	actor.stamina = 17
	_check(not actor._try_start_mantle(Vector3.FORWARD) and actor.stamina == 17, "insufficient mantle stamina cannot start traversal")
	await _reset()
	actor.healing_active = true
	_check(not actor._try_start_mantle(Vector3.FORWARD), "active treatment cannot mantle")
	await _reset()
	actor.stun_remaining = 1
	_check(not actor._try_start_mantle(Vector3.FORWARD), "stunned player cannot mantle")
	await _reset()
	actor.reloading = true
	_check(not actor._try_start_mantle(Vector3.FORWARD), "reload in progress cannot start mantle")
	await _reset()
	actor._set_crouch_state(true)
	_check(not actor._try_start_mantle(Vector3.FORWARD), "crouched player cannot mantle")
	world.queue_free()
	await process_frame
	print("MANTLE_PHYSICS_TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _box(label: String, dimensions: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	node.shape = shape
	body.add_child(node)
	world.add_child(body)
	return body

func _reset() -> void:
	actor.position = Vector3(0, 0.1, -0.2)
	actor.velocity = Vector3.ZERO
	actor.ads = false
	actor.ads_blend = 0
	actor.reloading = false
	actor.stun_remaining = 0
	actor.reset_survival()
	for index: int in range(12):
		actor._advance_ground_movement(DT, Vector2.ZERO, false, false, false)
		await physics_frame

func _world_overlap() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = actor.body_capsule
	query.transform = actor.body_collision.global_transform
	query.collision_mask = 3
	query.margin = 0.0
	query.exclude = [actor.get_rid()]
	return not actor.get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
