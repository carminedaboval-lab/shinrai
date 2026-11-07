extends "./biome_capture.gd"
## Measure the same live HQ and cameras before and after a single real biome installation.

var capture_camera: Camera3D
var poses := {}

func aim(name: String, terrain: Node) -> void:
	var view: Array = VIEWS[name]
	var eye: Vector3 = view[0]
	var target: Vector3 = view[1]
	eye.y = terrain.height_at(Vector2(eye.x, eye.z)) + 1.7
	target.y += terrain.height_at(Vector2(target.x, target.z))
	capture_camera.global_position = eye
	capture_camera.look_at(target)
	capture_camera.reset_physics_interpolation()

func capture_phase(out: String, names: Array, only: PackedStringArray, off: bool) -> String:
	var terrain := scene.get_node("MidoriTerrain")
	var meta: Dictionary = scene.get_meta("midori_biomes")
	var results := {}
	capture_camera.make_current()
	# Both phases enter from the same position, with identical exposure and streaming warm-up.
	aim(names[0], terrain)
	await frames(90)
	for name: String in names:
		aim(name, terrain)
		if off:
			poses[name] = capture_camera.global_transform
		elif not capture_camera.global_transform.is_equal_approx(poses[name]):
			return "Camera transform changed between OFF and ON for " + name
		var visible := await measure() # Inherited: 70 settled frames, three timed 40-frame windows.
		await RenderingServer.frame_post_draw
		if root.get_camera_3d() != capture_camera or not capture_camera.global_transform.is_equal_approx(poses[name]):
			return "Camera changed before capture for " + name
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != SIZE:
			return "Missing 1920x1080 viewport image for " + name
		var file := out.path_join(name + ".png")
		if FileAccess.file_exists(file) or image.save_png(file) != OK:
			return "Could not save fresh PNG at " + file
		var check := Image.new()
		if check.load_png_from_buffer(FileAccess.get_file_as_bytes(file)) != OK or check.get_size() != SIZE:
			return "Saved PNG failed validation: " + file
		results[name] = {"view": name, "width": image.get_width(), "height": image.get_height(), "png_saved": true, "visible": visible}
		print("CONTROL_SHOT " if off else "SHOT ", name, " steady_fps=", snappedf(1000.0 / visible.median_ms, 0.1))
	# Measure root-hidden views on a separate reverse sweep, so extra ON-only work does not
	# alter the order or warm-up of the comparable fully visible OFF/ON measurements.
	if not off:
		var reversed := names.duplicate()
		reversed.reverse()
		for name: String in reversed:
			for area: String in ROOTS:
				if not (name == area or name.begins_with(area + "_")) or not meta.has(area): continue
				aim(name, terrain)
				var area_root := scene.get_node(NodePath(ROOTS[area])) as Node3D
				if not area_root.visible: return "Expected visible area root for " + area
				area_root.visible = false
				results[name]["own_root_hidden"] = await measure()
				area_root.visible = true
				break
	for name: String in names:
		print("CONTROL_ROUND4 " if off else "ROUND4 ", JSON.stringify(results[name]))
	var record := {"off": off, "only": Array(only), "requested_views": names, "views": results,
			"paired": "same HQ instance; all visible views in identical order; 70 warm frames then 3 x 40; root-hidden reverse sweep"}
	var path := out.path_join("capture.json")
	if FileAccess.file_exists(path): return "Capture manifest already exists: " + path
	var manifest := FileAccess.open(path, FileAccess.WRITE)
	if manifest == null: return "Could not create capture manifest: " + path
	manifest.store_string(JSON.stringify(record, "\t"))
	manifest.flush()
	var error := manifest.get_error()
	manifest.close()
	return "" if error == OK else "Could not write capture manifest: " + path

func run() -> void:
	var out := OS.get_environment("ROUND4_CAPTURE_DIR")
	var control_dir := out.path_join("off")
	if not out.is_absolute_path() or DirAccess.dir_exists_absolute(control_dir) or DirAccess.make_dir_recursive_absolute(control_dir) != OK:
		fail("Expected a fresh capture directory with no off/ subdirectory")
		return
	var wanted := OS.get_environment("BIOME_VIEWS").split(",", false)
	var names: Array = []
	for name: String in VIEWS:
		if wanted.is_empty() or wanted.has(name): names.append(name)
	if not wanted.is_empty() and wanted.size() != names.size():
		fail("Unknown or duplicate camera in BIOME_VIEWS")
		return
	var requested := OS.get_environment("MIDORI_BIOMES_ONLY")
	var only := requested.split(",", false)
	OS.set_environment("MIDORI_BIOMES_ONLY", "")
	OS.set_environment("MIDORI_BIOMES_OFF", "1")
	root.size = SIZE
	root.content_scale_size = SIZE
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_perf_probe.json"
	root.add_child(scene)
	current_scene = scene
	var raid := scene.get_node("ExtractionRun")
	var started := Time.get_ticks_msec()
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() - started < 900000:
		await process_frame
	while not scene.has_meta("midori_biomes") and Time.get_ticks_msec() - started < 1200000:
		await process_frame
	if raid.phase != raid.Phase.HQ or not scene.has_meta("midori_biomes"):
		fail("Timed out waiting for disabled biomes and a fully booted HQ")
		return
	var meta: Dictionary = scene.get_meta("midori_biomes")
	var error := validation_error(meta, PackedStringArray(), true)
	if not error.is_empty():
		fail(error)
		return
	print("CONTROL_BIOMES_META ", JSON.stringify(meta))
	var boot_camera := root.get_camera_3d()
	raid.hud.hide()
	if is_instance_valid(raid.player): raid.player.visible = false
	capture_camera = Camera3D.new()
	capture_camera.fov = 70
	scene.add_child(capture_camera)
	error = await capture_phase(control_dir, names, PackedStringArray(), true)
	if not error.is_empty():
		fail(error)
		return
	print("PAIRED_CONTROL_DONE")
	if is_instance_valid(boot_camera): boot_camera.make_current()
	else: capture_camera.clear_current(false)
	OS.set_environment("MIDORI_BIOMES_ONLY", requested)
	OS.set_environment("MIDORI_BIOMES_OFF", "0")
	scene.remove_meta("midori_biomes")
	await BIOMES.install(scene)
	meta = scene.get_meta("midori_biomes", {})
	error = validation_error(meta, only, false)
	if not error.is_empty():
		fail(error)
		return
	print("BIOMES_META ", JSON.stringify(meta))
	error = await capture_phase(out, names, only, false)
	if not error.is_empty():
		fail(error)
		return
	print("BUILD_DONE")
	quit()
