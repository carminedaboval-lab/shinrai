extends SceneTree

# Fast menu capture without the park: builds every menu screen against stub
# sources over a plaza-art "scene", at 1920x1080 and 1280x720.
#   godot --path . --script res://tests/probe_ui_menus_only.gd -- --out <dir> [--tag quick]
# Writes <dir>/<tag>_<screen>.png and <tag>_720_<screen>.png. No profile file
# is read or written.

const Hud = preload("res://scripts/extraction_hud.gd")
const Loading = preload("res://scripts/shinrai_loading_screen.gd")
const Operations = preload("res://scripts/ui/shinrai_operations_menu.gd")
const Kit = preload("res://scripts/ui/shinrai_menu_kit.gd")

var out_dir := ""
var tag := "quick"
var failures: Array[String] = []

class StubProfile extends RefCounted:
	var data := {"credits": 1240, "stash": {"circuit": 3, "battery": 1}, "extracts": 2, "runs": 5, "active_run": false, "prepared_medkit": false, "pack_level": 0, "loadout": {}, "starter_pending": false}
	var last_error := ""
	var recovered_interrupted_run := false

class StubNav extends RefCounted:
	var ready := false
	var shoreline: Array = []
	func _init() -> void:
		for i: int in range(24):
			var a := TAU * i / 24.0
			shoreline.append(Vector2(60, -20) + Vector2(cos(a) * 70, sin(a) * 48))

class StubPark extends Node:
	var high_render_quality := false
	var applied := 0
	func _apply_render_quality() -> void: applied += 1

class StubPlayer extends Node3D:
	var kills := 3

class StubRaid extends Node:
	enum Phase { BOOT, HQ, RAID, PAUSED, RESULT }
	const PRICES := {"circuit": 60, "battery": 40}
	var phase := Phase.HQ
	var profile := StubProfile.new()
	var navigation := StubNav.new()
	var night_deployment := false
	var enemy_visual: Variant = 1
	var deploy_queued := false
	var relays := 1
	var remaining := 4123.0
	var bag: Array[Dictionary] = [{"title": "AKANE / A-9 magazine"}, {"title": "Kaki persimmon"}, {"title": "Bandage"}]
	var map_open := false
	var player: StubPlayer
	var sites: Array[Dictionary] = [{"id": "r1", "title": "North sports relay", "kind": "relay", "position": Vector3(-120, 0, -90), "done": false}, {"id": "s1", "title": "Kiosk", "kind": "search", "position": Vector3(30, 0, 100), "done": false}]
	var exits: Array[Dictionary] = [{"id": "gate", "title": "South gate extraction", "position": Vector3(10, 0, 160)}]
	var map_routes: Array = [[Vector2(-100, -80), Vector2(0, -60), Vector2(80, 40)]]
	var guidance_path := PackedVector3Array([Vector3(0, 0, 0), Vector3(-60, 0, -40), Vector3(-120, 0, -90)])
	var guidance_distance := 192.0
	var approach_cover := {"placements": []}
	func cargo_cells_used() -> int: return 4
	func capacity() -> int: return 6
	func can_retry_deployment_save() -> bool: return false
	func can_retry_result_save() -> bool: return true
	func tracked_objective() -> Dictionary: return sites[0]

## Early-boot source shape (shinrai_menu_source.gd contract).
class EarlySource extends RefCounted:
	var profile := StubProfile.new()
	func menu_profile() -> Dictionary: return profile.data
	func menu_world_ready() -> bool: return false
	func menu_can(action: String) -> bool: return action in ["deploy", "time", "graphics", "quit_confirm"]
	func menu_night() -> bool: return true
	func menu_high_quality() -> bool: return false
	func menu_last_error() -> String: return ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--out": out_dir = args[i + 1]
		if args[i] == "--tag": tag = args[i + 1]
	if out_dir.is_empty(): out_dir = ProjectSettings.globalize_path("user://ui_quick")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _scene_layer() -> CanvasLayer:
	# Stand-in for the live 3D view: the plaza art at full brightness.
	var layer := CanvasLayer.new()
	layer.layer = -10
	var art := TextureRect.new()
	art.texture = Kit.plaza_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(art)
	root.add_child(layer)
	return layer

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_scene_layer()
	await _pass("")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	await _pass("720_")
	print("UI_QUICK checks failed: %d" % failures.size())
	for f: String in failures: print("UI_QUICK FAIL ", f)
	print("UI_QUICK done ", out_dir)
	quit()

func _pass(prefix: String) -> void:
	# Loading screen.
	var loading: CanvasLayer = Loading.new()
	root.add_child(loading)
	loading.begin("Building the park")
	loading.set_stage("Placing trees and lamps", 0.52)
	await _capture(prefix + "loading")
	loading.begin("Entering the park", &"deploy")
	loading.show_cancel(true)
	loading.finish(&"boot")
	_check(loading.active and loading.visible, "deploy owner keeps the screen after boot finishes")
	await _capture(prefix + "loading_deploy")
	loading.finish(&"deploy")
	_check(not loading.active and not loading.visible, "screen hides when the last owner finishes")
	loading.begin("Loading park resources")
	loading.fail("Park scene could not be loaded (error 7).")
	await _capture(prefix + "loading_fail")
	loading.finish()
	loading.queue_free()
	# Early menu (no ExtractionRun), 3D off -> plaza art; progress from ShinraiLoadState.
	var load_state: Script = Kit.load_state()
	if load_state != null:
		load_state.call("reset")
		load_state.call("report", "Placing trees and lamps", 0.64)
		_check(is_equal_approx(float(Kit.load_value("fraction", -1.0)), 0.64), "menus read ShinraiLoadState.fraction")
	root.disable_3d = true
	var early_layer := CanvasLayer.new()
	early_layer.layer = 60
	root.add_child(early_layer)
	var early: Control = Operations.new()
	early_layer.add_child(early)
	early.configure(EarlySource.new())
	await _capture(prefix + "early_menu")
	_check(not early.deploy_button.disabled and early.deploy_button.text.contains("PREPARING"), "early DEPLOY enabled with preparing label")
	_check(early.inventory_button.disabled, "early inventory disabled until ready")
	if load_state != null: _check(early.deploy_button.text.contains("64%"), "DEPLOY shows live park progress")
	early_layer.queue_free()
	if load_state != null: load_state.call("reset")
	root.disable_3d = false
	# HUD screens with an ExtractionRun-shaped stub.
	var park := StubPark.new()
	root.add_child(park)
	var raid := StubRaid.new()
	park.add_child(raid)
	raid.player = StubPlayer.new()
	park.add_child(raid.player)
	var hud: CanvasLayer = Hud.new()
	raid.add_child(hud)
	var actions: Array[String] = []
	hud.action_requested.connect(func(a: String) -> void: actions.append(a))
	hud.show_hq(raid)
	await _capture(prefix + "hq_preparing")
	raid.navigation.ready = true
	var menu: Control = hud.operations_menu
	hud.show_hq(raid)
	_check(hud.operations_menu == menu, "show_hq refreshes in place")
	_check(menu.deploy_button.text.contains("GOLDEN HOUR"), "ready DEPLOY label")
	_check(not hud.body_status.visible, "x-ray body hidden on Operations")
	await _capture(prefix + "hq")
	menu.screen.open_side()
	await _capture(prefix + "hq_settings")
	menu.screen.close_side()
	menu.time_choice.buttons[1].pressed.emit()
	_check(actions.has("time"), "NIGHT segment emits time")
	menu.deploy_button.pressed.emit()
	_check(actions.has("deploy"), "DEPLOY emits deploy")
	menu.graphics_choice.buttons[1].pressed.emit()
	_check(park.high_render_quality and park.applied == 1, "graphics handled locally by HUD")
	raid.phase = StubRaid.Phase.PAUSED
	hud.show_pause(raid, false)
	_check(not hud.body_status.visible, "x-ray body hidden on Pause")
	await _capture(prefix + "pause")
	hud.show_pause(raid, true)
	_check(hud.map_view != null, "map view set")
	await _capture(prefix + "map")
	hud.show_quit_confirmation(raid)
	await _capture(prefix + "quit")
	hud.show_abandon()
	await _capture(prefix + "abandon")
	raid.profile.last_error = "Could not write user://shinrai_extraction_v1.json (error 31)."
	hud.show_pending_result(raid)
	await _capture(prefix + "pending")
	raid.profile.last_error = ""
	hud.show_result(raid, true, "Extracted through the south gate with the relay data.", 250)
	await _capture(prefix + "result_won")
	hud.show_result(raid, false, "You were eliminated near the lake promenade.", 0)
	await _capture(prefix + "result_lost")
	hud.show_raid()
	_check(hud.body_status.visible, "x-ray body returns in the raid HUD")
	park.queue_free()
	await process_frame

func _check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _capture(label: String) -> void:
	for frame: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("%s_%s.png" % [tag, label])
	root.get_texture().get_image().save_png(path)
	print("UI_QUICK ", path)
