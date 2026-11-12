extends RefCounted
## Shared building blocks for Shinrai's menus, in the field inventory's visual
## language (extraction_inventory*.gd): dark teal glass, slate cards with a
## slanted tab label, slash-marker section headers with a hairline rule, mint
## and brass accents, a top bar and a bottom key-hint strip. Static helpers
## only; every node is code-built so menus need no scene files.

const UIStyle = preload("res://scripts/hud/shinrai_ui_style.gd")
const PLAZA_ART := "res://assets/shinrai/ui/loading/midori_plaza.jpg"
const LOAD_STATE_PATH := "res://scripts/shinrai_load_state.gd"

# Colours copied from the inventory so menus and inventory read as one system.
const PAPER := Color("#eeeeee")
const PAPER_SOFT := Color("e1eae4")
const MUTED := Color("#c3c3c3")
const DIM := Color("a9bcb3")
const STATUS := Color("a9c2c3")
const MINT := Color("#bfd5c8")
const TEAL := Color("a1ded5")
const AMBER := Color("#c7bb8e")
const DANGER := Color("#f0b6a5")
const TITLE := Color("e5efef")
const TILE_FILL := Color(0.035, 0.045, 0.038, 0.18)
const TILE_BORDER := Color("#b8c3bf36")
const GLASS := Color(0.035, 0.045, 0.038, 0.38)
const GLASS_BORDER := Color("#bec9c426")
const BAR_FILL := Color("101d24ee")
const BAR_BORDER := Color("78979876")
const STRIP_FILL := Color("0a181ff5")
const STRIP_BORDER := Color("738e9082")
const PANEL_FILL := Color("0d1a20f2")

# ---------------------------------------------------------------- primitives

static func style(fill: Color, border: Color, padding: float = 8.0, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(padding)
	return box

static func text(parent: Node, content: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if heading:
		label.add_theme_font_override("font", UIStyle.heading_font())
	# Same readability shadow the inventory uses on light text.
	if color.get_luminance() > 0.25:
		label.add_theme_color_override("font_shadow_color", Color("#050807f2"))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("shadow_outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(label)
	return label

static func wrapped(label: Label, width: float = 0.0) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		label.custom_minimum_size.x = width
	return label

static func spacer(parent: Node, height: float = 0.0, expand: bool = false) -> Control:
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.y = height
	if expand:
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(gap)
	return gap

static func vbox(parent: Node, separation: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

static func hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

static func column(parent: Node, width: float, separation: int = 8) -> VBoxContainer:
	var box := vbox(parent, separation)
	box.custom_minimum_size.x = width
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return box

## Font-and-colour theme for a whole menu: Bahnschrift buttons, inventory text.
static func menu_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_font("font", "Button", UIStyle.heading_font())
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("8f9a97"))
	theme.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0.95))
	theme.set_constant("shadow_offset_y", "Button", 1)
	theme.set_stylebox("normal", "TooltipPanel", style(PANEL_FILL, BAR_BORDER, 8))
	theme.set_stylebox("panel", "TooltipPanel", style(PANEL_FILL, BAR_BORDER, 8))
	theme.set_color("font_color", "TooltipLabel", PAPER)
	return theme

# ------------------------------------------------------------------- buttons

## Inventory secondary button (tile glass, mint hover, brass press, paper focus ring).
static func secondary_button(parent: Node, label_text: String, font_size: int = 17) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", style(Color(0.035, 0.045, 0.038, 0.28), TILE_BORDER, 10))
	button.add_theme_stylebox_override("hover", style(Color(0.12, 0.16, 0.13, 0.55), MINT, 10))
	button.add_theme_stylebox_override("pressed", style(Color(0.15, 0.18, 0.13, 0.65), AMBER, 10))
	button.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), PAPER, 10, 2))
	button.add_theme_stylebox_override("disabled", style(Color(0.035, 0.045, 0.038, 0.16), Color("#b8c3bf20"), 10))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if parent != null:
		parent.add_child(button)
	return button

## Inventory primary action (brass border) — DEPLOY, RESUME, RETURN.
static func primary_button(parent: Node, label_text: String, font_size: int = 22) -> Button:
	var button := secondary_button(parent, label_text, font_size)
	button.add_theme_stylebox_override("normal", style(Color(0.16, 0.18, 0.12, 0.55), AMBER, 14))
	button.add_theme_stylebox_override("hover", style(Color(0.25, 0.28, 0.17, 0.72), AMBER, 14))
	button.add_theme_stylebox_override("pressed", style(Color(0.29, 0.30, 0.19, 0.80), AMBER, 14))
	button.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), PAPER, 14, 2))
	button.add_theme_stylebox_override("disabled", style(Color(0.10, 0.11, 0.09, 0.40), Color("#c7bb8e40"), 14))
	button.add_theme_color_override("font_color", Color("f6f1df"))
	return button

## A destructive confirm (quit, abandon): muted rust border, same shape.
static func danger_button(parent: Node, label_text: String, font_size: int = 18) -> Button:
	var button := secondary_button(parent, label_text, font_size)
	button.add_theme_stylebox_override("normal", style(Color(0.16, 0.07, 0.06, 0.45), Color("d79a8a90"), 10))
	button.add_theme_stylebox_override("hover", style(Color(0.30, 0.12, 0.10, 0.70), DANGER, 10))
	button.add_theme_stylebox_override("pressed", style(Color(0.36, 0.14, 0.11, 0.80), DANGER, 10))
	return button

# ---------------------------------------------------------------- structures

## Slanted marker in front of section titles (the inventory's "/ GEAR").
class SectionMarker extends Control:
	var tint := Color("90a4a1a8")
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(13, 0), Vector2(9, size.y), Vector2(0, size.y)]), tint)

## Section header: slash marker, title, hairline rule to the column edge.
static func section(parent: Node, title: String, space_above: int = 0, extra: String = "") -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if space_above > 0:
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top", space_above)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(margin)
		margin.add_child(line)
	else:
		parent.add_child(line)
	var marker := SectionMarker.new()
	marker.custom_minimum_size = Vector2(13, 20)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(marker)
	var label := text(line, title, 20, PAPER_SOFT)
	label.add_theme_color_override("font_shadow_color", Color("081114"))
	label.add_theme_constant_override("shadow_outline_size", 3)
	var rule := ColorRect.new()
	rule.color = Color("9eafb06a")
	rule.custom_minimum_size.y = 1
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(rule)
	if not extra.is_empty():
		text(line, extra, 14, DIM)
	return line

## Card background exactly like the inventory's gear cards: slate gradient,
## slanted tab label, hairline border and a short accent at the foot.
class CardChrome extends Control:
	var tab_text := ""
	var vacant := false
	var accent := Color("a4b1acca")
	var tab_tint := Color("8c999f74")
	var glass := false
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if glass:
			draw_rect(rect, Color(0.035, 0.045, 0.038, 0.42))
		else:
			var top := Color("63808a80") if not vacant else Color("45575e70")
			var foot := Color("1c2e33a9")
			draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([top, top, foot, foot]))
		if not tab_text.is_empty():
			var font := UIStyle.body_font()
			var width := font.get_string_size(tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var end := minf(size.x - 6.0, maxf(65.0, width + 34.0))
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(end, 0), Vector2(end - 15, 20), Vector2(0, 20)]), tab_tint if not vacant else Color("85949b4b"))
			draw_string(font, Vector2(7, 15), tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eef2f2"))
		draw_rect(rect.grow(-0.5), Color("a3b1b47a") if not glass else GLASS_BORDER, false, 1.0)
		draw_line(Vector2(0, size.y - 1), Vector2(24, size.y - 1), accent, 1.5)

## A card with a slanted tab; returns the content VBox. card.get_meta("chrome")
## gives the chrome for later tab/accent changes.
static func card(parent: Node, tab_text: String, padding: int = 14, separation: int = 8, glass: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var chrome := CardChrome.new()
	chrome.tab_text = tab_text
	chrome.glass = glass
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(chrome)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_top", padding + (18 if not tab_text.is_empty() else 0))
	margin.add_theme_constant_override("margin_bottom", padding)
	panel.add_child(margin)
	var box := vbox(margin, separation)
	box.set_meta("chrome", chrome)
	box.set_meta("panel", panel)
	return box

static func chrome_of(card_box: Control) -> CardChrome:
	return card_box.get_meta("chrome") as CardChrome

## Small bordered chip (top-bar "HQ", contract tags).
static func chip(parent: Node, content: String, font_size: int = 15, color: Color = PAPER, border: Color = TILE_BORDER) -> Label:
	var surface := PanelContainer.new()
	surface.add_theme_stylebox_override("panel", style(Color(0.035, 0.045, 0.038, 0.30), border, 0))
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(surface)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]: margin.add_theme_constant_override(side, 9)
	for side: String in ["margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 4)
	surface.add_child(margin)
	return text(margin, content, font_size, color)

## Stat tile: caption over a large value, in the inventory's tile glass.
class StatTile extends PanelContainer:
	var caption: Label
	var value: Label
	var unit: Label
	func set_value(amount: String, unit_text: String = "", tint: Color = Color("f3f6f3")) -> void:
		value.text = amount
		value.add_theme_color_override("font_color", tint)
		unit.text = unit_text
		unit.visible = not unit_text.is_empty()

static func stat_tile(parent: Node, caption_text: String, amount: String, unit_text: String = "", tint: Color = Color("f3f6f3")) -> StatTile:
	var tile := StatTile.new()
	tile.add_theme_stylebox_override("panel", style(Color(0.035, 0.045, 0.038, 0.34), GLASS_BORDER, 12))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(tile)
	var box := vbox(tile, 2)
	tile.caption = text(box, caption_text, 13, DIM)
	var row := hbox(box, 6)
	tile.value = text(row, amount, 30, tint, true)
	tile.unit = text(row, unit_text, 15, Color("bfd0d1"))
	tile.unit.size_flags_vertical = Control.SIZE_SHRINK_END
	tile.unit.visible = not unit_text.is_empty()
	return tile

## Two-or-more-way choice (GOLDEN HOUR | NIGHT). on_pick receives the index of
## a segment that is not already selected.
class Segmented extends HBoxContainer:
	var buttons: Array[Button] = []
	var selected := 0
	var looks: Dictionary = {}
	func select(index: int) -> void:
		selected = index
		for i: int in range(buttons.size()):
			var on := i == selected
			var button := buttons[i]
			button.add_theme_stylebox_override("normal", looks.on_normal if on else looks.off_normal)
			button.add_theme_stylebox_override("hover", looks.on_hover if on else looks.off_hover)
			button.add_theme_stylebox_override("pressed", looks.on_normal if on else looks.off_hover)
			button.add_theme_color_override("font_color", looks.on_font if on else looks.off_font)
			button.set_pressed_no_signal(on)

static func segmented(parent: Node, options: Array, selected: int, on_pick: Callable, font_size: int = 17) -> Segmented:
	var row := Segmented.new()
	row.add_theme_constant_override("separation", 4)
	row.looks = {
		"on_normal": style(Color(0.18, 0.20, 0.14, 0.58), MINT, 10),
		"off_normal": style(Color(0.035, 0.045, 0.038, 0.26), TILE_BORDER, 10),
		"on_hover": style(Color(0.20, 0.24, 0.17, 0.66), MINT, 10),
		"off_hover": style(Color(0.12, 0.16, 0.13, 0.55), MINT, 10),
		"on_font": PAPER, "off_font": MUTED}
	parent.add_child(row)
	for i: int in range(options.size()):
		var button := secondary_button(row, str(options[i]), font_size)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		button.pressed.connect(func() -> void:
			if index != row.selected:
				on_pick.call(index)
			row.select(row.selected))
		row.buttons.append(button)
	row.select(selected)
	return row

static func progress_bar(parent: Node, height: float = 4.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size.y = height
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", style(Color("#90909030"), Color.TRANSPARENT, 0, 0))
	bar.add_theme_stylebox_override("fill", style(Color(TEAL, 0.92), Color.TRANSPARENT, 0, 0))
	if parent != null:
		parent.add_child(bar)
	return bar

## The inventory's crest glyph (brass arc, jade leaf).
class FieldCrest extends Control:
	func _draw() -> void:
		var brass := Color("c7bb8e")
		var jade := Color("bfd5c8")
		draw_arc(Vector2(17, 17), 14, -PI * .42, PI * .72, 28, Color(brass, 0.7), 1.3, true)
		draw_polyline(PackedVector2Array([Vector2(10, 24), Vector2(12, 13), Vector2(24, 9), Vector2(21, 20), Vector2(10, 24)]), jade, 1.5, true)
		draw_line(Vector2(9, 26), Vector2(23, 11), brass, 1.5, true)
		draw_circle(Vector2(29, 23), 2, brass)

# -------------------------------------------------------------------- screens

## One full menu screen: top bar, body, bottom hint strip, optional side panel.
class MenuScreen extends Control:
	var top_bar: PanelContainer
	var title_label: Label
	var chip_label: Label
	var status_box: HBoxContainer
	var body: HBoxContainer
	var bottom_left: VBoxContainer
	var hints: HBoxContainer
	var side_panel: PanelContainer
	var side_box: VBoxContainer
	var side_return: Control

	var side_hint: Control

	func open_side(focus_first: bool = true) -> void:
		if side_panel == null: return
		side_return = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		side_panel.show()
		# Modal for keyboard / pad focus: nothing under the drawer (market tiles,
		# the field map, top-bar buttons) can take focus while it is open.
		for area: Control in [body, status_box]:
			if area != null: area.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		_show_side_hint(true)
		if focus_first:
			for node: Node in side_box.find_children("*", "Button", true, false):
				var button := node as Button
				if button.is_visible_in_tree() and not button.disabled:
					button.grab_focus()
					break

	func close_side() -> void:
		if side_panel == null or not side_panel.visible: return
		side_panel.hide()
		for area: Control in [body, status_box]:
			if area != null: area.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		_show_side_hint(false)
		if is_instance_valid(side_return) and side_return.is_visible_in_tree():
			side_return.grab_focus()

	## "Esc / B  Close" in the bottom bar only while the drawer is open.
	func _show_side_hint(on: bool) -> void:
		if is_instance_valid(side_hint):
			side_hint.queue_free()
			side_hint = null
		if not on or hints == null or not side_hint_factory.is_valid(): return
		side_hint = side_hint_factory.call(hints)

	## Set by screen(): builds one key-hint group (the kit's statics are not
	## reachable from this inner class).
	var side_hint_factory: Callable

	func side_open() -> bool:
		return side_panel != null and side_panel.visible

	## Called by ShinraiControllerUi.cancel_topmost (pad B) where wired.
	func controller_cancel() -> bool:
		if side_open():
			close_side()
			return true
		return false

	func _input(event: InputEvent) -> void:
		if not side_open() or not is_visible_in_tree(): return
		var back := false
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE: back = true
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B: back = true
		if back:
			close_side()
			get_viewport().set_input_as_handled()

static func screen(parent: Node, title: String, chip_text: String) -> MenuScreen:
	var root := MenuScreen.new()
	root.name = "MenuScreen"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = menu_theme()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(root)
	if not parent is Container:
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stack)
	# Top bar, as the inventory's head surface.
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", style(BAR_FILL, BAR_BORDER, 10))
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(bar)
	root.top_bar = bar
	var head := hbox(bar, 12)
	var crest := FieldCrest.new()
	crest.custom_minimum_size = Vector2(34, 34)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(crest)
	root.title_label = text(head, "SHINRAI   /   " + title, 22, TITLE, true)
	root.title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.chip_label = chip(head, chip_text, 16)
	if chip_text.is_empty():
		root.chip_label.get_parent().get_parent().hide()
	spacer(head, 0, true).custom_minimum_size.y = 1
	root.status_box = hbox(head, 14)
	root.status_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Body.
	root.body = HBoxContainer.new()
	root.body.add_theme_constant_override("separation", 32)
	root.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(root.body)
	# Bottom strip, as the inventory's survival strip.
	var strip := PanelContainer.new()
	strip.custom_minimum_size.y = 57
	strip.add_theme_stylebox_override("panel", style(STRIP_FILL, STRIP_BORDER, 10))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(strip)
	var strip_row := hbox(strip, 16)
	root.bottom_left = vbox(strip_row, 0)
	root.bottom_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.bottom_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.hints = hbox(strip_row, 22)
	root.hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.side_hint_factory = func(parent: Node) -> Control:
		var group := hbox(parent, 7)
		chip(group, "Esc / B", 14, PAPER, Color("a3b1b45a"))
		var what := text(group, "Close settings", 14, MUTED)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return group
	return root

static func status_text(screen_root: MenuScreen, content: String, color: Color = STATUS, font_size: int = 16) -> Label:
	var label := text(screen_root.status_box, content, font_size, color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

static func bar_button(screen_root: MenuScreen, label_text: String) -> Button:
	var button := secondary_button(screen_root.status_box, label_text, 16)
	button.add_theme_constant_override("h_separation", 0)
	return button

static func caption(screen_root: MenuScreen, primary: String, secondary: String = "") -> void:
	for child: Node in screen_root.bottom_left.get_children():
		child.queue_free()
	var top := text(screen_root.bottom_left, primary, 14, MUTED)
	top.clip_text = true
	if not secondary.is_empty():
		var bottom := text(screen_root.bottom_left, secondary, 14, PAPER)
		bottom.clip_text = true

## Bottom-bar key hints: [["Enter / A", "Select"], ["Esc / B", "Back"]].
static func key_hints(screen_root: MenuScreen, pairs: Array) -> void:
	for child: Node in screen_root.hints.get_children():
		child.queue_free()
	for pair: Array in pairs:
		var group := hbox(screen_root.hints, 7)
		chip(group, str(pair[0]), 14, PAPER, Color("a3b1b45a"))
		var what := text(group, str(pair[1]), 14, MUTED)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## Right-hand drawer over the body (settings: graphics + controls help).
static func side_panel(screen_root: MenuScreen, title: String, width: float = 560.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "SidePanel"
	panel.add_theme_stylebox_override("panel", style(PANEL_FILL, BAR_BORDER, 18))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -width
	panel.offset_right = 0
	panel.offset_top = 70
	panel.offset_bottom = -71
	screen_root.add_child(panel)
	var box := vbox(panel, 10)
	var head := hbox(box, 8)
	var marker := SectionMarker.new()
	marker.custom_minimum_size = Vector2(13, 22)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.tint = Color(AMBER, 0.85)
	head.add_child(marker)
	var heading := text(head, title, 24, PAPER, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := secondary_button(head, "CLOSE", 15)
	close.pressed.connect(screen_root.close_side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var content := vbox(scroll, 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_root.side_panel = panel
	screen_root.side_box = box
	panel.hide()
	return content

## Settings drawer contents shared by Operations and Pause.
## Returns the graphics Segmented so callers can refresh it.
static func settings_contents(content: VBoxContainer, high_quality: bool, on_graphics: Callable) -> Segmented:
	section(content, "GRAPHICS")
	var quality := card(content, "RENDER QUALITY", 12, 8)
	var choice := segmented(quality, ["BALANCED", "HIGH"], 1 if high_quality else 0, func(_index: int) -> void: on_graphics.call(), 16)
	wrapped(text(quality, "High adds screen-space reflections and indirect light. F7 switches it at any time.", 14, MUTED))
	var settings: GDScript = load("res://scripts/shinrai_settings.gd")
	var smoothing := card(content, "ANTI-ALIASING", 12, 8)
	segmented(smoothing, settings.AA_LABELS, settings.aa_index(), func(index: int) -> void: settings.set_aa(index), 16)
	wrapped(text(smoothing, "Higher numbers give smoother edges; 9X and 12X want a strong graphics card. TAA is softest and needs about 5 GB more memory. Takes effect the next time you start the game.", 14, MUTED))
	var edge := card(content, "EDGE FILTER", 12, 8)
	segmented(edge, settings.FILTER_LABELS, settings.filter_index(), func(index: int) -> void: settings.set_filter(index), 16)
	wrapped(text(edge, "A light extra pass over remaining jagged edges. Applies at once.", 14, MUTED))
	section(content, "CONTROLS", 12)
	var pad := card(content, "CONTROLLER", 12, 3)
	for row: Array in [["LS / RS", "Move / look"], ["L3", "Sprint"], ["A / B", "Jump / crouch"], ["X", "Reload"], ["Y", "Weapons"], ["RT / LT", "Fire / aim"], ["RB", "Interact"], ["LB", "Heal"], ["Dpad Up / Down", "Eat / lower weapon"], ["View / Menu", "Inventory / pause"], ["Hold R3", "Vitals  ·  R3 + X check magazine"], ["Menus", "Dpad or LS navigate · A select · B back"], ["Inventory", "LB-RB categories · Y cargo actions"]]:
		_control_row(pad, str(row[0]), str(row[1]))
	var keys := card(content, "KEYBOARD AND MOUSE", 12, 3)
	for row: Array in [["W A S D", "Move"], ["Shift", "Sprint"], ["Ctrl", "Crouch"], ["Space", "Jump"], ["LMB / RMB", "Fire / aim"], ["R", "Reload"], ["J", "Check magazine"], ["B", "Lower weapon"], ["Hold E", "Interact"], ["Hold H", "Heal"], ["Hold V", "Vitals"], ["I / Tab", "Inventory / map"], ["Esc", "Pause"], ["T", "Target"], ["F7", "Graphics"]]:
		_control_row(keys, str(row[0]), str(row[1]))
	return choice

static func _control_row(parent: Node, key: String, what: String) -> void:
	var row := hbox(parent, 12)
	var cap := text(row, key, 15, PAPER, true)
	cap.custom_minimum_size.x = 150
	var label := text(row, what, 15, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## Centred dialog card in the body (quit, abandon, pending save).
static func dialog(screen_root: MenuScreen, tab_text: String, title: String, title_color: Color = PAPER, width: float = 760.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.body.add_child(center)
	var holder := vbox(center, 0)
	holder.custom_minimum_size.x = width
	var box := card(holder, tab_text, 26, 14)
	text(box, title, 40, title_color, true)
	return box

static func button_row(parent: Node, separation: int = 10) -> HBoxContainer:
	var row := hbox(parent, separation)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	return row

# ------------------------------------------------------------------- backdrop

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 3.0;
uniform float center_clear = 0.45;
uniform float shade = 0.52;
uniform vec4 tint : source_color = vec4(0.020, 0.043, 0.050, 1.0);
vec3 tap(vec2 uv, float lod) { return textureLod(screen_tex, uv, lod).rgb; }
void fragment() {
	float side = smoothstep(0.16, 0.40, abs(UV.x - 0.5));
	float lod = blur * mix(1.0 - center_clear, 1.0, side);
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod) * 0.9;
	vec3 c = tap(SCREEN_UV, lod) * 0.25;
	c += (tap(SCREEN_UV + vec2(px.x, 0.0), lod) + tap(SCREEN_UV - vec2(px.x, 0.0), lod) + tap(SCREEN_UV + vec2(0.0, px.y), lod) + tap(SCREEN_UV - vec2(0.0, px.y), lod)) * 0.125;
	c += (tap(SCREEN_UV + px, lod) + tap(SCREEN_UV - px, lod) + tap(SCREEN_UV + vec2(px.x, -px.y), lod) + tap(SCREEN_UV + vec2(-px.x, px.y), lod)) * 0.0625;
	// Grade toward the inventory's cool teal, then darken the edges.
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(0.80, 0.94, 0.97), 0.38);
	vec2 q = (UV - 0.5) * vec2(1.55, 1.25);
	float vig = smoothstep(0.30, 1.05, length(q));
	float dark = clamp(shade * mix(0.82, 1.0, side) + vig * 0.30, 0.0, 0.94);
	c = mix(c, tint.rgb, dark);
	COLOR = vec4(c, 1.0);
}
"""

## Full-rect backdrop: the live scene (or the plaza art when 3D is off),
## blurred and graded toward the inventory's dark teal.
class Backdrop extends Control:
	var art: TextureRect
	var veil: ColorRect
	var material_ref: ShaderMaterial
	var force_art := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
		_sync()
	func _process(_delta: float) -> void:
		if is_visible_in_tree(): _sync()
	func _sync() -> void:
		var want := force_art or (is_inside_tree() and get_viewport().disable_3d)
		if art.visible != want: art.visible = want
	func configure(blur: float, center_clear: float, shade: float) -> void:
		material_ref.set_shader_parameter("blur", blur)
		material_ref.set_shader_parameter("center_clear", center_clear)
		material_ref.set_shader_parameter("shade", shade)

static var _blur_shader: Shader
static var _plaza: Texture2D

static func plaza_texture() -> Texture2D:
	if _plaza == null and ResourceLoader.exists(PLAZA_ART):
		_plaza = load(PLAZA_ART) as Texture2D
	return _plaza

static func backdrop(parent: Node, blur: float = 3.0, center_clear: float = 0.45, shade: float = 0.52) -> Backdrop:
	var root := Backdrop.new()
	root.name = "MenuBackdrop"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.art = TextureRect.new()
	root.art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.art.texture = plaza_texture()
	root.art.hide()
	root.add_child(root.art)
	root.veil = ColorRect.new()
	root.veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _blur_shader == null:
		_blur_shader = Shader.new()
		_blur_shader.code = BLUR_SHADER
	root.material_ref = ShaderMaterial.new()
	root.material_ref.shader = _blur_shader
	root.veil.material = root.material_ref
	root.add_child(root.veil)
	root.configure(blur, center_clear, shade)
	parent.add_child(root)
	return root

# ------------------------------------------------------------ load progress

static var _load_state_script: Script
static var _load_state_checked := false

## ShinraiLoadState (FLOW) read by path so menus parse even before it exists
## and without relying on the global class cache.
static func load_state() -> Script:
	if not _load_state_checked:
		_load_state_checked = true
		if ResourceLoader.exists(LOAD_STATE_PATH):
			_load_state_script = load(LOAD_STATE_PATH) as Script
	return _load_state_script

static func load_value(field: String, fallback: Variant) -> Variant:
	var script := load_state()
	if script == null: return fallback
	var value: Variant = script.get(field)
	return fallback if value == null else value

static func number(amount: int) -> String:
	var result := str(absi(amount))
	var index := result.length() - 3
	while index > 0:
		result = result.insert(index, ",")
		index -= 3
	return ("-" if amount < 0 else "") + result
