extends CanvasLayer
## Boot / deploy loading screen in the field inventory's visual language.
## API (fixed, FLOW calls it): begin(text, owner), finish(owner), set_stage,
## fail, show_cancel, var active, signals retry_requested / cancel_requested.
## Several owners (&"boot", &"deploy", ...) may hold the screen; it hides only
## when the last owner finishes.
signal retry_requested
signal cancel_requested

const Kit = preload("res://scripts/ui/shinrai_menu_kit.gd")
const ART := "res://assets/shinrai/ui/loading/midori_plaza.jpg"
## World-build milestones (ShinraiLoadState contract) shown as a stage list.
const STEPS := [
	[0.00, 0.20, "Park resources"],
	[0.20, 0.45, "Park structure"],
	[0.45, 0.65, "Ground, foliage and detail"],
	[0.65, 0.75, "Navigation"],
	[0.75, 0.95, "Biomes, paths and roads"],
	[0.95, 1.00, "Warming up the view"],
]

var shield: Control
var content: Control
var stage_label: Label
var detail_label: Label
var percent_label: Label
var retry_button: Button
var cancel_button: Button
var resource_progress := -1.0
var elapsed := 0.0
var active := false
var rendered_frames := 0
var stage_events: Array[Dictionary] = []
var owners: Array[StringName] = []
var failed := false
var cancel_enabled := false
var screen: Kit.MenuScreen
var bar: ProgressBar
var step_rows: Array[Dictionary] = []
var hint_cancel: Control

class StepMarker extends Control:
	var state := 0 # 0 pending, 1 active, 2 done
	var pulse := 0.0
	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		if state == 2:
			draw_rect(r, Color("a1ded5"))
		elif state == 1:
			draw_rect(r, Color(0.78, 0.73, 0.56, 0.20 + 0.25 * pulse))
			draw_rect(r, Color("c7bb8e"), false, 1.5)
		else:
			draw_rect(r, Color("90a4a160"), false, 1.0)

func _ready() -> void:
	name = "ShinraiLoadingScreen"
	layer = 1000
	add_to_group("shinrai_loading_ui")
	shield = Control.new()
	shield.name = "InputShield"
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shield)
	# Opaque plaza art under the same blur/grade as the menus.
	var floor_fill := ColorRect.new()
	floor_fill.color = Color("0b171c")
	floor_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.add_child(floor_fill)
	var backdrop := Kit.backdrop(shield, 2.2, 0.75, 0.42)
	backdrop.force_art = true
	if ResourceLoader.exists(ART): backdrop.art.texture = load(ART)
	content = MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]: content.add_theme_constant_override(side, 12)
	for side: String in ["margin_top", "margin_bottom"]: content.add_theme_constant_override(side, 14)
	shield.add_child(content)
	screen = Kit.screen(content, "FIELD OPERATIONS", "01")
	Kit.status_text(screen, "MIDORI PARK")
	percent_label = Kit.status_text(screen, "", Kit.AMBER, 17)
	Kit.caption(screen, "SHINRAI  /  EXTRACTION", "The park is built once per launch. Later deployments are quick.")
	_set_hints()
	var left := Kit.column(screen.body, 660, 8)
	Kit.section(left, "OPERATION")
	var title_card := Kit.card(left, "OPERATION 01   ·   MIDORI PARK", 20, 6)
	Kit.text(title_card, "SHINRAI", 84, Color("f3eee2"), true)
	Kit.text(title_card, "THE QUIET EXIT", 26, Color("e9dfbc"), true)
	Kit.spacer(left, 16, true)
	Kit.section(left, "PREPARING THE PARK")
	var progress_card := Kit.card(left, "LOADING", 20, 8)
	stage_label = Kit.text(progress_card, "Preparing the park", 24, Color("f3eee2"), true)
	stage_label.clip_text = true
	bar = Kit.progress_bar(progress_card, 6)
	detail_label = Kit.wrapped(Kit.text(progress_card, "", 15, Color("b5c6c4")), 600)
	Kit.spacer(progress_card, 6)
	for step: Array in STEPS:
		var row := Kit.hbox(progress_card, 12)
		var marker := StepMarker.new()
		marker.custom_minimum_size = Vector2(16, 16)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)
		var label := Kit.text(row, str(step[2]), 16, Kit.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var state := Kit.text(row, "", 14, Kit.DIM)
		step_rows.append({"marker": marker, "label": label, "state": state})
	var actions := Kit.button_row(progress_card)
	retry_button = Kit.primary_button(actions, "RETRY", 18)
	retry_button.custom_minimum_size.x = 180
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	retry_button.hide()
	cancel_button = Kit.secondary_button(actions, "CANCEL DEPLOY", 17)
	cancel_button.custom_minimum_size.x = 220
	cancel_button.pressed.connect(func() -> void: if cancel_enabled: cancel_requested.emit())
	cancel_button.hide()
	Kit.spacer(screen.body, 0, true)
	hide()
	set_process(false)

func _set_hints() -> void:
	var pairs: Array = []
	if retry_button != null and retry_button.visible: pairs.append(["Enter / A", "Retry"])
	if cancel_enabled: pairs.append(["Esc / B", "Cancel deploy"])
	Kit.key_hints(screen, pairs)

func begin(text: String, owner: StringName = &"boot") -> void:
	var first := owners.is_empty()
	if not owners.has(owner): owners.append(owner)
	active = true
	failed = false
	if first:
		elapsed = 0.0
	resource_progress = -1.0
	retry_button.hide()
	detail_label.text = ""
	detail_label.add_theme_color_override("font_color", Color("b5c6c4"))
	cancel_enabled = false
	cancel_button.hide()
	_set_hints()
	set_stage(text)
	show()
	set_process(true)

func finish(owner: StringName = &"boot") -> void:
	owners.erase(owner)
	if not owners.is_empty(): return
	active = false
	failed = false
	cancel_enabled = false
	cancel_button.hide()
	hide()
	set_process(false)
	if shield.get_viewport() != null:
		var focused := shield.get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and shield.is_ancestor_of(focused): focused.release_focus()

## `progress` is the OVERALL build fraction (0..1, as ShinraiLoadState.fraction),
## or -1 to follow ShinraiLoadState alone. While failed, the headline and the
## error stay: a build still running behind the failure cannot overwrite them.
func set_stage(text: String, progress: float = -1.0) -> void:
	if stage_label == null: return
	if failed: return
	if stage_label.text != text: stage_events.append({"stage": text, "engine_ms": Time.get_ticks_msec()})
	stage_label.text = text
	resource_progress = progress
	var overall := clampf(_overall(), 0.0, 1.0)
	var resources_end: float = STEPS[0][1]
	if text.to_lower().contains("resource") and overall < resources_end:
		detail_label.text = "Resources  /  %d%%" % roundi(overall / resources_end * 100.0)
	else:
		detail_label.text = ""
	detail_label.visible = not detail_label.text.is_empty()
	_refresh_progress()

func fail(message: String) -> void:
	failed = false
	set_stage("Unable to load the park")
	failed = true
	detail_label.text = message
	detail_label.add_theme_color_override("font_color", Kit.DANGER)
	detail_label.visible = true
	retry_button.show()
	_set_hints()
	if not visible: show()
	retry_button.grab_focus()

func show_cancel(enabled: bool) -> void:
	cancel_enabled = enabled
	cancel_button.visible = enabled
	_set_hints()
	if enabled and visible: cancel_button.grab_focus()

## One value drives the bar, the header percentage and the step rows.
func _overall() -> float:
	var state_fraction := float(Kit.load_value("fraction", 0.0))
	if resource_progress >= 0.0: return maxf(state_fraction, resource_progress)
	return state_fraction

func _refresh_progress() -> void:
	var overall := clampf(_overall(), 0.0, 1.0)
	if resource_progress >= 0.0 or overall > 0.0 or failed:
		bar.value = overall
	percent_label.text = "%d%%" % roundi(overall * 100.0) if overall > 0.0 or resource_progress >= 0.0 else ""
	var first_launch := bool(Kit.load_value("first_launch_shaders", false))
	for i: int in range(step_rows.size()):
		var row: Dictionary = step_rows[i]
		var start: float = STEPS[i][0]
		var end: float = STEPS[i][1]
		var marker: StepMarker = row.marker
		var state := 2 if overall >= end - 0.0001 else (1 if overall >= start else 0)
		if failed and state == 1: state = 0
		marker.state = state
		marker.queue_redraw()
		var label: Label = row.label
		label.text = "Preparing shaders (first launch)" if i == STEPS.size() - 1 and first_launch else str(STEPS[i][2])
		label.add_theme_color_override("font_color", Kit.PAPER if state == 1 else (Kit.MINT if state == 2 else Color("8f9a97")))
		var note: Label = row.state
		note.text = "DONE" if state == 2 else ("%d%%" % roundi(clampf((overall - start) / maxf(0.001, end - start), 0.0, 1.0) * 100.0) if state == 1 else "")

func _input(event: InputEvent) -> void:
	if not visible or not cancel_enabled or failed: return
	var back := false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE: back = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B: back = true
	if back:
		get_viewport().set_input_as_handled()
		cancel_requested.emit()

func _process(delta: float) -> void:
	elapsed += delta
	rendered_frames += 1
	if bar == null: return
	if resource_progress < 0.0 and float(Kit.load_value("fraction", 0.0)) <= 0.0 and not failed:
		# Indeterminate: a slow mint sweep instead of a stuck bar.
		bar.value = fposmod(elapsed * 0.22, 1.0)
	for row: Dictionary in step_rows:
		var marker: StepMarker = row.marker
		if marker.state == 1:
			marker.pulse = 0.5 + 0.5 * sin(elapsed * 4.0)
			marker.queue_redraw()
	if Engine.get_process_frames() % 6 == 0: _refresh_progress()
