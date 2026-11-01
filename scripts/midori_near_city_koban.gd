extends "res://scripts/midori_near_city_handmade.gd"
## 緑公園前交番: the police box on the corner, in the tall thin way the city ones are now built.
## White tile piers, a black fascia with its gold star and two red lamps, a lattice over the
## upstairs windows. Nobody has staffed it since the drones: a terminal answers the door and the
## dock on the roof is the real station. The red lamps still stay on all night, as they always have.
## Local origin is the middle of the lot's street front.
const ATLAS := "res://assets/shinrai/near_city/koban_atlas.png"
const CUT_SHADER := preload("res://scripts/midori_near_city_cutout.gdshader")
const WIDE := 6.0
const DEEP := 7.9
const PIER := .46
const PORCH_TOP := 2.7
const BAND := 3.72
const TOP := 8.3
const PORCH := 1.2
const ROOM := 5.4
const TILE := Color(.95, .95, .92)
const BLACK := Color("#141416")
const SOFFIT := Color("#e8e8e2")
const RED := Color(.72, .015, .015)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 110
	_build_looks()
	_piers()
	_porch()
	_inside()
	_fascia()
	_upstairs()
	_flanks()
	_rooftop()
	_pavement()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "led", "leaf", "room", "sign", "poster", "cut", "label"])
	_kit = null
	_omni("Porch", Vector3(-.2, 2.3, .4), Color(.9, .96, 1.0), 1.3, 7.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.tile = _look("long_white_tiles", 1.4, .5)
	_looks.tile.set_shader_parameter("chroma", .4)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .6)
	_looks.stone = _look("", 1.0, .22)
	_looks.label = _look("", 1.0, .82) # Printed straight on a white box, so it must not glow past it.
	_looks.label.set_shader_parameter("albedo_map", signs)
	_looks.room = _look("", 1.0, .6)
	_looks.room.set_shader_parameter("glow", .6)
	_looks.room.set_shader_parameter("day_glow", .22)
	for row: Array in [["sign", .9, .2], ["poster", .6, .28]]:
		var look := _look("", 1.0, .8)
		look.set_shader_parameter("albedo_map", signs)
		look.set_shader_parameter("glow", row[1])
		look.set_shader_parameter("day_glow", row[2])
		_looks[row[0]] = look
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .9)
	letters.set_shader_parameter("day_glow", .2)
	_looks.decal = letters
	var cut := ShaderMaterial.new()
	cut.shader = CUT_SHADER
	cut.set_shader_parameter("atlas", signs)
	cut.set_shader_parameter("glow", .34)
	cut.set_shader_parameter("day_glow", .14)
	_looks.cut = cut

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _piers() -> void:
	var f := _front
	for x: float in [PIER * .5, WIDE - PIER * .5]:
		_bar("tile", f, x, TOP * .5, .04, Vector3(PIER, TOP, .2), TILE, .94, 1.0)
		_bar("stone", f, x, .22, .06, Vector3(PIER + .02, .44, .24), Color("#3a3c40"), .85, .9)
	_bar("metal", f, WIDE * .5, TOP + .05, .02, Vector3(WIDE + .1, .1, .26), Color("#b8bab6"))

func _porch() -> void:
	# The step back from the street that makes it a porch: tiled, lit, and open all night.
	var f := _front
	var x0 := PIER
	var x1 := WIDE - PIER
	var z := -PORCH
	_kit.quad("stone", f * Vector3(x0, .03, 0), f * Vector3(x0, .03, z), f * Vector3(x1, .03, z), f * Vector3(x1, .03, 0), Color("#6a6c6e"))
	_kit.quad("room", f * Vector3(x0, PORCH_TOP, z), f * Vector3(x0, PORCH_TOP, 0), f * Vector3(x1, PORCH_TOP, 0), f * Vector3(x1, PORCH_TOP, z), SOFFIT)
	_kit.quad("tile", f * Vector3(x0, 0, 0), f * Vector3(x0, PORCH_TOP, 0), f * Vector3(x0, PORCH_TOP, z), f * Vector3(x0, 0, z), TILE)
	_kit.quad("tile", f * Vector3(x1, 0, z), f * Vector3(x1, PORCH_TOP, z), f * Vector3(x1, PORCH_TOP, 0), f * Vector3(x1, 0, 0), TILE)
	for x: float in [1.5, 3.0, 4.5]:
		_kit.disc("lamp", f * Vector3(x, PORCH_TOP - .01, z * .5), Vector3.RIGHT, Vector3.BACK, .11, Color(.9, .96, 1.0))
	# Glass all the way across, the doors in the middle, a rail at hand height for the leaflets.
	_kit.quad("front", f * Vector3(x0, .03, z), f * Vector3(x0, PORCH_TOP, z), f * Vector3(x1, PORCH_TOP, z), f * Vector3(x1, .03, z), Color.WHITE)
	var frame := Color("#8a8e90")
	for x: float in [x0 + .03, 1.9, 3.0, 4.1, x1 - .03]:
		_bar("metal", f, x, PORCH_TOP * .5, z, Vector3(.06, PORCH_TOP, .08), frame)
	_bar("metal", f, WIDE * .5, 2.24, z, Vector3(x1 - x0, .06, .08), frame)
	for x: float in [2.84, 3.16]:
		_bar("metal", f, x, 1.1, z + .05, Vector3(.03, .5, .03), Color("#d0d2d0"))
	_panel("poster", f, 3.2, 3.9, 1.0, 1.47, z + .045, _cell(1530, 230, 300, 200))
	# The case by the door, and the lantern the neighbourhood association gave them in 1998.
	var wall := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x0, 0, 0))
	_bar("metal", wall, .68, 1.42, .04, Vector3(1.0, .72, .06), frame)
	_panel("poster", wall, .22, 1.14, .9, 1.94, .075, _cell(610, 230, 500, 320))
	_paper_lantern(f * Vector3(x1 - .36, 2.68, -.26))
	_kit.tube("metal", [f * Vector3(x1 - .1, 2.6, -.26), f * Vector3(x1 - .36, 2.6, -.26)], .01, Color("#26282a"), 4)

func _paper_lantern(top: Vector3) -> void:
	var rect := _cell(1120, 230, 400, 200)
	var wide := .2
	var tall := .6
	var sides := 12
	var rows := 6
	for r: int in range(rows):
		var t0 := float(r) / float(rows)
		var t1 := float(r + 1) / float(rows)
		var r0 := wide * (.62 + .38 * sin(PI * t0))
		var r1 := wide * (.62 + .38 * sin(PI * t1))
		var y0 := top.y - .1 - tall * (1.0 - t0)
		var y1 := top.y - .1 - tall * (1.0 - t1)
		for s: int in range(sides):
			var a0 := -TAU * float(s) / float(sides)
			var a1 := -TAU * float(s + 1) / float(sides)
			var uv := Rect2(rect.position + Vector2(rect.size.x * float(s) / float(sides), rect.size.y * (1.0 - t1)), Vector2(rect.size.x / float(sides), rect.size.y / float(rows)))
			_kit.atlas("sign", Vector3(top.x + cos(a0) * r0, y0, top.z + sin(a0) * r0), Vector3(top.x + cos(a0) * r1, y1, top.z + sin(a0) * r1), Vector3(top.x + cos(a1) * r1, y1, top.z + sin(a1) * r1), Vector3(top.x + cos(a1) * r0, y0, top.z + sin(a1) * r0), uv)
	var band := Color("#17130f")
	_kit.lathe("plain", top + Vector3.DOWN * .12, [Vector2(wide * .7, 0), Vector2(wide * .7, .05), Vector2(.0, .06)], band, 14)
	_kit.lathe("plain", top + Vector3.DOWN * (tall + .12), [Vector2(.0, -.01), Vector2(wide * .7, 0), Vector2(wide * .7, .05)], band, 14)

func _inside() -> void:
	# One bright room and no one in it: a counter, the ward map, and the screen that took over.
	var f := _front
	var x0 := PIER
	var x1 := WIDE - PIER
	var near := -PORCH
	var far := -ROOM
	var head := PORCH_TOP
	var wall := Color("#dfe2dc")
	_kit.quad("room", f * Vector3(x0, .02, near), f * Vector3(x0, .02, far), f * Vector3(x1, .02, far), f * Vector3(x1, .02, near), Color("#9aa09a"))
	_kit.quad("room", f * Vector3(x0, head, far), f * Vector3(x0, head, near), f * Vector3(x1, head, near), f * Vector3(x1, head, far), Color("#c8ccc6"))
	_kit.quad("room", f * Vector3(x0, 0, far), f * Vector3(x0, head, far), f * Vector3(x1, head, far), f * Vector3(x1, 0, far), wall)
	_kit.quad("room", f * Vector3(x0, 0, near), f * Vector3(x0, head, near), f * Vector3(x0, head, far), f * Vector3(x0, 0, far), wall)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, head, far), f * Vector3(x1, head, near), f * Vector3(x1, 0, near), wall)
	for x: float in [1.7, 4.3]:
		_bar("lamp", f, x, head - .02, -3.3, Vector3(.12, .02, 2.8), Color(.9, .96, 1.0))
	_panel("poster", f, .9, 3.3, .94, 2.42, far + .02, _cell(0, 560, 700, 500))
	_bar("room", f, 3.0, .46, -3.2, Vector3(3.6, .92, .6), Color("#6a7a8a"))
	_bar("metal", f, 3.0, .94, -3.15, Vector3(3.7, .05, .72), Color("#c8ccc8"))
	_bar("metal", f, 4.1, 1.5, -3.2, Vector3(.66, .9, .05), Color("#2a2c2e"))
	_panel("poster", f, 3.82, 4.38, 1.1, 1.9, -3.17, _cell(710, 560, 320, 420))
	_kit.tube("metal", [f * Vector3(4.1, .96, -3.2), f * Vector3(4.1, 1.08, -3.2)], .03, STEEL, 6)
	for x: float in [1.8, 2.5]:
		_kit.lathe("plain", f * Vector3(x, 0, -2.3), [Vector2(.16, .02), Vector2(.04, .04), Vector2(.04, .4), Vector2(.18, .44), Vector2(.0, .5)], Color("#2a3a5a"), 20)

func _fascia() -> void:
	var f := _front
	var mid := (PORCH_TOP + BAND) * .5
	var tall := BAND - PORCH_TOP
	_bar("plain", f, WIDE * .5, mid, -.11, Vector3(WIDE - PIER * 2.0, tall, .5), BLACK)
	_panel("sign", f, 1.2, WIDE - 1.2, PORCH_TOP + .16, BAND - .1, .15, _cell(0, 0, 1300, 220))
	for x: float in [.86, WIDE - .86]:
		_bar("metal", f, x, mid, .17, Vector3(.2, .62, .06), Color("#26282a"))
		_bar("led", f, x, mid, .205, Vector3(.15, .56, .012), RED)
		_bar("lamp", f, x, mid, .214, Vector3(.035, .46, .006), Color(1.0, .34, .2))
	_camera(f * Vector3(PIER + .16, PORCH_TOP - .02, -.1))

func _upstairs() -> void:
	# The lattice is what the street sees: black fins, set proud of the real wall behind.
	var f := _front
	var inner := Transform3D(Basis.IDENTITY, f * Vector3(0, 0, -.5))
	var x0 := PIER
	var x1 := WIDE - PIER
	var windows: Array[Rect2] = [Rect2(.7, 4.2, 2.2, 1.3), Rect2(3.1, 4.2, 2.2, 1.3), Rect2(.7, 6.1, 2.2, 1.3), Rect2(3.1, 6.1, 2.2, 1.3)]
	for piece: Rect2 in _minus(Rect2(x0, BAND, x1 - x0, TOP - .5 - BAND), windows):
		_kit.quad("plain", inner * Vector3(piece.position.x, piece.position.y, 0), inner * Vector3(piece.position.x, piece.end.y, 0), inner * Vector3(piece.end.x, piece.end.y, 0), inner * Vector3(piece.end.x, piece.position.y, 0), Color("#2c2e30"), .8, .9)
	for r: Rect2 in windows:
		_window(inner, r, _rng.randf(), false)
	var low := BAND + .02
	var high := TOP - .48
	var x := x0 + .13
	while x < x1:
		_bar("metal", f, x, (low + high) * .5, -.14, Vector3(.045, high - low, .2), BLACK)
		x += .26
	for y: float in [5.86, 7.0]:
		_bar("metal", f, WIDE * .5, y, -.14, Vector3(x1 - x0, .05, .2), BLACK)
	for z: float in [0.0]:
		_bar("plain", f, WIDE * .5, TOP - .24, z - .22, Vector3(x1 - x0, .5, .56), BLACK)
	_panel("decal", f, 1.5, WIDE - 1.5, TOP - .46, TOP - .04, .064, _cell(1310, 130, 620, 90))
	# Blade sign for anyone coming along the pavement, who cannot see a word of the front.
	_koban_blade(f * Vector3(-.02, 5.2, -.5))

func _koban_blade(at: Vector3) -> void:
	var near := at + Vector3.LEFT * .14
	var far := at + Vector3.LEFT * 1.56
	var low := Vector3.DOWN * .2
	var high := Vector3.UP * .2
	var rect := _cell(1310, 0, 420, 120)
	_kit.beam("metal", at, far, .04, .44, Vector3.BACK, Color("#2a2c2e"))
	_kit.atlas("sign", far + low + Vector3.BACK * .03, far + high + Vector3.BACK * .03, near + high + Vector3.BACK * .03, near + low + Vector3.BACK * .03, rect)
	_kit.atlas("sign", near + low + Vector3.FORWARD * .03, near + high + Vector3.FORWARD * .03, far + high + Vector3.FORWARD * .03, far + low + Vector3.FORWARD * .03, rect)

func _flanks() -> void:
	# Round the side, the tile gives out to the same render as any back office.
	var paint := Color(.82, .78, .68)
	var low_a := Rect2(1.8, 1.0, 1.5, 1.1)
	var low_b := Rect2(4.2, 1.0, 1.5, 1.1)
	var up_a := Rect2(1.4, 4.5, 1.5, 1.0)
	var up_b := Rect2(4.2, 4.5, 1.5, 1.0)
	var louvre := Rect2(2.6, 6.6, 2.0, .9)
	var holes: Array[Rect2] = [low_a, low_b, up_a, up_b, louvre]
	_render_wall(_west, DEEP, TOP, 3.3, 2.5, paint, holes, .8)
	for r: Rect2 in [low_a, low_b]:
		_window(_west, r, _rng.randf(), true)
	for r: Rect2 in [up_a, up_b]:
		_window(_west, r, _rng.randf(), false)
	_reveal(_west, louvre, .1, Color("#6b6a66"))
	_kit.quad("plain", _west * Vector3(louvre.position.x, louvre.position.y, -.1), _west * Vector3(louvre.position.x, louvre.end.y, -.1), _west * Vector3(louvre.end.x, louvre.end.y, -.1), _west * Vector3(louvre.end.x, louvre.position.y, -.1), Color("#17181a"))
	var y := louvre.position.y + .03
	while y < louvre.end.y - .06:
		_kit.quad("metal", _west * Vector3(louvre.position.x, y, -.01), _west * Vector3(louvre.position.x, y + .09, -.09), _west * Vector3(louvre.end.x, y + .09, -.09), _west * Vector3(louvre.end.x, y, -.01), Color("#a8aaa6"))
		y += .13
	_bar("plain", _west, DEEP * .5, 3.2, .05, Vector3(DEEP, .12, .1), paint * .8)
	# Red lamp on the corner, the sign box and the AED: the three things a side wall has to say.
	_bar("metal", _west, DEEP - .5, 3.2, .05, Vector3(.2, .62, .08), Color("#26282a"))
	_bar("led", _west, DEEP - .5, 3.2, .095, Vector3(.15, .56, .012), RED)
	_bar("lamp", _west, DEEP - .5, 3.2, .104, Vector3(.035, .46, .006), Color(1.0, .34, .2))
	_bar("metal", _west, 6.5, 2.0, .02, Vector3(.74, .46, .04), ALUMINIUM)
	_panel("poster", _west, 6.16, 6.84, 1.8, 2.2, .045, _cell(1450, 560, 200, 120))
	_camera(_west * Vector3(6.9, 3.0, .12))
	_kit.tube("plain", [_west * Vector3(.5, .1, .08), _west * Vector3(.5, TOP - .1, .08)], .05, Color("#8a8b84"), 7)
	_kit.tube("plain", [_west * Vector3(3.8, .1, .08), _west * Vector3(3.8, 3.1, .08)], .04, Color("#6a6a64"), 6)
	_fibre([_west * Vector3(7.5, TOP, .03), _west * Vector3(7.5, .3, .03)])
	_bar("metal", _west, 1.0, 1.4, .08, Vector3(.42, .56, .14), Color("#9a9c98"))
	_outdoor_unit(_west, 1.1, .5, .2)
	_render_wall(_east, DEEP, TOP, 3.3, 2.5, paint, [] as Array[Rect2], .7)
	_render_wall(_back, WIDE, TOP, 3.3, 2.5, paint, [] as Array[Rect2], .7)
	_outdoor_unit(_back, 1.4, 3.0, .2)
	_outdoor_unit(_back, 3.4, 3.0, .2)

func _rooftop() -> void:
	var half := WIDE * .5
	var level := TOP + .02
	_kit.quad("plain", Vector3(-half, level, 0), Vector3(-half, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, 0), Color("#5c5d59"), .8, .9)
	var roof := Transform3D(Basis.IDENTITY, Vector3(0, level, 0))
	var parapet := Color(.82, .78, .68)
	for row: Array in [[-half + .08, -DEEP * .5, .16, DEEP], [half - .08, -DEEP * .5, .16, DEEP], [0.0, -DEEP + .08, WIDE, .16]]:
		_bar("render", roof, row[0], .22, row[1], Vector3(row[2], .44, row[3]), parapet)
		_bar("metal", roof, row[0], .46, row[1], Vector3(row[2] + .03, .04, row[3] + .03), Color("#a8aaa8"))
	# The dock: a steel table and a painted pad, empty, because the unit is always out.
	var dock := Vector3(0, level, -4.2)
	var steel := Color("#3a3d40")
	for a: float in [PI * .25, PI * .75, PI * 1.25, PI * 1.75]:
		_kit.tube("metal", [dock + Vector3(cos(a) * 1.0, 0, sin(a) * 1.0), dock + Vector3(cos(a) * .9, .9, sin(a) * .9)], .05, steel, 6)
	_kit.lathe("metal", dock + Vector3.UP * .86, [Vector2(0, 0), Vector2(1.22, .02), Vector2(1.22, .1)], Color("#55585a"), 28)
	_kit.disc("sign", dock + Vector3.UP * .97, Vector3.RIGHT, Vector3.FORWARD, 1.16, Color.WHITE, _cell(1684, 444, 352, 352))
	var ring: Array[Vector3] = []
	for i: int in range(33):
		var a := TAU * float(i) / 32.0
		ring.append(dock + Vector3(cos(a) * 1.24, 1.0, sin(a) * 1.24))
	_kit.tube("led", ring, .012, CYAN, 4)
	_bar("metal", roof, 2.1, .4, -3.0, Vector3(.7, .8, .5), Color("#a4a8aa"))
	_status(roof, 2.1, .6, -2.74, GREEN)
	_kit.tube("metal", [Vector3(-2.2, level, -6.8), Vector3(-2.2, level + 3.4, -6.8)], .05, steel, 7)
	for y: float in [2.4, 3.0]:
		_bar("metal", roof, -2.2, y, -6.66, Vector3(.2, .46, .1), Color("#c8ccce"))
	_bar("led", roof, -2.2, 3.44, -6.8, Vector3(.05, .05, .05), RED)
	_bar("render", roof, 1.9, .9, -6.6, Vector3(1.5, 1.8, 1.8), parapet)
	_bar("metal", roof, 1.9, 1.84, -6.6, Vector3(1.6, .08, 1.9), Color("#8a8c8a"))

func _pavement() -> void:
	var f := _front
	# The board that tells the ward how yesterday went.
	var board := Transform3D(Basis(Vector3.UP, .12), f * Vector3(1.05, 0, .7))
	_bar("metal", board, 0, .84, 0, Vector3(1.3, .8, .12), Color("#d0d2d0"))
	_panel("poster", board, -.6, .6, .48, 1.2, .064, _cell(0, 230, 600, 320))
	_bar("metal", board, 0, 1.28, .05, Vector3(1.36, .05, .22), Color("#d0d2d0"))
	for x: float in [-.55, .55]:
		_bar("metal", board, x, .22, 0, Vector3(.08, .44, .12), Color("#b0b2b0"))
	_owl(f * Vector3(2.3, 0, -.8))
	_police_cub(Transform3D(Basis(Vector3.UP, -.08), f * Vector3(3.92, 0, -.5)))
	# The two beat bicycles along the side wall, boxes to the street, where they always get left.
	var label := _cell(1450, 860, 300, 110)
	_police_bicycle(Transform3D(Basis(Vector3.UP, -PI * .5 - .14), f * Vector3(-.62, 0, -2.0)), label)
	_police_bicycle(Transform3D(Basis(Vector3.UP, -PI * .5 - .1), f * Vector3(-.74, 0, -4.1)), label)
	_cone(f * Vector3(5.5, 0, .9), 3)
	_cone(f * Vector3(4.8, 0, 1.0))

func _owl(foot: Vector3) -> void:
	# ミドリン, life-size for an owl with a cap and a job, on a steel foot.
	var t := Transform3D(Basis(Vector3.UP, .2), foot)
	_kit.atlas("cut", t * Vector3(-.5, .03, 0), t * Vector3(-.5, 1.28, 0), t * Vector3(.5, 1.28, 0), t * Vector3(.5, .03, 0), _cell(1040, 560, 400, 500))
	_bar("metal", t, 0, .02, 0, Vector3(.5, .04, .24), STEEL)

func _cone(at: Vector3, stacked := 0) -> void:
	# Red, two white bands, a square rubber foot; the spares wait underneath, one inside the next.
	for i: int in range(stacked + 1):
		var foot := at + Vector3.UP * float(i) * .05
		_bar("plain", Transform3D(Basis.IDENTITY, foot), 0, .02, 0, Vector3(.36, .04, .36), Color("#a81c14"))
	var base := at + Vector3.UP * float(stacked) * .05
	_kit.lathe("plain", base + Vector3.UP * .04, [Vector2(.13, 0), Vector2(.09, .22), Vector2(.05, .46), Vector2(.022, .66), Vector2(.0, .68)], Color("#d8380f"), 24)
	_kit.lathe("plain", base + Vector3.UP * .17, [Vector2(.107, 0), Vector2(.092, .09)], Color("#f4f4ee"), 24)
	_kit.lathe("plain", base + Vector3.UP * .38, [Vector2(.07, 0), Vector2(.058, .09)], Color("#f4f4ee"), 24)

func _arc(t: Transform3D, centre: Vector2, radius: float, a0: float, a1: float, steps: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i: int in range(steps + 1):
		var a := lerpf(a0, a1, float(i) / float(steps))
		points.append(t * Vector3(centre.x + cos(a) * radius, centre.y + sin(a) * radius, 0))
	return points

func _sweep(t: Transform3D, path: Array[Vector2], steps: int, z := 0.0) -> Array[Vector3]:
	# A smooth line through the given points, so a frame bends instead of kinking.
	var points: Array[Vector3] = []
	for i: int in range(path.size() - 1):
		var p0 := path[maxi(i - 1, 0)]
		var p1 := path[i]
		var p2 := path[i + 1]
		var p3 := path[mini(i + 2, path.size() - 1)]
		for k: int in range(steps):
			var at := p1.cubic_interpolate(p2, p0, p3, float(k) / float(steps))
			points.append(t * Vector3(at.x, at.y, z))
	var last := path[path.size() - 1]
	points.append(t * Vector3(last.x, last.y, z))
	return points

func _loft(t: Transform3D, sections: Array[Vector4], tint: Color, around := 16, steps := 4) -> void:
	# Pressed bodywork: oval sections (x, y, half width, half height) skinned along a curve.
	var rings: Array[Vector4] = []
	for i: int in range(sections.size() - 1):
		var s0 := sections[maxi(i - 1, 0)]
		var s1 := sections[i]
		var s2 := sections[i + 1]
		var s3 := sections[mini(i + 2, sections.size() - 1)]
		for k: int in range(steps):
			rings.append(s1.cubic_interpolate(s2, s0, s3, float(k) / float(steps)))
	rings.append(sections[sections.size() - 1])
	var across := t.basis.z
	for r: int in range(rings.size() - 1):
		var a := rings[r]
		var b := rings[r + 1]
		var along := Vector2(b.x - a.x, b.y - a.y).normalized()
		var before := Vector2(a.x - rings[maxi(r - 1, 0)].x, a.y - rings[maxi(r - 1, 0)].y).normalized()
		if r == 0:
			before = along
		var after := Vector2(rings[mini(r + 2, rings.size() - 1)].x - b.x, rings[mini(r + 2, rings.size() - 1)].y - b.y).normalized()
		if r == rings.size() - 2:
			after = along
		var n0 := t.basis * Vector3(-(before + along).normalized().y, (before + along).normalized().x, 0)
		var n1 := t.basis * Vector3(-(along + after).normalized().y, (along + after).normalized().x, 0)
		var c0 := t * Vector3(a.x, a.y, 0)
		var c1 := t * Vector3(b.x, b.y, 0)
		for s: int in range(around):
			var u0 := -TAU * float(s) / float(around)
			var u1 := -TAU * float(s + 1) / float(around)
			var p := c0 + across * cos(u0) * a.z + n0 * sin(u0) * a.w
			var q := c1 + across * cos(u0) * b.z + n1 * sin(u0) * b.w
			var e := c1 + across * cos(u1) * b.z + n1 * sin(u1) * b.w
			var g := c0 + across * cos(u1) * a.z + n0 * sin(u1) * a.w
			_kit.smooth("plain", p, q, e, g, (across * cos(u0) / maxf(a.z, .01) + n0 * sin(u0) / maxf(a.w, .01)).normalized(), (across * cos(u0) / maxf(b.z, .01) + n1 * sin(u0) / maxf(b.w, .01)).normalized(), (across * cos(u1) / maxf(b.z, .01) + n1 * sin(u1) / maxf(b.w, .01)).normalized(), (across * cos(u1) / maxf(a.z, .01) + n0 * sin(u1) / maxf(a.w, .01)).normalized(), tint)

func _band(t: Transform3D, hub: Vector2, radius: float, a0: float, a1: float, half: float, tint: Color) -> void:
	# A mudguard: a curved strip, seen from both sides, with a shallow crown across it.
	var steps := 22
	for i: int in range(steps):
		var u0 := lerpf(a0, a1, float(i) / float(steps))
		var u1 := lerpf(a0, a1, float(i + 1) / float(steps))
		var d0 := Vector3(cos(u0), sin(u0), 0)
		var d1 := Vector3(cos(u1), sin(u1), 0)
		var c := Vector3(hub.x, hub.y, 0)
		var n0 := t.basis * d0
		var n1 := t.basis * d1
		for row: Array in [[half, 0.0, half * .34, 0.0], [0.0, -half, 0.0, -half * .34]]:
			var z0: float = row[0]
			var z1: float = row[1]
			var side: float = 1.0 if z0 > 0.0 else -1.0
			var lift0 := radius if z0 == 0.0 else radius - .012
			var lift1 := radius if z1 == 0.0 else radius - .012
			var a := t * (c + d0 * lift0 + Vector3(0, 0, z0))
			var b := t * (c + d1 * lift0 + Vector3(0, 0, z0))
			var e := t * (c + d1 * lift1 + Vector3(0, 0, z1))
			var f := t * (c + d0 * lift1 + Vector3(0, 0, z1))
			var lean := t.basis.z * side * .18
			_kit.smooth("plain", a, b, e, f, (n0 + lean).normalized(), (n1 + lean).normalized(), (n1 + lean).normalized(), (n0 + lean).normalized(), tint)
			_kit.smooth("plain", f, e, b, a, -n0, -n1, -n1, -n0, tint * .6)

func _wheel(t: Transform3D, x: float, y: float, radius: float, tyre: float, spokes: int) -> void:
	var hub := Vector2(x, y)
	var rim := radius - tyre - .012
	_kit.tube("plain", _arc(t, hub, radius - tyre, 0.0, TAU, 44), tyre, Color("#17181a"), 10)
	_kit.tube("metal", _arc(t, hub, rim, 0.0, TAU, 44), .009, Color("#c4c6c4"), 5)
	for i: int in range(spokes):
		var a := TAU * float(i) / float(spokes)
		var side := .022 if i % 2 == 0 else -.022
		var inner := a + (.5 if i % 2 == 0 else -.5)
		_kit.tube("metal", [t * Vector3(x + cos(inner) * .03, y + sin(inner) * .03, side), t * Vector3(x + cos(a) * rim, y + sin(a) * rim, 0)], .0026, Color("#b4b6b4"), 3)
	_ball(t * Vector3(x, y, 0), Vector3(.034, .034, .06), Color("#c4c6c4"), "metal", 6, 10, t.basis)

func _police_bicycle(t: Transform3D, name_cell: Rect2) -> void:
	# The real one: a white step-through city bike, built heavy, with a box on the back rack.
	var white := Color("#e6e6e0")
	var black := Color("#17181a")
	var chrome := Color("#c4c6c4")
	var hub := .345
	var nose := .53
	var tail := -.53
	_wheel(t, nose, hub, .335, .021, 18)
	_wheel(t, tail, hub, .335, .021, 18)
	_band(t, Vector2(nose, hub), .36, .55, 2.8, .032, white)
	_band(t, Vector2(tail, hub), .36, .3, 2.75, .034, white)
	# Two sloping tubes where a man's bike has a crossbar: you step through it in uniform.
	_kit.tube("plain", _arc(t, Vector2(nose, hub), .0, 0.0, .1, 1), .001, white, 3)
	_kit.tube("plain", _sweep(t, [Vector2(.36, .74), Vector2(.31, .94)] as Array[Vector2], 1), .021, white, 10)
	_kit.tube("plain", _sweep(t, [Vector2(.33, .87), Vector2(.14, .56), Vector2(-.02, .3)] as Array[Vector2], 5), .017, white, 8)
	_kit.tube("plain", _sweep(t, [Vector2(.35, .78), Vector2(.15, .49), Vector2(.0, .27)] as Array[Vector2], 5), .017, white, 8)
	_kit.tube("plain", _sweep(t, [Vector2(-.01, .28), Vector2(-.16, .82)] as Array[Vector2], 1), .018, white, 8)
	for z: float in [-1.0, 1.0]:
		_kit.tube("plain", [t * Vector3(-.01, .28, z * .03), t * Vector3(tail, hub, z * .056)], .011, white, 6)
		_kit.tube("plain", [t * Vector3(-.125, .68, z * .02), t * Vector3(tail, hub, z * .056)], .009, white, 6)
		_kit.tube("plain", [t * Vector3(.365, .72, z * .03), t * Vector3(.49, .46, z * .046), t * Vector3(nose, hub, z * .046)], .012, white, 8)
		_kit.tube("metal", [t * Vector3(nose, hub, z * .05), t * Vector3(.72, .56, z * .036)], .004, chrome, 4)
		# The double stand: both legs down, the way a box-laden bike has to stand.
		_kit.tube("metal", [t * Vector3(-.47, .34, z * .06), t * Vector3(-.43, .006, z * .17)], .011, chrome, 6)
		_kit.tube("metal", [t * Vector3(tail, hub, z * .06), t * Vector3(-.66, .72, z * .1)], .008, chrome, 5)
	_kit.tube("metal", [t * Vector3(-.43, .012, -.2), t * Vector3(-.43, .012, .2)], .013, chrome, 6)
	# Saddle on a sprung post.
	_kit.tube("metal", _sweep(t, [Vector2(-.16, .82), Vector2(-.19, .9)] as Array[Vector2], 1), .012, chrome, 6)
	_ball(t * Vector3(-.17, .93, 0), Vector3(.13, .03, .06), black, "plain", 8, 12, t.basis)
	_ball(t * Vector3(-.26, .935, 0), Vector3(.08, .04, .115), black, "plain", 8, 12, t.basis)
	for z: float in [-.05, .05]:
		_kit.tube("metal", _sweep(t, [Vector2(-.27, .91), Vector2(-.26, .87)] as Array[Vector2], 1, z), .012, chrome, 6)
	# Swept-back bars, grips, levers and the bell nobody has used since the drones.
	_kit.tube("metal", _sweep(t, [Vector2(.31, .94), Vector2(.29, 1.07)] as Array[Vector2], 1), .012, chrome, 6)
	for z: float in [-1.0, 1.0]:
		_kit.tube("metal", [t * Vector3(.29, 1.07, 0), t * Vector3(.27, 1.09, z * .1), t * Vector3(.19, 1.11, z * .21), t * Vector3(.08, 1.11, z * .28)], .011, chrome, 6)
		_kit.tube("plain", [t * Vector3(.14, 1.11, z * .245), t * Vector3(.05, 1.11, z * .295)], .016, black, 8)
		_kit.tube("metal", [t * Vector3(.21, 1.11, z * .19), t * Vector3(.16, 1.07, z * .26)], .005, chrome, 4)
	_ball(t * Vector3(.24, 1.14, .08), Vector3(.03, .018, .03), chrome, "metal", 6, 10, t.basis)
	_kit.tube("plain", _sweep(t, [Vector2(.2, 1.1), Vector2(.42, 1.0), Vector2(.36, .84)] as Array[Vector2], 5, .05), .0035, black, 3)
	_ball(t * Vector3(.45, .72, 0), Vector3(.05, .05, .05), chrome, "metal", 8, 12, t.basis)
	_kit.disc("plain", t * Vector3(.495, .72, 0), -t.basis.z, t.basis.y, .04, Color("#f4f2e0"))
	# Full chain case, the cranks and pedals, and the skirt guard's stays.
	_ball(t * Vector3(-.26, .33, .075), Vector3(.34, .095, .012), white, "plain", 8, 18, t.basis)
	_ball(t * Vector3(-.01, .28, .082), Vector3(.1, .1, .012), white, "plain", 8, 18, t.basis)
	_kit.tube("metal", [t * Vector3(-.01, .28, .1), t * Vector3(.06, .12, .11)], .012, chrome, 6)
	_kit.tube("metal", [t * Vector3(-.01, .28, -.1), t * Vector3(-.08, .44, -.11)], .012, chrome, 6)
	_bar("plain", Transform3D(t.basis, t * Vector3(.06, .12, .16)), 0, 0, 0, Vector3(.1, .02, .09), black)
	_bar("plain", Transform3D(t.basis, t * Vector3(-.08, .44, -.16)), 0, 0, 0, Vector3(.1, .02, .09), black)
	# The rack, and the box that makes it a police bicycle.
	for z: float in [-.12, .12]:
		_kit.tube("metal", [t * Vector3(-.3, .73, z * .5), t * Vector3(-.34, .73, z), t * Vector3(-.88, .73, z)], .009, chrome, 5)
	for x: float in [-.42, -.6, -.78]:
		_kit.tube("metal", [t * Vector3(x, .73, -.12), t * Vector3(x, .73, .12)], .007, chrome, 4)
	var box := Color("#f0f0ea")
	_bar("plain", t, -.61, .87, 0, Vector3(.58, .27, .46), box, .9, 1.0)
	_bar("plain", t, -.61, 1.03, 0, Vector3(.6, .05, .48), box, 1.0, 1.0)
	_panel("label", t, -.89, -.33, .75, .99, .232, name_cell)
	var other := Transform3D(t.basis * Basis(Vector3.UP, PI), t.origin)
	_panel("label", other, .33, .89, .75, .99, .232, name_cell)
	var rear := Transform3D(t.basis * Basis(Vector3.UP, PI * .5), t * Vector3(-.902, 0, 0))
	_panel("label", rear, -.21, .21, .77, .99, 0, name_cell)
	_ball(t * Vector3(-.9, .7, 0), Vector3(.012, .03, .03), Color("#b01010"), "plain", 6, 10, t.basis)

func _police_cub(t: Transform3D) -> void:
	# The white Super Cub: leg shield, seat, a box on the rack, a little rack on the nose.
	var white := Color("#ecece4")
	var black := Color("#17181a")
	var chrome := Color("#c8cac8")
	var amber := Color("#e88a14")
	var hub := .285
	var nose := .6
	var tail := -.58
	_wheel(t, nose, hub, .285, .044, 20)
	_wheel(t, tail, hub, .285, .044, 20)
	_band(t, Vector2(nose, hub), .32, .45, 2.75, .062, white)
	_band(t, Vector2(tail, hub), .325, .55, 2.6, .068, white)
	# The step-through spine and the rear body, all one pressed shape.
	_loft(t, [Vector4(.44, 1.0, .01, .01), Vector4(.43, .96, .04, .04), Vector4(.34, .7, .09, .07), Vector4(.16, .44, .11, .08), Vector4(-.06, .42, .12, .1), Vector4(-.26, .55, .15, .15), Vector4(-.46, .64, .165, .165), Vector4(-.6, .69, .14, .12), Vector4(-.69, .72, .09, .075), Vector4(-.715, .735, .01, .01)] as Array[Vector4], white, 18, 5)
	# The leg shield, a thin wide curve from under the bars down to the footboards.
	_loft(t, [Vector4(.43, 1.0, .01, .01), Vector4(.42, .97, .07, .024), Vector4(.4, .84, .15, .026), Vector4(.34, .64, .2, .03), Vector4(.27, .46, .215, .03), Vector4(.21, .34, .2, .026), Vector4(.18, .3, .02, .01)] as Array[Vector4], white, 16, 5)
	_loft(t, [Vector4(-.08, .78, .01, .01), Vector4(-.14, .81, .1, .04), Vector4(-.36, .845, .135, .055), Vector4(-.6, .85, .125, .055), Vector4(-.69, .83, .02, .01)] as Array[Vector4], black, 18, 4)
	# Engine low in the frame, fins and all, with the exhaust running back along the right.
	_ball(t * Vector3(.0, .26, 0), Vector3(.17, .12, .115), Color("#8f908c"), "plain", 10, 18, t.basis)
	_ball(t * Vector3(.17, .26, 0), Vector3(.09, .07, .08), Color("#9a9b96"), "plain", 8, 14, t.basis)
	_kit.disc("metal", t * Vector3(.0, .26, .118), t.basis.x, t.basis.y, .075, Color("#b8bab6"))
	_kit.disc("metal", t * Vector3(.0, .26, .122), t.basis.x, t.basis.y, .045, Color("#8a8c8a"))
	for x: float in [.12, .16, .2, .24]:
		_bar("metal", t, x, .26, 0, Vector3(.012, .12, .15), Color("#6a6c6a"))
	_kit.tube("metal", _sweep(t, [Vector2(.2, .22), Vector2(.06, .15), Vector2(-.2, .17), Vector2(-.42, .2)] as Array[Vector2], 5, .15), .018, chrome, 8)
	_ball(t * Vector3(-.5, .22, .15), Vector3(.24, .05, .05), chrome, "metal", 8, 12, t.basis)
	_ball(t * Vector3(-.28, .27, -.09), Vector3(.33, .05, .022), black, "plain", 8, 14, t.basis)
	_kit.tube("plain", [t * Vector3(-.03, .18, -.3), t * Vector3(-.03, .18, .3)], .016, black, 8)
	for z: float in [-1.0, 1.0]:
		_kit.tube("plain", [t * Vector3(-.03, .18, z * .22), t * Vector3(-.03, .18, z * .3)], .024, black, 8)
		_kit.tube("metal", [t * Vector3(tail, hub, z * .115), t * Vector3(-.5, .68, z * .115)], .02, chrome, 8)
		_kit.tube("metal", [t * Vector3(-.18, .2, z * .09), t * Vector3(-.2, .006, z * .15)], .014, Color("#3a3c3e"), 6)
		_kit.tube("plain", [t * Vector3(.44, .92, z * .075), t * Vector3(.52, .44, z * .075), t * Vector3(nose, hub, z * .075)], .024, white, 10)
		# Bars, grip, amber indicator, and a round mirror on a long stalk.
		_kit.tube("metal", [t * Vector3(.44, 1.09, z * .18), t * Vector3(.42, 1.1, z * .3)], .012, chrome, 6)
		_kit.tube("plain", [t * Vector3(.42, 1.1, z * .3), t * Vector3(.41, 1.1, z * .42)], .02, black, 10)
		_ball(t * Vector3(.5, 1.07, z * .26), Vector3(.05, .045, .045), amber, "plain", 8, 12, t.basis)
		_kit.tube("metal", [t * Vector3(.42, 1.12, z * .22), t * Vector3(.36, 1.34, z * .34)], .006, Color("#3a3c3e"), 5)
		var glass := t * Vector3(.355, 1.37, z * .35)
		_ball(glass, Vector3(.012, .062, .062), black, "plain", 8, 14, t.basis)
		_kit.tube("metal", [t * Vector3(-.7, .76, z * .08), t * Vector3(-.74, .76, z * .16)], .008, Color("#3a3c3e"), 5)
		_ball(t * Vector3(-.76, .76, z * .17), Vector3(.04, .03, .03), amber, "plain", 6, 10, t.basis)
	_kit.tube("metal", [t * Vector3(-.2, .012, -.2), t * Vector3(-.2, .012, .2)], .014, Color("#3a3c3e"), 6)
	# The nacelle that carries headlamp, bars and speedo in one white casting.
	_ball(t * Vector3(.44, 1.08, 0), Vector3(.13, .07, .25), white, "plain", 12, 20, t.basis)
	_ball(t * Vector3(.53, 1.07, 0), Vector3(.05, .095, .095), chrome, "metal", 10, 16, t.basis)
	_kit.disc("lamp", t * Vector3(.578, 1.07, 0), -t.basis.z, t.basis.y, .078, Color(1.0, .96, .84))
	_ball(t * Vector3(.4, 1.15, 0), Vector3(.05, .018, .07), Color("#2a2c2e"), "plain", 6, 10, t.basis)
	# Crash rack on the nose, the first thing to meet a bollard.
	for z: float in [-1.0, 1.0]:
		_kit.tube("plain", [t * Vector3(.52, .78, z * .1), t * Vector3(.7, .7, z * .17), t * Vector3(.7, .46, z * .19), t * Vector3(.6, .36, z * .15)], .014, white, 8)
	for y: float in [.7, .62, .54]:
		_kit.tube("plain", [t * Vector3(.7, y, -.18), t * Vector3(.7, y, .18)], .009, white, 6)
	_kit.tube("plain", [t * Vector3(.6, .75, -.14), t * Vector3(.6, .75, .14)], .009, white, 6)
	# Rack, box and rear lamp.
	_bar("metal", t, -.64, .88, 0, Vector3(.54, .025, .36), Color("#3a3c3e"))
	var box := Color("#f2f2ea")
	_bar("plain", t, -.66, 1.05, 0, Vector3(.56, .3, .46), box, .9, 1.0)
	_bar("plain", t, -.66, 1.215, 0, Vector3(.58, .05, .48), box, 1.0, 1.0)
	_bar("metal", t, -.37, 1.1, 0, Vector3(.03, .08, .08), chrome)
	var cell := _cell(1450, 980, 300, 90)
	_panel("label", t, -.88, -.44, .94, 1.14, .232, cell)
	var other := Transform3D(t.basis * Basis(Vector3.UP, PI), t.origin)
	_panel("label", other, .44, .88, .94, 1.14, .232, cell)
	var rear := Transform3D(t.basis * Basis(Vector3.UP, PI * .5), t * Vector3(-.942, 0, 0))
	_panel("label", rear, -.21, .21, .94, 1.14, 0, cell)
	_bar("plain", t, -.72, .74, 0, Vector3(.06, .1, .2), Color("#d8d8d0"))
	_bar("led", t, -.752, .75, 0, Vector3(.012, .07, .16), Color(.6, .02, .02))
	_bar("plain", t, -.72, .63, 0, Vector3(.02, .12, .17), Color("#f2f2ea"))
