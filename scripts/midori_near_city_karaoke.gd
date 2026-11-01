extends "res://scripts/midori_near_city_handmade.gd"
## カラオケ ケロ: a thin corner tower dressed head to foot in one colour, the way the chains do it.
## Lime panels and white piers, a chamfer for the corner with the trade stacked down it in
## channel letters and a neon frog in full song, and a sign box on the roof with lamps on arms.
## Every floor has its own use and says so. Local origin is the middle of the lot's street front.
const ATLAS := "res://assets/shinrai/near_city/karaoke_atlas.png"
const ROOM_SHADER := preload("res://scripts/midori_near_city_karaoke_room.gdshader")
const TICKER_SHADER := preload("res://scripts/midori_near_city_ticker.gdshader")
const WIDE := 8.9
const DEEP := 7.88
const CUT := 1.8 # How far the corner is sliced back along each face.
const GROUND := 3.6
const STOREY := 3.0
const FLOORS := 7
const TOP := 24.6
const CROWN := 28.4
const LIME := Color("#45ad1c")
const FLOOR_MOODS: Array[float] = [.1, .3, .1, .8, .35, .05, .6] # Each floor keeps its own colour.
const WHITE := Color("#f0efe4")
const NAVY := Color("#123a5a")
const FRONT_RUN := 7.1
const WEST_RUN := 6.08
const CHAMFER_RUN := 2.546

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5 + CUT, 0, 0))
var _chamfer := Transform3D(Basis(Vector3(.7071, 0, .7071), Vector3.UP, Vector3(-.7071, 0, .7071)), Vector3(-WIDE * .5, 0, -CUT))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _room_number := 0

func _ready() -> void:
	_rng.seed = 96
	_build_looks()
	_livery(_front, FRONT_RUN)
	_livery(_west, WEST_RUN)
	_corner()
	_street_floor()
	_lobby()
	_side_street()
	_crown()
	_flanks()
	_kerbside()
	_kit.commit(self, _looks, ["front", "rooms", "ticker", "decal", "lamp", "led", "neon", "leaf", "sign", "poster", "room", "cloth"])
	_kit = null
	_omni("Lobby", Vector3(.6, 2.4, -2.0), Color(.9, 1.0, .82), 1.1, 8.0)
	_omni("Pavement", Vector3(.6, 2.6, 1.4), Color(.72, 1.0, .62), .8, 7.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.panel = _look("", 1.0, .48, .1)
	_looks.render = _look("plastered_wall_03", 2.4, .92)
	_looks.render.set_shader_parameter("chroma", .6)
	_looks.stone = _look("", 1.0, .2)
	_looks.tile = _look("square_tiled_wall", 1.6, .5)
	_looks.tile.set_shader_parameter("chroma", .3)
	_looks.room = _look("", 1.0, .6)
	_looks.room.set_shader_parameter("glow", .42)
	_looks.room.set_shader_parameter("day_glow", .2)
	for row: Array in [["sign", .85, .26], ["poster", .7, .34], ["cloth", .2, .08]]:
		var look := _look("", 1.0, .85)
		look.set_shader_parameter("albedo_map", signs)
		look.set_shader_parameter("glow", row[1])
		look.set_shader_parameter("day_glow", row[2])
		_looks[row[0]] = look
	var rooms := ShaderMaterial.new()
	rooms.shader = ROOM_SHADER
	_looks.rooms = rooms
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", 1.6)
	letters.set_shader_parameter("day_glow", .46)
	_looks.decal = letters
	var ticker := ShaderMaterial.new()
	ticker.shader = TICKER_SHADER
	ticker.set_shader_parameter("atlas", signs)
	var strip := _cell(0, 714, 2048, 56)
	ticker.set_shader_parameter("strip", Vector4(strip.position.x, strip.position.y, strip.size.x, strip.size.y))
	_looks.ticker = ticker

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _sheet(f: Transform3D, x0: float, x1: float, y0: float, y1: float, tint: Color, streak := .5) -> void:
	_kit.quad("panel", f * Vector3(x0, y0, 0), f * Vector3(x0, y1, 0), f * Vector3(x1, y1, 0), f * Vector3(x1, y0, 0), tint, .94, 1.0, streak, Vector2(x0, -y0))

func _livery(f: Transform3D, run: float) -> void:
	# Lime spandrels, white piers: every storey one band of panel and one band of dark glass.
	var bays := int(round(run / 2.2))
	var bay := run / float(bays)
	var pier := .34
	for storey: int in range(FLOORS):
		var y := GROUND + float(storey) * STOREY
		var sill := y + .86
		var head := y + 2.72
		var x := .0
		while x < run - .01:
			var right := minf(x + 1.22, run)
			var tone := _rng.randf_range(.93, 1.03)
			_sheet(f, x, right, y, sill, Color(LIME.r * tone, LIME.g * tone, LIME.b * tone))
			_bar("plain", f, right, (y + sill) * .5, .002, Vector3(.012, sill - y, .006), LIME * .5)
			x = right
		_sheet(f, 0, run, head, y + STOREY, WHITE, .7)
		_bar("metal", f, run * .5, sill, .03, Vector3(run, .05, .07), Color("#d6d6cc"))
		_bar("led", f, run * .5, head + .03, .025, Vector3(run, .016, .012), AMBER * .6)
		for i: int in range(bays):
			var x0 := float(i) * bay + pier * .5
			var x1 := float(i + 1) * bay - pier * .5
			_room_window(f, x0, x1, sill, head, FLOOR_MOODS[storey])
			_sheet(f, x0 + bay - pier, x1 + pier, sill, head, WHITE, .7)
		_sheet(f, 0, pier * .5, sill, head, WHITE, .7)
		_sheet(f, run - pier * .5, run, sill, head, WHITE, .7)

func _room_window(f: Transform3D, x0: float, x1: float, y0: float, y1: float, mood: float) -> void:
	# A set-back pane with the room worked out behind it, in a dark aluminium frame.
	var r := Rect2(x0, y0, x1 - x0, y1 - y0)
	_reveal(f, r, .16, Color("#b8b8ae"))
	var half := r.size * .5
	var mid := r.get_center()
	_room_number += 1
	var number := fposmod(float(_room_number) * .0713, 1.0)
	_kit.atlas("rooms", f * Vector3(x0, y0, -.16), f * Vector3(x0, y1, -.16), f * Vector3(x1, y1, -.16), f * Vector3(x1, y0, -.16), Rect2(-half.x, -half.y, r.size.x, r.size.y), Color(number, mood, 0))
	var alu := Color("#2c2e30")
	_bar("metal", f, mid.x, y1 - .02, -.13, Vector3(r.size.x, .04, .06), alu)
	_bar("metal", f, mid.x, y0 + .02, -.13, Vector3(r.size.x, .04, .06), alu)
	_bar("metal", f, mid.x, mid.y, -.13, Vector3(.04, r.size.y, .05), alu)

func _corner() -> void:
	# The slice off the corner is what the crossing looks at: green, tall, and shouting.
	var f := _chamfer
	var run := CHAMFER_RUN
	var y := GROUND
	while y < TOP - .01:
		var high := minf(y + 1.5, TOP)
		_sheet(f, 0, run, y, high, Color("#3a9a18") * _rng.randf_range(.94, 1.02))
		_bar("plain", f, run * .5, high, .002, Vector3(run, .012, .006), LIME * .5)
		y = high
	_kit.quad("tile", f * Vector3(0, 0, 0), f * Vector3(0, GROUND, 0), f * Vector3(run, GROUND, 0), f * Vector3(run, 0, 0), Color(.3, .32, .34), .9, 1.0)
	# The building's directory beside the crossing: which floor is for what, lit, in a steel frame.
	_bar("metal", f, run * .5, 1.92, .03, Vector3(1.86, 2.3, .06), Color("#8a8e90"))
	_bar("metal", f, run * .5, 1.92, .05, Vector3(1.74, 2.18, .03), Color("#14181c"))
	for row: int in range(7):
		var top := 2.92 - float(row) * .3
		_panel("poster", f, .4, run - .4, top - .27, top, .07, _cell(1190, 790.0 + float(6 - row) * 66.0, 420, 60))
	# The neon singer over the lower floors, the channel letters above him.
	_panel("decal", f, -.2, run + .2, 6.4, 14.4, .05, _cell(610, 790, 400, 800))
	_panel("decal", f, .3, run - .3, 15.2, 24.2, .05, _cell(1020, 790, 160, 640))
	for side: float in [.12, run - .12]:
		_neon([f * Vector3(side, GROUND, .07), f * Vector3(side, TOP, .07)], Color(.5, 1.0, .34))

func _street_floor() -> void:
	var f := _front
	var band := 3.0
	# Polished piers each end, a dark band with a line of light above and below it.
	for row: Array in [[0.0, .44], [FRONT_RUN - .4, FRONT_RUN]]:
		_bar("stone", f, (row[0] + row[1]) * .5, band * .5, -.1, Vector3(row[1] - row[0], band, .24), Color("#3c4044"), .85, .9)
	_bar("metal", f, FRONT_RUN * .5, (band + GROUND) * .5, .06, Vector3(FRONT_RUN + .04, GROUND - band, .2), Color("#14181c"))
	_panel("poster", f, .1, FRONT_RUN - .1, band + .05, GROUND - .05, .162, _cell(1100, 1620, 940, 80))
	for y: float in [band + .02, GROUND - .02]:
		_bar("led", f, FRONT_RUN * .5, y, .17, Vector3(FRONT_RUN, .022, .02), Color(.42, 1.0, .3))
	_kit.quad("front", f * Vector3(.44, .05, -.3), f * Vector3(.44, band, -.3), f * Vector3(FRONT_RUN - .4, band, -.3), f * Vector3(FRONT_RUN - .4, .05, -.3), Color.WHITE)
	for x: float in [.44, 2.4, 3.1, 3.8, 4.5, FRONT_RUN - .4]:
		_bar("metal", f, x, band * .5, -.28, Vector3(.06, band, .08), Color("#8a8e90"))
	_bar("metal", f, FRONT_RUN * .5, 2.5, -.28, Vector3(FRONT_RUN - .84, .05, .08), Color("#8a8e90"))
	_panel("poster", f, .6, 1.3, .3, 1.35, -.34, _cell(1620, 990, 200, 300))
	_panel("poster", f, 1.45, 2.15, .3, 1.35, -.34, _cell(1830, 990, 200, 300))
	_panel("poster", f, 4.7, 5.4, .3, 1.35, -.34, _cell(1620, 1300, 200, 300))
	_panel("poster", f, 5.55, 6.25, .3, 1.35, -.34, _cell(1830, 1300, 200, 300))
	_panel("poster", f, 2.55, 4.35, 2.56, 2.96, -.34, _cell(0, 1600, 300, 200))
	_bar("stone", f, FRONT_RUN * .5, .03, -.1, Vector3(FRONT_RUN, .06, .5), Color("#2c2e30"))
	# Each floor says what it is, on the band beneath its windows.
	for row: int in range(7):
		var base := GROUND + float(row) * STOREY
		_bar("metal", f, 1.98, base + .43, .01, Vector3(3.3, .5, .02), Color("#14181c"))
		_panel("poster", f, .4, 3.56, base + .21, base + .65, .024, _cell(1190, 790.0 + float(row) * 66.0, 420, 60))
	# The second floor is all advertising, glass or no glass, the way the low floors always are.
	var y := GROUND + .9
	_panel("poster", f, .5, 1.62, y, y + 1.68, -.08, _cell(0, 1600, 300, 200))
	_panel("poster", f, 2.9, 3.86, y + .1, y + 1.56, -.08, _cell(310, 1600, 300, 420))
	# A long banner down the front, on brackets, for this month's offer.
	var x := FRONT_RUN - 1.1
	_bar("metal", f, x, 11.55, .2, Vector3(.98, 12.1, .06), Color("#2c2e30"))
	_panel("sign", f, x - .46, x + .46, 11.6, 17.6, .24, _cell(630, 1600, 120, 440))
	_panel("sign", f, x - .46, x + .46, 5.5, 11.5, .24, _cell(760, 1600, 120, 440))
	for level: float in [6.0, 9.0, 12.0, 15.0, 17.2]:
		_bar("metal", f, x, level, .1, Vector3(.7, .06, .2), Color("#2c2e30"))

func _lobby() -> void:
	# White floor, round coffers, a wall of posters and a counter nobody stands behind any more.
	var f := _front
	var x0 := .44
	var x1 := FRONT_RUN - .4
	var far := -4.8
	var ceiling := 2.98
	var wall := Color("#dfe4da")
	_kit.quad("room", f * Vector3(x0, .03, -.3), f * Vector3(x0, .03, far), f * Vector3(x1, .03, far), f * Vector3(x1, .03, -.3), Color("#c8ccc4"))
	_kit.quad("room", f * Vector3(x0, ceiling, far), f * Vector3(x0, ceiling, -.3), f * Vector3(x1, ceiling, -.3), f * Vector3(x1, ceiling, far), Color("#b8bcb4"))
	_kit.quad("room", f * Vector3(x0, 0, far), f * Vector3(x0, ceiling, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, 0, far), wall)
	_kit.quad("room", f * Vector3(x0, 0, -.3), f * Vector3(x0, ceiling, -.3), f * Vector3(x0, ceiling, far), f * Vector3(x0, 0, far), wall)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, ceiling, -.3), f * Vector3(x1, 0, -.3), wall)
	for x: float in [1.7, 3.5, 5.3]:
		for z: float in [-1.5, -3.4]:
			_kit.disc("lamp", f * Vector3(x, ceiling - .01, z), Vector3.RIGHT, Vector3.BACK, .34, Color(1.0, .92, .78))
	_bar("room", f, 3.5, .54, -3.7, Vector3(3.4, 1.08, .5), LIME)
	_bar("room", f, 3.5, 1.1, -3.64, Vector3(3.5, .05, .68), Color("#f2f2e8"))
	_panel("poster", f, 2.4, 4.6, 1.7, 2.7, far + .03, _cell(0, 1810, 300, 200))
	_panel("poster", f, .8, 1.5, 1.2, 2.3, far + .03, _cell(1620, 990, 200, 300))
	_panel("poster", f, 5.5, 6.2, 1.2, 2.3, far + .03, _cell(1830, 1300, 200, 300))

func _side_street() -> void:
	# Round the corner the show thins out: the same livery upstairs, a shutter and a door below.
	var f := _west
	_kit.quad("tile", f * Vector3(0, 0, 0), f * Vector3(0, GROUND, 0), f * Vector3(WEST_RUN, GROUND, 0), f * Vector3(WEST_RUN, 0, 0), Color(.3, .32, .34), .9, 1.0, .6)
	_bar("led", f, WEST_RUN * .5, GROUND - .02, .02, Vector3(WEST_RUN, .022, .02), Color(.42, 1.0, .3))
	_kit.quad("plain", f * Vector3(.5, .03, .02), f * Vector3(.5, 2.7, .02), f * Vector3(2.9, 2.7, .02), f * Vector3(2.9, .03, .02), Color("#5e6264"), .9, 1.0, .8)
	var y := .2
	while y < 2.7:
		_bar("plain", f, 1.7, y, .03, Vector3(2.4, .012, .012), Color("#3e4244"))
		y += .12
	_bar("metal", f, 1.7, 2.84, .08, Vector3(2.6, .3, .14), Color("#44484a"))
	_panel("poster", f, 3.3, 4.1, .9, 2.1, .02, _cell(1620, 990, 200, 300))
	_panel("poster", f, 4.3, 5.1, .9, 2.1, .02, _cell(310, 1600, 300, 420))
	_camera(f * Vector3(5.5, 3.5, .1))
	_fibre([f * Vector3(5.8, 3.6, .03), f * Vector3(5.8, .3, .03)])

func _crown() -> void:
	# The sign box: three faces of it and a steel frame behind, carried a little proud of the tower.
	var proud := .3
	var low := TOP
	var high := CROWN
	var front_face := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5 + CUT, 0, proud))
	var west_face := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5 - proud, 0, -DEEP))
	var corner := Transform3D(_chamfer.basis, _chamfer * Vector3(0, 0, proud))
	_panel("sign", front_face, 0, FRONT_RUN, low + .6, high, 0, _cell(0, 0, 1400, 700))
	_panel("sign", west_face, 0, WEST_RUN, low + .6, high, 0, _cell(1410, 0, 630, 370))
	_panel("sign", corner, -.12, CHAMFER_RUN + .12, low + .6, high, 0, _cell(1480, 380, 280, 326))
	var dark := Color("#1a1c1e")
	_kit.quad("plain", Vector3(-WIDE * .5 - proud, low, -DEEP), Vector3(-WIDE * .5 - proud, low, -CUT), Vector3(-WIDE * .5 + CUT, low, proud), Vector3(WIDE * .5, low, proud), dark)
	for row: Array in [[front_face, FRONT_RUN], [west_face, WEST_RUN], [corner, CHAMFER_RUN]]:
		var face: Transform3D = row[0]
		var run: float = row[1]
		_bar("plain", face, run * .5, low + .3, -.02, Vector3(run + .1, .62, .04), dark)
		_bar("metal", face, run * .5, high + .05, -.1, Vector3(run + .12, .1, .24), WHITE)
		_neon([face * Vector3(0, high + .12, .03), face * Vector3(run, high + .12, .03)], Color(.5, 1.0, .34))
		var x := .5
		while x < run:
			_lamp_arm(face, x, high)
			x += 1.5
	_panel("ticker", front_face, .15, FRONT_RUN - .15, low + .1, low + .5, .01, Rect2(0, 0, 1, 1))
	# Behind the boards, the steel that holds them up and the plant that keeps the rooms cold.
	var steel := Color("#3a3d40")
	for x: float in [-3.4, -.8, 1.8, 4.2]:
		_kit.tube("metal", [Vector3(x, TOP, -.2), Vector3(x, CROWN, -.2)], .05, steel, 6)
		_kit.tube("metal", [Vector3(x, TOP, -2.2), Vector3(x, CROWN - .6, -.2)], .04, steel, 6)
	_kit.quad("plain", Vector3(-WIDE * .5, TOP + .02, 0), Vector3(-WIDE * .5, TOP + .02, -DEEP), Vector3(WIDE * .5, TOP + .02, -DEEP), Vector3(WIDE * .5, TOP + .02, 0), Color("#5c5d59"), .8, .9)
	var roof := Transform3D(Basis.IDENTITY, Vector3(0, TOP, 0))
	for x: float in [-1.9, 1.6]:
		_bar("metal", roof, x, .7, -5.6, Vector3(2.2, 1.4, 1.6), Color("#a9adae"), .85, 1.0)
	_bar("render", roof, 3.2, 1.15, -3.2, Vector3(1.6, 2.3, 2.0), Color(.72, .71, .66))

func _lamp_arm(face: Transform3D, x: float, high: float) -> void:
	# A floodlight on a long arm, the old way of lighting a sign.
	_kit.tube("metal", [face * Vector3(x, high + .08, .03), face * Vector3(x, high + .5, .7)], .02, Color("#3a3d40"), 5)
	_bar("metal", face, x, high + .5, .74, Vector3(.34, .09, .18), Color("#55585a"))
	_bar("lamp", face, x, high + .45, .74, Vector3(.28, .012, .14), Color(1.0, .92, .76))

func _flanks() -> void:
	var paint := Color(.76, .75, .7)
	_render_wall(_east, DEEP, CROWN - 1.0, GROUND, STOREY, paint, [] as Array[Rect2], .7)
	_render_wall(_back, WIDE, CROWN - 1.0, GROUND, STOREY, paint, [] as Array[Rect2], .7)
	# The stalls next door stop at the first floor, so ケロちゃん gets the whole wall above them.
	_panel("sign", _east, .9, 7.3, 7.0, 15.5, .03, _cell(0, 790, 600, 800), Color(.84, .82, .78))
	_kit.tube("plain", [_east * Vector3(.5, .1, .08), _east * Vector3(.5, CROWN - 1.2, .08)], .05, Color("#8a8b84"), 7)
	_kit.tube("plain", [_east * Vector3(7.5, .1, .08), _east * Vector3(7.5, CROWN - 1.2, .08)], .05, Color("#8a8b84"), 7)
	for row: int in range(4):
		_outdoor_unit(_east, 1.6, 16.6 + float(row) * 1.3, .2)
		_outdoor_unit(_east, 6.2, 16.6 + float(row) * 1.3, .2)

func _kerbside() -> void:
	# ケロちゃん in fibreglass on the corner, microphone up, and the boards and flags round him.
	var frog := Vector3(-3.0, 0, .9)
	var green := Color("#4cba22")
	var pale := Color("#dff0a0")
	# Bolted down: the plinth is wide and heavy, and the feet and belly both sink into it.
	_kit.lathe("metal", frog, [Vector2(.66, 0), Vector2(.66, .16), Vector2(.56, .22)], Color("#3a3d40"), 28)
	for side: float in [-1.0, 1.0]:
		_ball(frog + Vector3(side * .28, .24, .2), Vector3(.27, .1, .34), green)
	_ball(frog + Vector3(-.46, .72, .1), Vector3(.14, .3, .14), green)
	_ball(frog + Vector3(0, .68, 0), Vector3(.46, .54, .42), green)
	_ball(frog + Vector3(0, .68, .22), Vector3(.32, .4, .25), pale)
	var head := frog + Vector3.UP * 1.5
	_ball(head, Vector3(.6, .44, .54), green)
	for side: float in [-1.0, 1.0]:
		var eye := head + Vector3(side * .3, .4, .1)
		_ball(eye, Vector3(.19, .19, .19), green)
		_ball(eye + Vector3(0, .01, .08), Vector3(.145, .145, .145), Color("#fafaf4"))
		_ball(eye + Vector3(0, .01, .19), Vector3(.06, .07, .05), Color("#17120e"))
		_ball(head + Vector3(side * .4, -.04, .31), Vector3(.09, .06, .05), Color("#ff9fb0"))
	_ball(head + Vector3(0, -.14, .46), Vector3(.2, .17, .09), Color("#5a0e20"))
	_ball(head + Vector3(0, -.22, .5), Vector3(.1, .06, .06), Color("#ff6a88"))
	# The arm comes off the shoulder, bends at the elbow, and the fist closes round the stick.
	_kit.tube("plain", [frog + Vector3(.36, 1.0, .1), frog + Vector3(.6, .9, .34), frog + Vector3(.3, 1.08, .6)], .1, green, 10)
	_kit.tube("metal", [frog + Vector3(.32, .9, .6), frog + Vector3(.17, 1.3, .66)], .032, Color("#3a3c40"), 8)
	_ball(frog + Vector3(.26, 1.08, .62), Vector3(.13, .13, .13), green)
	_ball(frog + Vector3(.15, 1.34, .67), Vector3(.095, .095, .095), Color("#c8ccd0"))
	_flag(_front * Vector3(1.1, 0, 1.1), .2, 760.0)
	_flag(_front * Vector3(5.9, 0, 1.1), -.2, 630.0)
	var board := Transform3D(Basis(Vector3.UP, -.2), _front * Vector3(5.0, 0, .9))
	_kit.atlas("poster", board * Vector3(-.34, .1, .12), board * Vector3(-.34, 1.08, -.08), board * Vector3(.34, 1.08, -.08), board * Vector3(.34, .1, .12), _cell(310, 1600, 300, 420))
	_kit.quad("plain", board * Vector3(.34, 0, -.3), board * Vector3(.34, 1.08, -.1), board * Vector3(-.34, 1.08, -.1), board * Vector3(-.34, 0, -.3), Color("#2c2e30"))

func _ball(at: Vector3, size: Vector3, tint: Color) -> void:
	var profile: Array[Vector2] = []
	var rings := 20
	for i: int in range(rings + 1):
		var a := -PI * .5 + PI * float(i) / float(rings)
		profile.append(Vector2(maxf(cos(a), .001), sin(a)))
	# The lathe is round, so an egg is a stack of its own rings: scale them here instead.
	var sides := 32
	for r: int in range(rings):
		for s: int in range(sides):
			var a0 := -TAU * float(s) / float(sides)
			var a1 := -TAU * float(s + 1) / float(sides)
			var p0 := profile[r]
			var p1 := profile[r + 1]
			var low_left := at + Vector3(cos(a0) * p0.x * size.x, p0.y * size.y, sin(a0) * p0.x * size.z)
			var top_left := at + Vector3(cos(a0) * p1.x * size.x, p1.y * size.y, sin(a0) * p1.x * size.z)
			var top_right := at + Vector3(cos(a1) * p1.x * size.x, p1.y * size.y, sin(a1) * p1.x * size.z)
			var low_right := at + Vector3(cos(a1) * p0.x * size.x, p0.y * size.y, sin(a1) * p0.x * size.z)
			var n0 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var n1 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var n2 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var n3 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			_kit.smooth("plain", low_left, top_left, top_right, low_right, n0, n1, n2, n3, tint)

func _flag(foot: Vector3, turn: float, column: float) -> void:
	var spin := Basis(Vector3.UP, turn)
	_kit.lathe("metal", foot, [Vector2(.16, 0), Vector2(.16, .1), Vector2(.03, .14)], Color("#3a3d40"), 10)
	_kit.tube("metal", [foot, foot + Vector3.UP * 2.7], .016, Color("#c9cbc9"), 6)
	_kit.tube("metal", [foot + Vector3.UP * 2.66, foot + Vector3.UP * 2.66 + spin * Vector3(.56, 0, 0)], .01, Color("#c9cbc9"), 5)
	var rect := _cell(column, 1600, 120, 440)
	var a := foot + spin * Vector3(.02, 0, 0)
	var e := foot + spin * Vector3(.56, 0, 0)
	_kit.atlas("cloth", a + Vector3.UP * .64, a + Vector3.UP * 2.64, e + Vector3.UP * 2.64, e + Vector3.UP * .64, rect)
	_kit.atlas("cloth", e + Vector3.UP * .64, e + Vector3.UP * 2.64, a + Vector3.UP * 2.64, a + Vector3.UP * .64, rect)
