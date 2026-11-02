extends "res://scripts/midori_near_city_handmade.gd"
## 亀の家不動産 at street level, sixty-five years of paper taped to its own window, and 登竜ゼミナール
## stacked over it: study room, junior classroom, senior classroom behind cream curtains. An
## accountant keeps the tin box on the roof. The stair tower is the only thing all of them share.
const ATLAS := "res://assets/shinrai/near_city/fudosan_atlas.png"
const WIDE := 5.5
const DEEP := 9.2
const CORE := 1.3
const GROUND := 3.4
const STOREY := 3.1
const DECK := 12.7
const PARAPET := 13.5
const PENT := 15.8
const SET := 2.4
const SHOP_TOP := 2.72
const SHOP_DEEP := 6.0
const NAVY := Color("#12336e")
const TILE := Color("#4e2f26")
const STONE := Color(.27, .25, .25)
const PALE := Color("#d9d4c6")
const WOOD := Color("#b48a58")
const STAIR := Rect2(.14, .02, .9, 2.3)
const GLAZE := Rect2(1.92, .32, 2.38, 2.3)
const SLIDE := Rect2(4.3, .02, 1.04, 2.6)
const RIBBON := Rect2(1.5, 4.25, 3.8, 1.8)
const THIRD := Rect2(1.5, 7.3, 2.5, 1.8)
const FOURTH := Rect2(1.5, 10.35, 2.5, 1.75)
const SLOT := Rect2(.46, 4.2, .38, 2.0)
const SLOT_TOP := Rect2(.46, 13.2, .38, 2.0)
const PENT_WINDOW := Rect2(2.0, 13.6, 1.5, 1.3)
const PENT_DOOR := Rect2(4.25, 12.75, .85, 2.0)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _pent := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, -SET))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 4649
	_build_looks()
	_ground_wall()
	_shop_room()
	_counter()
	_back_office()
	_shop_glass()
	_listing_board()
	_stair_lobby()
	_fascia()
	_tile_front()
	_study_floor()
	_junior_floor()
	_senior_floor()
	_banners()
	_tower_signs()
	_penthouse()
	_street_things()
	_side_walls()
	_render_wall(_back, WIDE, PENT, GROUND, STOREY, PALE * .86, [] as Array[Rect2], .5)
	_kit.commit(self, _looks, ["front", "decal", "lamp", "neon", "led", "sign", "sign2", "room", "wall", "carpet", "display", "paper", "card", "curtain", "gblock"])
	_kit = null
	_omni("EstateRoom", Vector3(.3, 2.3, -2.2), Color(1.0, .93, .8), .4, 5.0)
	_omni("EstateStreet", Vector3(-.9, 2.5, .9), Color(1.0, .8, .56), .6, 5.0)

func _side_walls() -> void:
	# Tile was for the street: the flanks are painted render, with frosted lavatory windows and plant.
	var east_holes: Array[Rect2] = [Rect2(3.4, 7.7, .8, 1.0), Rect2(3.4, 10.8, .8, 1.0)]
	var west_holes: Array[Rect2] = [Rect2(4.6, 10.8, .8, 1.0), Rect2(4.6, 13.9, .8, 1.0)]
	_render_wall(_east, DEEP, PARAPET, GROUND, STOREY, PALE * .78, east_holes, .8)
	_render_wall(_west, DEEP, PENT, GROUND, STOREY, PALE * .82, west_holes, .8)
	for r: Rect2 in east_holes:
		_window(_east, r, .13, false)
	for r: Rect2 in west_holes:
		_window(_west, r, .71, false)
	_outdoor_unit(_east, 6.3, 7.4, .2)
	_bar("metal", _east, 6.3, 7.06, .16, Vector3(.9, .04, .34), STEEL)
	_outdoor_unit(_east, 6.3, 10.5, .2)
	_bar("metal", _east, 6.3, 10.16, .16, Vector3(.9, .04, .34), STEEL)
	_kit.tube("plain", [_east * Vector3(6.3, 10.2, .04), _east * Vector3(5.5, 10.0, .04), _east * Vector3(5.5, .1, .04)], .018, Color("#c4c2b6"), 6)
	_kit.tube("plain", [_east * Vector3(8.8, PARAPET, .06), _east * Vector3(8.8, .1, .06)], .04, Color("#a9a79e"), 8)
	_fibre([_east * Vector3(2.0, 13.0, .04), _east * Vector3(2.2, 9.0, .04), _east * Vector3(2.2, 3.4, .04)])

func _atlas_look(name: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _build_looks() -> void:
	_shared_looks()
	_looks.brick = _look("", 1.0, .4)
	_looks.brick.set_shader_parameter("tile_size", Vector2(.227, .06))
	_looks.stone = _look("square_tiled_wall", 1.0, .45)
	_looks.core = _look("plastered_wall_03", 3.0, .9)
	_looks.core.set_shader_parameter("chroma", .6)
	_looks.tin = _look("worn_corrugated_iron", 2.0, .6, .2)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.wall = _look("white_stucco", 2.0, .85)
	_looks.wall.set_shader_parameter("chroma", .6)
	_looks.wall.set_shader_parameter("glow", .24)
	_looks.wall.set_shader_parameter("day_glow", .1)
	_looks.carpet = _look("", 1.0, .9)
	_looks.carpet.set_shader_parameter("tile_size", Vector2(.5, .5))
	_looks.carpet.set_shader_parameter("glow", .2)
	_looks.carpet.set_shader_parameter("day_glow", .08)
	_looks.room = _look("", 1.0, .55)
	_looks.room.set_shader_parameter("glow", .24)
	_looks.room.set_shader_parameter("day_glow", .1)
	_looks.curtain = _look("", 1.0, .9)
	_looks.curtain.set_shader_parameter("glow", .3)
	_looks.curtain.set_shader_parameter("day_glow", .1)
	_looks.gblock = _look("", 1.0, .3)
	_looks.gblock.set_shader_parameter("tile_size", Vector2(.19, .19))
	_looks.gblock.set_shader_parameter("glow", .34)
	_looks.gblock.set_shader_parameter("day_glow", .04)
	_atlas_look("sign", .35, .9, .16)
	_atlas_look("sign2", .4, .2, .06)
	_atlas_look("display", .4, .45, .16)
	_atlas_look("paper", .7, .42, .2)
	_atlas_look("card", .6, .2, .08)
	_atlas_look("banner", .92, .08, .0)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", load(ATLAS))
	letters.set_shader_parameter("glow", .3)
	letters.set_shader_parameter("day_glow", .1)
	_looks.decal = letters

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _skin(part: String, face: Transform3D, area: Rect2, holes: Array[Rect2], tint: Color, streak := .75) -> void:
	for piece: Rect2 in _minus(area, holes):
		_kit.quad(part, face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), tint, .9, 1.0, streak, Vector2(piece.position.x, -piece.position.y))

func _box(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, back: Color, left: Color, right: Color, floor_tint: Color, ceiling: Color) -> void:
	# Five inward faces of a room, in face space, in the lit "room" look.
	var f := _front
	_kit.quad("wall", f * Vector3(x0, y0, z1), f * Vector3(x0, y1, z1), f * Vector3(x1, y1, z1), f * Vector3(x1, y0, z1), back, .62, .95)
	_kit.quad("wall", f * Vector3(x0, y0, z0), f * Vector3(x0, y1, z0), f * Vector3(x0, y1, z1), f * Vector3(x0, y0, z1), left, .62, .9)
	_kit.quad("wall", f * Vector3(x1, y0, z1), f * Vector3(x1, y1, z1), f * Vector3(x1, y1, z0), f * Vector3(x1, y0, z0), right, .62, .9)
	_kit.quad("carpet", f * Vector3(x0, y0, z0), f * Vector3(x0, y0, z1), f * Vector3(x1, y0, z1), f * Vector3(x1, y0, z0), floor_tint, .8, .8)
	_kit.quad("room", f * Vector3(x0, y1, z1), f * Vector3(x0, y1, z0), f * Vector3(x1, y1, z0), f * Vector3(x1, y1, z1), ceiling, .8, .8)

func _ceiling_grid(x0: float, x1: float, y: float, z0: float, z1: float, line: Color) -> void:
	# Tee bars of a system ceiling, six hundred square.
	var f := _front
	var x := x0 + .3
	while x < x1:
		_kit.quad("room", f * Vector3(x, y, z1), f * Vector3(x, y, z0), f * Vector3(x + .018, y, z0), f * Vector3(x + .018, y, z1), line)
		x += .6
	var z := z0 - .3
	while z > z1:
		_kit.quad("room", f * Vector3(x0, y, z - .018), f * Vector3(x0, y, z), f * Vector3(x1, y, z), f * Vector3(x1, y, z - .018), line)
		z -= .6

func _ceiling_lamp(x0: float, x1: float, y: float, z0: float, z1: float, tint: Color) -> void:
	var f := _front
	_kit.quad("lamp", f * Vector3(x0, y, z1), f * Vector3(x0, y, z0), f * Vector3(x1, y, z0), f * Vector3(x1, y, z1), tint)

func _glazing(r: Rect2, z: float, bars: Array[float]) -> void:
	# Real depth behind plain glass, the frame in anodised section.
	var f := _front
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, z), f * Vector3(r.position.x, r.end.y, z), f * Vector3(r.end.x, r.end.y, z), f * Vector3(r.end.x, r.position.y, z), Color.WHITE)
	var m := r.get_center()
	for x: float in bars:
		_bar("metal", f, x, m.y, z + .02, Vector3(.05, r.size.y, .08), ALUMINIUM)
	for x: float in [r.position.x + .022, r.end.x - .022]:
		_bar("metal", f, x, m.y, z + .02, Vector3(.045, r.size.y, .08), ALUMINIUM)
	for y: float in [r.position.y + .022, r.end.y - .022]:
		_bar("metal", f, m.x, y, z + .02, Vector3(r.size.x, .045, .08), ALUMINIUM)

func _ground_wall() -> void:
	# Dark polished stone to the fascia: the one expensive thing anyone did to this building in 1985.
	var f := _front
	_skin("stone", f, Rect2(0, 0, WIDE, GROUND), [STAIR, GLAZE, SLIDE, Rect2(1.06, .4, .8, 1.94)], STONE, .5)
	_reveal(f, STAIR, .14, Color("#55534e"))
	_reveal(f, GLAZE, .1, Color("#4a4946"))
	_reveal(f, SLIDE, .1, Color("#4a4946"))
	_bar("metal", f, GLAZE.get_center().x, GLAZE.position.y - .012, .02, Vector3(GLAZE.size.x + .04, .024, .14), ALUMINIUM)

func _shop_room() -> void:
	# Pale vinyl walls, grey carpet tile gone shiny along the path to the counter.
	var f := _front
	var x0 := 1.72
	var x1 := 5.42
	var wall := Color("#a8a290")
	_box(x0, x1, 0.03, SHOP_TOP, -.08, -SHOP_DEEP, wall, wall * .96, wall * .92, Color("#44484e"), Color("#b4b2a6"))
	_ceiling_grid(x0, x1, SHOP_TOP - .004, -.08, -SHOP_DEEP, Color("#a9a79c"))
	for z: float in [-.9, -3.4]:
		_ceiling_lamp(2.6, 4.4, SHOP_TOP - .012, z, z - .6, Color(1.0, .95, .8))
	# Skirting along both sides.
	_kit.quad("room", f * Vector3(x0 + .004, .03, -.08), f * Vector3(x0 + .004, .13, -.08), f * Vector3(x0 + .004, .13, -SHOP_DEEP), f * Vector3(x0 + .004, .03, -SHOP_DEEP), Color("#3c3e40"))
	_kit.quad("room", f * Vector3(x1 - .004, .03, -SHOP_DEEP), f * Vector3(x1 - .004, .13, -SHOP_DEEP), f * Vector3(x1 - .004, .13, -.08), f * Vector3(x1 - .004, .03, -.08), Color("#3c3e40"))
	# On the walls: 住宅地図 pinned up, the law's licence plate, the month's roses.
	_kit.atlas("display", f * Vector3(x0 + .01, 1.0, -2.6), f * Vector3(x0 + .01, 1.95, -2.6), f * Vector3(x0 + .01, 1.95, -4.1), f * Vector3(x0 + .01, 1.0, -4.1), _cell(430, 1855, 300, 190))
	_kit.atlas("display", f * Vector3(x1 - .01, 1.45, -1.6), f * Vector3(x1 - .01, 1.9, -1.6), f * Vector3(x1 - .01, 1.9, -.95), f * Vector3(x1 - .01, 1.45, -.95), _cell(930, 1855, 220, 150))
	_panel("display", f, 3.6, 4.5, 1.72, 2.03, -SHOP_DEEP + .012, _cell(1160, 1958, 250, 87))
	# Shelving along the back: lever-arch files, three bays, the firm's real memory.
	for y: float in [.55, 1.08]:
		_bar("room", f, 2.6, y + .28, -SHOP_DEEP + .19, Vector3(1.6, .03, .34), Color("#7c746a"))
		_panel("display", f, 1.86, 3.34, y + .3, y + .72, -SHOP_DEEP + .05, _cell(1160, 1855, 250, 100))
	_bar("room", f, 2.6, .3, -SHOP_DEEP + .19, Vector3(1.6, .6, .34), Color("#8a8276"))
	_bar("room", f, 1.84, 1.1, -SHOP_DEEP + .19, Vector3(.03, 1.6, .34), Color("#7c746a"))
	_bar("room", f, 3.36, 1.1, -SHOP_DEEP + .19, Vector3(.03, 1.6, .34), Color("#7c746a"))
	# 神棚 up in the corner, a small shelf and a smaller shrine.
	_bar("room", f, 4.9, 2.32, -SHOP_DEEP + .1, Vector3(.6, .03, .2), Color("#c4a878"))
	_bar("room", f, 4.9, 2.42, -SHOP_DEEP + .1, Vector3(.3, .17, .12), Color("#d8c49a"))

func _office_chair(at: Vector3, away: float, tint: Color) -> void:
	# Five castors, a gas column, a pad, a back on one steel stalk.
	var hub := at + Vector3.UP * .09
	for i: int in range(5):
		var a := TAU * float(i) / 5.0 + .3
		var foot := at + Vector3(cos(a) * .27, .05, sin(a) * .27)
		_kit.tube("room", [hub, foot], .014, Color("#2a2b2e"), 4)
		_kit.lathe("room", foot + Vector3.DOWN * .05, [Vector2(.02, 0), Vector2(.03, .02), Vector2(.02, .05)], Color("#141416"), 6)
	_kit.lathe("room", hub, [Vector2(.03, 0), Vector2(.022, .08), Vector2(.022, .36)], Color("#3a3b3e"), 8)
	_kit.block("room", Transform3D(Basis.IDENTITY, at + Vector3.UP * .47), Vector3(.44, .07, .42), tint, .8, 1.0)
	_kit.tube("room", [at + Vector3(0, .46, .2 * away), at + Vector3(0, .6, .23 * away)], .014, Color("#3a3b3e"), 4)
	_kit.block("room", Transform3D(Basis.IDENTITY, at + Vector3(0, .78, .24 * away)), Vector3(.4, .34, .05), tint, .8, 1.0)
	_kit.tube("room", [at + Vector3(-.2, .96, .24 * away), at + Vector3(.2, .96, .24 * away)], .022, tint.darkened(.25), 6)

func _counter() -> void:
	# 接客カウンター: three seats with the acrylic screens nobody took down after 2020 or 2038.
	var f := _front
	var x0 := 1.74
	var x1 := 4.2
	var z := -2.0
	var mid := (x0 + x1) * .5
	# Its name on a board on two chains.
	_panel("display", f, 2.5, 3.4, 2.1, 2.42, z - .1, _cell(1810, 760, 230, 80))
	for x: float in [2.6, 3.3]:
		_bar("room", f, x, 2.57, z - .11, Vector3(.012, .3, .012), Color("#3a3a3c"))
	_bar("room", f, 2.95, 2.26, z - .11, Vector3(.94, .34, .012), Color("#2a2c30"))
	_bar("room", f, mid, .36, z + .12, Vector3(x1 - x0, .68, .03), Color("#c8c0ac"))
	_bar("room", f, x1, .36, z - .1, Vector3(.04, .68, .46), Color("#b4ac98"))
	_bar("room", f, mid, .73, z - .08, Vector3(x1 - x0 + .06, .036, .72), WOOD)
	_bar("room", f, mid, .712, z + .285, Vector3(x1 - x0 + .06, .014, .02), Color("#6c5230"))
	for i: int in range(3):
		var x := x0 + .42 + float(i) * .82
		_kit.quad("room", f * Vector3(x - .3, .75, z - .3), f * Vector3(x - .3, .78, z + .12), f * Vector3(x + .3, .78, z + .12), f * Vector3(x + .3, .75, z - .3), Color("#35383c"))
		if i != 1: _office_chair(f * Vector3(x, 0, z + .78), 1.0, Color("#2c3a4e"))
		_office_chair(f * Vector3(x, 0, z - .9), -1.0, Color("#3a3a3e"))
		# Sheet of listings, a palm pad, a pen cup.
		_kit.quad("paper", f * Vector3(x - .1, .755, z + .02), f * Vector3(x - .1, .755, z - .28), f * Vector3(x + .12, .755, z - .28), f * Vector3(x + .12, .755, z + .02), Color.WHITE)
		_bar("room", f, x + .24, .76, z - .14, Vector3(.1, .02, .13), Color("#141618"))
		_bar("led", f, x + .24, .772, z - .14, Vector3(.07, .004, .1), CYAN * .5)
		_kit.lathe("room", f * Vector3(x - .22, .75, z - .3), [Vector2(.03, 0), Vector2(.032, .1)], Color("#b8302a"), 8)
	for i: int in range(4):
		var x := x0 + float(i) * .82 + .01
		_bar("room", f, x, 1.08, z - .1, Vector3(.012, .64, .6), Color("#cfd8da"))

func _desk_set(x: float, z: float, away: float) -> void:
	var f := _front
	_bar("room", f, x, .7, z, Vector3(1.02, .03, .66), Color("#c9c4b4"))
	for side: float in [-.48, .48]:
		_bar("room", f, x + side, .35, z, Vector3(.03, .68, .6), Color("#8c8a82"))
	_bar("room", f, x + .32, .36, z, Vector3(.34, .64, .56), Color("#9c9a92"))
	_bar("room", f, x, .96, z + .14 * away, Vector3(.54, .32, .02), Color("#1a1c20"))
	_bar("led", f, x, .96, z + .128 * away, Vector3(.48, .26, .004), Color(.5, .62, .7) * .7)
	_bar("room", f, x, .77, z + .14 * away, Vector3(.04, .12, .04), Color("#1a1c20"))
	_bar("room", f, x - .36, .76, z - .1 * away, Vector3(.22, .08 + _rng.randf() * .1, .3), Color("#ecead8"))
	_bar("room", f, x + .34, .735, z - .08 * away, Vector3(.38, .018, .13), Color("#2a2b2e"))
	_office_chair(f * Vector3(x, 0, z - .66 * away), -away, Color("#4a4a4e"))

func _back_office() -> void:
	# Two pairs of desks head to head, the copier by the back wall, the key cabinet nobody may open.
	var f := _front
	for x: float in [2.5, 3.6]:
		_desk_set(x, -3.35, -1.0)
		_desk_set(x, -4.05, 1.0)
	_bar("room", f, 4.95, .55, -5.4, Vector3(.66, 1.08, .6), Color("#d4d2c6"))
	_bar("room", f, 4.95, 1.14, -5.46, Vector3(.6, .1, .44), Color("#6c6e70"))
	_bar("led", f, 4.76, 1.102, -5.1, Vector3(.14, .05, .006), GREEN * .4)
	_bar("room", f, 5.34, 1.4, -3.6, Vector3(.14, .9, .7), Color("#7a7e7c"))
	_bar("room", f, 5.262, 1.4, -3.6, Vector3(.012, .84, .012), Color("#3a3c3c"))
	_kit.lathe("plain", f * Vector3(5.1, .03, -2.1), [Vector2(.13, 0), Vector2(.17, .3)], Color("#c8c0b0"), 10)
	_plant(f * Vector3(5.1, .32, -2.1), 1.1, Color("#3a6a3e"))

func _sheet(part: String, face: Transform3D, centre: Vector2, z: float, size: Vector2, rect: Rect2, tint: Color, angle: float) -> void:
	# One sheet taped up slightly out of true.
	var x := Vector2(cos(angle), sin(angle)) * size.x * .5
	var y := Vector2(-sin(angle), cos(angle)) * size.y * .5
	var a := centre - x - y
	var b := centre - x + y
	var c := centre + x + y
	var d := centre + x - y
	_kit.atlas(part, face * Vector3(a.x, a.y, z), face * Vector3(b.x, b.y, z), face * Vector3(c.x, c.y, z), face * Vector3(d.x, d.y, z), rect, tint)

func _flyer(at: Vector2, i: int, z: float) -> void:
	var rect := _cell(float(i % 7) * 200.0, float(i / 7 % 3) * 280.0, 200, 280)
	var fade := _rng.randf()
	var tint := Color(1.0, .98, .9) if fade < .5 else Color(.96, .98, 1.0) if fade < .8 else Color(.96, .9, .74)
	_sheet("paper", _front, at + Vector2(_rng.randf_range(-.008, .008), _rng.randf_range(-.008, .008)), z, Vector2(.245, .345), rect, tint, _rng.randf_range(-.022, .022))

func _shop_glass() -> void:
	var f := _front
	_glazing(GLAZE, -.1, [3.1])
	# 物件情報: nine columns of sheets inside the glass, with a gap the staff can see the street through.
	var i := 0
	for row: int in range(4):
		for col: int in range(9):
			if row >= 1 and col >= 3 and col <= 5: continue
			_flyer(Vector2(2.09 + float(col) * .255, .59 + float(row) * .365), i, -.13)
			i += 1
	for col: int in range(9):
		_flyer(Vector2(2.09 + float(col) * .255, 2.05), i, -.13)
		i += 1
	# Blue band across the head of the glass, with the trades cut out of vinyl.
	_bar("metal", f, GLAZE.position.x + 1.71, 2.47, -.02, Vector3(3.42, .22, .05), NAVY)
	_panel("decal", f, GLAZE.position.x, GLAZE.position.x + 3.42, 2.37, 2.57, .008, _cell(0, 1060, 1000, 60))
	# Sliding doors, the one tidy pane: VR viewing notice, the turtle, opening hours.
	var mid := SLIDE.get_center().x
	var door := Rect2(SLIDE.position.x, SLIDE.position.y, SLIDE.size.x, 2.35)
	_glazing(door, -.09, [mid])
	_bar("metal", f, mid, .14, -.07, Vector3(SLIDE.size.x, .2, .05), ALUMINIUM * .9)
	_panel("display", f, 4.42, 4.72, 1.1, 1.5, -.115, _cell(1210, 1590, 200, 260))
	_panel("paper", f, 4.96, 5.2, 1.12, 1.36, -.115, _cell(1408, 640, 200, 200))
	_flyer(Vector2(5.08, 1.62), 3, -.115)
	_bar("metal", f, mid - .06, 1.05, -.05, Vector3(.025, .36, .03), STEEL)
	_bar("metal", f, mid + .06, 1.05, -.05, Vector3(.025, .36, .03), STEEL)
	_bar("plain", f, SLIDE.get_center().x, .025, .22, Vector3(1.04, .02, .62), Color("#26282a"))

func _listing_board() -> void:
	# The wall beside the glass: a black board of clear pockets on spiral rails, green cards inside.
	var f := _front
	_bar("metal", f, 1.46, 1.37, .02, Vector3(.82, 1.96, .05), Color("#16171a"))
	var i := 0
	for row: int in range(6):
		var y := .56 + float(row) * .31
		for col: int in range(2):
			var card := i % 6
			var rect := _cell(1408.0 + float(card % 2) * 320.0, float(card / 2) * 210.0, 320, 210)
			_sheet("card", f, Vector2(1.26 + float(col) * .4, y), .05, Vector2(.37, .245), rect, Color(1, 1, 1) if row % 3 != 2 else Color(.94, .95, .8), _rng.randf_range(-.008, .008))
			i += 1
		_kit.tube("metal", [f * Vector3(1.08, y + .14, .052), f * Vector3(1.84, y + .14, .052)], .006, Color("#3a3c40"), 4)

func _stair_lobby() -> void:
	# The juku's own door, a mailbox wall and stairs in pale terrazzo going straight up out of sight.
	var f := _front
	var cream := Color("#a89f88")
	_box(.12, 1.6, .02, 2.7, -.1, -4.2, cream * .9, cream * .86, cream * .84, Color("#6c6a62"), Color("#a8a290"))
	_ceiling_lamp(.6, 1.0, 2.692, -.7, -1.1, Color(1.0, .92, .76))
	var z := -1.5
	for i: int in range(11):
		var tall := float(i + 1) * .17
		_bar("room", f, .87, tall * .5 + .02, z, Vector3(1.46, tall, .27), Color("#8a887c") if i % 2 == 0 else Color("#6e6c62"))
		_bar("room", f, .87, tall + .024, z + .12, Vector3(1.46, .012, .03), Color("#4a4c48"))
		z -= .27
	_kit.tube("metal", [f * Vector3(1.5, 1.0, -1.3), f * Vector3(1.5, 2.9, -4.3)], .018, Color("#7a4a2a"), 6)
	# Post boxes: real flaps, one lip each.
	for row: int in range(3):
		for col: int in range(2):
			var y := 1.0 + float(row) * .2
			var at := -.42 - float(col) * .36
			_bar("room", f, .165, y, at, Vector3(.07, .18, .33), Color("#8e9294"))
			_bar("room", f, .204, y + .04, at, Vector3.ONE * .012 + Vector3(0, .02, .24), Color("#3c3e40"))
	_kit.atlas("display", f * Vector3(1.59, 1.15, -1.1), f * Vector3(1.59, 1.65, -1.1), f * Vector3(1.59, 1.65, -.55), f * Vector3(1.59, 1.15, -.55), _cell(740, 1855, 180, 190))
	# A swing door, glass and steel, with the winter poster taped inside it.
	_glazing(STAIR, -.1, [])
	_panel("display", f, .44, .74, 1.1, 1.5, -.115, _cell(1010, 1590, 200, 260))
	_bar("metal", f, .94, 1.08, -.05, Vector3(.025, .5, .03), STEEL)
	# 2050: the palm pad that replaced the entry phone, in the old phone's cut-out.
	_bar("metal", f, 1.0, 1.32, .018, Vector3(.08, .13, .03), Color("#1a1b1e"))
	_bar("led", f, 1.0, 1.32, .035, Vector3(.05, .08, .004), CYAN * .55)

func _fascia() -> void:
	var f := _front
	var x0 := 1.22
	_bar("metal", f, (x0 + WIDE) * .5, 3.03, .13, Vector3(WIDE - x0, .68, .26), Color("#2c2e34"), .8, 1.0)
	_panel("sign", f, x0 + .01, WIDE - .01, 2.72, 3.34, .264, _cell(0, 850, 1400, 204))
	_bar("metal", f, (x0 + WIDE) * .5, 3.385, .17, Vector3(WIDE - x0 + .04, .04, .36), STEEL)
	# The juku's board over its door, and a cone lamp lighting the listings.
	_bar("metal", f, .62, 2.98, .02, Vector3(1.02, .53, .05), Color("#26282c"))
	_panel("sign2", f, .13, 1.11, 2.73, 3.22, .048, _cell(1810, 640, 230, 115))
	for x: float in [1.46, 3.0, 4.8]:
		_kit.tube("metal", [f * Vector3(x, 2.7, .1), f * Vector3(x, 2.6, .3), f * Vector3(x, 2.55, .34)], .012, Color("#18181a"), 5)
		_kit.lathe("metal", f * Vector3(x, 2.42, .34), [Vector2(.055, 0), Vector2(.04, .13)], Color("#18181a"), 8)
		_kit.disc("lamp", f * Vector3(x, 2.419, .34), Vector3.RIGHT, Vector3.FORWARD, .046, Color(1.0, .86, .62))

func _tile_front() -> void:
	# Chocolate 二丁掛 tile over the shop; bare precast on the stair tower beside it.
	var f := _front
	_skin("brick", f, Rect2(CORE, GROUND, WIDE - CORE, PARAPET - GROUND), [RIBBON, THIRD, FOURTH], TILE)
	_skin("core", f, Rect2(0, GROUND, CORE, PENT - GROUND), [SLOT, SLOT_TOP], Color(.7, .77, .8), .85)
	_bar("plain", f, CORE, (GROUND + PARAPET) * .5, .012, Vector3(.03, PARAPET - GROUND, .024), Color("#3a3634"))
	for y: float in [GROUND + STOREY, GROUND + STOREY * 2.0]:
		_bar("plain", f, (CORE + WIDE) * .5, y + .12, .014, Vector3(WIDE - CORE, .03, .03), Color("#4c403a"))
	_bar("plain", f, (CORE + WIDE) * .5, PARAPET + .04, -.06, Vector3(WIDE - CORE + .04, .08, .26), Color("#6e6a62"), .7, 1.0)
	for r: Rect2 in [SLOT, SLOT_TOP]:
		_reveal(f, r, .12, Color("#5e5c56"))
		_kit.quad("gblock", f * Vector3(r.position.x, r.position.y, -.11), f * Vector3(r.position.x, r.end.y, -.11), f * Vector3(r.end.x, r.end.y, -.11), f * Vector3(r.end.x, r.position.y, -.11), Color(.74, .86, .8))
	# Letters in cream plate on the band between the second and third floors, with their shadow.
	_panel("decal", f, 1.612, 5.212, 6.208, 6.928, .004, _cell(600, 1390, 800, 160), Color(0, 0, 0, .5))
	_panel("decal", f, 1.6, 5.2, 6.22, 6.94, .008, _cell(600, 1390, 800, 160))
	# Later trunk fibre, and the rainwater pipe that has lost its top bracket.
	_fibre([f * Vector3(1.24, PENT - .1, .05), f * Vector3(1.24, 3.5, .05), f * Vector3(1.0, 3.42, .05)])
	_kit.tube("plain", [f * Vector3(.07, PENT, .06), f * Vector3(.07, .1, .06)], .04, Color("#a9a79e"), 8)
	var y2 := 1.2
	while y2 < PENT:
		_bar("metal", f, .07, y2, .05, Vector3(.1, .03, .1), STEEL)
		y2 += 2.2
	_camera(f * Vector3(.5, 3.42, .18))
	# Drone drop shelf bolted to the tower between the slot and the sign.
	_bar("metal", f, .65, 6.56, .3, Vector3(.7, .05, .56), Color("#3a3d40"))
	_bar("metal", f, .65, 6.74, .03, Vector3(.7, .34, .05), Color("#2a2c2f"))
	_strip(f * Vector3(.32, 6.59, .57), f * Vector3(.98, 6.59, .57), CYAN * .7)
	_status(f, .95, 6.84, .062, GREEN)

func _recess(r: Rect2, deep: float, bars: Array[float]) -> void:
	_reveal(_front, r, deep, Color("#6a5a50"))
	_glazing(r, -deep + .02, bars)
	_bar("metal", _front, r.get_center().x, r.position.y - .014, .03, Vector3(r.size.x + .06, .028, .14), ALUMINIUM * .8)

func _study_floor() -> void:
	# 2F: 自習室. Long glass, vinyl lettering, orange over navy, plywood chairs at a window bar.
	var f := _front
	var y0 := GROUND + .1
	var y1 := y0 + 2.62
	var x0 := 1.42
	var x1 := 5.38
	var back := -2.8
	_recess(RIBBON, .2, [2.45, 3.4, 4.35])
	_panel("decal", f, 1.6, 5.2, 5.04, 5.58, -.165, _cell(0, 1590, 1000, 150))
	_panel("decal", f, 1.6, 5.2, 4.56, 4.92, -.165, _cell(0, 1745, 1000, 100))
	var navy := Color("#1d4a86")
	var orange := Color("#c47a1c")
	_box(x0, x1, y0, y1, -.16, back, orange, orange * .94, orange * .9, Color("#6e6455"), Color("#b4b2a6"))
	_kit.quad("room", f * Vector3(x0, y0, back + .01), f * Vector3(x0, y0 + 1.12, back + .01), f * Vector3(x1, y0 + 1.12, back + .01), f * Vector3(x1, y0, back + .01), navy, .7, 1.0)
	_ceiling_grid(x0, x1, y1 - .004, -.16, back, Color("#b4b2a8"))
	for x: float in [1.9, 3.1, 4.3]:
		_ceiling_lamp(x, x + .5, y1 - .012, -1.2, -1.7, Color(1.0, .94, .8))
	_panel("display", f, 2.1, 2.5, y0 + 1.36, y0 + 1.88, back + .02, _cell(1010, 1590, 200, 260))
	_panel("display", f, 3.9, 4.8, y0 + 1.4, y0 + 1.82, back + .02, _cell(0, 1390, 585, 195))
	# Paper banners off the ceiling tiles: the same slogan as the street gets, for the ones already inside.
	for hang: float in [2.0, 2.95, 3.9, 4.85]:
		_panel("display", f, hang - .15, hang + .15, y1 - 1.26, y1 - .06, -1.9, _cell(1420, 1160, 220, 880))
		_bar("room", f, hang, y1 - .03, -1.9, Vector3(.34, .03, .03), Color("#3a3a3c"))
	var mid := (x0 + x1) * .5
	_bar("room", f, mid, y0 + .7, -.52, Vector3(x1 - x0 - .04, .03, .44), WOOD * 1.1)
	var x := 1.8
	while x < 5.2:
		_bar("room", f, x, y0 + .35, -.3, Vector3(.03, .7, .03), Color("#1c1c1e"))
		_bar("room", f, x, y0 + .45, -1.0, Vector3(.38, .025, .38), WOOD)
		_bar("room", f, x, y0 + .76, -1.16, Vector3(.38, .3, .025), WOOD * 1.05)
		for s: float in [-.16, .16]:
			_bar("room", f, x + s, y0 + .34, -1.16, Vector3(.016, .68, .016), Color("#1c1c1e"))
			_bar("room", f, x + s, y0 + .22, -.84, Vector3(.016, .44, .016), Color("#1c1c1e"))
		x += .76
	for k: int in range(5):
		_bar("room", f, 1.9 + float(k) * .76, y0 + .56, back + .3, Vector3(.66, 1.12, .5), Color("#ccc6b4") if k % 2 == 0 else Color("#bdb7a6"))

func _classroom_lamp(x0: float, x1: float, y: float, z: float, tint: Color) -> void:
	var f := _front
	_bar("room", f, (x0 + x1) * .5, y - .02, z, Vector3(x1 - x0 + .06, .04, .14), Color("#d8d8d0"))
	_bar("lamp", f, (x0 + x1) * .5, y - .06, z - .03, Vector3(x1 - x0, .026, .026), tint)
	_bar("lamp", f, (x0 + x1) * .5, y - .06, z + .03, Vector3(x1 - x0, .026, .026), tint)

func _school_desk(x: float, y0: float, z: float) -> void:
	var f := _front
	_bar("room", f, x, y0 + .72, z, Vector3(.58, .025, .42), WOOD)
	_bar("room", f, x, y0 + .63, z, Vector3(.54, .12, .38), Color("#4a4c50"))
	for sx: float in [-.25, .25]:
		_bar("room", f, x + sx, y0 + .3, z, Vector3(.025, .6, .36), Color("#8e9294"))
	_bar("room", f, x, y0 + .43, z + .48, Vector3(.38, .02, .36), Color("#c28a4e"))
	_bar("room", f, x, y0 + .76, z + .66, Vector3(.38, .24, .02), Color("#c28a4e"))
	for sx: float in [-.17, .17]:
		_bar("room", f, x + sx, y0 + .38, z + .66, Vector3(.02, .76, .02), Color("#8e9294"))
		_bar("room", f, x + sx, y0 + .21, z + .32, Vector3(.02, .42, .02), Color("#8e9294"))

func _junior_floor() -> void:
	# 3F: 中学部. Bare cool tubes, a whiteboard at the back with last period still on it.
	var f := _front
	var y0 := GROUND + STOREY + .1
	var y1 := y0 + 2.6
	var x0 := 1.42
	var x1 := 4.08
	var back := -3.6
	_recess(THIRD, .16, [2.33, 3.17])
	var wall := Color("#9ea8a2")
	_box(x0, x1, y0, y1, -.12, back, wall, wall * .95, wall * .9, Color("#6e6a5a"), Color("#b8b8b0"))
	_ceiling_grid(x0, x1, y1 - .004, -.12, back, Color("#8e8e86"))
	_kit.quad("room", f * Vector3(x0, y0, back + .01), f * Vector3(x0, y0 + .9, back + .01), f * Vector3(x1, y0 + .9, back + .01), f * Vector3(x1, y0, back + .01), Color("#b9a27c"), .8, 1.0)
	_panel("display", f, 1.72, 3.78, y0 + 1.0, y0 + 2.0, back + .02, _cell(0, 1855, 420, 190))
	_bar("room", f, 2.75, y0 + .98, back + .05, Vector3(2.1, .03, .07), ALUMINIUM)
	_kit.disc("room", f * Vector3(3.9, y0 + 2.28, back + .03), Vector3.RIGHT, Vector3.UP, .14, Color("#f2f2ea"))
	_bar("room", f, 3.9, y0 + 2.31, back + .036, Vector3(.012, .09, .006), Color("#1a1a1c"))
	_bar("room", f, 3.94, y0 + 2.28, back + .036, Vector3(.08, .012, .006), Color("#1a1a1c"))
	for z: float in [-.9, -2.0, -3.0]:
		_classroom_lamp(1.9, 3.6, y1, z, Color(.9, .97, 1.0))
	# Roller blinds, each left where the last teacher wanted it.
	_blind(1.54, 2.31, THIRD.end.y - .04, 8.1)
	_blind(3.19, 3.96, THIRD.end.y - .04, 8.52)
	for row: int in range(3):
		for col: int in range(3):
			_school_desk(1.96 + float(col) * .8, y0, -2.68 + float(row) * .84)

func _blind(x0: float, x1: float, y1: float, y0: float) -> void:
	var f := _front
	_kit.quad("curtain", f * Vector3(x0, y0, -.13), f * Vector3(x0, y1, -.13), f * Vector3(x1, y1, -.13), f * Vector3(x1, y0, -.13), Color("#c8c4b0"), .85, 1.0)
	_bar("metal", f, (x0 + x1) * .5, y1, -.13, Vector3(x1 - x0, .05, .05), Color("#b4b2a6"))
	_bar("metal", f, (x0 + x1) * .5, y0 - .01, -.13, Vector3(x1 - x0, .02, .02), Color("#6c6a62"))

func _senior_floor() -> void:
	# 4F: 高校部, the top of the ladder: a white surround standing proud, cream curtains half drawn.
	var f := _front
	var y0 := GROUND + STOREY * 2.0 + .1
	var y1 := y0 + 2.56
	var x0 := 1.42
	var x1 := 4.08
	var back := -2.9
	_recess(FOURTH, .14, [2.75])
	var frame := Color(.8, .78, .72)
	var cx := FOURTH.get_center().x
	_bar("core", f, cx, FOURTH.end.y + .1, .17, Vector3(2.9, .2, .34), frame, .85, 1.0)
	_bar("core", f, cx, FOURTH.position.y - .1, .17, Vector3(2.9, .2, .34), frame, .85, 1.0)
	for x: float in [FOURTH.position.x - .1, FOURTH.end.x + .1]:
		_bar("core", f, x, FOURTH.get_center().y, .17, Vector3(.2, FOURTH.size.y, .34), frame, .85, 1.0)
	var wall := Color("#b0a890")
	_box(x0, x1, y0, y1, -.1, back, wall, wall * .95, wall * .9, Color("#5c5648"), Color("#b8b4a4"))
	_ceiling_grid(x0, x1, y1 - .004, -.1, back, Color("#908c7e"))
	for z: float in [-1.0, -2.2]:
		_classroom_lamp(1.8, 3.7, y1, z, Color(1.0, .95, .84))
	# Past-paper shelves at the back, spines in the colours of the red book and the blue.
	for shelf: int in range(4):
		var y := y0 + .5 + float(shelf) * .48
		_bar("room", f, 2.75, y, back + .16, Vector3(2.5, .025, .26), Color("#8a7a60"))
		var x := 1.56
		while x < 3.94:
			var thick := _rng.randf_range(.03, .06)
			var tint := [Color("#a82420"), Color("#a82420"), Color("#2a4a8a"), Color("#d8d0b8"), Color("#3a7a54")][_rng.randi_range(0, 4)] as Color
			_bar("room", f, x, y + .15, back + .17, Vector3(thick, _rng.randf_range(.2, .28), .19), tint)
			x += thick + .006
	_curtain(1.54, 2.46, FOURTH.position.y - .02, FOURTH.end.y - .04, -.1)
	_curtain(3.2, 3.96, FOURTH.position.y - .02, FOURTH.end.y - .04, -.1)
	_bar("metal", f, cx, FOURTH.end.y - .03, -.08, Vector3(2.46, .03, .03), ALUMINIUM * .8)

func _curtain(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	# Folded cloth: a strip that zigzags, so the room's light shades into each pleat.
	var f := _front
	var cream := Color("#ecc98a")
	var x := x0
	var out := true
	while x < x1 - .01:
		var next := minf(x + .055, x1)
		var a := z - (.0 if out else .05)
		var b := z - (.05 if out else .0)
		_kit.quad("curtain", f * Vector3(x, y0, a), f * Vector3(x, y1, a), f * Vector3(next, y1, b), f * Vector3(next, y0, b), cream * (1.0 if out else .74), .8, 1.0)
		out = not out
		x = next

func _cloth(rect: Rect2, x0: float, x1: float, y0: float, y1: float, z: float, slack: float, across: bool) -> void:
	# A printed banner in strips, so it sags between its ties rather than sitting flat as paint.
	var f := _front
	var steps := 8
	for i: int in range(steps):
		var u0 := float(i) / float(steps)
		var u1 := float(i + 1) / float(steps)
		var w0 := z + sin(u0 * 9.0) * slack
		var w1 := z + sin(u1 * 9.0) * slack
		var cut := Rect2(rect.position.x + rect.size.x * u0, rect.position.y, rect.size.x / float(steps), rect.size.y)
		var shade := .9 + .1 * cos(u0 * 9.0)
		if across:
			_kit.atlas("banner", f * Vector3(lerpf(x0, x1, u0), y0, w0), f * Vector3(lerpf(x0, x1, u0), y1, w0), f * Vector3(lerpf(x0, x1, u1), y1, w1), f * Vector3(lerpf(x0, x1, u1), y0, w1), cut, Color(shade, shade, shade), 1.0, .3)
		else:
			cut = Rect2(rect.position.x, rect.position.y + rect.size.y * u0, rect.size.x, rect.size.y / float(steps))
			var top := lerpf(y1, y0, u0)
			var low := lerpf(y1, y0, u1)
			_kit.atlas("banner", f * Vector3(x0, low, w1), f * Vector3(x0, top, w0), f * Vector3(x1, top, w0), f * Vector3(x1, low, w1), cut, Color(shade, shade, shade), 1.0, .3)

func _banners() -> void:
	var f := _front
	# 合格実績 across the parapet; 第一志望合格 hung two storeys down the blind pier.
	_cloth(_cell(0, 1140, 1400, 245), 1.42, 5.42, 12.78, 13.46, .05, .012, true)
	_cloth(_cell(1420, 1160, 220, 880), 4.25, 5.35, 7.0, 11.4, .1, .018, false)
	_cloth(_cell(0, 1390, 585, 195), 1.5, 4.05, 9.2, 10.04, .05, .01, true)
	# Pipes it hangs from, and rope to the wall.
	_kit.tube("metal", [f * Vector3(4.2, 11.42, .1), f * Vector3(5.4, 11.42, .1)], .016, Color("#8a8a84"), 6)
	_kit.tube("metal", [f * Vector3(4.2, 6.98, .1), f * Vector3(5.4, 6.98, .1)], .016, Color("#8a8a84"), 6)
	for x: float in [4.3, 5.3]:
		for y: float in [11.42, 6.98]:
			_kit.tube("metal", [f * Vector3(x, y, .1), f * Vector3(x, y + .03, 0)], .006, Color("#d8d8d0"), 3)
	for x: float in [1.54, 2.78, 4.0]:
		for y: float in [10.0, 9.24]:
			_kit.tube("metal", [f * Vector3(x, y, .05), f * Vector3(x, y + .02, 0)], .006, Color("#d8d8d0"), 3)
	# Three goosenecks over the parapet, because nobody paid for a banner to go dark at five.
	for x: float in [2.0, 3.4, 4.8]:
		_kit.tube("metal", [f * Vector3(x, PARAPET + .06, 0), f * Vector3(x, PARAPET + .22, .22), f * Vector3(x, PARAPET + .2, .34)], .01, Color("#1a1a1c"), 5)
		_kit.lathe("metal", f * Vector3(x, PARAPET + .1, .34), [Vector2(.05, 0), Vector2(.03, .1)], Color("#1a1a1c"), 8)
		_kit.disc("lamp", f * Vector3(x, PARAPET + .098, .34), Vector3.RIGHT, Vector3.FORWARD, .04, Color(1.0, .9, .7))

func _tower_signs() -> void:
	var f := _front
	# Painted panel up the tower, lit by what spills on to it.
	_bar("metal", f, .65, 9.4, .04, Vector3(.94, 4.44, .08), Color("#2c2e32"))
	_panel("sign2", f, .2, 1.1, 7.2, 11.6, .082, _cell(1650, 1160, 180, 880))
	# Tenant blade off the east corner, one lit box to a tenant.
	var x := WIDE - .07
	var low := 3.66
	var high := 6.16
	var near := .2
	var far := .77
	_bar("metal", f, x, (low + high) * .5, (near + far) * .5, Vector3(.1, high - low + .06, far - near + .06), Color("#2c2b2a"))
	var rect := _cell(1840, 1160, 200, 880)
	_kit.atlas("sign", f * Vector3(x + .054, low, far), f * Vector3(x + .054, high, far), f * Vector3(x + .054, high, near), f * Vector3(x + .054, low, near), rect)
	_kit.atlas("sign", f * Vector3(x - .054, low, near), f * Vector3(x - .054, high, near), f * Vector3(x - .054, high, far), f * Vector3(x - .054, low, far), rect)
	for y: float in [low + .25, high - .25]:
		_bar("metal", f, x, y, .1, Vector3(.05, .05, .24), STEEL)

func _penthouse() -> void:
	# Tin box on the deck, set back: the accountant, a terrace of plant, and the overrun above the stair.
	var half := WIDE * .5
	var left := CORE - half
	var level := DECK + .02
	_kit.quad("plain", Vector3(left, level, 0), Vector3(left, level, -SET), Vector3(half, level, -SET), Vector3(half, level, 0), Color("#5c5e5a"), .8, .9)
	var inner := Color(.5, .36, .28)
	_kit.quad("render", Vector3(half - .02, level, -.14), Vector3(half - .02, PARAPET, -.14), Vector3(left, PARAPET, -.14), Vector3(left, level, -.14), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(half - .02, level, -SET), Vector3(half - .02, PARAPET, -SET), Vector3(half - .02, PARAPET, -.02), Vector3(half - .02, level, -.02), inner, .7, 1.0, .5)
	_kit.quad("core", Vector3(left, DECK, 0), Vector3(left, PENT, 0), Vector3(left, PENT, -SET), Vector3(left, DECK, -SET), Color(.66, .72, .75), .8, 1.0, .6)
	var blue := Color(.76, .86, .9)
	_skin("tin", _pent, Rect2(CORE, DECK, WIDE - CORE, PENT - DECK), [PENT_WINDOW, PENT_DOOR], blue, .5)
	_window(_pent, PENT_WINDOW, .27, false)
	_reveal(_pent, PENT_DOOR, .06, Color("#3a3c3e"))
	_kit.quad("plain", _pent * Vector3(PENT_DOOR.position.x, PENT_DOOR.position.y, -.05), _pent * Vector3(PENT_DOOR.position.x, PENT_DOOR.end.y, -.05), _pent * Vector3(PENT_DOOR.end.x, PENT_DOOR.end.y, -.05), _pent * Vector3(PENT_DOOR.end.x, PENT_DOOR.position.y, -.05), Color("#55605e"), .8, 1.0, .6)
	_bar("metal", _pent, PENT_DOOR.position.x + .08, 13.8, -.03, Vector3(.03, .14, .05), STEEL)
	_kit.quad("tin", Vector3(half, PARAPET, -DEEP), Vector3(half, PENT, -DEEP), Vector3(half, PENT, -SET), Vector3(half, PARAPET, -SET), blue * .9, .9, 1.0, .5)
	_bar("metal", _pent, (CORE + WIDE) * .5, PENT + .05, .03, Vector3(WIDE - CORE + .06, .1, .1), Color("#59605f"))
	_kit.quad("plain", Vector3(-half, PENT + .02, 0), Vector3(-half, PENT + .02, -DEEP), Vector3(half, PENT + .02, -DEEP), Vector3(half, PENT + .02, 0), Color("#55565a"), .8, .9)
	# Stair overrun, with the lift motor room: taller than the box, so the outline steps twice.
	_kit.block("core", Transform3D(Basis.IDENTITY, Vector3(CORE * .5 - half, PENT + .45, -2.2)), Vector3(CORE, .9, 4.4), Color(.68, .74, .77), .8, 1.0, .7, Vector2(.3, .2))
	_kit.block("metal", Transform3D(Basis.IDENTITY, Vector3(CORE * .5 - half, PENT + .93, -2.2)), Vector3(CORE + .04, .06, 4.44), Color("#6e6e68"))
	# Terrace: condensers on a steel stand, the juku's parcels at the drone pad, cables to the box.
	var t := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	_outdoor_unit(t, 1.2, level + .36, -1.7)
	_outdoor_unit(t, .3, level + .36, -1.7)
	_bar("metal", t, .75, level + .03, -1.7, Vector3(1.9, .05, .34), Color("#4a4c4e"))
	_bar("plain", t, -.65, level + .012, -1.0, Vector3(1.0, .02, 1.0), Color("#2e3033"))
	_strip(Vector3(-1.13, level + .03, -.52), Vector3(-.17, level + .03, -.52), CYAN * .6)
	_status(t, -.2, level + .06, -.5, GREEN)
	_fibre([Vector3(left + .1, level + .1, -.4), Vector3(left + .1, level + .1, -2.3)])
	_solar_module(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-64.0)), Vector3(.9, PENT + .5, -4.0)), 1.7, 1.05)
	_solar_module(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-64.0)), Vector3(.9, PENT + .5, -5.6)), 1.7, 1.05)
	_kit.lathe("plain", Vector3(-1.7, PENT + .94, -6.4), [Vector2(.42, 0), Vector2(.46, .08), Vector2(.46, .8), Vector2(.3, .96), Vector2(.02, 1.0)], Color("#a6b2b2"), 12)
	_kit.tube("metal", [Vector3(-2.1, PENT + .96, -.6), Vector3(-2.1, PENT + 2.3, -.6)], .02, Color("#6a6c6e"), 6)
	_bar("metal", Transform3D.IDENTITY, -2.1, PENT + 2.0, -.6, Vector3(.42, .05, .1), Color("#c8ccce"))

func _nobori(x: float, z: float, rect: Rect2) -> void:
	# のぼり on a sprung pole: water-filled base, two short arms, cloth on a slight curve.
	var f := _front
	var tall := 2.2
	var wide := .47
	var drop := 1.42
	_kit.lathe("plain", f * Vector3(x, 0, z), [Vector2(.2, 0), Vector2(.2, .1), Vector2(.06, .16), Vector2(.04, .24)], Color("#2a2c30"), 12)
	_kit.tube("metal", [f * Vector3(x, .2, z), f * Vector3(x, tall, z)], .012, Color("#dedfda"), 6)
	_kit.tube("metal", [f * Vector3(x, tall - .02, z), f * Vector3(x + wide, tall - .02, z + .04)], .007, Color("#dedfda"), 4)
	var steps := 5
	for i: int in range(steps):
		var u0 := float(i) / float(steps)
		var u1 := float(i + 1) / float(steps)
		var a := x + wide * u0
		var b := x + wide * u1
		var w0 := z + sin(u0 * 3.2) * .05
		var w1 := z + sin(u1 * 3.2) * .05
		var cut := Rect2(rect.position.x + rect.size.x * u0, rect.position.y, rect.size.x / float(steps), rect.size.y)
		_kit.atlas("banner", f * Vector3(a, tall - .03 - drop, w0), f * Vector3(a, tall - .03, w0), f * Vector3(b, tall - .03, w1), f * Vector3(b, tall - .03 - drop, w1), cut)
		_kit.atlas("banner", f * Vector3(b, tall - .03 - drop, w1 - .004), f * Vector3(b, tall - .03, w1 - .004), f * Vector3(a, tall - .03, w0 - .004), f * Vector3(a, tall - .03 - drop, w0 - .004), cut, Color(.7, .7, .7))

func _rack(x: float, z: float) -> void:
	# Pavement rack: a frame of pipe on two feet with a pocket panel each side.
	var f := _front
	var pipe := Color("#2c2e30")
	for side: float in [-.42, .42]:
		_kit.tube("metal", [f * Vector3(x + side, 0.03, z - .24), f * Vector3(x + side, 0.03, z + .24)], .012, pipe, 5)
		_kit.tube("metal", [f * Vector3(x + side, 0.03, z), f * Vector3(x + side, 1.42, z)], .012, pipe, 5)
	_kit.tube("metal", [f * Vector3(x - .42, 1.42, z), f * Vector3(x + .42, 1.42, z)], .012, pipe, 5)
	_kit.tube("metal", [f * Vector3(x - .42, .3, z), f * Vector3(x + .42, .3, z)], .012, pipe, 5)
	_bar("metal", f, x, .86, z, Vector3(.8, 1.04, .02), Color("#1a1b1e"))
	for row: int in range(4):
		var card := (row * 2 + 1) % 6
		var rect := _cell(1408.0 + float(card % 2) * 320.0, float(card / 2) * 210.0, 320, 210)
		var rect2 := _cell(1408.0 + float((card + 1) % 2) * 320.0, float(((card + 2) % 6) / 2) * 210.0, 320, 210)
		var y := .46 + float(row) * .25
		_sheet("card", f, Vector2(x - .19, y), z + .014, Vector2(.36, .235), rect, Color.WHITE, 0.0)
		_sheet("card", f, Vector2(x + .19, y), z + .014, Vector2(.36, .235), rect2, Color.WHITE, 0.0)

func _street_things() -> void:
	_nobori(1.42, .46, _cell(1530, 850, 100, 300))
	_nobori(4.12, .46, _cell(1420, 850, 100, 300))
	_nobori(.1, .4, _cell(1640, 850, 100, 300))
	_rack(4.92, .62)
