extends VBoxContainer
## Inventory Health tab; all transactions are validated by extraction_run.
const Medical = preload("./extraction_medical.gd")
const Art = preload("res://scripts/extraction_item_art.gd")
const PAPER := Color("e2e9e5")
const MUTED := Color("a0ada7")
const GREEN := Color("9ed5b3")
const ALERT := Color("f09b87")
var raid: Node
var selected_part := "thorax"
var part_buttons: Dictionary = {}
var treatment_buttons: Dictionary = {}
var state: RefCounted
var in_hq := false
var treatment_feedback: Label

func configure(controller: Node) -> void:
	raid = controller
	in_hq = raid.phase == raid.Phase.HQ
	state = Medical.new() if in_hq else raid.player.medical
	custom_minimum_size.x = 320
	add_theme_constant_override("separation", 6)
	_label("BODY CONDITION", 23, PAPER)
	_label("BODY HEALTH  %.1f / %.1f" % [state.total_hp(), Medical.TOTAL_HP], 20, GREEN)
	_label("HP %.1f / %.1f  ·  BLOOD %.1f%%" % [state.effective_hp(),Medical.TOTAL_HP,state.blood],17,PAPER)
	_label("Next deployment" if in_hq else state.summary(), 14, MUTED if in_hq else ALERT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for part: String in Medical.PARTS:
		var button := Button.new()
		button.name = "Body_" + part
		button.custom_minimum_size.y = 48
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(func() -> void: selected_part = part; _refresh())
		add_child(button)
		part_buttons[part] = button
	_label("TREAT SELECTED PART", 17, PAPER)
	treatment_feedback = _label("", 14, ALERT)
	treatment_feedback.name = "TreatmentFeedback"
	treatment_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for item: String in ["bandage", "tourniquet", "splint", "medkit"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		if item != "medkit":
			var art := Art.new()
			art.item_id = item
			art.custom_minimum_size = Vector2(58, 52)
			row.add_child(art)
		var button := Button.new()
		button.name = "Treat_" + item
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.tooltip_text = str(Medical.TREATMENTS[item].effect)
		button.pressed.connect(func() -> void: _request_treatment(item))
		row.add_child(button)
		treatment_buttons[item] = button
	_label("Select a part, then a treatment. Applying returns to the raid; damage or firing cancels.", 14, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("Pouch: 2 bandages, 1 tourniquet, 1 splint per deployment. Recovered supplies also count. Destroyed parts cannot be healed by a medkit.", 13, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh()

func _request_treatment(item: String) -> void:
	if not is_instance_valid(raid): return
	# A successful request resumes the raid and removes this inventory panel.
	if raid.request_treatment(item, selected_part): return
	if not is_instance_valid(self) or is_queued_for_deletion() or not is_inside_tree(): return
	_refresh()
	var reason: String = raid.treatment_request_block_reason(item, selected_part)
	_show_treatment_feedback(reason if not reason.is_empty() else "Treatment could not start. Reopen Health and try again.")

func _show_treatment_feedback(reason: String) -> void:
	treatment_feedback.text = reason
	treatment_feedback.visible = not reason.is_empty()

func _refresh() -> void:
	for part: String in part_buttons:
		var button: Button = part_buttons[part]
		button.text = "%s  %.1f / %.1f\n%s" % [Medical.LABELS[part], float(state.hp[part]), float(Medical.MAX_HP[part]), state.part_status(part)]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("2b423780") if part == selected_part else Color("18212366")
		style.border_color = GREEN if part == selected_part else Color("3e4d48")
		style.set_border_width_all(1)
		style.content_margin_left = 10
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", ALERT if state.part_status(part) != "HEALTHY" else PAPER)
	var blocked_reason := ""
	for item: String in treatment_buttons:
		var button: Button = treatment_buttons[item]
		var count := 0
		if in_hq:
			count = (2 if raid.profile.data.prepared_medkit else 1) if item == "medkit" else (2 if item == "bandage" else 1)
		else:
			count = raid.medical_count(item)
		button.text = "%s x%d  /  %.1fs\n%s" % [Medical.TREATMENTS[item].title, count, Medical.TREATMENTS[item].seconds, Medical.TREATMENTS[item].effect]
		var reason: String = raid.treatment_request_block_reason(item, selected_part)
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason.get_slice("\n", 0) if not reason.is_empty() else str(Medical.TREATMENTS[item].effect)
		if not in_hq and count > 0 and state.can_treat(item, selected_part) and not reason.is_empty():
			blocked_reason = reason
	_show_treatment_feedback(blocked_reason)

func _label(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.95))
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label
