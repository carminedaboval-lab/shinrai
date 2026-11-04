extends RefCounted

# Shared typography and small motion helpers for Shinrai's code-built UI.
# Bahnschrift ships with Windows 10/11 and gives a clean DIN-style tactical
# look without bundling a font; other systems fall back in order.

const FONT_NAMES := ["Bahnschrift", "DIN Alternate", "Segoe UI", "Arial"]

static var _body: Font
static var _heading: Font

static func body_font() -> Font:
	if _body == null:
		_body = _system_font(400)
	return _body

static func heading_font() -> Font:
	if _heading == null:
		_heading = _system_font(600)
	return _heading

static func apply_fonts(theme: Theme) -> void:
	theme.default_font = body_font()
	theme.set_font("font", "Button", heading_font())

static func heading(label: Label, size: int = 34) -> Label:
	label.add_theme_font_override("font", heading_font())
	label.add_theme_font_size_override("font_size", size)
	return label

static func reveal(control: Control, owner: Node, offset: float = 18.0, time: float = 0.22) -> Tween:
	# Fade in while rising slightly; the final position is the layout position.
	var settled := control.position
	control.modulate.a = 0.0
	control.position = settled + Vector2(0.0, offset)
	var tween := owner.create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", settled, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween

static func animate_button(button: Button) -> void:
	# A small scale lift on hover/focus and a dip on press.
	var keep_pivot := func() -> void: button.pivot_offset = button.size * 0.5
	button.resized.connect(keep_pivot)
	keep_pivot.call()
	var to_scale := func(value: float, time: float) -> void:
		if not button.is_inside_tree():
			return
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(value, value), time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button.mouse_entered.connect(func() -> void: if not button.disabled: to_scale.call(1.035, 0.12))
	button.focus_entered.connect(func() -> void: if not button.disabled: to_scale.call(1.035, 0.12))
	button.mouse_exited.connect(func() -> void: to_scale.call(1.0, 0.14))
	button.focus_exited.connect(func() -> void: to_scale.call(1.0, 0.14))
	button.button_down.connect(func() -> void: to_scale.call(0.97, 0.06))
	button.button_up.connect(func() -> void: to_scale.call(1.035 if button.is_hovered() else 1.0, 0.1))

static func _system_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = weight
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font
