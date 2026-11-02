extends "res://scripts/midori_near_city_handmade.gd"
## 雀の湯: the street's last 銭湯, a temple gable and a bowed porch on a lot too narrow for
## either, set back a tiled step from the road. Timber-fired since before anyone can say, the
## brick stack still the tallest thing on the row, with a heat exchanger clamped round it in 2044.
const ATLAS := "res://assets/shinrai/near_city/sento_atlas.png"
const WIDE := 6.6
const SET := 1.2 # The wall stands back from the street line by this much.
const LONG := 6.55 # Wall plane to the back of the hall.
const OVER := .16
const EAVE := 6.55
const SKIRT := 7.4
const RIDGE := 9.75
const CX := 3.3
const KR := 1.95 # Half the span of the bowed porch.
const KLOW := 3.42
const KRISE := 1.3
const FOYER_X0 := 1.72
const FOYER_X1 := 4.88
const FOYER_Z := -3.0
const FOYER_TOP := 2.62
const SHOE := Rect2(2.15, .07, 2.3, 2.38)
const GLASS_R := Rect2(4.96, 1.12, 1.36, 1.34)
const MEN := Rect2(2.03, .18, .86, 1.98)
const WOMEN := Rect2(3.71, .18, .86, 1.98)
const HATCH := Rect2(3.03, .98, .43, .5)
const FLAT_L := Rect2(.32, 4.2, 1.3, 1.16)
const FLAT_R := Rect2(4.98, 4.2, 1.3, 1.16)
const ROOM_X1 := 3.25
const ROOM_Z := -5.8
const ROOM_TOP := 2.8
const STACK := Vector3(2.4, 0, -8.55)
const STACK_TALL := 21.5
const STACK_R0 := .72
const STACK_R1 := .38
const OILED := Color("#34241a")
const TAN := Color("#6e5238")
const PLASTER := Color(.93, .9, .82)
const PUTTY := Color(.72, .64, .58)
const TERRACOTTA := Color("#a0512a")
const FORECOURT := Color("#6f9c7c")
const PAN := Color("#2b2d30")
const ROOF := Color("#3f4348")
const CREAM_DOOR := Color("#d3c8a8")

var _f := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, -SET))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, -SET))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -SET - LONG))

func _ready() -> void:
	_rng.seed = 1948
	_build_looks()
	_apron()
	_front_wall()
	_foyer()
	_back_of_foyer()
	_hatch()
	_mens_room()
	_womens_room()
	_big_noren()
	_porch()
	_pent()
	_upper_wall()
	_gable()
	_main_roof()
	_steam_vent()
	_flanks()
	_boiler()
	_chimney()
	_blade()
	_street_things()
	_kit.commit(self, _looks, ["front", "decal", "frost", "paint", "lamp", "neon", "led", "sign", "room", "woodroom", "cedar", "groom", "lantern", "display", "clothroom", "steel"])
	_kit = null
	_omni("SentoFoyer", Vector3(0, 2.25, -3.0), Color(1.0, .8, .56), .5, 5.0)
	_omni("SentoPorch", Vector3(0, 2.7, -.5), Color(1.0, .76, .5), .55, 5.0)

func _atlas_look(key: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[key] = look

func _decal_look(key: String, glow: float, day: float) -> void:
	var look := ShaderMaterial.new()
	look.shader = DECAL_SHADER
	look.set_shader_parameter("atlas", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[key] = look

func _glowing(key: String, base: ShaderMaterial, glow: float, day: float) -> void:
	base.set_shader_parameter("glow", glow)
	base.set_shader_parameter("day_glow", day)
	_looks[key] = base

func _build_looks() -> void:
	_shared_looks()
	_looks.tile = _look("", 1.0, .32)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.19, .062))
	_looks.green = _look("", 1.0, .3)
	_looks.green.set_shader_parameter("tile_size", Vector2(.1, .1))
	_glowing("groom", _look("", 1.0, .35), .18, .08)
	_looks.groom.set_shader_parameter("tile_size", Vector2(.1, .1))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.stone = _look("precast_concrete_wall", 2.4, .9)
	_looks.stone.set_shader_parameter("chroma", .6)
	_looks.wood = _look("japanese_cedar_planks", 1.4, .75)
	_looks.wood.set_shader_parameter("chroma", .5)
	_looks.iron = _look("worn_corrugated_iron", 2.0, .85)
	_looks.kawara = _look("", 1.0, .5, .1)
	_looks.pan = _look("", 1.0, .8, .0)
	_looks.pan.set_shader_parameter("tile_size", Vector2(.27, .31))
	_looks.brick = _look("", 1.0, .9)
	_looks.brick.set_shader_parameter("tile_size", Vector2(.22, .068))
	_glowing("room", _look("", 1.0, .55), .24, .1)
	_glowing("woodroom", _look("japanese_cedar_planks", 1.4, .6), .24, .1)
	_looks.woodroom.set_shader_parameter("chroma", .55)
	_glowing("cedar", _look("japanese_cedar_planks", 1.0, .4), .24, .1)
	_looks.cedar.set_shader_parameter("chroma", .6)
	_glowing("steel", _look("", 1.0, .34, .7), .16, .05)
	_glowing("lantern", _look("", 1.0, .45), .55, .1)
	_atlas_look("sign", .35, .8, .14)
	_atlas_look("display", .4, .36, .14)
	_atlas_look("board", .75, .12, .0)
	_atlas_look("cloth", .92, .12, .0)
	_atlas_look("clothroom", .92, .3, .1)
	_decal_look("decal", .3, .1)
	_decal_look("frost", .3, .12)
	_decal_look("paint", .03, .02)

# ---- small drawing helpers, all in the wall's own coordinates ----

func _p(x: float, y: float, z: float) -> Vector3:
	return _f * Vector3(x, y, z)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _wall(part: String, r: Rect2, z: float, tint: Color, low := .9, high := 1.0, streak := .5) -> void:
	_kit.quad(part, _p(r.position.x, r.position.y, z), _p(r.position.x, r.end.y, z), _p(r.end.x, r.end.y, z), _p(r.end.x, r.position.y, z), tint, low, high, streak, Vector2(r.position.x, -r.position.y))

func _floor(part: String, x0: float, x1: float, near: float, far: float, y: float, tint: Color) -> void:
	_kit.quad(part, _p(x0, y, near), _p(x0, y, far), _p(x1, y, far), _p(x1, y, near), tint, .85, .85, 0.0, Vector2(x0, near))

func _ceiling(part: String, x0: float, x1: float, near: float, far: float, y: float, tint: Color) -> void:
	_kit.quad(part, _p(x0, y, far), _p(x0, y, near), _p(x1, y, near), _p(x1, y, far), tint, .8, .8)

func _side_w(part: String, x: float, near: float, far: float, y0: float, y1: float, tint: Color) -> void:
	# A wall on the room's west, facing east.
	_kit.quad(part, _p(x, y0, near), _p(x, y1, near), _p(x, y1, far), _p(x, y0, far), tint, .75, .95)

func _side_e(part: String, x: float, near: float, far: float, y0: float, y1: float, tint: Color) -> void:
	_kit.quad(part, _p(x, y0, far), _p(x, y1, far), _p(x, y1, near), _p(x, y0, near), tint, .75, .95)

func _tama(at: Vector3, r := .078) -> void:
	# 玉縁: the row of ball tiles the old bathhouses run down every edge.
	var profile: Array[Vector2] = []
	for i: int in range(7):
		var a := -PI * .5 + PI * float(i) / 6.0
		profile.append(Vector2(maxf(cos(a) * r, .001), sin(a) * r))
	_kit.lathe("kawara", at, profile, ROOF * 1.05, 8)

func _tile_field(e0: Vector3, e1: Vector3, t0: Vector3, t1: Vector3, ends := false) -> void:
	# Real roll tiles from eave to head: e0-e1 the eave left to right from outside, t0-t1 above it.
	_kit.quad("pan", e0, t0, t1, e1, PAN, .8, .9)
	var along := e1 - e0
	var side := along.normalized()
	var up := along.cross(t0 - e0).normalized()
	var rolls := maxi(int(along.length() / .27), 2)
	var slope := ((t0 + t1) * .5 - (e0 + e1) * .5).length()
	var courses := maxi(int(slope / .34), 1)
	for i: int in range(rolls):
		var u := (float(i) + .5) / float(rolls)
		var p := e0.lerp(e1, u)
		var q := t0.lerp(t1, u)
		var tint := ROOF * _rng.randf_range(.86, 1.08)
		for c: int in range(courses):
			var a := p.lerp(q, float(c) / float(courses))
			var b := p.lerp(q, float(c + 1) / float(courses))
			for k: int in range(3):
				var a0 := PI * float(k) / 3.0
				var a1 := PI * float(k + 1) / 3.0
				var d0 := side * cos(a0) + up * sin(a0)
				var d1 := side * cos(a1) + up * sin(a1)
				_kit.smooth("kawara", a + d0 * .08, b + d0 * .064, b + d1 * .064, a + d1 * .08, d0, d0, d1, d1, tint)
		if ends:
			_kit.disc("kawara", p + up * .012, side, up, .092, tint * 1.12)
	_kit.beam("kawara", e0 - up * .02, e1 - up * .02, .13, .05, up, PAN * 1.2)

func _oni(at: Vector3, s: float) -> void:
	# 鬼瓦: stacked crest at a ridge end, heavy and round-shouldered.
	var t := ROOF * .68
	_kit.block("kawara", Transform3D(Basis.IDENTITY, at + Vector3(0, .1 * s, 0)), Vector3(.62, .2, .16) * s, t)
	_kit.block("kawara", Transform3D(Basis.IDENTITY, at + Vector3(0, .3 * s, 0)), Vector3(.5, .26, .16) * s, t)
	_kit.disc("kawara", at + Vector3(0, .32 * s, .082 * s), Vector3.RIGHT, Vector3.UP, .2 * s, t * 1.3)
	_kit.disc("kawara", at + Vector3(0, .32 * s, .09 * s), Vector3.RIGHT, Vector3.UP, .1 * s, t * .8)
	for side: float in [-1.0, 1.0]:
		_kit.tube("kawara", [at + Vector3(side * .3 * s, .1 * s, 0), at + Vector3(side * .36 * s, .28 * s, 0), at + Vector3(side * .26 * s, .46 * s, 0), at + Vector3(0, .5 * s, 0)], .07 * s, t, 6)

func _rafters(x0: float, x1: float, step: float, inner: Vector3, outer: Vector3) -> void:
	# Exposed rafters with their ends limed white, as every photographed eave has them.
	var x := x0
	while x <= x1 + .001:
		var a := _p(x, inner.y, inner.z)
		var b := _p(x, outer.y, outer.z)
		_kit.beam("wood", a, b, .055, .075, Vector3.UP, OILED)
		var tip := b + (b - a).normalized() * .004
		_kit.block("plain", Transform3D(Basis.IDENTITY, tip), Vector3(.058, .078, .012), Color("#d9d4c4"))
		x += step

# ---- street level ----

func _apron() -> void:
	# Takara-yu's green tile, carried from the kerb right into the shoe room.
	_floor("green", .0, WIDE, SET, .0, .07, FORECOURT)
	_kit.quad("green", _p(0, 0, SET), _p(0, .07, SET), _p(WIDE, .07, SET), _p(WIDE, 0, SET), FORECOURT * .8, .7, .9)
	_kit.quad("green", _p(0, 0, 0), _p(0, .07, 0), _p(0, .07, SET), _p(0, 0, SET), FORECOURT * .8, .7, .9)
	_kit.quad("green", _p(WIDE, 0, SET), _p(WIDE, .07, SET), _p(WIDE, .07, 0), _p(WIDE, 0, 0), FORECOURT * .8, .7, .9)
	# A drain slot, and the worn mat in front of the door.
	_bar("metal", _f, 3.3, .074, .9, Vector3(2.3, .006, .1), Color("#3a3c3e"))
	_bar("plain", _f, 3.3, .085, .42, Vector3(1.5, .022, .62), Color("#2a2c2a"))

func _front_wall() -> void:
	var wood := OILED
	for x: float in [.1, 6.5]:
		_wall("stone", Rect2(x - .1, 0, .2, 3.4), 0, Color(.72, .71, .68), .7, 1.0, .6)
	for span: Vector2 in [Vector2(.2, 2.06), Vector2(4.54, 6.4)]:
		_wall("stone", Rect2(span.x, .07, span.y - span.x, .15), .0, Color(.56, .55, .53), .7, .9, .3)
		_wall("tile", Rect2(span.x, .22, span.y - span.x, .84), 0, TERRACOTTA, .85, 1.0, .3)
		_bar("wood", _f, (span.x + span.y) * .5, 1.08, .03, Vector3(span.y - span.x, .05, .09), TAN)
		_wall("render", Rect2(span.x, 2.5, span.y - span.x, .9), 0, PLASTER, .8, .9, .5)
	_wall("render", Rect2(.2, 1.1, 1.86, 1.4), 0, PLASTER * .96, .9, 1.0, .7)
	for piece: Rect2 in _minus(Rect2(4.54, 1.1, 1.86, 1.4), [GLASS_R]):
		_wall("render", piece, 0, PLASTER * .96, .9, 1.0, .7)
	# The baths board, and the carved board over the door.
	_bar("wood", _f, 1.13, 1.74, .012, Vector3(1.68, 1.08, .024), TAN)
	_panel("board", _f, .32, 1.94, 1.24, 2.24, .026, _cell(530, 540, 640, 400), Color(.86, .83, .76))
	_wall("wood", Rect2(2.06, 2.45, 2.48, .95), 0, wood, .6, .7, .0)
	_panel("board", _f, 2.2, 4.4, 2.5, 3.1, .01, _cell(1070, 1360, 620, 200))
	# Timber: two rails, the door posts, the corner boards.
	for y: float in [2.5, 3.14]:
		_bar("wood", _f, CX, y, .03, Vector3(WIDE - .4, .1, .1), wood)
	for x: float in [.25, 2.1, 4.5, 6.35]:
		_bar("wood", _f, x, 1.7, .03, Vector3(.15, 3.3, .1), wood)
	_reveal(_f, SHOE, .14, Color("#3b2a1c"))
	# Pebbled window in a heavy tan frame, the street's only look at the women's side.
	_reveal(_f, GLASS_R, .1, Color("#5a432c"))
	_panel("frost", _f, GLASS_R.position.x, GLASS_R.end.x, GLASS_R.position.y, GLASS_R.end.y, -.08, _cell(0, 540, 350, 345), Color(1.0, .88, .68))
	for x: float in [GLASS_R.position.x + .03, GLASS_R.get_center().x, GLASS_R.end.x - .03]:
		_bar("wood", _f, x, GLASS_R.get_center().y, -.05, Vector3(.05, GLASS_R.size.y, .06), TAN)
	for y: float in [GLASS_R.position.y + .03, GLASS_R.end.y - .03]:
		_bar("wood", _f, GLASS_R.get_center().x, y, -.05, Vector3(GLASS_R.size.x, .05, .06), TAN)

func _foyer() -> void:
	# 下足場: tile underfoot, walls of shoe boxes, wallpaper gone soft above them.
	var paper := Color("#c7c6b4")
	_floor("groom", FOYER_X0, FOYER_X1, -.0, FOYER_Z, .07, FORECOURT * .9)
	_side_w("room", FOYER_X0, -.1, FOYER_Z, 0, FOYER_TOP, paper)
	_side_e("room", FOYER_X1, -.1, FOYER_Z, 0, FOYER_TOP, paper)
	_ceiling("cedar", FOYER_X0, FOYER_X1, -.1, FOYER_Z, FOYER_TOP, Color("#a88a62"))
	_kit.disc("lamp", _p(3.3, FOYER_TOP - .05, -1.5), Vector3.RIGHT, Vector3.BACK, .2, Color(.95, .9, .74))
	_kit.lathe("steel", _p(3.3, FOYER_TOP - .05, -1.5), [Vector2(.21, 0), Vector2(.21, .05)], Color("#d8d4c8"), 12)
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), _p(2.04, 0, -.42))
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), _p(4.56, 0, -2.66))
	_lockers(west, 8, 0)
	_lockers(east, 8, 7)
	# Notices above the boxes, and the bare backs of the boxes against the walls.
	var side := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), _p(2.04, 0, -.42))
	_panel("display", side, .45, .85, 2.06, 2.56, .02, _cell(1550, 540, 240, 320))
	_panel("display", side, 1.2, 1.56, 2.08, 2.56, .02, _cell(1800, 540, 240, 320))
	var other := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), _p(4.56, 0, -2.66))
	_panel("display", other, .5, .84, 2.08, 2.56, .02, _cell(880, 1720, 170, 240))
	# Stack of plastic slippers for the old men, and an umbrella stand by the jamb.
	var ring := _p(2.3, .07, -.24)
	_kit.lathe("steel", ring, [Vector2(.08, 0), Vector2(.09, .46), Vector2(.08, .46)], Color("#5f6362"), 10)
	for i: int in range(3):
		_kit.tube("plain", [ring + Vector3(.03 * float(i - 1), .05, 0), ring + Vector3(.1 * float(i - 1), .92, .04 * float(i))], .012, [Color("#23324a"), Color("#3a3a3a"), Color("#6a1f22")][i], 5)

func _lockers(t: Transform3D, cols: int, offset: int) -> void:
	# Cream doors, brown carcass, a tin lock and its wooden key: a door here and there left open.
	var w := .28
	var h := .25
	var low := .24
	var rows := 7
	var run := float(cols) * w
	_kit.block("woodroom", _at(t, run * .5, 1.09, -.17), Vector3(run + .04, 1.82, .34), Color("#6b4a2c"))
	_bar("woodroom", t, run * .5, 2.02, -.1, Vector3(run + .1, .03, .24), Color("#5a3d24"))
	for col: int in range(cols):
		for row: int in range(rows):
			var x0 := float(col) * w + .012
			var x1 := float(col + 1) * w - .012
			var y0 := low + float(row) * h + .012
			var y1 := y0 + h - .024
			var mx := (x0 + x1) * .5
			var roll := _rng.randf()
			if roll < .035:
				# Standing open: the dark box, a pair of shoes in it, the door swung out.
				_kit.quad("plain", t * Vector3(x0, y0, .002), t * Vector3(x0, y1, .002), t * Vector3(x1, y1, .002), t * Vector3(x1, y0, .002), Color("#17110c"))
				_kit.quad("room", t * Vector3(x1, y0, .002), t * Vector3(x1, y1, .002), t * Vector3(x1 + .05, y1, .24), t * Vector3(x1 + .05, y0, .24), CREAM_DOOR * .85)
				_kit.block("room", _at(t, mx - .05, y0 + .03, -.1), Vector3(.075, .06, .2), Color("#3a2c22"))
				_kit.block("room", _at(t, mx + .05, y0 + .03, -.1), Vector3(.075, .06, .2), Color("#3a2c22"))
				continue
			var tone := _rng.randf_range(.86, 1.02)
			_kit.quad("room", t * Vector3(x0, y0, .006), t * Vector3(x0, y1, .006), t * Vector3(x1, y1, .006), t * Vector3(x1, y0, .006), CREAM_DOOR * tone, .8, 1.0)
			_kit.block("steel", _at(t, mx, y0 + .07, .012), Vector3(.062, .07, .012), Color("#7b7d7c"))
			if roll > .26:
				var n := (offset * 7 + col * 7 + row) % 128
				var rect := _cell(220 + float(n % 16) * 40, 1100 + float(n / 16) * 40, 40, 40)
				_kit.atlas("display", t * Vector3(mx - .03, y0 + .075, .02), t * Vector3(mx - .03, y0 + .15, .02), t * Vector3(mx + .03, y0 + .15, .02), t * Vector3(mx + .03, y0 + .075, .02), rect)

func _back_of_foyer() -> void:
	var cream := Color("#b4a688")
	for piece: Rect2 in _minus(Rect2(FOYER_X0, 0, FOYER_X1 - FOYER_X0, FOYER_TOP), [MEN, WOMEN, HATCH]):
		_kit.quad("room", _p(piece.position.x, piece.position.y, FOYER_Z), _p(piece.position.x, piece.end.y, FOYER_Z), _p(piece.end.x, piece.end.y, FOYER_Z), _p(piece.end.x, piece.position.y, FOYER_Z), cream, .85, 1.0)
	# 上がり框: the worn step up, polished by feet where everyone turns to go in.
	_bar("woodroom", _f, CX, .125, FOYER_Z + .17, Vector3(FOYER_X1 - FOYER_X0, .11, .34), Color("#8a6238"))
	_bar("woodroom", _f, CX, .185, FOYER_Z + .17, Vector3(FOYER_X1 - FOYER_X0, .014, .36), Color("#a67c4a"))
	_door(MEN, true)
	_door(WOMEN, false)
	_hanging("clothroom", MEN.position.x - .03, MEN.end.x + .03, 2.17, .56, FOYER_Z + .05, _cell(1260, 0, 380, 250), 2)
	_hanging("clothroom", WOMEN.position.x - .03, WOMEN.end.x + .03, 2.17, .56, FOYER_Z + .05, _cell(1660, 0, 380, 250), 2)

func _door(r: Rect2, open: bool) -> void:
	# Two wooden leaves of pebbled glass; the men's has been left a shoulder's width open.
	var z := FOYER_Z - .03
	var mid := r.get_center().x
	var wood := Color("#6e4a2a")
	if not open:
		_kit.quad("room", _p(r.position.x, r.position.y, z - .08), _p(r.position.x, r.end.y, z - .08), _p(r.end.x, r.end.y, z - .08), _p(r.end.x, r.position.y, z - .08), Color("#f0dcc0"))
		_panel("frost", _f, r.position.x, r.end.x, r.position.y, r.end.y, z, _cell(0, 540, 220, 500), Color(1.0, .88, .68))
	else:
		_kit.quad("room", _p(r.position.x, r.position.y, z - .05), _p(r.position.x, r.end.y, z - .05), _p(mid, r.end.y, z - .05), _p(mid, r.position.y, z - .05), Color("#ead8bc"))
		_panel("frost", _f, r.position.x, mid, r.position.y, r.end.y, z, _cell(0, 540, 110, 500), Color(1.0, .88, .68))
	for x: float in ([r.position.x + .025, mid - .025, r.end.x - .025] if open else [r.position.x + .025, mid, r.end.x - .025]):
		_bar("woodroom", _f, x, r.get_center().y, z + .005, Vector3(.05, r.size.y, .05), wood)
	var rails: Array[float] = [r.position.y + .03, r.position.y + .42, r.end.y - .03]
	for y: float in rails:
		_bar("woodroom", _f, (r.position.x + mid) * .5 if open else mid, y, z + .005, Vector3(r.size.x * .5 if open else r.size.x, .05, .05), wood)
	_bar("woodroom", _f, mid, r.end.y - .03, z + .005, Vector3(r.size.x, .05, .05), wood)

func _hatch() -> void:
	# 受付: a small lit hole between the two doors, a sill, and the palm pad bolted on in the forties.
	var z := FOYER_Z
	var x0 := HATCH.position.x
	var x1 := HATCH.end.x
	var y0 := HATCH.position.y
	var y1 := HATCH.end.y
	_kit.quad("room", _p(x0, y0, z - .6), _p(x0, y1, z - .6), _p(x1, y1, z - .6), _p(x1, y0, z - .6), Color("#c9b892"))
	_side_w("room", x0, z, z - .6, y0, y1, Color("#b5a584"))
	_side_e("room", x1, z, z - .6, y0, y1, Color("#b5a584"))
	_ceiling("room", x0, x1, z, z - .6, y1, Color("#d0c4a8"))
	_floor("cedar", x0, x1, z, z - .6, y0, Color("#a07a48"))
	_bar("woodroom", _f, HATCH.get_center().x, y0 - .012, z + .05, Vector3(.54, .025, .18), Color("#a67c4a"))
	_kit.block("room", _at(_f, x0 + .1, y0 + .06, z - .3), Vector3(.14, .12, .2), Color("#efe9d8"))
	_kit.block("room", _at(_f, x0 + .1, y0 + .15, z - .3), Vector3(.14, .05, .2), Color("#6f8fb0"))
	_kit.lathe("steel", _p(x1 - .1, y0 + .002, z - .16), [Vector2(.04, 0), Vector2(.03, .05), Vector2(.01, .06)], Color("#c9b45a"), 10)
	_panel("display", _f, 3.03, 3.57, 1.7, 2.46, z + .012, _cell(1190, 540, 340, 480))
	_panel("display", _f, 3.08, 3.42, 1.53, 1.665, z + .012, _cell(1690, 1100, 200, 80))
	# The pad: dark glass the size of a paperback, the outline of a hand.
	_bar("steel", _f, 3.56, 1.18, z + .012, Vector3(.13, .19, .024), Color("#3a3d40"))
	_panel("display", _f, 3.505, 3.615, 1.1, 1.26, z + .026, _cell(1510, 1100, 160, 220))
	_status(_f, 3.56, 1.3, z + .02, GREEN)

func _mens_room() -> void:
	# Seen only through a door left ajar: boards, baskets, the scale, a fridge of milk.
	var x0 := .12
	var x1 := ROOM_X1
	var far := ROOM_Z
	var near := FOYER_Z - .06
	var y0 := .18
	var top := ROOM_TOP
	_floor("cedar", x0, x1, near, far, y0, Color("#9c7648"))
	_ceiling("room", x0, x1, near, far, top, Color("#d9d2bc"))
	_side_w("room", x0, near, far, y0, top, Color("#cfc6aa"))
	_side_e("room", x1, near, far, y0, top, Color("#d8cfb4"))
	# Back wall: pebbled doors on to the bath hall, bright and steamy behind them.
	_kit.quad("room", _p(x0, y0, far), _p(x0, top, far), _p(x1, top, far), _p(x1, y0, far), Color("#cfe2d6"))
	_panel("frost", _f, x0, x1, y0, top - .2, far + .02, _cell(0, 540, 512, 420), Color(.92, .96, .94))
	_bar("woodroom", _f, (x0 + x1) * .5, top - .1, far + .03, Vector3(x1 - x0, .2, .04), Color("#6e4a2a"))
	var x := x0 + .45
	while x < x1:
		_bar("woodroom", _f, x, (y0 + top) * .5, far + .04, Vector3(.06, top - y0, .05), Color("#6e4a2a"))
		x += .9
	# Three shelves of rattan baskets down the east wall.
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), _p(x1, 0, far + .7))
	for y: float in [.62, 1.12, 1.62]:
		_bar("woodroom", east, 1.0, y, .19, Vector3(2.0, .03, .38), Color("#8a6238"))
	for u: float in [.0, .5, 1.0, 1.5, 2.0]:
		_bar("woodroom", east, u, 1.0, .19, Vector3(.03, 1.64, .38), Color("#6e4a2a"))
		if u > 1.9: continue
		for y: float in [.635, 1.135, 1.635]:
			_kit.lathe("woodroom", east * Vector3(u + .25, y, .19), [Vector2(.13, 0), Vector2(.18, .03), Vector2(.2, .2), Vector2(.17, .2), Vector2(.13, .03)], Color("#b08a52"), 10)
	_panel("display", east, .1, 1.9, 2.06, 2.42, .01, _cell(1070, 1580, 596, 120))
	# Milk: a glass-fronted cooler, three shelves of bottles, its label curling.
	var fx := x1 - .38
	var fz := far + .36
	_bar("steel", _f, fx, .98, fz, Vector3(.6, 1.6, .6), Color("#d8d6cc"))
	_kit.quad("room", _p(fx - .25, .4, fz + .305), _p(fx - .25, 1.56, fz + .305), _p(fx + .25, 1.56, fz + .305), _p(fx + .25, .4, fz + .305), Color("#e6e8e2"))
	for row: int in range(3):
		var y := .46 + float(row) * .36
		_bar("steel", _f, fx, y - .02, fz + .24, Vector3(.48, .012, .12), Color("#b6b9b6"))
		for i: int in range(4):
			var tint: Color = [Color("#f2eee0"), Color("#e9c98c"), Color("#c8a06a")][row]
			_kit.lathe("room", _p(fx - .18 + float(i) * .12, y - .012, fz + .25), [Vector2(.03, 0), Vector2(.03, .09), Vector2(.018, .15), Vector2(.02, .16)], tint, 7)
	_kit.quad("front", _p(fx - .26, .36, fz + .36), _p(fx - .26, 1.62, fz + .36), _p(fx + .26, 1.62, fz + .36), _p(fx + .26, .36, fz + .36), Color.WHITE)
	_panel("display", _f, fx - .26, fx + .26, 1.64, 1.76, fz + .305, _cell(1070, 1720, 260, 100))
	# The old dial scale that everyone stands on and nobody believes.
	var sx := 2.16
	var sz := far + .5
	_bar("room", _f, sx, y0 + .05, sz, Vector3(.42, .08, .38), Color("#c7c2b2"))
	_bar("room", _f, sx, y0 + .62, sz - .14, Vector3(.1, 1.08, .08), Color("#c7c2b2"))
	_kit.disc("display", _p(sx, y0 + 1.3, sz - .08), Vector3.RIGHT, Vector3.UP, .19, Color.WHITE, _cell(1705, 1305, 170, 170))
	# Fan, bench, the one ceiling light.
	var hub := _p(1.7, top, -4.4)
	_kit.lathe("steel", hub + Vector3.DOWN * .22, [Vector2(.012, .2), Vector2(.012, .12), Vector2(.09, .06), Vector2(.09, 0)], Color("#6b5a44"), 8)
	for i: int in range(3):
		var a := float(i) * TAU / 3.0 + .3
		_kit.beam("woodroom", hub + Vector3(cos(a) * .08, -.2, sin(a) * .08), hub + Vector3(cos(a) * .62, -.2, sin(a) * .62), .12, .012, Vector3.UP, Color("#5a3d24"))
	_kit.disc("lamp", _p(2.5, top - .02, -3.8), Vector3.RIGHT, Vector3.BACK, .2, Color(.95, .92, .78))
	_bar("woodroom", _f, 1.3, .58, -4.5, Vector3(.42, .05, 1.5), Color("#a67c4a"))
	for z: float in [-3.88, -5.12]:
		_bar("woodroom", _f, 1.3, .38, z, Vector3(.36, .4, .06), Color("#6e4a2a"))

func _womens_room() -> void:
	# All the street gets of this one is the shapes through the pebbled glass.
	var x0 := 4.98
	var x1 := 6.48
	var far := -2.9
	var wall := Color("#d8bd96")
	_kit.quad("room", _p(x0, 0, far), _p(x0, 2.62, far), _p(x1, 2.62, far), _p(x1, 0, far), wall)
	_side_w("room", x0, -.1, far, 0, 2.62, wall * .92)
	_side_e("room", x1, -.1, far, 0, 2.62, wall * .92)
	_ceiling("room", x0, x1, -.1, far, 2.62, wall)
	_floor("room", x0, x1, -.1, far, .18, Color("#9c7648"))
	_bar("woodroom", _f, 5.3, 1.0, -2.4, Vector3(.5, 1.9, .5), Color("#7a5634"))
	_bar("woodroom", _f, 6.2, 1.0, -1.6, Vector3(.5, 1.9, .5), Color("#6e4a2a"))
	_kit.disc("lamp", _p(5.6, 2.58, -1.3), Vector3.RIGHT, Vector3.BACK, .24, Color(.95, .9, .78))

func _hanging(part: String, x0: float, x1: float, top: float, drop: float, z: float, rect: Rect2, drops: int) -> void:
	# Noren: split drops on a pole, each a strip of faces so the cloth hangs in soft folds.
	var wide := (x1 - x0) / float(drops)
	var columns := 6
	_kit.tube("metal", [_p(x0 - .1, top + .015, z), _p(x1 + .1, top + .015, z)], .014, Color("#5c4128"), 6)
	for i: int in range(drops):
		var left := x0 + float(i) * wide + .008
		var right := left + wide - .016
		for c: int in range(columns):
			var u0 := float(c) / float(columns)
			var u1 := float(c + 1) / float(columns)
			var a0 := lerpf(left, right, u0)
			var a1 := lerpf(left, right, u1)
			var w0 := .018 + sin(u0 * 7.0 + float(i) * 1.9) * .016
			var w1 := .018 + sin(u1 * 7.0 + float(i) * 1.9) * .016
			var patch := Rect2(rect.position.x + rect.size.x * (float(i) + u0) / float(drops), rect.position.y, rect.size.x / float(drops * columns), rect.size.y)
			_kit.atlas(part, _p(a0, top - drop, z + w0 + .014), _p(a0, top, z), _p(a1, top, z), _p(a1, top - drop, z + w1 + .014), patch, Color.WHITE, .9, .15)
			_kit.atlas(part, _p(a1, top - drop, z + w1 + .012), _p(a1, top, z - .002), _p(a0, top, z - .002), _p(a0, top - drop, z + w0 + .012), patch, Color(.4, .4, .45), .7)

func _big_noren() -> void:
	_hanging("cloth", SHOE.position.x + .02, SHOE.end.x - .02, 2.43, 1.0, .08, _cell(0, 0, 1240, 520), 3)

# ---- the bowed porch ----

func _kara(u: float) -> float:
	var t := absf(u)
	return KLOW + KRISE * .5 * (1.0 + cos(PI * pow(t, 1.15))) + .09 * pow(t, 8.0)

func _kp(u: float, z: float, lift := 0.0) -> Vector3:
	return _p(CX + KR * u, _kara(u) + lift, z)

func _porch() -> void:
	var near := SET - .02
	var back := -.1
	var inner := .3
	var steps := 28
	for i: int in range(steps):
		var u0 := -1.0 + 2.0 * float(i) / float(steps)
		var u1 := -1.0 + 2.0 * float(i + 1) / float(steps)
		_kit.quad("pan", _kp(u0, near, .01), _kp(u0, back, .01), _kp(u1, back, .01), _kp(u1, near, .01), PAN)
		# 破風: the deep bowed board, dark oil under a green copper lip.
		_kit.quad("wood", _kp(u0, near + .01, -.3), _kp(u0, near + .01, -.02), _kp(u1, near + .01, -.02), _kp(u1, near + .01, -.3), OILED, .75, 1.0, .2)
		_kit.quad("plain", _kp(u0, near + .022, -.03), _kp(u0, near + .022, .06), _kp(u1, near + .022, .06), _kp(u1, near + .022, -.03), Color("#4f7d6a"), .9, 1.0, .5)
		# The soffit behind it.
		_kit.quad("wood", _kp(u0, inner, -.3), _kp(u0, near, -.3), _kp(u1, near, -.3), _kp(u1, inner, -.3), Color("#2c1d12"), .5, .6)
		if absf(u0 + u1) * .5 < .72:
			var a := _p(CX + KR * u0, 3.15, inner)
			var b := _kp(u0, inner, -.3)
			var c := _kp(u1, inner, -.3)
			var d := _p(CX + KR * u1, 3.15, inner)
			_kit.quad("render", a, b, c, d, PLASTER * .9, .7, .8, .3)
	var z := near - .14
	while z > back:
		var points: Array[Vector3] = []
		for i: int in range(steps + 1):
			points.append(_kp(-1.0 + 2.0 * float(i) / float(steps), z, .05))
		_kit.tube("kawara", points, .068, ROOF * _rng.randf_range(.86, 1.05), 5)
		z -= .25
	# Rope of tile along the front edge, the balls on top of it, the crest at the crown.
	var rope: Array[Vector3] = []
	for i: int in range(steps + 1):
		rope.append(_kp(-1.0 + 2.0 * float(i) / float(steps), near - .03, .12))
	_kit.tube("kawara", rope, .07, ROOF, 6)
	for i: int in range(-9, 10):
		if i == 0: continue
		var u := float(i) / 9.6
		_tama(_kp(u, near - .03, .23))
	_oni(_kp(0, near - .06, .18), .52)
	# Tips turn up and end in a small ball.
	for side: float in [-1.0, 1.0]:
		_tama(_kp(side, near - .03, .13), .09)
	# Carved bird hanging from the crown of the bow, name board on the plaster behind.
	_panel("paint", _f, 2.78, 3.82, 3.9, 4.48, near + .03, _cell(1070, 1100, 420, 240))
	_bar("wood", _f, CX, 3.52, inner + .012, Vector3(1.46, .4, .03), Color("#20140c"))
	_panel("board", _f, 2.62, 3.98, 3.37, 3.67, inner + .03, _cell(530, 950, 640, 140))
	# Posts on stone feet, the double beam, and small rafters under the soffit.
	for x: float in [1.95, 4.65]:
		_bar("stone", _f, x, .17, 1.03, Vector3(.3, .2, .3), Color(.6, .59, .56))
		_bar("wood", _f, x, 1.66, 1.03, Vector3(.2, 2.8, .2), OILED)
		_bar("wood", _f, x, 3.02, .5, Vector3(.14, .2, 1.12), OILED)
		_bar("wood", _f, x + (.02 if x > CX else -.02), 2.84, 1.03, Vector3(.28, .12, .24), TAN * .7)
	_bar("wood", _f, CX, 3.02, 1.03, Vector3(3.6, .22, .2), OILED)
	_bar("wood", _f, CX, 3.2, .7, Vector3(3.0, .12, .14), Color("#2c1d12"))
	for i: int in range(-5, 6):
		var u := float(i) * .13
		_kit.beam("wood", _kp(u, inner + .02, -.33), _kp(u, near - .02, -.33), .05, .05, Vector3.UP, OILED)
	_bar("wood", _f, CX, 3.97, inner + .012, Vector3(1.5, .5, .03), Color("#20140c"))
	_panel("board", _f, 2.6, 4.0, 3.75, 4.2, inner + .03, _cell(1070, 1360, 620, 200))
	for x: float in [2.5, 4.1]:
		_bar("wood", _f, x, 3.72, inner + .04, Vector3(.1, .96, .08), OILED)
	var slat := 2.0
	while slat < 2.46:
		_bar("wood", _f, slat, 3.52, inner + .02, Vector3(.02, .68, .02), Color("#2c1d12"))
		_bar("wood", _f, CX * 2.0 - slat, 3.52, inner + .02, Vector3(.02, .68, .02), Color("#2c1d12"))
		slat += .07
	_bar("wood", _f, 2.23, 3.84, inner + .03, Vector3(.54, .05, .05), OILED)
	_bar("wood", _f, 4.37, 3.84, inner + .03, Vector3(.54, .05, .05), OILED)
	# Milk-glass globes on short iron arms.
	for x: float in [2.34, 4.26]:
		_bar("metal", _f, x, 2.86, 1.03, Vector3(.02, .1, .02), Color("#1a1a1a"))
		var r := .135
		var profile: Array[Vector2] = []
		for i: int in range(9):
			var a := -PI * .5 + PI * float(i) / 8.0
			profile.append(Vector2(maxf(cos(a) * r, .001), sin(a) * r))
		_kit.lathe("lantern", _p(x, 2.68, 1.03), profile, Color(1.0, .74, .44), 14)
		_kit.lathe("metal", _p(x, 2.8, 1.03), [Vector2(.06, 0), Vector2(.03, .02), Vector2(.03, .05)], Color("#1a1a1a"), 8)

func _pent() -> void:
	# The lower roof either side of the porch.
	var out := .84
	var ranges: Array[Vector2] = [Vector2(-.12, 1.62), Vector2(4.98, 6.72)]
	for span: Vector2 in ranges:
		_tile_field(_p(span.x, 3.38, out), _p(span.y, 3.38, out), _p(span.x, 3.9, 0), _p(span.y, 3.9, 0), true)
		_ceiling("wood", span.x, span.y, out - .02, 0, 3.34, Color("#2c1d12"))
		_bar("wood", _f, (span.x + span.y) * .5, 3.3, out - .06, Vector3(span.y - span.x, .1, .1), OILED)
		_rafters(span.x + .1, span.y - .1, .42, Vector3(0, 3.4, 0), Vector3(0, 3.26, out + .02))
	_bar("wood", _f, CX, 3.42, .06, Vector3(WIDE, .1, .12), OILED)

func _sash(r: Rect2, cell: float) -> void:
	# Timber sash in the upper wall: 1960s, tan where the paint has gone.
	_reveal(_f, r, .1, Color("#6d543a"))
	var mid := r.get_center().x
	_kit.pane("glass", _f, r.position.x, mid + .02, r.position.y, r.end.y, -.09, cell)
	_kit.pane("glass", _f, mid - .02, r.end.x, r.position.y, r.end.y, -.065, fposmod(cell + .37, 1.0))
	for x: float in [r.position.x + .025, mid, r.end.x - .025]:
		_bar("wood", _f, x, r.get_center().y, -.05, Vector3(.05, r.size.y, .05), TAN)
	var y := r.position.y + .025
	while y < r.end.y:
		_bar("wood", _f, mid, y, -.05, Vector3(r.size.x, .04, .05), TAN)
		y += (r.size.y - .05) * .5
	_bar("wood", _f, mid, r.position.y - .03, .02, Vector3(r.size.x + .12, .05, .1), TAN * .85)
	_bar("wood", _f, mid, r.end.y + .03, .015, Vector3(r.size.x + .12, .06, .06), OILED)

func _upper_wall() -> void:
	# Owner's flat over the shoe room: putty render below, white panels above, as at Takara-yu.
	for piece: Rect2 in _minus(Rect2(0, 3.4, WIDE, 2.25), [FLAT_L, FLAT_R]):
		_wall("render", piece, 0, PUTTY, .85, 1.0, .9)
	_wall("render", Rect2(0, 5.65, WIDE, EAVE - 5.65), 0, PLASTER, .75, .85, .7)
	_sash(FLAT_L, .58)
	_sash(FLAT_R, .61)
	for y: float in [5.62, 6.36]:
		_bar("wood", _f, CX, y, .03, Vector3(WIDE, .11, .09), OILED)
	for x: float in [.06, 2.22, 4.38, 6.54]:
		_bar("wood", _f, x, 6.0 if x > .1 and x < 6.5 else 4.95, .03, Vector3(.13, .8 if x > .1 and x < 6.5 else 3.1, .08), OILED)
	# Curtain in the flat, faded, one side hanging off its hooks.
	_kit.quad("plain", _p(.38, 4.26, -.12), _p(.38, 5.3, -.12), _p(.92, 5.3, -.12), _p(1.02, 4.26, -.12), Color("#a08a6a"), .7, .9)
	# The fibre came up the east corner, and the ordinance's dome under the pent.
	_fibre([_p(6.46, 3.9, .04), _p(6.46, 5.5, .04), _p(6.46, 6.3, .05)])
	_camera(_p(.34, 3.28, .5))

func _gable() -> void:
	# Bracketed skirt, then the lattice triangle that is the whole front of a miyazukuri.
	var z := -.7
	var apex := RIDGE - .12
	var low := 7.72
	var k := (RIDGE - EAVE) / (CX + OVER)
	_kit.quad("render", _p(.76, SKIRT, z), _p(CX - (apex - low) / k, low, z), _p(CX + (apex - low) / k, low, z), _p(5.84, SKIRT, z), PLASTER, .8, 1.0, .6)
	var half := (apex - low) / k
	_kit.quad("plain", _p(CX - half, low, z), _p(CX, apex, z), _p(CX, apex, z), _p(CX + half, low, z), Color("#17100a"))
	var x := CX - half + .05
	while x < CX + half:
		var top := apex - absf(x - CX) * k
		if top > low + .02:
			_bar("wood", _f, x, (low + top) * .5, z + .035, Vector3(.02, top - low, .022), Color("#55391f"))
		x += .09
	var y := low + .05
	while y < apex:
		var wide := (apex - y) / k
		_bar("wood", _f, CX, y, z + .05, Vector3(wide * 2.0, .02, .022), Color("#5e4024"))
		y += .09
	_bar("wood", _f, CX, low, z + .06, Vector3(half * 2.0 + .1, .1, .1), OILED)
	_panel("paint", _f, 2.62, 3.98, 8.72, 9.5, z + .1, _cell(1070, 1100, 420, 240))
	# Barge boards, tile rope and balls down both rakes.
	for side: float in [-1.0, 1.0]:
		var foot := _p(CX + side * (CX - .6), SKIRT - .1, z + .04)
		var head := _p(CX, RIDGE + .02, z + .04)
		_kit.beam("wood", foot + Vector3.DOWN * .16, head + Vector3.DOWN * .16, .3, .1, Vector3.BACK, OILED)
		_kit.tube("kawara", [foot + Vector3(0, .05, .02), head + Vector3(0, .05, .02)], .07, ROOF, 6)
		for i: int in range(1, 10):
			_tama(foot.lerp(head, float(i) / 10.0) + Vector3(0, .15, .02))
	# Skirt soffit, with its limed rafter ends.
	_ceiling("wood", -OVER, WIDE + OVER, .46, 0, EAVE - .03, Color("#2c1d12"))
	_bar("wood", _f, CX, EAVE - .1, .42, Vector3(WIDE + OVER * 2.0, .12, .1), OILED)
	_rafters(.08, WIDE - .08, .4, Vector3(0, EAVE + .02, 0), Vector3(0, EAVE - .14, .5))

func _main_roof() -> void:
	var back := -LONG - .2
	var e := EAVE
	var west_eave := -OVER
	var east_eave := WIDE + OVER
	_tile_field(_p(west_eave, e, .5), _p(east_eave, e, .5), _p(.76, SKIRT, -.7), _p(5.84, SKIRT, -.7), true)
	_tile_field(_p(west_eave, e, back), _p(west_eave, e, .5), _p(.76, SKIRT, back), _p(.76, SKIRT, -.7), true)
	_tile_field(_p(.76, SKIRT, back), _p(.76, SKIRT, -.7), _p(CX, RIDGE, back), _p(CX, RIDGE, -.7))
	_tile_field(_p(east_eave, e, .5), _p(east_eave, e, back), _p(5.84, SKIRT, -.7), _p(5.84, SKIRT, back), true)
	_tile_field(_p(5.84, SKIRT, -.7), _p(5.84, SKIRT, back), _p(CX, RIDGE, -.7), _p(CX, RIDGE, back))
	# Hip rolls, each tipped with a ball.
	for row: Array in [[west_eave, .76], [east_eave, 5.84]]:
		_kit.tube("kawara", [_p(row[0], e + .05, .5), _p(row[1], SKIRT + .05, -.7)], .08, ROOF * .9, 6)
		_tama(_p(row[0], e + .12, .5), .1)
	# Ridge: stacked noshi, a round cap, a crest at each end.
	var middle := (back - .7) * .5
	var run := -.7 - back
	_bar("kawara", _f, CX, RIDGE + .05, middle, Vector3(.26, .1, run), PAN * 1.2)
	_bar("kawara", _f, CX, RIDGE + .14, middle, Vector3(.2, .08, run), ROOF)
	_bar("kawara", _f, CX, RIDGE + .21, middle, Vector3(.16, .06, run), PAN * 1.2)
	_kit.tube("kawara", [_p(CX, RIDGE + .26, -.7), _p(CX, RIDGE + .26, back)], .075, ROOF, 6)
	_oni(_p(CX, RIDGE + .12, -.62), .8)
	_oni(_p(CX, RIDGE + .12, back + .1), .7)
	# Back of the hall: rendered gable.
	var z := -LONG
	_kit.quad("render", _p(WIDE, 0, z), _p(WIDE, EAVE + .1, z), _p(0, EAVE + .1, z), _p(0, 0, z), PLASTER * .8, .7, 1.0, .9)
	_kit.quad("render", _p(WIDE + .1, EAVE + .1, z), _p(CX, RIDGE - .1, z), _p(CX, RIDGE - .1, z), _p(-.1, EAVE + .1, z), PLASTER * .8, .9, 1.0, .8)

func _steam_vent() -> void:
	# 湯気抜き: the little roof on the roof that lets the bath hall breathe.
	var z0 := -3.3
	var z1 := -5.4
	var mid := (z0 + z1) * .5
	var y0 := RIDGE - .24
	var y1 := RIDGE + .58
	var side := .62
	for s: float in [-1.0, 1.0]:
		_bar("wood", _f, CX + s * side, (y0 + y1) * .5, mid, Vector3(.06, y1 - y0, z0 - z1), OILED * .7)
		var y := y0 + .32
		while y < y1 - .05:
			_bar("wood", _f, CX + s * (side + .05), y, mid, Vector3(.03, .05, z0 - z1 - .1), TAN * .7)
			y += .11
	_kit.quad("wood", _p(CX - side, y0, z0), _p(CX - side, y1, z0), _p(CX + side, y1, z0), _p(CX + side, y0, z0), OILED * .8, .7, 1.0)
	_tile_field(_p(CX - side - .24, y1, z1 - .2), _p(CX - side - .24, y1, z0 + .2), _p(CX, y1 + .46, z1 - .2), _p(CX, y1 + .46, z0 + .2))
	_tile_field(_p(CX + side + .24, y1, z0 + .2), _p(CX + side + .24, y1, z1 - .2), _p(CX, y1 + .46, z0 + .2), _p(CX, y1 + .46, z1 - .2))
	_kit.tube("kawara", [_p(CX, y1 + .5, z0 + .2), _p(CX, y1 + .5, z1 - .2)], .07, ROOF, 6)

func _flanks() -> void:
	# The sides nobody dressed: render, a timber band, high windows that steam up.
	var holes: Array[Rect2] = [Rect2(2.6, 4.5, 1.5, 1.0), Rect2(4.5, 4.5, 1.5, 1.0)]
	_render_wall(_east, LONG, EAVE, 3.4, 3.2, PLASTER * .84, holes, .9)
	_render_wall(_west, LONG, EAVE, 3.4, 3.2, PLASTER * .8, [] as Array[Rect2], .9)
	for hole: Rect2 in holes:
		_window(_east, hole, .83, false)
	_bar("wood", _east, LONG * .5, 3.4, .03, Vector3(LONG, .12, .07), OILED)
	_kit.quad("iron", _east * Vector3(0, 0, .02), _east * Vector3(0, 2.5, .02), _east * Vector3(LONG, 2.5, .02), _east * Vector3(LONG, 0, .02), Color(.72, .7, .66), .7, 1.0, .7)
	_bar("wood", _east, LONG * .5, 2.52, .04, Vector3(LONG, .07, .05), TAN * .8)
	_bar("metal", _east, 1.5, 1.45, .08, Vector3(.3, .4, .12), Color("#8f9290"))
	_kit.tube("plain", [_east * Vector3(1.5, 1.25, .08), _east * Vector3(1.5, .1, .08)], .018, Color("#5c5c58"), 5)
	_kit.tube("plain", [_east * Vector3(.15, 6.4, .34), _east * Vector3(.15, 6.1, .08), _east * Vector3(.15, .1, .08)], .036, Color("#6f6a5e"), 6)
	_kit.tube("plain", [_west * Vector3(LONG - .15, 6.4, .34), _west * Vector3(LONG - .15, 6.1, .08), _west * Vector3(LONG - .15, .1, .08)], .036, Color("#6f6a5e"), 6)
	_fibre([_east * Vector3(3.2, 3.5, .1), _east * Vector3(5.6, 3.5, .1)])
	_bar("wood", _west, LONG * .5, 3.4, .03, Vector3(LONG, .12, .07), OILED)

func _boiler() -> void:
	# 釜場: a rusted tin shed behind the hall, the scrap timber it still burns stacked in the yard.
	var x0 := 3.5
	var x1 := WIDE
	var z0 := -LONG
	var z1 := -8.0
	var low := 2.9
	var high := 3.5
	_kit.quad("iron", _p(x1, 0, z1), _p(x1, low, z1), _p(x0, low, z1), _p(x0, 0, z1), Color(.7, .66, .6), .7, 1.0, .6)
	_kit.quad("iron", _p(x1, 0, z0), _p(x1, high, z0), _p(x1, low, z1), _p(x1, 0, z1), Color(.7, .66, .6), .7, 1.0, .6)
	_kit.quad("iron", _p(x0, 0, z1), _p(x0, low, z1), _p(x0, high, z0), _p(x0, 0, z0), Color(.66, .62, .58), .7, 1.0, .6)
	_kit.quad("iron", _p(x0 - .1, low - .03, z1 - .1), _p(x0 - .1, high, z0), _p(x1 + .05, high, z0), _p(x1 + .05, low - .03, z1 - .1), Color(.6, .56, .52), .9, 1.0)
	for row: int in range(6):
		var count := 24 - row * 2
		for i: int in range(count):
			var tone := Color("#7a6248").lerp(Color("#3e2e20"), _rng.randf())
			_bar("plain", _f, .5 + float(i) * .11 + float(row) * .05, .08 + float(row) * .1, -7.45 + _rng.randf_range(-.06, .06), Vector3(.09, .085, 1.2), tone, .7, 1.0)

func _chimney_r(y: float) -> float:
	return lerpf(STACK_R0, STACK_R1, y / STACK_TALL)

func _chimney() -> void:
	# Brick, hooped in steel after the 2031 quake; soot climbing as it goes, as they all do.
	var sides := 20
	var y := 0.0
	var lift := 1.4
	var base := Color("#8b4a35")
	while y < STACK_TALL - .01:
		var y1 := minf(y + lift, STACK_TALL)
		var r0 := _chimney_r(y)
		var r1 := _chimney_r(y1)
		var soot := smoothstep(11.0, STACK_TALL, y)
		var tint := base.lerp(Color("#2a2320"), soot * .75) * _rng.randf_range(.9, 1.06)
		for s: int in range(sides):
			var a0 := TAU * float(s) / float(sides)
			var a1 := TAU * float(s + 1) / float(sides)
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			var run0 := a0 * (r0 + r1) * .5
			var run1 := a1 * (r0 + r1) * .5
			_kit.mapped("brick", [STACK + d0 * r0 + Vector3.UP * y, STACK + d0 * r1 + Vector3.UP * y1, STACK + d1 * r1 + Vector3.UP * y1, STACK + d1 * r0 + Vector3.UP * y], [d0, d0, d1, d1], [Vector2(run0, -y), Vector2(run0, -y1), Vector2(run1, -y1), Vector2(run1, -y)], [.25 + soot * .4, .25 + soot * .4, .25 + soot * .4, .25 + soot * .4], tint)
		y = y1
	var hoop := 4.2
	while hoop < STACK_TALL - 1.0:
		var r := _chimney_r(hoop) + .018
		_kit.lathe("metal", STACK + Vector3.UP * hoop, [Vector2(r - .02, 0), Vector2(r + .012, .005), Vector2(r + .012, .08), Vector2(r - .02, .085)], Color("#1e1d1c"), 20)
		hoop += 2.3
	# Crown: an iron collar and a short black cap.
	var top := STACK + Vector3.UP * STACK_TALL
	var tip := STACK_R1
	_kit.lathe("metal", top + Vector3.DOWN * .36, [Vector2(tip + .01, 0), Vector2(tip + .05, .06), Vector2(tip + .05, .3), Vector2(tip + .09, .36), Vector2(tip + .09, .44), Vector2(tip - .03, .46), Vector2(tip - .05, .6), Vector2(tip - .1, .6), Vector2(tip - .1, -.3)], Color("#1b1a19"), 20)
	# House name on the street face.
	var cols := 10
	var low := 13.2
	var high := 18.0
	var rect := _cell(0, 1100, 200, 900)
	for c: int in range(cols):
		var u0 := float(c) / float(cols)
		var u1 := float(c + 1) / float(cols)
		var a0 := deg_to_rad(lerpf(-62.0, 62.0, u0))
		var a1 := deg_to_rad(lerpf(-62.0, 62.0, u1))
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var rl := _chimney_r(low) + .012
		var rh := _chimney_r(high) + .012
		var points: Array[Vector3] = [STACK + d0 * rl + Vector3.UP * low, STACK + d0 * rh + Vector3.UP * high, STACK + d1 * rh + Vector3.UP * high, STACK + d1 * rl + Vector3.UP * low]
		var prints: Array[Vector2] = [Vector2(rect.position.x + rect.size.x * u0, rect.end.y), Vector2(rect.position.x + rect.size.x * u0, rect.position.y), Vector2(rect.position.x + rect.size.x * u1, rect.position.y), Vector2(rect.position.x + rect.size.x * u1, rect.end.y)]
		var normals: Array[Vector3] = [d0, d0, d1, d1]
		var marks: Array[float] = [0.0, 0.0, 0.0, 0.0]
		_kit.mapped("paint", points, normals, prints, marks, Color(.92, .9, .86))
	# Ladder up the east side, in the thin steel the photographs show.
	var dir := Vector3(sin(1.75), 0, cos(1.75))
	var across := Vector3(cos(1.75), 0, -sin(1.75))
	var stand := .15
	var rail := Color("#3b3a38")
	for s: float in [-1.0, 1.0]:
		var foot := STACK + dir * (_chimney_r(3.6) + stand) + across * s * .17 + Vector3.UP * 3.6
		var head := STACK + dir * (_chimney_r(STACK_TALL - .1) + stand) + across * s * .17 + Vector3.UP * (STACK_TALL - .1)
		_kit.tube("metal", [foot, head], .014, rail, 4)
	var rung := 3.8
	while rung < STACK_TALL - .2:
		var at := STACK + dir * (_chimney_r(rung) + stand) + Vector3.UP * rung
		_kit.beam("metal", at - across * .17, at + across * .17, .018, .018, Vector3.UP, rail)
		rung += .34
	var brace := 4.6
	while brace < STACK_TALL - 1.0:
		var at := STACK + dir * _chimney_r(brace) + Vector3.UP * brace
		_kit.beam("metal", at, at + dir * stand, .03, .03, Vector3.UP, rail)
		brace += 3.4
	# 2044: heat exchanger clamped on above the roofline, two lagged pipes back into the hall.
	var band := STACK + Vector3.UP * 10.8
	var r := _chimney_r(10.8)
	_kit.lathe("metal", band, [Vector2(r, 0), Vector2(r + .07, .03), Vector2(r + .07, .7), Vector2(r, .74)], Color("#6f7375"), 20)
	for i: int in range(3):
		_kit.lathe("metal", band + Vector3.UP * (.12 + float(i) * .22), [Vector2(r + .07, 0), Vector2(r + .09, .01), Vector2(r + .09, .03), Vector2(r + .07, .04)], Color("#55595b"), 20)
	var west := STACK + Vector3(-r - .1, 11.3, 0)
	for i: int in range(2):
		var dz := float(i) * .16 - .08
		_kit.tube("plain", [west + Vector3(0, float(i) * -.18, dz), west + Vector3(-.3, float(i) * -.18, dz), Vector3(1.05, 8.0, -7.5 + dz), Vector3(.82, 8.0, -7.3 + dz)], .05, Color("#c9c6bc"), 6)
	_kit.block("metal", Transform3D(Basis.IDENTITY, band + Vector3(0, .42, r + .1)), Vector3(.12, .16, .05), Color("#8f9290"))
	_kit.block("led", Transform3D(Basis.IDENTITY, band + Vector3(.03, .46, r + .13)), Vector3(.02, .02, .01), GREEN)
	_fibre([STACK + Vector3(-.2, 3.4, .72), STACK + Vector3(-.12, 10.4, .54)])

func _blade() -> void:
	# Narrow lit sign off the east corner, for the people who can't see the chimney any more.
	var x := WIDE - .08
	var low := 3.98
	var high := 5.76
	var near := .2
	var far := .7
	_bar("metal", _f, x, (low + high) * .5, (near + far) * .5, Vector3(.09, high - low + .05, far - near + .05), Color("#2c2b2a"))
	_kit.atlas("sign", _p(x + .05, low, far), _p(x + .05, high, far), _p(x + .05, high, near), _p(x + .05, low, near), _cell(880, 1100, 170, 600))
	_kit.atlas("sign", _p(x - .05, low, near), _p(x - .05, high, near), _p(x - .05, high, far), _p(x - .05, low, far), _cell(880, 1100, 170, 600))
	for y: float in [low + .22, high - .22]:
		_bar("metal", _f, x, y, .1, Vector3(.05, .05, .22), STEEL)

func _street_things() -> void:
	_mamachari(Transform3D(Basis(Vector3.UP, .22), _p(.5, .07, .92)), Color("#b8bcbc"), true)
	_mamachari(Transform3D(Basis(Vector3.UP, -.16), _p(1.14, .07, 1.0)), Color("#8a2f28"), false)
	_towel_rack()
	_hours_stand()
	# The pot of black pine by the post, and a yellow basin airing on a stool.
	var pot := _p(1.72, .07, .96)
	_kit.lathe("plain", pot, [Vector2(.14, 0), Vector2(.2, .24), Vector2(.21, .26), Vector2(.17, .26), Vector2(0, .22)], Color("#5a3a2c"), 12)
	_plant(pot + Vector3.UP * .22, .62, Color("#2f5230"))
	var stool := _p(1.7, .07, .36)
	for s: Vector2 in [Vector2(-.1, -.1), Vector2(.1, -.1), Vector2(-.1, .1), Vector2(.1, .1)]:
		_kit.block("plain", Transform3D(Basis.IDENTITY, stool + Vector3(s.x, .1, s.y)), Vector3(.03, .2, .03), Color("#d8d4c6"))
	_kit.block("plain", Transform3D(Basis.IDENTITY, stool + Vector3.UP * .21), Vector3(.28, .03, .28), Color("#d8d4c6"))
	_kit.lathe("plain", stool + Vector3.UP * .225, [Vector2(.08, 0), Vector2(.13, .02), Vector2(.15, .11), Vector2(.14, .11), Vector2(.12, .025), Vector2(0, .02)], Color("#e8c02c"), 14)

func _hours_stand() -> void:
	# Opening hours on a folding wooden easel, leaning on the window's tile.
	var at := Vector3(4.96, .07, .72)
	var lean := .12
	var a := _p(at.x - .2, at.y + .42, at.z + lean * .4)
	var b := _p(at.x - .2, at.y + 1.0, at.z)
	var c := _p(at.x + .2, at.y + 1.0, at.z)
	var d := _p(at.x + .2, at.y + .42, at.z + lean * .4)
	_kit.atlas("board", a, b, c, d, _cell(1550, 540, 240, 320))
	for s: float in [-.21, .21]:
		_kit.tube("plain", [_p(at.x + s, at.y, at.z + lean), _p(at.x + s, at.y + 1.03, at.z - .012)], .012, TAN, 4)
		_kit.tube("plain", [_p(at.x + s, at.y, at.z - lean - .12), _p(at.x + s, at.y + 1.03, at.z - .012)], .01, TAN, 4)
	_kit.tube("plain", [_p(at.x - .21, at.y + .42, at.z + lean * .4 - .006), _p(at.x + .21, at.y + .42, at.z + lean * .4 - .006)], .012, TAN, 4)

func _towel_rack() -> void:
	# Hand towels drying in the porch's lee: an old wooden rack with feet, folded over its rails.
	var x0 := 5.26
	var x1 := 6.34
	var z := .56
	for x: float in [x0, x1]:
		_bar("plain", _f, x, .82, z, Vector3(.045, 1.5, .045), Color("#8a6a44"))
		_bar("plain", _f, x, .1, z, Vector3(.05, .05, .42), Color("#7a5c3a"))
	var rails: Array[Vector2] = [Vector2(1.56, .0), Vector2(.98, .1)]
	_bar("plain", _f, x0, .98, z + .05, Vector3(.03, .03, .13), Color("#8a6a44"))
	_bar("plain", _f, x1, .98, z + .05, Vector3(.03, .03, .13), Color("#8a6a44"))
	for rail: Vector2 in rails:
		_kit.tube("plain", [_p(x0, rail.x, z + rail.y), _p(x1, rail.x, z + rail.y)], .014, Color("#a08458"), 6)
		var x := x0 + .06 + rail.y * .6
		var i := int(rail.y * 10.0)
		while x < x1 - .22:
			var wide := .2 + float(i % 2) * .04
			var long := .38 + float(i % 3) * .05
			_towel(x, wide, long, rail.x, z + rail.y, i)
			x += wide + .07
			i += 1

func _towel(x: float, wide: float, long: float, y: float, z: float, seed_at: int) -> void:
	# Doubled over the rail, the two faces hanging in shallow folds, a dyed stripe near each end.
	var tones: Array[Color] = [Color("#e6e2d6"), Color("#dcdfe2"), Color("#e8dfd0")]
	var base := tones[seed_at % 3]
	var stripe := Color("#2f5e96") if seed_at % 2 == 0 else Color("#a0392e")
	var columns := 4
	for s: float in [1.0, -1.0]:
		var bottom := y - long * (1.0 if s > 0.0 else .84)
		for c: int in range(columns):
			var u0 := float(c) / float(columns)
			var u1 := float(c + 1) / float(columns)
			if s < 0.0:
				var flip := u0
				u0 = 1.0 - u1
				u1 = 1.0 - flip
			var a0 := x + wide * u0
			var a1 := x + wide * u1
			var w0 := s * (.018 + sin(u0 * 9.0 + float(seed_at)) * .012)
			var w1 := s * (.018 + sin(u1 * 9.0 + float(seed_at)) * .012)
			_kit.quad("plain", _p(a0, bottom, z + w0), _p(a0, y + .014, z + s * .006), _p(a1, y + .014, z + s * .006), _p(a1, bottom, z + w1), base, .85, 1.0)
			if s > 0.0:
				_kit.quad("plain", _p(a0, bottom + .04, z + w0 + .002), _p(a0, bottom + .07, z + w0 + .002), _p(a1, bottom + .07, z + w1 + .002), _p(a1, bottom + .04, z + w1 + .002), stripe)

func _mamachari(t: Transform3D, tint: Color, basket: bool) -> void:
	# A shopping bicycle: step-through frame, stand down, wire basket, a seat gone at the corner.
	var black := Color("#17181a")
	var rear := t * Vector3(0, .32, .56)
	var front := t * Vector3(0, .32, -.5)
	for hub: Vector3 in [rear, front]:
		var ring: Array[Vector3] = []
		for i: int in range(21):
			var a := TAU * float(i) / 20.0
			ring.append(hub + (t.basis.y * sin(a) + t.basis.z * cos(a)) * .31)
		_kit.tube("metal", ring, .014, black, 4)
		for i: int in range(10):
			var a := TAU * float(i) / 10.0
			_kit.tube("metal", [hub, hub + (t.basis.y * sin(a) + t.basis.z * cos(a)) * .3], .002, ALUMINIUM, 3)
		_kit.lathe("metal", hub + t.basis.x * -.03 + Vector3.DOWN * .03, [Vector2(.03, 0), Vector2(.03, .06)], ALUMINIUM, 6)
	var crank := t * Vector3(0, .3, .1)
	var seat := t * Vector3(0, .92, .34)
	var head := t * Vector3(0, .88, -.36)
	var low := t * Vector3(0, .42, -.05)
	_kit.tube("metal", [head, low, crank], .018, tint, 5)
	_kit.tube("metal", [crank, seat], .017, tint, 5)
	_kit.tube("metal", [crank, rear], .011, tint, 4)
	_kit.tube("metal", [seat + t.basis.y * -.1, rear], .009, tint, 4)
	_kit.tube("metal", [head + t.basis.y * .12, head + t.basis.y * -.1, front], .016, tint, 4)
	_kit.tube("metal", [head + t.basis.y * .14 + t.basis.x * -.27 + t.basis.z * .12, head + t.basis.y * .14, head + t.basis.y * .14 + t.basis.x * .27 + t.basis.z * .12], .012, ALUMINIUM, 4)
	_kit.lathe("plain", seat + t.basis.z * .05, [Vector2(.03, 0), Vector2(.1, .03), Vector2(.11, .06), Vector2(.07, .09), Vector2(0, .095)], Color("#2a2622"), 9)
	_kit.disc("plain", crank + t.basis.x * .03, t.basis.z, t.basis.y, .08, black)
	# Rear carrier and chain guard.
	for s: float in [-.07, 0.0, .07]:
		_kit.tube("metal", [t * Vector3(s, .66, .44), t * Vector3(s, .66, .8)], .006, ALUMINIUM, 3)
	_kit.tube("metal", [t * Vector3(-.07, .66, .8), t * Vector3(.07, .66, .8)], .006, ALUMINIUM, 3)
	_kit.tube("metal", [t * Vector3(.06, .66, .78), rear], .006, ALUMINIUM, 3)
	_kit.tube("metal", [t * Vector3(-.06, .66, .78), rear], .006, ALUMINIUM, 3)
	_kit.block("plain", Transform3D(t.basis, t * Vector3(.04, .32, .33)), Vector3(.01, .11, .44), tint.darkened(.25))
	_kit.tube("metal", [t * Vector3(.05, .34, .5), t * Vector3(.2, .0, .56)], .009, ALUMINIUM, 3)
	if not basket: return
	var at := t * Vector3(0, .9, -.62)
	var rim: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-.18, -.14), Vector2(.18, -.14), Vector2(.18, .14), Vector2(-.18, .14), Vector2(-.18, -.14)]:
		rim.append(at + t.basis * Vector3(corner.x, .2, corner.y))
		bottom.append(at + t.basis * Vector3(corner.x * .8, 0, corner.y * .8))
	_kit.tube("metal", rim, .006, ALUMINIUM, 3)
	_kit.tube("metal", bottom, .004, ALUMINIUM, 3)
	for i: int in range(14):
		var u := float(i) / 14.0 * 4.0
		var k := int(u)
		_kit.tube("metal", [bottom[k].lerp(bottom[k + 1], u - float(k)), rim[k].lerp(rim[k + 1], u - float(k))], .0035, ALUMINIUM, 3)
