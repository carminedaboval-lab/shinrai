extends "res://tests/probe_shader_warmup.gd"

# Finds shimmer (edges and fine patterns that flicker as the view moves) around the map.
# For each view the camera is nudged by fractions of a pixel with time frozen; anything stable
# barely changes, anything aliased flips. Saves the picture and a heat map (white = flickers),
# and prints a score per view. Uses the game's own smoothing setting unless --aa is given.
#   godot --path . --script res://tests/probe_shimmer.gd -- --out=<folder> [--aa=taa|off|msaa2|msaa4|msaa8] [--only=view,view]
# Uses a QA profile, never the player's save.

const VIEWS := [
	["fence_north", Vector3(-40, 1.6, -187), Vector3(60, 1.4, -186)],
	["fence_east", Vector3(227, 1.6, -60), Vector3(226, 1.4, 40)],
	["south_street", Vector3(60, 1.6, 187), Vector3(-40, 1.4, 186)],
	["shop_street", Vector3(70, 1.6, -201.5), Vector3(120, 1.4, -203.5)],
	["corner_city", Vector3(200, 9, -160), Vector3(226, 0, -186)],
	["park_trees", Vector3(-100, 1.7, -100), Vector3(-150, 4.0, -150)],
	["park_lake", Vector3(0, 1.7, 70), Vector3(60, 1.5, -20)],
	["park_paths", Vector3(0, 1.7, 0), Vector3(-80, 1.5, -60)],
	["south_gate", Vector3(0, 1.7, 150), Vector3(0, 1.7, 200)],
	["west_gate", Vector3(-190, 1.7, 40), Vector3(-240, 1.7, 40)],
	["park_from_above", Vector3(0, 40, -170), Vector3(0, 0, 0)],
	["east_lawn", Vector3(120, 1.7, 60), Vector3(200, 1.5, 0)],
	["rail_close", Vector3(-38, 1.5, -195.0), Vector3(-30, 0.8, -196.6)]]

const NUDGES := [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5), Vector2(0.25, 0.75)]


func _run() -> void:
	var out := "user://shimmer"
	var aa := ""
	var only: PackedStringArray = []
	var filter := ""
	var coverage := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--aa="): aa = arg.trim_prefix("--aa=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
		if arg.begins_with("--filter="): filter = arg.trim_prefix("--filter=")
		if arg == "--a2c": coverage = true
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if not aa.is_empty():
		root.set_meta(&"shinrai_aa_external", true)
		var hold := func() -> void:
			var msaa: int = {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X, "msaa8": Viewport.MSAA_8X}.get(aa, Viewport.MSAA_DISABLED)
			if root.msaa_3d != msaa: root.msaa_3d = msaa
			if root.use_taa != (aa == "taa"): root.use_taa = aa == "taa"
		hold.call()
		process_frame.connect(hold)
	Warmup.suppressed = true
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	root.disable_3d = true
	Engine.max_fps = 120
	var park := (load(WORLD) as PackedScene).instantiate() as Node3D
	park.set("profile_path", PROFILE)
	preload("res://scripts/creator/creator_game_integration.gd").prepare_world(park, LAYOUT)
	park.set_meta("shinrai_incremental_loading", true)
	park.set_meta("shinrai_structure_pending", true)
	root.add_child(park)
	while is_instance_valid(park) and park.get_meta("shinrai_structure_pending", false):
		await process_frame
	current_scene = park
	var raid: Node = null
	var deadline := Time.get_ticks_msec() + 900000
	while Time.get_ticks_msec() < deadline:
		raid = park.get_node_or_null("ExtractionRun")
		if raid != null and int(raid.get("phase")) == 1 and raid.world_ready(): break
		await process_frame
	var hud := raid.get("hud") as CanvasLayer
	if hud != null: hud.visible = false
	root.disable_3d = false
	if not filter.is_empty():
		var wanted: int = {"fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}.get(filter, Viewport.SCREEN_SPACE_AA_DISABLED)
		process_frame.connect(func() -> void:
			if root.screen_space_aa != wanted: root.screen_space_aa = wanted)
	if coverage:
		# Experiment: alpha-to-coverage on every cut-out standard material in the park.
		var seen := {}
		for node: Node in park.find_children("*", "GeometryInstance3D", true, false):
			var materials: Array = []
			var geometry := node as GeometryInstance3D
			materials.append(geometry.material_override)
			if node is MeshInstance3D and node.mesh != null:
				for surface: int in node.mesh.get_surface_count():
					materials.append(node.get_surface_override_material(surface))
					materials.append(node.mesh.surface_get_material(surface))
			elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
				for surface: int in node.multimesh.mesh.get_surface_count():
					materials.append(node.multimesh.mesh.surface_get_material(surface))
			for material: Variant in materials:
				if material is BaseMaterial3D and not seen.has(material) and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					seen[material] = true
					material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		print("SHIMMER a2c materials=%d" % seen.size())
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	print("SHIMMER settings msaa=%d taa=%s scale=%.2f size=%s" % [root.msaa_3d, root.use_taa, root.scaling_3d_scale, root.size])
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 900.0
	park.add_child(camera)
	camera.make_current()
	var size := root.size
	var pixel := deg_to_rad(camera.fov) / float(size.y)
	for view: Array in VIEWS:
		if not only.is_empty() and not only.has(view[0]): continue
		camera.look_at_from_position(view[1], view[2])
		Engine.time_scale = 1.0
		for i: int in 90: await process_frame
		var gpu := 0.0
		for i: int in 30:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		print("SHIMMER view=%s gpu_ms=%.2f" % [view[0], gpu / 30.0])
		# Freeze wind, water and anything else that moves by itself.
		Engine.time_scale = 0.0
		var base := camera.global_transform
		var low := PackedByteArray()
		var high := PackedByteArray()
		for index: int in NUDGES.size():
			var nudge: Vector2 = NUDGES[index]
			camera.global_transform = base
			camera.rotate_object_local(Vector3.UP, nudge.x * pixel)
			camera.rotate_object_local(Vector3.RIGHT, nudge.y * pixel)
			for i: int in (12 if root.use_taa else 3): await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if index == 0: image.save_png("%s/%s.png" % [out, view[0]])
			image.convert(Image.FORMAT_L8)
			var data := image.get_data()
			if index == 0:
				low = data.duplicate()
				high = data.duplicate()
			else:
				for at: int in data.size():
					var value := data[at]
					if value < low[at]: low[at] = value
					elif value > high[at]: high[at] = value
		camera.global_transform = base
		var total := 0
		var hot := 0
		var heat := PackedByteArray()
		heat.resize(low.size())
		for at: int in low.size():
			var spread := high[at] - low[at]
			total += spread
			if spread > 24: hot += 1
			heat[at] = mini(255, spread * 4)
		Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, heat).save_png("%s/%s_heat.png" % [out, view[0]])
		print("SHIMMER view=%s mean=%.2f hot_pct=%.2f" % [view[0], float(total) / float(low.size()), 100.0 * float(hot) / float(low.size())])
	Engine.time_scale = 1.0
	print("SHIMMER done")
	quit(0)
