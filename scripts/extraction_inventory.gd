extends VBoxContainer

# Presentation only: every raid tile represents one real cargo slot.
signal action_requested(action: String)
const GameInput=preload("./shinrai_input.gd")

const PAPER := Color("#eeeeee")
const MUTED := Color("#c3c3c3")
const MINT := Color("#bfd5c8")
const AMBER := Color("#c7bb8e")
const INK := Color.TRANSPARENT
const LootContainers = preload("./extraction_loot_containers.gd")
const Metabolism = preload("./extraction_metabolism.gd")
const Food = preload("res://scripts/extraction_food_condition.gd")
const Canned = preload("res://scripts/extraction_canned_food.gd")
const ItemSymbol = preload("res://scripts/extraction_item_art.gd")
const Supply=preload("./extraction_weapon_supplies.gd")
const Clothing=preload("./extraction_clothing.gd")
const LoadoutPreview = preload("res://scripts/extraction_loadout_preview.gd")
const WeaponWorkbench = preload("res://scripts/extraction_weapon_workbench.gd")
const WeaponCatalog = preload("res://scripts/extraction_weapon_catalog.gd")
const DESCRIPTIONS := {
	"canned_mackerel":"Sealed mackerel with a pull-tab lid. Open it during a raid before eating.",
	"canned_mackerel_open":"Mackerel in an opened can. Nutrition depends on its condition.",
	"canned_peaches":"Sealed peaches in a plain-lid tin. Requires a can opener in your cargo to open during a raid.",
	"canned_peaches_open":"Peaches in an opened can. Nutrition depends on its condition.",
	"can_opener":"A reusable hand can opener. Carry it to open plain-lid food tins. Pull-tab cans open without it.",
	"garden_mikan":"A Japanese mikan mandarin. Its condition determines the nutrition it supplies.",
	"garden_persimmon":"A Japanese kaki persimmon. Its condition determines the nutrition it supplies.",
	"backpack_regular":"+4 cargo slots and +10 kg cargo allowance while equipped this raid. Pack mass: 0.7 kg.",
	"backpack_mountain":"+8 cargo slots and +20 kg cargo allowance while equipped this raid. Pack mass: 1.5 kg.",
	"park_map": "A collectible Midori Park visitor map. Open it to see park paths and your current position during a raid.",
	"coffee_cup": "+4% stamina capacity and recovery.\n3 minutes. Another cup refreshes it.",
	"circuit": "Recovered control board. Its traces and connectors can be sold to a workshop after extraction.",
	"optics": "Compact optical sensor assembly. Valuable salvage from the park's monitoring equipment.",
	"cell": "Industrial power cell. A common recovery item with a reliable resale value.",
	"archive": "Encrypted telemetry archive. Extract with the storage module intact to bank its value."
}

var raid: Node
var in_hq := false
var entries: Array[Dictionary] = []
var selected := -1
var grid: GridContainer
var detail: VBoxContainer
var search: LineEdit
var tiles: Array[Button] = []
var empty_label: Label
var entrance_tween: Tween
var selection_tween: Tween
var category := "ALL"
var category_buttons: Array[Button] = []
var sorting := 0
var _sort_applied := false
var cargo_scroll: ScrollContainer
var equipment_preview: Control
var _building_details := false
var weapon_workbench: Control
var equipment_title: Label
var equipment_ammunition: Label
const CharacterPreview = preload("res://scripts/extraction_character_preview.gd")
var character_preview: Control
var medical_panel: Control
var inspector_tab := "ITEM"
var inspector_tabs: Array[Button] = []
var detail_shell: PanelContainer
var vicinity_label: Label
var hidden_game_models: Array[Dictionary] = []
var game_model_properties: Array[String] = []
var backpack_slot: Button
var inspector_scroll: ScrollContainer
var capacity_label: Label
var mass_label: Label
var transaction_status: Label
var food_detail_label: Label
var food_action_button: Button
var can_action_button: Button
var can_status_label: Label
var _food_refresh_clock := 0.0
var _controller_empty: Button
var _discard_confirmation:=false
var _status_caption := ""
var _transaction_message := ""
const TILE_SIZE := Vector2(112, 112)
const GRID_COLUMNS := 4
const TILE_FILL := Color(0.035, 0.045, 0.038, 0.18)
const TILE_BORDER := Color("#b8c3bf36")
const BackpackState = preload("res://scripts/extraction_backpack_state.gd")
const FieldOverview = preload("./extraction_inventory_overview.gd")
const MedicalData = preload("./extraction_medical.gd")
const SurvivalSymbols = preload("res://assets/ui/inventory/survival_symbols.svg")
const InventoryFonts = preload("res://scripts/hud/shinrai_ui_style.gd")
var field_overview: Control
var catalog_columns: HBoxContainer
var catalog_switch: Button
var controls_hint: Label
var overview_open := false

func configure(source: Node) -> void:
	raid = source
	in_hq = raid.phase == raid.Phase.HQ
	custom_minimum_size = Vector2(1504, 0)
	add_theme_constant_override("separation", 3)
	_collect_entries()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var head_surface := PanelContainer.new()
	head_surface.add_theme_stylebox_override("panel", _style(Color("101d24ee"),Color("78979876"),10))
	add_child(head_surface)
	head_surface.add_child(head)
	var crest := FieldCrest.new()
	crest.custom_minimum_size = Vector2(34,34)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(crest)
	var title := _text(head, "SHINRAI   /   FIELD KIT", 22, Color("e5efef"))
	title.add_theme_font_override("font", InventoryFonts.heading_font())
	catalog_switch = _button(head, "HQ LOCKER" if in_hq else "CARGO LIST", func() -> void: _set_overview(not overview_open))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_text(head, "HQ  ·  SECURED" if in_hq else "MIDORI PARK  ·  PAUSED", 16, Color("a9c2c3"))
	_text(head, "%s CR" % _number(int(raid.profile.data.credits)), 17, AMBER)
	if not in_hq: _button(head, "FIELD MAP", func() -> void: action_requested.emit("map"))
	_button(head, "BACK TO OPERATIONS" if in_hq else "RESUME RAID", func() -> void: action_requested.emit("inventory_close"))
	var columns := HBoxContainer.new()
	catalog_columns = columns
	columns.name = "InventoryColumns"
	columns.add_theme_constant_override("separation", 32)
	add_child(columns)
	# DayZ-style composition: item information / full character / equipment+cargo.
	var inspector := _column(columns, 440)
	_build_vicinity(inspector)
	var medical_available: bool = raid.has_method("request_treatment") and (in_hq or (is_instance_valid(raid.player) and raid.player.has_method("max_health") and raid.player.get("medical") != null)) and ResourceLoader.exists("res://scripts/extraction_medical_panel.gd")
	if medical_available:
		var tabs := HBoxContainer.new()
		inspector.add_child(tabs)
		for tab: String in ["ITEM", "HEALTH"]:
			var button := _button(tabs, tab, func() -> void: _show_inspector_tab(tab))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inspector_tabs.append(button)
	inspector_scroll = ScrollContainer.new()
	inspector_scroll.custom_minimum_size = Vector2(440, (630 if medical_available else 678) - (104 if not in_hq else 0))
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.add_child(inspector_scroll)
	var inspector_stack := VBoxContainer.new()
	inspector_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(inspector_stack)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	detail_shell = PanelContainer.new()
	detail_shell.add_theme_stylebox_override("panel", _style(Color(0.035,0.045,0.038,0.38), Color("#bec9c426"), 12))
	inspector_stack.add_child(detail_shell)
	detail_shell.add_child(detail)
	if medical_available:
		medical_panel = load("res://scripts/extraction_medical_panel.gd").new()
		medical_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inspector_stack.add_child(medical_panel)
		medical_panel.theme = _field_theme()
		medical_panel.configure(raid)
		medical_panel.hide()
		_show_inspector_tab("ITEM")
	var character := Control.new()
	character.name = "CharacterColumn"
	character.custom_minimum_size = Vector2(536, 752)
	columns.add_child(character)
	character_preview = CharacterPreview.new()
	character_preview.name = "CharacterPreview"
	character_preview.custom_minimum_size = Vector2(536, 590)
	character_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character.add_child(character_preview)
	character_preview.tooltip_text = ""
	character_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	character_preview.offset_bottom = 590
	var hands_column := VBoxContainer.new()
	hands_column.position = Vector2(16, 596)
	hands_column.custom_minimum_size = Vector2(504, 0)
	hands_column.add_theme_constant_override("separation", 4)
	character.add_child(hands_column)
	var orbit := _text(character, "DRAG TO ROTATE  ·  SCROLL TO ZOOM", 13, MUTED)
	orbit.position = Vector2(16, 0)
	orbit.size = Vector2(504, 18)
	orbit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_section(hands_column, "HANDS", "")
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 14)
	var hands_panel := PanelContainer.new()
	hands_panel.add_theme_stylebox_override("panel", _style(Color(0.035,0.045,0.038,0.28), Color("#bac4bf24"), 8))
	hands_column.add_child(hands_panel)
	hands_panel.add_child(hands)
	var preview := LoadoutPreview.new()
	equipment_preview = preview
	preview.name = "EquipmentPreview"
	preview.custom_minimum_size = Vector2(164, 62)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hands.add_child(preview)
	preview.viewport.transparent_bg = true
	for studio_world: Node in preview.viewport.find_children("*", "WorldEnvironment", true, false):
		studio_world.environment.background_mode = Environment.BG_CLEAR_COLOR
	var weapon_copy := VBoxContainer.new()
	weapon_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hands.add_child(weapon_copy)
	equipment_title = _text(weapon_copy, "", 22, PAPER)
	equipment_ammunition = _text(weapon_copy, "", 16, PAPER)
	_button(weapon_copy, "WEAPONS & OPTICS", _open_weapon_workbench)
	if not in_hq and is_instance_valid(raid.player) and raid.player.get("physical_magazines") == true and raid.player.get("magazine_inserted") == true:
		_button(weapon_copy,"REMOVE MAGAZINE",func()->void:_request_inventory_action("unload_magazine"))
	_refresh_equipment_readout()
	var right := _column(columns, 464)
	_build_equipment(right)
	_build_cargo(right)
	if not entries.is_empty(): selected = 0
	_build_details()
	var footer := _build_survival_strip()
	_status_caption = "STASH  /  Banked items stay at HQ" if in_hq else "UNBANKED  /  Extract to keep cargo"
	transaction_status = _text(footer, _status_caption, 14, MUTED)
	transaction_status.name = "InventoryFeedback"
	transaction_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	transaction_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transaction_status.clip_text = true
	transaction_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_refresh_transaction_feedback()
	controls_hint = _text(footer, "", 14, PAPER)
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field_overview = FieldOverview.new()
	field_overview.name = "FieldGearOverview"
	add_child(field_overview)
	move_child(field_overview, columns.get_index())
	field_overview.configure(self)
	_set_overview(true, false)
	_update_hint()
	if is_instance_valid(raid.player):
		for property: Dictionary in raid.player.get_property_list():
			if str(property.name) in ["weapon", "uzi_viewmodel"]: game_model_properties.append(str(property.name))
	_hide_game_models()
	call_deferred("_animate_entrance")
	call_deferred("_focus_first")

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(weapon_workbench):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_F:
		if overview_open: _set_overview(false, false)
		search.grab_focus()
		search.select_all()
		get_viewport().set_input_as_handled()

func _set_overview(active: bool, focus: bool = true) -> void:
	if not is_instance_valid(field_overview): return
	overview_open = active
	catalog_columns.visible = not active
	field_overview.visible = active
	catalog_switch.text = ("HQ LOCKER" if in_hq else "CARGO LIST") if active else "GEAR OVERVIEW"
	if in_hq:
		_status_caption = "FIELD KIT  /  Prepared for your next deployment" if active else "STASH  /  Banked items stay at HQ"
		_refresh_transaction_feedback()
	field_overview.set_overview(active)
	_update_hint()
	if focus: _focus_first()

func _update_hint() -> void:
	if not is_instance_valid(controls_hint): return
	if overview_open:
		controls_hint.text = "D-PAD  Navigate     A  Select     B  Back" if GameInput.gamepad_active() else "Drag items to move     Ctrl F  Search     I  Close"
	else:
		controls_hint.text = "D-PAD  Select     Y  Actions     LB / RB  Categories" if GameInput.gamepad_active() else "Arrows  Select     F  Actions     Ctrl F  Search"

func _collect_entries() -> void:
	entries.clear()
	if in_hq:
		var known: Dictionary = {}
		for spec: Dictionary in raid.ITEMS:
			known[spec.id] = true
			if Food.is_food(str(spec.id)):
				for lot: Dictionary in raid.profile.food_entries(spec):
					lot["bag_index"] = -1
					entries.append(lot)
				continue
			var count := int(raid.profile.data.stash.get(spec.id, 0))
			if count > 0:
				var entry := spec.duplicate(true)
				entry["quantity"] = count
				entry["bag_index"] = -1
				entries.append(entry)
		for key: String in raid.profile.data.stash:
			if known.has(key) or int(raid.profile.data.stash[key]) <= 0:
				continue
			entries.append({"id": key, "title": "Unidentified salvage", "value": 0, "quantity": int(raid.profile.data.stash[key]), "bag_index": -1})
	else:
		for index: int in range(raid.bag.size()):
			var entry: Dictionary = raid.bag[index].duplicate(true)
			entry["quantity"] = 1
			entry["bag_index"] = index
			entry["_source_item"] = raid.bag[index] # Identity survives in-place cargo sorting.
			entries.append(entry)

func _column(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 752)
	panel.add_theme_stylebox_override("panel", _style(INK, Color.TRANSPARENT, 0))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box

func _build_equipment(box: VBoxContainer) -> void:
	_section(box, "EQUIPMENT", "CLOTHES / POCKETS / BACKPACK")
	var outfit: Dictionary = raid.profile.data.get("clothing",Clothing.defaults()) if in_hq else raid.backpack_state.get("clothing",Clothing.defaults())
	_text(box,"POCKETS  %d slots · accessories add no storage" % Clothing.pocket_slots(outfit),16,MUTED)
	for slot: String in outfit:
		var worn := Clothing.spec(str(outfit[slot]))
		if not worn.is_empty():_text(box,str(worn.title),15,PAPER)
	var pack_id: String = raid.equipped_backpack_id() if not in_hq else ""
	character_preview.set_backpack(pack_id)
	backpack_slot = _button(box, "", _select_equipped_pack)
	backpack_slot.name = "BackpackSlot"
	if not pack_id.is_empty():
		backpack_slot.add_theme_stylebox_override("normal", _style(Color(0.07,0.19,0.12,0.28),Color(0.48,0.82,0.61,0.55),8))
		var glow := PackGlow.new()
		glow.name = "BackpackPulse"
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backpack_slot.add_child(glow)
	backpack_slot.custom_minimum_size.y = 64
	backpack_slot.tooltip_text = "Select equipped backpack. Drag a carried backpack here to equip it." if not in_hq else "Backpacks are equipped during a raid."
	var pack_row := HBoxContainer.new()
	pack_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pack_row.offset_left = 10
	pack_row.offset_top = 6
	pack_row.offset_right = -10
	pack_row.offset_bottom = -6
	pack_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backpack_slot.add_child(pack_row)
	if not pack_id.is_empty():
		var art := ItemSymbol.new()
		art.item_id = pack_id
		art.custom_minimum_size = Vector2(65, 50)
		pack_row.add_child(art)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_row.add_child(copy)
	_text(copy, str(BackpackState.PACKS[pack_id].title) if not pack_id.is_empty() else "No backpack equipped", 20, PAPER)
	_text(copy, "EQUIPPED  ·  %d ITEMS" % raid.bag.size() if not pack_id.is_empty() else "Find during a raid" if in_hq else "Drag a carried backpack here to equip", 15, MUTED)
	backpack_slot.disabled = in_hq
	backpack_slot.set_drag_forwarding(Callable(), _can_drop_pack, _drop_pack)
	var medical: int = (1 if raid.profile.data.prepared_medkit else 0) if in_hq else raid.medkits
	var maximum: float = float(raid.player.max_health()) if is_instance_valid(raid.player) and raid.player.has_method("max_health") else 100.0
	_text(box, "MEDKITS  %02d  /  NEXT RAID" % medical if in_hq else "HP  %s / %s      MEDKITS  %02d" % [("%.1f" % raid.player.health).trim_suffix(".0"), ("%.1f" % maximum).trim_suffix(".0"), medical], 17, PAPER)
	if in_hq:
		var purchases := HBoxContainer.new()
		purchases.add_theme_constant_override("separation", 6)
		box.add_child(purchases)
		var level := int(raid.profile.data.pack_level)
		var upgrade := _button(purchases, "EXPAND CARGO  ·  %d CR" % (450 * (level + 1)) if level < 2 else "CARGO FULLY UPGRADED", func() -> void: _request_inventory_action("upgrade"))
		upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade.disabled = level >= 2 or int(raid.profile.data.credits) < 450 * (level + 1) or not raid.profile.last_error.is_empty()
		if not raid.profile.last_error.is_empty(): upgrade.tooltip_text = raid.profile.last_error
		var med := _button(purchases, "EXTRA MEDKIT  ·  120 CR", func() -> void: _request_inventory_action("medkit"))
		med.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		med.disabled = raid.profile.data.prepared_medkit or int(raid.profile.data.credits) < 120 or not raid.profile.last_error.is_empty()
		if not raid.profile.last_error.is_empty(): med.tooltip_text = raid.profile.last_error

func _refresh_equipment_readout() -> void:
	var state: Dictionary = raid.active_weapon_loadout() if raid.has_method("active_weapon_loadout") else raid.profile.data.loadout
	var id := str(state.equipped)
	if not state.weapons.has(id):
		if is_instance_valid(equipment_preview): equipment_preview.hide()
		if is_instance_valid(character_preview): character_preview.set_loadout("", "")
		equipment_title.text = "UNARMED"
		equipment_ammunition.text = "Find a weapon · extract to keep it"
		return
	var record: Dictionary = state.weapons[id]
	if is_instance_valid(equipment_preview):
		equipment_preview.show()
	if is_instance_valid(equipment_preview):
		equipment_preview.call("set_loadout", id, str(record.optic))
	if is_instance_valid(character_preview):
		character_preview.set_loadout(id, str(record.optic))
	equipment_title.text = str(WeaponCatalog.WEAPONS[id].title)
	var rounds := int(record.ammo)
	var spare := int(record.reserve)
	if not in_hq and is_instance_valid(raid.player) and str(raid.player.get("weapon_id")) == id:
		rounds = int(raid.player.ammo)
		spare = int(raid.player.reserve)
	equipment_ammunition.text = "%s     %02d / %03d" % [WeaponCatalog.weapon(id).ammo_type, rounds, spare]

func _open_weapon_workbench() -> void:
	if is_instance_valid(weapon_workbench):
		return
	_transaction_message = ""
	_refresh_transaction_feedback()
	for child: Node in get_children():
		if child is Control:
			child.hide()
	weapon_workbench = WeaponWorkbench.new()
	add_child(weapon_workbench)
	weapon_workbench.configure(raid)
	weapon_workbench.exit_requested.connect(func() -> void: action_requested.emit("inventory_close"))
	weapon_workbench.closed.connect(func() -> void:
		# Changing an optic can return a reserved reload magazine to cargo.
		# Rebuild from current records and let the HUD restore the return view.
		raid.hud.show_inventory(raid))

func _build_cargo(box: VBoxContainer) -> void:
	var total := 0
	var value := 0
	for entry: Dictionary in entries:
		total += int(entry.quantity)
		value += int(entry.quantity) * int(entry.value)
	_section(box, "STASH" if in_hq else "CARRIED CARGO", "%s CR TOTAL" % _number(value))
	var capacity_row := HBoxContainer.new()
	box.add_child(capacity_row)
	var cells: int = raid.cargo_cells_used() if not in_hq else 0
	capacity_label = _text(capacity_row, "%d BANKED ITEMS" % total if in_hq else "%02d / %02d CELLS%s" % [cells, raid.capacity(), "  ·  FULL" if cells >= raid.capacity() else ""], 21, PAPER)
	capacity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mass_label = _text(capacity_row, "SECURED AT HQ" if in_hq else "%.1f / %.1f kg" % [raid.cargo_mass_kg(), raid.cargo_limit_kg()], 18, MUTED)
	var meter := ProgressBar.new()
	meter.name = "CargoCapacity"
	meter.custom_minimum_size.y = 4
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.max_value = 1.0
	meter.value = 1.0 if in_hq else maxf(float(cells) / raid.capacity(), raid.cargo_mass_kg() / raid.cargo_limit_kg())
	meter.add_theme_stylebox_override("background", _style(Color("#90909040"), Color.TRANSPARENT, 0))
	meter.add_theme_stylebox_override("fill", _style(AMBER if not in_hq and meter.value >= 1.0 else MINT.darkened(0.3), Color.TRANSPARENT, 0))
	box.add_child(meter)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	box.add_child(tools)
	search = LineEdit.new()
	search.name = "InventorySearch"
	search.placeholder_text = "Search cargo…"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", 16)
	search.add_theme_color_override("font_color", PAPER)
	search.add_theme_stylebox_override("normal", _style(Color("#10101064"), TILE_BORDER, 9))
	search.add_theme_stylebox_override("focus", _style(Color("#20202099"), MINT, 9))
	search.text_changed.connect(_filter_changed)
	search.text_submitted.connect(func(_query: String) -> void: _focus_first())
	tools.add_child(search)
	var sort_button := _button(tools, "SORT / NAME", _sort_entries)
	sort_button.disabled = entries.size() < 2
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 5)
	box.add_child(categories)
	for kind: String in ["ALL", "TECH", "SUPPLIES", "DOCUMENTS", "GEAR", "TOOLS"]:
		var button := _button(categories, kind, func() -> void: _set_category(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		category_buttons.append(button)
	_update_categories()
	cargo_scroll = ScrollContainer.new()
	cargo_scroll.custom_minimum_size = Vector2(464, 280)
	cargo_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cargo_scroll.follow_focus = true
	box.add_child(cargo_scroll)
	grid = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	cargo_scroll.add_child(grid)
	for index: int in range(entries.size()): _add_tile(index)
	empty_label = _text(box, "Stash is empty. Extract with cargo to bank items." if in_hq and entries.is_empty() else "Grouped by item · Select to inspect" if in_hq else "%d carried · Select to inspect" % total, 17, MUTED)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.custom_minimum_size.x = 464

func _add_tile(index: int) -> void:
	var entry: Dictionary = entries[index]
	var tile := Button.new()
	tile.name = "Item_%d" % index
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = _item_tooltip(entry)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.add_theme_stylebox_override("normal", _style(TILE_FILL, TILE_BORDER, 5))
	tile.add_theme_stylebox_override("hover", _style(Color(0.12,0.16,0.13,0.48), MINT, 5))
	tile.add_theme_stylebox_override("pressed", _style(Color(0.15,0.18,0.13,0.55), AMBER, 5))
	var focus_style := _style(Color.TRANSPARENT, PAPER, 5)
	focus_style.set_border_width_all(2)
	tile.add_theme_stylebox_override("focus", focus_style)
	tile.pressed.connect(func() -> void: _select(index))
	tile.gui_input.connect(func(event: InputEvent) -> void: _tile_input(event, index))
	tile.focus_entered.connect(func() -> void:
		if detail != null and not _building_details: _select(index))
	tile.set_drag_forwarding(func(at: Vector2) -> Variant: return _drag_item(at, index), Callable(), Callable())
	grid.add_child(tile)
	tiles.append(tile)
	var corners := SlotAccent.new()
	corners.name = "SlotAccent"
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(corners)
	corners.hide()
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -8
	content.offset_top = 6
	content.offset_bottom = -6
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	var equipped := not in_hq and not str(entry.get("pack_uid", "")).is_empty() and str(entry.get("pack_uid")) == str(raid.backpack_state.equipped_uid)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",2)
	content.add_child(top)
	if Food.is_food(str(entry.id)):
		var badge := _text(top,Food.label(_food_record(entry)).to_upper(),12,Food.tint(_food_record(entry)))
		badge.name = "FoodConditionBadge"
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		badge.clip_text = true
		tile.set_meta("food_badge",badge)
	var count := _text(top, "×%d" % int(entry.quantity) if in_hq else "%02d%s" % [int(entry.bag_index) + 1, "  E" if equipped else ""], 14, MINT if equipped else MUTED)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_art(content, str(entry.id), Vector2(0, 52))
	var caption := _text(content, str(entry.title), 14, PAPER)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = true

func _kind(id: String) -> String:
	if Supply.is_supply(id) or not Clothing.spec(id).is_empty():return "GEAR"
	if id in LootContainers.Tables.TOOLS: return "TOOLS"
	if Canned.is_closed(id) or Canned.is_opened(id): return "SUPPLIES"
	if id in ["backpack_regular","backpack_mountain"]: return "GEAR"
	if id in ["garden_mikan", "garden_persimmon", "ration_bar", "bandage", "tourniquet", "splint", "coffee_cup", "bottled_water_closed", "bottled_water_open", "sports_bottle_closed", "sports_bottle_open"]: return "SUPPLIES"
	if id == "park_map": return "DOCUMENTS"
	return "TECH"

func _set_category(value: String) -> void:
	category = value
	_update_categories()
	_filter_changed(search.text)

func _update_categories() -> void:
	for button: Button in category_buttons:
		button.add_theme_color_override("font_color", MINT if button.text == category else MUTED)
		button.add_theme_stylebox_override("normal", _style(Color(0.18,0.20,0.14,0.42) if button.text == category else Color(0.035,0.045,0.038,0.22), MINT if button.text == category else TILE_BORDER, 8))

func _sort_entries() -> void:
	if not in_hq:
		action_requested.emit("sort_cargo")
		return
	var selected_id := str(entries[selected].id) if selected >= 0 else ""
	var selected_slot := int(entries[selected].bag_index) if selected >= 0 else -1
	sorting = (sorting + 1) % 2
	_sort_applied = true
	_rebuild_sorted_tiles(selected_id, selected_slot,str(entries[selected].get("food_lot_id","")) if selected >= 0 else "")

func _rebuild_sorted_tiles(selected_id: String, selected_slot: int, selected_lot_id: String = "") -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if sorting == 0 and int(a.value) != int(b.value): return int(a.value) > int(b.value)
		return str(a.title) < str(b.title))
	for child: Node in grid.get_children():
		if child is Button and child!=_controller_empty:
			grid.remove_child(child)
			child.queue_free()
	tiles.clear()
	for index: int in range(entries.size()):
		_add_tile(index)
		grid.move_child(tiles.back(), index)
		if str(entries[index].id) == selected_id and int(entries[index].bag_index) == selected_slot and str(entries[index].get("food_lot_id","")) == selected_lot_id:
			selected = index
	_filter_changed(search.text)
	_build_details()
	# Sorting is a view operation. Original bag indices remain bound to actions.
	for node: Node in search.get_parent().get_children():
		if node is Button: node.text = "SORT / VALUE" if sorting == 1 else "SORT / NAME"


func view_state() -> Dictionary:
	var state := {"in_hq": in_hq, "query": search.text, "category": category,
		"controller_focus": _controller_focus_state(), "inspector_tab": inspector_tab, "sorting": sorting, "sort_applied": _sort_applied, "scroll": cargo_scroll.scroll_vertical}
	if selected >= 0 and selected < entries.size():
		state["item"] = entries[selected]
	if is_instance_valid(field_overview):
		state["overview_open"] = overview_open
		state["overview_page"] = field_overview.page
		state["overview_record"] = field_overview.selected_record()
		if is_instance_valid(medical_panel): state["body_part"] = medical_panel.selected_part
	return state

func restore_view_state(state: Dictionary) -> void:
	if bool(state.get("in_hq", not in_hq)) != in_hq:
		return
	search.text = str(state.get("query", ""))
	category = str(state.get("category", "ALL"))
	sorting = int(state.get("sorting", 0))
	_sort_applied = bool(state.get("sort_applied", false))
	if in_hq and _sort_applied:
		_rebuild_sorted_tiles("", -1)
	var previous: Dictionary = state.get("item", {})
	selected = -1
	# Prefer the actual carried record, then a backpack's unique ID. An item ID
	# alone is not sufficient when two wearable packs occupy different slots.
	if not in_hq and previous.has("_source_item"):
		for index: int in range(entries.size()):
			if is_same(entries[index].get("_source_item"), previous._source_item):
				selected = index
				break
	if selected < 0 and not previous.is_empty():
		for index: int in range(entries.size()):
			var entry: Dictionary = entries[index]
			if str(entry.id) != str(previous.id): continue
			if in_hq and str(entry.get("food_lot_id","")) != str(previous.get("food_lot_id","")): continue
			if not in_hq and str(entry.get("pack_uid", "")) != str(previous.get("pack_uid", "")): continue
			if selected < 0 or int(entry.bag_index) == int(previous.bag_index): selected = index
	_update_categories()
	_filter_changed(search.text)
	_build_details()
	# Apply after container layout and initial keyboard focus have settled.
	_restore_scroll_after_layout(int(state.get("scroll", 0)))
	_show_inspector_tab(str(state.get("inspector_tab", "ITEM")))
	if is_instance_valid(field_overview):
		_set_overview(bool(state.get("overview_open", true)), false)
		if overview_open:
			field_overview.restore_record(state.get("overview_record",{}))
			field_overview.restore_page(str(state.get("overview_page","body")), str(state.get("body_part","thorax")))
			return
	if GameInput.gamepad_active():call_deferred("_restore_controller_focus",state.get("controller_focus",{}))

func _restore_scroll_after_layout(offset: int) -> void:
	await get_tree().process_frame
	if is_inside_tree() and not is_queued_for_deletion():
		cargo_scroll.scroll_vertical = offset

func _filter_changed(query: String) -> void:
	var visible_count := 0
	var first := -1
	for index: int in range(tiles.size()):
		var matches := query.strip_edges().is_empty() or str(entries[index].title).to_lower().contains(query.to_lower().strip_edges())
		tiles[index].visible = matches and (category == "ALL" or _kind(str(entries[index].id)) == category)
		if tiles[index].visible:
			visible_count += 1
			if first < 0: first = index
	for node: Node in grid.get_children():
		if not node is Button: node.visible = query.strip_edges().is_empty() and category == "ALL"
	if not is_instance_valid(_controller_empty):
		_controller_empty=Button.new();_controller_empty.text="NO MATCHING CARGO"
		_controller_empty.tooltip_text="LB / RB changes category; Y opens item or Health actions."
		_controller_empty.pressed.connect(func() -> void:
			if not category_buttons.is_empty():category_buttons[0].grab_focus())
		grid.add_child(_controller_empty)
	_controller_empty.visible=GameInput.gamepad_active() and visible_count==0
	empty_label.text = "%d matching item%s" % [visible_count, "s" if visible_count != 1 else ""] if not query.is_empty() or category != "ALL" else "%d item%s · Select to inspect" % [visible_count, "s" if visible_count != 1 else ""]
	if selected < 0 or selected >= tiles.size() or not tiles[selected].visible:
		selected = first
		_build_details()

func _select(index: int) -> void:
	if index == selected:
		_show_inspector_tab("ITEM")
		return
	if index < 0 or index >= entries.size(): return
	selected = index
	_show_inspector_tab("ITEM")
	inspector_scroll.scroll_vertical = 0
	_build_details()
	if selection_tween != null:
		selection_tween.kill()
	detail.modulate.a = 0.45
	selection_tween = create_tween()
	selection_tween.tween_property(detail, "modulate:a", 1.0, 0.13)

func _build_details() -> void:
	_discard_confirmation=false
	_transaction_message = ""
	_refresh_transaction_feedback()
	_building_details = true
	food_detail_label = null
	food_action_button = null
	can_action_button = null
	can_status_label = null
	for child: Node in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	for index: int in range(tiles.size()):
		var tile_style := _style(Color(0.10,0.13,0.10,0.36) if index == selected else TILE_FILL, AMBER if index == selected else TILE_BORDER, 5)
		tile_style.set_border_width_all(2 if index == selected else 1)
		tiles[index].add_theme_stylebox_override("normal", tile_style)
		tiles[index].get_node("SlotAccent").visible = index == selected
	if selected < 0 or selected >= entries.size():
		_text(detail, "NO ITEM SELECTED", 25, PAPER)
		_text(detail, "Select an item from the cargo grid. Clear your filters to see everything.", 19, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_building_details = false
		return
	var entry: Dictionary = entries[selected]
	var identity := HBoxContainer.new()
	detail.add_child(identity)
	var kind := _text(identity, _kind(str(entry.id)), 14, MUTED)
	kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(identity,"BANKED" if in_hq else "CARRIED ITEM %02d" % (int(entry.bag_index)+1),14,MUTED)
	var title := _text(detail,entry.title,28,PAPER)
	title.name = "ItemTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_art(detail,str(entry.id),Vector2(0,88))
	var stats := HBoxContainer.new()
	stats.name = "ItemStats"
	stats.add_theme_constant_override("separation",12)
	detail.add_child(stats)
	_inspector_stat(stats,"MASS","%.2f kg" % raid.cargo_item_mass(entry))
	_inspector_stat(stats,"VALUE","%d CR" % int(entry.value))
	_inspector_stat(stats,"QUANTITY","×%d" % int(entry.quantity))
	_inspector_heading("EFFECT" if entry.id=="coffee_cup" else "CAPACITY" if str(entry.id).begins_with("backpack_") else "DESCRIPTION")
	var description := str(DESCRIPTIONS.get(entry.id,LootContainers.spec(str(entry.id)).get("description","Recovered salvage. Extract safely to bank this item.")))
	if entry.id == "coffee_cup":
		_inspector_fact("Stamina & recovery","+4%")
		_inspector_fact("Duration","3 minutes")
		_text(detail,"Another cup refreshes the duration.",16,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif str(entry.id).begins_with("backpack_"):
		_inspector_fact("Cargo slots","+8" if entry.id=="backpack_mountain" else "+4")
		_inspector_fact("Mass allowance","+20 kg" if entry.id=="backpack_mountain" else "+10 kg")
		_text(detail,"Bonus applies while equipped this raid.",16,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var copy := _text(detail,description,18,MUTED)
		copy.name = "ItemDescription"
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_theme_constant_override("line_spacing",4)
	if Food.is_food(str(entry.id)):
		_inspector_heading("CONDITION")
		food_detail_label = _text(detail,_food_summary(entry),16,Food.tint(_food_record(entry)))
		food_detail_label.name = "FoodConditionSummary"
		food_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Supply.MAGAZINES.has(str(entry.id)):
		_inspector_fact("Rounds",str(Supply.rounds(entry))+" / "+str(WeaponCatalog.WEAPONS[Supply.MAGAZINES[str(entry.id)]].magazine))
	elif Supply.AMMUNITION.has(str(entry.id)):
		_inspector_fact("Loose rounds",str(Supply.rounds(entry)))
	_inspector_heading("ACTIONS")
	if Supply.MAGAZINES.has(str(entry.id)) and not in_hq:
		_primary_action(_button(detail,"PACK MAGAZINE WITH LOOSE ROUNDS",func()->void:_request_inventory_action("pack_magazine:%d" % int(entry.bag_index))))
	elif not Clothing.spec(str(entry.id)).is_empty() and not in_hq:
		_primary_action(_button(detail,"WEAR / EQUIP",func()->void:_request_inventory_action("wear_clothing:%d" % int(entry.bag_index))))
	elif Canned.is_closed(str(entry.id)):
		if in_hq:
			_text(detail,"Open during a raid.",16,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			can_action_button = _button(detail,"OPEN PULL TAB" if str(entry.id)=="canned_mackerel" else "OPEN WITH CAN OPENER",func() -> void: _open_can_from_entry(entry))
			can_action_button.name = "OpenSelectedCan"
			_primary_action(can_action_button)
			can_status_label = _text(detail,"",16,AMBER)
			can_status_label.name = "CanOpeningRequirement"
			can_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_refresh_can_action(entry)
	elif entry.id == "coffee_cup" and not in_hq:
		var drink := _button(detail,"DRINK COFFEE  ·  3 MIN BOOST",func() -> void: _request_inventory_action("drink_coffee:%d" % int(entry.bag_index)))
		drink.tooltip_text = "Consumes this cup and refreshes the stamina boost."
		_primary_action(drink)
	elif Metabolism.PROVISIONS.has(str(entry.id)) and not in_hq:
		var use := _button(detail,_food_action_label(entry),func() -> void: _request_inventory_action("consume_provision:%d" % int(entry.bag_index)))
		food_action_button = use
		_refresh_food_action(entry)
		_primary_action(use)
	elif entry.id == "park_map":
		_primary_action(_button(detail,"OPEN MAP",func() -> void: action_requested.emit("open_collected_map")))
	if str(entry.id) in ["backpack_regular","backpack_mountain"] and not in_hq:
		var uid := str(entry.get("pack_uid",""))
		var active := uid==str(raid.backpack_state.equipped_uid)
		var equip := _button(detail,"UNEQUIP BACKPACK" if active else "EQUIP BACKPACK",func() -> void: _request_inventory_action("equip_pack:"+("" if active else uid)))
		_primary_action(equip)
		var next: Dictionary = raid.backpack_state.duplicate(true)
		equip.disabled = not BackpackState.equip(next, raid.bag, "" if active else uid, int(raid.profile.data.pack_level))
		if equip.disabled:
			equip.tooltip_text = "Your cargo would exceed the remaining slot or mass allowance."
			_text(detail, "Reduce cargo before changing this backpack.", 16, AMBER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(stretch)
	if in_hq:
		var sell_one := _button(detail, "SELL ONE  ·  %d CR" % int(entry.value), func() -> void: _request_inventory_action(_sell_action(entry,1)))
		_primary_action(sell_one)
		sell_one.disabled = int(entry.value) <= 0 or not raid.profile.last_error.is_empty()
		if not raid.profile.last_error.is_empty(): sell_one.tooltip_text = raid.profile.last_error
		if int(entry.quantity) > 1:
			var sell_all := _button(detail, "SELL ×%d  ·  %d CR" % [int(entry.quantity), int(entry.quantity) * int(entry.value)], func() -> void: _request_inventory_action(_sell_action(entry,int(entry.quantity))))
			sell_all.disabled = int(entry.value) <= 0 or not raid.profile.last_error.is_empty()
			if not raid.profile.last_error.is_empty(): sell_all.tooltip_text = raid.profile.last_error
		if int(entry.value) <= 0:
			_text(detail, "No sale price is registered for this item. It remains safely banked.", 15, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if Food.is_perishable(str(entry.id)) and not str(entry.get("food_lot_id","")).is_empty():
			var discard := _button(detail,"DISCARD LOT…",func() -> void: _confirm_discard_food_lot(entry))
			discard.disabled = not raid.profile.last_error.is_empty()
			discard.tooltip_text = raid.profile.last_error if discard.disabled else "Discard only this selected food lot and its displayed quantity. No credits are paid."
	else:
		_button(detail, "DISCARD ITEM…", func() -> void: _confirm_discard(entry))
	_building_details = false

func _carried_entry_index(entry: Dictionary) -> int:
	if in_hq or not entry.has("_source_item"): return -1
	for index: int in range(raid.bag.size()):
		if is_same(raid.bag[index],entry._source_item): return index
	return -1

func _refresh_can_action(entry: Dictionary) -> void:
	if not is_instance_valid(can_action_button): return
	var index := _carried_entry_index(entry)
	var reason := "This item is no longer in your cargo."
	if index >= 0:
		var item: Dictionary = raid.bag[index]
		reason = Canned.blocked_reason(item,raid.bag)
		can_action_button.disabled = not Canned.can_open(item,raid.bag)
	else:
		can_action_button.disabled = true
	can_action_button.tooltip_text = reason if not reason.is_empty() else "Open this can in its current cargo slot. A can opener, when required, is kept."
	if is_instance_valid(can_status_label):
		can_status_label.text = reason
		can_status_label.visible = not reason.is_empty()

func _open_can_from_entry(entry: Dictionary) -> void:
	var index := _carried_entry_index(entry)
	if index < 0:
		_transaction_message = "This item is no longer in your cargo."
		_refresh_transaction_feedback()
		_refresh_can_action(entry)
		return
	var item: Dictionary = raid.bag[index]
	if not Canned.can_open(item,raid.bag):
		_transaction_message = Canned.blocked_reason(item,raid.bag)
		_refresh_transaction_feedback()
		_refresh_can_action(entry)
		return
	_request_inventory_action("open_can:%d"%index)

func _food_record(entry: Dictionary) -> Dictionary:
	var item: Dictionary = entry.get("_source_item",entry)
	Food.ensure(item)
	return item

func _item_tooltip(entry: Dictionary) -> String:
	var copy := "%s · %.2f kg · %d CR each" % [entry.title,raid.cargo_item_mass(entry),int(entry.value)]
	if Food.is_food(str(entry.id)): copy += "\n"+_food_summary(entry)
	return copy

func _food_summary(entry: Dictionary) -> String:
	var item := _food_record(entry)
	var text: String = Food.label(item)
	var gain: Dictionary = Metabolism.PROVISIONS.get(str(item.id),{})
	if not gain.is_empty():
		var effects: Dictionary = Food.effects(item)
		text += "\nNutrition: %+.1f food, %+.1f water, %+.1f energy" % [float(gain.get("food",0.0))*float(effects.get("food_multiplier",1.0)),float(gain.get("water",0.0))*float(effects.get("water_multiplier",1.0)),float(gain.get("energy",0.0))*float(effects.get("energy_multiplier",1.0))]
	var warning: String = Food.warning(item)
	if not warning.is_empty(): text += "\n"+warning
	if float(gain.get("food",0.0)) > 0.0 and raid.metabolism.nausea_remaining() > 0.0:
		text += "\nNAUSEA: eating now causes vomiting; this meal will be lost."
	return text

func _food_action_label(entry: Dictionary) -> String:
	var id := str(entry.id)
	var state: String = Food.state(_food_record(entry))
	if Canned.is_opened(id):
		return "EAT "+state.to_upper()+" CANNED FOOD" if state in ["stale","spoiled","rotten"] else "EAT CANNED FOOD"
	if id in ["garden_mikan","garden_persimmon"]:
		return "EAT "+state.to_upper()+" FRUIT" if state in ["stale","spoiled","rotten"] else "EAT FRUIT"
	return "EAT RATION" if id == "ration_bar" else "DRINK"

func _refresh_food_action(entry: Dictionary) -> void:
	if not is_instance_valid(food_action_button): return
	var item := _food_record(entry)
	food_action_button.text = _food_action_label(entry)
	food_action_button.disabled = not raid.metabolism.can_consume_item(item)
	var warning: String = Food.warning(item)
	var provision: Dictionary = Metabolism.PROVISIONS.get(str(item.id),{})
	if float(provision.get("food",0.0)) > 0.0 and raid.metabolism.nausea_remaining() > 0.0:
		var nausea_warning := "Nausea: eating now triggers vomiting and loses this meal. Wait until nausea clears before eating. Eating restarts a 60-second stomach-settling period."
		warning = nausea_warning+("\n"+warning if not warning.is_empty() else "")
	food_action_button.tooltip_text = warning if not warning.is_empty() else "Reserves are already full." if food_action_button.disabled else "Consume this item using its current condition and nutrition."

func _refresh_food_presentation() -> void:
	if not is_instance_valid(grid): return
	for index: int in range(mini(entries.size(),tiles.size())):
		var entry: Dictionary = entries[index]
		if not Food.is_food(str(entry.id)): continue
		var item := _food_record(entry)
		var badge := tiles[index].get_meta("food_badge",null) as Label
		if is_instance_valid(badge):
			badge.text = Food.label(item).to_upper()
			badge.add_theme_color_override("font_color",Food.tint(item))
		tiles[index].tooltip_text = _item_tooltip(entry)
	if selected < 0 or selected >= entries.size() or not Food.is_food(str(entries[selected].id)): return
	var selected_entry: Dictionary = entries[selected]
	if is_instance_valid(food_detail_label):
		food_detail_label.text = _food_summary(selected_entry)
		food_detail_label.add_theme_color_override("font_color",Food.tint(_food_record(selected_entry)))
	_refresh_food_action(selected_entry)
	_refresh_can_action(selected_entry)

func _sell_action(entry: Dictionary, quantity: int) -> String:
	var lot_id := str(entry.get("food_lot_id",""))
	if not lot_id.is_empty(): return "sell_food:%s:%s:%d" % [entry.id,lot_id,quantity]
	return "sell_item:%s:%d" % [entry.id,quantity]

func _inspector_heading(title: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 25
	row.add_theme_constant_override("separation",12)
	detail.add_child(row)
	_text(row,title,14,PAPER)
	var rule := ColorRect.new()
	rule.color = Color("#d0d0d038")
	rule.custom_minimum_size.y = 1
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)

func _inspector_stat(parent: Control, caption: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",3)
	parent.add_child(box)
	_text(box,caption,14,MUTED)
	_text(box,value,23,PAPER)

func _inspector_fact(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	detail.add_child(row)
	var label := _text(row,caption,18,MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(row,value,19,PAPER)

func _primary_action(button: Button) -> void:
	button.custom_minimum_size.y = 42
	button.add_theme_stylebox_override("normal",_style(Color(0.16,0.18,0.12,0.50),AMBER,8))
	button.add_theme_stylebox_override("hover",_style(Color(0.25,0.28,0.17,0.70),AMBER,8))
	button.add_theme_stylebox_override("pressed",_style(Color(0.29,0.30,0.19,0.78),AMBER,8))
	button.add_theme_color_override("font_color",PAPER)
	button.add_theme_color_override("font_hover_color",PAPER)
	button.add_theme_color_override("font_pressed_color",PAPER)

func _request_inventory_action(action: String) -> void:
	_transaction_message = ""
	_refresh_transaction_feedback()
	action_requested.emit(action)
	# Success and save-failure refreshes replace this panel. The replacement
	# reads the actual save error; never carry an old transient notice into it.
	if not is_inside_tree() or is_queued_for_deletion(): return
	var current_notice := str(raid.notice)
	# These existing transactions announce their rejection and leave the panel
	# open. Read only the reason belonging to the action just attempted.
	if action.begins_with("discard_item:") and current_notice == "Remove cargo before discarding this backpack.":
		_transaction_message = current_notice
	elif action.begins_with("equip_pack:") and current_notice == "Remove cargo before changing to a smaller backpack.":
		_transaction_message = current_notice
	_refresh_transaction_feedback()

func _refresh_transaction_feedback() -> void:
	if not is_instance_valid(transaction_status): return
	var save_error := str(raid.profile.last_error)
	var error := save_error if not save_error.is_empty() else _transaction_message
	transaction_status.text = error if not error.is_empty() else _status_caption
	transaction_status.tooltip_text = error
	transaction_status.add_theme_color_override("font_color", Color("#f0b6a5") if not error.is_empty() else MUTED)

func _confirm_discard_food_lot(entry: Dictionary) -> void:
	# Capture the stable selected lot, never an item aggregate or grid position.
	var id := str(entry.id)
	var lot_id := str(entry.get("food_lot_id",""))
	var quantity := int(entry.quantity)
	if not in_hq or not Food.is_perishable(id) or lot_id.is_empty() or quantity <= 0: return
	_discard_confirmation=true
	food_detail_label = null
	food_action_button = null
	can_action_button = null
	can_status_label = null
	for child: Node in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	_text(detail,"DISCARD THIS FOOD LOT?",27,AMBER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(detail,str(entry.title),22,PAPER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(detail,"%s · Quantity %d" % [Food.label(_food_record(entry)),quantity],19,Food.tint(_food_record(entry))).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(detail,"This permanently removes this food lot from your banked stash. No credits are paid. Other lots stay banked.",19,MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(detail,"KEEP LOT",func() -> void:
		_build_details()
		_focus_first()).grab_focus()
	_button(detail,"CONFIRM DISCARD",func() -> void: _request_inventory_action("discard_food:%s:%s:%d" % [id,lot_id,quantity]))

func _confirm_discard(entry: Dictionary) -> void:
	_discard_confirmation=true
	# Confirmation binds the original slot, never a filtered grid position.
	for child: Node in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	_text(detail, "DISCARD THIS ITEM?", 27, AMBER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(detail, str(entry.title), 22, PAPER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(detail, "This permanently removes the item from your cargo. It will not be banked at extraction.", 19, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(detail, "KEEP ITEM", func() -> void:
		_build_details()
		_focus_first()).grab_focus()
	_button(detail, "CONFIRM DISCARD", func() -> void: _request_inventory_action("discard_item:%d" % int(entry.bag_index)))

func _animate_entrance() -> void:
	if not is_inside_tree():
		return
	modulate.a = 0.0
	entrance_tween = create_tween()
	entrance_tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _focus_first() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if overview_open and is_instance_valid(field_overview):
		field_overview.focus_first()
		return
	var retained_tab := inspector_tab
	if selected >= 0 and selected < tiles.size() and tiles[selected].visible:
		tiles[maxi(0, selected)].grab_focus()
	elif GameInput.gamepad_active() and is_instance_valid(_controller_empty) and _controller_empty.visible:
		_controller_empty.grab_focus()
	elif GameInput.gamepad_active() and not category_buttons.is_empty():
		category_buttons[0].grab_focus()
	else:
		search.grab_focus()
	# Initial/deferred focus is not a new item choice after a view-state refresh.
	_show_inspector_tab(retained_tab)

func _animate_icon(icon: Control, hovered: bool) -> void:
	if icon.has_meta("hover_tween"):
		var previous: Tween = icon.get_meta("hover_tween")
		if previous != null:
			previous.kill()
	var tween := icon.create_tween()
	icon.set_meta("hover_tween", tween)
	tween.tween_property(icon, "modulate:a", 1.0 if hovered else 0.90, 0.12)

func _text(parent: Node, content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# Keep light labels readable over sky and foliage without darkening the world.
	if color.get_luminance() > 0.25:
		label.add_theme_color_override("font_shadow_color", Color("#050807f2"))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("shadow_outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, content: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = content
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_shadow_color", Color(0,0,0,0.95))
	button.add_theme_constant_override("shadow_offset_y", 1)
	button.add_theme_stylebox_override("normal", _style(Color(0.035,0.045,0.038,0.28), TILE_BORDER, 8))
	button.add_theme_stylebox_override("hover", _style(Color(0.12,0.16,0.13,0.55), MINT, 8))
	button.add_theme_stylebox_override("pressed", _style(Color(0.15,0.18,0.13,0.65), AMBER, 8))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), PAPER, 9))
	button.add_theme_stylebox_override("disabled", _style(Color(0.035,0.045,0.038,0.16), TILE_BORDER, 8))
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _style(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin_all(padding)
	return style

func _number(amount: int) -> String:
	var result := str(amount)
	var index := result.length() - 3
	while index > 0:
		result = result.insert(index, ",")
		index -= 3
	return result


func _section(parent: Control, title: String, subtitle: String) -> void:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", _style(Color(0.035,0.045,0.038,0.25), Color("#c7bb8e50"), 5))
	parent.add_child(band)
	var row := HBoxContainer.new()
	band.add_child(row)
	var pip := ColorRect.new()
	pip.color = AMBER
	pip.custom_minimum_size = Vector2(2,18)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pip)
	row.add_theme_constant_override("separation", 10)
	var label := _text(row, title, 17, PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not subtitle.is_empty():
		band.tooltip_text = subtitle
		_text(row, subtitle, 13, MUTED)

func _add_art(parent: Control, id: String, minimum: Vector2) -> void:
	if ItemSymbol.CODES.has(id) or (id != "coffee_cup" and id != "park_map" and not BackpackState.PACKS.has(id) and LootContainers.spec(id).is_empty()):
		# No invented item picture: a compact, explicit record uses the real name below.
		var record := VBoxContainer.new()
		record.custom_minimum_size = minimum
		record.size_flags_vertical = Control.SIZE_EXPAND_FILL
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(record)
		var code := _text(record, str(ItemSymbol.CODES.get(id, "UNIDENTIFIED")), 14 if minimum.y < 70 else 16, MUTED)
		code.size_flags_vertical = Control.SIZE_EXPAND_FILL
		code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if minimum.y > 100:
			_text(record, str(ItemSymbol.RECORD_CATEGORIES.get(id, "UNCLASSIFIED")), 15, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var art := ItemSymbol.new()
		art.item_id = id
		art.custom_minimum_size = minimum
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(art)

func _tile_input(event: InputEvent, index: int) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var delta_index:=0
		if event.is_action_pressed("ui_left"):delta_index=-1
		elif event.is_action_pressed("ui_right"):delta_index=1
		elif event.is_action_pressed("ui_up"):delta_index=-GRID_COLUMNS
		elif event.is_action_pressed("ui_down"):delta_index=GRID_COLUMNS
		if delta_index!=0:
			var visible_tiles: Array[Button]=[]
			for tile: Button in tiles:
				if tile.visible:visible_tiles.append(tile)
			if not visible_tiles.is_empty():visible_tiles[clampi(visible_tiles.find(tiles[index])+delta_index,0,visible_tiles.size()-1)].grab_focus()
			tiles[index].accept_event()
		return
	if not event is InputEventKey or not event.pressed: return
	var visible_indices: Array[int] = []
	for i: int in range(tiles.size()):
		if tiles[i].visible: visible_indices.append(i)
	var position_in_view := visible_indices.find(index)
	var next := position_in_view
	match event.keycode:
		KEY_LEFT: next -= 1
		KEY_RIGHT: next += 1
		KEY_UP: next -= GRID_COLUMNS
		KEY_DOWN: next += GRID_COLUMNS
		KEY_HOME: next = 0
		KEY_END: next = visible_indices.size() - 1
		KEY_F:
			if event.ctrl_pressed: return
			_focus_action()
			tiles[index].accept_event()
			return
		_: return
	if not visible_indices.is_empty(): tiles[visible_indices[clampi(next, 0, visible_indices.size() - 1)]].grab_focus()
	tiles[index].accept_event()

func _focus_action() -> void:
	_show_inspector_tab("ITEM")
	for child: Node in detail.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			inspector_scroll.ensure_control_visible(child)
			return

func _select_equipped_pack() -> void:
	if in_hq: return
	for index: int in range(entries.size()):
		if str(entries[index].get("pack_uid", "")).is_empty(): continue
		if str(entries[index].get("pack_uid")) == str(raid.backpack_state.equipped_uid):
			search.text = ""
			_set_category("GEAR")
			_select(index)
			tiles[index].grab_focus()
			return

func _pack_payload(index: int) -> Dictionary:
	if in_hq or index < 0 or index >= entries.size(): return {}
	var entry: Dictionary = entries[index]
	if not BackpackState.PACKS.has(str(entry.id)) or str(entry.get("pack_uid", "")).is_empty(): return {}
	return {"type":"shinrai_carried_pack", "panel":get_instance_id(), "uid":str(entry.pack_uid), "record":entry.get("_source_item")}

func _drag_item(_at: Vector2, index: int) -> Variant:
	var payload := _pack_payload(index)
	if payload.is_empty(): return null
	_select(index)
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", _style(Color("#253c33ed"), MINT, 12))
	_text(preview, str(entries[index].title) + "  →  BACKPACK", 18, PAPER)
	tiles[index].set_drag_preview(preview)
	backpack_slot.add_theme_stylebox_override("normal", _style(Color("#28463b"), MINT, 9))
	return payload

func _can_drop_pack(_at: Vector2, data: Variant) -> bool:
	var valid := _valid_pack_drop(data)
	if is_instance_valid(backpack_slot) and not in_hq:
		backpack_slot.add_theme_stylebox_override("normal", _style(Color("#28463b") if valid else Color("#462d2d"), MINT if valid else Color("#df9685"), 9))
	return valid

func _valid_pack_drop(data: Variant) -> bool:
	if in_hq or not data is Dictionary or str(data.get("type", "")) != "shinrai_carried_pack": return false
	if raid.phase != raid.Phase.PAUSED or not raid.pending_cache_id.is_empty(): return false
	if int(data.get("panel", 0)) != get_instance_id() or not raid.inventory_open: return false
	var uid := str(data.get("uid", ""))
	if uid.is_empty() or uid == str(raid.backpack_state.equipped_uid): return false
	var found := false
	for item: Dictionary in raid.bag:
		if is_same(item, data.get("record")) and str(item.get("pack_uid", "")) == uid and BackpackState.PACKS.has(str(item.get("id", ""))): found = true
	if not found: return false
	# The same existing capacity check as the equip transaction, on a copy only.
	var next: Dictionary = raid.backpack_state.duplicate(true)
	next.equipped_uid = uid
	return BackpackState.fits(next, raid.bag, int(raid.profile.data.pack_level))

func _drop_pack(at: Vector2, data: Variant) -> void:
	if _can_drop_pack(at, data): _request_inventory_action("equip_pack:" + str(data.uid))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_instance_valid(backpack_slot):
		backpack_slot.add_theme_stylebox_override("normal", _style(Color(0.035,0.045,0.038,0.28), TILE_BORDER, 8))

func _show_inspector_tab(tab: String) -> void:
	inspector_tab = "HEALTH" if tab == "HEALTH" and is_instance_valid(medical_panel) else "ITEM"
	detail_shell.visible = inspector_tab == "ITEM"
	detail.visible = inspector_tab == "ITEM"
	if is_instance_valid(medical_panel): medical_panel.visible = inspector_tab == "HEALTH"
	for button: Button in inspector_tabs:
		button.add_theme_color_override("font_color", MINT if button.text == inspector_tab else MUTED)
	inspector_scroll.scroll_vertical = 0

func _hide_game_models() -> void:
	if not is_instance_valid(raid) or not is_instance_valid(raid.player): return
	for property: String in game_model_properties:
		var node := raid.player.get(property) as Node3D
		if not is_instance_valid(node): continue
		var known := false
		for record: Dictionary in hidden_game_models:
			if is_instance_valid(record.node) and record.node == node:
				# A weapon transition can reveal its replacement while inventory is open.
				record.visible = bool(record.visible) or node.visible
				known = true
		if not known: hidden_game_models.append({"node":node, "visible":node.visible})
		node.hide()

func _process(_delta: float) -> void:
	_food_refresh_clock += _delta
	if _food_refresh_clock >= 1.0:
		_food_refresh_clock = 0.0
		_refresh_food_presentation()
	# A workbench can replace the current viewmodel while inventory remains open.
	_hide_game_models()

func _exit_tree() -> void:
	# Capture a transition reveal even when exit precedes the next inventory frame.
	_hide_game_models()
	for record: Dictionary in hidden_game_models:
		if is_instance_valid(record.node): record.node.visible = record.visible
	hidden_game_models.clear()

func _vicinity_text() -> String:
	if in_hq or not is_instance_valid(raid.player): return ""
	# Read the same closest target the existing E interaction uses. Do not reveal
	# unsearched contents, reach farther, or bypass the search/pickup transaction.
	var site: Dictionary = raid.nearest_site()
	if site.is_empty(): return "Nothing within reach"
	var title := str(site.get("title", "Nearby object"))
	if site.get("kind", "") == "cache" and bool(site.get("discovered", false)):
		if not LootContainers.is_container(site) and not site.get("loot", {}).is_empty():
			title = str(site.loot.get("title", title))
	var interaction := "recover relay" if str(site.get("kind", "")) == "relay" else "inspect" if bool(site.get("discovered", false)) else "search"
	return title + "\nClose inventory · hold E to " + interaction

func _build_vicinity(parent: Control) -> void:
	if in_hq: return
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	parent.add_child(stack)
	_section(stack, "VICINITY", "CURRENT INTERACTION TARGET")
	var surface := PanelContainer.new()
	surface.custom_minimum_size.y = 66
	surface.add_theme_stylebox_override("panel", _style(Color(0.035,0.045,0.038,0.24), Color.TRANSPARENT, 8))
	stack.add_child(surface)
	vicinity_label = _text(surface, _vicinity_text(), 17, PAPER)
	vicinity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


class PackGlow extends Control:
	var elapsed := 0.0
	func _ready() -> void:
		visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
	func _draw() -> void:
		if size.x < 4 or size.y < 4: return
		var pulse := (sin(elapsed*TAU/3.0)+1.0)*0.5
		draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)),Color(0.48,0.86,0.64,0.18+pulse*0.28),false,1.5)
		var travel := fmod(elapsed/3.0,1.0)
		var length := minf(64,size.x*.18)
		var x := 8.0+travel*(size.x-length-16.0)
		draw_line(Vector2(x,size.y-3),Vector2(x+length,size.y-3),Color(0.58,0.92,0.71,0.25+pulse*.35),2,true)


func _field_theme() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_color("font_shadow_color", "Button", Color(0,0,0,0.95))
	theme.set_constant("shadow_offset_y", "Button", 1)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := Color(0.035,0.045,0.038,0.30)
		if state in ["hover", "pressed", "focus"]: fill = Color(0.12,0.16,0.13,0.58)
		theme.set_stylebox(state,"Button",_style(fill,AMBER if state == "focus" else TILE_BORDER,8))
	return theme

class FieldCrest extends Control:
	func _draw() -> void:
		var brass := Color("c7bb8e")
		var jade := Color("bfd5c8")
		draw_arc(Vector2(17,17),14,-PI*.42,PI*.72,28,Color(brass,0.7),1.3,true)
		draw_polyline(PackedVector2Array([Vector2(10,24),Vector2(12,13),Vector2(24,9),Vector2(21,20),Vector2(10,24)]),jade,1.5,true)
		draw_line(Vector2(9,26),Vector2(23,11),brass,1.5,true)
		draw_circle(Vector2(29,23),2,brass)

class SlotAccent extends Control:
	func _draw() -> void:
		var c := Color("c7bb8e")
		for p: Vector2 in [Vector2(2,2),Vector2(size.x-2,2),Vector2(2,size.y-2),Vector2(size.x-2,size.y-2)]:
			var sx := 1.0 if p.x < size.x*.5 else -1.0
			var sy := 1.0 if p.y < size.y*.5 else -1.0
			draw_line(p,p+Vector2(9*sx,0),c,2,true)
			draw_line(p,p+Vector2(0,9*sy),c,2,true)


func _build_survival_strip() -> VBoxContainer:
	var surface := PanelContainer.new()
	surface.name = "SurvivalStats"
	surface.custom_minimum_size.y = 57
	surface.add_theme_stylebox_override("panel", _style(Color("0a181ff5"), Color("738e9082"), 10))
	add_child(surface)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 16)
	surface.add_child(row)
	var reserves: RefCounted = raid.metabolism
	var medical: Variant = raid.player.get("medical") if is_instance_valid(raid.player) else null
	var maximum := int(MedicalData.TOTAL_HP)
	var hp := float(maximum)
	if not in_hq:
		if medical != null:
			hp = medical.effective_hp()
		elif is_instance_valid(raid.player):
			hp = raid.player.health
			maximum = int(raid.player.max_health()) if raid.player.has_method("max_health") else 100
	var water := 100 if in_hq else roundi(reserves.hydration)
	var food := 100 if in_hq else roundi(reserves.food)
	var energy := 100 if in_hq else roundi(reserves.energy)
	var blood := 100 if in_hq or medical == null else roundi(medical.blood)
	var pulse := 68 if in_hq else roundi(reserves.heart_rate)
	_survival_readout(row, 0, "Health", str(ceili(hp)), "/%d" % maximum, "Effective HP includes injury and blood loss.")
	_survival_readout(row, 1, "Water", str(water), "/100", "Drinking restores hydration.")
	_survival_readout(row, 2, "Food", str(food), "/100", "Eating restores your food reserve.")
	_survival_readout(row, 3, "Energy", str(energy), "/100", "Activity draws on your long-term energy reserve.")
	_survival_readout(row, 4, "Blood", str(blood), "%", "Bleeding reduces blood volume.")
	_survival_readout(row, 5, "Pulse", str(pulse), " bpm", "Current heart rate.")
	_survival_readout(row, 6, "Cargo", "%.1f" % raid.cargo_mass_kg(), " kg", "Carried cargo. Your limit is %.1f kg." % raid.cargo_limit_kg())
	var feedback := VBoxContainer.new()
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feedback.add_theme_constant_override("separation", 0)
	row.add_child(feedback)
	return feedback

func _survival_readout(row: HBoxContainer, symbol_index: int, stat: String, amount: String, unit: String, detail_text: String) -> void:
	var group := HBoxContainer.new()
	group.name = stat
	group.add_theme_constant_override("separation", 0)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.mouse_filter = Control.MOUSE_FILTER_PASS
	group.accessibility_name = "%s %s%s" % [stat, amount, unit]
	group.tooltip_text = group.accessibility_name + "\n" + detail_text
	row.add_child(group)
	var glyph := AtlasTexture.new()
	glyph.atlas = SurvivalSymbols
	glyph.region = Rect2(symbol_index * 64, 0, 64, 64)
	glyph.filter_clip = true
	var icon := TextureRect.new()
	icon.texture = glyph
	icon.custom_minimum_size = Vector2(34, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(icon)
	var value := _text(group, amount, 25, Color("f3f6f3"))
	value.name = "Value"
	value.add_theme_font_override("font", InventoryFonts.heading_font())
	var units := _text(group, unit, 17, Color("bfd0d1"))
	units.add_theme_font_override("font", InventoryFonts.body_font())
	var divider := VSeparator.new()
	var line := StyleBoxLine.new()
	line.vertical = true
	line.color = Color("728b8b69")
	divider.add_theme_stylebox_override("separator", line)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)

# Controller routing only changes presentation; original callbacks validate actions.
func controller_event(event: InputEvent) -> bool:
	if is_instance_valid(weapon_workbench):return false
	if overview_open: return field_overview.handle_controller(event)
	var focused:=get_viewport().gui_get_focus_owner()
	if GameInput.pressed(event,"ui_details"):
		if is_instance_valid(focused) and (detail_shell.is_ancestor_of(focused) or (is_instance_valid(medical_panel) and medical_panel.is_ancestor_of(focused))):_focus_first()
		else:_controller_focus_details()
		return true
	var step:= -1 if GameInput.pressed(event,"ui_section_prev") else (1 if GameInput.pressed(event,"ui_section_next") else 0)
	if step==0:return false
	if is_instance_valid(focused) and (detail_shell.is_ancestor_of(focused) or inspector_tabs.has(focused) or (is_instance_valid(medical_panel) and medical_panel.is_ancestor_of(focused))):
		_show_inspector_tab("HEALTH" if inspector_tab=="ITEM" else "ITEM")
		_controller_focus_details()
	elif not category_buttons.is_empty():
		var position_in_tabs:=0
		for i: int in range(category_buttons.size()):
			if category_buttons[i].text==category:position_in_tabs=i
		_set_category(category_buttons[posmod(position_in_tabs+step,category_buttons.size())].text)
		_focus_first()
	return true

func _controller_focus_details() -> void:
	if inspector_tab=="HEALTH" and is_instance_valid(medical_panel):
		var buttons:=medical_panel.find_children("*","Button",true,false)
		for button: Button in buttons:
			if button.is_visible_in_tree() and not button.disabled:
				button.grab_focus();inspector_scroll.ensure_control_visible(button);return
	else:
		_focus_action()
		# Keep the action's successful focus; tab fallback is only for empty details.
		var action_focus:=get_viewport().gui_get_focus_owner()
		if is_instance_valid(action_focus) and detail_shell.is_ancestor_of(action_focus):return
	if not inspector_tabs.is_empty():inspector_tabs[0].grab_focus()

func _controller_focus_state() -> Dictionary:
	var focused:=get_viewport().gui_get_focus_owner()
	if not is_instance_valid(focused) or not is_ancestor_of(focused):return {}
	var zone:="grid"
	if detail_shell.is_ancestor_of(focused):zone="action"
	elif is_instance_valid(medical_panel) and medical_panel.is_ancestor_of(focused):zone="health"
	elif focused==search:zone="search"
	elif category_buttons.has(focused):zone="category"
	elif inspector_tabs.has(focused):zone="tab"
	return {"zone":zone,"name":str(focused.name),"text":str(focused.get("text")) if focused is BaseButton else ""}

func _restore_controller_focus(state: Dictionary) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion() or not GameInput.gamepad_active():return
	var zone: String=state.get("zone","grid")
	if zone in ["action","health"]:
		_show_inspector_tab("HEALTH" if zone=="health" else "ITEM")
		var surface: Node=medical_panel if zone=="health" else detail
		if is_instance_valid(surface):
			for button: Button in surface.find_children("*","Button",true,false):
				if not button.disabled and button.is_visible_in_tree() and (str(button.name)==str(state.get("name","")) or button.text==str(state.get("text",""))):button.grab_focus();return
		_controller_focus_details()
	elif zone=="category":
		for button: Button in category_buttons:
			if button.text==category:button.grab_focus();return
	elif zone=="tab":
		for button: Button in inspector_tabs:
			if button.text==inspector_tab:button.grab_focus();return
	else:_focus_first()

func controller_cancel() -> bool:
	if overview_open and not _discard_confirmation:
		return field_overview.go_back()
	if not _discard_confirmation or not detail.is_visible_in_tree():return false
	_build_details()
	for button: Button in detail.find_children("*","Button",true,false):
		if not button.disabled and button.text.begins_with("DISCARD"):
			button.grab_focus();inspector_scroll.ensure_control_visible(button);return true
	_controller_focus_details()
	return true
