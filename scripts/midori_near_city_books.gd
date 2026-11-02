extends "res://scripts/midori_near_city_handmade.gd"
## 紙魚堂書店: a used bookshop named for the silverfish, open to the pavement since the war.
## Cases face the street, carts of ¥100 stock stand under the tile, and the owner sits at the far
## end of the middle aisle behind a wall of what nobody has priced. A map dealer's shutter has
## been down upstairs for two years; a marine scrivener still keeps the frosted room above it.
const ATLAS := "res://assets/shinrai/near_city/books_atlas.png"
const WIDE := 4.14
const DEEP := 10.2
const GROUND := 3.3
const SECOND := 5.75
const EAVE := 8.0
const RIDGE := 10.4
const ROOM_TOP := 2.95
const ROOM_BACK := 8.9
const RECESS := .42
const WALL_NEAR := .72
const WALL_FAR := 7.32
const ISLE_NEAR := 1.1
const ISLE_FAR := 6.9
const X0 := .12
const X1 := WIDE - .12
const POST := .24
const GAP := Rect2(1.3, 0, 1.9, 2.84)
const BAND := 190.0
const PM := 760.0
const SOOT := Color("#221610")
const STAIN := Color("#3a2418")
const CASE := Color("#553322")
const FLOOR := Color("#3f3226")
const SCRATCH := Color("#3d2a21")
const ROOF := Color("#3f4044")
const SUBJECTS: Array = [[2, 3], [3, 4], [2, 5], [4, 7], [6, 2], [5, 3], [7, 4], [2, 6], [3, 6]]
const TALL_LEVELS: Array[float] = [.32, .3, .28, .27, .27, .27, .27, .27, .21, .21]

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1923
	_build_looks()
	_room()
	_wall_cases()
	_islands()
	_cashier()
	_aisle_things()
	_street_cases()
	_frontage()
	_pent_roof()
	_map_floor()
	_office_floor()
	_flanks()
	_roof()
	_carts()
	_street_things()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "led", "room", "shelf", "spines", "floor", "frost", "indoor_cover", "pages"])
	_kit = null
	_omni("BooksAisle", Vector3(.18, 2.5, -3.6), Color(1.0, .82, .6), .75, 5.5)
	_omni("BooksCart", Vector3(-.3, 2.62, .5), Color(1.0, .76, .5), .85, 4.5)

func _atlas_look(key: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[key] = look

func _build_looks() -> void:
	_shared_looks()
	_atlas_look("spines", .8, .34, .24)
	_atlas_look("spines_out", .8, .12, .06)
	_atlas_look("indoor_cover", .7, .3, .22)
	_atlas_look("cover", .7, .1, .04)
	_atlas_look("pages", .9, .3, .2)
	_atlas_look("paper", .9, .12, .05)
	_atlas_look("board", .6, .1, .03)
	_atlas_look("frost", .3, .36, .1)
	_looks.timber = _look("japanese_cedar_planks", 1.6, .8)
	_looks.timber.set_shader_parameter("chroma", .42)
	_looks.shelf = _look("japanese_cedar_planks", 1.6, .6)
	_looks.shelf.set_shader_parameter("chroma", .5)
	_looks.shelf.set_shader_parameter("glow", .3)
	_looks.shelf.set_shader_parameter("day_glow", .22)
	_looks.floor = _look("japanese_cedar_planks", 1.4, .55)
	_looks.floor.set_shader_parameter("chroma", .5)
	_looks.floor.set_shader_parameter("glow", .22)
	_looks.floor.set_shader_parameter("day_glow", .17)
	_looks.room = _look("plastered_wall_03", 2.0, .9)
	_looks.room.set_shader_parameter("glow", .28)
	_looks.room.set_shader_parameter("day_glow", .2)
	_looks.render = _look("japanese_cedar_planks", 2.0, .92)
	_looks.render.set_shader_parameter("chroma", .45)
	_looks.scratch = _look("", 1.0, .7)
	_looks.scratch.set_shader_parameter("tile_size", Vector2(.227, .062))
	_looks.shutter = _look("painted_metal_shutter", 1.4, .7, .25)
	_looks.tile = _look("", 1.0, .46, .15)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", load(ATLAS))
	letters.set_shader_parameter("glow", .3)
	letters.set_shader_parameter("day_glow", .05)
	_looks.decal = letters

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _cover_cell(i: int) -> Rect2:
	return _cell(930.0 + float(i % 8) * 138.0, 1520.0 + float(i / 8) * 186.0, 132, 180)

# Shelving ---------------------------------------------------------------------------------

func _books(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, band: int, shade: float) -> void:
	# One shelf of spines in chunks, pulled a little in and out, so a row is never one flat strip.
	var tall := minf((y1 - y0) * PM, BAND)
	var top := float(band) * BAND + BAND - tall
	var need := (x1 - x0) * PM
	var u := _rng.randf_range(0.0, maxf(2048.0 - need - 4.0, 1.0))
	var x := x0
	var before := -.05
	var tone := Color(shade, shade * .985, shade * .95)
	while x < x1 - .01:
		var run := minf(_rng.randf_range(.16, .46), x1 - x)
		if x1 - x - run < .1: run = x1 - x
		var z := -_rng.randf_range(.03, .058)
		_kit.atlas(part, face * Vector3(x, y0, z), face * Vector3(x, y1, z), face * Vector3(x + run, y1, z), face * Vector3(x + run, y0, z), _cell(u, top, run * PM, tall), tone)
		if x > x0:
			var dark := Color("#120b07")
			var a := minf(before, z)
			var b := maxf(before, z)
			if z > before:
				_kit.quad("plain", face * Vector3(x, y0, a), face * Vector3(x, y1, a), face * Vector3(x, y1, b), face * Vector3(x, y0, b), dark)
			else:
				_kit.quad("plain", face * Vector3(x, y0, b), face * Vector3(x, y1, b), face * Vector3(x, y1, a), face * Vector3(x, y0, a), dark)
		before = z
		u += run * PM
		x += run

func _board(frame: String, face: Transform3D, x0: float, x1: float, y: float, tint: Color) -> void:
	var under := y - .02
	var deep := -.06
	_kit.quad(frame, face * Vector3(x0, under, 0), face * Vector3(x0, y, 0), face * Vector3(x1, y, 0), face * Vector3(x1, under, 0), tint)
	_kit.quad(frame, face * Vector3(x0, y, 0), face * Vector3(x0, y, deep), face * Vector3(x1, y, deep), face * Vector3(x1, y, 0), tint, 1.0, .6)
	_kit.quad(frame, face * Vector3(x0, under, deep), face * Vector3(x0, under, 0), face * Vector3(x1, under, 0), face * Vector3(x1, under, deep), tint, .5, .6)

func _upright(frame: String, face: Transform3D, x: float, y0: float, y1: float, wide: float, tint: Color) -> void:
	var a := x - wide * .5
	var b := x + wide * .5
	var deep := -.06
	_kit.quad(frame, face * Vector3(a, y0, .002), face * Vector3(a, y1, .002), face * Vector3(b, y1, .002), face * Vector3(b, y0, .002), tint)
	_kit.quad(frame, face * Vector3(a, y0, .002), face * Vector3(a, y1, .002), face * Vector3(a, y1, deep), face * Vector3(a, y0, deep), tint, .6, .6)
	_kit.quad(frame, face * Vector3(b, y0, deep), face * Vector3(b, y1, deep), face * Vector3(b, y1, .002), face * Vector3(b, y0, .002), tint, .6, .6)

func _case(frame: String, part: String, face: Transform3D, x0: float, x1: float, bottom: float, levels: Array[float], bay: float, tint := CASE) -> float:
	# A run of shelving: boards the whole length, uprights each bay, its stock chosen by subject.
	var bays := maxi(int(round((x1 - x0) / bay)), 1)
	var wide := (x1 - x0) / float(bays)
	var subject: Array = []
	for b: int in range(bays): subject.append(SUBJECTS[_rng.randi_range(0, SUBJECTS.size() - 1)])
	var y := bottom
	for i: int in range(levels.size()):
		var clear: float = levels[i] - .02
		_board(frame, face, x0, x1, y, tint)
		for b: int in range(bays):
			var left := x0 + float(b) * wide + .012
			var right := left + wide - .024
			var band: int = subject[b].pick_random()
			if clear < .2: band = _rng.randi_range(0, 1)
			elif levels[i] >= .3: band = [4, 5, 7].pick_random()
			elif _rng.randf() < .22: band = _rng.randi_range(2, 7)
			var shade := lerpf(.7, 1.0, clampf(y / 1.5, 0.0, 1.0)) * _rng.randf_range(.86, 1.04)
			_books(part, face, left, right, y, y + clear, band, shade)
			if clear > .22 and _rng.randf() < .07:
				_face_out(part, face, lerpf(left, right, _rng.randf_range(.1, .7)), y)
		y += levels[i]
	_board(frame, face, x0, x1, y, tint)
	for b: int in range(bays + 1):
		_upright(frame, face, x0 + float(b) * wide, bottom - .02, y, .03, tint)
	return y

func _face_out(part: String, face: Transform3D, x: float, y: float) -> void:
	# A book turned to show its cover, resting back against the row.
	var cover := "indoor_cover" if part == "spines" else "cover"
	var wide := .14
	var tall := .2
	var cell := _cover_cell(_rng.randi_range(0, 15))
	_kit.atlas(cover, face * Vector3(x, y, -.012), face * Vector3(x, y + tall, -.028), face * Vector3(x + wide, y + tall, -.028), face * Vector3(x + wide, y, -.012), cell)

func _end_panel(frame: String, face: Transform3D, x0: float, x1: float, top: float, z: float, tint := CASE) -> void:
	_bar(frame, face, (x0 + x1) * .5, top * .5, z, Vector3(x1 - x0, top, .022), tint)

func _book(part: String, xf: Transform3D, size: Vector3, tint := Color.WHITE) -> void:
	# A real book: size is thick (x), tall (y), deep (z), and the spine faces local +Z.
	var cover := "indoor_cover" if part == "pages" else "cover"
	var edge := part
	var half := size * .5
	var art := _cover_cell(_rng.randi_range(0, 15))
	var page := _cell(590, 1905 + _rng.randf_range(0, 80), 200, 30)
	var slice := Rect2(art.position + Vector2(0, art.size.y * .04), Vector2(art.size.x * .14, art.size.y * .9))
	var p := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x * half.x, y * half.y, z * half.z)
	_kit.atlas(cover, p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, -1, 1), slice, tint)
	_kit.atlas(cover, p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(1, -1, -1), art, tint)
	_kit.atlas(cover, p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, -1, 1), art, tint)
	_kit.atlas(edge, p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), p.call(-1, -1, -1), page, tint)
	_kit.atlas(edge, p.call(-1, 1, 1), p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), page, tint)
	_kit.atlas(edge, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, -1, -1), page, tint)

func _pile(part: String, base: Vector3, count: int, along: Vector3 = Vector3.RIGHT) -> float:
	# Books lying flat, each squared up about as well as the last. Returns the height reached.
	var y := base.y
	var spin := atan2(-along.z, along.x)
	for i: int in range(count):
		var thick := _rng.randf_range(.022, .05)
		var wide := _rng.randf_range(.15, .24)
		var long := wide * _rng.randf_range(1.2, 1.5)
		var turn := Basis(Vector3.UP, spin + _rng.randf_range(-.14, .14)) * Basis(Vector3.BACK, PI * .5)
		var at := Vector3(base.x + _rng.randf_range(-.015, .015), y + thick * .5, base.z + _rng.randf_range(-.015, .015))
		_book(part, Transform3D(turn, at), Vector3(thick, long, wide), Color(1, 1, 1).darkened(_rng.randf_range(0.0, .2)))
		y += thick
	return y

# Inside -----------------------------------------------------------------------------------

func _room() -> void:
	var f := _front
	var near := -RECESS
	var far := -ROOM_BACK
	# Old boards down the aisles, worn pale along the middle where the customers go.
	var x := X0
	while x < X1 - .01:
		var wide := minf(.3, X1 - x)
		var worn := 1.0 + .18 * (1.0 - absf(x + wide * .5 - 2.25) / 2.0)
		var tint := Color(FLOOR.r * worn, FLOOR.g * worn, FLOOR.b * worn) * _rng.randf_range(.86, 1.0)
		_kit.quad("floor", f * Vector3(x, .03, near), f * Vector3(x, .03, far), f * Vector3(x + wide, .03, far), f * Vector3(x + wide, .03, near), tint, .9, .9, 0.0, Vector2(x * 3.0, 0))
		_kit.quad("plain", f * Vector3(x, .032, near), f * Vector3(x, .032, far), f * Vector3(x + .006, .032, far), f * Vector3(x + .006, .032, near), Color("#17100b"))
		x += wide
	var plaster := Color("#8d7a5c")
	_kit.quad("room", f * Vector3(X0, ROOM_TOP, far), f * Vector3(X0, ROOM_TOP, near), f * Vector3(X1, ROOM_TOP, near), f * Vector3(X1, ROOM_TOP, far), Color("#3a3026"), .7, .7)
	_kit.quad("room", f * Vector3(X0, 0, near), f * Vector3(X0, ROOM_TOP, near), f * Vector3(X0, ROOM_TOP, far), f * Vector3(X0, 0, far), plaster, .7, .8)
	_kit.quad("room", f * Vector3(X1, 0, far), f * Vector3(X1, ROOM_TOP, far), f * Vector3(X1, ROOM_TOP, near), f * Vector3(X1, 0, near), plaster, .7, .8)
	_kit.quad("room", f * Vector3(X0, 0, far), f * Vector3(X0, ROOM_TOP, far), f * Vector3(X1, ROOM_TOP, far), f * Vector3(X1, 0, far), plaster, .7, .8)
	# Ceiling joists, and the lights: two enamel shades down the middle, a tube over each side aisle.
	var z := -1.0
	while z > far:
		_bar("shelf", f, 2.07, ROOM_TOP - .04, z, Vector3(X1 - X0, .08, .09), Color("#3a2416"))
		z -= 1.3
	for at: float in [-2.2, -4.7]:
		_pendant(f * Vector3(2.25, 2.36, at))
	for x2: float in [.86, 3.44]:
		_bar("metal", f, x2, ROOM_TOP - .1, -4.0, Vector3(.1, .05, 1.26), Color("#b6ad98"))
		_bar("lamp", f, x2, ROOM_TOP - .135, -4.0, Vector3(.035, .03, 1.2), Color(.62, .52, .36))

func _pendant(at: Vector3) -> void:
	_kit.tube("plain", [at + Vector3.UP * .14, at + Vector3.UP * (ROOM_TOP - at.y - .06)], .006, Color("#141210"), 4)
	_kit.lathe("shelf", at, [Vector2(.2, 0), Vector2(.18, .02), Vector2(.09, .1), Vector2(.03, .14), Vector2(.03, .18)], Color("#2d3a33"), 12)
	_kit.lathe("room", at, [Vector2(.03, .15), Vector2(.09, .105), Vector2(.18, .022), Vector2(.2, .001)], Color("#f2e4c4"), 12)
	_ball(at + Vector3.UP * .055, Vector3(.04, .05, .04), Color(1.0, .86, .6), "lamp", 6, 8)

func _wall_cases() -> void:
	var near := -WALL_NEAR
	var far := -WALL_FAR
	var length := WALL_FAR - WALL_NEAR
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), _front * Vector3(.37, 0, near))
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), _front * Vector3(3.77, 0, far))
	var top := _case("shelf", "spines", west, 0, length, .12, TALL_LEVELS, .9)
	_case("shelf", "spines", east, 0, length, .12, TALL_LEVELS, .9)
	# The case's sides and plinths, and a rail for a ladder that went years ago.
	for face: Transform3D in [west, east]:
		_bar("shelf", face, length * .5, .06, -.02, Vector3(length, .12, .04), Color("#3a2416"))
		_bar("shelf", face, length * .5, top + .02, -.09, Vector3(length, .05, .2), CASE)
		_bar("shelf", face, length * .5, 2.46, .03, Vector3(length, .022, .02), Color("#7f6236"))
	# Boxed sets stacked on the top of each case, up into the dark.
	var along := .5
	while along < length - .3:
		_pile("pages", west * Vector3(along, top + .05, -.1), _rng.randi_range(2, 5), Vector3.BACK)
		_pile("pages", east * Vector3(along, top + .05, -.1), _rng.randi_range(2, 5), Vector3.BACK)
		along += _rng.randf_range(.4, .9)

func _islands() -> void:
	var levels: Array[float] = [.32, .3, .28, .27, .27, .27, .21, .21]
	var length := ISLE_FAR - ISLE_NEAR
	for x: float in [1.38, 2.68]:
		var wide := .44
		var near := -ISLE_NEAR
		var far := -ISLE_FAR
		var west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), _front * Vector3(x, 0, far))
		var east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), _front * Vector3(x + wide, 0, near))
		var top := _case("shelf", "spines", west, 0, length, .12, levels, .9)
		_case("shelf", "spines", east, 0, length, .12, levels, .9)
		var f := _at(_front, x + wide * .5, 0, 0)
		var mid := (near + far) * .5
		_bar("shelf", f, 0, top + .02, mid, Vector3(wide + .03, .04, length + .04), CASE)
		_bar("shelf", f, 0, .06, mid, Vector3(wide - .02, .12, length), Color("#3a2416"))
		_bar("shelf", f, 0, top * .5, mid, Vector3(.02, top, length), Color("#2a1a10"))
		# The end of the case: boards, a wooden subject tag, a sheet of paper pinned to it.
		_end_panel("shelf", _front, x - .01, x + wide + .01, top + .04, near + .012)
		_end_panel("shelf", _front, x - .01, x + wide + .01, top + .04, far - .012)
		var tag := 0 if x < 2.0 else 2
		_panel("indoor_cover", _front, x + .03, x + wide - .03, top - .2, top - .06, near + .026, _cell(930.0 + float(tag) * 158.0, 1890, 150, 60))
		_panel("indoor_cover", _front, x + .08, x + wide - .08, 1.1, 1.52, near + .026, _cell(0, 1680, 220, 340) if x < 2.0 else _cover_cell(5), Color(.86, .84, .78))
		# Stock waiting to be shelved, along the top of the case.
		var z := near - .3
		while z > far + .3:
			_pile("pages", _front * Vector3(x + wide * .5, top + .04, z), _rng.randi_range(2, 7), Vector3(1, 0, _rng.randf_range(-.3, .3)))
			z -= _rng.randf_range(.34, .8)

func _cashier() -> void:
	# 帳場: raised boards at the end of the middle aisle, a desk, and a wall of the unpriced.
	var f := _front
	var far := -ROOM_BACK
	var lip := -7.62
	var y := .3
	_bar("shelf", f, 2.07, y * .5, (lip + far) * .5, Vector3(X1 - X0, y, far * -1.0 + lip), Color("#3a2416"))
	# Worn tatami on the platform, the binding cloth still showing at the edges.
	var mat := Color("#8a7d50")
	_kit.quad("room", f * Vector3(X0, y + .012, lip - .02), f * Vector3(X0, y + .012, far), f * Vector3(X1, y + .012, far), f * Vector3(X1, y + .012, lip - .02), mat)
	_bar("plain", f, 2.07, y + .014, lip - .05, Vector3(X1 - X0, .004, .05), Color("#1d2a24"))
	var back := Transform3D(_front.basis, _front * Vector3(0, 0, far + .24))
	_kit.quad("shelf", f * Vector3(X0, y, far + .24), f * Vector3(X0, ROOM_TOP, far + .24), f * Vector3(X0 + .02, ROOM_TOP, far + .24), f * Vector3(X0 + .02, y, far + .24), CASE)
	var levels: Array[float] = [.3, .28, .27, .27, .27, .27, .27, .21]
	var top := _case("shelf", "spines", back, X0, X1, y + .04, levels, .96)
	_bar("shelf", f, 2.07, (top + ROOM_TOP) * .5, far + .2, Vector3(X1 - X0, ROOM_TOP - top, .1), Color("#3a2416"))
	# The desk, boarded along its front, with a worn step to it.
	var x := 2.25
	var z := -7.46
	var wide := 1.7
	_bar("shelf", f, x, .78, z, Vector3(wide + .08, .035, .62), Color("#7a4a2a"))
	var at := x - wide * .5
	while at < x + wide * .5 - .01:
		_bar("shelf", f, at + .09, .39, z + .27, Vector3(.17, .76, .02), STAIN * _rng.randf_range(.9, 1.2))
		at += .18
	_bar("shelf", f, x - wide * .5, .39, z, Vector3(.03, .76, .56), STAIN)
	_bar("shelf", f, x + wide * .5, .39, z, Vector3(.03, .76, .56), STAIN)
	var desk := .8
	_pile("pages", f * Vector3(x - .62, desk, z + .05), 11)
	_pile("pages", f * Vector3(x - .3, desk, z - .1), 6)
	_pile("pages", f * Vector3(x + .66, desk, z + .02), 14)
	_pile("pages", f * Vector3(x + .34, desk, z + .12), 3)
	# A ledger, open; the lamp that pools on it; the palm pad the tax office made him buy.
	_kit.atlas("pages", f * Vector3(x - .17, desk + .022, z + .02), f * Vector3(x - .17, desk + .022, z - .22), f * Vector3(x + .17, desk + .022, z - .22), f * Vector3(x + .17, desk + .022, z + .02), _cell(590, 1905, 330, 120))
	var foot := f * Vector3(x + .24, desk, z - .14)
	_kit.lathe("shelf", foot, [Vector2(.07, 0), Vector2(.07, .02), Vector2(.012, .03), Vector2(.012, .32)], Color("#a8884a"), 10)
	var head := foot + Vector3(-.08, .33, .05)
	_kit.tube("shelf", [foot + Vector3.UP * .32, head + Vector3.UP * .03], .012, Color("#a8884a"), 5)
	_kit.lathe("shelf", head, [Vector2(.11, 0), Vector2(.1, .03), Vector2(.05, .07), Vector2(.02, .08)], Color("#2d4a3a"), 10)
	_ball(head + Vector3.UP * .01, Vector3(.035, .03, .035), Color(1.0, .86, .6), "lamp", 5, 8)
	_kit.quad("lamp", f * Vector3(x - .08, desk + .024, z - .02), f * Vector3(x - .08, desk + .024, z - .16), f * Vector3(x + .08, desk + .024, z - .16), f * Vector3(x + .08, desk + .024, z - .02), Color(.22, .17, .1))
	_bar("metal", f, x - .08, desk + .018, z + .22, Vector3(.13, .03, .13), Color("#25282c"))
	_bar("led", f, x - .08, desk + .034, z + .22, Vector3(.1, .002, .1), CYAN * .35)
	# His chair, the wall clock, a calendar from a printer that shut in 2039.
	var chair := f * Vector3(x - .42, y, z - .74)
	_kit.block("shelf", Transform3D(Basis.IDENTITY, chair + Vector3(0, .42, 0)), Vector3(.42, .04, .4), Color("#5a3a22"))
	_kit.block("room", Transform3D(Basis.IDENTITY, chair + Vector3(0, .46, 0)), Vector3(.38, .04, .36), Color("#6a2a24"))
	_kit.block("shelf", Transform3D(Basis.IDENTITY, chair + Vector3(0, .62, -.19)), Vector3(.4, .2, .03), Color("#5a3a22"))
	for sx: float in [-.18, .18]:
		for sz: float in [-.17, .17]:
			_kit.block("shelf", Transform3D(Basis.IDENTITY, chair + Vector3(sx, .2, sz)), Vector3(.03, .4, .03), Color("#3a2416"))
	_panel("indoor_cover", Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), _front * Vector3(X0 + .012, 0, lip)), .1, .46, 1.3, 1.82, 0, _cover_cell(9), Color(.9, .88, .8))
	# Stock heaped against the desk, and the clock over him.
	for row: Array in [[1.5, -7.0, 12], [1.74, -7.04, 7], [2.98, -7.02, 15], [2.76, -7.0, 6]]:
		_pile("pages", f * Vector3(row[0], .03, row[1]), row[2], Vector3(1, 0, _rng.randf_range(-.3, .3)))
	var dial := f * Vector3(2.25, 2.72, far + .262)
	_kit.disc("shelf", dial, Vector3.RIGHT, Vector3.UP, .15, Color("#3a2416"))
	_kit.disc("room", dial + Vector3(0, 0, .006), Vector3.RIGHT, Vector3.UP, .125, Color("#e6dcc0"))
	_kit.beam("plain", dial + Vector3(0, 0, .012), dial + Vector3(.06, .05, .012), .008, .002, Vector3.BACK, Color("#17120e"))
	_kit.beam("plain", dial + Vector3(0, 0, .012), dial + Vector3(-.03, .1, .012), .006, .002, Vector3.BACK, Color("#17120e"))

func _aisle_things() -> void:
	var f := _front
	# A wooden kick-step, two treads on splayed sides, in the wide west aisle.
	var s := Vector3(.84, 0, -2.6)
	var tone := Color("#7a5230")
	for side: float in [-.17, .17]:
		_kit.beam("shelf", f * (s + Vector3(side, 0, .22)), f * (s + Vector3(side, .46, -.1)), .03, .1, Vector3.BACK, tone)
		_kit.beam("shelf", f * (s + Vector3(side, 0, -.26)), f * (s + Vector3(side, .46, -.1)), .03, .08, Vector3.BACK, tone.darkened(.2))
	_bar("shelf", f, s.x, .46, s.z - .08, Vector3(.4, .025, .26), tone)
	_bar("shelf", f, s.x, .22, s.z + .05, Vector3(.38, .025, .2), tone)
	# Piles on the floor, because the cases gave out long ago.
	for row: Array in [[.56, -1.5, 12], [.54, -5.5, 16], [.6, -5.88, 9], [3.52, -2.3, 14], [3.5, -2.72, 8], [1.24, -6.98, 11], [3.3, -6.96, 13], [1.2, -3.3, 7], [2.82, -7.06, 6]]:
		_pile("pages", f * Vector3(row[0], .03, row[1]), row[2], Vector3(1, 0, _rng.randf_range(-.4, .4)))
	# A few books out of the row and lying where the last customer left them.
	for row: Array in [[1.9, 1.34, -2.52, 0.0], [2.56, 1.34, -4.3, 0.0]]:
		var tilt := Basis(Vector3.UP, _rng.randf_range(-.3, .3)) * Basis(Vector3.FORWARD, .12)
		_book("pages", Transform3D(tilt, f * Vector3(row[0], row[1], row[2])), Vector3(.026, .21, .15))

func _street_cases() -> void:
	# Two cases facing straight onto the pavement, their backs to the shop, as at the 矢口 corner.
	var levels: Array[float] = [.32, .3, .3, .27, .27, .27, .27, .21, .21]
	var f := Transform3D(_front.basis, _front * Vector3(0, 0, -RECESS))
	var red := Color("#5a2c1c")
	var top := _case("timber", "spines_out", f, POST, GAP.position.x, .24, levels, .53, red)
	_case("timber", "spines_out", f, GAP.end.x, WIDE - POST, .24, levels, .37, red)
	for span: Vector2 in [Vector2(POST, GAP.position.x), Vector2(GAP.end.x, WIDE - POST)]:
		_bar("timber", f, (span.x + span.y) * .5, .12, -.03, Vector3(span.y - span.x, .24, .08), SOOT)
		_bar("timber", f, (span.x + span.y) * .5, (top + GAP.end.y) * .5, -.03, Vector3(span.y - span.x, GAP.end.y - top + .02, .08), SOOT)
		_kit.quad("plain", f * Vector3(span.x, 0, -.075), f * Vector3(span.x, 2.86, -.075), f * Vector3(span.y, 2.86, -.075), f * Vector3(span.y, 0, -.075), Color("#0d0806"))
	# The two returns that frame the way in: the shop's own cheeks of old board.
	for x: float in [GAP.position.x, GAP.end.x]:
		_bar("timber", _front, x, 1.42, -RECESS - .16, Vector3(.1, 2.84, .32), SOOT)

# The street wall ---------------------------------------------------------------------------

func _frontage() -> void:
	var f := _front
	# Great posts at the corners, the lintel across, a threshold stone worn into a dish.
	for x: float in [POST * .5, WIDE - POST * .5]:
		_bar("timber", f, x, GROUND * .5, -RECESS * .5, Vector3(POST, GROUND, RECESS), SOOT)
		_bar("plain", f, x, .1, .004, Vector3(POST + .02, .2, .012), Color("#1a1512"))
	_bar("timber", f, WIDE * .5, (GAP.end.y + GROUND) * .5, -RECESS * .5, Vector3(WIDE - POST * 2.0, GROUND - GAP.end.y, RECESS), SOOT)
	_bar("timber", f, WIDE * .5, GAP.end.y + .02, .02, Vector3(WIDE - POST * 2.0 + .02, .04, .05), STAIN)
	_kit.quad("plain", f * Vector3(POST, .012, 0), f * Vector3(POST, .012, -RECESS), f * Vector3(WIDE - POST, .012, -RECESS), f * Vector3(WIDE - POST, .012, 0), Color("#49433b"), .8, .8)
	_bar("plain", f, 2.25, .018, -RECESS + .02, Vector3(GAP.size.x, .03, .1), Color("#6f685c"))
	# The board: bolted to the lintel, nothing lit but the bulb on its bracket.
	_panel("board", f, .62, 3.5, 2.92, 3.32, .036, _cell(0, 1520, 900, 150))
	_bar("timber", f, 2.06, 3.12, .016, Vector3(2.96, .48, .036), Color("#1b100a"))
	for x2: float in [.74, 3.38]:
		_kit.disc("metal", f * Vector3(x2, 3.12, .038), Vector3.RIGHT, Vector3.UP, .014, Color("#6a5a3c"))
	for x3: float in [.42, 3.72]:
		var arm := f * Vector3(x3, 2.62, .3)
		_kit.tube("metal", [f * Vector3(x3, 2.8, .03), f * Vector3(x3, 2.78, .2), arm + Vector3.UP * .04], .009, Color("#1c1a18"), 4)
		_kit.lathe("metal", arm, [Vector2(.11, 0), Vector2(.1, .015), Vector2(.05, .05), Vector2(.015, .07)], Color("#23272a"), 12)
		_kit.lathe("room", arm, [Vector2(.015, .06), Vector2(.05, .045), Vector2(.1, .012)], Color("#efe2c0"), 12)
		_ball(arm + Vector3.UP * .03, Vector3(.03, .035, .03), Color(1.0, .84, .58), "lamp", 5, 8)

	# Paper on the post, taped at the corners by someone who has done it many times.
	_panel("paper", f, .025, .215, 1.28, 1.57, .006, _cell(0, 1680, 220, 340))
	_bar("plain", f, .12, 1.57, .007, Vector3(.05, .012, .002), Color("#c8bd9a"))
	# 2050: palm pad for the after-hours returns slot, fibre down the east post.
	_bar("metal", f, WIDE - .12, 1.26, .012, Vector3(.1, .16, .024), Color("#22252a"))
	_bar("led", f, WIDE - .12, 1.31, .025, Vector3(.07, .05, .002), CYAN * .28)
	_status(f, WIDE - .08, 1.2, .025, GREEN)
	_fibre([f * Vector3(WIDE - .05, EAVE - .1, .04), f * Vector3(WIDE - .05, 3.95, .04), f * Vector3(WIDE - .05, 3.6, .1), f * Vector3(WIDE - .05, 1.42, .03)])

func _pent_roof() -> void:
	# The tile skirt over the carts: real courses, a dark board under, rafters you can count.
	var low := 3.36
	var high := 3.92
	var out := .82
	var pitch := Vector3(0, high - low, -out).normalized()
	var length := Vector2(out, high - low).length()
	var columns := 15
	var wide := (WIDE + .12) / float(columns)
	_tiles(Vector3(-WIDE * .5 - .06, low, out), Vector3.RIGHT, pitch, columns, wide, 3, length / 3.0, ROOF)
	_eave_ends(Vector3(-WIDE * .5 - .06, low, out), columns, wide)
	var f := _front
	_kit.quad("timber", f * Vector3(-.06, low + .02, .02), f * Vector3(-.06, low + .02, out - .02), f * Vector3(WIDE + .06, low + .02, out - .02), f * Vector3(WIDE + .06, low + .02, .02), Color("#20130c"), .6, .7)
	for i: int in range(6):
		var x := .16 + float(i) * .764
		_kit.beam("timber", f * Vector3(x, 3.26, -.02), f * Vector3(x, low - .03, out - .06), .08, .1, Vector3.UP, SOOT)
	_bar("timber", f, WIDE * .5, low - .01, out - .03, Vector3(WIDE + .12, .08, .04), Color("#20130c"))
	# Copper gutter gone brown, the leader down the west post.
	var y := low - .02
	_kit.tube("metal", [f * Vector3(-.08, y, out + .08), f * Vector3(WIDE + .08, y, out + .08)], .05, Color("#3a2e20"), 8)
	_kit.tube("metal", [f * Vector3(-.03, y, out + .08), f * Vector3(-.03, y - .16, .3), f * Vector3(.05, y - .3, .03), f * Vector3(.05, 0, .03)], .024, Color("#2f261c"), 7)

func _tiles(origin: Vector3, right: Vector3, up: Vector3, columns: int, wide: float, courses: int, long: float, tint: Color) -> void:
	# 桟瓦: each tile an S across, its lower edge lapped over the next, a dark bed beneath.
	var n := right.cross(up).normalized()
	var shape: Array[float] = [0.0, .024, .036, .016, 0.0]
	var span := float(columns) * wide
	var length := float(courses) * long
	_kit.quad("plain", origin, origin + up * length, origin + up * length + right * span, origin + right * span, Color("#101012"))
	for c: int in range(courses):
		var bottom := origin + up * float(c) * long
		for i: int in range(columns):
			var tone := _rng.randf_range(.78, 1.16)
			var shade := Color(tint.r * tone, tint.g * tone, tint.b * tone * _rng.randf_range(.96, 1.06))
			if _rng.randf() < .05: shade = shade.lerp(Color("#5e5a48"), .5)
			var left := bottom + right * float(i) * wide
			for k: int in range(4):
				var a0 := float(k) * .25 * wide
				var a1 := float(k + 1) * .25 * wide
				var a := left + right * a0 + n * (shape[k] + .03)
				var d := left + right * a1 + n * (shape[k + 1] + .03)
				var b := left + right * a0 + up * (long + .03) + n * shape[k] * .7
				var e := left + right * a1 + up * (long + .03) + n * shape[k + 1] * .7
				_kit.quad("tile", a, b, e, d, shade, .78, 1.0, .35)
			# The nose of the tile: lets the lap catch a shadow line.
			_kit.quad("tile", left + right * wide * .02 + n * .002, left + right * wide * .02 + n * .03, left + right * wide * .98 + n * .03, left + right * wide * .98 + n * .002, shade * .5, .5, .7)

func _eave_ends(origin: Vector3, columns: int, wide: float) -> void:
	# Round eave tiles with the family's three-comma crest long since worn to a boss.
	for i: int in range(columns):
		var at := origin + Vector3(float(i) * wide + wide * .42, .012, .012)
		_kit.disc("tile", at, Vector3.RIGHT, Vector3.UP, wide * .36, ROOF * .86)
		_kit.disc("tile", at + Vector3(0, 0, .004), Vector3.RIGHT, Vector3.UP, wide * .14, ROOF * 1.2)

func _map_floor() -> void:
	# 古地図 測量舎: dark board, a steel shutter that has not been up in two years, one lattice slit.
	var f := _front
	var shut := Rect2(.5, 4.1, 2.56, 1.34)
	var slit := Rect2(3.34, 4.2, .46, 1.18)
	for piece: Rect2 in _minus(Rect2(0, GROUND, WIDE, SECOND - GROUND), [shut, slit] as Array[Rect2]):
		var at := piece.position.x
		while at < piece.end.x - .01:
			var w := minf(.19, piece.end.x - at)
			var tone := _rng.randf_range(.8, 1.1)
			_kit.quad("render", f * Vector3(at, piece.position.y, 0), f * Vector3(at, piece.end.y, 0), f * Vector3(at + w, piece.end.y, 0), f * Vector3(at + w, piece.position.y, 0), Color(STAIN.r * tone, STAIN.g * tone, STAIN.b * tone), .92, 1.0, .6, Vector2(at * 2.0, piece.position.y))
			_bar("plain", f, at, (piece.position.y + piece.end.y) * .5, .006, Vector3(.012, piece.size.y, .014), Color("#1d110a"))
			at += w
	_reveal(f, shut, .16, Color("#2a1c14"))
	_kit.quad("shutter", f * Vector3(shut.position.x, shut.position.y, -.13), f * Vector3(shut.position.x, shut.end.y, -.13), f * Vector3(shut.end.x, shut.end.y, -.13), f * Vector3(shut.end.x, shut.position.y, -.13), Color("#6e5a48"), .85, .95, .85)
	_bar("metal", f, shut.get_center().x, shut.end.y + .03, .1, Vector3(shut.size.x + .16, .22, .24), Color("#2c231c"), .8, 1.0)
	for x: float in [shut.position.x + .02, shut.end.x - .02]:
		_bar("metal", f, x, shut.get_center().y, -.1, Vector3(.05, shut.size.y, .07), Color("#3a3028"))
	_bar("metal", f, shut.get_center().x, shut.position.y + .03, -.11, Vector3(shut.size.x - .04, .05, .05), Color("#4c4238"))
	_bar("metal", f, shut.position.x + .4, shut.position.y + .05, -.08, Vector3(.05, .07, .03), Color("#8a8a84"))
	_panel("paper", f, 1.5, 1.82, 4.45, 4.89, -.122, _cell(590, 1680, 160, 220), Color(.84, .8, .72))
	_panel("board", f, .08, .4, 4.16, 5.28, .02, _cell(480, 1680, 100, 340))
	_bar("timber", f, .24, 4.72, .008, Vector3(.35, 1.15, .024), Color("#120c08"))
	# The slit: old glass behind square lattice, a real window with a stair light on behind it.
	_reveal(f, slit, .12, Color("#2a1c14"))
	_kit.pane("glass", f, slit.position.x, slit.end.x, slit.position.y, slit.end.y, -.1, .83)
	var x2 := slit.position.x + .03
	while x2 < slit.end.x:
		_bar("timber", f, x2, slit.get_center().y, .0, Vector3(.022, slit.size.y, .03), SOOT)
		x2 += .085
	for y: float in [slit.position.y + .02, slit.end.y - .02]:
		_bar("timber", f, slit.get_center().x, y, .0, Vector3(slit.size.x + .03, .04, .04), SOOT)
	# The belt beam between the timber and the tile.
	_bar("timber", f, WIDE * .5, SECOND, .03, Vector3(WIDE, .18, .08), SOOT, .8, 1.0)
	_bar("plain", f, WIDE * .5, SECOND + .1, .05, Vector3(WIDE, .02, .12), Color("#3a3534"))
	# 2050: the shop's mail-order drone shelf, on the only strong post left.
	_bar("metal", f, 3.56, 5.5, .28, Vector3(.76, .04, .56), Color("#25272a"))
	_bar("metal", f, 3.56, 5.3, .02, Vector3(.1, .4, .05), Color("#2a2c2f"))
	_kit.beam("metal", f * Vector3(3.56, 5.12, .04), f * Vector3(3.56, 5.48, .5), .04, .03, Vector3.UP, Color("#2a2c2f"))
	_strip(f * Vector3(3.22, 5.53, .56), f * Vector3(3.9, 5.53, .56), CYAN * .5)
	_status(f, 3.2, 5.46, .06, AMBER)

func _office_floor() -> void:
	# Scratch tile, as on the banks of 1930, with steel casements and a scrivener's gold letters.
	var f := _front
	var lamp := Rect2(.56, 6.12, 2.1, 1.42)
	var side := Rect2(3.0, 6.32, .72, 1.1)
	for piece: Rect2 in _minus(Rect2(0, SECOND + .09, WIDE, EAVE - SECOND - .09), [lamp, side] as Array[Rect2]):
		_kit.quad("scratch", f * Vector3(piece.position.x, piece.position.y, 0), f * Vector3(piece.position.x, piece.end.y, 0), f * Vector3(piece.end.x, piece.end.y, 0), f * Vector3(piece.end.x, piece.position.y, 0), SCRATCH, .86, 1.0, .6, Vector2(piece.position.x, -piece.position.y))
	_reveal(f, lamp, .2, Color("#3a2a20"))
	var iron := Color("#16181a")
	var leaf := lamp.size.x * .5
	for i: int in range(2):
		var x0 := lamp.position.x + float(i) * leaf
		_kit.atlas("frost", f * Vector3(x0, lamp.position.y, -.17), f * Vector3(x0, lamp.end.y, -.17), f * Vector3(x0 + leaf, lamp.end.y, -.17), f * Vector3(x0 + leaf, lamp.position.y, -.17), _cell(760, 1680, 160, 220), Color(.92, .88, .78))
		_bar("metal", f, x0 + leaf * .5, lamp.get_center().y, -.15, Vector3(.015, lamp.size.y, .03), iron)
		for row: int in range(1, 4):
			_bar("metal", f, x0 + leaf * .5, lamp.position.y + lamp.size.y * float(row) * .25, -.15, Vector3(leaf, .015, .03), iron)
		_bar("metal", f, x0, lamp.get_center().y, -.14, Vector3(.035, lamp.size.y, .04), iron)
	_bar("metal", f, lamp.end.x, lamp.get_center().y, -.14, Vector3(.035, lamp.size.y, .04), iron)
	for y: float in [lamp.position.y, lamp.end.y]:
		_bar("metal", f, lamp.get_center().x, y, -.14, Vector3(lamp.size.x, .035, .04), iron)
	_panel("decal", f, lamp.position.x + .1, lamp.position.x + .96, lamp.position.y + .78, lamp.position.y + 1.02, -.122, _cell(930, 1955, 400, 85))
	_panel("decal", f, lamp.position.x + 1.1, lamp.end.x - .08, lamp.position.y + .78, lamp.position.y + 1.02, -.122, _cell(1340, 1955, 520, 85))
	_bar("plain", f, lamp.get_center().x, lamp.position.y - .04, .04, Vector3(lamp.size.x + .24, .07, .13), Color("#5c5448"), .7, 1.0)
	_bar("plain", f, lamp.get_center().x, lamp.end.y + .05, .01, Vector3(lamp.size.x + .1, .1, .04), Color("#3b2a20"))
	_window(f, side, .47, false)
	_camera(f * Vector3(.16, 7.86, .24))
	_bar("metal", f, .16, 7.9, .1, Vector3(.03, .03, .22), Color("#23272a"))

func _flanks() -> void:
	# Black-stained boards down both sides, patched, and a plain back wall.
	var boards := Color("#3a2a20")
	_render_wall(_east, DEEP, EAVE, GROUND, 2.4, boards, [] as Array[Rect2], .7)
	_render_wall(_west, DEEP, EAVE, GROUND, 2.4, boards * .9, [] as Array[Rect2], .7)
	_render_wall(_back, WIDE, EAVE, GROUND, 2.4, boards * .95, [] as Array[Rect2], .5)
	var half := DEEP * .5
	for face: Transform3D in [_east, _west]:
		var x := .0
		while x < DEEP - .01:
			var w := minf(.6, DEEP - x)
			var y0 := EAVE + (RIDGE - EAVE) * (1.0 - absf(x - half) / half)
			var y1 := EAVE + (RIDGE - EAVE) * (1.0 - absf(x + w - half) / half)
			_kit.quad("render", face * Vector3(x, EAVE, 0), face * Vector3(x, y0, 0), face * Vector3(x + w, y1, 0), face * Vector3(x + w, EAVE, 0), boards * _rng.randf_range(.86, 1.0), .9, .8, .5, Vector2(x * 1.3, 0))
			x += w

func _roof() -> void:
	var half := WIDE * .5 + .2
	var eave_out := .56
	var rise := (RIDGE - EAVE) / (DEEP * .5)
	var ridge_z := -DEEP * .5
	var low := EAVE - eave_out * rise
	var slope := Vector3(0, rise, -1.0).normalized()
	var length := Vector2(DEEP * .5 + eave_out, RIDGE - low).length()
	var columns := 16
	var wide := half * 2.0 / float(columns)
	var courses := int(length / .3)
	var origin := Vector3(-half, low, eave_out)
	_tiles(origin, Vector3.RIGHT, slope, columns, wide, courses, length / float(courses), ROOF * .96)
	_eave_ends(origin, columns, wide)
	# The north slope, seen from nowhere much: long ribs instead of separate tiles.
	var north := Vector3(half, low, -DEEP - eave_out)
	var back_up := Vector3(0, rise, 1.0).normalized()
	_kit.quad("plain", north, north + back_up * length, north + back_up * length + Vector3.LEFT * half * 2.0, north + Vector3.LEFT * half * 2.0, ROOF * .4)
	var i := 0
	while i < columns:
		var a := north + Vector3.LEFT * float(i) * wide + Vector3.UP * .02
		var b := a + Vector3.LEFT * wide * .5 + Vector3.UP * .03
		var c := a + Vector3.LEFT * wide
		_kit.quad("tile", a, a + back_up * length, b + back_up * length, b, ROOF * .9, .8, 1.0, .3)
		_kit.quad("tile", b, b + back_up * length, c + back_up * length, c, ROOF * .8, .8, 1.0, .3)
		i += 1
	# Soffit and rafter ends along the street eave.
	_kit.quad("timber", Vector3(-half, EAVE - .03, .0), Vector3(-half, low - .03, eave_out), Vector3(half, low - .03, eave_out), Vector3(half, EAVE - .03, .0), Color("#1c110b"), .6, .6)
	for k: int in range(9):
		var x := -half + .15 + float(k) * .535
		_kit.beam("timber", Vector3(x, EAVE - .06, 0), Vector3(x, low - .07, eave_out), .07, .09, Vector3.UP, SOOT)
	_bar("timber", Transform3D.IDENTITY, 0, low - .03, eave_out - .02, Vector3(half * 2.0, .1, .035), Color("#1f120b"))
	_kit.tube("metal", [Vector3(-half - .02, low - .03, eave_out + .07), Vector3(half + .02, low - .03, eave_out + .07)], .055, Color("#3a2e20"), 8)
	# Barge boards up both gables.
	for x2: float in [-half + .01, half - .01]:
		for z0: float in [eave_out, -DEEP - eave_out]:
			_kit.beam("timber", Vector3(x2, low - .04, z0), Vector3(x2, RIDGE - .04, ridge_z), .05, .2, Vector3.UP, Color("#1f120b"))
	# The ridge, built up in three courses with a round cap and a demon tile at each end.
	var top := Vector3(0, RIDGE, ridge_z)
	for row: Array in [[.09, .3, ROOF * .8], [.2, .24, ROOF * .9]]:
		_kit.block("tile", Transform3D(Basis.IDENTITY, top + Vector3.UP * (row[0] as float)), Vector3(half * 2.0, .1, row[1]), row[2])
	_kit.tube("tile", [top + Vector3(-half, .3, 0), top + Vector3(half, .3, 0)], .09, ROOF, 8)
	for side: float in [-1.0, 1.0]:
		var end := top + Vector3(side * (half + .02), .2, 0)
		_kit.block("tile", Transform3D(Basis.IDENTITY, end + Vector3.UP * .08), Vector3(.1, .5, .46), ROOF * .84)
		_kit.disc("tile", end + Vector3(side * .056, .1, 0), Vector3.FORWARD * side, Vector3.UP, .15, ROOF * 1.15)
	# 2050: two modules laid on the good south slope, a sensor mast by the ridge.
	var n := Vector3.RIGHT.cross(slope).normalized()
	for row2: Array in [[.55, 3.5], [.55, 4.75]]:
		var at := origin + Vector3.RIGHT * (half + float(row2[0])) + slope * float(row2[1]) + n * .13
		_solar_module(Transform3D(Basis(Vector3.RIGHT, slope, n), at), 1.5, 1.16)
	_kit.tube("metal", [top + Vector3(-.9, .1, -.1), top + Vector3(-.9, .95, -.1)], .014, Color("#3a3d40"), 5)
	_kit.lathe("metal", top + Vector3(-.9, .95, -.1), [Vector2(.05, 0), Vector2(.05, .06), Vector2(.02, .09)], Color("#c8c9c4"), 8)

# The pavement -------------------------------------------------------------------------------

func _spine_tray(part: String, f: Transform3D, x0: float, x1: float, y: float, z0: float, z1: float, lift: float) -> void:
	# Books stood fore-edge down: the street looks along their spines, as in every 均一 tray.
	var tall := minf((z0 - z1) * PM * 1.25, BAND)
	var band := _rng.randi_range(0, 6)
	var need := (x1 - x0) * PM
	var u := _rng.randf_range(0.0, 2048.0 - need - 4.0)
	var x := x0
	while x < x1 - .01:
		var run := minf(_rng.randf_range(.2, .5), x1 - x)
		var up := _rng.randf_range(-.008, .012)
		var rect := _cell(u, float(band) * BAND + BAND - tall, run * PM, tall)
		var tone := _rng.randf_range(.86, 1.05)
		_kit.atlas(part, f * Vector3(x, y + up, z0), f * Vector3(x, y + up + lift, z1), f * Vector3(x + run, y + up + lift, z1), f * Vector3(x + run, y + up, z0), rect, Color(tone, tone, tone * .96))
		_kit.atlas("paper", f * Vector3(x, y - .05, z0), f * Vector3(x, y + up, z0), f * Vector3(x + run, y + up, z0), f * Vector3(x + run, y - .05, z0), _cell(590, 1905 + _rng.randf_range(0, 40), 200, 40), Color(.66, .62, .55))
		u += run * PM
		x += run

func _caster(f: Transform3D, x: float, z: float) -> void:
	_bar("metal", f, x, .1, z, Vector3(.05, .05, .05), Color("#2a2a2a"))
	var hub := f * Vector3(x, .05, z)
	_kit.tube("plain", [hub + Vector3(-.02, 0, 0), hub + Vector3(.02, 0, 0)], .05, Color("#1e1b18"), 10)

func _cart(f: Transform3D, x0: float, x1: float, z0: float, z1: float, top: float) -> void:
	# A carpenter's book cart: square legs, open-slatted sides, a stepped tray of spines,
	# and a slatted deck below for what does not fit.
	var wood := Color("#5a3a22")
	var mid := (x0 + x1) * .5
	var deep := (z0 + z1) * .5
	var wide := x1 - x0
	var long := z0 - z1
	for x: float in [x0 + .03, x1 - .03]:
		for z: float in [z0 - .03, z1 + .03]:
			_bar("timber", f, x, (top + .12) * .5, z, Vector3(.05, top - .12, .05), wood.darkened(.2))
			_caster(f, x, z)
	# Slatted end boards and long sides; you can see the street through them.
	for y: float in [top - .02, top - .13, top - .24]:
		_bar("timber", f, mid, y, z0 - .005, Vector3(wide, .07, .018), wood)
		_bar("timber", f, mid, y + .1, z1 + .005, Vector3(wide, .07, .018), wood)
		for x2: float in [x0 + .005, x1 - .005]:
			_bar("timber", f, x2, y, deep, Vector3(.018, .07, long), wood.darkened(.1))
	# Lower deck: separate boards with the gap between them.
	var at := z1 + .05
	while at < z0 - .03:
		_bar("timber", f, mid, .22, at, Vector3(wide - .08, .018, .07), wood.lightened(.08))
		at += .1
	# Tray: three steps of stock rising to the back.
	var steps := 3
	var step := (long - .06) / float(steps)
	for i: int in range(steps):
		var front := z0 - .03 - float(i) * step
		var y := top - .03 + float(i) * .05
		_spine_tray("spines_out", f, x0 + .025, x1 - .025, y, front, front - step, .04)
	_bar("timber", f, mid, top + .1, z1 + .004, Vector3(wide, .12, .018), wood)
	for x3: float in [x0 + .005, x1 - .005]:
		_kit.beam("timber", f * Vector3(x3, top + .02, z0 - .01), f * Vector3(x3, top + .16, z1 + .01), .02, .06, Vector3.BACK, wood.darkened(.1))
	# Stacks on the lower deck.
	_pile("paper", f * Vector3(x0 + wide * .3, .235, deep), 7)
	_pile("paper", f * Vector3(x1 - wide * .28, .235, deep - .04), 10)

func _apple_box(f: Transform3D, x: float, y: float, z: float, wide: float, deep: float) -> void:
	# A slatted fruit crate of paperbacks, ¥100 the lot, the slats showing the books inside.
	var wood := Color("#8a6a44")
	var tall := .24
	_bar("timber", f, x, y + .01, z, Vector3(wide, .02, deep), wood.darkened(.35))
	for level: float in [.05, .135, .21]:
		_bar("timber", f, x, y + level, z + deep * .5 - .006, Vector3(wide, .055, .012), wood)
		_bar("timber", f, x, y + level, z - deep * .5 + .006, Vector3(wide, .055, .012), wood)
		_bar("timber", f, x - wide * .5 + .006, y + level, z, Vector3(.012, .055, deep), wood.darkened(.12))
		_bar("timber", f, x + wide * .5 - .006, y + level, z, Vector3(.012, .055, deep), wood.darkened(.12))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bar("timber", f, x + sx * (wide * .5 - .018), y + tall * .5, z + sz * (deep * .5 - .018), Vector3(.03, tall, .03), wood.darkened(.2))
	_kit.quad("plain", f * Vector3(x - wide * .5 + .01, y + .03, z - deep * .5 + .01), f * Vector3(x - wide * .5 + .01, y + tall - .05, z + deep * .5 - .01), f * Vector3(x + wide * .5 - .01, y + tall - .05, z + deep * .5 - .01), f * Vector3(x + wide * .5 - .01, y + .03, z - deep * .5 + .01), Color("#0f0a07"))
	var front := z + deep * .5 - .012
	var rows := 2
	var step := (deep - .024) / float(rows)
	for i: int in range(rows):
		var near := front - float(i) * step
		_spine_tray("spines_out", f, x - wide * .5 + .014, x + wide * .5 - .014, y + tall - .03, near, near - step, .01)

func _card_stand(f: Transform3D, x: float, y: float, z: float, rect: Rect2, wide: float) -> void:
	# The wire holder: two legs, a bent top rail, a card held in it, as photographed in Jimbocho.
	var tall := wide * .72
	var wire := Color("#c9ccc8")
	var a := f * Vector3(x - wide * .5 - .012, y, z)
	var b := f * Vector3(x + wide * .5 + .012, y, z)
	_kit.tube("metal", [a, a + Vector3.UP * (tall + .1), a + Vector3.UP * (tall + .14) + Vector3.RIGHT * .03, b + Vector3.UP * (tall + .14) + Vector3.LEFT * .03, b + Vector3.UP * (tall + .1), b], .006, wire, 4)
	_kit.tube("metal", [a + Vector3.UP * .08, b + Vector3.UP * .08], .004, wire, 4)
	_panel("paper", f, x - wide * .5, x + wide * .5, y + .09, y + .09 + tall, z + .008, rect)
	_kit.quad("plain", f * Vector3(x + wide * .5, y + .09, z + .002), f * Vector3(x + wide * .5, y + .09 + tall, z + .002), f * Vector3(x - wide * .5, y + .09 + tall, z + .002), f * Vector3(x - wide * .5, y + .09, z + .002), Color("#d9d3c0"))

func _carts() -> void:
	var f := _front
	_cart(f, .3, 1.26, .08, -.34, .74)
	_card_stand(f, .56, 1.0, -.2, _cell(230, 1680, 240, 170), .26)
	_cart(f, 3.24, 3.92, .08, -.34, .66)
	_card_stand(f, 3.72, .9, -.2, _cell(230, 1860, 240, 160), .24)

func _bundle(f: Transform3D, x: float, y: float, z: float, wide: float, long: float, tall: float, cover: int) -> void:
	# Back numbers tied in string, the way they come out of a house clearance.
	var c := f * Vector3(x, y, z)
	var p := func(a: float, b: float, d: float) -> Vector3: return c + Vector3(a * wide * .5, b * tall, d * long * .5)
	var side := _cell(590, 1905, 330, 120)
	_kit.atlas("cover", p.call(-1, 1, 1), p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), _cover_cell(cover))
	_kit.atlas("paper", p.call(-1, 0, 1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 0, 1), side)
	_kit.atlas("paper", p.call(1, 0, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(1, 0, -1), side)
	_kit.atlas("paper", p.call(-1, 0, -1), p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, 0, 1), side)
	_kit.atlas("paper", p.call(1, 0, -1), p.call(1, 1, -1), p.call(-1, 1, -1), p.call(-1, 0, -1), side)
	var cord := Color("#c9b98f")
	var e := .006
	_kit.tube("plain", [p.call(-1, 0, 0) + Vector3(-e, 0, 0), p.call(-1, 1, 0) + Vector3(-e, e, 0), p.call(1, 1, 0) + Vector3(e, e, 0), p.call(1, 0, 0) + Vector3(e, 0, 0)], .004, cord, 3)
	_kit.tube("plain", [p.call(0, 0, 1) + Vector3(0, 0, e), p.call(0, 1, 1) + Vector3(0, e, e), p.call(0, 1, -1) + Vector3(0, e, -e), p.call(0, 0, -1) + Vector3(0, 0, -e)], .004, cord, 3)

func _street_things() -> void:
	var f := _front
	# A slatted pallet by the east case, crates and bundles on it.
	var wood := Color("#7a6040")
	var x := 2.98
	for k: int in range(5):
		_bar("timber", f, x + (float(k) - 2.0) * .09, .075, .3, Vector3(.07, .018, .5), wood)
	for z: float in [.1, .3, .5]:
		_bar("timber", f, x, .035, z, Vector3(.48, .06, .06), wood.darkened(.3))
	_apple_box(f, x, .085, .3, .44, .32)
	_bundle(f, x - .02, .33, .26, .24, .32, .14, 4)
	_bundle(f, x + .03, .47, .28, .22, .31, .11, 13)
	# Another pair of crates stood on the pavement under the west cart's end.
	_apple_box(f, .74, 0, .36, .44, .3)
	_bundle(f, 1.42, 0, .26, .24, .32, .22, 2)
	_bundle(f, 1.43, .22, .25, .23, .31, .1, 11)
