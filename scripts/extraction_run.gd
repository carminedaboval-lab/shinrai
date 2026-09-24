extends Node

const Profile = preload("res://scripts/extraction_profile.gd")
const Navigation = preload("res://scripts/extraction_navigation.gd")
const Hud = preload("res://scripts/extraction_hud.gd")
const Enemy = preload("res://scripts/extraction_enemy.gd")
const Cover = preload("res://scripts/extraction_cover.gd")
const ITEMS := [
	{"id": "circuit", "title": "Control circuit", "value": 85},
	{"id": "optics", "title": "Optical sensor", "value": 140},
	{"id": "cell", "title": "Power cell", "value": 60},
	{"id": "archive", "title": "Encrypted archive", "value": 220}]
const PRICES := {"circuit": 85, "optics": 140, "cell": 60, "archive": 220}
const RAID_SECONDS := 600.0
enum Phase { BOOT, HQ, RAID, PAUSED, RESULT }

var phase: Phase = Phase.BOOT
var profile := Profile.new()
var navigation := Navigation.new()
var park: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var menu_camera: Camera3D
var enemy_visual: PackedScene
var sites: Array[Dictionary] = []
var exits: Array[Dictionary] = []
var map_routes: Array = []
var bag: Array[Dictionary] = []
var relays := 0
var medkits := 1
var remaining := RAID_SECONDS
var extraction_progress := 0.0
var extraction_id := ""
var hold_progress := 0.0
var hold_id := ""
var healing := 0.0
var last_damage_at := -100.0
var run_time := 0.0
var last_safe := Vector3(0, 0.2, 160)
var notice := ""
var notice_time := 0.0
var prompt_text := ""
var progress_ratio := 0.0
var night_deployment := false
var map_open := false
var track_extraction := false
var rng := RandomNumberGenerator.new()
var ui_elapsed := 0.0
var approach_cover: Node3D
var guidance_path := PackedVector3Array()
var guidance_distance := 0.0
var guidance_elapsed := 0.0
var selected_destination := ""
var result_saved := false
var result_extracted := false
var result_reason := ""
var result_bonus := 0

func _ready() -> void:
	process_physics_priority = 10 # Apply shoreline safety after player movement.
	park = get_parent()
	player = park.get_node("ParkScaleReviewPlayer")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	profile.save_path = park.profile_path
	profile.load_profile()
	hud = Hud.new()
	add_child(hud)
	hud.action_requested.connect(_on_action)
	player.died.connect(func() -> void: finish_run(false, "You were eliminated."))
	player.shot_fired.connect(_on_shot)
	player.damage_received.connect(_on_damage)
	player.hud_health.get_parent().hide()
	player.hud_status.hide()
	menu_camera = Camera3D.new()
	park.add_child(menu_camera)
	menu_camera.position = Vector3(142, 9, 160)
	menu_camera.fov = 58
	menu_camera.look_at(Vector3(164, 3.0, 135))
	menu_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Exact supported art socket. No runtime scanning/importing and no proxy.
	for path: String in ["res://assets/enemies/k17_drone/godot_test/K17_Stage34_LOD0.glb", "res://assets/enemies/k17/K17_Drone_Static.tscn", "res://assets/enemies/k17/K17_Drone_Static.glb"]:
		if ResourceLoader.exists(path):
			enemy_visual = load(path) as PackedScene
			if enemy_visual != null:
				break
	hud.show_hq(self)
	call_deferred("_prepare_park")

func _prepare_park() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	approach_cover = Cover.new()
	park.add_child(approach_cover)
	approach_cover.build(park)
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation.build(park)
	map_routes = [park.OUTER_CIRCUIT, park.LAKE_PROMENADE_LOOP, park.SOUTH_ARRIVAL_ROUTE, park.WEST_DESTINATION_ROUTE, park.PLAZA_ARRIVAL_ROUTE, park.NORTH_ENTRY_ROUTE, park.EAST_DECK_ROUTE, park.SPORTS_LINK_ROUTE, park.PLAYGROUND_LOOP, park.NORTH_WOODLAND_LOOP, park.SOUTH_BRIDGE_APPROACH, park.PAVILION_LINK_ROUTE, park.VIEWING_DECK_APPROACH_ROUTE, park.FUTURE_BRIDGE_WEST, park.FUTURE_BRIDGE_NORTH_EAST, park.FUTURE_BRIDGE_SOUTH]
	_register_sites()
	phase = Phase.HQ
	hud.show_hq(self)

func _register_sites() -> void:
	sites.clear()
	# Attach interactions to supplied furniture, rather than inventing loot art.
	var relay_names := ["EmeraldHaloLamp_01", "EmeraldHaloLamp_05", "EmeraldHaloLamp_10"]
	var titles := ["South garden relay", "North sports relay", "East lake relay"]
	for index: int in range(relay_names.size()):
		var prop := park.find_child(relay_names[index], true, false) as Node3D
		if prop != null:
			sites.append({"id": relay_names[index], "title": titles[index], "kind": "relay", "position": prop.global_position, "done": false})
	for prop: Node in park.find_children("*Bench*", "Node3D", true, false):
		if not (String(prop.name).begins_with("NeonParkBench_") or String(prop.name).begins_with("FuturisticEcoBench_") or String(prop.name).begins_with("PlazaBench_")):
			continue
		sites.append({"id": String(prop.name), "title": "Search bench compartment", "kind": "cache", "position": prop.global_position, "done": false})
	exits = [
		{"id": "south", "title": "South gate extraction", "position": Vector3(0, 0.2, 167)},
		{"id": "west", "title": "West gate extraction", "position": Vector3(-205, 0.2, 40)}]

func capacity() -> int:
	return 6 + int(profile.data.pack_level) * 2

func _on_action(action: String) -> void:
	if action.begins_with("track:") and phase == Phase.PAUSED:
		selected_destination = action.trim_prefix("track:")
		refresh_guidance()
		hud.show_pause(self, true)
		return
	match action:
		"deploy": start_run()
		"time":
			night_deployment = not night_deployment
			park.is_night_mode = night_deployment
			park._apply_time_of_day()
			hud.show_hq(self)
		"sell":
			profile.sell_stash(PRICES)
			hud.show_hq(self)
		"upgrade":
			profile.buy_upgrade()
			hud.show_hq(self)
		"medkit":
			profile.buy_medkit()
			hud.show_hq(self)
		"resume": resume_run()
		"abandon_confirm": hud.show_abandon()
		"abandon": finish_run(false, "Run abandoned. Carried items were lost.")
		"drop":
			if not bag.is_empty():
				bag.pop_back()
			hud.show_pause(self, true)
		"hq":
			if phase != Phase.RESULT or not result_saved:
				return
			phase = Phase.HQ
			menu_camera.make_current()
			hud.show_hq(self)
		"retry_result":
			if phase == Phase.RESULT and not result_saved:
				_settle_result()
		"retry_save":
			if phase == Phase.HQ:
				profile.save_profile()
				hud.show_hq(self)

func start_run() -> void:
	if phase != Phase.HQ or not navigation.ready:
		return
	var extra_medkit: bool = profile.data.prepared_medkit
	if not profile.begin_run():
		hud.show_hq(self)
		return
	rng.randomize()
	_clear_enemies()
	bag.clear()
	relays = 0
	track_extraction = false
	selected_destination = ""
	medkits = 2 if extra_medkit else 1
	remaining = RAID_SECONDS
	run_time = 0.0
	healing = 0.0
	hold_progress = 0.0
	prompt_text = "Hold H: medkit   ·   Tab: field map / cargo"
	progress_ratio = 0.0
	ui_elapsed = 0.0
	extraction_progress = 0.0
	extraction_id = ""
	hold_id = ""
	last_damage_at = -100.0
	for site: Dictionary in sites:
		site.done = false
		if site.kind == "cache":
			site.loot = ITEMS[rng.randi_range(0, ITEMS.size() - 1)].duplicate()
	player.alive = true
	player.health = 100.0
	player.ammo = 30
	player.reserve = 90
	player.kills = 0
	player.reloading = false
	player.reload_time = 0.0
	player.ads = false
	player.ads_blend = 0.0
	player.fire_cooldown = 0.0
	player.damage_flash = 0.0
	# A run can end mid-mantle, while the controller temporarily has no collision.
	if player.mantle_active:
		player.collision_layer = player.mantle_saved_layer
		player.collision_mask = player.mantle_saved_mask
	player.mantle_active = false
	player.jump_was_down = false
	player.velocity = Vector3.ZERO
	player.position = navigation.nearest(Vector3(0, 0.2, 160))
	last_safe = player.position
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	refresh_guidance()
	for point: Vector3 in guidance_path:
		if point.distance_to(player.position) > 12.0:
			player.look_at(Vector3(point.x, player.position.y, point.z))
			break
	player.camera.make_current()
	player._update_hud()
	phase = Phase.RAID
	_set_actors_enabled(true)
	_spawn_patrols()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_raid()
	announce("Recover a relay at a marked lamp. Hold E nearby. Tab opens your field map.", 9.0)
	hud.update_raid(self)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
		if phase == Phase.RAID:
			pause_run(event.keycode == KEY_TAB)
		elif phase == Phase.PAUSED:
			resume_run()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_T and phase == Phase.RAID:
		track_extraction = not track_extraction
		selected_destination = ""
		refresh_guidance()
		announce("Tracking extraction gates" if track_extraction else "Tracking remaining relays", 2.0)
		get_viewport().set_input_as_handled()

func pause_run(with_map: bool) -> void:
	if phase != Phase.RAID:
		return
	phase = Phase.PAUSED
	refresh_guidance()
	map_open = with_map
	_set_actors_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause(self, with_map)

func resume_run() -> void:
	if phase != Phase.PAUSED:
		return
	phase = Phase.RAID
	_set_actors_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_raid()
	hud.update_raid(self)

func _set_actors_enabled(enabled: bool) -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	player.ads = false
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	if phase != Phase.RAID:
		return
	remaining = maxf(0.0, remaining - delta)
	run_time += delta
	notice_time = maxf(0.0, notice_time - delta)
	if remaining <= 0.0:
		finish_run(false, "The park locked down before you reached extraction.")
		return
	var p := player.global_position
	if absf(p.x) > 215 or absf(p.z) > 175 or navigation.is_water(Vector2(p.x, p.z)):
		player.global_position = last_safe
		player.velocity = Vector3.ZERO
		announce("Deep water / perimeter. Stay on the park's dry routes.", 2.0)
	elif player.is_on_floor():
		last_safe = p
	prompt_text = "Hold H: medkit   ·   Tab: field map / cargo"
	progress_ratio = 0.0
	_update_interaction(delta)
	_update_healing(delta)
	_update_extraction(delta)
	if phase != Phase.RAID:
		return
	guidance_elapsed += delta
	if guidance_elapsed >= 1.0:
		refresh_guidance()
	ui_elapsed += delta
	if ui_elapsed >= 0.08:
		ui_elapsed = 0.0
		hud.update_raid(self)

func nearest_site() -> Dictionary:
	var found: Dictionary = {}
	var best := 4.2
	for site: Dictionary in sites:
		if site.done:
			continue
		var distance := _distance(site.position)
		if distance < best:
			best = distance
			found = site
	return found

func _distance(point: Vector3) -> float:
	return Vector2(player.position.x, player.position.z).distance_to(Vector2(point.x, point.z))

func _update_interaction(delta: float) -> void:
	var site := nearest_site()
	if site.is_empty() or healing > 0.0:
		hold_progress = 0.0
		hold_id = ""
		return
	if site.id != hold_id:
		hold_progress = 0.0
		hold_id = site.id
	if site.kind == "cache" and bag.size() >= capacity():
		prompt_text = "CARGO FULL  ·  Extract or drop an item from the field map"
		return
	prompt_text = "HOLD E  /  " + String(site.title)
	if Input.is_key_pressed(KEY_E) and run_time - last_damage_at > 0.8 and not player.reloading:
		hold_progress += delta
		var required := 4.0 if site.kind == "relay" else 2.0
		progress_ratio = hold_progress / required
		if hold_progress >= required:
			complete_site(site)
	else:
		hold_progress = 0.0

func complete_site(site: Dictionary) -> bool:
	if phase != Phase.RAID or site.is_empty() or site.done or _distance(site.position) > 4.2:
		return false
	if site.kind == "cache" and bag.size() >= capacity():
		return false
	site.done = true
	if selected_destination == site.id:
		selected_destination = ""
	hold_progress = 0.0
	if site.kind == "relay":
		relays += 1
		track_extraction = true
		announce("Telemetry recovered %d/3. Extraction is available at South or West Gate." % relays, 7.0)
		_alert_nearby(site.position, 85.0)
	else:
		bag.append(site.loot.duplicate())
		player.reserve = mini(player.reserve + 15, 240)
		announce("Recovered %s  ·  %d credits on sale  ·  +15 rounds" % [site.loot.title, site.loot.value])
	refresh_guidance()
	return true

func refresh_guidance() -> void:
	guidance_elapsed = 0.0
	guidance_path.clear()
	guidance_distance = 0.0
	var objective := tracked_objective()
	if objective.is_empty():
		return
	var radius := 7.5 if not objective.has("kind") else 4.0
	guidance_path = navigation.interaction_path(player.position, objective.position, radius)
	for index: int in range(1, guidance_path.size()):
		guidance_distance += guidance_path[index - 1].distance_to(guidance_path[index])

func _update_healing(delta: float) -> void:
	if Input.is_key_pressed(KEY_H) and medkits > 0 and player.health < 100.0 and run_time - last_damage_at > 1.0 and hold_progress == 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		healing += delta
		prompt_text = "APPLYING MEDKIT  ·  Hold H"
		progress_ratio = healing / 2.5
		if healing >= 2.5:
			player.health = minf(100.0, player.health + 55.0)
			medkits -= 1
			healing = 0.0
			announce("Medkit applied. +55 health.")
	else:
		healing = 0.0

func _update_extraction(delta: float) -> void:
	var exit_point: Dictionary = {}
	for candidate: Dictionary in exits:
		if _distance(candidate.position) <= 8.0:
			exit_point = candidate
	if exit_point.is_empty() or relays == 0:
		if not exit_point.is_empty():
			prompt_text = "EXTRACTION LOCKED  ·  Recover at least one relay"
		extraction_progress = 0.0
		extraction_id = ""
		return
	if extraction_id != exit_point.id:
		extraction_id = exit_point.id
		extraction_progress = 0.0
		_alert_nearby(exit_point.position, 100.0)
	if run_time - last_damage_at < 2.0:
		extraction_progress = 0.0
		prompt_text = "EXTRACTION INTERRUPTED  ·  Break contact"
		return
	extraction_progress += delta
	prompt_text = "EXTRACTING  ·  Stay in the gate zone  ·  %ds" % ceili(15.0 - extraction_progress)
	progress_ratio = extraction_progress / 15.0
	if extraction_progress >= 15.0:
		finish_run(true, "You made it out of Shinrai Park.")

func tracked_objective() -> Dictionary:
	if not selected_destination.is_empty():
		for candidate: Dictionary in sites + exits:
			if candidate.id == selected_destination and not candidate.get("done", false):
				return candidate
	var unfinished := sites.filter(func(site: Dictionary) -> bool: return site.kind == "relay" and not site.done)
	var candidates: Array = exits if track_extraction or unfinished.is_empty() else unfinished
	var result: Dictionary = {}
	var distance := INF
	for candidate: Dictionary in candidates:
		if _distance(candidate.position) < distance:
			distance = _distance(candidate.position)
			result = candidate
	return result

func finish_run(extracted: bool, reason: String) -> void:
	if phase != Phase.RAID and phase != Phase.PAUSED:
		return
	phase = Phase.RESULT
	_set_actors_enabled(false)
	result_extracted = extracted
	result_reason = reason
	result_bonus = (150 * relays + (300 if relays == 3 else 0)) if extracted else 0
	result_saved = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settle_result()

func _settle_result() -> void:
	result_saved = profile.complete_run(result_extracted, bag, result_bonus)
	hud.show_result(self, result_extracted, result_reason, result_bonus)

func announce(text: String, duration: float = 4.0) -> void:
	notice = text
	notice_time = duration

func _on_damage(_amount: float) -> void:
	last_damage_at = run_time
	healing = 0.0
	hold_progress = 0.0

func _on_shot() -> void:
	healing = 0.0
	hold_progress = 0.0
	_alert_nearby(player.position, 65.0)

func _alert_nearby(point: Vector3, radius: float) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.hear_noise(point, radius)

func _clear_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.queue_free()

func _spawn_patrols() -> void:
	if enemy_visual == null:
		return
	for site: Dictionary in sites:
		if site.kind != "relay":
			continue
		for flank: int in [-1, 1]:
			var anchor := navigation.nearest(site.position + Vector3(flank * 16, 0, -12))
			if anchor.distance_to(player.position) < 50:
				continue
			var route: Array[Vector3] = [anchor, navigation.nearest(anchor + Vector3(16, 0, 16)), navigation.nearest(anchor + Vector3(-12, 0, 24))]
			var enemy := Enemy.new()
			enemy.approved_visual = enemy_visual
			enemy.position = anchor
			enemy.configure(player, 1, self, route)
			enemy.add_to_group("extraction_hostiles")
			park.add_child(enemy)

func get_path_world(from: Vector3, to: Vector3) -> PackedVector3Array:
	return navigation.path(from, to)

func get_nearest_walkable_world(point: Vector3) -> Vector3:
	return navigation.nearest(point)

func get_search_positions_world(point: Vector3, count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index: int in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(navigation.nearest(point + Vector3(cos(angle), 0, sin(angle)) * 10.0))
	return points
