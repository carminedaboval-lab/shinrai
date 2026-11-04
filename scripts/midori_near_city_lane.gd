extends "res://scripts/midori_near_city_handmade.gd"
## 星屑横丁: the slot beside the pachinko hall opened into a real lane. Low wooden stalls along one
## side, the blind backs of the next block along the other, lanterns and stacked signs for the
## first twenty metres, then the quiet end with its shutters, bicycles, pots and meters.
## Local origin is the stalls' building line at the main street; +x crosses the lane, -z goes in.
const ATLAS := "res://assets/shinrai/near_city/lane_atlas.png"
const ROAD_ALBEDO := "res://assets/environment/roads/shinrai_road/textures/SHINRAI_Road_FineAggregate_BaseColor_2K.png"
const CUT_SHADER := preload("res://scripts/midori_near_city_cutout.gdshader")
const STREET_SHADER := preload("res://scripts/midori_tokyo_road.gdshader")
const ROAD_TEXTURES := "res://assets/environment/roads/shinrai_road/textures/"
const WIND_INCLUDE := "res://scripts/midori_wind.gdshaderinc"
const WIND_DIR := Vector3(.94, 0, .34) # Matches midori_wind.gdshaderinc.
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
var _detail := RandomNumberGenerator.new()
var _flicker_light: OmniLight3D
var _plumes: Array[GPUParticles3D] = []
var _pendant_spots: Array[Vector3] = []

func _ready() -> void:
	position.x += SHIFT
	_rng.seed = 1950
	# New detail draws from its own stream, so the lane's original layout never shifts.
	_detail.seed = 2611
	_build_looks()
	_breeze_looks()
	_ground()
	for row: Array in UNITS:
		_unit(row)
	_street_end()
	_gate()
	_opposite()
	_overhead()
	_autumn()
	_lane_life()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "led", "neon", "leaf", "room", "sign", "poster", "goods", "paper", "cloth", "cable", "cut", "road", "apron", "flicker"])
	_kit = null
	_fit_street()
	for u: float in [1.8, 8.6, 15.0, 22.0]:
		_omni("Stall%d" % int(u), Vector3(.9, 2.3, -u), SODIUM, 1.5, 6.5)
	_omni("DyingTube", _face(UNITS[8]) * Vector3(30.6, 2.3, .7), Color(.82, .9, 1.0), .9, 4.5)
	_flicker_light = _lamps[_lamps.size() - 1] as OmniLight3D
	# Each enamel pendant really lights the lane below it.
	for i: int in range(_pendant_spots.size()):
		_omni("Pendant%d" % i, _pendant_spots[i], Color(1.0, .78, .5), .9, 5.5)
	for lamp: Light3D in _lamps:
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 55.0
		lamp.distance_fade_length = 15.0
		lamp.light_specular = .3
	_plumes.append(_plume("GrillSmoke", _face(UNITS[0]) * Vector3(2.4, 1.02, .46), 80, 5.0, .38, Color(.8, .8, .82, .15), .5))
	_plumes.append(_plume("StockpotSteam", _face(UNITS[3]) * Vector3(12.75, 1.3, -2.77), 20, 1.8, .55, Color(1, 1, 1, .26), .45))

func set_night_mode(value: bool) -> void:
	super(value)
	# The breeze drops after dark, as it does in the city.
	for look: ShaderMaterial in _looks.values():
		look.set_shader_parameter("wind_strength", .45 if value else 1.0)

func _process(_delta: float) -> void:
	# The quiet end's last fluorescent tube, matching its shader's stutter.
	if _flicker_light == null or not _flicker_light.visible: return
	var t := float(Time.get_ticks_msec()) / 1000.0
	var slot := floorf(t * 6.0)
	var bad := 1.0 if fposmod(sin(slot * 12.9898) * 43758.5453, 1.0) > .86 else 0.0
	_flicker_light.light_energy = .9 * (1.0 - bad * (.75 * (.5 + .5 * sin(t * 113.0)) + .2))

func _face(row: Array) -> Transform3D:
	return Transform3D(_row.basis, _row * Vector3(0, 0, float(row[2])))

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
	# Ceiling batten: a steel channel with one warm tube under it.
	var run := u1 - u0 - .6
	var centre := (u0 + u1) * .5
	_bar("metal", f, centre, head - .022, far * .5, Vector3(run, .035, .09), Color("#e6e4dc"))
	for end: float in [-run * .5 + .02, run * .5 - .02]:
		_bar("metal", f, centre + end, head - .05, far * .5, Vector3(.025, .03, .04), Color("#d2d0c8"))
	_kit.tube("lamp", [f * Vector3(centre - run * .5 + .035, head - .055, far * .5), f * Vector3(centre + run * .5 - .035, head - .055, far * .5)], .013, Color(1.0, .84, .6), 8)
	# Smoke-dark joists under the ceiling, a wainscot rail, and the conduit to the lamp.
	for k: int in range(3):
		var z := far * (float(k) + .5) / 3.0
		_bar("wood", f, (u0 + u1) * .5, head - .06, z, Vector3(u1 - u0, .1, .09), Color("#241810"))
	_bar("wood", f, (u0 + u1) * .5, .92, far + .015, Vector3(u1 - u0, .05, .03), Color("#2a1c12"))
	_kit.tube("plain", [f * Vector3(u0 + .05, head - .03, far + .1), f * Vector3((u0 + u1) * .5, head - .03, far + .1), f * Vector3((u0 + u1) * .5, head - .03, far * .5)], .01, Color("#d8d6cc"), 4)

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
	# Real shelves of bottles over a drinks fridge, where a printed shelf used to hang.
	_back_bar(f, u0 + .3, mid, far, int(row[6]))
	_panel("goods", f, mid + .05, u1 - .3, 1.42, 2.3, far + .02, _cell(510, 1520, 480, 200))
	_kitchen(f, mid + .05, u1 - .3, far, int(row[6]))
	# Counter across the width, and the stools people lean back from into the lane.
	var counter := -1.0
	_bar("wood", f, mid, .5, counter, Vector3(u1 - u0 - .3, 1.0, .1), Color("#5a3a22"))
	_bar("wood", f, mid, 1.03, counter, Vector3(u1 - u0 - .24, .06, .46), Color("#8a5a32"))
	# Tongue-and-groove boards down the customer side, scuffed dark where knees rest.
	var board := u0 + .3
	while board < u1 - .3:
		_bar("plain", f, board, .5, counter + .052, Vector3(.012, .96, .004), Color("#2e1e12"))
		board += .14
	_bar("plain", f, mid, .55, counter + .053, Vector3(u1 - u0 - .32, .16, .003), Color("#3a2618"))
	_bar("metal", f, mid, .16, counter + .2, Vector3(u1 - u0 - .4, .03, .03), Color("#9a9c98"))
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
	# Each strip is cut in rows so it curves away from its pole and can move in the breeze.
	var strips := 3
	var rows := 4
	var run := (x1 - x0) / float(strips)
	var start := _mark("cloth")
	for i: int in range(strips):
		var left := x0 + float(i) * run + .015
		var right := x0 + float(i + 1) * run - .015
		var swing := .05 + _rng.randf() * .07
		for r: int in range(rows):
			var t0 := float(r) / float(rows)
			var t1 := float(r + 1) / float(rows)
			var y0 := 2.42 - .58 * t0
			var y1 := 2.42 - .58 * t1
			var z0 := .05 + swing * t0 * t0
			var z1 := .05 + swing * t1 * t1
			var cut := Rect2(rect.position + Vector2(rect.size.x * float(i) / float(strips), rect.size.y * t0), Vector2(rect.size.x / float(strips), rect.size.y / float(rows)))
			_kit.atlas("cloth", f * Vector3(left, y1, z1), f * Vector3(left, y0, z0), f * Vector3(right, y0, z0), f * Vector3(right, y1, z1), cut)
			_kit.atlas("cloth", f * Vector3(right, y1, z1), f * Vector3(right, y0, z0), f * Vector3(left, y0, z0), f * Vector3(left, y1, z1), cut, Color(.6, .6, .6))
	_sway("cloth", start, 2.42, .58, .07)
	# A bamboo pole carries the cloth, its ends lashed to the frame.
	_kit.tube("wood", [f * Vector3(x0 - .08, 2.44, .05), f * Vector3(x1 + .08, 2.44, .05)], .017, Color("#b49a5e"), 6)

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
	# Bracket lamp: a frosted pink glass cylinder between a cap and a base.
	var dark := Color("#2a2228")
	_bar("metal", f, x, y + .02, .025, Vector3(.07, .16, .05), dark)
	_kit.tube("metal", [f * Vector3(x, y + .06, .05), f * Vector3(x, y + .06, .16)], .012, dark, 6)
	var at := f * Vector3(x, y - .1, .18)
	_kit.lathe("metal", at + Vector3.DOWN * .02, [Vector2(.0, 0), Vector2(.05, .005), Vector2(.055, .02)], dark, 14)
	_kit.lathe("lamp", at, [Vector2(.05, 0), Vector2(.058, .04), Vector2(.058, .18), Vector2(.05, .22)], Color(1.0, .5, .78), 14)
	_kit.lathe("metal", at + Vector3.UP * .22, [Vector2(.055, 0), Vector2(.05, .02), Vector2(.0, .03)], dark, 14)

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
	# It hangs from one hook, so the whole thing swings a little about the top.
	var starts := {"paper":_mark("paper"), "plain":_mark("plain"), "cable":_mark("cable")}
	_lantern_body(top, rect, wide, tall)
	for part: String in starts:
		_sway(part, starts[part], top.y, tall + .1, .06)

func _lantern_body(top: Vector3, rect: Rect2, wide: float, tall: float) -> void:
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
	# Chrome counter stool: weighted foot, a footrest ring, and a buttoned vinyl seat
	# split at the seam where everybody sits.
	var chrome := Color("#b4b7b6")
	_kit.lathe("metal", at, [Vector2(.16, 0), Vector2(.16, .012), Vector2(.05, .045), Vector2(.026, .06), Vector2(.024, .44)], chrome, 14)
	var ring: Array[Vector3] = []
	for k: int in range(17):
		var a := TAU * float(k) / 16.0
		ring.append(at + Vector3(cos(a) * .13, .2, sin(a) * .13))
	_kit.tube("metal", ring, .009, chrome, 5)
	for k: int in range(3):
		var a := TAU * float(k) / 3.0
		_kit.tube("metal", [at + Vector3(0, .24, 0), at + Vector3(cos(a) * .13, .2, sin(a) * .13)], .007, chrome, 4)
	_kit.lathe("metal", at + Vector3.UP * .44, [Vector2(.04, 0), Vector2(.15, .012), Vector2(.15, .03)], chrome, 16)
	var vinyl := Color("#b01414").darkened(_detail.randf() * .12)
	_kit.lathe("plain", at + Vector3.UP * .47, [Vector2(.16, 0), Vector2(.172, .02), Vector2(.17, .055), Vector2(.12, .078), Vector2(0, .082)], vinyl, 18)
	if _detail.randf() < .3:
		# Gaffer tape over the split.
		_kit.block("plain", Transform3D(Basis(Vector3.UP, _detail.randf() * TAU), at + Vector3.UP * .552), Vector3(.12, .004, .05), Color("#2a2a2c"))

func _crates(f: Transform3D, x: float, z: float, count: int) -> void:
	# Returnable beer crates: open plastic with hand slots, the top one still full of bottles.
	for i: int in range(count):
		var y := .15 + float(i) * .3
		var red := Color("#a81616").darkened(float(i) * .04)
		var top := i == count - 1
		if top:
			_bar("plain", f, x, y - .135, z, Vector3(.46, .02, .34), red)
			for side: float in [-1.0, 1.0]:
				_bar("plain", f, x + side * .22, y, z, Vector3(.02, .29, .34), red)
				_bar("plain", f, x, y, z + side * .16, Vector3(.46, .29, .02), red)
			_bar("plain", f, x, y - .02, z, Vector3(.42, .25, .3), Color("#3a0a08"), .5, .4)
			for col: int in range(4):
				for line: int in range(3):
					var at := f * Vector3(x - .165 + float(col) * .11, y - .125, z - .1 + float(line) * .1)
					_kit.lathe("bottle", at, [Vector2(.032, 0), Vector2(.034, .17), Vector2(.014, .23), Vector2(.012, .3)], Color("#4a2410"), 8)
					_kit.lathe("metal", at + Vector3.UP * .3, [Vector2(.015, 0), Vector2(.015, .01), Vector2(0, .012)], Color("#c9a24a"), 8)
		else:
			_bar("plain", f, x, y, z, Vector3(.46, .29, .34), red)
		_panel("goods", f, x - .22, x + .22, y - .13, y + .13, z + .174, _cell(520, 1740, 160, 100))
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
	_vending(b, 4.15, true)
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

func _vending(f: Transform3D, x: float, bin := false) -> void:
	# Drinks machine: a lit window of dummy cans proud of the cabinet, a button under
	# each, the payment panel, the drop slot, and its feet levelled on shims.
	var cabinet := Color("#c8ccce")
	_bar("metal", f, x, .97, .38, Vector3(.9, 1.86, .72), cabinet)
	_bar("metal", f, x, 1.94, .38, Vector3(.92, .06, .74), cabinet.darkened(.15))
	_bar("led", f, x, 1.8, .748, Vector3(.82, .12, .006), Color("#d02a22"))
	_bar("metal", f, x, 1.32, .76, Vector3(.84, .74, .04), Color("#8e9294"))
	_panel("goods", f, x - .4, x + .4, .97, 1.67, .782, _cell(1510, 1580, 225, 215))
	for col: int in range(6):
		_bar("led", f, x - .33 + float(col) * .132, .9, .76, Vector3(.07, .03, .02), Color(.3, .9, .5))
	_bar("plain", f, x + .24, .62, .752, Vector3(.24, .4, .012), Color("#1f2326"))
	_bar("led", f, x + .24, .74, .76, Vector3(.12, .07, .006), Color(.35, .75, 1.0))
	_bar("metal", f, x + .24, .52, .76, Vector3(.05, .1, .015), Color("#c0c2c0"))
	_bar("plain", f, x - .12, .26, .74, Vector3(.5, .2, .03), Color("#15181a"))
	_bar("metal", f, x - .12, .37, .752, Vector3(.52, .02, .02), cabinet.darkened(.2))
	for side: float in [-.38, .38]:
		_bar("plain", f, x + side, .02, .38, Vector3(.08, .04, .6), Color("#3a3c3e"))
	# The recycling bin that always stands beside one.
	if not bin: return
	_kit.lathe("plain", f * Vector3(x + .62, 0, .5), [Vector2(.17, 0), Vector2(.19, .7), Vector2(.2, .72)], Color("#2c5c94"), 12)
	_kit.disc("plain", f * Vector3(x + .62, .73, .5), f.basis.x, -f.basis.z, .2, Color("#e8e6df"))

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
	var start := _mark("cable")
	_kit.tube("cable", points, .011, Color("#15161a"), 3)
	# Fixed at both walls, free to bow in the middle.
	var target: Dictionary = _kit._part("cable")
	var vertices: PackedVector3Array = target.v
	var weights: PackedVector2Array = target.u2
	var span := b - a
	for i: int in range(start, vertices.size()):
		var s := clampf((vertices[i] - a).dot(span) / span.length_squared(), 0.0, 1.0)
		weights[i] = Vector2(weights[i].x, .05 * 4.0 * s * (1.0 - s) * (1.0 + drop * 2.0))
	target.u2 = weights

func _pendant(at: Vector3) -> void:
	# Green enamel over a bare bulb, older than the lane's name. It hangs from the
	# wire, so it rides the wire's swing and adds its own.
	var starts := {"cable":_mark("cable"), "plain":_mark("plain"), "lamp":_mark("lamp"), "led":_mark("led")}
	_pendant_body(at)
	for part: String in starts:
		_sway(part, starts[part], at.y + .2, .7, .06)

func _pendant_body(at: Vector3) -> void:
	# Open underneath: the white enamel inside catches the bulb, the green outside
	# stays dark, and the rim is rolled over a wire bead.
	var low := at + Vector3.DOWN * .42
	_kit.tube("cable", [at, low + Vector3.UP * .2], .008, Color("#15161a"), 3)
	_kit.lathe("plain", low + Vector3.UP * .14, [Vector2(.026, 0), Vector2(.026, .07), Vector2(.012, .085)], Color("#1a1b1c"), 10)
	_kit.lathe("plain", low, [Vector2(.245, -.012), Vector2(.24, .015), Vector2(.19, .065), Vector2(.08, .145), Vector2(.032, .17)], Color("#2f5e4a"), 18)
	_kit.lathe("led", low, [Vector2(.03, .16), Vector2(.075, .135), Vector2(.18, .06), Vector2(.232, .012)], Color(1.0, .92, .78), 18)
	var bead: Array[Vector3] = []
	for k: int in range(19):
		var a := TAU * float(k) / 18.0
		bead.append(low + Vector3(cos(a) * .243, -.008, sin(a) * .243))
	_kit.tube("plain", bead, .007, Color("#e6e2d4"), 4)
	_ball(low + Vector3.UP * .07, Vector3(.042, .052, .042), Color(1.0, .86, .62), "lamp", 8, 12)
	_pendant_spots.append(low + Vector3.DOWN * .15)

func _autumn() -> void:
	# Plastic maple wired overhead, clear of the signs: it has never once been taken down.
	var u := 3.0
	while u < 22.0:
		_bunch(Vector3(.2 + _rng.randf() * .5, 5.0 + _rng.randf() * .4, -u))
		_bunch(Vector3(1.4 + _rng.randf() * 1.0, 5.1 + _rng.randf() * .5, -u - .5))
		u += _rng.randf_range(1.3, 2.2)

func _bunch(at: Vector3) -> void:
	var size := _rng.randf_range(.8, 1.2)
	var start := _mark("cut")
	_bunch_body(at, size)
	_sway("cut", start, at.y + size * .42, size * .84, .07)

func _bunch_body(at: Vector3, size: float) -> void:
	for turn: float in [_rng.randf() * PI, _rng.randf() * PI + PI * .5]:
		var side := Vector3(cos(turn), 0, sin(turn)) * size * .5
		var up := Vector3.UP * size * .42
		var rect := _cell(1030.0 + _rng.randf() * 50.0, 1770.0 + _rng.randf() * 30.0, 200, 180)
		_kit.atlas("cut", at - side - up, at - side + up, at + side + up, at + side - up, rect)

# ------------------------------------------------------------- lane life
# Everything below came after the lane was first built: what moves, what fills
# the stalls, and the floor. New randomness uses _detail, never _rng.

func _mark(part: String) -> int:
	return (_kit._part(part).v as PackedVector3Array).size()

## Lets every vertex of `part` added since `from` move in the breeze, more the
## further it hangs below `pivot_y`; `amount` is metres at full gust.
func _sway(part: String, from: int, pivot_y: float, reach: float, amount: float) -> void:
	var target: Dictionary = _kit._part(part)
	var vertices: PackedVector3Array = target.v
	var weights: PackedVector2Array = target.u2
	for i: int in range(from, vertices.size()):
		var drop := clampf((pivot_y - vertices[i].y) / reach, 0.0, 1.0)
		weights[i] = Vector2(weights[i].x, amount * drop)
	target.u2 = weights

## Copies of the shared building shaders that move any vertex whose UV2.y is
## set. Built from the live shader text, so the originals stay untouched; if
## their text ever changes past recognition the lane simply keeps still.
func _breeze_looks() -> void:
	var windy := _windy(SHADER, true)
	var windy_cut := _windy(CUT_SHADER, false)
	for key: String in _looks:
		var look := _looks[key] as ShaderMaterial
		if look.shader == SHADER and windy != null: look.shader = windy
		elif look.shader == CUT_SHADER and windy_cut != null: look.shader = windy_cut
	var dying := (_looks.lamp as ShaderMaterial).duplicate() as ShaderMaterial
	dying.set_shader_parameter("flicker", 1.0)
	_looks.flicker = dying
	# The lane floor takes the street's asphalt: aggregate, wear, joints and patches.
	var street := ShaderMaterial.new()
	street.shader = STREET_SHADER
	street.set_shader_parameter("aggregate_albedo", load(ROAD_TEXTURES + "SHINRAI_Road_FineAggregate_BaseColor_2K.png"))
	street.set_shader_parameter("aggregate_normal", load(ROAD_TEXTURES + "SHINRAI_Road_RealisticDry_NormalGL_2K.png"))
	street.set_shader_parameter("aggregate_orm", load(ROAD_TEXTURES + "SHINRAI_Road_RealisticDry_ORM_2K.png"))
	street.set_shader_parameter("asphalt_color", Color(.34, .335, .325))
	_looks.road = street

static func _windy(source: Shader, has_vertex: bool) -> Shader:
	var code := source.code
	var first_uniform := code.find("uniform ")
	if not code.begins_with("shader_type") or first_uniform < 0: return null
	var push := "if (UV2.y > 0.0) { VERTEX += inverse(mat3(MODEL_MATRIX)) * (midori_wind((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, TIME) * UV2.y); }"
	if has_vertex:
		var anchor := "world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;"
		if not code.contains(anchor): return null
		code = code.replace(anchor, push + "\n\t" + anchor)
		var glow_line := "EMISSION += face * COLOR.rgb * mix(day_glow, glow, night);"
		if code.contains(glow_line):
			code = code.replace(glow_line, glow_line + "\n\tif (flicker > 0.0) { float slot = floor(TIME * 6.0); float bad = step(0.86, fract(sin(slot * 12.9898) * 43758.5453)); EMISSION *= 1.0 - bad * (0.75 * (0.5 + 0.5 * sin(TIME * 113.0)) + 0.2); }")
	else:
		var anchor := "void fragment(){"
		if not code.contains(anchor): return null
		code = code.replace(anchor, "void vertex(){ " + push + " }\n" + anchor)
	code = code.insert(code.find("uniform "), "#include \"" + WIND_INCLUDE + "\"\nuniform float flicker = 0.0;\n")
	var shader := Shader.new()
	shader.code = code
	return shader

func _fit_street() -> void:
	var lane_floor := get_node_or_null("Part_road") as MeshInstance3D
	if lane_floor == null or (_looks.road as ShaderMaterial).shader != STREET_SHADER: return
	# The floor runs along -z from the main street: centre, half width and length.
	lane_floor.set_instance_shader_parameter("road_frame", Vector4(1.0, 2.6, DEEP + .2, 0.0))
	lane_floor.set_instance_shader_parameter("road_centre", Vector2(1.235, -(DEEP + .2) * .5))

func _lane_life() -> void:
	for row: Array in UNITS:
		if row[5] == "open":
			_counter_spread(_face(row), float(row[0]), float(row[1]))
	_grill(_face(UNITS[0]), 2.4, .46)
	_dying_tube(_face(UNITS[8]), 30.6)
	_cat(_face(UNITS[8]) * Vector3(31.9, .72, .28), .8)
	_laundry_pole(_face(UNITS[10]), 36.7, 39.7)

## Bottles on two shelves, over a lit drinks fridge with its brewer's header.
func _back_bar(f: Transform3D, x0: float, x1: float, far: float, blade: int) -> void:
	var fridge := minf(.6, (x1 - x0) * .5)
	var fx := x0 + fridge * .5
	var white := Color("#e4e4de")
	_bar("metal", f, fx, .62, far + .28, Vector3(fridge, 1.24, .5), white)
	_bar("metal", f, fx, .66, far + .535, Vector3(fridge - .04, 1.0, .02), Color("#2a2c2e"))
	_panel("goods", f, fx - fridge * .42, fx + fridge * .42, .22, 1.12, far + .548, _cell(1510, 1580, 225, 215))
	_bar("led", f, fx, 1.19, far + .537, Vector3(fridge - .04, .07, .01), Color("#c82a22"))
	_bar("metal", f, fx + fridge * .4, .66, far + .56, Vector3(.02, .38, .03), Color("#c0c2c0"))
	var palette: Array[Color] = [Color("#2e4a1e"), Color("#4a2410"), Color("#1e3a2a"), Color("#d8d2c0"), Color("#1a1a1c"), Color("#6a4a1a"), Color("#3a5a6a")]
	for level: float in [1.5, 1.92]:
		_bar("wood", f, (x0 + x1) * .5, level, far + .12, Vector3(x1 - x0, .03, .22), Color("#4a2e1a"))
		for side: float in [x0 + .08, x1 - .08]:
			_bar("metal", f, side, level - .07, far + .1, Vector3(.02, .12, .18), Color("#3a3c3e"))
		var x := x0 + .07
		while x < x1 - .07:
			var at := f * Vector3(x, level + .015, far + .1 + _detail.randf_range(-.03, .03))
			var tint: Color = palette[_detail.randi_range(0, palette.size() - 1)]
			match _detail.randi_range(0, 3):
				0: # One-sho sake bottle.
					_kit.lathe("bottle", at, [Vector2(.045, 0), Vector2(.047, .26), Vector2(.02, .33), Vector2(.016, .38)], tint, 8)
				1: # Square whisky bottle with its keep-tag.
					_kit.lathe("bottle", at, [Vector2(.04, 0), Vector2(.042, .18), Vector2(.014, .23), Vector2(.013, .27)], Color("#7a4a14"), 4)
					_bar("plain", f, x, level + .12, far + .145, Vector3(.035, .05, .003), Color("#f0ece0"))
				2: # Shochu.
					_kit.lathe("bottle", at, [Vector2(.036, 0), Vector2(.038, .2), Vector2(.015, .26), Vector2(.014, .3)], tint, 8)
				3: # Squat liqueur.
					_kit.lathe("bottle", at, [Vector2(.04, 0), Vector2(.044, .12), Vector2(.016, .17), Vector2(.014, .2)], tint, 8)
			x += _detail.randf_range(.085, .12)
	if blade == 0 or blade == 5:
		_lucky_cat(f * Vector3(x1 - .12, 1.935, far + .12))

## Stainless bench under the menu tags, with what that trade cooks on it.
func _kitchen(f: Transform3D, x0: float, x1: float, far: float, blade: int) -> void:
	var steel := Color("#aeb2b2")
	var cx := (x0 + x1) * .5
	var z := far + .28
	_bar("metal", f, cx, .43, z, Vector3(x1 - x0, .86, .5), steel)
	_bar("metal", f, cx, .875, z, Vector3(x1 - x0 + .02, .03, .52), steel.lightened(.1))
	_bar("plain", f, cx, .08, z + .23, Vector3(x1 - x0 - .04, .14, .04), Color("#2a2c2e"))
	match blade:
		3: # Ramen: the stockpot that never comes off, and the noodle baskets.
			_kit.lathe("metal", f * Vector3(12.75, .89, z), [Vector2(.2, 0), Vector2(.21, .32), Vector2(.22, .34)], Color("#c4c6c4"), 16)
			_kit.lathe("bottle", f * Vector3(12.75, 1.17, z), [Vector2(.2, 0), Vector2(0, .005)], Color("#6a4a24"), 16)
			for k: int in range(3):
				var at := f * Vector3(x0 + .15 + float(k) * .16, .89, z + .05)
				_kit.lathe("metal", at, [Vector2(.06, 0), Vector2(.065, .12)], Color("#8e908e"), 10)
				_kit.tube("wood", [at + Vector3.UP * .12, at + Vector3.UP * .12 + f.basis.z * .3 + Vector3.UP * .08], .008, Color("#7a5a32"), 4)
		1: # Oden: the compartment pan, simmering.
			_bar("metal", f, cx, .97, z, Vector3(minf(.9, x1 - x0 - .1), .16, .42), Color("#b8bab8"))
			_bar("bottle", f, cx, 1.04, z, Vector3(minf(.86, x1 - x0 - .14), .01, .38), Color("#8a5a20"))
			for k: int in range(4):
				_bar("metal", f, cx - .3 + float(k) * .2, 1.0, z, Vector3(.01, .1, .4), Color("#d0d2d0"))
			for k: int in range(7):
				var at := f * Vector3(cx - .35 + _detail.randf() * .7, 1.05, z - .15 + _detail.randf() * .3)
				if k % 2 == 0: _ball(at, Vector3(.03, .025, .03), Color("#d8c08a"), "plain", 6, 8)
				else: _kit.lathe("plain", at + Vector3.DOWN * .02, [Vector2(.04, 0), Vector2(.04, .035)], Color("#e8dcc0"), 10)
		_: # Rice cooker, a board, a knife, the sauce pot.
			_kit.lathe("metal", f * Vector3(x1 - .25, .89, z), [Vector2(.15, 0), Vector2(.16, .2), Vector2(.12, .26), Vector2(0, .27)], Color("#e8e6de"), 14)
			_bar("wood", f, cx - .1, .9, z + .02, Vector3(.42, .025, .26), Color("#c8b48a"))
			_bar("metal", f, cx - .06, .918, z + .04, Vector3(.24, .004, .035), Color("#d4d6d4"))
			_kit.lathe("plain", f * Vector3(x0 + .15, .89, z - .05), [Vector2(.07, 0), Vector2(.075, .12)], Color("#2a1a12"), 10)
	if blade == 1 or blade == 5:
		# The television in the corner, always on the baseball.
		var at := f * Vector3(x1 - .3, 2.12, far + .5)
		_kit.tube("metal", [at + Vector3.UP * .3, at + Vector3.UP * .12], .012, Color("#3a3c3e"), 4)
		_bar("plain", f, x1 - .3, 2.12, far + .5, Vector3(.5, .3, .05), Color("#141516"))
		_bar("led", f, x1 - .3, 2.12, far + .526, Vector3(.45, .25, .004), Color(.35, .55, .4))

## Beer, skewers, sake and an ashtray along the counter top.
func _counter_spread(f: Transform3D, u0: float, u1: float) -> void:
	var x := u0 + .45 + _detail.randf() * .2
	while x < u1 - .4:
		var at := f * Vector3(x, 1.06, -1.0 + _detail.randf_range(-.1, .12))
		match _detail.randi_range(0, 4):
			0, 1: # Draught beer in a mug, head still on it.
				_kit.lathe("bottle", at, [Vector2(.04, 0), Vector2(.044, .12)], Color("#c8861c"), 10)
				_kit.lathe("plain", at + Vector3.UP * .12, [Vector2(.044, 0), Vector2(.045, .022), Vector2(.0, .03)], Color("#f4f0e6"), 10)
				_kit.tube("bottle", [at + f.basis.x * .044 + Vector3.UP * .03, at + f.basis.x * .075 + Vector3.UP * .06, at + f.basis.x * .044 + Vector3.UP * .1], .008, Color("#c8c8c0"), 4)
			2: # Skewers on a plate.
				_kit.lathe("plain", at, [Vector2(0, 0), Vector2(.09, .004), Vector2(.11, .02)], Color("#f0ece2"), 14)
				for k: int in range(3):
					var a := at + Vector3.UP * .025 + f.basis.z * (float(k) - 1.0) * .03
					_kit.tube("wood", [a - f.basis.x * .1, a + f.basis.x * .1], .003, Color("#d8c49a"), 3)
					for m: int in range(3):
						_kit.block("plain", Transform3D(f.basis, a - f.basis.x * .05 + f.basis.x * float(m) * .04), Vector3(.03, .022, .022), Color("#6a3a1a"))
			3: # Warm sake: flask and cup.
				_kit.lathe("plain", at, [Vector2(.032, 0), Vector2(.044, .06), Vector2(.02, .12), Vector2(.016, .15)], Color("#ece8dc"), 10)
				_kit.lathe("plain", at + f.basis.x * .08, [Vector2(.02, 0), Vector2(.026, .035)], Color("#ece8dc"), 10)
			4: # Tin ashtray and a lighter.
				_kit.lathe("metal", at, [Vector2(.05, 0), Vector2(.055, .015)], Color("#8a8c8a"), 10)
				_bar("plain", f, x + .08, 1.075, -1.0, Vector3(.025, .03, .012), Color("#d02a5a"))
		x += _detail.randf_range(.32, .55)

## Charcoal grill out front of the yakitori stall: the smoke is what you smell first.
func _grill(f: Transform3D, x: float, z: float) -> void:
	var iron := Color("#262728")
	for dx: float in [-.32, .32]:
		for dz: float in [-.1, .1]:
			_kit.tube("metal", [f * Vector3(x + dx, 0, z + dz), f * Vector3(x + dx, .82, z + dz)], .012, iron, 4)
	_bar("metal", f, x, .88, z, Vector3(.74, .16, .26), iron)
	_bar("lamp", f, x, .955, z, Vector3(.66, .01, .2), Color(1.0, .32, .06))
	for k: int in range(7):
		_kit.tube("metal", [f * Vector3(x - .33 + float(k) * .11, .968, z - .12), f * Vector3(x - .33 + float(k) * .11, .968, z + .12)], .004, Color("#4a4a48"), 3)
	for k: int in range(6):
		var sx := x - .27 + float(k) * .11
		_kit.tube("wood", [f * Vector3(sx, .985, z - .2), f * Vector3(sx, .985, z + .16)], .003, Color("#d8c49a"), 3)
		for m: int in range(4):
			_kit.block("plain", Transform3D(f.basis, f * Vector3(sx, .99, z - .1 + float(m) * .05)), Vector3(.026, .024, .03), Color("#5a2e12").lightened(_detail.randf() * .15))
	# The fan that keeps the coals going, and a towel over the rail.
	_kit.disc("plain", f * Vector3(x + .45, 1.0, z + .05), f.basis.z, Vector3.UP, .09, Color("#d8c89a"))
	_kit.tube("wood", [f * Vector3(x + .45, .91, z + .05), f * Vector3(x + .45, .96, z + .05)], .006, Color("#7a5a32"), 4)
	var start := _mark("plain")
	_kit.quad("plain", f * Vector3(x - .4, .7, z + .14), f * Vector3(x - .4, .94, z + .14), f * Vector3(x - .2, .94, z + .14), f * Vector3(x - .2, .7, z + .14), Color("#e8e4d6"))
	_kit.quad("plain", f * Vector3(x - .2, .7, z + .14), f * Vector3(x - .2, .94, z + .14), f * Vector3(x - .4, .94, z + .14), f * Vector3(x - .4, .7, z + .14), Color("#d8d4c6"))
	_sway("plain", start, .94, .24, .04)

## The last fluorescent tube at the quiet end, on its way out.
func _dying_tube(f: Transform3D, x: float) -> void:
	# A bare batten: steel channel, lampholders at each end, one 120 cm tube.
	_bar("metal", f, x, 2.64, .09, Vector3(1.3, .045, .12), Color("#e2e2da"))
	_bar("metal", f, x, 2.662, .09, Vector3(1.26, .006, .1), Color("#cacac2"))
	for end: float in [-.635, .635]:
		_bar("metal", f, x + end, 2.605, .14, Vector3(.03, .05, .05), Color("#d4d4cc"))
	_kit.tube("flicker", [f * Vector3(x - .62, 2.6, .14), f * Vector3(x + .62, 2.6, .14)], .014, Color(.86, .93, 1.0), 10)
	_kit.tube("plain", [f * Vector3(x - .6, 2.6, .14), f * Vector3(x - .56, 2.6, .14)], .0145, Color("#4a4440"), 10)

## A ginger cat asleep on the bin lid, nose tucked into its tail.
func _cat(at: Vector3, yaw: float) -> void:
	var axes := Basis(Vector3.UP, yaw)
	var fur := Color("#c07a36")
	_ball(at + Vector3.UP * .07, Vector3(.17, .08, .12), fur, "plain", 8, 14, axes)
	_ball(at + Vector3.UP * .1 + axes * Vector3(.13, 0, .04), Vector3(.065, .055, .06), fur.lightened(.05), "plain", 6, 10, axes)
	for side: float in [-1.0, 1.0]:
		var ear := at + Vector3.UP * .15 + axes * Vector3(.14, 0, .04 + side * .035)
		_kit.quad("plain", ear + axes * Vector3(-.02, 0, -.018), ear + Vector3.UP * .04, ear + Vector3.UP * .04, ear + axes * Vector3(.02, 0, .018), fur.darkened(.2))
	var tail: Array[Vector3] = []
	for k: int in range(8):
		var a := PI * .6 + float(k) / 7.0 * PI * 1.1
		tail.append(at + Vector3.UP * .03 + axes * Vector3(cos(a) * .18, 0, sin(a) * .14))
	_kit.tube("plain", tail, .022, fur.darkened(.1), 6)
	for k: int in range(3):
		_ball(at + Vector3.UP * .1 + axes * Vector3(-.06 + float(k) * .05, .0, .0), Vector3(.012, .075, .11), fur.darkened(.25), "plain", 4, 6, axes)

## Washing on a pole above the last door, the only house still lived in.
func _laundry_pole(f: Transform3D, x0: float, x1: float) -> void:
	var steel := Color("#c4c6c4")
	for x: float in [x0, x1]:
		_kit.tube("metal", [f * Vector3(x, 4.5, 0), f * Vector3(x, 4.55, .55)], .012, Color("#5a5c5a"), 4)
	_kit.tube("metal", [f * Vector3(x0 - .1, 4.55, .55), f * Vector3(x1 + .1, 4.55, .55)], .016, steel, 6)
	var colors: Array[Color] = [Color("#e8e4da"), Color("#6a8ab0"), Color("#d4a0a0"), Color("#f0d890"), Color("#4a5a4a")]
	var x := x0 + .15
	while x < x1 - .3:
		var wide := _detail.randf_range(.24, .5)
		var drop := _detail.randf_range(.3, .7)
		var tint: Color = colors[_detail.randi_range(0, colors.size() - 1)]
		var start := _mark("plain")
		for r: int in range(3):
			var y0 := 4.54 - drop * float(r) / 3.0
			var y1 := 4.54 - drop * float(r + 1) / 3.0
			_kit.quad("plain", f * Vector3(x, y1, .55), f * Vector3(x, y0, .55), f * Vector3(x + wide, y0, .55), f * Vector3(x + wide, y1, .55), tint)
			_kit.quad("plain", f * Vector3(x + wide, y1, .55), f * Vector3(x + wide, y0, .55), f * Vector3(x, y0, .55), f * Vector3(x, y1, .55), tint.darkened(.15))
		_sway("plain", start, 4.55, drop, .12)
		for peg: float in [x + .02, x + wide - .02]:
			_bar("plain", f, peg, 4.56, .55, Vector3(.012, .04, .02), Color("#e0507a"))
		x += wide + _detail.randf_range(.06, .2)

## Maneki-neko on the top shelf, paw up for business.
func _lucky_cat(at: Vector3) -> void:
	var white := Color("#f4f0e6")
	_ball(at + Vector3.UP * .05, Vector3(.045, .05, .04), white, "plain", 6, 10)
	_ball(at + Vector3.UP * .12, Vector3(.042, .036, .038), white, "plain", 6, 10)
	_kit.lathe("plain", at + Vector3.UP * .085, [Vector2(.043, 0), Vector2(.044, .008)], Color("#c8221a"), 10)
	_kit.tube("plain", [at + Vector3(.035, .1, 0), at + Vector3(.04, .16, 0)], .012, white, 5)

## Upright mamachari on its stand, nose toward -z: basket, mudguards, chain case,
## rear carrier and a step-through frame, as every shopping bicycle has.
func _parked_bicycle(at: Vector3, tint: Color) -> void:
	var black := Color("#1b1c1e")
	var silver := Color("#b8bcbe")
	for z: float in [-.52, .52]:
		var hub := at + Vector3(0, .33, z)
		var tyre: Array[Vector3] = []
		var rim: Array[Vector3] = []
		for i: int in range(29):
			var angle := TAU * float(i) / 28.0
			tyre.append(hub + Vector3(0, sin(angle), cos(angle)) * .315)
			rim.append(hub + Vector3(0, sin(angle), cos(angle)) * .285)
		_kit.tube("plain", tyre, .018, black, 5)
		_kit.tube("metal", rim, .007, silver, 4)
		for i: int in range(9):
			var angle := TAU * float(i) / 9.0
			_kit.tube("metal", [hub + Vector3(.012 if i % 2 == 0 else -.012, 0, 0), hub + Vector3(0, sin(angle), cos(angle)) * .28], .0025, silver, 3)
		# Mudguard over the top of the wheel.
		var guard: Array[Vector3] = []
		for i: int in range(11):
			var angle := lerpf(.25, PI - .25, float(i) / 10.0)
			guard.append(hub + Vector3(0, sin(angle), -cos(angle) * signf(z)) * .35)
		_kit.tube("metal", guard, .028, tint.lightened(.1) if tint.get_luminance() < .5 else silver, 5)
	var crank := at + Vector3(0, .3, .02)
	var seat := at + Vector3(0, .82, .26)
	var head := at + Vector3(0, .86, -.4)
	_kit.tube("metal", [at + Vector3(0, .33, .52), crank], .016, tint, 5)
	_kit.tube("metal", [at + Vector3(0, .33, .52), seat + Vector3.DOWN * .05], .014, tint, 5)
	_kit.tube("metal", [crank, crank + Vector3(0, .12, -.18), head + Vector3.DOWN * .12], .024, tint, 6)
	_kit.tube("metal", [crank, seat], .02, tint, 5)
	_kit.tube("metal", [head + Vector3.UP * .05, head + Vector3.DOWN * .1, at + Vector3(0, .33, -.52)], .018, tint, 5)
	_kit.block("plain", Transform3D(Basis.IDENTITY, crank + Vector3(.04, .02, .25)), Vector3(.03, .1, .58), black)
	_ball(seat + Vector3(0, .04, .02), Vector3(.085, .035, .13), Color("#2a1e18"), "plain", 6, 10)
	_kit.tube("metal", [seat + Vector3.DOWN * .02, seat + Vector3(0, -.02, .32), at + Vector3(0, .62, .62)], .01, silver, 4)
	_kit.block("metal", Transform3D(Basis.IDENTITY, seat + Vector3(0, -.03, .38)), Vector3(.18, .015, .26), silver)
	_kit.tube("metal", [head + Vector3(-.26, .1, .08), head + Vector3(-.2, .06, -.02), head + Vector3(.2, .06, -.02), head + Vector3(.26, .1, .08)], .012, silver, 4)
	for side: float in [-.26, .26]:
		_kit.tube("plain", [head + Vector3(side, .1, .08), head + Vector3(side * 1.12, .11, .16)], .016, black, 5)
	# Wire basket on the front stays.
	var basket := head + Vector3(0, -.16, -.2)
	_kit.block("metal", Transform3D(Basis.IDENTITY, basket + Vector3.DOWN * .12), Vector3(.34, .01, .26), Color("#8e9092"))
	for corner: Vector2 in [Vector2(-.17, -.13), Vector2(.17, -.13), Vector2(.17, .13), Vector2(-.17, .13)]:
		_kit.tube("metal", [basket + Vector3(corner.x, -.12, corner.y), basket + Vector3(corner.x * 1.06, .08, corner.y * 1.06)], .005, Color("#8e9092"), 3)
	var rim_points: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-.18, -.14), Vector2(.18, -.14), Vector2(.18, .14), Vector2(-.18, .14), Vector2(-.18, -.14)]:
		rim_points.append(basket + Vector3(corner.x, .08, corner.y))
	_kit.tube("metal", rim_points, .006, Color("#8e9092"), 3)
	# Two-legged stand, folded down.
	for side: float in [-.09, .09]:
		_kit.tube("metal", [at + Vector3(0, .3, .5), at + Vector3(side, .0, .42)], .008, silver, 4)

## Grey smoke or white steam, drifting downwind as it rises.
func _plume(label: String, at: Vector3, count: int, life: float, rise: float, tint: Color, size: float) -> GPUParticles3D:
	var plume := GPUParticles3D.new()
	plume.name = label
	plume.position = at
	plume.amount = count
	plume.lifetime = life
	plume.preprocess = life
	plume.local_coords = false
	plume.fixed_fps = 30
	plume.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(.12, .03, .25)
	motion.direction = Vector3.UP
	motion.spread = 14.0
	motion.initial_velocity_min = rise * .8
	motion.initial_velocity_max = rise * 1.2
	motion.gravity = WIND_DIR * .22 + Vector3.UP * .06
	motion.damping_min = .1
	motion.damping_max = .3
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = .9
	motion.turbulence_noise_scale = 1.1
	motion.turbulence_influence_min = .12
	motion.turbulence_influence_max = .3
	motion.angle_min = 0.0
	motion.angle_max = 360.0
	motion.angular_velocity_min = -20.0
	motion.angular_velocity_max = 20.0
	motion.scale_min = .7
	motion.scale_max = 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0, .25))
	grow.add_point(Vector2(1, 1.6))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	motion.scale_curve = grow_texture
	motion.color = Color(tint.r, tint.g, tint.b, 1.0)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, .15, .6, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, tint.a), Color(1, 1, 1, tint.a * .6), Color(1, 1, 1, 0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	motion.color_ramp = fade_texture
	plume.process_material = motion
	var puff := Gradient.new()
	puff.offsets = PackedFloat32Array([0.0, .55, 1.0])
	puff.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, .45), Color(1, 1, 1, 0)])
	var soft := GradientTexture2D.new()
	soft.gradient = puff
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(.5, .5)
	soft.fill_to = Vector2(1.0, .5)
	soft.width = 64
	soft.height = 64
	var material := StandardMaterial3D.new()
	material.albedo_texture = soft
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = .35
	material.roughness = 1.0
	material.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	plume.draw_pass_1 = quad
	add_child(plume)
	return plume
