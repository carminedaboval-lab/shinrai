extends SceneTree
## Cinematic capture for the Shinrai showcase trailer.
##
## Boots the live extraction scene on an isolated profile, starts a raid,
## hides the HUD and flies a free camera through authored shots. Every shot
## writes a midpoint still to user://trailer/stills/ (AI image-to-video seeds)
## and its drawn-frame range to user://trailer/shots_<day|night>.json so the
## AVI written by --write-movie can be cut into clips afterwards.
##
## Stills only (fast framing check):
##   godot --path . --script res://tests/trailer_capture.gd [-- --night]
## Full frame dump for clips (1080p JPEG per frame, assembled by trailer/cut_trailer_shots.py):
##   godot --path . --script res://tests/trailer_capture.gd --fixed-fps 30 -- --frames [--night]
## Godot's own --write-movie records the OS window, which this project overrides
## to 1280x720 regardless of --resolution, so the frame dump is the 1080p path.

const FPS := 30.0
const STILL_DIR := "user://trailer/stills"
const FRAME_DIR := "user://trailer/frames"
const FRAME_QUALITY := 0.93

## pos/look: Vector3 start and end. Interpolated with smoothstep over seconds.
## kind "track_drone" orbits the police drone nearest to "anchor" instead.
## Landmark positions are world metres. The blockout's authored list is in
## concept metres at half scale (torii 82,68 -> world 164,136).
const DAY_SHOTS: Array[Dictionary] = [
	{"name":"d01_aerial_establish","seconds":9.0,"fov":52.0,
		"pos":[Vector3(-30,42,240),Vector3(-10,34,196)],"look":[Vector3(20,0,110),Vector3(30,2,60)]},
	{"name":"d02_south_gate_push","seconds":7.0,"fov":60.0,
		"pos":[Vector3(-8,1.9,172),Vector3(-8,1.8,138)],"look":[Vector3(-6,2.2,110),Vector3(-4,2.4,60)]},
	{"name":"d03_torii_plaza","seconds":7.0,"fov":55.0,
		"pos":[Vector3(122,2.6,170),Vector3(144,2.0,154)],"look":[Vector3(164,4.5,136),Vector3(164,4.0,136)]},
	{"name":"d04_lake_edge","seconds":7.0,"fov":55.0,
		"pos":[Vector3(18,1.8,-26),Vector3(30,2.2,-24)],"look":[Vector3(80,2.0,-26),Vector3(80,3.0,-30)]},
	{"name":"d05_sakura_grove","seconds":7.0,"fov":58.0,
		"pos":[Vector3(-166,1.6,-42),Vector3(-150,1.8,-32)],"look":[Vector3(-130,3.0,-24),Vector3(-128,4.0,-20)]},
	{"name":"d06_drone_patrol","seconds":8.0,"fov":55.0,"kind":"track_drone","anchor":Vector3(0,0,0),
		"pos":[Vector3(-2,1.6,26),Vector3(-2,1.6,14)],"look":[Vector3(-2,1.2,10),Vector3(-2,1.2,0)]},
	{"name":"d07_cover_lattice","seconds":6.0,"fov":62.0,
		"pos":[Vector3(-70,1.6,108),Vector3(-58,1.5,100)],"look":[Vector3(-42,1.2,90),Vector3(-36,1.2,84)]},
	{"name":"d08_playground_pan","seconds":6.0,"fov":55.0,
		"pos":[Vector3(-112,2.0,124),Vector3(-124,2.0,116)],"look":[Vector3(-144,1.5,90),Vector3(-154,1.5,86)]},
	{"name":"d09_pavilion_east","seconds":6.0,"fov":55.0,
		"pos":[Vector3(120,2.2,-112),Vector3(136,2.0,-124)],"look":[Vector3(152,2.5,-146),Vector3(152,2.5,-146)]},
]

const NIGHT_SHOTS: Array[Dictionary] = [
	{"name":"n01_gate_smashed","seconds":8.0,"fov":60.0,
		"pos":[Vector3(2,1.7,204),Vector3(0.5,1.6,174)],"look":[Vector3(0,2.0,140),Vector3(0,2.0,100)]},
	{"name":"n02_torii_neon","seconds":7.0,"fov":52.0,
		"pos":[Vector3(150,1.8,174),Vector3(160,1.8,158)],"look":[Vector3(164,4.5,136),Vector3(164,4.0,136)]},
	{"name":"n03_fireflies_grove","seconds":7.0,"fov":58.0,
		"pos":[Vector3(-152,1.4,-32),Vector3(-140,1.4,-26)],"look":[Vector3(-120,2.5,-20),Vector3(-118,2.0,-18)]},
	{"name":"n04_drone_patrol","seconds":8.0,"fov":55.0,"kind":"track_drone","anchor":Vector3(0,0,0),
		"pos":[Vector3(-2,1.6,26),Vector3(-2,1.6,14)],"look":[Vector3(-2,1.2,10),Vector3(-2,1.2,0)]},
	{"name":"n05_lake_lamps","seconds":7.0,"fov":55.0,
		"pos":[Vector3(18,1.8,-26),Vector3(26,2.0,-24)],"look":[Vector3(80,2.0,-26),Vector3(80,2.5,-30)]},
	{"name":"n06_west_gate_exfil","seconds":7.0,"fov":58.0,
		"pos":[Vector3(-178,2.0,40),Vector3(-198,1.8,40)],"look":[Vector3(-215,2.0,40),Vector3(-225,2.0,40)]},
	{"name":"n07_aerial_city_glow","seconds":9.0,"fov":52.0,
		"pos":[Vector3(-40,40,236),Vector3(-20,32,196)],"look":[Vector3(20,0,110),Vector3(30,6,60)]},
	{"name":"n08_billboard_street","seconds":7.0,"fov":50.0,
		"pos":[Vector3(-6,1.7,150),Vector3(-2,1.8,166)],"look":[Vector3(0,8.0,230),Vector3(0,9.0,230)]},
]

var night := false
var dump_frames := false
var only_shots: PackedStringArray = []
var camera: Camera3D
var shots_record: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	night = "--night" in args
	dump_frames = "--frames" in args
	for arg: String in args:
		# --only=d01_aerial_establish,d03_torii_plaza re-renders a subset.
		if arg.begins_with("--only="):
			only_shots = arg.trim_prefix("--only=").split(",", false)
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_trailer_qa.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		push_error("Trailer capture: scene did not reach HQ")
		quit(1)
		return
	if night:
		raid.night_deployment = true
		scene.is_night_mode = true
		scene._apply_time_of_day()
	await raid.start_run()
	deadline = Time.get_ticks_msec() + 60000
	while raid.phase != raid.Phase.RAID and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.RAID:
		push_error("Trailer capture: raid did not start")
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Park the player outside the fence line so patrols have nothing to chase,
	# and keep the HUD and view model out of every frame.
	raid.player.process_mode = Node.PROCESS_MODE_DISABLED
	raid.player.global_position = Vector3(150, 0.2, 196)
	raid.player.velocity = Vector3.ZERO
	if raid.hud != null:
		raid.hud.hide()
	for layer: Node in raid.player.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	for layer: Node in scene.find_children("*", "CanvasLayer", false, false):
		layer.hide()
	camera = Camera3D.new()
	camera.name = "TrailerCamera"
	camera.near = 0.1
	camera.far = 2500.0
	scene.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(STILL_DIR)
	# Let patrols, wildlife and the lighting settle before the first cut.
	for _frame: int in range(90):
		await process_frame
	var shots: Array[Dictionary] = NIGHT_SHOTS if night else DAY_SHOTS
	for shot: Dictionary in shots:
		if not only_shots.is_empty() and not only_shots.has(shot["name"]):
			continue
		await play_shot(shot)
	var record_path := "user://trailer/shots_%s.json" % ("night" if night else "day")
	var file := FileAccess.open(record_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "shots": shots_record}, "\t"))
	file.close()
	print("TRAILER_CAPTURE: done, %d shots -> %s" % [shots.size(), record_path])
	quit()

func play_shot(shot: Dictionary) -> void:
	var seconds: float = shot["seconds"]
	var frames := int(round(seconds * FPS))
	camera.fov = shot.get("fov", 55.0)
	var kind: String = shot.get("kind", "dolly")
	var drone: Node3D = null
	if kind == "track_drone":
		drone = _nearest_drone(shot["anchor"])
		if drone == null:
			push_warning("Trailer capture: no police drone for %s, using dolly" % shot["name"])
	var start_frame := Engine.get_frames_drawn()
	var still_saved := false
	var frame_dir := "%s/%s" % [FRAME_DIR, shot["name"]]
	if dump_frames:
		DirAccess.make_dir_recursive_absolute(frame_dir)
	for frame: int in range(frames):
		var t := float(frame) / float(maxi(frames - 1, 1))
		var eased := t * t * (3.0 - 2.0 * t)
		if drone != null and is_instance_valid(drone):
			var target: Vector3 = drone.global_position + Vector3(0, 1.2, 0)
			var angle := deg_to_rad(-40.0 + 80.0 * eased)
			var offset := Vector3(sin(angle), 0.0, cos(angle)) * 7.0 + Vector3(0, 2.4, 0)
			camera.global_position = target + offset
			camera.look_at(target, Vector3.UP)
		else:
			var p0: Vector3 = shot["pos"][0]
			var p1: Vector3 = shot["pos"][1]
			var l0: Vector3 = shot["look"][0]
			var l1: Vector3 = shot["look"][1]
			camera.global_position = p0.lerp(p1, eased)
			camera.look_at(l0.lerp(l1, eased), Vector3.UP)
		await process_frame
		if dump_frames:
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_jpg("%s/%05d.jpg" % [frame_dir, frame], FRAME_QUALITY)
			if not still_saved and frame >= frames / 2:
				image.save_png("%s/%s.png" % [STILL_DIR, shot["name"]])
				still_saved = true
		elif not still_saved and frame >= frames / 2:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s.png" % [STILL_DIR, shot["name"]])
			still_saved = true
	var end_frame := Engine.get_frames_drawn()
	shots_record.append({"name": shot["name"], "start_frame": start_frame, "end_frame": end_frame, "seconds": seconds})
	print("TRAILER_SHOT: %s frames %d-%d" % [shot["name"], start_frame, end_frame])

func _nearest_drone(anchor: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node: Node in get_nodes_in_group("police_spider_drones"):
		if not (node is Node3D) or not node.is_inside_tree():
			continue
		var distance: float = (node as Node3D).global_position.distance_to(anchor)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best
