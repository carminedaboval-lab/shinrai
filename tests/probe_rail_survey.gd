extends "res://tests/probe_shader_warmup.gd"

# Survey for the ring-road rail line (investigation probe): ground heights across the ring road on
# each side of the park, anything standing in a tram-sized corridor along the loop, and four
# reference pictures. Boots the park like the warm-up probe, then stops at the HQ menu.
#   godot --path . --fixed-fps 60 --script res://tests/probe_rail_survey.gd -- --out=<folder>

const RailTrack := preload("res://scripts/shinrai_rail_track.gd")

func _run() -> void:
	var out := "user://rail_survey"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	Warmup.suppressed = true
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	root.disable_3d = true
	var scene := load(WORLD) as PackedScene
	var park := scene.instantiate() as Node3D
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
		if raid != null and int(raid.get("phase")) != 0: break
		await process_frame
	for i: int in 30: await physics_frame
	var space := park.get_world_3d().direct_space_state
	# Ground profile across the road on each side.
	for cut: Array in [["north", Vector3(70, 0, -174), Vector3(0, 0, -1)], ["south", Vector3(0, 0, 174), Vector3(0, 0, 1)],
			["east", Vector3(214, 0, 0), Vector3(1, 0, 0)], ["west", Vector3(-214, 0, 40), Vector3(-1, 0, 0)]]:
		var line := ""
		for step: int in 36:
			var at: Vector3 = cut[1] + cut[2] * float(step)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 5.0))
			line += "%d:%s " % [step, ("%.2f" % hit.position.y) if not hit.is_empty() else "none"]
		print("RAIL_SURVEY profile %s %s" % [cut[0], line])
	# Anything inside a tram-sized corridor (2.8 m wide, 0.4 to 3.6 m up) along the loop.
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 3.2, 4.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	var seen := {}
	var s := 0.0
	var total := RailTrack.length()
	while s < total:
		var frame := RailTrack.frame_at(s)
		query.transform = Transform3D(frame.basis, frame.origin + Vector3.UP * 2.0)
		for hit: Dictionary in space.intersect_shape(query, 8):
			var node := hit.collider as Node
			var key := str(node.get_path()) if node != null else "?"
			if not seen.has(key): seen[key] = snappedf(s, 1.0)
		s += 4.0
	print("RAIL_SURVEY loop_length %.1f blockers %s" % [total, JSON.stringify(seen)])
	# Pictures.
	root.disable_3d = false
	var hud := raid.get("hud") as CanvasLayer
	if hud != null: hud.visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 900.0
	park.add_child(camera)
	camera.make_current()
	var shots := [["north_east", Vector3(-40, 1.6, -187), Vector3(60, 1.4, -186)], ["east_south", Vector3(227, 1.6, -60), Vector3(226, 1.4, 40)],
		["south_west", Vector3(60, 1.6, 187), Vector3(-40, 1.4, 186)], ["north_above", Vector3(70, 26, -160), Vector3(70, 0, -192)],
		["corner_ne", Vector3(200, 9, -160), Vector3(226, 0, -186)]]
	for shot: Array in shots:
		camera.look_at_from_position(shot[1], shot[2])
		for i: int in 40: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		print("RAIL_SURVEY shot ", shot[0])
	quit(0)
