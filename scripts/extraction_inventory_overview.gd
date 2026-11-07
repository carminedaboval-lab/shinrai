extends PanelContainer
## Default field inventory. Item and medical transactions use the existing inspector.
const Storage = preload("./extraction_storage_layout.gd")
const GearGrid = preload("./extraction_container_grid.gd")
const GearIcon = preload("./extraction_gear_icon.gd")
const BodyDiagram = preload("./extraction_inventory_body.gd")
const Clothes = preload("./extraction_clothing.gd")
const WeaponStudio = preload("./extraction_loadout_preview.gd")
const Catalog = preload("./extraction_weapon_catalog.gd")
const GameInput = preload("./shinrai_input.gd")
const PAPER := Color("e1eae4")
const TEAL := Color("8ae4d1")
const MUTED := Color("a9bcb3")
var panel: Control
var raid: Node
var page := "body"
var data: Dictionary
var selected_index := -1
var inspected_record: Dictionary = {}
var moving_index := -1
var moving_record: Dictionary = {}
var grids: Array[Control] = []
var item_buttons: Dictionary = {}
var pockets: VBoxContainer
var containers: VBoxContainer
var character_box: Control
var hero_input: Control
var weapon_box: VBoxContainer
var weapons: VBoxContainer
var health_box: VBoxContainer
var inspector_box: VBoxContainer
var move_button: Button
var kit_record: VBoxContainer
var pack_slot: Button
var body: Control
var info: Label
var mass: Label
var legacy_character: Control
var legacy_weapon: Control
var legacy_inspector: Control
var old_inspector_min: Vector2
var workbench_button: Button
var chosen_weapon: Label
var stowed_cards: GridContainer
var weapon_card: Control

class CardChrome extends Control:
	var vacant := false
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO,size)
		var top := Color("63808a80") if not vacant else Color("45575e70")
		var foot := Color("1c2e33a9")
		draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]),PackedColorArray([top,top,foot,foot]))
		var end := clampf(size.x*0.66,65.0,maxf(65.0,size.x-6.0))
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(end,0),Vector2(end-15,20),Vector2(0,20)]),Color("8c999f74") if not vacant else Color("85949b4b"))
		draw_rect(rect.grow(-0.5),Color("a3b1b47a"),false,1.0)
		draw_line(Vector2(0,size.y-1),Vector2(24,size.y-1),Color("a4b1acca"),1.5)

class SectionMarker extends Control:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(4,0),Vector2(13,0),Vector2(9,size.y),Vector2(0,size.y)]),Color("90a4a1a8"))


func configure(owner_panel: Control) -> void:
	panel = owner_panel
	raid = panel.raid
	legacy_character = panel.character_preview.get_parent()
	legacy_weapon = panel.equipment_preview.get_parent()
	legacy_inspector = panel.inspector_scroll.get_parent()
	old_inspector_min = panel.inspector_scroll.custom_minimum_size
	custom_minimum_size = Vector2(1504,794)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel",skin(Color("18262b32"),Color.TRANSPARENT,0,0))
	var stage := Control.new()
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	character_box = Control.new()
	character_box.name = "OperatorPreviewFrame"
	character_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(character_box)
	character_box.anchor_left = 0.065
	character_box.anchor_right = 0.542
	character_box.anchor_bottom = 1.28
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.offset_top = 12
	row.offset_bottom = -10
	var gear_side := HBoxContainer.new()
	gear_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_side.size_flags_stretch_ratio = 0.65
	gear_side.add_theme_constant_override("separation",12)
	gear_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gear_side)
	var left := column(gear_side,246,0.29)
	section(left,"GEAR")
	var equipment := GridContainer.new()
	equipment.columns = 2
	equipment.add_theme_constant_override("h_separation",8)
	equipment.add_theme_constant_override("v_separation",8)
	left.add_child(equipment)
	var outfit: Dictionary = raid.inventory_outfit()
	for slot: String in ["top","legs","armour","pouch"]:
		var id := str(outfit[slot])
		var spec := Clothes.spec(id)
		card(equipment,{"top":"UPPER BODY","legs":"LOWER BODY","armour":"ARMOUR","pouch":"RIG"}[slot],id if not id.is_empty() else slot,str(spec.get("title","Empty")),Vector2(116,145),id.is_empty())
	section(left,"POCKETS",18)
	pockets = VBoxContainer.new()
	pockets.add_theme_constant_override("separation",4)
	left.add_child(pockets)
	section(left,"WEAPONS",24)
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_scroll.follow_focus = true
	weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_scroll.custom_minimum_size.y = 175
	left.add_child(weapon_scroll)
	weapons = VBoxContainer.new()
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_scroll.add_child(weapons)
	weapon_card = Control.new()
	weapon_card.custom_minimum_size = Vector2(116,145)
	weapons.add_child(weapon_card)
	chrome(weapon_card,false)
	weapon_box = VBoxContainer.new()
	weapon_card.add_child(weapon_box)
	weapon_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_box.offset_top = 17
	weapon_box.offset_bottom = -19
	header_text(weapon_card,"IN HANDS")
	chosen_weapon = label(weapon_card,"",14,PAPER)
	chosen_weapon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chosen_weapon.offset_left = 5
	chosen_weapon.offset_right = -3
	chosen_weapon.offset_top = -20
	chosen_weapon.clip_text = true
	workbench_button = button(weapons,"Weapons & optics  ›",panel._open_weapon_workbench)
	if not panel.in_hq and is_instance_valid(raid.player) and raid.player.get("physical_magazines") == true and raid.player.get("magazine_inserted") == true:
		button(weapons,"Remove magazine",func() -> void: panel._request_inventory_action("unload_magazine"))
	stowed_cards = GridContainer.new()
	stowed_cards.columns = 2
	weapons.add_child(stowed_cards)
	hero_input = Control.new()
	hero_input.name = "RotateOperator"
	hero_input.custom_minimum_size.x = 110
	hero_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_input.size_flags_stretch_ratio = 0.28
	hero_input.mouse_default_cursor_shape = Control.CURSOR_DRAG
	hero_input.tooltip_text = "Drag to rotate operator · scroll to zoom"
	gear_side.add_child(hero_input)
	hero_input.gui_input.connect(func(event: InputEvent) -> void: panel.character_preview._gui_input(event))
	var storage_column := column(gear_side,321,0.43)
	section(storage_column,"LOADOUT")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	storage_column.add_child(scroll)
	containers = VBoxContainer.new()
	containers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	containers.add_theme_constant_override("separation",23)
	scroll.add_child(containers)
	info = label(storage_column,"",14,MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.hide()
	mass = label(storage_column,"",14,MUTED)
	var divider := VSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.add_theme_stylebox_override("separator",skin(Color("8da0a252"),Color.TRANSPARENT,0))
	row.add_child(divider)
	var right := column(row,389,0.35)
	health_box = VBoxContainer.new()
	health_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(health_box)
	section(health_box,"HEALTH")
	if is_instance_valid(panel.medical_panel) and is_instance_valid(raid.hud) and is_instance_valid(raid.hud.body_status):
		body = BodyDiagram.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		health_box.add_child(body)
		body.part_selected.connect(inspect_part)
		body.configure(raid)
	else:
		label(health_box,"HP   %d" % roundi(float(raid.player.get("health"))) if is_instance_valid(raid.player) else "Body data unavailable",20,PAPER)
	inspector_box = VBoxContainer.new()
	inspector_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(inspector_box)
	button(inspector_box,"‹   Body overview",back_to_body)
	kit_record = VBoxContainer.new()
	inspector_box.add_child(kit_record)
	kit_record.hide()
	move_button = button(inspector_box,"Move item",begin_move)
	rebuild_grids()
	refresh_weapons()
	back_to_body(false)

func chrome(parent: Control,empty: bool) -> void:
	var background := CardChrome.new()
	background.vacant = empty
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func header_text(parent: Control,value: String) -> void:
	var title := label(parent,value,13,Color("eef2f2"))
	title.position = Vector2(6,1)

func card(parent: Control,slot: String,id: String,title: String,minimum: Vector2,empty: bool,action: Callable = Callable()) -> Control:
	var tile: Control
	if action.is_valid():
		var hit := Button.new()
		hit.flat = true
		hit.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		hit.add_theme_stylebox_override("hover",skin(Color("748e902e"),TEAL))
		hit.add_theme_stylebox_override("focus",skin(Color.TRANSPARENT,TEAL,2))
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.pressed.connect(action)
		tile = hit
	else:
		tile = Control.new()
	tile.custom_minimum_size = minimum
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = title
	tile.accessibility_name = slot.capitalize() + ", " + title
	parent.add_child(tile)
	chrome(tile,empty)
	if not id.is_empty():
		var icon := GearIcon.new()
		tile.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5
		icon.offset_right = -5
		icon.offset_top = 18
		icon.offset_bottom = -17
		icon.setup(id,empty)
	header_text(tile,slot)
	var nameplate := label(tile,title,14,PAPER if not empty else MUTED)
	nameplate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nameplate.offset_left = 5
	nameplate.offset_right = -3
	nameplate.offset_top = -20
	nameplate.clip_text = true
	nameplate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return tile

func column(parent: Control, width: int, ratio: float) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.custom_minimum_size.x = width
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_stretch_ratio = ratio
	outer.add_theme_constant_override("separation",8)
	parent.add_child(outer)
	return outer

func skin(fill: Color,border: Color,line_width: int = 1,padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(line_width)
	style.set_content_margin_all(padding)
	return style

func label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func section(parent: Control,value: String,space_above: int = 0) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",8)
	if space_above > 0:
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top",space_above)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(margin)
		margin.add_child(line)
	else: parent.add_child(line)
	var marker := SectionMarker.new()
	marker.custom_minimum_size = Vector2(13,20)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(marker)
	var title := label(line,value,20,PAPER)
	title.add_theme_color_override("font_shadow_color",Color("081114"))
	title.add_theme_constant_override("shadow_outline_size",3)
	var rule := ColorRect.new()
	rule.color = Color("9eafb06a")
	rule.custom_minimum_size.y = 1
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(rule)

func button(parent: Control,value: String,callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.add_theme_font_size_override("font_size",15)
	b.add_theme_color_override("font_color",PAPER)
	b.add_theme_stylebox_override("normal",skin(Color("273a3f7c"),Color("77868994"),1,5))
	b.add_theme_stylebox_override("hover",skin(Color("36524f"),TEAL,1,5))
	b.add_theme_stylebox_override("focus",skin(Color.TRANSPARENT,TEAL,2,6))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func set_overview(active: bool) -> void:
	var character: Control = panel.character_preview
	var weapon: Control = panel.equipment_preview
	var inspector: ScrollContainer = panel.inspector_scroll
	if active:
		if character.get_parent() != character_box:
			character.reparent(character_box,false)
			character.set_backpack(raid.equipped_backpack_id())
			character.custom_minimum_size = Vector2.ZERO
			character.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			character.mouse_filter = Control.MOUSE_FILTER_IGNORE
			character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon.reparent(weapon_box,false)
			weapon.custom_minimum_size = Vector2(80,95)
			weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon.workbench_presentation = true
			weapon.call_deferred("reset_view")
			inspector.reparent(inspector_box,false)
			inspector.custom_minimum_size = Vector2(0,470)
		restore_page(page, str(panel.medical_panel.selected_part) if is_instance_valid(panel.medical_panel) else "")
	else:
		cancel_move()
		if character.get_parent() != legacy_character:
			character.reparent(legacy_character,false)
			character.mouse_filter = Control.MOUSE_FILTER_STOP
			character.custom_minimum_size = Vector2(536,590)
			character.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			character.offset_bottom = 590
			weapon.reparent(legacy_weapon,false)
			legacy_weapon.move_child(weapon,0)
			weapon.custom_minimum_size = Vector2(164,62)
			weapon.workbench_presentation = false
			weapon.reset_view()
			inspector.reparent(legacy_inspector,false)
			inspector.custom_minimum_size = old_inspector_min
			inspector.show()
		if panel.in_hq: character.set_backpack("")
		panel._show_inspector_tab("ITEM")

func refresh_weapons() -> void:
	var state: Dictionary = raid.active_weapon_loadout()
	var equipped := str(state.get("equipped",""))
	if equipped.is_empty() or not state.weapons.has(equipped):
		chosen_weapon.text = "Hands empty"
	else:
		chosen_weapon.text = "%s   ·   %s" % [str(Catalog.WEAPONS[equipped].title),panel.equipment_ammunition.text.strip_edges()]
		chosen_weapon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for previous: Node in stowed_cards.get_children():
		stowed_cards.remove_child(previous)
		previous.queue_free()
	for key: String in state.weapons:
		if key == equipped or not Catalog.WEAPONS.has(key): continue
		var tile := card(stowed_cards,"CARRIED","",str(Catalog.WEAPONS[key].title),Vector2(110,95),false,panel._open_weapon_workbench)
		var thumbnail := WeaponStudio.new()
		thumbnail.workbench_presentation = true
		thumbnail.weapon_id = key
		thumbnail.optic_id = str(state.weapons[key].get("optic",""))
		thumbnail.custom_minimum_size = Vector2(24,24)
		tile.add_child(thumbnail)
		thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thumbnail.offset_top = 18
		thumbnail.offset_bottom = -20
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumbnail.reset_view()
		thumbnail.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		thumbnail.set_process(false)

func rebuild_grids() -> void:
	for stack: VBoxContainer in [pockets,containers]:
		for child: Node in stack.get_children():
			stack.remove_child(child)
			child.queue_free()
	grids.clear()
	item_buttons.clear()
	data = raid.storage_layout()
	mass.text = "%d / %d cells   ·   %.1f / %.1f kg" % [raid.cargo_cells_used(),raid.capacity(),raid.cargo_mass_kg(),raid.cargo_limit_kg()]
	var has_pack := false
	var pouch_row: HBoxContainer
	for spec: Dictionary in data.containers:
		var destination: Control
		if spec.kind == "pockets":
			destination = pockets
			label(pockets,str(spec.title),14,MUTED)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",9)
			containers.add_child(row)
			var is_pack := str(spec.id).begins_with("pack:")
			if spec.id == "pouch": pouch_row = row
			var slot := "BACKPACK" if is_pack else "POUCH" if spec.id == "pouch" else "TROUSERS"
			var side := card(row,slot,str(spec.item_id),str(spec.title),Vector2(164,172),false,_inspect_pack if is_pack else Callable())
			side.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			if is_pack:
				has_pack = true
				configure_pack(side)
			destination = row
		var g := GearGrid.new()
		destination.add_child(g)
		g.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		g.build(self,spec,data)
		grids.append(g)
	if not has_pack:
		var empty_pack := card(containers,"BACKPACK","backpack","Empty",Vector2(164,125),true,_inspect_pack)
		empty_pack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		configure_pack(empty_pack)
	if is_instance_valid(pouch_row):
		section(containers,"TACTICAL GEAR",150)
		containers.move_child(pouch_row,-1)
	if not data.overflow.is_empty():
		section(containers,"UNPLACED CARGO")
		for index: int in data.overflow:
			var row := button(containers,str(raid.inventory_gear()[index].title),func() -> void: inspect_item(index))
			row.clip_text = true
			row.set_drag_forwarding(func(_p: Vector2) -> Variant: return drag_payload(index,Vector2i.ZERO,row),Callable(),Callable())
			item_buttons[index] = row

func configure_pack(tile: Control) -> void:
	pack_slot = tile as Button
	pack_slot.name = "WornBackpack"
	pack_slot.tooltip_text = "Selected backpack for deployment." if panel.in_hq else "Select equipped backpack or drag a carried pack here to equip it."
	pack_slot.set_drag_forwarding(Callable(),_can_equip,_drop_equip)

func _inspect_pack() -> void:
	if int(data.worn_index) >= 0: inspect_item(int(data.worn_index))
	else: feedback("Equip a carried backpack to open its storage grid.")

func inspect_item(index: int,focus: bool = true) -> void:
	var gear: Array = raid.inventory_gear()
	if index < 0 or index >= gear.size() or moving_index >= 0: return
	selected_index = index
	inspected_record = gear[index]
	if panel.in_hq:
		panel.inspector_scroll.hide()
		kit_record.show()
		for child: Node in kit_record.get_children():
			kit_record.remove_child(child)
			child.queue_free()
		var entry: Dictionary = gear[index]
		section(kit_record,"DEPLOYMENT KIT")
		var title := label(kit_record,str(entry.get("title",entry.get("id","Item"))),22,PAPER)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var art := GearIcon.new()
		art.custom_minimum_size.y = 106
		kit_record.add_child(art)
		art.setup(str(entry.id))
		if entry.has("rounds"): label(kit_record,"%d rounds" % int(entry.rounds),18,MUTED)
		var shape: Vector2i = data.sizes[index]
		if index != int(data.worn_index): label(kit_record,"%d × %d cells" % [shape.x,shape.y],16,MUTED)
	else:
		kit_record.hide()
		panel.inspector_scroll.show()
		panel._select(index)
		panel._show_inspector_tab("ITEM")
	page = "item"
	health_box.hide()
	inspector_box.show()
	move_button.visible = index != int(data.worn_index)
	if focus and GameInput.gamepad_active():
		if move_button.visible: move_button.grab_focus()
		else: inspector_box.get_child(0).grab_focus()

func inspect_part(part: String,focus: bool = true) -> void:
	if not is_instance_valid(panel.medical_panel) or moving_index >= 0: return
	page = "health"
	health_box.hide()
	inspector_box.show()
	move_button.hide()
	kit_record.hide()
	panel.inspector_scroll.show()
	panel._show_inspector_tab("HEALTH")
	panel.medical_panel.selected_part = part
	panel.medical_panel._refresh()
	if focus and GameInput.gamepad_active():
		var part_button: Button = panel.medical_panel.part_buttons.get(part)
		if is_instance_valid(part_button): part_button.grab_focus()

func back_to_body(focus: bool = true) -> void:
	cancel_move()
	page = "body"
	inspector_box.hide()
	health_box.show()
	if focus: focus_first()

func restore_page(value: String,part: String) -> void:
	var index: int = selected_index if panel.in_hq else panel.selected
	if value == "item" and index >= 0: inspect_item(index,false)
	elif value == "health" and not part.is_empty(): inspect_part(part,false)
	else: back_to_body(false)

func focus_first() -> void:
	if not is_inside_tree(): return
	if page == "item" and move_button.is_visible_in_tree(): move_button.grab_focus()
	elif page == "health": panel._controller_focus_details()
	elif item_buttons.has(selected_index): item_buttons[selected_index].grab_focus()
	elif not item_buttons.is_empty(): item_buttons.values()[0].grab_focus()
	else: workbench_button.grab_focus()

func feedback(message: String) -> void:
	info.text = message
	info.visible = not message.is_empty()

func drag_payload(index: int,grab: Vector2i,button_node: Button) -> Variant:
	var gear: Array = raid.inventory_gear()
	if index < 0 or index >= gear.size() or moving_index >= 0: return null
	var record: Dictionary = gear[index]
	var ghost := PanelContainer.new()
	ghost.add_theme_stylebox_override("panel",skin(Color("284037ef"),TEAL,1,7))
	label(ghost,str(record.title),15,PAPER)
	button_node.set_drag_preview(ghost)
	for g: Control in grids: g.show_destinations(index)
	return {"owner":get_instance_id(),"index":index,"record":record,"grab":grab}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and moving_index < 0:
		for g: Control in grids:
			if is_instance_valid(g): g.show_destinations(-1)

func valid_payload(payload: Variant) -> bool:
	if not payload is Dictionary or payload.get("owner") != get_instance_id(): return false
	var index := int(payload.get("index",-1))
	var gear: Array = raid.inventory_gear()
	return index >= 0 and index < gear.size() and is_same(payload.get("record"),gear[index])

func selected_record() -> Dictionary:
	return inspected_record

func restore_record(record: Dictionary) -> void:
	selected_index = -1
	inspected_record = {}
	if record.is_empty(): return
	var gear: Array = raid.inventory_gear()
	for index: int in gear.size():
		if is_same(gear[index],record):
			selected_index = index
			inspected_record = gear[index]
			return

func _can_equip(_at: Vector2,payload: Variant) -> bool:
	if panel.in_hq or not valid_payload(payload): return false
	return panel._valid_pack_drop(panel._pack_payload(int(payload.index)))

func _drop_equip(at: Vector2,payload: Variant) -> void:
	if _can_equip(at,payload): panel._drop_pack(at,panel._pack_payload(int(payload.index)))

func can_move(index: int,id: String,position_in_grid: Vector2i) -> bool:
	return Storage.can_move(data,index,id,position_in_grid.x,position_in_grid.y)

func begin_move() -> void:
	var gear: Array = raid.inventory_gear()
	if selected_index < 0 or selected_index >= gear.size(): return
	moving_index = selected_index
	moving_record = gear[selected_index]
	var destination: Button
	for grid: Control in grids:
		grid.set_moving(moving_index)
		for target: Button in grid.targets:
			if not target.disabled and destination == null: destination = target
	if destination == null:
		cancel_move()
		feedback("No compatible free space for this item.")
		return
	health_box.show()
	inspector_box.hide()
	feedback("Choose a highlighted cell for %s." % str(moving_record.title))
	destination.grab_focus()

func place_selected(id: String,cell: Vector2i) -> void:
	if moving_index >= 0: commit_move(moving_index,moving_record,id,cell)

func commit_move(index: int,record: Dictionary,id: String,cell: Vector2i) -> void:
	if not raid.move_storage_item(index,record,id,cell.x,cell.y):
		feedback(str(raid.profile.last_error) if not str(raid.profile.last_error).is_empty() else "That space is unavailable.")
		return
	cancel_move()
	selected_index = index
	inspected_record = raid.inventory_gear()[index]
	rebuild_grids()
	back_to_body()

func cancel_move() -> void:
	if moving_index < 0: return
	moving_index = -1
	moving_record = {}
	for g: Control in grids: g.set_moving(-1)
	feedback("")

func go_back() -> bool:
	if moving_index >= 0:
		cancel_move()
		inspect_item(selected_index)
		return true
	if page == "body": return false
	back_to_body()
	return true

func handle_controller(event: InputEvent) -> bool:
	if moving_index >= 0: return false
	if GameInput.pressed(event,"ui_details"):
		if page == "item" and move_button.visible: begin_move()
		elif page != "body": back_to_body()
		elif selected_index >= 0: inspect_item(selected_index)
		else: panel._set_overview(false)
		return true
	return false
