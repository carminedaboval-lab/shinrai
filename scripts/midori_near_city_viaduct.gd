extends "res://scripts/midori_near_city_handmade.gd"
## The commuter line where it passes the park, 1978 and still carrying its own weather: portal
## rigid frames straddling the street on the pavement line, a riveted through-girder over every
## cross street, and a few trades that rent the bays between the columns. No station, no trains.
## Local origin is the street centre under the viaduct, at x = VIADUCT_X, z = 0, road level.
## The street below stays clear: columns and units keep to the back 1.75 m of each pavement.
const ATLAS := "res://assets/shinrai/near_city/viaduct_atlas.png"
const Z_START := -148.0 # Where the old blocks stop; rebuilt from here to the end of the line.
const Z_END := 152.0
const CROSSINGS: Array[float] = [-128.0, -64.0, 0.0, 64.0, 128.0]
const REACH := 11.0 # Half length of a girder span, frame to frame.
const BAY := 7.0
const COLUMN_X := 9.4
const FRONT := 8.75 # Shop-front plane; x = 311.25 and 328.75, leaving 1.75 m of pavement.
const ROOM_DEEP := .95 # Stops short of the lots' low boundary walls at x = 310.
const SOFFIT := 7.55
const DECK_TOP := 8.45
const RAIL_TOP := 8.63 # The old blocks' rail height, so the two meet level.
const WALL_FOOT := 9.65 # Top of the old parapet.
const WALL_TOP := 11.0
const GIRDER_LOW := 7.36
const GIRDER_HIGH := 9.82
const WIRE_Y := 14.0 # Contact wire, level with the old line's.
const TRACK := 1.8
const GAUGE := .7525
const MASTS: Array[float] = [-136.0, -108.0, -80.0, -52.0, -26.0, 4.0, 32.0, 60.0, 90.0, 116.0, 144.0]
const CONCRETE := Color(1.0, .97, .91)
const PAINT := Color("#86a896")
const WOOD := Color("#6b4a32")
const PVC := Color("#c4c9c4")
const STAIN_DARK := 0
const STAIN_FAN := 1
const STAIN_RUST := 2
const STAIN_RUST_FINE := 3
const STAIN_LIME := 4
const STAIN_DAMP := 5
const STAIN_PATCH := 6
const STAIN_CRACK := 7
# Who rents which bay, by side and the z of the frame at the bay's low end.
const TENANTS: Array[Array] = [[-1.0, -117.0, "clothes"], [1.0, -117.0, "bikes"], [-1.0, -110.0, "bikes"], [1.0, -103.0, "shutter"], [-1.0, -89.0, "cabinets"],
	[-1.0, -82.0, "shutter"], [1.0, -82.0, "bikes"], [-1.0, -53.0, "yakitori"], [1.0, -53.0, "coffee"], [-1.0, -46.0, "keys"], [1.0, -46.0, "shutter"], [1.0, -39.0, "cabinets"],
	[-1.0, -25.0, "bikes"], [-1.0, -18.0, "vending"], [1.0, -18.0, "tenant"], [-1.0, 11.0, "tako"], [1.0, 11.0, "cycle"], [-1.0, 18.0, "shutter"], [1.0, 18.0, "bikes"],
	[-1.0, 25.0, "bikes"], [1.0, 25.0, "clothes"], [1.0, 39.0, "cabinets"], [-1.0, 46.0, "shutter"], [1.0, 46.0, "vending"], [-1.0, 75.0, "tenant"], [1.0, 75.0, "yakitori"],
	[-1.0, 82.0, "bikes"], [1.0, 89.0, "shutter"], [-1.0, 103.0, "cabinets"], [-1.0, 110.0, "keys"], [1.0, 110.0, "shutter"]]

var _deck_runs: Array[Vector2] = []

func _ready() -> void:
	_rng.seed = 1978
	_build_looks()
	_plan_and_frames()
	for run: Vector2 in _deck_runs:
		_deck_run(run)
		for s: float in [-1.0, 1.0]:
			_wall_run(run, s)
	for i: int in range(CROSSINGS.size()):
		_span(CROSSINGS[i], i)
	_trackbed()
	_masts()
	_north_join()
	_south_end()
	for row: Array in TENANTS:
		_tenant(row[0], row[1], row[2])
	_instruments()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "neon", "led", "sign", "room", "shelf", "lantern", "wood", "tiled"])
	_kit = null

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.conc = _look("plastered_wall_03", 4.0, .95)
	_looks.conc.set_shader_parameter("tile_size", Vector2(2.1, .18))
	_looks.conc.set_shader_parameter("chroma", .45)
	_looks.conc.set_shader_parameter("day_glow", .2)
	_looks.conc.set_shader_parameter("glow", .05)
	_looks.concv = _look("plastered_wall_03", 4.0, .95)
	_looks.concv.set_shader_parameter("tile_size", Vector2(.15, 2.4))
	_looks.concv.set_shader_parameter("chroma", .45)
	_looks.concv.set_shader_parameter("day_glow", .2)
	_looks.concv.set_shader_parameter("glow", .05)
	_looks.smooth = _look("plastered_wall_03", 5.0, .95)
	_looks.smooth.set_shader_parameter("chroma", .45)
	_looks.smooth.set_shader_parameter("day_glow", .2)
	_looks.smooth.set_shader_parameter("glow", .05)
	_looks.trough = _look("plastered_wall_03", 3.0, .95)
	_looks.trough.set_shader_parameter("tile_size", Vector2(.6, .34))
	_looks.trough.set_shader_parameter("chroma", .6)
	_looks.steel = _look("plastered_wall_03", 3.0, .6, .2)
	_looks.steel.set_shader_parameter("chroma", .2)
	_looks.steel.set_shader_parameter("day_glow", .22)
	_looks.steel.set_shader_parameter("glow", .08)
	_looks.corr = _look("rusty_corrugated_iron", 2.6, .8, .2)
	_looks.corr.set_shader_parameter("chroma", .5)
	_looks.corr.set_shader_parameter("day_glow", .14)
	_looks.corr.set_shader_parameter("glow", .03)
	_looks.noise = _look("painted_metal_shutter", 2.4, .7, .1)
	_looks.noise.set_shader_parameter("chroma", .3)
	_looks.noise.set_shader_parameter("day_glow", .18)
	_looks.noise.set_shader_parameter("glow", .03)
	_looks.shutter = _look("painted_metal_shutter", 2.0, .6, .2)
	_looks.shutter.set_shader_parameter("chroma", .4)
	_looks.shutter.set_shader_parameter("day_glow", .2)
	_looks.shutter.set_shader_parameter("glow", .04)
	_looks.wood = _look("japanese_cedar_planks", 2.0, .7)
	_looks.wood.set_shader_parameter("chroma", .6)
	_looks.wood.set_shader_parameter("glow", .13)
	_looks.wood.set_shader_parameter("day_glow", .1)
	_looks.tiled = _look("long_white_tiles", 1.6, .6)
	_looks.tiled.set_shader_parameter("chroma", .6)
	_looks.tiled.set_shader_parameter("glow", .24)
	_looks.tiled.set_shader_parameter("day_glow", .1)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.iron = _look("worn_corrugated_iron", 2.4, .8, .2)
	_looks.iron.set_shader_parameter("chroma", .6)
	_looks.iron.set_shader_parameter("day_glow", .16)
	_looks.iron.set_shader_parameter("glow", .03)
	_looks.rail = _look("", 1.0, .32, .75)
	_looks.room = _look("", 1.0, .55)
	_looks.room.set_shader_parameter("glow", .3)
	_looks.room.set_shader_parameter("day_glow", .1)
	_looks.shelf = _look("", 1.0, .55)
	_looks.shelf.set_shader_parameter("albedo_map", signs)
	_looks.shelf.set_shader_parameter("glow", .32)
	_looks.shelf.set_shader_parameter("day_glow", .12)
	_looks.ballast = _look("", 1.0, .9)
	_looks.ballast.set_shader_parameter("albedo_map", signs)
	_looks.board = _look("", 1.0, .75)
	_looks.board.set_shader_parameter("albedo_map", signs)
	_looks.sign = _look("", 1.0, .35)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .7)
	_looks.sign.set_shader_parameter("day_glow", .12)
	_looks.cloth = _look("", 1.0, .92)
	_looks.cloth.set_shader_parameter("albedo_map", signs)
	_looks.lantern = _look("", 1.0, .7)
	_looks.lantern.set_shader_parameter("albedo_map", signs)
	_looks.lantern.set_shader_parameter("glow", 1.1)
	_looks.lantern.set_shader_parameter("day_glow", .1)
	var marks := ShaderMaterial.new()
	marks.shader = DECAL_SHADER
	marks.set_shader_parameter("atlas", signs)
	_looks.decal = marks

# Small hands -----------------------------------------------------------------

func _box(part: String, x: float, y: float, z: float, size: Vector3, tint: Color, low := 1.0, high := 1.0, streak := 0.0) -> void:
	_kit.block(part, Transform3D(Basis.IDENTITY, Vector3(x, y, z)), size, tint, low, high, streak, Vector2(_rng.randf() * 7.0, _rng.randf() * 7.0))

func _corners(out: Vector3, at: float, u0: float, u1: float, y0: float, y1: float) -> Array[Vector3]:
	# The four corners, in kit order, of a wall facing along out: u is z on an x wall, x on a z wall.
	if out.x > 0.0: return [Vector3(at, y0, u1), Vector3(at, y1, u1), Vector3(at, y1, u0), Vector3(at, y0, u0)]
	if out.x < 0.0: return [Vector3(at, y0, u0), Vector3(at, y1, u0), Vector3(at, y1, u1), Vector3(at, y0, u1)]
	if out.z > 0.0: return [Vector3(u0, y0, at), Vector3(u0, y1, at), Vector3(u1, y1, at), Vector3(u1, y0, at)]
	return [Vector3(u1, y0, at), Vector3(u1, y1, at), Vector3(u0, y1, at), Vector3(u0, y0, at)]

func _wall(part: String, out: Vector3, at: float, u0: float, u1: float, y0: float, y1: float, tint: Color, low := 1.0, high := 1.0, streak := 0.0) -> void:
	var c := _corners(out, at, u0, u1, y0, y1)
	_kit.quad(part, c[0], c[1], c[2], c[3], tint, low, high, streak, Vector2(_rng.randf() * 7.0, _rng.randf() * 7.0))

func _stain(cell: int, out: Vector3, at: float, u0: float, u1: float, y0: float, y1: float, strength := 1.0) -> void:
	# Weather runs from the top of its cell, so y1 is where the water came out.
	var c := _corners(out, at + .012 * (out.x + out.z), u0, u1, y0, y1)
	_kit.atlas("decal", c[0], c[1], c[2], c[3], _cell(float(cell) * 256.0, 0, 256, 512), Color.WHITE, strength)

func _mark(part: String, out: Vector3, at: float, u0: float, u1: float, y0: float, y1: float, rect: Rect2, tint := Color.WHITE) -> void:
	var c := _corners(out, at + .014 * (out.x + out.z), u0, u1, y0, y1)
	_kit.atlas(part, c[0], c[1], c[2], c[3], rect, tint)

func _under(part: String, x0: float, x1: float, z0: float, z1: float, y: float, tint: Color, ao := .6) -> void:
	_kit.quad(part, Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), tint, ao, ao, 0.0, Vector2(_rng.randf() * 7.0, _rng.randf() * 7.0))

func _over(part: String, x0: float, x1: float, z0: float, z1: float, y: float, tint: Color, ao := 1.0) -> void:
	_kit.quad(part, Vector3(x0, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), tint, ao, ao, 0.0, Vector2(_rng.randf() * 7.0, _rng.randf() * 7.0))

func _tone(strength := .06) -> Color:
	var t := 1.0 - _rng.randf() * strength * 2.0
	return Color(CONCRETE.r * t, CONCRETE.g * t, CONCRETE.b * t)

func _pick(cells: Array[int]) -> int:
	return cells[_rng.randi_range(0, cells.size() - 1)]

func _prism(part: String, cx: float, cz: float, hx: float, hz: float, cut: float, y0: float, y1: float, tint: Color, streak := .5) -> void:
	# A column with its arrises chamfered, as the shutter fillets leave them.
	var ring: Array[Vector2] = [Vector2(-hx + cut, hz), Vector2(hx - cut, hz), Vector2(hx, hz - cut), Vector2(hx, -hz + cut), Vector2(hx - cut, -hz), Vector2(-hx + cut, -hz), Vector2(-hx, -hz + cut), Vector2(-hx, hz - cut)]
	var along := _rng.randf() * 6.0
	for i: int in range(8):
		var p := ring[i]
		var q := ring[(i + 1) % 8]
		_kit.quad(part, Vector3(cx + p.x, y0, cz + p.y), Vector3(cx + p.x, y1, cz + p.y), Vector3(cx + q.x, y1, cz + q.y), Vector3(cx + q.x, y0, cz + q.y), tint, .78, .82, streak, Vector2(along, y0))
		along += p.distance_to(q)

# Frames ----------------------------------------------------------------------

func _plan_and_frames() -> void:
	var count := 0
	var zs: Array[Vector2] = [Vector2(-146.0, 0.0), Vector2(-139.0, 1.0)]
	var runs: Array[Vector2] = [Vector2(-148.0, -139.0)]
	for i: int in range(CROSSINGS.size() - 1):
		var low := CROSSINGS[i] + REACH
		var high := CROSSINGS[i + 1] - REACH
		runs.append(Vector2(low, high))
		var z := low
		while z <= high + .1:
			zs.append(Vector2(z, 1.0 if z == low or z >= high - .1 else 0.0))
			z += BAY
	runs.append(Vector2(139.0, Z_END))
	zs.append_array([Vector2(139.0, 1.0), Vector2(146.0, 0.0), Vector2(150.9, 0.0)] as Array[Vector2])
	_deck_runs = runs
	for row: Vector2 in zs:
		count += 1
		_frame(row.x, row.y > .5, count)
	# Tie beams along the pavement, where the frames are one structure.
	for run: Vector2 in runs:
		var z := run.x if run.x > -140.0 else -146.0
		while z < minf(run.y - 1.0, 150.8):
			var next := minf(z + BAY, 150.9)
			for s: float in [-1.0, 1.0]:
				_box("conc", s * COLUMN_X, 6.88, (z + next) * .5, Vector3(.5, .66, next - z), _tone(), .55, .9, .5)
				if _rng.randf() < .5:
					_stain(_pick([STAIN_DARK, STAIN_LIME, STAIN_RUST]), Vector3(-s, 0, 0), s * (COLUMN_X - .25), z + _rng.randf_range(.8, 3.0), next - _rng.randf_range(.8, 3.0), 6.55, 7.21, .8)
			z = next

func _wire_low(z: float) -> float:
	# Where the street's telecom bundle runs past a frame: pole to pole with a .7 m sag.
	var bank := fposmod(z - 7.0, 64.0)
	var t := fposmod(bank, 50.0 / 3.0) / (50.0 / 3.0)
	return 6.6 - .7 * 4.0 * t * (1.0 - t)

func _frame(z: float, heavy: bool, number: int) -> void:
	var half := .7 if heavy else .45
	var top := 7.3 if heavy else SOFFIT
	var thick := .7 if heavy else .5
	var knee := 5.0
	var belly := 5.75
	var tone := _tone()
	for s: float in [-1.0, 1.0]:
		_prism("concv", s * COLUMN_X, z, .45, thick, .05, 0.0, knee + .02, tone)
		_box("smooth", s * COLUMN_X, .16, z, Vector3(1.04, .32, thick * 2.0 + .14), tone * .85, .7, 1.0)
		_column_weather(s, z, thick, number, heavy)
	for side: float in [-1.0, 1.0]:
		var at := z + side * half
		var out := Vector3(0, 0, side)
		_wall("conc", out, at, -9.85, -8.95, knee, top, tone, .8, .7, .6)
		_wall("conc", out, at, 8.95, 9.85, knee, top, tone, .8, .7, .6)
		_wall("conc", out, at, -7.6, 7.6, belly, top, tone, .62, .55, .6)
		for s: float in [-1.0, 1.0]:
			var near := s * 8.95
			var far := s * 7.6
			var a := Vector3(minf(near, far), knee if s < 0.0 else belly, at)
			var b := Vector3(a.x, top, at)
			var c := Vector3(maxf(near, far), top, at)
			var d := Vector3(c.x, belly if s < 0.0 else knee, at)
			if side > 0.0: _kit.quad("conc", a, b, c, d, tone, .7, .6, .6, Vector2(_rng.randf() * 7.0, _rng.randf()))
			else: _kit.quad("conc", d, c, b, a, tone, .7, .6, .6, Vector2(_rng.randf() * 7.0, _rng.randf()))
		# What runs off the exposed cap, and what comes through at the bearings.
		for s: float in [-1.0, 1.0]:
			if _rng.randf() < .7:
				var mid := s * _rng.randf_range(6.0, 8.8)
				_stain(_pick([STAIN_DARK, STAIN_FAN, STAIN_LIME]), out, at, mid - _rng.randf_range(.5, 1.0), mid + _rng.randf_range(.5, 1.0), top - 2.2, top, .9)
		if heavy: _stain(STAIN_RUST, out, at, -5.0, -2.8, belly + .05, top, 1.0)
	_under("conc", -7.6, 7.6, z - half, z + half, belly, tone, .5)
	for s: float in [-1.0, 1.0]:
		var x0 := s * 8.95
		var x1 := s * 7.6
		var a := Vector3(x0, knee, z - half)
		var b := Vector3(x0, knee, z + half)
		var c := Vector3(x1, belly, z + half)
		var d := Vector3(x1, belly, z - half)
		if s < 0.0: _kit.quad("conc", a, b, c, d, tone, .5, .5)
		else: _kit.quad("conc", d, c, b, a, tone, .5, .5)
		_wall("concv", Vector3(s, 0, 0), s * 9.85, z - half, z + half, knee, top, tone, .8, .8, .7)
		_over("smooth", minf(s * 5.5, s * 9.85), maxf(s * 5.5, s * 9.85), z - half, z + half, top, tone * .8)
	# A sleeve where the street's telecom bundle was let through the beam.
	_box("metal", -7.35, _wire_low(z), z, Vector3(.13, .13, half * 2.0 + .05), Color("#2a2b2c"))
	if number % 3 == 1: _downpipe(z, half, 1.0 if number % 2 == 0 else -1.0)
	if number % 2 == 0 and not heavy:
		# Council tube under the beam, for the street it stands over.
		for s: float in [-1.0, 1.0]:
			_box("metal", s * 3.6, belly - .03, z, Vector3(.14, .06, 1.25), Color("#55585a"))
			_box("lamp", s * 3.6, belly - .07, z, Vector3(.06, .03, 1.16), Color(.95, .88, .72))

func _column_weather(s: float, z: float, thick: float, number: int, heavy: bool) -> void:
	var road := Vector3(-s, 0, 0)
	var face := s * (COLUMN_X - .45)
	var left := z - thick + .05
	var right := z + thick - .05
	_stain(STAIN_DAMP, road, face, left, right, 0.0, _rng.randf_range(1.3, 2.3), .85)
	_stain(_pick([STAIN_DARK, STAIN_FAN, STAIN_LIME, STAIN_CRACK]), road, face, left, right, _rng.randf_range(1.6, 3.0), 5.0, .9)
	if _rng.randf() < .3: _stain(STAIN_PATCH, road, face, left + .1, right - .2, _rng.randf_range(2.2, 3.4), 4.3, .95)
	for side: float in [-1.0, 1.0]:
		var along := Vector3(0, 0, side)
		var u0 := s * COLUMN_X - .4
		var u1 := s * COLUMN_X + .4
		_stain(STAIN_DAMP, along, z + side * thick, u0, u1, 0.0, _rng.randf_range(1.0, 2.0), .8)
		if _rng.randf() < .6: _stain(_pick([STAIN_DARK, STAIN_RUST_FINE, STAIN_LIME]), along, z + side * thick, u0, u1, _rng.randf_range(2.0, 3.2), 5.0, .85)
	if heavy:
		# Corner columns at the junction get the lorry paint.
		for i: int in range(2):
			_mark("board", road, face, left + float(i) * thick, left + float(i + 1) * thick - .04, .34, 1.2, _cell(60.0 + float(i) * 240.0, 548, 110, 60))
	# 枠 number, stencilled at inspection height: the only thing the maintenance gang reads.
	var text := "R%03d" % (number + 200)
	var x := z - .32 if s > 0.0 else z + .16
	for i: int in range(4):
		var c := text.unicode_at(i)
		var slot := 10 if c == 82 else c - 48
		_mark("decal", road, face, x + float(i) * (.16 if s > 0.0 else -.16), x + float(i) * (.16 if s > 0.0 else -.16) + .15, 2.5, 2.74, _cell(float(slot) * 60.0, 824, 60, 90), Color(.92, .92, .88))
	if number % 7 == 3:
		var poster := _rng.randi_range(0, 2)
		_mark("board", road, face + s * .002, left + .2, left + .62, 1.2, 1.78, _cell(float(poster) * 250.0, 1700, 240, 340), Color(.9, .88, .84))

func _downpipe(z: float, half: float, s: float) -> void:
	# Grey PVC off the deck gully, along the cap and down the column to the street drain.
	var side := z + half + .1
	var points: Array[Vector3] = [Vector3(s * 5.62, 8.2, side), Vector3(s * 5.72, 7.82, side), Vector3(s * 8.78, 7.72, side), Vector3(s * 8.86, 7.4, side), Vector3(s * 8.86, .35, side), Vector3(s * 8.7, .14, side)]
	_kit.tube("plain", points, .05, PVC, 6)
	var y := 1.2
	while y < 7.0:
		_kit.block("metal", Transform3D(Basis.IDENTITY, Vector3(s * 8.88, y, side)), Vector3(.14, .03, .14), Color("#55504a"))
		y += 2.6
	_stain(STAIN_RUST_FINE, Vector3(0, 0, 1), z + half, s * 8.86 - .34, s * 8.86 + .34, 3.0, 5.4, .7)

# Deck ------------------------------------------------------------------------

func _deck_run(run: Vector2) -> void:
	var z := run.x
	while z < run.y - .01:
		var next := minf(z + BAY, run.y)
		var from := -148.7 if z <= Z_START else z
		_deck_bay(from, next)
		z = next
	# Movement joints every third bay, with the water that has found every one of them.
	var joint := run.x + 3.0 * BAY
	while joint < run.y - 3.0:
		for s: float in [-1.0, 1.0]:
			_box("plain", s * 5.5, 7.95, joint, Vector3(.012, .8, .035), Color("#181716"))
			_box("plain", s * 5.0, 6.88, joint, Vector3(.012, 1.34, .035), Color("#181716"))
			_stain(STAIN_FAN, Vector3(s, 0, 0), s * 5.0, joint - 1.2, joint + 1.2, 6.2, 7.55, 1.0)
			_stain(_pick([STAIN_RUST, STAIN_LIME]), Vector3(s, 0, 0), s * 5.5, joint - .8, joint + .8, 7.0, 8.35, 1.0)
		_under("plain", -5.5, 5.5, joint - .02, joint + .02, SOFFIT - .02, Color("#181716"))
		joint += 3.0 * BAY
	# Slab walkway beside the ballast.
	for s: float in [-1.0, 1.0]:
		_box("trough", s * 5.08, 8.36, (run.x + run.y) * .5, Vector3(.36, .22, run.y - run.x), Color(.82, .8, .76))

func _deck_bay(z0: float, z1: float) -> void:
	var tone := _tone(.05)
	_under("smooth", -5.5, 5.5, z0, z1, SOFFIT - .01, tone, .42)
	for s: float in [-1.0, 1.0]:
		var out := Vector3(s, 0, 0)
		var inner := Vector3(-s, 0, 0)
		_wall("conc", out, s * 5.5, z0 if z0 > Z_START else Z_START, z1, SOFFIT, 8.35, tone, .75, .95, .55)
		_wall("conc", out, s * 5.0, z0, z1, 6.2, SOFFIT, tone, .55, .5, .4)
		_wall("conc", inner, s * 4.55, z0, z1, 6.2, SOFFIT, tone, .4, .4)
		_under("conc", minf(s * 5.0, s * 4.55), maxf(s * 5.0, s * 4.55), z0, z1, 6.2, tone, .5)
		for m: float in [-1.0, 1.0]:
			var x := s * 1.7 + m * .2
			_wall("conc", Vector3(m, 0, 0), x, z0, z1, 6.8, SOFFIT, tone, .4, .35)
		_under("conc", s * 1.7 - .2, s * 1.7 + .2, z0, z1, 6.8, tone, .45)
		var heart := z0 + _rng.randf_range(.8, z1 - z0 - .8)
		_stain(_pick([STAIN_DARK, STAIN_FAN, STAIN_RUST]), out, s * 5.5, heart - .7, heart + .7, 6.9, 8.35, .9)
		_stain(_pick([STAIN_DARK, STAIN_LIME, STAIN_FAN]), out, s * 5.0, z0 + .3, z0 + 1.7, 6.2, SOFFIT, .85)
		if _rng.randf() < .35: _stain(STAIN_CRACK, out, s * 5.0, heart - .35, heart + .35, 6.2, SOFFIT, .7)
		# Gully spout, a stub of pipe with its own tide mark.
		var spout := z0 + 2.2
		_kit.tube("metal", [Vector3(s * 5.5, 8.18, spout), Vector3(s * 5.72, 8.14, spout)], .045, Color("#3f3d3a"), 4)

func _wall_run(run: Vector2, s: float) -> void:
	var out := Vector3(s, 0, 0)
	var z := run.x
	while z < run.y - .01:
		var next := minf(z + BAY, run.y)
		var tone := _tone()
		_wall("conc", out, s * 5.54, z, next, 8.35, WALL_FOOT, tone, .85, 1.0, .8)
		_wall("conc", -out, s * 5.26, z, next, 8.35, WALL_FOOT, tone * .9, .8, 1.0, .5)
		_over("smooth", minf(s * 5.26, s * 5.54), maxf(s * 5.26, s * 5.54), z, next, WALL_FOOT, tone)
		z = next
	# Noise panels on H-posts; the first and last ramp, so the line of the wall never steps.
	var at := run.x
	while at < run.y - .01:
		var end := minf(at + 3.5, run.y)
		var low := WALL_TOP
		var high := WALL_TOP
		if at < Z_START + 7.0: low = lerpf(WALL_FOOT, WALL_TOP, (at - Z_START) / 7.0); high = lerpf(WALL_FOOT, WALL_TOP, (end - Z_START) / 7.0)
		else:
			if at - run.x < 3.4: low = WALL_FOOT + .3
			if run.y - end < .1 and run.y < 150.0: high = WALL_FOOT + .3
		var fresh := _rng.randf() < .18
		var tint := Color("#e4e8e2") if fresh else Color("#c2c6be") * _rng.randf_range(.86, 1.06)
		tint.a = 1.0
		var a := Vector3(s * 5.48, WALL_FOOT, end if s > 0.0 else at)
		var b := Vector3(s * 5.48, high if s > 0.0 else low, end if s > 0.0 else at)
		var c := Vector3(s * 5.48, low if s > 0.0 else high, at if s > 0.0 else end)
		var d := Vector3(s * 5.48, WALL_FOOT, at if s > 0.0 else end)
		_kit.quad("noise", a, b, c, d, tint, .9, 1.0, .7, Vector2(_rng.randf() * 3.0, 0))
		_kit.quad("noise", d + Vector3(-s * .08, 0, 0), c + Vector3(-s * .08, 0, 0), b + Vector3(-s * .08, 0, 0), a + Vector3(-s * .08, 0, 0), tint * .8, .9, 1.0, .4)
		var cap := Vector3(s * .1, 0, 0)
		var rise := Vector3.UP * .03
		if s > 0.0: _kit.quad("metal", b + rise, b + cap + rise, c + cap + rise, c + rise, Color("#5f625f"))
		else: _kit.quad("metal", c + rise, c + cap + rise, b + cap + rise, b + rise, Color("#5f625f"))
		if int((at - run.x) / 3.5) % 2 == 0: _box("metal", s * 5.5, (WALL_FOOT + low) * .5, at, Vector3(.13, low - WALL_FOOT + .05, .13), STEEL)
		else: _wall("metal", out, s * 5.5, at - .06, at + .06, WALL_FOOT, low, STEEL)
		if _rng.randf() < .4: _stain(STAIN_RUST_FINE, out, s * 5.54, at - .5, at + .5, 8.1, WALL_FOOT, .9)
		at = end

# Steel over the street -------------------------------------------------------

func _span(c: float, number: int) -> void:
	# A through plate-girder: two riveted girders outboard, the track slung between them.
	var z0 := c - REACH + .4
	var z1 := c + REACH - .4
	var paint := PAINT.darkened(_rng.randf_range(0.0, .12))
	for s: float in [-1.0, 1.0]:
		_girder(s, z0, z1, paint)
		_street_face(s, c, number)
	var z := z0 + .35
	while z < z1:
		_box("steel", 0, 7.71, z, Vector3(10.3, .5, .02), paint * .8, .6, .7)
		_box("steel", 0, 7.45, z, Vector3(10.3, .03, .3), paint * .7, .5, .6)
		z += 2.2
	for x: float in [-TRACK - GAUGE, -TRACK + GAUGE, TRACK - GAUGE, TRACK + GAUGE]:
		_box("steel", x, 7.8, c, Vector3(.016, .4, z1 - z0), paint * .75, .5, .6)
		_box("steel", x, 7.6, c, Vector3(.22, .03, z1 - z0), paint * .65, .5, .6)
	for i: int in range(4):
		var a := z0 + 2.0 + float(i) * 4.65
		var b := a + 4.65
		_kit.beam("steel", Vector3(-4.8, 7.5, a), Vector3(4.8, 7.5, b), .08, .05, Vector3.UP, paint * .6)
		_kit.beam("steel", Vector3(4.8, 7.5, a), Vector3(-4.8, 7.5, b), .08, .05, Vector3.UP, paint * .6)
	# Ribbed trough under the ballast, running across the bridge as in the Koenji bays.
	var a2 := Vector3(-5.0, 8.02, z0)
	var b2 := Vector3(-5.0, 8.02, z1)
	var c2 := Vector3(5.0, 8.02, z1)
	var d2 := Vector3(5.0, 8.02, z0)
	_kit.quad("corr", b2, c2, d2, a2, Color(.5, .56, .52), .45, .45)
	for s: float in [-1.0, 1.0]:
		for end: float in [c - REACH + .5, c + REACH - .5]:
			_box("metal", s * 5.2, 7.325, end, Vector3(.76, .05, .56), Color("#3b3c3c"))
	# Tube lights slung for the crossing, the one warm-white pool on the street.
	for row: Array in [[-3.0, c - 4.4], [3.0, c - 4.4], [-3.0, c + 4.4], [3.0, c + 4.4]]:
		_box("metal", row[0], 7.36, row[1], Vector3(.1, .06, 1.3), Color("#4a4c4e"))
		_box("lamp", row[0], 7.32, row[1], Vector3(.05, .03, 1.2), Color(1.0, .9, .74))
	_omni("SpanLight%d" % number, Vector3(0, 6.6, c), Color(1.0, .86, .68), 1.2, 5.9)

func _girder(s: float, z0: float, z1: float, paint: Color) -> void:
	var c := (z0 + z1) * .5
	var long := z1 - z0
	var x := s * 5.2
	var mid := (GIRDER_LOW + GIRDER_HIGH) * .5
	var tall := GIRDER_HIGH - GIRDER_LOW
	_wall("steel", Vector3(s, 0, 0), x + s * .012, z0, z1, GIRDER_LOW, GIRDER_HIGH, paint, .7, 1.0, .9)
	_wall("steel", Vector3(-s, 0, 0), x - s * .012, z0, z1, GIRDER_LOW, GIRDER_HIGH, paint * .85, .7, 1.0, .5)
	_box("steel", x, GIRDER_LOW + .02, c, Vector3(.56, .04, long), paint * .9, .55, .9, .3)
	_box("steel", x, GIRDER_HIGH - .02, c, Vector3(.56, .04, long), paint, .95, 1.0, .3)
	_box("steel", x, GIRDER_LOW - .012, c, Vector3(.56, .022, long * .62), paint * .9, .55, .9)
	_box("steel", x, GIRDER_HIGH + .012, c, Vector3(.56, .022, long * .62), paint, .95, 1.0)
	for m: float in [-1.0, 1.0]:
		_box("steel", x + m * .05, GIRDER_LOW + .09, c, Vector3(.09, .1, long), paint * .82, .6, .9)
		_box("steel", x + m * .05, GIRDER_HIGH - .09, c, Vector3(.09, .1, long), paint * .95, .8, 1.0)
		_box("steel", x, mid, z0 + (m + 1.0) * .5 * long, Vector3(.56, tall, .05), paint * .92, .8, 1.0, .4)
	var at := z0 + 1.0
	var count := 0
	while at < z1 - .4:
		_box("steel", x + s * .07, mid, at, Vector3(.13, tall - .3, .02), paint * (.96 if count % 2 == 0 else .9), .8, 1.0, .6)
		if count % 3 == 0: _box("steel", x - s * .07, mid, at, Vector3(.13, tall - .3, .02), paint * .8, .8, 1.0)
		# Rust bleeds at the foot of the stiffeners, where wet ballast dust has sat for fifty years.
		if _rng.randf() < .55:
			_stain(_pick([STAIN_RUST, STAIN_RUST_FINE, STAIN_DARK]), Vector3(s, 0, 0), x + s * .012, at + .1, at + 1.3, GIRDER_LOW + .1, GIRDER_HIGH - .1, .95)
		at += 1.6
		count += 1
	var strip := z0
	while strip < z1 - .1:
		var end := minf(strip + 8.2, z1)
		var cover := _cell(0, 512, 1024.0 * (end - strip) / 8.2, 32)
		for y: float in [GIRDER_LOW + .19, GIRDER_HIGH - .19]:
			_mark("decal", Vector3(s, 0, 0), x + s * .012, strip, end, y - .05, y + .05, cover)
		strip = end

func _street_face(s: float, c: float, number: int) -> void:
	var out := Vector3(s, 0, 0)
	var face := s * 5.48
	var dark := Color("#20211f")
	# 防護工: a yellow-black beam under the girder, over the carriageway, bolted on and well dented.
	_box("metal", s * 5.42, 7.17, c, Vector3(.12, .34, 14.4), dark)
	var at := c - 7.2
	var left := 14.4
	while left > .01:
		var run := minf(5.2, left)
		_mark("board", out, s * 5.48, at, at + run, 7.0, 7.34, _cell(0, 548, 960.0 * run / 5.2, 60))
		at += run
		left -= run
	for z: float in [c - 6.0, c - 2.0, c + 2.0, c + 6.0]:
		_box("metal", s * 5.4, 7.36, z, Vector3(.1, .1, .16), STEEL)
	var lane := c - s * -3.5 if s > 0.0 else c - 3.5
	var right := Vector3(0, 0, -s)
	var disc_at := Vector3(face + s * .06, 8.42, lane)
	_box("metal", face, 8.42, lane, Vector3(.08, .3, .3), dark)
	_kit.disc("metal", disc_at - out * .012, right, Vector3.UP, .47, Color("#3a3c3c"))
	_kit.disc("board", disc_at, right, Vector3.UP, .45, Color.WHITE, _cell(0, 620, 200, 200))
	_mark("board", out, face + s * .02, c - .85, c + .85, 8.1, 8.72, _cell(210, 620, 380, 140))
	_box("metal", face, 8.41, c, Vector3(.05, .68, 1.78), dark)
	# Name board at the pavement end, and the bridge's big painted number.
	var plate := c + 8.4 * (1.0 if s > 0.0 else -1.0)
	_box("metal", face, 8.5, plate, Vector3(.04, .34, 1.34), dark)
	_mark("board", out, face + s * .02, plate - .65, plate + .65, 8.34, 8.66, _cell(700, 910.0 + float(number) * 104.0, 400, 96))
	var text := "%02d" % (number + 41)
	var mark := c - 8.8 * (1.0 if s > 0.0 else -1.0)
	for i: int in range(2):
		var slot := mark + float(i) * (-.42 if s > 0.0 else .42)
		_mark("decal", out, s * 5.32, slot, slot + .4, 8.3, 8.9, _cell(float(text.unicode_at(i) - 48) * 60.0, 824, 60, 90), Color(.88, .88, .82))

# On top ----------------------------------------------------------------------

func _trackbed() -> void:
	# Ballast shoulder to shoulder, concrete sleepers, four rails at the old line's positions.
	var z := Z_START
	while z < Z_END - 2.0:
		var end := minf(z + 3.0, Z_END - .3)
		var x := -4.9
		var wide := 9.8 / 3.0
		while x < 4.85:
			var rect := _cell(1536, 512, 512, 512)
			rect.size.y *= (end - z) / 3.0
			_kit.atlas("ballast", Vector3(x, DECK_TOP + .01, end), Vector3(x, DECK_TOP + .01, z), Vector3(x + wide, DECK_TOP + .01, z), Vector3(x + wide, DECK_TOP + .01, end), rect, Color(.9, .88, .85))
			x += wide
		z = end
	for track: float in [-TRACK, TRACK]:
		var at := Z_START + .3
		while at < Z_END - 2.6:
			var a := track - 1.2
			var b := track + 1.2
			var tint := Color(.6, .59, .56) * _rng.randf_range(.86, 1.05)
			tint.a = 1.0
			var low := DECK_TOP + .01
			var high := DECK_TOP + .08
			_over("plain", a, b, at - .11, at + .11, high, tint)
			_wall("plain", Vector3(0, 0, 1), at + .11, a, b, low, high, tint * .8)
			at += .8
		for offset: float in [-GAUGE, GAUGE]:
			var middle := (Z_START + Z_END - 2.4) * .5
			var long := Z_END - 2.4 - Z_START
			_box("rail", track + offset, DECK_TOP + .093, middle, Vector3(.13, .016, long), Color("#54392a"))
			_box("rail", track + offset, RAIL_TOP - .062, middle, Vector3(.022, .06, long), Color("#4e3628"))
			_box("rail", track + offset, RAIL_TOP - .02, middle, Vector3(.066, .04, long), Color("#8d8984"))

func _masts() -> void:
	# H-section masts on the deck edge, cantilever arms out over each track, droppers and a sagging catenary.
	for i: int in range(MASTS.size()):
		var z := MASTS[i]
		var zig := 0.0 if i == 0 else (.14 if i % 2 == 0 else -.14)
		for s: float in [-1.0, 1.0]:
			_mast(s, z, zig, i)
			if i + 1 < MASTS.size():
				_wires(s, z, MASTS[i + 1], zig, 0.14 if (i + 1) % 2 == 0 else -.14)

func _mast(s: float, z: float, zig: float, i: int) -> void:
	var x := s * 5.86
	var tint := Color("#6d7570") * (.9 if i % 3 == 0 else 1.0)
	tint.a = 1.0
	var foot := 7.84
	var head := 16.0
	var middle := (foot + head) * .5
	var tall := head - foot
	for m: float in [-1.0, 1.0]:
		_box("metal", x + m * .14, middle, z, Vector3(.025, tall, .3), tint)
	_box("metal", x, middle, z, Vector3(.28, tall, .02), tint * .85)
	_box("metal", s * 5.72, 8.1, z, Vector3(.42, .56, .46), Color("#3e3f3e"))
	_box("metal", x, head + .02, z, Vector3(.34, .03, .34), tint)
	var track := s * TRACK + zig
	var pin_high := Vector3(x - s * .16, 15.5, z)
	var pin_low := Vector3(x - s * .16, 14.15, z)
	var end := Vector3(track, 15.24, z)
	_kit.tube("metal", [pin_high + Vector3(-s * .32, 0, 0), end], .03, Color("#7c807e"), 5)
	_kit.tube("metal", [pin_low + Vector3(-s * .32, 0, 0), Vector3(track, 14.46, z), end], .025, Color("#7c807e"), 5)
	for pin: Vector3 in [pin_high, pin_low]:
		_kit.lathe("plain", pin + Vector3(-s * .1, -.1, 0), [Vector2(.04, 0), Vector2(.08, .06), Vector2(.05, .1), Vector2(.08, .14), Vector2(.04, .19)], Color("#6e4a36"), 5)
	_kit.tube("metal", [Vector3(track, 14.46, z), Vector3(track, WIRE_Y, z)], .012, Color("#6a6e6c"), 3)
	if i % 4 == 1:
		# 2050: a strain sensor on the arm, and the little sun that keeps it awake.
		_box("metal", x - s * .12, 13.1, z, Vector3(.1, .18, .14), Color("#d0d2cc"))
		_bar("led", Transform3D.IDENTITY, x - s * .18, 13.14, z, Vector3(.012, .03, .03), GREEN)

func _wires(s: float, z0: float, z1: float, zig0: float, zig1: float) -> void:
	var black := Color("#141414")
	var track := s * TRACK
	_kit.tube("plain", [Vector3(track + zig0, WIRE_Y, z0), Vector3(track + zig1, WIRE_Y, z1)], .014, black, 3)
	var points: Array[Vector3] = []
	for i: int in range(7):
		var t := float(i) / 6.0
		points.append(Vector3(track + lerpf(zig0, zig1, t) * .3, 15.24 - 4.0 * t * (1.0 - t) * .92, lerpf(z0, z1, t)))
	_kit.tube("plain", points, .012, black, 3)
	for i: int in range(1, 6):
		var t := float(i) / 6.0
		_kit.tube("plain", [points[i], Vector3(track + lerpf(zig0, zig1, t), WIRE_Y, lerpf(z0, z1, t))], .004, Color("#2c2c2c"), 3)
	# Feeder along the mast tops.
	_kit.tube("plain", [Vector3(s * 5.86, 16.0, z0), Vector3(s * 5.86, 15.72, (z0 + z1) * .5), Vector3(s * 5.86, 16.0, z1)], .016, black, 3)

# The two ends ----------------------------------------------------------------

func _north_join() -> void:
	# Bolted cover plates over the movement joint where the 1978 pour meets the older deck.
	var plate := Color("#55565a")
	for s: float in [-1.0, 1.0]:
		_box("metal", s * 5.51, 7.95, Z_START, Vector3(.07, .84, .14), plate)
		_box("metal", s * 5.55, 9.0, Z_START, Vector3(.05, 1.32, .14), plate)
		_box("metal", s * 5.4, 9.665, Z_START, Vector3(.3, .03, .14), plate)
		_box("metal", s * 5.02, 6.88, Z_START - .72, Vector3(.05, 1.36, .1), plate)
		_stain(STAIN_DARK, Vector3(s, 0, 0), s * 5.5, Z_START - .5, Z_START + .9, 6.9, 8.35, 1.0)
	_box("metal", 0, DECK_TOP + .012, Z_START, Vector3(10.6, .02, .16), plate)

func _south_end() -> void:
	# The extension was never built: a stop block, buffers, and starter bars left for the next century.
	var z := Z_END
	_wall("conc", Vector3(0, 0, 1), z, -5.54, 5.54, 6.2, WALL_FOOT, _tone(), .6, 1.0, .9)
	_wall("conc", Vector3(0, 0, -1), z - .3, -5.26, 5.26, DECK_TOP, WALL_FOOT, _tone() * .9, .8, 1.0)
	_over("smooth", -5.54, 5.54, z - .3, z, WALL_FOOT, _tone())
	for i: int in range(4):
		var u := -4.6 + float(i) * 2.4
		_stain(_pick([STAIN_DARK, STAIN_RUST, STAIN_FAN]), Vector3(0, 0, 1), z, u, u + 1.8, 6.4, WALL_FOOT, .9)
	var x := -4.8
	while x < 4.9:
		_kit.tube("metal", [Vector3(x, WALL_FOOT, z - .15), Vector3(x + .02, WALL_FOOT + .62, z - .14)], .016, Color("#5a3a28"), 4)
		x += .8
	for track: float in [-TRACK, TRACK]:
		var at := Z_END - 2.2
		for m: float in [-1.0, 1.0]:
			_box("metal", track + m * GAUGE, 9.0, at, Vector3(.14, 1.0, .14), Color("#a8281c"))
			_kit.beam("metal", Vector3(track + m * GAUGE, 8.6, at + .9), Vector3(track + m * GAUGE, 9.3, at), .1, .1, Vector3.FORWARD, Color("#a8281c"))
		_box("metal", track, 9.32, at, Vector3(1.9, .26, .18), Color("#d8d4c8"))
		_box("led", track, 9.56, at + .02, Vector3(.1, .1, .1), Color(1.0, .12, .08))

# Under the arches ------------------------------------------------------------

func _bay_face(s: float, z0: float) -> Transform3D:
	# Face-local: origin at the bay's left end on the shop-front line, +z out to the pavement.
	if s < 0.0: return Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(-FRONT, 0, z0 + BAY))
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), Vector3(FRONT, 0, z0))

func _fq(part: String, f: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, tint: Color, low := 1.0, high := 1.0, streak := 0.0) -> void:
	_kit.quad(part, f * Vector3(x0, y0, z), f * Vector3(x0, y1, z), f * Vector3(x1, y1, z), f * Vector3(x1, y0, z), tint, low, high, streak, Vector2(_rng.randf() * 5.0, -y0))

func _sheet(part: String, f: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, f * Vector3(x0, y0, z), f * Vector3(x0, y1, z), f * Vector3(x1, y1, z), f * Vector3(x1, y0, z), rect, tint)

func _shell(f: Transform3D, upper: String, tint: Color) -> void:
	# Infill to the tie beam: the tenant's own wall, whatever they could get.
	_fq(upper, f, .5, 6.5, 3.05, 6.56, 0, tint, .8, .5, .8)
	for x: float in [.5, 6.5]:
		_kit.quad("plain", f * Vector3(x, 0, -.3 if x < 3.0 else 0.0), f * Vector3(x, 6.56, -.3 if x < 3.0 else 0.0), f * Vector3(x, 6.56, 0.0 if x < 3.0 else -.3), f * Vector3(x, 0, 0.0 if x < 3.0 else -.3), Color("#57544e"), .6, .6)
	_bar("metal", f, 3.5, 6.59, -.2, Vector3(6.04, .05, .48), Color("#5b5c5a"))
	_wall_clutter(f)
	_kit.quad("plain", f * Vector3(.5, 3.05, 0), f * Vector3(.5, 3.05, -.3), f * Vector3(6.5, 3.05, -.3), f * Vector3(6.5, 3.05, 0), Color("#3a3936"), .5, .5)

func _wall_clutter(f: Transform3D) -> void:
	# What collects on a rented wall: a condenser or two, the run of pipe, a meter, the rain's own marks.
	var at := _rng.randf_range(1.2, 2.8)
	if _rng.randf() < .3: _outdoor_unit(f, at, 3.75, .15)
	if _rng.randf() < .12: _outdoor_unit(f, at + 2.4, 4.7, .15)
	_kit.tube("plain", [f * Vector3(at + .5, 3.75, .05), f * Vector3(at + .9, 3.75, .05), f * Vector3(at + .9, 5.9, .05), f * Vector3(5.9, 6.1, .05)], .024, PVC, 5)
	_bar("metal", f, 5.2, 3.5, .06, Vector3(.26, .36, .12), Color("#a8aba4"))
	var left := _rng.randf_range(.7, 3.2)
	_kit.atlas("decal", f * Vector3(left, 3.1, .012), f * Vector3(left, 6.5, .012), f * Vector3(left + 2.2, 6.5, .012), f * Vector3(left + 2.2, 3.1, .012), _cell(float(_pick([STAIN_DARK, STAIN_FAN, STAIN_RUST])) * 256.0, 0, 256, 512), Color.WHITE, .8)

func _room(f: Transform3D, wall: Color, floor_tint: Color, back := "tiled") -> void:
	var x0 := .5
	var x1 := 6.5
	var d := ROOM_DEEP
	var top := 2.56
	_kit.quad(back, f * Vector3(x0, 0, -d), f * Vector3(x0, top, -d), f * Vector3(x1, top, -d), f * Vector3(x1, 0, -d), wall, .7, .9, 0.0, Vector2(_rng.randf() * 3.0, 0))
	_kit.quad("room", f * Vector3(x0, 0, 0), f * Vector3(x0, top, 0), f * Vector3(x0, top, -d), f * Vector3(x0, 0, -d), wall * .92, .7, .9)
	_kit.quad("room", f * Vector3(x1, 0, -d), f * Vector3(x1, top, -d), f * Vector3(x1, top, 0), f * Vector3(x1, 0, 0), wall * .92, .7, .9)
	_kit.quad("room", f * Vector3(x0, .03, 0), f * Vector3(x0, .03, -d), f * Vector3(x1, .03, -d), f * Vector3(x1, .03, 0), floor_tint, .7, .7)
	_kit.quad("room", f * Vector3(x0, top, -d), f * Vector3(x0, top, 0), f * Vector3(x1, top, 0), f * Vector3(x1, top, -d), wall * .8, .75, .75)
	_bar("metal", f, 3.5, top - .04, -.6, Vector3(1.3, .05, .12), Color("#d7d4c8"))
	_bar("lamp", f, 3.5, top - .075, -.6, Vector3(1.2, .03, .05), Color(.95, .92, .78))

func _fascia(f: Transform3D, cell: int, part := "sign", tint := Color.WHITE) -> void:
	_bar("metal", f, 3.5, 2.8, .05, Vector3(6.0, .5, .1), Color("#2b2a28"), .8, 1.0)
	_sheet(part, f, 1.25, 5.75, 2.59, 3.03, .104, _cell(1120, 1030.0 + float(cell) * 110.0, 928, 100), tint)

func _glazed(f: Transform3D, x0: float, x1: float, sill: float) -> void:
	# Aluminium shop-front in three leaves; the room shows through it.
	var leaf := (x1 - x0) / 3.0
	_fq("front", f, x0, x1, sill, 2.5, -.04, Color.WHITE)
	if sill > .05: _fq("render", f, x0, x1, 0, sill, -.02, Color("#6d6a62"), .7, .9, .6)
	for i: int in range(4):
		_bar("metal", f, x0 + float(i) * leaf, (sill + 2.5) * .5, -.02, Vector3(.05, 2.5 - sill, .05), ALUMINIUM)
	_bar("metal", f, (x0 + x1) * .5, 2.5, -.02, Vector3(x1 - x0, .06, .05), ALUMINIUM)
	_bar("metal", f, (x0 + x1) * .5, sill, -.02, Vector3(x1 - x0, .05, .05), ALUMINIUM)

func _shutter(f: Transform3D, x0: float, x1: float, down: float, tint: Color, tag: int) -> void:
	# Roller shutter, down, or stopped at the height of whoever opened up this morning.
	_fq("shutter", f, x0, x1, down, 2.5, .01, tint, .85, .75, .75)
	_bar("metal", f, (x0 + x1) * .5, 2.54, .06, Vector3(x1 - x0 + .04, .2, .16), tint.darkened(.25))
	_bar("metal", f, (x0 + x1) * .5, down + .02, .03, Vector3(x1 - x0, .05, .05), Color("#3a3a38"))
	for x: float in [x0, x1]:
		_bar("metal", f, x, 1.26, .02, Vector3(.07, 2.52, .05), Color("#4f504e"))
	if tag >= 0:
		_sheet("decal", f, x0 + 1.1, minf(x0 + 3.0, x1 - .2), .8, 1.25, .02, _cell(1120.0 + float(tag % 2) * 60.0, 1810.0 + float(tag) * 76.0, 440, 100))

func _awning(f: Transform3D, x0: float, x1: float, tint: Color, strong: Color) -> void:
	var stripes := int((x1 - x0) / .46)
	for i: int in range(stripes):
		var a := lerpf(x0, x1, float(i) / float(stripes))
		var b := lerpf(x0, x1, float(i + 1) / float(stripes))
		var look := tint if i % 2 == 0 else strong
		_kit.quad("cloth", f * Vector3(a, 2.26, .62), f * Vector3(a, 2.58, .06), f * Vector3(b, 2.58, .06), f * Vector3(b, 2.26, .62), look, .95, 1.0)
		_fq("cloth", f, a, b, 2.14, 2.26, .62, look * .9, .9, 1.0)

func _tenant(s: float, z0: float, kind: String) -> void:
	var f := _bay_face(s, z0)
	match kind:
		"bikes": _bike_bay(f, z0)
		"cabinets": _cabinets(f, s, z0)
		"vending": _vending_bay(f, z0)
		"shutter", "tenant":
			_shell(f, "iron" if int(z0) % 2 == 0 else "render", Color("#d8d4c6"))
			_fq("plain", f, .5, 6.5, 0, .1, .02, Color("#3a3834"), .7, .8)
			var tone := [Color("#c8c9c2"), Color("#a8bcb2"), Color("#d0c4ae"), Color("#b4b8c2")][int(absf(z0)) % 4] as Color
			_shutter(f, .55, 6.45, .02, tone, int(absf(z0)) % 3)
			if kind == "tenant": _fascia(f, 6, "board", Color(.85, .83, .78))
			else: _fascia(f, 4 if z0 < 0.0 else 5, "board", Color(.42, .42, .42))
		"yakitori": _yakitori(f, s, z0)
		"keys": _glass_shop(f, 1, Color("#d8dcd6"), z0)
		"clothes": _clothes(f, z0)
		"coffee": _coffee(f, s, z0)
		"tako": _tako(f, s, z0)
		"cycle": _cycle(f, s, z0)

func _yakitori(f: Transform3D, s: float, z0: float) -> void:
	# 立ち呑み: a hatch and a counter, the grill smoke going straight up the wall.
	_shell(f, "render", Color("#8c8474"))
	_room(f, Color("#c8a878"), Color("#4a453e"), "wood")
	_fascia(f, 0)
	_bar("wood", f, 3.5, .5, -.08, Vector3(5.9, 1.0, .18), Color("#8a6a4a"), .8, 1.0)
	_bar("wood", f, 3.5, 1.04, -.05, Vector3(6.0, .06, .42), Color("#c49a68"))
	_bottle_shelf(f, 2.6, 6.3, 1.72)
	_bottle_shelf(f, 2.6, 6.3, 1.34)
	_sheet("shelf", f, 2.8, 4.8, 2.06, 2.44, -ROOM_DEEP + .02, _cell(820, 1610, 280, 180))
	for i: int in range(9):
		var stick := f * Vector3(1.05 + float(i) * .13, 1.07, -.7)
		_kit.tube("plain", [stick, stick + f.basis.z * -.3], .006, Color("#d9c49a"), 3)
		_kit.tube("plain", [stick + f.basis.z * -.08, stick + f.basis.z * -.24], .018, Color("#7a4a26"), 4)
	_bar("metal", f, 1.6, .98, -.85, Vector3(1.3, .08, .34), Color("#2a2826"))
	_bar("lamp", f, 1.6, 1.03, -.85, Vector3(1.1, .02, .2), Color(1.0, .4, .14))
	_bar("metal", f, 1.6, 2.32, -.8, Vector3(1.5, .4, .6), Color("#6e6e68"))
	var drops := 4
	var rect := _cell(0, 1440, 800, 240)
	for i: int in range(drops):
		var a := 1.7 + float(i) * .72
		var cut := rect
		cut.size.x *= .25
		cut.position.x += cut.size.x * float(i)
		_kit.atlas("cloth", f * Vector3(a, 1.9, .06), f * Vector3(a, 2.52, .02), f * Vector3(a + .69, 2.52, .02), f * Vector3(a + .69, 1.9, .06), cut, Color.WHITE, .9, .2)
		_kit.atlas("cloth", f * Vector3(a + .69, 1.9, .05), f * Vector3(a + .69, 2.52, .01), f * Vector3(a, 2.52, .01), f * Vector3(a, 1.9, .05), cut, Color(.4, .4, .45), .7)
	for x: float in [.95, 6.05]:
		_paper_lantern(f * Vector3(x, 2.0, .24))
	_sheet("board", f, .55, 1.0, .1, .9, .1, _cell(820, 1800, 280, 240))
	_omni("Stand%d" % int(z0), f * Vector3(3.5, 2.2, .6), Color(1.0, .7, .42), .9, 5.2)

func _bottle_shelf(f: Transform3D, x0: float, x1: float, y: float) -> void:
	# A real plank with real bottles: shochu, hoppy, the good soy.
	_bar("wood", f, (x0 + x1) * .5, y, -ROOM_DEEP + .1, Vector3(x1 - x0, .03, .2), Color("#6b4a30"))
	var tones: Array[Color] = [Color("#2d4a2f"), Color("#5a3016"), Color("#d8d2c0"), Color("#1f3050"), Color("#7a2a1a")]
	var x := x0 + .1
	var i := 0
	while x < x1 - .1:
		var tall := .2 + float((i * 7) % 5) * .018
		_kit.lathe("room", f * Vector3(x, y + .015, -ROOM_DEEP + .1), [Vector2(.045, 0), Vector2(.045, tall), Vector2(.018, tall + .1)], tones[i % 5], 5)
		x += _rng.randf_range(.16, .3)
		i += 1

func _paper_lantern(at: Vector3) -> void:
	var profile: Array[Vector2] = [Vector2(.09, -.24), Vector2(.15, -.17), Vector2(.18, -.07), Vector2(.19, 0), Vector2(.18, .07), Vector2(.15, .17), Vector2(.09, .25)]
	_kit.lathe("lantern", at, profile, Color.WHITE, 10, _cell(820, 1440, 280, 160))
	_kit.tube("metal", [at + Vector3.UP * .25, at + Vector3.UP * .5], .006, Color("#1a1a1a"), 3)

func _glass_shop(f: Transform3D, cell: int, wall: Color, z0: float) -> void:
	# 靴修理・合鍵: a key board, a last, a man who has been here since the Heisei era.
	_shell(f, "iron", Color("#d0dade"))
	_room(f, wall.darkened(.28), Color("#5f5c55"))
	_fascia(f, cell)
	_glazed(f, .55, 6.45, .62)
	_bar("wood", f, 3.0, .86, -.72, Vector3(3.6, .05, .5), Color("#a8865c"))
	_bar("metal", f, 4.6, 1.5, -ROOM_DEEP + .04, Vector3(1.5, 1.0, .03), Color("#8f8a7c"))
	for i: int in range(18):
		_bar("metal", f, 3.95 + float(i % 6) * .25, 1.2 + float(i / 6) * .3, -ROOM_DEEP + .07, Vector3(.05, .14, .012), Color("#c9b878"))
	_bottle_shelf(f, .8, 2.6, 1.5)
	_status(f, 6.2, 1.5, .03, CYAN)

func _clothes(f: Transform3D, z0: float) -> void:
	# 古着: rails right up to the glass, the door propped by a mannequin's leg.
	_shell(f, "render", Color("#7b7486"))
	_room(f, Color("#a88a96"), Color("#44403c"))
	_fascia(f, 5)
	_glazed(f, .55, 6.45, .05)
	_kit.tube("metal", [f * Vector3(.8, 2.0, -.52), f * Vector3(6.2, 2.0, -.52)], .014, Color("#c9ccce"), 4)
	var colours: Array[Color] = [Color("#7a3b3b"), Color("#2f4f6e"), Color("#c9a24a"), Color("#3f6a4a"), Color("#d9d2c0"), Color("#50405e")]
	var x := .95
	var i := 0
	while x < 6.1:
		var wide := _rng.randf_range(.12, .2)
		var long := _rng.randf_range(.7, 1.15)
		_bar("room", f, x, 2.0 - long * .5, -.52, Vector3(wide, long, .44), colours[i % 6].darkened(_rng.randf() * .2))
		x += wide + .06
		i += 1

func _coffee(f: Transform3D, s: float, z0: float) -> void:
	# A coffee hatch: dark timber, one machine, a shelf of tins, a bench of nothing.
	_shell(f, "iron", Color("#b8a490"))
	_room(f, Color("#9a7a5c"), Color("#3a3632"), "wood")
	_fascia(f, 3)
	_fq("wood", f, .55, 2.1, 0, 2.5, -.02, Color("#5a4230"), .8, .9)
	_fq("wood", f, 5.0, 6.45, 0, 2.5, -.02, Color("#5a4230"), .8, .9)
	_bar("wood", f, 3.55, .52, -.06, Vector3(2.9, 1.04, .16), Color("#5a4230"), .8, 1.0)
	_bar("wood", f, 3.55, 1.07, -.02, Vector3(3.0, .05, .36), Color("#b8946c"))
	_bar("metal", f, 3.0, 1.32, -.8, Vector3(.7, .46, .44), Color("#b8bcbc"))
	_bottle_shelf(f, 2.2, 4.9, 1.8)
	_kit.tube("metal", [f * Vector3(3.0, 1.1, -.8), f * Vector3(3.0, 1.66, -.8)], .02, Color("#c9ccce"), 5)
	_kit.lathe("metal", f * Vector3(3.5, 1.1, -.7), [Vector2(.06, 0), Vector2(.09, .12), Vector2(.05, .2), Vector2(.02, .22)], Color("#c8ccce"), 8)
	_sheet("board", f, 1.0, 1.55, .3, 1.1, .01, _cell(820, 1800, 280, 240))
	_omni("Coffee%d" % int(z0), f * Vector3(3.5, 2.3, .5), Color(1.0, .78, .55), .55, 4.5)

func _tako(f: Transform3D, s: float, z0: float) -> void:
	# たこ八: the griddle in the window, striped awning, and an octopus doing the selling.
	_shell(f, "render", Color("#a89478"))
	_room(f, Color("#c8b894"), Color("#55504a"))
	_fascia(f, 2)
	_bar("wood", f, 3.5, .5, -.06, Vector3(5.9, 1.0, .16), Color("#e0863a"), .8, 1.0)
	_bar("metal", f, 3.5, 1.04, -.04, Vector3(6.0, .06, .36), Color("#b8bcbc"))
	_bar("metal", f, 2.4, 1.0, -.62, Vector3(1.6, .08, .6), Color("#2a2826"))
	for i: int in range(12):
		_kit.disc("plain", f * Vector3(1.75 + float(i % 6) * .26, 1.045, -.5 - float(i / 6) * .24), f.basis.x, -f.basis.z, .09, Color("#c98a38"))
	_awning(f, .7, 6.3, Color("#e9e2d2"), Color("#d8641c"))
	_bottle_shelf(f, 3.8, 6.2, 1.6)
	_omni("Tako", f * Vector3(3.5, 2.1, .7), Color(1.0, .74, .46), .7, 4.8)

func _cycle(f: Transform3D, s: float, z0: float) -> void:
	# 丸輪: shutter stopped at head height, bikes inside the line, tyres on the wall.
	_shell(f, "iron", Color("#c4d2c8"))
	_room(f, Color("#969c92"), Color("#4a4640"))
	_fascia(f, 4)
	_shutter(f, .55, 3.0, .02, Color("#b4c2b6"), -1)
	_shutter(f, 3.0, 6.45, 2.1, Color("#b4c2b6"), -1)
	for i: int in range(3):
		_bike(f * Vector3(3.5 + float(i) * .95, 0, -.6), f.basis.x, [Color("#7a2a22"), Color("#2f5a7e"), Color("#3a3a3e")][i])
	for i: int in range(4):
		var centre := f * Vector3(3.5 + float(i) * .72, 1.85, -ROOM_DEEP + .05)
		var points: Array[Vector3] = []
		for k: int in range(13):
			var a := TAU * float(k) / 12.0
			points.append(centre + (f.basis.x * cos(a) + Vector3.UP * sin(a)) * .3)
		_kit.tube("plain", points, .018, Color("#191a1b"), 3)

func _vending_bay(f: Transform3D, z0: float) -> void:
	# Two machines against a mesh screen, with the crate of empties nobody claims.
	_screen(f)
	for i: int in range(2):
		var x := 1.4 + float(i) * 1.1
		_bar("metal", f, x, .92, -.42, Vector3(1.0, 1.84, .7), Color("#c8ccc8"))
		_sheet("sign", f, x - .47, x + .47, .08, 1.8, -.066, _cell(20, 1085, 200, 340))
	_kit.lathe("plain", f * Vector3(3.3, 0, -.5), [Vector2(.2, 0), Vector2(.24, .62), Vector2(.26, .64), Vector2(.24, .68), Vector2(.09, .72), Vector2(.09, .7)], Color("#3a6a9a"), 10)
	if int(z0) % 2 == 0: _omni("Vending", f * Vector3(1.9, 1.2, .5), Color(.86, .94, 1.0), .4, 3.2)

func _screen(f: Transform3D) -> void:
	# Back of an unlet bay: corrugated sheet on rails, closing off whatever is behind.
	_fq("iron", f, .5, 6.5, 0, 2.6, -.98, Color("#c8ccc4"), .7, .9, .6)
	_bar("metal", f, 3.5, 2.62, -.96, Vector3(6.0, .05, .05), STEEL)
	_bar("metal", f, 3.5, .1, -.96, Vector3(6.0, .05, .05), STEEL)

func _bike_bay(f: Transform3D, z0: float) -> void:
	# 駐輪区画: rail, plate, and bikes nose to tail inside the column line.
	_screen(f)
	_sheet("board", f, 2.9, 4.1, 1.5, 2.04, -.96, _cell(790, 620, 360, 160))
	_kit.tube("metal", [f * Vector3(.7, .62, -.84), f * Vector3(6.3, .62, -.84)], .016, Color("#8f908c"), 4)
	var tints: Array[Color] = [Color("#3a3a3e"), Color("#b8b4a8"), Color("#2f5a7e"), Color("#7a2a22"), Color("#2f4a3a")]
	var count := 2 + int(absf(z0)) % 2
	for i: int in range(count):
		var along := .95 + float(i) * (5.1 / float(count)) + _rng.randf_range(-.08, .08)
		_bike(f * Vector3(along + .72, 0, -.56 - _rng.randf() * .14), f.basis.x, tints[(i + int(absf(z0))) % 5])

func _bike(at: Vector3, along: Vector3, tint: Color) -> void:
	# The kit bicycle, thinned out: there are a lot of these.
	var black := Color("#1b1c1e")
	for t: float in [-.56, .56]:
		var hub := at + along * t + Vector3.UP * .32
		var points: Array[Vector3] = []
		for i: int in range(11):
			var a := TAU * float(i) / 10.0
			points.append(hub + (along * cos(a) + Vector3.UP * sin(a)) * .3)
		_kit.tube("plain", points, .014, black, 3)
	var seat := at + along * -.26 + Vector3.UP * .86
	var bars := at + along * .36 + Vector3.UP * .96
	_kit.tube("plain", [at + along * -.56 + Vector3.UP * .32, seat, bars, at + along * .56 + Vector3.UP * .32], .016, tint, 3)
	_kit.tube("plain", [at + Vector3.UP * .32, bars], .014, tint, 3)
	_kit.tube("plain", [at + Vector3.UP * .32, seat], .014, tint, 3)
	var cross := along.cross(Vector3.UP).normalized() * .24
	_kit.tube("plain", [bars - cross, bars + cross], .012, black, 3)
	_kit.block("plain", Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), seat + Vector3.UP * .03), Vector3(.24, .05, .1), black)

func _cabinets(f: Transform3D, s: float, z0: float) -> void:
	# Signal relay cases and the 2050 edge node beside them, chained to the column.
	_screen(f)
	_bar("metal", f, 1.9, .9, -.62, Vector3(.9, 1.8, .55), Color("#8f968e"))
	_bar("metal", f, 2.95, .75, -.62, Vector3(.7, 1.5, .55), Color("#a2a89e"))
	_bar("plain", f, 2.0, .06, -.72, Vector3(2.4, .12, .7), Color("#54514a"))
	_sheet("board", f, 2.72, 3.18, .9, 1.32, -.34, _cell(600, 620, 180, 165))
	_bar("metal", f, 4.2, .85, -.7, Vector3(.6, 1.5, .44), Color("#2c2f33"))
	_status(f, 4.05, 1.4, -.47, GREEN)
	_status(f, 4.15, 1.4, -.47, CYAN)
	_strip(f * Vector3(3.96, 1.2, -.47), f * Vector3(4.44, 1.2, -.47), CYAN * .7)
	_kit.tube("plain", [f * Vector3(4.2, 1.6, -.8), f * Vector3(4.2, 5.9, -.8), f * Vector3(4.2, 6.5, -.65)], .03, Color("#17181a"), 4)

# 2050 ------------------------------------------------------------------------

func _instruments() -> void:
	# Fibre in an open tray along the east fascia, and strain boxes reporting on the concrete.
	var tray := Color("#6a6d6b")
	for run: Vector2 in _deck_runs:
		var z := run.x + .1
		while z < run.y - .1:
			var end := minf(z + 3.5, run.y - .1)
			_kit.quad("metal", Vector3(5.86, 7.84, end), Vector3(5.6, 7.84, end), Vector3(5.6, 7.84, z), Vector3(5.86, 7.84, z), tray, .7, .7)
			_wall("metal", Vector3(1, 0, 0), 5.86, z, end, 7.84, 7.95, tray)
			_wall("metal", Vector3(1, 0, 0), 5.6, z, end, 7.84, 7.95, tray)
			if int(z) % 2 == 0: _box("metal", 5.72, 7.81, z, Vector3(.32, .05, .05), Color("#3f4140"))
			z = end
	_kit.tube("plain", [Vector3(5.76, 7.9, -147.0), Vector3(5.76, 7.9, 150.0)], .022, Color("#17181a"), 3)
	_kit.tube("plain", [Vector3(5.67, 7.9, -147.0), Vector3(5.67, 7.9, 150.0)], .014, Color("#d9681c"), 3)
	for z: float in [-96.0, -32.0, 25.0, 96.0]:
		var s := 1.0 if int(z) % 2 == 0 else -1.0
		var x := s * (COLUMN_X - .46)
		_box("metal", x, 4.2, z, Vector3(.06, .36, .26), Color("#c8cbc6"))
		_box("led", x - s * .036, 4.33, z + .08, Vector3(.012, .03, .03), GREEN)
		_kit.tube("plain", [Vector3(x, 4.38, z), Vector3(x, 6.4, z)], .012, Color("#17181a"), 3)
		_kit.tube("metal", [Vector3(x, 4.38, z - .1), Vector3(x, 4.7, z - .1)], .004, Color("#222222"), 3)
	for i: int in range(CROSSINGS.size()):
		# Crack gauge and a camera at each crossing, on the girder's bottom flange.
		var c := CROSSINGS[i]
		var s := 1.0 if i % 2 == 0 else -1.0
		_box("metal", s * 5.5, 7.62, c + 5.4, Vector3(.08, .16, .3), Color("#c8cbc6"))
		_box("led", s * 5.545, 7.66, c + 5.3, Vector3(.012, .025, .025), AMBER)
		_camera(Vector3(s * 5.3, 7.0, c - 8.0))
