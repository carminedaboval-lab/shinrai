extends SceneTree

const Run = preload("res://scripts/extraction_run.gd")
var checks := 0
var failures: Array[String] = []
var player: FixturePlayer
var run: FixtureRun
var world: Node3D

class FixturePlayer extends "res://scripts/player.gd":
	func _ready() -> void:
		collision_layer = 1
		collision_mask = 3
		_build_collision()
		_build_camera()
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)

class FixtureRun extends "res://scripts/extraction_run.gd":
	func _ready() -> void:
		set_physics_process(false)
		set_process_input(false)

class FakeHud extends CanvasLayer:
	func show_pause(_run: Node, _with_map: bool) -> void:
		pass
	func show_raid() -> void:
		pass

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20, 0.2, 20)
	collision.shape = floor_shape
	floor_body.position.y = -0.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	player = FixturePlayer.new()
	player.extraction_mode = true
	player.position = Vector3(0, 0.1, 0)
	world.add_child(player)
	run = FixtureRun.new()
	run.player = player
	run.hud = FakeHud.new()
	run.add_child(run.hud)
	world.add_child(run)
	player.healing_cancelled.connect(run._cancel_healing)
	await physics_frame
	await physics_frame
	for index: int in range(12):
		player._advance_ground_movement(1.0 / 60.0, Vector2.ZERO, false, false, false)
		await physics_frame
	_check(player.is_on_floor(), "healing fixture uses physically grounded player")
	_prepare()
	_check(run.can_heal(), "damaged grounded player can heal during raid")
	player.ads = true
	run._advance_healing(1.0, true, false)
	_check(is_equal_approx(run.healing, 1.0) and player.healing_active and not player.ads, "healing starts and exits ADS")
	_check(run.medkits == 2 and is_equal_approx(player.health, 40.0), "partial treatment consumes no medkit or health gain")
	run._advance_healing(1.4, true, false)
	_check(run.medkits == 2 and is_equal_approx(player.health, 40.0), "treatment remains unpaid before 2.5 seconds")
	run._advance_healing(0.11, true, false)
	_check(run.medkits == 1 and is_equal_approx(player.health, 95.0) and not player.healing_active and is_zero_approx(run.healing), "completed treatment adds55 health and consumes exactly one medkit")
	run._advance_healing(2.5, true, false)
	_check(run.medkits == 0 and is_equal_approx(player.health, 100.0), "second treatment clamps health and consumes one remaining medkit")
	run._advance_healing(3.0, true, false)
	_check(run.medkits == 0 and player.health == 100 and not player.healing_active, "no medical charges can be spent after kit depletion")
	for blocker: String in ["reloading", "stun_remaining", "mantle_active"]:
		_prepare()
		run._advance_healing(1.0, true, false)
		player.set(blocker, 0.5 if blocker == "stun_remaining" else true)
		run._advance_healing(2.0, true, false)
		_check(is_zero_approx(run.healing) and not player.healing_active and run.medkits == 2 and player.health == 40, "treatment cancels without charge when " + blocker)
	_prepare()
	run._advance_healing(1.0, true, false)
	run._advance_healing(2.0, false, false)
	_check(is_zero_approx(run.healing) and not player.healing_active and run.medkits == 2, "releasing H cancels treatment without charge")
	_prepare()
	run._advance_healing(1.0, true, false)
	run._advance_healing(2.0, true, true)
	_check(is_zero_approx(run.healing) and not player.healing_active and run.medkits == 2, "firing request cancels treatment without charge")
	_prepare()
	run._advance_healing(1.0, true, false)
	run._on_damage(5.0)
	_check(is_zero_approx(run.healing) and not player.healing_active and not run.can_heal(), "new damage immediately cancels and gates treatment")
	run._advance_healing(2.5, true, false)
	_check(run.medkits == 2 and player.health == 40, "damage cooldown prevents banking interrupted treatment")
	run.run_time += 1.1
	_check(run.can_heal(), "damage cooldown expires before treatment can restart")
	_prepare()
	run._advance_healing(1.0, true, false)
	player._cancel_healing_for_weapon_action()
	_check(not player.healing_active and is_zero_approx(run.healing), "player weapon-action cancellation signal clears controller treatment")
	_prepare()
	run._advance_healing(1.0, true, false)
	var previous_ammo := player.ammo
	player.shoot()
	_check(player.ammo == previous_ammo, "direct shooting cannot consume ammunition while treatment active")
	player.ammo = 12
	player.start_reload()
	_check(not player.reloading, "direct reload cannot run simultaneously with treatment")
	_prepare()
	run._advance_healing(1.0, true, false)
	run._on_shot()
	_check(is_zero_approx(run.healing) and not player.healing_active, "shot event cancels treatment state")
	_prepare()
	run._advance_healing(1.0, true, false)
	run.pause_run(false)
	_check(run.phase == Run.Phase.PAUSED and is_zero_approx(run.healing) and not player.healing_active and run.medkits == 2, "pause clears treatment without spending kit")
	_check(player.process_mode == Node.PROCESS_MODE_DISABLED, "pause disables gameplay actor processing")
	var clock_before := run.remaining
	var stamina_before := player.stamina
	run._physics_process(5.0)
	_check(is_equal_approx(run.remaining, clock_before) and is_equal_approx(player.stamina, stamina_before), "paused controller cannot advance raid clock or player stamina")
	run._advance_healing(3.0, true, false)
	_check(run.medkits == 2 and player.health == 40, "paused raid cannot advance treatment")
	run.resume_run()
	_check(run.phase == Run.Phase.RAID and is_zero_approx(run.healing), "resume preserves cancelled treatment rather than resuming old progress")
	_check(player.process_mode == Node.PROCESS_MODE_INHERIT, "resume re-enables gameplay actor processing")
	_prepare()
	run._advance_healing(1.0, true, false)
	var walking_speed := player.walk_speed
	player._advance_ground_movement(0.1, Vector2(0, -1), true, false, false)
	_check(not player.sprinting and player.movement_speed() < walking_speed, "active treatment slows movement and prevents sprint")
	for invalid_phase: int in [Run.Phase.HQ, Run.Phase.BOOT, Run.Phase.RESULT]:
		_prepare()
		run.phase = invalid_phase
		run._advance_healing(3.0, true, false)
		_check(run.medkits == 2 and player.health == 40 and not player.healing_active, "treatment cannot consume kits outside active raid phase %d" % invalid_phase)
	_prepare()
	player.health = 100
	_check(not run.can_heal(), "full-health player cannot begin treatment")
	_prepare()
	run.medkits = 0
	_check(not run.can_heal(), "empty medical inventory cannot begin treatment")
	_prepare()
	run.hold_progress = 0.1
	_check(not run.can_heal(), "loot interaction and treatment cannot overlap")
	_prepare()
	player.alive = false
	_check(not run.can_heal(), "eliminated player cannot begin treatment")
	_prepare()
	player.position.y = 4.0
	player.velocity = Vector3.ZERO
	player._advance_ground_movement(1.0 / 60.0, Vector2.ZERO, false, false, false)
	await physics_frame
	_check(not player.is_on_floor() and not run.can_heal(), "actual airborne player cannot begin treatment")
	world.queue_free()
	await process_frame
	print("HEALING_TEST_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures:
		print("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _prepare() -> void:
	run._cancel_healing()
	run.phase = Run.Phase.RAID
	run.run_time = 20.0
	run.last_damage_at = -100.0
	run.medkits = 2
	run.hold_progress = 0.0
	player.health = 40
	player.alive = true
	player.ads = false
	player.ads_blend = 0.0
	player.reloading = false
	player.stun_remaining = 0.0
	player.mantle_active = false
	player.ammo = 30
	player.reserve = 90

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
