extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("K17 TEST FAILED: " + description)

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_k17_integration_qa.json"
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(raid.phase == raid.Phase.HQ, "Park reaches HQ")
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	_check(raid.enemy_visual != null and raid.enemy_visual.resource_path.ends_with("K17_Drone_Static.glb"), "Optimized supplied K17 is loaded")
	raid.start_run()
	for frame: int in range(4):
		await physics_frame
	var patrols := get_nodes_in_group("extraction_hostiles")
	_check(patrols.size() == 7, "Three relay pairs and one entry patrol spawn")
	if patrols.is_empty():
		quit(1)
		return
	var chase_target := patrols[0] as Node3D
	var chase_start: Vector3 = chase_target.global_position
	var patrol_starts: Array[Vector3] = []
	for patrol: Node in patrols:
		patrol_starts.append(patrol.global_position)
	raid.player.global_position = chase_target.global_position - chase_target.global_transform.basis.z * 10.0 + Vector3.UP * 0.2
	raid.player.velocity = Vector3.ZERO
	for frame: int in range(300):
		await physics_frame
	var walking_patrols := 0
	for index: int in range(1, patrols.size()):
		if patrol_starts[index].distance_to(patrols[index].global_position) > 2.0:
			walking_patrols += 1
	_check(walking_patrols >= 4, "Patrols advance through the park instead of oscillating at route cells")
	_check(chase_start.distance_to(chase_target.global_position) > 2.0 and chase_target.state == chase_target.AIState.COMBAT, "K17 detects and approaches a player in front")
	for patrol: Node in patrols:
		patrol.set_physics_process(false)
		_check(patrol.find_child("K17_Drone", true, false) is MeshInstance3D, "Patrol has supplied visible mesh")
	var enemy := patrols[0] as Node3D
	enemy.muzzle_timer = 0.0
	scene.is_night_mode = true
	enemy._update_timers(0.0)
	_check(is_equal_approx(enemy.muzzle_light.light_energy, 0.55), "K17 remains readable under night lighting")
	enemy.muzzle_timer = 0.08
	enemy._update_timers(0.0)
	_check(enemy.muzzle_light.light_energy >= 6.9 and enemy.muzzle_light.light_color.r > enemy.muzzle_light.light_color.b, "Warm muzzle flash overrides cool night light")
	enemy.muzzle_timer = 0.0
	scene.is_night_mode = false
	enemy._update_timers(0.0)
	_check(enemy.muzzle_light.light_energy < 0.01, "Idle K17 light switches off during daylight")
	var visual := enemy.find_child("K17_Drone", true, false) as MeshInstance3D
	var bounds := visual.mesh.get_aabb()
	_check(bounds.size.y > 1.8 and bounds.size.y < 2.1 and absf(bounds.position.y) < 0.02, "K17 has correct upright scale and grounded pivot")
	var shape_names: Array[String] = []
	for shape: Node in enemy.find_children("*_Hit", "CollisionShape3D", true, false):
		shape_names.append(String(shape.name))
	_check(shape_names.size() == 4, "Four lightweight arm and fin hitboxes are installed")
	var hit_all := true
	for sample: Vector2 in [Vector2(0.0, 1.1), Vector2(-0.65, 0.8), Vector2(0.65, 0.8), Vector2(-0.65, 1.55), Vector2(0.65, 1.55)]:
		var point := enemy.global_position + enemy.global_transform.basis.x * sample.x + Vector3.UP * sample.y
		var query := PhysicsRayQueryParameters3D.create(point - enemy.global_transform.basis.z * 4.0, point + enemy.global_transform.basis.z * 4.0, 2)
		var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
		hit_all = hit_all and hit.get("collider") == enemy
	_check(hit_all, "Body, weapon arms and upper fins accept hits")
	raid.player.set_physics_process(false)
	raid.player.global_position = enemy.global_position - enemy.global_transform.basis.z * 3.0 + Vector3.UP * 0.2
	raid.player.velocity = Vector3.ZERO
	await physics_frame
	raid.player.ads_blend = 1.0
	raid.player.recoil_pitch = 0.0
	raid.player.fire_cooldown = 0.0
	raid.player.camera.look_at(enemy.global_position + Vector3.UP * 1.1)
	var health_before: float = enemy.health
	var ammo_before: int = raid.player.ammo
	raid.player.shoot()
	_check(enemy.health < health_before and raid.player.ammo == ammo_before - 1, "UZI damages K17 body and consumes one round")
	raid.player.fire_cooldown = 0.0
	raid.player.camera.look_at(enemy.global_position + enemy.global_transform.basis.x * 0.65 + Vector3.UP * 0.8)
	health_before = enemy.health
	raid.player.shoot()
	_check(enemy.health < health_before, "UZI damages the visible weapon arm")
	raid.player.fire_cooldown = 0.0
	raid.player.camera.look_at(enemy.global_position + Vector3.UP * 1.1)
	raid.player.shoot()
	_check(enemy.defeat_reported and raid.player.kills == 1, "Final UZI hit records one K17 defeat")
	print("K17_INTEGRATION_RESULT: ", failures.size(), " failures")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	quit(0 if failures.is_empty() else 1)
