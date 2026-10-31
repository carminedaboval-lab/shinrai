extends "res://scripts/midori_near_city_handmade.gd"
## 餃子のみどり: a two-storey shop clad in corrugated tin, a century old by 2050 and
## left standing while the block grew up around it, now wired into the city it outlived. Modelled by hand, part by part. Local origin is the
## middle of its street front at pavement level, facing +Z.
const ATLAS := "res://assets/shinrai/near_city/gyoza_atlas.png"
const WIDE := 5.8
const DEEP := 9.5
const WALL := 6.0 # Height of the wall plate.
const SHOP_TOP := 3.3
const PITCH := .45
const EAVE := .55
const VERGE := .32
const SHEET := Vector2(.82, 1.82)
const TILE := Vector2(.265, .235)
const WAVE := 5
const STAIN := Color("#5a3d29") # Dark stain over the cedar's natural orange.
const GUTTER := Color("#b4a486")
const LIGHT_DAY := Color(1.0, .86, .68)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1973
	_build_looks()
	_walls()
	_shopfront()
	_interior()
	_awning()
	_fascia_sign()
	_upper_floor()
	_roof()
	_east_side()
	_street_things()
	_retrofit()
	_kit.commit(self, _looks, ["front", "cloth", "lamp", "leaf", "neon", "led"])
	_kit = null
	_build_lights()

func _build_looks() -> void:
	_shared_looks()
	_looks.tin = _look("worn_corrugated_iron", 1.8, 1.0)
	_looks.rust = _look("rusty_corrugated_iron", 2.0, 1.0)
	_looks.cedar = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.cedar.set_shader_parameter("chroma", .42)
	_looks.paint = _look("rusty_painted_metal", 2.2, 1.0)
	_looks.kawara = _look("", 1.0, .36, .3)
	_looks.tile = _look("", 1.0, .24)
	_looks.room = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.room.set_shader_parameter("glow", .3)
	_looks.room.set_shader_parameter("day_glow", .05)
	_looks.room.set_shader_parameter("chroma", .6)
	var signs: Texture2D = load(ATLAS)
	_looks.cloth = _look("", 1.0, .9)
	_looks.cloth.set_shader_parameter("albedo_map", signs)
	_looks.sign = _look("", 1.0, .4)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .6)
	_looks.room_sign = _look("", 1.0, .8)
	_looks.room_sign.set_shader_parameter("albedo_map", signs)
	_looks.room_sign.set_shader_parameter("glow", .4)
	_looks.room_sign.set_shader_parameter("day_glow", .14)
	_looks.display = _look("", 1.0, .3)
	_looks.display.set_shader_parameter("albedo_map", signs)
	_looks.display.set_shader_parameter("glow", .8)
	_looks.display.set_shader_parameter("day_glow", .5)

func _wall_top(_x: float) -> float:
	return WALL

func _gable_top(x: float) -> float:
	return WALL + (DEEP * .5 - absf(x - DEEP * .5)) * PITCH

func _sheets(face: Transform3D, length: float, from_y: float, top: Callable, holes: Array[Rect2]) -> void:
	# Tin laid in sheets: each laps the last, and the odd rusted repair shows through.
	var x := 0.0
	var column := 0
	while x < length - .02:
		var wide := minf(SHEET.x, length - x)
		var left: float = top.call(x)
		var right: float = top.call(x + wide)
		var y := from_y
		var course := 0
		while y < maxf(left, right) - .02:
			var part := "tin" if _rng.randf() < .8 else "rust"
			var tint: Color = Color(1.25, 1.2, 1.15) if part == "rust" else [Color(1, 1, 1), Color(1, .95, .86), Color(.9, .95, 1.0)][_rng.randi_range(0, 2)]
			var lap := .014 * float((column + course) % 2)
			var uv := Vector2(_rng.randf() * 4.0, _rng.randf() * 4.0)
			var end := y + SHEET.y
			if end >= minf(left, right) and left != right:
				_kit.quad(part, face * Vector3(x, y, lap), face * Vector3(x, left, lap), face * Vector3(x + wide, right, lap), face * Vector3(x + wide, y, lap), tint, _wall_shade(y, WALL + 2.0), .6, .7, uv)
				break
			for piece: Rect2 in _minus(Rect2(x, y, wide, minf(end, left) - y), holes):
				var bottom := piece.position.y
				var head := piece.end.y
				var at := uv + Vector2(piece.position.x - x, y - bottom)
				_kit.quad(part, face * Vector3(piece.position.x, bottom, lap), face * Vector3(piece.position.x, head, lap), face * Vector3(piece.end.x, head, lap), face * Vector3(piece.end.x, bottom, lap), tint, _wall_shade(bottom, left), _wall_shade(head, left), .7, at)
			y = end
			course += 1
		x += wide
		column += 1

func _wall_shade(y: float, top: float) -> float:
	return 1.0 - .5 * smoothstep(top - 1.1, top, y) - .14 * (1.0 - smoothstep(0.0, .5, y))

func _walls() -> void:
	var upper_holes: Array[Rect2] = [Rect2(.6, 4.3, 2.4, 1.15), Rect2(3.8, 4.5, 1.0, .9)]
	var east_holes: Array[Rect2] = [Rect2(1.7, 1.25, 1.0, .85), Rect2(3.6, 4.1, 1.6, 1.0)]
	var none: Array[Rect2] = []
	_sheets(_front, WIDE, SHOP_TOP, _wall_top, upper_holes)
	_sheets(_east, DEEP, .24, _gable_top, east_holes)
	_sheets(_west, DEEP, .24, _gable_top, none)
	_sheets(_back, WIDE, .24, _wall_top, none)
	var trim := STEEL.lightened(.1)
	# Concrete footing, angle flashings on the corners, and a drip strip over the shop.
	var footing := Color("#7d7a72")
	_bar("plain", _east, DEEP * .5, .13, -.02, Vector3(DEEP, .26, .08), footing, .7, 1.0)
	_bar("plain", _west, DEEP * .5, .13, -.02, Vector3(DEEP, .26, .08), footing, .7, 1.0)
	_bar("plain", _back, WIDE * .5, .13, -.02, Vector3(WIDE, .26, .08), footing, .7, 1.0)
	for corner: Vector3 in [Vector3(-WIDE * .5, 0, 0), Vector3(WIDE * .5, 0, 0)]:
		_kit.block("paint", Transform3D(Basis.IDENTITY, corner + Vector3(0, WALL * .5 + 1.65, 0)), Vector3(.1, WALL - 3.3, .1), trim, 1.0, .6, .5)
		_kit.block("paint", Transform3D(Basis.IDENTITY, corner + Vector3(0, 1.65, -.05)), Vector3(.1, 3.3, .1), trim, .8, 1.0, .4)
	_bar("metal", _front, WIDE * .5, SHOP_TOP + .02, .05, Vector3(WIDE + .08, .04, .12), STEEL)

func _shopfront() -> void:
	var f := _front
	var stain := STAIN
	var post := Vector3(.14, SHOP_TOP, .16)
	var dark := stain.darkened(.25)
	# Posts and head beam.
	for x: float in [.07, 3.61, WIDE - .07]:
		_bar("cedar", f, x, SHOP_TOP * .5, 0.0, post, stain, .7, .6)
	_bar("cedar", f, WIDE * .5, 2.86, 0.0, Vector3(WIDE, .16, .14), stain, .7, .7)
	# Boarding over the doors and the kitchen wall above the takeaway window.
	_kit.quad("cedar", f * Vector3(.14, 2.94, -.03), f * Vector3(.14, SHOP_TOP, -.03), f * Vector3(WIDE - .14, SHOP_TOP, -.03), f * Vector3(WIDE - .14, 2.94, -.03), dark, .5, .4, .4)
	_kit.quad("cedar", f * Vector3(.14, 2.4, -.05), f * Vector3(.14, 2.78, -.05), f * Vector3(3.54, 2.78, -.05), f * Vector3(3.54, 2.4, -.05), dark, .55, .45, .4)
	_kit.quad("cedar", f * Vector3(3.68, 2.25, -.05), f * Vector3(3.68, 2.78, -.05), f * Vector3(WIDE - .14, 2.78, -.05), f * Vector3(WIDE - .14, 2.25, -.05), dark, .55, .45, .4)
	# Threshold.
	_bar("plain", f, 1.84, .05, .1, Vector3(3.44, .1, .34), Color("#6f6d68"), .8, 1.0)
	_bar("metal", f, 1.84, .112, -.04, Vector3(3.4, .024, .1), Color("#8d7a55"))
	# Four sliding door leaves: two tracks, a kick board and a glazing bar on each.
	var leaf := 3.4 / 4.0
	for i: int in range(4):
		var x0 := .14 + leaf * float(i)
		var z := -.03 if i % 2 == 1 else -.09
		var middle := x0 + leaf * .5
		_bar("cedar", f, x0 + .03, 1.26, z, Vector3(.06, 2.28, .04), stain)
		_bar("cedar", f, x0 + leaf - .03, 1.26, z, Vector3(.06, 2.28, .04), stain)
		_bar("cedar", f, middle, 2.37, z, Vector3(leaf, .06, .04), stain)
		_bar("cedar", f, middle, .29, z, Vector3(leaf, .36, .03), stain.darkened(.1), .7, 1.0)
		_bar("cedar", f, middle, .49, z, Vector3(leaf, .05, .04), stain)
		_bar("cedar", f, middle, 1.42, z, Vector3(leaf, .025, .03), stain)
	_kit.quad("front", f * Vector3(.14, .47, -.06), f * Vector3(.14, 2.36, -.06), f * Vector3(3.54, 2.36, -.06), f * Vector3(3.54, .47, -.06), Color.WHITE)
	_bar("metal", f, 1.84, 2.4, -.02, Vector3(3.4, .03, .12), Color("#6a6a68"))
	# Glazed brown tile dado under the takeaway window, each tile its own.
	var dado := Rect2(3.68, .02, WIDE - .14 - 3.68, .93)
	_kit.quad("plain", f * Vector3(dado.position.x, dado.position.y, -.03), f * Vector3(dado.position.x, dado.end.y, -.03), f * Vector3(dado.end.x, dado.end.y, -.03), f * Vector3(dado.end.x, dado.position.y, -.03), Color("#7c7870"), .6, .7)
	var size := .108
	for row: int in range(int(dado.size.y / size)):
		for column: int in range(int(dado.size.x / size)):
			var shade := _rng.randf_range(.82, 1.12)
			var glaze := Color(.42 * shade, .25 * shade, .16 * shade)
			if _rng.randf() < .05: glaze = glaze.lightened(.14)
			var x := dado.position.x + .006 + size * float(column)
			var y := dado.position.y + .006 + size * float(row)
			var bow := _rng.randf_range(-.0015, .0015)
			_kit.quad("tile", f * Vector3(x, y, -.022 + bow), f * Vector3(x, y + size - .01, -.022), f * Vector3(x + size - .01, y + size - .01, -.022 + bow), f * Vector3(x + size - .01, y, -.022), glaze)
	# Takeaway window with a steel shelf, and a paper notice taped inside the glass.
	_window(f, Rect2(3.74, .98, 1.86, 1.25), .86, false)
	_bar("metal", f, 4.67, .98, .13, Vector3(1.95, .025, .3), Color("#a9a8a2"))
	for x: float in [3.95, 5.4]:
		_kit.beam("metal", f * Vector3(x, .78, 0.0), f * Vector3(x, .97, .24), .02, .02, Vector3.BACK, Color("#6f6f6c"))
	_kit.atlas("display", f * Vector3(3.92, 1.3, -.04), f * Vector3(3.92, 1.74, -.04), f * Vector3(4.8, 1.74, -.04), f * Vector3(4.8, 1.3, -.04), _cell(0, 1024, 400, 200))
	_noren()
	# Drinks poster on the post, gone pale in the sun.
	_kit.atlas("cloth", f * Vector3(3.76, 2.3, .005), f * Vector3(3.76, 2.76, .005), f * Vector3(4.09, 2.76, .005), f * Vector3(4.09, 2.3, .005), _cell(408, 1024, 300, 420), Color(.92, .9, .84), .8)

func _noren() -> void:
	# Three indigo panels on a pole, stirring slightly.
	var f := _front
	_kit.tube("metal", [f * Vector3(.42, 2.3, .14), f * Vector3(3.26, 2.3, .14)], .016, Color("#2a241d"))
	for hook: float in [.5, 3.18]:
		_bar("metal", f, hook, 2.34, .07, Vector3(.02, .1, .15), Color("#2a241d"))
	for i: int in range(3):
		var x0 := .44 + float(i) * .95
		var rect := _cell(float(i) * 320.0 + 6.0, 632, 308, 380)
		var rows := 4
		var columns := 6
		for row: int in range(rows):
			var v0 := float(row) / float(rows)
			var v1 := float(row + 1) / float(rows)
			for column: int in range(columns):
				var u0 := float(column) / float(columns)
				var u1 := float(column + 1) / float(columns)
				var at := func(u: float, v: float) -> Vector3:
					return f * Vector3(x0 + u * .92, 2.3 - v * .74, .14 + sin(u * 11.0 + float(i) * 2.0) * .012 * (1.0 + v) + sin(v * 3.0) * .02 * v)
				var patch := Rect2(rect.position + Vector2(u0, v0) * rect.size, Vector2(u1 - u0, v1 - v0) * rect.size)
				_kit.atlas("cloth", at.call(u0, v1), at.call(u0, v0), at.call(u1, v0), at.call(u1, v1), patch, Color.WHITE, 1.0, .25)
				_kit.atlas("cloth", at.call(u1, v1), at.call(u1, v0), at.call(u0, v0), at.call(u0, v1), patch, Color(.5, .5, .5), .7)

func _hood(face: Transform3D, x0: float, x1: float, y: float, reach: float) -> void:
	# Bent sheet canopy over a window, on two thin brackets.
	var tint := Color("#54585a")
	var a := face * Vector3(x0, y, reach)
	var b := face * Vector3(x0, y + .16, 0)
	var c := face * Vector3(x1, y + .16, 0)
	var d := face * Vector3(x1, y, reach)
	_kit.quad("paint", a, b, c, d, tint, .9, 1.0, .5)
	_kit.quad("plain", b, a, d, c, tint.darkened(.4), .5, .5)
	_bar("metal", face, (x0 + x1) * .5, y - .02, reach, Vector3(x1 - x0, .05, .012), tint)
	for x: float in [x0 + .12, x1 - .12]:
		_kit.beam("metal", face * Vector3(x, y - .22, 0.0), face * Vector3(x, y - .01, reach - .03), .02, .02, face.basis.z, tint.darkened(.2))

func _interior() -> void:
	# A real room behind the door glass: wood walls, a counter, stools and paper menus.
	var f := _front
	var wall := Color(.58, .42, .3)
	var deep := 4.2
	var bay := Rect2(.14, 0, 3.4, 2.5)
	_kit.quad("room", f * Vector3(bay.position.x, 0, -deep), f * Vector3(bay.position.x, bay.end.y, -deep), f * Vector3(bay.end.x, bay.end.y, -deep), f * Vector3(bay.end.x, 0, -deep), wall, .6, .8)
	_kit.quad("room", f * Vector3(bay.position.x, 0, 0), f * Vector3(bay.position.x, bay.end.y, 0), f * Vector3(bay.position.x, bay.end.y, -deep), f * Vector3(bay.position.x, 0, -deep), wall * .9, .6, .8)
	_kit.quad("room", f * Vector3(bay.end.x, 0, -deep), f * Vector3(bay.end.x, bay.end.y, -deep), f * Vector3(bay.end.x, bay.end.y, 0), f * Vector3(bay.end.x, 0, 0), wall * .9, .6, .8)
	_kit.quad("room", f * Vector3(bay.position.x, 0.02, 0), f * Vector3(bay.position.x, 0.02, -deep), f * Vector3(bay.end.x, 0.02, -deep), f * Vector3(bay.end.x, 0.02, 0), Color(.3, .27, .24), .7, .7)
	_kit.quad("room", f * Vector3(bay.position.x, bay.end.y, -deep), f * Vector3(bay.position.x, bay.end.y, 0), f * Vector3(bay.end.x, bay.end.y, 0), f * Vector3(bay.end.x, bay.end.y, -deep), Color(.7, .64, .52), .8, .8)
	# Counter along the kitchen side, with a shelf of bottles behind it.
	var counter := Color(.5, .36, .24)
	_bar("room", f, 2.95, .95, -2.5, Vector3(.08, 1.9, 2.9), counter)
	_bar("room", f, 2.5, .5, -2.5, Vector3(.08, 1.0, 2.9), counter * .8)
	_bar("room", f, 2.62, 1.03, -2.5, Vector3(.58, .05, 3.0), Color(.74, .56, .36))
	_bar("room", f, 3.4, 1.72, -2.5, Vector3(.24, .03, 2.8), counter)
	for i: int in range(9):
		var z := -1.3 - float(i) * .29
		var tint: Color = [Color("#3c5a3a"), Color("#6b3b1e"), Color("#b9ac8c")][i % 3]
		_kit.lathe("room", f * Vector3(3.4, 1.735, z), [Vector2(.04, 0), Vector2(.04, .2), Vector2(.015, .28), Vector2(.015, .33)], tint, 6)
	for i: int in range(4):
		var z := -1.35 - float(i) * .72
		_kit.lathe("room", f * Vector3(2.12, 0, z), [Vector2(.14, .02), Vector2(.03, .04), Vector2(.03, .62), Vector2(.17, .66), Vector2(.16, .72), Vector2(0, .73)], Color(.62, .2, .16), 8)
	# Paper menu strips along the back wall, and lamps over the counter.
	_kit.atlas("room_sign", f * Vector3(.3, 1.3, -deep + .02), f * Vector3(.3, 2.2, -deep + .02), f * Vector3(2.5, 2.2, -deep + .02), f * Vector3(2.5, 1.3, -deep + .02), _cell(1488, 628, 560, 388))
	for z: float in [-1.4, -2.5, -3.6]:
		_kit.tube("plain", [f * Vector3(2.3, 2.5, z), f * Vector3(2.3, 1.98, z)], .006, Color("#1a1a1a"), 4)
		_kit.lathe("lamp", f * Vector3(2.3, 1.74, z), [Vector2(.18, 0), Vector2(.16, .05), Vector2(.05, .24)], Color(1.0, .78, .5), 10)

func _awning() -> void:
	# Canvas テント on a steel frame, its slope and valance signwritten by hand.
	var f := _front
	var x0 := .06
	var x1 := WIDE - .06
	var low := 2.58
	var high := 3.22
	var reach := 1.08
	var drop := .23
	_kit.atlas("cloth", f * Vector3(x0, low, reach), f * Vector3(x0, high, 0), f * Vector3(x1, high, 0), f * Vector3(x1, low, reach), _cell(0, 216, 1536, 336), Color(.96, .94, .9), 1.0, .55)
	_kit.quad("cloth", f * Vector3(x0, high, 0), f * Vector3(x0, low, reach), f * Vector3(x1, low, reach), f * Vector3(x1, high, 0), Color(.0, .0, .0), .4, .4)
	_kit.atlas("cloth", f * Vector3(x0, low - drop, reach), f * Vector3(x0, low, reach), f * Vector3(x1, low, reach), f * Vector3(x1, low - drop, reach), _cell(0, 560, 1536, 60), Color(.96, .94, .9), 1.0, .4)
	_kit.atlas("cloth", f * Vector3(x1, low - drop, reach), f * Vector3(x1, low, reach), f * Vector3(x0, low, reach), f * Vector3(x0, low - drop, reach), _cell(0, 560, 40, 60), Color(.3, .1, .08), .6)
	var red := Color(.56, .13, .11)
	for side: float in [x0, x1]:
		var near := f * Vector3(side, high, 0)
		var far := f * Vector3(side, low, reach)
		var under := f * Vector3(side, low - drop, reach)
		var wall := f * Vector3(side, low - drop, 0)
		if side > 1.0: _kit.quad("cloth", under, far, near, wall, red, .9, .9)
		else: _kit.quad("cloth", wall, near, far, under, red, .9, .9)
		if side > 1.0: _kit.quad("cloth", wall, near, far, under, red.darkened(.5), .6, .6)
		else: _kit.quad("cloth", under, far, near, wall, red.darkened(.5), .6, .6)
	var frame := Color("#2c2d2e")
	_kit.tube("metal", [f * Vector3(x0, low - .02, reach - .02), f * Vector3(x1, low - .02, reach - .02)], .018, frame, 5)
	_kit.tube("metal", [f * Vector3(x0, low - drop + .02, reach - .02), f * Vector3(x1, low - drop + .02, reach - .02)], .012, frame, 5)
	for x: float in [x0 + .02, 1.5, 2.9, 4.3, x1 - .02]:
		_kit.tube("metal", [f * Vector3(x, high - .03, .02), f * Vector3(x, low - .03, reach - .03)], .014, frame, 5)
		_kit.tube("metal", [f * Vector3(x, low - .35, .02), f * Vector3(x, low - .03, reach * .62)], .011, frame, 5)

func _fascia_sign() -> void:
	# Painted board on the wall above the awning, under three swan-neck lamps.
	var f := _front
	var frame := Color("#3a1414")
	_bar("metal", f, WIDE * .5, 3.72, .1, Vector3(5.3, .72, .14), frame, .8, 1.0)
	_kit.atlas("sign", f * Vector3(.3, 3.38, .172), f * Vector3(.3, 4.06, .172), f * Vector3(5.5, 4.06, .172), f * Vector3(5.5, 3.38, .172), _cell(0, 0, 1536, 208), Color.WHITE, 1.0, .75)
	for x: float in [1.0, 2.9, 4.8]:
		var points: Array[Vector3] = [f * Vector3(x, 4.08, .1), f * Vector3(x, 4.3, .12), f * Vector3(x, 4.42, .26), f * Vector3(x, 4.42, .44)]
		_kit.tube("metal", points, .011, frame, 5)
		_kit.lathe("metal", f * Vector3(x, 4.3, .48), [Vector2(.11, 0), Vector2(.09, .06), Vector2(.03, .12)], Color("#2a2b2c"), 8)
		_kit.lathe("lamp", f * Vector3(x, 4.3, .48), [Vector2(0, .005), Vector2(.09, .01)], Color(1, .86, .62), 8)

func _upper_floor() -> void:
	var f := _front
	_window(f, Rect2(.6, 4.3, 2.4, 1.15), .28, false)
	_window(f, Rect2(3.8, 4.5, 1.0, .9), .63, true)
	_hood(f, .46, 3.14, 5.56, .46)
	_hood(f, 3.66, 4.94, 5.5, .34)
	_hood(_east, 3.46, 5.34, 5.2, .36)
	_window(_east, Rect2(3.6, 4.1, 1.6, 1.0), .52, false)
	# Flower rail: bent steel on two brackets, with a row of old pots.
	var rail := Color("#39403f")
	for y: float in [4.3, 4.72]:
		_kit.tube("metal", [f * Vector3(.5, y, .08), f * Vector3(.5, y, .3), f * Vector3(3.1, y, .3), f * Vector3(3.1, y, .08)], .012, rail, 5)
	var at := .6
	while at < 3.04:
		_bar("metal", f, at, 4.5, .3, Vector3(.012, .42, .012), rail)
		at += .135
	_bar("metal", f, 1.8, 4.2, .19, Vector3(2.5, .03, .24), rail.darkened(.2))
	for x: float in [.85, 1.32, 1.95, 2.6]:
		_kit.lathe("plain", f * Vector3(x, 4.215, .19), [Vector2(.07, 0), Vector2(.1, .17), Vector2(.11, .18)], Color("#8a5a3e"), 8)
		_plant(f * Vector3(x, 4.39, .19), .3, Color("#3f6133"))
	# Drying pole on two brackets, towels left out.
	_kit.tube("metal", [f * Vector3(.5, 5.22, .36), f * Vector3(3.1, 5.22, .36)], .012, Color("#b8bab6"), 5)
	for x: float in [.62, 2.98]:
		_kit.beam("metal", f * Vector3(x, 5.3, 0.0), f * Vector3(x, 5.2, .4), .02, .02, Vector3.UP, rail)
	for row: Array in [[1.0, Color("#b9b3a6"), .55], [1.46, Color("#6f8799"), .46], [2.5, Color("#c9bfae"), .5]]:
		_towel(row[0], .36, row[2], row[1])
	# Feed from the eaves to the sign, clipped to the tin.
	_kit.tube("plain", [f * Vector3(5.2, 5.9, .05), f * Vector3(5.2, 4.1, .05), f * Vector3(5.0, 4.08, .1)], .012, Color("#1f2022"), 5)
	_bar("metal", f, 5.2, 4.78, .05, Vector3(.13, .17, .08), Color("#77796f"))

func _towel(x: float, wide: float, drop: float, tint: Color) -> void:
	# Cloth over the pole, hanging in soft folds.
	var f := _front
	var folds := 6
	for i: int in range(folds):
		var x0 := x + wide * float(i) / float(folds)
		var x1 := x + wide * float(i + 1) / float(folds)
		var z0 := .37 + sin(float(i) * 2.1) * .012
		var z1 := .37 + sin(float(i + 1) * 2.1) * .012
		var shade := .86 + .14 * sin(float(i) * 2.1 + 1.0)
		var tone := tint * shade
		_kit.quad("plain", f * Vector3(x0, 5.22 - drop - float(i % 2) * .012, z0), f * Vector3(x0, 5.23, z0), f * Vector3(x1, 5.23, z1), f * Vector3(x1, 5.22 - drop - float((i + 1) % 2) * .012, z1), tone, .85, 1.0)
		_kit.quad("plain", f * Vector3(x1, 5.22 - drop, .35), f * Vector3(x1, 5.23, .35), f * Vector3(x0, 5.23, .35), f * Vector3(x0, 5.22 - drop, .35), tone, .7, .8)

func _roof() -> void:
	var up_slope := Vector3(0, PITCH, -1).normalized()
	var length := (DEEP * .5 + EAVE) * sqrt(1.0 + PITCH * PITCH)
	var normal := Vector3.RIGHT.cross(up_slope)
	var foot := Vector3(0, WALL - EAVE * PITCH, EAVE)
	var slope := Transform3D(Basis(Vector3.RIGHT, up_slope, normal), foot)
	var turned := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -DEEP))
	for side: Transform3D in [slope, turned * slope]:
		_tiles(side, length)
	for side: Transform3D in [Transform3D.IDENTITY, turned]:
		_eaves(side)
	_ridge()
	for x: float in [-1.0, 1.0]:
		_verge(x)
	_antenna()

func _tiles(slope: Transform3D, length: float) -> void:
	var half := WIDE * .5 + VERGE
	var columns := int(half * 2.0 / TILE.x)
	var rows := int(length / TILE.y)
	_kit.quad("plain", slope * Vector3(-half, 0, -.03), slope * Vector3(-half, length, -.03), slope * Vector3(half, length, -.03), slope * Vector3(half, 0, -.03), Color(.08, .08, .08))
	for row: int in range(rows):
		for column: int in range(columns):
			var shade := _rng.randf_range(.82, 1.1)
			var tint := Color(.34 * shade, .36 * shade, .39 * shade)
			# Slipped and replaced tiles, and moss low on the slope.
			if _rng.randf() < .03: tint = tint.lightened(.16)
			if row < 4 and _rng.randf() < .06: tint = tint.lerp(Color(.28, .31, .17), .5)
			var x := -half + TILE.x * float(column) + _rng.randf_range(-.003, .003)
			_tile(slope, x, TILE.y * float(row), tint, row == 0)

func _wave_height(u: float) -> float:
	return .024 * sin(TAU * u)

func _wave_lean(u: float) -> float:
	return .024 * TAU / TILE.x * cos(TAU * u)

func _tile(slope: Transform3D, x: float, s: float, tint: Color, first: bool) -> void:
	# One S-curved 桟瓦: the butt stands proud of the course below.
	var lift := .03 + _rng.randf() * .006
	var over := TILE.y + .05
	var down := -slope.basis.y
	var skirt := .055 if first else 0.0
	for k: int in range(WAVE):
		var u0 := float(k) / float(WAVE)
		var u1 := float(k + 1) / float(WAVE)
		var h0 := _wave_height(u0)
		var h1 := _wave_height(u1)
		var n0 := slope.basis * Vector3(-_wave_lean(u0), 0, 1).normalized()
		var n1 := slope.basis * Vector3(-_wave_lean(u1), 0, 1).normalized()
		var x0 := x + u0 * TILE.x
		var x1 := x + u1 * TILE.x
		var a := slope * Vector3(x0, s, h0 + lift)
		var b := slope * Vector3(x0, s + over, h0)
		var c := slope * Vector3(x1, s + over, h1)
		var d := slope * Vector3(x1, s, h1 + lift)
		_kit.smooth("kawara", a, b, c, d, n0, n0, n1, n1, tint)
		var e := slope * Vector3(x0, s, h0 - skirt)
		var g := slope * Vector3(x1, s, h1 - skirt)
		_kit.smooth("kawara", e, a, d, g, down, down, down, down, tint, .42)

func _eaves(xf: Transform3D) -> void:
	# Boarded soffit, rafter ends, fascia and the gutter along the low edge.
	var half := WIDE * .5 + VERGE
	var y := WALL - EAVE * PITCH
	var stain := STAIN.darkened(.2)
	_kit.quad("cedar", xf * Vector3(-half, WALL, 0), xf * Vector3(-half, y, EAVE), xf * Vector3(half, y, EAVE), xf * Vector3(half, WALL, 0), stain, .5, .55, 0.0)
	var x := -half + .1
	while x < half:
		_kit.beam("cedar", xf * Vector3(x, WALL - .06, 0), xf * Vector3(x, y - .06, EAVE), .055, .09, Vector3(0, 1, PITCH), stain, .6)
		x += .455
	_kit.block("paint", Transform3D(xf.basis, xf * Vector3(0, y - .07, EAVE + .01)), Vector3(half * 2.0, .17, .03), Color("#5a5d5c"), .9, 1.0, .5)
	_kit.tube("metal", [xf * Vector3(-half - .02, y - .08, EAVE + .1), xf * Vector3(half + .02, y - .1, EAVE + .1)], .058, GUTTER, 7, .95)
	x = -half + .4
	while x < half:
		_kit.block("metal", Transform3D(xf.basis, xf * Vector3(x, y - .03, EAVE + .1)), Vector3(.03, .01, .16), STEEL)
		x += .9

func _ridge() -> void:
	# Stacked のし瓦 under a round cap, finished with a 鬼瓦 at each end.
	var y := WALL + DEEP * .5 * PITCH
	var z := -DEEP * .5
	var half := WIDE * .5 + VERGE
	var tone := Color(.3, .32, .35)
	for layer: int in range(4):
		var deep := .34 - float(layer) * .04
		var x := -half
		while x < half - .01:
			var run := minf(.42, half - x)
			var shade := _rng.randf_range(.86, 1.08)
			_kit.block("kawara", Transform3D(Basis.IDENTITY, Vector3(x + run * .5, y + .02 + float(layer) * .058, z + _rng.randf_range(-.004, .004))), Vector3(run - .006, .052, deep), tone * shade, .6, 1.0)
			x += run
	var top := y + .28
	_kit.tube("kawara", [Vector3(-half, top, z), Vector3(half, top, z)], .09, tone, 9)
	var cap := -half
	while cap < half:
		_kit.tube("kawara", [Vector3(cap, top, z), Vector3(cap + .03, top, z)], .1, tone * .9, 9)
		cap += .3
	for side: float in [-1.0, 1.0]:
		var end := Vector3(side * (half + .03), y + .24, z)
		_kit.block("kawara", Transform3D(Basis.IDENTITY, end), Vector3(.1, .54, .44), tone * .95, .8, 1.0)
		_kit.block("kawara", Transform3D(Basis.IDENTITY, end + Vector3(side * .04, .1, 0)), Vector3(.08, .22, .24), tone * 1.1, .8, 1.0)

func _verge(side: float) -> void:
	# Barge boards up the gable, and a run of edge tiles over them.
	var x := side * (WIDE * .5 + VERGE)
	var foot_y := WALL - EAVE * PITCH
	var peak := WALL + DEEP * .5 * PITCH
	for end: float in [EAVE, -DEEP - EAVE]:
		var from := Vector3(x, foot_y - .1, end)
		var to := Vector3(x, peak - .1, -DEEP * .5)
		_kit.beam("cedar", from, to, .04, .24, Vector3(0, 1, 0), STAIN.darkened(.2), .8)
		var edge_from := Vector3(x - side * .02, foot_y + .1, end)
		var edge_to := Vector3(x - side * .02, peak + .1, -DEEP * .5)
		_kit.beam("kawara", edge_from, edge_to, .16, .1, Vector3(0, 1, 0), Color(.3, .32, .35))

func _antenna() -> void:
	# Old terrestrial aerial still bolted to the ridge, with its guy wires.
	var foot := Vector3(1.4, WALL + DEEP * .5 * PITCH + .3, -DEEP * .5)
	var top := foot + Vector3.UP * 2.6
	var steel := Color("#8d9092")
	_kit.tube("metal", [foot, top], .022, steel, 5)
	var boom := top - Vector3.UP * .2
	_kit.block("metal", Transform3D(Basis.IDENTITY, boom), Vector3(1.8, .022, .022), steel)
	for i: int in range(9):
		var wide := .66 - float(i) * .035
		_kit.block("metal", Transform3D(Basis.IDENTITY, boom + Vector3(-.82 + float(i) * .2, 0, 0)), Vector3(.012, .012, wide), steel)
	for corner: Vector3 in [Vector3(1.5, 0, 1.2), Vector3(-1.5, 0, 1.2), Vector3(0, 0, -1.3)]:
		_kit.tube("plain", [foot + Vector3.UP * 1.7, foot + corner + Vector3.DOWN * .4], .004, Color("#2b2b2b"), 3)

func _retrofit() -> void:
	# A century on: solar on the old tiles, neon round the old board, fibre on the old tin.
	var f := _front
	var up_slope := Vector3(0, PITCH, -1).normalized()
	var slope := Transform3D(Basis(Vector3.RIGHT, up_slope, Vector3.RIGHT.cross(up_slope)), Vector3(0, WALL - EAVE * PITCH, EAVE))
	for row: int in range(2):
		for column: int in range(4):
			_solar_module(slope.translated_local(Vector3(-1.56 + float(column) * 1.04, 1.5 + float(row) * 1.72, .11)), 1.0, 1.68)
	var tube := Color(1.0, .28, .16)
	_neon([f * Vector3(.3, 3.38, .2), f * Vector3(.3, 4.06, .2), f * Vector3(5.5, 4.06, .2), f * Vector3(5.5, 3.38, .2), f * Vector3(.3, 3.38, .2)], tube)
	_fibre([f * Vector3(5.46, 5.68, .06), f * Vector3(5.46, 4.2, .06), f * Vector3(5.6, 2.84, .09), f * Vector3(5.6, .3, .09)])
	_camera(f * Vector3(3.6, 2.5, .1))
	# Card and palm reader on the door post.
	_bar("bottle", f, 3.61, 1.3, .09, Vector3(.1, .22, .02), Color("#0b0c0e"))
	_status(f, 3.61, 1.36, .102, CYAN)
	# The roof keeps its old aerial, with a 6G panel clamped on above it.
	var mast := Vector3(1.4, WALL + DEEP * .5 * PITCH + 2.9, -DEEP * .5)
	_kit.block("plain", Transform3D(Basis.IDENTITY, mast + Vector3(0, 0, .1)), Vector3(.3, .7, .1), Color("#dfe0db"), .9, 1.0)
	# Smart meter over the old one, in the alley.
	_bar("bottle", _east, .78, 1.68, .05, Vector3(.24, .14, .02), Color("#0b0c0e"))
	_status(_east, .72, 1.68, .062, GREEN)

func _east_side() -> void:
	var e := _east
	_window(e, Rect2(1.7, 1.25, 1.0, .85), .71, true)
	# Extract fan through the kitchen wall, its hood black with years of grease.
	var soot := Color("#2a2622")
	_bar("paint", e, 3.9, 2.35, .13, Vector3(.62, .62, .26), soot, .9, 1.0)
	_kit.quad("paint", e * Vector3(3.56, 2.1, .32), e * Vector3(3.56, 2.72, .28), e * Vector3(4.24, 2.72, .28), e * Vector3(4.24, 2.1, .32), soot.darkened(.3), .8, 1.0, 1.0)
	_kit.tube("metal", [e * Vector3(3.3, 2.7, .08), e * Vector3(3.3, 5.9, .08)], .05, Color("#55524c"), 7)
	_kit.tube("metal", [e * Vector3(3.3, 2.7, .08), e * Vector3(3.56, 2.5, .12)], .05, Color("#55524c"), 7)
	# Electricity meter, board and conduit up to the service drop at the eaves.
	_bar("cedar", e, .78, 1.95, .03, Vector3(.34, .5, .03), STAIN, .9, 1.0)
	_kit.lathe("metal", e * Vector3(.78, 1.95, .05), [Vector2(.1, 0), Vector2(.1, .1), Vector2(.08, .13)], Color("#b0b3ad"), 10)
	_kit.tube("plain", [e * Vector3(.78, 2.2, .05), e * Vector3(.78, 5.85, .05)], .016, Color("#35373a"), 5)
	# Household fuel cell where the gas bottles used to stand, its pipe still in the old copper.
	_bar("metal", e, 1.2, .72, .24, Vector3(.82, 1.44, .42), Color("#d6d6cf"), .8, 1.0)
	_bar("plain", e, 1.2, 1.1, .452, Vector3(.5, .26, .006), Color("#14161a"))
	_status(e, 1.0, 1.1, .46, GREEN)
	_status(e, 1.08, 1.1, .46, GREEN)
	_status(e, 1.16, 1.1, .46, AMBER)
	_kit.tube("metal", [e * Vector3(1.18, 1.44, .1), e * Vector3(1.18, 1.62, .05), e * Vector3(1.6, 1.64, .05), e * Vector3(1.6, 2.8, .05)], .011, Color("#b27a3a"), 5)
	# Outdoor unit standing on blocks, and water pipes along the footing.
	var unit := Vector3(5.9, .48, .22)
	_bar("metal", e, unit.x, unit.y, unit.z, Vector3(.86, .66, .3), Color("#c2c2b8"))
	_kit.lathe("plain", e * Vector3(unit.x, unit.y, unit.z + .155) , [Vector2(.2, 0), Vector2(.2, .004)], Color("#26272a"), 14)
	for block_x: float in [5.6, 6.2]:
		_bar("plain", e, block_x, .07, .22, Vector3(.2, .14, .34), Color("#6f6d68"))
	_kit.tube("plain", [e * Vector3(5.5, .66, .26), e * Vector3(5.2, .9, .06), e * Vector3(5.2, 2.6, .06)], .025, Color("#d2cdbd"), 6)
	_kit.tube("metal", [e * Vector3(.3, .33, .06), e * Vector3(8.0, .33, .06)], .02, Color("#62655f"), 6)
	# Service drop from the crossarm on the pole outside, sagging to an insulator on the eaves.
	var pole := Vector3(6.83, 9.5, 2.65)
	var eave := Vector3(WIDE * .5 + .02, 5.72, .22)
	var cable: Array[Vector3] = []
	for i: int in range(9):
		var t := float(i) / 8.0
		cable.append(pole.lerp(eave, t) + Vector3.DOWN * sin(t * PI) * .28)
	_kit.tube("plain", cable, .011, Color("#1c1d1f"), 4)
	_kit.lathe("plain", eave + Vector3.DOWN * .06, [Vector2(.03, 0), Vector2(.05, .02), Vector2(.03, .05), Vector2(.04, .07), Vector2(.02, .1)], Color("#c7c3b6"), 8)
	_kit.tube("plain", [eave, eave + Vector3(.0, -.06, -.1), e * Vector3(.78, 5.85, .05)], .009, Color("#1c1d1f"), 4)
	# Down pipe from the front gutter, kinked in past the awning.
	var drop := Vector3(5.66, 0, .1)
	var f := _front
	var points: Array[Vector3] = [f * Vector3(drop.x, WALL - EAVE * PITCH - .12, EAVE + .1), f * Vector3(drop.x, 5.5, .32), f * Vector3(drop.x, 5.32, .08), f * drop + Vector3.UP * .16, f * Vector3(drop.x, .06, .2)]
	_kit.tube("metal", points, .034, GUTTER, 7, .9)
	var y := 1.2
	while y < 5.2:
		_bar("metal", f, drop.x, y, .05, Vector3(.1, .03, .1), STEEL)
		y += 1.25

func _street_things() -> void:
	var f := _front
	_lantern(f * Vector3(.42, 2.2, .86))
	_lantern(f * Vector3(3.3, 2.2, .86))
	# Empty crates waiting for the brewery, bottles still in the top one.
	_crate(f * Vector3(.42, 0, .42), .05, Color("#8f7420"), false)
	_crate(f * Vector3(.42, .31, .42), -.04, Color("#7c2019"), false)
	_crate(f * Vector3(.45, .62, .42), .1, Color("#8f7420"), true)
	# Scallions growing in polystyrene boxes under the takeaway window.
	for x: float in [3.95, 4.62, 5.3]:
		_bar("plain", f, x, .16, .34, Vector3(.6, .3, .34), Color("#d7d5cc"), .75, 1.0)
		_bar("plain", f, x, .31, .34, Vector3(.54, .012, .28), Color("#3a2c20"), .7, .7)
		for i: int in range(26):
			var base := f * Vector3(x + _rng.randf_range(-.25, .25), .31, .34 + _rng.randf_range(-.12, .12))
			var tip := base + Vector3(_rng.randf_range(-.09, .09), _rng.randf_range(.32, .56), _rng.randf_range(-.09, .09))
			var side := Vector3(.009, 0, .006)
			var tone := Color("#5c8a3a").darkened(_rng.randf_range(0.0, .34))
			_kit.quad("leaf", base - side, tip - side * .3, tip + side * .3, base + side, tone, .7, 1.0)
			_kit.quad("leaf", base + side, tip + side * .3, tip - side * .3, base - side, tone, .6, .9)
	# Stand sign out on the pavement, a lightbox on a weighted foot.
	var at := Vector3(3.5, 0, 1.55) + _front.origin
	var turn := Basis(Vector3.UP, -.24)
	var box := Transform3D(turn, at + Vector3.UP * .78)
	_kit.block("metal", box, Vector3(.47, 1.12, .17), Color("#3c3d3e"), .8, 1.0)
	_kit.block("metal", Transform3D(turn, at + Vector3.UP * .1), Vector3(.62, .1, .36), Color("#1d1e1f"))
	_kit.block("metal", Transform3D(turn, at + Vector3.UP * .2), Vector3(.04, .14, .04), Color("#3c3d3e"))
	for face_sign: float in [1.0, -1.0]:
		var out := turn * Vector3(0, 0, .088) * face_sign
		var across := turn * Vector3(.22, 0, 0) * face_sign
		var mid := at + Vector3.UP * .78 + out
		_kit.atlas("sign", mid - across - Vector3.UP * .54, mid - across + Vector3.UP * .54, mid + across + Vector3.UP * .54, mid + across - Vector3.UP * .54, _cell(1544, 0, 252, 620), Color.WHITE, 1.0, .3)
	# Blue bin and a mop bucket on the alley corner.
	_kit.lathe("plain", f * Vector3(WIDE + .55, 0, -.4), [Vector2(.2, 0), Vector2(.26, .62), Vector2(.28, .64)], Color("#2a5f8e"), 12)
	_kit.lathe("plain", f * Vector3(WIDE + .55, .64, -.4), [Vector2(.29, 0), Vector2(.28, .05), Vector2(0, .09)], Color("#234f77"), 12)

func _lantern(top: Vector3) -> void:
	# Red paper 提灯, glowing after dark, strung from the awning frame.
	var rect := _cell(968, 628, 512, 384)
	var shape: Array[Vector2] = []
	for i: int in range(11):
		var t := float(i) / 10.0
		shape.append(Vector2(.09 + .16 * sin(t * PI), t * .72))
	_kit.lathe("sign", top - Vector3.UP * .72, shape, Color.WHITE, 14, rect)
	_kit.tube("plain", [top, top + Vector3.UP * .36], .005, Color("#1a1a1a"), 3)

func _crate(base: Vector3, turn: float, tint: Color, bottles: bool) -> void:
	# Moulded plastic beer crate: rails and corner posts with the gaps left open.
	var basis := Basis(Vector3.UP, turn)
	var size := Vector3(.48, .3, .36)
	for y: float in [.02, .15, .285]:
		_kit.block("plain", Transform3D(basis, base + basis * Vector3(0, y, size.z * .5)), Vector3(size.x, .03, .018), tint)
		_kit.block("plain", Transform3D(basis, base + basis * Vector3(0, y, -size.z * .5)), Vector3(size.x, .03, .018), tint)
		_kit.block("plain", Transform3D(basis, base + basis * Vector3(size.x * .5, y, 0)), Vector3(.018, .03, size.z), tint)
		_kit.block("plain", Transform3D(basis, base + basis * Vector3(-size.x * .5, y, 0)), Vector3(.018, .03, size.z), tint)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_kit.block("plain", Transform3D(basis, base + basis * Vector3(size.x * .5 * x, .15, size.z * .5 * z)), Vector3(.03, .3, .03), tint)
	_kit.block("plain", Transform3D(basis, base + basis * Vector3(0, .012, 0)), Vector3(size.x, .012, size.z), tint.darkened(.25))
	if not bottles: return
	for row: int in range(3):
		for column: int in range(4):
			var at := base + basis * Vector3(-.165 + float(column) * .11, .02, -.11 + float(row) * .11)
			_kit.lathe("bottle", at, [Vector2(.036, 0), Vector2(.036, .19), Vector2(.014, .27), Vector2(.014, .33)], Color("#3a1d0c"), 7)

func _build_lights() -> void:
	# Real light from the room, spilling through the door glass and over the pavement.
	var room := OmniLight3D.new()
	room.name = "RoomGlow"
	room.position = Vector3(-1.1, 2.1, -1.3)
	room.light_color = LIGHT_DAY
	room.light_energy = 1.9
	room.omni_range = 8.5
	room.omni_attenuation = 1.3
	room.visible = false
	add_child(room)
	_lamps.append(room)
	var board := OmniLight3D.new()
	board.name = "SignGlow"
	board.position = Vector3(0, 3.0, 1.9)
	board.light_color = Color(1.0, .72, .5)
	board.light_energy = .8
	board.omni_range = 6.0
	board.omni_attenuation = 1.4
	board.visible = false
	add_child(board)
	_lamps.append(board)
