extends "res://scripts/midori_near_city_handmade.gd"
## 御菓子司 萩乃屋: a post-war shop-house where the same family has made namagashi since 1952.
## Tiled pent roof over an indigo noren, a glass case out on the pavement, gilt keyaki board on
## the eave, a steamer going in the back room, and the flat upstairs where the son sleeps.
const ATLAS := "res://assets/shinrai/near_city/wagashi_atlas.png"
const WIDE := 5.04
const DEEP := 6.6
const GROUND := 3.34
const EAVE := 5.85
const RIDGE := 7.45
const RIDGE_Z := -3.3
const FRONT_EDGE := .55
const BACK_EDGE := -6.72
const ROOM_TOP := 2.55
const ROOM_DEEP := 3.7
const WORK_DEEP := 6.3
const RX0 := .12
const RX1 := WIDE - .12
const DOOR := Rect2(.5, 0, 1.8, 2.36)
const SHOW := Rect2(2.46, 0, 2.42, 2.36)
const CASE_X0 := 2.52
const CASE_X1 := 4.82
const CASE_Z := .5
const CASE_LOW := .66
const CASE_TOP := 1.24
const WIN_L := Rect2(.42, 4.12, 2.26, 1.18)
const WIN_R := Rect2(3.25, 4.2, 1.35, 1.05)
const E_WIN := Rect2(2.5, 4.05, .9, .85)
const E_LOW := Rect2(4.7, 1.3, .8, .55)
const W_WIN := Rect2(2.9, 4.1, .8, .8)
const B_WIN := Rect2(.9, 4.0, 1.3, .9)
const B_DOOR := Rect2(3.5, 0, .8, 1.9)
const HISASHI_HIGH := Vector2(0, 3.36)
const HISASHI_LOW := Vector2(.86, 2.98)
const DARKWOOD := Color("#3c2a1e")
const CEDAR := Color("#6e4c34")
const PLASTER := Color("#ddd5c2")
const CHAR := Color("#3a3532")
const TILE := Color("#53585e")
const TRAY := Color("#c49a68")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1952
	_build_looks()
	_ground_front()
	_room()
	_shelves()
	_wrap_counter()
	_work_room()
	_door()
	_noren()
	_showcase()
	_shop_glass()
	_hisashi()
	_kanban()
	_upper_front()
	_side_walls()
	_roof()
	_street_things()
	_kit.commit(self, _looks, ["front", "decal", "steam", "lamp", "led", "lantern", "room", "floor", "display", "sweet", "steel", "shoji", "shade", "eink", "sign"])
	_kit = null
	_omni("WagashiShop", _front * Vector3(2.6, 2.2, -1.5), Color(1.0, .86, .66), .5, 5.0)
	_omni("WagashiLantern", _front * Vector3(2.38, 2.1, 1.0), Color(1.0, .76, .5), .5, 4.5)

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

func _decal_look(name: String, glow: float, day: float) -> void:
	var look := ShaderMaterial.new()
	look.shader = DECAL_SHADER
	look.set_shader_parameter("atlas", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _build_looks() -> void:
	_shared_looks()
	_looks.plaster = _look("plastered_wall_03", 2.2, .95)
	_looks.plaster.set_shader_parameter("chroma", .35)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .5)
	_looks.wood = _look("japanese_cedar_planks", 1.2, .75)
	_looks.wood.set_shader_parameter("chroma", .3)
	_looks.clap = _look("japanese_cedar_planks", 1.5, .85)
	_looks.clap.set_shader_parameter("chroma", .4)
	_looks.char = _look("japanese_cedar_planks", 1.4, .92)
	_looks.char.set_shader_parameter("chroma", .15)
	_looks.stone = _look("precast_concrete_wall", 1.6, .9)
	_looks.stone.set_shader_parameter("chroma", .3)
	_looks.kawara = _look("", 1.0, .36, .3)
	_looks.cloth = _look("", 1.0, .94)
	_looks.cloth.set_shader_parameter("albedo_map", load(ATLAS))
	_looks.cloth.set_shader_parameter("glow", .06)
	_lit_look("room", .6, .25, .1)
	_lit_look("sweet", .5, .34, .12)
	_lit_look("steel", .3, .2, .06, .7)
	_lit_look("shoji", .9, .7, .04)
	_lit_look("shade", .4, 1.1, .14)
	_atlas_look("sign", .45, .22, .04)
	_atlas_look("display", .4, .38, .14)
	_atlas_look("floor", .5, .28, .1)
	_atlas_look("board", .6, .04, .02)
	_atlas_look("lantern", .7, 1.1, .1)
	_atlas_look("eink", .7, .1, .02)
	_decal_look("decal", .3, .1)
	_decal_look("steam", .25, .05)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _flat(part: String, face: Transform3D, area: Rect2, z: float, tint: Color, low := .9, streak := .6) -> void:
	_kit.quad(part, face * Vector3(area.position.x, area.position.y, z), face * Vector3(area.position.x, area.end.y, z), face * Vector3(area.end.x, area.end.y, z), face * Vector3(area.end.x, area.position.y, z), tint, low, 1.0, streak, Vector2(area.position.x, -area.position.y))

func _roof_y(z: float) -> float:
	if z >= RIDGE_Z:
		return lerpf(RIDGE, EAVE, clampf((z - RIDGE_Z) / (FRONT_EDGE - RIDGE_Z), 0.0, 1.0))
	return lerpf(RIDGE, EAVE, clampf((RIDGE_Z - z) / (RIDGE_Z - BACK_EDGE), 0.0, 1.0))

# ---------------------------------------------------------------- ground floor front

func _ground_front() -> void:
	# Plaster between dark posts, burnt-cedar boards at the foot of the pier, granite plinth.
	var f := _front
	for piece: Rect2 in _minus(Rect2(0, .18, WIDE, GROUND - .18), [DOOR, SHOW]):
		_flat("plaster", f, piece, 0.0, PLASTER, .85, .7)
	_flat("char", f, Rect2(0, .18, DOOR.position.x, .86), .006, CHAR, .8, .3)
	_bar("stone", f, DOOR.position.x * .5, .09, .02, Vector3(DOOR.position.x, .18, .06), Color("#8a8680"), .8, 1.0)
	_bar("stone", f, WIDE - .08, .09, .02, Vector3(.16, .18, .06), Color("#8a8680"), .8, 1.0)
	for post: Vector2 in [Vector2(.07, .14), Vector2(2.38, .16), Vector2(WIDE - .08, .16)]:
		_bar("wood", f, post.x, GROUND * .5, .03, Vector3(post.y, GROUND, .1), DARKWOOD, .75, 1.0)
	# Lintel over both openings, and the floor beam the pent roof hangs from.
	_bar("wood", f, WIDE * .5, 2.49, .04, Vector3(WIDE, .26, .12), DARKWOOD, .8, 1.0)
	_bar("wood", f, WIDE * .5, GROUND - .04, .03, Vector3(WIDE, .12, .1), DARKWOOD.darkened(.15))
	# Stone step at the door, worn hollow in the middle.
	_bar("stone", f, DOOR.get_center().x, .05, .16, Vector3(DOOR.size.x + .12, .1, .34), Color("#9a968e"), .8, 1.0)
	_bar("stone", f, DOOR.get_center().x, .101, .2, Vector3(.8, .004, .2), Color("#87837c"))
	# The street-safety camera and the fibre run down the corner post.
	_camera(f * Vector3(.2, 2.85, .2))
	_fibre([f * Vector3(.04, 5.9, .12), f * Vector3(.04, 3.5, .12), f * Vector3(.04, 3.3, .9), f * Vector3(.04, 2.95, .9), f * Vector3(.04, 2.7, .12), f * Vector3(.04, .3, .12)])

# ---------------------------------------------------------------- the shop room

func _room() -> void:
	var f := _front
	var near := -.1
	var deep := -ROOM_DEEP
	var wall := Color("#e6dcc4")
	var panel := Color("#8a6040")
	_kit.atlas("floor", f * Vector3(RX0, .02, near), f * Vector3(RX0, .02, deep), f * Vector3(RX1, .02, deep), f * Vector3(RX1, .02, near), _cell(0, 1260, 400, 500))
	_kit.quad("room", f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, ROOM_TOP, near), f * Vector3(RX1, ROOM_TOP, near), f * Vector3(RX1, ROOM_TOP, deep), Color("#b89a72"), .7, .7)
	# Ceiling boards: one batten a board.
	var x := RX0 + .3
	while x < RX1:
		_bar("room", f, x, ROOM_TOP - .012, (near + deep) * .5, Vector3(.025, .02, -deep + near), Color("#7a5a3c"))
		x += .45
	# Side walls: wood wainscot, plaster over it.
	var rail := .92
	for side: Array in [[RX0, true], [RX1, false]]:
		var at: float = side[0]
		var left: bool = side[1]
		var z0 := near if left else deep
		var z1 := deep if left else near
		_kit.quad("room", f * Vector3(at, 0, z0), f * Vector3(at, rail, z0), f * Vector3(at, rail, z1), f * Vector3(at, 0, z1), panel, .6, .95)
		_kit.quad("room", f * Vector3(at, rail, z0), f * Vector3(at, ROOM_TOP, z0), f * Vector3(at, ROOM_TOP, z1), f * Vector3(at, rail, z1), wall, .95, .8)
		_bar("room", f, at + (.012 if left else -.012), rail, (near + deep) * .5, Vector3(.024, .04, -deep + near), Color("#5a3a26"))
	# Back partition: plaster, the doorway to the work room, its short persimmon noren.
	var gap := Rect2(.55, 0, .9, 2.0)
	for piece: Rect2 in _minus(Rect2(RX0, 0, RX1 - RX0, ROOM_TOP), [gap]):
		_flat("room", f, piece, deep, wall if piece.position.y > .5 else wall.darkened(.08), .75, 0.0)
	_flat("room", f, Rect2(RX0, 0, RX1 - RX0, rail), deep + .006, panel, .6, 0.0)
	_kit.quad("room", f * Vector3(gap.position.x, 0, deep), f * Vector3(gap.position.x, gap.end.y, deep), f * Vector3(gap.position.x, gap.end.y, deep - .12), f * Vector3(gap.position.x, 0, deep - .12), Color("#6a4a30"))
	_kit.quad("room", f * Vector3(gap.end.x, 0, deep - .12), f * Vector3(gap.end.x, gap.end.y, deep - .12), f * Vector3(gap.end.x, gap.end.y, deep), f * Vector3(gap.end.x, 0, deep), Color("#6a4a30"))
	_bar("room", f, gap.get_center().x, gap.end.y + .03, deep, Vector3(gap.size.x + .12, .06, .14), Color("#4a3020"))
	for half: int in range(2):
		var x0 := gap.position.x + float(half) * gap.size.x * .5 + .01
		var x1 := x0 + gap.size.x * .5 - .02
		var cell := _cell(1460.0 + float(half) * 150.0, 1260, 150, 300)
		_kit.atlas("display", f * Vector3(x0, gap.end.y - .82, deep + .03 + float(half) * .01), f * Vector3(x0, gap.end.y, deep + .02), f * Vector3(x1, gap.end.y, deep + .02), f * Vector3(x1, gap.end.y - .82, deep + .03 + float(half) * .01), cell)
	# Scroll and calendar on the partition; お品書き by the door; the clock.
	_panel("display", f, 1.7, 2.1, 1.25, 1.77, deep + .012, _cell(0, 1780, 200, 260))
	_panel("display", f, 2.3, 2.56, 1.4, 1.78, deep + .012, _cell(220, 1780, 180, 260))
	var m := RX0 + .008
	_kit.atlas("display", f * Vector3(m, 1.05, -1.0), f * Vector3(m, 2.1, -1.0), f * Vector3(m, 2.1, -1.68), f * Vector3(m, 1.05, -1.68), _cell(1080, 1260, 360, 560))
	var clock := f * Vector3(1.0, 2.25, deep + .02)
	_kit.disc("room", clock, Vector3.RIGHT, Vector3.UP, .12, Color("#f0e8d4"))
	_kit.tube("plain", [clock + Vector3(0, 0, .006), clock + Vector3(.0, .08, .006)], .004, Color("#222222"), 3)
	_kit.tube("plain", [clock + Vector3(0, 0, .006), clock + Vector3(.05, -.02, .006)], .005, Color("#222222"), 3)
	# Customers' bench on the west wall: red felt over plain boards, a tea tray at one end.
	var bx := RX0 + .22
	_bar("room", f, bx, .42, -2.4, Vector3(.4, .05, 1.3), Color("#8a6a48"))
	_bar("room", f, bx, .455, -2.4, Vector3(.42, .02, 1.32), Color("#a8281e"))
	for z: float in [-1.85, -2.95]:
		for dx: float in [-.15, .15]:
			_bar("room", f, bx + dx, .2, z, Vector3(.04, .4, .04), Color("#5a4028"))
	_bar("room", f, bx, .5, -2.9, Vector3(.24, .02, .3), Color("#3a2618"))
	_kit.lathe("room", f * Vector3(bx, .51, -2.95), [Vector2(.04, 0), Vector2(.055, .03), Vector2(.05, .08), Vector2(.02, .1), Vector2(.0, .11)], Color("#4a5a4a"), 8)
	for z: float in [-2.8, -2.82]:
		_kit.lathe("room", f * Vector3(bx + .07, .51, z), [Vector2(.02, 0), Vector2(.03, .06)], Color("#e8e2d0"), 7)
	# Two pendant shades in milk glass, on cloth flex.
	for at: Vector2 in [Vector2(1.3, -1.7), Vector2(3.5, -1.9)]:
		var top := f * Vector3(at.x, ROOM_TOP, at.y)
		_kit.tube("plain", [top, top + Vector3.DOWN * .5], .006, Color("#2a2420"), 3)
		_kit.lathe("shade", top + Vector3.DOWN * .72, [Vector2(.2, 0), Vector2(.17, .06), Vector2(.09, .18), Vector2(.03, .22)], Color("#f6efe0"), 12)
		_kit.disc("lamp", top + Vector3.DOWN * .7, Vector3.RIGHT, Vector3.BACK, .08, Color(1.0, .9, .72))

func _gift(face: Transform3D, x: float, y: float, z: float, size: Vector3, kind: int) -> void:
	# A boxed set: body in its paper, the kakegami face turned to the street.
	var col := kind % 4
	var row := (kind / 4) % 2
	var tones: Array[Color] = [Color("#c9a678"), Color("#f2eee4"), Color("#5a3a6a"), Color("#6a8a4a"), Color("#e4d4b0"), Color("#b03a2a"), Color("#2a3a5a"), Color("#f0e8d4")]
	_bar("room", face, x, y + size.y * .5, z, size, tones[kind % 8])
	_panel("display", face, x - size.x * .5, x + size.x * .5, y, y + size.y, z + size.z * .5 + .003, _cell(420.0 + float(col) * 150.0, 1260.0 + float(row) * 100.0, 150, 100))

func _shelves() -> void:
	# Open shelves of gift boxes on the partition, the stock that pays for the winters.
	var f := _front
	var deep := -ROOM_DEEP
	var x0 := 2.85
	var x1 := RX1 - .04
	var d := .32
	var z := deep + d * .5 + .01
	var wood := Color("#6a4a30")
	for x: float in [x0, (x0 + x1) * .5, x1]:
		_bar("room", f, x, 1.2, z, Vector3(.03, 2.3, d), wood)
	var kind := 0
	for level: int in range(4):
		var y := .35 + float(level) * .5
		_bar("room", f, (x0 + x1) * .5, y, z, Vector3(x1 - x0, .025, d), wood)
		var x := x0 + .05
		while x < x1 - .22:
			var w := _rng.randf_range(.24, .34)
			var h := _rng.randf_range(.07, .12)
			var stack := 1 + _rng.randi() % 3
			for s: int in range(stack):
				_gift(f, x + w * .5, y + .013 + float(s) * h, z + .02, Vector3(w, h, .22), kind)
			kind += 1
			x += w + .04
	# A low glazed case on the east wall: yokan and senbei in tins.
	var ex := RX1 - .25
	_bar("room", f, ex, .4, -2.1, Vector3(.46, .8, 1.6), Color("#5a3c28"))
	_bar("room", f, ex, .82, -2.1, Vector3(.5, .03, 1.64), Color("#3a2618"))
	var zz := -1.45
	while zz > -2.8:
		_bar("room", f, ex, .9, zz, Vector3(.3, .14, .2), [Color("#c0a050"), Color("#8a2a22"), Color("#3a4a6a")][_rng.randi() % 3])
		zz -= .3

func _wrap_counter() -> void:
	# Just inside the window: where everything is wrapped, paid for and bowed over.
	var f := _front
	var x0 := 2.62
	var x1 := RX1 - .55
	var z := -.75
	_bar("room", f, (x0 + x1) * .5, .44, z, Vector3(x1 - x0, .88, .5), Color("#5a3c28"))
	_bar("room", f, (x0 + x1) * .5, .9, z, Vector3(x1 - x0 + .04, .04, .54), Color("#8a6444"))
	# Register, a roll of wrapping paper, paper bags, a stack of boxes waiting for their string.
	_bar("room", f, x1 - .3, 1.0, z, Vector3(.34, .16, .3), Color("#d8d2c0"))
	_bar("room", f, x1 - .3, 1.1, z - .05, Vector3(.3, .06, .14), Color("#a8a290"))
	_kit.tube("room", [f * Vector3(x0 + .1, .97, z + .2), f * Vector3(x0 + .7, .97, z + .2)], .045, Color("#efe6d0"), 8)
	for i: int in range(3):
		_gift(f, x0 + .95 + float(i) * .03, .92 + float(i) * .09, z - .02, Vector3(.3, .09, .22), i + 1)
	_bar("room", f, x0 + .45, .96, z - .12, Vector3(.3, .06, .2), Color("#c9a678"))

func _work_room() -> void:
	# Through the doorway: white tile, a gas ring, the seiro stacked and steaming, the an pot.
	var f := _front
	var near := -ROOM_DEEP - .12
	var deep := -WORK_DEEP
	var top := 2.4
	var tile := Color("#d8d8d0")
	_kit.quad("room", f * Vector3(RX0, .02, near), f * Vector3(RX0, .02, deep), f * Vector3(RX1, .02, deep), f * Vector3(RX1, .02, near), Color("#7a7872"), .7, .7)
	_kit.quad("room", f * Vector3(RX0, top, deep), f * Vector3(RX0, top, near), f * Vector3(RX1, top, near), f * Vector3(RX1, top, deep), Color("#c8c4b8"), .7, .7)
	_kit.quad("room", f * Vector3(RX0, 0, deep), f * Vector3(RX0, top, deep), f * Vector3(RX1, top, deep), f * Vector3(RX1, 0, deep), tile, .7, .9)
	_kit.quad("room", f * Vector3(RX0, 0, near), f * Vector3(RX0, top, near), f * Vector3(RX0, top, deep), f * Vector3(RX0, 0, deep), tile, .7, .9)
	_kit.quad("room", f * Vector3(RX1, 0, deep), f * Vector3(RX1, top, deep), f * Vector3(RX1, top, near), f * Vector3(RX1, 0, near), tile, .7, .9)
	var y := .3
	while y < top:
		_bar("room", f, RX0 + .003, y, (near + deep) * .5, Vector3(.004, .006, -deep + near), Color("#a8a8a0"))
		_bar("room", f, (RX0 + RX1) * .5, y, deep + .003, Vector3(RX1 - RX0, .006, .004), Color("#a8a8a0"))
		y += .15
	_bar("lamp", f, 1.6, top - .04, -4.9, Vector3(.04, .04, 1.2), Color(.95, .95, .88))
	# Gas range against the back wall, steamer on the left ring, copper pot on the right.
	var rx := 1.1
	var rz := deep + .35
	_bar("steel", f, rx, .4, rz, Vector3(1.0, .8, .6), Color("#9a9c98"))
	_bar("steel", f, rx, .81, rz, Vector3(1.02, .03, .62), Color("#5a5c5a"))
	var steam := f * Vector3(rx - .25, .83, rz)
	for i: int in range(4):
		_kit.lathe("room", steam + Vector3.UP * float(i) * .1, [Vector2(.2, 0), Vector2(.2, .09), Vector2(.19, .1)], Color("#c8a070").darkened(float(i) * .04), 12)
		_kit.lathe("room", steam + Vector3.UP * (float(i) * .1 + .005), [Vector2(.203, 0), Vector2(.203, .015)], Color("#7a5a3a"), 12)
	_kit.lathe("room", steam + Vector3.UP * .4, [Vector2(.21, 0), Vector2(.2, .03), Vector2(.05, .06), Vector2(0, .06)], Color("#b89060"), 12)
	_panel_quad("steam", steam + Vector3(-.3, .45, .05), Vector3(.6, 0, 0), Vector3(0, .8, 0))
	var pot := f * Vector3(rx + .26, .83, rz)
	_kit.lathe("room", pot, [Vector2(.12, 0), Vector2(.2, .05), Vector2(.22, .16), Vector2(.23, .2), Vector2(.2, .2)], Color("#b8683a"), 12)
	_kit.tube("room", [pot + Vector3(-.1, .2, 0), pot + Vector3(.1, .55, -.1)], .012, Color("#8a6a48"), 5)
	# Work table with its board and a heap of rice flour, trays racked by the east wall.
	_bar("steel", f, 2.7, .82, -4.7, Vector3(1.5, .04, .7), Color("#b8bab6"))
	for dx: float in [-.7, .7]:
		for dz: float in [-.3, .3]:
			_bar("steel", f, 2.7 + dx, .4, -4.7 + dz, Vector3(.04, .8, .04), Color("#8a8c88"))
	_bar("room", f, 2.6, .86, -4.7, Vector3(.9, .03, .5), Color("#d8b888"))
	_ball(f * Vector3(2.4, .87, -4.65), Vector3(.12, .05, .1), Color("#f2f0ea"), "room", 3, 8)
	for i: int in range(5):
		_ball(f * Vector3(2.8 + float(i % 3) * .08, .9, -4.6 - float(i / 3) * .08), Vector3(.03, .022, .03), Color("#efece4"), "sweet", 3, 7)
	for level: int in range(6):
		_bar("steel", f, RX1 - .3, .3 + float(level) * .3, -4.9, Vector3(.5, .02, .7), Color("#a8aaa6"))
	_bar("steel", f, RX1 - .3, 1.0, -4.9, Vector3(.52, 2.0, .02), Color("#8a8c88"))

func _panel_quad(part: String, origin: Vector3, across: Vector3, up: Vector3) -> void:
	_kit.atlas(part, origin, origin + up, origin + up + across, origin + across, _cell(1460, 1580, 300, 300))

# ---------------------------------------------------------------- sweets

func _sweet(kind: int, at: Vector3) -> void:
	match kind:
		0: # 栗きんとん: crumbled chestnut, gathered in a cloth twist.
			_ball(at + Vector3.UP * .022, Vector3(.026, .024, .026), Color("#cfa860"), "sweet", 4, 7)
			_ball(at + Vector3.UP * .045, Vector3(.008, .006, .008), Color("#a87a38"), "sweet", 2, 5)
		1: # 亥の子餅: little brown boar, three stripes.
			_ball(at + Vector3.UP * .016, Vector3(.034, .018, .024), Color("#8a5a3a"), "sweet", 4, 8)
			for s: float in [-.012, 0.0, .012]:
				_kit.block("sweet", Transform3D(Basis.IDENTITY, at + Vector3(s, .033, 0)), Vector3(.004, .002, .03), Color("#4a2a18"))
		2: # 豆大福
			_ball(at + Vector3.UP * .02, Vector3(.032, .022, .032), Color("#f2eee6"), "sweet", 4, 8)
			_ball(at + Vector3(.012, .036, .006), Vector3(.006, .005, .006), Color("#3a2a28"), "sweet", 2, 4)
		3: # みたらし: three balls on a skewer, glazed.
			_kit.tube("room", [at + Vector3(-.075, .016, 0), at + Vector3(.07, .016, 0)], .003, Color("#d8c098"), 3)
			for i: int in range(3):
				_ball(at + Vector3(-.04 + float(i) * .036, .017, 0), Vector3(.017, .016, .017), Color("#b8762e"), "sweet", 3, 7)
		4: # どら焼
			_kit.lathe("sweet", at, [Vector2(.035, 0), Vector2(.045, .012), Vector2(.046, .02), Vector2(.04, .03), Vector2(0, .032)], Color("#8a4a1e"), 10)
		5: # 最中: a shell of wafer, the shop's crest pressed in.
			_kit.block("sweet", Transform3D(Basis(Vector3.UP, _rng.randf_range(-.3, .3)), at + Vector3.UP * .014), Vector3(.05, .026, .05), Color("#d8bc84"))
		6: # 柿: an orange namagashi with its green calyx.
			_ball(at + Vector3.UP * .022, Vector3(.03, .024, .03), Color("#e0782a"), "sweet", 4, 8)
			_kit.block("sweet", Transform3D(Basis(Vector3.UP, .7), at + Vector3.UP * .047), Vector3(.022, .006, .022), Color("#3a5a2a"))
		7: # 草餅
			_ball(at + Vector3.UP * .018, Vector3(.03, .02, .03), Color("#6a8a4a"), "sweet", 4, 8)
		8: # 紅葉: a maple-red namagashi.
			_ball(at + Vector3.UP * .02, Vector3(.03, .02, .03), Color("#b0302a"), "sweet", 4, 8)
			_ball(at + Vector3.UP * .036, Vector3(.012, .004, .012), Color("#e0a030"), "sweet", 2, 6)

func _tray(face: Transform3D, x: float, y: float, z: float, w: float, d: float, kind: int, card: int) -> void:
	# Shallow white-wood tray, a grid of one kind, the hand-written name stuck in the front.
	_bar("room", face, x, y + .006, z, Vector3(w, .012, d), TRAY)
	for s: float in [-1.0, 1.0]:
		_bar("room", face, x, y + .02, z + s * (d * .5 - .005), Vector3(w, .03, .01), TRAY.darkened(.08))
		_bar("room", face, x + s * (w * .5 - .005), y + .02, z, Vector3(.01, .03, d), TRAY.darkened(.12))
	var cols := maxi(1, int((w - .02) / (.13 if kind == 3 else .075)))
	var rows := maxi(1, int((d - .02) / (.06 if kind == 3 else .075)))
	for c: int in range(cols):
		for r: int in range(rows):
			if _rng.randf() < .12:
				continue
			var px := x - w * .5 + (float(c) + .5) * w / float(cols)
			var pz := z - d * .5 + (float(r) + .5) * d / float(rows)
			_sweet(kind, face * Vector3(px, y + .012, pz))
	if card >= 0:
		var cz := z + d * .5 + .004
		_panel("display", face, x - .03, x + .03, y + .03, y + .12, cz, _cell(420.0 + float(card) * 80.0, 1560, 80, 120))

func _showcase() -> void:
	# The glass case set out on the pavement as the 相州屋 photograph has it: dark base, a lit box
	# of trays in two tiers, stainless edges, and the e-paper price rail along its lip.
	var f := _front
	var cx := (CASE_X0 + CASE_X1) * .5
	var w := CASE_X1 - CASE_X0
	_bar("wood", f, cx, CASE_LOW * .5, CASE_Z * .5, Vector3(w, CASE_LOW, CASE_Z), DARKWOOD, .7, 1.0)
	_bar("plain", f, cx, .04, CASE_Z * .5 + .01, Vector3(w + .02, .08, CASE_Z + .02), Color("#1e1a16"))
	_bar("steel", f, cx, CASE_LOW - .015, CASE_Z * .5, Vector3(w + .02, .03, CASE_Z + .02), Color("#b8bab8"))
	# Inside: cream liner, back board, a lamp tube under the top glass.
	_kit.quad("room", f * Vector3(CASE_X0, CASE_LOW + .002, CASE_Z), f * Vector3(CASE_X0, CASE_LOW + .002, .0), f * Vector3(CASE_X1, CASE_LOW + .002, .0), f * Vector3(CASE_X1, CASE_LOW + .002, CASE_Z), Color("#efe6d2"))
	_flat("room", f, Rect2(CASE_X0, CASE_LOW, w, CASE_TOP - CASE_LOW), .01, Color("#b8a080"), 1.0, 0.0)
	_bar("lamp", f, cx, CASE_TOP - .03, .06, Vector3(w - .1, .02, .02), Color(1.0, .94, .8))
	# Lower tier: six trays across.
	var kinds: Array[int] = [0, 1, 2, 3, 6, 8]
	var cards: Array[int] = [0, 1, 2, 3, 6, -1]
	var n := 6
	var tw := (w - .08) / float(n)
	for i: int in range(n):
		_tray(f, CASE_X0 + .04 + tw * (float(i) + .5), CASE_LOW + .004, .3, tw - .025, .3, kinds[i], cards[i])
	# Upper tier on a glass shelf at the back.
	var shelf_y := .96
	_bar("steel", f, cx, shelf_y, .1, Vector3(w - .04, .008, .18), Color("#c8d8d4"))
	for x: float in [CASE_X0 + .06, CASE_X1 - .06]:
		_bar("steel", f, x, (CASE_LOW + shelf_y) * .5, .1, Vector3(.012, shelf_y - CASE_LOW, .012), Color("#b8bab8"))
	var upper: Array[int] = [4, 5, 7, 2, 0]
	var ucards: Array[int] = [4, 5, 7, -1, -1]
	var un := 5
	var uw := (w - .1) / float(un)
	for i: int in range(un):
		_tray(f, CASE_X0 + .05 + uw * (float(i) + .5), shelf_y + .006, .1, uw - .025, .16, upper[i], ucards[i])
	# Glass: front, top and both ends.
	var z := CASE_Z
	_kit.quad("front", f * Vector3(CASE_X0, CASE_LOW, z), f * Vector3(CASE_X0, CASE_TOP, z), f * Vector3(CASE_X1, CASE_TOP, z), f * Vector3(CASE_X1, CASE_LOW, z), Color.WHITE)
	_kit.quad("front", f * Vector3(CASE_X0, CASE_TOP, z), f * Vector3(CASE_X0, CASE_TOP, 0), f * Vector3(CASE_X1, CASE_TOP, 0), f * Vector3(CASE_X1, CASE_TOP, z), Color.WHITE)
	_kit.quad("front", f * Vector3(CASE_X0, CASE_LOW, 0), f * Vector3(CASE_X0, CASE_TOP, 0), f * Vector3(CASE_X0, CASE_TOP, z), f * Vector3(CASE_X0, CASE_LOW, z), Color.WHITE)
	_kit.quad("front", f * Vector3(CASE_X1, CASE_LOW, z), f * Vector3(CASE_X1, CASE_TOP, z), f * Vector3(CASE_X1, CASE_TOP, 0), f * Vector3(CASE_X1, CASE_LOW, 0), Color.WHITE)
	var edge := Color("#c4c6c4")
	_bar("steel", f, cx, CASE_TOP, z, Vector3(w + .02, .018, .018), edge)
	_bar("steel", f, cx, CASE_TOP, .01, Vector3(w + .02, .018, .018), edge)
	for x: float in [CASE_X0, CASE_X1]:
		_bar("steel", f, x, (CASE_LOW + CASE_TOP) * .5, z, Vector3(.018, CASE_TOP - CASE_LOW, .018), edge)
		_bar("steel", f, x, CASE_TOP, z * .5, Vector3(.018, .018, z), edge)
	# 2050: e-paper rail on the lip, payment pad on its post at the end.
	_bar("plain", f, cx, CASE_LOW - .07, z + .012, Vector3(w - .2, .07, .016), Color("#2a2c2c"))
	_panel("eink", f, CASE_X0 + .12, CASE_X1 - .12, CASE_LOW - .098, CASE_LOW - .042, z + .021, _cell(420, 1480, 600, 60))
	var pad := f * Vector3(CASE_X1 - .16, CASE_TOP + .012, .14)
	_kit.tube("metal", [pad, pad + Vector3.UP * .12], .012, Color("#3a3c3e"), 6)
	_kit.block("plain", Transform3D(Basis(Vector3.RIGHT, -.5), pad + Vector3(0, .17, .02)), Vector3(.13, .1, .016), Color("#1c1e20"))
	_kit.block("led", Transform3D(Basis(Vector3.RIGHT, -.5), pad + Vector3(0, .172, .029)), Vector3(.1, .07, .002), CYAN * .5)
	# Paper weights against the wind: a pebble on the top glass, a stack of shop leaflets.
	_kit.block("room", Transform3D(Basis(Vector3.UP, .2), f * Vector3(CASE_X0 + .3, CASE_TOP + .006, .3)), Vector3(.15, .01, .21), Color("#f4efe2"))

func _shop_glass() -> void:
	# Above the case: two sliding glazed sashes in cedar, posters taped on the inside.
	var f := _front
	var x0 := SHOW.position.x
	var x1 := SHOW.end.x
	var y0 := CASE_TOP
	var y1 := SHOW.end.y
	var mid := (x0 + x1) * .5
	_kit.quad("front", f * Vector3(x0, y0, -.05), f * Vector3(x0, y1, -.05), f * Vector3(mid + .02, y1, -.05), f * Vector3(mid + .02, y0, -.05), Color.WHITE)
	_kit.quad("front", f * Vector3(mid - .02, y0, -.09), f * Vector3(mid - .02, y1, -.09), f * Vector3(x1, y1, -.09), f * Vector3(x1, y0, -.09), Color.WHITE)
	var frame := Color("#5a3e2a")
	for leaf: Array in [[x0, mid + .02, -.05], [mid - .02, x1, -.09]]:
		var a: float = leaf[0]
		var b: float = leaf[1]
		var z: float = leaf[2]
		for x: float in [a + .025, b - .025]:
			_bar("wood", f, x, (y0 + y1) * .5, z, Vector3(.05, y1 - y0, .04), frame)
		for y: float in [y0 + .025, y1 - .025, y0 + (y1 - y0) * .62]:
			_bar("wood", f, (a + b) * .5, y, z, Vector3(b - a, .04, .04), frame)
	_bar("wood", f, (x0 + x1) * .5, y0 - .01, -.02, Vector3(x1 - x0, .03, .1), frame.darkened(.2))
	# Posters on the inside of the glass, the shop's real advertising.
	_panel("display", f, x0 + .1, x0 + .36, 1.32, 1.84, -.11, _cell(0, 720, 260, 520))
	_panel("display", f, x0 + .42, x0 + .68, 1.32, 1.84, -.11, _cell(270, 720, 260, 520))
	_panel("display", f, mid + .12, mid + .48, 1.36, 1.88, -.13, _cell(540, 720, 360, 520))
	_panel("display", f, x1 - .38, x1 - .1, 1.38, 1.75, -.13, _cell(1220, 720, 300, 400))

func _door() -> void:
	# Two cedar-framed glass sliders, a kick board, gilt name, and the 商い中 board on its cord.
	var f := _front
	var r := DOOR
	var half := r.size.x * .5
	var frame := Color("#5a3e2a")
	for i: int in range(2):
		var a := r.position.x + float(i) * (half - .03)
		var b := a + half + .03
		var z := -.06 - float(i) * .05
		_kit.quad("front", f * Vector3(a, .46, z), f * Vector3(a, r.end.y - .06, z), f * Vector3(b, r.end.y - .06, z), f * Vector3(b, .46, z), Color.WHITE)
		_bar("wood", f, (a + b) * .5, .24, z, Vector3(b - a, .44, .035), CEDAR.darkened(.15))
		for x: float in [a + .03, b - .03]:
			_bar("wood", f, x, r.end.y * .5, z, Vector3(.06, r.end.y, .045), frame)
		for y: float in [.47, r.end.y - .04, 1.3]:
			_bar("wood", f, (a + b) * .5, y, z, Vector3(b - a, .05, .045), frame)
		for y: float in [.85, 1.75, 2.05]:
			_bar("wood", f, (a + b) * .5, y, z, Vector3(b - a - .06, .015, .02), frame)
		_bar("metal", f, (b - .1) if i == 0 else (a + .1), 1.05, z + .03, Vector3(.025, .14, .012), Color("#2a2624"))
		_panel("decal", f, a + .1, b - .1, 1.36, 1.68, z + .025, _cell(420.0 + float(i) * 300.0, 1700, 300, 140))
	_bar("metal", f, r.get_center().x, .015, -.08, Vector3(r.size.x, .03, .12), Color("#7a7670"))
	# 商い中 on a cord from the right leaf's rail.
	var hook := f * Vector3(1.72, 1.72, -.07)
	_kit.tube("plain", [hook + Vector3(-.08, -.08, 0), hook, hook + Vector3(.08, -.08, 0)], .003, Color("#d8c8a0"), 3)
	_panel("display", f, 1.6, 1.84, 1.5, 1.64, -.068, _cell(1040, 1840, 200, 120))

func _noren() -> void:
	# Three drops of indigo, the kanji white, swinging a hand's breadth off the doors.
	var f := _front
	var x0 := DOOR.position.x - .03
	var top := 2.33
	var drop := .86
	var wide := (DOOR.size.x + .06) / 3.0
	var full := _cell(0, 280, 1200, 420)
	_kit.tube("wood", [f * Vector3(x0 - .1, top + .02, .1), f * Vector3(x0 + wide * 3.0 + .1, top + .02, .1)], .016, Color("#3a2a1c"), 6)
	for side: float in [x0 - .06, x0 + wide * 3.0 + .06]:
		_bar("metal", f, side, top + .06, .06, Vector3(.02, .1, .1), Color("#2a2624"))
	for i: int in range(3):
		var left := x0 + float(i) * wide + .01
		var right := left + wide - .02
		var columns := 5
		for c: int in range(columns):
			var u0 := float(c) / float(columns)
			var u1 := float(c + 1) / float(columns)
			var a0 := lerpf(left, right, u0)
			var a1 := lerpf(left, right, u1)
			var w0 := .1 + sin(u0 * 6.0 + float(i) * 2.1) * .018
			var w1 := .1 + sin(u1 * 6.0 + float(i) * 2.1) * .018
			var patch := full
			patch.position.x = full.position.x + (float(i) + u0) / 3.0 * full.size.x
			patch.size.x = full.size.x / 3.0 / float(columns)
			_kit.atlas("cloth", f * Vector3(a0, top - drop, w0 + .02), f * Vector3(a0, top, .1), f * Vector3(a1, top, .1), f * Vector3(a1, top - drop, w1 + .02), patch, Color.WHITE, .9, .15)
			_kit.atlas("cloth", f * Vector3(a1, top - drop, w1 + .018), f * Vector3(a1, top, .098), f * Vector3(a0, top, .098), f * Vector3(a0, top - drop, w0 + .018), patch, Color(.35, .35, .4), .7)

# ---------------------------------------------------------------- roofs

func _slope(x0: float, x1: float, low: Vector2, high: Vector2, tint: Color, pitch := .27) -> void:
	# Ibushi kawara: the bed, round-backed courses down the slope, and a tile end at each foot.
	# low and high are (z, y) of the eave and the top edge.
	var h := WIDE * .5
	var dz := high.x - low.x
	var dy := high.y - low.y
	var n := Vector3(0, absf(dz), -signf(dz) * dy).normalized()
	var front := low.x > high.x
	var lo0 := Vector3(x0 - h, low.y, low.x)
	var hi0 := Vector3(x0 - h, high.y, high.x)
	var lo1 := Vector3(x1 - h, low.y, low.x)
	var hi1 := Vector3(x1 - h, high.y, high.x)
	if front:
		_kit.quad("kawara", lo0, hi0, hi1, lo1, tint, .8, 1.0)
	else:
		_kit.quad("kawara", lo1, hi1, hi0, lo0, tint, .8, 1.0)
	var right := Vector3.RIGHT if front else Vector3.LEFT
	var x := x0 + pitch * .5
	while x < x1:
		var tone := tint * _rng.randf_range(.88, 1.08)
		var a := Vector3(x - h, low.y, low.x) + n * .028
		var b := Vector3(x - h, high.y, high.x) + n * .028
		_kit.tube("kawara", [a, b], .05, tone, 5)
		var out := (a - b).normalized()
		_kit.disc("kawara", a + out * .006, right, n, .06, tint * .82)
		x += pitch
	# Courses: each row of tiles laps the one below in a little step.
	var length := Vector2(dz, dy).length()
	var t := .3
	while t < length - .1:
		var p: Vector3 = Vector3(0, low.y, low.x).lerp(Vector3(0, high.y, high.x), t / length) + n * .012
		_kit.beam("kawara", Vector3(x0 - h, p.y, p.z), Vector3(x1 - h, p.y, p.z), .03, .02, n, tint * .78)
		t += .3
	# Barge boards at both ends.
	for at: float in [x0 + .03, x1 - .03]:
		var from := Vector3(at - h, low.y, low.x) - n * .06
		var to := Vector3(at - h, high.y, high.x) - n * .06
		_kit.beam("wood", from, to, .05, .2, n, DARKWOOD)

func _hisashi() -> void:
	# The pent roof over the shop: kawara on cedar brackets, a copper gutter, two lamps in its soffit.
	var f := _front
	var h := WIDE * .5
	var x0 := -.06
	var x1 := WIDE + .06
	_slope(x0, x1, HISASHI_LOW, HISASHI_HIGH, TILE, .26)
	var under := -.09
	_kit.quad("wood", Vector3(x0 - h, HISASHI_HIGH.y + under, 0), Vector3(x0 - h, HISASHI_LOW.y + under, HISASHI_LOW.x), Vector3(x1 - h, HISASHI_LOW.y + under, HISASHI_LOW.x), Vector3(x1 - h, HISASHI_HIGH.y + under, 0), Color("#6a4a32"), .6, .7)
	var x := x0 + .2
	while x < x1:
		_kit.beam("wood", Vector3(x - h, HISASHI_HIGH.y + under - .03, 0), Vector3(x - h, HISASHI_LOW.y + under - .03, HISASHI_LOW.x), .05, .06, Vector3.UP, DARKWOOD)
		x += .45
	# Brackets on the three posts, front board, gutter.
	for px: float in [.07, 2.38, WIDE - .08]:
		_kit.beam("wood", f * Vector3(px, 2.62, .05), f * Vector3(px, HISASHI_LOW.y - .08, HISASHI_LOW.x - .06), .1, .12, Vector3.UP, DARKWOOD)
	_kit.block("wood", Transform3D(Basis.IDENTITY, Vector3(WIDE * .5 - h, HISASHI_LOW.y - .04, HISASHI_LOW.x + .01)), Vector3(x1 - x0, .12, .04), DARKWOOD)
	_kit.tube("metal", [Vector3(x0 - h, HISASHI_LOW.y - .1, HISASHI_LOW.x + .08), Vector3(x1 - h, HISASHI_LOW.y - .1, HISASHI_LOW.x + .08)], .045, Color("#5a6a5e"), 6)
	_kit.tube("metal", [Vector3(x1 - h - .04, HISASHI_LOW.y - .1, HISASHI_LOW.x + .08), Vector3(x1 - h - .04, .08, HISASHI_LOW.x + .08)], .03, Color("#5a6a5e"), 6)
	for lx: float in [1.4, 3.6]:
		var at := f * Vector3(lx, HISASHI_HIGH.y + under - (HISASHI_HIGH.y - HISASHI_LOW.y) * .4 - .02, .35)
		_kit.lathe("metal", at + Vector3.DOWN * .05, [Vector2(.06, 0), Vector2(.05, .05)], Color("#2a2624"), 8)
		_kit.disc("lamp", at + Vector3.DOWN * .052, Vector3.RIGHT, Vector3.BACK, .045, Color(1.0, .86, .62))

func _kanban() -> void:
	# The keyaki board standing on the pent roof, under its own copper cap, lit by two goosenecks.
	var f := _front
	var x0 := .95
	var x1 := 3.75
	var y0 := 3.36
	var y1 := 3.98
	var z := .16
	_bar("wood", f, (x0 + x1) * .5, (y0 + y1) * .5, z - .05, Vector3(x1 - x0 + .1, y1 - y0 + .1, .08), Color("#24160e"))
	_panel("sign", f, x0, x1, y0 + .02, y1 - .02, z - .008, _cell(0, 0, 1400, 260))
	_bar("metal", f, (x0 + x1) * .5, y1 + .07, z - .04, Vector3(x1 - x0 + .24, .04, .2), Color("#4a6a5a"))
	_bar("metal", f, (x0 + x1) * .5, y1 + .1, z - .06, Vector3(x1 - x0 + .16, .03, .12), Color("#3e5a4c"))
	for x: float in [x0 + .3, x1 - .3]:
		_bar("wood", f, x, y0 - .02, z - .1, Vector3(.08, .2, .08), DARKWOOD)
		var base := f * Vector3(x, y1 + .14, .02)
		_kit.tube("metal", [base, base + Vector3(0, .14, .12), base + Vector3(0, .12, .34)], .01, Color("#2a2624"), 4)
		var shade := base + Vector3(0, .1, .36)
		_kit.lathe("metal", shade, [Vector2(.02, .06), Vector2(.06, 0)], Color("#2a2624"), 8)
		_kit.disc("lamp", shade + Vector3.DOWN * .002, Vector3.RIGHT, Vector3.BACK, .05, Color(1.0, .88, .66))

func _roof() -> void:
	var h := WIDE * .5
	var x0 := -.09
	var x1 := WIDE + .09
	_slope(x0, x1, Vector2(FRONT_EDGE, EAVE), Vector2(RIDGE_Z, RIDGE), TILE)
	_slope(x0, x1, Vector2(BACK_EDGE, EAVE), Vector2(RIDGE_Z, RIDGE), TILE * .94)
	# Ridge: stacked noshi tiles under a round cap, a demon tile at each end.
	_kit.beam("kawara", Vector3(x0 - h, RIDGE + .08, RIDGE_Z), Vector3(x1 - h, RIDGE + .08, RIDGE_Z), .34, .18, Vector3.UP, TILE * .9)
	for k: int in range(3):
		_kit.beam("kawara", Vector3(x0 - h, RIDGE + .19 + float(k) * .05, RIDGE_Z), Vector3(x1 - h, RIDGE + .19 + float(k) * .05, RIDGE_Z), .26 - float(k) * .03, .04, Vector3.UP, TILE * (.8 + float(k) * .06))
	_kit.tube("kawara", [Vector3(x0 - h, RIDGE + .34, RIDGE_Z), Vector3(x1 - h, RIDGE + .34, RIDGE_Z)], .08, TILE, 8)
	for ex: float in [x0 - .02, x1 + .02]:
		_kit.block("kawara", Transform3D(Basis.IDENTITY, Vector3(ex - h, RIDGE + .26, RIDGE_Z)), Vector3(.1, .5, .42), TILE * .85)
		_kit.disc("kawara", Vector3(ex - h + (.051 if ex > 1.0 else -.051), RIDGE + .3, RIDGE_Z), Vector3.FORWARD if ex > 1.0 else Vector3.BACK, Vector3.UP, .14, TILE * .7)
	# Soffits under both eaves, rafter ends, fascia board and the front gutter.
	var wall_front := _roof_y(0) - .12
	var wall_back := _roof_y(-DEEP) - .12
	var ye := EAVE - .12
	_kit.quad("wood", Vector3(x0 - h, wall_front, 0), Vector3(x0 - h, ye, FRONT_EDGE), Vector3(x1 - h, ye, FRONT_EDGE), Vector3(x1 - h, wall_front, 0), Color("#5a4030"), .5, .6)
	_kit.quad("wood", Vector3(x1 - h, wall_back, -DEEP), Vector3(x1 - h, ye, BACK_EDGE), Vector3(x0 - h, ye, BACK_EDGE), Vector3(x0 - h, wall_back, -DEEP), Color("#5a4030"), .5, .6)
	var x := x0 + .15
	while x < x1:
		_kit.beam("wood", Vector3(x - h, wall_front - .03, 0), Vector3(x - h, ye - .03, FRONT_EDGE), .05, .07, Vector3.UP, DARKWOOD)
		x += .42
	_kit.block("wood", Transform3D(Basis.IDENTITY, Vector3(WIDE * .5 - h, EAVE - .1, FRONT_EDGE + .02)), Vector3(x1 - x0, .16, .04), DARKWOOD)
	_kit.block("wood", Transform3D(Basis.IDENTITY, Vector3(WIDE * .5 - h, EAVE - .1, BACK_EDGE - .02)), Vector3(x1 - x0, .16, .04), DARKWOOD)
	var gutter := Color("#6a5a48")
	_kit.tube("metal", [Vector3(x0 - h, EAVE - .2, FRONT_EDGE + .09), Vector3(x1 - h, EAVE - .2, FRONT_EDGE + .09)], .055, gutter, 6)
	_kit.tube("metal", [Vector3(x1 - h - .1, EAVE - .2, FRONT_EDGE + .09), Vector3(x1 - h - .1, EAVE - .5, .1), Vector3(x1 - h - .1, HISASHI_HIGH.y + .05, .1)], .035, gutter, 6)
	_kit.tube("metal", [Vector3(x0 - h, EAVE - .2, BACK_EDGE - .09), Vector3(x1 - h, EAVE - .2, BACK_EDGE - .09)], .055, gutter, 6)
	# The 2050 layer on the back slope: a strip of solar, a sensor mast on the old aerial.
	var slope := atan2(RIDGE - EAVE, RIDGE_Z - BACK_EDGE)
	_solar_module(Transform3D(Basis(Vector3.RIGHT, -PI * .5 - slope), Vector3(.2, _roof_y(-5.0) + .12, -5.0)), 2.6, 1.0)
	_kit.tube("metal", [Vector3(1.6, _roof_y(-4.4), -4.4), Vector3(1.6, RIDGE + 1.5, -4.4)], .018, ALUMINIUM, 5)
	for y: float in [RIDGE + .9, RIDGE + 1.2]:
		_kit.tube("metal", [Vector3(1.1, y, -4.4), Vector3(2.1, y, -4.4)], .006, ALUMINIUM, 3)
	_kit.lathe("plain", Vector3(1.6, RIDGE + 1.5, -4.4), [Vector2(.05, 0), Vector2(.06, .04), Vector2(.02, .1)], Color("#d6d6d0"), 8)
	_status(Transform3D(Basis.IDENTITY, Vector3(1.6, RIDGE + 1.56, -4.38)), 0, 0, 0, GREEN)

# ---------------------------------------------------------------- upstairs

func _upper_front() -> void:
	# The flat: oiled cedar boards, an aluminium sash behind a wooden rail, a shoji lit late.
	var f := _front
	var top := _roof_y(0) - .1
	var holes: Array[Rect2] = [WIN_L.grow(.06), WIN_R.grow(.06)]
	var x := .0
	while x < WIDE - .01:
		var run := minf(.21, WIDE - x)
		var tone := _rng.randf_range(.86, 1.06)
		var tint := Color(CEDAR.r * tone, CEDAR.g * tone, CEDAR.b * tone)
		var uv := Vector2(_rng.randf() * 3.0, _rng.randf() * 3.0)
		for piece: Rect2 in _minus(Rect2(x, GROUND, run, top - GROUND), holes):
			_kit.quad("clap", f * Vector3(piece.position.x, piece.position.y, 0), f * Vector3(piece.position.x, piece.end.y, 0), f * Vector3(piece.end.x, piece.end.y, 0), f * Vector3(piece.end.x, piece.position.y, 0), tint, .8, 1.0, .8, uv + Vector2(0, -piece.position.y))
		x += run
	# Battens over the joints every third board, stopping at the windows.
	var bx := .63
	while bx < WIDE - .1:
		for piece: Rect2 in _minus(Rect2(bx - .02, GROUND, .04, top - GROUND), holes):
			_bar("wood", f, piece.get_center().x, piece.get_center().y, .015, Vector3(.035, piece.size.y, .03), CEDAR.darkened(.3))
		bx += .63
	_bar("wood", f, WIDE * .5, top - .03, .03, Vector3(WIDE, .1, .08), DARKWOOD)
	_bar("wood", f, .05, (GROUND + top) * .5, .03, Vector3(.1, top - GROUND, .08), DARKWOOD)
	_bar("wood", f, WIDE - .05, (GROUND + top) * .5, .03, Vector3(.1, top - GROUND, .08), DARKWOOD)
	_window(f, WIN_L, .52, false)
	# Wooden window rail, cedar gone silver.
	var rail := Color("#7a6a58")
	var rx0 := WIN_L.position.x - .1
	var rx1 := WIN_L.end.x + .1
	var rz := .2
	for y: float in [WIN_L.position.y - .02, WIN_L.position.y + .48]:
		_bar("wood", f, (rx0 + rx1) * .5, y, rz, Vector3(rx1 - rx0, .05, .06), rail)
	var i := 0
	var px := rx0 + .06
	while px < rx1 - .03:
		_bar("wood", f, px, WIN_L.position.y + .23, rz, Vector3(.03, .46, .03), rail.darkened(.08 if i % 2 == 0 else 0.0))
		px += .11
		i += 1
	for x2: float in [rx0 + .05, rx1 - .05]:
		_bar("wood", f, x2, WIN_L.position.y - .06, rz * .5, Vector3(.05, .05, rz), rail.darkened(.2))
	# Laundry pole on two arms, the morning's washing still out.
	var py := 5.32
	for ax: float in [.25, 2.85]:
		_kit.tube("metal", [f * Vector3(ax, py - .1, .02), f * Vector3(ax, py, .55)], .012, ALUMINIUM, 4)
	_kit.tube("metal", [f * Vector3(.15, py, .52), f * Vector3(2.95, py, .52)], .018, Color("#b8bcc0"), 6)
	var hung: Array[Color] = [Color("#e6e4dc"), Color("#5a6a8a"), Color("#d8cfc0"), Color("#9a4a3a")]
	var lx := .5
	for k: int in range(3):
		var w := _rng.randf_range(.32, .5)
		var long := _rng.randf_range(.32, .5)
		_kit.quad("plain", f * Vector3(lx, py - long, .54), f * Vector3(lx, py, .52), f * Vector3(lx + w, py, .52), f * Vector3(lx + w, py - long, .54), hung[k], .85, 1.0)
		_kit.quad("plain", f * Vector3(lx + w, py - long, .52), f * Vector3(lx + w, py, .51), f * Vector3(lx, py, .51), f * Vector3(lx, py - long, .52), hung[k].darkened(.3), .8, 1.0)
		lx += w + .3
	_shoji_window()
	# Air-con on the pent roof, drone drop box on the other end: the 2050 layer stays small.
	var roof_at := func(z: float) -> float: return lerpf(HISASHI_HIGH.y, HISASHI_LOW.y, z / HISASHI_LOW.x)
	_outdoor_unit(f, 4.4, roof_at.call(.42) + .36, .42)
	_bar("metal", f, 4.4, roof_at.call(.42) + .03, .42, Vector3(.7, .06, .3), Color("#3a3a38"))
	var dz := .4
	var dy: float = roof_at.call(dz) + .05
	_bar("metal", f, .5, dy + .2, dz, Vector3(.48, .38, .38), Color("#3c4044"))
	_bar("metal", f, .5, dy + .4, dz, Vector3(.54, .02, .44), Color("#2a2c2e"))
	_bar("plain", f, .5, dy + .2, dz + .192, Vector3(.4, .3, .004), Color("#30343a"))
	_strip(f * Vector3(.28, dy + .405, dz + .22), f * Vector3(.72, dy + .405, dz + .22), CYAN * .6)
	_status(f, .68, dy + .32, dz + .196, GREEN)

func _shoji_window() -> void:
	# The grandmother's room: wooden sash, and behind the glass a shoji with the lamp on.
	var f := _front
	var r := WIN_R
	_reveal(f, r, .14, Color("#5a4a3a"))
	_kit.quad("shoji", f * Vector3(r.position.x, r.position.y, -.13), f * Vector3(r.position.x, r.end.y, -.13), f * Vector3(r.end.x, r.end.y, -.13), f * Vector3(r.end.x, r.position.y, -.13), Color("#f4ecd8"))
	var x := r.position.x + .2
	while x < r.end.x - .05:
		_bar("plain", f, x, r.get_center().y, -.125, Vector3(.012, r.size.y, .006), Color("#5a4630"))
		x += .2
	var y := r.position.y + .26
	while y < r.end.y - .05:
		_bar("plain", f, r.get_center().x, y, -.125, Vector3(r.size.x, .012, .006), Color("#5a4630"))
		y += .26
	_bar("plain", f, r.get_center().x, r.get_center().y, -.122, Vector3(.03, r.size.y, .01), Color("#4a3a28"))
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, -.05), f * Vector3(r.position.x, r.end.y, -.05), f * Vector3(r.end.x, r.end.y, -.05), f * Vector3(r.end.x, r.position.y, -.05), Color.WHITE)
	var frame := Color("#4a3626")
	for x2: float in [r.position.x + .025, r.get_center().x, r.end.x - .025]:
		_bar("wood", f, x2, r.get_center().y, -.05, Vector3(.045, r.size.y, .05), frame)
	for y2: float in [r.position.y + .025, r.end.y - .025]:
		_bar("wood", f, r.get_center().x, y2, -.05, Vector3(r.size.x, .045, .05), frame)
	_bar("wood", f, r.get_center().x, r.end.y + .08, .05, Vector3(r.size.x + .2, .05, .12), DARKWOOD)
	# Planter of chrysanthemums on the sill.
	var px0 := r.position.x + .05
	var px1 := r.end.x - .05
	_bar("wood", f, (px0 + px1) * .5, r.position.y - .1, .14, Vector3(px1 - px0, .18, .2), Color("#6a5040"))
	_bar("metal", f, (px0 + px1) * .5, r.position.y - .21, .1, Vector3(px1 - px0 + .1, .03, .24), Color("#3a3a38"))
	for k: int in range(4):
		var at := f * Vector3(lerpf(px0 + .15, px1 - .15, float(k) / 3.0), r.position.y - .02, .14)
		_plant(at, .24, Color("#4a6a3a"))
		for b: int in range(3):
			_ball(at + Vector3(_rng.randf_range(-.08, .08), _rng.randf_range(.12, .22), _rng.randf_range(-.04, .06)), Vector3(.03, .022, .03), [Color("#e8c040"), Color("#f0ece0"), Color("#c8603a")][k % 3], "plain", 3, 6)

# ---------------------------------------------------------------- side and back walls

func _wall(face: Transform3D, length: float, to_z: Callable, holes: Array[Rect2], flat: bool) -> void:
	# Burnt-cedar boards to shoulder height, plaster over them, timber frame showing through,
	# and the gable following the roof.
	var low := 1.9
	var top := _roof_y(to_z.call(length * .5)) - .12 if flat else EAVE - .12
	for piece: Rect2 in _minus(Rect2(0, .22, length, low - .22), holes):
		_flat("char", face, piece, 0.0, CHAR, .8, .3)
	for piece: Rect2 in _minus(Rect2(0, low, length, top - low), holes):
		_flat("plaster", face, piece, 0.0, PLASTER * .96, .85, .9)
	_bar("stone", face, length * .5, .11, .02, Vector3(length, .22, .05), Color("#8a8680"), .8, 1.0)
	if not flat:
		var x := .0
		while x < length - .01:
			var run := minf(.5, length - x)
			var t0: float = _roof_y(to_z.call(x)) - .12
			var t1: float = _roof_y(to_z.call(x + run)) - .12
			if maxf(t0, t1) > top + .01:
				_kit.quad("plaster", face * Vector3(x, top, 0), face * Vector3(x, t0, 0), face * Vector3(x + run, t1, 0), face * Vector3(x + run, top, 0), PLASTER * .94, .9, .95, .9, Vector2(x, -top))
			x += run
	# Frame: sill beam, floor beam, wall plate, three posts.
	for y: float in [low, GROUND, top]:
		for piece: Rect2 in _minus(Rect2(0, y - .05, length, .1), holes):
			_bar("wood", face, piece.get_center().x, y, .02, Vector3(piece.size.x, .1, .05), DARKWOOD, .8, 1.0)
	for x: float in [.06, length * .5, length - .06]:
		for piece: Rect2 in _minus(Rect2(x - .06, .22, .12, top - .22), holes):
			_bar("wood", face, x, piece.get_center().y, .025, Vector3(.12, piece.size.y, .05), DARKWOOD, .8, 1.0)

func _side_walls() -> void:
	var to_z_east := func(x: float) -> float: return -x
	var to_z_west := func(x: float) -> float: return x - DEEP
	var to_z_back := func(_x: float) -> float: return -DEEP
	_wall(_east, DEEP, to_z_east, [E_WIN.grow(.05), E_LOW.grow(.05)], false)
	_wall(_west, DEEP, to_z_west, [W_WIN.grow(.05)], false)
	_wall(_back, WIDE, to_z_back, [B_WIN.grow(.05), B_DOOR], true)
	_window(_east, E_WIN, .71, false)
	_window(_east, E_LOW, .58, true)
	_window(_west, W_WIN, .44, false)
	_window(_back, B_WIN, .87, false)
	var e := _east
	# East: the old enamel plate by the front, gas meter and pipes, a hood for the steamer.
	_bar("metal", e, .48, 1.25, .012, Vector3(.3, .58, .02), Color("#2a2a28"))
	_panel("board", e, .35, .61, .98, 1.52, .024, _cell(1800, 780, 220, 460))
	_bar("metal", e, 2.0, .95, .08, Vector3(.26, .32, .14), Color("#c8c6b8"))
	_bar("plain", e, 2.0, .98, .152, Vector3(.14, .1, .004), Color("#1c1e20"))
	_kit.tube("metal", [e * Vector3(.3, .55, .05), e * Vector3(2.0, .55, .05), e * Vector3(2.0, .78, .08)], .016, Color("#b4a24a"), 6)
	_kit.tube("metal", [e * Vector3(2.0, 1.12, .08), e * Vector3(2.0, 1.4, .05), e * Vector3(6.2, 1.4, .05)], .016, Color("#b4a24a"), 6)
	_bar("steel", e, 5.6, 2.5, .14, Vector3(.4, .4, .26), Color("#9a9c98"))
	_bar("steel", e, 5.6, 2.28, .2, Vector3(.44, .04, .3), Color("#7a7c78"))
	_kit.quad("plain", e * Vector3(5.42, 1.0, .012), e * Vector3(5.42, 2.3, .012), e * Vector3(5.78, 2.3, .012), e * Vector3(5.78, 1.0, .012), Color(.22, .18, .14), .9, 1.0)
	_outdoor_unit(e, 3.9, 4.35, .2)
	_bar("metal", e, 3.9, 4.0, .2, Vector3(.9, .04, .34), Color("#3a3a38"))
	_kit.tube("plain", [e * Vector3(3.5, 4.3, .03), e * Vector3(3.3, 4.3, .03), e * Vector3(3.3, .25, .03)], .016, Color("#d6d0c0"), 4)
	_fibre([e * Vector3(.1, EAVE - .25, .06), e * Vector3(6.4, EAVE - .25, .06)])
	_kit.tube("metal", [e * Vector3(6.45, EAVE - .1, .08), e * Vector3(6.45, .1, .08)], .04, Color("#6a5a48"), 7)
	_bar("plain", e, 3.3, 6.5, .01, Vector3(.5, .3, .02), Color("#2a2a28"))
	for k: int in range(4):
		_bar("wood", e, 3.3, 6.39 + float(k) * .075, .025, Vector3(.46, .025, .03), DARKWOOD)
	# West: plain, a downpipe, the barber's side of things.
	var w := _west
	_kit.tube("metal", [w * Vector3(.2, EAVE - .1, .08), w * Vector3(.2, .1, .08)], .04, Color("#6a5a48"), 7)
	_bar("metal", w, 1.4, 1.0, .08, Vector3(.3, .4, .14), Color("#8a8c88"))
	# Back: the kitchen door and the water heater.
	var b := _back
	_flat("wood", b, B_DOOR, .01, Color("#6a5a48"), .8, .5)
	_bar("wood", b, B_DOOR.get_center().x, B_DOOR.end.y + .04, .04, Vector3(B_DOOR.size.x + .1, .08, .08), DARKWOOD)
	_bar("metal", b, B_DOOR.position.x + .7, 1.0, .03, Vector3(.03, .03, .03), Color("#a88a4a"))
	_bar("metal", b, 2.8, 1.2, .2, Vector3(.5, .8, .34), Color("#d8d6cc"))

# ---------------------------------------------------------------- pavement

func _street_things() -> void:
	var f := _front
	# 提灯 on the middle post, the name down its belly.
	var at := f * Vector3(2.38, 2.28, .72)
	var hang := f * Vector3(2.38, HISASHI_LOW.y - .1, .72)
	_kit.tube("metal", [hang, at + Vector3.UP * .4], .006, Color("#1a1a1a"), 4)
	_kit.lathe("metal", at + Vector3.UP * .33, [Vector2(.11, 0), Vector2(.11, .06)], Color("#141414"), 12)
	_kit.lathe("metal", at + Vector3.DOWN * .36, [Vector2(.11, 0), Vector2(.11, .05)], Color("#141414"), 12)
	var profile: Array[Vector2] = [Vector2(.11, -.32), Vector2(.17, -.24), Vector2(.2, -.1), Vector2(.205, 0), Vector2(.2, .1), Vector2(.17, .24), Vector2(.11, .33)]
	_kit.lathe("lantern", at, profile, Color.WHITE, 18, _cell(1220, 280, 500, 300))
	# 行灯 on the pavement by the door: paper in a black frame, standing on short legs.
	var ax := .25
	var az := .42
	var ay := .28
	var s := .14
	var tall := .66
	var faces: Array[Transform3D] = []
	for k: int in range(4):
		faces.append(Transform3D(Basis(Vector3.UP, PI * .5 * float(k)), f * Vector3(ax, 0, az)))
	for xf: Transform3D in faces:
		_kit.atlas("lantern", xf * Vector3(-s, ay, s), xf * Vector3(-s, ay + tall, s), xf * Vector3(s, ay + tall, s), xf * Vector3(s, ay, s), _cell(1540, 720, 240, 400))
		_kit.block("plain", Transform3D(xf.basis, xf * Vector3(s, ay + tall * .5, s)), Vector3(.025, tall + .04, .025), Color("#141210"))
		_kit.block("plain", Transform3D(xf.basis, xf * Vector3(s - .01, ay * .5, s - .01)), Vector3(.025, ay, .025), Color("#141210"))
	_kit.block("plain", Transform3D(Basis.IDENTITY, f * Vector3(ax, ay + tall + .03, az)), Vector3(s * 2.0 + .08, .04, s * 2.0 + .08), Color("#141210"))
	_kit.block("plain", Transform3D(Basis.IDENTITY, f * Vector3(ax, ay, az)), Vector3(s * 2.0 + .03, .025, s * 2.0 + .03), Color("#141210"))
	_kit.block("lamp", Transform3D(Basis.IDENTITY, f * Vector3(ax, ay + tall * .5, az)), Vector3(.05, .2, .05), Color(1.0, .84, .6))
	# のぼり for the season's sweet, at the end of the case.
	var base := f * Vector3(WIDE - .1, 0, .78)
	_kit.lathe("plain", base, [Vector2(.16, 0), Vector2(.16, .09), Vector2(.05, .12), Vector2(.03, .14)], Color("#2a2a2c"), 10)
	_kit.tube("metal", [base, base + Vector3.UP * 2.35], .012, Color("#d8d8d4"), 5)
	var along := -f.basis.x
	_kit.tube("metal", [base + Vector3.UP * 2.25, base + Vector3.UP * 2.25 + along * .42], .007, Color("#d8d8d4"), 4)
	var rect := _cell(1800, 0, 220, 760)
	var a := base + Vector3.UP * .78 + along * .02
	var b := base + Vector3.UP * 2.23 + along * .02
	var c := base + Vector3.UP * 2.23 + along * .42
	var d := base + Vector3.UP * .78 + along * .42 + f.basis.z * .03
	_kit.atlas("board", d, c, b, a, rect, Color.WHITE, .95, .2)
	_kit.atlas("board", a, b, c, d, Rect2(rect.end.x, rect.position.y, -rect.size.x, rect.size.y), Color(.7, .7, .7), .85)
	# A pot of nanten by the post, its berries red for the year's end.
	var pot := f * Vector3(2.38, 0, .3)
	_kit.lathe("plain", pot, [Vector2(.11, 0), Vector2(.15, .2), Vector2(.16, .22), Vector2(.14, .23)], Color("#5a4a3e"), 10)
	_plant(pot + Vector3.UP * .22, .5, Color("#4a6a34"))
	for k: int in range(7):
		_ball(pot + Vector3(_rng.randf_range(-.12, .12), _rng.randf_range(.45, .65), _rng.randf_range(-.1, .1)), Vector3(.018, .018, .018), Color("#c0261c"), "plain", 3, 5)
