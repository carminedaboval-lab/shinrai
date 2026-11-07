extends SceneTree
## Close-ups of single cherries: around the trunk, looking up into the crown,
## and tight on a limb, to see how blossom grows from the branches.
var scene: Node3D

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i: int in range(n): await process_frame

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_perf_probe.json"
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var started := Time.get_ticks_msec()
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() - started < 900000: await process_frame
	while not scene.has_meta("midori_biomes") and Time.get_ticks_msec() - started < 1200000: await process_frame
	raid.hud.hide()
	if raid.get("player") != null and is_instance_valid(raid.player): raid.player.visible = false
	await frames(60)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 60
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("user://tree_closeup")
	var terrain: Node = scene.get_node("MidoriTerrain")
	var trees := [Vector2(83.0, 124.4)]
	# Also the cherry nearest the west camera's centre tree.
	var best := Vector2.ZERO
	var best_d := INF
	for n: Node in scene.find_children("BiomeSakuraContent", "Node3D", true, false):
		var p := Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
		var d := p.distance_to(Vector2(-25, 128))
		if d < best_d and (n as Node3D).is_visible_in_tree():
			best_d = d
			best = p
	if best_d < 40.0: trees.append(best)
	var idx := 0
	for c: Vector2 in trees:
		var g: float = terrain.height_at(c)
		var shots := [
			["side_s", Vector3(c.x, g + 1.7, c.y + 7.0), Vector3(c.x, g + 4.0, c.y)],
			["side_e", Vector3(c.x + 7.0, g + 1.7, c.y), Vector3(c.x, g + 4.0, c.y)],
			["under", Vector3(c.x + 1.8, g + 1.6, c.y + 1.2), Vector3(c.x - 1.0, g + 7.5, c.y - 1.5)],
			["limb", Vector3(c.x + 3.0, g + 3.4, c.y + 2.0), Vector3(c.x + 0.5, g + 4.6, c.y)],
			["crown_edge", Vector3(c.x - 4.5, g + 4.6, c.y + 3.5), Vector3(c.x - 5.5, g + 5.2, c.y - 1.0)],
		]
		for s: Array in shots:
			camera.global_position = s[1]
			camera.look_at(s[2])
			await frames(45)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://tree_closeup/t%d_%s.png" % [idx, s[0]])
		idx += 1
	print("CLOSEUP_DONE trees=", trees)
	quit()
