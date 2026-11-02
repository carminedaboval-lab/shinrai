extends "res://scripts/midori_near_city_handmade.gd"
## 花つぐみ: the Tsukumi family's flower shop, one room wide, its stock out on the pavement by
## seven under a green blind. Three generations live upstairs: a parlour behind a balcony of
## pots, the grandmother's bay above it, a thin tin roof that falls towards the estate agent.
const ATLAS := "res://assets/shinrai/near_city/flower_atlas.png"
const WIDE := 3.68
const DEEP := 9.6
const HEAD := 2.7
const GROUND := 3.6
const SECOND := 6.2
const EAVE := 8.6
const RIDGE := 9.6
const ROOM_TOP := 2.66
const ROOM_DEEP := 7.4
const RX0 := .14
const RX1 := 2.78
const RENDER := Color(.95, .98, .92)
const CELADON := Color("#aec8b0")
const SAGE := Color("#8aa895")
const BUCKET := Color("#17181a")
const STEM := Color("#4a6f3a")
const WHITE_POT := Color("#e4e2da")
const PANE := Rect2(.14, .42, 1.08, 2.28)
const GAP := Rect2(1.22, 0, 1.56, 2.7)
const HOME := Rect2(2.94, .02, .62, 2.14)
const LOGGIA := Rect2(.26, 3.72, 3.16, 2.26)
const BAY := Rect2(.46, 6.62, 1.72, 1.24)
const SLIT := Rect2(2.78, 6.72, .4, 1.16)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _p := "petal"
var _l := "leaf"
var _rich := 1.0
var _solid := "plain"

func _ready() -> void:
	_rng.seed = 8710
	_build_looks()
	_shop_wall()
	_outdoors(false)
	_room()
	_cooler()
	_wrapping_bench()
	_west_wall()
	_window_display()
	_table()
	_east_shelf()
	_outdoors(true)
	_shop_front()
	_home_door()
	_blind()
	_signboard()
	_upper_wall()
	_balcony()
	_parlour()
	_bay()
	_roof()
	_flanks()
	_stock_stand()
	_plant_bench()
	_pavement_things()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "led", "room", "wall", "floor", "timber", "bloom", "frond", "cold", "paper", "card", "film"])
	_kit = null
	_omni("FlowerRoom", Vector3(-.5, 2.25, -3.0), Color(1.0, .84, .62), .42, 5.0)
	_omni("FlowerStreet", Vector3(-.75, 2.35, .7), Color(1.0, .8, .56), .75, 4.5)

func _outdoors(value: bool) -> void:
	_p = "petal" if value else "bloom"
	_l = "leaf" if value else "frond"
	_rich = 1.0 if value else .5
	_solid = "plain" if value else "room"

func _atlas_look(name: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _lit(name: String, texture: String, tile: float, rough: float, glow: float, day: float, chroma := 1.0) -> void:
	var look := _look(texture, tile, rough)
	look.set_shader_parameter("chroma", chroma)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _build_looks() -> void:
	_shared_looks()
	_looks.leaf.set_shader_parameter("glow", .05)
	_looks.tile = _look("", 1.0, .3)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.095, .046))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .6)
	_looks.tin = _look("worn_corrugated_iron", 2.0, .6, .2)
	_looks.tin.set_shader_parameter("chroma", .15)
	_looks.wood = _look("white_stucco", 1.2, .72)
	_looks.wood.set_shader_parameter("chroma", .25)
	_looks.wood.set_shader_parameter("glow", .07)
	_lit("petal", "", 1.0, .7, .17, .03)
	_lit("bloom", "", 1.0, .7, .42, .2)
	_lit("frond", "", 1.0, .6, .3, .18)
	_lit("room", "", 1.0, .55, .3, .18)
	_lit("wall", "white_stucco", 2.0, .85, .2, .16, .4)
	_lit("floor", "plastered_wall_03", 2.0, .5, .2, .14, .3)
	_lit("timber", "japanese_cedar_planks", 1.2, .7, .28, .18, .34)
	_lit("cold", "", 1.0, .4, .42, .2)
	_atlas_look("cloth", .9, .03, .0)
	_atlas_look("card", .6, .16, .03)
	_atlas_look("paper", .7, .3, .1)
	var film := ShaderMaterial.new()
	film.shader = DECAL_SHADER
	film.set_shader_parameter("atlas", load(ATLAS))
	film.set_shader_parameter("glow", .12)
	film.set_shader_parameter("day_glow", .55)
	_looks.film = film
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", load(ATLAS))
	letters.set_shader_parameter("glow", .05)
	letters.set_shader_parameter("day_glow", .02)
	_looks.decal = letters

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _skin(part: String, face: Transform3D, area: Rect2, holes: Array[Rect2], tint: Color, low := .9, streak := .6) -> void:
	for piece: Rect2 in _minus(area, holes):
		_kit.quad(part, face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), tint, low, 1.0, streak, Vector2(piece.position.x, -piece.position.y))

# --- Plant parts. Petals and leaves are single sheets, so each is written twice, once a side.

func _two(part: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, low := 1.0, high := 1.0) -> void:
	_kit.quad(part, a, b, c, d, tint, low, high)
	_kit.quad(part, d, c, b, a, tint.darkened(.14), low * .85, high * .85)

func _petal(base: Vector3, along: Vector3, side: Vector3, length: float, wide: float, cup: float, tint: Color) -> void:
	# Narrow claw, broad blade, rounded tip; cup above zero folds the tip towards the flower's heart.
	var n := along.cross(side).normalized()
	var s := side.normalized()
	var mid := base + along * length * .52 + n * cup * length * .2
	var tip := base + along * length + n * cup * length * .75
	_two(_p, base - s * wide * .12, mid - s * wide * .5, mid + s * wide * .5, base + s * wide * .12, tint, .55, 1.0)
	_two(_p, mid - s * wide * .5, tip - s * wide * .22, tip + s * wide * .22, mid + s * wide * .5, tint.lightened(.08), 1.0, 1.0)

func _spread(up: Vector3) -> Array[Vector3]:
	var a := up.cross(Vector3(.3, .13, .9)).normalized()
	return [a, up.cross(a).normalized()]

func _ring(at: Vector3, up: Vector3, count: int, tilt: float, length: float, wide: float, cup: float, tint: Color, spin := 0.0) -> void:
	var axes := _spread(up)
	for i: int in range(count):
		var angle := spin + TAU * float(i) / float(count) + _rng.randf_range(-.12, .12)
		var out := axes[0] * cos(angle) + axes[1] * sin(angle)
		var along := (up * cos(tilt) + out * sin(tilt)).normalized()
		_petal(at + out * length * .06, along, up.cross(out), length, wide, cup, tint)

func _fleck(at: Vector3, up: Vector3, count: int, size: float, tint: Color, sided := true) -> void:
	# A floret of kite petals, for anything with too many flowers to model each one.
	var axes := _spread(up)
	var spin := _rng.randf() * TAU
	for i: int in range(count):
		var angle := spin + TAU * float(i) / float(count)
		var out := axes[0] * cos(angle) + axes[1] * sin(angle)
		var side := up.cross(out) * size * .44
		var mid := at + out * size * .55
		var tip := at + out * size + up * size * .1
		if sided:
			_two(_p, at, mid + side, tip, mid - side, tint)
		else:
			_kit.quad(_p, at, mid + side, tip, mid - side, tint, .75, 1.0)

func _leaf(base: Vector3, along: Vector3, length: float, wide: float, droop: float, tint: Color, pear := 1.1, rib := false) -> void:
	# Two halves folded along a midrib, the blade arching over under its own weight.
	var flat := along.cross(Vector3.UP + along * -.2 + Vector3(.13, 0, .07)).normalized()
	var n := flat.cross(along).normalized()
	var spine_before := base
	var half_before := 0.0
	var steps := 2 if length < .05 else 3 if length < .2 else 5
	for i: int in range(1, steps + 1):
		var t := float(i) / float(steps)
		var spine := base + along * length * t + Vector3.DOWN * droop * length * t * t
		var half := sin(PI * pow(minf(t, .999), pear)) * wide * .5
		var l0 := spine_before + flat * half_before + n * half_before * .3
		var r0 := spine_before - flat * half_before + n * half_before * .3
		var l1 := spine + flat * half + n * half * .3
		var r1 := spine - flat * half + n * half * .3
		_two(_l, spine_before, spine, l1, l0, tint, .85, 1.0)
		_two(_l, r0, r1, spine, spine_before, tint.darkened(.08), .85, 1.0)
		spine_before = spine
		half_before = half
	if rib:
		_kit.tube(_l, [base, base + along * length * .5 + Vector3.DOWN * droop * length * .25 + n * .004, base + along * length + Vector3.DOWN * droop * length + n * .002], .0028, tint.lightened(.36), 3)

func _rose(at: Vector3, up: Vector3, s: float, tint: Color) -> void:
	# Tight heart, a looser collar, and the guard petals starting to fall open.
	_ring(at, up, 3, .12, s * .95, s * .95, .55, tint.darkened(.2), _rng.randf() * TAU)
	_ring(at, up, 5, .5, s * 1.15, s * 1.15, .42, tint.darkened(.04), _rng.randf() * TAU)
	if _rich > .6:
		_ring(at - up * s * .1, up, 6, 1.0, s * 1.3, s * 1.25, .05, tint.lightened(.06), _rng.randf() * TAU)
	_fleck(at - up * s * .12, -up, 5, s * .7, STEM.darkened(.1))

func _carnation(at: Vector3, up: Vector3, s: float, tint: Color) -> void:
	# Frilled: lots of short broad petals, their tips a shade paler.
	_ring(at, up, 5, .1, s * .8, s * .5, .3, tint.darkened(.14), 0.0)
	_ring(at, up, 9, .5, s * .95, s * .5, .05, tint.darkened(.05), .5)
	_ring(at, up, 11, .95, s * 1.05, s * .55, -.1, tint, .2)
	if _rich > .6:
		_ring(at, up, 12, 1.3, s * 1.1, s * .55, -.2, tint.lightened(.04), .4)
	_kit.tube(_l, [at - up * s * .7, at - up * s * .1], s * .3, STEM, 4)

func _gerbera(at: Vector3, up: Vector3, s: float, tint: Color, eye: Color) -> void:
	var axes := _spread(up)
	_ring(at, up, 18 if _rich > .6 else 11, 1.42, s, s * .23, -.05, tint)
	if _rich > .6:
		_ring(at + up * .003, up, 12, 1.2, s * .62, s * .2, 0.0, tint.lightened(.12), .13)
	_kit.disc(_p, at + up * .012, axes[0], axes[1], s * .3, eye)
	_kit.disc(_p, at - up * .006, axes[1], axes[0], s * .34, STEM)

func _lily(at: Vector3, up: Vector3, s: float, tint: Color, throat: Color) -> void:
	# Six tepals thrown back at the tip, a green throat, stamens out on long filaments.
	_ring(at, up, 6, .85, s, s * .4, -.75, tint)
	_ring(at, up, 3, .35, s * .4, s * .22, -.2, throat, .5)
	if _rich < .6: return
	var axes := _spread(up)
	for i: int in range(6):
		var angle := TAU * float(i) / 6.0
		var tip := at + up * s * .62 + (axes[0] * cos(angle) + axes[1] * sin(angle)) * s * .2
		_kit.tube(_p, [at, tip], .0018, Color("#dfe6c0"), 3)
		_kit.beam(_p, tip + axes[0] * .007, tip - axes[0] * .007, .005, .004, up, Color("#a8501e"))

func _tulip(at: Vector3, up: Vector3, s: float, tint: Color) -> void:
	_ring(at, up, 3, .2, s, s * .85, .35, tint.darkened(.1))
	_ring(at, up, 3, .24, s * 1.04, s * .85, .22, tint, PI / 3.0)
	_kit.lathe(_p, at - Vector3.UP * .01, [Vector2(.006, 0), Vector2(.02, .018)], tint.darkened(.4), 5)

func _mum(at: Vector3, up: Vector3, s: float, tint: Color) -> void:
	# 小菊: dense narrow rays, the heart still closed and greenish.
	_ring(at, up, 13 if _rich > .6 else 9, 1.35, s, s * .28, .1, tint)
	_ring(at, up, 9, .85, s * .78, s * .24, .3, tint.darkened(.05), .3)
	_ring(at, up, 6, .35, s * .5, s * .2, .5, tint.lerp(Color("#a8b860"), .35), .1)

func _trumpet(at: Vector3, up: Vector3, s: float, tint: Color) -> void:
	# Mandevilla or moth orchid: five flared lobes round a short throat.
	_ring(at, up, 5, 1.32, s, s * .7, -.12, tint, _rng.randf() * TAU)
	_kit.tube(_p, [at - up * s * .7, at], s * .13, tint.darkened(.2), 4)
	_kit.lathe(_p, at, [Vector2(s * .04, 0), Vector2(s * .1, .002)], Color("#e8d060"), 5)

func _spike(foot: Vector3, top: Vector3, tint: Color, tall_florets: int, size: float) -> void:
	# Stock, gentian, lavender: florets wound up a stem, shrinking into buds at the tip.
	var along := (top - foot).normalized()
	var axes := _spread(along)
	for i: int in range(tall_florets):
		var t := float(i) / float(tall_florets)
		var angle := float(i) * 2.4
		var out := axes[0] * cos(angle) + axes[1] * sin(angle)
		var s := size * (1.0 - t * .6)
		_fleck(foot.lerp(top, t) + out * s * .55, (out + along * .45).normalized(), 4 if t < .7 else 3, s, tint.lightened(.1 * t))

func _hydrangea(at: Vector3, r: float, tint: Color, other: Color) -> void:
	# A dome of forty four-petalled florets over a dark core, each a touch off its neighbours.
	_ball(at, Vector3.ONE * r * .86, tint.darkened(.28), _p, 4, 8)
	var count := 64 if _rich > .6 else 30
	for i: int in range(count):
		var y := float(i) / float(count) * 1.2 - .25
		var around := sqrt(maxf(1.0 - y * y, 0.0))
		var angle := float(i) * 2.4
		var dir := Vector3(cos(angle) * around, y, sin(angle) * around).normalized()
		var tone := tint.lerp(other, _rng.randf()).lightened(_rng.randf_range(-.06, .08))
		_fleck(at + dir * r * _rng.randf_range(.9, 1.0), dir, 4, r * .23, tone, false)

func _gyp(at: Vector3, up: Vector3, spread: float) -> void:
	# かすみ草: wire stems, then a mist of very small white flowers.
	var axes := _spread(up)
	for i: int in range(26 if _rich > .6 else 8):
		var a := _rng.randf() * TAU
		var tip := at + (axes[0] * cos(a) + axes[1] * sin(a)) * spread * sqrt(_rng.randf()) + up * spread * _rng.randf_range(.1, .7)
		_kit.tube(_l, [at, tip], .0012, Color("#7f9a68"), 3)
		_fleck(tip, up, 5, .008, Color("#f4f2ea"))
		_fleck(tip + axes[0] * .016, up, 5, .007, Color("#efeee2"))
		_fleck(tip - axes[1] * .015, up, 5, .007, Color("#f4f2ea"))
		_fleck(tip + axes[1] * .017, up, 5, .007, Color("#f4f2ea"))

func _bucket(at: Vector3, tall: float, low: float, top: float, tint: Color, water := true, part := "plain") -> Vector3:
	# Tapered, a rolled rim, real inside, and water standing in it.
	var profile: Array[Vector2] = [Vector2(low, 0), Vector2(top - .006, tall - .018), Vector2(top + .006, tall - .014), Vector2(top + .006, tall), Vector2(top - .008, tall), Vector2(low + .002, tall * .3)]
	_kit.lathe(part, at, profile, tint, 14)
	if water:
		_kit.disc(part, at + Vector3.UP * tall * .55, Vector3.RIGHT, Vector3.FORWARD, lerpf(low, top, .55), Color("#2c3532"))
	return at + Vector3.UP * tall

func _head(kind: String, at: Vector3, up: Vector3, tint: Color) -> void:
	match kind:
		"rose": _rose(at, up, .037, tint)
		"carnation": _carnation(at, up, .04, tint)
		"gerbera": _gerbera(at, up, .062, tint, Color("#3c2a18"))
		"sunflower": _gerbera(at, up, .068, tint, Color("#2e1e10"))
		"lily": _lily(at, up, .105, tint, Color("#b9cf8c"))
		"tulip": _tulip(at, up, .058, tint)
		"mum": _mum(at, up, .042, tint)
		"lisianthus": _rose(at, up, .04, tint.lightened(.2))
		"stock": _spike(at - up * .2, at + up * .07, tint, 16, .027)
		"gentian": _spike(at - up * .17, at + up * .06, tint, 12, .024)

func _bunch(kind: String, mouth: Vector3, count: int, tall: float, tints: Array, sleeve := true) -> void:
	# Stems gathered at the mouth and falling open at the top, a collar of leaf, tallest at the centre.
	var lean := Vector3(0, 0, .16)
	for i: int in range(count):
		var angle := float(i) * 2.39996 + _rng.randf()
		var near := sqrt((float(i) + .5) / float(count))
		var out := Vector3(cos(angle), 0, sin(angle)) * near
		var foot := mouth + out * .04 + Vector3.DOWN * .1
		var head := mouth + out * .17 + lean * .4 + Vector3.UP * tall * (1.0 - near * near * .3) * _rng.randf_range(.9, 1.02)
		var up := (out * .75 + lean + Vector3.UP).normalized()
		_kit.tube(_l, [foot, foot.lerp(head, .5) + out * .012, head - up * .01], .0034, STEM, 3)
		_head(kind, head, up, tints[i % tints.size()])
		var leaves := 3 if _rich > .6 else 1
		for k: int in range(leaves):
			var t := .4 + float(k) * .17
			var side := Vector3(cos(angle + float(k) * 2.2), .55, sin(angle + float(k) * 2.2)).normalized()
			var long := .2 if kind == "tulip" else .13
			_leaf(foot.lerp(head, t), side, long, .045 if kind != "carnation" else .016, .5, STEM.darkened(_rng.randf() * .25).lightened(_rng.randf() * .12))
	for k: int in range(9 if _rich > .6 else 4):
		var a := float(k) * 2.39996
		var ring := Vector3(cos(a), 0, sin(a))
		_leaf(mouth + ring * .05 + Vector3.DOWN * .02, (ring * .8 + Vector3.UP).normalized(), .2, .06, .55, Color("#3b6134").darkened(_rng.randf() * .25))
	if sleeve:
		_kit.lathe("film", mouth + Vector3.DOWN * .03, [Vector2(.1, 0), Vector2(.14, tall * .3), Vector2(.21, tall * .66)], Color.WHITE, 12, _cell(1040, 720, 360, 200))

func _foliage(mouth: Vector3, count: int, tall: float, tint: Color) -> void:
	# Green filler: leatherleaf and eucalyptus, cut long, round paired leaves.
	for i: int in range(count):
		var angle := _rng.randf() * TAU
		var out := Vector3(cos(angle), 0, sin(angle))
		var top := mouth + out * _rng.randf_range(.08, .2) + Vector3.UP * tall * _rng.randf_range(.7, 1.0) + Vector3.BACK * .05
		_kit.tube(_l, [mouth + Vector3.DOWN * .08, mouth.lerp(top, .5), top], .003, tint.darkened(.3), 3)
		for k: int in range(6):
			var at := mouth.lerp(top, .35 + float(k) * .12)
			_leaf(at, (out + Vector3.UP * .6 + Vector3.BACK * .3).normalized(), .07, .058, .2, tint.lightened(_rng.randf() * .12), .9)
			_leaf(at, (Vector3(-out.x, .6, -out.z)).normalized(), .07, .058, .2, tint.darkened(_rng.randf() * .1), .9)

func _card(mouth: Vector3, top: float, i: int) -> void:
	# 値札 on a clear pick pushed in at the bucket's lip, facing the street.
	var c := mouth + Vector3(_rng.randf_range(-.03, .03), .1, top + .03)
	var rect := _cell(1040.0 + float(i % 4) * 200.0, float(i / 4) * 92.0, 200, 92)
	var wide := .06
	var tall := .028
	var lean := Vector3(0, 0, -.012)
	_kit.atlas("card", c + Vector3(-wide, -tall, .012), c + Vector3(-wide, tall, 0) + lean, c + Vector3(wide, tall, 0) + lean, c + Vector3(wide, -tall, .012), rect)
	_kit.quad("plain", c + Vector3(wide, -tall, .01), c + Vector3(wide, tall, -.002) + lean, c + Vector3(-wide, tall, -.002) + lean, c + Vector3(-wide, -tall, .01), Color("#d8d6cc"))
	_kit.tube("plain", [c + Vector3(0, -tall, .004), mouth + Vector3(0, -.05, top - .02)], .0025, Color("#d4dcd8"), 3)

func _pot(at: Vector3, tall: float, low: float, top: float, tint: Color) -> Vector3:
	var profile: Array[Vector2] = [Vector2(low, 0), Vector2(top - .004, tall - .03), Vector2(top + .008, tall - .03), Vector2(top + .008, tall), Vector2(top - .01, tall)]
	_kit.lathe(_solid, at, profile, tint, 14)
	_kit.disc(_solid, at + Vector3.UP * (tall - .012), Vector3.RIGHT, Vector3.FORWARD, top - .008, Color("#2c2219"))
	return at + Vector3.UP * (tall - .012)

func _basket(at: Vector3, tall: float, low: float, top: float, part := "room") -> Vector3:
	# Woven cover: stacked rounds of cane, each a slightly different dry brown.
	var rounds := int(tall / .024)
	for i: int in range(rounds):
		var t := float(i) / float(rounds)
		var r := lerpf(low, top, t) + sin(t * PI) * .012
		var tint := Color("#8a6a3e") if i % 2 == 0 else Color("#6e5230")
		_kit.lathe(part, at + Vector3.UP * t * tall, [Vector2(r, 0), Vector2(r + .006, .012), Vector2(r, .024)], tint, 12)
	_kit.disc(part, at + Vector3.UP * tall * .92, Vector3.RIGHT, Vector3.FORWARD, top, Color("#2c2219"))
	return at + Vector3.UP * tall * .92

func _fern(root: Vector3, count: int, length: float, tint: Color, pinnae := 12) -> void:
	# Arching fronds with a pair of leaflets at every step, shrinking to the tip.
	for i: int in range(count):
		var angle := TAU * float(i) / float(count) + _rng.randf()
		var out := Vector3(cos(angle), 0, sin(angle))
		var points: Array[Vector3] = []
		var reach := length * _rng.randf_range(.7, 1.0)
		for k: int in range(5):
			var t := float(k) / 4.0
			points.append(root + out * reach * t * .9 + Vector3.UP * (sin(t * 2.4) * reach * .62 - t * t * reach * .2))
		_kit.tube(_l, points, .0026, tint.darkened(.25), 3)
		var side := out.cross(Vector3.UP).normalized()
		for k: int in range(pinnae):
			var t := .2 + .8 * float(k) / float(pinnae)
			var seg := minf(t * 4.0, 3.0)
			var at := points[int(seg)].lerp(points[int(seg) + 1], seg - float(int(seg)))
			var s := (1.0 - t * .75) * length * .17
			_leaf(at, (side + out * .4).normalized(), s, s * .42, .3, tint.lightened(_rng.randf() * .1), 1.0)
			_leaf(at, (-side + out * .4).normalized(), s, s * .42, .3, tint.darkened(_rng.randf() * .1), 1.0)

func _ivy(from: Vector3, length: float) -> void:
	# A strand over the edge, a leaf every hand's width, wandering as it falls.
	var points: Array[Vector3] = [from]
	var at := from
	var steps := int(length / .05)
	for i: int in range(steps):
		at += Vector3(_rng.randf_range(-.025, .025), -.05, _rng.randf_range(-.008, .012))
		points.append(at)
		for k: int in range(2):
			var dir := Vector3(_rng.randf_range(-1.0, 1.0), -.75, .3).normalized()
			_leaf(at, dir, .085, .08, .1, Color("#44683a").lerp(Color("#6f9150"), _rng.randf()), .85)
	_kit.tube(_l, points, .0022, Color("#5a4a30"), 3)

# --- Street wall and shop room.

func _shop_wall() -> void:
	# Pale celadon mosaic from 1978, the plinth darker where the hose reaches.
	var f := _front
	for piece: Rect2 in _minus(Rect2(0, 0, WIDE, GROUND), [PANE, GAP, HOME] as Array[Rect2]):
		_kit.quad("tile", f * Vector3(piece.position.x, piece.position.y, 0), f * Vector3(piece.position.x, piece.end.y, 0), f * Vector3(piece.end.x, piece.end.y, 0), f * Vector3(piece.end.x, piece.position.y, 0), CELADON, .88, 1.0, .4, Vector2(piece.position.x, -piece.position.y))
	_reveal(f, PANE, .1, Color("#8f958a"))
	_reveal(f, GAP, .14, Color("#8f958a"))
	_reveal(f, HOME, .08, Color("#8f958a"))
	_bar("plain", f, .68, .135, .008, Vector3(1.08, .13, .016), Color("#59615a"), .7, .9)
	_bar("plain", f, 2.86, .1, .008, Vector3(.16, .2, .016), Color("#59615a"), .7, .9)
	_bar("plain", f, 3.62, .1, .008, Vector3(.12, .2, .016), Color("#59615a"), .7, .9)
	_bar("metal", f, PANE.get_center().x, PANE.position.y - .012, .025, Vector3(PANE.size.x + .03, .024, .14), ALUMINIUM)

func _room() -> void:
	# Cream walls, a wet concrete floor with its drain slot, black track and warm spots on the stock.
	var f := _front
	var x0 := RX0
	var x1 := RX1
	var d := ROOM_DEEP
	var cream := Color("#7f8c7e")
	_kit.quad("wall", f * Vector3(x0, 0, -.08), f * Vector3(x0, ROOM_TOP, -.08), f * Vector3(x0, ROOM_TOP, -d), f * Vector3(x0, 0, -d), cream, .7, .95)
	_kit.quad("wall", f * Vector3(x1, 0, -d), f * Vector3(x1, ROOM_TOP, -d), f * Vector3(x1, ROOM_TOP, -.08), f * Vector3(x1, 0, -.08), cream * .94, .7, .9)
	_kit.quad("wall", f * Vector3(x0, 0, -d), f * Vector3(x0, ROOM_TOP, -d), f * Vector3(x1, ROOM_TOP, -d), f * Vector3(x1, 0, -d), cream * .9, .7, .9)
	_kit.quad("floor", f * Vector3(x0, .02, -.04), f * Vector3(x0, .02, -d), f * Vector3(x1, .02, -d), f * Vector3(x1, .02, -.04), Color(.42, .43, .41), .75, .8)
	_kit.quad("room", f * Vector3(x0, .024, -.3), f * Vector3(x0, .024, -d + .9), f * Vector3(x0 + .07, .024, -d + .9), f * Vector3(x0 + .07, .024, -.3), Color("#2a2c2a"))
	_kit.quad("room", f * Vector3(x0, ROOM_TOP, -d), f * Vector3(x0, ROOM_TOP, -.08), f * Vector3(x1, ROOM_TOP, -.08), f * Vector3(x1, ROOM_TOP, -d), Color("#6e6a5c"), .75, .8)
	# Boarded ceiling joints, the track, and five cans each aimed at its own patch of colour.
	var z := -.6
	while z > -d:
		_kit.quad("room", f * Vector3(x0, ROOM_TOP - .002, z - .012), f * Vector3(x0, ROOM_TOP - .002, z), f * Vector3(x1, ROOM_TOP - .002, z), f * Vector3(x1, ROOM_TOP - .002, z - .012), Color("#8f8a7c"))
		z -= .6
	_bar("room", f, 1.46, ROOM_TOP - .025, -3.4, Vector3(.04, .05, 6.0), Color("#141416"))
	for row: Vector2 in [Vector2(-.7, -.4), Vector2(-1.9, .3), Vector2(-3.1, .4), Vector2(-4.3, -.4), Vector2(-5.5, .2)]:
		var pivot := f * Vector3(1.46, ROOM_TOP - .06, row.x)
		var aim := pivot + Vector3(row.y, -.5, -.05).normalized() * .15
		_kit.tube("room", [pivot + Vector3.UP * .02, pivot], .012, Color("#141416"), 5)
		_kit.tube("room", [pivot, aim], .036, Color("#1a1a1c"), 8)
		_kit.disc("lamp", aim + Vector3.DOWN * .002, Vector3.FORWARD, Vector3.RIGHT, .03, Color(1.0, .86, .62))
	# Dried stock hung head-down from a pipe over the aisle.
	var pipe := .86
	_kit.tube("room", [f * Vector3(pipe, ROOM_TOP - .26, -.9), f * Vector3(pipe, ROOM_TOP - .26, -4.2)], .011, Color("#3a3a38"), 6)
	for at: float in [-.9, -4.2]:
		_kit.tube("room", [f * Vector3(pipe, ROOM_TOP, at), f * Vector3(pipe, ROOM_TOP - .26, at)], .006, Color("#3a3a38"), 4)
	var tones: Array[Color] = [Color("#a8784e"), Color("#b89a6a"), Color("#7e4638"), Color("#c0ae8a"), Color("#8a5a44"), Color("#a08a5a")]
	for i: int in range(6):
		var tie := f * Vector3(pipe, ROOM_TOP - .3, -1.2 - float(i) * .54)
		for k: int in range(7):
			var a := float(k) * 2.4
			var tip := tie + Vector3(cos(a) * .07, -_rng.randf_range(.3, .46), sin(a) * .07)
			_kit.tube("room", [tie, tip], .0026, Color("#6a6040"), 3)
			_fleck(tip, Vector3(cos(a) * .4, -1, sin(a) * .4).normalized(), 6, .03, tones[i].darkened(_rng.randf() * .2))

func _cooler() -> void:
	# フラワーキーパー: three glass doors across the back of the room, cold white inside, stepped tiers.
	var f := _front
	var x0 := .24
	var x1 := 2.68
	var near := -6.62
	var far := -7.36
	var low := .2
	var top := 2.14
	var cold := Color("#65747a")
	_bar("room", f, (x0 + x1) * .5, .1, (near + far) * .5, Vector3(x1 - x0 + .1, .18, -far + near + .06), Color("#55585a"))
	_bar("room", f, (x0 + x1) * .5, top + .16, (near + far) * .5 + .02, Vector3(x1 - x0 + .1, .32, -far + near + .1), Color("#c9c9c2"))
	_bar("room", f, 1.46, top + .19, near + .04, Vector3(1.4, .14, .012), Color("#3c3e40"))
	for x: float in [x0 - .03, x1 + .03]:
		_bar("room", f, x, (low + top) * .5, (near + far) * .5, Vector3(.06, top - low, -far + near), Color("#c9c9c2"))
	_kit.quad("cold", f * Vector3(x0, low, far), f * Vector3(x0, top, far), f * Vector3(x1, top, far), f * Vector3(x1, low, far), cold * .92, .8, 1.0)
	_kit.quad("cold", f * Vector3(x0, low, near), f * Vector3(x0, top, near), f * Vector3(x0, top, far), f * Vector3(x0, low, far), cold * .8)
	_kit.quad("cold", f * Vector3(x1, low, far), f * Vector3(x1, top, far), f * Vector3(x1, top, near), f * Vector3(x1, low, near), cold * .8)
	_kit.quad("cold", f * Vector3(x0, top, far), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, far), cold * .8)
	_kit.quad("lamp", f * Vector3(x0 + .06, top - .004, near - .1), f * Vector3(x0 + .06, top - .004, near - .03), f * Vector3(x1 - .06, top - .004, near - .03), f * Vector3(x1 - .06, top - .004, near - .1), Color(.86, .94, 1.0) * .8)
	# Tiers rising to the back, a bucket every forty centimetres, each kind in its own row.
	var kinds: Array[Array] = [
		[["rose", [Color("#a81f2e"), Color("#8e1a26")]], ["lisianthus", [Color("#a874c0"), Color("#d8c4e4")]], ["carnation", [Color("#e88aa6")]], ["rose", [Color("#f1ece0")]], ["mum", [Color("#e8c23a")]], ["gerbera", [Color("#ef7a2e"), Color("#f2b23a")]]],
		[["lily", [Color("#f2efe4")]], ["rose", [Color("#f2b4b8")]], ["stock", [Color("#e8d8ec")]], ["tulip", [Color("#ef6a5a")]], ["gentian", [Color("#3a46a8")]], ["carnation", [Color("#c8284a")]]],
		[["stock", [Color("#f1ecd8")]], ["lily", [Color("#eda4c0")]], ["mum", [Color("#f1ece0")]], ["rose", [Color("#e8a23c")]], ["lisianthus", [Color("#f0e8ee")]], ["gentian", [Color("#5a4ab8")]]],
	]
	for tier: int in range(3):
		var y := low + .02 + float(tier) * .5
		var z := -6.86 - float(tier) * .2
		_bar("room", f, (x0 + x1) * .5, y - .012, z, Vector3(x1 - x0 - .04, .024, .24), Color("#8e9694"))
		for i: int in range(6):
			var x := x0 + .2 + float(i) * .405
			var row: Array = kinds[tier][i]
			var mouth := _bucket(f * Vector3(x, y, z), .2, .07, .095, Color("#3a3e40"), false, "room")
			_bunch(row[0], mouth, 10, .29, row[1], false)
	# Doors over it all: plain glass, bright rails, a long pull on each.
	var doors: Array[float] = [x0 - .02, 1.05, 1.87, x1 + .02]
	_kit.quad("front", f * Vector3(x0, low - .02, near + .03), f * Vector3(x0, top + .02, near + .03), f * Vector3(x1, top + .02, near + .03), f * Vector3(x1, low - .02, near + .03), Color.WHITE)
	var i2 := 0
	for x: float in doors:
		_bar("room", f, x, (low + top) * .5, near + .05, Vector3(.05, top - low + .06, .04), Color("#a8aaa8"))
		if i2 < 3:
			_bar("room", f, x + .1, 1.15, near + .09, Vector3(.022, .54, .03), Color("#d0d2d0"))
		i2 += 1
	for y: float in [low - .01, top + .02]:
		_bar("room", f, (x0 + x1) * .5, y, near + .05, Vector3(x1 - x0 + .04, .05, .04), Color("#a8aaa8"))

func _wrapping_bench() -> void:
	# ラッピング台 on the east wall: roll cutters, ribbon on a rod, a bouquet left half-wrapped.
	var f := _front
	var x := RX1 - .3
	var near := -2.4
	var far := -4.7
	var mid := (near + far) * .5
	var run := near - far
	_bar("timber", f, x, .875, mid, Vector3(.6, .05, run), Color(1.5, 1.32, 1.02))
	_bar("room", f, x + .27, .44, mid, Vector3(.04, .84, run), Color("#a8a59a"))
	_bar("room", f, x, .4, mid, Vector3(.54, .025, run), Color("#a8a59a"))
	for z: float in [near - .02, mid, far + .02]:
		_bar("room", f, x, .44, z, Vector3(.56, .84, .03), Color("#b4b1a4"))
	# Under it: folded sheets in pigeonholes, vases out of the season.
	for i: int in range(5):
		var z := near - .3 - float(i) * .4
		for k: int in range(4 + i % 3):
			_bar("room", f, x + .02, .425 + float(k) * .018, z, Vector3(.42, .014, .3), [Color("#e8e2d0"), Color(1.5, 1.32, 1.02), Color("#c8d8c4"), Color("#e4c4c8")][(k + i) % 4])
		_kit.lathe("room", f * Vector3(x, .03, z), [Vector2(.08, 0), Vector2(.1, .2), Vector2(.06, .28), Vector2(.075, .34)], [Color("#d8d4c6"), Color("#8ea69a"), Color("#c4c8c8")][i % 3], 10)
	# Roll cutters on the wall: kraft below, white above, the loose end hanging over a steel bar.
	var wall := RX1 - .06
	var rolls: Array[Array] = [[1.16, Color("#b08a56")], [1.46, Color("#e6e2d6")], [1.76, Color("#b7cdbc")]]
	for row: Array in rolls:
		var y: float = row[0]
		_kit.tube("room", [f * Vector3(wall - .04, y, near - .15), f * Vector3(wall - .04, y, far + .15)], .058, row[1], 12)
		for z: float in [near - .15, far + .15]:
			_bar("room", f, wall - .02, y, z, Vector3(.1, .03, .02), Color("#2c2c2e"))
			_kit.disc("room", f * Vector3(wall - .04, y, z), Vector3.FORWARD, Vector3.UP, .058, (row[1] as Color).darkened(.2))
		_bar("room", f, wall - .11, y - .08, mid, Vector3(.016, .03, run - .32), Color("#a8aaa8"))
		_kit.quad("room", f * Vector3(wall - .12, y - .18, near - .2), f * Vector3(wall - .12, y - .06, near - .2), f * Vector3(wall - .12, y - .06, far + .2), f * Vector3(wall - .12, y - .18, far + .2), (row[1] as Color).darkened(.06), .9, 1.0)
	# Ribbon spools on a rod.
	var ribbons: Array[Color] = [Color("#b02a30"), Color("#e8e2d0"), Color("#d8a4b0"), Color("#3f6a50"), Color("#d8b050"), Color("#6a5a90"), Color("#f0e8e8"), Color("#2a2a30")]
	_kit.tube("room", [f * Vector3(wall - .08, 2.02, near - .3), f * Vector3(wall - .08, 2.02, far + .3)], .007, Color("#3a3a38"), 5)
	for i: int in range(8):
		var z := near - .5 - float(i) * .17
		_kit.tube("room", [f * Vector3(wall - .08, 2.02, z), f * Vector3(wall - .08, 2.02, z - .07)], .05, ribbons[i], 10)
		_kit.quad("room", f * Vector3(wall - .13, 1.8 - float(i % 3) * .05, z - .02), f * Vector3(wall - .13, 2.02, z - .02), f * Vector3(wall - .13, 2.02, z - .05), f * Vector3(wall - .13, 1.8 - float(i % 3) * .05, z - .05), ribbons[i])
	# On the top: a sheet of kraft, the half-wrapped bouquet, scissors, tape, a jar of pins.
	_kit.quad("room", f * Vector3(x - .22, .905, -3.0), f * Vector3(x - .22, .905, -3.72), f * Vector3(x + .2, .905, -3.72), f * Vector3(x + .2, .905, -3.0), Color("#b08a56"))
	var tied := f * Vector3(x, 1.0, -3.4)
	_kit.lathe("room", tied + Vector3(0, -.095, 0), [Vector2(.06, 0), Vector2(.07, .16)], Color("#c9d4d6"), 10)
	_kit.lathe("room", tied + Vector3(0, -.02, 0), [Vector2(.03, 0), Vector2(.08, .1), Vector2(.14, .22)], Color("#c8a26a"), 9)
	_rich = .5
	for i: int in range(6):
		var a := float(i) * 2.4
		var at := tied + Vector3(cos(a) * .08, .2, sin(a) * .08)
		_rose(at, Vector3(cos(a) * .3, 1, sin(a) * .3).normalized(), .03, Color("#e8a8b0") if i % 2 == 0 else Color("#f1ece0"))
	_bar("room", f, x - .1, .908, -2.8, Vector3(.03, .006, .18), Color("#a8aaa8"))
	_kit.lathe("room", f * Vector3(x + .12, .9, -4.1), [Vector2(.05, 0), Vector2(.05, .06), Vector2(.02, .07)], Color("#46484a"), 10)
	# Orders on a clip by the bench end.
	_kit.atlas("paper", f * Vector3(RX1 - .01, 1.18, -5.1), f * Vector3(RX1 - .01, 1.62, -5.1), f * Vector3(RX1 - .01, 1.62, -4.82), f * Vector3(RX1 - .01, 1.18, -4.82), _cell(1740, 500, 240, 320))
	# Sheet stock on end in a tin bin, a dozen tall rolls.
	var bin := f * Vector3(RX1 - .22, .02, -5.72)
	_kit.lathe("room", bin, [Vector2(.16, 0), Vector2(.17, .5), Vector2(.15, .5)], Color("#7c8080"), 12)
	for i: int in range(9):
		var a := float(i) * 2.4
		var r := .11 * sqrt(float(i) / 9.0)
		var foot := bin + Vector3(cos(a) * r, .1, sin(a) * r)
		_kit.tube("room", [foot, foot + Vector3(cos(a) * .03, _rng.randf_range(.95, 1.25), sin(a) * .03)], .025, [Color("#e6e2d6"), Color("#b08a56"), Color("#c8d8c4"), Color("#e4c4c8")][i % 4], 7)

func _west_wall() -> void:
	# Three cedar shelves of vases and baskets, buckets of the slow lines below, the till at the back.
	var f := _front
	var x := RX0 + .15
	for y: float in [1.02, 1.42, 1.82]:
		_bar("timber", f, x, y, -3.1, Vector3(.28, .03, 3.2), Color(1.4, 1.22, .96))
		for z: float in [-1.7, -3.1, -4.5]:
			_bar("room", f, RX0 + .03, y - .07, z, Vector3(.03, .14, .03), Color("#26262a"))
	var shapes: Array[Array] = [
		[[Vector2(.05, 0), Vector2(.06, .1), Vector2(.03, .2), Vector2(.042, .24)], Color("#dad6c8")],
		[[Vector2(.06, 0), Vector2(.08, .08), Vector2(.05, .15)], Color("#8ea69a")],
		[[Vector2(.04, 0), Vector2(.044, .26)], Color("#c9d4d6")],
		[[Vector2(.05, 0), Vector2(.09, .12), Vector2(.08, .18)], Color("#b86a4a")],
		[[Vector2(.035, 0), Vector2(.075, .09), Vector2(.03, .17), Vector2(.03, .22)], Color("#3e4a56")],
	]
	for y: float in [1.035, 1.435, 1.835]:
		var z := -1.68
		while z > -4.5:
			var row: Array = shapes[_rng.randi_range(0, 4)]
			var profile: Array[Vector2] = []
			for p: Vector2 in row[0]:
				profile.append(p)
			_kit.lathe("room", f * Vector3(x, y, z), profile, row[1], 10)
			z -= _rng.randf_range(.24, .38)
	_kit.atlas("paper", f * Vector3(RX0 + .01, 1.98 - .9, -5.5), f * Vector3(RX0 + .01, 1.98, -5.5), f * Vector3(RX0 + .01, 1.98, -4.86), f * Vector3(RX0 + .01, 1.98 - .9, -4.86), _cell(1420, 400, 300, 420))
	# Floor row: what has not sold fast enough to stand on the pavement.
	var row2: Array[Array] = [["carnation", [Color("#d8426a")]], ["mum", [Color("#f1ece0"), Color("#e4d870")]], ["rose", [Color("#d03048")]], ["gerbera", [Color("#f0b83a"), Color("#e8604a")]]]
	for i: int in range(4):
		var mouth := _bucket(f * Vector3(RX0 + .2, .02, -1.5 - float(i) * .6), .3, .08, .11, BUCKET, false, "room")
		_bunch(row2[i][0], mouth, 5, .4, row2[i][1], false)
	# Till: a cedar counter, a tablet, a palm pad, the shop's scales.
	var c := -5.72
	_bar("timber", f, .62, .84, c, Vector3(.9, .05, .56), Color(1.5, 1.32, 1.02))
	_bar("room", f, .62, .41, c, Vector3(.84, .8, .5), Color("#d0ccbc"))
	_bar("room", f, .46, .91, c, Vector3(.2, .1, .14), Color("#1c1e20"))
	_bar("led", f, .46, .92, c + .074, Vector3(.17, .08, .004), Color(.5, .7, .62) * .6)
	_bar("room", f, .86, .872, c + .1, Vector3(.1, .02, .13), Color("#141618"))
	_bar("led", f, .86, .884, c + .1, Vector3(.07, .004, .1), CYAN * .5)

func _window_display() -> void:
	# In the glass: a stepped cedar stage, a moth orchid for somebody's opening, pampas in a tall jar.
	var f := _front
	_bar("timber", f, .68, .46, -.56, Vector3(1.02, .04, .8), Color(1.4, 1.22, .96))
	_bar("room", f, .68, .22, -.56, Vector3(.98, .44, .76), Color("#8f8a7a"))
	_bar("timber", f, .68, .72, -.82, Vector3(1.02, .04, .28), Color(1.4, 1.22, .96))
	_bar("room", f, .68, .6, -.82, Vector3(.98, .2, .26), Color("#8f8a7a"))
	var rich := _rich
	_rich = 1.0
	# Moth orchid: two stems on wires, the flowers stepping down the arch.
	var pot := _pot(f * Vector3(.42, .48, -.42), .15, .07, .095, WHITE_POT)
	for s: float in [-1.0, 1.0]:
		var stem: Array[Vector3] = []
		for k: int in range(7):
			var t := float(k) / 6.0
			stem.append(pot + Vector3(s * .02 + s * t * t * .3, t * .66 - t * t * t * .2, .03 + t * .06))
		_kit.tube(_l, stem, .0034, Color("#3e5a36"), 3)
		for k: int in range(3, 7):
			_trumpet(stem[k] + Vector3(0, -.02, .02), Vector3(s * .25, .1, 1).normalized(), .05, Color("#f2eef0") if s > 0.0 else Color("#e9b8d0"))
	for i: int in range(7):
		var a := float(i) * .9
		_leaf(pot, Vector3(cos(a), .25, sin(a)).normalized(), .17, .07, .18, Color("#2f5a34"), 1.0, true)
	# Basket of mixed pots on the top step.
	var left := _basket(f * Vector3(.92, .74, -.8), .17, .1, .13)
	for i: int in range(4):
		var a := float(i) * 1.7
		_hydrangea(left + Vector3(cos(a) * .07, .08, sin(a) * .07 + .03), .065, Color("#8fb0e0"), Color("#5a6ac8"))
	for i: int in range(5):
		var a := float(i) * 1.3
		_leaf(left, Vector3(cos(a), .3, sin(a)).normalized(), .15, .1, .4, Color("#35583a"), 1.0, true)
	_rich = rich
	# Pampas jar stands in the corner and shows its plumes over the top of it all.
	var jar := f * Vector3(.26, .03, -1.0)
	_kit.lathe("room", jar, [Vector2(.08, 0), Vector2(.12, .2), Vector2(.09, .62), Vector2(.075, .7), Vector2(.09, .74)], Color("#4a4438"), 12)
	for i: int in range(6):
		var a := float(i) * 1.5 + .4
		var lean := Vector3(cos(a) * .22, 1.3, sin(a) * .12 + .08)
		var top := jar + Vector3.UP * .7 + lean
		_kit.tube("room", [jar + Vector3.UP * .6, jar + Vector3.UP * .7 + lean * .6, top], .004, Color("#c4b48a"), 3)
		for k: int in range(46):
			var t := float(k) / 46.0
			var at := (jar + Vector3.UP * .7 + lean * .6).lerp(top, t)
			var out := Vector3(cos(float(k) * 2.4), _rng.randf_range(1.1, 1.8), sin(float(k) * 2.4)).normalized()
			var long := .15 * sin(t * 2.8 + .3) * _rng.randf_range(.75, 1.1)
			_two(_l, at, at + out * long, at + out * long + Vector3(.005, 0, 0), at + Vector3(.007, 0, 0), Color("#e4d6b4").darkened(_rng.randf() * .12), .8, 1.0)

func _table() -> void:
	# Plain table down the middle of the west side: ready bouquets and baskets at hand height.
	var f := _front
	_bar("timber", f, .78, .72, -2.5, Vector3(.8, .04, 1.4), Color(1.32, 1.18, .94))
	for sx: float in [-.34, .34]:
		for sz: float in [-.62, .62]:
			_bar("room", f, .78 + sx, .35, -2.5 + sz, Vector3(.04, .7, .04), Color("#26262a"))
	_bar("room", f, .78, .2, -2.5, Vector3(.72, .025, 1.3), Color("#3a3a38"))
	var tones: Array[Array] = [["mum", [Color("#e8c23a"), Color("#f0a040")]], ["rose", [Color("#e8a8b0"), Color("#f1ece0")]], ["carnation", [Color("#c8284a"), Color("#f0e0e4")]]]
	for i: int in range(3):
		var pot := _basket(f * Vector3(.78 + (.1 if i == 1 else -.1), .74, -2.0 - float(i) * .46), .15, .1, .13)
		_bunch(tones[i][0], pot, 8, .15, tones[i][1], false)
	# Kraft cones on the shelf below, waiting for their ribbon.
	for i: int in range(4):
		var at := f * Vector3(.56 + float(i) * .15, .225, -2.2 - float(i) * .22)
		_kit.lathe("room", at, [Vector2(.03, 0), Vector2(.09, .14), Vector2(.13, .24)], Color("#c8a26a"), 9)
		_rose(at + Vector3(0, .26, .02), Vector3.UP, .04, [Color("#f1ece0"), Color("#d04a6a")][i % 2])

func _east_shelf() -> void:
	# Green plants on the wall near the door, and two ferns on chains in the first of the light.
	var f := _front
	var x := RX1 - .17
	for y: float in [.55, 1.0]:
		_bar("timber", f, x, y, -1.3, Vector3(.3, .03, 1.7), Color(1.32, 1.18, .94))
	for z: float in [-.56, -1.3, -2.04]:
		_bar("room", f, x + .1, .5, z, Vector3(.03, 1.0, .03), Color("#26262a"))
	var rich := _rich
	_rich = 1.0
	for row: Vector2 in [Vector2(.57, -.7), Vector2(.57, -1.5), Vector2(1.02, -1.0), Vector2(1.02, -1.9)]:
		var pot := _pot(f * Vector3(x, row.x, row.y), .16, .07, .1, [Color("#d8d4c6"), Color("#a06a48"), Color("#8ea69a")][_rng.randi_range(0, 2)])
		_fern(pot, 6, .34, Color("#3f7a44"), 7)
	for spot: Vector2 in [Vector2(2.2, -.75), Vector2(1.0, -.72)]:
		var top := f * Vector3(spot.x, ROOM_TOP, spot.y)
		var bowl := top + Vector3.DOWN * .86
		for a: float in [0.0, 2.1, 4.2]:
			_kit.tube("room", [top, bowl + Vector3(cos(a) * .12, 0, sin(a) * .12)], .0028, Color("#c4b48a"), 3)
		_kit.lathe("room", bowl + Vector3.DOWN * .1, [Vector2(.05, 0), Vector2(.12, .08), Vector2(.13, .12)], Color("#d8d4c6"), 10)
		_fern(bowl, 8, .55, Color("#487f40"), 8)
	_rich = rich

func _shop_front() -> void:
	# Plain anodised frame, one fixed light and a sliding leaf run back behind it for the day.
	var f := _front
	var z := -.09
	_kit.quad("front", f * Vector3(PANE.position.x, PANE.position.y, z), f * Vector3(PANE.position.x, PANE.end.y, z), f * Vector3(PANE.end.x, PANE.end.y, z), f * Vector3(PANE.end.x, PANE.position.y, z), Color.WHITE)
	for x: float in [PANE.position.x + .022, PANE.end.x - .01]:
		_bar("metal", f, x, PANE.get_center().y, z + .02, Vector3(.05, PANE.size.y, .08), ALUMINIUM)
	for y: float in [PANE.position.y + .022, PANE.end.y - .022]:
		_bar("metal", f, PANE.get_center().x, y, z + .02, Vector3(PANE.size.x, .045, .08), ALUMINIUM)
	_bar("metal", f, PANE.get_center().x, 2.3, z + .02, Vector3(PANE.size.x, .03, .06), ALUMINIUM)
	# Leaf parked behind the light, handle showing; its track across the threshold.
	_bar("metal", f, PANE.end.x + .02, 1.3, -.14, Vector3(.05, 2.5, .03), ALUMINIUM * .9)
	_bar("metal", f, GAP.get_center().x, .012, -.08, Vector3(GAP.size.x, .012, .07), STEEL)
	_bar("metal", f, GAP.get_center().x, HEAD - .04, -.1, Vector3(GAP.size.x, .08, .08), ALUMINIUM)
	# Shutter drum over the opening and its guide channels down each jamb.
	_bar("metal", f, (PANE.position.x + GAP.end.x) * .5, HEAD + .1, .05, Vector3(GAP.end.x - PANE.position.x + .08, .18, .12), Color("#a8ada4"))
	for x: float in [.1, GAP.end.x + .03]:
		_bar("metal", f, x, HEAD * .5, .025, Vector3(.05, HEAD, .05), Color("#8e9490"))

func _home_door() -> void:
	# The family's own door at the end of the tile, sage paint, a post slot and a palm pad.
	var f := _front
	var r := HOME
	var z := -.06
	_bar("wood", f, r.get_center().x, r.get_center().y, z - .02, Vector3(r.size.x - .03, r.size.y - .02, .03), SAGE)
	var groove := r.position.x + .13
	while groove < r.end.x - .05:
		_bar("plain", f, groove, .5, z - .003, Vector3(.006, .96, .004), SAGE.darkened(.4))
		groove += .12
	for y: float in [.04, .98, 2.1]:
		_bar("wood", f, r.get_center().x, y, z + .001, Vector3(r.size.x - .03, .05, .012), SAGE.lightened(.08))
	_bar("metal", f, r.get_center().x, r.end.y - .34, z + .003, Vector3(.34, .46, .012), Color("#4c5a52"))
	_kit.quad("front", f * Vector3(r.position.x + .15, r.end.y - .55, z + .02), f * Vector3(r.position.x + .15, r.end.y - .13, z + .02), f * Vector3(r.end.x - .15, r.end.y - .13, z + .02), f * Vector3(r.end.x - .15, r.end.y - .55, z + .02), Color.WHITE)
	_bar("metal", f, r.get_center().x, 1.0, z + .003, Vector3(.24, .05, .012), Color("#b8ae88"))
	_kit.tube("metal", [f * Vector3(r.position.x + .07, 1.0, z + .03), f * Vector3(r.position.x + .07, 1.14, z + .03)], .009, Color("#b8ae88"), 5)
	_panel("paper", f, 3.08, 3.42, 2.24, 2.37, .014, _cell(1740, 400, 240, 90))
	_bar("plain", f, 3.25, 2.305, .005, Vector3(.37, .16, .012), Color("#7a6c54"))
	# 2050: palm pad in the old bell's plate.
	_bar("metal", f, 2.87, 1.26, .012, Vector3(.07, .12, .024), Color("#1a1b1e"))
	_bar("led", f, 2.87, 1.26, .026, Vector3(.045, .08, .004), GREEN * .35)
	# Tin hood over it and a caged lamp.
	_bar("metal", f, r.get_center().x, 2.66, .16, Vector3(.82, .03, .34), SAGE.darkened(.2), .8, 1.0)
	_bar("metal", f, r.get_center().x, 2.6, .012, Vector3(.82, .1, .02), SAGE.darkened(.3))
	_kit.tube("metal", [f * Vector3(3.25, 2.62, .24), f * Vector3(3.25, 2.5, .24)], .006, Color("#1a1a1c"), 4)
	_kit.lathe("metal", f * Vector3(3.25, 2.42, .24), [Vector2(.08, 0), Vector2(.05, .08)], Color("#2a2c2a"), 10)
	_kit.disc("lamp", f * Vector3(3.25, 2.425, .24), Vector3.FORWARD, Vector3.RIGHT, .045, Color(1.0, .82, .56))

func _blind() -> void:
	# Fixed テント: canvas over a light steel frame, sagging a finger's depth between ribs.
	var f := _front
	var x0 := .06
	var x1 := 2.86
	var rows := 4
	var cols := 12
	var y_top := 3.08
	var y_low := 2.72
	var reach := 1.12
	var top := _cell(0, 0, 1024, 420)
	var hem := _cell(0, 430, 1024, 110)
	var at := func(u: float, v: float) -> Vector3:
		var sag := -.02 * sin(v * PI) * absf(sin(u * PI * 3.0))
		var bow := sin(v * PI) * .05
		return Vector3(lerpf(x0, x1, u), lerpf(y_top, y_low, v) + bow + sag, .03 + (reach - .03) * v)
	for r: int in range(rows):
		var v0 := float(r) / float(rows)
		var v1 := float(r + 1) / float(rows)
		for c: int in range(cols):
			var u0 := float(c) / float(cols)
			var u1 := float(c + 1) / float(cols)
			var a: Vector3 = at.call(u0, v1)
			var b: Vector3 = at.call(u0, v0)
			var cc: Vector3 = at.call(u1, v0)
			var d: Vector3 = at.call(u1, v1)
			var shade := .9 + .1 * cos(u0 * PI * 6.0)
			var cut := Rect2(top.position.x + top.size.x * u0, top.position.y + top.size.y * v0, top.size.x / float(cols), top.size.y / float(rows))
			_kit.atlas("cloth", f * a, f * b, f * cc, f * d, cut, Color(shade, shade, shade), 1.0, .12)
			_kit.quad("plain", f * d, f * cc, f * b, f * a, Color("#39594a"), .75, .85)
	for c: int in range(cols):
		var u0 := float(c) / float(cols)
		var u1 := float(c + 1) / float(cols)
		var a0 := lerpf(x0, x1, u0)
		var a1 := lerpf(x0, x1, u1)
		var w0 := reach + .012 + sin(u0 * 16.0) * .012
		var w1 := reach + .012 + sin(u1 * 16.0) * .012
		var cut := Rect2(hem.position.x + hem.size.x * u0, hem.position.y, hem.size.x / float(cols), hem.size.y)
		_kit.atlas("cloth", f * Vector3(a0, y_low - .23, w0), f * Vector3(a0, y_low + .005, reach), f * Vector3(a1, y_low + .005, reach), f * Vector3(a1, y_low - .23, w1), cut, Color.WHITE, .95)
		_kit.quad("plain", f * Vector3(a1, y_low - .23, w1 - .003), f * Vector3(a1, y_low + .005, reach - .003), f * Vector3(a0, y_low + .005, reach - .003), f * Vector3(a0, y_low - .23, w0 - .003), Color("#2e4539"), .8, .9)
	# Steel: a wall rail, a front rail, ribs, two struts back to the wall.
	var steel := Color("#51605a")
	_kit.tube("metal", [f * Vector3(x0, y_top - .02, .03), f * Vector3(x1, y_top - .02, .03)], .018, steel, 6)
	_kit.tube("metal", [f * Vector3(x0, y_low - .012, reach), f * Vector3(x1, y_low - .012, reach)], .016, steel, 6)
	for u: float in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		var points: Array[Vector3] = []
		for k: int in range(5):
			var v := float(k) / 4.0
			points.append(f * ((at.call(u, v) as Vector3) + Vector3.DOWN * .02))
		_kit.tube("metal", points, .011, steel, 5)
	for x: float in [.14, 2.78]:
		_kit.tube("metal", [f * Vector3(x, 2.34, .03), f * Vector3(x, y_low - .02, reach * .9)], .012, steel, 5)
	# Two small lamps under the frame: the stock is what gets lit, not the sign.
	for x: float in [.68, 2.3]:
		var can := f * Vector3(x, 2.84, .62)
		_kit.lathe("metal", can + Vector3.DOWN * .12, [Vector2(.05, 0), Vector2(.036, .12)], Color("#1a1a1c"), 8)
		_kit.disc("lamp", can + Vector3.DOWN * .119, Vector3.FORWARD, Vector3.RIGHT, .042, Color(1.0, .84, .6))

func _signboard() -> void:
	# A long cedar board over the blind, letters and a thrush in the grandfather's own green.
	var f := _front
	_kit.block("wood", _at(f, 1.82, 3.32, .03), Vector3(2.5, .38, .05), Color(.93, .9, .78), .9, 1.0, .25)
	for y: float in [3.2, 3.32, 3.44]:
		_bar("plain", f, 1.82, y, .057, Vector3(2.5, .006, .004), Color("#8a846e"))
	_panel("decal", f, .78, 2.86, 3.13, 3.51, .058, _cell(0, 572, 1000, 240))
	for x: float in [.68, 2.96]:
		_bar("metal", f, x, 3.32, .04, Vector3(.03, .4, .08), Color("#3a3c3a"))

func _upper_wall() -> void:
	# Cream render, a concrete band for each floor slab, a run of fibre and the pipe from the roof.
	var f := _front
	_skin("render", f, Rect2(0, GROUND, WIDE, EAVE - GROUND), [LOGGIA, SLIT], RENDER)
	_kit.quad("render", f * Vector3(0, EAVE, 0), f * Vector3(0, EAVE + .002, 0), f * Vector3(WIDE, RIDGE, 0), f * Vector3(WIDE, EAVE, 0), RENDER, .95, 1.0, .5, Vector2(0, -EAVE))
	_bar("plain", f, WIDE * .5, GROUND + .02, .02, Vector3(WIDE, .1, .05), Color("#9a988c"), .75, 1.0)
	_bar("plain", f, WIDE * .5, SECOND, .012, Vector3(WIDE, .06, .03), Color("#a6a498"), .8, 1.0)
	# Vent in the top of the gable.
	var vent := f * Vector3(3.0, 8.82, .02)
	_kit.disc("plain", vent, Vector3.RIGHT, Vector3.UP, .09, Color("#3a3c3a"))
	_kit.lathe("metal", vent + Vector3.DOWN * 0, [Vector2(.1, 0), Vector2(.1, .012)], Color("#b8b6a8"), 12)
	# Rainwater pipe from the low eave, then the fibre that followed it down.
	_kit.tube("plain", [f * Vector3(.05, EAVE - .02, .22), f * Vector3(.05, EAVE - .3, .07), f * Vector3(.05, .1, .07)], .036, Color("#bdbcb0"), 8)
	var y := 1.3
	while y < EAVE:
		_bar("metal", f, .05, y, .05, Vector3(.1, .03, .1), STEEL)
		y += 2.1
	_fibre([f * Vector3(3.6, EAVE + .4, .04), f * Vector3(3.6, 3.7, .04), f * Vector3(3.58, 2.76, .04)])
	_camera(f * Vector3(2.88, 2.98, .16))
	_window(f, SLIT, .43, true)
	# 2050: the wholesaler's drone shelf by the slit window, one crate left on it.
	_bar("metal", f, 3.3, 6.42, .25, Vector3(.6, .04, .5), Color("#3a3d40"))
	_bar("metal", f, 3.3, 6.6, .03, Vector3(.6, .32, .05), Color("#2a2c2f"))
	_strip(f * Vector3(3.02, 6.445, .49), f * Vector3(3.58, 6.445, .49), CYAN * .55)
	_status(f, 3.54, 6.7, .06, GREEN)
	_bar("plain", f, 3.28, 6.53, .24, Vector3(.34, .18, .26), Color("#b49a6e"))

func _balcony() -> void:
	# A deep loggia dug out of the first floor, thick with pots: the family's whole garden.
	var f := _front
	var r := LOGGIA
	var back := -1.1
	var wall := RENDER * .92
	_kit.quad("render", f * Vector3(r.position.x, r.position.y, 0), f * Vector3(r.position.x, r.end.y, 0), f * Vector3(r.position.x, r.end.y, back), f * Vector3(r.position.x, r.position.y, back), wall, .8, .75)
	_kit.quad("render", f * Vector3(r.end.x, r.position.y, back), f * Vector3(r.end.x, r.end.y, back), f * Vector3(r.end.x, r.end.y, 0), f * Vector3(r.end.x, r.position.y, 0), wall, .8, .75)
	_kit.quad("plain", f * Vector3(r.position.x, r.end.y, back), f * Vector3(r.position.x, r.end.y, 0), f * Vector3(r.end.x, r.end.y, 0), f * Vector3(r.end.x, r.end.y, back), Color("#a8a698"), .7, .7)
	_kit.quad("plain", f * Vector3(r.position.x, r.position.y, 0), f * Vector3(r.position.x, r.position.y, back), f * Vector3(r.end.x, r.position.y, back), f * Vector3(r.end.x, r.position.y, 0), Color("#8a7664"), .8, .8)
	var door := Rect2(.5, r.position.y, 2.7, r.size.y)
	var plate := Transform3D(Basis.IDENTITY, f.origin + Vector3(0, 0, back))
	_skin("render", plate, r, [door] as Array[Rect2], wall * .96, .85, .3)
	# Low parapet, a rail and pickets painted the same green as the blind.
	_kit.block("render", _at(f, WIDE * .5, r.position.y + .05, -.08), Vector3(r.size.x, .1, .16), RENDER, .9, 1.0, .5)
	var rail := Color("#4c6a5a")
	_kit.tube("metal", [f * Vector3(r.position.x, r.position.y + 1.02, .0), f * Vector3(r.end.x, r.position.y + 1.02, .0)], .02, rail, 6)
	var x := r.position.x + .08
	while x < r.end.x:
		_bar("metal", f, x, r.position.y + .67, -.0, Vector3(.012, .7, .012), rail)
		x += .13
	# Hanging trough outside, on hooks over the rail: white pelargonium, lavender, ivy over the lip.
	var y0 := r.position.y + .36
	_bar("plain", f, 1.5, y0 + .02, .17, Vector3(2.2, .13, .2), Color("#4a4f48"), .8, 1.0)
	_bar("plain", f, 1.5, y0 + .083, .17, Vector3(2.14, .012, .15), Color("#2c2219"))
	for hook: float in [.6, 1.5, 2.4]:
		_kit.tube("metal", [f * Vector3(hook, y0 + .08, .08), f * Vector3(hook, r.position.y + 1.06, .04), f * Vector3(hook, r.position.y + 1.0, -.03)], .006, rail, 4)
	var at := .46
	while at < 2.56:
		var c := f * Vector3(at, y0 + .09, .17)
		for i: int in range(5):
			var a := _rng.randf() * TAU
			_leaf(c, Vector3(cos(a), .55, sin(a) + .3).normalized(), .16, .14, .3, Color("#3f6838").lerp(Color("#5c8348"), _rng.randf()), .85)
		var bloom := c + Vector3(_rng.randf_range(-.04, .04), _rng.randf_range(.24, .34), .05)
		_kit.tube(_l, [c, bloom], .003, STEM, 3)
		for k: int in range(11):
			var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-.1, 1), _rng.randf_range(-.6, 1)).normalized()
			_fleck(bloom + d * .045, d, 5, .03, Color("#f4f0e6") if int(at * 10.0) % 3 != 0 else Color("#d8607a"))
		at += .14
	var strand := .42
	while strand < 2.6:
		_ivy(f * Vector3(strand, y0 + .08, .285), _rng.randf_range(.22, .5))
		strand += .155
	# Floor pots behind the rail: a yuzu with its fruit, a tree fern, herbs, watering can.
	var b := r.position.y
	var yuzu := _pot(f * Vector3(3.0, b, -.42), .34, .15, .2, Color("#a06a48"))
	_kit.tube("plain", [yuzu, yuzu + Vector3(.02, .55, 0), yuzu + Vector3(-.12, 1.2, .08)], .016, Color("#5a4a38"), 5)
	_kit.tube("plain", [yuzu + Vector3(.02, .55, 0), yuzu + Vector3(.2, 1.1, .1)], .011, Color("#5a4a38"), 5)
	for i: int in range(130):
		var a := float(i) * 2.4
		var r2 := .42 * sqrt(float(i) / 130.0) + .05
		var spot := yuzu + Vector3(cos(a) * r2, .6 + float(i % 11) * .085, sin(a) * r2 * .75)
		_leaf(spot, Vector3(cos(a), -.55, sin(a) + .6).normalized(), .19, .1, .2, Color("#2f5a30").lerp(Color("#4d7a3c"), _rng.randf()), 1.0)
		if i % 17 == 3:
			_ball(spot + Vector3(0, -.03, .05), Vector3(.036, .032, .036), Color("#e0b52c"), "plain", 5, 8)
	# Timber plant stand so the fern clears the rail.
	_bar("wood", f, .66, b + .46, -.42, Vector3(.5, .03, .4), Color("#8a7458"))
	for sx: float in [-.2, .2]:
		for sz: float in [-.15, .15]:
			_bar("wood", f, .66 + sx, b + .22, -.42 + sz, Vector3(.04, .46, .04), Color("#8a7458"))
	var fern := _pot(f * Vector3(.66, b + .475, -.42), .26, .12, .17, Color("#d8d4c6"))
	_fern(fern, 14, 1.0, Color("#4a7a3a"), 12)
	var herb := _pot(f * Vector3(1.32, b + .1, -.34), .24, .11, .15, Color("#a06a48"))
	for i: int in range(26):
		var a := float(i) * 2.4
		var rr := .12 * sqrt(float(i) / 26.0)
		var top := herb + Vector3(cos(a) * rr * 2.0, .46 + float(i % 4) * .05, sin(a) * rr * 2.0)
		_kit.tube(_l, [herb + Vector3(cos(a) * rr, 0, sin(a) * rr), top], .0026, Color("#6a8058"), 3)
		_spike(top + Vector3.DOWN * .12, top, Color("#8a74c0"), 8, .015)
	var can := f * Vector3(2.12, b + .01, -.46)
	_kit.lathe("metal", can, [Vector2(.1, 0), Vector2(.1, .22), Vector2(.05, .25)], Color("#a8aeb0"), 12)
	_kit.tube("metal", [can + Vector3(.09, .05, 0), can + Vector3(.32, .26, 0)], .012, Color("#a8aeb0"), 5)
	_kit.tube("metal", [can + Vector3(-.09, .05, 0), can + Vector3(-.18, .22, 0), can + Vector3(-.05, .3, 0)], .007, Color("#a8aeb0"), 4)
	# 2050: a soil probe in the yuzu's pot, because the grandmother insisted, with a pin of green.
	_kit.tube("metal", [yuzu + Vector3(.12, -.03, .1), yuzu + Vector3(.12, .12, .1)], .005, Color("#2a2c2e"), 4)
	_bar("led", Transform3D.IDENTITY, (yuzu + Vector3(.12, .13, .1)).x, (yuzu + Vector3(.12, .13, .1)).y, (yuzu + Vector3(.12, .13, .1)).z, Vector3(.018, .018, .018), GREEN * .5)

func _parlour() -> void:
	# The family's room behind the balcony door: table lamp on, curtain half across, books.
	var f := _front
	var y0 := LOGGIA.position.y
	var y1 := LOGGIA.end.y
	var x0 := .4
	var x1 := 3.3
	var near := -1.14
	var far := -3.9
	var paper := Color("#c8b890")
	_kit.quad("wall", f * Vector3(x0, y0, far), f * Vector3(x0, y1, far), f * Vector3(x1, y1, far), f * Vector3(x1, y0, far), paper, .75, .95)
	_kit.quad("wall", f * Vector3(x0, y0, near), f * Vector3(x0, y1, near), f * Vector3(x0, y1, far), f * Vector3(x0, y0, far), paper * .94, .75, .9)
	_kit.quad("wall", f * Vector3(x1, y0, far), f * Vector3(x1, y1, far), f * Vector3(x1, y1, near), f * Vector3(x1, y0, near), paper * .9, .75, .9)
	_kit.quad("timber", f * Vector3(x0, y0, near), f * Vector3(x0, y0, far), f * Vector3(x1, y0, far), f * Vector3(x1, y0, near), Color("#9a7448"), .75, .85)
	_kit.quad("room", f * Vector3(x0, y1, far), f * Vector3(x0, y1, near), f * Vector3(x1, y1, near), f * Vector3(x1, y1, far), Color("#d0c8b0"), .8, .9)
	# Round paper shade over a low table, zaisu cushions, the bookcase with the family albums.
	var lamp := f * Vector3(1.9, y1 - .5, -2.3)
	_kit.tube("room", [lamp + Vector3.UP * .5, lamp + Vector3.UP * .12], .004, Color("#2a2a28"), 3)
	_ball(lamp, Vector3(.22, .15, .22), Color(1.0, .86, .62), "lamp", 6, 12)
	_bar("timber", f, 1.9, y0 + .34, -2.3, Vector3(1.0, .04, .7), Color("#7a5634"))
	for sx: float in [-.44, .44]:
		for sz: float in [-.28, .28]:
			_bar("timber", f, 1.9 + sx, y0 + .16, -2.3 + sz, Vector3(.05, .32, .05), Color("#5e4228"))
	var vase := f * Vector3(1.9, y0 + .36, -2.3)
	_kit.lathe("room", vase, [Vector2(.04, 0), Vector2(.06, .08), Vector2(.03, .17)], Color("#8ea69a"), 10)
	var rich := _rich
	_p = "bloom"
	_l = "frond"
	_rich = .5
	_bunch("rose", vase + Vector3.UP * .17, 5, .24, [Color("#f0d8d0"), Color("#e8a8b0")], false)
	_p = "petal"
	_l = "leaf"
	_rich = rich
	_bar("room", f, 2.5, y0 + .05, -2.0, Vector3(.5, .08, .5), Color("#6e4a5a"))
	_bar("room", f, 1.2, y0 + .05, -2.5, Vector3(.5, .08, .5), Color("#4c6a78"))
	_bar("room", f, 1.9, y0 + .85, far + .17, Vector3(2.2, 1.7, .3), Color("#5e4228"))
	for shelf: int in range(4):
		var y := y0 + .12 + float(shelf) * .42
		var x := .86
		while x < 2.95:
			var thick := _rng.randf_range(.03, .07)
			_bar("room", f, x, y + .15, far + .335, Vector3(thick, _rng.randf_range(.2, .3), .02), [Color("#a84a3a"), Color("#d8ceb0"), Color("#3a5a6a"), Color("#c8a048"), Color("#6a7a5a")][_rng.randi_range(0, 4)] as Color)
			x += thick + .008
	# Glass door with two leaves, one open a hand, and the unbleached curtain gathered to one side.
	var door := Rect2(.5, y0 + .02, 2.7, y1 - y0 - .08)
	var z := -1.1
	_kit.quad("front", f * Vector3(door.position.x, door.position.y, z), f * Vector3(door.position.x, door.end.y, z), f * Vector3(door.end.x, door.end.y, z), f * Vector3(door.end.x, door.position.y, z), Color.WHITE)
	for x: float in [door.position.x + .025, door.get_center().x, door.end.x - .025]:
		_bar("metal", f, x, door.get_center().y, z + .02, Vector3(.05, door.size.y, .06), ALUMINIUM)
	for y: float in [door.position.y + .025, door.end.y - .025]:
		_bar("metal", f, door.get_center().x, y, z + .02, Vector3(door.size.x, .05, .06), ALUMINIUM)
	_curtain(.56, 1.42, y0 + .1, y1 - .08, -1.2)

func _curtain(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	var f := _front
	var x := x0
	var out := true
	while x < x1 - .01:
		var next := minf(x + .05, x1)
		var a := z - (.0 if out else .05)
		var b := z - (.05 if out else .0)
		_kit.quad("room", f * Vector3(x, y0, a), f * Vector3(x, y1, a), f * Vector3(next, y1, b), f * Vector3(next, y0, b), Color("#e6dcc0") * (1.0 if out else .78), .85, 1.0)
		out = not out
		x = next

func _bay() -> void:
	# The grandmother's 出窓, boxed out in sheet and render, an iron box of pinks hung beneath it.
	var f := _front
	var d := .3
	var plate := Transform3D(Basis.IDENTITY, f.origin + Vector3(0, 0, d))
	var outer := Rect2(.34, 6.5, 1.96, 1.48)
	_skin("render", plate, outer, [BAY] as Array[Rect2], RENDER * 1.02, .95, .4)
	_kit.quad("render", f * Vector3(outer.position.x, outer.position.y, 0), f * Vector3(outer.position.x, outer.end.y, 0), f * Vector3(outer.position.x, outer.end.y, d), f * Vector3(outer.position.x, outer.position.y, d), RENDER * .92, .9, 1.0, .4)
	_kit.quad("render", f * Vector3(outer.end.x, outer.position.y, d), f * Vector3(outer.end.x, outer.end.y, d), f * Vector3(outer.end.x, outer.end.y, 0), f * Vector3(outer.end.x, outer.position.y, 0), RENDER * .92, .9, 1.0, .4)
	_kit.quad("plain", f * Vector3(outer.position.x, outer.position.y, d), f * Vector3(outer.position.x, outer.position.y, 0), f * Vector3(outer.end.x, outer.position.y, 0), f * Vector3(outer.end.x, outer.position.y, d), RENDER * .7, .7, .7)
	_kit.quad("tin", f * Vector3(outer.position.x - .04, outer.end.y, d + .06), f * Vector3(outer.position.x - .04, outer.end.y + .1, 0), f * Vector3(outer.end.x + .04, outer.end.y + .1, 0), f * Vector3(outer.end.x + .04, outer.end.y, d + .06), SAGE, .9, 1.0, .3)
	_window(plate, BAY, .61, false)
	# Iron basket on two brackets, pinks spilling over the bars.
	var y := outer.position.y - .17
	_bar("metal", f, 1.32, y, d + .08, Vector3(1.5, .02, .2), Color("#2c2e2c"))
	for s: float in [-.72, -.36, 0.0, .36, .72]:
		_bar("metal", f, 1.32 + s, y + .08, d + .18, Vector3(.012, .16, .012), Color("#2c2e2c"))
	_kit.tube("metal", [f * Vector3(.57, y + .16, d + .18), f * Vector3(2.07, y + .16, d + .18)], .007, Color("#2c2e2c"), 4)
	_bar("plain", f, 1.32, y + .07, d + .08, Vector3(1.42, .13, .15), Color("#3e3226"))
	for i: int in range(16):
		var c := f * Vector3(.64 + float(i) * .09, y + .14, d + .1)
		for k: int in range(3):
			_leaf(c, Vector3(_rng.randf_range(-.8, .8), .35, _rng.randf_range(.1, .9)).normalized(), .15, .04, .6, Color("#54785a").lightened(_rng.randf() * .15))
		var top := c + Vector3(_rng.randf_range(-.05, .05), _rng.randf_range(.08, .2), .1)
		_kit.tube(_l, [c, top], .002, STEM, 3)
		_carnation(top, Vector3(0, .6, .8).normalized(), .034, Color("#d8588a") if i % 3 != 1 else Color("#f0e0e4"))
	var strand := .62
	while strand < 2.04:
		_ivy(f * Vector3(strand, y + .1, d + .19), _rng.randf_range(.16, .42))
		strand += .17

func _roof() -> void:
	# One thin plane of painted tin, low at the estate agent's wall, high at the east side.
	var half := WIDE * .5
	var out := .26
	var west := Vector3(-half + .02, EAVE - .02, out)
	var east := Vector3(half - .02, RIDGE - .02, out)
	var west2 := Vector3(-half + .02, EAVE - .02, -DEEP - .1)
	var east2 := Vector3(half - .02, RIDGE - .02, -DEEP - .1)
	var lift := Vector3.UP * .05
	var tin := Color("#a6b4aa")
	_kit.quad("tin", west + lift, west2 + lift, east2 + lift, east + lift, tin, .95, 1.0, .5)
	_kit.quad("plain", east, east2, west2, west, Color("#6e7468"), .7, .7)
	var z := out - .25
	while z > -DEEP:
		_kit.beam("metal", west + lift + Vector3(0, .02, z - out), east + lift + Vector3(0, .02, z - out), .024, .03, Vector3.UP, tin.darkened(.12))
		z -= .42
	# Fascia up the slope, the barge board, a gutter along the low side.
	_kit.beam("wood", west + Vector3(0, .02, .01), east + Vector3(0, .02, .01), .03, .14, Vector3.UP, Color(.9, .9, .82))
	_kit.beam("wood", west2 + Vector3(0, .02, -.01), east2 + Vector3(0, .02, -.01), .03, .14, Vector3.UP, Color(.84, .84, .76))
	_kit.tube("plain", [west + Vector3(.02, -.03, .02), west2 + Vector3(.02, -.03, 0)], .05, Color("#bdbcb0"), 8)
	# Rafter ends showing under the overhang.
	for x: float in [.3, .9, 1.5, 2.1, 2.7, 3.3]:
		var p := west.lerp(east, x / WIDE)
		_bar("plain", Transform3D.IDENTITY, p.x, p.y - .05, .12, Vector3(.06, .1, .3), Color("#c4c2b2"))
	# 2050: two modules laid on the slope, with the battery's lead into the barge board.
	var angle := atan2(RIDGE - EAVE, WIDE)
	var slope := Vector3(cos(angle), sin(angle), 0)
	var n := Vector3(-sin(angle), cos(angle), 0)
	var centre := Vector3(0, (EAVE + RIDGE) * .5, 0)
	for at: float in [-3.8, -5.7]:
		_solar_module(Transform3D(Basis(slope, Vector3(0, 0, -1), n), centre + Vector3(0, 0, at) + n * .11), 3.0, 1.7)
	_fibre([Vector3(half - .1, RIDGE - .3, -2.8), Vector3(half - .1, RIDGE - .1, -3.0)])

func _flanks() -> void:
	# Plain render on the sides, a little frosted lavatory window, the air conditioner on a bracket.
	var east_holes: Array[Rect2] = [Rect2(5.0, 4.5, .7, .9), Rect2(5.0, 7.0, .7, .9)]
	var west_holes: Array[Rect2] = [Rect2(6.8, 4.5, .7, .9)]
	_render_wall(_east, DEEP, RIDGE, GROUND, SECOND - GROUND, RENDER * .9, east_holes, .75)
	_render_wall(_west, DEEP, EAVE, GROUND, SECOND - GROUND, RENDER * .86, west_holes, .75)
	_render_wall(_back, WIDE, EAVE, GROUND, SECOND - GROUND, RENDER * .84, [] as Array[Rect2], .6)
	_kit.quad("render", _back * Vector3(0, EAVE, 0), _back * Vector3(0, RIDGE, 0), _back * Vector3(WIDE, EAVE + .002, 0), _back * Vector3(WIDE, EAVE, 0), RENDER * .84, .95, 1.0, .5)
	for r: Rect2 in east_holes:
		_window(_east, r, .19, false)
	_window(_west, west_holes[0], .83, false)
	_outdoor_unit(_east, 3.0, 5.0, .2)
	_bar("metal", _east, 3.0, 4.66, .16, Vector3(.9, .04, .34), STEEL)
	_kit.tube("plain", [_east * Vector3(2.4, 5.2, .05), _east * Vector3(2.1, 5.0, .05), _east * Vector3(2.1, .1, .05)], .018, Color("#c4c2b6"), 6)

# --- The stock on the pavement.

func _stock_stand() -> void:
	# Black wire stand on casters, three tiers of tapered buckets stepped up to the glass.
	var f := _front
	var wire := Color("#141517")
	var xs: Array[float] = [.29, .66, 1.03]
	var tiers: Array[Vector2] = [Vector2(.1, 1.02), Vector2(.36, .62), Vector2(.64, .24)]
	var rows: Array[Array] = [
		[["tulip", [Color("#f2d24a"), Color("#ef6a5a")], 10, .36, 5], ["gerbera", [Color("#ef7a2e"), Color("#f2b23a"), Color("#e84a68")], 10, .38, 3], ["carnation", [Color("#e88aa6"), Color("#f4dfe2")], 13, .36, 2]],
		[["rose", [Color("#a81f2e"), Color("#b82438")], 14, .42, 0], ["gentian", [Color("#3a46a8"), Color("#5a4ab8")], 11, .46, 6], ["mum", [Color("#e8c23a"), Color("#f1ece0")], 13, .4, 4]],
		[["lily", [Color("#f2efe4")], 8, .5, 1], ["stock", [Color("#efe0ee"), Color("#b890c8")], 10, .5, 8], ["rose", [Color("#f2b4b8"), Color("#f4e6d8")], 13, .44, 0]],
	]
	for t: int in range(3):
		var y := tiers[t].x
		var z := tiers[t].y
		# The hoop rail each row of buckets drops through, with a floor tray under it.
		for k: int in range(2):
			var h := y + .06 + float(k) * .15
			_kit.tube("metal", [f * Vector3(.12, h, z - .11), f * Vector3(1.2, h, z - .11)], .006, wire, 4)
			_kit.tube("metal", [f * Vector3(.12, h, z + .11), f * Vector3(1.2, h, z + .11)], .006, wire, 4)
		_kit.tube("metal", [f * Vector3(.12, y, z - .12), f * Vector3(1.2, y, z - .12)], .007, wire, 4)
		_kit.tube("metal", [f * Vector3(.12, y, z + .12), f * Vector3(1.2, y, z + .12)], .007, wire, 4)
		for x: float in [.12, .475, .845, 1.2]:
			_kit.tube("metal", [f * Vector3(x, y, z + .12), f * Vector3(x, y, z - .12)], .006, wire, 4)
		for i: int in range(3):
			var row: Array = rows[t][i]
			var mouth := _bucket(f * Vector3(xs[i], y, z), .26, .075, .112, BUCKET)
			_bunch(row[0], mouth, row[2], row[3], row[1])
			_card(mouth, .112, row[4])
	# Uprights stepping up with the tiers, a pair of diagonals, and four rubber casters.
	for x: float in [.12, 1.2]:
		for row: Vector3 in [Vector3(.0, 1.14, .3), Vector3(.0, .74, .56), Vector3(.0, .36, .86), Vector3(.0, .12, .86)]:
			_kit.tube("metal", [f * Vector3(x, .07, row.y), f * Vector3(x, row.z, row.y)], .008, wire, 4)
		_kit.tube("metal", [f * Vector3(x, .07, 1.14), f * Vector3(x, .07, .12)], .008, wire, 4)
		for z: float in [1.14, .12]:
			_kit.lathe("metal", f * Vector3(x, .0, z), [Vector2(.022, 0), Vector2(.03, .03), Vector2(.012, .07)], Color("#26262a"), 7)

func _plant_bench() -> void:
	# Green slatted bench, paint worn at the edge, pots and sleeved mandevilla along it.
	var f := _front
	var x0 := 1.96
	var x1 := 2.72
	var y := .42
	var green := Color("#4f7a62")
	for i: int in range(5):
		var z := .3 + float(i) * .155
		_bar("wood", f, (x0 + x1) * .5, y, z, Vector3(x1 - x0, .025, .12), green.lightened(_rng.randf_range(-.08, .08)))
	for x: float in [x0 + .05, x1 - .05]:
		_bar("metal", f, x, y * .5, .34, Vector3(.03, y - .02, .03), Color("#26282a"))
		_bar("metal", f, x, y * .5, .9, Vector3(.03, y - .02, .03), Color("#26282a"))
		_bar("metal", f, x, y - .03, .62, Vector3(.035, .03, .74), Color("#26282a"))
	# Pink lacecap hydrangea, then a pale green one, as they stand in the photographs.
	var one := _pot(f * Vector3(2.16, y + .012, .44), .18, .07, .1, WHITE_POT)
	_hydrangea(one + Vector3(-.07, .26, .08), .095, Color("#d85a9a"), Color("#f08ab8"))
	_hydrangea(one + Vector3(.08, .3, -.02), .085, Color("#d85a9a"), Color("#f4a0c4"))
	_hydrangea(one + Vector3(0, .2, -.09), .08, Color("#c84a8a"), Color("#e87aa8"))
	var two := _pot(f * Vector3(2.54, y + .012, .5), .18, .07, .1, Color("#26282a"))
	_hydrangea(two + Vector3(-.08, .24, .07), .1, Color("#dfe6c4"), Color("#f0dcd8"))
	_hydrangea(two + Vector3(.08, .28, 0), .09, Color("#d4e0b8"), Color("#f0e0d8"))
	for spot: Vector3 in [one, two]:
		for i: int in range(8):
			var a := float(i) * 2.4
			_leaf(spot + Vector3(cos(a) * .03, .04, sin(a) * .03), Vector3(cos(a), .6, sin(a)).normalized(), .17, .11, .35, Color("#2e5a34").lerp(Color("#3f6e3c"), _rng.randf()), 1.0, i % 2 == 0)
	_card(one + Vector3(-.03, .02, .02), .1, 9)
	# Mandevilla on a hoop, trumpets in crimson, its pot in a clear sleeve.
	var three := _pot(f * Vector3(2.36, y + .012, .84), .14, .06, .08, BUCKET)
	_kit.lathe("front", three + Vector3.DOWN * .1, [Vector2(.08, 0), Vector2(.11, .1), Vector2(.16, .24)], Color.WHITE, 8)
	for i: int in range(5):
		var a := float(i) * 1.3
		var top := three + Vector3(cos(a) * .13, .3 + float(i % 2) * .08, sin(a) * .1 + .02)
		_kit.tube(_l, [three, three.lerp(top, .5) + Vector3.UP * .05, top], .0028, Color("#5a4a30"), 3)
		for k: int in range(4):
			var d := Vector3(cos(a + float(k) * 1.6), .35, sin(a + float(k) * 1.6)).normalized()
			_leaf(three.lerp(top, .4 + float(k) * .17), d, .09, .05, .2, Color("#2f6030"), .95)
		_trumpet(top, (Vector3(cos(a) * .6, .35, .9)).normalized(), .046, Color("#c82a48"))
	_card(three, .08, 10)
	# Chalk board wired to the front rail.
	var c := Vector3(0, 0, 1.0)
	_panel("paper", f, x0 + .06, x1 - .06, .06, .39, c.z + .012, _cell(1040, 400, 360, 300))
	_bar("plain", f, (x0 + x1) * .5, .225, c.z, Vector3(x1 - x0 - .1, .35, .02), Color("#3a2c1e"))
	for x: float in [x0 + .12, x1 - .12]:
		_kit.tube("metal", [f * Vector3(x, .38, c.z + .012), f * Vector3(x, y, .96)], .002, Color("#b8b8b0"), 3)

func _pavement_things() -> void:
	# What stands round the bench: a fiddle-leaf fig, cut branches, the hose, the morning's overflow.
	var f := _front
	# Fiddle-leaf fig in a white pot against the jamb.
	var fig := _pot(f * Vector3(2.92, 0, .36), .3, .13, .18, WHITE_POT)
	_kit.tube("plain", [fig, fig + Vector3(.02, .5, 0), fig + Vector3(-.03, 1.02, .02)], .017, Color("#7a6248"), 6)
	for i: int in range(26):
		var t := float(i) / 26.0
		var a := float(i) * 2.4
		var at := fig + Vector3(-.03 * t, .34 + t * .72, 0)
		var dir := Vector3(cos(a), .25 + t * .9, sin(a) * .8 + .3).normalized()
		_leaf(at, dir, .36 - t * .12, .27 - t * .08, .32, Color("#2e5a30").lerp(Color("#44743c"), _rng.randf()), 1.5, true)
	# Long branches in a zinc pail, the tallest thing out here: pale blossom, bare wood.
	var pail := _bucket(f * Vector3(2.48, 0, .15), .32, .1, .14, Color("#a4a8a6"), true, "metal")
	for i: int in range(6):
		var a := float(i) * 1.9
		var tip := pail + Vector3(cos(a) * .24, _rng.randf_range(1.05, 1.5), sin(a) * .1 + .08)
		var bend := pail.lerp(tip, .55) + Vector3(sin(a) * .06, 0, .02)
		_kit.tube("plain", [pail + Vector3.DOWN * .1, bend, tip], .005, Color("#4a3a2c"), 4)
		for k: int in range(18):
			var t := .4 + float(k) * .036
			var at := (pail.lerp(bend, t * 2.0) if t < .5 else bend.lerp(tip, t * 2.0 - 1.0)) + Vector3(_rng.randf_range(-.02, .02), 0, _rng.randf_range(-.02, .02))
			_fleck(at, Vector3(_rng.randf_range(-1, 1), .5, _rng.randf_range(-.4, 1)).normalized(), 5, .014, Color("#f4e4e4").lerp(Color("#eeb8c4"), _rng.randf()))
	_card(pail, .14, 11)
	# Two more buckets stood on the ground in front of the bench, foliage and baby's breath.
	var a1 := _bucket(f * Vector3(1.42, 0, .98), .34, .09, .125, BUCKET)
	_foliage(a1, 7, .62, Color("#4f7a62"))
	_card(a1, .125, 12)
	var a2 := _bucket(f * Vector3(3.06, 0, 1.0), .3, .08, .11, BUCKET)
	for i: int in range(10):
		var a := float(i) * 2.4
		var top := a2 + Vector3(cos(a) * .1, .3 + float(i % 3) * .05, sin(a) * .1 + .04)
		_kit.tube(_l, [a2 + Vector3.DOWN * .08, top], .0026, Color("#7f9a68"), 3)
		_gyp(top, Vector3.UP, .15)
	_card(a2, .11, 7)
	# The hose coiled under the bench, and a terracotta saucer of standing water.
	var coil2: Array[Vector3] = []
	for i: int in range(72):
		var a := float(i) * .42
		var r := .18 + float(i) * .0012
		coil2.append(f * Vector3(2.34 + cos(a) * r, .03 + float(i / 15) * .022, .6 + sin(a) * r * .8))
	_kit.tube("plain", coil2, .011, Color("#2a2c2e"), 5)
	_kit.lathe("plain", f * Vector3(2.5, 0, 1.28), [Vector2(.1, 0), Vector2(.16, .05), Vector2(.15, .05), Vector2(.09, .012)], Color("#a8603a"), 14)
	_kit.disc("plain", f * Vector3(2.5, .018, 1.28), Vector3.RIGHT, Vector3.FORWARD, .11, Color("#7f5236"))
