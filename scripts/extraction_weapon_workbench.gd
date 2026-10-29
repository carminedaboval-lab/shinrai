extends VBoxContainer
signal closed
signal exit_requested
const Catalog = preload("res://scripts/extraction_weapon_catalog.gd")
const State = preload("res://scripts/extraction_weapon_state.gd")
const Slot = preload("res://scripts/extraction_optic_slot.gd")
const Preview = preload("res://scripts/extraction_loadout_preview.gd")
const PAPER := Color("#eeeeee")
const MUTED := Color("#c3c3c3")
const MINT := Color("#c6d7d2")
const AMBER := Color("#ddd4bd")
var raid: Node
var selected_weapon := "shigure"
var selected_optic := ""
var feedback := ""
var _focus_controls: Dictionary = {}
var _focus_order: Array[String] = []
var _focus_generation := 0
var _pending_focus_key := ""
var _pending_focus_generation := -1

func configure(source: Node) -> void:
	raid = source
	custom_minimum_size = Vector2(1720, 650)
	add_theme_constant_override("separation", 18)
	_rebuild()

func _label(parent: Node, text: String, size: int = 22, colour: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color("#050807b8"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 1)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, focus_key: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	_style_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	_register_focus(button, focus_key)
	return button

func _rebuild() -> void:
	var previous_focus := _focused_key()
	_focus_generation += 1
	_focus_controls.clear()
	_focus_order.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var state: Dictionary = _loadout()
	var revision := int(state.revision)
	if not state.weapons.has(selected_weapon): selected_weapon = str(state.equipped)
	var top := HBoxContainer.new()
	add_child(top)
	_label(top, "WEAPONS / OPTIC BENCH", 34).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "BACK TO CARGO", func() -> void: closed.emit(), "back")
	_button(top, "CLOSE INVENTORY", func() -> void: exit_requested.emit(), "close")
	_label(self, "Drag an optic to another slot, or select it and click its destination. Occupied slots exchange attachments.", 20, MUTED)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	add_child(columns)
	var gun_scroll := ScrollContainer.new()
	gun_scroll.custom_minimum_size = Vector2(440,480)
	gun_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(gun_scroll)
	var guns := VBoxContainer.new()
	guns.custom_minimum_size.x = 420
	guns.add_theme_constant_override("separation", 12)
	gun_scroll.add_child(guns)
	_section(guns, "WEAPONS")
	for id: String in state.weapons:
		var gun_id := id
		var status := "EQUIPPED" if state.equipped == id else ("AVAILABLE" if Catalog.available(id) else "MODEL PENDING")
		var weapon_button := _button(guns, "%s    /    %s" % [Catalog.WEAPONS[id].title, status], func() -> void: selected_weapon = gun_id; selected_optic = ""; _rebuild(), "weapon:" + gun_id)
		_style_button(weapon_button, id == selected_weapon)
		if not str(Catalog.WEAPONS[id].optic_mount).is_empty():
			_slot(guns, str(state.weapons[id].optic), id, revision)
	var tray := VBoxContainer.new()
	tray.custom_minimum_size.x = 340
	tray.add_theme_constant_override("separation", 12)
	columns.add_child(tray)
	_section(tray, "LOOSE OPTICS")
	_slot(tray, "", "tray", revision)
	for id: String in state.loose_optics:
		_slot(tray, id, "tray", revision)
	var selected := _label(tray, "SELECTED\n" + (Catalog.OPTICS[selected_optic].title if Catalog.OPTICS.has(selected_optic) else "Select an optic to move it"), 20, AMBER)
	selected.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	columns.add_child(details)
	if state.weapons.is_empty():
		_label(details,"NO WEAPON FOUND",30)
		_label(details,"Search security supply cases. Extract with recovered gear to keep it.",20,MUTED)
		call_deferred("_restore_focus",previous_focus,_focus_generation)
		return
	var record: Dictionary = state.weapons[selected_weapon]
	var spec := Catalog.effective(selected_weapon, str(record.optic))
	_label(details, spec.title, 30)
	if ResourceLoader.exists(str(Catalog.WEAPONS[selected_weapon].scene).replace("_viewmodel.tscn", "_weapon.tscn")) or selected_weapon == "uzi":
		var preview := Preview.new()
		preview.workbench_presentation = true
		preview.custom_minimum_size = Vector2(480,300)
		preview.set_loadout(selected_weapon, str(record.optic))
		var preview_panel := PanelContainer.new()
		preview_panel.add_theme_stylebox_override("panel", _style(Color("#11181755"), Color("#bec9c426"), 10))
		details.add_child(preview_panel)
		preview_panel.add_child(preview)
		_label(details, "DRAG TO ROTATE  ·  SCROLL TO ZOOM  ·  DOUBLE-CLICK TO RESET", 15, MUTED)
	_label(details, spec.ammo_type + "   ·   " + ("AUTOMATIC" if spec.mode == "auto" else "BOLT ACTION" if spec.mode == "bolt" else "SEMI-AUTOMATIC"), 20, MINT)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 30)
	stats.add_theme_constant_override("v_separation", 7)
	details.add_child(stats)
	_stat(stats, "STORED AMMO", "%d / %d" % [record.ammo, record.reserve])
	_stat(stats, "MAGAZINE", "%d rounds" % spec.magazine)
	_stat(stats, "RATE / DAMAGE", "%d RPM  /  %s" % [roundi(spec.rpm), ("%.0f" % spec.damage_min) if is_equal_approx(spec.damage_min, spec.damage_max) else ("%.0f–%.0f" % [spec.damage_min, spec.damage_max])])
	_stat(stats, "RELOAD", "%.1fs partial  /  %.1fs empty" % [spec.reload_partial, spec.reload_empty])
	_stat(stats, "AIM / RECOIL", "%.0f° FOV  /  %.2f°" % [spec.ads_fov, spec.recoil_ads])
	if not Catalog.available(selected_weapon):
		var pending := _label(details, "3D model and animation fitting pending.\nStats are provisional game balance.\nOptics can be arranged here before assembly.", 20, AMBER)
		pending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var equip := _button(details, "EQUIPPED" if state.equipped == selected_weapon else "EQUIP WEAPON", func() -> void: _equip(), "equip")
		equip.disabled = state.equipped == selected_weapon
		if not equip.disabled:
			equip.add_theme_stylebox_override("normal", _style(Color("#d9d9d9e8"), Color.TRANSPARENT, 10))
			equip.add_theme_color_override("font_color", Color("#171b1d"))
	var save_error := str(raid.profile.last_error)
	var message_text := save_error if not save_error.is_empty() else feedback if not feedback.is_empty() else "Reflex/prism fit railed weapons. Kasumi scope fits Hayate and Yuzuru. Ammunition stays with its weapon."
	var message := _label(self, message_text, 20, AMBER if not save_error.is_empty() else MINT)
	message.name = "WorkbenchFeedback"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	call_deferred("_restore_focus", previous_focus, _focus_generation)

func _slot(parent: Node, optic_id: String, target: String, revision: int) -> void:
	var slot := Slot.new()
	slot.optic_id = optic_id
	slot.target = target
	slot.revision = revision
	slot.text = Catalog.OPTICS[optic_id].title if not optic_id.is_empty() else ("DROP / REMOVE TO TRAY" if target == "tray" else "EMPTY OPTIC SLOT")
	slot.custom_minimum_size.y = 54
	slot.add_theme_font_size_override("font_size", 20)
	_style_button(slot, not optic_id.is_empty() and optic_id == selected_optic)
	slot.tooltip_text = "Drag this optic or click to select it; click another slot to exchange."
	slot.optic_clicked.connect(_clicked)
	slot.optic_dropped.connect(_move)
	parent.add_child(slot)
	_register_focus(slot, "slot:" + target + (":" + optic_id if target == "tray" else ""))

func _style(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	return style

func _style_button(button: Button, selected: bool = false) -> void:
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(Color("#94949470") if selected else Color("#16161666"), MINT if selected else Color("#b8c3bf36"), 10))
	button.add_theme_stylebox_override("hover", _style(Color("#93aaa480"), MINT, 10))
	button.add_theme_stylebox_override("pressed", _style(Color("#aec5bc99"), PAPER, 10))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, PAPER, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("#16161655"), Color("#b8c3bf36"), 10))

func _section(parent: Node, title: String) -> void:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", _style(Color("#aeb8b48c"), Color("#d1d9d32b"), 7))
	parent.add_child(band)
	var heading := _label(band, title, 20, Color("#101613"))
	heading.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _stat(parent: Node, title: String, value: String) -> void:
	_label(parent, title, 18, MUTED)
	_label(parent, value, 22)

func _register_focus(control: Control, key: String) -> void:
	if key.is_empty(): return
	control.set_meta("workbench_focus_key", key)
	_focus_controls[key] = control
	_focus_order.append(key)

func _focused_key() -> String:
	if not is_inside_tree(): return ""
	var focused := get_viewport().gui_get_focus_owner()
	if not is_instance_valid(focused) or not is_ancestor_of(focused): return ""
	return str(focused.get_meta("workbench_focus_key", ""))

func _restore_focus(key: String, generation: int) -> void:
	if generation != _focus_generation or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree(): return
	# A drop can rebuild the bench before Godot finishes the drag operation.
	if get_viewport().gui_is_dragging():
		_pending_focus_key = key
		_pending_focus_generation = generation
		return
	_pending_focus_generation = -1
	var choices: Array[String] = []
	if not key.is_empty():
		choices.append(key)
		# A moved optic can leave its old tray slot; an equipped button disables.
		choices.append("weapon:" + selected_weapon)
	choices.append_array(_focus_order)
	for choice: String in choices:
		var control := _focus_controls.get(choice) as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE: continue
		if control is BaseButton and control.disabled: continue
		control.grab_focus()
		return

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _pending_focus_generation == _focus_generation:
		call_deferred("_restore_focus", _pending_focus_key, _pending_focus_generation)

func _clicked(optic_id: String, target: String) -> void:
	if selected_optic.is_empty():
		selected_optic = optic_id
		_rebuild()
	else:
		_move(selected_optic, target, int(_loadout().revision))

func _move(optic_id: String, target: String, revision: int) -> void:
	var moved: bool = raid.move_weapon_optic(optic_id, target, revision)
	feedback = "Optic moved. Equipment and ammunition saved." if moved else "Move rejected. Re-select the optic, or check the save status."
	selected_optic = ""
	_rebuild()

func _equip() -> void:
	var equipped: bool = raid.equip_weapon(selected_weapon, int(_loadout().revision))
	feedback = "Weapon equipped. Its ammunition is preserved." if equipped else "Weapon unavailable or equipment change blocked."
	_rebuild()

func _loadout() -> Dictionary:
	return raid.active_weapon_loadout() if raid.has_method("active_weapon_loadout") else raid.profile.data.loadout
