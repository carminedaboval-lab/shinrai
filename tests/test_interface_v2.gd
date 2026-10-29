extends SceneTree
const Profile = preload("res://scripts/extraction_profile.gd")
var scene: Node
var raid: Node
var failures: Array[String] = []
var checks := 0
var output := ""
var render := false
func _initialize() -> void:
	output = OS.get_environment("SHINRAI_UI_QA")
	render = OS.get_cmdline_user_args().has("--render")
	call_deferred("review")
func check(value: bool, label: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", label)
	if not value: failures.append(label)
func panel() -> Control:
	return raid.hud.panel_content.get_child(0)
func frames(count: int = 5) -> void:
	for i: int in range(count): await process_frame
func capture(label: String) -> void:
	if not render: return
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("UI_CAPTURE: ", label)
func click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func key(code: Key, ctrl: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		Input.parse_input_event(event)
		await process_frame
func benchmark(label: String) -> void:
	if not render: return
	await frames(30)
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i: int in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	print("UI_BENCHMARK: ", label, " median_ms=", samples[60], " p95_ms=", samples[114], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func review() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	scene = load("res://scenes/shinrai_extraction.tscn").instantiate()
	scene.profile_path = output.path_join("ui_v2_profile.json")
	for suffix: String in ["", ".tmp"]: DirAccess.remove_absolute(scene.profile_path + suffix)
	root.add_child(scene)
	current_scene = scene
	raid = scene.get_node("ExtractionRun")
	var deadline := Time.get_ticks_msec() + 600000
	while raid.phase == raid.Phase.BOOT and Time.get_ticks_msec() < deadline: await process_frame
	check(raid.phase == raid.Phase.HQ, "Actual main scene reaches HQ")
	if raid.phase != raid.Phase.HQ:
		quit(1)
		return
	raid.profile.data.stash = {"circuit": 3, "optics": 2, "cell": 4, "archive": 1, "coffee_cup": 2, "park_map": 1}
	raid.profile.data.credits = 1600
	raid.profile.save_profile()
	raid.open_inventory()
	await frames()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Inventory releases pointer")
	check(Rect2(Vector2.ZERO, Vector2(1920,1080)).encloses(panel().get_global_rect()), "HQ interface fits viewport")
	await click(panel().tiles[4])
	check(panel().selected == 4, "Actual mouse press selects the cup")
	await capture("stash_cup_1080")
	await key(KEY_F, true)
	check(panel().search.has_focus(), "Ctrl F focuses item search")
	panel().search.text = "optical"
	panel().search.text_changed.emit("optical")
	check(panel().selected == 1 and panel().tiles[1].visible and not panel().tiles[0].visible, "Search moves inspector to a visible matching item")
	panel()._set_category("DOCUMENTS")
	check(panel().selected == -1, "Combined empty filter clears inspector selection")
	panel().search.text = ""
	panel().search.text_changed.emit("")
	check(panel().selected == 5, "Document category selects actual collected map")
	await capture("map_inspector_1080")
	panel()._set_category("ALL")
	panel()._select(0)
	await capture("pending_art_1080")
	root.size = Vector2i(1280,720)
	await capture("stash_720")
	root.size = Vector2i(1920,1080)
	raid.hud.action_requested.emit("sell_item:circuit:1")
	var reload := Profile.new()
	reload.save_path = scene.profile_path
	reload.load_profile()
	check(reload.data.stash.circuit == 2 and reload.data.credits == 1685, "Sale persists exact quantity and credit through reload")
	raid.close_inventory()
	raid.start_run()
	raid._clear_enemies()
	for i: int in range(120):
		await physics_frame
		await process_frame
		if raid.player.is_on_floor(): break
	check(raid.player.is_on_floor(), "Player stands at gameplay height on live park collision")
	raid.set_physics_process(false)
	raid.player.set_physics_process(false)
	raid.player.health = 67
	raid.player.stamina = 64
	raid.player.ammo = 21
	raid.relays = 1
	raid.notice_time = 0
	raid.prompt_text = ""
	raid.hud.update_raid(raid)
	await capture("hud_day_1080")
	await benchmark("HUD visible")
	raid.hud.hide()
	await benchmark("HUD hidden")
	raid.hud.show()
	root.size = Vector2i(1280,720)
	await capture("hud_day_720")
	root.size = Vector2i(1920,1080)
	raid.bag.clear()
	for item: Dictionary in raid.ITEMS: raid.bag.append(item.duplicate(true))
	raid.open_inventory()
	await frames()
	panel()._select(4)
	await capture("cargo_cup_1080")
	var preview: Control = panel().equipment_preview
	var yaw: float = preview._yaw
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	preview._gui_input(down)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(28,12)
	preview._gui_input(drag)
	down.pressed = false
	preview._gui_input(down)
	check(preview._yaw != yaw and not preview._dragging, "Equipment drag rotates supplied weapon and release ends drag")
	check(preview.inspect_equipment(), "Supplied weapon inspection animation still plays")
	raid.hud.action_requested.emit("drink_coffee:4")
	check(raid.bag.size() == 5 and raid.player.coffee_boost_remaining > 0, "Cup action consumes exactly one item and applies real boost")
	check(raid.player.ammo == 21, "Inventory clicks and preview drag do not fire or consume weapon ammunition")
	var count: int = raid.bag.size()
	panel()._confirm_discard(panel().entries[0])
	panel()._build_details()
	check(raid.bag.size() == count, "Discard cancellation preserves cargo")
	raid.hud.action_requested.emit("sort_cargo")
	check(raid.bag.size() == count, "Cargo sort preserves ownership")
	raid.hud.action_requested.emit("map")
	check(raid.hud.map_view != null, "Inventory transitions to field map")
	raid.open_inventory()
	await frames()
	await key(KEY_ESCAPE)
	check(not raid.inventory_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Escape closes inventory and recaptures mouse")
	await frames()
	check(raid.hud.panel_content.find_children("EquipmentPreview", "", true, false).is_empty(), "Closed inventory frees 3D equipment viewport")
	raid.set_physics_process(false)
	raid.player.set_physics_process(false)
	scene.is_night_mode = true
	scene._apply_time_of_day()
	raid.hud.update_raid(raid)
	await capture("hud_night_1080")
	raid.open_inventory()
	await frames()
	panel()._select(0)
	await capture("cargo_night_1080")
	root.size = Vector2i(1280,720)
	await capture("cargo_night_720")
	root.size = Vector2i(1920,1080)
	raid.close_inventory()
	raid.player.health = 21
	raid.player.stamina = 7
	raid.player.ammo = 3
	raid.player.reloading = true
	raid.remaining = 61
	raid.prompt_text = "H  ·  Healing"
	raid.progress_ratio = .62
	raid.hud.update_raid(raid)
	await capture("hud_urgent_1080")
	check(raid.hud.ammo_status.ammo == 3 and raid.hud.mission_status.urgent and raid.hud.progress.visible, "Low ammunition, time and contextual treatment show live values")
	raid.finish_run(false, "UI acceptance test")
	check(raid.profile.data.stash.circuit == 2, "Unbanked cargo does not alter stash on death")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("UI_V2_RESULT: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
