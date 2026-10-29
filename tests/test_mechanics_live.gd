extends SceneTree
var failures: Array[String] = []
var render := false
var output := ""

func _initialize() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	output = OS.get_environment("SHINRAI_MECHANICS_QA")
	call_deferred("review")

func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value:
		failures.append(label)

func review() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = output.path_join("mechanics_live_profile.json")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 120000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	check(raid.phase == raid.Phase.HQ, "Configured main reaches operations with mechanics update")
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	raid.start_run()
	raid._clear_enemies()
	for frame: int in range(120):
		await physics_frame
		await process_frame
		if raid.player.is_on_floor():
			print("MECHANICS_LANDING: frames=", frame + 1, " position=", raid.player.position)
			break
		if frame % 30 == 0:
			print("MECHANICS_SETTLING: position=", raid.player.position, " velocity=", raid.player.velocity, " enabled=", raid.player.is_physics_processing())
	check(raid.player.stamina == 100.0 and not raid.player.crouching and not raid.player.healing_active, "Deployment resets survival state")
	check(raid.player.is_on_floor(), "Live player lands on park collision geometry")
	raid.set_physics_process(false)
	raid.player.set_physics_process(false)
	for index: int in range(raid.capacity()):
		raid.bag.append(raid.ITEMS[index % 4].duplicate(true))
	raid.player.set_cargo_load(raid.bag.size(), raid.capacity())
	check(raid.player.cargo_load_ratio == 1.0, "Live cargo binds to movement load")
	raid.player.health = 65.0
	raid.run_time = 5.0
	raid._advance_healing(1.0, true, false)
	check(raid.player.healing_active and is_equal_approx(raid.healing, 1.0), "Live run begins treatment through shared medical state")
	raid.pause_run(false)
	check(raid.healing == 0.0 and not raid.player.healing_active, "Pause cancels treatment without consuming a medkit")
	raid.resume_run()
	raid.player.set_physics_process(false)
	raid._advance_healing(2.5, true, false)
	check(raid.medkits == 0 and raid.player.health == 100.0, "Live treatment consumes one medkit on completion")
	raid.player.health = 67.0
	raid.player.ammo = 21
	raid.player.stamina = 64.0
	raid.relays = 1
	raid.prompt_text = ""
	raid.progress_ratio = 0.0
	raid.notice_time = 0.0
	raid.hud.update_raid(raid)
	check(raid.hud.objectives.text.is_empty() and not raid.hud.prompt.visible, "Idle HUD removes persistent mission and control text")
	check(raid.hud.vitals.text == "21 / 090" and raid.hud.raid_status.health == 67.0 and raid.hud.raid_status.stamina == 64.0, "Compact HUD uses live ammunition, health and stamina")
	if render:
		await capture("hud_day")
		root.size = Vector2i(1280, 720)
		await capture("hud_1280")
		root.size = Vector2i(1920, 1080)
		var cache: Dictionary = raid.sites.filter(func(site: Dictionary) -> bool: return site.kind == "cache")[0]
		raid.player.position = cache.position + Vector3(2.0, 0.2, 0.0)
		raid._update_interaction(0.0)
		raid.hud.update_raid(raid)
		await capture("hud_context")
		raid.player.ads = true
		raid.player.ads_blend = 1.0
		raid.hud.update_raid(raid)
		check(not raid.hud.marker.visible, "Waypoint hides during aiming")
		raid.player.ads = false
		raid.player.ads_blend = 0.0
		scene.is_night_mode = true
		scene._apply_time_of_day()
		raid.prompt_text = ""
		raid.hud.update_raid(raid)
		await capture("hud_night")
	raid.open_inventory()
	check(raid.inventory_open and not raid.hud.raid_status.visible and raid.hud.overlay.visible, "Inventory hides combat HUD and opens normally")
	raid.close_inventory()
	check(raid.phase == raid.Phase.RAID and raid.hud.raid_status.visible, "Closing inventory restores combat HUD")
	# Recreate the collision state while traversing a mantle, then leave the raid.
	var saved_layer: int = raid.player.collision_layer
	var saved_mask: int = raid.player.collision_mask
	raid.player.mantle_saved_layer = saved_layer
	raid.player.mantle_saved_mask = saved_mask
	raid.player.mantle_active = true
	raid.player.collision_layer = 0
	raid.player.collision_mask = 0
	raid.finish_run(false, "Interrupted mantle integration test")
	raid._on_action("hq")
	raid.start_run()
	raid._clear_enemies()
	check(raid.phase == raid.Phase.RAID, "Result-to-operations flow allows redeployment")
	check(not raid.player.mantle_active and raid.player.collision_layer == saved_layer and raid.player.collision_mask == saved_mask, "Redeploy after interrupted mantle restores collision")
	raid.player.set_physics_process(true)
	for frame: int in range(120):
		await physics_frame
		await process_frame
		if raid.player.is_on_floor():
			break
	check(raid.player.is_on_floor(), "Redeployed player lands after interrupted mantle")
	raid.finish_run(false, "Mechanics integration test")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("MECHANICS_LIVE_RESULT: ", failures.size(), " failures")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	print("MECHANICS_CAPTURE: ", path)
