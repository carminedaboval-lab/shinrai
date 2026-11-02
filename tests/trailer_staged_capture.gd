extends SceneTree
## Staged first-person, HUD-plate and HQ-menu captures for the showcase trailer.
##
## Companion to trailer_capture.gd (free-camera dollies). This one keeps the real
## player, view model and HUD live and drives them with synthetic input so the
## mechanics the narration names (sprint weight, mantle-aim, lean, jump-ADS,
## doors, loot, extraction) are shown by the actual game, not by AI video.
##
##   godot --path . --script res://tests/trailer_staged_capture.gd --fixed-fps 30 -- --probe
##       prints landmark positions (doors, relays, exits, weapon cases) to
##       user://trailer/probe.json so shots can be authored against real geometry.
##   ... -- --hq            HQ menu stills + a short buy sequence (Field Ops, Loadout)
##   ... -- --plates        transparent 1080p HUD plates per narrated state
##   ... -- --shots [--night] [--only=a,b]   first-person staged shots as frame dumps
##   ... -- --frames        also dump every frame (otherwise midpoint stills only)
##
## Output mirrors trailer_capture.gd: user://trailer/stills, user://trailer/frames/<shot>,
## user://trailer/plates. trailer/cut_trailer_shots.py encodes the frame folders.

const FPS := 30.0
const STILL_DIR := "user://trailer/stills"
const FRAME_DIR := "user://trailer/frames"
const PLATE_DIR := "user://trailer/plates"
const FRAME_QUALITY := 0.93
const GameInput := preload("res://scripts/shinrai_input.gd")
const WeaponState := preload("res://scripts/extraction_weapon_state.gd")

## A staged shot is a list of steps run in order. Step keys:
##   teleport: Vector3   yaw: deg   pitch: deg      place the player (yaw 0 faces -Z)
##   hold: [actions]  seconds: float               hold sr_ actions while recording
##   press: [actions]                              one-frame press (jump, interact, fire)
##   look_to: {yaw, pitch} seconds                 ease the view over the step
##   wait: seconds                                  record with no input
##   record: bool (default true)                    false = settle without recording
## All steps after the first recorded one are part of the clip.
const DAY_SHOTS: Array[Dictionary] = [
	# 0:14 walking in through the open south gate with the HUD live.
	# Exit point is (0, 0.2, 167); start on the street side so the gate passes the camera.
	{"name":"s01_gate_walk_in","steps":[
		{"teleport":Vector3(-2,0.3,187),"yaw":0,"pitch":2,"record":false,"wait":0.6},
		{"hold":["move_forward"],"seconds":6.5}]},
	# 0:58 sprint across the torii plaza, hard stop against the planter row at (141, 147).
	{"name":"s02_sprint_stop","steps":[
		{"teleport":Vector3(124,0.3,165),"yaw":-43,"pitch":0,"record":false,"wait":0.6},
		{"hold":["move_forward","sprint"],"seconds":3.4},
		{"wait":1.6}]},
	# 1:02 mantle a planter with the weapon up, aim before the feet are down.
	# Probe: planter row top 1.15 m at (4.6..11.4, z 152.6), benches behind it.
	{"name":"s03_mantle_aim","steps":[
		{"teleport":Vector3(8,0.3,148.6),"yaw":180,"pitch":-6,"record":false,"wait":0.6},
		{"hold":["move_forward"],"seconds":0.8},
		{"press":["jump"],"hold":["move_forward","aim"],"seconds":1.6},
		{"hold":["aim"],"seconds":1.2},
		{"wait":0.6}]},
	# 1:05 lean out from behind the plaza bench toward the torii at (164, 136).
	{"name":"s04_corner_lean","steps":[
		{"teleport":Vector3(139.2,0.3,152.6),"yaw":-58,"pitch":0,"record":false,"wait":0.6},
		{"wait":0.5},
		{"hold":["lean_right","aim"],"seconds":1.8},
		{"hold":["aim"],"seconds":0.6},
		{"hold":["lean_left","aim"],"seconds":1.6},
		{"wait":0.5}]},
	# 1:18 jump, aim down sights in the air, land heavy.
	{"name":"s05_jump_ads","steps":[
		{"teleport":Vector3(-20,0.3,128),"yaw":90,"pitch":-2,"record":false,"wait":0.6},
		{"hold":["move_forward","sprint"],"seconds":1.2},
		{"press":["jump"],"hold":["move_forward","aim"],"seconds":1.3},
		{"wait":1.2}]},
	# 1:26 push a south-street shop door open and step inside.
	# Probe: PublicShopEntrance at (7.69, 0.19, 194.26), leaf faces -Z.
	{"name":"s06_door_push","steps":[
		{"teleport":Vector3(7.69,0.3,192.4),"yaw":180,"pitch":-2,"record":false,"wait":0.6},
		{"wait":0.6},
		{"press":["interact"],"seconds":1.4},
		{"hold":["move_forward"],"seconds":2.4},
		{"look_to":{"yaw_delta":35,"pitch":-6},"seconds":1.2}]},
	# 1:48 lead signals hold, relay 40 m out. Probe: south garden relay at (-152.5, 0.6, 148.5).
	{"name":"s07_relay_approach","steps":[
		{"teleport":Vector3(-110,0.3,150),"yaw":90,"pitch":0,"record":false,"wait":0.6,"relays":0},
		{"hold":["move_forward"],"seconds":3.0},
		{"hold":["crouch"],"seconds":0.3},
		{"wait":2.2}]},
	# 1:26b the clubhouse front door as the alternative interior.
	# Probe: FrontEntry at (-126, 0.36, -59.68); its +Z is the interior, so approach from -Z.
	{"name":"s06b_clubhouse_door","steps":[
		{"teleport":Vector3(-126,0.3,-62.9),"yaw":180,"pitch":-2,"record":false,"wait":0.6},
		{"hold":["move_forward"],"seconds":0.3},
		{"wait":0.5},
		{"press":["interact"],"seconds":1.4},
		{"hold":["move_forward"],"seconds":2.4},
		{"look_to":{"yaw_delta":-30,"pitch":-4},"seconds":1.2}]},
]

const NIGHT_SHOTS: Array[Dictionary] = [
	# 0:37 / 2:11 walking the west exfil path at night with extraction open.
	{"name":"s08_west_exfil_hud","steps":[
		{"teleport":Vector3(-180,0.3,40),"yaw":90,"pitch":1,"record":false,"wait":0.6,"relays":1},
		{"hold":["move_forward"],"seconds":5.0},
		{"wait":1.5}]},
	# 2:11 the south-garden drone group sweeping toward camera, relay just taken.
	# Probe: drones patrol around (-152, 0.5, 142).
	{"name":"s09_drone_searchlight","steps":[
		{"teleport":Vector3(-136,0.3,152),"yaw":110,"pitch":2,"record":false,"wait":0.6,"relays":1,"drones":true},
		{"hold":["crouch"],"seconds":0.3},
		{"look_to":{"yaw_delta":-35,"pitch":3},"seconds":4.5},
		{"wait":1.5}]},
]

## Combat and survival shots (--combat [--night]). Extra step keys:
##   weapon: "uzi"              grant and equip a weapon with a loaded magazine
##   face_group: "enemies"      stand `distance` m from the nearest live member of
##   anchor: Vector3            that group to `anchor`, facing it
##   hostiles: true/false       let scav crews and drone weapons run for this shot
##   damage: float              hit the player (thorax) at the start of the step
##   bursts: [on, off]          pulse sr_fire with that on/off pattern (seconds)
##   cache: Vector3             stand at the undiscovered cache nearest this point
const COMBAT_DAY: Array[Dictionary] = [
	# Opening contact: SMG bursts at the scav crew on the south street.
	{"name":"c01_scav_contact","steps":[
		{"weapon":"uzi","face_group":"enemies","anchor":Vector3(0,0,190),"distance":11.0,"yaw_offset":5.0,"hostiles":true,"record":false,"wait":0.8},
		{"hold":["aim"],"seconds":0.9},
		{"hold":["aim"],"bursts":[0.35,0.4],"seconds":3.6},
		{"hold":["aim"],"seconds":0.8},
		{"wait":0.6}]},
	# Run the magazine dry and reload while the crew keeps shooting.
	{"name":"c03_reload_under_fire","steps":[
		{"weapon":"uzi","face_group":"enemies","anchor":Vector3(0,0,190),"distance":18.0,"hostiles":true,"record":false,"wait":0.8},
		{"hold":["aim"],"bursts":[0.6,0.2],"seconds":3.0},
		{"press":["reload"],"seconds":2.6},
		{"hold":["aim"],"seconds":1.0}]},
	# Press-check the pistol on the plaza (the field-handling inspect).
	{"name":"c04_mag_check","steps":[
		{"teleport":Vector3(146,0.3,160),"yaw":-50,"pitch":-8,"record":false,"wait":0.6},
		{"wait":0.4},
		{"press":["mag_check"],"seconds":3.2},
		{"wait":0.8}]},
	# Search a bench cache: the loot panel opens on the real site.
	{"name":"c05_bench_search","steps":[
		{"cache":Vector3(150,0,160),"record":false,"wait":0.6},
		{"wait":0.5},
		{"hold":["interact"],"seconds":2.2},
		{"wait":2.6}]},
	# Take a hit, break contact, patch up. The wound is scripted so the take cannot
	# end in an elimination; the crew is frozen for it. Runs last for the same reason.
	{"name":"c02_hit_and_heal","steps":[
		{"weapon":"uzi","face_group":"enemies","anchor":Vector3(0,0,190),"distance":14.0,"hostiles":false,"record":false,"wait":0.8},
		{"hold":["aim"],"seconds":1.0},
		{"damage":60.0,"damage_part":"left_arm","hold":["aim"],"seconds":0.9},
		{"look_to":{"yaw_delta":150,"pitch":-6},"hold":["move_back"],"seconds":1.0},
		{"hold":["heal"],"seconds":3.6},
		{"wait":0.8}]},
]

const COMBAT_NIGHT: Array[Dictionary] = [
	# Firefight with the south-garden drone group under the lamps.
	{"name":"c06_drone_fight","steps":[
		{"weapon":"uzi","face_group":"police_spider_drones","anchor":Vector3(-152,0,144),"distance":15.0,"hostiles":true,"record":false,"wait":0.8},
		{"hold":["aim"],"seconds":0.8},
		{"hold":["aim"],"bursts":[0.4,0.3],"seconds":4.0},
		{"look_to":{"yaw_delta":-25,"pitch":2},"hold":["aim"],"seconds":1.2},
		{"wait":0.8}]},
	# Let the drones close in: identification beam, stun, face latch.
	{"name":"c07_drone_stun","steps":[
		{"face_group":"police_spider_drones","anchor":Vector3(-152,0,144),"distance":7.0,"hostiles":true,"record":false,"wait":0.4},
		{"wait":7.0}]},
]

## HUD plates: name, raid fields, optional extra line (trailer mock, not game UI).
const PLATES: Array[Dictionary] = [
	{"name":"p01_start_0of3","relays":0,"remaining":7200.0},
	{"name":"p02_relay_1of3","relays":1,"remaining":5280.0},
	{"name":"p03_extraction_bar","relays":1,"remaining":4310.0,"prompt":"Extracting · 9s","progress":0.4},
	{"name":"p04_next_train","relays":2,"remaining":2292.0,"extra":"NEXT TRAIN  01:47"},
	{"name":"p05_urgent","relays":2,"remaining":71.0},
	{"name":"p06_loot_prompt","relays":1,"remaining":5100.0,"prompt":"E  ·  Search shelf unit"},
	{"name":"p07_locked","relays":0,"remaining":6900.0,"prompt":"Extraction locked · recover a relay"},
]

var night := false
var dump_frames := false
var mode := ""
var only_shots: PackedStringArray = []
var scene: Node
var raid: Node
var player: CharacterBody3D
var shots_record: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	night = "--night" in args
	dump_frames = "--frames" in args
	for flag: String in ["--probe","--hq","--plates","--shots","--combat"]:
		if flag in args: mode = flag.trim_prefix("--")
	if mode.is_empty(): mode = "shots"
	for arg: String in args:
		if arg.begins_with("--only="):
			only_shots = arg.trim_prefix("--only=").split(",", false)
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = "user://shinrai_trailer_staged.json"
	DirAccess.remove_absolute(scene.profile_path)
	root.add_child(scene)
	current_scene = scene
	raid = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 300000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.HQ:
		push_error("Staged capture: scene did not reach HQ")
		quit(1)
		return
	for dir: String in [STILL_DIR, FRAME_DIR, PLATE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
	if night:
		raid.night_deployment = true
		scene.is_night_mode = true
		scene._apply_time_of_day()
	if mode == "hq":
		await capture_hq()
		quit()
		return
	await raid.start_run()
	deadline = Time.get_ticks_msec() + 60000
	while raid.phase != raid.Phase.RAID and Time.get_ticks_msec() < deadline:
		await process_frame
	if raid.phase != raid.Phase.RAID:
		push_error("Staged capture: raid did not start")
		quit(1)
		return
	player = raid.player
	# Synthetic input needs the same state a focused, captured window has.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	raid.run_time = 120.0 # past the insertion grace so its prompt never shows
	for _frame: int in range(90):
		await process_frame
	match mode:
		"probe": write_probe()
		"plates": await capture_plates()
		"shots": await capture_shots()
		"combat": await capture_shots(COMBAT_NIGHT if night else COMBAT_DAY, "combat")
	quit()

# ---------------------------------------------------------------- probe

func write_probe() -> void:
	var out := {"exits": raid.exits, "sites": [], "clubhouse_doors": [], "access_doors": [], "drones": []}
	for site: Dictionary in raid.sites:
		if site.kind == "relay" or String(site.id).begins_with("weapon"):
			out.sites.append({"id": site.id, "kind": site.kind, "position": _v(site.position)})
	if is_instance_valid(raid.clubhouse_doors):
		for door: Dictionary in raid.clubhouse_doors.doors:
			var frame: Node3D = door.frame
			out.clubhouse_doors.append({"id": door.id, "position": _v(frame.global_position),
				"forward": _v(-frame.global_basis.z), "yaw_deg": rad_to_deg(frame.global_rotation.y)})
	for node: Node in get_nodes_in_group("building_access_targets"):
		if node is Node3D and str(node.get_meta("building_access_kind","")) in ["door","sliding_door","gallery_sliding"]:
			var n := node as Node3D
			out.access_doors.append({"path": str(n.get_path()).get_file(), "kind": n.get_meta("building_access_kind"),
				"position": _v(n.global_position), "forward": _v(-n.global_basis.z), "yaw_deg": rad_to_deg(n.global_rotation.y)})
	for node: Node in get_nodes_in_group("police_spider_drones"):
		if node is Node3D: out.drones.append(_v((node as Node3D).global_position))
	# Mantle candidates: named cover geometry whose top sits in the mantle band.
	var mantle: Array = []
	var pattern := RegEx.create_from_string("(?i)planter|barrier|sandbag|jersey|lowwall|low_wall|parapet|cover|bollard_wall|retaining|hedge_wall|crate|container|bench")
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		if pattern.search(String(node.name)) == null or not node.is_visible_in_tree(): continue
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		var top := box.position.y + box.size.y
		if top < 0.6 or top > 1.7 or maxf(box.size.x, box.size.z) < 1.2 or mantle.size() >= 120: continue
		mantle.append({"name": String(node.name), "center": _v(box.get_center()), "size": _v(box.size), "top": snappedf(top, 0.01)})
	out["mantle_candidates"] = mantle
	var file := FileAccess.open("user://trailer/probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	print("TRAILER_PROBE: %d access doors, %d clubhouse doors, %d drones" % [out.access_doors.size(), out.clubhouse_doors.size(), out.drones.size()])

func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]

# ---------------------------------------------------------------- HQ menu

func capture_hq() -> void:
	# A believable mid-career profile: some runs banked, one upgrade bought.
	var d: Dictionary = raid.profile.data
	d.credits = 1840
	d.runs = 11
	d.extracts = 7
	d.pack_level = 1
	d.stash = {"archive": 1, "optics": 2, "circuit": 3, "cell": 2, "bolt_cutters": 1,
		"tourniquet": 2, "canned_peaches": 3, "patrol_armour_t3": 1}
	raid.hud.show_hq(raid)
	for _frame: int in range(20): await process_frame
	await _save_frame("%s/hq01_field_operations.png" % STILL_DIR)
	# Buy sequence: focus the cargo upgrade, click, then the medkit. ~4 s clip.
	var frame_dir := "%s/hq02_buy_sequence" % FRAME_DIR
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var index := 0
	var upgrade := _find_button("Cargo upgrade")
	if upgrade != null: upgrade.grab_focus()
	index = await _record_frames(frame_dir, index, 1.0)
	raid._on_action("upgrade")
	for _frame: int in range(3): await process_frame
	var medkit := _find_button("Extra medkit")
	if medkit != null: medkit.grab_focus()
	index = await _record_frames(frame_dir, index, 1.2)
	raid._on_action("medkit")
	for _frame: int in range(3): await process_frame
	index = await _record_frames(frame_dir, index, 1.4)
	await _save_frame("%s/hq02_after_purchase.png" % STILL_DIR)
	raid._on_action("inventory")
	for _frame: int in range(20): await process_frame
	await _save_frame("%s/hq03_loadout_inventory.png" % STILL_DIR)
	print("TRAILER_HQ: done")

func _find_button(prefix: String) -> Button:
	for node: Node in raid.hud.panel_content.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with(prefix): return node
	return null

# ---------------------------------------------------------------- HUD plates

func capture_plates() -> void:
	# Freeze the raid so staged values are not overwritten, and draw only the
	# canvas layers over a transparent background.
	raid.set_physics_process(false)
	raid.set_process(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.transparent_bg = true
	root.disable_3d = true
	for plate: Dictionary in PLATES:
		raid.relays = int(plate.get("relays", 0))
		raid.remaining = float(plate.get("remaining", 7200.0))
		raid.prompt_text = str(plate.get("prompt", ""))
		raid.progress_ratio = float(plate.get("progress", 0.0))
		raid.hud.update_raid(raid)
		var extra: Label = null
		if plate.has("extra"):
			extra = Label.new()
			extra.text = str(plate.extra)
			extra.add_theme_font_size_override("font_size", 18)
			extra.add_theme_color_override("font_color", raid.hud.MINT)
			extra.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			extra.offset_left = -350
			extra.offset_right = -46
			extra.offset_top = 132
			extra.offset_bottom = 160
			extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			raid.hud.root.add_child(extra)
		for _frame: int in range(4): await process_frame
		await _save_frame("%s/%s.png" % [PLATE_DIR, plate.name])
		if extra != null: extra.queue_free()
	print("TRAILER_PLATES: %d plates" % PLATES.size())

# ---------------------------------------------------------------- staged shots

func capture_shots(shots: Array[Dictionary] = [], label: String = "staged") -> void:
	_quiet_hostiles(true)
	if shots.is_empty():
		shots = NIGHT_SHOTS if night else DAY_SHOTS
	for shot: Dictionary in shots:
		if not only_shots.is_empty() and not only_shots.has(shot["name"]):
			continue
		await play_shot(shot)
		_quiet_hostiles(true)
	var record_path := "user://trailer/%s_%s.json" % [label, "night" if night else "day"]
	var file := FileAccess.open(record_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps": FPS, "shots": shots_record}, "\t"))
	file.close()
	print("TRAILER_STAGED: done, %d shots" % shots.size())

func play_shot(shot: Dictionary) -> void:
	var name: String = shot["name"]
	if not bool(player.alive) or raid.phase != raid.Phase.RAID:
		push_warning("Staged capture: player is down, skipping " + name)
		print("TRAILER_STAGED_SKIP: " + name)
		return
	var frame_dir := "%s/%s" % [FRAME_DIR, name]
	if dump_frames: DirAccess.make_dir_recursive_absolute(frame_dir)
	var index := 0
	var total := 0.0
	for step: Dictionary in shot["steps"]:
		if step.get("record", true): total += float(step.get("seconds", step.get("wait", 0.0)))
	var still_at := int(total * FPS / 2.0)
	var still_saved := false
	for step: Dictionary in shot["steps"]:
		if step.has("relays"): raid.relays = int(step.relays)
		if step.has("drones"): _quiet_hostiles(not bool(step.drones))
		if step.has("hostiles"): _quiet_hostiles(not bool(step.hostiles))
		if step.has("teleport"): _place(step.teleport, float(step.get("yaw", 0.0)), float(step.get("pitch", 0.0)))
		if step.has("face_group"): _face_group(str(step.face_group), step.get("anchor", Vector3.ZERO), float(step.get("distance", 15.0)), float(step.get("yaw_offset", 0.0)))
		if step.has("cache"): _stand_at_cache(step.cache)
		if step.has("weapon"): _grant_weapon(str(step.weapon))
		if step.has("damage"): player.take_damage(float(step.damage), str(step.get("damage_part", "left_arm")))
		var seconds := float(step.get("seconds", step.get("wait", 0.0)))
		var frames := int(round(seconds * FPS))
		var held: Array = step.get("hold", [])
		var bursts: Array = step.get("bursts", [])
		var fire_down := false
		var record := bool(step.get("record", true))
		var yaw0: float = player.rotation.y
		var head: Node3D = player.head
		var pitch0: float = head.rotation.x
		var look: Dictionary = step.get("look_to", {})
		for action: String in step.get("press", []):
			_send_action(action, true)
		for action: String in held:
			_send_action(action, true)
		for frame: int in range(frames):
			# Door and cache latches want the key down across a few physics ticks.
			if frame == 3:
				for action: String in step.get("press", []):
					_send_action(action, false)
			if not bursts.is_empty():
				var period := float(bursts[0]) + float(bursts[1])
				var want := fmod(frame / FPS, period) < float(bursts[0])
				if want != fire_down:
					_send_action("fire", want)
					fire_down = want
			if not look.is_empty():
				var t := float(frame) / float(maxi(frames - 1, 1))
				var eased := t * t * (3.0 - 2.0 * t)
				player.rotation.y = yaw0 + deg_to_rad(float(look.get("yaw_delta", 0.0))) * eased
				head.rotation.x = lerpf(pitch0, deg_to_rad(float(look.get("pitch", rad_to_deg(pitch0)))), eased)
			GameInput._focused = true
			await process_frame
			if not record: continue
			if dump_frames or (not still_saved and index >= still_at):
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				if dump_frames: image.save_jpg("%s/%05d.jpg" % [frame_dir, index], FRAME_QUALITY)
				if not still_saved and index >= still_at:
					image.save_png("%s/%s.png" % [STILL_DIR, name])
					still_saved = true
			index += 1
		for action: String in held:
			_send_action(action, false)
		if fire_down: _send_action("fire", false)
	shots_record.append({"name": name, "frames": index, "seconds": index / FPS})
	print("TRAILER_STAGED_SHOT: %s %d frames" % [name, index])

func _send_action(action: String, pressed: bool) -> void:
	# Routed through parse_input_event so both Input.is_action_pressed and the
	# player's _unhandled_input (aim, fire, interact edges) see it.
	var event := InputEventAction.new()
	event.action = "sr_" + action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

func _place(position: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = position
	player.rotation.y = deg_to_rad(yaw_deg)
	var head: Node3D = player.head
	head.rotation.x = deg_to_rad(pitch_deg)
	if player.has_method("reset_controller_intents"): player.reset_controller_intents()
	raid.last_damage_at = -100.0
	# Every shot starts healthy so a hard take never carries damage into the next.
	var medical: Variant = player.get("medical")
	if medical != null and medical.has_method("reset"):
		medical.reset()
		player.health = medical.effective_hp()
	raid.medkits = maxi(int(raid.medkits), 2)

func _nearest_in_group(group: String, anchor: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node: Node in get_nodes_in_group(group):
		if not (node is Node3D) or not node.is_inside_tree(): continue
		if bool(node.get("dead")): continue
		var distance: float = (node as Node3D).global_position.distance_to(anchor)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func _face_group(group: String, anchor: Vector3, distance: float, yaw_offset: float = 0.0) -> void:
	var target := _nearest_in_group(group, anchor)
	if target == null:
		push_warning("Staged capture: nobody in group " + group)
		_place(anchor, 0.0, 0.0)
		return
	var at := target.global_position
	# Stand `distance` metres back toward the anchor side, eyes on the target.
	var away := (anchor - at)
	away.y = 0.0
	if away.length() < 1.0: away = Vector3(0, 0, 1)
	var stand := at + away.normalized() * distance
	var forward := (at - stand).normalized()
	var yaw := rad_to_deg(atan2(-forward.x, -forward.z)) + yaw_offset
	_place(Vector3(stand.x, at.y + 0.3, stand.z), yaw, -2.0)

func _stand_at_cache(anchor: Vector3) -> void:
	var best: Dictionary = {}
	var best_distance := INF
	for site: Dictionary in raid.sites:
		if site.kind != "cache" or bool(site.get("done", false)): continue
		var distance: float = Vector2(site.position.x, site.position.z).distance_to(Vector2(anchor.x, anchor.z))
		if distance < best_distance:
			best_distance = distance
			best = site
	if best.is_empty():
		push_warning("Staged capture: no cache near " + str(anchor))
		return
	var at: Vector3 = best.position
	var stand := at + Vector3(0, 0, 1.6)
	_place(Vector3(stand.x, at.y + 0.3, stand.z), 0.0, -14.0)

func _grant_weapon(id: String) -> void:
	if player.weapon_id == id: return
	var state: Dictionary = raid.active_weapon_loadout()
	var record: Dictionary = WeaponState.recovered_weapon(id)
	if record.is_empty(): return
	record.ammo = 30
	record.reserve = 120
	record.chambered = true
	record.magazine_inserted = true
	# Loose reserve rounds, so a reload on camera does not need a packed magazine in cargo.
	record.physical_magazines = false
	if player.apply_weapon_loadout(id, record):
		state.weapons[id] = record
		state.equipped = id
		state.revision += 1
	else:
		push_warning("Staged capture: could not equip " + id)

func _quiet_hostiles(quiet: bool) -> void:
	# Scav crews and drone weapons stay out of the staged movement shots so the
	# player survives the take; drone bodies keep patrolling for the lighting.
	for node: Node in get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED if quiet else Node.PROCESS_MODE_INHERIT
	for node: Node in scene.find_children("*", "Node", true, false):
		var script: Script = node.get_script()
		if script == null: continue
		var path := script.resource_path
		if path.ends_with("patrol_combat.gd") or path.ends_with("patrol_stun_emitter.gd"):
			node.process_mode = Node.PROCESS_MODE_DISABLED if quiet else Node.PROCESS_MODE_INHERIT

func _record_frames(frame_dir: String, index: int, seconds: float) -> int:
	for _frame: int in range(int(round(seconds * FPS))):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("%s/%05d.jpg" % [frame_dir, index], FRAME_QUALITY)
		index += 1
	return index

func _save_frame(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
