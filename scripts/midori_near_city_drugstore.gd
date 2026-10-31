extends "res://scripts/midori_near_city_handmade.gd"
## ハマダ薬局: a 1962 corner building in mint mosaic tile, its wall swept round the junction
## in one curve. The chemist spills out over the pavement, the dentist has the ribbon window
## upstairs, and the family still live on top with their balcony on the bend.
const ATLAS := "res://assets/shinrai/near_city/drugstore_atlas.png"
const WIDE := 5.2
const DEEP := 4.6
const RADIUS := 1.4 # The sweep of the corner.
const GROUND := 3.3
const STOREY := 2.85
const TOP := 9.0
const PARAPET := 9.7
const FASCIA_LOW := 2.62
const FASCIA_HIGH := 3.24
const MINT := Color(.56, .8, .74)
const CREAM := Color(.98, .93, .82)
const RENDER := Color(.9, .86, .78)
const SHELF := Color(.86, .88, .89)
const SKY := Color(.25, .6, .7)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _side := DEEP - RADIUS # Straight run down the side street.
var _arc := RADIUS * PI * .5
var _length := DEEP - RADIUS + RADIUS * PI * .5 + WIDE - RADIUS

func _ready() -> void:
	_rng.seed = 1962
	_build_looks()
	_shop()
	_fascia()
	_surgery()
	_flat()
	_walls()
	_rooftop()
	_pavement()
	_mascot()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "leaf", "led", "goods", "shop", "floor", "sign", "cloth", "fascia"])
	_kit = null
	_omni("ShopSpill", Vector3(-1.4, 2.3, .9), Color(1.0, .95, .8), 1.3, 8.0)
	_omni("ShopRoom", Vector3(.3, 2.2, -2.2), Color(.95, .98, 1.0), .7, 6.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.mosaic = _look("", 1.0, .32)
	_looks.mosaic.set_shader_parameter("tile_size", Vector2(.052, .052))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.shop = _look("", 1.0, .6)
	_looks.shop.set_shader_parameter("glow", .3)
	_looks.shop.set_shader_parameter("day_glow", .28)
	_looks.floor = _look("", 1.0, .14)
	_looks.floor.set_shader_parameter("tile_size", Vector2(.3, .3))
	_looks.floor.set_shader_parameter("glow", .12)
	_looks.floor.set_shader_parameter("day_glow", .14)
	_looks.room = _look("", 1.0, .7)
	_looks.room.set_shader_parameter("glow", .36)
	_looks.room.set_shader_parameter("day_glow", .12)
	_looks.goods = _look("", 1.0, .5)
	_looks.goods.set_shader_parameter("albedo_map", signs)
	_looks.goods.set_shader_parameter("glow", .48)
	_looks.goods.set_shader_parameter("day_glow", .3)
	_looks.fascia = _look("", 1.0, .35)
	_looks.fascia.set_shader_parameter("albedo_map", signs)
	_looks.fascia.set_shader_parameter("glow", .8)
	_looks.fascia.set_shader_parameter("day_glow", .12)
	_looks.sign = _look("", 1.0, .35)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .75)
	_looks.sign.set_shader_parameter("day_glow", .15)
	_looks.cloth = _look("", 1.0, .9)
	_looks.cloth.set_shader_parameter("albedo_map", signs)
	_looks.cloth.set_shader_parameter("glow", .16)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .55)
	letters.set_shader_parameter("day_glow", .22)
	_looks.decal = letters

func _along(s: float, inset: float, y: float) -> Vector3:
	# A point on the street line: down the side street, round the bend, along the front.
	if s <= _side:
		return _front * Vector3(inset, y, -DEEP + s)
	if s <= _side + _arc:
		var angle := (s - _side) / RADIUS
		var reach := RADIUS - inset
		return _front * Vector3(RADIUS - reach * cos(angle), y, -RADIUS + reach * sin(angle))
	return _front * Vector3(RADIUS + s - _side - _arc, y, -inset)

func _step(s: float, end: float) -> float:
	# Short facets on the bend, long ones on the flat, always landing on the joins.
	var next := s + (.14 if s >= _side - .001 and s < _side + _arc - .001 else .6)
	for mark: float in [_side, _side + _arc, end]:
		if s < mark - .001 and next > mark:
			next = mark
	return minf(next, end)

func _wrap(part: String, s0: float, s1: float, y0: float, y1: float, inset: float, tint: Color, low := .9, high := 1.0, streak := .4, inward := false) -> void:
	var s := s0
	while s < s1 - .001:
		var next := _step(s, s1)
		var a := _along(s, inset, y0)
		var b := _along(s, inset, y1)
		var c := _along(next, inset, y1)
		var d := _along(next, inset, y0)
		if inward:
			_kit.quad(part, d, c, b, a, tint, low, high, streak, Vector2(s, -y0))
		else:
			_kit.quad(part, a, b, c, d, tint, low, high, streak, Vector2(s, -y0))
		s = next

func _wrap_atlas(part: String, s0: float, s1: float, y0: float, y1: float, inset: float, rect: Rect2) -> void:
	# An atlas panel bent round the wall, cut into a slice per facet.
	var s := s0
	while s < s1 - .001:
		var next := _step(s, s1)
		var from := (s - s0) / (s1 - s0)
		var to := (next - s0) / (s1 - s0)
		var slice := Rect2(rect.position.x + rect.size.x * from, rect.position.y, rect.size.x * (to - from), rect.size.y)
		_kit.atlas(part, _along(s, inset, y0), _along(s, inset, y1), _along(next, inset, y1), _along(next, inset, y0), slice)
		s = next

func _ring(s0: float, s1: float, y: float, outer: float, inner: float, part: String, tint: Color, facing_up: bool, ao := .9) -> void:
	# A band of slab following the wall: floors, soffits, coping, the balcony.
	var s := s0
	while s < s1 - .001:
		var next := _step(s, s1)
		var a := _along(s, outer, y)
		var b := _along(s, inner, y)
		var c := _along(next, inner, y)
		var d := _along(next, outer, y)
		if facing_up:
			_kit.quad(part, a, b, c, d, tint, ao, ao, 0.0, Vector2(s, 0))
		else:
			_kit.quad(part, b, a, d, c, tint, ao, ao, 0.0, Vector2(s, 0))
		s = next

func _slab(y: float, part: String, tint: Color, facing_up: bool) -> void:
	# A whole floor plate, round corner included.
	_ring(0.0, _length, y, 0.0, 1.6, part, tint, facing_up)
	var f := _front
	var x0 := 1.6
	var z0 := -1.6
	if facing_up:
		_kit.quad(part, f * Vector3(x0, y, z0), f * Vector3(x0, y, -DEEP), f * Vector3(WIDE, y, -DEEP), f * Vector3(WIDE, y, z0), tint, .9, .9)
	else:
		_kit.quad(part, f * Vector3(x0, y, -DEEP), f * Vector3(x0, y, z0), f * Vector3(WIDE, y, z0), f * Vector3(WIDE, y, -DEEP), tint, .9, .9)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect)

func _goods(index: int, from: float, share: float) -> Rect2:
	var rect := _cell(float(index / 6) * 1024.0, 146.0 + float(index % 6) * 176.0, 1020, 168)
	return Rect2(rect.position.x + rect.size.x * from, rect.position.y, rect.size.x * share, rect.size.y)

func _shop() -> void:
	# Bright, crammed and wide open: no front to speak of, shelves to the ceiling.
	var f := _front
	_slab(.03, "floor", Color(.8, .8, .78), true)
	_slab(FASCIA_LOW, "shop", Color(.62, .63, .62), false)
	var back := f.translated_local(Vector3(0, 0, -DEEP + .14))
	var side := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(WIDE - .14, 0, -DEEP))
	_kit.quad("shop", back * Vector3(0, 0, 0), back * Vector3(0, FASCIA_LOW, 0), back * Vector3(WIDE, FASCIA_LOW, 0), back * Vector3(WIDE, 0, 0), Color(.55, .56, .55), .8, 1.0)
	_kit.quad("shop", side * Vector3(0, 0, 0), side * Vector3(0, FASCIA_LOW, 0), side * Vector3(DEEP, FASCIA_LOW, 0), side * Vector3(DEEP, 0, 0), Color(.55, .56, .55), .8, 1.0)
	_shelves(back, .2, WIDE - .3, 5)
	_shelves(side, .3, DEEP - .4, 5)
	_island()
	for x: float in [1.2, 2.5, 3.8]:
		_kit.quad("lamp", f * Vector3(x - .6, FASCIA_LOW - .01, -2.24), f * Vector3(x - .6, FASCIA_LOW - .01, -2.1), f * Vector3(x + .6, FASCIA_LOW - .01, -2.1), f * Vector3(x + .6, FASCIA_LOW - .01, -2.24), Color(.62, .64, .66))
	# Slim columns where the front opens, and the mosaic pier at each end.
	for s: float in [_side, _side + _arc]:
		_kit.tube("metal", [_along(s, .18, .02), _along(s, .18, FASCIA_LOW)], .05, Color("#c9cbc9"), 8)
	_wrap("mosaic", 0.0, .45, 0.0, FASCIA_LOW, 0.0, MINT, .8, .95, .3)
	_wrap("mosaic", _length - .32, _length, 0.0, FASCIA_LOW, 0.0, MINT, .8, .95, .3)
	_wrap("mosaic", 0.0, .45, .0, 1.0, .002, MINT * .72, .7, .9, .2)
	# Prescription lockers set into the end pier, run by the machine behind the counter.
	for row: int in range(3):
		var at := _along(.22, -.015, .9 + float(row) * .36)
		_kit.block("metal", Transform3D(_west.basis, at), Vector3(.34, .32, .03), Color("#d6d8d6"))
		_kit.block("led", Transform3D(_west.basis, at + Vector3(-.02, -.12, .12)), Vector3(.03, .03, .012), GREEN)

func _shelves(wall: Transform3D, from: float, to: float, levels: int) -> void:
	for level: int in range(levels):
		var y := .16 + float(level) * .44
		var run := from
		while run < to - .05:
			var wide := minf(1.7, to - run)
			_panel("goods", wall, run, run + wide, y + .012, y + .4, .32, _goods((level * 3 + int(run * 2.0)) % 12, _rng.randf() * (1.0 - wide / 1.72) * .9, wide / 1.72 * .78))
			run += wide
		_bar("shop", wall, (from + to) * .5, y, .17, Vector3(to - from, .022, .36), SHELF)

func _island() -> void:
	var f := _front
	var mid := Vector3(2.9, 0, -2.3)
	_bar("shop", f, mid.x, .72, mid.z, Vector3(1.9, 1.4, .05), SHELF)
	_bar("shop", f, mid.x, .07, mid.z, Vector3(1.9, .14, .7), Color(.22, .23, .25))
	for level: int in range(3):
		var y := .16 + float(level) * .42
		_bar("shop", f, mid.x, y, mid.z + .17, Vector3(1.9, .02, .32), SHELF)
		_panel("goods", f, mid.x - .94, mid.x + .94, y + .012, y + .4, mid.z + .3, _goods(level * 2 + 1, _rng.randf() * .1, .9))

func _fascia() -> void:
	# The yellow board, proud of the wall and bent round the whole corner.
	var inset := -.14
	_wrap("mosaic", 0.0, _length, FASCIA_LOW, GROUND - .12, 0.0, MINT * .7, .8, .9, .2)
	_wrap_atlas("fascia", 0.0, _length, FASCIA_LOW, FASCIA_HIGH, inset, _cell(0, 0, 2048, 138))
	_ring(0.0, _length, FASCIA_LOW, inset, 0.0, "metal", Color("#55585a"), false, .8)
	_ring(0.0, _length, FASCIA_HIGH, inset, 0.0, "metal", Color("#8a8c8a"), true)
	# Price cards hung along the front of the shop on fishing line.
	var f := _front
	var cards: Array[int] = [0, 3, 1, 4]
	for i: int in range(cards.size()):
		var x := 1.7 + float(i) * .9
		_panel("decal", f, x, x + .78, 2.0, 2.54, .04, _cell(float(cards[i]) * 206.0 + 2.0, 1216, 200, 148))
		_bar("metal", f, x + .39, 2.58, .04, Vector3(.006, .1, .006), STEEL)
	var west := Transform3D(_west.basis, _along(0.0, -.04, 0.0))
	for i: int in range(2):
		var x := .8 + float(i) * 1.1
		_panel("decal", west, x, x + .78, 2.0, 2.54, .0, _cell(float(2 + i * 3) * 206.0 + 2.0, 1216, 200, 148))

func _surgery() -> void:
	# はまだ歯科: a ribbon of steel window the whole way round, with the tooth on the bend.
	var f := _front
	var base := GROUND
	var low := base + .72
	var high := base + 2.28
	_ring(0.0, _length, base, -.08, .02, "render", CREAM, true)
	_ring(0.0, _length, base - .1, -.08, .02, "render", CREAM, false)
	_wrap("render", 0.0, _length, base - .1, base, -.08, CREAM, .8, 1.0, .4)
	_wrap("mosaic", 0.0, _length, base, low, 0.0, MINT, .85, 1.0, .5)
	_wrap("mosaic", 0.0, _length, high, base + STOREY, 0.0, MINT, .7, .95, .4)
	_wrap("mosaic", 0.0, .3, low, high, 0.0, MINT, .8, .95)
	_wrap("mosaic", _length - .3, _length, low, high, 0.0, MINT, .8, .95)
	_ring(.3, _length - .3, low, -.06, .12, "metal", Color("#c9c6bb"), true)
	_ring(.3, _length - .3, high, 0.0, .12, "metal", Color("#8a8c8a"), false)
	_wrap("room", .3, _length - .3, base, high + .1, 1.3, Color("#cfe4e6"), .85, 1.0, 0.0)
	_ring(.3, _length - .3, low - .3, .12, 1.3, "room", Color("#9fb6b8"), true)
	_ring(.3, _length - .3, high + .1, .12, 1.3, "room", Color("#e8eeee"), false)
	_wrap("front", .3, _length - .3, low, high, .12, Color.WHITE)
	var s := .3
	var frame := Color("#3a3d3f")
	while s < _length - .28:
		_kit.block("metal", Transform3D(Basis.IDENTITY, _along(s, .1, (low + high) * .5)), Vector3(.05, high - low, .05), frame)
		s += .62
	for y: float in [low + .03, low + 1.02, high - .03]:
		var points: Array[Vector3] = []
		var t := .3
		while t < _length - .31:
			points.append(_along(t, .1, y))
			t = _step(t, _length - .3)
		points.append(_along(_length - .3, .1, y))
		_kit.tube("metal", points, .018, frame, 4)
	# White blinds, half the room's patience, and the chair under its lamp.
	_wrap("plain", 5.6, 7.0, low + 1.04, high, .14, Color("#eef0ee"), .9, 1.0, 0.0)
	_wrap("plain", 1.0, 2.0, low + 1.04, high, .14, Color("#eef0ee"), .9, 1.0, 0.0)
	var chair := _along(4.3, 1.0, low - .1)
	_kit.beam("room", chair, chair + Vector3(.5, .42, -.1), .34, .12, Vector3.UP, Color("#3fb6d4"))
	_kit.tube("room", [chair + Vector3(.1, 1.3, 0), chair + Vector3(.5, 1.1, -.1), chair + Vector3(.3, .95, -.1)], .02, Color("#f0f2f2"), 5)
	_kit.disc("lamp", chair + Vector3(.3, .94, -.1), Vector3.RIGHT, Vector3.BACK, .1, Color(.8, .82, .78))
	# Name across the front glass, the tooth on the curve, a real poster down the side.
	_panel("decal", f, 2.1, 4.8, low + .24, low + .9, -.1, _cell(0, 1372, 620, 150))
	_wrap_atlas("decal", 3.66, 4.94, low + .12, low + 1.0, .1, _cell(1410, 1372, 232, 160))
	_panel("decal", _west, .5, 1.5, low + .2, low + .92, -.1, _cell(310, 1540, 420, 300))

func _flat() -> void:
	# The family's floor: mosaic to the sky, a bent balcony, a window to the street.
	var f := _front
	var base := GROUND + STOREY
	var low := base + .05
	var high := base + 2.2
	var s0 := 2.0
	var s1 := 6.5
	var win := Rect2(3.3, base + 1.0, 1.3, 1.2)
	var hole0 := _side + _arc + win.position.x - RADIUS
	var hole1 := hole0 + win.size.x
	_wrap("mosaic", 0.0, s0, base, TOP, 0.0, MINT, .85, 1.0, .55)
	_wrap("mosaic", s1, hole0, base, TOP, 0.0, MINT, .85, 1.0, .55)
	_wrap("mosaic", hole1, _length, base, TOP, 0.0, MINT, .85, 1.0, .55)
	_wrap("mosaic", hole0, hole1, base, win.position.y, 0.0, MINT, .85, 1.0, .55)
	_wrap("mosaic", hole0, hole1, win.end.y, TOP, 0.0, MINT, .7, 1.0, .5)
	_wrap("mosaic", s0, s1, high, TOP, 0.0, MINT, .7, 1.0, .5)
	_window(f, win, .47, true)
	# Sliding doors round the curve, onto the balcony.
	_wrap("room", s0, s1, base, high + .1, 1.2, Color("#c9bea2"), .85, 1.0, 0.0)
	_ring(s0, s1, high + .1, .12, 1.2, "room", Color("#e0dac8"), false)
	_wrap("front", s0, s1, low, high, .12, Color.WHITE)
	var s := s0
	while s < s1 + .01:
		_kit.block("metal", Transform3D(Basis.IDENTITY, _along(minf(s, s1), .1, (low + high) * .5)), Vector3(.05, high - low, .05), ALUMINIUM)
		s += .75
	_wrap("plain", s0 + .1, s0 + 1.5, low + .06, high - .05, .15, Color("#e6e3da"), .9, 1.0, 0.0)
	_wrap("plain", s1 - 1.1, s1 - .1, low + .06, high - .05, .15, Color("#d7c9a8"), .9, 1.0, 0.0)
	# The balcony itself, on a thin cantilever.
	var lip := -.62
	_ring(s0 - .1, s1 + .1, base + .02, lip, 0.0, "render", CREAM, true)
	_ring(s0 - .1, s1 + .1, base - .12, lip, 0.0, "render", CREAM, false, .7)
	_wrap("render", s0 - .1, s1 + .1, base - .12, base + .02, lip, CREAM, .8, 1.0, .6)
	for y: float in [base + .44, base + 1.04]:
		var points: Array[Vector3] = []
		var t := s0 - .08
		while t < s1 + .07:
			points.append(_along(t, lip + .05, y))
			t = _step(t, s1 + .08)
		points.append(_along(s1 + .08, lip + .05, y))
		_kit.tube("metal", points, .016, Color("#d3d4cf"), 5)
	var post := s0 - .08
	while post < s1 + .08:
		_kit.tube("metal", [_along(post, lip + .05, base + .02), _along(post, lip + .05, base + 1.04)], .012, Color("#d3d4cf"), 4)
		post += .4
	for row: Array in [[2.5, .7, Color("#3f6a35")], [3.1, .5, Color("#507a3f")], [5.6, .9, Color("#35592e")], [6.1, .55, Color("#467038")]]:
		var at := _along(row[0], -.2, base + .02)
		_kit.lathe("plain", at, [Vector2(.09, 0), Vector2(.13, .22), Vector2(.14, .24)], Color("#a8603c"), 9)
		_plant(at + Vector3.UP * .2, row[1], row[2])
	_outdoor_unit(_east, 3.0, GROUND + 1.0, .22)
	_outdoor_unit(_east, 3.0, base + 1.0, .22)

func _walls() -> void:
	# Plain render where it faces the alley and the lot behind.
	_render_wall(_east, DEEP, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2])
	_render_wall(_back, WIDE, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2])
	_fibre([_east * Vector3(1.0, PARAPET - .1, .03), _east * Vector3(1.0, 2.6, .03)])
	_kit.tube("metal", [_east * Vector3(2.0, .1, .07), _east * Vector3(2.0, PARAPET - .3, .07)], .04, Color("#8a8b84"), 7)
	_camera(_along(_length - .15, -.1, 2.56))

func _rooftop() -> void:
	# Coping round the top, a little solar, and 薬 on a pole for the whole junction to see.
	_wrap("mosaic", 0.0, _length, TOP, PARAPET, 0.0, MINT, .85, .96, .5)
	_wrap("render", 0.0, _length, TOP, PARAPET, .14, RENDER * .9, .8, 1.0, .4, true)
	_ring(0.0, _length, PARAPET, -.04, .16, "render", CREAM, true)
	_wrap("render", 0.0, _length, PARAPET - .08, PARAPET, -.04, CREAM, .9, 1.0, .3)
	_slab(TOP + .02, "plain", Color("#62625e"), true)
	var pitch := Basis(Vector3.RIGHT, -.24)
	for x: float in [.1, 1.5]:
		_solar_module(Transform3D(pitch, Vector3(x, TOP + .6, -2.8)), 1.3, 1.8)
	_bar("metal", Transform3D(Basis.IDENTITY, Vector3(0, TOP + .02, 0)), 1.6, .52, -1.1, Vector3(.82, 1.04, .32), Color("#2b2e31"))
	_status(Transform3D(Basis.IDENTITY, Vector3(0, TOP + .02, 0)), 1.9, .86, -.93, GREEN)
	var foot := _along(_side + _arc * .5, .85, TOP)
	var box := foot + Vector3.UP * 3.2
	_kit.tube("metal", [foot, box - Vector3.UP * .55], .05, Color("#7f8488"), 8)
	var half := .55
	_kit.block("metal", Transform3D(Basis.IDENTITY, box), Vector3(half * 2.0, half * 2.0, half * 2.0), Color("#c9cbc9"))
	var rect := _cell(1830, 1380, 210, 210)
	for turn: float in [0.0, PI * .5, PI, PI * 1.5]:
		var spin := Basis(Vector3.UP, turn)
		var o := box + spin * Vector3(0, 0, half + .004)
		_kit.atlas("sign", o + spin * Vector3(-half, -half, 0), o + spin * Vector3(-half, half, 0), o + spin * Vector3(half, half, 0), o + spin * Vector3(half, -half, 0), rect)

func _pavement() -> void:
	# The stock that will not fit inside, racked on the street under its price cards.
	var f := _front
	for row: Array in [[1.75, 2], [2.95, 7], [4.1, 9]]:
		_rack(Transform3D(f.basis, f * Vector3(row[0], 0, .95)), row[1])
	var side := _west.basis
	for row: Array in [[-2.9, 4], [-1.8, 0]]:
		_rack(Transform3D(side, f * Vector3(-.9, 0, row[0] - .5)), row[1])
	# Pyramid of tissue boxes, the oldest trick on the pavement.
	var boxes := Color("#f2f4f6")
	for layer: int in range(3):
		for i: int in range(3 - layer):
			var x := 4.82 + float(i) * .25 + float(layer) * .12
			_bar("plain", f, x - .42, .08 + float(layer) * .13, .35, Vector3(.24, .12, .12), boxes if (i + layer) % 2 == 0 else Color("#f0a0c0"), .85, 1.0)
	# のぼり on their poles, stirring against the kerb.
	_flag(f * Vector3(1.0, 0, 1.8), .0, 750)
	_flag(f * Vector3(3.5, 0, 1.8), .25, 1010)
	_flag(f * Vector3(-1.5, 0, -2.6), -.5, 880)

func _rack(at: Transform3D, first: int) -> void:
	# Three stepped shelves on castors, facing whoever is walking past.
	var wide := 1.04
	_kit.block("metal", _at(at, wide * .5, .06, -.3), Vector3(wide, .08, .72), Color("#3a3d40"))
	for level: int in range(3):
		var y := .14 + float(level) * .34
		var z := -float(level) * .22
		_kit.block("shop", _at(at, wide * .5, y + .14, z - .12), Vector3(wide, .3, .24), Color(.74, .76, .77))
		_panel("goods", at, .02, wide - .02, y + .01, y + .32, z + .004, _goods((first + level * 5) % 12, _rng.randf() * .6, .36))
	var card := _cell(float((first + 1) % 6) * 206.0 + 2.0, 1216, 200, 148)
	_panel("decal", at, .16, wide - .16, 1.36, 1.92, -.44, card)
	_kit.tube("metal", [at * Vector3(wide * .5, 1.0, -.46), at * Vector3(wide * .5, 1.4, -.46)], .006, Color("#c9cbc9"), 3)

func _flag(foot: Vector3, turn: float, column: int) -> void:
	var spin := Basis(Vector3.UP, turn)
	_kit.lathe("metal", foot, [Vector2(.16, 0), Vector2(.16, .1), Vector2(.03, .14)], Color("#3a3d40"), 10)
	_kit.tube("metal", [foot, foot + Vector3.UP * 2.5], .016, Color("#c9cbc9"), 6)
	_kit.tube("metal", [foot + Vector3.UP * 2.46, foot + Vector3.UP * 2.46 + spin * Vector3(.5, 0, 0)], .01, Color("#c9cbc9"), 5)
	var rect := _cell(float(column), 1540, 120, 440)
	var top := 2.44
	var low := .7
	var half := Rect2(rect.position, Vector2(rect.size.x * .5, rect.size.y))
	var rest := Rect2(rect.position + Vector2(rect.size.x * .5, 0), Vector2(rect.size.x * .5, rect.size.y))
	var a := foot + spin * Vector3(.02, 0, 0)
	var m := foot + spin * Vector3(.26, 0, .05)
	var e := foot + spin * Vector3(.5, 0, 0)
	for pair: Array in [[a, m, half], [m, e, rest]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		var cut: Rect2 = pair[2]
		_kit.atlas("cloth", p + Vector3.UP * low, p + Vector3.UP * top, q + Vector3.UP * top, q + Vector3.UP * low, cut)
		_kit.atlas("cloth", q + Vector3.UP * low, q + Vector3.UP * top, p + Vector3.UP * top, p + Vector3.UP * low, cut)

func _mascot() -> void:
	# ハマちゃん at the corner, a head taller than a child, patted smooth by three generations.
	var at := _along(_side + _arc * .5, -.75, 0.0)
	var out := (at - _along(_side + _arc * .5, 0.0, 0.0)).normalized()
	var across := Vector3.UP.cross(out).normalized()
	var coat := Color("#fbfaf4")
	_kit.lathe("metal", at, [Vector2(.3, 0), Vector2(.3, .08), Vector2(.24, .1)], Color("#7b7468"), 14)
	_kit.lathe("plain", at + Vector3.UP * .08, [Vector2(.2, 0), Vector2(.27, .24), Vector2(.25, .55), Vector2(.12, .72)], coat, 14)
	var head := at + Vector3.UP * .96
	_kit.lathe("plain", head + Vector3.DOWN * .27, [Vector2(.02, 0), Vector2(.22, .08), Vector2(.28, .27), Vector2(.22, .46), Vector2(.02, .54)], Color("#f6e2bc"), 14)
	for side: float in [-1.0, 1.0]:
		_kit.disc("plain", head + across * side * .2 + Vector3.UP * .24 + out * .03, across, Vector3.UP, .09, Color("#f0c9a0"))
		_kit.disc("plain", head + across * side * .2 + Vector3.UP * .24 - out * .0, -across, Vector3.UP, .09, Color("#f0c9a0"))
		_kit.tube("plain", [at + Vector3.UP * .6 + across * side * .24, at + Vector3.UP * .4 + across * side * .34 + out * .1], .05, coat, 6)
	_kit.disc("cloth", head + out * .275, across, Vector3.UP, .24, Color.WHITE, _cell(1636, 1378, 192, 192))
	_kit.lathe("plain", head + Vector3.UP * .22, [Vector2(.17, 0), Vector2(.17, .09), Vector2(.09, .13), Vector2(.01, .14)], coat, 12)
	_kit.disc("cloth", head + Vector3.UP * .28 + out * .15, across, Vector3.UP, .05, Color.WHITE, _cell(1830, 1380, 210, 210))
