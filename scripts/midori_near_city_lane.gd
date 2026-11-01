extends "res://scripts/midori_near_city_handmade.gd"
## 星屑横丁: the slot beside the pachinko hall opened into a real lane. Low wooden stalls along one
## side, the blind backs of the next block along the other, lanterns and stacked signs for the
## first twenty metres, then the quiet end with its shutters, bicycles, pots and meters.
## Local origin is the stalls' building line at the main street; +x crosses the lane, -z goes in.
const ATLAS := "res://assets/shinrai/near_city/lane_atlas.png"
const ROAD_ALBEDO := "res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png"
const CUT_SHADER := preload("res://scripts/midori_near_city_cutout.gdshader")
const SHIFT := .185 # From the middle of the old corner lot to the stalls' building line.
const DEEP := 40.0
const REAR := -3.4 # The stalls' back wall, hard against the taller block behind.
const EAVE := 2.7
const HALL_X := 3.77
const MOUTH := 3.5
const INK := Color("#2a2622")
const TIMBER := Color("#3a2a1e")
const SODIUM := Color(1.0, .68, .36)
# Along the lane from, to, step in or out, height, wall skin, trade, blade, lantern, noren.
const UNITS: Array = [
	[0.0, 3.6, 0.0, 5.6, "wood", "open", 0, 0, 0],
	[3.6, 6.8, -.12, 6.4, "tin", "open", 1, 1, 1],
	[6.8, 10.4, .06, 5.2, "mortar", "open", 2, 2, 2],
	[10.4, 13.4, -.1, 6.0, "tin", "open", 3, 3, 3],
	[13.4, 16.6, 0.0, 6.6, "mortar", "snack", 4, -1, -1],
	[16.6, 20.4, .1, 5.4, "wood", "open", 5, 4, 4],
	[20.4, 23.6, -.08, 5.9, "tin", "open", 6, 7, 4],
	[23.6, 28.8, 0.0, 6.2, "mortar", "cafe", 9, -1, -1],
	[28.8, 32.4, -1.0, 5.0, "tin", "shutter", -1, -1, -1],
	[32.4, 36.4, -1.1, 5.6, "wood", "bike", 10, -1, -1],
	[36.4, 40.0, -.95, 5.2, "mortar", "house", -1, -1, -1],
]

var _row := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3.ZERO)

func _ready() -> void:
	position.x += SHIFT
	_rng.seed = 1950
	_build_looks()
	_ground()
	for row: Array in UNITS:
		_unit(row)
	_street_end()
	_gate()
	_opposite()
	_overhead()
	_autumn()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "led", "neon", "leaf", "room", "sign", "poster", "goods", "paper", "cloth", "cable", "cut", "road", "apron"])
	_kit = null
	for u: float in [1.8, 8.6, 15.0, 22.0]:
		_omni("Stall%d" % int(u), Vector3(.9, 2.3, -u), SODIUM, 1.5, 6.5)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.wood = _look("japanese_cedar_planks", 1.4, .85)
	_looks.wood.set_shader_parameter("chroma", .55)
	_looks.tin = _look("rusty_corrugated_iron", 1.2, .75)
	_looks.tin.set_shader_parameter("chroma", .75)
	_looks.mortar = _look("plastered_wall_03", 2.2, .92)
	_looks.mortar.set_shader_parameter("chroma", .7)
	_looks.shutter = _look("painted_metal_shutter", 1.0, .7)
	_looks.shutter.set_shader_parameter("chroma", .4)
	_looks.apron = _look("precast_concrete_wall", 2.5, .9)
	_looks.apron.set_shader_parameter("chroma", .45)
	_looks.road = _look("", 4.0, .94)
	_looks.road.set_shader_parameter("albedo_map", load(ROAD_ALBEDO))
	_looks.room = _look("japanese_cedar_planks", 1.4, .7)
	_looks.room.set_shader_parameter("chroma", .6)
	_looks.room.set_shader_parameter("glow", .38)
	_looks.room.set_shader_parameter("day_glow", .14)
	_looks.cable = _look("", 1.0, .7)
	for row: Array in [["sign", .8, .24], ["poster", .55, .3], ["goods", .7, .34], ["cloth", .4, .12], ["paper", 1.5, .42]]:
		var look := _look("", 1.0, .85)
		look.set_shader_parameter("albedo_map", signs)
		look.set_shader_parameter("glow", row[1])
		look.set_shader_parameter("day_glow", row[2])
		_looks[row[0]] = look
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	_looks.decal = letters
	var cut := ShaderMaterial.new()
	cut.shader = CUT_SHADER
	cut.set_shader_parameter("atlas", signs)
	cut.set_shader_parameter("glow", .12)
	cut.set_shader_parameter("day_glow", .08)
	_looks.cut = cut

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _skin(part: String, f: Transform3D, x0: float, x1: float, y0: float, y1: float, tint: Color, holes: Array[Rect2], z := 0.0) -> void:
	for piece: Rect2 in _minus(Rect2(x0, y0, x1 - x0, y1 - y0), holes):
		_kit.quad(part, f * Vector3(piece.position.x, piece.position.y, z), f * Vector3(piece.position.x, piece.end.y, z), f * Vector3(piece.end.x, piece.end.y, z), f * Vector3(piece.end.x, piece.position.y, z), tint, .9, 1.0, .75, Vector2(piece.position.x, -piece.position.y))

func _ground() -> void:
	# Old asphalt, patched and repatched, between two lips of concrete that wander with the walls.
	var east := HALL_X
	_flat("road", -1.4, east + .1, 0.0, -DEEP - .2, .012, Color(.7, .68, .64))
	_flat("road", east, 7.0, -8.6, -11.0, .012, Color(.7, .68, .64))
	for i: int in range(9):
		var u := _rng.randf_range(1.0, DEEP - 3.0)
		var wide := _rng.randf_range(.7, 1.9)
		var x := _rng.randf_range(-.2, 2.4 - wide)
		_flat("road", x, x + wide, -u, -u - _rng.randf_range(.9, 2.6), .016, Color(.5, .49, .47) if i % 2 == 0 else Color(.84, .82, .78))
	var u := .0
	while u < DEEP:
		var step := _rng.randf_range(1.6, 3.4)
		var line := -1.0 if u >= 28.8 else 0.0
		var lip := _rng.randf_range(.32, .62)
		_flat("apron", line - .1, line + lip, -u, -u - step, .03, Color(.72, .71, .67))
		u += step
	# The covered drain down the far side: concrete lids, and a steel grating every few metres.
	var lid := .3
	var count := 0
	while lid < DEEP:
		var edge := _far_wall(lid)
		_flat("apron", edge - .46, edge, -lid, -lid - .58, .036, Color(.62, .61, .58))
		if count % 9 == 4:
			_kit.atlas("goods", Vector3(edge - .42, .042, -lid - .04), Vector3(edge - .42, .042, -lid - .54), Vector3(edge - .04, .042, -lid - .54), Vector3(edge - .04, .042, -lid - .04), _cell(1750, 1840, 200, 100), Color(.5, .5, .5))
		lid += .6
		count += 1
	for row: Array in [[1.5, 4.6], [1.3, 15.8], [1.0, 26.5], [.3, 35.0]]:
		_kit.disc("goods", Vector3(row[0], .022, -row[1]), Vector3.RIGHT, Vector3.FORWARD, .34, Color(.72, .72, .72), _cell(1740, 1530, 300, 300))
	# 止まれ, read walking out to the main street, and the bar to stop at.
	_road_paint(2.6, 1.0, -3.1, -1.5, _cell(700, 1740, 140, 280))
	_road_paint(2.6, 1.0, -4.9, -3.3, _cell(850, 1740, 140, 280))
	_flat("apron", .55, 3.2, -.72, -1.02, .021, Color(.92, .9, .84))

func _road_paint(right: float, left: float, far: float, near: float, rect: Rect2) -> void:
	_kit.atlas("decal", Vector3(right, .024, near), Vector3(right, .024, far), Vector3(left, .024, far), Vector3(left, .024, near), rect, Color(1, 1, 1, .85))

func _far_wall(u: float) -> float:
	# The next block's walls, which never agreed on a line.
	if u < 9.2: return HALL_X
	if u < 18.0: return 3.06
	if u < 28.4: return 2.8
	return 1.89

func _flat(part: String, x0: float, x1: float, z0: float, z1: float, y: float, tint: Color) -> void:
	_kit.quad(part, Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), tint, 1.0, 1.0, 0.0, Vector2(x0, z0))

func _unit(row: Array) -> void:
	var u0: float = row[0]
	var u1: float = row[1]
	var v: float = row[2]
	var top: float = row[3]
	var skin: String = row[4]
	var trade: String = row[5]
	var f := Transform3D(_row.basis, _row * Vector3(0, 0, v))
	var back := REAR - v
	var mid := (u0 + u1) * .5
	var run := u1 - u0
	var tone := Color(.82, .78, .7) if skin != "wood" else Color(.72, .62, .52)
	tone = tone * _rng.randf_range(.86, 1.04)
	_bar("plain", f, mid, (EAVE + top) * .5, (back - .22) * .5, Vector3(run, top - EAVE, -back - .22), tone)
	var wide := minf(run - 1.0, 1.7)
	var sash := Rect2(mid - wide * .5 + _rng.randf_range(-.2, .2), 3.35, wide, 1.0)
	var holes: Array[Rect2] = [sash]
	_skin(skin, f, u0, u1, EAVE, top, tone, holes)
	_window(f, sash, _rng.randf(), _rng.randf() < .4)
	_kit.quad("tin", f * Vector3(u0, top, 0), f * Vector3(u0, top, back), f * Vector3(u1, top, back), f * Vector3(u1, top, 0), Color(.56, .54, .5))
	_bar("metal", f, mid, top + .03, 0, Vector3(run + .02, .06, .1), Color("#55524c"))
	_outdoor_unit(f, u1 - .62, 4.75 if top > 5.8 else 2.95 + .35, .2)
	_kit.tube("plain", [f * Vector3(u0 + .12, .04, .06), f * Vector3(u0 + .12, top - .1, .06)], .028, Color("#6a6a64"), 6)
	match trade:
		"open": _open_stall(f, u0, u1, back, row)
		"snack": _snack(f, u0, u1, back, row)
		"cafe": _cafe(f, u0, u1, back, row)
		"shutter": _closed_shop(f, u0, u1, skin, tone)
		"bike": _bike_shop(f, u0, u1, back, row)
		"house": _house(f, u0, u1, skin, tone)
	_eave(f, u0, u1, trade)

func _eave(f: Transform3D, u0: float, u1: float, trade: String) -> void:
	var reach := .92 if trade in ["open", "snack"] else .56
	var a := f * Vector3(u0, EAVE, reach)
	var b := f * Vector3(u0, EAVE + .3, 0)
	var c := f * Vector3(u1, EAVE + .3, 0)
	var d := f * Vector3(u1, EAVE, reach)
	_kit.quad("tin", a, b, c, d, Color(.74, .7, .64), .9, 1.0, .5, Vector2(u0, 0))
	_kit.quad("plain", d, c, b, a, INK)
	var mid := (u0 + u1) * .5
	_bar("wood", f, mid, EAVE - .05, reach, Vector3(u1 - u0, .12, .05), TIMBER)
	_kit.tube("plain", [f * Vector3(u0, EAVE + .02, reach + .06), f * Vector3(u1, EAVE - .02, reach + .06)], .03, Color("#7a776e"), 5)

func _room(f: Transform3D, u0: float, u1: float, back: float, wall: Color) -> void:
	# The narrow room behind every front: floor, ceiling, walls, all of it a hand's reach away.
	var far := back + .25
	var head := 2.42
	_kit.quad("room", f * Vector3(u0, .03, 0), f * Vector3(u0, .03, far), f * Vector3(u1, .03, far), f * Vector3(u1, .03, 0), Color("#3a342e"))
	_kit.quad("room", f * Vector3(u0, head, far), f * Vector3(u0, head, 0), f * Vector3(u1, head, 0), f * Vector3(u1, head, far), Color("#3a2e24"))
	# Yesterday's specials stay pinned to the side wall until the paper gives up.
	_kit.atlas("poster", f * Vector3(u1 - .01, 1.2, far + .5), f * Vector3(u1 - .01, 2.05, far + .5), f * Vector3(u1 - .01, 2.05, far + 1.1), f * Vector3(u1 - .01, 1.2, far + 1.1), _cell(250, 1520, 240, 340))
	_kit.quad("room", f * Vector3(u0, 0, far), f * Vector3(u0, head, far), f * Vector3(u1, head, far), f * Vector3(u1, 0, far), wall)
	_kit.quad("room", f * Vector3(u0, 0, 0), f * Vector3(u0, head, 0), f * Vector3(u0, head, far), f * Vector3(u0, 0, far), wall)
	_kit.quad("room", f * Vector3(u1, 0, far), f * Vector3(u1, head, far), f * Vector3(u1, head, 0), f * Vector3(u1, 0, 0), wall)
	_bar("lamp", f, (u0 + u1) * .5, head - .02, far * .5, Vector3(u1 - u0 - .6, .02, .08), Color(1.0, .8, .52))

func _frame(f: Transform3D, u0: float, u1: float) -> void:
	for x: float in [u0 + .06, u1 - .06]:
		_bar("wood", f, x, 1.25, .02, Vector3(.13, 2.5, .15), TIMBER)
	_bar("wood", f, (u0 + u1) * .5, 2.52, .02, Vector3(u1 - u0, .24, .15), TIMBER)
	_bar("plain", f, (u0 + u1) * .5, 2.68, -.02, Vector3(u1 - u0, .1, .1), INK)

func _open_stall(f: Transform3D, u0: float, u1: float, back: float, row: Array) -> void:
	var mid := (u0 + u1) * .5
	var far := back + .25
	_room(f, u0 + .1, u1 - .1, back, Color("#46301f"))
	_frame(f, u0, u1)
	_panel("goods", f, u0 + .3, mid, .98, 1.92, far + .02, _cell(1000, 1520, 480, 200))
	_panel("goods", f, mid + .05, u1 - .3, 1.42, 2.3, far + .02, _cell(510, 1520, 480, 200))
	# Counter across the width, and the stools people lean back from into the lane.
	var counter := -1.0
	_bar("wood", f, mid, .5, counter, Vector3(u1 - u0 - .3, 1.0, .1), Color("#5a3a22"))
	_bar("wood", f, mid, 1.03, counter, Vector3(u1 - u0 - .24, .06, .46), Color("#8a5a32"))
	var seats := int((u1 - u0 - .5) / .62)
	for i: int in range(seats):
		_stool(f * Vector3(u0 + .55 + float(i) * .62, 0, counter + .55))
	_noren(f, u0 + .22, u1 - .22, _cell(float(int(row[8]) % 4) * 410.0, 1230.0 + float(int(row[8]) / 4) * 140.0, 400, 130))
	_kit.tube("metal", [f * Vector3(u0 + .2, 2.42, .05), f * Vector3(u1 - .2, 2.42, .05)], .012, Color("#b8a468"), 4)
	var lantern := _cell(float(int(row[7]) % 4) * 410.0, 810.0 + float(int(row[7]) / 4) * 210.0, 400, 200)
	_lantern(f * Vector3(u0 + .42, 2.74, .56), lantern)
	_lantern(f * Vector3(u1 - .42, 2.74, .56), lantern)
	_blade(f, u1 - .24, 3.0, int(row[6]))
	# No two fronts alike: a sliding door, a ticket machine, barrels to stand round.
	var blade: int = row[6]
	if blade == 1 or blade == 5:
		_kit.quad("front", f * Vector3(mid, .04, -.05), f * Vector3(mid, 2.38, -.05), f * Vector3(u1 - .12, 2.38, -.05), f * Vector3(u1 - .12, .04, -.05), Color.WHITE)
		for x: float in [mid, (mid + u1) * .5, u1 - .14]:
			_bar("metal", f, x, 1.2, -.05, Vector3(.05, 2.34, .05), Color("#7a6a4a"))
		_bar("metal", f, (mid + u1) * .5, 1.0, -.05, Vector3(u1 - mid, .05, .05), Color("#7a6a4a"))
	elif blade == 3:
		_bar("metal", f, u0 + .5, .85, .14, Vector3(.5, 1.7, .32), Color("#c8ccce"))
		_panel("goods", f, u0 + .29, u0 + .71, .5, 1.6, .305, _cell(1500, 1520, 240, 420))
	elif blade == 6:
		for x: float in [mid - .7, mid + .7]:
			_barrel(f * Vector3(x, 0, .62))
	# What ends up on the lane, and it is never the same twice.
	if blade == 0 or blade == 3 or blade == 6:
		_menu(f * Vector3(u0 + .9 + _rng.randf() * .6, 0, .78), .3, 0 if blade == 0 else 1)
	else:
		_crates(f, u1 - .62, .32, 2 + blade % 2)
	_clutter(f, u0, u1)

func _noren(f: Transform3D, x0: float, x1: float, rect: Rect2) -> void:
	# Split cloth on a bamboo pole, each strip hanging its own way.
	var strips := 3
	var run := (x1 - x0) / float(strips)
	for i: int in range(strips):
		var left := x0 + float(i) * run + .015
		var right := x0 + float(i + 1) * run - .015
		var cut := Rect2(rect.position + Vector2(rect.size.x * float(i) / float(strips), 0), Vector2(rect.size.x / float(strips), rect.size.y))
		var swing := .05 + _rng.randf() * .07
		_kit.atlas("cloth", f * Vector3(left, 1.84, .05 + swing), f * Vector3(left, 2.42, .05), f * Vector3(right, 2.42, .05), f * Vector3(right, 1.84, .05 + swing), cut)
		_kit.atlas("cloth", f * Vector3(right, 1.84, .05 + swing), f * Vector3(right, 2.42, .05), f * Vector3(left, 2.42, .05), f * Vector3(left, 1.84, .05 + swing), cut, Color(.6, .6, .6))

func _barrel(at: Vector3) -> void:
	# Stand-up drinking: a sake barrel with a board on it and nowhere to sit.
	_kit.lathe("wood", at, [Vector2(.26, 0), Vector2(.3, .4), Vector2(.26, .84)], Color(.7, .5, .32), 16)
	for y: float in [.16, .68]:
		_kit.lathe("metal", at + Vector3.UP * y, [Vector2(.29, 0), Vector2(.3, .03)], Color("#3a3c3e"), 16)
	_kit.lathe("wood", at + Vector3.UP * .84, [Vector2(.34, 0), Vector2(.34, .04), Vector2(0, .05)], Color(.62, .44, .28), 16)

func _clutter(f: Transform3D, u0: float, u1: float) -> void:
	# Whatever will not fit indoors: a bucket, flattened boxes, a coil of hose, a stack of crates.
	match _rng.randi_range(0, 3):
		0:
			_kit.lathe("plain", f * Vector3(u0 + .3, 0, .24), [Vector2(.1, 0), Vector2(.14, .26), Vector2(.15, .27)], Color("#3a7ab0"), 12)
		1:
			var at := f * Vector3(u0 + .28, .36, .1)
			for i: int in range(3):
				_kit.block("plain", Transform3D(f.basis * Basis(Vector3.RIGHT, -.1 - float(i) * .05), at + f.basis.z * float(i) * .05), Vector3(.5, .74, .02), Color("#a88a5a"))
		2:
			var ring: Array[Vector3] = []
			for k: int in range(25):
				var a := TAU * float(k) / 8.0
				ring.append(f * Vector3(u0 + .32, 1.05 + float(k) * .006 + sin(a) * .15, .06 + (cos(a) + 1.0) * .1))
			_kit.tube("plain", ring, .011, Color("#2a6a4a"), 4)
		3:
			_bar("plain", f, u0 + .32, .2, .24, Vector3(.4, .4, .3), Color("#a88a5a"))
			_bar("plain", f, u0 + .3, .52, .25, Vector3(.34, .24, .26), Color("#8a7248"))

func _pipework(f: Transform3D, run: float, high: float) -> void:
	# A back wall gets whatever the rooms behind it needed, added one decade at a time.
	var x := .5
	while x < run - .3:
		match _rng.randi_range(0, 3):
			0:
				_kit.tube("plain", [f * Vector3(x, .05, .08), f * Vector3(x, high, .08)], _rng.randf_range(.03, .06), Color("#7e7f78"), 6)
			1:
				_outdoor_unit(f, x, _rng.randf_range(3.3, high - 1.0), .2)
			2:
				var y := _rng.randf_range(3.2, high - 1.0)
				_bar("metal", f, x, y, .1, Vector3(.34, .3, .2), Color("#a4a6a0"))
				_bar("plain", f, x, y - .12, .12, Vector3(.3, .05, .2), Color("#2a2c2e"))
				_kit.tube("metal", [f * Vector3(x, y + .15, .1), f * Vector3(x, high, .1)], .08, Color("#a4a6a0"), 8)
			3:
				for i: int in range(3):
					_kit.tube("plain", [f * Vector3(x + float(i) * .06, .4, .05), f * Vector3(x + float(i) * .06, 2.2, .05), f * Vector3(x + float(i) * .06 + .5, 2.5, .05), f * Vector3(x + float(i) * .06 + .5, high, .05)], .012, Color("#3a3c3e"), 4)
		x += _rng.randf_range(.8, 1.7)

func _snack(f: Transform3D, u0: float, u1: float, back: float, row: Array) -> void:
	# A padded door, a purple box and no window: you know whether you are expected.
	var mid := (u0 + u1) * .5
	_skin("mortar", f, u0, u1, 0, EAVE, Color("#4a3a5a"), [] as Array[Rect2])
	_bar("wood", f, mid, 1.05, .03, Vector3(.96, 2.1, .06), Color("#5a1a3a"))
	_bar("metal", f, mid + .34, 1.05, .08, Vector3(.03, .22, .03), Color("#c9a44a"))
	for side: float in [-.74, .74]:
		_lamp_box(f, mid + side, 2.0)
	_blade(f, u1 - .24, 3.0, int(row[6]))
	_round_sign(f, u0 + .5, 3.5)

func _lamp_box(f: Transform3D, x: float, y: float) -> void:
	_bar("metal", f, x, y, .05, Vector3(.16, .3, .08), Color("#2a2228"))
	_bar("lamp", f, x, y, .092, Vector3(.12, .26, .006), Color(1.0, .5, .78))

func _cafe(f: Transform3D, u0: float, u1: float, back: float, row: Array) -> void:
	# 純喫茶: dark wood, a window you cannot quite see through, and a sill of plants that outlived it.
	var mid := (u0 + u1) * .5
	_room(f, u0 + .1, u1 - .1, back, Color("#3e2a1a"))
	_frame(f, u0, u1)
	var door := u0 + 1.0
	_skin("wood", f, u0 + .1, u1 - .1, .02, .85, Color(.6, .44, .3), [] as Array[Rect2], -.08)
	_kit.quad("front", f * Vector3(door + .55, .85, -.08), f * Vector3(door + .55, 2.4, -.08), f * Vector3(u1 - .12, 2.4, -.08), f * Vector3(u1 - .12, .85, -.08), Color.WHITE)
	_bar("wood", f, door, 1.2, -.04, Vector3(.9, 2.4, .08), Color("#3a2414"))
	_bar("metal", f, door + .34, 1.1, .02, Vector3(.03, .3, .03), Color("#c9a44a"))
	_blade(f, u0 + .3, 3.0, int(row[6]))
	for i: int in range(5):
		_pot(f * Vector3(mid + .2 + float(i) * .42, 0, .22), .24 + _rng.randf() * .14, .5 + _rng.randf() * .35)
	_menu(f * Vector3(door + .1, 0, .62), -.2, 0)

func _closed_shop(f: Transform3D, u0: float, u1: float, skin: String, tone: Color) -> void:
	# It sold rice, then nothing. The shutter stayed.
	var mid := (u0 + u1) * .5
	_skin(skin, f, u0, u0 + .3, 0, EAVE, tone, [] as Array[Rect2])
	_skin(skin, f, u1 - .3, u1, 0, EAVE, tone, [] as Array[Rect2])
	_kit.quad("shutter", f * Vector3(u0 + .3, .02, -.06), f * Vector3(u0 + .3, 2.3, -.06), f * Vector3(u1 - .3, 2.3, -.06), f * Vector3(u1 - .3, .02, -.06), Color(.62, .66, .66), 1.0, 1.0, .9)
	_bar("metal", f, mid, 2.46, .04, Vector3(u1 - u0 - .5, .34, .3), Color("#7a7c78"))
	_panel("decal", f, u0 + .5, u1 - .5, .9, 1.7, -.05, _cell(0, 1870, 500, 170))
	_parked_bicycle(f * Vector3(mid - .9, 0, .55), Color("#3a5a7a"))
	_bin(f * Vector3(u1 - .5, 0, .28), Color("#2c5c94"))

func _bike_shop(f: Transform3D, u0: float, u1: float, back: float, row: Array) -> void:
	var mid := (u0 + u1) * .5
	_room(f, u0 + .1, u1 - .1, back, Color("#6a6a60"))
	_frame(f, u0, u1)
	_blade(f, u0 + .3, 3.0, int(row[6]))
	for i: int in range(5):
		var rim := f * Vector3(u0 + .7 + float(i) * .6, 1.9, back + .32)
		var ring: Array[Vector3] = []
		for k: int in range(13):
			var a := TAU * float(k) / 12.0
			ring.append(rim + f.basis.x * cos(a) * .3 + f.basis.y * sin(a) * .3)
		_kit.tube("plain", ring, .018, Color("#17181a"), 4)
	_parked_bicycle(f * Vector3(mid - .6, 0, .4), Color("#a8201a"))
	_parked_bicycle(f * Vector3(mid + .7, 0, .58), Color("#d8d4c8"))
	_parked_bicycle(f * Vector3(mid + 1.3, 0, .25), Color("#2a6a5a"))

func _house(f: Transform3D, u0: float, u1: float, skin: String, tone: Color) -> void:
	# Somebody still lives at the end: a door, a meter, and more pots than the step can hold.
	var door := Rect2(u0 + .5, .1, .86, 2.0)
	_skin(skin, f, u0, u1, 0, EAVE, tone, [door])
	_bar("wood", f, door.get_center().x, 1.1, -.06, Vector3(door.size.x, 2.0, .05), Color("#4a3a2a"))
	_reveal(f, door, .08, Color("#5a5650"))
	_window(f, Rect2(u0 + 1.8, 1.0, 1.2, 1.0), .4, true)
	_gas_heater(f, u0 + .24, 1.7, .1)
	for i: int in range(9):
		var side := float(i % 3)
		_pot(f * Vector3(door.position.x - .2 + float(i / 3) * .72 + side * .1, 0, .2 + side * .24), .2 + _rng.randf() * .2, .42 + _rng.randf() * .5)

func _street_end() -> void:
	# The stall's gable, the only part of the lane the main street sees square on.
	var back := REAR
	var top := 5.6
	var wall := Color(.72, .62, .52)
	_kit.quad("wood", Vector3(back, 0, .012), Vector3(back, top, .012), Vector3(0, top, .012), Vector3(0, 0, .012), wall, .9, 1.0, .7)
	var face := Transform3D.IDENTITY
	_panel("cloth", face, back + .35, -.3, 2.5, 3.2, .02, _cell(0, 1230, 400, 130))
	_panel("poster", face, back + .9, -.8, 1.0, 2.3, .02, _cell(0, 1520, 240, 340))
	_bar("wood", face, back * .5, 2.42, .02, Vector3(-back - .2, .05, .05), TIMBER)
	_lantern(face * Vector3(back + .5, 2.46, .3), _cell(0, 810, 400, 200))
	_lantern(face * Vector3(-.5, 2.46, .3), _cell(0, 810, 400, 200))
	_outdoor_unit(face, back * .5, 4.3, .2)

func _gate() -> void:
	# Steel posts, a lit board and two lamps: the lane announcing itself to the main street.
	var steel := Color("#2c2e30")
	var z := -.32
	var x0 := .3
	var x1 := MOUTH
	for x: float in [x0, x1]:
		_kit.tube("metal", [Vector3(x, 0, z), Vector3(x, 5.0, z)], .06, steel, 8)
	_bar("metal", Transform3D.IDENTITY, (x0 + x1) * .5, 4.2, z, Vector3(x1 - x0 + .12, .86, .14), Color("#1a0f0a"))
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 0, z + .074))
	_panel("sign", front, x0 + .04, x1 - .04, 3.82, 4.58, 0, _cell(0, 0, 900, 160))
	var back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(x1, 0, z - .074))
	_panel("sign", back, .04, x1 - x0 - .04, 3.82, 4.58, 0, _cell(0, 0, 900, 160))
	for x: float in [x0 + .7, x1 - .7]:
		_kit.tube("metal", [Vector3(x, 4.6, z), Vector3(x, 4.86, z), Vector3(x, 4.86, z + .5)], .014, steel, 4)
		_bar("metal", Transform3D.IDENTITY, x, 4.84, z + .54, Vector3(.3, .06, .14), Color("#44403a"))
		_bar("lamp", Transform3D.IDENTITY, x, 4.805, z + .54, Vector3(.26, .01, .1), Color(1.0, .86, .6))
	_lantern(Vector3(x0 + .55, 3.78, z), _cell(820, 1020, 400, 200), .17, .46)
	_lantern(Vector3(x1 - .55, 3.78, z), _cell(820, 1020, 400, 200), .17, .46)

func _lantern(top: Vector3, rect: Rect2, wide := .21, tall := .58) -> void:
	# Paper on a wire hoop, lit from inside; the word wraps it so it reads from either end.
	var sides := 12
	var rows := 6
	for r: int in range(rows):
		var t0 := float(r) / float(rows)
		var t1 := float(r + 1) / float(rows)
		var r0 := wide * (.62 + .38 * sin(PI * t0))
		var r1 := wide * (.62 + .38 * sin(PI * t1))
		var y0 := top.y - .03 - tall * (1.0 - t0)
		var y1 := top.y - .03 - tall * (1.0 - t1)
		for s: int in range(sides):
			var a0 := -TAU * float(s) / float(sides)
			var a1 := -TAU * float(s + 1) / float(sides)
			var uv := Rect2(rect.position + Vector2(rect.size.x * float(s) / float(sides), rect.size.y * (1.0 - t1)), Vector2(rect.size.x / float(sides), rect.size.y / float(rows)))
			_kit.atlas("paper", Vector3(top.x + cos(a0) * r0, y0, top.z + sin(a0) * r0), Vector3(top.x + cos(a0) * r1, y1, top.z + sin(a0) * r1), Vector3(top.x + cos(a1) * r1, y1, top.z + sin(a1) * r1), Vector3(top.x + cos(a1) * r0, y0, top.z + sin(a1) * r0), uv)
	var band := Color("#17130f")
	_kit.lathe("plain", top + Vector3.DOWN * .05, [Vector2(wide * .72, 0), Vector2(wide * .72, .05), Vector2(.0, .06)], band, 16)
	_kit.lathe("plain", top + Vector3.DOWN * (tall + .06), [Vector2(.0, -.01), Vector2(wide * .72, 0), Vector2(wide * .72, .05)], band, 16)
	_kit.tube("cable", [top, top + Vector3.DOWN * .04], .008, band, 3)

func _blade(f: Transform3D, x: float, y: float, column: int, wide := .56, tall := 1.86) -> void:
	# Board on a bracket, off the wall and across the lane: these are what stack up in the distance.
	var near := .12
	var far := near + wide
	var rect := _cell(2.0 + float(column) * 150.0, 320, 140, 470)
	_bar("metal", f, x, y + tall * .5, (near + far) * .5, Vector3(.05, tall + .04, wide + .04), Color("#26282a"))
	_kit.atlas("sign", f * Vector3(x - .03, y, near), f * Vector3(x - .03, y + tall, near), f * Vector3(x - .03, y + tall, far), f * Vector3(x - .03, y, far), rect)
	_kit.atlas("sign", f * Vector3(x + .03, y, far), f * Vector3(x + .03, y + tall, far), f * Vector3(x + .03, y + tall, near), f * Vector3(x + .03, y, near), rect)
	for level: float in [y + .2, y + tall - .2]:
		_bar("metal", f, x, level, near * .5, Vector3(.05, .05, near), Color("#26282a"))

func _round_sign(f: Transform3D, x: float, y: float) -> void:
	var radius := .62
	var centre := f * Vector3(x, y, radius + .24)
	_kit.disc("sign", centre + f.basis.x * .05, -f.basis.z, f.basis.y, radius, Color.WHITE, _cell(910, 0, 300, 300))
	_kit.disc("sign", centre - f.basis.x * .05, f.basis.z, f.basis.y, radius, Color.WHITE, _cell(910, 0, 300, 300))
	_bar("metal", f, x, y, .12, Vector3(.05, .06, .26), Color("#26282a"))

func _menu(foot: Vector3, turn: float, cell: int) -> void:
	# A-frame board, angled at whoever is walking in from the main street.
	var t := Transform3D(Basis(Vector3.UP, turn), foot)
	var rect := _cell(float(cell) * 250.0, 1520, 240, 340)
	_kit.atlas("poster", t * Vector3(-.28, .08, .1), t * Vector3(-.28, 1.0, -.08), t * Vector3(.28, 1.0, -.08), t * Vector3(.28, .08, .1), rect)
	_kit.quad("plain", t * Vector3(.28, 0, -.3), t * Vector3(.28, 1.0, -.1), t * Vector3(-.28, 1.0, -.1), t * Vector3(-.28, 0, -.3), TIMBER)
	_kit.beam("wood", t * Vector3(-.3, 0, .12), t * Vector3(-.3, 1.02, -.09), .03, .03, Vector3.RIGHT, TIMBER)
	_kit.beam("wood", t * Vector3(.3, 0, .12), t * Vector3(.3, 1.02, -.09), .03, .03, Vector3.RIGHT, TIMBER)

func _stool(at: Vector3) -> void:
	_kit.lathe("metal", at, [Vector2(.14, 0), Vector2(.03, .04), Vector2(.03, .46)], Color("#a8aaa8"), 8)
	_kit.lathe("plain", at + Vector3.UP * .46, [Vector2(.04, 0), Vector2(.17, .01), Vector2(.17, .06), Vector2(.0, .08)], Color("#c01818"), 18)

func _crates(f: Transform3D, x: float, z: float, count: int) -> void:
	for i: int in range(count):
		var y := .15 + float(i) * .3
		_bar("plain", f, x, y, z, Vector3(.46, .29, .34), Color("#a81616"))
		_panel("goods", f, x - .22, x + .22, y - .13, y + .13, z + .172, _cell(520, 1740, 160, 100))
		_panel("goods", Transform3D(f.basis * Basis(Vector3.UP, PI * .5), f * Vector3(x - .232, 0, z)), -.16, .16, y - .13, y + .13, 0, _cell(520, 1740, 160, 100))

func _pot(at: Vector3, wide: float, tall: float) -> void:
	_kit.lathe("plain", at, [Vector2(wide * .36, 0), Vector2(wide * .5, wide * .7), Vector2(wide * .54, wide * .78), Vector2(wide * .4, wide * .8)], [Color("#8a4a2c"), Color("#5a5a5e"), Color("#a8a49a")][_rng.randi_range(0, 2)], 16)
	_plant(at + Vector3.UP * wide * .76, tall, Color("#3e6a34"))

func _bin(at: Vector3, tint: Color) -> void:
	_kit.lathe("plain", at, [Vector2(.18, 0), Vector2(.23, .62), Vector2(.25, .66), Vector2(.21, .7), Vector2(0, .72)], tint, 12)

func _gas_heater(f: Transform3D, x: float, y: float, z: float) -> void:
	# The white box on every Tokyo wall, its copper running down to the ground.
	_bar("metal", f, x, y, z, Vector3(.38, .56, .17), Color("#d2d3cd"))
	_bar("plain", f, x, y + .12, z + .09, Vector3(.26, .06, .02), Color("#3a3c3e"))
	for i: int in range(3):
		var at := x - .1 + float(i) * .1
		_kit.tube("metal", [f * Vector3(at, y - .28, z), f * Vector3(at, y - .5, z), f * Vector3(at, .3, .05 + float(i) * .02)], .011, Color("#a8704a") if i != 1 else Color("#c8c8c0"), 4)

func _meters(f: Transform3D, x: float, y: float) -> void:
	_bar("metal", f, x, y, .09, Vector3(.42, .56, .16), Color("#9a9c98"))
	for i: int in range(2):
		_kit.disc("bottle", f * Vector3(x - .09 + float(i) * .18, y + .08, .172), f.basis.x, f.basis.y, .06, Color("#20262a"))
	_kit.tube("plain", [f * Vector3(x, y + .28, .09), f * Vector3(x, 3.4, .09)], .022, Color("#3a3c3e"), 5)

func _facing(x: float, u: float) -> Transform3D:
	# A wall of the next block looking back across the lane; its x runs towards the main street.
	return Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(x, 0, -u))

func _opposite() -> void:
	# Nobody decorates a back wall. It just collects pipes.
	_pipework(_facing(HALL_X, 9.0), 4.6, 6.8)
	var a := _facing(3.06, 17.9)
	_meters(a, 1.2, 1.5)
	_gas_heater(a, 2.4, 1.7, .1)
	_gas_heater(a, 3.1, 1.7, .1)
	_outdoor_unit(a, 4.6, 2.9, .2)
	_outdoor_unit(a, 4.6, 3.56, .2)
	_blade(a, 5.8, 3.3, 7)
	_pipework(a, 7.6, 9.0)
	_kit.tube("plain", [a * Vector3(.4, .05, .08), a * Vector3(.4, 7.0, .08)], .05, Color("#8a8b84"), 7)
	_bin(a * Vector3(3.7, 0, .3), Color("#2c5c94"))
	var b := _facing(2.8, 28.3)
	_vending(b, 3.2)
	_vending(b, 4.15)
	_blade(b, 7.5, 3.4, 8)
	_blade(b, 1.5, 3.1, 12)
	_pipework(b, 9.8, 8.5)
	_kit.tube("plain", [b * Vector3(6.3, .05, .08), b * Vector3(6.3, 7.0, .08)], .04, Color("#6a6a64"), 6)
	_meters(b, 1.0, 1.4)
	_kit.quad("plain", b * Vector3(7.6, 3.4, .22), b * Vector3(7.6, 5.0, .04), b * Vector3(9.4, 5.0, .04), b * Vector3(9.4, 3.3, .28), Color("#2a6fb8"), .9, 1.0)
	var c := _facing(1.89, 40.0)
	_gas_heater(c, 2.2, 1.7, .1)
	_meters(c, 3.3, 1.45)
	_outdoor_unit(c, 6.0, 1.0, .2)
	_outdoor_unit(c, 6.0, 3.4, .2)
	_blade(c, 7.6, 3.1, 11)
	_pipework(c, 10.8, 7.5)
	_kit.tube("plain", [c * Vector3(4.4, .05, .08), c * Vector3(4.4, 6.5, .08)], .05, Color("#8a8b84"), 7)
	_parked_bicycle(c * Vector3(8.8, 0, .32), Color("#b8b4a8"))
	_parked_bicycle(c * Vector3(10.0, 0, .3), Color("#2a4a6a"))
	for i: int in range(4):
		_pot(c * Vector3(.7 + float(i) * .4, 0, .22), .26, .5 + _rng.randf() * .4)

func _vending(f: Transform3D, x: float) -> void:
	_bar("metal", f, x, .95, .38, Vector3(.9, 1.86, .72), Color("#c8ccce"))
	_panel("goods", f, x - .42, x + .42, .12, 1.8, .745, _cell(1500, 1520, 240, 420))

func _overhead() -> void:
	# Lamps slung across on a wire, and every service anyone ever ran, in no order at all.
	for row: Array in [[3.4, true], [8.9, true], [14.2, false], [19.6, true], [25.0, false], [31.0, true], [36.6, false]]:
		var u: float = row[0]
		var west := Vector3(-.1, 4.5, -u)
		var east := Vector3(_far_wall(u), 4.7, -u)
		var middle := (west + east) * .5 + Vector3.DOWN * .22
		_sag(west, middle, .02)
		_sag(middle, east, .02)
		_pendant(middle)
	for i: int in range(64):
		var u := _rng.randf_range(.5, DEEP - .5)
		var from := Vector3(-.05, _rng.randf_range(4.4, 6.0), -u)
		var to := Vector3(_far_wall(u + 1.0), _rng.randf_range(5.0, 8.5), -u - _rng.randf_range(-3.0, 3.0))
		_sag(from, to, _rng.randf_range(.1, .5))

func _sag(a: Vector3, b: Vector3, drop: float) -> void:
	var points: Array[Vector3] = []
	for i: int in range(7):
		var t := float(i) / 6.0
		points.append(a.lerp(b, t) + Vector3.DOWN * drop * 4.0 * t * (1.0 - t))
	_kit.tube("cable", points, .011, Color("#15161a"), 3)

func _pendant(at: Vector3) -> void:
	# Green enamel over a bare bulb, older than the lane's name.
	var low := at + Vector3.DOWN * .42
	_kit.tube("cable", [at, low + Vector3.UP * .2], .008, Color("#15161a"), 3)
	_kit.lathe("plain", low, [Vector2(.24, 0), Vector2(.2, .05), Vector2(.07, .17), Vector2(.02, .2)], Color("#3a6a54"), 14)
	_kit.disc("plain", low + Vector3.UP * .02, Vector3.RIGHT, Vector3.BACK, .23, Color("#e8e2d0"))
	_kit.lathe("lamp", low + Vector3.DOWN * .04, [Vector2(.02, 0), Vector2(.06, .03), Vector2(.05, .08)], Color(1.0, .84, .58), 8)

func _autumn() -> void:
	# Plastic maple wired overhead, clear of the signs: it has never once been taken down.
	var u := 3.0
	while u < 22.0:
		_bunch(Vector3(.2 + _rng.randf() * .5, 5.0 + _rng.randf() * .4, -u))
		_bunch(Vector3(1.4 + _rng.randf() * 1.0, 5.1 + _rng.randf() * .5, -u - .5))
		u += _rng.randf_range(1.3, 2.2)

func _bunch(at: Vector3) -> void:
	var size := _rng.randf_range(.8, 1.2)
	for turn: float in [_rng.randf() * PI, _rng.randf() * PI + PI * .5]:
		var side := Vector3(cos(turn), 0, sin(turn)) * size * .5
		var up := Vector3.UP * size * .42
		var rect := _cell(1030.0 + _rng.randf() * 50.0, 1770.0 + _rng.randf() * 30.0, 200, 180)
		_kit.atlas("cut", at - side - up, at - side + up, at + side + up, at + side - up, rect)
