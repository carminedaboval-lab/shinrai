extends CanvasLayer

signal action_requested(action: String)
const INK := Color("#09151d")
const PAPER := Color("#e8eee7")
const MINT := Color("#85dfc4")
const GOLD := Color("#e5bc7f")
var root: Control
var telemetry: Label
var objectives: Label
var vitals: Label
var prompt: Label
var message: Label
var marker: Label
var progress: ProgressBar
var overlay: ColorRect
var panel_content: VBoxContainer
var map_view: Control
var game_controls: Array[Control] = []

func _ready() -> void:
	layer = 60
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 23
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1a383f") if style_name == "hover" else Color("#14272f")
		style.border_color = MINT if style_name == "focus" else Color("#33565c")
		style.set_border_width_all(1)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 13
		style.content_margin_bottom = 13
		theme.set_stylebox(style_name, "Button", style)
	root.theme = theme
	objectives = _label(root, "", 24, MINT)
	objectives.position = Vector2(36, 30)
	telemetry = _label(root, "", 25, PAPER)
	telemetry.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	telemetry.offset_left = -420
	telemetry.offset_right = -36
	telemetry.offset_top = 30
	telemetry.offset_bottom = 110
	telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vitals = _label(root, "", 25, PAPER)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 36
	vitals.offset_top = -105
	vitals.offset_right = 650
	vitals.offset_bottom = -30
	message = _label(root, "", 23, GOLD)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message.offset_left = -600
	message.offset_right = 600
	message.offset_top = 150
	message.offset_bottom = 215
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = _label(root, "", 24, PAPER)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -500
	prompt.offset_right = 500
	prompt.offset_top = -125
	prompt.offset_bottom = -70
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress.offset_left = -190
	progress.offset_right = 190
	progress.offset_top = -62
	progress.offset_bottom = -57
	root.add_child(progress)
	marker = _label(root, "", 21, GOLD)
	game_controls = [objectives, telemetry, vitals, message, prompt, progress, marker]
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.06, 0.085, 0.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	panel_content = VBoxContainer.new()
	panel_content.custom_minimum_size = Vector2(780, 0)
	panel_content.add_theme_constant_override("separation", 15)
	center.add_child(panel_content)

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
	for child: Node in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	map_view = null
	overlay.show()
	for control: Control in game_controls:
		control.hide()

func _button(text: String, action: String, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(func() -> void: action_requested.emit(action))
	panel_content.add_child(button)
	return button

func show_hq(raid: Node) -> void:
	_clear_panel()
	_label(panel_content, "SHINRAI  /  FIELD OPERATIONS", 19, MINT)
	_label(panel_content, "THE QUIET EXIT", 58, PAPER)
	_label(panel_content, "01   SHINRAI PARK", 26, GOLD)
	_label(panel_content, "Recover the park's telemetry. Search for salvage. Get out alive.\nOne relay opens extraction. All three earn the full contract bonus.", 23, PAPER)
	_label(panel_content, "10 MINUTES   /   SOLO PvE   /   CARRY 6–10 ITEMS", 19, MINT)
	var d: Dictionary = raid.profile.data
	var stash_count := 0
	for amount: Variant in d.stash.values():
		stash_count += int(amount)
	_label(panel_content, "CREDITS  %d     STASH  %d     EXTRACTS  %d / %d" % [d.credits, stash_count, d.extracts, d.runs], 23, PAPER)
	_label(panel_content, "LOADOUT  UZI · 30 + 90 rounds · %d medkit(s) · %d cargo slots" % [2 if d.prepared_medkit else 1, 6 + int(d.pack_level) * 2], 21, PAPER)
	if raid.enemy_visual == null:
		_label(panel_content, "RECON BUILD: K17 model pending. Hostile spawning is disabled.", 20, GOLD)
	if raid.profile.recovered_interrupted_run:
		_label(panel_content, "Last run was interrupted. Unbanked cargo was lost; your stash is safe.", 18, GOLD)
	if not raid.profile.last_error.is_empty():
		_label(panel_content, raid.profile.last_error, 19, Color("#ef9b8c"))
	_button("DEPLOY  →  " + ("NIGHT" if raid.night_deployment else "GOLDEN HOUR"), "deploy", not raid.navigation.ready or not raid.profile.last_error.is_empty()).grab_focus()
	var row := HBoxContainer.new()
	panel_content.add_child(row)
	for spec: Array in [["Change time of day", "time"], ["Sell stash", "sell"], ["Extra medkit · 120", "medkit"]]:
		var button := Button.new()
		button.text = spec[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var event: String = spec[1]
		button.pressed.connect(func() -> void: action_requested.emit(event))
		row.add_child(button)
	var level: int = d.pack_level
	_button("Cargo upgrade · %d credits" % (450 * (level + 1)) if level < 2 else "Cargo fully upgraded", "upgrade", level >= 2)
	_label(panel_content, "WASD move · Shift sprint · Space jump/mantle · LMB fire · RMB aim\nR reload · Hold E interact · Hold H heal · Tab map/cargo · Esc pause\nT track relays/extraction · F7 graphics · Starter kit is always free.\nCarried items are lost on death or abandoning a run.", 18, Color("#aabbbd"))

func show_raid() -> void:
	overlay.hide()
	for control: Control in game_controls:
		control.show()

func show_pause(raid: Node, map_open: bool) -> void:
	_clear_panel()
	_label(panel_content, "SHINRAI PARK  /  " + ("FIELD MAP" if map_open else "PAUSED"), 32, PAPER)
	if map_open:
		var chart := FieldMap.new()
		chart.raid = raid
		chart.destination_selected.connect(func(id: String) -> void: action_requested.emit("track:" + id))
		chart.custom_minimum_size = Vector2(780, 470)
		panel_content.add_child(chart)
		map_view = chart
		_label(panel_content, "YOU  △   RELAYS  ●   SEARCH  ·   EXTRACTION  □   Click a site to track", 18, MINT)
		var target: Dictionary = raid.tracked_objective()
		if not target.is_empty():
			_label(panel_content, "%s  ·  ~%dm suggested route" % [target.title, int(raid.guidance_distance)], 18, GOLD)
		var names: Array[String] = []
		for item: Dictionary in raid.bag:
			names.append(item.title)
		var cargo := _label(panel_content, "CARGO %d/%d  ·  %s" % [raid.bag.size(), raid.capacity(), ", ".join(names) if not names.is_empty() else "Empty"], 18, PAPER)
		cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cargo.custom_minimum_size.x = 780
		_button("Drop last cargo item (permanent)", "drop", raid.bag.is_empty())
	_label(panel_content, "The raid clock and patrols are paused. F7: High / Balanced graphics.", 19, GOLD)
	_button("RESUME", "resume").grab_focus()
	_button("Abandon run…", "abandon_confirm")

func show_abandon() -> void:
	_clear_panel()
	_label(panel_content, "ABANDON THIS RUN?", 40, PAPER)
	_label(panel_content, "You will lose everything you are carrying. Your banked stash is safe.", 22, GOLD)
	_button("Keep playing", "resume").grab_focus()
	_button("Abandon and return to operations", "abandon")

func show_result(raid: Node, won: bool, reason: String, bonus: int) -> void:
	_clear_panel()
	_label(panel_content, "EXTRACTION CONFIRMED" if won else "SIGNAL LOST", 47, MINT if won else GOLD)
	_label(panel_content, reason, 24, PAPER)
	_label(panel_content, "%d RELAYS   /   %d HOSTILES   /   %d ITEMS %s" % [raid.relays, raid.player.kills, raid.bag.size(), "BANKED" if won else "LOST"], 23, PAPER)
	_label(panel_content, "CONTRACT BONUS  +%d credits" % bonus if won else "Your banked stash and upgrades are safe.", 23, MINT)
	if not raid.profile.last_error.is_empty():
		_label(panel_content, "SAVE FAILED: " + raid.profile.last_error, 20, GOLD)
	_button("RETURN TO OPERATIONS", "hq").grab_focus()

func update_raid(raid: Node) -> void:
	var seconds := ceili(raid.remaining)
	telemetry.text = "%02d:%02d   /   %s\n%s GRAPHICS" % [seconds / 60, seconds % 60, "LOCKDOWN" if seconds < 90 else "UNTIL LOCKDOWN", "HIGH" if raid.park.high_render_quality else "BALANCED"]
	if OS.is_debug_build():
		telemetry.text += "  ·  %d FPS" % Engine.get_frames_per_second()
	telemetry.modulate = Color("#efa27e") if seconds < 90 else Color.WHITE
	objectives.text = "SHINRAI PARK  /  THE QUIET EXIT\nTELEMETRY  %d / 3    ·    %s" % [raid.relays, "EXTRACTION AVAILABLE" if raid.relays > 0 else "RECOVER A RELAY"]
	vitals.text = "HP  %03d    MED  %d    CARGO  %d/%d\nUZI   %02d / %03d%s" % [ceili(raid.player.health), raid.medkits, raid.bag.size(), raid.capacity(), raid.player.ammo, raid.player.reserve, "   RELOADING" if raid.player.reloading else ""]
	message.text = raid.notice if raid.notice_time > 0.0 else ""
	prompt.text = raid.prompt_text
	progress.value = raid.progress_ratio * 100.0
	progress.visible = raid.progress_ratio > 0.0
	marker.hide()
	var objective: Dictionary = raid.tracked_objective()
	if not objective.is_empty():
		objectives.text += "\n%s · ~%dm via route   [T: change target]" % [objective.title, int(raid.guidance_distance)]
		var world: Vector3 = objective.position + Vector3.UP * 2.5
		var camera: Camera3D = raid.player.camera
		if not camera.is_position_behind(world):
			var pixel := camera.unproject_position(world)
			var view_size := root.get_rect().size
			if pixel.x > 40 and pixel.x < view_size.x - 260 and pixel.y > 140 and pixel.y < view_size.y - 180:
				marker.position = pixel
				marker.text = "%s  ·  %dm" % [objective.title, int(raid.player.global_position.distance_to(objective.position))]
				marker.show()

class FieldMap extends Control:
	signal destination_selected(id: String)
	var raid: Node
	func _gui_input(event: InputEvent) -> void:
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
		return Vector2(28, 20) + (p + Vector2(220, 180)) / Vector2(440, 360) * Vector2(size.x - 56, size.y - 40)
	func _draw() -> void:
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
		var p: Vector3 = raid.player.global_position
		var center := project(Vector2(p.x, p.z))
		var triangle := PackedVector2Array()
		for v: Vector2 in [Vector2(0, -10), Vector2(-6, 6), Vector2(6, 6)]:
			triangle.append(center + v.rotated(-raid.player.rotation.y))
		draw_colored_polygon(triangle, Color.WHITE)
