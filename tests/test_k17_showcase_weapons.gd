extends SceneTree

# Focused entry-encounter and dual-weapon regression. Run with the trial K17
# scripts applied to a checkout; the saved QA profile is deliberately separate.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("K17 SHOWCASE FAILED: " + description)

func _line_of_sight(from: Vector3, to: Vector3, player: CollisionObject3D, enemy: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
	return hit.get("collider") == enemy

func _run() -> void:
	var scene: Node3D = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_k17_showcase_qa.json"
	var qa_path: String = ProjectSettings.globalize_path(scene.profile_path)
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(qa_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline: int = Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(raid.phase == raid.Phase.HQ, "Park loads to HQ")
	if raid.phase != raid.Phase.HQ:
		_finish(qa_path)
		return
	raid.start_run()
	for frame: int in range(3):
		await physics_frame
	_check(raid.phase == raid.Phase.RAID, "Raid deploys")
	var patrols: Array[Node] = get_nodes_in_group("extraction_hostiles")
	_check(patrols.size() == 7, "Six relay K17s and one entry K17 spawn")
	var entry: Node3D = scene.find_child("K17_EntryGuard", true, false) as Node3D
	_check(entry != null and patrols.has(entry), "Entry K17 is a live hostile")
	if entry == null:
		_finish(qa_path)
		return
	for patrol: Node in patrols:
		patrol.set_physics_process(false)
	var player: CharacterBody3D = raid.player
	player.velocity = Vector3.ZERO
	var camera: Camera3D = player.camera
	var visual: MeshInstance3D = entry.find_child("K17_Drone", true, false) as MeshInstance3D
	_check(visual != null and visual.visible, "Entry K17 uses visible supplied model")
	_check(entry.find_child("PistolMuzzle", true, false) is Marker3D and entry.find_child("StunMuzzle", true, false) is Marker3D, "K17 has separate pistol and stun muzzle sockets")
	var target_point: Vector3 = entry.global_position + Vector3.UP * 1.1
	var screen_size: Vector2 = root.get_visible_rect().size
	var screen_point: Vector2 = camera.unproject_position(target_point)
	var on_screen: bool = (
		not camera.is_position_behind(target_point)
		and screen_point.x >= 0.0 and screen_point.x <= screen_size.x
		and screen_point.y >= 0.0 and screen_point.y <= screen_size.y
	)
	_check(on_screen, "Entry K17 appears inside the starting camera view")
	_check(_line_of_sight(camera.global_position, target_point, player, entry), "Entry K17 has clear player sightline")
	_check(player.global_position.distance_to(entry.global_position) <= 28.0, "Entry K17 is near enough to notice")

	# Move the player down the same clear line for reliable close-range attack QA.
	var from_entry: Vector3 = player.global_position - entry.global_position
	from_entry.y = 0.0
	if from_entry.length_squared() < 0.01:
		from_entry = Vector3.FORWARD
	player.global_position = entry.global_position + from_entry.normalized() * 4.0 + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	entry.look_at(Vector3(player.global_position.x, entry.global_position.y, player.global_position.z))
	await physics_frame
	_check(entry._can_see_target(), "Uncovered K17 has a clear line to the nearby player")

	# Force the pistol branch and verify a shot, not only a color/light cue.
	entry.shots_since_stun = 0
	entry.stun_cooldown = 7.0
	var health_before: float = player.health
	var pistol_hit := false
	for attempt: int in range(6):
		entry._shoot_at_player(4.0)
		if player.health < health_before:
			pistol_hit = true
			break
	_check(entry.last_weapon == "pistol" and pistol_hit, "Pistol fires and damages the unobstructed player")
	_check(player.stun_remaining <= 0.0, "Pistol does not apply the stun effect")

	# Force the next attack onto the separate stun circuit. A stun should briefly
	# change player control and then expire without leaving extraction unusable.
	player.stun_immunity_remaining = 0.0
	for attempt: int in range(6):
		entry.shots_since_stun = 2
		entry.stun_cooldown = 0.0
		entry._shoot_at_player(4.0)
		if player.stun_remaining > 0.0:
			break
	_check(entry.last_weapon == "stun" and player.stun_remaining > 0.0, "Stun weapon briefly disables the player")
	var stunned_ammo: int = player.ammo
	player.fire_cooldown = 0.0
	player.shoot()
	_check(player.ammo == stunned_ammo, "Player cannot shoot while stunned")
	var stun_expiry_deadline: int = Time.get_ticks_msec() + 5000
	while player.stun_remaining > 0.0 and Time.get_ticks_msec() < stun_expiry_deadline:
		await physics_frame
	_check(player.stun_remaining <= 0.0, "Stun expires and player control recovers")
	player.fire_cooldown = 0.0
	player.shoot()
	_check(player.ammo == stunned_ammo - 1, "Player can shoot after stun recovery")

	# A lightweight physical wall must stop the pistol ray. This also protects
	# park cover gameplay against a regression to direct distance-based damage.
	var cover := StaticBody3D.new()
	cover.name = "K17WeaponQACover"
	cover.collision_layer = 1
	cover.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.35)
	shape.shape = box
	cover.add_child(shape)
	scene.add_child(cover)
	cover.global_position = (entry.global_position + player.global_position) * 0.5 + Vector3.UP * 1.0
	cover.look_at(Vector3(player.global_position.x, cover.global_position.y, player.global_position.z))
	await physics_frame
	entry.shots_since_stun = 0
	entry.stun_cooldown = 7.0
	health_before = player.health
	for attempt: int in range(3):
		entry._shoot_at_player(4.0)
	_check(is_equal_approx(player.health, health_before), "Pistol fire stops at physical cover")
	cover.queue_free()
	await physics_frame

	# Exercise the normal AI tick as well as the weapon method: a visible player
	# in combat range must make the guard fire without a test calling its gun.
	entry.shots_since_stun = 0
	entry.stun_cooldown = 7.0
	entry.attack_cooldown = 0.0
	entry._enter_state(entry.AIState.COMBAT)
	entry.set_physics_process(true)
	for frame: int in range(3):
		await physics_frame
	_check(entry.shots_since_stun >= 1 and entry.attack_cooldown > 0.0, "Combat AI fires the pistol on its own")
	entry.set_physics_process(false)

	print("K17_SHOWCASE_WEAPONS_RESULT: ", failures.size(), " failures")
	_finish(qa_path)

func _finish(qa_path: String) -> void:
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(qa_path + suffix)
	quit(0 if failures.is_empty() else 1)
