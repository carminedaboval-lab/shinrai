extends "res://scripts/midori_near_city_handmade.gd"
## 第二銀鈴ビル: a six-storey 飲み屋ビル on a six-and-a-half-metre corner lot, 1984. Tired grey-green
## 二丁掛 tile to the street, render on the flanks. Ten small bars stacked over a 立ち飲み, their lit
## acrylic names on a steel frame up the east corner, a narrow tiled hall with the mailboxes, a
## two-person lift and a steep stair; a steel fire stair down the back, a drone ledge on the roof.
const ATLAS := "res://assets/shinrai/near_city/snack_atlas.png"
const WIDE := 6.5
const DEEP := 9.6
const GROUND := 3.5
const PITCH := 2.8
const FLOORS := 5
const ROOF := GROUND + PITCH * FLOORS
const PARAPET := ROOF + .75
const IZ_X0 := .3
const IZ_X1 := 4.1
const IZ_TOP := 2.5
const IZ_DEEP := 6.4
const HALL_X0 := 4.45
const HALL_X1 := 5.65
const HALL_TOP := 2.4
const HALL_DEEP := 6.6
const WELL_TOP := 4.2
const STAIR_Z := -3.2
const STACK_X := 6.2
const STACK_Z0 := .13
const STACK_Z1 := 1.03
const TILE := Color("#8e968a")
const DARK_TILE := Color("#646c62")
const PAINT := Color("#b9b2a2")
const STAIR := Color("#5e6a70")
const ALU := Color("#a4a6a2")
const WOOD := Color("#5a3e2a")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1984
	_build_looks()
	_front_wall()
	_izakaya_front()
	_izakaya_room()
	_hall()
	_upper_windows()
	_sign_stack()
	_side_walls()
	_back_stair()
	_roof()
	_pavement()
	_kit.commit(self, _looks, ["front", "decal", "paint", "hall_decal", "lamp", "led", "sign", "sign_dim", "sign_off", "lit", "screen", "eink", "lantern", "paper", "hall", "hall_tile", "hall_wall", "hall_board", "izk", "izk_wood", "izk_plaster", "izk_floor", "izk_board", "cold", "noren", "fascia"])
	_kit = null
	_omni("SnackIzakaya", _front * Vector3(2.0, 2.2, -1.6), Color(1.0, .78, .52), .8, 5.5)
	_omni("SnackLantern", _front * Vector3(.9, 1.9, .9), Color(1.0, .5, .3), .45, 3.6)
	_omni("SnackHall", _front * Vector3(5.05, 2.15, -1.3), Color(.86, .92, 1.0), .4, 3.8)

# ---------------------------------------------------------------- looks

func _atlas_look(name: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _lit_look(name: String, rough: float, glow: float, day: float, metal := 0.0) -> void:
	var look := _look("", 1.0, rough, metal)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _lit_tex(name: String, texture: String, tile: float, rough: float, glow: float, day: float, chroma := .45) -> void:
	var look := _look(texture, tile, rough)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	look.set_shader_parameter("chroma", chroma)
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
	_looks.tile.set_shader_parameter("tile_size", Vector2(.227, .06))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .4)
	_looks.concrete = _look("precast_concrete_wall", 2.0, .9)
	_looks.concrete.set_shader_parameter("chroma", .3)
	_looks.stone = _look("concrete_tile_facade", 1.2, .5)
	_looks.steel = _look("rusty_painted_metal", 1.6, .8)
	_looks.steel.set_shader_parameter("chroma", .35)
	_looks.wood = _look("japanese_cedar_planks", 1.0, .8)
	_looks.wood.set_shader_parameter("chroma", .5)
	_looks.tin = _look("worn_corrugated_iron", 1.2, .6, .25)
	_looks.tin.set_shader_parameter("chroma", .45)
	_atlas_look("sign", .35, 1.6, .1)
	_atlas_look("sign_dim", .35, .42, .06)
	_atlas_look("sign_off", .4, .03, .03)
	_atlas_look("lit", .9, .5, 0.0)
	_atlas_look("film", .4, 0.0, 0.0)
	_atlas_look("board", .7, .03, .03)
	_atlas_look("fascia", .6, .14, .03)
	_atlas_look("eink", .7, .1, .02)
	_atlas_look("screen", .3, .9, .3)
	_atlas_look("lantern", .7, 1.5, .06)
	_atlas_look("paper", .8, .9, .04)
	_atlas_look("noren", .9, .1, .03)
	_atlas_look("hall_board", .5, .3, .1)
	_atlas_look("izk_board", .7, .32, .1)
	_lit_look("hall", .6, .28, .1)
	_lit_tex("hall_tile", "square_tiled_wall", 1.0, .35, .3, .1, .35)
	_lit_tex("hall_wall", "white_stucco", 2.5, .9, .3, .1, .4)
	_lit_look("izk", .6, .3, .1)
	_lit_tex("izk_wood", "japanese_cedar_planks", 1.0, .8, .3, .1, .5)
	_lit_tex("izk_plaster", "plastered_wall_03", 2.0, .9, .32, .1, .4)
	_lit_tex("izk_floor", "precast_concrete_wall", 2.0, .8, .24, .1, .3)
	_lit_look("cold", .4, .6, .2)
	_decal_look("decal", .3, .1)
	_decal_look("hall_decal", .3, .1)
	_decal_look("paint", 0.0, 0.0)

# ---------------------------------------------------------------- helpers

func _px(x: float, y: float, w: float, h: float) -> Rect2:
	return _cell(x, y, w, h)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _flat(part: String, face: Transform3D, area: Rect2, z: float, tint: Color, low := .9, streak := .6) -> void:
	_kit.quad(part, face * Vector3(area.position.x, area.position.y, z), face * Vector3(area.position.x, area.end.y, z), face * Vector3(area.end.x, area.end.y, z), face * Vector3(area.end.x, area.position.y, z), tint, low, 1.0, streak, Vector2(area.position.x, -area.position.y))

func _west_side(part: String, x: float, z0: float, z1: float, y0: float, y1: float, rect: Rect2, tint := Color.WHITE) -> void:
	# A panel on a wall that faces +X (seen from the east): z0 is the nearer end.
	var f := _front
	_kit.atlas(part, f * Vector3(x, y0, z0), f * Vector3(x, y1, z0), f * Vector3(x, y1, z1), f * Vector3(x, y0, z1), rect, tint)

func _east_side(part: String, x: float, z0: float, z1: float, y0: float, y1: float, rect: Rect2, tint := Color.WHITE) -> void:
	# A panel on a wall that faces -X (seen from the west): z0 is the nearer end.
	var f := _front
	_kit.atlas(part, f * Vector3(x, y0, z1), f * Vector3(x, y1, z1), f * Vector3(x, y1, z0), f * Vector3(x, y0, z0), rect, tint)

func _floor_y(i: int) -> float:
	return GROUND + float(i) * PITCH

func _frame(face: Transform3D, r: Rect2, z: float, tint: Color, mullion: bool) -> void:
	var cx := r.get_center().x
	var cy := r.get_center().y
	_bar("metal", face, cx, r.end.y - .02, z, Vector3(r.size.x, .04, .06), tint)
	_bar("metal", face, cx, r.position.y + .02, z, Vector3(r.size.x, .04, .06), tint)
	_bar("metal", face, r.position.x + .02, cy, z, Vector3(.04, r.size.y, .06), tint)
	_bar("metal", face, r.end.x - .02, cy, z, Vector3(.04, r.size.y, .06), tint)
	if mullion:
		_bar("metal", face, cx, cy, z - .01, Vector3(.035, r.size.y, .05), tint)

func _ac(face: Transform3D, x: float, y: float) -> void:
	# Condenser on a wall bracket: case, fan, guard cross, the pipes going in.
	_bar("metal", face, x, y, .22, Vector3(.78, .58, .28), Color("#c4c4ba"))
	_kit.disc("plain", face * Vector3(x - .1, y, .362), face.basis.x, face.basis.y, .2, Color("#26272a"))
	_bar("metal", face, x - .1, y, .366, Vector3(.4, .015, .008), Color("#8f908c"))
	_bar("metal", face, x - .1, y, .366, Vector3(.015, .4, .008), Color("#8f908c"))
	_bar("metal", face, x, y - .32, .22, Vector3(.88, .04, .38), Color("#3a3a38"))
	for xx: float in [x - .34, x + .34]:
		_kit.beam("metal", face * Vector3(xx, y - .32, .38), face * Vector3(xx, y - .78, .02), .03, .03, Vector3.UP, Color("#3a3a38"))
	_kit.tube("plain", [face * Vector3(x + .3, y - .1, .2), face * Vector3(x + .5, y - .1, .2), face * Vector3(x + .5, y + .5, .06)], .025, Color("#d8d4c4"), 5)
	_panel("paint", face, x - .25, x + .25, y - 1.9, y - .36, .006, _px(1620, 910, 100, 220))

# ---------------------------------------------------------------- street face

func _front_openings() -> Array:
	# Per floor, the two windows and what is behind each: [rect, cell index, part, tint].
	var out: Array = []
	var y := _floor_y(0)
	out.append([[Rect2(.7, y + .95, 1.2, 1.1), 1, "lit", .75], [Rect2(2.9, y + .95, 1.2, 1.1), 5, "film", .75]])
	y = _floor_y(1)
	out.append([[Rect2(.75, y + 1.0, 1.6, 1.0), 0, "lit", 1.0], [Rect2(3.3, y + 1.0, .85, 1.0), 7, "film", .9]])
	y = _floor_y(2)
	out.append([[Rect2(.7, y + .95, 1.3, 1.1), 2, "lit", .7], [Rect2(3.0, y + .95, 1.1, 1.1), 6, "film", .8]])
	y = _floor_y(3)
	out.append([[Rect2(1.0, y + 1.0, 1.1, 1.0), 3, "film", 1.0], [Rect2(3.1, y + .95, 1.1, 1.1), 1, "lit", .42]])
	y = _floor_y(4)
	out.append([[Rect2(.8, y + 1.0, 1.2, 1.0), 0, "lit", .38], [Rect2(3.0, y + 1.0, 1.3, 1.1), 4, "film", .85]])
	return out

func _front_wall() -> void:
	var f := _front
	var holes: Array[Rect2] = []
	for row: Array in _front_openings():
		for w: Array in row:
			holes.append((w[0] as Rect2).grow(.05))
	for piece: Rect2 in _minus(Rect2(0, GROUND, WIDE, ROOF - .3 - GROUND), holes):
		var tone := _rng.randf_range(.95, 1.03)
		_flat("tile", f, piece, 0.0, Color(TILE.r * tone, TILE.g * tone, TILE.b * tone), .88, .75)
	# Ground floor piers and the bands over the two openings.
	for r: Rect2 in [Rect2(0, 0, IZ_X0, GROUND), Rect2(IZ_X1, 0, HALL_X0 - IZ_X1, GROUND), Rect2(HALL_X1, 0, WIDE - HALL_X1, GROUND), Rect2(IZ_X0, IZ_TOP, IZ_X1 - IZ_X0, GROUND - IZ_TOP), Rect2(HALL_X0, HALL_TOP, HALL_X1 - HALL_X0, GROUND - HALL_TOP)]:
		_flat("tile", f, r, 0.0, TILE * .97, .8, .5)
	# Dark skirting of granite-look tile where the mops and the bikes hit.
	for r: Array in [[0.0, IZ_X0], [IZ_X1, HALL_X0], [HALL_X1, WIDE]]:
		_bar("stone", f, (r[0] + r[1]) * .5, .2, .012, Vector3(r[1] - r[0], .4, .024), Color("#4a4a48"))
	# Crown band, coping, the slab course at each floor.
	_bar("tile", f, WIDE * .5, (ROOF - .3 + PARAPET) * .5, .035, Vector3(WIDE, PARAPET - ROOF + .3, .07), DARK_TILE, .9, 1.0)
	_bar("concrete", f, WIDE * .5, PARAPET + .04, -.06, Vector3(WIDE + .04, .08, .3), Color("#9a968e"))
	for i: int in range(1, FLOORS):
		_bar("tile", f, WIDE * .5, _floor_y(i) + .04, .015, Vector3(WIDE, .09, .03), DARK_TILE)
	_bar("tile", f, WIDE * .5, GROUND - .02, .03, Vector3(WIDE, .12, .06), DARK_TILE)
	# Downpipe on the west corner, fibre up the east pier behind the stack.
	_kit.tube("metal", [f * Vector3(.12, PARAPET - .1, .12), f * Vector3(.12, .15, .12), f * Vector3(.12, .05, .3)], .045, Color("#8a8476"), 7)
	for k: int in range(6):
		_bar("metal", f, .12, 1.5 + float(k) * 3.0, .06, Vector3(.12, .04, .1), Color("#5a5652"))
	_fibre([f * Vector3(5.75, ROOF - .2, .08), f * Vector3(5.75, 3.0, .08), f * Vector3(5.9, 2.7, .08), f * Vector3(5.9, .4, .08)])
	# Front condensers on brackets under two of the windows, a stain run below each.
	_ac(f, 4.75, _floor_y(0) + .55)
	_ac(f, 4.75, _floor_y(2) + .55)
	_ac(f, 2.5, _floor_y(3) + .55)
	# Lit floor numbers on the east pier.
	for i: int in range(FLOORS):
		var y := _floor_y(i) + 1.9
		_bar("metal", f, 5.86, y + .14, .03, Vector3(.32, .32, .06), Color("#2a2a2c"))
		_panel("sign_dim" if i == 3 else "sign", f, 5.71, 6.01, y, y + .3, .061, _px(1090 + float(i) * 100.0, 530, 96, 96))
	# Electricity meters on the middle pier, and the directory over them.
	_bar("plain", f, (IZ_X1 + HALL_X0) * .5, .7, .06, Vector3(.24, .3, .12), Color("#8a8c88"))
	_bar("plain", f, (IZ_X1 + HALL_X0) * .5, .74, .121, Vector3(.16, .1, .004), Color("#1a1c1c"))
	_bar("metal", f, (IZ_X1 + HALL_X0) * .5, 1.5, .03, Vector3(.34, .58, .06), Color("#1a1a1c"))
	_panel("hall_board", f, IZ_X1 + .025, HALL_X0 - .025, 1.22, 1.78, .062, _px(1440, 0, 300, 520))

# ---------------------------------------------------------------- the 立ち飲み

func _izakaya_front() -> void:
	var f := _front
	# 腰板: cedar boards under the window.
	var wx0 := IZ_X0
	var wx1 := 1.95
	_bar("wood", f, (wx0 + wx1) * .5, .43, -.02, Vector3(wx1 - wx0, .86, .06), WOOD * 1.25)
	for k: int in range(1, 6):
		_bar("wood", f, wx0 + (wx1 - wx0) * float(k) / 6.0, .43, .015, Vector3(.025, .8, .02), WOOD * .8)
	_bar("wood", f, (wx0 + wx1) * .5, .88, .02, Vector3(wx1 - wx0 + .04, .05, .14), WOOD)
	# Window over it: glass behind a wood frame of four lights.
	var r := Rect2(wx0, .9, wx1 - wx0, 1.45)
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, -.06), f * Vector3(r.position.x, r.end.y, -.06), f * Vector3(r.end.x, r.end.y, -.06), f * Vector3(r.end.x, r.position.y, -.06), Color.WHITE)
	for k: int in range(5):
		_bar("wood", f, wx0 + .03 + (wx1 - wx0 - .06) * float(k) / 4.0, r.get_center().y, -.03, Vector3(.05, r.size.y, .06), WOOD)
	for y: float in [r.position.y + .02, 1.7, r.end.y - .03]:
		_bar("wood", f, (wx0 + wx1) * .5, y, -.03, Vector3(wx1 - wx0, .05, .06), WOOD)
	# Taped inside the glass: happy hour, open hours.
	_panel("izk_board", f, 1.2, 1.86, .98, 1.38, -.09, _px(310, 1870, 280, 170))
	_panel("izk_board", f, .42, .98, 1.78, 2.1, -.09, _px(600, 1870, 300, 170))
	# Header over the doorway and the posts either side.
	_bar("wood", f, (wx1 + IZ_X1) * .5, 2.35, -.02, Vector3(IZ_X1 - wx1, .3, .1), WOOD)
	_bar("wood", f, wx1 + .12, 1.1, -.02, Vector3(.24, 2.2, .1), WOOD * 1.1)
	_bar("wood", f, IZ_X1 - .09, 1.1, -.02, Vector3(.18, 2.2, .1), WOOD * 1.1)
	_bar("wood", f, (wx1 + IZ_X1) * .5, .015, -.05, Vector3(IZ_X1 - wx1, .03, .2), Color("#3a3634"))
	# Sliding doors: the left leaf run back behind the right, the doorway open under the noren.
	for leaf: Array in [[3.0, 3.9, -.12], [2.93, 3.83, -.05]]:
		var a: float = leaf[0]
		var b: float = leaf[1]
		var z: float = leaf[2]
		_kit.quad("front", f * Vector3(a, .1, z), f * Vector3(a, 2.15, z), f * Vector3(b, 2.15, z), f * Vector3(b, .1, z), Color.WHITE)
		for x: float in [a + .025, b - .025]:
			_bar("wood", f, x, 1.1, z, Vector3(.05, 2.2, .04), WOOD * .9)
		for y: float in [.06, .9, 2.17]:
			_bar("wood", f, (a + b) * .5, y, z, Vector3(b - a, .05 if y > .1 else .12, .04), WOOD * .9)
	# Noren: three indigo panels on a rod, a hand's gap between them.
	var nx0 := 2.18
	var nw := .54
	_kit.tube("metal", [f * Vector3(nx0 - .08, 2.2, .14), f * Vector3(nx0 + nw * 3.0 + .1, 2.2, .14)], .015, Color("#2a2622"), 5)
	for k: int in range(3):
		var x0 := nx0 + float(k) * (nw + .015)
		var cell := _px(460 + float(k) * 213.3, 1400, 213, 260)
		var sway := float(k - 1) * .012
		_kit.atlas("noren", f * Vector3(x0, 1.46, .13 + sway), f * Vector3(x0, 2.19, .14), f * Vector3(x0 + nw, 2.19, .14), f * Vector3(x0 + nw, 1.46, .13 + sway), cell)
		_kit.atlas("noren", f * Vector3(x0 + nw, 1.46, .125 + sway), f * Vector3(x0 + nw, 2.19, .135), f * Vector3(x0, 2.19, .135), f * Vector3(x0, 1.46, .125 + sway), cell, Color(.7, .7, .75))
	# Tin eave on two brackets, a strip light under its edge.
	var ey0 := 2.62
	var ey1 := 2.5
	var out := .72
	var x0 := IZ_X0 - .1
	var x1 := IZ_X1 + .05
	_kit.quad("tin", f * Vector3(x0, ey1, out), f * Vector3(x0, ey0, 0), f * Vector3(x1, ey0, 0), f * Vector3(x1, ey1, out), Color("#8a8478"), .9, 1.0, .6)
	_kit.quad("tin", f * Vector3(x0, ey0 - .03, 0), f * Vector3(x0, ey1 - .03, out), f * Vector3(x1, ey1 - .03, out), f * Vector3(x1, ey0 - .03, 0), Color("#6a665e"), .7, .7)
	_bar("metal", f, (x0 + x1) * .5, ey1 - .03, out, Vector3(x1 - x0, .09, .03), Color("#4a4642"))
	for bx: float in [x0 + .2, x1 - .2]:
		_kit.beam("metal", f * Vector3(bx, ey1 - .05, out - .05), f * Vector3(bx, ey0 - .4, .02), .03, .03, Vector3.UP, Color("#3a3836"))
	_strip(f * Vector3(x0 + .3, ey1 - .085, out - .08), f * Vector3(x1 - .3, ey1 - .085, out - .08), Color(1.0, .78, .5))
	# Name board over the eave, two little goose-neck lamps on it.
	_bar("wood", f, 2.22, 3.0, .03, Vector3(3.68, .68, .06), Color("#3a2618"))
	_panel("fascia", f, .4, 4.04, 2.69, 3.29, .062, _px(0, 1710, 900, 150))
	for lx: float in [1.2, 3.2]:
		_kit.tube("metal", [f * Vector3(lx, 3.32, .06), f * Vector3(lx, 3.45, .2), f * Vector3(lx, 3.42, .34)], .012, Color("#2a2a2a"), 4)
		_kit.lathe("metal", f * Vector3(lx, 3.34, .36), [Vector2(.02, .08), Vector2(.07, 0)], Color("#2a2a2a"), 8)
		_kit.disc("lamp", f * Vector3(lx, 3.338, .36), Vector3.RIGHT, Vector3.BACK, .055, Color(1.0, .86, .6))
	# 赤提灯 from the eave at the west end, and a second, smaller one by the door.
	_red_lantern(Vector3(.75, 1.72, .5), 1.0)
	_red_lantern(Vector3(1.82, 1.98, .55), .72)

func _red_lantern(at: Vector3, s: float) -> void:
	var f := _front
	var base := f * at
	var profile: Array[Vector2] = []
	for k: int in range(9):
		var t := float(k) / 8.0
		profile.append(Vector2((.11 + .12 * sin(t * PI)) * s, t * .72 * s))
	_kit.lathe("lantern", base, profile, Color.WHITE, 14, _px(1110, 1416, 256, 268))
	_kit.lathe("plain", base + Vector3.DOWN * .04 * s, [Vector2(.11 * s, 0), Vector2(.115 * s, .05 * s)], Color("#1a1414"), 12)
	_kit.lathe("plain", base + Vector3.UP * .7 * s, [Vector2(.11 * s, 0), Vector2(.115 * s, .05 * s)], Color("#1a1414"), 12)
	_kit.tube("plain", [base + Vector3.UP * .75 * s, base + Vector3(0, 2.6 - at.y, 0)], .006, Color("#1a1a1a"), 3)

func _izakaya_room() -> void:
	var f := _front
	var x0 := IZ_X0 + .02
	var x1 := IZ_X1 - .02
	var near := 0.0
	var far := -IZ_DEEP
	var top := 2.7
	_kit.quad("izk_floor", f * Vector3(x0, .02, near), f * Vector3(x0, .02, far), f * Vector3(x1, .02, far), f * Vector3(x1, .02, near), Color("#7a7068"), .8, .8)
	_kit.quad("izk_wood", f * Vector3(x0, top, far), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, far), Color("#6a4a32"), .7, .7)
	_kit.quad("izk_plaster", f * Vector3(x0, 0, near), f * Vector3(x0, top, near), f * Vector3(x0, top, far), f * Vector3(x0, 0, far), Color("#d8c8a0"), .7, 1.0)
	_kit.quad("izk_plaster", f * Vector3(x1, 0, far), f * Vector3(x1, top, far), f * Vector3(x1, top, near), f * Vector3(x1, 0, near), Color("#d0c098"), .7, 1.0)
	_kit.quad("izk_plaster", f * Vector3(x0, 0, far), f * Vector3(x0, top, far), f * Vector3(x1, top, far), f * Vector3(x1, 0, far), Color("#c8b890"), .7, 1.0)
	# Smoke-browned wainscot and the drinking ledge along the west wall.
	_kit.quad("izk_wood", f * Vector3(x0 + .005, 0, near), f * Vector3(x0 + .005, .95, near), f * Vector3(x0 + .005, .95, far), f * Vector3(x0 + .005, 0, far), Color("#7a5a3a"), .7, 1.0)
	_bar("izk_wood", f, x0 + .14, 1.08, (near + far) * .5 - .3, Vector3(.28, .05, (near - far) - 1.0), Color("#8a6040"))
	# Menu strips round the walls.
	for z: float in [-.6, -2.4]:
		_west_side("izk_board", x0 + .01, z, z - 1.75, 1.95, 2.45, _px(1180, 1710, 560, 160))
	_panel("izk_board", f, .5, 2.25, 1.95, 2.45, far + .01, _px(1180, 1710, 560, 160))
	# The counter, front to back, the kitchen behind it to the east.
	var cx0 := 2.5
	var cx1 := 2.95
	var cz0 := -1.4
	var cz1 := -5.9
	_bar("izk_wood", f, (cx0 + cx1) * .5, .5, (cz0 + cz1) * .5, Vector3(cx1 - cx0, 1.0, cz0 - cz1), Color("#5a3a26"))
	_bar("izk_wood", f, (cx0 + cx1) * .5 - .04, 1.03, (cz0 + cz1) * .5, Vector3(cx1 - cx0 + .14, .06, cz0 - cz1 + .06), Color("#a07a50"))
	_bar("izk", f, cx0 - .01, .08, (cz0 + cz1) * .5, Vector3(.02, .16, cz0 - cz1), Color("#2a1e16"))
	# On the counter: glasses, a jug, a dish of edamame, the soy and the shichimi.
	for k: int in range(5):
		var z := cz0 - .4 - float(k) * .85
		_kit.lathe("bottle", f * Vector3(cx0 + .12, 1.06, z), [Vector2(.03, 0), Vector2(.035, .12)], Color("#c8d0c8"), 8)
		_bar("izk", f, cx0 + .2, 1.075, z - .25, Vector3(.14, .03, .1), Color("#d8d0c0"))
	_kit.lathe("izk", f * Vector3(cx0 + .2, 1.06, -3.3), [Vector2(.04, 0), Vector2(.05, .14), Vector2(.02, .18)], Color("#e8e0d0"), 8)
	# Kitchen: the yakitori grill on its stand with the coals glowing, a hood over it.
	var gx := 3.5
	var gz := -2.2
	_bar("izk", f, gx, .45, gz, Vector3(.9, .9, .4), Color("#8a8c88"))
	_bar("izk", f, gx, .93, gz, Vector3(.9, .06, .3), Color("#3a3a38"))
	_bar("led", f, gx, .965, gz, Vector3(.8, .01, .2), Color(1.0, .38, .1))
	for k: int in range(8):
		_kit.beam("izk", f * Vector3(gx - .35 + float(k) * .1, 1.0, gz - .16), f * Vector3(gx - .35 + float(k) * .1, 1.0, gz + .16), .02, .02, Vector3.UP, Color("#8a5a30"))
	_bar("izk", f, gx, 2.35, gz, Vector3(1.0, .5, .7), Color("#a8aaa8"))
	_bar("izk", f, gx, 2.6, gz - .2, Vector3(.3, .2, .3), Color("#8a8c8a"))
	_bar("izk", f, 3.5, .45, -4.0, Vector3(1.0, .9, .6), Color("#b8bab8"))
	_bar("izk", f, 3.5, .93, -4.0, Vector3(1.0, .04, .62), Color("#d8dad8"))
	_kit.lathe("izk", f * Vector3(3.3, .95, -4.0), [Vector2(.16, 0), Vector2(.17, .22)], Color("#9a9c9a"), 10)
	# Back wall: bottle shelf over a drinks fridge, a kept-bottle shelf.
	_panel("izk_board", f, 2.6, 4.05, 1.4, 2.06, far + .02, _px(1390, 1880, 350, 160))
	for y: float in [1.4, 1.73]:
		_bar("izk_wood", f, 3.33, y, far + .12, Vector3(1.45, .03, .22), Color("#6a4a2a"))
	var fz := far + .35
	_bar("izk", f, .95, .9, fz, Vector3(.7, 1.8, .6), Color("#d8dcdc"))
	_kit.quad("cold", f * Vector3(.65, .15, fz + .1), f * Vector3(.65, 1.7, fz + .1), f * Vector3(1.25, 1.7, fz + .1), f * Vector3(1.25, .15, fz + .1), Color(.62, .7, .74))
	for y: float in [.16, .54, .92, 1.3]:
		_bar("izk", f, .95, y, fz + .2, Vector3(.58, .015, .2), Color("#c8ccc8"))
	_kit.quad("front", f * Vector3(.65, .12, fz + .302), f * Vector3(.65, 1.72, fz + .302), f * Vector3(1.25, 1.72, fz + .302), f * Vector3(1.25, .12, fz + .302), Color.WHITE)
	_bar("izk", f, .95, 1.78, fz + .3, Vector3(.7, .12, .02), Color("#c83a2a"))
	for row: int in range(4):
		for k: int in range(4):
			_bar("izk", f, .72 + float(k) * .15, .3 + float(row) * .38, fz + .22, Vector3(.07, .24, .07), [Color("#c8a830"), Color("#2a6a3a"), Color("#c8d8e0"), Color("#a83a2a")][(row + k) % 4])
	# Paper pendants over the counter.
	for z: float in [-2.0, -3.4, -4.8]:
		var at := f * Vector3(2.2, 2.05, z)
		_kit.tube("plain", [at + Vector3.UP * .2, at + Vector3.UP * .65], .006, Color("#1a1a1a"), 3)
		_kit.lathe("lamp", at, [Vector2(.04, 0), Vector2(.15, .06), Vector2(.17, .12), Vector2(.15, .18), Vector2(.05, .22)], Color(1.0, .82, .58), 10)
	# A beer case and the empties by the door.
	_crate(Vector3(.75, 0, -.9), .2, Color("#c89818"), true)
	_crate(Vector3(.75, .3, -.9), .1, Color("#c89818"), true)

# ---------------------------------------------------------------- the entrance hall

func _hall() -> void:
	var f := _front
	var x0 := HALL_X0
	var x1 := HALL_X1
	var near := 0.0
	var far := -HALL_DEEP
	var wall := Color("#d6cfbe")
	# Opening: tile reveals, a stone threshold.
	_reveal(f, Rect2(x0, 0, x1 - x0, HALL_TOP), .2, Color("#8a9088"))
	_bar("stone", f, (x0 + x1) * .5, .025, .05, Vector3(x1 - x0 + .1, .05, .2), Color("#6a6a66"))
	# Floor: small white tile, gone grey along the walk line.
	_kit.quad("hall_tile", f * Vector3(x0, .03, near - .2), f * Vector3(x0, .03, STAIR_Z), f * Vector3(x1, .03, STAIR_Z), f * Vector3(x1, .03, near - .2), Color("#b8b4aa"), .8, .9)
	_bar("hall", f, (x0 + x1) * .5, .036, -.6, Vector3(.8, .012, .5), Color("#3a3c3a"))
	# Walls: render over a tile dado, both sides up the well.
	_kit.quad("hall_wall", f * Vector3(x0, 0, near - .2), f * Vector3(x0, WELL_TOP, near - .2), f * Vector3(x0, WELL_TOP, far), f * Vector3(x0, 0, far), wall, .7, 1.0)
	_kit.quad("hall_wall", f * Vector3(x1, 0, far), f * Vector3(x1, WELL_TOP, far), f * Vector3(x1, WELL_TOP, near - .2), f * Vector3(x1, 0, near - .2), wall * .97, .7, 1.0)
	_kit.quad("hall_wall", f * Vector3(x0, 0, far), f * Vector3(x0, WELL_TOP, far), f * Vector3(x1, WELL_TOP, far), f * Vector3(x1, 0, far), wall * .9, .6, 1.0)
	for side: Array in [[x0 + .004, 1.0], [x1 - .004, -1.0]]:
		var x: float = side[0]
		if side[1] > 0.0:
			_kit.quad("hall_tile", f * Vector3(x, 0, near - .2), f * Vector3(x, .95, near - .2), f * Vector3(x, .95, STAIR_Z), f * Vector3(x, 0, STAIR_Z), Color("#8a948a"), .7, .9)
		else:
			_kit.quad("hall_tile", f * Vector3(x, 0, STAIR_Z), f * Vector3(x, .95, STAIR_Z), f * Vector3(x, .95, near - .2), f * Vector3(x, 0, near - .2), Color("#8a948a"), .7, .9)
		_bar("hall", f, x, .97, (near - .2 + STAIR_Z) * .5, Vector3(.02, .03, STAIR_Z - near + .2), Color("#5a6058"))
	# Ceiling over the lobby, the well open above the stair.
	_kit.quad("hall_wall", f * Vector3(x0, HALL_TOP, STAIR_Z + .3), f * Vector3(x0, HALL_TOP, near - .2), f * Vector3(x1, HALL_TOP, near - .2), f * Vector3(x1, HALL_TOP, STAIR_Z + .3), Color("#e0dcd0"), .7, .7)
	_kit.quad("hall_wall", f * Vector3(x0, HALL_TOP, STAIR_Z + .3), f * Vector3(x0, WELL_TOP - .01, STAIR_Z + .3), f * Vector3(x1, WELL_TOP - .01, STAIR_Z + .3), f * Vector3(x1, HALL_TOP, STAIR_Z + .3), Color("#c8c4b8"), .6, .8)
	_kit.quad("hall_wall", f * Vector3(x0, WELL_TOP, far), f * Vector3(x0, WELL_TOP, STAIR_Z + .3), f * Vector3(x1, WELL_TOP, STAIR_Z + .3), f * Vector3(x1, WELL_TOP, far), Color("#b8b4a8"), .5, .6)
	# Fluorescent batten over the mailboxes, a bulb at the top of the stair.
	_bar("hall", f, (x0 + x1) * .5, HALL_TOP - .03, -1.2, Vector3(.12, .05, 1.2), Color("#d8d8d4"))
	_bar("lamp", f, (x0 + x1) * .5, HALL_TOP - .06, -1.2, Vector3(.04, .03, 1.1), Color(.92, .96, 1.0))
	_kit.disc("lamp", f * Vector3((x0 + x1) * .5, WELL_TOP - .02, far + .4), Vector3.RIGHT, Vector3.BACK, .07, Color(1.0, .92, .8))
	# Mailboxes on the west wall, the e-paper guide and the lift on the east.
	_bar("hall", f, x0 + .07, 1.35, -.95, Vector3(.14, .74, .92), Color("#6a6c6e"))
	_west_side("hall_board", x0 + .142, -.5, -1.4, 1.0, 1.7, _px(1620, 640, 330, 260))
	_west_side("hall_decal", x0 + .006, -1.55, -2.85, 1.05, 2.05, _px(1090, 640, 520, 400))
	_bar("hall", f, x1 - .015, 1.5, -.9, Vector3(.03, .56, .44), Color("#3a3c3e"))
	_east_side("eink", x1 - .032, -.7, -1.1, 1.25, 1.75, _px(1750, 0, 290, 380))
	_status(f, x1 - .033, 1.79, -.75, GREEN)
	_east_side("hall_decal", x1 - .006, -.25, -.65, 1.3, 1.72, _px(1090, 640, 140, 140))
	_east_side("hall_decal", x1 - .006, -2.75, -3.1, 1.5, 1.85, _px(1440, 950, 160, 84))
	var lz0 := -1.75
	var lz1 := -2.6
	_bar("hall", f, x1 - .02, 2.12, (lz0 + lz1) * .5, Vector3(.04, .1, lz0 - lz1 + .2), Color("#9a9c9a"))
	for z: float in [lz0 + .05, lz1 - .05]:
		_bar("hall", f, x1 - .02, 1.05, z, Vector3(.04, 2.1, .1), Color("#9a9c9a"))
	_kit.quad("metal", f * Vector3(x1 - .03, 0, lz1), f * Vector3(x1 - .03, 2.06, lz1), f * Vector3(x1 - .03, 2.06, lz0), f * Vector3(x1 - .03, 0, lz0), Color("#b8bab6"), .8, 1.0)
	_bar("hall", f, x1 - .035, 1.03, (lz0 + lz1) * .5, Vector3(.01, 2.06, .01), Color("#4a4c4c"))
	_bar("hall", f, x1 - .03, 2.3, (lz0 + lz1) * .5, Vector3(.02, .1, .34), Color("#121212"))
	_east_side("screen", x1 - .042, (lz0 + lz1) * .5 + .15, (lz0 + lz1) * .5 - .15, 2.26, 2.34, _px(1710, 530, 160, 60))
	_bar("hall", f, x1 - .03, 1.15, lz0 + .2, Vector3(.02, .2, .09), Color("#8a8c8a"))
	_status(f, x1 - .043, 1.2, lz0 + .2, AMBER)
	# The steep stair: fourteen risers straight up to the first landing, a rail on the west wall.
	var rise := GROUND / 14.0
	var run := .228
	for k: int in range(14):
		var z := STAIR_Z - run * (float(k) + .5)
		var y := rise * (float(k) + .5)
		_bar("hall_tile", f, (x0 + x1) * .5, y, z, Vector3(x1 - x0, rise, run), Color("#a8a49a"), .8, 1.0)
		_bar("hall", f, (x0 + x1) * .5, rise * float(k + 1) - .01, z + run * .5 - .015, Vector3(x1 - x0, .02, .03), Color("#6a6c68"))
	var top_z := STAIR_Z - run * 14.0
	_bar("hall_tile", f, (x0 + x1) * .5, GROUND - .1, (top_z + far) * .5, Vector3(x1 - x0, .2, top_z - far), Color("#a8a49a"))
	_kit.tube("metal", [f * Vector3(x0 + .06, .95, STAIR_Z + .1), f * Vector3(x0 + .06, .95 + GROUND, top_z)], .02, Color("#8a6a40"), 6)
	# At the top: the door of 2F 由美, padded in red, and the next flight turning out of sight.
	_kit.quad("hall", f * Vector3(x0 + .2, GROUND, far + .025), f * Vector3(x0 + .2, GROUND + 1.95, far + .025), f * Vector3(x1 - .3, GROUND + 1.95, far + .025), f * Vector3(x1 - .3, GROUND, far + .025), Color("#7a2420"), .7, 1.0)
	for k: int in range(4):
		for j: int in range(2):
			_bar("hall", f, x0 + .35 + float(j) * .4, GROUND + .35 + float(k) * .45, far + .035, Vector3(.025, .025, .02), Color("#c8a456"))
	_panel("hall_board", f, x0 + .3, x0 + .66, GROUND + 1.45, GROUND + 1.6, far + .04, _px(1100, 650, 116, 58))

# ---------------------------------------------------------------- upper floors

func _upper_windows() -> void:
	var f := _front
	var openings := _front_openings()
	for i: int in range(openings.size()):
		for w: Array in openings[i]:
			_film_window(f, w[0], int(w[1]), w[2], float(w[3]))
	# 2F: スナック由美's little OPEN box hung inside the glass.
	var r: Rect2 = openings[0][0][0]
	_bar("metal", f, r.get_center().x, r.position.y + .22, -.08, Vector3(.42, .2, .04), Color("#0a0a0c"))
	_panel("sign", f, r.get_center().x - .2, r.get_center().x + .2, r.position.y + .13, r.position.y + .31, -.058, _px(0, 1400, 200, 90))
	# 5F: 紫苑's OPEN box, dimmer.
	r = openings[3][1][0]
	_bar("metal", f, r.get_center().x, r.position.y + .22, -.08, Vector3(.42, .2, .04), Color("#0a0a0c"))
	_panel("sign_dim", f, r.get_center().x - .2, r.get_center().x + .2, r.position.y + .13, r.position.y + .31, -.058, _px(0, 1400, 200, 90))
	# 4F: カラオケ box on a bracket out from the wall beside the purple window.
	r = openings[2][0][0]
	var sx := r.end.x + .22
	var sy := r.end.y - .1
	_bar("metal", f, sx, sy, .2, Vector3(.08, .32, .38), Color("#2a2a2c"))
	_kit.atlas("sign", f * Vector3(sx - .045, sy - .15, .03), f * Vector3(sx - .045, sy + .15, .03), f * Vector3(sx - .045, sy + .15, .38), f * Vector3(sx - .045, sy - .15, .38), _px(210, 1400, 240, 90))
	_kit.atlas("sign", f * Vector3(sx + .045, sy - .15, .38), f * Vector3(sx + .045, sy + .15, .38), f * Vector3(sx + .045, sy + .15, .03), f * Vector3(sx + .045, sy - .15, .03), _px(210, 1400, 240, 90))
	# 3F: 小料理たまき's paper lantern on an iron arm by her window.
	r = openings[1][0][0]
	var lx := r.end.x + .3
	var ly := r.position.y + .2
	_kit.tube("metal", [f * Vector3(lx, ly + 1.0, .02), f * Vector3(lx, ly + 1.0, .4), f * Vector3(lx, ly + .78, .4)], .012, Color("#1a1a1a"), 4)
	var profile: Array[Vector2] = []
	for k: int in range(7):
		var t := float(k) / 6.0
		profile.append(Vector2(.1 + .06 * sin(t * PI), t * .55))
	_kit.lathe("paper", f * Vector3(lx, ly + .2, .4), profile, Color(1.0, .9, .76), 12, _px(1376, 1412, 200, 216))
	_kit.lathe("plain", f * Vector3(lx, ly + .17, .4), [Vector2(.1, 0), Vector2(.1, .04)], Color("#2a1e14"), 10)
	_kit.lathe("plain", f * Vector3(lx, ly + .74, .4), [Vector2(.1, 0), Vector2(.1, .04)], Color("#2a1e14"), 10)

func _film_window(face: Transform3D, r: Rect2, cell: int, part: String, tint: float) -> void:
	# Small aluminium window: film or frosting on the glass, lit or dark behind it.
	_reveal(face, r, .14, Color("#7a8078"))
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var rect := _px(float(cell) * 256.0 + 6.0, 1146, 238, 238)
	var shift := _rng.randf_range(0.0, .03)
	_kit.atlas(part, face * Vector3(x0, y0, -.12), face * Vector3(x0, y1, -.12), face * Vector3(x1, y1, -.12), face * Vector3(x1, y0, -.12), Rect2(rect.position.x + shift, rect.position.y, rect.size.x - shift, rect.size.y), Color(tint, tint, tint))
	_kit.quad("front", face * Vector3(x0, y0, -.09), face * Vector3(x0, y1, -.09), face * Vector3(x1, y1, -.09), face * Vector3(x1, y0, -.09), Color.WHITE)
	_frame(face, r, -.07, ALU, true)
	_bar("concrete", face, r.get_center().x, y0 - .04, .04, Vector3(r.size.x + .12, .05, .16), Color("#9a9890"))
	# A rust-and-soot run under the sill.
	_panel("paint", face, r.get_center().x - .25, r.get_center().x + .25, y0 - 1.1, y0 - .07, .004, _px(1620, 910, 100, 220))

# ---------------------------------------------------------------- the sign stack

func _sign_stack() -> void:
	# Eleven acrylic boxes in a steel frame up the east corner, the building's name on top.
	# Most burn bright; 華 is on a failing tube, 茜 closed for good and dark, the vacancy unlit.
	var f := _front
	var order: Array = [[0, "sign"], [1, "sign_off"], [2, "sign"], [3, "sign"], [4, "sign"], [5, "sign"], [6, "sign"], [7, "sign_dim"], [8, "sign"], [9, "sign_off"], [10, "sign"]]
	var h := .7
	var gap := .08
	var y_low := 4.0
	var t := .2
	var xw := STACK_X - t * .5 - .004
	var xe := STACK_X + t * .5 + .004
	var count := order.size()
	for k: int in range(count):
		var y0 := y_low + float(count - 1 - k) * (h + gap)
		var y1 := y0 + h
		var slot: int = order[k][0]
		var part: String = order[k][1]
		var cell := _px(float(slot % 3) * 360.0 + 6.0, float(slot / 3) * 282.0 + 6.0, 344, 266)
		var body := Color("#2a2c2e") if k % 3 != 0 else Color("#3a3c3e")
		_bar("metal", f, STACK_X, (y0 + y1) * .5, (STACK_Z0 + STACK_Z1) * .5, Vector3(t, h, STACK_Z1 - STACK_Z0), body)
		_kit.atlas(part, f * Vector3(xw, y0, STACK_Z0), f * Vector3(xw, y1, STACK_Z0), f * Vector3(xw, y1, STACK_Z1), f * Vector3(xw, y0, STACK_Z1), cell)
		_kit.atlas(part, f * Vector3(xe, y0, STACK_Z1), f * Vector3(xe, y1, STACK_Z1), f * Vector3(xe, y1, STACK_Z0), f * Vector3(xe, y0, STACK_Z0), cell)
		_bar("metal", f, STACK_X, y0 - .012, (STACK_Z0 + STACK_Z1) * .5, Vector3(t + .02, .024, STACK_Z1 - STACK_Z0 + .02), ALU)
		_bar("metal", f, STACK_X, y1 + .012, (STACK_Z0 + STACK_Z1) * .5, Vector3(t + .02, .024, STACK_Z1 - STACK_Z0 + .02), ALU)
	# Crown: the building's name, a little bell on it.
	var cy0 := y_low + float(count) * (h + gap) + .1
	var cy1 := cy0 + 1.85
	var ct := .3
	var cz0 := STACK_Z0 - .02
	var cz1 := STACK_Z1 + .03
	_bar("metal", f, STACK_X, (cy0 + cy1) * .5, (cz0 + cz1) * .5, Vector3(ct, cy1 - cy0, cz1 - cz0), Color("#6a1414"))
	var side := _px(1096, 6, 238, 448)
	_kit.atlas("sign", f * Vector3(STACK_X - ct * .5 - .004, cy0, cz0), f * Vector3(STACK_X - ct * .5 - .004, cy1, cz0), f * Vector3(STACK_X - ct * .5 - .004, cy1, cz1), f * Vector3(STACK_X - ct * .5 - .004, cy0, cz1), side)
	_kit.atlas("sign", f * Vector3(STACK_X + ct * .5 + .004, cy0, cz1), f * Vector3(STACK_X + ct * .5 + .004, cy1, cz1), f * Vector3(STACK_X + ct * .5 + .004, cy1, cz0), f * Vector3(STACK_X + ct * .5 + .004, cy0, cz0), side)
	_panel("sign", f, STACK_X - ct * .5, STACK_X + ct * .5, cy0, cy1, cz1 + .004, _px(1350, 0, 80, 460))
	_bar("metal", f, STACK_X, cy1 + .04, (cz0 + cz1) * .5, Vector3(ct + .04, .08, cz1 - cz0 + .04), ALU)
	_bar("metal", f, STACK_X, cy0 - .04, (cz0 + cz1) * .5, Vector3(ct + .04, .08, cz1 - cz0 + .04), ALU)
	# Frame: two square posts, arms back to the pier every two metres, the cable down to a box.
	for z: float in [STACK_Z0 - .045, STACK_Z1 + .045]:
		_bar("steel", f, STACK_X, (y_low - .2 + cy1 + .3) * .5, z, Vector3(.07, cy1 + .3 - y_low + .2, .07), STEEL)
	var y := y_low
	while y < cy1:
		_bar("steel", f, STACK_X, y - .03, (STACK_Z0 + STACK_Z1) * .5, Vector3(.06, .05, STACK_Z1 - STACK_Z0 + .18), STEEL)
		_bar("steel", f, STACK_X, y - .03, (STACK_Z0 - .045) * .5, Vector3(.06, .05, STACK_Z0 - .045), STEEL)
		_kit.beam("steel", f * Vector3(STACK_X, y - .03, STACK_Z1 + .045), f * Vector3(STACK_X, y + .9, .01), .04, .04, Vector3.UP, STEEL)
		y += 2.0
	_kit.tube("plain", [f * Vector3(STACK_X - .05, y_low - .2, STACK_Z0 - .02), f * Vector3(STACK_X - .05, 3.6, .06), f * Vector3(6.1, 2.6, .06)], .018, Color("#1a1a1a"), 4)
	_bar("metal", f, 6.1, 2.4, .07, Vector3(.24, .34, .14), Color("#8a8c88"))

# ---------------------------------------------------------------- flanks

func _side_walls() -> void:
	var w := _west
	var e := _east
	var west_windows: Array[Rect2] = []
	var east_windows: Array[Rect2] = []
	for i: int in range(FLOORS):
		var y := _floor_y(i)
		west_windows.append(Rect2(4.5, y + 1.3, .55, .75))
		east_windows.append(Rect2(3.6, y + 1.25, .6, .8))
		if i % 2 == 0:
			east_windows.append(Rect2(6.9, y + 1.2, .5, .7))
	var west_holes: Array[Rect2] = []
	for r: Rect2 in west_windows: west_holes.append(r.grow(.04))
	var east_holes: Array[Rect2] = []
	for r: Rect2 in east_windows: east_holes.append(r.grow(.04))
	_render_wall(w, DEEP, PARAPET, GROUND, PITCH, PAINT, west_holes)
	_render_wall(e, DEEP, PARAPET, GROUND, PITCH, PAINT * .96, east_holes)
	# The street tile turns the corner for a hand's breadth.
	_flat("tile", w, Rect2(DEEP - .4, 0, .4, ROOF - .3), .006, TILE, .88, .6)
	_flat("tile", e, Rect2(0, 0, .4, ROOF - .3), .006, TILE, .88, .6)
	_flat("tile", w, Rect2(DEEP - .4, ROOF - .3, .4, PARAPET - ROOF + .3), .04, DARK_TILE, .9, .3)
	_flat("tile", e, Rect2(0, ROOF - .3, .4, PARAPET - ROOF + .3), .04, DARK_TILE, .9, .3)
	var lit_w := [2]
	for k: int in range(west_windows.size()):
		_toilet_window(w, west_windows[k], k in lit_w, Color(.9, .86, .72))
	for k: int in range(east_windows.size()):
		_toilet_window(e, east_windows[k], k == 1 or k == 5, Color(.8, .7, .9) if k == 5 else Color(.92, .84, .7))
	# West, over the greengrocer: the name painted long ago, condensers, the izakaya's duct.
	_panel("paint", w, DEEP - 1.95, DEEP - .95, 9.0, 16.6, .012, _px(1960, 390, 84, 640))
	for i: int in range(1, FLOORS):
		_ac(w, 6.6 if i % 2 else 2.6, _floor_y(i) + .8)
	_kit.tube("metal", [w * Vector3(5.8, 2.3, .02), w * Vector3(5.8, 2.3, .3), w * Vector3(5.8, ROOF + 1.1, .3), w * Vector3(5.6, ROOF + 1.4, .3)], .14, Color("#b8b8b2"), 10)
	for k: int in range(7):
		_bar("metal", w, 5.8, 3.5 + float(k) * 2.2, .16, Vector3(.36, .04, .3), Color("#6a6a66"))
	_kit.tube("metal", [w * Vector3(.3, PARAPET - .2, .1), w * Vector3(.3, .1, .1)], .05, Color("#8a8476"), 7)
	_kit.tube("plain", [w * Vector3(1.2, .1, .06), w * Vector3(1.2, ROOF - 1.0, .06), w * Vector3(1.6, ROOF - .6, .06)], .025, Color("#c8b878"), 5)
	for k: int in range(2):
		_bar("plain", w, 1.6 + float(k) * .5, 1.35, .12, Vector3(.32, .42, .22), Color("#c8c4b4"))
		_bar("plain", w, 1.6 + float(k) * .5, 1.4, .232, Vector3(.16, .1, .004), Color("#1a1c1c"))
	_bar("plain", w, 3.2, .45, .08, Vector3(.5, .5, .16), Color("#8a8c88"))
	_fibre([w * Vector3(8.6, ROOF, .05), w * Vector3(8.6, 4.0, .05), w * Vector3(8.9, 3.6, .05)])
	# East, to the side street: a column of condensers on one duct, vent hoods, a gas riser.
	for i: int in range(FLOORS):
		var y := _floor_y(i) + .9
		_ac(e, 5.4, y)
		if i % 2 == 1:
			_ac(e, 6.3, y + .2)
		_kit.lathe("metal", e * Vector3(2.4, y + 1.1, .02), [Vector2(.09, 0), Vector2(.09, .12)], Color("#b8b8b0"), 8)
		_bar("metal", e, 2.4, y + 1.04, .1, Vector3(.24, .2, .18), Color("#c8c8c0"))
	_bar("metal", e, 4.85, (GROUND + ROOF) * .5, .07, Vector3(.18, ROOF - GROUND, .12), Color("#cfc8b6"))
	_kit.tube("metal", [e * Vector3(8.9, PARAPET - .2, .1), e * Vector3(8.9, .1, .1)], .05, Color("#8a8476"), 7)
	_kit.tube("plain", [e * Vector3(7.6, .1, .07), e * Vector3(7.6, ROOF + .4, .07)], .03, Color("#c8b878"), 5)
	for k: int in range(3):
		_bar("plain", e, 7.9 + float(k) * .35, 1.3, .12, Vector3(.28, .4, .2), Color("#c8c4b4"))
	_camera(e * Vector3(.8, 3.2, .25))
	# Ground floor to the side street: a steel service door, the hose box, the tenants' sign repeated flat.
	_bar("steel", e, 6.0, 1.0, .03, Vector3(.85, 2.0, .06), Color("#6a7470"))
	_bar("metal", e, 6.0, 2.06, .05, Vector3(.95, .06, .1), Color("#5a5c58"))
	_bar("metal", e, 5.7, 1.0, .07, Vector3(.04, .14, .04), Color("#c8c8c0"))
	_bar("plain", e, 4.2, 1.1, .08, Vector3(.5, .6, .16), Color("#b8281e"))
	_bar("plain", e, 4.2, 1.1, .161, Vector3(.36, .1, .004), Color("#f0e8d8"))
	_bar("metal", e, 1.2, 5.4, .06, Vector3(.98, 1.94, .1), Color("#6a1414"))
	_panel("sign", e, .74, 1.66, 4.46, 6.34, .112, _px(1096, 6, 238, 448))
	_panel("paint", e, 2.6, 3.6, 1.0, 1.77, .006, _px(1090, 640, 520, 400))
	_panel("paint", e, 1.6, 2.6, 3.4, 6.0, .006, _px(1620, 910, 100, 220))

func _toilet_window(face: Transform3D, r: Rect2, lit: bool, tint: Color) -> void:
	_reveal(face, r, .12, Color("#8a8072"))
	if lit:
		_kit.atlas("lit", face * Vector3(r.position.x, r.position.y, -.1), face * Vector3(r.position.x, r.end.y, -.1), face * Vector3(r.end.x, r.end.y, -.1), face * Vector3(r.end.x, r.position.y, -.1), _px(1542, 1146, 238, 238), tint * .7)
	else:
		_kit.atlas("film", face * Vector3(r.position.x, r.position.y, -.1), face * Vector3(r.position.x, r.end.y, -.1), face * Vector3(r.end.x, r.end.y, -.1), face * Vector3(r.end.x, r.position.y, -.1), _px(1542, 1146, 238, 238), Color(.75, .78, .78))
	_frame(face, r, -.06, ALU, false)
	_bar("metal", face, r.get_center().x, r.position.y + r.size.y * .5, .05, Vector3(r.size.x + .06, .02, .02), ALU)
	for k: int in range(1, 4):
		_bar("metal", face, r.position.x + r.size.x * float(k) / 4.0, r.get_center().y, .05, Vector3(.015, r.size.y + .06, .015), ALU)

# ---------------------------------------------------------------- the back

func _back_stair() -> void:
	# Painted steel fire stair, switchback, a landing at each floor's back door.
	var f := _front
	var b := _back
	var holes: Array[Rect2] = []
	for i: int in range(FLOORS + 1):
		var y := 0.0 if i == 0 else _floor_y(i - 1)
		holes.append(Rect2(WIDE - 1.6, y, .85, 2.0))
	_render_wall(b, WIDE, PARAPET, GROUND, PITCH, PAINT * .93, holes)
	for k: int in range(holes.size()):
		var r := holes[k]
		_flat("steel", b, r, -.04, Color("#6a7470") if k != 4 else Color("#2a2420"), .8, .4)
		_bar("metal", b, r.get_center().x, r.end.y + .03, .02, Vector3(r.size.x + .1, .06, .06), Color("#5a5c58"))
		_bar("metal", b, r.end.x - .12, r.position.y + 1.0, -.01, Vector3(.04, .14, .05), Color("#c8c8c0"))
	# 5F: Bar Nocturne's back door, brass plate and the face reader beside it.
	var nd := holes[4]
	_panel("board", b, nd.position.x + .1, nd.end.x - .1, nd.position.y + 1.45, nd.position.y + 1.65, -.035, _px(0, 1870, 300, 90))
	_bar("plain", b, nd.end.x + .13, nd.position.y + 1.3, .02, Vector3(.13, .18, .04), Color("#1a1c1e"))
	_panel("screen", b, nd.end.x + .08, nd.end.x + .18, nd.position.y + 1.24, nd.position.y + 1.37, .041, _px(1600, 530, 100, 120))
	_status(b, nd.end.x + .13, nd.position.y + 1.415, .042, CYAN)
	var zi0 := -DEEP - .05
	var zi1 := -DEEP - 1.1
	var zo0 := -DEEP - 1.2
	var zo1 := -DEEP - 2.25
	var ax0 := .45
	var ax1 := 1.65
	var bx0 := 4.55
	var bx1 := 5.75
	for i: int in range(FLOORS + 1):
		var y := 0.0 if i == 0 else _floor_y(i - 1)
		if i > 0:
			_landing(ax0, ax1, y, zi0, zo1)
			_end_guard(ax0, y, zi0, zo1)
		if i == FLOORS:
			break
		var half := y + PITCH * .5 if i > 0 else GROUND * .5
		var next := _floor_y(i)
		_landing(bx0, bx1, half, zi0, zo1)
		_end_guard(bx1, half, zi0, zo1)
		_flight(ax1, bx0, y, half, zi0, zi1)
		_flight(bx0, ax1, half, next, zo0, zo1)
		_guard(f * Vector3(bx0, half, zo1), f * Vector3(ax1, next, zo1))
	for x: float in [ax0, bx1]:
		_bar("steel", f, x, (ROOF + 1.1) * .5, zo1, Vector3(.11, ROOF + 1.1, .11), STAIR * .85)
		_bar("steel", f, x, (ROOF + 1.1) * .5, zi0 - .06, Vector3(.09, ROOF + 1.1, .09), STAIR * .85)
	# Beer kegs and the empties' crates stacked under the bottom flight.
	for k: int in range(3):
		_kit.lathe("metal", f * Vector3(2.6 + float(k) * .45, 0, -DEEP - .6), [Vector2(.18, 0), Vector2(.2, .05), Vector2(.2, .55), Vector2(.12, .6)], Color("#b8bab8"), 10)
	_crate(Vector3(3.9, 0, -DEEP - .6), 0.0, Color("#c89818"), false)
	_crate(Vector3(3.9, .3, -DEEP - .6), .1, Color("#2a6ab0"), false)

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
		_bar("steel", f, lerpf(xa, xb, t), lerpf(ya, yb, (float(k) + 1.0) / float(steps)) - .02, zc, Vector3(absf(xb - xa) / float(steps) + .02, .03, z0 - z1 - .06), STAIR)

func _guard(from: Vector3, to: Vector3) -> void:
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
	_bar("steel", _front, x, y + .55, (z0 + z1) * .5, Vector3(.03, 1.1, z0 - z1), STAIR * 1.05)

# ---------------------------------------------------------------- roof

func _roof() -> void:
	var f := _front
	var t := .18
	_kit.quad("concrete", f * Vector3(t, ROOF, -t), f * Vector3(t, ROOF, -DEEP + t), f * Vector3(WIDE - t, ROOF, -DEEP + t), f * Vector3(WIDE - t, ROOF, -t), Color("#8a8882"), .8, .8)
	var inner := Color("#a8a49a")
	_kit.quad("concrete", f * Vector3(WIDE - t, ROOF, -t), f * Vector3(WIDE - t, PARAPET, -t), f * Vector3(t, PARAPET, -t), f * Vector3(t, ROOF, -t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(WIDE - t, ROOF, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -t), f * Vector3(WIDE - t, ROOF, -t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(t, ROOF, -t), f * Vector3(t, PARAPET, -t), f * Vector3(t, PARAPET, -DEEP + t), f * Vector3(t, ROOF, -DEEP + t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(t, ROOF, -DEEP + t), f * Vector3(t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, ROOF, -DEEP + t), inner, .7, 1.0)
	for x: float in [.09, WIDE - .09]:
		_bar("concrete", f, x, PARAPET + .04, -DEEP * .5, Vector3(.28, .08, DEEP), Color("#9a968e"))
	_bar("concrete", f, WIDE * .5, PARAPET + .04, -DEEP + .09, Vector3(WIDE, .08, .28), Color("#9a968e"))
	# Stair and lift penthouse at the back.
	var px0 := 3.4
	var px1 := 6.1
	var pz0 := -5.2
	var pz1 := -9.2
	var ph := ROOF + 2.7
	var wall := PAINT * .9
	_kit.quad("render", f * Vector3(px0, ROOF, pz0), f * Vector3(px0, ph, pz0), f * Vector3(px1, ph, pz0), f * Vector3(px1, ROOF, pz0), wall, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px1, ROOF, pz0), f * Vector3(px1, ph, pz0), f * Vector3(px1, ph, pz1), f * Vector3(px1, ROOF, pz1), wall * .95, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px0, ROOF, pz1), f * Vector3(px0, ph, pz1), f * Vector3(px0, ph, pz0), f * Vector3(px0, ROOF, pz0), wall * .95, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px1, ROOF, pz1), f * Vector3(px1, ph, pz1), f * Vector3(px0, ph, pz1), f * Vector3(px0, ROOF, pz1), wall * .9, .8, 1.0, .9)
	_kit.quad("concrete", f * Vector3(px0 - .05, ph, pz0 + .05), f * Vector3(px0 - .05, ph, pz1 - .05), f * Vector3(px1 + .05, ph, pz1 - .05), f * Vector3(px1 + .05, ph, pz0 + .05), Color("#7a7872"), .9, .9)
	_bar("concrete", f, (px0 + px1) * .5, ph + .07, pz0, Vector3(px1 - px0 + .1, .14, .1), Color("#9a968e"))
	_bar("steel", f, 4.0, ROOF + 1.0, pz0 + .02, Vector3(.8, 2.0, .04), Color("#6a7470"))
	_kit.disc("lamp", f * Vector3(4.0, ROOF + 2.2, pz0 + .05), Vector3.RIGHT, Vector3.UP, .06, Color(1.0, .9, .75))
	# Condensers on the roof, their pipes, a TV aerial from before everyone stopped watching.
	var roof := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, ROOF, 0))
	for x: float in [1.0, 2.05]:
		_bar("metal", roof, x, .06, -6.5, Vector3(.88, .12, .44), STEEL)
		_ac(roof.translated_local(Vector3(0, 0, -6.7)), x, .44)
	_kit.tube("metal", [f * Vector3(px1 - .3, ph, pz1 + .4), f * Vector3(px1 - .3, ph + 2.6, pz1 + .4)], .025, ALUMINIUM, 5)
	for k: int in range(3):
		_kit.tube("metal", [f * Vector3(px1 - .9 + float(k) * .1, ph + 2.0 + float(k) * .2, pz1 + .4), f * Vector3(px1 + .3 - float(k) * .1, ph + 2.0 + float(k) * .2, pz1 + .4)], .008, ALUMINIUM, 3)
	_status(f, px1 - .3, ph + 2.64, pz1 + .4, Color(1.0, .2, .15))
	# 2050: the drone ledge, a grated steel shelf standing proud of the front parapet, its locker beside it.
	var dx := 1.9
	var dz := -1.3
	var dy := PARAPET + .35
	for c: Vector2 in [Vector2(-.5, .45), Vector2(.5, .45), Vector2(-.5, -.45), Vector2(.5, -.45)]:
		_bar("steel", f, dx + c.x, (ROOF + dy) * .5, dz + c.y, Vector3(.06, dy - ROOF, .06), STAIR * .8)
	_bar("steel", f, dx, dy, dz, Vector3(1.16, .06, 1.06), STAIR * .7)
	for k: int in range(9):
		_bar("metal", f, dx - .48 + float(k) * .12, dy + .035, dz, Vector3(.02, .01, 1.0), Color("#5a5e60"))
	_kit.atlas("paint", f * Vector3(dx - .5, dy + .045, dz + .5), f * Vector3(dx - .5, dy + .045, dz - .5), f * Vector3(dx + .5, dy + .045, dz - .5), f * Vector3(dx + .5, dy + .045, dz + .5), _px(1730, 910, 220, 220))
	for c: Vector2 in [Vector2(-.55, .5), Vector2(.55, .5), Vector2(-.55, -.5), Vector2(.55, -.5)]:
		_bar("led", f, dx + c.x, dy + .06, dz + c.y, Vector3(.05, .04, .05), AMBER * .8)
	_bar("metal", f, dx + 1.05, ROOF + .45, dz - .2, Vector3(.5, .9, .5), Color("#3c4044"))
	_strip(f * Vector3(dx + .82, ROOF + .92, dz + .06), f * Vector3(dx + 1.28, ROOF + .92, dz + .06), CYAN * .6)
	_status(f, dx + 1.2, ROOF + .7, dz + .06, GREEN)
	_fibre([f * Vector3(dx + 1.05, ROOF + .1, dz - .45), f * Vector3(dx + 1.05, ROOF + .05, -DEEP + .4), f * Vector3(.3, ROOF + .05, -DEEP + .4)])
	# Old FRP water tank on a steel stand, streaked green, its ladder and overflow.
	var tc := f * Vector3(1.55, ROOF + .9, -4.1)
	for c: Vector2 in [Vector2(-.6, -.6), Vector2(.6, -.6), Vector2(-.6, .6), Vector2(.6, .6)]:
		_kit.block("steel", Transform3D(Basis.IDENTITY, tc + Vector3(c.x, -.45, c.y)), Vector3(.08, .9, .08), STAIR * .7)
	_kit.block("steel", Transform3D(Basis.IDENTITY, tc + Vector3(0, -.03, 0)), Vector3(1.4, .06, 1.4), STAIR * .7)
	_kit.lathe("plain", tc, [Vector2(.66, 0), Vector2(.7, .1), Vector2(.7, 1.3), Vector2(.62, 1.45), Vector2(.3, 1.55), Vector2(.18, 1.58)], Color("#9aa896"), 16)
	_kit.lathe("plain", tc + Vector3.UP * 1.58, [Vector2(.2, 0), Vector2(.2, .08), Vector2(0, .09)], Color("#6a7466"), 10)
	for k: int in range(4):
		_kit.lathe("plain", tc + Vector3.UP * (.28 + float(k) * .3), [Vector2(.705, 0), Vector2(.705, .03)], Color("#7a8878"), 16)
	_kit.tube("metal", [tc + Vector3(.7, .2, 0), tc + Vector3(.95, .2, 0), tc + Vector3(.95, -.9, 0)], .025, Color("#8a8c88"), 5)
	for k: int in range(7):
		_kit.tube("metal", [tc + Vector3(-.3, -.8 + float(k) * .3, .74), tc + Vector3(.3, -.8 + float(k) * .3, .74)], .01, Color("#6a6c6a"), 3)
	for x: float in [-.3, .3]:
		_kit.tube("metal", [tc + Vector3(x, -.9, .74), tc + Vector3(x, 1.2, .74)], .015, Color("#6a6c6a"), 4)
	var solar := Transform3D(Basis(Vector3.RIGHT, -.35), f * Vector3(1.6, ROOF + .5, -8.2))
	_solar_module(solar, 1.6, 1.0)
	for x: float in [.9, 2.3]:
		_bar("steel", f, x, ROOF + .28, -8.2, Vector3(.05, .56, .05), STAIR * .8)

# ---------------------------------------------------------------- pavement

func _crate_bar(xf: Transform3D, x: float, y: float, z: float, size: Vector3, tint: Color) -> void:
	_kit.block("plain", Transform3D(xf.basis, xf * Vector3(x, y, z)), size, tint)

func _crate(at: Vector3, yaw: float, tint: Color, upside: bool) -> void:
	# Plastic beer crate: corner posts, three rails a side with the gaps between, a solid floor.
	var xf := Transform3D(Basis(Vector3.UP, yaw), _front * at)
	var hx := .23
	var hz := .17
	var h := .3
	var floor_y := h - .012 if upside else .012
	_crate_bar(xf, 0, floor_y, 0, Vector3(hx * 2.0 - .02, .024, hz * 2.0 - .02), tint * .85)
	for y: float in [.02, .13, .27]:
		_crate_bar(xf, 0, y, hz - .008, Vector3(hx * 2.0, .035 if y > .2 else .028, .016), tint)
		_crate_bar(xf, 0, y, -hz + .008, Vector3(hx * 2.0, .035 if y > .2 else .028, .016), tint)
		_crate_bar(xf, hx - .008, y, 0, Vector3(.016, .035 if y > .2 else .028, hz * 2.0), tint)
		_crate_bar(xf, -hx + .008, y, 0, Vector3(.016, .035 if y > .2 else .028, hz * 2.0), tint)
	for c: Vector2 in [Vector2(hx, hz), Vector2(-hx, hz), Vector2(hx, -hz), Vector2(-hx, -hz)]:
		_crate_bar(xf, c.x - signf(c.x) * .02, h * .5, c.y - signf(c.y) * .02, Vector3(.04, h, .04), tint)
	_crate_bar(xf, 0, .2, hz - .006, Vector3(.3, .07, .014), tint)
	var y0 := .168 if not upside else .132
	var y1 := y0 + .064
	var label := _px(1180, 1880, 200, 80)
	if upside:
		_kit.atlas("board", xf * Vector3(.15, .2 + .032, hz + .002), xf * Vector3(.15, .2 - .032, hz + .002), xf * Vector3(-.15, .2 - .032, hz + .002), xf * Vector3(-.15, .2 + .032, hz + .002), label)
	else:
		_kit.atlas("board", xf * Vector3(-.15, y0, hz + .002), xf * Vector3(-.15, y1, hz + .002), xf * Vector3(.15, y1, hz + .002), xf * Vector3(.15, y0, hz + .002), label)

func _pavement() -> void:
	var f := _front
	# 立ち飲み overflow: two crates under a plank for a table, upturned crates for stools.
	_crate(Vector3(1.3, 0, .55), 0.0, Color("#d8a818"), true)
	_crate(Vector3(1.3, .3, .55), .05, Color("#d8a818"), true)
	_bar("wood", f, 1.3, .62, .55, Vector3(.9, .04, .46), Color("#8a6a48"))
	_kit.lathe("bottle", f * Vector3(1.1, .64, .5), [Vector2(.035, 0), Vector2(.04, .13)], Color("#e8c060"), 8)
	_kit.lathe("bottle", f * Vector3(1.5, .64, .6), [Vector2(.03, 0), Vector2(.035, .11)], Color("#c8d8d0"), 8)
	_bar("plain", f, 1.32, .645, .45, Vector3(.16, .012, .1), Color("#e8e0d0"))
	_crate(Vector3(.62, 0, .62), .4, Color("#2a6ab0"), true)
	_crate(Vector3(2.05, 0, .7), -.3, Color("#d8a818"), true)
	# Chalk menu on an easel by the middle pier, both faces.
	var ax := 4.27
	var az := .5
	var hw := .25
	var cell := _px(910, 1710, 260, 330)
	_kit.atlas("board", f * Vector3(ax - hw, .25, az + .2), f * Vector3(ax - hw, .92, az + .02), f * Vector3(ax + hw, .92, az + .02), f * Vector3(ax + hw, .25, az + .2), cell)
	_kit.atlas("board", f * Vector3(ax + hw, .25, az - .2), f * Vector3(ax + hw, .92, az - .02), f * Vector3(ax - hw, .92, az - .02), f * Vector3(ax - hw, .25, az - .2), cell)
	for x: float in [ax - hw - .015, ax + hw + .015]:
		for s: float in [1.0, -1.0]:
			_kit.beam("wood", f * Vector3(x, 0, az + s * .27), f * Vector3(x, .96, az), .03, .03, Vector3.UP, Color("#6a4a2a"))
	# スナック由美's lit stand at the hall door, faces turned to the passers-by.
	var sx := 5.1
	var sz := .6
	_bar("plain", f, sx, .05, sz, Vector3(.48, .1, .32), Color("#1a1a1c"))
	_bar("plain", f, sx, .52, sz, Vector3(.44, .84, .26), Color("#f0eee8"))
	var stand := _px(1750, 1710, 160, 300)
	_kit.atlas("sign", f * Vector3(sx - .22, .12, sz + .132), f * Vector3(sx - .22, .92, sz + .132), f * Vector3(sx + .22, .92, sz + .132), f * Vector3(sx + .22, .12, sz + .132), stand)
	_kit.atlas("sign", f * Vector3(sx + .22, .12, sz - .132), f * Vector3(sx + .22, .92, sz - .132), f * Vector3(sx - .22, .92, sz - .132), f * Vector3(sx - .22, .12, sz - .132), stand)
	_kit.tube("plain", [f * Vector3(sx + .1, .05, sz - .16), f * Vector3(sx + .3, .02, sz - .5), f * Vector3(HALL_X1 - .1, .02, -.2)], .008, Color("#1a1a1a"), 3)
