extends SceneTree

# Captures every menu screen at 1920x1080 for design review, using a throwaway
# QA profile (never the player's save).
#   godot --path . --script res://tests/probe_ui_capture.gd -- --out <dir> [--tag before]
# Writes <dir>/<tag>_<screen>.png: loading, hq_building, hq, hq_inventory, raid_inventory,
# pause, map, quit, abandon, result_won, result_lost.

var out_dir := ""
var tag := "ui"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--out": out_dir = args[i + 1]
		if args[i] == "--tag": tag = args[i + 1]
	if out_dir.is_empty(): out_dir = ProjectSettings.globalize_path("user://ui_capture")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	# Loading screen on its own, mid-progress.
	var loading_script: Script = load("res://scripts/shinrai_loading_screen.gd")
	var loading: CanvasLayer = loading_script.new()
	root.add_child(loading)
	loading.begin("Loading park resources")
	# Overall fraction, as the real flow passes it (0.12 = 60 % of the resources step).
	loading.set_stage("Loading park resources", 0.12)
	await _capture("loading")
	loading.finish()
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_ui_capture_qa.json"
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 420000
	# The Operations menu while the park still builds, as the boot host shows it
	# (3D off, DEPLOY "PREPARING PARK n%"). Taken once the build is well under way.
	var building_at := Time.get_ticks_msec() + 40000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < building_at:
		await process_frame
	if raid.phase == raid.Phase.BOOT and "hq_menu_open" in raid:
		raid.hq_menu_open = true
		root.disable_3d = true
		raid.hud.show_hq(raid)
		await _capture("hq_building")
		root.disable_3d = false
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	# Let post-menu work settle so screenshots are not mid-freeze.
	for i: int in range(120): await process_frame
	await _capture("hq")
	raid.open_inventory()
	await _capture("hq_inventory")
	raid.close_inventory()
	await _capture_settle()
	raid.start_run()
	while raid.phase != raid.Phase.RAID and Time.get_ticks_msec() < deadline + 60000:
		await process_frame
	for i: int in range(30): await process_frame
	await _capture("raid_hud")
	raid.open_inventory()
	await _capture("raid_inventory")
	raid.close_inventory()
	raid.pause_run(false)
	await _capture("pause")
	raid.hud.show_pause(raid, true)
	await _capture("map")
	raid.hud.show_quit_confirmation(raid)
	await _capture("quit")
	raid.hud.show_abandon()
	await _capture("abandon")
	raid.hud.show_result(raid, true, "Extracted through the south gate with the relay data.", 250)
	await _capture("result_won")
	raid.hud.show_result(raid, false, "You were eliminated near the lake promenade.", 0)
	await _capture("result_lost")
	print("UI_CAPTURE done ", out_dir)
	quit()

func _capture_settle() -> void:
	for frame: int in range(20): await process_frame

func _capture(label: String) -> void:
	for frame: int in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("%s_%s.png" % [tag, label])
	root.get_texture().get_image().save_png(path)
	print("UI_CAPTURE ", path)
