extends "res://scripts/midori_near_city_handmade.gd"
## らーめん 福丸: a shop one counter wide, the noodle room in the window and the stockpots
## going since five. A mahjong room upstairs, a flat above that, and a ticket machine that
## took a palm reader in 2041 and has not been cleaned since.
const ATLAS := "res://assets/shinrai/near_city/ramen_atlas.png"
const WIDE := 3.72
const DEEP := 9.2
const GROUND := 3.3
const STOREY := 2.85
const TOP := 9.0
const PARAPET := 9.5
const ROOM_TOP := 2.62
const ROOM_DEEP := 7.2
const OXBLOOD := Color("#6d2a22")
const FORMICA := Color("#c4553f")
const CHROME := Color("#c9ccce")
const RENDER := Color(.8, .76, .68)
const DOOR := Rect2(.22, .02, 1.2, 2.36)
const WINDOW := Rect2(2.2, .62, 1.32, 1.56)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 2019
	_build_looks()
	_shop_wall()
	_room()
	_counter()
	_kitchen()
	_noodle_room()
	_door()
	_ticket_machine()
	_fascia()
	_noren()
	_lantern()
	_upper_front()
	_duct()
	_blade()
	_render_wall(_east, DEEP, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2], .7)
	_render_wall(_back, WIDE, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2], .5)
	_render_wall(_west, DEEP, PARAPET, GROUND, STOREY, RENDER * .9, [] as Array[Rect2], .7)
	_rooftop()
	_street_things()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "neon", "led", "sign", "room", "display", "strips", "lantern"])
	_kit = null
	_omni("RamenCounter", Vector3(-.6, 2.3, -2.6), Color(1.0, .86, .66), .9, 5.5)
	_omni("RamenStreet", Vector3(-.5, 2.5, .9), Color(1.0, .72, .46), .55, 5.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.tile = _look("", 1.0, .3)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.216, .06))
	_looks.white = _look("long_white_tiles", 2.0, .7)
	_looks.white.set_shader_parameter("chroma", .6)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.room = _look("", 1.0, .55)
	_looks.room.set_shader_parameter("glow", .3)
	_looks.room.set_shader_parameter("day_glow", .1)
	_looks.steel = _look("", 1.0, .34, .7)
	_looks.steel.set_shader_parameter("glow", .16)
	_looks.steel.set_shader_parameter("day_glow", .05)
	_looks.sign = _look("", 1.0, .35)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .9)
	_looks.sign.set_shader_parameter("day_glow", .16)
	_looks.display = _look("", 1.0, .3)
	_looks.display.set_shader_parameter("albedo_map", signs)
	_looks.display.set_shader_parameter("glow", .7)
	_looks.display.set_shader_parameter("day_glow", .34)
	_looks.strips = _look("", 1.0, .85)
	_looks.strips.set_shader_parameter("albedo_map", signs)
	_looks.strips.set_shader_parameter("glow", .42)
	_looks.strips.set_shader_parameter("day_glow", .16)
	_looks.cloth = _look("", 1.0, .92)
	_looks.cloth.set_shader_parameter("albedo_map", signs)
	_looks.board = _look("", 1.0, .8)
	_looks.board.set_shader_parameter("albedo_map", signs)
	_looks.lantern = _look("", 1.0, .7)
	_looks.lantern.set_shader_parameter("albedo_map", signs)
	_looks.lantern.set_shader_parameter("glow", 1.1)
	_looks.lantern.set_shader_parameter("day_glow", .1)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .3)
	letters.set_shader_parameter("day_glow", .12)
	_looks.decal = letters

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _tiled(part: String, face: Transform3D, area: Rect2, holes: Array[Rect2], tint: Color, low := .9) -> void:
	for piece: Rect2 in _minus(area, holes):
		var a := face * Vector3(piece.position.x, piece.position.y, 0)
		var b := face * Vector3(piece.position.x, piece.end.y, 0)
		var c := face * Vector3(piece.end.x, piece.end.y, 0)
		var d := face * Vector3(piece.end.x, piece.position.y, 0)
		_kit.quad(part, a, b, c, d, tint, low, 1.0, .75, Vector2(piece.position.x, -piece.position.y))

func _shop_wall() -> void:
	# Oxblood glazed tile round the shop, pale strip tile above it, both 1980s and both tired.
	var f := _front
	var machine := Rect2(1.5, .0, .62, 2.36)
	_tiled("tile", f, Rect2(0, 0, WIDE, GROUND), [DOOR, WINDOW, machine], OXBLOOD)
	# Plinth, where the mop water and the pedals reach.
	for span: Vector2 in [Vector2(0, DOOR.position.x), Vector2(DOOR.end.x, machine.position.x), Vector2(machine.end.x, WIDE)]:
		_kit.quad("plain", f * Vector3(span.x, 0, .008), f * Vector3(span.x, .14, .008), f * Vector3(span.y, .14, .008), f * Vector3(span.y, 0, .008), Color("#3a3431"), .7, .9)
	_reveal(f, DOOR, .16, Color("#3a3834"))
	_reveal(f, machine, .3, Color("#3a3834"))
	_reveal(f, WINDOW, .14, Color("#3a3834"))
	_bar("metal", f, WINDOW.get_center().x, WINDOW.position.y - .03, .05, Vector3(WINDOW.size.x + .1, .05, .16), ALUMINIUM)

func _room() -> void:
	# The room itself: pale tile to shoulder height, cream paint over it, and a mop-grey floor.
	var f := _front
	var x0 := .12
	var x1 := WIDE - .12
	var deep := ROOM_DEEP
	var cream := Color("#d8cfb4")
	var wall := Color("#b8c0b4")
	_kit.quad("room", f * Vector3(x0, 0, -deep), f * Vector3(x0, ROOM_TOP, -deep), f * Vector3(x1, ROOM_TOP, -deep), f * Vector3(x1, 0, -deep), cream, .7, .9)
	_kit.quad("room", f * Vector3(x0, 0, -.1), f * Vector3(x0, 1.2, -.1), f * Vector3(x0, 1.2, -deep), f * Vector3(x0, 0, -deep), wall, .65, .9)
	_kit.quad("room", f * Vector3(x0, 1.2, -.1), f * Vector3(x0, ROOM_TOP, -.1), f * Vector3(x0, ROOM_TOP, -deep), f * Vector3(x0, 1.2, -deep), cream, .9, .8)
	_kit.quad("room", f * Vector3(x1, 0, -deep), f * Vector3(x1, ROOM_TOP, -deep), f * Vector3(x1, ROOM_TOP, -.1), f * Vector3(x1, 0, -.1), Color("#b6bab6"), .7, .85)
	_kit.quad("room", f * Vector3(x0, .03, -.1), f * Vector3(x0, .03, -deep), f * Vector3(x1, .03, -deep), f * Vector3(x1, .03, -.1), Color("#5f5c55"), .7, .7)
	_kit.quad("room", f * Vector3(x0, ROOM_TOP, -deep), f * Vector3(x0, ROOM_TOP, -.1), f * Vector3(x1, ROOM_TOP, -.1), f * Vector3(x1, ROOM_TOP, -deep), Color("#cdc4a8"), .75, .75)
	# Tile joints on the wainscot, and the menu strips stuck above it.
	var z := -.4
	while z > -deep:
		_kit.quad("room", f * Vector3(x0 + .004, 0, z), f * Vector3(x0 + .004, 1.2, z), f * Vector3(x0 + .004, 1.2, z - .006), f * Vector3(x0 + .004, 0, z - .006), Color("#8d9488"))
		z -= .15
	_kit.atlas("strips", f * Vector3(x0 + .01, 1.34, -1.2), f * Vector3(x0 + .01, 1.95, -1.2), f * Vector3(x0 + .01, 1.95, -2.1), f * Vector3(x0 + .01, 1.34, -2.1), _cell(920, 760, 480, 320))
	_kit.atlas("strips", f * Vector3(x0 + .01, 1.34, -3.2), f * Vector3(x0 + .01, 1.95, -3.2), f * Vector3(x0 + .01, 1.95, -4.1), f * Vector3(x0 + .01, 1.34, -4.1), _cell(920, 760, 480, 320))
	_kit.atlas("strips", f * Vector3(x0 + .01, 1.3, -4.8), f * Vector3(x0 + .01, 1.86, -4.8), f * Vector3(x0 + .01, 1.86, -5.2), f * Vector3(x0 + .01, 1.3, -5.2), _cell(220, 1420, 300, 420))
	# Two twin battens, the only lighting anyone has ever wanted in a ramen shop.
	for y: float in [-2.0, -4.6]:
		_kit.block("metal", _at(f, 1.6, ROOM_TOP - .03, y), Vector3(.14, .05, 1.26), Color("#d7d4c8"))
		_kit.block("lamp", _at(f, 1.56, ROOM_TOP - .07, y), Vector3(.03, .03, 1.2), Color(.9, .92, .8))
		_kit.block("lamp", _at(f, 1.64, ROOM_TOP - .07, y), Vector3(.03, .03, 1.2), Color(.9, .92, .8))

func _counter() -> void:
	# Eleven stools down one counter: orange formica, a steel edge, and the same tray at each pair.
	var f := _front
	var x := 2.02
	var near := -1.15
	var far := -6.5
	var run := far - near
	var middle := (near + far) * .5
	_bar("room", f, x + .12, .46, middle, Vector3(.1, .92, -run), Color("#6b4a32"))
	_bar("room", f, x, .955, middle, Vector3(.52, .05, -run), FORMICA)
	_bar("steel", f, x - .262, .955, middle, Vector3(.012, .06, -run), CHROME)
	# The raised lip the bowls are handed over.
	_bar("room", f, x + .26, 1.11, middle, Vector3(.1, .27, -run), Color("#7a5a3c"))
	_bar("room", f, x + .2, 1.25, middle, Vector3(.3, .03, -run), Color("#a8835a"))
	var at := near - .3
	var seat := 0
	while at > far + .1:
		_stool(f * Vector3(x - .62, 0, at))
		if seat % 2 == 0:
			_tray(f * Vector3(x + .06, .98, at - .25))
		seat += 1
		at -= .49

func _stool(base: Vector3) -> void:
	# Chrome stem, a round red pad split along one seam and taped.
	_kit.lathe("room", base + Vector3.UP * .03, [Vector2(.17, 0), Vector2(.15, .03), Vector2(.03, .05), Vector2(.03, .62)], CHROME * .8, 10)
	_kit.lathe("room", base + Vector3.UP * .64, [Vector2(.03, 0), Vector2(.165, .02), Vector2(.17, .07), Vector2(.14, .1), Vector2(0, .11)], Color("#8e231c"), 12)

func _tray(at: Vector3) -> void:
	# Chopsticks in a steel pot, soy, vinegar, chilli oil, a stack of small plates.
	_kit.lathe("steel", at, [Vector2(.04, 0), Vector2(.045, .03), Vector2(.03, .05), Vector2(.03, .19), Vector2(.036, .2)], CHROME, 8)
	for i: int in range(5):
		var angle := float(i) * 1.26
		var tip := at + Vector3(cos(angle) * .02, .285, sin(angle) * .02)
		_kit.tube("room", [at + Vector3(0, .15, 0), tip], .004, Color("#d9c49a"), 3)
	for row: Array in [[Vector3(.09, 0, .08), Color("#2a1a12")], [Vector3(.09, 0, .15), Color("#7a2a12")], [Vector3(.02, 0, .13), Color("#c23a18")]]:
		_kit.lathe("room", at + row[0], [Vector2(.024, 0), Vector2(.024, .08), Vector2(.012, .1), Vector2(.014, .13)], row[1], 7)
		_kit.lathe("room", at + (row[0] as Vector3) + Vector3.UP * .128, [Vector2(.016, 0), Vector2(.012, .025), Vector2(0, .03)], Color("#b12a22"), 6)
	_kit.lathe("room", at + Vector3(-.07, 0, .12), [Vector2(.05, 0), Vector2(.07, .05)], Color("#dfe6ea"), 10)
	_kit.lathe("room", at + Vector3(-.07, .012, .12), [Vector2(.05, 0), Vector2(.07, .05)], Color("#cfd8de"), 10)

func _kitchen() -> void:
	# Behind the lip: steel benches, a range of stockpots and a hood that stains the ceiling.
	var f := _front
	var x := WIDE - .42
	var near := -1.7
	var far := -6.9
	var run := near - far
	var middle := (near + far) * .5
	_bar("steel", f, x, .44, middle, Vector3(.56, .88, run), Color("#a9adae"))
	_bar("steel", f, x, .895, middle, Vector3(.6, .03, run), Color("#c4c8ca"))
	var pots: Array[float] = [.34, .3, .27, .34]
	var z := -2.3
	for i: int in range(pots.size()):
		var r := pots[i] * .62
		var tall := .34 + .1 * float(i % 2)
		_kit.lathe("steel", f * Vector3(x, .91, z), [Vector2(r - .01, 0), Vector2(r, .02), Vector2(r, tall), Vector2(r + .012, tall + .01), Vector2(r - .02, tall + .02)], Color("#b6babc"), 14)
		_kit.disc("room", f * Vector3(x, .91 + tall - .01, z), Vector3.RIGHT, Vector3.FORWARD, r - .02, Color("#a87a3e"))
		z -= .6
	# Boiler with its timed baskets on the hook, a rack of bowls over it.
	_bar("steel", f, WIDE - .36, 1.55, middle, Vector3(.44, .03, run), Color("#b4b8ba"))
	for i: int in range(16):
		var along := near - .2 - float(i) * .32
		for k: int in range(2 + i % 2):
			_kit.lathe("room", f * Vector3(WIDE - .36, 1.565 + float(k) * .04, along), [Vector2(.04, 0), Vector2(.1, .08)], Color("#f0ebe0"), 10)
			_kit.lathe("room", f * Vector3(WIDE - .36, 1.565 + float(k) * .04, along), [Vector2(.104, .08), Vector2(.044, 0)], Color("#a8281c"), 10)
	_kit.quad("steel", f * Vector3(WIDE - .12, 2.0, far), f * Vector3(WIDE - .12, 2.5, far), f * Vector3(WIDE - .9, 2.5, far), f * Vector3(WIDE - .9, 2.0, far), Color("#9fa3a5"), .7, .7)
	_bar("steel", f, WIDE - .5, 2.32, middle, Vector3(.76, .36, run), Color("#a3a7a9"))
	_kit.quad("lamp", f * Vector3(WIDE - .7, 2.135, far + .2), f * Vector3(WIDE - .7, 2.135, near - .2), f * Vector3(WIDE - .6, 2.135, near - .2), f * Vector3(WIDE - .6, 2.135, far + .2), Color(.9, .84, .66))

func _noodle_room() -> void:
	# 自家製麺: flour sacks and a roller machine set in the window so the street can watch.
	var f := _front
	var x0 := 2.1
	var x1 := WIDE - .12
	_bar("room", f, (x0 + x1) * .5, .3, -.9, Vector3(x1 - x0, .6, .9), Color("#3e3a36"))
	_bar("steel", f, 2.82, .84, -.86, Vector3(.92, .46, .56), Color("#c2c5c3"))
	for y: float in [.98, 1.08]:
		_kit.tube("steel", [f * Vector3(2.42, y, -.58), f * Vector3(3.22, y, -.58)], .046, Color("#dfe1e0"), 10)
	_bar("steel", f, 2.82, 1.2, -.86, Vector3(.7, .1, .4), Color("#8f9493"))
	_kit.lathe("room", f * Vector3(3.3, 1.07, -.84), [Vector2(.06, 0), Vector2(.13, .04), Vector2(.13, .08), Vector2(.03, .1)], Color("#2a2c30"), 12)
	for row: Array in [[Vector3(2.3, .6, -1.5), Color("#c9c0a8")], [Vector3(2.76, .6, -1.5), Color("#d3cbb6")], [Vector3(2.5, .86, -1.46), Color("#c2b9a0")]]:
		_kit.block("room", _at(f, (row[0] as Vector3).x, (row[0] as Vector3).y + .12, (row[0] as Vector3).z), Vector3(.46, .26, .34), row[1], .7, 1.0)
	var y := .62
	for i: int in range(6):
		_bar("room", f, 3.34, y, -1.3, Vector3(.42, .1, .3), Color("#2c5fa8") if i % 2 == 0 else Color("#c23a24"))
		y += .1
	_kit.quad("lamp", f * Vector3(2.3, ROOM_TOP - .12, -.9), f * Vector3(2.3, ROOM_TOP - .12, -.5), f * Vector3(3.4, ROOM_TOP - .12, -.5), f * Vector3(3.4, ROOM_TOP - .12, -.9), Color(.8, .78, .66))
	_kit.quad("front", f * Vector3(WINDOW.position.x, WINDOW.position.y, -.1), f * Vector3(WINDOW.position.x, WINDOW.end.y, -.1), f * Vector3(WINDOW.end.x, WINDOW.end.y, -.1), f * Vector3(WINDOW.end.x, WINDOW.position.y, -.1), Color.WHITE)
	for x: float in [WINDOW.position.x + .025, WINDOW.end.x - .025]:
		_bar("metal", f, x, WINDOW.get_center().y, -.08, Vector3(.05, WINDOW.size.y, .06), ALUMINIUM)
	for y2: float in [WINDOW.position.y + .025, WINDOW.end.y - .025]:
		_bar("metal", f, WINDOW.get_center().x, y2, -.08, Vector3(WINDOW.size.x, .05, .06), ALUMINIUM)
	# 自家製麺 lettering stuck on inside the glass, sun-faded, and the photo strip over the window.
	_panel("display", f, 2.2, 3.52, 2.24, 2.68, .035, _cell(0, 760, 900, 300))
	_bar("metal", f, 2.86, 2.46, .012, Vector3(1.38, .5, .03), Color("#1c1b1a"))

func _door() -> void:
	# Two sliding aluminium leaves with a kick plate, one left half-open against the lunch queue.
	var f := _front
	var mid := DOOR.get_center().x
	_kit.quad("front", f * Vector3(DOOR.position.x, DOOR.position.y, -.12), f * Vector3(DOOR.position.x, DOOR.end.y, -.12), f * Vector3(mid + .02, DOOR.end.y, -.12), f * Vector3(mid + .02, DOOR.position.y, -.12), Color.WHITE)
	_kit.quad("front", f * Vector3(mid - .02, DOOR.position.y, -.09), f * Vector3(mid - .02, DOOR.end.y, -.09), f * Vector3(DOOR.end.x, DOOR.end.y, -.09), f * Vector3(DOOR.end.x, DOOR.position.y, -.09), Color.WHITE)
	for x: float in [DOOR.position.x + .03, mid, DOOR.end.x - .03]:
		_bar("metal", f, x, DOOR.get_center().y, -.08, Vector3(.05, DOOR.size.y, .05), ALUMINIUM)
	_bar("metal", f, mid, DOOR.end.y - .03, -.08, Vector3(DOOR.size.x, .06, .05), ALUMINIUM)
	_bar("metal", f, DOOR.position.x + .3, .17, -.115, Vector3(.54, .3, .012), ALUMINIUM * .9)
	_bar("metal", f, DOOR.end.x - .3, .17, -.085, Vector3(.54, .3, .012), ALUMINIUM * .9)
	_bar("metal", f, mid - .07, 1.05, -.1, Vector3(.025, .32, .03), STEEL)
	_bar("metal", f, mid + .07, 1.05, -.07, Vector3(.025, .32, .03), STEEL)
	_bar("plain", f, DOOR.get_center().x, .03, .2, Vector3(1.2, .02, .6), Color("#23201d"))

func _ticket_machine() -> void:
	# 券売機 in its own hole in the wall, with a dented steel sill and the coin tray worn bright.
	var f := _front
	var x := 1.81
	_bar("metal", f, x, 1.08, -.14, Vector3(.58, 2.1, .32), Color("#d3cfc2"))
	_panel("display", f, x - .27, x + .27, .28, 1.94, .022, _cell(1420, 0, 400, 900))
	_bar("metal", f, x, 2.02, .02, Vector3(.58, .1, .06), Color("#4a4c4e"))
	_bar("lamp", f, x, 2.2, -.05, Vector3(.4, .03, .05), Color(.9, .92, .84))
	_bar("led", f, x + .2, 1.98, .056, Vector3(.1, .03, .01), GREEN * .7)

func _fascia() -> void:
	# Lightbox the whole width of the shop, under a tin hood, bowed where a van once clipped it.
	var f := _front
	_bar("metal", f, WIDE * .5, 3.02, .14, Vector3(WIDE, .68, .28), Color("#3b3a38"), .8, 1.0)
	_panel("sign", f, .05, WIDE - .05, 2.72, 3.32, .285, _cell(0, 0, 1400, 300))
	_bar("metal", f, WIDE * .5, 3.38, .2, Vector3(WIDE + .06, .04, .42), STEEL)
	_bar("metal", f, WIDE * .5, 2.68, .14, Vector3(WIDE + .02, .03, .3), STEEL)
	_kit.quad("lamp", f * Vector3(.2, 2.66, .28), f * Vector3(.2, 2.66, .04), f * Vector3(1.5, 2.66, .04), f * Vector3(1.5, 2.66, .28), Color(1.0, .82, .6))

func _noren() -> void:
	# Four indigo drops on a pole over the door, weighted by nothing but a decade of steam.
	var f := _front
	var x0 := DOOR.position.x - .02
	var drop := .78
	var top := 2.42
	var wide := (DOOR.size.x + .04) / 4.0
	var rect := _cell(0, 320, 1200, 420)
	_kit.tube("metal", [f * Vector3(x0 - .08, top + .02, .1), f * Vector3(x0 + wide * 4.0 + .08, top + .02, .1)], .014, Color("#5c4128"), 6)
	for i: int in range(4):
		var left := x0 + float(i) * wide + .012
		var right := left + wide - .024
		var columns := 5
		for c: int in range(columns):
			var u0 := float(c) / float(columns)
			var u1 := float(c + 1) / float(columns)
			var a0 := lerpf(left, right, u0)
			var a1 := lerpf(left, right, u1)
			var w0 := .1 + sin(u0 * 7.0 + float(i) * 1.9) * .016
			var w1 := .1 + sin(u1 * 7.0 + float(i) * 1.9) * .016
			var patch := Rect2(0.0, 320.0 / 2048.0, 1200.0 / 2048.0, 420.0 / 2048.0)
			patch.position.x = (float(i) + u0) * .25 * rect.size.x
			patch.size.x = .25 * rect.size.x / float(columns)
			_kit.atlas("cloth", f * Vector3(a0, top - drop, w0 + .014), f * Vector3(a0, top, .1), f * Vector3(a1, top, .1), f * Vector3(a1, top - drop, w1 + .014), patch, Color.WHITE, .9, .2)
			_kit.atlas("cloth", f * Vector3(a1, top - drop, w1 + .012), f * Vector3(a1, top, .098), f * Vector3(a0, top, .098), f * Vector3(a0, top - drop, w0 + .012), patch, Color(.4, .4, .45), .7)

func _lantern() -> void:
	# 赤提灯 by the door, the paper gone pink on its sunny side.
	var at := _front * Vector3(2.14, 2.2, .36)
	_kit.tube("metal", [_front * Vector3(2.14, 2.68, .08), _front * Vector3(2.14, 2.64, .36), at + Vector3.UP * .36], .008, Color("#1a1a1a"), 4)
	_kit.lathe("metal", at + Vector3.UP * .315, [Vector2(.1, 0), Vector2(.1, .05)], Color("#141414"), 12)
	_kit.lathe("metal", at + Vector3.DOWN * .31, [Vector2(.1, 0), Vector2(.1, .04)], Color("#141414"), 12)
	var profile: Array[Vector2] = [Vector2(.1, -.28), Vector2(.17, -.2), Vector2(.2, -.08), Vector2(.21, 0), Vector2(.2, .08), Vector2(.17, .2), Vector2(.1, .3)]
	_kit.lathe("lantern", at, profile, Color.WHITE, 18, _cell(1440, 1480, 500, 300))

func _upper_front() -> void:
	# Strip-tile above the shop: the mahjong room's wide sash, then the flat with its rail.
	var f := _front
	var low := Rect2(.34, GROUND + .6, 2.5, 1.42)
	var flat := Rect2(.34, GROUND + STOREY + .1, 2.5, 2.0)
	_tiled("white", f, Rect2(0, GROUND, WIDE, PARAPET - GROUND), [low, flat], Color(.82, .79, .7), .7)
	_window(f, low, .19, false)
	_panel("decal", f, low.position.x + .1, low.end.x - .1, low.position.y + .52, low.position.y + 1.0, .004, _cell(540, 1420, 880, 170))
	_panel("decal", f, low.position.x + .22, low.end.x - .22, low.position.y + .3, low.position.y + .52, .004, _cell(540, 1600, 880, 110))
	_window(f, flat, .61, false)
	_bar("plain", f, WIDE * .5, PARAPET + .04, -.04, Vector3(WIDE + .06, .08, .24), Color("#7b786f"), .7, 1.0)
	_bar("plain", f, WIDE * .5, GROUND + STOREY, .02, Vector3(WIDE, .1, .06), Color("#8d8a7f"), .8, 1.0)
	# A shallow steel balcony rail, a drying pole and a week's washing.
	var rail := Color("#6f7270")
	_bar("metal", f, 1.59, GROUND + STOREY + .06, .28, Vector3(2.9, .06, .56), rail, .8, 1.0)
	_kit.tube("metal", [f * Vector3(.12, GROUND + STOREY + .96, .54), f * Vector3(3.06, GROUND + STOREY + .96, .54)], .018, rail, 6)
	for i: int in range(16):
		var x := .16 + float(i) * .194
		_bar("metal", f, x, GROUND + STOREY + .5, .54, Vector3(.016, .9, .016), rail)
	_kit.tube("metal", [f * Vector3(.3, GROUND + STOREY + 1.72, .4), f * Vector3(2.9, GROUND + STOREY + 1.72, .4)], .012, Color("#b9bcc0"), 6)
	var hung: Array[Color] = [Color("#dfe0e4"), Color("#37507a"), Color("#d9c8b0"), Color("#c0c4c8"), Color("#7a3b3b")]
	var x2 := .5
	for i: int in range(5):
		var wide := _rng.randf_range(.26, .5)
		var long := _rng.randf_range(.5, .82)
		_kit.quad("plain", f * Vector3(x2, GROUND + STOREY + 1.72 - long, .42), f * Vector3(x2, GROUND + STOREY + 1.72, .4), f * Vector3(x2 + wide, GROUND + STOREY + 1.72, .4), f * Vector3(x2 + wide, GROUND + STOREY + 1.72 - long, .42), hung[i], .85, 1.0)
		_kit.quad("plain", f * Vector3(x2 + wide, GROUND + STOREY + 1.72 - long, .4), f * Vector3(x2 + wide, GROUND + STOREY + 1.72, .39), f * Vector3(x2, GROUND + STOREY + 1.72, .39), f * Vector3(x2, GROUND + STOREY + 1.72 - long, .4), hung[i].darkened(.3), .8, 1.0)
		x2 += wide + .08
	_outdoor_unit(f, 2.45, GROUND + STOREY + .34, .24)
	# 2050: a drop shelf for the delivery drones, bolted on where the mahjong sign used to be.
	_bar("metal", f, 3.28, GROUND + 1.0, .3, Vector3(.54, .05, .6), Color("#3a3d40"))
	_bar("metal", f, 3.28, GROUND + 1.28, .03, Vector3(.54, .6, .06), Color("#2a2c2f"))
	_strip(f * Vector3(3.03, GROUND + 1.03, .6), f * Vector3(3.53, GROUND + 1.03, .6), CYAN * .7)
	_status(f, 3.28, GROUND + 1.42, .065, GREEN)
	_camera(f * Vector3(.12, 3.5, .18))
	_fibre([f * Vector3(.08, PARAPET - .1, .04), f * Vector3(.08, 3.45, .04)])

func _duct() -> void:
	# Kitchen exhaust, up the outside in square steel, with the grease it has wept down the tile.
	var f := _front
	var x := WIDE - .2
	var tint := Color("#a2a5a4")
	_bar("metal", f, x, (3.44 + PARAPET + 1.0) * .5, .16, Vector3(.3, PARAPET + 1.0 - 3.44, .3), tint, .7, 1.0)
	var y := 3.6
	while y < PARAPET + .9:
		_bar("metal", f, x, y, .16, Vector3(.33, .03, .33), tint.darkened(.2))
		y += 1.0
	for y2: float in [4.3, 6.2, 8.1]:
		_bar("metal", f, x, y2, .02, Vector3(.42, .05, .04), STEEL)
	_kit.quad("plain", f * Vector3(x - .22, 3.4, .012), f * Vector3(x - .2, 7.4, .012), f * Vector3(x - .15, 7.4, .012), f * Vector3(x - .15, 3.4, .012), Color(.2, .15, .1, 1.0), .9, 1.0)
	_kit.lathe("metal", f * Vector3(x, PARAPET + 1.0, .16), [Vector2(.14, 0), Vector2(.14, .16), Vector2(.3, .22), Vector2(.3, .26), Vector2(.02, .38)], tint.darkened(.1), 10)

func _blade() -> void:
	# 袖看板 out over the pavement from the first floor, lit from inside.
	var f := _front
	var x := .08
	var low := 3.5
	var high := 5.6
	var near := .22
	var far := .86
	_bar("metal", f, x, (low + high) * .5, (near + far) * .5, Vector3(.1, high - low + .06, far - near + .06), Color("#2c2b2a"))
	_kit.atlas("sign", f * Vector3(x + .054, low, far), f * Vector3(x + .054, high, far), f * Vector3(x + .054, high, near), f * Vector3(x + .054, low, near), _cell(0, 1420, 200, 620))
	_kit.atlas("sign", f * Vector3(x - .054, low, near), f * Vector3(x - .054, high, near), f * Vector3(x - .054, high, far), f * Vector3(x - .054, low, far), _cell(0, 1420, 200, 620))
	for y: float in [low + .25, high - .25]:
		_bar("metal", f, x, y, .1, Vector3(.05, .05, .24), STEEL)

func _rooftop() -> void:
	var half := WIDE * .5
	var level := TOP + .02
	_kit.quad("plain", Vector3(-half, level, 0), Vector3(-half, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, 0), Color("#5e5e5a"), .8, .9)
	var inner := Color(.74, .72, .66)
	_kit.quad("render", Vector3(half - .02, level, -.02), Vector3(half - .02, PARAPET, -.02), Vector3(-half + .02, PARAPET, -.02), Vector3(-half + .02, level, -.02), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(-half + .02, level, -DEEP), Vector3(-half + .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, level, -DEEP), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(-half + .02, level, -.02), Vector3(-half + .02, PARAPET, -.02), Vector3(-half + .02, PARAPET, -DEEP), Vector3(-half + .02, level, -DEEP), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(half - .02, level, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -.02), Vector3(half - .02, level, -.02), inner, .7, 1.0, .5)
	_kit.block("render", Transform3D(Basis.IDENTITY, Vector3(.4, TOP + 1.1, -6.6)), Vector3(1.9, 2.2, 2.4), RENDER * .9, .75, 1.0, .7)
	var tank := Vector3(-.8, TOP + .3, -3.6)
	_kit.lathe("plain", tank, [Vector2(.5, 0), Vector2(.54, .08), Vector2(.54, .96), Vector2(.36, 1.14), Vector2(.02, 1.18)], Color("#a9b6b8"), 12)
	_solar_module(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-62.0)), Vector3(.5, TOP + .86, -3.7)), 1.6, 1.0)
	for x: float in [-.9, .1]:
		_outdoor_unit(Transform3D(Basis.IDENTITY, Vector3(x, level, 0)), 0, .4, -1.3)

func _street_things() -> void:
	# What a ramen shop keeps on the pavement: the board, crates, a bucket, a delivery bike.
	var f := _front
	var at := Vector3(2.7, 0, .64)
	var top := .96
	var lean := .1
	_kit.atlas("board", f * (at + Vector3(-.27, .04, lean)), f * (at + Vector3(-.27, top, 0)), f * (at + Vector3(.27, top, 0)), f * (at + Vector3(.27, .04, lean)), _cell(1440, 920, 360, 540))
	_kit.quad("plain", f * (at + Vector3(.27, .04, -lean)), f * (at + Vector3(.27, top, 0)), f * (at + Vector3(-.27, top, 0)), f * (at + Vector3(-.27, .04, -lean)), Color("#23211e"))
	_crate(f, 3.34, 0, .3, Color("#2c5fa8"))
	_crate(f, 3.34, .31, .3, Color("#b8452a"))
	_kit.lathe("plain", f * Vector3(.1, 0, .3), [Vector2(.12, 0), Vector2(.15, .3)], Color("#3a6a9a"), 10)
	_parked_bicycle(f * Vector3(1.5, 0, .72), Color("#7a2a22"))

func _crate(face: Transform3D, x: float, y: float, z: float, tint: Color) -> void:
	# Plastic noodle crate: open slats on all four sides, so the street shows through it.
	var wide := .44
	var deep := .32
	var tall := .3
	_bar("plain", face, x, y + .012, z, Vector3(wide, .024, deep), tint.darkened(.25))
	for level: float in [.13, .29]:
		_bar("plain", face, x, y + level, z - deep * .5 + .012, Vector3(wide, .03, .024), tint)
		_bar("plain", face, x, y + level, z + deep * .5 - .012, Vector3(wide, .03, .024), tint)
		_bar("plain", face, x - wide * .5 + .012, y + level, z, Vector3(.024, .03, deep), tint)
		_bar("plain", face, x + wide * .5 - .012, y + level, z, Vector3(.024, .03, deep), tint)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bar("plain", face, x + sx * (wide * .5 - .018), y + tall * .5, z + sz * (deep * .5 - .018), Vector3(.036, tall, .036), tint.darkened(.1))
		for i: int in range(3):
			_bar("plain", face, x + (float(i) - 1.0) * .12, y + tall * .5, z + sx * (deep * .5 - .012), Vector3(.02, tall, .016), tint.darkened(.15))