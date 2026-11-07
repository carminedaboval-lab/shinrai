extends Control
## Selectable body regions in the inventory. Each region uses the same medical
## state as the treatment inspector. The raid HUD supplies a fallback scan.
signal part_selected(part: String)

const Medical = preload("res://scripts/extraction_medical.gd")
const UIStyle = preload("res://scripts/hud/shinrai_ui_style.gd")
const SCAN_PATH := "res://assets/ui/inventory/medical_scan.png"
const MINT := Color("83f0d1")
const WOUNDED := Color("ffb376")
const CRITICAL := Color("ff776d")
const LABEL := Color("b9c9c8")
const FOOTER := 65.0
const CARD_HEIGHT := 49.0
# Landmark coordinates in the original 1024 × 1536 scan.
# The subject faces the viewer, so its right limbs are on the viewer's left.
const ART_SIZE := Vector2(1024, 1536)
const ART_CROP := Rect2(150, 0, 724, 1536)
const ANCHORS := {
	"head": Vector2(515, 102), "thorax": Vector2(550, 355),
	"stomach": Vector2(504, 554),
	"right_arm": Vector2(297, 533), "left_arm": Vector2(713, 533),
	"right_leg": Vector2(410, 1031), "left_leg": Vector2(596, 1031)
}
const CARDS := {
	"head": Vector2(0, 0.06), "thorax": Vector2(1, 0.19),
	"right_arm": Vector2(0, 0.345), "left_arm": Vector2(1, 0.345),
	"stomach": Vector2(0, 0.51), "right_leg": Vector2(0, 0.765), "left_leg": Vector2(1, 0.765)
}
# Polygons select the affected bones in the same illustration. The texture's
# alpha clips the colour wash to the figure, including the gaps between bones.
const HEAD_ZONE := [Vector2(400, 0), Vector2(620, 0), Vector2(585, 185), Vector2(554, 210), Vector2(477, 195), Vector2(433, 166)]
const CHEST_ZONE := [Vector2(345, 268), Vector2(455, 215), Vector2(477, 195), Vector2(554, 210), Vector2(674, 267), Vector2(642, 325), Vector2(641, 487), Vector2(612, 544), Vector2(543, 502), Vector2(476, 502), Vector2(403, 544), Vector2(374, 487), Vector2(378, 325)]
const ABDOMEN_ZONE := [Vector2(374, 487), Vector2(403, 544), Vector2(476, 502), Vector2(543, 502), Vector2(612, 544), Vector2(641, 487), Vector2(664, 707), Vector2(628, 705), Vector2(570, 754), Vector2(549, 792), Vector2(464, 792), Vector2(442, 755), Vector2(389, 707), Vector2(353, 707)]
const ARM_ZONE := [Vector2(150, 266), Vector2(340, 264), Vector2(378, 294), Vector2(378, 337), Vector2(351, 486), Vector2(327, 597), Vector2(282, 731), Vector2(281, 913), Vector2(150, 913)]
const LEG_ZONE := [Vector2(350, 708), Vector2(388, 707), Vector2(451, 751), Vector2(486, 794), Vector2(500, 866), Vector2(469, 999), Vector2(451, 1204), Vector2(459, 1536), Vector2(291, 1536), Vector2(313, 1005)]

class RegionButton extends Button:
	var caption := ""
	var amount := ""
	var ratio := 1.0
	var tint := MINT
	var wound := ""
	
	func _draw() -> void:
		var inset := 6.0
		var band := Color("344c4d")
		draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(size.x * 0.75, 1), Vector2(size.x * 0.75 - 14, 19), Vector2(1, 19)]), band)
		draw_string(UIStyle.heading_font(), Vector2(inset + 1, 15), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e0ebea"))
		var meter := Rect2(inset, 24, size.x - 2 * inset, 18)
		draw_rect(meter, Color("263b3d"))
		if ratio > 0:
			var filled := Rect2(meter.position, Vector2(meter.size.x * ratio, meter.size.y))
			draw_rect(filled, tint)
			draw_line(filled.position, filled.position + Vector2(filled.size.x, 0), tint.lightened(0.28))
		var text_pos := Vector2(meter.position.x, meter.position.y + 14)
		var color := Color("102322")
		if ratio < 0.78:
			color = Color("effbf7")
			draw_string_outline(UIStyle.heading_font(), text_pos, amount, HORIZONTAL_ALIGNMENT_CENTER, meter.size.x, 14, 4, Color("1a2b2b"))
		draw_string(UIStyle.heading_font(), text_pos, amount, HORIZONTAL_ALIGNMENT_CENTER, meter.size.x, 14, color)
		if not wound.is_empty():
			# A wound is legible independently of the bar colour and stays outside it.
			draw_string_outline(UIStyle.heading_font(), Vector2(1, size.y + 13), wound, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2, 12, 3, Color("0c2020"))
			draw_string(UIStyle.heading_font(), Vector2(1, size.y + 13), wound, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2, 12, tint)

var scan: Control
var illustration: Texture2D
var source_rect: Rect2
var medical: RefCounted
var buttons := {}
var totals: Label
var total_caption: Label
var blood: Label
var blood_caption: Label
var last_values := {}
var last_blood := -1.0

func configure(raid: Node) -> void:
	name = "BodyCondition"
	custom_minimum_size = Vector2(330, 488)
	size_flags_vertical = SIZE_EXPAND_FILL
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE
	var in_hq: bool = raid.phase == raid.Phase.HQ
	medical = Medical.new() if in_hq else raid.player.medical
	if ResourceLoader.exists(SCAN_PATH):
		illustration = load(SCAN_PATH) as Texture2D
	if illustration != null:
		var image_scale := illustration.get_size() / ART_SIZE
		source_rect = Rect2(ART_CROP.position * image_scale, ART_CROP.size * image_scale)
	else:
		scan = raid.hud.body_status
		scan.feed(medical, false)
	for part: String in CARDS:
		var button := RegionButton.new()
		button.name = "Inspect_" + part
		button.caption = str(Medical.LABELS[part]).to_upper()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _box(Color("182d2ee8"), Color("536969")))
		button.add_theme_stylebox_override("hover", _box(Color("31484a"), Color("b6f6e5")))
		button.add_theme_stylebox_override("pressed", _box(Color("324f4e"), MINT))
		button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, MINT, 2))
		button.pressed.connect(func() -> void: part_selected.emit(part))
		add_child(button)
		buttons[part] = button
	totals = _label(22, Color("f0f6f3"))
	totals.mouse_filter = MOUSE_FILTER_PASS
	totals.tooltip_text = "Health across all seven body regions, before the effect of blood loss."
	total_caption = _label(12, LABEL)
	total_caption.text = "DEPLOYMENT HEALTH" if in_hq else "BODY HEALTH"
	blood = _label(19, Color("e4ebe8"))
	blood_caption = _label(12, LABEL)
	blood_caption.text = "BLOOD VOLUME"
	_refresh_medical()
	# Inspectors can reopen without rebuilding the inventory. Keep data current
	# while visible without requesting a canvas redraw every frame.
	var refresh := Timer.new()
	refresh.wait_time = 0.4
	refresh.timeout.connect(_refresh_medical)
	add_child(refresh)
	refresh.start()
	resized.connect(_layout)
	visibility_changed.connect(_refresh_medical)
	_layout()

func _refresh_medical() -> void:
	if not is_visible_in_tree() and not last_values.is_empty(): return
	var changed := false
	for part: String in buttons:
		var hp := float(medical.hp[part])
		var status: String = medical.part_status(part)
		var key := Vector3(hp, int(medical.bleeding[part]), int(bool(medical.fractures[part])))
		if last_values.has(part) and last_values[part] == key: continue
		last_values[part] = key
		var maximum := float(Medical.MAX_HP[part])
		var button: RegionButton = buttons[part]
		button.ratio = clampf(hp / maximum, 0, 1)
		button.tint = MINT if status == "HEALTHY" else WOUNDED
		if hp <= 0 or int(medical.bleeding[part]) >= 2 or button.ratio < 0.35: button.tint = CRITICAL
		button.wound = status if status != "HEALTHY" and status != "INJURED" else ""
		if button.wound.contains(" / "): button.wound = str(button.wound.split(" / ")[0]) + " +"
		button.amount = "%s / %d" % [_amount(hp), int(maximum)]
		button.tooltip_text = "%s · %s" % [Medical.LABELS[part], status]
		button.accessibility_name = "%s, %s of %d, %s" % [Medical.LABELS[part], _amount(hp), int(maximum), status]
		button.queue_redraw()
		changed = true
	if changed:
		totals.text = "%s / %d" % [_amount(medical.total_hp()), int(Medical.TOTAL_HP)]
		if is_instance_valid(scan): scan.feed(medical, false)
		queue_redraw()
	var volume := float(medical.blood)
	if not is_equal_approx(last_blood, volume):
		blood.text = "%s %%" % _amount(volume)
		last_blood = volume

func _amount(value: float) -> String:
	return ("%.1f" % value).trim_suffix(".0")

func _label(points: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UIStyle.heading_font())
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	return box

func _figure_rect() -> Rect2:
	var area := Vector2(size.x - 16, size.y - FOOTER - 12)
	var aspect := source_rect.size.x / source_rect.size.y if source_rect.has_area() else 0.5
	var height := minf(area.y, (area.x * 0.76) / aspect)
	var figure := Vector2(height * aspect, height)
	return Rect2(Vector2((size.x - figure.x) * 0.5, 5 + (area.y - height) * 0.5), figure)

func _layout() -> void:
	var height := size.y - FOOTER
	var card_width := clampf(size.x * 0.205, 88, 127)
	var inset := clampf(size.x * 0.025, 4, 15)
	for part: String in buttons:
		var location: Vector2 = CARDS[part]
		var button: RegionButton = buttons[part]
		var left := location.x == 0
		var x := inset if left else size.x - inset - card_width
		button.position = Vector2(x, clampf(height * location.y - CARD_HEIGHT * 0.5, 3, height - CARD_HEIGHT))
		button.size = Vector2(card_width, CARD_HEIGHT)
	var value_x := 54.0
	var divider := floorf(size.x * 0.56)
	totals.position = Vector2(value_x, height + 7)
	total_caption.position = Vector2(value_x, height + 34)
	blood.position = Vector2(divider + 15, height + 10)
	blood_caption.position = Vector2(divider + 15, height + 34)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(totals): return
	var rect := _figure_rect()
	if illustration != null:
		draw_texture_rect_region(illustration, rect, source_rect)
	elif is_instance_valid(scan):
		draw_texture_rect(scan.scan_texture(), rect, false)
	for part: String in buttons:
		var button: RegionButton = buttons[part]
		if illustration != null and button.tint != MINT:
			_draw_injury(part, rect, button.tint)
	for part: String in buttons:
		var anchor: Vector2 = (Vector2(ANCHORS[part]) - ART_CROP.position) / ART_CROP.size if illustration != null else scan.scan_anchor(part)
		if anchor.x < 0: continue
		var target := rect.position + rect.size * anchor
		var box: Rect2 = buttons[part].get_rect()
		var left: bool = CARDS[part].x == 0
		var start := Vector2(box.end.x if left else box.position.x, box.get_center().y)
		var elbow := Vector2(target.x + (-14 if left else 14), start.y)
		var button: RegionButton = buttons[part]
		var tint := Color("b5cece") if button.tint == MINT else button.tint
		draw_polyline(PackedVector2Array([start, elbow, target]), Color(tint, 0.72), 1.25, true)
		draw_circle(target, 4.0, Color("1b3437"), true, -1, true)
		draw_arc(target, 4.0, 0, TAU, 20, tint, 1.15, true)
		if button.tint != MINT: draw_circle(target, 1.65, tint, true, -1, true)
	var base_y := size.y - FOOTER
	draw_rect(Rect2(0, base_y, size.x, FOOTER), Color("101e20d9"))
	draw_line(Vector2(0, base_y), Vector2(size.x, base_y), Color("5c7372"))
	draw_line(Vector2(floorf(size.x * 0.56), base_y + 8), Vector2(floorf(size.x * 0.56), size.y - 7), Color("334849"))
	var origin := Vector2(12, base_y + 17)
	var heart := PackedVector2Array([Vector2(0, 8), Vector2(6, 1), Vector2(13, 1), Vector2(17, 5), Vector2(21, 1), Vector2(28, 1), Vector2(34, 8), Vector2(34, 14), Vector2(17, 29), Vector2(0, 14), Vector2(0, 8)])
	var pulse := PackedVector2Array([Vector2(-1, 13), Vector2(10, 13), Vector2(13, 9), Vector2(17, 17), Vector2(21, 12), Vector2(35, 12)])
	draw_set_transform(origin)
	draw_polyline(heart, Color("f17e79"), 2.0, true)
	draw_polyline(pulse, Color("f17e79"), 1.5, true)
	draw_set_transform(Vector2.ZERO)

func _draw_injury(part: String, rect: Rect2, tint: Color) -> void:
	var zone: Array
	match part:
		"head": zone = HEAD_ZONE
		"thorax": zone = CHEST_ZONE
		"stomach": zone = ABDOMEN_ZONE
		"left_arm", "right_arm": zone = ARM_ZONE
		_: zone = LEG_ZONE
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for original: Vector2 in zone:
		var pixel := Vector2(1014.0 - original.x, original.y) if part.begins_with("left_") else original
		points.append(rect.position + (pixel - ART_CROP.position) / ART_CROP.size * rect.size)
		uvs.append(pixel / ART_SIZE)
	draw_polygon(points, PackedColorArray([Color(tint.r, tint.g * 0.62, tint.b * 0.52, 0.92)]), uvs, illustration)
