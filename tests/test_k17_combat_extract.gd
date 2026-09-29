extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, note: String) -> void:
	if ok:
		print("PASS: ", note)
	else:
		failures.append(note)
		push_error("K17 COMBAT EXTRACT FAILED: " + note)

func _run() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var scene: Node3D = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_k17_combat_extract_qa.json"
	var qa_path: String = ProjectSettings.globalize_path(scene.profile_path)
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(qa_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(raid.phase == raid.Phase.HQ, "Park loads to HQ")
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	raid.start_run()
	await physics_frame
	_check(raid.phase == raid.Phase.RAID, "Raid deploys")
	var relay: Dictionary = {}
	for site: Dictionary in raid.sites:
		if site.id == "EmeraldHaloLamp_01":
			relay = site
	_check(not relay.is_empty(), "South relay exists")
	if relay.is_empty():
		quit(1)
		return
	var nearby: Array[Node3D] = []
	for patrol: Node in get_nodes_in_group("extraction_hostiles"):
		if patrol.global_position.distance_to(relay.position) < 35.0:
			nearby.append(patrol as Node3D)
	_check(nearby.size() == 2, "South relay has two K17 guards")
	if nearby.size() != 2:
		quit(1)
		return
	var ammo_at_start: int = raid.player.ammo
	for enemy: Node3D in nearby:
		if not is_instance_valid(enemy):
			continue
		raid.player.global_position = enemy.global_position - enemy.global_transform.basis.z * 3.0 + Vector3.UP * 0.2
		raid.player.velocity = Vector3.ZERO
		raid.player.ads_blend = 1.0
		await physics_frame
		for shot: int in range(4):
			if not is_instance_valid(enemy):
				break
			raid.player.camera.look_at(enemy.global_position + Vector3.UP * 1.1)
			raid.player.shoot()
			for frame: int in range(8):
				await physics_frame
	_check(raid.player.kills == 2, "Actual UZI fire defeats both K17 guards")
	_check(raid.player.ammo < ammo_at_start and raid.player.health > 0.0, "Combat consumes ammo and player survives")
	var relay_stop: Vector3 = raid.navigation.nearest(relay.position)
	raid.player.global_position = relay_stop
	raid.player.velocity = Vector3.ZERO
	await physics_frame
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = true
	Input.parse_input_event(interact)
	for frame: int in range(300):
		await physics_frame
	interact.pressed = false
	Input.parse_input_event(interact)
	_check(relay.done and raid.relays == 1, "Player recovers the defended relay")
	# The new entry K17 patrols the south extraction gate. Clear it with the
	# player's weapon before testing the uninterrupted extraction hold.
	var entry: Node3D = scene.find_child("K17_EntryGuard", true, false) as Node3D
	_check(entry != null, "South gate has a K17 entry patrol")
	if entry != null:
		raid.player.global_position = entry.global_position - entry.global_transform.basis.z * 3.0 + Vector3.UP * 0.2
		raid.player.velocity = Vector3.ZERO
		raid.player.clear_stun()
		await physics_frame
		for shot: int in range(8):
			if not is_instance_valid(entry):
				break
			raid.player.camera.look_at(entry.global_position + Vector3.UP * 1.1)
			raid.player.shoot()
			for frame: int in range(8):
				await physics_frame
		_check(not is_instance_valid(entry), "UZI fire clears the K17 guarding the south extraction gate")
	var extracts_before: int = raid.profile.data.extracts
	raid.player.global_position = raid.navigation.nearest(raid.exits[0].position)
	raid.player.velocity = Vector3.ZERO
	for frame: int in range(1100):
		if raid.phase == raid.Phase.RESULT:
			break
		await physics_frame
	_check(raid.phase == raid.Phase.RESULT and int(raid.profile.data.extracts) == extracts_before + 1, "One defended relay unlocks a successful extraction")
	print("K17_COMBAT_EXTRACT_RESULT: ", failures.size(), " failures")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(qa_path + suffix)
	quit(0 if failures.is_empty() else 1)
