extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_park_quality_qa.json"
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 30000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		push_error("Park quality: scene did not reach HQ")
		quit(1)
		return
	raid.start_run()
	if raid.phase != raid.Phase.RAID:
		push_error("Park quality: scene did not start raid")
		quit(1)
		return
	var cover_point: Vector3 = raid.approach_cover.placements[0]
	raid.player.global_position = cover_point + Vector3(7.0, 0.2, 10.0)
	raid.player.velocity = Vector3.ZERO
	raid.player.look_at(Vector3(cover_point.x, raid.player.global_position.y, cover_point.z))
	if OS.get_cmdline_user_args().has("--ao-cost"):
		scene.park_environment.ssao_enabled = false
		await sample("high_no_ssao")
		scene.park_environment.ssao_enabled = true
		await sample("high_with_ssao")
		raid.park.high_render_quality = false
		raid.park._apply_render_quality()
		scene.park_environment.ssao_enabled = true
		await sample("balanced_with_ssao")
		scene.park_environment.ssao_enabled = false
		await sample("balanced_no_ssao")
		quit()
		return
	if OS.get_cmdline_user_args().has("--night-light-candidate"):
		scene.is_night_mode = true
		scene._apply_time_of_day()
		scene.park_environment.ambient_light_energy = 0.75
		scene.park_directional_light.light_energy = 0.45
		var ground_service: Node = root.get_node("MidoriGroundTexture")
		var ground_material := ground_service.get("_active_ground_material") as ShaderMaterial
		ground_material.set_shader_parameter("scene_light_factor", 0.60)
		await sample("night_light_candidate")
		quit()
		return
	if OS.get_cmdline_user_args().has("--night-preset"):
		scene.is_night_mode = true
		scene._apply_time_of_day()
		await sample("preset_night_high")
		raid.park.high_render_quality = false
		raid.park._apply_render_quality()
		await sample("preset_night_balanced")
		quit()
		return
	if OS.get_cmdline_user_args().has("--preset"):
		await sample("preset_high")
		raid.park.high_render_quality = false
		raid.park._apply_render_quality()
		await sample("preset_balanced")
		quit()
		return
	if OS.get_cmdline_user_args().has("--candidate"):
		root.msaa_3d = Viewport.MSAA_DISABLED
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		root.scaling_3d_scale = 0.75
		await sample("fsr75_taa_ssr")
		quit()
		return
	if OS.get_cmdline_user_args().has("--extra"):
		root.msaa_3d = Viewport.MSAA_DISABLED
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		root.scaling_3d_scale = 0.85
		raid.park.park_environment.ssr_enabled = false
		await sample("fsr85_taa_no_ssr")
		root.scaling_3d_scale = 0.80
		await sample("fsr80_taa_no_ssr")
		quit()
		return
	await sample("native_msaa_taa")
	root.msaa_3d = Viewport.MSAA_DISABLED
	await sample("native_taa")
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	root.scaling_3d_scale = 0.85
	await sample("fsr85_taa")
	quit()

func sample(label: String) -> void:
	var fps_sum := 0.0
	var fps_min := 10000.0
	var count := 0
	for frame: int in range(480):
		await process_frame
		if frame >= 120 and frame % 60 == 0:
			var fps: float = Engine.get_frames_per_second()
			fps_sum += fps
			fps_min = minf(fps_min, fps)
			count += 1
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://extraction_qa")
	root.get_texture().get_image().save_png("user://extraction_qa/park_quality_" + label + ".png")
	print("PARK_QUALITY: %s resolution=%s msaa=%d taa=%s scale=%.2f mean=%.1f min=%.1f samples=%d" % [label, root.size, root.msaa_3d, root.use_taa, root.scaling_3d_scale, fps_sum / float(count), fps_min, count])
