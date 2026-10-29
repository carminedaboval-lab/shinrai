class_name CreatorModeUI
extends CanvasLayer
## Presentation-only v2: v1 API plus first-person holding/preview state.

signal asset_selected(asset_id: String)
signal action_requested(action: String)
signal settings_changed(options: Dictionary)
signal menu_visibility_requested(is_open: bool)

const PAPER := Color("#e8eee7")
const MUTED := Color("#aabbbd")
const MINT := Color("#85dfc4")
const AMBER := Color("#e5bc7f")
const ALERT := Color("#ef9b8c")
const UI_REVISION := "v2.1"
const DEFAULT_STATE := {
	"active": false, "menu_open": false, "selected_asset_id": "",
	"selected_asset_name": "", "target_name": "", "target_editable": false,
	"target_reason": "", "placement_valid": false, "placement_reason": "",
	"can_undo": false, "can_redo": false, "dirty": false, "busy": false,
	"rotation_degrees": 0.0, "height_offset": 0.0, "grid_snap": false,
	"grid_size": 0.25, "surface_align": false, "layout_name": "Current layout",
	"status_text": "", "status_severity": "info", "bindings": {},
	"interaction_mode": "browse", "held_object_name": "", "can_pick_up": false,
	"can_cancel_placement": false, "primary_action_label": "",
	"primary_action_hint": "", "can_change_asset": true
}

var _state: Dictionary = DEFAULT_STATE.duplicate(true)
var _catalog: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _category := ""
var _query := ""
var _revision := 0
var _built := false
var _syncing := false
var _root: Control
var _panel: PanelContainer
var _strip: PanelContainer
var _strip_text: Label
var _strip_status: Label
var _search: LineEdit
var _categories: OptionButton
var _count: Label
var _list: ItemList
var _empty: Label
var _layout_label: Label
var _selected: Label
var _eligibility: Label
var _target: Label
var _target_reason: Label
var _status: Label
var _buttons: Dictionary = {}
var _settings: Dictionary = {}
var _adjust: Button
var _adjust_controls: VBoxContainer
var _adjust_open := false
var _show_unavailable: CheckBox
var _include_unavailable := false

func _ready() -> void:
	layer = 40
	_build()
	_built = true
	_rebuild_categories()
	_rebuild_list(0.0)
	_apply_state()

func set_catalog(entries: Array[Dictionary]) -> void:
	var scroll_value := _list.get_v_scroll_bar().value if _built else 0.0
	_catalog.clear()
	_by_id.clear()
	for entry: Dictionary in entries:
		var record := entry.duplicate(true)
		_catalog.append(record)
		_by_id[str(record.get("id", ""))] = record
	if _built:
		_rebuild_categories()
		_rebuild_list(scroll_value)
		_apply_state()

func set_creator_state(state: Dictionary) -> void:
	for key: Variant in state:
		if DEFAULT_STATE.has(key):
			_state[key] = state[key].duplicate(true) if state[key] is Dictionary else state[key]
	if _built:
		_apply_state()

func set_status(message: String, severity: String = "info") -> void:
	_state.status_text = message
	_state.status_severity = severity
	if _built:
		_apply_state()

func set_creator_visible(active: bool) -> void:
	set_creator_state({"active": active})

func set_menu_open(is_open: bool) -> void:
	set_creator_state({"menu_open": is_open})

func _build() -> void:
	_root = Control.new()
	_root.name = "CreatorModeRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_root.resized.connect(_fit_width)
	_panel = PanelContainer.new()
	_panel.name = "AssetPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -422.0
	_panel.offset_right = -12.0
	_panel.offset_top = 12.0
	_panel.offset_bottom = -12.0
	_panel.add_theme_stylebox_override("panel", _box(Color("#101e22f5"), Color("#53746c"), 12))
	_root.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := _label(header, "SHINRAI  /  CREATOR", MINT, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(header, "Aim in world", "Close the catalog; keep Creator Mode active.")
	close.name = "CloseMenu"
	close.pressed.connect(func() -> void: menu_visibility_requested.emit(false))
	_buttons["close_menu"] = close
	_layout_label = _label(stack, "", MUTED, 14)
	_layout_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search asset names or categories…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = 32
	_search.text_changed.connect(_on_search_changed)
	stack.add_child(_search)
	_categories = OptionButton.new()
	_categories.name = "Category"
	_categories.custom_minimum_size.y = 28
	_categories.item_selected.connect(_on_category_changed)
	stack.add_child(_categories)
	var availability := HBoxContainer.new()
	availability.add_theme_constant_override("separation", 6)
	stack.add_child(availability)
	_count = _label(availability, "", MUTED, 13)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.mouse_filter = Control.MOUSE_FILTER_PASS
	_show_unavailable = CheckBox.new()
	_show_unavailable.name = "ShowUnavailable"
	_show_unavailable.text = "Show unavailable"
	_show_unavailable.toggled.connect(_on_availability_toggled)
	availability.add_child(_show_unavailable)
	var list_area := Control.new()
	list_area.name = "CatalogArea"
	list_area.custom_minimum_size.y = 100
	list_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(list_area)
	_list = ItemList.new()
	_list.name = "Assets"
	_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.max_columns = 1
	_list.same_column_width = true
	_list.clip_contents = true
	_list.allow_reselect = true
	_list.item_selected.connect(_on_item_selected)
	list_area.add_child(_list)
	_empty = _label(list_area, "No assets match. Try another name or category.", MUTED, 15)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selected = _label(stack, "", PAPER, 16)
	_selected.name = "SelectedAsset"
	_selected.mouse_filter = Control.MOUSE_FILTER_PASS
	_eligibility = _label(stack, "", AMBER, 14)
	_eligibility.name = "PlacementReason"
	_eligibility.mouse_filter = Control.MOUSE_FILTER_PASS
	_target = _label(stack, "", PAPER, 15)
	_target.name = "AimedObject"
	_target.mouse_filter = Control.MOUSE_FILTER_PASS
	_target_reason = _label(stack, "", MUTED, 14)
	_target_reason.name = "TargetReason"
	_target_reason.mouse_filter = Control.MOUSE_FILTER_PASS
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	_action_button(actions, "Place here", "place")
	_action_button(actions, "Pick up aimed", "pick_up")
	_action_button(actions, "Cancel placement", "cancel_placement")
	var secondary := HBoxContainer.new()
	stack.add_child(secondary)
	_action_button(secondary, "Remove aimed", "remove")
	_adjust = _button(secondary, "Adjust ▸", "Optional rotation, height, grid and surface precision.")
	_adjust.name = "Adjust"
	_adjust.toggle_mode = true
	_adjust.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_adjust.toggled.connect(_on_adjust_toggled)
	_adjust_controls = VBoxContainer.new()
	_adjust_controls.name = "AdjustControls"
	_adjust_controls.visible = false
	stack.add_child(_adjust_controls)
	var numeric := HBoxContainer.new()
	numeric.add_theme_constant_override("separation", 8)
	_adjust_controls.add_child(numeric)
	_spin(numeric, "Rotation °", "rotation_degrees", -36000.0, 36000.0, 0.01)
	_spin(numeric, "Height m", "height_offset", -1000.0, 1000.0, 0.01)
	_spin(numeric, "Grid m", "grid_size", 0.001, 1000.0, 0.001)
	var toggles := HBoxContainer.new()
	_adjust_controls.add_child(toggles)
	_check(toggles, "Snap to grid", "grid_snap")
	_check(toggles, "Align to surface", "surface_align")
	var history := HBoxContainer.new()
	stack.add_child(history)
	_action_button(history, "Undo", "undo")
	_action_button(history, "Redo", "redo")
	_action_button(history, "Save layout", "save")
	var session := HBoxContainer.new()
	stack.add_child(session)
	_action_button(session, "Reload layout", "reload")
	_action_button(session, "Exit Creator Mode", "exit")
	_status = _label(stack, "", MUTED, 14)
	_status.name = "Status"
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	_status.custom_minimum_size.y = 36
	_strip = PanelContainer.new()
	_strip.name = "AimStrip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_strip.offset_left = -412
	_strip.offset_right = -12
	_strip.offset_top = 12
	_strip.add_theme_stylebox_override("panel", _box(Color("#101e22e8"), Color("#53746c"), 10))
	_root.add_child(_strip)
	var strip_stack := VBoxContainer.new()
	strip_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(strip_stack)
	_strip_text = _label(strip_stack, "", PAPER, 15)
	_strip_text.max_lines_visible = 2
	_strip_status = _label(strip_stack, "", MUTED, 14)
	_strip_status.max_lines_visible = 1
	_fit_width()

func _fit_width() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_strip):
		return
	var width := clampf(_root.size.x * 0.32, 360.0, 440.0)
	_panel.offset_left = -12.0 - width
	_strip.offset_left = -12.0 - minf(width, 410.0)

func _on_adjust_toggled(opened: bool) -> void:
	_adjust_open = opened
	_adjust_controls.visible = opened
	_adjust.text = "Adjust ▾" if opened else "Adjust ▸"

func _apply_state() -> void:
	_syncing = true
	var active := bool(_state.active)
	var opened := bool(_state.menu_open)
	var busy := bool(_state.busy)
	var holding := str(_state.interaction_mode) == "holding"
	_root.visible = active
	_panel.visible = active and opened
	_strip.visible = active and not opened
	if not active or not opened:
		var owner := _root.get_viewport().gui_get_focus_owner()
		if owner != null and _root.is_ancestor_of(owner):
			owner.release_focus()
	_layout_label.text = "%s  ·  %s" % [str(_state.layout_name), "Working…" if busy else "Unsaved changes" if _state.dirty else "No unsaved changes"]
	_layout_label.tooltip_text = _layout_label.text
	_layout_label.modulate = AMBER if _state.dirty else MUTED
	var selected_id := str(_state.selected_asset_id)
	var record: Dictionary = _by_id.get(selected_id, {})
	var selected_name := str(record.get("name", _state.selected_asset_name))
	if selected_name.is_empty():
		selected_name = selected_id if not selected_id.is_empty() else "None selected"
	_selected.text = ("Holding  /  " + _held_name()) if holding else "Selected  /  " + selected_name
	_selected.tooltip_text = _held_name() if holding else selected_name
	var placement_reason := _placement_explanation(record, selected_id)
	_eligibility.text = placement_reason
	_eligibility.tooltip_text = placement_reason
	_eligibility.modulate = MINT if _can_place(record) else AMBER
	var target_name := str(_state.target_name)
	_target.text = "Aimed  /  " + (target_name if not target_name.is_empty() else "No object")
	_target.tooltip_text = _target.text
	var target_reason := str(_state.target_reason)
	if target_reason.is_empty():
		target_reason = "Editable object" if _state.target_editable else "Aim at an editable object to remove it."
	if not _can_change_catalog():
		target_reason = "Place or cancel the held object before choosing another asset."
	_target_reason.text = target_reason
	_target_reason.tooltip_text = target_reason
	var preview_active := str(_state.interaction_mode) in ["holding", "new_preview"]
	var can_preview := not record.is_empty() and bool(record.get("placeable", false)) and _can_change_catalog()
	_buttons.place.visible = preview_active or can_preview
	_buttons.place.disabled = not _can_place(record) if preview_active else busy or not can_preview
	_buttons.place.text = _place_label() if preview_active else "Preview selected"
	_buttons.pick_up.visible = not preview_active
	_buttons.cancel_placement.visible = preview_active or bool(_state.can_cancel_placement)
	_buttons.pick_up.disabled = busy or preview_active or not _state.can_pick_up
	_buttons.cancel_placement.disabled = busy or not _state.can_cancel_placement
	_buttons.remove.disabled = busy or holding or not _state.target_editable
	_buttons.undo.disabled = busy or not _state.can_undo
	_buttons.redo.disabled = busy or not _state.can_redo
	for key: String in ["save", "reload", "exit", "close_menu"]:
		_buttons[key].disabled = busy
	_adjust.disabled = busy
	_buttons.reload.text = "Reload layout…" if _state.dirty else "Reload layout"
	_buttons.exit.text = "Exit Creator Mode…" if _state.dirty else "Exit Creator Mode"
	_buttons.reload.tooltip_text = "Request reload. The controller must offer discard or cancel for unsaved changes." if _state.dirty else "Request reload of the saved layout."
	_buttons.exit.tooltip_text = "Request exit. The controller must offer discard or cancel for unsaved changes." if _state.dirty else "Request exit from Creator Mode."
	for key: String in _settings:
		var control: Control = _settings[key]
		if control is SpinBox:
			# Reapplying an unchanged value resets native in-progress text (e.g. "2.").
			if not is_equal_approx(control.value, float(_state[key])):
				control.set_value_no_signal(float(_state[key]))
			control.editable = not busy
			control.get_line_edit().focus_mode = Control.FOCUS_NONE if busy else Control.FOCUS_ALL
		elif control is CheckBox:
			control.set_pressed_no_signal(bool(_state[key]))
			control.disabled = busy
	_settings.grid_size.editable = not busy and bool(_state.grid_snap)
	_settings.grid_size.get_line_edit().focus_mode = Control.FOCUS_ALL if _settings.grid_size.editable else Control.FOCUS_NONE
	_sync_list_selection()
	var status_text := str(_state.status_text)
	if status_text.is_empty():
		if holding:
			status_text = "Place here to finish the move, or cancel to return it."
		elif str(_state.interaction_mode) == "new_preview":
			status_text = "Place one object, or cancel the preview."
		else:
			status_text = "Unsaved changes. Reload or exit requires confirmation." if _state.dirty else "Select an asset, then aim in the world to place it."
	var severity := str(_state.status_severity)
	var status_color := _severity_color(severity)
	_status.text = _severity_prefix(severity) + status_text
	_status.tooltip_text = _status.text
	_status.modulate = status_color
	var hints := _compact_hints(record)
	var context_name := "Holding / " + _held_name() if holding else "Place / " + selected_name if str(_state.interaction_mode) == "new_preview" else "Aimed / " + target_name if not target_name.is_empty() else "Creator / " + selected_name if not selected_id.is_empty() else "Creator / Aim at an object"
	_strip_text.text = "%s%s\n%s" % [context_name, " · Unsaved" if _state.dirty else "", " · ".join(hints)]
	_strip_text.tooltip_text = "" # This strip never owns pointer or keyboard input.
	_strip_status.text = _compact_status()
	if _strip_status.text.is_empty() and (holding or str(_state.interaction_mode) == "new_preview") and not _state.placement_valid:
		_strip_status.text = "Cannot place here. Find a clear surface."
	_strip_status.visible = not _strip_status.text.is_empty()
	_strip_status.modulate = status_color
	_syncing = false

func _can_place(record: Dictionary) -> bool:
	if str(_state.interaction_mode) == "holding":
		return not bool(_state.busy) and bool(_state.placement_valid)
	return not bool(_state.busy) and not record.is_empty() and bool(record.get("placeable", false)) and bool(_state.placement_valid)

func _placement_explanation(record: Dictionary, selected_id: String) -> String:
	if str(_state.interaction_mode) == "holding":
		if _state.busy: return "Waiting for the current operation."
		if not _state.placement_valid:
			return str(_state.placement_reason) if not str(_state.placement_reason).is_empty() else "Find a clear surface for the held object."
		return "Place the held object here, or cancel to return it."
	if selected_id.is_empty():
		return "Choose a name from the asset catalog."
	if record.is_empty():
		return "Selected asset is no longer in the supplied catalog."
	if not bool(record.get("placeable", false)):
		var reason := str(record.get("reason", ""))
		return reason if not reason.is_empty() else "This catalog entry cannot be placed."
	if _state.busy:
		return "Waiting for the current operation."
	if str(_state.interaction_mode) == "browse":
		return "Preview selected to position this object."
	if not _state.placement_valid:
		var reason := str(_state.placement_reason)
		return reason if not reason.is_empty() else "Aim at a valid placement surface."
	return "Ready to place at the preview."

func _rebuild_categories() -> void:
	_categories.clear()
	_categories.add_item("All categories")
	_categories.set_item_metadata(0, "")
	var names: Array[String] = []
	for record: Dictionary in _catalog:
		var category := str(record.get("category", ""))
		if not category.is_empty() and not names.has(category):
			names.append(category)
	# Keep an absent filter selected so a refresh cannot silently broaden a query.
	if not _category.is_empty() and not names.has(_category):
		names.append(_category)
	names.sort()
	for category: String in names:
		_categories.add_item(category)
		var index := _categories.item_count - 1
		_categories.set_item_metadata(index, category)
		if category == _category:
			_categories.select(index)

func _rebuild_list(scroll_value: float) -> void:
	_revision += 1
	_list.clear()
	var name_counts: Dictionary = {}
	for record: Dictionary in _catalog:
		var friendly := str(record.get("name", record.get("id", "Unnamed asset")))
		name_counts[friendly] = int(name_counts.get(friendly, 0)) + 1
	var total_unavailable := 0
	for record: Dictionary in _catalog:
		var friendly := str(record.get("name", record.get("id", "Unnamed asset")))
		var category := str(record.get("category", ""))
		if not bool(record.get("placeable", false)):
			total_unavailable += 1
			if not _include_unavailable:
				continue
		if not _category.is_empty() and category != _category:
			continue
		if not _query.is_empty() and not (friendly + " " + category).to_lower().contains(_query.to_lower()):
			continue
		var label := friendly
		if int(name_counts[friendly]) > 1:
			label += "  ·  " + category
			var variant := str(record.get("variant_group", ""))
			if not variant.is_empty():
				label += " / " + variant
		if not bool(record.get("placeable", false)):
			label += "  ·  Unavailable"
		var index := _list.add_item(label)
		_list.set_item_metadata(index, str(record.get("id", "")))
		var tooltip := friendly + "\n" + category
		if not bool(record.get("placeable", false)):
			tooltip += "\n" + str(record.get("reason", "This entry cannot be placed."))
			_list.set_item_custom_fg_color(index, MUTED)
		if not str(record.get("source_path", "")).is_empty():
			tooltip += "\n" + str(record.source_path)
		tooltip += "\nAsset ID: " + str(record.get("id", ""))
		_list.set_item_tooltip(index, tooltip)
	_count.text = "%d of %d %s" % [_list.item_count, _catalog.size() if _include_unavailable else _catalog.size() - total_unavailable, "entries" if _include_unavailable else "objects"]
	_count.tooltip_text = "%d matching; %d total records, %d unavailable." % [_list.item_count, _catalog.size(), total_unavailable]
	_show_unavailable.tooltip_text = "Include all %d catalog records, including %d unavailable entries with reasons." % [_catalog.size(), total_unavailable]
	_empty.text = "No assets match. Try another name or category." if _include_unavailable else "No placeable objects match.\nTry another search or Show unavailable."
	_empty.visible = _list.item_count == 0
	_sync_list_selection()
	_restore_scroll.call_deferred(scroll_value, _revision)

func _restore_scroll(value: float, revision: int) -> void:
	if revision != _revision or not is_inside_tree():
		return
	_list.get_v_scroll_bar().value = value

func _sync_list_selection() -> void:
	_list.deselect_all()
	for index: int in range(_list.item_count):
		if str(_list.get_item_metadata(index)) == str(_state.selected_asset_id):
			_list.select(index)
			break

func _on_search_changed(value: String) -> void:
	_query = value.strip_edges()
	_rebuild_list(0.0)

func _on_category_changed(index: int) -> void:
	_category = str(_categories.get_item_metadata(index))
	_rebuild_list(0.0)

func _on_availability_toggled(include: bool) -> void:
	_include_unavailable = include
	_rebuild_list(_list.get_v_scroll_bar().value)

func _on_item_selected(index: int) -> void:
	if _syncing or _state.busy or not _can_change_catalog():
		_sync_list_selection()
		return
	# Selection stays controller-authoritative; synchronous controllers may echo state.
	asset_selected.emit(str(_list.get_item_metadata(index)))
	_sync_list_selection()

func _request(action: String) -> void:
	if not _state.active or not _state.menu_open or _state.busy or _buttons[action].disabled:
		return
	if action == "place" and str(_state.interaction_mode) == "browse":
		asset_selected.emit(str(_state.selected_asset_id))
		return
	action_requested.emit(action)

func _binding(action: String, fallback: String) -> String:
	var bindings: Dictionary = _state.bindings
	var value := str(bindings.get(action, ""))
	return fallback + (" [" + value + "]" if not value.is_empty() else "")

func _place_label() -> String:
	if not str(_state.primary_action_label).is_empty():
		return str(_state.primary_action_label)
	return "Place here" if str(_state.interaction_mode) in ["holding", "new_preview"] else "Place at preview"

func _held_name() -> String:
	return str(_state.held_object_name) if not str(_state.held_object_name).is_empty() else "Existing object"

func _can_change_catalog() -> bool:
	return bool(_state.can_change_asset) and str(_state.interaction_mode) != "holding"

func _compact_hints(record: Dictionary) -> Array[String]:
	var hints: Array[String] = []
	if _state.busy:
		return ["Working…"]
	var mode := str(_state.interaction_mode)
	if mode in ["holding", "new_preview"]:
		var primary := str(_state.primary_action_hint)
		if primary.is_empty() or primary.to_lower() in ["left-click: place", "left click: place", "lmb: place"]:
			primary = _binding("place", "Place")
		hints.append(primary)
		var bindings: Dictionary = _state.bindings
		# Wheel rotation is part of the v2 flow even for controllers omitting its label.
		hints.append(_binding("rotate", "Rotate") if bindings.has("rotate") else "Rotate [Wheel]")
		if _state.can_cancel_placement:
			hints.append(_binding("cancel_placement", "Cancel").replace(" / ", "/"))
		elif _can_change_catalog():
			hints.append(_binding("menu", "Assets"))
	else:
		if _state.can_pick_up:
			hints.append(_binding("pick_up", "Pick up"))
		if _state.target_editable:
			hints.append(_binding("remove", "Remove"))
		if _can_change_catalog():
			hints.append(_binding("menu", "Assets"))
	return hints.slice(0, 3)

func _compact_status() -> String:
	var message := str(_state.status_text)
	var severity := str(_state.status_severity)
	if severity == "info" and str(_state.interaction_mode) in ["holding", "new_preview"]:
		var normalized := message.to_lower().strip_edges()
		var is_instruction := normalized.contains("place") and normalized.contains("cancel")
		var is_problem := normalized.contains("cannot") or normalized.contains("could not") or normalized.contains("fail") or normalized.contains("before") or normalized.contains("error")
		if (is_instruction and not is_problem) or normalized == str(_state.primary_action_hint).to_lower().strip_edges():
			return ""
	return _severity_prefix(severity) + message if not message.is_empty() else ""

func _label(parent: Node, text: String, color: Color = PAPER, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size.y = 30
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(button)
	return button

func _action_button(parent: Node, text: String, action: String) -> void:
	var button := _button(parent, text)
	button.name = action.capitalize().replace(" ", "")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_request.bind(action))
	_buttons[action] = button

func _spin(parent: Node, caption: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 0)
	parent.add_child(column)
	_label(column, caption, MUTED, 13)
	var spin := SpinBox.new()
	spin.name = key.to_pascal_case()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = key != "grid_size"
	spin.custom_minimum_size = Vector2(0, 28)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(spin)
	spin.value_changed.connect(func(value: float) -> void:
		if not _syncing and not _state.busy:
			settings_changed.emit({key: value})
	)
	_settings[key] = spin

func _check(parent: Node, caption: String, key: String) -> void:
	var check := CheckBox.new()
	check.name = key.to_pascal_case()
	check.text = caption
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(check)
	check.toggled.connect(func(value: bool) -> void:
		if not _syncing and not _state.busy:
			settings_changed.emit({key: value})
	)
	_settings[key] = check

func _severity_color(severity: String) -> Color:
	match severity:
		"success": return MINT
		"warning": return AMBER
		"error": return ALERT
	return MUTED

func _severity_prefix(severity: String) -> String:
	match severity:
		"success": return "OK / "
		"warning": return "Notice / "
		"error": return "Error / "
	return ""

func _box(fill: Color, edge: Color, padding: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	style.set_corner_radius_all(3)
	return style

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	for type: String in ["Button", "OptionButton", "CheckBox", "LineEdit", "ItemList"]:
		theme.set_color("font_color", type, PAPER)
		theme.set_color("font_disabled_color", type, Color("#7c8d8f"))
		theme.set_stylebox("focus", type, _box(Color("#213c3d"), MINT))
	for type: String in ["Button", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			theme.set_stylebox(state, type, _box(Color("#294443") if state == "hover" else Color("#192b2d"), Color("#385350") if state == "disabled" else Color("#53746c")))
	for type: String in ["LineEdit", "ItemList"]:
		theme.set_stylebox("normal" if type == "LineEdit" else "panel", type, _box(Color("#0b171b"), Color("#385350")))
	theme.set_stylebox("selected", "ItemList", _box(Color("#254641"), MINT))
	theme.set_stylebox("selected_focus", "ItemList", _box(Color("#254641"), MINT))
	theme.set_constant("v_separation", "ItemList", 7)
	return theme
