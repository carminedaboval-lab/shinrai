extends Control
## One mounted pocket, channel panel or backpack. The backend owns every cell.
const GearIcon = preload("./extraction_gear_icon.gd")
const CELL := 59
const CHANNEL_GUTTER := 5
const EMPTY_FILL := Color("20333885")
const EMPTY_EDGE := Color("8297988f")
const CARGO_FILL := Color("415554cc")
const CARGO_EDGE := Color("95a7a49c")
var overview: Control
var container: Dictionary
var layout: Dictionary
var targets: Array[Button] = []
var items: Array[Button] = []
var active_index := -1
var marker: ReferenceRect

func build(view: Control, specification: Dictionary, current_layout: Dictionary) -> void:
	overview = view
	container = specification
	layout = current_layout
	name = "Grid_" + str(container.id)
	custom_minimum_size = _origin(Vector2i(container.cols - 1, container.rows - 1)) + Vector2(CELL,CELL)
	for offset: int in range(int(container.cells)):
		var cell := Vector2i(offset % int(container.cols), floori(float(offset) / int(container.cols)))
		var target := Button.new()
		target.name = "Cell_%d_%d" % [cell.x,cell.y]
		target.set_meta("cell",cell)
		target.set_meta("grid_item",-1)
		target.position = _origin(cell)
		target.size = Vector2(CELL-2,CELL-2)
		target.focus_mode = Control.FOCUS_NONE
		target.add_theme_stylebox_override("normal",overview.skin(EMPTY_FILL,EMPTY_EDGE))
		target.add_theme_stylebox_override("hover",overview.skin(Color("2d454a"),Color("91beb7")))
		target.add_theme_stylebox_override("focus",overview.skin(Color("2a5c4e"),Color("a0f4de")))
		target.tooltip_text = "%s · %d, %d" % [str(container.title),cell.x+1,cell.y+1]
		target.set_drag_forwarding(Callable(), _can_drop.bind(cell), _drop.bind(cell))
		target.pressed.connect(func() -> void: overview.place_selected(str(container.id),cell))
		target.focus_entered.connect(func() -> void: _highlight(cell))
		target.mouse_entered.connect(func() -> void:
			if overview.moving_index >= 0: _highlight(cell))
		target.mouse_exited.connect(_clear_highlight)
		target.focus_exited.connect(_clear_highlight)
		add_child(target)
		targets.append(target)
	for index: int in range(layout.placements.size()):
		var place: Dictionary = layout.placements[index]
		if str(place.get("container","")) == str(container.id):
			_add_item(index,place)
	marker = ReferenceRect.new()
	marker.editor_only = false
	marker.border_color = Color("94ffe0")
	marker.border_width = 3.0
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marker)
	marker.hide()

func _origin(cell: Vector2i) -> Vector2:
	var gap := CHANNEL_GUTTER if str(container.kind) in ["pockets","channels"] else 0
	return Vector2(cell.x * (CELL + gap), cell.y * (CELL + (gap if str(container.kind) == "pockets" else 0)))

func _add_item(index: int, place: Dictionary) -> void:
	var at := Vector2i(place.x,place.y)
	var item: Dictionary = overview.raid.inventory_gear()[index]
	var tile := Button.new()
	tile.name = "Stored_%d" % index
	tile.set_meta("grid_item",index)
	tile.clip_contents = true
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.position = _origin(at)
	tile.size = _origin(at + Vector2i(place.w-1,place.h-1)) - tile.position + Vector2(CELL-2,CELL-2)
	tile.tooltip_text = "%s · %d × %d" % [item.title,place.w,place.h]
	tile.accessibility_name = tile.tooltip_text
	tile.add_theme_stylebox_override("normal",overview.skin(CARGO_FILL,CARGO_EDGE))
	tile.add_theme_stylebox_override("hover",overview.skin(Color("4c6665"),Color("9aeed4")))
	tile.add_theme_stylebox_override("focus",overview.skin(Color.TRANSPARENT,Color("a0f4de"),2))
	tile.pressed.connect(func() -> void: overview.inspect_item(index))
	var footprint := Vector2i(place.w,place.h)
	tile.set_drag_forwarding(_drag.bind(index,tile,footprint),_can_drop.bind(at,footprint),_drop.bind(at,footprint))
	tile.mouse_exited.connect(_clear_highlight)
	var icon := GearIcon.new()
	tile.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2
	icon.offset_right = -2
	icon.offset_bottom = -18
	icon.setup(str(item.id))
	var caption: Label = overview.label(tile,_short_name(item),13,Color("e9eee7"))
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 3
	caption.offset_right = -3
	caption.offset_top = -19
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tile)
	items.append(tile)
	overview.item_buttons[index] = tile

func _short_name(item: Dictionary) -> String:
	var id := str(item.id)
	if id.ends_with("_magazine"):
		var weapon := id.trim_suffix("_magazine")
		var names := {"akane":"A-9","raiden_r56":"R-56","tobikage":"T-65","hayate":"H-7","yuzuru":"YZ-10","uzi":"UZI","shigure":"S-9","kite":"K-12"}
		return str(names.get(weapon,"Mag"))
	if id.begins_with("ammo_"): return id.trim_prefix("ammo_").replace("x","×")
	if id.begins_with("sports_bottle"): return "Drink"
	if id == "wrench": return "Wrench"
	var names := {"canned_mackerel":"Fish tin","canned_mackerel_open":"Fish tin","canned_peaches":"Peaches","canned_peaches_open":"Peaches","bolt_cutters":"Cutters","bottled_water_closed":"Water","bottled_water_open":"Water","sports_bottle_closed":"Sports drink","sports_bottle_open":"Sports drink","can_opener":"Opener","utility_knife":"Knife","garden_mikan":"Mikan","garden_persimmon":"Kaki","coffee_cup":"Coffee","park_map":"Map","ration_bar":"Ration","basic_shirt":"Shirt","basic_trousers":"Trousers","work_jacket":"Jacket","cargo_trousers":"Trousers","utility_pouch":"Pouch","security_armour_t2":"T2 vest","patrol_armour_t3":"T3 vest","backpack_regular":"Pack","backpack_mountain":"Mt. pack","archive":"Archive","cell":"Cell","circuit":"Circuit","optics":"Optics","tourniquet":"TQ","screwdriver":"Driver","optic_scope_01":"Scope"}
	return str(names.get(id,str(item.title).get_slice(" · ",0)))

func _drag(at: Vector2, index: int, tile: Button, footprint: Vector2i) -> Variant:
	var grab := Vector2i(floori(at.x / CELL),floori(at.y / CELL)).clamp(Vector2i.ZERO,footprint-Vector2i.ONE)
	return overview.drag_payload(index,grab,tile)

func _destination(local: Vector2, payload: Dictionary, origin: Vector2i, footprint: Vector2i) -> Vector2i:
	var subcell := Vector2i(floori(local.x / CELL),floori(local.y / CELL)).clamp(Vector2i.ZERO,footprint-Vector2i.ONE)
	return origin + subcell - Vector2i(payload.get("grab",Vector2i.ZERO))

func _can_drop(local: Vector2, payload: Variant, origin: Vector2i, footprint := Vector2i.ONE) -> bool:
	if not overview.valid_payload(payload): return false
	var destination := _destination(local,payload,origin,footprint)
	_highlight(destination)
	return overview.can_move(int(payload.index),str(container.id),destination)

func _highlight(cell: Vector2i) -> void:
	if active_index < 0 or not is_instance_valid(marker): return
	var shape := Vector2i(overview.Storage.shape_at(layout,active_index,str(container.id),cell.x,cell.y))
	if shape == Vector2i.ZERO:
		_clear_highlight()
		return
	marker.position = _origin(cell)
	marker.size = _origin(cell + shape - Vector2i.ONE) - marker.position + Vector2(CELL-2,CELL-2)
	marker.show()

func _clear_highlight() -> void:
	if is_instance_valid(marker): marker.hide()

func _drop(local: Vector2, payload: Variant, origin: Vector2i, footprint := Vector2i.ONE) -> void:
	if _can_drop(local,payload,origin,footprint):
		overview.commit_move(int(payload.index),payload.record,str(container.id),_destination(local,payload,origin,footprint))

func set_moving(index: int) -> void:
	for item: Button in items:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE if index >= 0 else Control.MOUSE_FILTER_STOP
		item.focus_mode = Control.FOCUS_NONE if index >= 0 else Control.FOCUS_ALL
		item.modulate.a = 0.28 if int(item.get_meta("grid_item")) == index else 0.62 if index >= 0 else 1.0
	show_destinations(index)
	for target: Button in targets:
		var valid: bool = index >= 0 and overview.can_move(index,str(container.id),target.get_meta("cell"))
		target.focus_mode = Control.FOCUS_ALL if valid else Control.FOCUS_NONE
		target.disabled = index >= 0 and not valid

func show_destinations(index: int) -> void:
	active_index = index
	_clear_highlight()
	for target: Button in targets:
		var valid: bool = index >= 0 and overview.can_move(index,str(container.id),target.get_meta("cell"))
		target.add_theme_stylebox_override("normal",overview.skin(Color("28665e") if valid else EMPTY_FILL,Color("75c8ba") if valid else EMPTY_EDGE))
		target.add_theme_stylebox_override("disabled",overview.skin(Color("23302f"),Color("344843")))
