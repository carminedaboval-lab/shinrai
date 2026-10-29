extends SceneTree

var checks := 0
var failures: Array[String] = []
var world: Node3D
var actor: FixturePlayer
var ceiling: StaticBody3D
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
	_box("Floor", Vector3(200, 0.2, 200), Vector3(0, -0.1, 0))
	ceiling = _box("LowCeiling", Vector3(3, 0.2, 3), Vector3(4, 1.4, 0))
	actor = FixturePlayer.new()
	actor.extraction_mode = true
	actor.position = Vector3(0, 0.1, 0)
	world.add_child(actor)
	await physics_frame
	await physics_frame
	await _settle()
	_check(actor.is_on_floor(), "fixture player physically lands on flat floor")
	await _test_stance_clearance()
	await _test_sprint_policy()
	await _test_stamina_and_cargo()
	await _test_jump_edges()
	await _test_legacy_review_policy()
	world.queue_free()
	await process_frame
	print("SURVIVAL_PHYSICS_TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _box(label: String, dimensions: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _step(input_vec := Vector2.ZERO, sprint := false, crouch := false, jump := false, delta := DT) -> void:
	actor._advance_ground_movement(delta, input_vec, sprint, crouch, jump)
	await physics_frame

func _settle() -> void:
	for index: int in range(12):
		await _step()

func _reset_on_open_floor() -> void:
	actor.global_position = Vector3(0, 0.1, 4)
	actor.velocity = Vector3.ZERO
	actor.ads = false
	actor.ads_blend = 0.0
	actor.reloading = false
	actor.stun_remaining = 0.0
	actor.reset_survival()
	await _settle()

func _test_stance_clearance() -> void:
	var standing_height: float = actor.body_capsule.height
	var standing_eye: float = actor.head.position.y
	await _step(Vector2.ZERO, false, true)
	for index: int in range(20):
		await _step(Vector2.ZERO, false, true)
	_check(actor.crouching and actor.body_capsule.height < 1.3, "crouch changes actual capsule to fit below 1.3m ceiling")
	_check(actor.head.position.y < standing_eye - 0.3, "crouch lowers actual camera head")
	var crouch_height: float = actor.body_capsule.height
	actor.global_position = Vector3(4, actor.position.y, 0)
	actor.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_check(not actor._can_stand(), "standing capsule cannot fit beneath low ceiling")
	await _step()
	_check(actor.crouching and is_equal_approx(actor.body_capsule.height, crouch_height), "release crouch preserves physical low stance when blocked")
	var space := actor.get_world_3d().direct_space_state
	var occupied := PhysicsShapeQueryParameters3D.new()
	occupied.shape = actor.body_capsule
	occupied.transform = actor.body_collision.global_transform
	occupied.collision_mask = 1
	occupied.exclude = [actor.get_rid()]
	_check(space.intersect_shape(occupied).is_empty(), "blocked stand leaves current crouched capsule free of world overlap")
	# Shoulder ceiling: centre upward ray is clear, but the capsule volume is not.
	ceiling.position = Vector3(4.4, 1.4, 0)
	(ceiling.get_child(0).shape as BoxShape3D).size = Vector3(0.4, 0.2, 3)
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(4, 0.1, 0), Vector3(4, 2.0, 0), 1, [actor.get_rid()])
	_check(space.intersect_ray(ray).is_empty(), "shoulder ceiling fixture leaves centre vertical ray clear")
	_check(not actor._can_stand(), "full standing capsule catches off-centre shoulder obstruction")
	await _step()
	_check(actor.crouching, "off-centre obstruction prevents standing after key release")
	actor.position = Vector3(0, actor.position.y, 4)
	await physics_frame
	for index: int in range(20):
		await _step()
	print("STANCE_FIXTURE: open floor position=%s, can_stand=%s, crouching=%s, head_y=%s" % [actor.position, actor._can_stand(), actor.crouching, actor.head.position.y])
	_check(not actor.crouching and is_equal_approx(actor.body_capsule.height, standing_height), "standing resumes physically after leaving obstruction")
	_check(absf(actor.head.position.y - standing_eye) < 0.03, "standing restores camera eye height")

func _test_sprint_policy() -> void:
	await _reset_on_open_floor()
	await _step(Vector2(0, -1), true)
	_check(actor.sprinting, "forward input and held sprint starts sprint")
	for blocker: String in ["ads", "reloading", "healing_active", "stun_remaining"]:
		await _reset_on_open_floor()
		actor.set(blocker, 1.0 if blocker == "stun_remaining" else true)
		await _step(Vector2(0, -1), true)
		_check(not actor.sprinting, "sprint is blocked by " + blocker)
	await _reset_on_open_floor()
	await _step(Vector2(0, 1), true)
	_check(not actor.sprinting, "backward input cannot sprint")
	await _reset_on_open_floor()
	await _step(Vector2(1, 0), true)
	_check(not actor.sprinting, "pure sideways input cannot sprint")
	await _reset_on_open_floor()
	await _step(Vector2(0, -1), true, true)
	_check(actor.crouching and not actor.sprinting, "crouch and sprint resolve to crouched movement")

func _test_stamina_and_cargo() -> void:
	await _reset_on_open_floor()
	var initial: float = actor.stamina
	for index: int in range(60):
		await _step(Vector2(0, -1), true)
	var empty_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var empty_drain: float = initial - actor.stamina
	_check(empty_drain > 0 and empty_drain < actor.max_stamina, "one second sprint drains bounded stamina")
	_check(empty_speed > actor.walk_speed, "sprint physically moves faster than walk")
	await _reset_on_open_floor()
	actor.set_cargo_load(6, 6)
	_check(is_equal_approx(actor.cargo_load_ratio, 1.0), "full cargo sets normalized load")
	for index: int in range(60):
		await _step(Vector2(0, -1), true)
	var loaded_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var loaded_drain: float = actor.max_stamina - actor.stamina
	_check(loaded_speed < empty_speed, "full cargo reduces actual sprint speed")
	_check(loaded_drain > empty_drain, "full cargo costs more sprint stamina")
	actor.set_cargo_load(12, 6)
	_check(is_equal_approx(actor.cargo_load_ratio, 1.0), "over-capacity cargo ratio clamps safely")
	actor.set_cargo_load(-2, 0)
	_check(is_equal_approx(actor.cargo_load_ratio, 0.0), "negative cargo and empty capacity do not add load")
	await _reset_on_open_floor()
	actor.stamina = 0.2
	await _step(Vector2(0, -1), true)
	await _step(Vector2(0, -1), true)
	_check(not actor.sprinting and actor.stamina >= 0, "exhaustion stops sprint and cannot create negative stamina")
	for index: int in range(12):
		await _step(Vector2(0, -1), true)
	_check(not actor.sprinting, "exhausted sprint cannot immediately flicker back on")
	for index: int in range(240):
		await _step()
	_check(actor.stamina > 20 and actor.stamina <= actor.max_stamina, "standing rest recovers stamina within maximum")
	await _step(Vector2(0, -1), true)
	_check(actor.sprinting, "recovered stamina permits a later sprint")
	actor.stamina = 3
	actor.healing_active = true
	actor.crouching = true
	actor.jump_was_down = true
	actor.set_cargo_load(6, 6)
	await _reset_on_open_floor()
	_check(is_equal_approx(actor.stamina, actor.max_stamina) and not actor.sprinting and not actor.crouching and not actor.healing_active and not actor.jump_was_down and is_zero_approx(actor.cargo_load_ratio), "deployment reset clears stamina, stance, heal, jump and cargo state")

func _test_jump_edges() -> void:
	await _reset_on_open_floor()
	var before: float = actor.stamina
	await _step(Vector2.ZERO, false, false, true)
	_check(actor.velocity.y > 0 and actor.stamina < before, "fresh jump press launches body and charges stamina")
	var landed := false
	var jumped_again := false
	for index: int in range(110):
		await _step(Vector2.ZERO, false, false, true)
		if landed and actor.velocity.y > 1:
			jumped_again = true
		if actor.is_on_floor():
			landed = true
	_check(landed and not jumped_again and actor.is_on_floor(), "held jump remains grounded after landing without automatic bunny hop")
	await _step()
	await _step(Vector2.ZERO, false, false, true)
	_check(actor.velocity.y > 0, "release and fresh jump press permits another jump")
	await _reset_on_open_floor()
	actor.stamina = 0
	await _step(Vector2.ZERO, false, false, true)
	_check(actor.velocity.y <= 0 and actor.is_on_floor(), "insufficient stamina prevents jump without leaving floor")

func _test_legacy_review_policy() -> void:
	await _reset_on_open_floor()
	actor.extraction_mode = false
	actor.stamina = 0
	actor.set_cargo_load(6, 6)
	await _step(Vector2(0, -1), true, true)
	_check(actor.sprinting and not actor.crouching and is_equal_approx(actor.movement_speed(), actor.sprint_speed), "review mode preserves sprint speed without survival load or crouch restrictions")
	_check(is_zero_approx(actor.stamina), "review movement does not spend or recover survival stamina")
	await _step(Vector2.ZERO, false, false, true)
	_check(actor.velocity.y > 0 and is_zero_approx(actor.stamina), "review mode preserves jump without survival stamina charge")
