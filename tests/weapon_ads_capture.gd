extends SceneTree
# In-game hip and aimed (ADS) views for each real-counterpart gun, taken through
# the live player camera in the park, irons only. Prints the aim time and zoom.
#   godot --path . --script res://tests/weapon_ads_capture.gd -- --out <dir> [--only key,key]
const ControllerInput = preload("res://scripts/shinrai_input.gd")
const GUNS :=["akane", "raiden_r56", "tobikage", "hayate", "yuzuru", "shigure", "kite"]
var out_dir := "user://ads_capture"
var only: Array = []
var want_ads := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		if args[i] == "--only" and i + 1 < args.size():
			only = Array(args[i + 1].split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func shot(label: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
	print("ADS_CAPTURE: ", path)

func run() -> void:
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	var scene: Node = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = out_dir.path_join("ads_profile.json")
	root.add_child(scene)
	current_scene = scene
	var raid: Node = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 180000
	while raid.phase != raid.Phase.HQ and Time.get_ticks_msec() < deadline:
		await process_frame
	await frames(30)
	print("ADS_PHASE before start: ", raid.phase)
	for attempt in 5:
		raid.start_run()
		await frames(30)
		if raid.phase == raid.Phase.RAID:
			break
	print("ADS_PHASE after start: ", raid.phase, " (RAID=", raid.Phase.RAID, ")")
	raid._clear_enemies()
	await frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Node = raid.player
	# A scripted window has no mouse focus, so the player drops aim each frame
	# (controller intents reset); hold the aim input the way a held button would.
	physics_frame.connect(func() -> void:
		if want_ads and is_instance_valid(player):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			ControllerInput._focused = true
			ControllerInput._release_required = false
			Input.action_press("sr_aim")
			player.ads = true
		else:
			Input.action_release("sr_aim"))
	# Look level along open ground so the sight picture is readable.
	player.rotation.y = 0.6
	if player.head != null:
		player.head.rotation.x = 0.0
	for id: String in GUNS:
		if not only.is_empty() and not only.has(id):
			continue
		var ok: bool = player.apply_weapon_loadout(id, {"optic": "", "ammo": 20, "reserve": 60, "chambered": true, "bolt_locked": false})
		if not ok:
			print("ADS_FAIL: could not equip ", id)
			continue
		await frames(150)
		player.ads = false
		await frames(40)
		await shot(id + "_hip")
		want_ads = true
		player.ads = true
		var t0 := Time.get_ticks_msec()
		var reached := -1.0
		for f in 200:
			await frames(1)
			if reached < 0.0 and player.ads_blend >= 0.999:
				reached = (Time.get_ticks_msec() - t0) / 1000.0
			if reached >= 0.0 and f > 40:
				break
		await shot(id + "_ads")
		var d: Dictionary = player.weapon_definition
		var hip_fov := 73.0
		var zoom := tan(deg_to_rad(hip_fov) * 0.5) / tan(deg_to_rad(float(d.ads_fov)) * 0.5)
		# Wall-clock aim time is only indicative under capture load; the catalogue
		# figure (1 / ads_speed) is the real one.
		print("ADS_STATS ", id, " ads_time=%.2f s (measured %.2f) ads_fov=%.1f zoom=%.2fx eye_relief=%.3f m" % [1.0 / float(d.ads_speed), reached, float(d.ads_fov), zoom, float(player.uzi_viewmodel.call("get_ads_eye_relief")) if player.uzi_viewmodel.has_method("get_ads_eye_relief") else -1.0])
		want_ads = false
		player.ads = false
		await frames(30)
	raid.finish_run(false, "ADS capture")
	quit(0)
