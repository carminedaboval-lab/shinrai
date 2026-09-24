extends SceneTree

# Three isolated snapshots for CI visual inspection; uses a separate QA save.
var save_path := "user://shinrai_visual_qa_%d.json" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = save_path
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 90000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		print("VISUAL_RESULT: FAIL park did not reach operations")
		quit(1)
		return
	await capture("hq")
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		print("VISUAL_RESULT: FAIL deployment")
		quit(1)
		return
	raid.hud.update_raid(raid)
	await capture("gameplay")
	raid.pause_run(true)
	await capture("map")
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(save_path + suffix)
	print("VISUAL_RESULT: PASS captured operations, gameplay HUD, and field map")
	quit(0)

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://extraction_qa")
	var file := "user://extraction_qa/review_" + label + ".png"
	var error := root.get_texture().get_image().save_png(file)
	print("VISUAL_CAPTURE: ", label, " error=", error, " path=", ProjectSettings.globalize_path(file))
