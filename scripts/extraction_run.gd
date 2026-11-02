extends Node
const GameInput=preload("./shinrai_input.gd")
const ControllerUI=preload("./shinrai_controller_ui.gd")
var controller_ui: Node
var abandon_confirmation_open:=false
const Medical = preload("./extraction_medical.gd")
const Cans = preload("./extraction_canned_food.gd")
const Food = preload("./extraction_food_condition.gd")
const Metabolism = preload("./extraction_metabolism.gd")
const FruitHarvest = preload("./midori_fruit_harvest.gd")
var fruit_harvest := FruitHarvest.new()
const LegacyHostile = preload("res://scripts/enemy.gd")
var metabolism := Metabolism.new()
var _previous_stamina := 100.0
var _metabolic_combat := false
var _metabolic_sample := 0.0
const LoadingBudget = preload("res://scripts/shinrai_loading_budget.gd")

const PitchGate = preload("./midori_pitch_gate.gd")
var pitch_gate: Node3D
const ClubhouseDoors = preload("./midori_clubhouse_doors.gd")
var clubhouse_doors: Node3D
const BuildingAccess = preload("res://scripts/building_access/service.gd")
var building_access := BuildingAccess.new()

const WeaponSupply=preload("./extraction_weapon_supplies.gd")
const Clothing=preload("./extraction_clothing.gd")
var pending_magazine: Dictionary = {}
const MagazineRecord = preload("./extraction_magazine_record.gd")
const DroppedMagazine = preload("./extraction_dropped_magazine.gd")
var _reload_outgoing_magazine: Dictionary = {}
var _reload_magazine_source_index := -1
const WeaponLoot = preload("./extraction_weapon_loot.gd")
const ResidentialLoot = preload("./extraction_residential_loot.gd")
var field_loadout: Dictionary = {}
const ContextLoot = preload("./extraction_context_loot.gd")
const LootContainers = preload("./extraction_loot_containers.gd")
const FootballTrainingPlacement = preload("./football_training_placement.gd")
const FootballLootRegistration = preload("./extraction_football_loot_registration.gd")
const BackpackRules = preload("./extraction_backpack_state.gd")
const BackpackPickups = preload("./extraction_backpack_pickups.gd")
var backpack_state: Dictionary = BackpackRules.new_state("not-started")
var backpack_test_enabled := false
var pending_result_save: Dictionary = {}

const Profile = preload("./extraction_profile.gd")
const WeaponState = preload("./extraction_weapon_state.gd")
const WeaponCatalog = preload("res://scripts/extraction_weapon_catalog.gd")
const Navigation = preload("res://scripts/extraction_navigation.gd")
const Hud = preload("./extraction_hud.gd")
const Enemy = preload("res://scripts/extraction_enemy.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")
const PoliceGroups = preload("res://assets/enemies/police_spider/park_drone_groups.gd")
const ScavSquad = preload("./scav_squad.gd")
const Cover = preload("res://scripts/extraction_cover.gd")
const ITEMS := [
	{"id": "circuit", "title": "Control circuit", "value": 85},
	{"id": "optics", "title": "Optical sensor", "value": 140},
	{"id": "cell", "title": "Power cell", "value": 60},
	{"id": "archive", "title": "Encrypted archive", "value": 220},
	{"id": "coffee_cup", "title": "Sealed coffee cup", "value": 12},
	{"id": "park_map", "title": "Midori park map", "value": 0},
	{"id":"backpack_regular","title":"Field backpack","value":0},
	{"id":"backpack_mountain","title":"Mountain backpack","value":0}] + LootContainers.ITEMS + FruitHarvest.ITEMS
const PRICES := {"hammer":22,"screwdriver":12,"wrench":24,"circuit": 85, "optics": 140, "cell": 60, "archive": 220, "coffee_cup": 12, "pliers":18, "scissors":10, "utility_knife":16, "bottled_water_closed":8, "bottled_water_open":2, "sports_bottle_closed":14, "sports_bottle_open":7, "bandage":15, "tourniquet":35, "splint":25, "ration_bar":12, "garden_mikan":4, "garden_persimmon":5,"canned_mackerel":14,"canned_mackerel_open":6,"canned_peaches":12,"canned_peaches_open":5,"can_opener":9}
const RAID_SECONDS := 7200.0
enum Phase { BOOT, HQ, RAID, PAUSED, RESULT }

var creator_layout_result: Dictionary = {}
var quit_confirmation_open := false
var deployment_pending := false
var _pause_after_deployment := false
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
var medical_pouch := {"bandage":2,"tourniquet":1,"splint":1}
var treatment_item := ""
var treatment_part := ""
var treatment_automatic := false
var remaining := RAID_SECONDS
var extraction_progress := 0.0
var extraction_id := ""
var hold_progress := 0.0
var hold_id := ""
var healing := 0.0
var last_damage_at := -100.0
var run_time := 0.0
## Seconds after deployment during which hostiles cannot perceive the player,
## so a new raid starts with time to orient instead of an instant firefight.
const INSERTION_GRACE_SECONDS := 15.0
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
var pending_cache_id := ""
var cache_release_id := ""
var cache_input_release_pending := false
var inventory_open := false
var food_save_elapsed := 0.0
var food_save_dirty := false
var weapon_save_elapsed := 0.0
var weapon_save_pending := false

func _ready() -> void:
	add_to_group("shinrai_survival_run")
	GameInput.ensure_actions()
	var input_router:=GameInput.new();input_router.name="GamepadInput";add_child(input_router)
	backpack_test_enabled = BackpackRules.test_override(OS.get_cmdline_user_args(), OS.has_feature("debug"))
	process_physics_priority = 10 # Apply shoreline safety after player movement.
	park = get_parent()
	player = park.get_node("ParkScaleReviewPlayer")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.weapon_input_locked = true
	player.physical_reload_handler = Callable(self,"physical_magazine_reload")
	profile.save_path = park.profile_path
	profile.load_profile()
	metabolism.restore_illness(profile.data.get("food_illness",{}))
	_restore_weapon_loadout()
	hud = Hud.new()
	add_child(hud)
	hud.action_requested.connect(_on_action)
	controller_ui=ControllerUI.new();controller_ui.name="ControllerUI";add_child(controller_ui);controller_ui.setup(self)
	player.died.connect(func() -> void: finish_run(false, "You were eliminated."))
	player.shot_fired.connect(_on_shot)
	player.damage_received.connect(_on_damage)
	player.healing_cancelled.connect(_cancel_healing)
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
	for path: String in ["res://assets/enemies/police_spider/Shinrai_Patrol_Animated.glb", "res://assets/enemies/k17_drone/godot_test/K17_Stage34_LOD0.glb", "res://assets/enemies/k17/K17_Drone_Static.tscn", "res://assets/enemies/k17/K17_Drone_Static.glb"]:
		if ResourceLoader.exists(path):
			enemy_visual = load(path) as PackedScene
			if enemy_visual != null:
				break
	# HQ is presented only when its native dependencies are ready.
	call_deferred("_prepare_park")

func _prepare_park() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	approach_cover = Cover.new()
	park.add_child(approach_cover)
	approach_cover.build(park)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var terrain := park.get_node_or_null("MidoriTerrain")
	while terrain != null and not terrain.installed:
		await get_tree().process_frame
	var desire_paths := park.get_node_or_null("MidoriDesirePaths")
	while desire_paths != null and not desire_paths.finished:
		await get_tree().process_frame
	var stone_lanterns := park.get_node_or_null("MidoriStoneLanterns")
	while stone_lanterns != null and not stone_lanterns.installed:
		await get_tree().process_frame
	if stone_lanterns != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
	var path_lamps := park.get_node_or_null("MidoriJapanesePathLamps")
	while path_lamps != null and not path_lamps.installed:
		await get_tree().process_frame
	if path_lamps != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
	var secondary_path_lamps := park.get_node_or_null("MidoriSecondaryPathLamps")
	while secondary_path_lamps != null and not secondary_path_lamps.installed:
		await get_tree().process_frame
	if secondary_path_lamps != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
	# Furniture must exist before native obstacle sampling and cache registration.
	var identity := park.get_node_or_null("Midori2050Identity")
	var _t := StartupTrace.begin()
	while identity != null and not identity.installed:
		await get_tree().process_frame
	_t = StartupTrace.finish("raid.wait_identity", _t)
	if identity != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
	# Complete the supported fruit garden before navigation samples its trunks.
	var fruit_street := park.get_node_or_null("MidoriSouthStreet")
	while fruit_street != null and fruit_street.get("installed") != true:
		await get_tree().process_frame
	_t = StartupTrace.finish("raid.wait_south_street", _t)
	# Recent emergency fixtures must exist before navigation and Creator scanning.
	var aftermath := park.get_node_or_null("MidoriAftermath")
	while aftermath != null and aftermath.get("installed") != true:
		await get_tree().process_frame
	_t = StartupTrace.finish("raid.wait_aftermath", _t)
	# Finish the road-connected corporate parcel before world caches and HQ.
	var corporate := park.get_node_or_null("MidoriCorporateDistrict")
	while corporate != null and corporate.get("installed") != true:
		await get_tree().process_frame
	_t = StartupTrace.finish("raid.wait_corporate", _t)
	var fruit_garden: Dictionary = preload("./midori_fruit_garden.gd").install(park)
	if fruit_garden.get("report",{}).has("error"):
		push_warning("MIDORI_FRUIT_GARDEN: " + str(fruit_garden.report.error))
	_t = StartupTrace.finish("raid.fruit_garden", _t)
	creator_layout_result = await preload("./creator/creator_game_integration.gd").apply_before_navigation(park)
	_t = StartupTrace.finish("raid.creator_layout", _t)
	LoadingBudget.stage(park,"Preparing park routes")
	await navigation.build(park)
	map_routes = [park.OUTER_CIRCUIT, park.LAKE_PROMENADE_LOOP, park.SOUTH_ARRIVAL_ROUTE, park.WEST_DESTINATION_ROUTE, park.PLAZA_PAVED_ROUTE, park.NORTH_ENTRY_ROUTE, park.EAST_DECK_ROUTE, park.SPORTS_LINK_ROUTE, park.PLAYGROUND_LOOP, park.NORTH_WOODLAND_LOOP, park.SOUTH_BRIDGE_APPROACH, park.PAVILION_LINK_ROUTE, park.VIEWING_DECK_APPROACH_ROUTE, park.FUTURE_BRIDGE_WEST, park.FUTURE_BRIDGE_NORTH_EAST, park.FUTURE_BRIDGE_SOUTH]
	if desire_paths != null:
		for route: Dictionary in desire_paths.routes:
			var line: Array[Vector2] = []
			for point: Vector2 in route.points: line.append(point / park.LAYOUT_SCALE)
			map_routes.append(line)
	var cafe := park.get_node_or_null("MidoriClubhouseCafeteria")
	while cafe != null and not cafe.installed:
		await get_tree().process_frame
	var street: Node=park.get_node_or_null("MidoriSouthStreet")
	while street!=null and street.get("installed")!=true:await get_tree().process_frame
	pitch_gate = PitchGate.install(park,self)
	# Install after navigation captures open apertures; dynamic doors filter routes.
	clubhouse_doors = ClubhouseDoors.install(cafe,self)
	_register_sites()
	# Finish late planting and partition once while deployment is still locked.
	LoadingBudget.stage(park,"Finishing park details")
	_t = StartupTrace.begin()
	var detail_result: Dictionary = await preload("res://scripts/midori_distance_boot.gd").install_before_hq(park)
	_t = StartupTrace.finish("raid.distance_boot", _t)
	if detail_result.get("status", "") == "cancelled": return
	if detail_result.has("error"):
		push_warning("MIDORI_DISTANCE_BOOT: " + str(detail_result.error))
	else:
		print("MIDORI_DISTANCE_BOOT ", JSON.stringify(detail_result))
		var render_result: Dictionary = await preload("res://scripts/midori_render_budget.gd").install_before_hq(park)
		if render_result.get("status", "") == "cancelled": return
		if render_result.has("error"):
			push_warning("MIDORI_RENDER_BOOT: " + str(render_result.error))
		else:
			print("MIDORI_RENDER_BOOT ", JSON.stringify(render_result))
	phase = Phase.HQ
	hud.show_hq(self)
	preload("./creator/creator_game_integration.gd").show_report(self, creator_layout_result)

func _register_sites() -> void:
	sites.clear()
	# Attach interactions to supplied furniture, rather than inventing loot art.
	var relay_names := ["EmeraldHaloLamp_01", "EmeraldHaloLamp_05", "EmeraldHaloLamp_10"]
	var titles := ["South garden relay", "North sports relay", "East lake relay"]
	# Keep stable gameplay IDs when the main-path furniture is replaced.
	var relay_anchors := [Vector2(-144,149), Vector2(-110,-154), Vector2(203,0)]
	var used_relay_props: Array[Node3D] = []
	var japanese_lamps := park.find_children("JapanesePathLamp_*", "Node3D", true, false)
	for index: int in range(relay_names.size()):
		var prop := park.find_child(relay_names[index], true, false) as Node3D
		if prop != null and not prop.is_visible_in_tree(): prop = null
		if prop == null:
			var nearest_distance := INF
			for candidate: Node3D in japanese_lamps:
				if candidate in used_relay_props or not candidate.is_visible_in_tree():
					continue
				var point := Vector2(candidate.global_position.x, candidate.global_position.z)
				var distance := point.distance_squared_to(relay_anchors[index])
				if distance < nearest_distance:
					nearest_distance = distance
					prop = candidate
		if prop != null:
			used_relay_props.append(prop)
		if prop != null:
			sites.append({"id": relay_names[index], "title": titles[index], "kind": "relay", "position": prop.global_position, "done": false})
	for prop: Node in park.find_children("*Bench*", "Node3D", true, false):
		if not prop.is_visible_in_tree(): continue
		if not (String(prop.name).begins_with("NeonParkBench_") or String(prop.name).begins_with("FuturisticEcoBench_") or String(prop.name).begins_with("PlazaBench_")):
			continue
		sites.append({"id": String(prop.name), "title": "Search bench compartment", "kind": "cache", "position": prop.global_position, "done": false, "discovered": false})
	exits = [
		{"id": "south", "title": "South gate extraction", "position": Vector3(0, 0.2, 167)},
		{"id": "west", "title": "West gate extraction", "position": Vector3(-205, 0.2, 40)}]

	BackpackPickups.register_for(self,park.get_node_or_null("MidoriClubhouseCafeteria"))
	var football_layout: Dictionary = FootballTrainingPlacement.build_actual_cluster(park)
	if not FootballLootRegistration.register_layout(self, football_layout):
		push_warning("MIDORI_FOOTBALL_LOOT: " + str(football_layout.get("reason", "Container registration failed.")))
	# Garden installation is owned by the park setup; register only its logical fruit.
	fruit_harvest.register_tree(park)
	WeaponLoot.install(self)
	var context_result: Dictionary=ContextLoot.install(self)
	if not context_result.missing.is_empty():push_warning("CONTEXT_LOOT missing anchors: "+str(context_result.missing))

func capacity() -> int:
	return int(BackpackRules.limits(backpack_state, [] if phase == Phase.HQ else bag, int(profile.data.pack_level)).slots)

func _on_action(action: String) -> void:
	var loading_ui := get_tree().get_first_node_in_group("shinrai_loading_ui")
	if deployment_pending or (loading_ui != null and loading_ui.active): return
	if not pending_result_save.is_empty():
		if action == "retry_result_save": retry_result_save()
		return
	if quit_confirmation_open and action not in ["quit_cancel", "quit_desktop"]: return
	if action=="unload_magazine":
		unload_magazine()
		hud.show_inventory(self)
		return
	if action.begins_with("pack_magazine:"):
		pack_magazine(int(action.trim_prefix("pack_magazine:")))
		hud.show_inventory(self)
		return
	if action.begins_with("wear_clothing:"):
		wear_clothing(int(action.trim_prefix("wear_clothing:")))
		hud.show_inventory(self)
		return
	if action.begins_with("equip_pack:"):
		equip_backpack(action.trim_prefix("equip_pack:"))
		return
	if action.begins_with("open_can:"):
		var slot := action.trim_prefix("open_can:")
		if slot.is_valid_int(): open_canned_food(slot.to_int())
		return
	if action.begins_with("consume_provision:"):
		var slot := action.trim_prefix("consume_provision:")
		if slot.is_valid_int(): consume_provision(slot.to_int())
		return
	if action.begins_with("drink_coffee:"):
		var slot := action.trim_prefix("drink_coffee:")
		if slot.is_valid_int(): consume_coffee(slot.to_int())
		return
	if action == "open_collected_map":
		open_collected_map()
		return
	if action.begins_with("discard_food:"):
		var parts := action.split(":")
		if phase==Phase.HQ and inventory_open and parts.size()==4 and parts[3].is_valid_int():
			profile.discard_food_lot(parts[1],parts[2],parts[3].to_int())
			hud.show_inventory(self)
		return
	if action.begins_with("sell_food:"):
		var parts := action.split(":")
		if phase == Phase.HQ and inventory_open and parts.size()==4 and parts[3].is_valid_int():
			profile.sell_food_lot(parts[1],parts[2],parts[3].to_int(),PRICES)
			hud.show_inventory(self)
		return
	if action.begins_with("sell_item:"):
		var parts := action.split(":")
		if phase == Phase.HQ and inventory_open and parts.size() == 3 and parts[2].is_valid_int():
			profile.sell_item(parts[1], parts[2].to_int(), PRICES)
			hud.show_inventory(self)
		return
	if action.begins_with("discard_item:"):
		var index_text := action.trim_prefix("discard_item:")
		if inventory_open and index_text.is_valid_int():
			discard_cargo(index_text.to_int())
		return
	if action.begins_with("cache_"):
		if action == "cache_take":
			resolve_cache_choice("take")
		elif action == "cache_leave":
			resolve_cache_choice("leave")
		elif action.begins_with("cache_quick:"):
			var item_text := action.trim_prefix("cache_quick:")
			if item_text.is_valid_int() and select_container_item(item_text.to_int()):
				resolve_cache_choice("take")
		elif action.begins_with("cache_select:"):
			var item_text := action.trim_prefix("cache_select:")
			if item_text.is_valid_int(): select_container_item(item_text.to_int())
		elif action.begins_with("cache_swap:"):
			var slot_text := action.trim_prefix("cache_swap:")
			if slot_text.is_valid_int():
				resolve_cache_choice("swap", slot_text.to_int())
		return
	if action.begins_with("track:") and phase == Phase.PAUSED:
		selected_destination = action.trim_prefix("track:")
		refresh_guidance()
		hud.show_pause(self, true)
		return
	match action:
		"quit_confirm": _request_quit_confirmation()
		"quit_cancel": _cancel_quit_confirmation()
		"quit_desktop":
			if quit_confirmation_open: get_tree().quit()
		"inventory": open_inventory()
		"inventory_close": close_inventory()
		"sort_cargo":
			if phase == Phase.PAUSED and inventory_open and pending_cache_id.is_empty():
				bag.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.title).naturalnocasecmp_to(String(b.title)) < 0)
				hud.show_inventory(self)
		"map":
			if phase == Phase.PAUSED and pending_cache_id.is_empty():
				inventory_open = false
				map_open = true
				hud.show_pause(self, true)
		"deploy": start_run()
		"retry_deploy": start_run(true)
		"time":
			if phase != Phase.HQ:
				return
			night_deployment = not night_deployment
			park.is_night_mode = night_deployment
			park._apply_time_of_day()
			hud.show_hq(self)
		"sell":
			if phase == Phase.HQ:
				profile.sell_stash(PRICES)
				_refresh_operations()
		"upgrade":
			if phase == Phase.HQ:
				profile.buy_upgrade()
				_refresh_operations()
		"medkit":
			if phase == Phase.HQ:
				profile.buy_medkit()
				_refresh_operations()
		"resume": resume_run()
		"abandon_confirm":
			abandon_confirmation_open=true
			hud.show_abandon()
		"abandon": finish_run(false, "Run abandoned. Carried items were lost.")
		"drop":
			if phase == Phase.PAUSED and pending_cache_id.is_empty() and not bag.is_empty():
				BackpackRules.discard(backpack_state,bag,bag.size()-1,int(profile.data.pack_level))
			hud.show_pause(self, true)
		"hq":
			phase = Phase.HQ
			inventory_open = false
			menu_camera.make_current()
			hud.show_hq(self)

func _request_quit_confirmation() -> void:
	if phase not in [Phase.HQ, Phase.PAUSED] or inventory_open or not pending_cache_id.is_empty() or not pending_result_save.is_empty(): return
	quit_confirmation_open = true
	hud.show_quit_confirmation(self)

func _cancel_quit_confirmation() -> void:
	if not quit_confirmation_open: return
	quit_confirmation_open = false
	if phase == Phase.HQ: hud.show_hq(self)
	elif phase == Phase.PAUSED: hud.show_pause(self, map_open)

func _refresh_operations() -> void:
	if inventory_open:
		hud.show_inventory(self)
	else:
		hud.show_hq(self)

func open_inventory() -> void:
	GameInput.require_release()
	player.reset_controller_intents()
	if not pending_cache_id.is_empty():
		close_cache_choice()
		return
	if phase == Phase.RAID:
		pause_run(false)
	if phase != Phase.HQ and phase != Phase.PAUSED:
		return
	if not pending_cache_id.is_empty():
		return
	inventory_open = true
	_capture_weapon_ammunition()
	_flush_weapon_save()
	map_open = false
	hud.show_inventory(self)

func close_inventory() -> void:
	if not inventory_open:
		return
	inventory_open = false
	if phase == Phase.HQ:
		hud.show_hq(self)
	elif phase == Phase.PAUSED:
		resume_run()

func discard_cargo(index: int) -> bool:
	if phase != Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or index < 0 or index >= bag.size():
		return false
	if not BackpackRules.discard(backpack_state, bag, index, int(profile.data.pack_level)):
		announce("Remove cargo before discarding this backpack.",3.0)
		return false
	_refresh_magazine_cargo()
	hud.show_inventory(self)
	return true

func can_retry_deployment_save() -> bool:
	return phase == Phase.HQ and navigation.ready and pending_result_save.is_empty() and profile.last_error in ["Could not write the save. Your previous save is unchanged.", "Could not replace the save. Your previous save is unchanged."]

func start_run(retry_save: bool = false) -> void:
	if deployment_pending or phase != Phase.HQ or not navigation.ready or not pending_result_save.is_empty():
		return
	if retry_save and not can_retry_deployment_save(): return
	_pause_after_deployment = false
	deployment_pending = true
	var loading_ui := get_tree().get_first_node_in_group("shinrai_loading_ui")
	if loading_ui != null:
		loading_ui.begin("Entering the park")
		await RenderingServer.frame_post_draw
	# Finish an HQ weapon swap before committing and applying the free kit.
	while player.weapon_transition_pending:
		await get_tree().process_frame
	var extra_medkit: bool = profile.data.prepared_medkit
	if retry_save:
		# Recheck after the loading-frame yield; never clear a newer protected error.
		if not can_retry_deployment_save():
			deployment_pending = false
			_pause_after_deployment = false
			if loading_ui != null: loading_ui.finish()
			if not pending_result_save.is_empty(): hud.show_pending_result(self)
			elif phase == Phase.HQ: hud.show_hq(self)
			return
		profile.last_error = ""
	var staged_kit: Array = profile.data.get("field_kit",[]).duplicate(true)
	var starter_supplies := bool(profile.data.get("starter_pending",false))
	if not profile.begin_run():
		deployment_pending = false
		_pause_after_deployment = false
		if loading_ui != null: loading_ui.finish()
		hud.show_hq(self)
		return
	rng.randomize()
	_clear_enemies()
	bag.assign(staged_kit)
	pending_magazine.clear()
	field_loadout = profile.data.loadout.duplicate(true)
	if starter_supplies:
		var fruit_id: String = ["garden_mikan","garden_persimmon"][rng.randi_range(0,1)]
		var fruit := FruitHarvest.spec(fruit_id)
		Food.seed(fruit)
		bag.append(fruit)
		bag.append(LootContainers.spec("bandage"))
	backpack_state = BackpackRules.new_state("run-%d" % int(profile.data.runs))
	backpack_state.clothing = profile.data.clothing.duplicate(true)
	player.equipped_clothing = backpack_state.clothing
	inventory_open = false
	relays = 0
	track_extraction = false
	selected_destination = ""
	pending_cache_id = ""
	cache_release_id = ""
	medkits = 1 if extra_medkit else 0
	medical_pouch = {"bandage":0,"tourniquet":0,"splint":0}
	remaining = RAID_SECONDS
	var retained_illness := metabolism.illness_snapshot()
	metabolism.reset()
	metabolism.restore_illness(retained_illness)
	fruit_harvest.begin_raid(str(profile.data.runs))
	_metabolic_combat = false
	_metabolic_sample = 0.0
	run_time = 0.0
	healing = 0.0
	hold_progress = 0.0
	extraction_progress = 0.0
	extraction_id = ""
	hold_id = ""
	last_damage_at = -100.0
	_reset_site_spawns()
	player.alive = true
	player.reset_medical()
	_restore_weapon_loadout()
	_refresh_magazine_cargo()
	player.kills = 0
	player.reloading = false
	player.reload_time = 0.0
	player.ads = false
	player.ads_blend = 0.0
	player.fire_cooldown = 0.0
	player.damage_flash = 0.0
	player.clear_stun()
	player.velocity = Vector3.ZERO
	player.position = navigation.nearest(Vector3(0, 0.2, 160))
	last_safe = player.position
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.reset_survival()
	_previous_stamina = player.stamina
	player.set_cargo_mass(0.0, cargo_limit_kg())
	refresh_guidance()
	for point: Vector3 in guidance_path:
		if point.distance_to(player.position) > 12.0:
			player.look_at(Vector3(point.x, player.position.y, point.z))
			break
	player.camera.make_current()
	player._update_hud()
	# Remain in HQ with actors locked until the first native raid view is drawn.
	_spawn_patrols()
	var entry_guard: Node3D = park.get_node_or_null("K17_EntryGuard") as Node3D
	if entry_guard != null:
		player.look_at(Vector3(entry_guard.global_position.x, player.global_position.y, entry_guard.global_position.z))
	hud.show_raid()
	_set_actors_enabled(false)
	if loading_ui != null:
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
	phase = Phase.RAID
	# A focus loss during loading remains paused even if focus returned meanwhile.
	if _pause_after_deployment:
		pause_run(false)
	else:
		_set_actors_enabled(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	deployment_pending = false
	_pause_after_deployment = false
	if loading_ui != null: loading_ui.finish()
	announce("TEST BACKPACK SPAWNS · guaranteed when real models are installed" if backpack_test_enabled else "Recover a relay · reach extraction", 5.0)

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT: return
	GameInput.require_release()
	if is_instance_valid(player):player.reset_controller_intents()
	if deployment_pending:
		_pause_after_deployment = true
	elif phase == Phase.RAID:
		pause_run(false)

func _exit_tree() -> void:
	if is_instance_valid(park): _persist_food_state(true)

func _input(event: InputEvent) -> void:
	if not GameInput.application_focused():return
	var loading_ui := get_tree().get_first_node_in_group("shinrai_loading_ui")
	if deployment_pending or (loading_ui != null and loading_ui.active): return
	if not pending_result_save.is_empty(): return
	if event is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit and event.keycode not in [KEY_ESCAPE,KEY_TAB]:return
	var pad_back: bool=event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B
	var pause_pressed: bool=GameInput.pressed(event,"pause")
	var map_pressed: bool=GameInput.pressed(event,"map")
	var inventory_pressed: bool=GameInput.pressed(event,"inventory")
	var back: bool=pad_back or pause_pressed or map_pressed
	if GameInput.released(event,"interact"):cache_release_id=""
	# Resolve only the topmost modal. Navigation/accept goes on to native GUI.
	if quit_confirmation_open:
		if back:
			_cancel_quit_confirmation();get_viewport().set_input_as_handled()
		return
	if abandon_confirmation_open:
		if back:
			abandon_confirmation_open=false;hud.show_pause(self,false);get_viewport().set_input_as_handled()
		return
	if not pending_cache_id.is_empty():
		if back or inventory_pressed:
			close_cache_choice();get_viewport().set_input_as_handled()
		elif event is InputEventKey and GameInput.pressed(event,"interact") and cache_release_id.is_empty():
			resolve_cache_choice("take");get_viewport().set_input_as_handled()
		return
	if back and inventory_open and is_instance_valid(controller_ui) and controller_ui.cancel_topmost():
		get_viewport().set_input_as_handled();return
	# Text entry retains its letters on keyboard; a pad View press still closes.
	if inventory_pressed and not (event is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit):
		if inventory_open:close_inventory()
		else:open_inventory()
		get_viewport().set_input_as_handled();return
	if back:
		if pad_back and phase==Phase.RAID and not inventory_open:return
		if inventory_open:
			# Collected map returns to its inventory before leaving the inventory.
			if map_open:map_open=false;hud.show_inventory(self)
			else:close_inventory()
		elif phase==Phase.RAID and not pad_back:pause_run(map_pressed)
		elif phase==Phase.PAUSED:
			if map_open and pad_back:map_open=false;hud.show_pause(self,false)
			else:resume_run()
		get_viewport().set_input_as_handled()
		return
	if phase!=Phase.RAID or inventory_open:return
	if GameInput.pressed(event,"heal") and GameInput.gameplay_ready() and can_heal():player.set_medical_active(true)
	if GameInput.pressed(event,"weapon_next") and GameInput.gameplay_ready():
		cycle_carried_weapon();get_viewport().set_input_as_handled()
	elif GameInput.pressed(event,"track"):
		track_extraction=not track_extraction;selected_destination="";refresh_guidance()
		announce("Tracking remaining relays" if tracked_objective().get("kind","")=="relay" else "Tracking extraction gates",2.0)
		get_viewport().set_input_as_handled()

func cycle_carried_weapon() -> bool:
	if phase != Phase.RAID or inventory_open or not pending_cache_id.is_empty() or player.weapon_transition_pending or player.reloading or player.healing_active or player.mantle_active or not player.alive: return false
	var state := active_weapon_loadout()
	var available: Array[String] = []
	for id: String in state.weapons:
		if player.can_equip_weapon(id): available.append(id)
	if available.size() < 2: return false
	_capture_weapon_ammunition()
	var id: String = available[(available.find(str(player.weapon_id))+1)%available.size()]
	if not player.apply_weapon_loadout(id,state.weapons[id]): return false
	if player.physical_magazines and phase in [Phase.RAID,Phase.PAUSED]: _refresh_magazine_cargo()
	state.equipped = id
	state.revision += 1
	announce(str(WeaponCatalog.weapon(id).title),1.5)
	return true

func pause_run(with_map: bool) -> void:
	if not pending_cache_id.is_empty(): close_cache_choice()
	if phase != Phase.RAID:
		return
	phase = Phase.PAUSED
	_persist_food_state(true)
	inventory_open = false
	refresh_guidance()
	map_open = with_map
	_set_actors_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause(self, with_map)

func resume_run() -> void:
	abandon_confirmation_open=false
	if not pending_result_save.is_empty(): return
	if phase != Phase.PAUSED:
		return
	if not pending_cache_id.is_empty():
		cache_release_id = pending_cache_id if GameInput.down("interact") else ""
	pending_cache_id = ""
	inventory_open = false
	phase = Phase.RAID
	_set_actors_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_raid()

func _set_actors_enabled(enabled: bool) -> void:
	GameInput.require_release()
	player.reset_controller_intents()
	fruit_harvest.require_release()
	for crew: Node in get_tree().get_nodes_in_group("scav_squad_directors"):
		crew.set_active(enabled)
	if is_instance_valid(pitch_gate): pitch_gate.set_active(enabled)
	if is_instance_valid(clubhouse_doors): clubhouse_doors.set_active(enabled)
	building_access.set_active(enabled)
	_cancel_healing()
	hold_progress = 0.0
	hold_id = ""
	progress_ratio = 0.0
	player.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	player.weapon_input_locked = not enabled or cache_input_release_pending
	player.ads = false
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	fruit_harvest.sample_input()
	if phase != Phase.RAID:
		return
	# Keep player physics, enemies, injuries and the raid clock live while searching.
	# A held UI click must be released before it can become a weapon shot.
	if cache_input_release_pending and GameInput.buttons_released() and GameInput.gameplay_ready():
		cache_input_release_pending = false
		player.weapon_input_locked = false
	if not pending_cache_id.is_empty():
		var searched := pending_cache()
		if searched.is_empty() or searched.done or not _site_in_reach(searched) or absf(player.global_position.y - searched.position.y) > 2.5:
			close_cache_choice()
	_capture_weapon_ammunition()
	weapon_save_elapsed += delta
	if weapon_save_pending and weapon_save_elapsed >= 1.0:
		_flush_weapon_save()
	player.set_cargo_mass(cargo_mass_kg(), cargo_limit_kg())
	remaining = maxf(0.0, remaining - delta)
	run_time += delta
	_advance_food_state(delta)
	_update_metabolism(delta)
	_advance_medical(delta)
	if phase != Phase.RAID or not player.alive: return
	notice_time = maxf(0.0, notice_time - delta)
	if remaining <= 0.0:
		finish_run(false, "The park locked down before you reached extraction.")
		return
	_keep_player_in_playable_area()
	ResidentialLoot.process_refills(self)
	prompt_text = ("SWIM · LS + RS · A rise · B dive" if GameInput.gamepad_active() else "SWIM · WASD + look · Space rise · Ctrl dive") if player != null and player.is_swimming else ""
	progress_ratio = 0.0
	_update_interaction(delta)
	if phase != Phase.RAID:
		return
	_update_healing(delta)
	_update_extraction(delta)
	if phase != Phase.RAID: return
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
		if distance < best and _site_in_reach(site):
			best = distance
			found = site
	return found

func _site_in_reach(site: Dictionary) -> bool:
	if not ResidentialLoot.reachable(player, site): return false
	if _distance(site.position)>4.2 or not ContextLoot.reachable(player,site): return false
	if site.get("requires_drop_los",false):
		if absf(player.global_position.y-site.position.y)>2.5 or not is_instance_valid(player.camera): return false
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,site.position,1,[player.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	return true

func _distance(point: Vector3) -> float:
	return Vector2(player.position.x, player.position.z).distance_to(Vector2(point.x, point.z))

func _update_interaction(delta: float) -> void:
	if not pending_cache_id.is_empty():
		building_access.require_release()
		prompt_text = ""
		hold_progress = 0.0
		return
	var site := nearest_site()
	var site_distance := INF if site.is_empty() else _distance(site.position)
	var fruit := fruit_harvest.find_target(self)
	var fruit_distance := float(fruit.get("distance", INF))
	var eligible: bool = healing <= 0.0 and not player.reloading and run_time-last_damage_at > 0.8
	var pressed := GameInput.down("interact")
	if not pressed: cache_release_id = ""
	var access := building_access.find_target(player)
	var access_distance := float(access.get("distance",INF))
	var door_distance := INF
	var gate_distance := INF
	if is_instance_valid(clubhouse_doors): door_distance = clubhouse_doors.interaction_distance(player)
	if is_instance_valid(pitch_gate) and pitch_gate.reachable(player.global_position):
		gate_distance = absf(pitch_gate.to_local(player.global_position).z)
	var door_prompt := ""
	var gate_prompt := ""
	# Update both key latches every frame, including when another target wins.
	if is_instance_valid(clubhouse_doors):
		door_prompt = clubhouse_doors.consume_interaction(player,minf(access_distance,minf(fruit_distance,minf(site_distance,gate_distance))),eligible,pressed)
	if is_instance_valid(pitch_gate):
		gate_prompt = pitch_gate.consume_interaction(player,minf(access_distance,minf(fruit_distance,minf(site_distance,door_distance-.001))),eligible,pressed)
	var access_prompt := building_access.consume_interaction(access,player,minf(door_distance,minf(gate_distance,minf(fruit_distance,site_distance))),eligible,pressed)
	if not door_prompt.is_empty() or not gate_prompt.is_empty() or not access_prompt.is_empty():
		prompt_text = (door_prompt if not door_prompt.is_empty() else gate_prompt if not gate_prompt.is_empty() else access_prompt).replace("E  ·",GameInput.hint("E")+"  ·").replace("E ·",GameInput.hint("E")+" ·")
		hold_progress = 0.0
		hold_id = ""
		progress_ratio = 0.0
		return
	if not fruit.is_empty() and fruit_distance < site_distance:
		var fruit_result := fruit_harvest.interact(self, fruit, eligible)
		prompt_text = str(fruit_result.prompt)
		hold_progress = 0.0
		hold_id = ""
		progress_ratio = 0.0
		return
	if site.is_empty() or healing > 0.0:
		hold_progress = 0.0
		hold_id = ""
		return
	if site.id != hold_id:
		hold_progress = 0.0
		hold_id = site.id
	var loose_pickup: bool = site.kind == "cache" and site.has("pickup_node") and not LootContainers.is_container(site)
	prompt_text = GameInput.hint("E")+"  ·  " + ("Pick up" if loose_pickup else "Inspect" if site.kind == "cache" and site.discovered else "Search" if site.kind == "cache" else "Recover relay")
	if pressed and (site.kind != "cache" or site.id != cache_release_id) and run_time - last_damage_at > 0.8 and not player.reloading:
		hold_progress += delta
		var required := 4.0 if site.kind == "relay" else (0.25 if loose_pickup else 0.3 if site.discovered else 2.0)
		progress_ratio = hold_progress / required
		if hold_progress >= required:
			if site.kind == "cache":
				open_cache_choice(site)
			else:
				complete_site(site)
	else:
		hold_progress = 0.0

func open_cache_choice(site: Dictionary) -> bool:
	if phase != Phase.RAID or site.is_empty() or site.kind != "cache" or site.done or not _site_in_reach(site):
		return false
	# Loose objects go straight into cargo; only containers need a search surface.
	if site.has("pickup_node") and not LootContainers.is_container(site) and can_take_site(site):
		cache_release_id = site.id if GameInput.down("interact") else ""
		return complete_site(site)
	# Keep the same item in an inspected compartment when the player leaves it.
	site.discovered = true
	pending_cache_id = site.id
	cache_input_release_pending = false
	cache_release_id = site.id if GameInput.down("interact") else ""
	hold_progress = 0.0
	hold_id = ""
	progress_ratio = 0.0
	_cancel_healing()
	GameInput.require_release()
	player.reset_controller_intents()
	player.weapon_input_locked = true
	player.ads = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_cache_choice(self, site)
	return true

func close_cache_choice() -> void:
	if pending_cache_id.is_empty(): return
	GameInput.require_release()
	player.reset_controller_intents()
	cache_release_id = pending_cache_id if GameInput.down("interact") else ""
	pending_cache_id = ""
	hold_progress = 0.0
	hold_id = ""
	progress_ratio = 0.0
	cache_input_release_pending = true
	player.weapon_input_locked = true
	if phase == Phase.RAID and player.alive:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.show_raid()

func pending_cache() -> Dictionary:
	for site: Dictionary in sites:
		if site.id == pending_cache_id and site.kind == "cache":
			return site
	return {}

func resolve_cache_choice(choice: String, replace_index: int = -1) -> bool:
	if phase != Phase.RAID or pending_cache_id.is_empty():
		return false
	var site := pending_cache()
	if site.is_empty() or site.done or not player.alive or not _site_in_reach(site):
		return false
	if choice == "leave":
		close_cache_choice()
		announce("Left %s contents in place." % str(site.get("container_title","yellow backpack")).to_lower() if LootContainers.is_container(site) else "Left %s in place." % site.loot.title, 3.0)
		return true
	if choice != "take" and choice != "swap":
		return false
	if choice == "take" and not can_take_site(site):
		return false
	if choice == "swap" and (replace_index < 0 or replace_index >= bag.size()):
		return false
	var accepted := complete_site(site, replace_index if choice == "swap" else -1)
	if accepted:
		if LootContainers.is_container(site) and not site.done:
			hud.show_cache_choice(self, site)
		else:
			close_cache_choice()
	return accepted

func complete_site(site: Dictionary, replace_index: int = -1) -> bool:
	var choosing_cache: bool = phase == Phase.PAUSED and site.get("kind", "") == "cache" and pending_cache_id == site.get("id", "")
	if (phase != Phase.RAID and not choosing_cache) or site.is_empty() or site.done or not _site_in_reach(site):
		return false
	if replace_index < -1 or (replace_index >= 0 and (site.kind != "cache" or replace_index >= bag.size())):
		return false
	if site.kind == "cache" and not can_take_site(site, replace_index):
		return false
	if not str(site.get("loot",{}).get("weapon_id", "")).is_empty():
		return _recover_world_weapon(site)
	if not str(site.get("loot",{}).get("optic_id", "")).is_empty():
		return _recover_world_optic(site)
	if LootContainers.is_container(site):
		var recovered: Dictionary = site.loot.duplicate(true)
		if not LootContainers.remove_selected(site): return false
		if replace_index >= 0: bag[replace_index] = recovered
		else: bag.append(recovered)
		if BackpackRules.equipped_id(backpack_state, bag).is_empty(): backpack_state.equipped_uid = ""
		if site.done and selected_destination == site.id: selected_destination = ""
		hold_progress = 0.0
		announce("Recovered %s%s" % [recovered.title, " · backpack empty" if site.done else ""], 3.0)
		refresh_guidance()
		return true
	var is_backpack := BackpackRules.PACKS.has(str(site.get("backpack_id","")))
	if is_backpack and not BackpackRules.pickup(backpack_state,bag,str(site.backpack_id),int(profile.data.pack_level),_backpack_model_ready(site),true,replace_index):
		return false
	site.done = true
	if selected_destination == site.id:
		selected_destination = ""
	hold_progress = 0.0
	if site.kind == "relay":
		relays += 1
		track_extraction = true
		announce("Relay %d/3 · extraction available" % relays, 3.0)
		_alert_nearby(site.position, 85.0)
	elif is_backpack:
		if is_instance_valid(site.get("pickup_node")): site.pickup_node.hide()
		announce("Recovered %s · %d slots / %.1f kg cargo" % [site.loot.title,capacity(),cargo_limit_kg()],3.0)
	else:
		if replace_index >= 0:
			bag[replace_index] = site.loot.duplicate(true)
		else:
			bag.append(site.loot.duplicate(true))
		if BackpackRules.equipped_id(backpack_state,bag).is_empty(): backpack_state.equipped_uid=""
		var ammo_bonus := mini(maxi(int(site.get("ammo_bonus", 15)), 0), maxi(240 - player.reserve, 0))
		player.reserve += ammo_bonus
		if is_instance_valid(site.get("pickup_node")): site.pickup_node.hide()
		announce("Recovered %s%s" % [site.loot.title, " · +%d rounds" % ammo_bonus if ammo_bonus > 0 else ""], 3.0)
	if WeaponSupply.MAGAZINES.has(str(site.get("loot",{}).get("id",""))):_refresh_magazine_cargo()
	ResidentialLoot.collected(self, site)
	refresh_guidance()
	return true

func refresh_guidance() -> void:
	guidance_elapsed = 0.0
	guidance_path.clear()
	guidance_distance = 0.0
	var objective := tracked_objective()
	if objective.is_empty():
		return
	guidance_path = navigation.path(player.position, objective.position)
	# Deployment still uses the full path for initial facing and entry placement.
	if (phase == Phase.RAID or phase == Phase.PAUSED) and objective.get("kind", "") == "relay" and not objective.get("done", false):
		var relay_position := Vector2(objective.position.x, objective.position.z)
		for index: int in range(guidance_path.size()):
			var waypoint := Vector2(guidance_path[index].x, guidance_path[index].z)
			if waypoint.distance_to(relay_position) >= 4.2:
				continue
			# Match nearest_site ordering/range; doors and gates retain their own priority.
			var nearest: Dictionary = {}
			var best := 4.2
			for site: Dictionary in sites:
				if site.done:
					continue
				var distance := waypoint.distance_to(Vector2(site.position.x, site.position.z))
				if distance < best:
					best = distance
					nearest = site
			if not nearest.is_empty() and nearest.id == objective.id:
				guidance_path = guidance_path.slice(0, index + 1)
				break
	for index: int in range(1, guidance_path.size()):
		guidance_distance += guidance_path[index - 1].distance_to(guidance_path[index])

func can_heal() -> bool:
	var item := treatment_item if not treatment_item.is_empty() else "medkit"
	var part: String = treatment_part if not treatment_part.is_empty() else player.medical.treatment_target(item)
	return phase == Phase.RAID and player.alive and medical_count(item) > 0 and player.medical.can_treat(item, part) and run_time - last_damage_at > 1.0 and hold_progress == 0.0 and not player.reloading and player.stun_remaining <= 0.0 and not player.mantle_active and player.is_on_floor()

func _cancel_healing() -> void:
	healing = 0.0
	treatment_item = ""
	treatment_part = ""
	treatment_automatic = false
	if is_instance_valid(player): player.set_medical_active(false)

func _advance_healing(delta: float, requested: bool, firing: bool) -> void:
	if not requested or firing or not can_heal():
		_cancel_healing()
		return
	if treatment_item.is_empty():
		treatment_item = "medkit"
		treatment_part = player.medical.treatment_target("medkit")
	var spec: Dictionary = Medical.TREATMENTS[treatment_item]
	player.set_medical_active(true)
	healing += maxf(0.0, delta)
	prompt_text = "%s · %s · fire to cancel" % [spec.title, Medical.LABELS[treatment_part]]
	progress_ratio = healing / float(spec.seconds)
	if healing >= float(spec.seconds):
		var item := treatment_item
		var part := treatment_part
		# State and stock are checked again at completion; no cost on cancel.
		if player.medical.can_treat(item, part) and _consume_medical(item):
			player.medical.treat(item, part)
			player._sync_medical_health()
			announce("%s applied · %s" % [spec.title, Medical.LABELS[part]], 2.5)
		_cancel_healing()

func _update_healing(delta: float) -> void:
	if not pending_cache_id.is_empty(): return
	_advance_healing(delta, treatment_automatic or GameInput.down("heal"), GameInput.down("fire"))

## True while the start-of-raid grace window is active.
func insertion_grace() -> bool:
	return phase == Phase.RAID and run_time < INSERTION_GRACE_SECONDS

func _update_extraction(delta: float) -> void:
	if not pending_cache_id.is_empty():
		extraction_progress = 0.0
		return
	var exit_point: Dictionary = {}
	for candidate: Dictionary in exits:
		if _distance(candidate.position) <= 8.0:
			exit_point = candidate
	if exit_point.is_empty() or relays == 0:
		if insertion_grace():
			prompt_text = "Insertion · hostiles unaware for %d s · move off the entry" % int(ceil(INSERTION_GRACE_SECONDS - run_time))
		elif not exit_point.is_empty():
			prompt_text = "Extraction locked · recover a relay"
		extraction_progress = 0.0
		extraction_id = ""
		return
	if extraction_id != exit_point.id:
		extraction_id = exit_point.id
		extraction_progress = 0.0
		_alert_nearby(exit_point.position, 100.0)
	if run_time - last_damage_at < 2.0:
		extraction_progress = 0.0
		prompt_text = "Extraction interrupted · break contact"
		return
	extraction_progress += delta
	prompt_text = "Extracting · %ds" % ceili(15.0 - extraction_progress)
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
	if not pending_result_save.is_empty() or (phase != Phase.RAID and phase != Phase.PAUSED): return
	pending_cache_id=""
	inventory_open=false
	phase=Phase.PAUSED
	_set_actors_enabled(false)
	if not _cancel_magazine_reload():
		if extracted:
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			hud.show_pause(self,false)
			announce("Make space for the reserved magazine before extracting.",4.0)
			return
		# Failed raids already lose carried cargo; a reserved spare follows that same existing rule.
		pending_magazine.clear()
		_reload_outgoing_magazine.clear()
		_reload_magazine_source_index=-1
	_capture_weapon_ammunition()
	_sync_food_illness()
	var bonus := (150*relays+(300 if relays==3 else 0)) if extracted else 0
	pending_result_save={"extracted":extracted,"reason":reason,"bonus":bonus}
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_attempt_result_save()

func can_retry_result_save() -> bool:
	return not pending_result_save.is_empty() and (profile.last_error.is_empty() or profile.last_error.begins_with("Could not write the save.") or profile.last_error.begins_with("Could not replace the save."))

func retry_result_save() -> bool:
	if not can_retry_result_save(): return false
	# Clear only transient write/rename failures after an explicit user retry.
	# A corrupt/unreadable profile's protective saving-disabled guard stays intact.
	profile.last_error=""
	return _attempt_result_save()

func _attempt_result_save() -> bool:
	if pending_result_save.is_empty(): return false
	var outcome := pending_result_save.duplicate(true)
	if not profile.complete_run(bool(outcome.extracted),bag,int(outcome.bonus),field_loadout,backpack_state.get("clothing",{})):
		hud.show_pending_result(self)
		return false
	pending_result_save.clear()
	phase=Phase.RESULT
	weapon_save_pending=false
	hud.show_result(self,bool(outcome.extracted),str(outcome.reason),int(outcome.bonus))
	return true

func announce(text: String, duration: float = 4.0) -> void:
	notice = text
	notice_time = duration

func _on_damage(_amount: float) -> void:
	last_damage_at = run_time
	metabolism.stress(8.0)
	if not pending_cache_id.is_empty(): close_cache_choice()
	_cancel_healing()
	hold_progress = 0.0

func _on_shot() -> void:
	# Scavs only react to gunfire once the insertion grace has passed.
	if not insertion_grace():
		for crew: Node in get_tree().get_nodes_in_group("scav_squad_directors"):
			crew.player_fired()
	metabolism.stress()
	_capture_weapon_ammunition()
	_cancel_healing()
	hold_progress = 0.0
	_alert_nearby(player.position, 65.0)

func active_weapon_loadout() -> Dictionary:
	return field_loadout if not field_loadout.is_empty() and phase not in [Phase.HQ,Phase.BOOT] else profile.data.loadout

func _restore_weapon_loadout() -> bool:
	var state := active_weapon_loadout()
	var id := str(state.equipped)
	if id.is_empty() or not state.weapons.has(id): return player.unequip_weapon()
	if not player.can_equip_weapon(id): return false
	return player.apply_weapon_loadout(id,state.weapons[id])

func _recover_world_weapon(site: Dictionary) -> bool:
	var id := str(site.loot.get("weapon_id",""))
	var state := active_weapon_loadout()
	if state.weapons.has(id) or not player.can_equip_weapon(id) or player.weapon_transition_pending: return false
	var record: Dictionary = site.loot.get("weapon_record",WeaponState.recovered_weapon(id)).duplicate(true)
	if record.is_empty(): return false
	_capture_weapon_ammunition()
	if not player.apply_weapon_loadout(id,record): return false
	if player.physical_magazines and phase in [Phase.RAID,Phase.PAUSED]: _refresh_magazine_cargo()
	state.weapons[id] = record
	state.equipped = id
	state.revision += 1
	if LootContainers.is_container(site): LootContainers.remove_selected(site)
	else:
		site.done = true
		if is_instance_valid(site.get("pickup_node")): site.pickup_node.hide()
	if site.done and selected_destination == site.id: selected_destination = ""
	hold_progress = 0.0
	announce("Recovered %s · extract to keep it" % str(WeaponCatalog.weapon(id).title),4.0)
	ResidentialLoot.collected(self, site)
	refresh_guidance()
	return true

func _capture_weapon_ammunition() -> void:
	var id := str(player.weapon_id)
	var state := active_weapon_loadout()
	if not state.weapons.has(id): return
	var record: Dictionary = state.weapons[id]
	if int(record.ammo)!=player.ammo or int(record.reserve)!=player.reserve or bool(record.chambered)!=player.chambered or bool(record.magazine_inserted)!=player.magazine_inserted or bool(record.bolt_locked)!=player.bolt_locked or record.get("inserted_magazine",{})!=player.inserted_magazine:
		WeaponState.set_ammunition(state,id,player.ammo,player.reserve,player.chambered,player.magazine_inserted,player.bolt_locked,player.inserted_magazine)
		weapon_save_pending = phase == Phase.HQ

func _flush_weapon_save() -> bool:
	if not weapon_save_pending: return profile.last_error.is_empty()
	weapon_save_elapsed = 0.0
	if profile.save_profile():
		weapon_save_pending = false
		return true
	announce(profile.last_error)
	return false

func move_weapon_optic(optic_id: String, target: String, revision: int) -> bool:
	if not inventory_open or phase not in [Phase.HQ,Phase.PAUSED] or not pending_cache_id.is_empty(): return false
	_capture_weapon_ammunition()
	var state := active_weapon_loadout()
	var previous := state.duplicate(true)
	if not WeaponState.move_optic(state,optic_id,target,revision): return false
	var current := str(state.equipped)
	if (not current.is_empty() and not player.apply_weapon_loadout(current,state.weapons[current])) or (phase==Phase.HQ and not profile.save_profile()):
		if phase==Phase.HQ: profile.data.loadout = previous
		else: field_loadout = previous
		return false
	weapon_save_pending = false
	if player.physical_magazines and phase in [Phase.RAID,Phase.PAUSED]: _refresh_magazine_cargo()
	return true

func equip_weapon(id: String, revision: int) -> bool:
	if not inventory_open or phase not in [Phase.HQ,Phase.PAUSED] or not pending_cache_id.is_empty() or not player.can_equip_weapon(id) or player.reloading: return false
	_capture_weapon_ammunition()
	var state := active_weapon_loadout()
	var previous := state.duplicate(true)
	if not WeaponState.equip(state,id,revision,true): return false
	if not player.apply_weapon_loadout(id,state.weapons[id]) or (phase==Phase.HQ and not profile.save_profile()):
		if phase==Phase.HQ: profile.data.loadout = previous
		else: field_loadout = previous
		return false
	weapon_save_pending = false
	if player.physical_magazines and phase in [Phase.RAID,Phase.PAUSED]: _refresh_magazine_cargo()
	return true

func _alert_nearby(point: Vector3, radius: float) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.hear_noise(point, radius)

func _clear_enemies() -> void:
	for crew: Node in get_tree().get_nodes_in_group("scav_squad_directors"):
		crew.queue_free()
	for director: Node in get_tree().get_nodes_in_group("police_drone_directors"):
		director.queue_free()
	for enemy: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		enemy.queue_free()

func _spawn_patrols() -> void:
	var director := PoliceGroups.new()
	director.name = "PoliceDroneGroups"
	director.raid = self
	park.add_child(director)
	var crew:=ScavSquad.new()
	crew.name="ScavPatrolCrew"
	crew.raid=self
	park.add_child(crew)

func _spawn_entry_guard() -> void:
	# Put one of the supplied K17s in the first view down the south approach.
	# Keep the two guards at each relay, and use the same combat controller.
	var placement: Dictionary = _find_visible_entry_guard_position()
	if placement.is_empty():
		push_warning("K17 entry guard could not find a clear, visible park position")
		return
	var anchor: Vector3 = placement.position
	var route: Array[Vector3] = [anchor]
	var enemy := Enemy.new()
	enemy.name = "K17_EntryGuard"
	enemy.approved_visual = enemy_visual
	enemy.position = Vector3(anchor.x, anchor.y - 0.24, anchor.z)
	enemy.configure(player, 1, self, route)
	enemy.add_to_group("extraction_hostiles")
	park.add_child(enemy)
	enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
	enemy.attack_cooldown = 1.5 # Give the player time to recognize the drone before its first shot.

func _find_visible_entry_guard_position() -> Dictionary:
	if guidance_path.size() < 2:
		return {}
	var camera_eye: Vector3 = player.camera.global_position
	var camera_forward: Vector3 = -player.camera.global_transform.basis.z
	var visible_dot: float = cos(deg_to_rad(player.camera.fov * 0.5 - 4.0))
	var space: PhysicsDirectSpaceState3D = park.get_world_3d().direct_space_state
	var clearance := PhysicsShapeQueryParameters3D.new()
	var clearance_shape := SphereShape3D.new()
	clearance_shape.radius = 0.95
	clearance.shape = clearance_shape
	clearance.collision_mask = 1
	clearance.exclude = [player.get_rid()]
	for path_distance: float in [22.0, 20.0, 24.0, 18.0]:
		var traveled := 0.0
		for index: int in range(1, guidance_path.size()):
			var start: Vector3 = guidance_path[index - 1]
			var finish: Vector3 = guidance_path[index]
			var segment: Vector3 = finish - start
			segment.y = 0.0
			var segment_length: float = segment.length()
			if segment_length < 0.01:
				continue
			if traveled + segment_length < path_distance:
				traveled += segment_length
				continue
			var along: Vector3 = start.lerp(finish, (path_distance - traveled) / segment_length)
			var lateral := Vector3(-segment.z, 0.0, segment.x).normalized()
			# Try the lawn shoulders; keep the drone off the paved walking route.
			for side: float in [1.0, -1.0, 1.4, -1.4]:
				var candidate: Vector3 = navigation.nearest(along + lateral * (5.0 * side))
				var horizontal_distance: float = Vector2(candidate.x, candidate.z).distance_to(Vector2(player.position.x, player.position.z))
				if horizontal_distance < 18.0 or horizontal_distance > 23.0:
					continue
				if park._is_near_destination_path(Vector2(candidate.x, candidate.z) / park.LAYOUT_SCALE, 0.1):
					continue
				var eye_target: Vector3 = candidate + Vector3.UP * 1.25
				if camera_forward.dot((eye_target - camera_eye).normalized()) < visible_dot:
					continue
				clearance.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * 1.1)
				if not space.intersect_shape(clearance, 1).is_empty():
					continue
				var sight: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera_eye, eye_target, 1)
				sight.exclude = [player.get_rid()]
				if not space.intersect_ray(sight).is_empty():
					continue
				# A decorative object can clear the camera ray yet still block K17's higher eye.
				var return_sight: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 1.52, player.global_position + Vector3.UP * 1.25, 1)
				var blocker: Dictionary = space.intersect_ray(return_sight)
				if not blocker.is_empty() and blocker.get("collider") != player:
					continue
				return {"position": candidate}
			break
	return {}

func get_path_world(from: Vector3, to: Vector3) -> PackedVector3Array:
	var route := navigation.path(from, to)
	if is_instance_valid(pitch_gate) and pitch_gate.blocks_route(from,route): return PackedVector3Array()
	if is_instance_valid(clubhouse_doors) and clubhouse_doors.blocks_route(from,route): return PackedVector3Array()
	return route

func _inside_playable_area(point: Vector3) -> bool:
	if not point.is_finite() or point.y < -12.0:return false
	if absf(point.x)<=215.0 and absf(point.z)<=175.0:return true
	if not is_instance_valid(park):return false
	var corporate: Node=park.get_node_or_null("MidoriCorporateDistrict")
	if corporate != null and corporate.has_method("contains_world_point") and corporate.contains_world_point(point):return true
	for building: Node in get_tree().get_nodes_in_group("playable_buildings"):
		if building.contains_world_point(point):return true
	var street: Node=park.get_node_or_null("MidoriSouthStreet")
	if street==null or street.get("installed")!=true:return false
	var data: Variant=street.get("report")
	if not data is Dictionary:return false
	# These builders publish world-metre footprints. Keep the narrower later
	# sections separate so an expanded street does not also admit unbuilt land.
	var areas: Array=[data.get("landscape",{}).get("world_bounds",Rect2()),data.get("neighbourhood_ground",{}).get("bounds",Rect2()),data.get("court_ground",{}).get("bounds",Rect2())]
	for area: Variant in areas:
		if area is Rect2 and area.has_point(Vector2(point.x,point.z)):return true
	return false

func _keep_player_in_playable_area() -> void:
	var point:=player.global_position
	if not _inside_playable_area(point):
		player.global_position=last_safe
		player.velocity=Vector3.ZERO
		announce("Playable boundary. Returned to safe ground.",2.0)
	elif player.is_on_floor() and not player.is_swimming and not navigation.is_water(Vector2(point.x,point.z)):
		last_safe=point

func get_nearest_walkable_world(point: Vector3) -> Vector3:
	return navigation.nearest(point)

func get_search_positions_world(point: Vector3, count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index: int in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(navigation.nearest(point + Vector3(cos(angle), 0, sin(angle)) * 10.0))
	return points

func consume_coffee(index: int) -> bool:
	if phase != Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or index < 0 or index >= bag.size(): return false
	if bag[index].id != "coffee_cup": return false
	bag.remove_at(index)
	player.apply_coffee_boost()
	metabolism.consume("coffee_cup")
	hud.show_inventory(self)
	announce("Coffee boost · +4% max stamina and regeneration · 3 minutes", 4.0)
	return true

func open_collected_map() -> bool:
	if not inventory_open or (phase != Phase.HQ and phase != Phase.PAUSED) or not pending_cache_id.is_empty(): return false
	var owned := int(profile.data.stash.get("park_map",0))>0 if phase == Phase.HQ else false
	for item: Dictionary in bag:
		if item.id == "park_map": owned=true
	if not owned: return false
	map_open=true
	hud.show_collected_map(self)
	return true

func _reset_site_spawns() -> void:
	for old: Dictionary in sites.duplicate():
		if old.get("raid_drop",false):
			if is_instance_valid(old.get("pickup_node")):old.pickup_node.queue_free()
			sites.erase(old)
	var cache_items := ITEMS.filter(func(item: Dictionary) -> bool: return LootContainers.allows_spawn(str(item.id), "bench"))
	var backpack_spawns := BackpackRules.roll_spawns(backpack_state,rng.randf(),backpack_test_enabled,OS.has_feature("debug"))
	for site: Dictionary in sites:
		if bool(site.get("residential_loot", false)): continue
		if BackpackRules.PACKS.has(str(site.get("backpack_id",""))):
			site.spawned = bool(backpack_spawns[site.backpack_id]) and not bool(backpack_state.collected.get(site.backpack_id,false)) and _backpack_model_ready(site)
		else:
			site.spawned = rng.randf() < float(site.get("spawn_chance", 1.0)) if site.has("spawn_chance") else true
		site.done = not site.spawned
		if site.kind == "cache":
			if LootContainers.is_container(site):
				LootContainers.begin_run(site, rng, str(backpack_state.run_token))
				for item: Dictionary in site.contents: Food.ensure(item)
				LootContainers.sync_selection(site)
				if is_instance_valid(site.get("pickup_node")): site.pickup_node.visible = site.spawned
				continue
			site.loot = site.fixed_loot.duplicate(true) if site.has("fixed_loot") else cache_items[rng.randi_range(0, cache_items.size() - 1)].duplicate(true)
			Food.ensure(site.loot)
			if is_instance_valid(site.get("pickup_node")): site.pickup_node.visible = site.spawned
			site.discovered = false
	ResidentialLoot.begin_run(self, str(backpack_state.run_token))


func cargo_mass_kg() -> float:
	return 0.0 if phase == Phase.HQ else BackpackRules.cargo_mass(bag)

func cargo_item_mass(item: Dictionary) -> float:
	return BackpackRules.item_mass(item)

func cargo_limit_kg() -> float:
	return float(BackpackRules.limits(backpack_state,[] if phase == Phase.HQ else bag,int(profile.data.pack_level)).kg)

func equipped_backpack_id() -> String:
	return "" if phase == Phase.HQ else BackpackRules.equipped_id(backpack_state,bag)

func equip_backpack(uid: String) -> bool:
	if phase != Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty(): return false
	if not BackpackRules.equip(backpack_state,bag,uid,int(profile.data.pack_level)):
		announce("Remove cargo before changing to a smaller backpack.",3.0)
		return false
	hud.show_inventory(self)
	return true

func _backpack_model_ready(site: Dictionary) -> bool:
	var model := site.get("pickup_node") as Node3D
	var path := str(site.get("model_path",""))
	return is_instance_valid(model) and model.is_inside_tree() and path.ends_with(".glb") and ResourceLoader.exists(path) and model.scene_file_path == path

func register_backpack_pickup(id: String, model: Node3D, model_path: String) -> bool:
	# Asset owner supplies the real GLB instance at its grounded, distinct anchor.
	if phase not in [Phase.BOOT,Phase.HQ] or not BackpackRules.PACKS.has(id): return false
	if not is_instance_valid(model) or not model.is_inside_tree(): return false
	var site := {"id":"clubhouse_"+id,"title":"Collect "+str(BackpackRules.PACKS[id].title),"kind":"cache","position":model.global_position if is_instance_valid(model) else Vector3.ZERO,"backpack_id":id,"pickup_node":model,"model_path":model_path,"spawn_chance":0.05 if id==BackpackRules.MOUNTAIN else 1.0,"ammo_bonus":0,"done":true,"spawned":false,"discovered":false,"fixed_loot":{"id":id,"title":str(BackpackRules.PACKS[id].title),"value":0}}
	if not _backpack_model_ready(site): return false
	for existing: Dictionary in sites:
		if existing.id==site.id: return false
	model.hide()
	sites.append(site)
	return true

func register_loot_container_pickup(site_id: String, model: Node3D) -> bool:
	# Placement owns grounding and yellow materials; this API never equips the model.
	if phase not in [Phase.BOOT, Phase.HQ] or site_id.is_empty(): return false
	if not is_instance_valid(model) or not model.is_inside_tree(): return false
	for existing: Dictionary in sites:
		if existing.id == site_id: return false
	sites.append({"id":site_id, "title":"Search yellow backpack", "kind":"cache", "position":model.global_position, "container_type":LootContainers.TYPE, "pickup_node":model, "spawn_chance":1.0, "ammo_bonus":0, "done":true, "spawned":false, "discovered":false, "contents":[], "loot":{}})
	model.hide()
	return true

func select_container_item(index: int) -> bool:
	if phase != Phase.RAID or pending_cache_id.is_empty(): return false
	var site := pending_cache()
	if site.is_empty() or site.done or not _site_in_reach(site): return false
	if not LootContainers.select(site, index): return false
	hud.show_cache_choice(self, site)
	return true

func can_take_site(site: Dictionary, replace_index: int = -1) -> bool:
	if site.is_empty() or bool(site.get("done",true)) or site.get("kind","")!="cache": return false
	if replace_index < -1 or replace_index >= bag.size(): return false
	var gun_id := str(site.get("loot",{}).get("weapon_id",""))
	if not gun_id.is_empty():
		return replace_index == -1 and WeaponCatalog.available(gun_id) and not active_weapon_loadout().weapons.has(gun_id)
	var optic_id := str(site.get("loot",{}).get("optic_id",""))
	if not optic_id.is_empty():
		return replace_index == -1 and WeaponCatalog.OPTICS.has(optic_id) and WeaponState.location(active_weapon_loadout(),optic_id).is_empty()
	var candidate: Array=bag.duplicate(true)
	var next: Dictionary=backpack_state.duplicate(true)
	if BackpackRules.PACKS.has(str(site.get("backpack_id",""))):
		return BackpackRules.pickup(next,candidate,str(site.backpack_id),int(profile.data.pack_level),_backpack_model_ready(site),true,replace_index)
	if replace_index>=0: candidate[replace_index]=site.loot.duplicate(true)
	else: candidate.append(site.loot.duplicate(true))
	return BackpackRules.fits(next,candidate,int(profile.data.pack_level))

func medical_count(item: String) -> int:
	if item == "medkit": return medkits
	if not medical_pouch.has(item): return 0
	var count := int(medical_pouch[item])
	for record: Dictionary in bag:
		if str(record.get("id", "")) == item: count += 1
	return count

func treatment_request_block_reason(item: String, part: String) -> String:
	if phase != Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or not pending_result_save.is_empty():
		return "Treatments start from the Health tab during a raid."
	if not Medical.TREATMENTS.has(item): return "Unknown treatment."
	if not player.alive: return "Cannot treat while down."
	if medical_count(item) <= 0: return "No supplies for this treatment."
	if not player.medical.can_treat(item, part): return "This treatment does not apply to the selected part."
	if player.reloading: return "Resume the raid to finish reloading.\nTime is paused in inventory."
	if player.stun_remaining > 0.0: return "Resume the raid until the stun ends.\nTime is paused in inventory."
	if player.mantle_active: return "Resume the raid to finish climbing.\nMovement is paused in inventory."
	if not player.is_on_floor(): return "Resume the raid and land before treating.\nMovement is paused in inventory."
	if run_time - last_damage_at <= 1.0: return "Resume the raid briefly after damage.\nTime is paused in inventory."
	return ""

func request_treatment(item: String, part: String) -> bool:
	if not treatment_request_block_reason(item, part).is_empty(): return false
	# resume_run cancels any earlier action before this new request is armed.
	resume_run()
	treatment_item = item
	treatment_part = part
	treatment_automatic = true
	player.set_medical_active(true)
	return true

func _consume_medical(item: String) -> bool:
	if item == "medkit":
		if medkits <= 0: return false
		medkits -= 1
		return true
	if int(medical_pouch.get(item, 0)) > 0:
		medical_pouch[item] = int(medical_pouch[item]) - 1
		return true
	for index: int in range(bag.size()):
		if str(bag[index].get("id", "")) == item:
			bag.remove_at(index)
			return true
	return false


func _advance_medical(delta: float) -> void:
	if phase != Phase.RAID or not player.alive: return
	var tissue_rate := 0.0
	# Recovery resumes after a quiet interval, and never during strenuous movement.
	if run_time-last_damage_at >= 20.0 and not _metabolic_combat and metabolism.stress_remaining <= 0.0 and not player.sprinting and not player.is_swimming and not player.mantle_active:
		tissue_rate = metabolism.health_recovery_rate()
	player.advance_medical(delta,metabolism.can_recover_blood(),metabolism.blood_recovery_multiplier(),tissue_rate)

func _update_metabolism(delta: float) -> void:
	_metabolic_sample -= delta
	if _metabolic_sample <= 0.0:
		_metabolic_sample = 0.25
		_metabolic_combat = false
		for hostile: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
			if hostile.has_method("is_in_combat_with") and hostile.is_in_combat_with(player):
				_metabolic_combat = true
				break
			if hostile is LegacyHostile and hostile.health > 0 and hostile.target == player and hostile.state == LegacyHostile.AIState.COMBAT:
				_metabolic_combat = true
				break
	var spent := maxf(0.0,_previous_stamina - float(player.stamina))
	_previous_stamina = player.stamina
	metabolism.tick(delta, {
		"health_ratio":player.health_ratio(), "combat":_metabolic_combat,
		"moving":Vector2(player.velocity.x,player.velocity.z).length() > 0.2,
		"sprinting":player.sprinting, "swimming":player.is_swimming,
		"mantling":player.mantle_active, "healing":healing>0.0,
		"exhausted":player.stamina/maxf(1.0,player.max_stamina)<0.2,
		"stamina_spent":spent})
	player.field_handling.nutrition = {"food":metabolism.food,"hydration":metabolism.hydration,"energy":metabolism.energy}
	_apply_vomit_feedback()
	_sync_food_illness()

func consume_provision(index: int) -> bool:
	if phase != Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or index<0 or index>=bag.size():return false
	var id := str(bag[index].id)
	if id == "coffee_cup" or not metabolism.can_consume_item(bag[index]):return false
	var item: Dictionary=bag[index]
	if not consume_food_item(item):return false
	bag.remove_at(index)
	hud.show_inventory(self)
	announce_food_consumption(item)
	return true

func _advance_food_state(delta: float) -> void:
	if phase!=Phase.RAID or not player.alive or not is_finite(delta) or delta<=0.0: return
	for item: Dictionary in bag: Food.advance(item,delta,"carried")
	for site: Dictionary in sites:
		if bool(site.get("done",false)) or not bool(site.get("spawned",true)): continue
		if LootContainers.is_container(site):
			var changed := false
			for item: Dictionary in site.get("contents",[]):
				if Food.advance(item,delta,"world"): changed=true
			# Selection is a snapshot; refresh it after aging the canonical contents.
			if changed: LootContainers.sync_selection(site)
		elif site.get("loot") is Dictionary: Food.advance(site.loot,delta,"world")
	fruit_harvest.advance(delta)
	if profile.advance_food(delta): food_save_dirty=true
	food_save_elapsed+=delta
	# Saving has no wall-clock aging. Never bank transient raid cargo here.
	if food_save_elapsed>=30.0: _persist_food_state()

func _sync_food_illness() -> void:
	var snapshot := metabolism.illness_snapshot()
	if profile.data.get("food_illness",{})!=snapshot:
		profile.data.food_illness=snapshot
		food_save_dirty=true

func _persist_food_state(force: bool = false) -> bool:
	_sync_food_illness()
	food_save_elapsed=0.0
	if not food_save_dirty and not force: return true
	if not profile.save_profile():
		# Keep protective corruption/save errors; the usual retry flow owns clearing.
		return false
	food_save_dirty=false
	return true

func _apply_vomit_feedback() -> bool:
	var stamina_cost: float=metabolism.take_vomit_stamina()
	if stamina_cost<=0.0: return false
	player._spend_stamina(stamina_cost)
	announce("Vomiting · lost food, water and energy. Wait for nausea to clear.",4.0)
	return true

func consume_food_item(item: Dictionary) -> bool:
	if not player.alive or phase not in [Phase.RAID,Phase.PAUSED] or not pending_result_save.is_empty(): return false
	if phase==Phase.PAUSED and not inventory_open: return false
	if not metabolism.consume_item(item): return false
	_apply_vomit_feedback()
	_persist_food_state(true)
	return true

func announce_food_consumption(item: Dictionary) -> void:
	if metabolism.last_meal_rejected:
		announce("Vomited after eating %s · meal lost. Wait for nausea to clear." % str(item.get("title","food")),5.0)
	else:
		announce("Consumed %s%s" % [str(item.get("title","food"))," · food poisoning" if float(Food.effects(item).sickness_seconds)>0.0 else ""],3.0)

func open_canned_food(index: int) -> bool:
	if phase!=Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or not pending_result_save.is_empty(): return false
	if not player.alive or deployment_pending or quit_confirmation_open or player.reloading or healing>0.0 or player.healing_active: return false
	if index<0 or index>=bag.size(): return false
	var item: Dictionary=bag[index]
	if not Cans.is_closed(str(item.get("id",""))): return false
	# UI enablement is advisory; the actual carried tool is checked again here.
	if not Cans.can_open(item,bag):
		announce(Cans.blocked_reason(item,bag),3.0)
		return false
	var opened: Dictionary=Cans.opened_copy(item)
	if opened.is_empty(): return false
	var candidate: Array=bag.duplicate(true)
	candidate[index]=opened
	if not BackpackRules.fits(backpack_state,candidate,int(profile.data.pack_level)): return false
	# Preserve the physical cargo slot and record identity; opening is not eating.
	item.clear()
	item.merge(opened,true)
	player.set_cargo_mass(cargo_mass_kg(),cargo_limit_kg())
	hud.show_inventory(self)
	announce("Opened %s · ready to eat" % str(item.title),3.0)
	return true

func unload_magazine() -> bool:
	if phase!=Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty():return false
	if not player.physical_magazines or not player.magazine_inserted or player.reloading:return false
	if not physical_magazine_reload("eject"):return false
	player._sync_weapon_magazine()
	announce("Magazine removed with its remaining rounds.",3.0)
	return true

func pack_magazine(index: int) -> bool:
	if phase!=Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or index<0 or index>=bag.size():return false
	var moved := WeaponSupply.pack(bag[index],bag)
	if moved>0:_refresh_magazine_cargo()
	announce("Packed %d rounds into magazine" % moved if moved>0 else "No compatible loose ammunition or magazine already full.",3.0)
	return moved>0

func wear_clothing(index: int) -> bool:
	if phase!=Phase.PAUSED or not inventory_open or not pending_cache_id.is_empty() or index<0 or index>=bag.size():return false
	var item := Clothing.spec(str(bag[index].id))
	if item.is_empty():return false
	var next := backpack_state.duplicate(true)
	var candidate: Array = bag.duplicate(true)
	var previous := Clothing.spec(str(next.clothing.get(item.slot,"")))
	next.clothing[item.slot] = item.id
	if previous.is_empty():candidate.remove_at(index)
	else:candidate[index]=previous
	if not BackpackRules.fits(next,candidate,int(profile.data.pack_level)):
		announce("Not enough remaining pocket space. Reduce cargo first.",3.0)
		return false
	bag.assign(candidate)
	backpack_state = next
	player.equipped_clothing = next.clothing
	return true

func _refresh_magazine_cargo() -> void:
	player.reserve=0
	for item: Dictionary in bag:
		if WeaponSupply.MAGAZINES.get(str(item.get("id","")),"")==str(player.weapon_id):player.reserve+=WeaponSupply.rounds(item)
	player.set_cargo_mass(cargo_mass_kg(),cargo_limit_kg())
	player._sync_weapon_magazine()

func _magazine_bag_index(uid: String) -> int:
	for index: int in range(bag.size()):
		if not uid.is_empty() and str(bag[index].get("magazine_uid",""))==uid:return index
	return -1

func _notify_magazine_destination(destination: String) -> void:
	if is_instance_valid(player.uzi_viewmodel) and player.uzi_viewmodel.has_method("set_reload_outgoing_destination"):
		player.uzi_viewmodel.call("set_reload_outgoing_destination",destination)

func _stow_or_drop_magazine(item: Dictionary, preferred_index: int = -1) -> bool:
	var candidate := bag.duplicate(true)
	if preferred_index>=0:candidate.insert(mini(preferred_index,candidate.size()),item.duplicate(true))
	else:candidate.append(item.duplicate(true))
	if BackpackRules.fits(backpack_state,candidate,int(profile.data.pack_level)):
		bag.assign(candidate)
		_notify_magazine_destination("cargo")
		return true
	if DroppedMagazine.drop(self,item):
		_notify_magazine_destination("ground")
		announce("No cargo space · magazine dropped with %d rounds." % WeaponSupply.rounds(item),4.0)
		return true
	announce("Cannot place magazine safely. Make cargo space before continuing.",4.0)
	return false

func physical_magazine_reload(event: String) -> bool:
	if event=="cancel":return _cancel_magazine_reload()
	var id := str(player.weapon_id)
	if event=="begin":
		if not pending_magazine.is_empty() and not _cancel_magazine_reload():return false
		var chosen := -1
		var best := 0
		for i: int in range(bag.size()):
			if WeaponSupply.MAGAZINES.get(str(bag[i].get("id","")),"")==id and WeaponSupply.rounds(bag[i])>best:
				chosen=i;best=WeaponSupply.rounds(bag[i])
		if chosen<0:
			announce("Find and pack a compatible magazine before reloading.",3.0)
			return false
		pending_magazine=MagazineRecord.normalize(id,bag[chosen],best)
		if pending_magazine.is_empty():return false
		_reload_magazine_source_index=chosen
		_reload_outgoing_magazine.clear()
		bag.remove_at(chosen)
		_refresh_magazine_cargo()
		return true
	if event=="eject":
		if player.magazine_inserted:
			var old := MagazineRecord.normalize(id,player.inserted_magazine,maxi(0,player.ammo-int(player.chambered)))
			if old.is_empty() or not _stow_or_drop_magazine(old,_reload_magazine_source_index):return false
			_reload_outgoing_magazine=old.duplicate(true)
			player.ammo=int(player.chambered)
			player.magazine_inserted=false
			player.inserted_magazine.clear()
		_refresh_magazine_cargo()
		return true
	if event=="insert" and not pending_magazine.is_empty():
		player.inserted_magazine=pending_magazine.duplicate(true)
		player.ammo=WeaponSupply.rounds(pending_magazine)+int(player.chambered)
		player.magazine_inserted=true
		pending_magazine.clear()
		_reload_outgoing_magazine.clear()
		_reload_magazine_source_index=-1
		_refresh_magazine_cargo()
		return true
	return false

func _cancel_magazine_reload() -> bool:
	if not pending_magazine.is_empty():
		var candidate := bag.duplicate(true)
		candidate.insert(clampi(_reload_magazine_source_index,0,candidate.size()),pending_magazine.duplicate(true))
		if not BackpackRules.fits(backpack_state,candidate,int(profile.data.pack_level)):
			var outgoing_index := _magazine_bag_index(str(_reload_outgoing_magazine.get("magazine_uid","")))
			if outgoing_index>=0:
				var outgoing: Dictionary=bag[outgoing_index]
				var restored := bag.duplicate(true)
				restored.remove_at(outgoing_index)
				restored.insert(clampi(_reload_magazine_source_index,0,restored.size()),pending_magazine.duplicate(true))
				if not BackpackRules.fits(backpack_state,restored,int(profile.data.pack_level)):return false
				if not DroppedMagazine.drop(self,outgoing):
					# With no safe world placement, undo only this exchange rather than lose either magazine.
					player.inserted_magazine=outgoing.duplicate(true)
					player.magazine_inserted=true
					player.ammo=WeaponSupply.rounds(outgoing)+int(player.chambered)
				bag.assign(restored)
			else:
				# The user's drop policy applies to the removed magazine, never an arbitrary replacement.
				# Keep this reservation owned until cargo space is freed; do not repeat the failed event.
				return false
		else:bag.assign(candidate)
		pending_magazine.clear()
	_reload_outgoing_magazine.clear()
	_reload_magazine_source_index=-1
	player.reloading=false
	_refresh_magazine_cargo()
	return true

func register_scav_drop(_actor: Node3D) -> void:
	# New gun/magazine loot is generated only in homes. Enemy equipment stays
	# on its actor; manually discarded player magazines retain their own path.
	return

func _recover_world_optic(site: Dictionary) -> bool:
	var id := str(site.get("loot",{}).get("optic_id",""))
	var state := active_weapon_loadout()
	if not WeaponCatalog.OPTICS.has(id) or not WeaponState.location(state,id).is_empty(): return false
	if LootContainers.is_container(site):
		if not LootContainers.remove_selected(site): return false
	else:
		site.done = true
		if is_instance_valid(site.get("pickup_node")): site.pickup_node.hide()
	state.loose_optics.append(id)
	state.revision += 1
	if site.done and selected_destination == site.id: selected_destination = ""
	hold_progress = 0.0
	announce("Recovered %s · fit at weapon bench; extract to keep it" % str(WeaponCatalog.optic(id).title),4.0)
	ResidentialLoot.collected(self, site)
	refresh_guidance()
	return true
