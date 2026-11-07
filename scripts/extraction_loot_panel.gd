extends PanelContainer
## Small field-only loot surface; the raid and its camera remain active behind it.
signal action_requested(action: String)
const GameInput=preload("./shinrai_input.gd")
var _pad_buttons: Array[Button]=[]
var _pad_records: Array[Dictionary]=[]
const Art = preload("./extraction_item_art.gd")
const Containers = preload("./extraction_loot_containers.gd")
const Food = preload("res://scripts/extraction_food_condition.gd")
const WHITE := Color("e4e5dd")
const MUTED := Color("c1c8c0")
const ACCENT := Color("c7bb8e")
var raid: Node
var site: Dictionary
var _food_rows: Array[Dictionary] = []
var _food_header: Label
var _food_clock := 0.0

func configure(run: Node, source: Dictionary) -> void:
	raid = run
	site = source
	name = "FieldLoot"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -490
	offset_right = -34
	offset_top = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.035, 0.045, 0.038, 0.48)
	surface.border_color = Color(0.68, 0.71, 0.63, 0.24)
	surface.set_border_width_all(1)
	surface.content_margin_left = 14
	surface.content_margin_right = 14
	surface.content_margin_top = 12
	surface.content_margin_bottom = 12
	add_theme_stylebox_override("panel", surface)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := label(header, heading(), 22, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close · Esc / Tab"
	close.custom_minimum_size = Vector2(44, 34)
	close.add_theme_font_size_override("font_size", 22)
	style_button(close, false)
	close.pressed.connect(func() -> void: action_requested.emit("cache_leave"))
	header.add_child(close)
	_food_header = label(body,"",16,MUTED)
	_food_header.name = "SelectedFoodCondition"
	_food_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_food_header.hide()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var contents: Array = site.contents if Containers.is_container(site) else [site.loot]
	for index: int in range(contents.size()):
		var item: Dictionary = contents[index]
		var selected: bool = not Containers.is_container(site) or index == int(site.selected_loot)
		var tile := Button.new()
		tile.name = "LootItem%d" % index
		tile.custom_minimum_size = Vector2(210, 100)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = _food_tooltip(item)
		style_button(tile, selected)
		grid.add_child(tile)
		_pad_buttons.append(tile);_pad_records.append(item)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_left = 8
		stack.offset_right = -8
		stack.offset_top = 6
		stack.offset_bottom = -6
		tile.add_child(stack)
		var art := Art.new()
		art.item_id = str(item.id)
		art.custom_minimum_size = Vector2(0, 42 if Food.is_food(str(item.id)) else 50)
		stack.add_child(art)
		if Food.is_food(str(item.id)):
			Food.ensure(item)
			var badge := label(stack,Food.label(item).to_upper(),13,Food.tint(item))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_food_rows.append({"item":item,"tile":tile,"badge":badge})
		var caption := label(stack, str(item.title), 18, WHITE)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var action := "cache_quick:%d" % index if Containers.is_container(site) else "cache_take"
		tile.pressed.connect(func() -> void: action_requested.emit(action))
	_refresh_food_rows()
	var can_take: bool = raid.can_take_site(site)
	label(body, "STORAGE  %d / %d CELLS    ·    %.1f / %.1f kg" % [raid.cargo_cells_used(), raid.capacity(), raid.cargo_mass_kg(), raid.cargo_limit_kg()], 18, MUTED)
	var weight := ProgressBar.new()
	weight.custom_minimum_size.y = 4
	weight.show_percentage = false
	weight.value = clampf(raid.cargo_mass_kg() / maxf(raid.cargo_limit_kg(), 0.01) * 100.0, 0, 100)
	weight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(weight)
	if not can_take:
		label(body, "No room for %s" % site.loot.title, 18, ACCENT)
		if not raid.bag.is_empty():
			label(body, "Replace an item below · old item is lost", 16, MUTED)
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size.y = 96
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.follow_focus = true
			body.add_child(scroll)
			var cargo := VBoxContainer.new()
			cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(cargo)
			for index: int in range(raid.bag.size()):
				var swap := Button.new()
				swap.text = "Replace %s" % raid.bag[index].title
				swap.add_theme_font_size_override("font_size", 17)
				swap.disabled = not raid.can_take_site(site, index)
				style_button(swap, false)
				var action := "cache_swap:%d" % index
				swap.pressed.connect(func() -> void: action_requested.emit(action))
				cargo.add_child(swap)
				swap.set_meta("pad_loot_key","swap:%d"%index)
	var take := Button.new()
	take.name = "TakeSelected"
	take.text = "["+GameInput.hint("E")+"]  TAKE HIGHLIGHTED"
	take.add_theme_font_size_override("font_size", 18)
	take.disabled = not can_take
	style_button(take, true)
	take.pressed.connect(func() -> void: action_requested.emit("cache_take"))
	if can_take:
		body.add_child(take)
	else:
		take.free()
	label(body, "A take focused / B close" if GameInput.gamepad_active() else "Click to take  ·  E highlighted  ·  Esc close", 16, MUTED)
	# Pointer pickups keep cursor position; pad entry gets an explicit target.
	if GameInput.gamepad_active():call_deferred("restore_controller_focus",{})

func _food_tooltip(item: Dictionary) -> String:
	var text := "%s - Click to take" % item.title
	if Food.is_food(str(item.id)):
		Food.ensure(item)
		text += "\n"+_food_condition_text(item)
	return text

func _food_condition_text(item: Dictionary) -> String:
	var text: String = Food.label(item)
	var warning: String = Food.warning(item)
	if not warning.is_empty(): text += "\n"+warning
	return text

func _refresh_food_rows() -> void:
	for row: Dictionary in _food_rows:
		if not is_instance_valid(row.tile) or not is_instance_valid(row.badge): continue
		var item: Dictionary = row.item
		Food.ensure(item)
		row.badge.text = Food.label(item).to_upper()
		row.badge.add_theme_color_override("font_color",Food.tint(item))
		row.tile.tooltip_text = _food_tooltip(item)
	if not is_instance_valid(_food_header): return
	var selected_item: Dictionary = site.get("loot",{})
	if selected_item.is_empty() or not Food.is_food(str(selected_item.id)):
		_food_header.hide()
		return
	Food.ensure(selected_item)
	_food_header.text = str(selected_item.title)+" - "+_food_condition_text(selected_item)
	_food_header.add_theme_color_override("font_color",Food.tint(selected_item))
	_food_header.show()

func _process(delta: float) -> void:
	_food_clock += delta
	if _food_clock < 1.0: return
	_food_clock = 0.0
	_refresh_food_rows()

func heading() -> String:
	if Containers.is_container(site): return str(site.get("container_title","YELLOW BACKPACK"))
	if site.loot.id in ["backpack_regular", "backpack_mountain"]: return "FOUND BACKPACK"
	if site.loot.id == "park_map": return "PICNIC TABLE"
	if site.loot.id == "coffee_cup": return "PICNIC BENCH"
	return "BENCH COMPARTMENT"

func label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var text_label := Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", color)
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	text_label.add_theme_constant_override("shadow_offset_y", 1)
	text_label.add_theme_constant_override("shadow_outline_size", 2)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(text_label)
	return text_label

func style_button(button: Button, selected: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.08, 0.10, 0.08, 0.58) if state in ["hover", "pressed", "focus"] else Color(0.035, 0.045, 0.038, 0.30 if selected else 0.18)
		box.border_color = ACCENT if selected or state in ["hover", "focus"] else Color(0.65, 0.69, 0.61, 0.27)
		if state == "disabled": box.border_color = Color(0.4, 0.43, 0.38, 0.20)
		box.set_border_width_all(1)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	button.add_theme_constant_override("shadow_offset_y", 1)

func controller_focus_state() -> Dictionary:
	var focused:=get_viewport().gui_get_focus_owner()
	var index: int=_pad_buttons.find(focused)
	if index>=0:return {"record":_pad_records[index],"index":index}
	if is_instance_valid(focused) and is_ancestor_of(focused):return {"key":str(focused.get_meta("pad_loot_key",focused.name))}
	return {}

func restore_controller_focus(state: Dictionary) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not GameInput.gamepad_active():return
	var previous: Dictionary=state.get("record",{})
	for index: int in range(_pad_records.size()):
		if not previous.is_empty() and is_same(_pad_records[index],previous):_pad_buttons[index].grab_focus();return
	if state.has("key"):
		for button: Button in find_children("*","Button",true,false):
			if str(button.get_meta("pad_loot_key",button.name))==str(state.key) and not button.disabled:button.grab_focus();return
	if not _pad_buttons.is_empty():_pad_buttons[clampi(int(state.get("index",0)),0,_pad_buttons.size()-1)].grab_focus();return
	for button: Button in find_children("*","Button",true,false):
		if not button.disabled and button.is_visible_in_tree():button.grab_focus();return
