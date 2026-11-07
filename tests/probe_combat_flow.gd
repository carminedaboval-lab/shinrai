extends SceneTree

# A real fight with the awareness running: contact, a wounded unit falling back,
# a kill, then the player vanishing so the pack has to hunt. Prints a timeline.
# Headless: godot --headless --path . --script res://tests/probe_combat_flow.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_combat_flow_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	raid.start_run()
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	raid.player.set("god_mode", true)
	while raid.has_method("insertion_grace") and raid.insertion_grace():
		await process_frame
	var pack: Node3D = scene.get_node("PoliceDroneGroups").groups[2]
	var lead: CharacterBody3D = pack.living_members()[0]
	raid.player.global_position = lead.global_position + lead.global_basis.z * 14.0 + Vector3.UP * .3
	var worst := 0
	var fight_until := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < fight_until and not pack.battle_active:
		await physics_frame
	print("FLOW battle_active=%s after contact" % pack.battle_active)
	await _report(pack, "in contact", 2.0)
	var hurt: CharacterBody3D
	for member: CharacterBody3D in pack.living_members():
		if member != pack.gunner and member.get_node("Awareness").state == "COMBAT" and member.mode == "GROUND" and member.combat.attack == "":
			hurt = member
			break
	if hurt != null:
		hurt.dodge_chance = 0.0
		hurt.health.body_hp = 30.0
		hurt.take_damage(1.0, raid.player)
		print("FLOW wounded unit withdrawing=%s" % pack.withdrawals.has(hurt))
	await _report(pack, "after wound", 3.0)
	var killed: CharacterBody3D = pack.living_members()[-1]
	killed.health.damage_body(100.0)
	await _report(pack, "after kill", 2.0)
	# The player slips away: the pack only has its last sighting to go on.
	var before: Dictionary = {}
	for member: CharacterBody3D in pack.living_members(): before[member] = member.global_position
	var last_seen: Vector3 = pack.observed_contact
	raid.player.visible = false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 40000:
		await physics_frame
		worst = maxi(worst, int(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0))
		if (Time.get_ticks_msec() - started) % 5000 < 17: _print_pack(pack, "hunt t=%ds" % ((Time.get_ticks_msec() - started) / 1000))
		var settled := true
		for member: CharacterBody3D in pack.living_members():
			if member.get_node("Awareness").state not in ["PATROL", "RELAX"]: settled = false
		if settled: break
	print("FLOW hunt ended after %d s, worst physics tick %d ms" % [(Time.get_ticks_msec() - started) / 1000, worst])
	for member: CharacterBody3D in pack.living_members():
		var moved: float = (member.global_position - (before[member] as Vector3)).length()
		print("FLOW %s travelled %.1f m, ends %.1f m from last sighting" % [member.name, moved, member.global_position.distance_to(last_seen)])
	print("FLOW_RESULT done")
	quit(0)

func _report(pack: Node3D, label: String, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame
	_print_pack(pack, label)

func _print_pack(pack: Node3D, label: String) -> void:
	var rows: Array[String] = []
	for member: CharacterBody3D in pack.living_members():
		var brain: Node = member.get_node("Awareness")
		rows.append("%s/%s/hp%d%s" % [brain.state, member.nav_status, int(member.health.body_hp), "/withdrawing" if pack.withdrawals.has(member) else ""])
	print("FLOW %s: %s" % [label, ", ".join(rows)])
