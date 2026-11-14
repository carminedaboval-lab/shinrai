extends SceneTree
## Fixed-camera pictures of the Map 1 blockout, for judging the layout:
##   godot --path . --resolution 1600x900 --fixed-fps 60 --script res://tests/map1_blockout_capture.gd
##   ... -- --out=reports/map1 --views=aerial_south,avenue
## Writes <view>.jpg per view. No player, no mouse capture.

const Blockout := preload("res://scripts/map1/map1_blockout.gd")

## name, camera position, look-at point, field of view. A camera below 100 m is given as a
## height above the ground under it, and so is the point it looks at.
const VIEWS: Array = [
	["aerial_south", Vector3(-120, 1150, 2300), Vector3(-120, 0, -200), 50.0],
	["aerial_east", Vector3(2500, 900, -200), Vector3(-100, 0, -250), 50.0],
	["aerial_city", Vector3(250, 520, 900), Vector3(120, 0, -150), 55.0],
	["avenue", Vector3(0, 1.6, -424), Vector3(0, 1.6, 0), 75.0],
	["town_square", Vector3(-150, 46, -236), Vector3(-66, 0, -310), 60.0],
	["small_park", Vector3(290, 40, 500), Vector3(364, 0, 412), 60.0],
	["aerial_homes", Vector3(120, 210, 640), Vector3(140, 0, 380), 55.0],
	["aerial_nightlife", Vector3(760, 240, 220), Vector3(480, 0, -160), 55.0],
	["stream", Vector3(300, 30, 330), Vector3(430, 0, 338), 62.0],
	["shop_street", Vector3(-120, 1.6, -300), Vector3(120, 4, -300), 75.0],
	["nightlife", Vector3(310, 1.6, -100), Vector3(700, 8, -104), 75.0],
	["old_town", Vector3(430, 1.6, -480), Vector3(600, 30, -560), 75.0],
	["housing", Vector3(-250, 1.6, -180), Vector3(-420, 14, -220), 75.0],
	["valley", Vector3(-1085, 1.6, -30), Vector3(0, 60, 80), 75.0],
	["port", Vector3(180, 1.6, 870), Vector3(770, 90, 750), 75.0],
	["expressway", Vector3(838, 11.2, -300), Vector3(300, 0, 100), 75.0],
	["airport", Vector3(-250, 1.6, -1180), Vector3(60, 24, -1300), 75.0],
	["dam", Vector3(-968, 1.7, -1090), Vector3(-985, 46, -1262), 75.0],
	["dam_crest", Vector3(-1076, 5.5, -1262), Vector3(-889, 0.5, -1262), 75.0],
	["aerial_dam", Vector3(-760, 330, -820), Vector3(-985, 40, -1240), 55.0],
	["hill_foot", Vector3(452, 1.7, -322), Vector3(566, 14, -512), 70.0],
	["hill_top", Vector3(560, 1.7, -488), Vector3(0, -24, -100), 75.0],
	["aerial_hill", Vector3(330, 230, -250), Vector3(592, 10, -524), 55.0],
	["saddle", Vector3(-690, 1.7, 40), Vector3(-900, 4, 30), 75.0],
	["aerial_valley", Vector3(-760, 300, 420), Vector3(-1040, 0, -60), 60.0],
	["village", Vector3(-1040, 1.7, -60), Vector3(-1090, 8, -20), 75.0],
	["aerial_airport", Vector3(120, 430, -820), Vector3(90, 0, -1290), 60.0],
	["aerial_plaza", Vector3(60, 300, -330), Vector3(40, 0, -585), 55.0],
	["aerial_depot", Vector3(-300, 240, -360), Vector3(-320, 0, -580), 55.0],
	["aerial_approach", Vector3(200, 420, -560), Vector3(150, 0, -900), 60.0],
	["cove_stadium", Vector3(-150, 150, 900), Vector3(-450, 0, 650), 55.0],
	["cove_ridge", Vector3(-800, 1.7, -340), Vector3(-790, 2, -300), 75.0],
	["junction", Vector3(-20, 14, 232), Vector3(0, 0, 189), 70.0],
	["stalled_vehicles", Vector3(300, 1.7, -640), Vector3(300, 1.7, 200), 70.0],
	["east_farm", Vector3(760, 26, -930), Vector3(815, 0, -975), 60.0],
	["turning_circle", Vector3(186, 34, 486), Vector3(155, 0, 448), 55.0],
	["turning_circle_street", Vector3(118, 1.7, 448), Vector3(155, 2, 448), 70.0],
	["station_tram_stop", Vector3(-279, 2.6, -291), Vector3(-294, 1.4, -300), 60.0],
	["recharge_station", Vector3(-144.5, 2.4, -412.0), Vector3(-145.8, 1.4, -401.0), 60.0],
	["recharge_street", Vector3(-160.0, 1.7, -418.0), Vector3(-145.8, 1.6, -402.1), 60.0],
	["stadium", Vector3(-215, 1.6, 420), Vector3(-450, 20, 620), 75.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var out := "reports/map1"
	var only: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		elif arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out))
	var map := Blockout.new()
	map.name = "Map1Blockout"
	map.with_player = false
	root.add_child(map)
	for label: Label3D in map.labels: label.visible = false
	var camera := Camera3D.new()
	camera.far = 20000.0
	root.add_child(camera)
	camera.make_current()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i: int in 12: await process_frame
	var frames_ms: Array[float] = []
	for view: Array in VIEWS:
		if not only.is_empty() and not only.has(str(view[0])): continue
		var eye: Vector3 = view[1]
		var target: Vector3 = view[2]
		if eye.y < 100.0:
			eye.y += map.ground_height(eye.x, eye.z)
			target.y += map.ground_height(target.x, target.z)
		camera.global_position = eye
		camera.look_at(target)
		camera.fov = view[3]
		# Labels help from the air and clutter the street views.
		for label: Label3D in map.labels: label.visible = false
		for i: int in 10: await process_frame
		var clock := Time.get_ticks_usec()
		for i: int in 20: await process_frame
		frames_ms.append(snappedf((Time.get_ticks_usec() - clock) / 20000.0, 0.1))
		var image := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://%s/%s.jpg" % [out, view[0]])
		image.save_jpg(path, 0.9)
		print("MAP1_CAPTURE ", path)
	# Is the ground you walk on where the ground you see is? Drop rays all over the map; a ray
	# that lands on a roof is ignored, one that lands below the drawn ground or on nothing is not.
	var space := root.get_world_3d().direct_space_state
	var missed := 0
	var wrong := 0
	var tried := 0
	for gx: int in 40:
		for gz: int in 48:
			var spot := Vector2(-1140.0 + gx * 52.3, -1480.0 + gz * 50.7)
			var drawn := map.ground_height(spot.x, spot.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(spot.x, 400, spot.y), Vector3(spot.x, -50, spot.y)))
			tried += 1
			if hit.is_empty():
				missed += 1
				if missed <= 6: print("MAP1_GROUND nothing solid at x=%.1f z=%.1f (drawn %.2f)" % [spot.x, spot.y, drawn])
			elif hit.position.y < drawn - 0.15:
				wrong += 1
				if wrong <= 6: print("MAP1_GROUND solid %.2f below drawn %.2f at x=%.1f z=%.1f" % [hit.position.y, drawn, spot.x, spot.y])
	print("MAP1_GROUND rays=%d nothing=%d below=%d" % [tried, missed, wrong])
	print("MAP1_RENDER_MS cpu=%.2f gpu=%.2f" % [RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())])
	print("MAP1_FRAME_MS ", frames_ms)
	print("MAP1_CAPTURE_DONE build=", JSON.stringify(map.report), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " static_mem_mb=", int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	quit(0)
