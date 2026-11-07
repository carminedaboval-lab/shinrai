extends SceneTree

# A real fight against the human crew: contact, a hit, an empty magazine, a
# casualty, then the player vanishing. Prints a timeline of what each scav does.
# Headless: godot --headless --path . --script res://tests/probe_scav_fight.gd

var crew: Node3D
var raid: Node
var worst := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_scav_fight_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	raid = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	while raid.has_method("insertion_grace") and raid.insertion_grace():
		await process_frame
	crew = scene.get_node("ScavPatrolCrew")
	while not crew.ready_for_use and Time.get_ticks_msec() < deadline:
		await process_frame
	var lead: CharacterBody3D = crew.members[0]
	raid.player.global_position = lead.global_position - lead.global_basis.z * 16.0 + Vector3.UP * .3
	await physics_frame
	crew.make_hostile(lead, "gunfire")
	crew.tactics.report(lead, raid.player.global_position, "visual")
	await _watch("contact", 12.0)

	var hurt: CharacterBody3D = crew.members[1]
	hurt.take_damage(18.0, raid.player)
	await _watch("after hit", 4.0)

	var empty: CharacterBody3D = crew.members[0]
	empty.weapon_rounds = 1
	print("SCAV stage: gun running dry on ", empty.name)
	await _watch("dry gun", 8.0)

	var killed: CharacterBody3D = crew.members[2]
	killed.take_damage(500.0, raid.player)
	await _watch("after kill", 5.0)

	var last_seen: Vector3 = raid.player.global_position
	# Beyond every sight range, so the crew only has its last sighting to go on.
	raid.player.global_position += Vector3(400.0, 0.0, 0.0)
	await _watch("player gone", 30.0)
	for actor: CharacterBody3D in crew.members:
		if not actor.dead: print("SCAV %s ends %.1f m from last sighting" % [actor.name, actor.global_position.distance_to(last_seen)])
	print("SCAV worst physics tick %d ms" % worst)
	print("SCAV_RESULT done")
	quit(0)

func _watch(label: String, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var next_row := 0
	while Time.get_ticks_msec() < until:
		await physics_frame
		worst = maxi(worst, int(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0))
		if raid.player.get("health") != null: raid.player.set("health", 100.0)
		if Time.get_ticks_msec() >= next_row:
			next_row = Time.get_ticks_msec() + 1500
			_row(label)

func _row(label: String) -> void:
	var rows: Array[String] = []
	for actor: CharacterBody3D in crew.members:
		if actor.dead: rows.append("%s dead" % actor.role); continue
		var order: Dictionary = crew.tactics.orders.get(actor, {})
		var to_player: float = actor.global_position.distance_to(raid.player.global_position)
		rows.append("%s %s/%s hp%d %.0fm fired%d mag%d sees%d crouch%d" % [actor.role, actor.AIState.keys()[actor.state], order.get("kind", "-"), int(actor.health), to_player, actor.rounds_fired, actor.weapon_rounds, 1 if actor.own_visual_time < .3 else 0, 1 if actor.crouching else 0])
	print("SCAV %s: %s" % [label, " | ".join(rows)])
