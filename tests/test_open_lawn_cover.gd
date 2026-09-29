extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_open_cover_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		push_error("Open cover QA: scene did not reach HQ")
		quit(1)
		return
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		push_error("Open cover QA: raid did not start")
		quit(1)
		return
	var cover := raid.park.find_child("OpenBoulder_03", true, false) as Node3D
	if cover == null:
		push_error("Open cover QA: center boulder missing")
		quit(1)
		return
	var point := cover.global_position
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 5.0,
		point + Vector3.DOWN * 1.0,
		1
	)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node3D
	if collider == null or collider.get_parent() != cover:
		push_error("Open cover QA: center boulder has no aligned collision")
		quit(1)
		return
	raid.player.global_position = point + Vector3(8.0, 0.2, 11.0)
	raid.player.velocity = Vector3.ZERO
	raid.player.look_at(Vector3(point.x, raid.player.global_position.y, point.z))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	var fps_sum := 0.0
	var fps_min := 10000.0
	var fps_count := 0
	for frame: int in range(420):
		await process_frame
		if frame >= 120 and frame % 60 == 0:
			var fps := Engine.get_frames_per_second()
			fps_sum += fps
			fps_min = minf(fps_min, fps)
			fps_count += 1
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://extraction_qa")
	root.get_texture().get_image().save_png("user://extraction_qa/open_lawn_cover.png")
	print("OPEN_COVER_RESULT: collision aligned at %s" % point)
	print("OPEN_COVER_FPS: mean=%.1f min=%.1f samples=%d" % [fps_sum / float(fps_count), fps_min, fps_count])
	quit()
