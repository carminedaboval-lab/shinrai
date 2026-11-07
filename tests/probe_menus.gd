extends SceneTree

# Captures the operations screen, pause menu and field map from the real game.
# godot --path . --script res://tests/probe_menus.gd
# Saves user://visual_fx_qa/menu_*.png. Allows a slow park load (5 minutes).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_menu_probe_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	await _capture("menu_operations")
	raid.start_run()
	for frame: int in range(30):
		await process_frame
	raid.hud.show_pause(raid, false)
	await _capture("menu_pause")
	raid.hud.show_pause(raid, true)
	await _capture("menu_map")
	raid.hud.show_quit_confirmation(raid)
	await _capture("menu_quit")
	quit()

func _capture(label: String) -> void:
	for frame: int in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://visual_fx_qa")
	root.get_texture().get_image().save_png("user://visual_fx_qa/%s.png" % label)
	print("MENU_CAPTURE ", label)
