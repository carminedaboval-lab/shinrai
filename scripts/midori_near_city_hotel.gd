extends "res://scripts/midori_near_city_handmade.gd"
## ホテルニュー千鳥: a ten-storey business hotel squeezed onto a seven-metre lot in 1991.
## Brown 45二丁掛 tile on the street face, painted render on the flanks, two small rooms a
## floor behind net curtains, a breakfast room on 2F and the bath on 10F, a lit blade sign,
## a steel fire stair down the back, and on the roof a sign frame, a tank and a drone pad.
const ATLAS := "res://assets/shinrai/near_city/hotel_atlas.png"
const WIDE := 6.9
const DEEP := 13.2
const GROUND := 3.7
const PITCH := 2.9
const FLOORS := 9
const ROOF := GROUND + PITCH * FLOORS
const PARAPET := ROOF + 1.1
const PIER := .42
const WIN_W := 1.3
const WIN_H := 1.35
const SILL := .92
const FRONT_X: Array[float] = [1.85, 4.62]
const SIDE_X: Array[float] = [2.6, 5.5, 8.4]
const DOOR_X1 := 2.75
const SHOP_X0 := 3.25
const SHOP_X1 := 6.44
const RECESS := .9
const LOBBY_TOP := 2.75
const LOBBY_DEEP := 6.8
const TILE := Color("#a3876a")
const DARK_TILE := Color("#6b5241")
const PAINT := Color("#bdb39f")
const BRONZE := Color("#4a4036")
const STAIR := Color("#66706b")
const CREAM := Color("#e6dccb")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1991
	_build_looks()
	_front_wall()
	_ground_floor()
	_lobby()
	_canopy()
	_upper_floors()
	_blade_sign()
	_side_walls()
	_back_stair()
	_roof()
	_pavement()
	_kit.commit(self, _looks, ["front", "decal", "paint", "lamp", "led", "sign", "fascia", "room", "hall", "display", "vend", "screen", "lit", "curtain", "eink", "bath", "floor"])
	_kit = null
	_omni("HotelLobby", _front * Vector3(3.6, 2.4, -3.0), Color(1.0, .88, .7), .7, 5.5)
	_omni("HotelCanopy", _front * Vector3(1.6, 2.4, .9), Color(1.0, .86, .64), .5, 4.5)

func _atlas_look(name: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _lit_look(name: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _decal_look(name: String, glow: float, day: float) -> void:
	var look := ShaderMaterial.new()
	look.shader = DECAL_SHADER
	look.set_shader_parameter("atlas", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _build_looks() -> void:
	_shared_looks()
	_looks.tile = _look("white_stucco", 3.0, .7)
	_looks.tile.set_shader_parameter("chroma", .2)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.1, .05))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .4)
	_looks.concrete = _look("precast_concrete_wall", 2.0, .9)
	_looks.concrete.set_shader_parameter("chroma", .3)
	_looks.stone = _look("concrete_tile_facade", 1.2, .45)
	_looks.steel = _look("rusty_painted_metal", 1.6, .8)
	_looks.steel.set_shader_parameter("chroma", .35)
	_atlas_look("curtain", .9, 0.0, 0.0)
	_atlas_look("lit", .9, .45, 0.0)
	_atlas_look("sign", .4, 1.4, .12)
	_atlas_look("fascia", .5, .3, .04)
	_atlas_look("board", .6, .05, .02)
	_atlas_look("display", .5, .3, .12)
	_atlas_look("floor", .3, .24, .1)
	_atlas_look("vend", .3, .9, .3)
	_atlas_look("screen", .3, .9, .3)
	_atlas_look("eink", .7, .08, .02)
	_lit_look("room", .6, .22, .08)
	_lit_look("hall", .6, .03, .07)
	_lit_look("bath", .4, .7, .05)
	_decal_look("decal", .3, .1)
	_decal_look("paint", 0.0, 0.0)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _flat(part: String, face: Transform3D, area: Rect2, z: float, tint: Color, low := .9, streak := .6) -> void:
	_kit.quad(part, face * Vector3(area.position.x, area.position.y, z), face * Vector3(area.position.x, area.end.y, z), face * Vector3(area.end.x, area.end.y, z), face * Vector3(area.end.x, area.position.y, z), tint, low, 1.0, streak, Vector2(area.position.x, -area.position.y))

func _floor_y(i: int) -> float:
	return GROUND + float(i) * PITCH

func _front_openings(i: int) -> Array[Rect2]:
	var y := _floor_y(i)
	if i == 0:
		return [Rect2(.67, y + .8, 5.56, 1.65)]
	var out: Array[Rect2] = []
	for cx: float in FRONT_X:
		if i == FLOORS - 1:
			out.append(Rect2(cx - .65, y + 1.25, 1.3, .75))
		else:
			out.append(Rect2(cx - WIN_W * .5, y + SILL, WIN_W, WIN_H))
	return out

# ---------------------------------------------------------------- street face

func _front_wall() -> void:
	# 45二丁掛 in running bond between two darker corner piers, a crown band at the roof.
	var f := _front
	var holes: Array[Rect2] = []
	for i: int in range(FLOORS):
		for r: Rect2 in _front_openings(i):
			holes.append(r.grow(.04))
	for piece: Rect2 in _minus(Rect2(PIER, GROUND, WIDE - PIER * 2.0, ROOF - .25 - GROUND), holes):
		var tone := _rng.randf_range(.96, 1.03)
		_flat("tile", f, piece, 0.0, Color(TILE.r * tone, TILE.g * tone, TILE.b * tone), .88, .55)
	# Crown band and parapet, the same tile a shade darker and proud of the face.
	_bar("tile", f, WIDE * .5, (ROOF - .25 + PARAPET) * .5, .04, Vector3(WIDE, PARAPET - ROOF + .25, .08), DARK_TILE, .9, 1.0)
	_bar("concrete", f, WIDE * .5, PARAPET + .04, -.06, Vector3(WIDE + .04, .08, .34), Color("#9a968e"))
	for x: float in [PIER * .5, WIDE - PIER * .5]:
		_bar("tile", f, x, (ROOF - .25) * .5, .05, Vector3(PIER, ROOF - .25, .1), DARK_TILE, .85, 1.0)
	# A course of dark tile at every slab, the floors read from the street.
	for i: int in range(1, FLOORS):
		_bar("tile", f, WIDE * .5, _floor_y(i) + .04, .02, Vector3(WIDE - PIER * 2.0, .1, .04), DARK_TILE * 1.1)
	# The fibre trunk the city ran up every frontage, here down the west pier.
	_fibre([f * Vector3(.12, ROOF - .3, .14), f * Vector3(.12, 3.0, .14), f * Vector3(.12, 2.8, .4), f * Vector3(.12, .3, .4)])

func _louvre(face: Transform3D, cx: float, y: float, w := 1.2) -> void:
	# Aluminium grille over the room unit's intake: dark back, frame, seven slats.
	var y0 := y + .2
	var y1 := y + .72
	_bar("metal", face, cx, (y0 + y1) * .5, .01, Vector3(w, y1 - y0, .02), Color("#242220"))
	for yy: float in [y0 + .015, y1 - .015]:
		_bar("metal", face, cx, yy, .04, Vector3(w + .02, .03, .06), Color("#8a857a"))
	for xx: float in [cx - w * .5, cx + w * .5]:
		_bar("metal", face, xx, (y0 + y1) * .5, .04, Vector3(.03, y1 - y0, .06), Color("#8a857a"))
	for k: int in range(7):
		_bar("metal", face, cx, y0 + .06 + float(k) * .065, .045, Vector3(w - .03, .022, .05), Color("#9a958a"))
	if _rng.randf() < .55:
		_panel("paint", face, cx - .3, cx + .3, y0 - 1.1, y0 - .02, .004, _cell(1650, 1250, 120, 300))

func _frame(face: Transform3D, r: Rect2, z: float, tint: Color, mullion: bool) -> void:
	var cx := r.get_center().x
	var cy := r.get_center().y
	_bar("metal", face, cx, r.end.y - .025, z, Vector3(r.size.x, .05, .06), tint)
	_bar("metal", face, cx, r.position.y + .025, z, Vector3(r.size.x, .05, .06), tint)
	_bar("metal", face, r.position.x + .025, cy, z, Vector3(.05, r.size.y, .06), tint)
	_bar("metal", face, r.end.x - .025, cy, z, Vector3(.05, r.size.y, .06), tint)
	if mullion:
		_bar("metal", face, cx, cy, z - .01, Vector3(.045, r.size.y, .05), tint)

func _room_window(face: Transform3D, r: Rect2) -> void:
	# Each room its own night: most dark, some behind lace, a few lit warm or blue with the TV on.
	_reveal(face, r, .14, Color("#8a8072"))
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var z := -.12
	var roll := _rng.randf()
	if roll < .7 or roll > .9:
		_kit.pane("glass", face, x0, x1, y0, y1, z, _rng.randf())
	else:
		var lace := _cell(0, 1520, 256, 256)
		var cloth := lace
		var part := "curtain"
		var tint := Color.WHITE
		if roll < .79:
			tint = Color(.74, .74, .71)
		elif roll < .84:
			cloth = _cell(260, 1520, 256, 256) if _rng.randf() < .6 else _cell(520, 1520, 256, 256)
		elif roll < .87:
			part = "lit"
			tint = Color(1.0, .72, .44)
		elif roll < .885:
			part = "lit"
			cloth = _cell(260, 1520, 256, 256)
			tint = Color(1.0, .66, .4)
		else:
			part = "lit"
			tint = Color(.66, .8, 1.0)
		var shift := _rng.randf_range(0.0, .1)
		_kit.atlas(part, face * Vector3(x0, y0, z - .02), face * Vector3(x0, y1, z - .02), face * Vector3(x1, y1, z - .02), face * Vector3(x1, y0, z - .02), Rect2(cloth.position.x + shift * cloth.size.x, cloth.position.y, cloth.size.x * .9, cloth.size.y), tint)
		_kit.quad("front", face * Vector3(x0, y0, z + .03), face * Vector3(x0, y1, z + .03), face * Vector3(x1, y1, z + .03), face * Vector3(x1, y0, z + .03), Color.WHITE)
	_frame(face, r, -.07, BRONZE, true)
	_bar("concrete", face, r.get_center().x, y0 - .05, .04, Vector3(r.size.x + .14, .06, .17), Color("#a8a49a"))

func _upper_floors() -> void:
	var f := _front
	for i: int in range(FLOORS):
		var y := _floor_y(i)
		if i == 0:
			_breakfast_room(y)
			continue
		var openings := _front_openings(i)
		for k: int in range(openings.size()):
			var r := openings[k]
			var cx: float = FRONT_X[k]
			if i == FLOORS - 1:
				_bath_window(f, r)
			else:
				_room_window(f, r)
				if k == 0:
					# 非常用進入口: one red triangle a floor, on the glass.
					_panel("paint", f, r.position.x + .08, r.position.x + .3, r.end.y - .3, r.end.y - .08, -.095, _cell(1200, 720, 128, 128))
			_louvre(f, cx, y)

func _bath_window(face: Transform3D, r: Rect2) -> void:
	# 大浴場 on the top floor: high frosted lights, steamy and lit till one in the morning.
	_reveal(face, r, .14, Color("#8a8072"))
	_flat("bath", face, r, -.12, Color(.9, .88, .8), 1.0, 0.0)
	for k: int in range(1, 4):
		_bar("plain", face, r.get_center().x, r.position.y + r.size.y * float(k) / 4.0, -.115, Vector3(r.size.x, .012, .006), Color("#b8b4a8"))
	_frame(face, r, -.07, BRONZE, false)
	_bar("concrete", face, r.get_center().x, r.position.y - .05, .04, Vector3(r.size.x + .14, .06, .17), Color("#a8a49a"))

func _breakfast_room(y: float) -> void:
	# 2F: the breakfast room behind one long window, chairs up on the tables after nine.
	var f := _front
	var r := _front_openings(0)[0]
	var near := -.14
	var deep := -3.6
	var top := y + 2.6
	var x0 := PIER + .02
	var x1 := WIDE - PIER - .02
	_reveal(f, r, .14, Color("#8a8072"))
	_kit.quad("hall", f * Vector3(x0, y + .02, near), f * Vector3(x0, y + .02, deep), f * Vector3(x1, y + .02, deep), f * Vector3(x1, y + .02, near), Color("#6a5848"), .8, .8)
	_kit.quad("hall", f * Vector3(x0, top, deep), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, deep), Color("#e4ded0"), .8, .8)
	_kit.quad("hall", f * Vector3(x0, y, deep), f * Vector3(x0, top, deep), f * Vector3(x1, top, deep), f * Vector3(x1, y, deep), Color("#d6c8ae"), .7, 1.0)
	_kit.quad("hall", f * Vector3(x0, y, near), f * Vector3(x0, top, near), f * Vector3(x0, top, deep), f * Vector3(x0, y, deep), Color("#cbbd9f"), .7, 1.0)
	_kit.quad("hall", f * Vector3(x1, y, deep), f * Vector3(x1, top, deep), f * Vector3(x1, top, near), f * Vector3(x1, y, near), Color("#cbbd9f"), .7, 1.0)
	# Buffet counter along the back with its steel chafing dishes, rice cooker and urn.
	_bar("hall", f, 3.4, y + .45, deep + .35, Vector3(4.2, .9, .6), Color("#8a6a4c"))
	for k: int in range(5):
		_bar("metal", f, 1.8 + float(k) * .75, y + .96, deep + .35, Vector3(.5, .12, .34), Color("#b8bab6"))
	_kit.lathe("metal", f * Vector3(5.3, y + .9, deep + .3), [Vector2(.16, 0), Vector2(.17, .3), Vector2(.05, .36)], Color("#c8c4bc"), 10)
	# Four tables, the chairs stacked on two of them.
	for t: int in range(4):
		var tx := 1.3 + float(t) * 1.4
		var tz := -1.3 - float(t % 2) * .5
		_bar("hall", f, tx, y + .72, tz, Vector3(.8, .04, .7), Color("#d8d0c0"))
		_bar("hall", f, tx, y + .36, tz, Vector3(.06, .72, .06), Color("#3a3634"))
		for s: float in [-.5, .5]:
			if t % 2 == 0:
				_bar("hall", f, tx + s * .9, y + .23, tz, Vector3(.4, .04, .4), Color("#7a3a32"))
				_bar("hall", f, tx + s * 1.06, y + .5, tz, Vector3(.04, .5, .4), Color("#7a3a32"))
			else:
				_bar("hall", f, tx + s * .3, y + .96, tz, Vector3(.38, .04, .38), Color("#7a3a32"))
	# Glazing: three leaves, the breakfast hours on the glass.
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, -.1), f * Vector3(r.position.x, r.end.y, -.1), f * Vector3(r.end.x, r.end.y, -.1), f * Vector3(r.end.x, r.position.y, -.1), Color.WHITE)
	_frame(f, r, -.07, BRONZE, false)
	for k: int in range(1, 3):
		_bar("metal", f, r.position.x + r.size.x * float(k) / 3.0, r.get_center().y, -.07, Vector3(.05, r.size.y, .06), BRONZE)
	_panel("decal", f, .95, 2.95, r.end.y - .52, r.end.y - .12, -.095, _cell(240, 880, 600, 120))
	_bar("concrete", f, r.get_center().x, r.position.y - .05, .04, Vector3(r.size.x + .14, .06, .17), Color("#a8a49a"))
	_bar("metal", f, r.get_center().x, y + .45, .01, Vector3(r.size.x, .5, .02), Color("#242220"))
	for k: int in range(6):
		_bar("metal", f, r.get_center().x, y + .25 + float(k) * .075, .04, Vector3(r.size.x - .03, .022, .05), Color("#9a958a"))

# ---------------------------------------------------------------- ground floor

func _ground_floor() -> void:
	var f := _front
	# Band over the openings, behind the name board.
	_flat("tile", f, Rect2(PIER, LOBBY_TOP, WIDE - PIER * 2.0, GROUND - LOBBY_TOP), 0.0, DARK_TILE, .8, .3)
	_bar("stone", f, (SHOP_X0 + SHOP_X1) * .5, .22, .03, Vector3(SHOP_X1 - SHOP_X0, .44, .06), Color("#8a8580"), .8, 1.0)
	_bar("stone", f, (DOOR_X1 + SHOP_X0) * .5, LOBBY_TOP * .5, .03, Vector3(SHOP_X0 - DOOR_X1, LOBBY_TOP, .1), Color("#9a948c"), .8, 1.0)
	# Name board over the whole front.
	_bar("metal", f, WIDE * .5, 3.23, .07, Vector3(5.6, .84, .08), Color("#1e1c1a"))
	_panel("fascia", f, .7, 6.2, 2.84, 3.62, .115, _cell(240, 310, 1200, 170))
	# Lobby window: bronze frame, one mullion, the name in gold across its head.
	var r := Rect2(SHOP_X0, .44, SHOP_X1 - SHOP_X0, LOBBY_TOP - .44)
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, -.08), f * Vector3(r.position.x, r.end.y, -.08), f * Vector3(r.end.x, r.end.y, -.08), f * Vector3(r.end.x, r.position.y, -.08), Color.WHITE)
	_frame(f, r, -.05, BRONZE, true)
	_panel("decal", f, 3.62, 5.2, 2.22, 2.55, -.075, _cell(240, 600, 540, 110))
	# The e-paper vacancy board on the stone pier.
	_bar("plain", f, (DOOR_X1 + SHOP_X0) * .5, 1.45, .1, Vector3(.46, .32, .03), Color("#2a2c2e"))
	_panel("eink", f, DOOR_X1 + .04, SHOP_X0 - .04, 1.32, 1.58, .117, _cell(880, 720, 300, 200))
	_status(f, SHOP_X0 - .06, 1.6, .117, GREEN)
	# Entrance recess: stone cheeks, a soffit, the door mat.
	var x0 := PIER
	var x1 := DOOR_X1
	var z := -RECESS
	_kit.quad("stone", f * Vector3(x0, 0, 0), f * Vector3(x0, LOBBY_TOP, 0), f * Vector3(x0, LOBBY_TOP, z), f * Vector3(x0, 0, z), Color("#9a948c"), .7, .9)
	_kit.quad("stone", f * Vector3(x1, 0, z), f * Vector3(x1, LOBBY_TOP, z), f * Vector3(x1, LOBBY_TOP, 0), f * Vector3(x1, 0, 0), Color("#9a948c"), .7, .9)
	_kit.quad("plain", f * Vector3(x0, LOBBY_TOP - .012, z), f * Vector3(x0, LOBBY_TOP - .012, 0), f * Vector3(x1, LOBBY_TOP - .012, 0), f * Vector3(x1, LOBBY_TOP - .012, z), Color("#d8d4cc"), .6, .7)
	_kit.quad("stone", f * Vector3(x0, .03, 0), f * Vector3(x0, .03, z), f * Vector3(x1, .03, z), f * Vector3(x1, .03, 0), Color("#7a7670"), .7, .8)
	_bar("plain", f, (x0 + x1) * .5, .04, z * .5, Vector3(1.6, .015, .6), Color("#3a3c40"))
	for lx: float in [.9, 2.2]:
		_kit.disc("lamp", f * Vector3(lx, LOBBY_TOP - .004, z * .5), Vector3.RIGHT, Vector3.BACK, .06, Color(1.0, .9, .74))
	# Automatic doors: two glass leaves in thin stainless, header with its sensor.
	var hx0 := x0 + .06
	var hx1 := x1 - .06
	var mid := (hx0 + hx1) * .5
	_bar("metal", f, (x0 + x1) * .5, 2.48, z, Vector3(x1 - x0, .54, .12), Color("#8a8a86"))
	_bar("plain", f, mid, 2.32, z + .07, Vector3(.22, .06, .04), Color("#1a1a1c"))
	_status(f, mid + .07, 2.32, z + .091, Color(1.0, .3, .2))
	_kit.quad("front", f * Vector3(hx0, .02, z + .01), f * Vector3(hx0, 2.2, z + .01), f * Vector3(hx1, 2.2, z + .01), f * Vector3(hx1, .02, z + .01), Color.WHITE)
	for leaf: Array in [[hx0, mid + .02], [mid - .02, hx1]]:
		var a: float = leaf[0]
		var b: float = leaf[1]
		for x: float in [a + .02, b - .02]:
			_bar("metal", f, x, 1.1, z + .02, Vector3(.04, 2.2, .04), Color("#b8b8b2"))
		for y: float in [.04, 2.18]:
			_bar("metal", f, (a + b) * .5, y, z + .02, Vector3(b - a, .06, .04), Color("#b8b8b2"))
		_panel("decal", f, (a + b) * .5 - .16, (a + b) * .5 + .16, 1.2, 1.32, z + .045, _cell(780, 610, 250, 92))
	_panel("decal", f, mid + .08, mid + 1.0, .9, 1.01, z + .045, _cell(240, 490, 800, 100))
	_bar("metal", f, (x0 + x1) * .5, .015, z, Vector3(x1 - x0, .03, .1), Color("#9a9a96"))
	# Camera over the door, a palm pad for guests coming back after the desk shuts.
	_camera(f * Vector3(.65, LOBBY_TOP - .02, -.2))
	_bar("plain", f, x1 - .06, 1.2, z + .3, Vector3(.03, .2, .14), Color("#1c1e20"))
	_status(f, x1 - .08, 1.26, z + .3, CYAN)

func _canopy() -> void:
	# Small steel canopy over the door, hung on two rods, three downlights in its soffit.
	var f := _front
	var x0 := .3
	var x1 := 2.95
	var y := 2.5
	var out := 1.1
	_bar("metal", f, (x0 + x1) * .5, y + .07, out * .5, Vector3(x1 - x0, .14, out), Color("#34302c"))
	_bar("metal", f, (x0 + x1) * .5, y + .06, out, Vector3(x1 - x0 + .02, .2, .04), Color("#b0aaa0"))
	for lx: float in [.9, 1.75, 2.6]:
		_kit.disc("lamp", f * Vector3(lx, y - .002, .8), Vector3.RIGHT, Vector3.BACK, .055, Color(1.0, .88, .7))
	for rx: float in [.6, 2.85]:
		_kit.tube("metal", [f * Vector3(rx, y + .14, out - .05), f * Vector3(rx, y + 1.0, .05)], .012, Color("#3a3836"), 5)

# ---------------------------------------------------------------- the lobby

func _lobby() -> void:
	var f := _front
	var x0 := PIER + .03
	var x1 := WIDE - PIER - .03
	var near := -.1
	var far := -LOBBY_DEEP
	var top := LOBBY_TOP
	# Beige stone floor in 600 squares.
	var gx := x0
	while gx < x1 - .01:
		var gz := near
		var w := minf(1.2, x1 - gx)
		while gz > far + .01:
			var d := minf(1.2, gz - far)
			_kit.atlas("floor", f * Vector3(gx, .02, gz), f * Vector3(gx, .02, gz - d), f * Vector3(gx + w, .02, gz - d), f * Vector3(gx + w, .02, gz), _cell(780, 1520, 256.0 * w / 1.2, 256.0 * d / 1.2))
			gz -= 1.2
		gx += 1.2
	_kit.quad("room", f * Vector3(x0, top, far), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, far), Color("#d8d0c0"), .7, .7)
	var panel := Color("#a88e6c")
	_kit.quad("room", f * Vector3(x0, 0, near), f * Vector3(x0, top, near), f * Vector3(x0, top, far), f * Vector3(x0, 0, far), panel, .7, 1.0)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, top, far), f * Vector3(x1, top, near), f * Vector3(x1, 0, near), panel, .7, 1.0)
	_kit.quad("room", f * Vector3(x0, 0, far), f * Vector3(x0, top, far), f * Vector3(x1, top, far), f * Vector3(x1, 0, far), Color("#8a6a4c"), .7, 1.0)
	for side: Array in [[x0 + .01, near, far], [x1 - .01, far, near]]:
		_bar("room", f, side[0], .05, (near + far) * .5, Vector3(.02, .1, near - far), Color("#5a4636"))
	# Downlights and a ceiling cassette.
	for lx: float in [1.4, 3.4, 5.4]:
		for lz: float in [-1.4, -3.4, -5.4]:
			_kit.disc("lamp", f * Vector3(lx, top - .004, lz), Vector3.RIGHT, Vector3.BACK, .06, Color(1.0, .9, .74))
	_bar("room", f, 3.4, top - .03, -2.4, Vector3(.84, .05, .84), Color("#f2f0ea"))
	_bar("room", f, 3.4, top - .056, -2.4, Vector3(.5, .004, .5), Color("#9a9a94"))
	# Lift on the back wall, stainless, its floor numbers over the door.
	var lx0 := .8
	var lx1 := 1.8
	_kit.quad("metal", f * Vector3(lx0, 0, far + .01), f * Vector3(lx0, 2.1, far + .01), f * Vector3(lx1, 2.1, far + .01), f * Vector3(lx1, 0, far + .01), Color("#c4c6c4"), .8, 1.0)
	_bar("room", f, (lx0 + lx1) * .5, 1.05, far + .02, Vector3(.01, 2.1, .01), Color("#5a5c5c"))
	_bar("room", f, (lx0 + lx1) * .5, 2.15, far + .02, Vector3(1.2, .1, .04), Color("#8a8c8a"))
	_bar("room", f, lx0 - .1, 1.1, far + .02, Vector3(.1, 1.0, .04), Color("#8a8c8a"))
	_bar("room", f, (lx0 + lx1) * .5, 2.35, far + .02, Vector3(.6, .12, .02), Color("#141414"))
	_bar("led", f, (lx0 + lx1) * .5 - .1, 2.35, far + .032, Vector3(.08, .06, .004), AMBER)
	_status(f, lx0 - .1, 1.15, far + .045, AMBER)
	# Notice board on the west wall: bath, breakfast, ice, washing machines.
	var m := x0 + .01
	_kit.atlas("display", f * Vector3(m, 1.1, -3.0), f * Vector3(m, 1.9, -3.0), f * Vector3(m, 1.9, -3.55), f * Vector3(m, 1.1, -3.55), _cell(1780, 870, 260, 380))
	# Vending machine in its nook by the lift.
	var vx := 2.55
	var vz := far + .38
	_bar("room", f, vx, .9, vz, Vector3(.92, 1.8, .7), Color("#e0e4e6"))
	_panel("vend", f, vx - .45, vx + .45, .04, 1.78, vz + .352, _cell(1460, 660, 300, 580))
	# Front desk: veneer, a top of dark wood, the name on its face.
	var dx0 := 3.4
	var dx1 := x1 - .05
	var dz := -4.4
	_bar("room", f, (dx0 + dx1) * .5, .52, dz, Vector3(dx1 - dx0, 1.04, .55), Color("#bfa47e"))
	_bar("room", f, (dx0 + dx1) * .5, 1.06, dz + .04, Vector3(dx1 - dx0 + .04, .05, .65), Color("#4a3426"))
	_bar("room", f, (dx0 + dx1) * .5, .06, dz + .25, Vector3(dx1 - dx0, .12, .06), Color("#3a2a20"))
	_panel("display", f, 4.4, 5.6, .55, .85, dz + .28, _cell(240, 720, 400, 100))
	# On it: the bell, a stand of leaflets, the staff's monitor, two check-in kiosks.
	_kit.lathe("metal", f * Vector3(5.8, 1.085, dz + .15), [Vector2(.05, 0), Vector2(.045, .03), Vector2(.02, .05), Vector2(0, .06)], Color("#d8c070"), 8)
	_bar("display", f, 4.9, 1.2, dz + .2, Vector3(.2, .22, .04), Color("#f4f2ea"))
	_bar("room", f, 5.3, 1.3, dz - .1, Vector3(.42, .3, .04), Color("#1a1a1c"))
	for kx: float in [2.6, 3.1]:
		_bar("room", f, kx, .55, -3.7, Vector3(.12, 1.1, .12), Color("#2a2c30"))
		_kit.block("room", Transform3D(Basis(Vector3.RIGHT, -.35), f * Vector3(kx, 1.25, -3.68)), Vector3(.4, .32, .06), Color("#1c1e22"))
		_kit.atlas("screen", f * Vector3(kx - .17, 1.12, -3.61), f * Vector3(kx - .17, 1.37, -3.7), f * Vector3(kx + .17, 1.37, -3.7), f * Vector3(kx + .17, 1.12, -3.61), _cell(660, 720, 200, 150))
	# 2050: the arm on the counter that hands over the key card.
	var arm := f * Vector3(3.75, 1.085, dz + .1)
	_kit.lathe("metal", arm, [Vector2(.08, 0), Vector2(.07, .06), Vector2(.05, .08)], Color("#e8e8e4"), 10)
	_kit.tube("metal", [arm + Vector3(0, .08, 0), arm + Vector3(0, .38, 0), arm + Vector3(-.2, .5, .25)], .03, Color("#ecece8"), 8)
	_kit.tube("metal", [arm + Vector3(-.2, .5, .25), arm + Vector3(-.28, .4, .42)], .022, Color("#ecece8"), 8)
	_bar("led", f, 3.47, 1.48, dz + .52, Vector3(.08, .02, .05), CYAN * .7)
	_bar("room", f, 3.47, 1.46, dz + .56, Vector3(.086, .054, .004), Color("#f8f8f4"))
	# Behind the desk: a veneer partition with the key pigeonholes, three clocks, a print of plovers.
	var back := -5.6
	_kit.quad("room", f * Vector3(3.2, 0, back), f * Vector3(3.2, top, back), f * Vector3(x1, top, back), f * Vector3(x1, 0, back), Color("#9a7a58"), .7, 1.0)
	_kit.quad("room", f * Vector3(3.2, 0, far), f * Vector3(3.2, top, far), f * Vector3(3.2, top, back), f * Vector3(3.2, 0, back), Color("#7a5e44"), .7, 1.0)
	_bar("room", f, (3.2 + x1) * .5, 1.0, back + .01, Vector3(x1 - 3.2, .03, .02), Color("#4a3426"))
	_panel("display", f, 4.2, 5.75, 1.3, 2.2, back + .015, _cell(1060, 490, 380, 220))
	for k: int in range(3):
		var c := f * Vector3(4.45 + float(k) * .52, 2.47, back + .02)
		_kit.disc("room", c, Vector3.RIGHT, Vector3.UP, .11, Color("#f2eee4"))
		_kit.tube("plain", [c + Vector3(0, 0, .006), c + Vector3(.03 * float(k - 1), .07, .006)], .004, Color("#202020"), 3)
	_panel("display", f, 3.45, 3.98, 1.35, 2.04, back + .015, _cell(1040, 1520, 200, 260))
	# Sofa set by the window: tired maroon vinyl, a low table, the newspapers.
	var sx := x1 - .35
	_bar("room", f, sx, .22, -2.0, Vector3(.66, .44, 1.8), Color("#5a2e2c"))
	_bar("room", f, sx + .23, .62, -2.0, Vector3(.2, .5, 1.8), Color("#4e2826"))
	for z: float in [-1.05, -2.95]:
		_bar("room", f, sx, .5, z, Vector3(.66, .26, .14), Color("#4e2826"))
	_bar("room", f, sx - .9, .38, -2.0, Vector3(.6, .04, 1.0), Color("#3a2a20"))
	_bar("room", f, sx - .9, .18, -2.0, Vector3(.5, .36, .9), Color("#2a1e18"))
	_bar("room", f, sx - .9, .41, -1.8, Vector3(.3, .02, .4), Color("#e8e4d8"))
	_bar("room", f, x1 - .16, .55, -3.55, Vector3(.3, 1.1, .5), Color("#7a5a3a"))
	_kit.atlas("display", f * Vector3(x1 - .32, .55, -3.78), f * Vector3(x1 - .32, 1.1, -3.78), f * Vector3(x1 - .32, 1.1, -3.32), f * Vector3(x1 - .32, .55, -3.32), _cell(1780, 660, 260, 200))
	# Plant in the window, the plan poster taped to the glass.
	var pot := f * Vector3(3.6, 0, -.55)
	_kit.lathe("room", pot, [Vector2(.14, 0), Vector2(.18, .36), Vector2(.19, .38)], Color("#d8d2c4"), 10)
	_plant(pot + Vector3.UP * .36, .8, Color("#3f6a35"))
	_panel("display", f, 5.7, 6.13, 1.0, 1.6, -.12, _cell(1250, 1520, 200, 280))
	# Umbrella stand at the door.
	_kit.lathe("metal", f * Vector3(.75, 0, -1.3), [Vector2(.14, 0), Vector2(.14, .5)], Color("#5a5c5e"), 10)
	for k: int in range(3):
		_kit.tube("plain", [f * Vector3(.72 + float(k) * .04, .1, -1.3), f * Vector3(.7 + float(k) * .06, .85, -1.28)], .012, [Color("#1a1a1c"), Color("#2a4a8a"), Color("#d8d8d0")][k], 4)

# ---------------------------------------------------------------- blade sign

func _blade_sign() -> void:
	# Acrylic box on three arms off the east pier, lit from inside: the name down both faces.
	var f := _front
	var x := 6.66
	var t := .32
	var z0 := .22
	var z1 := z0 + 1.1
	var y0 := 4.6
	var y1 := y0 + 7.5
	var xe := x + t * .5 + .004
	var xw := x - t * .5 - .004
	_bar("metal", f, x, (y0 + y1) * .5, (z0 + z1) * .5, Vector3(t, y1 - y0, z1 - z0), Color("#1d2f5a"))
	var face := _cell(0, 0, 220, 1500)
	_kit.atlas("sign", f * Vector3(xe, y0, z1), f * Vector3(xe, y1, z1), f * Vector3(xe, y1, z0), f * Vector3(xe, y0, z0), face)
	_kit.atlas("sign", f * Vector3(xw, y0, z0), f * Vector3(xw, y1, z0), f * Vector3(xw, y1, z1), f * Vector3(xw, y0, z1), face)
	_kit.atlas("sign", f * Vector3(x - t * .5, y1 - 1.75, z1 + .004), f * Vector3(x - t * .5, y1 - .1, z1 + .004), f * Vector3(x + t * .5, y1 - .1, z1 + .004), f * Vector3(x + t * .5, y1 - 1.75, z1 + .004), _cell(1340, 720, 100, 520))
	_bar("metal", f, x, y1 + .04, (z0 + z1) * .5, Vector3(t + .04, .08, z1 - z0 + .04), Color("#8a8c8e"))
	_bar("metal", f, x, y0 - .04, (z0 + z1) * .5, Vector3(t + .04, .08, z1 - z0 + .04), Color("#8a8c8e"))
	for y: float in [y0 + .5, (y0 + y1) * .5, y1 - .5]:
		_bar("metal", f, x, y, (.1 + z0) * .5, Vector3(.08, .12, z0 - .1), Color("#3a3c3e"))
	_kit.tube("plain", [f * Vector3(x - .1, y0 - .04, z0 + .1), f * Vector3(x - .1, y0 - .4, .12), f * Vector3(x - .1, 2.9, .12)], .015, Color("#202022"), 4)
	for y: float in [y0 + 1.6, y1 - 1.6]:
		_panel("paint", f, x - .4, x + .4, y - 1.4, y, .004, _cell(1650, 1250, 120, 300))

# ---------------------------------------------------------------- flanks

func _ac(face: Transform3D, x: float, y: float) -> void:
	# Condenser on a wall bracket, kept cheap: case, fan, guard cross.
	_bar("metal", face, x, y, .22, Vector3(.8, .6, .3), Color("#c4c4ba"))
	_kit.disc("plain", face * Vector3(x - .1, y, .372), face.basis.x, face.basis.y, .21, Color("#26272a"))
	_bar("metal", face, x - .1, y, .376, Vector3(.42, .015, .008), Color("#8f908c"))
	_bar("metal", face, x - .1, y, .376, Vector3(.015, .42, .008), Color("#8f908c"))
	_bar("metal", face, x, y - .33, .22, Vector3(.9, .04, .4), Color("#3a3a38"))
	for xx: float in [x - .35, x + .35]:
		_kit.beam("metal", face * Vector3(xx, y - .33, .4), face * Vector3(xx, y - .8, .02), .03, .03, Vector3.UP, Color("#3a3a38"))

func _side_walls() -> void:
	var w := _west
	var e := _east
	var west_holes: Array[Rect2] = []
	var west_windows: Array[Rect2] = []
	var east_windows: Array[Rect2] = []
	for i: int in range(FLOORS):
		var y := _floor_y(i)
		for x: float in SIDE_X:
			var r := Rect2(x - .4, y + 1.0, .8, 1.1)
			west_windows.append(r)
			west_holes.append(r.grow(.04))
		east_windows.append(Rect2(12.0, y + 1.3, .6, .8))
	var east_holes: Array[Rect2] = []
	for r: Rect2 in east_windows:
		east_holes.append(r.grow(.04))
	_render_wall(w, DEEP, PARAPET, GROUND, PITCH, PAINT, west_holes)
	_render_wall(e, DEEP, PARAPET, GROUND, PITCH, PAINT * .97, east_holes)
	# The street tile turns the corner for a hand's breadth, as builders did to save tile.
	_flat("tile", w, Rect2(DEEP - .45, 0, .45, ROOF - .25), .006, TILE, .88, .5)
	_flat("tile", e, Rect2(0, 0, .45, ROOF - .25), .006, TILE, .88, .5)
	for face: Transform3D in [w, e]:
		var x0 := DEEP - .45 if face == w else 0.0
		_flat("tile", face, Rect2(x0, ROOF - .25, .45, PARAPET - ROOF + .25), .046, DARK_TILE, .9, .3)
	for r: Rect2 in west_windows:
		_room_window(w, r)
	for r: Rect2 in east_windows:
		# Corridor ends: frosted, lit all night.
		_reveal(e, r, .12, Color("#8a8072"))
		_flat("bath", e, r, -.1, Color(.78, .84, .88), 1.0, 0.0)
		_frame(e, r, -.06, Color("#8a8a86"), false)
	# Names painted down both flanks in 1991, for the trains and the expressway.
	var name_cell := _cell(1460, 1250, 180, 790)
	_panel("paint", w, DEEP - 2.6, DEEP - .5, 15.0, 24.2, .012, name_cell)
	_panel("paint", e, .5, 2.6, 15.0, 24.2, .012, name_cell)
	# East: a column of condensers on brackets, their pipes boxed in a duct, stains below.
	for i: int in range(FLOORS - 1):
		var y := _floor_y(i) + 1.0
		_ac(e, 6.2, y)
		if i % 2 == 0:
			_ac(e, 7.15, y)
		_panel("paint", e, 6.0, 6.5, y - 1.9, y - .4, .006, _cell(1650, 1250, 120, 300))
	_bar("metal", e, 7.95, (GROUND + ROOF) * .5, .07, Vector3(.18, ROOF - GROUND, .12), Color("#cfc8b6"))
	_kit.tube("metal", [e * Vector3(12.9, PARAPET - .2, .1), e * Vector3(12.9, .1, .1)], .05, Color("#8a8476"), 7)
	_kit.tube("metal", [e * Vector3(3.2, ROOF + .3, .08), e * Vector3(3.2, 4.0, .08), e * Vector3(3.6, 3.6, .08), e * Vector3(3.6, .2, .08)], .045, Color("#9a9688"), 7)
	_fibre([e * Vector3(.7, ROOF, .06), e * Vector3(.7, 5.0, .06)])
	# West: a downpipe, the old vent stack, rust where the bracket of a long-gone sign was.
	_kit.tube("metal", [w * Vector3(.3, PARAPET - .2, .1), w * Vector3(.3, .1, .1)], .05, Color("#8a8476"), 7)
	_kit.tube("metal", [w * Vector3(10.0, ROOF + 1.6, .14), w * Vector3(10.0, 3.2, .14)], .07, Color("#a8a49a"), 8)
	for k: int in range(4):
		_bar("metal", w, 10.0, 6.0 + float(k) * 5.8, .08, Vector3(.2, .05, .12), Color("#5a5652"))
	for y: float in [11.0, 13.4]:
		_bar("metal", w, 11.6, y, .03, Vector3(.24, .12, .06), Color("#5a4232"))
		_panel("paint", w, 11.35, 11.85, y - 1.6, y, .006, _cell(1650, 1250, 120, 300))

# ---------------------------------------------------------------- the back

func _back_stair() -> void:
	# Painted steel fire stair, switchback, a landing at every floor's door; a sheet guard.
	var f := _front
	var b := _back
	var holes: Array[Rect2] = []
	for i: int in range(FLOORS + 1):
		var y := 0.0 if i == 0 else _floor_y(i - 1)
		holes.append(Rect2(WIDE - 1.6, y, .85, 2.0))
	_render_wall(b, WIDE, PARAPET, GROUND, PITCH, PAINT * .95, holes)
	for r: Rect2 in holes:
		_flat("steel", b, r, -.04, Color("#7a8078"), .8, .4)
		_bar("metal", b, r.get_center().x, r.end.y + .03, .02, Vector3(r.size.x + .1, .06, .06), Color("#5a5c58"))
	var zi0 := -DEEP - .05
	var zi1 := -DEEP - 1.15
	var zo0 := -DEEP - 1.25
	var zo1 := -DEEP - 2.35
	var ax0 := .45
	var ax1 := 1.75
	var bx0 := 4.25
	var bx1 := 5.55
	for i: int in range(FLOORS + 1):
		var y := 0.0 if i == 0 else _floor_y(i - 1)
		if i > 0:
			_landing(ax0, ax1, y, zi0, zo1)
		if i == FLOORS:
			break
		var half := y + PITCH * .5 if i > 0 else GROUND * .5
		var next := _floor_y(i)
		_landing(bx0, bx1, half, zi0, zo1)
		_flight(ax1, bx0, y, half, zi0, zi1)
		_flight(bx0, ax1, half, next, zo0, zo1)
		# Guard sheet along the outer flight, and the ends of the landings.
		_guard(f * Vector3(bx0, half, zo1), f * Vector3(ax1, next, zo1))
	for x: float in [ax0, bx1]:
		_bar("steel", f, x, (ROOF + 1.1) * .5, zo1, Vector3(.12, ROOF + 1.1, .12), STAIR * .85)
		_bar("steel", f, x, (ROOF + 1.1) * .5, zi0 - .06, Vector3(.1, ROOF + 1.1, .1), STAIR * .85)
	for y: float in [GROUND, _floor_y(3), _floor_y(6)]:
		_bar("steel", f, (ax0 + bx1) * .5, y, zo1, Vector3(bx1 - ax0, .1, .1), STAIR * .85)
	# Landing ends: guard sheets at x ends, full width.
	for i: int in range(1, FLOORS + 1):
		var y := _floor_y(i - 1)
		_end_guard(ax0, y, zi0, zo1)
		if i < FLOORS + 1 and i <= FLOORS - 1:
			_end_guard(bx1, y + PITCH * .5, zi0, zo1)
	_end_guard(bx1, GROUND * .5, zi0, zo1)

func _landing(x0: float, x1: float, y: float, z0: float, z1: float) -> void:
	_bar("steel", _front, (x0 + x1) * .5, y - .04, (z0 + z1) * .5, Vector3(x1 - x0, .08, z0 - z1), STAIR)

func _flight(xa: float, xb: float, ya: float, yb: float, z0: float, z1: float) -> void:
	var f := _front
	var steps := 8
	var zc := (z0 + z1) * .5
	for s: float in [z0 - .03, z1 + .03]:
		_kit.beam("steel", f * Vector3(xa, ya - .1, s), f * Vector3(xb, yb - .1, s), .06, .2, Vector3.UP, STAIR * .9)
	for k: int in range(steps):
		var t := (float(k) + .5) / float(steps)
		var x := lerpf(xa, xb, t)
		var y := lerpf(ya, yb, (float(k) + 1.0) / float(steps)) - .02
		_bar("steel", f, x, y, zc, Vector3(absf(xb - xa) / float(steps) + .02, .03, z0 - z1 - .06), STAIR)

func _guard(from: Vector3, to: Vector3) -> void:
	# A raked sheet from one landing to the next, its handrail on top; both sides drawn.
	var up := Vector3.UP * 1.1
	var tint := STAIR * 1.05
	if from.x < to.x:
		_kit.quad("steel", to, to + up, from + up, from, tint, .8, 1.0, .6)
		_kit.quad("steel", from, from + up, to + up, to, tint * .8, .8, 1.0)
	else:
		_kit.quad("steel", from, from + up, to + up, to, tint, .8, 1.0, .6)
		_kit.quad("steel", to, to + up, from + up, from, tint * .8, .8, 1.0)
	_kit.beam("steel", from + up, to + up, .06, .06, Vector3.UP, STAIR * .7)

func _end_guard(x: float, y: float, z0: float, z1: float) -> void:
	var f := _front
	_bar("steel", f, x, y + .55, (z0 + z1) * .5, Vector3(.03, 1.1, z0 - z1), STAIR * 1.05)

# ---------------------------------------------------------------- roof

func _roof() -> void:
	var f := _front
	var t := .2
	_kit.quad("concrete", f * Vector3(t, ROOF, -t), f * Vector3(t, ROOF, -DEEP + t), f * Vector3(WIDE - t, ROOF, -DEEP + t), f * Vector3(WIDE - t, ROOF, -t), Color("#8a8882"), .8, .8)
	# Parapet insides and coping round the sides and back.
	var inner := Color("#a8a49a")
	_kit.quad("concrete", f * Vector3(WIDE - t, ROOF, -t), f * Vector3(WIDE - t, PARAPET, -t), f * Vector3(t, PARAPET, -t), f * Vector3(t, ROOF, -t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(WIDE - t, ROOF, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -t), f * Vector3(WIDE - t, ROOF, -t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(t, ROOF, -t), f * Vector3(t, PARAPET, -t), f * Vector3(t, PARAPET, -DEEP + t), f * Vector3(t, ROOF, -DEEP + t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(t, ROOF, -DEEP + t), f * Vector3(t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, ROOF, -DEEP + t), inner, .7, 1.0)
	for x: float in [.1, WIDE - .1]:
		_bar("concrete", f, x, PARAPET + .04, -DEEP * .5, Vector3(.3, .08, DEEP), Color("#9a968e"))
	_bar("concrete", f, WIDE * .5, PARAPET + .04, -DEEP + .1, Vector3(WIDE, .08, .3), Color("#9a968e"))
	# 2050: PV film laminated on the outside of both side parapets.
	for face: Transform3D in [_west, _east]:
		_kit.quad("solar", face * Vector3(.7, ROOF + .2, .014), face * Vector3(.7, PARAPET - .12, .014), face * Vector3(DEEP - .7, PARAPET - .12, .014), face * Vector3(DEEP - .7, ROOF + .2, .014), Color(.04, .06, .11))
	# Penthouse over the lift and the stair.
	var px0 := .35
	var px1 := 3.7
	var pz0 := -8.6
	var pz1 := -12.9
	var ph := ROOF + 3.0
	var wall := PAINT * .92
	_kit.quad("render", f * Vector3(px0, ROOF, pz0), f * Vector3(px0, ph, pz0), f * Vector3(px1, ph, pz0), f * Vector3(px1, ROOF, pz0), wall, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px1, ROOF, pz0), f * Vector3(px1, ph, pz0), f * Vector3(px1, ph, pz1), f * Vector3(px1, ROOF, pz1), wall * .95, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px0, ROOF, pz1), f * Vector3(px0, ph, pz1), f * Vector3(px0, ph, pz0), f * Vector3(px0, ROOF, pz0), wall * .95, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px1, ROOF, pz1), f * Vector3(px1, ph, pz1), f * Vector3(px0, ph, pz1), f * Vector3(px0, ROOF, pz1), wall * .9, .8, 1.0, .9)
	_kit.quad("concrete", f * Vector3(px0 - .05, ph, pz0 + .05), f * Vector3(px0 - .05, ph, pz1 - .05), f * Vector3(px1 + .05, ph, pz1 - .05), f * Vector3(px1 + .05, ph, pz0 + .05), Color("#7a7872"), .9, .9)
	_bar("concrete", f, (px0 + px1) * .5, ph + .08, pz0, Vector3(px1 - px0 + .1, .16, .12), Color("#9a968e"))
	_bar("steel", f, 2.9, ROOF + 1.0, pz0 + .02, Vector3(.85, 2.0, .04), Color("#7a8078"))
	_bar("metal", f, 1.3, ROOF + 2.3, pz0 + .03, Vector3(.6, .4, .04), Color("#5a5c58"))
	for k: int in range(5):
		_bar("metal", f, 1.3, ROOF + 2.14 + float(k) * .08, pz0 + .06, Vector3(.56, .02, .04), Color("#8a8c88"))
	# Drone pad on the penthouse, the drop locker beside it, lights at its corners.
	var pc := Vector2(2.0, -10.9)
	_kit.atlas("paint", f * Vector3(pc.x - 1.1, ph + .012, pc.y + 1.1), f * Vector3(pc.x - 1.1, ph + .012, pc.y - 1.1), f * Vector3(pc.x + 1.1, ph + .012, pc.y - 1.1), f * Vector3(pc.x + 1.1, ph + .012, pc.y + 1.1), _cell(1780, 1250, 260, 260))
	for c: Vector2 in [Vector2(-1.15, 1.15), Vector2(1.15, 1.15), Vector2(-1.15, -1.15), Vector2(1.15, -1.15)]:
		_bar("led", f, pc.x + c.x, ph + .04, pc.y + c.y, Vector3(.06, .05, .06), AMBER * .8)
	_bar("metal", f, 3.35, ph + .35, -9.1, Vector3(.5, .7, .5), Color("#3c4044"))
	_strip(f * Vector3(3.1, ph + .72, -8.84), f * Vector3(3.6, ph + .72, -8.84), CYAN * .6)
	_status(f, 3.5, ph + .5, -8.84, GREEN)
	_kit.tube("metal", [f * Vector3(.6, ph, -12.6), f * Vector3(.6, ph + 3.0, -12.6)], .03, ALUMINIUM, 5)
	_kit.tube("metal", [f * Vector3(.2, ph + 2.4, -12.6), f * Vector3(1.0, ph + 2.4, -12.6)], .008, ALUMINIUM, 3)
	_status(f, .6, ph + 3.04, -12.6, Color(1.0, .2, .15))
	# Panel water tank on its steel stand.
	var tx0 := 4.25
	var tx1 := 6.35
	var tz0 := -9.4
	var tz1 := -12.4
	var base := ROOF + 1.0
	for x: float in [tx0 + .1, tx1 - .1]:
		for z: float in [tz0 - .1, tz1 + .1]:
			_bar("steel", f, x, ROOF + .5, z, Vector3(.1, 1.0, .1), STAIR * .7)
	_bar("steel", f, (tx0 + tx1) * .5, base - .05, (tz0 + tz1) * .5, Vector3(tx1 - tx0, .1, tz0 - tz1), STAIR * .7)
	_bar("plain", f, (tx0 + tx1) * .5, base + .75, (tz0 + tz1) * .5, Vector3(tx1 - tx0 - .1, 1.5, tz0 - tz1 - .1), Color("#c4ccc6"))
	for k: int in range(1, 3):
		_bar("plain", f, tx0 + (tx1 - tx0) * float(k) / 3.0, base + .75, tz0 - .04, Vector3(.04, 1.5, .04), Color("#aab2ac"))
		_bar("plain", f, tx1 - .04, base + .75, tz0 - (tz0 - tz1) * float(k) / 3.0, Vector3(.04, 1.5, .04), Color("#aab2ac"))
	_bar("plain", f, (tx0 + tx1) * .5, base + .75, tz0 - .04, Vector3(tx1 - tx0 - .1, .04, .04), Color("#aab2ac"))
	_kit.tube("metal", [f * Vector3(tx0 + .4, ROOF, tz0 + .1), f * Vector3(tx0 + .4, base + 1.5, tz0 + .1)], .02, Color("#6a6c6a"), 4)
	_kit.tube("metal", [f * Vector3(tx0 + .7, ROOF, tz0 + .1), f * Vector3(tx0 + .7, base + 1.5, tz0 + .1)], .02, Color("#6a6c6a"), 4)
	for k: int in range(8):
		_kit.tube("metal", [f * Vector3(tx0 + .4, ROOF + .3 + float(k) * .3, tz0 + .1), f * Vector3(tx0 + .7, ROOF + .3 + float(k) * .3, tz0 + .1)], .012, Color("#6a6c6a"), 3)
	# Roof units.
	var roof := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, ROOF, 0))
	for x: float in [1.4, 2.5]:
		_bar("metal", roof, x, .06, -5.2, Vector3(.9, .12, .46), STEEL)
		_ac(roof.translated_local(Vector3(0, 0, -5.4)), x, .44)
	# Roof sign: a steel frame stood on the front parapet, the box lit from inside.
	var sy0 := PARAPET + .5
	var sy1 := sy0 + 1.55
	var sz := -.75
	_bar("metal", f, WIDE * .5, (sy0 + sy1) * .5, sz - .16, Vector3(6.3, sy1 - sy0 + .08, .3), Color("#1d2f5a"))
	_panel("sign", f, .35, 6.55, sy0, sy1, sz + .003, _cell(240, 0, 1200, 300))
	for x: float in [.7, 2.5, 4.4, 6.2]:
		_bar("steel", f, x, (ROOF + sy1) * .5, sz - .4, Vector3(.1, sy1 - ROOF, .1), STAIR * .7)
		_kit.beam("steel", f * Vector3(x, ROOF, -3.2), f * Vector3(x, sy1 - .2, sz - .4), .07, .07, Vector3.UP, STAIR * .7)
	_bar("steel", f, WIDE * .5, sy0 - .15, sz - .4, Vector3(6.0, .08, .08), STAIR * .7)
	_bar("steel", f, WIDE * .5, sy1 + .06, sz - .3, Vector3(6.3, .06, .5), STAIR * .7)

# ---------------------------------------------------------------- pavement

func _pavement() -> void:
	var f := _front
	# A-board by the door: the prices, both faces.
	var ax := 3.9
	var az := .95
	var hw := .26
	var cell := _cell(1460, 0, 420, 640)
	_kit.atlas("board", f * Vector3(ax - hw, .06, az + .24), f * Vector3(ax - hw, .86, az + .02), f * Vector3(ax + hw, .86, az + .02), f * Vector3(ax + hw, .06, az + .24), cell)
	_kit.atlas("board", f * Vector3(ax + hw, .06, az - .24), f * Vector3(ax + hw, .86, az - .02), f * Vector3(ax - hw, .86, az - .02), f * Vector3(ax - hw, .06, az - .24), cell)
	for x: float in [ax - hw - .015, ax + hw + .015]:
		for s: float in [1.0, -1.0]:
			_kit.beam("metal", f * Vector3(x, 0, az + s * .27), f * Vector3(x, .9, az), .025, .025, Vector3.UP, Color("#3a3c3e"))
	_kit.beam("metal", f * Vector3(ax - hw, .9, az), f * Vector3(ax + hw, .9, az), .03, .03, Vector3.UP, Color("#3a3c3e"))
	# Two potted shrubs either side of the door.
	for x: float in [.6, 2.55]:
		var pot := f * Vector3(x, 0, .3)
		_kit.lathe("plain", pot, [Vector2(.17, 0), Vector2(.2, .42), Vector2(.21, .44)], Color("#4a4440"), 10)
		_plant(pot + Vector3.UP * .42, .7, Color("#3a5e30"))
		_plant(pot + Vector3.UP * .44, .5, Color("#4c6e3a"))
