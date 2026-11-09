extends SceneTree

var failures: Array[String] = []
var output_dir := ""
var render := false

func _initialize() -> void:
	render = OS.get_cmdline_user_args().has("--render")
	output_dir = OS.get_environment("SHINRAI_INVENTORY_QA")
	call_deferred("run_checks")

func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value:
		failures.append(label)

func run_checks() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = output_dir.path_join("live_test_profile.json")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	# The world-complete step (biomes etc.) now finishes before HQ: ~150-190 s.
	var deadline := Time.get_ticks_msec() + 360000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	check(raid.phase == raid.Phase.HQ, "Configured main reaches operations")
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	if render:
		await capture("operations")
	raid.profile.data.stash = {"circuit": 3, "optics": 2, "archive": 1, "cell": 4}
	raid.profile.data.credits = 1600
	raid.profile.save_profile()
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.pressed = true
	raid._input(key)
	check(raid.inventory_open and raid.phase == raid.Phase.HQ, "I opens banked stash before deployment")
	check(raid.hud.panel_content.find_children("*", "Button", true, false).size() > 8, "Inventory offers real item controls")
	if render:
		await capture("stash")
	var inventory: Node = raid.hud.panel_content.get_child(0)
	var preview: Node = inventory.find_child("EquipmentPreview", true, false)
	if preview != null:
		check(preview.available and preview.inspect_equipment(), "Supplied equipment rig plays authored inspection")
		if render:
			await create_timer(0.55).timeout
			await capture("inspect")
	raid.hud.action_requested.emit("sell_item:circuit:1")
	check(raid.profile.data.stash.circuit == 2 and raid.profile.data.credits == 1685, "HUD action sells selected quantity and updates saved balance")
	raid.hud.action_requested.emit("medkit")
	check(raid.inventory_open and raid.profile.data.prepared_medkit, "Preparation purchase keeps inventory open")
	if render:
		root.content_scale_size = Vector2i(1920, 1080)
		root.size = Vector2i(1280, 720)
		await capture("stash_1280")
		root.size = Vector2i(1920, 1080)
	raid._input(key)
	check(not raid.inventory_open and raid.phase == raid.Phase.HQ, "I returns to operations")
	raid.start_run()
	check(raid.phase == raid.Phase.RAID and raid.medkits == 2, "Prepared equipment deploys into raid")
	raid._clear_enemies()
	for item: Dictionary in raid.ITEMS:
		raid.bag.append(item.duplicate(true))
	raid._input(key)
	var clock_before: float = raid.remaining
	for frame: int in range(8):
		await process_frame
	check(raid.inventory_open and raid.phase == raid.Phase.PAUSED and raid.remaining == clock_before, "Cargo inventory freezes solo raid clock and actors")
	if render:
		await capture("cargo")
	raid.hud.action_requested.emit("discard_item:1")
	check(raid.bag.size() == 3 and raid.bag[1].id == "cell", "Targeted discard preserves other cargo slots")
	raid.hud.action_requested.emit("sort_cargo")
	check(raid.bag.size() == 3, "Sorting preserves cargo count")
	raid.hud.action_requested.emit("map")
	check(not raid.inventory_open and raid.hud.map_view != null, "Inventory can switch to the existing field map")
	raid.hud.action_requested.emit("inventory")
	raid.hud.action_requested.emit("inventory_close")
	check(raid.phase == raid.Phase.RAID and not raid.inventory_open, "Closing cargo returns mouse and actors to raid")
	raid.finish_run(false, "Inventory integration test")
	check(raid.profile.data.stash.get("circuit", 0) == 2 and raid.profile.data.stash.get("cell", 0) == 4, "Death does not bank carried inventory")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("INVENTORY_LIVE_RESULT: ", failures.size(), " failures")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	for frame: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	print("INVENTORY_CAPTURE: ", path)
