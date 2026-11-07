extends SceneTree

# Measures how long the extraction scene takes to reach HQ (no time limit
# beyond 5 minutes) and then deploys to check the raid starts cleanly.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var started := Time.get_ticks_msec()
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_boot_probe_qa.json"
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() - started < 300000:
		await process_frame
	print("BOOT_PROBE reached phase %s after %.1f s" % [raid.phase, (Time.get_ticks_msec() - started) / 1000.0])
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	raid.start_run()
	for frame: int in range(30):
		await physics_frame
	var player: Node = raid.player
	var hostiles := get_nodes_in_group("extraction_hostiles")
	var styled := 0
	for hostile: Node in hostiles:
		if hostile.get("look") != null and hostile.look.material != null:
			styled += 1
	print("BOOT_PROBE hostiles=%d styled=%d" % [hostiles.size(), styled])
	print("BOOT_PROBE crosshair=%s damage_dir=%s impact_fx=%s trauma=%s" % [is_instance_valid(player.tactical_crosshair), is_instance_valid(player.damage_direction), is_instance_valid(player.impact_fx), is_instance_valid(player.camera_trauma)])
	player.register_damage_source(player.global_position + Vector3(5, 0, 0))
	player.take_damage(12.0)
	player.fire_cooldown = 0.0
	player.shoot()
	for frame: int in range(10):
		await process_frame
	print("BOOT_PROBE damage_marks=%d hp=%.1f ammo=%d" % [player.damage_direction._marks.size(), player.health, player.ammo])
	print("BOOT_PROBE done")
	quit()
