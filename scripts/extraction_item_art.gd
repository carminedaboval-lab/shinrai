extends Control
## Supplied item art, with native can/tool silhouettes. Other missing art is a record.
const LootContainers = preload("./extraction_loot_containers.gd")
const MAP = preload("res://assets/shinrai/parks/midori_park/models/furniture/ambient/information_board/midori_information_board_midori_information_map_draft_v2_1k.png")
const CUP_PATH := "res://assets/ui/items/takeaway_cup.png"
const CODES := {"weapon_akane":"AKANE / A-9","akane_magazine":"A-9 MAG","raiden_r56_magazine":"R-56 MAG","tobikage_magazine":"T-65 MAG","hayate_magazine":"H-7 MAG","yuzuru_magazine":"YZ-10 MAG","ammo_556x45":"5.56×45 mm","ammo_65x48":"6.5×48 mm","optic_scope_01":"KASUMI / 6×","uzi_magazine":"UZI MAG","shigure_magazine":"S-9 MAG","kite_magazine":"K-12 MAG","ammo_9x19":"9×19 mm","ammo_762x51":"7.62×51 mm","basic_shirt":"SHIRT","basic_trousers":"TROUSERS","work_jacket":"JACKET","cargo_trousers":"CARGO","utility_pouch":"POUCH","security_armour_t2":"VEST / T2","patrol_armour_t3":"VEST / T3","circuit": "CIRCUIT / 01", "optics": "OPTICS / 02", "cell": "POWER / 03", "archive": "ARCHIVE / 04", "medkit": "MEDICAL", "garden_mikan": "MIKAN", "garden_persimmon": "KAKI"}
const RECORD_CATEGORIES := {"weapon_akane":"PISTOL","akane_magazine":"MAGAZINE","raiden_r56_magazine":"MAGAZINE","tobikage_magazine":"MAGAZINE","hayate_magazine":"MAGAZINE","yuzuru_magazine":"MAGAZINE","ammo_556x45":"AMMUNITION","ammo_65x48":"AMMUNITION","optic_scope_01":"OPTIC","uzi_magazine":"MAGAZINE","shigure_magazine":"MAGAZINE","kite_magazine":"MAGAZINE","ammo_9x19":"AMMUNITION","ammo_762x51":"AMMUNITION","basic_shirt":"CLOTHING","basic_trousers":"CLOTHING","work_jacket":"CLOTHING","cargo_trousers":"CLOTHING","utility_pouch":"STORAGE","security_armour_t2":"ARMOUR","patrol_armour_t3":"ARMOUR","circuit": "ELECTRONICS", "optics": "OPTICS", "cell": "POWER", "archive": "DATA", "medkit": "MEDICAL", "garden_mikan": "FRUIT", "garden_persimmon": "FRUIT"}
var item_id := ""
var texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = loot_texture(item_id)
	if texture != null:
		pass
	elif item_id == "park_map":
		texture = MAP
	elif item_id == "coffee_cup" and ResourceLoader.exists(CUP_PATH):
		texture = load(CUP_PATH)
	elif item_id in ["backpack_regular","backpack_mountain"]:
		var image_path := "res://assets/shinrai/gear/backpacks/" + ("regular" if item_id=="backpack_regular" else "mountain") + "_inventory.png"
		if ResourceLoader.exists(image_path): texture=load(image_path)
	queue_redraw()

static func loot_texture(id: String) -> Texture2D:
	var path := str(LootContainers.spec(id).get("icon_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _draw() -> void:
	if item_id in ["hammer","screwdriver","wrench","bolt_cutters"]:
		_draw_maintenance_tool()
	elif item_id in ["canned_mackerel","canned_mackerel_open","canned_peaches","canned_peaches_open","can_opener"]:
		_draw_canned_item()
	elif texture != null:
		var factor := minf((size.x - 12.0) / texture.get_width(), (size.y - 8.0) / texture.get_height())
		var dimensions := Vector2(texture.get_size()) * factor
		draw_texture_rect(texture, Rect2((size - dimensions) * 0.5, dimensions), false)
	else:
		var font := get_theme_default_font()
		var text := str(CODES.get(item_id, "ITEM RECORD"))
		_draw_record_line(font, text, size.y * 0.48, 20, Color("aebbc4"))
		_draw_record_line(font, str(RECORD_CATEGORIES.get(item_id, "UNCLASSIFIED")), size.y * 0.48 + 26, 14, Color("c3c3c3"))

func _draw_canned_item() -> void:
	var factor := minf((size.x-8.0)/100.0,(size.y-4.0)/80.0)
	if factor <= 0.0: return
	draw_set_transform((size-Vector2(100,80)*factor)*.5,0.0,Vector2.ONE*factor)
	if item_id=="can_opener":
		_draw_can_opener()
	else:
		_draw_can(item_id.ends_with("_open"),item_id.begins_with("canned_mackerel"))
	draw_set_transform(Vector2.ZERO)

func _icon_ellipse(center: Vector2, radius: Vector2, fill: Color, edge: Color) -> void:
	var outline := PackedVector2Array()
	for index: int in range(32):
		var angle := TAU*float(index)/32.0
		outline.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	draw_colored_polygon(outline,fill)
	outline.append(outline[0])
	draw_polyline(outline,edge,1.5,true)

func _draw_can(opened: bool, pull_tab: bool) -> void:
	var steel := Color("aebbb9")
	var edge := Color("63777b")
	var shadow := Color("40545b")
	var band := Color("66858a") if pull_tab else Color("b2986b")
	# Rolled metal rim, cylindrical body and a clear label motif remain readable
	# at the existing 52px inventory-art height; no freshness is implied by art.
	_icon_ellipse(Vector2(50,63),Vector2(30,7),edge,shadow)
	draw_rect(Rect2(20,21,60,42),steel)
	draw_rect(Rect2(20,25,5,35),Color("849795"))
	draw_rect(Rect2(74,25,6,35),edge)
	draw_rect(Rect2(24,31,52,23),band)
	draw_line(Vector2(24,28),Vector2(76,28),edge,1.3,true)
	draw_line(Vector2(24,58),Vector2(76,58),edge,1.3,true)
	_icon_ellipse(Vector2(50,21),Vector2(30,7),steel,edge)
	if opened:
		_icon_ellipse(Vector2(50,21),Vector2(26,5),Color("26393b"),Color("c5cfca"))
		var flap := PackedVector2Array([Vector2(24,15),Vector2(31,4),Vector2(76,1),Vector2(71,12)])
		draw_colored_polygon(flap,Color("a0b0ac"))
		flap.append(flap[0])
		draw_polyline(flap,edge,1.5,true)
		if pull_tab: _icon_ellipse(Vector2(49,8),Vector2(6,2.8),steel,edge)
	elif pull_tab:
		_icon_ellipse(Vector2(50,21),Vector2(7.8,3.9),Color("cdd5ce"),edge)
		_icon_ellipse(Vector2(50,21),Vector2(4.8,1.9),Color("5d7174"),edge)
		draw_circle(Vector2(59,21),1.8,Color("d0d6cd"))
	else:
		# Plain lid has concentric pressed rings and no pull tab.
		_icon_ellipse(Vector2(50,21),Vector2(23,4.4),Color("b3bfbb"),edge)
	if pull_tab:
		_icon_ellipse(Vector2(51,42),Vector2(12,5.3),Color("e0e4d7"),Color("d5dfd2"))
		draw_colored_polygon(PackedVector2Array([Vector2(39,42),Vector2(32,36),Vector2(32,48)]),Color("e0e4d7"))
		draw_circle(Vector2(58,41),1.0,shadow)
	else:
		draw_circle(Vector2(46,43),7.5,Color("d5a071"))
		draw_circle(Vector2(54,43),7.0,Color("d9ae7b"))
		draw_colored_polygon(PackedVector2Array([Vector2(49,36),Vector2(53,30),Vector2(60,33),Vector2(53,37)]),Color("526e51"))
	draw_line(Vector2(20,22),Vector2(20,62),edge,1.5,true)
	draw_line(Vector2(80,22),Vector2(80,62),shadow,1.5,true)

func _draw_can_opener() -> void:
	var metal := Color("b8c4bf")
	var edge := Color("5d7375")
	var grip := Color("597267")
	# Two handles, cutting wheel and winding crank distinguish this reusable tool
	# from a key or a sealed food tin without requiring another image resource.
	draw_line(Vector2(44,34),Vector2(21,69),edge,9.0,true)
	draw_line(Vector2(51,37),Vector2(74,66),edge,9.0,true)
	draw_line(Vector2(37,45),Vector2(21,69),grip,7.0,true)
	draw_line(Vector2(58,46),Vector2(74,66),grip,7.0,true)
	draw_line(Vector2(44,34),Vector2(55,25),metal,5.5,true)
	draw_line(Vector2(51,37),Vector2(62,29),metal,5.5,true)
	draw_circle(Vector2(55,25),10.0,edge)
	draw_circle(Vector2(55,25),7.2,metal)
	for tooth: int in range(10):
		var direction := Vector2(cos(float(tooth)*TAU/10.0),sin(float(tooth)*TAU/10.0))
		draw_line(Vector2(55,25)+direction*7.0,Vector2(55,25)+direction*10.0,metal,1.8,true)
	draw_circle(Vector2(55,25),2.7,Color("405755"))
	draw_arc(Vector2(51,23),15.5,PI*.90,PI*1.80,16,metal,4.0,true)
	draw_line(Vector2(62,25),Vector2(81,26),metal,4.0,true)
	draw_rect(Rect2(78,20,8,14),grip)
	draw_circle(Vector2(47,34),2.7,Color("d2d8cb"))

func _draw_record_line(font: Font, text: String, baseline: float, font_size: int, tint: Color) -> void:
	var available := maxf(0.0, size.x - 16.0)
	if available <= 0.0: return
	while font_size > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	var shown := text
	if font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		while not shown.is_empty() and font.get_string_size(shown + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
			shown = shown.left(shown.length() - 1)
		shown += "…"
	var width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > available or font.get_height(font_size) > size.y: return
	var y := clampf(baseline, font.get_ascent(font_size), size.y - font.get_descent(font_size))
	# Width is fitted explicitly; do not silently cut the code's last glyphs.
	draw_string(font, Vector2((size.x - width) * 0.5, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _draw_maintenance_tool() -> void:
	var factor:=minf((size.x-12.0)/100.0,(size.y-8.0)/80.0)
	if factor<=0.0:return
	draw_set_transform((size-Vector2(100,80)*factor)*.5,0.0,Vector2.ONE*factor)
	var metal:=Color("b7c1bc");var dark:=Color("4a5e59");var grip:=Color("a3865c")
	match item_id:
		"hammer":
			draw_line(Vector2(48,26),Vector2(57,70),dark,12,true)
			draw_line(Vector2(51,40),Vector2(57,70),grip,9,true)
			draw_colored_polygon(PackedVector2Array([Vector2(25,15),Vector2(60,12),Vector2(71,20),Vector2(78,34),Vector2(66,28),Vector2(56,27),Vector2(29,31)]),metal)
			draw_rect(Rect2(22,15,10,18),dark)
		"screwdriver":
			draw_line(Vector2(35,60),Vector2(68,19),metal,5,true)
			draw_line(Vector2(23,72),Vector2(44,45),dark,14,true)
			draw_line(Vector2(25,69),Vector2(42,48),Color("6a8671"),10,true)
			draw_colored_polygon(PackedVector2Array([Vector2(64,19),Vector2(72,13),Vector2(74,16),Vector2(68,23)]),metal)
		"wrench":
			draw_line(Vector2(32,68),Vector2(60,31),dark,13,true)
			draw_line(Vector2(32,68),Vector2(60,31),metal,9,true)
			draw_circle(Vector2(31,69),7,metal);draw_circle(Vector2(31,69),3,dark)
			draw_colored_polygon(PackedVector2Array([Vector2(51,35),Vector2(46,23),Vector2(52,11),Vector2(63,8),Vector2(59,20),Vector2(66,27),Vector2(76,19),Vector2(77,31),Vector2(65,40)]),metal)
			draw_line(Vector2(52,31),Vector2(64,36),dark,3,true)
		"bolt_cutters":
			var handle:=Color("b3402f")
			draw_line(Vector2(50,32),Vector2(24,72),dark,7,true)
			draw_line(Vector2(54,32),Vector2(80,72),dark,7,true)
			draw_line(Vector2(36,54),Vector2(24,72),handle,8,true)
			draw_line(Vector2(68,54),Vector2(80,72),handle,8,true)
			draw_colored_polygon(PackedVector2Array([Vector2(44,34),Vector2(49,12),Vector2(52,10),Vector2(51,34)]),metal)
			draw_colored_polygon(PackedVector2Array([Vector2(60,34),Vector2(55,12),Vector2(52,10),Vector2(53,34)]),metal)
			draw_circle(Vector2(52,33),6,metal);draw_circle(Vector2(52,33),2.5,dark)
	draw_set_transform(Vector2.ZERO)
