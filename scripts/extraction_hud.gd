extends CanvasLayer

signal action_requested(action: String)
const GameInput=preload("./shinrai_input.gd")
const INK := Color("#09151d")
const PAPER := Color("#e8eee7")
const MINT := Color("#85dfc4")
const GOLD := Color("#e5bc7f")
const HudHostile = preload("res://scripts/enemy.gd")
var _observed_player: Node
var _last_raid_time := 0.0
var _combat_until := -100.0
const LoadoutSummary = preload("res://scripts/extraction_loadout_summary.gd")
const ItemArt = preload("./extraction_item_art.gd")
const InventoryPanel = preload("./extraction_inventory.gd")
const LootPanel = preload("./extraction_loot_panel.gd")
var loot_view: Control
const BodyStatus = preload("res://scripts/hud/body_status.gd")
var body_status: Control
var root: Control
var telemetry: Label
var objectives: Label
var vitals: Label
var prompt: Label
var message: Label
var marker: Label
var progress: ProgressBar
var overlay: ColorRect
var inventory_backdrop: TextureRect
var panel_content: VBoxContainer
var menu_center: CenterContainer
var menu_scroll: ScrollContainer
var map_view: Control
var game_controls: Array[Control] = []
var panel_tween: Tween
var inventory_selection := ""
var raid_status: Control
var ammo_status: Control
var weapon_readiness: Label
var mission_status: Control
var interaction_signal: Control
var vitals_check := false
var _notice_text := ""
var _notice_started_at := 0.0
var _notice_remaining := 0.0

func _ready() -> void:
	layer = 60
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_add_vignette()
	var theme := Theme.new()
	theme.default_font_size = 23
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", Color("#a3afb4"))
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#254454") if style_name == "hover" else Color("#152b3b")
		style.border_color = MINT if style_name == "focus" else Color("#415b6c")
		if style_name == "disabled":
			style.bg_color = Color("#12232c")
			style.border_color = Color("#30434e")
		style.set_border_width_all(1)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 13
		style.content_margin_bottom = 13
		theme.set_stylebox(style_name, "Button", style)
	root.theme = theme
	raid_status = RaidStatus.new()
	raid_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	raid_status.offset_left = 16
	raid_status.offset_right = 376
	raid_status.offset_top = -306
	raid_status.offset_bottom = -12
	raid_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(raid_status)
	# See-through body above the vitals cluster.
	body_status = BodyStatus.new()
	body_status.name = "BodyStatus"
	body_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	body_status.offset_left = 30
	body_status.offset_right = 190
	body_status.offset_top = -620
	body_status.offset_bottom = -296
	root.add_child(body_status)
	ammo_status = AmmoStatus.new()
	ammo_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_status.offset_left = -292
	ammo_status.offset_right = -30
	ammo_status.offset_top = -202
	ammo_status.offset_bottom = -42
	ammo_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ammo_status)
	weapon_readiness = _label(root, "", 17, MINT)
	weapon_readiness.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_readiness.offset_left = -390
	weapon_readiness.offset_right = -30
	weapon_readiness.offset_top = -270
	weapon_readiness.offset_bottom = -205
	weapon_readiness.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_readiness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_status = MissionStatus.new()
	mission_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mission_status.offset_left = -350
	mission_status.offset_right = -30
	mission_status.offset_top = 34
	mission_status.offset_bottom = 132
	mission_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mission_status)
	# Retain the public label handles used by run/review tooling; objective text
	# is represented by the relay pips rather than a second mission paragraph.
	objectives = _label(root, "", 18, MINT)
	objectives.position = Vector2(36, 30)
	telemetry = _label(root, "", 27, PAPER)
	telemetry.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	telemetry.offset_left = -164
	telemetry.offset_right = -46
	telemetry.offset_top = 43
	telemetry.offset_bottom = 83
	telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	telemetry.modulate.a = 0.86
	vitals = _label(root, "", 34, PAPER)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	vitals.offset_left = -254
	vitals.offset_top = -128
	vitals.offset_right = -48
	vitals.offset_bottom = -79
	vitals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vitals.visible = false
	message = _label(root, "", 20, GOLD)
	message.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	message.offset_left = 36
	message.offset_right = 476
	message.offset_top = 46
	message.offset_bottom = 104
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.max_lines_visible = 2
	message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prompt = _label(root, "", 21, PAPER)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -300
	prompt.offset_right = 300
	prompt.offset_top = -130
	prompt.offset_bottom = -94
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.modulate.a = 0.88
	prompt.clip_text = true
	prompt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress.offset_left = -190
	progress.offset_right = 190
	progress.offset_top = -88
	progress.offset_bottom = -84
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_back := StyleBoxFlat.new()
	progress_back.bg_color = Color(0.03, 0.08, 0.08, 0.35)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.52, 0.88, 0.77, 0.85)
	progress.add_theme_stylebox_override("background", progress_back)
	progress.add_theme_stylebox_override("fill", progress_fill)
	root.add_child(progress)
	interaction_signal = InteractionSignal.new()
	interaction_signal.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_signal.offset_left = -342
	interaction_signal.offset_right = -274
	interaction_signal.offset_top = -132
	interaction_signal.offset_bottom = -94
	interaction_signal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(interaction_signal)
	marker = _label(root, "", 18, GOLD)
	marker.modulate.a = 0.85
	game_controls = [raid_status, ammo_status, weapon_readiness, mission_status, objectives, telemetry, vitals, message, prompt, progress, marker, interaction_signal]
	overlay = ColorRect.new()
	overlay.color = Color(0.016, 0.032, 0.055, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	inventory_backdrop = TextureRect.new()
	inventory_backdrop.name = "InventoryBackdrop"
	inventory_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inventory_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	inventory_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_backdrop.modulate = Color(0.64, 0.74, 0.75, 0.82)
	inventory_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_backdrop.hide()
	overlay.add_child(inventory_backdrop)
	menu_center = CenterContainer.new()
	menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(menu_center)
	menu_scroll=ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus=true
	menu_center.add_child(menu_scroll)
	panel_content = VBoxContainer.new()
	panel_content.custom_minimum_size = Vector2(780, 0)
	panel_content.add_theme_constant_override("separation", 15)
	menu_scroll.add_child(panel_content)
	get_viewport().size_changed.connect(func() -> void:call_deferred("_fit_menu_scroll"))

func _label(parent: Node, text: String, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _clear_panel() -> void:
	inventory_backdrop.hide()
	_set_menu_scrolling(true)
	call_deferred("_fit_menu_scroll")
	_close_loot_view()
	panel_content.theme = null
	overlay.color = Color(0.016, 0.032, 0.055, 0.88)
	if panel_tween != null:
		panel_tween.kill()
	panel_content.custom_minimum_size = Vector2(780, 0)
	for child: Node in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	map_view = null
	vitals_check = false
	overlay.show()
	for control: Control in game_controls:
		control.hide()
	panel_content.modulate.a = 0.0
	panel_tween = create_tween()
	panel_tween.tween_property(panel_content, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _translucent_menu_theme() -> void:
	# Local to operations and pause screens; each panel rebuild resets this.
	overlay.color = Color(0.035, 0.040, 0.038, 0.32)
	var menu_theme := Theme.new()
	menu_theme.default_font_size = 23
	menu_theme.set_color("font_color", "Button", Color("#eeeeee"))
	menu_theme.set_color("font_disabled_color", "Button", Color("#c3c3c3"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#161616a6")
		style.border_color = Color("#b8c3bf60")
		if state == "hover": style.bg_color = Color("#93aaa48c")
		elif state == "pressed": style.bg_color = Color("#aec5bc99")
		elif state == "disabled": style.bg_color = Color("#16161670")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("#eeeeee")
		style.set_border_width_all(1)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 13
		style.content_margin_bottom = 13
		menu_theme.set_stylebox(state, "Button", style)
	panel_content.theme = menu_theme

func _button(text: String, action: String, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(func() -> void: action_requested.emit(action))
	panel_content.add_child(button)
	return button

func show_hq(raid: Node) -> void:
	_clear_panel()
	_translucent_menu_theme()
	_label(panel_content, "SHINRAI  /  FIELD OPERATIONS", 19, Color("#c6d7d2"))
	_label(panel_content, "THE QUIET EXIT", 58, PAPER)
	_label(panel_content, "01   SHINRAI PARK", 26, Color("#ddd4bd"))
	_label(panel_content, "Recover the park's telemetry. Search for salvage. Get out alive.\nOne relay opens extraction. All three earn the full contract bonus.", 23, PAPER)
	_label(panel_content, "UP TO 2 HOURS   /   SOLO PvE   /   BASE CARGO 6–10 SLOTS", 19, Color("#c6d7d2"))
	var d: Dictionary = raid.profile.data
	var stash_count := 0
	for amount: Variant in d.stash.values():
		stash_count += int(amount)
	_label(panel_content, "CREDITS  %d     STASH  %d     EXTRACTS  %d / %d" % [d.credits, stash_count, d.extracts, d.runs], 23, PAPER)
	_label(panel_content, LoadoutSummary.describe(d), 21, PAPER)
	if raid.enemy_visual == null:
		_label(panel_content, "RECON BUILD: K17 model pending. Hostile spawning is disabled.", 20, Color("#ddd4bd"))
	if raid.profile.recovered_interrupted_run:
		_label(panel_content, "Last run was interrupted. Unbanked cargo was lost; your stash is safe.", 18, Color("#ddd4bd"))
	if not raid.profile.last_error.is_empty():
		_label(panel_content, raid.profile.last_error, 19, Color("#ef9b8c"))
	var retry_deploy: bool = raid.can_retry_deployment_save()
	_button("RETRY SAVE & DEPLOY" if retry_deploy else "DEPLOY  →  " + ("NIGHT" if raid.night_deployment else "GOLDEN HOUR"), "retry_deploy" if retry_deploy else "deploy", not raid.navigation.ready or (not raid.profile.last_error.is_empty() and not retry_deploy)).grab_focus()
	_button("LOADOUT & INVENTORY  ·  %d banked item%s" % [stash_count, "s" if stash_count != 1 else ""], "inventory")
	_graphics_button(raid)
	_controls_help()
	var action_error := str(raid.profile.last_error)
	if action_error.is_empty() and bool(d.active_run):
		action_error = "Available after the current run ends."
	var sell_value := 0
	for item_id: String in d.stash:
		var price := int(raid.PRICES.get(item_id, 0))
		if price > 0: sell_value += int(d.stash[item_id]) * price
	var row := HBoxContainer.new()
	panel_content.add_child(row)
	for spec: Array in [["Change time of day", "time"], ["Sell stash", "sell"], ["Extra medkit · 120", "medkit"]]:
		var button := Button.new()
		button.text = spec[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var event: String = spec[1]
		var reason := action_error if event != "time" else ""
		if event == "sell":
			if reason.is_empty() and sell_value <= 0: reason = "No sellable items in your stash."
			button.tooltip_text = "Sell items worth %d credits. Unpriced items stay banked." % sell_value
		elif event == "medkit":
			if bool(d.prepared_medkit): button.text = "Extra medkit · READY"
			if reason.is_empty():
				if bool(d.prepared_medkit): reason = "Extra medkit prepared for the next deployment."
				elif int(d.credits) < 120: reason = "Need 120 credits; you have %d." % int(d.credits)
			button.tooltip_text = "Prepare one extra medkit for the next deployment."
		button.disabled = not reason.is_empty()
		if not reason.is_empty(): button.tooltip_text = reason
		button.pressed.connect(func() -> void: action_requested.emit(event))
		row.add_child(button)
	var level: int = d.pack_level
	var upgrade_price := 450 * (level + 1)
	var upgrade_reason := action_error
	if upgrade_reason.is_empty():
		if level >= 2: upgrade_reason = "Base cargo capacity is fully upgraded."
		elif int(d.credits) < upgrade_price: upgrade_reason = "Need %d credits; you have %d." % [upgrade_price, int(d.credits)]
	var upgrade := _button("Cargo upgrade · %d credits" % upgrade_price if level < 2 else "Cargo fully upgraded", "upgrade", not upgrade_reason.is_empty())
	upgrade.tooltip_text = upgrade_reason if not upgrade_reason.is_empty() else "Adds 2 base cargo slots."
	_button("QUIT TO DESKTOP", "quit_confirm")
	_label(panel_content, "Starter kit is free. Carried items are lost on death. Controls help is above.", 18, Color("#aabbbd"))

func show_inventory(raid: Node) -> void:
	# Only a refresh of this same inventory inherits filters and cargo identity.
	# Opening a different screen/run must not carry stale slot references.
	var previous_view: Dictionary = {}
	for child: Node in panel_content.get_children():
		if child is InventoryPanel and child.raid == raid:
			previous_view = child.view_state()
			if child.selected >= 0 and child.selected < child.entries.size():
				inventory_selection = str(child.entries[child.selected].id)
	_clear_panel()
	_set_menu_scrolling(false)
	overlay.color = Color(0.022, 0.059, 0.065, 0.88)
	if not inventory_backdrop.texture:
		inventory_backdrop.texture = load("res://assets/ui/inventory/inventory_backdrop.png")
	inventory_backdrop.show()
	body_status.hide()
	panel_content.custom_minimum_size.x = 1504
	var inventory := InventoryPanel.new()
	panel_content.add_child(inventory)
	inventory.configure(raid)
	var fit_width := func() -> void:
		inventory.custom_minimum_size = Vector2(clampf(root.size.x - 24.0, 1504.0, 2280.0), maxf(0.0, root.size.y - 28.0))
	fit_width.call()
	root.resized.connect(fit_width)
	inventory.tree_exiting.connect(func() -> void: root.resized.disconnect(fit_width), CONNECT_ONE_SHOT)
	inventory.action_requested.connect(func(action: String) -> void: action_requested.emit(action))
	if not previous_view.is_empty() and bool(previous_view.in_hq) == inventory.in_hq:
		inventory.restore_view_state(previous_view)
	elif inventory.in_hq and not inventory_selection.is_empty():
		for index: int in range(inventory.entries.size()):
			if str(inventory.entries[index].id) == inventory_selection:
				inventory._select(index)
				break

func show_raid() -> void:
	_close_loot_view()
	body_status.show()
	for child: Node in panel_content.get_children():
		if child is InventoryPanel:
			panel_content.remove_child(child)
			child.queue_free()
	overlay.hide()
	for control: Control in game_controls:
		control.show()
	# Context elements begin hidden until a real interaction/notice is supplied.
	objectives.text = ""
	prompt.visible = not prompt.text.is_empty()
	interaction_signal.visible = prompt.visible
	interaction_signal.ratio = clampf(progress.value / 100.0, 0, 1)
	interaction_signal.queue_redraw()
	message.visible = not message.text.is_empty()
	progress.visible = progress.value > 0.0
	marker.hide()

func _close_loot_view() -> void:
	if is_instance_valid(loot_view):
		root.remove_child(loot_view)
		loot_view.queue_free()
	loot_view = null

func show_cache_choice(raid: Node, site: Dictionary) -> void:
	var pad_focus: Dictionary=loot_view.controller_focus_state() if is_instance_valid(loot_view) and GameInput.gamepad_active() else {}
	# This is a field interaction layered over the live camera, not a pause screen.
	show_raid()
	loot_view = LootPanel.new()
	root.add_child(loot_view)
	loot_view.configure(raid, site)
	if GameInput.gamepad_active():loot_view.call_deferred("restore_controller_focus",pad_focus)
	loot_view.action_requested.connect(func(action: String) -> void: action_requested.emit(action))

func show_pause(raid: Node, map_open: bool) -> void:
	_clear_panel()
	_translucent_menu_theme()
	_label(panel_content, "SHINRAI PARK  /  " + ("FIELD MAP" if map_open else "PAUSED"), 32, PAPER)
	if map_open:
		var chart := FieldMap.new()
		chart.raid = raid
		chart.focus_mode=Control.FOCUS_ALL
		chart.tooltip_text="Left / right: destination - A: track - Up / down: menu"
		chart.destination_selected.connect(func(id: String) -> void: action_requested.emit("track:" + id))
		chart.custom_minimum_size = Vector2(780,clampf(get_viewport().get_visible_rect().size.y*.38,280,470))
		panel_content.add_child(chart)
		map_view = chart
		_label(panel_content, "RELAYS / SEARCH / EXITS   ·   Pad: Left-Right + A   ·   Mouse: click", 18, Color("#c6d7d2"))
		var target: Dictionary = raid.tracked_objective()
		if not target.is_empty():
			_label(panel_content, "%s  ·  ~%dm suggested route" % [target.title, int(raid.guidance_distance)], 18, Color("#ddd4bd"))
		var names: Array[String] = []
		for item: Dictionary in raid.bag:
			names.append(item.title)
		var cargo := _label(panel_content, "CARGO %d/%d CELLS  ·  %s" % [raid.cargo_cells_used(), raid.capacity(), ", ".join(names) if not names.is_empty() else "Empty"], 18, PAPER)
		cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cargo.max_lines_visible = 2
		cargo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cargo.custom_minimum_size.x = 780
	_button("INVENTORY  ·  %d / %d cargo cells" % [raid.cargo_cells_used(), raid.capacity()], "inventory")
	_label(panel_content, "The raid clock and patrols are paused.", 19, Color("#ddd4bd"))
	_button("RESUME", "resume").grab_focus()
	var map_button:=Button.new();map_button.text="PAUSE MENU" if map_open else "FIELD MAP"
	map_button.pressed.connect(func() -> void:
		raid.map_open=not map_open
		show_pause(raid,not map_open))
	panel_content.add_child(map_button)
	_graphics_button(raid)
	_controls_help()
	_button("Abandon run…", "abandon_confirm")
	_button("QUIT TO DESKTOP", "quit_confirm")

func show_quit_confirmation(raid: Node) -> void:
	_clear_panel()
	_translucent_menu_theme()
	_label(panel_content, "QUIT TO DESKTOP?", 40, PAPER)
	var message := "Close Shinrai and return to the desktop."
	if raid.phase == raid.Phase.PAUSED:
		message = "Leaving ends this raid. Unbanked cargo will be lost.\nYour banked stash is kept."
	var warning := _label(panel_content, message, 22, Color("#ddd4bd"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.x = 780
	if not raid.profile.last_error.is_empty():
		var save_warning := _label(panel_content, "Some changes could not be saved.\n" + raid.profile.last_error, 20, Color("#ef9b8c"))
		save_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("BACK", "quit_cancel").grab_focus()
	_button("QUIT TO DESKTOP", "quit_desktop")

func show_abandon() -> void:
	_clear_panel()
	_label(panel_content, "ABANDON THIS RUN?", 40, PAPER)
	_label(panel_content, "You will lose everything you are carrying. Your banked stash is safe.", 22, GOLD)
	_button("Keep playing", "resume").grab_focus()
	_button("Abandon run", "abandon")

func show_pending_result(raid: Node) -> void:
	_clear_panel()
	_label(panel_content,"RESULT NOT SAVED",40,GOLD)
	_label(panel_content,"Your cargo is held in this session. Rewards have not been banked.",22,PAPER)
	_label(panel_content,raid.profile.last_error,20,GOLD)
	_label(panel_content,"Restore save-file access, then retry. Keep the game open until saving succeeds.",18,PAPER)
	var retry := _button("RETRY SAVE","retry_result_save")
	retry.disabled=not raid.can_retry_result_save()
	if not retry.disabled: retry.grab_focus()

func show_result(raid: Node, won: bool, reason: String, bonus: int) -> void:
	_clear_panel()
	_label(panel_content, "EXTRACTION CONFIRMED" if won else "SIGNAL LOST", 47, MINT if won else GOLD)
	_label(panel_content, reason, 24, PAPER)
	_label(panel_content, "RELAYS %d   /   HOSTILES %d   /   %s %d" % [raid.relays, raid.player.kills, "ITEMS BANKED" if won else "ITEMS LOST", raid.bag.size()], 23, PAPER)
	_label(panel_content, "CONTRACT BONUS  +%d credits" % bonus if won else "Your banked stash and upgrades are safe.", 23, MINT)
	if not raid.profile.last_error.is_empty():
		_label(panel_content, "SAVE FAILED: " + raid.profile.last_error, 20, GOLD)
	_button("RETURN TO OPERATIONS", "hq").grab_focus()

func update_raid(raid: Node) -> void:
	vitals_check=GameInput.down("inspect") and (overlay==null or not overlay.visible) and not raid.player.field_handling.check.active
	_update_field_handling(raid.player)
	var seconds := maxi(0, ceili(raid.remaining))
	telemetry.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	telemetry.modulate = Color(0.94, 0.48, 0.37, 0.92) if seconds < 90 else Color(1, 1, 1, 0.86)
	objectives.text = ""
	vitals.text = "%02d / %03d" % [raid.player.ammo, raid.player.reserve]
	vitals.visible = false
	var status := raid_status as RaidStatus
	_update_combat(raid)
	status.combat = float(raid.run_time) < _combat_until
	status.medkits = raid.medkits
	_sync_health(status, raid.player)
	var medical_state: Variant = raid.player.get("medical") if raid.player.get("extraction_mode") == true else null
	body_status.feed(medical_state, vitals_check)
	body_status.visible = overlay == null or not overlay.visible
	var remaining_stun: Variant = raid.player.get("stun_remaining")
	status.stun_remaining = maxf(0.0,float(remaining_stun)) if remaining_stun != null and bool(raid.player.get("drone_stun_active")) else 0.0
	var current_stamina: Variant = raid.player.get("stamina")
	var maximum_stamina: Variant = raid.player.get("max_stamina")
	status.stamina = float(current_stamina) if current_stamina != null else 100.0
	status.max_stamina = float(maximum_stamina) if maximum_stamina != null else 100.0
	status.reserve_energy = raid.metabolism.energy
	status.food_poison_remaining = maxf(0.0,float(raid.metabolism.nausea_remaining()))
	status.food_poison_severity = maxf(0.0,float(raid.metabolism.nausea_severity()))
	status.food_illness_label = str(raid.metabolism.illness_label())
	status.heart_rate_override = raid.metabolism.heart_rate
	status.crouching = bool(raid.player.get("crouching"))
	status.sprinting = bool(raid.player.get("sprinting"))
	status.coffee_remaining = float(raid.player.get("coffee_boost_remaining")) if raid.player.get("coffee_boost_remaining") != null else 0.0
	status.treatment_ratio = clampf(raid.progress_ratio, 0, 1)
	status.healing = float(raid.get("healing")) > 0.0
	status.inspecting = vitals_check and not raid.player.ads and raid.player.ads_blend <= 0.25
	status.aiming = raid.player.ads or raid.player.ads_blend > 0.25
	status.accept_health()
	status.queue_redraw()
	var supplies := ammo_status as AmmoStatus
	supplies.ammo = raid.player.ammo
	supplies.reserve = raid.player.reserve
	supplies.medkits = raid.medkits
	supplies.cargo = raid.cargo_cells_used()
	supplies.capacity = raid.capacity()
	supplies.cargo_mass_kg = raid.cargo_mass_kg()
	supplies.cargo_limit_kg = raid.cargo_limit_kg()
	supplies.reloading = raid.player.reloading
	if raid.player.has_method("hud_weapon_state"):
		var weapon_state: Dictionary = raid.player.hud_weapon_state()
		supplies.weapon_name = str(weapon_state.get("name", "UZI"))
		supplies.magazine_capacity = maxi(1, int(weapon_state.get("magazine_capacity", 30)))
		supplies.fire_mode = str(weapon_state.get("fire_mode", "AUTO"))
		supplies.reload_ratio = clampf(float(weapon_state.get("reload_ratio", -1.0)), -1.0, 1.0)
	var mission := mission_status as MissionStatus
	mission.relays = raid.relays
	mission.urgent = seconds < 90
	_update_notice(raid)
	prompt.text = raid.prompt_text
	prompt.visible = not prompt.text.is_empty()
	interaction_signal.visible = prompt.visible
	interaction_signal.ratio = clampf(progress.value / 100.0, 0, 1)
	interaction_signal.queue_redraw()
	progress.value = raid.progress_ratio * 100.0
	interaction_signal.ratio = clampf(raid.progress_ratio, 0, 1)
	progress.visible = raid.progress_ratio > 0.0
	marker.hide()
	# Destinations remain on the field map; no floating world-space icon.

func _update_field_handling(player: Node) -> void:
	var info: Dictionary = player.field_handling.hud_state()
	var lines: Array[String] = []
	if not str(info.message).is_empty(): lines.append(str(info.message))
	var arms: float = float(info.arms)
	if vitals_check or arms < 70.0 or (player.weapon_lowered and arms < 99.5):
		var cue := " · " + GameInput.hint("B") + " REST" if arms < 70.0 and not player.weapon_lowered else (" · RECOVERING" if player.weapon_lowered and arms < 99.5 else "")
		lines.append("ARMS %d%%" % ceili(arms) + cue)
	weapon_readiness.text = "\n".join(lines)
	weapon_readiness.visible = not lines.is_empty() and not overlay.visible
	weapon_readiness.modulate = GOLD if arms < 25.0 else MINT

func _sync_health(status: RaidStatus, player: Node) -> void:
	status.actual_hp = float(player.health)
	status.max_hp = float(player.max_health()) if player.has_method("max_health") else 100.0
	status.health = clampf(float(player.health_ratio()) * 100.0, 0.0, 100.0) if player.has_method("health_ratio") else clampf(player.health, 0.0, 100.0)
	var medical: Variant = player.get("medical") if player.get("extraction_mode") == true else null
	status.medkit_target_available = not str(medical.treatment_target("medkit")).is_empty() if medical != null and medical.has_method("treatment_target") else true

func _update_notice(raid: Node) -> void:
	var current: String = raid.notice if raid.notice_time > 0.0 else ""
	var now := Time.get_ticks_msec() / 1000.0
	if current != _notice_text or float(raid.notice_time) > _notice_remaining + 0.01:
		_notice_text = current
		_notice_started_at = now
	_notice_remaining = float(raid.notice_time)
	var left := minf(float(raid.notice_time), 3.2 - (now - _notice_started_at))
	message.text = current
	message.visible = not current.is_empty() and left > 0.0
	message.modulate.a = clampf(left / 0.45, 0.0, 0.85)

func _short_target(title: String) -> String:
	var short := title.replace("Telemetry relay", "Relay").replace("telemetry relay", "Relay").replace("Extraction", "Exit").replace("extraction", "Exit")
	return short.left(24)

# Actual HP/stamina with an explicitly authored, state-driven HUD heart rate.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_V and not event.echo:
		if overlay != null and not overlay.visible:
			vitals_check = event.pressed
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			vitals_check = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		vitals_check = false

# Presentation-only engagement memory. Read real AI combat and actual shot events.
# No enemy AI, weapon, inventory or raid mechanics are changed here.
func _update_combat(raid: Node) -> void:
	var now := float(raid.run_time)
	if now < _last_raid_time: _combat_until = -100.0
	_last_raid_time = now
	if _observed_player != raid.player:
		if is_instance_valid(_observed_player) and _observed_player.has_signal("shot_fired") and _observed_player.is_connected("shot_fired",_on_hud_shot):
			_observed_player.disconnect("shot_fired",_on_hud_shot)
		_observed_player = raid.player
		if _observed_player.has_signal("shot_fired") and not _observed_player.is_connected("shot_fired",_on_hud_shot):
			_observed_player.connect("shot_fired",_on_hud_shot)
	for hostile: Node in get_tree().get_nodes_in_group("extraction_hostiles"):
		if hostile.has_method("is_in_combat_with") and hostile.is_in_combat_with(raid.player):
			_combat_until = now + 6.0
			break
		if hostile is HudHostile and hostile.health > 0 and hostile.target == raid.player and hostile.state == HudHostile.AIState.COMBAT:
			_combat_until = now + 6.0
			break

func _on_hud_shot() -> void:
	_combat_until = _last_raid_time + 6.0

class Optical:
	const CONTEXT_HOLD := 5.0
	const WHITE := Color("eaf6f2")
	const CYAN := Color("9ce9dc")
	const AMBER := Color("ffd6a0")
	const ALERT := Color("ff4931")
	static func text(c: Control, at: Vector2, value: String, px: int, tint: Color) -> void:
		var font := c.get_theme_default_font()
		c.draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, Color(.015, .035, .045, .92 * tint.a))
		c.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)
	static func line(c: Control, a: Vector2, b: Vector2, tint: Color, width: float = 1.0) -> void:
		c.draw_line(a, b, Color(.01, .025, .035, .75 * tint.a), width + 2, true)
		c.draw_line(a, b, tint, width, true)
	static func arc(c: Control, at: Vector2, radius: float, start: float, end: float, tint: Color, width: float = 2.0) -> void:
		if end <= start: return
		c.draw_arc(at, radius, start, end, 48, Color(.01, .025, .035, .75), width + 3, true)
		c.draw_arc(at, radius, start, end, 48, tint, width, true)

class RaidStatus extends Control:
	var medkits := 1
	var medkit_target_available := true
	var health := 100.0
	var actual_hp := -1.0
	var max_hp := 100.0
	var stun_remaining := 0.0
	var stamina := 100.0
	var max_stamina := 100.0
	var crouching := false
	var sprinting := false
	var coffee_remaining := 0.0
	var combat := false
	var healing := false
	var inspecting := false
	var aiming := false
	var treatment_ratio := 0.0
	var emphasis := 0.0
	var damage_echo := 0.0
	var last_health := -1.0
	var pulse_clock := 0.0
	var heart_rate := 68.0
	var heart_rate_override := -1.0
	var reserve_energy := 100.0
	var food_poison_remaining := 0.0
	var food_poison_severity := 0.0
	var food_illness_label := ""
	var pulse_speed := 68.0 / 60.0
	var symbol_clock := 0.0
	var check_focus := 0.0
	var recovery_echo := 0.0
	var recovered_amount := 0.0
	var was_healing := false
	var stamina_alpha := 0.0
	var support_alpha := 0.0
	var condition_alpha := 0.0
	var stamina_hold := 0.0
	var support_hold := 0.0
	var condition_hold := 0.0
	func accept_health() -> void:
		if last_health >= 0 and health < last_health:
			damage_echo = 1.0
			pulse_clock = floorf(pulse_clock) + .375
		if last_health > 0 and health > last_health and was_healing:
			recovery_echo = 1.0
			recovered_amount = (health - last_health) * max_hp / 100.0
		last_health = health
		was_healing = healing
	func _process(delta: float) -> void:
		if not visible: return
		var energy := stamina / maxf(1.0, max_stamina)
		var target := 1.0 if stun_remaining > 0 or inspecting or healing or health < 35 or energy < .2 else .55 if combat else .45 if sprinting or health < 100 else 0.0
		emphasis = move_toward(emphasis, target, delta * (4.0 if target > emphasis else 1.2))
		check_focus = move_toward(check_focus, 1.0 if inspecting and not aiming else 0.0, delta * 3.5)
		var checking := inspecting and not aiming
		var stamina_needed := checking or energy < .995 or sprinting or crouching
		var support_needed := checking or health < 100 or healing or recovery_echo > 0 or coffee_remaining > 0
		var condition_needed := stun_remaining > 0 or checking or combat or health < 100 or healing or recovery_echo > 0 or sprinting or energy < .2
		stamina_alpha = held_reveal(stamina_alpha,stamina_hold,stamina_needed,delta)
		support_alpha = held_reveal(support_alpha,support_hold,support_needed,delta)
		condition_alpha = held_reveal(condition_alpha,condition_hold,condition_needed,delta)
		stamina_hold = Optical.CONTEXT_HOLD if stamina_needed else maxf(0.0,stamina_hold-delta)
		support_hold = Optical.CONTEXT_HOLD if support_needed else maxf(0.0,support_hold-delta)
		condition_hold = Optical.CONTEXT_HOLD if condition_needed else maxf(0.0,condition_hold-delta)
		# Shared game BPM drives both the HUD and slow reserve consumption.
		var rate := target_heart_rate()
		heart_rate = (heart_rate_override if heart_rate_override >= 0.0 else move_toward(heart_rate, rate, delta * (32.0 if rate > heart_rate else 18.0))) if health > 0 else 0.0
		pulse_speed = heart_rate / 60.0
		if health > 0: pulse_clock += delta * pulse_speed
		symbol_clock += delta
		recovery_echo = maxf(0, recovery_echo - delta)
		damage_echo = maxf(0, damage_echo - delta * 1.4)
		queue_redraw()
	static func reveal(value: float, needed: bool, delta: float) -> float:
		return move_toward(value,1.0 if needed else 0.0,delta * (5.0 if needed else 1.8))
	static func held_reveal(value: float, hold: float, needed: bool, delta: float) -> float:
		if needed: return reveal(value,true,delta)
		# Only the portion of this frame after the hold expires can fade.
		var held := reveal(value,true,minf(delta,hold)) if hold > 0 else value
		return reveal(held,false,maxf(0.0,delta-hold))
	func target_heart_rate() -> float:
		if health <= 0: return 0.0
		if healing: return 118.0 if combat else 78.0
		var rate := (152.0 if health < 35 else 136.0 if health < 100 else 112.0) if combat else (100.0 if health < 35 else 88.0 if health < 100 else 68.0)
		if sprinting: rate += 18.0
		if stamina / maxf(1.0,max_stamina) < .2: rate += 10.0
		return minf(rate,170.0)
	func draw_medical_sign(tint: Color, beat: float) -> void:
		var danger := danger_strength()
		var outline := PackedVector2Array([Vector2(35,35),Vector2(65,35),Vector2(65,60),Vector2(90,60),Vector2(90,90),Vector2(65,90),Vector2(65,115),Vector2(35,115),Vector2(35,90),Vector2(10,90),Vector2(10,60),Vector2(35,60)])
		draw_colored_polygon(outline,Color(.015,.045,.04,.72))
		draw_colored_polygon(outline,Color(tint,.10 + beat * .04))
		outline.append(outline[0])
		draw_polyline(outline,Color(tint,.10 + beat * .10 + danger * .14),9 + danger * 3,true)
		draw_polyline(outline,Color(tint,.88 + danger * .12),3.5 + danger * .7,true)
		if danger > .01:
			# Sparse, deterministic phosphor fizz. Only the outline distorts;
			# fixed text and the symbol contents remain readable.
			var tick := int(symbol_clock * 13.0)
			for i: int in range(12):
				if (i * 7 + tick) % 5 > 1: continue
				var a := outline[i]
				var b := outline[i+1]
				var t := fposmod(float(tick * 17 + i * 31) * .037, .75)
				var jitter := Vector2(sin(float(tick * 11+i)*2.3),cos(float(tick*7+i)*1.9)) * 1.8 * danger
				var from := a.lerp(b,t) + jitter
				var to := a.lerp(b,minf(t+.18,1.0)) + jitter
				draw_line(from,to,Color("ffe3a8",.55 * danger),1.0,true)
		var mode := int(symbol_clock / 2.5) % 3
		if health <= 0:
			Optical.line(self,Vector2(26,75),Vector2(74,75),tint,2)
		elif stun_remaining > 0:
			# Native bolt geometry remains legible without an emoji-font fallback.
			var bolt := PackedVector2Array([Vector2(56,47),Vector2(34,78),Vector2(47,78),Vector2(40,106),Vector2(66,70),Vector2(53,70)])
			draw_colored_polygon(bolt,Color("72dfff"))
		elif healing:
			Optical.text(self,Vector2(39,80),"+",24,tint)
			Optical.line(self,Vector2(38,99),Vector2(38 + 24 * treatment_ratio,99),tint,2)
		elif mode == 0:
			var heart := PackedVector2Array()
			for i: int in range(49):
				var t := TAU * i / 48.0
				var scale := .82 + beat * .15
				heart.append(Vector2(50,77) + Vector2(16 * pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t))) * scale)
			draw_colored_polygon(heart,tint)
		elif mode == 1:
			var trace := PackedVector2Array()
			for i: int in range(81):
				var x := float(i)/80.0
				trace.append(Vector2(20 + 60*x,77 - pulse_shape(pulse_clock-x)*16))
			draw_polyline(trace,tint,2,true)
		else:
			var value := ("%.1f" % (actual_hp if actual_hp >= 0.0 else health)).trim_suffix(".0")
			var w := get_theme_default_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
			Optical.text(self,Vector2(50-w*.5,82),value,20,tint)
			Optical.text(self,Vector2(42,105),"HP",10,tint)
	func danger_strength() -> float:
		if health <= 0: return 0.0
		return maxf(damage_echo,1.0 if health < 35 else .38 if combat else 0.0)
	static func pulse_shape(phase: float) -> float:
		var t := fposmod(phase, 1.0)
		return .16 * exp(-pow((t - .20) / .045, 2)) - .26 * exp(-pow((t - .34) / .018, 2)) + exp(-pow((t - .375) / .012, 2)) - .42 * exp(-pow((t - .405) / .022, 2)) + .22 * exp(-pow((t - .54) / .07, 2))
	func _draw() -> void:
		var energy := clampf(stamina / maxf(1, max_stamina), 0, 1)
		var tint := Optical.ALERT if health < 35 else Color("ff7146") if combat else Optical.AMBER if health < 100 else Optical.WHITE
		if (healing or recovery_echo > 0) and health >= 35: tint = Optical.CYAN
		if damage_echo > .01: tint = tint.lerp(Optical.ALERT,damage_echo * .8)
		var focus := check_focus if not aiming else 0.0
		var drift := Vector2(focus * 4, sin(pulse_clock * .6) * .55)
		draw_set_transform(drift)
		# Open medical display: the cross and living pulse define its shape.
		if focus > .02:
			Optical.text(self,Vector2(110,16),"SELF / CHECK",11,Color(Optical.CYAN,focus * .8))
		var beat := maxf(0.0, pulse_shape(pulse_clock))
		draw_medical_sign(tint,beat)
		Optical.text(self,Vector2(110,45),"HEALTH",13,Color(tint,.88))
		Optical.text(self,Vector2(108,81),("%.1f" % (actual_hp if actual_hp >= 0.0 else health)).trim_suffix(".0"),32,tint)
		Optical.text(self,Vector2(180,79),"HP",14,Color(Optical.WHITE,.85))
		Optical.text(self,Vector2(234,45),"HEART RATE",11,Color(tint,.88))
		Optical.text(self,Vector2(232,81),"%03d" % roundi(heart_rate),26,tint)
		Optical.text(self,Vector2(286,80),"BPM",11,Color(Optical.WHITE,.85))
		if focus > .5: Optical.text(self,Vector2(110,104),"/ %s HP" % ("%.1f" % max_hp).trim_suffix(".0"),12,Color(Optical.WHITE,.75))
		var width := 205.0 + emphasis * 42 + focus * 35
		var amplitude := (7.0 + emphasis * 7 + damage_echo * 5 + (4.0 if combat else 0.0)) if health > 0 else 0.0
		var trace := PackedVector2Array()
		var trace_colors := PackedColorArray()
		var ghost_colors := PackedColorArray()
		var shadow_colors := PackedColorArray()
		var bloom_colors := PackedColorArray()
		for i: int in range(161):
			var x := float(i) / 160.0
			trace.append(Vector2(17 + x * width,146 - pulse_shape(pulse_clock - x * 1.15) * amplitude))
			var fade := smoothstep(0.0,.09,x) * (1.0-smoothstep(.87,1.0,x))
			trace_colors.append(Color(tint,(.62 + emphasis * .25) * fade))
			ghost_colors.append(Color(tint,.13 * fade))
			shadow_colors.append(Color(.01,.025,.035,.70 * fade))
			bloom_colors.append(Color(tint,(.045 + emphasis * .025) * fade))
		# Faint displaced phosphor image lends depth to a lens projection.
		var ghost := PackedVector2Array()
		for point: Vector2 in trace: ghost.append(point + Vector2(0, 1.4))
		draw_polyline_colors(trace,bloom_colors,5,true)
		draw_polyline_colors(ghost,ghost_colors,2,true)
		draw_polyline_colors(trace,shadow_colors,3.5,true)
		draw_polyline_colors(trace,trace_colors,1.2,true)
		var condition := condition_text()
		if stun_remaining > 0 and health > 0:
			var stun_box := Rect2(10,157,314,31)
			draw_rect(stun_box,Color(.015,.035,.05,.92))
			draw_rect(stun_box,Color("72dfff"),false,1.2)
			Optical.text(self,Vector2(22,179),condition,18,Color("bcefff"))
		else:
			Optical.text(self,Vector2(18,178),condition,14,Color(tint,.9 * condition_alpha))
		if healing:
			Optical.line(self,Vector2(17,157),Vector2(17 + width * treatment_ratio,157),Optical.CYAN,1.5)
			var end := Vector2(17 + width * treatment_ratio,157)
			Optical.line(self,end + Vector2(0,-3),end + Vector2(0,3),Optical.WHITE)
		var stamina_text := "STAMINA %03d / %03d" % [ceili(stamina),ceili(max_stamina)] if focus > .5 else "STAMINA %03d" % ceili(stamina)
		Optical.text(self,Vector2(18,211),stamina_text,15,Color(Optical.AMBER if energy < .2 else Optical.WHITE,stamina_alpha * .9))
		var inset := focus * 46
		Optical.line(self,Vector2(149 + inset,206),Vector2(205 + inset,206),Color(Optical.WHITE,.2 * stamina_alpha))
		Optical.line(self,Vector2(149 + inset,206),Vector2(149 + inset + 56 * energy,206),Color(Optical.AMBER if energy < .2 else Optical.CYAN,stamina_alpha * .7))
		if energy < .2: Optical.text(self,Vector2(217 + inset,211),"LOW / REST",12,Color(Optical.AMBER,stamina_alpha))
		elif crouching: Optical.text(self,Vector2(217 + inset,211),"CROUCH",12,Color(Optical.CYAN,stamina_alpha))
		elif sprinting: Optical.text(self,Vector2(217 + inset,211),"SPRINT",12,Color(Optical.CYAN,stamina_alpha))
		var treatment_stock := "MEDKITS %02d" % medkits if medkits > 0 else "NO MEDKITS"
		if health < 100 and medkits > 0 and medkit_target_available and not healing and focus < .5: treatment_stock = GameInput.hint("H")+" · TREAT   MED %02d" % medkits
		if coffee_remaining > 0: treatment_stock += " · COFFEE %d:%02d" % [int(coffee_remaining)/60,int(coffee_remaining)%60]
		Optical.text(self,Vector2(18,237),"ENERGY %03d" % ceili(reserve_energy),15,Color(Optical.AMBER,0.9))
		Optical.line(self,Vector2(149,232),Vector2(293,232),Color(Optical.WHITE,.20))
		Optical.line(self,Vector2(149,232),Vector2(149+144*clampf(reserve_energy/100.0,0,1),232),Color(Optical.AMBER,.80),2)
		Optical.text(self,Vector2(18,269),treatment_stock,13,Color(Optical.WHITE,support_alpha))
		if food_poison_remaining > 0.0:
			var seconds := maxi(1,ceili(food_poison_remaining))
			Optical.text(self,Vector2(18,291),"SICK  NAUSEA %d:%02d" % [seconds/60,seconds%60],13,Color(Optical.AMBER,.95))
		if damage_echo > .01:
			# The cross itself carries damage fizz; no detached edge marks.
			if damage_echo > .20: Optical.text(self,Vector2(110,123),"INJURY",13,Color(Optical.ALERT,.9))
		draw_set_transform(Vector2.ZERO)

	func condition_text() -> String:
		if health <= 0: return "DOWN"
		if stun_remaining > 0: return "STUNNED  ·  %.1f s" % stun_remaining
		if healing: return "COMBAT · TREATING" if combat else "TREATING · HOLD H"
		if recovery_echo > 0: return ("COMBAT · +%d HP" if combat else "RECOVERING · +%d HP") % ceili(recovered_amount)
		if combat: return "COMBAT · CRITICAL" if health < 35 else "COMBAT · INJURED" if health < 100 else "COMBAT · ALERT"
		if health < 35: return "OUT OF COMBAT · CRITICAL"
		if health < 100: return "OUT OF COMBAT · INJURED"
		if sprinting or stamina / maxf(1,max_stamina) < .2: return "UNDER STRAIN"
		return "OUT OF COMBAT · STEADY"

class AmmoStatus extends Control:
	var medkits := 1
	var cargo := 0:
		set(value):
			if cargo == value: return
			cargo = value
			queue_redraw()
	var capacity := 6:
		set(value):
			if capacity == value: return
			capacity = value
			queue_redraw()
	var cargo_mass_kg := 0.0:
		set(value):
			if cargo_mass_kg == value: return
			cargo_mass_kg = value
			queue_redraw()
	var cargo_limit_kg := 20.0:
		set(value):
			if cargo_limit_kg == value: return
			cargo_limit_kg = value
			queue_redraw()
	var reloading := false:
		set(value):
			if reloading == value: return
			reloading = value
			queue_redraw()
	var ammo := 30:
		set(value):
			if ammo == value: return
			ammo = value
			queue_redraw()
	var reserve := 90:
		set(value):
			if reserve == value: return
			reserve = value
			queue_redraw()
	var weapon_name := "UZI":
		set(value):
			if weapon_name == value: return
			weapon_name = value
			queue_redraw()
	var magazine_capacity := 30:
		set(value):
			if magazine_capacity == value: return
			magazine_capacity = value
			queue_redraw()
	var fire_mode := "AUTO":
		set(value):
			if fire_mode == value: return
			fire_mode = value
			queue_redraw()
	var reload_ratio := -1.0:
		set(value):
			if reload_ratio == value: return
			reload_ratio = value
			queue_redraw()
	var detail_alpha := 0.0
	var cargo_alpha := 0.0
	var activity_hold := 0.0
	var cargo_hold := 0.0
	var last_ammo := -1
	var last_weapon := ""
	func _process(delta: float) -> void:
		if not visible: return
		var previous_detail_alpha := detail_alpha
		var previous_cargo_alpha := cargo_alpha
		var changed := last_ammo >= 0 and (ammo != last_ammo or weapon_name != last_weapon)
		var needed := changed or reloading or ammo <= maxi(1,int(magazine_capacity*.2))
		detail_alpha = RaidStatus.held_reveal(detail_alpha,activity_hold,needed,delta)
		cargo_alpha = RaidStatus.held_reveal(cargo_alpha,cargo_hold,cargo > 0,delta)
		activity_hold = Optical.CONTEXT_HOLD if needed else maxf(0.0,activity_hold-delta)
		cargo_hold = Optical.CONTEXT_HOLD if cargo > 0 else maxf(0.0,cargo_hold-delta)
		last_ammo = ammo
		last_weapon = weapon_name
		if detail_alpha != previous_detail_alpha or cargo_alpha != previous_cargo_alpha:
			queue_redraw()
	func _draw() -> void:
		var accent := Optical.AMBER if ammo <= maxi(1, int(magazine_capacity * .2)) else Optical.WHITE
		Optical.text(self, Vector2(20, 32), weapon_name.to_upper().left(24), 13, Color(Optical.WHITE,.8 * detail_alpha))
		Optical.text(self, Vector2(20, 80), "%02d" % ammo, 34, accent)
		Optical.text(self, Vector2(83, 77), "/ %03d" % reserve, 18, Optical.WHITE)
		var fraction := clampf(float(ammo) / magazine_capacity, 0, 1)
		var state := "FIND A WEAPON" if weapon_name == "UNARMED" else "RELOADING" if reloading else ("EMPTY · "+GameInput.hint("R")+" RELOAD") if ammo == 0 else ("LOW · "+GameInput.hint("R")+" RELOAD") if fraction <= .2 else fire_mode
		Optical.text(self, Vector2(20, 121), state, 13, Color(accent,detail_alpha))
		if reloading and reload_ratio >= 0:
			Optical.line(self, Vector2(20, 130), Vector2(184, 130), Color("476461"))
			Optical.line(self, Vector2(20, 130), Vector2(20 + 164 * reload_ratio, 130), Optical.CYAN, 2)
		Optical.text(self,Vector2(20,154),"CELLS %d/%d" % [cargo,capacity],15,Color(Optical.AMBER if cargo>=capacity else Optical.CYAN,cargo_alpha))
		Optical.text(self,Vector2(20,174),"MASS %.1f/%.1f kg" % [cargo_mass_kg,cargo_limit_kg],13,Color(Optical.AMBER if cargo_mass_kg>=cargo_limit_kg else Optical.CYAN,cargo_alpha))

class MissionStatus extends Control:
	var relays := 0:
		set(value):
			if relays == value: return
			relays = value
			queue_redraw()
	var urgent := false:
		set(value):
			if urgent == value: return
			urgent = value
			queue_redraw()
	func _draw() -> void:
		var accent := Optical.AMBER if urgent else Optical.CYAN
		Optical.line(self, Vector2(0, 5), Vector2(280, 0), Color(accent, .20))
		Optical.text(self, Vector2(0, 26), "EXTRACTION" if not urgent else "TIME LOW", 14, accent)
		for i: int in range(3):
			var point := Vector2(6 + i * 17, 53)
			var diamond := PackedVector2Array([point + Vector2(0, -4), point + Vector2(4, 0), point + Vector2(0, 4), point + Vector2(-4, 0), point + Vector2(0, -4)])
			draw_polyline(diamond, accent if i < relays else Color("476461"), 1.5, true)
		Optical.text(self, Vector2(62, 58), "%d/3 RELAYS" % relays, 14, Optical.WHITE)
		Optical.text(self, Vector2(0, 83), "EXIT OPEN" if relays > 0 else "LINK A RELAY TO OPEN EXIT", 13, accent)

class InteractionSignal extends Control:
	var ratio := 0.0
	func _draw() -> void:
		Optical.line(self,Vector2(10,9),Vector2(10,27),Color(Optical.CYAN,.5))
		Optical.line(self,Vector2(10,9),Vector2(17,9),Color(Optical.CYAN,.5))
		Optical.line(self,Vector2(24,27),Vector2(31,27),Color(Optical.CYAN,.5))
		Optical.line(self,Vector2(31,9),Vector2(31,27),Color(Optical.CYAN,.5))
		Optical.line(self,Vector2(13,18),Vector2(13 + 15 * ratio,18),Optical.WHITE,1.5)
		Optical.line(self,Vector2(39,18),Vector2(60,18),Color(Optical.CYAN,.25))

class FieldMap extends Control:
	var pad_destination:=0
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_FOCUS_ENTER,NOTIFICATION_FOCUS_EXIT]:queue_redraw()
	func _destinations() -> Array[Dictionary]:
		var points: Array[Dictionary]=[]
		for site: Dictionary in raid.sites+raid.exits:
			if not site.get("done",false):points.append(site)
		return points
	var printed_map := false
	var show_player := true
	signal destination_selected(id: String)
	var raid: Node
	func _gui_input(event: InputEvent) -> void:
		if printed_map:
			return
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			var points:=_destinations()
			if points.is_empty():return
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
				pad_destination=posmod(pad_destination+(-1 if event.is_action_pressed("ui_left") else 1),points.size());queue_redraw();accept_event()
			elif event.is_action_pressed("ui_accept"):
				destination_selected.emit(str(points[clampi(pad_destination,0,points.size()-1)].id));accept_event()
			return
		if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		var best := 15.0
		var selected := ""
		for site: Dictionary in raid.sites + raid.exits:
			if site.get("done", false):
				continue
			var p: Vector3 = site.position
			var distance := project(Vector2(p.x, p.z)).distance_to(event.position)
			if distance < best:
				best = distance
				selected = site.id
		if not selected.is_empty():
			accept_event()
			destination_selected.emit(selected)
	func project(p: Vector2) -> Vector2:
		if printed_map:
			return (Vector2(79,219)+(p+Vector2(220,180))/Vector2(440,360)*Vector2(865,690))/1024.0*size
		return Vector2(28, 20) + (p + Vector2(220, 180)) / Vector2(440, 360) * Vector2(size.x - 56, size.y - 40)
	func _draw() -> void:
		if printed_map:
			var texture:=preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/information_board/midori_information_board_midori_information_map_draft_v2_1k.png")
			draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false)
			if show_player:
				var world: Vector3=raid.player.global_position
				var center:=project(Vector2(world.x,world.z))
				draw_circle(center,11,Color("#143f42"))
				var arrow:=PackedVector2Array()
				for p: Vector2 in [Vector2(0,-8),Vector2(-5,6),Vector2(5,6)]: arrow.append(center+p.rotated(-raid.player.rotation.y))
				draw_colored_polygon(arrow,Color.WHITE)
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("#11232b"))
		var lake := PackedVector2Array()
		for p: Vector2 in raid.navigation.shoreline:
			lake.append(project(p))
		draw_colored_polygon(lake, Color("#285e70"))
		for route: Array in raid.map_routes:
			var line := PackedVector2Array()
			for p: Vector2 in route:
				line.append(project(p * 2.0))
			draw_polyline(line, Color("#617577"), 2.0, true)
		for site: Dictionary in raid.sites:
			if not site.get("spawned",true): continue
			var p: Vector3 = site.position
			draw_circle(project(Vector2(p.x, p.z)), 5 if site.kind == "relay" else 2.5, Color("#486061") if site.done else Color("#e5bc7f"))
		var guidance := PackedVector2Array()
		for point: Vector3 in raid.guidance_path:
			guidance.append(project(Vector2(point.x, point.z)))
		if guidance.size() > 1:
			draw_polyline(guidance, Color("#85dfc4"), 3.0, true)
		var target: Dictionary = raid.tracked_objective()
		if not target.is_empty():
			var target_p: Vector3 = target.position
			draw_arc(project(Vector2(target_p.x, target_p.z)), 10.0, 0.0, TAU, 24, Color("#85dfc4"), 2.0, true)
		for point: Vector3 in raid.approach_cover.placements:
			draw_circle(project(Vector2(point.x, point.z)), 2.0, Color("#88928d"))
		var torii := project(Vector2(164, 136))
		draw_arc(torii, 8.0, 0.0, TAU, 20, Color("#e5bc7f"), 2.0, true)
		draw_string(get_theme_default_font(), torii + Vector2(-32, 23), "TORII", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e5bc7f"))
		for exit_point: Dictionary in raid.exits:
			var p: Vector3 = exit_point.position
			draw_rect(Rect2(project(Vector2(p.x, p.z)) - Vector2(6, 6), Vector2(12, 12)), Color("#85dfc4"), false, 2.0)
		if has_focus() and not printed_map:
			var points:=_destinations()
			if not points.is_empty():
				var picked: Dictionary=points[clampi(pad_destination,0,points.size()-1)]
				var picked_position: Vector3=picked.position
				draw_arc(project(Vector2(picked_position.x,picked_position.z)),13,0,TAU,32,Color.WHITE,2)
				draw_string(get_theme_default_font(),Vector2(18,26),"TRACK: "+str(picked.title),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		if not show_player: return
		var p: Vector3 = raid.player.global_position
		var center := project(Vector2(p.x, p.z))
		var triangle := PackedVector2Array()
		for v: Vector2 in [Vector2(0, -10), Vector2(-6, 6), Vector2(6, 6)]:
			triangle.append(center + v.rotated(-raid.player.rotation.y))
		draw_colored_polygon(triangle, Color.WHITE)

func show_collected_map(raid: Node) -> void:
	var return_view: Dictionary = {}
	var owner_id := raid.get_instance_id()
	for child: Node in panel_content.get_children():
		if child is InventoryPanel and child.raid == raid:
			return_view = child.view_state()
			break
	_clear_panel()
	_label(panel_content,"MIDORI PARK  /  COLLECTED VISITOR MAP",30,PAPER)
	var chart:=FieldMap.new()
	chart.raid=raid
	chart.show_player=raid.phase != raid.Phase.HQ
	chart.printed_map=true
	chart.custom_minimum_size=Vector2(620,620)
	chart.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	panel_content.add_child(chart)
	map_view=chart
	_label(panel_content,"YOU  △  ·  Red printed marker: information board" if chart.show_player else "Saved park map · No active deployment",18,MINT)
	# Only this Back button owns the snapshot; other exits cannot replay it.
	var back := Button.new()
	back.text = "BACK TO INVENTORY"
	back.pressed.connect(func() -> void:
		action_requested.emit("inventory")
		if return_view.is_empty(): return
		for child: Node in panel_content.get_children():
			if child is InventoryPanel and is_instance_valid(child.raid) and child.raid.get_instance_id() == owner_id:
				child.restore_view_state(return_view)
				break)
	panel_content.add_child(back)
	back.grab_focus()

func _controls_help() -> void:
	var button:=Button.new();button.text="CONTROLS HELP"
	panel_content.add_child(button)
	var help:=VBoxContainer.new();panel_content.add_child(help);help.hide()
	var pad:=_label(help,"Xbox: LS move / RS look / L3 sprint / A jump / B crouch / X reload / Y weapons\nRT fire / LT aim / RB interact / LB heal / Dpad Up eat / Dpad Down lower weapon\nView inventory / Menu pause / Hold R3 vitals / R3 + X check magazine\nMenus: Dpad or LS navigate / A select / B back\nInventory: LB-RB categories or tabs / Y cargo-actions",16,Color("aabbbd"))
	pad.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var keys:=_label(help,"Keyboard: WASD move / Shift sprint / Ctrl crouch / Space jump\nLMB fire / RMB aim / R reload / J check magazine / B lower weapon\nHold E interact / Hold H heal / Hold V vitals\nI inventory / Tab map / Esc pause / T target / F7 graphics",16,Color("aabbbd"))
	keys.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func() -> void:
		help.visible=not help.visible
		button.text="HIDE CONTROLS HELP" if help.visible else "CONTROLS HELP"
		call_deferred("_fit_menu_scroll"))

func _set_menu_scrolling(enabled: bool) -> void:
	if not is_instance_valid(menu_scroll) or not is_instance_valid(panel_content):return
	var destination: Node=menu_scroll if enabled else menu_center
	if panel_content.get_parent()!=destination:panel_content.reparent(destination,false)
	menu_scroll.visible=enabled
	if enabled:menu_scroll.scroll_vertical=0

func _fit_menu_scroll() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(menu_scroll) or not menu_scroll.visible:return
	var screen:=get_viewport().get_visible_rect().size
	menu_scroll.custom_minimum_size=Vector2(minf(820.0,screen.x-40.0),minf(panel_content.get_combined_minimum_size().y,screen.y-40.0))
	var focused:=get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and panel_content.is_ancestor_of(focused):menu_scroll.ensure_control_visible(focused)

func _graphics_button(raid: Node) -> void:
	var park: Node=raid.get_parent()
	if not park.has_method("_apply_render_quality"):return
	var button:=Button.new();button.text="GRAPHICS: "+("HIGH" if bool(park.get("high_render_quality")) else "BALANCED")
	button.pressed.connect(func() -> void:
		park.set("high_render_quality",not bool(park.get("high_render_quality")))
		park.call("_apply_render_quality")
		if park.has_method("_update_time_label"):park.call("_update_time_label")
		button.text="GRAPHICS: "+("HIGH" if bool(park.get("high_render_quality")) else "BALANCED"))
	panel_content.add_child(button)

## A soft, dark edge frames the view and pulls the eye to the centre. Drawn
## beneath every HUD element; never blocks input.
func _add_vignette() -> void:
	var vignette := ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.42;
uniform float softness : hint_range(0.1, 2.0) = 1.15;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.15;
	float d = length(p);
	float v = smoothstep(0.55, 1.75 * softness, d) * strength;
	// A touch of fine grain so flat gradients never band.
	float grain = fract(sin(dot(UV * 1920.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	COLOR = vec4(vec3(0.0), clamp(v + grain * 0.012, 0.0, 1.0));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	vignette.material = material
	root.add_child(vignette)
	root.move_child(vignette, 0)
