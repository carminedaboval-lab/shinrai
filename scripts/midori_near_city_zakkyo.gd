extends "res://scripts/midori_near_city_handmade.gd"
## 第三みやこビル: a 1991 zakkyo tower in stained white tile, nine floors of tenants who
## have nothing to do with each other. An arcade holds the street, a steel fire stair is
## cut into the sunny corner, and the top floor has gone dark to a rack of servers.
const ATLAS := "res://assets/shinrai/near_city/zakkyo_atlas.png"
const FLOOR_ART := "res://assets/shinrai/near_city/zakkyo_floors.png"
const WIDE := 8.2
const DEEP := 9.4
const GROUND := 4.0
const STOREY := 3.2
const FLOORS := 8
const TOP := 29.6
const PARAPET := 30.4
const STAIR := 1.9 # Width of the open stair bay on the west corner.
const SLOT := 3.4 # How far it cuts back.
const PIER := .32
const SPAN := -.1 # Tile between the piers sits back a little.
const SILL := .95
const HEAD := 2.92
const GLASS := -.3
const ROOM := 1.9
const TILE := Color(.9, .87, .8)
const OXIDE := Color("#6f958e") # Stair paint, thirty repaints deep.
const RENDER := Color(.88, .85, .78)
const ACID := Color(.78, 1.0, .23)
const PINK := Color(1.0, .37, .82)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1991
	_build_looks()
	_frame()
	for floor_index: int in range(FLOORS):
		_storey(floor_index)
	_arcade()
	_lift_lobby()
	_stair_walls()
	_stairs()
	_blades()
	_west_wall()
	_east_wall()
	_render_wall(_back, WIDE, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2])
	_rooftop()
	_retrofit()
	_standee()
	_kit.commit(self, _looks, ["front", "decal", "notice", "poster", "ghost", "lamp", "led", "neon", "room", "carpet", "arcade", "sign", "hall"])
	_kit = null
	_omni("ArcadeSpill", Vector3(.4, 2.6, 1.2), Color(.86, 1.0, .72), 1.0, 7.5)
	_omni("ArcadeRoom", Vector3(.2, 2.6, -3.4), Color(.9, .6, 1.0), .45, 7.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.tile = _look("", 1.0, .38)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.2, .06))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.paint = _look("rusty_painted_metal", 2.2, 1.0)
	_looks.paint.set_shader_parameter("chroma", .6)
	_looks.room = _look("", 1.0, .7)
	_looks.room.set_shader_parameter("glow", .4)
	_looks.room.set_shader_parameter("day_glow", .14)
	_looks.hall = _look("", 1.0, .6)
	_looks.hall.set_shader_parameter("glow", .24)
	_looks.hall.set_shader_parameter("day_glow", .1)
	_looks.carpet = _look("", 1.0, .9)
	_looks.carpet.set_shader_parameter("tile_size", Vector2(.5, .5))
	_looks.carpet.set_shader_parameter("glow", .3)
	_looks.carpet.set_shader_parameter("day_glow", .16)
	_looks.arcade = _look("", 1.0, .4)
	_looks.arcade.set_shader_parameter("albedo_map", signs)
	_looks.arcade.set_shader_parameter("glow", .75)
	_looks.arcade.set_shader_parameter("day_glow", .4)
	_looks.sign = _look("", 1.0, .35)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .62)
	_looks.sign.set_shader_parameter("day_glow", .1)
	_looks.painted = _look("", 1.0, .6)
	_looks.painted.set_shader_parameter("albedo_map", signs)
	_looks.cedar = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.cedar.set_shader_parameter("chroma", .6)
	var floors: Texture2D = load(FLOOR_ART)
	_looks.poster = _look("", 1.0, .4)
	_looks.poster.set_shader_parameter("albedo_map", floors)
	_looks.poster.set_shader_parameter("glow", .55)
	_looks.poster.set_shader_parameter("day_glow", .3)
	var notices := ShaderMaterial.new()
	notices.shader = DECAL_SHADER
	notices.set_shader_parameter("atlas", floors)
	notices.set_shader_parameter("glow", .5)
	notices.set_shader_parameter("day_glow", .28)
	_looks.notice = notices
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .55)
	letters.set_shader_parameter("day_glow", .24)
	_looks.decal = letters
	var ghost := ShaderMaterial.new()
	ghost.shader = DECAL_SHADER
	ghost.set_shader_parameter("atlas", signs)
	_looks.ghost = ghost

func _tile(face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, low := .9, high := 1.0, streak := .55) -> void:
	_kit.quad("tile", face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), TILE, low, high, streak, Vector2(x0, -y0))

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE, ao := 1.0) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint, ao)

func _floor_y(index: int) -> float:
	return GROUND + float(index) * STOREY

func _frame() -> void:
	# Piers either side of the tenants' bay, a band of tile to finish, a pre-cast coping.
	var f := _front
	for x: float in [STAIR, WIDE - PIER]:
		_tile(f, x, x + PIER, 0.0, PARAPET, 0.0, .86, .96)
		var ret := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x + PIER, 0, 0))
		_tile(ret, 0.0, -SPAN, GROUND, PARAPET, 0.0, .7, .8)
		ret = Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x, 0, SPAN))
		_tile(ret, 0.0, -SPAN, GROUND, PARAPET, 0.0, .7, .8)
	_tile(f, STAIR + PIER, WIDE - PIER, TOP, PARAPET, SPAN, .85, .95)
	_bar("render", f, (STAIR + WIDE) * .5, PARAPET + .05, -.08, Vector3(WIDE - STAIR + .1, .1, .3), RENDER, .7, 1.0)

func _storey(index: int) -> void:
	# No two tenants ever agreed on a shopfront, and none of them asked the landlord.
	var base := _floor_y(index)
	var x0 := STAIR + PIER
	var x1 := WIDE - PIER
	match index:
		0: _pawn_front(base, x0, x1)
		1: _mahjong_front(base, x0, x1)
		2: _neuro_front(base, x0, x1)
		3: _dive_front(base, x0, x1)
		4: _karaoke_front(base, x0, x1)
		5: _bar_front(base, x0, x1)
		6: _detective_front(base, x0, x1)
		7:
			var holes: Array[Rect2] = [Rect2(x0, base + SILL, x1 - x0, HEAD - SILL)]
			_band(x0, x1, base, holes)
			_data_floor(base, x0, x1)

func _band(x0: float, x1: float, base: float, holes: Array[Rect2]) -> void:
	# The original 1991 tile, wherever a tenant has not covered it.
	for piece: Rect2 in _minus(Rect2(x0, base, x1 - x0, STOREY), holes):
		_tile(_front, piece.position.x, piece.end.x, piece.position.y, piece.end.y, SPAN, .8, .96, .65)

func _clad(part: String, x0: float, x1: float, base: float, hole: Rect2, tint: Color) -> void:
	# Panels a tenant fixed straight over the tile, cut round their window.
	var holes: Array[Rect2] = [hole]
	for piece: Rect2 in _minus(Rect2(x0, base + .02, x1 - x0, STOREY - .04), holes):
		var mid := piece.get_center()
		_bar(part, _front, mid.x, mid.y, SPAN + .04, Vector3(piece.size.x, piece.size.y, .08), tint)

func _opening(r: Rect2, frame: Color, lights: int) -> void:
	var f := _front
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	_reveal(f.translated_local(Vector3(0, 0, SPAN)), r, -GLASS + SPAN, Color("#6c6e6c"))
	_kit.quad("front", f * Vector3(x0, y0, GLASS), f * Vector3(x0, y1, GLASS), f * Vector3(x1, y1, GLASS), f * Vector3(x1, y0, GLASS), Color.WHITE)
	for i: int in range(lights + 1):
		_bar("metal", f, x0 + r.size.x * float(i) / float(lights), (y0 + y1) * .5, GLASS + .03, Vector3(.05, r.size.y, .08), frame)
	for y: float in [y0 + .025, y1 - .025]:
		_bar("metal", f, (x0 + x1) * .5, y, GLASS + .03, Vector3(r.size.x, .05, .08), frame)

func _pawn_front(base: float, x0: float, x1: float) -> void:
	# Red board over a barred window, and today's prices taped up behind the bars.
	var f := _front
	var r := Rect2(x0, base + SILL, x1 - x0, 1.46)
	var holes: Array[Rect2] = [r]
	_band(x0, x1, base, holes)
	_tenant_room(0, x0, x1, base)
	_opening(r, Color("#34373a"), 4)
	var mid := (x0 + x1) * .5
	_bar("plain", f, mid, base + 2.8, .04, Vector3(x1 - x0 + .1, .66, .2), Color("#7a1216"))
	_bar("metal", f, mid, base + 3.14, .06, Vector3(x1 - x0 + .1, .03, .24), Color("#c9a65a"))
	_panel("decal", f, mid - 2.05, mid + 2.05, base + 2.5, base + 3.1, .142, _cell(0, 730, 1000, 150))
	_panel("notice", f, mid - 2.2, mid + 2.2, base + SILL + .04, base + SILL + 1.02, GLASS + .012, _cell(0, 1400, 1024, 228))

func _mahjong_front(base: float, x0: float, x1: float) -> void:
	# Old four-window front, one huge character to a window. Nothing else needs saying.
	var f := _front
	var holes: Array[Rect2] = []
	for i: int in range(4):
		holes.append(Rect2(x0 + .21 + float(i) * 1.38, base + SILL + .05, 1.1, HEAD - SILL - .05))
	_band(x0, x1, base, holes)
	_tenant_room(1, x0, x1, base)
	for i: int in range(4):
		var r := holes[i]
		_opening(r, Color("#7d8a7f"), 2)
		var c := r.get_center()
		_panel("notice", f, c.x - .47, c.x + .47, c.y - .47, c.y + .47, GLASS + .012, _cell(1040.0 + float(i) * 240.0, 1160, 240, 240))

func _neuro_front(base: float, x0: float, x1: float) -> void:
	# The one refit floor: white panels, a wall of glass and a frosted band of calm.
	var f := _front
	var r := Rect2(x0, base + .16, x1 - x0, 2.86)
	var white := Color("#e6e9e8")
	_bar("plain", f, (x0 + x1) * .5, base + .08, SPAN + .02, Vector3(x1 - x0, .16, .12), white, .85, 1.0)
	_bar("plain", f, (x0 + x1) * .5, base + 3.11, SPAN + .02, Vector3(x1 - x0, .18, .12), white, .85, 1.0)
	_tenant_room(2, x0, x1, base)
	_opening(r, Color("#d8dcdb"), 3)
	_panel("notice", f, x0 + .04, x1 - .04, base + .2, base + 1.44, GLASS + .012, _cell(0, 1160, 1024, 228))

func _dive_front(base: float, x0: float, x1: float) -> void:
	# Black panels and a lit image the whole width of the floor: you are already under.
	var f := _front
	var r := Rect2(x0 + .1, base + .62, x1 - x0 - .2, 1.9)
	_clad("metal", x0, x1, base, r, Color("#0e1116"))
	_opening(r, Color("#0a0c10"), 1)
	_panel("poster", f, r.position.x, r.end.x, r.position.y, r.end.y, GLASS - .012, _cell(0, 440, 2048, 712))
	var z := SPAN + .09
	_strip(f * Vector3(r.position.x, r.position.y - .04, z), f * Vector3(r.end.x, r.position.y - .04, z), CYAN)
	_strip(f * Vector3(r.position.x, r.end.y + .04, z), f * Vector3(r.end.x, r.end.y + .04, z), CYAN)

func _karaoke_front(base: float, x0: float, x1: float) -> void:
	# Loud purple cladding, the food on vinyl along the glass, the booths above it.
	var f := _front
	var r := Rect2(x0 + .1, base + .5, x1 - x0 - .2, 2.08)
	_clad("plain", x0, x1, base, r, Color("#7f1d86"))
	_tenant_room(4, x0, x1, base)
	_opening(r, Color("#2a0f33"), 3)
	_panel("poster", f, r.position.x, r.end.x, r.position.y, r.position.y + 1.12, GLASS - .012, _cell(0, 0, 2048, 420))
	var mid := (x0 + x1) * .5
	_panel("decal", f, mid - 1.7, mid + 1.7, base + 2.63, base + 3.14, SPAN + .09, _cell(0, 1050, 1000, 150))
	var z := SPAN + .1
	_neon([f * Vector3(r.position.x - .05, r.position.y - .05, z), f * Vector3(r.position.x - .05, r.end.y + .05, z), f * Vector3(r.end.x + .05, r.end.y + .05, z), f * Vector3(r.end.x + .05, r.position.y - .05, z), f * Vector3(r.position.x - .05, r.position.y - .05, z)], PINK)

func _bar_front(base: float, x0: float, x1: float) -> void:
	# Cedar slats floor to ceiling, one slit of bottles, a porthole. If you must ask, it is not for you.
	var f := _front
	var slit := Rect2(3.65, base + 1.4, 2.8, .62)
	var holes: Array[Rect2] = [slit]
	for piece: Rect2 in _minus(Rect2(x0, base, x1 - x0, STOREY), holes):
		_kit.quad("plain", f * Vector3(piece.position.x, piece.position.y, SPAN), f * Vector3(piece.position.x, piece.end.y, SPAN), f * Vector3(piece.end.x, piece.end.y, SPAN), f * Vector3(piece.end.x, piece.position.y, SPAN), Color("#120c08"))
	_tenant_room(5, x0, x1, base)
	_opening(slit, Color("#1d120a"), 3)
	var low := base + .04
	var high := base + STOREY - .04
	var x := x0 + .05
	while x < x1:
		var tone := Color("#5a3820") * _rng.randf_range(.8, 1.1)
		if x > slit.position.x - .05 and x < slit.end.x + .05:
			_bar("cedar", f, x, (low + slit.position.y) * .5, SPAN + .1, Vector3(.08, slit.position.y - low, .1), tone)
			_bar("cedar", f, x, (slit.end.y + high) * .5, SPAN + .1, Vector3(.08, high - slit.end.y, .1), tone)
		else:
			_bar("cedar", f, x, (low + high) * .5, SPAN + .1, Vector3(.08, high - low, .1), tone)
		x += .13
	_bar("lamp", f, (x0 + x1) * .5, base + .1, SPAN + .03, Vector3(x1 - x0, .02, .02), Color(.55, .34, .14))
	var round_at := f * Vector3(2.9, base + 1.72, SPAN + .16)
	_kit.disc("lamp", round_at, f.basis.x, f.basis.y, .34, Color(.62, .4, .18))
	var ring: Array[Vector3] = []
	for i: int in range(25):
		var angle := TAU * float(i) / 24.0
		ring.append(round_at + (f.basis.x * cos(angle) + f.basis.y * sin(angle)) * .35)
	_kit.tube("metal", ring, .03, Color("#a8854a"), 6)
	_panel("poster", f, 2.62, 3.18, .0 + base + .98, base + 1.16, SPAN + .16, _cell(1350, 1410, 320, 100))

func _detective_front(base: float, x0: float, x1: float) -> void:
	# Two tired sash windows, blinds down, and a name in gold leaf you have to look for.
	var wall := _front.translated_local(Vector3(0, 0, SPAN))
	var near := Rect2(x0 + .55, base + .95, 1.7, 1.62)
	var far := Rect2(x0 + 3.35, base + .95, 1.7, 1.62)
	var holes: Array[Rect2] = [near, far]
	_band(x0, x1, base, holes)
	_window(wall, near, .33, false)
	_window(wall, far, .72, false)
	_venetian(near, .5)
	_venetian(far, 1.0)
	_panel("notice", _front, near.position.x + .22, near.end.x - .22, near.position.y + .22, near.position.y + .56, SPAN - .05, _cell(1350, 1520, 420, 110))

func _venetian(r: Rect2, drop: float) -> void:
	var f := _front
	var z := SPAN - .06
	var y := r.end.y - .04
	while y > r.end.y - r.size.y * drop + .04:
		_kit.quad("plain", f * Vector3(r.position.x + .05, y - .036, z), f * Vector3(r.position.x + .05, y, z + .006), f * Vector3(r.end.x - .05, y, z + .006), f * Vector3(r.end.x - .05, y - .036, z), Color("#b4b6ae"), .85, 1.0)
		y -= .05

func _tenant_room(index: int, x0: float, x1: float, base: float) -> void:
	# Each tenant's own back wall and ceiling, then what they keep in the window.
	var f := _front
	var wall: Color = [Color("#6a2c28"), Color("#8a7d5c"), Color("#b4c6c8"), Color.BLACK, Color("#7a1f7f"), Color("#3a2413")][index]
	var y0 := base
	var y1 := base + 3.04
	var far := GLASS - ROOM
	_kit.quad("room", f * Vector3(x0, y0, far), f * Vector3(x0, y1, far), f * Vector3(x1, y1, far), f * Vector3(x1, y0, far), wall, .8, 1.0)
	_kit.quad("room", f * Vector3(x0, y0, GLASS), f * Vector3(x0, y1, GLASS), f * Vector3(x0, y1, far), f * Vector3(x0, y0, far), wall * .86, .8, 1.0)
	_kit.quad("room", f * Vector3(x1, y0, far), f * Vector3(x1, y1, far), f * Vector3(x1, y1, GLASS), f * Vector3(x1, y0, GLASS), wall * .86, .8, 1.0)
	_kit.quad("room", f * Vector3(x0, y1, far), f * Vector3(x0, y1, GLASS), f * Vector3(x1, y1, GLASS), f * Vector3(x1, y1, far), wall.lightened(.25), .9, .9)
	var sole := base + (.1 if index == 2 else SILL - .4)
	_kit.quad("room", f * Vector3(x0, sole, GLASS), f * Vector3(x0, sole, far), f * Vector3(x1, sole, far), f * Vector3(x1, sole, GLASS), wall.darkened(.45), .8, .8)
	var floor_y := y0 + SILL - .4
	match index:
		0: _pawn_shop(x0, x1, floor_y, far)
		1: _mahjong(x0, x1, floor_y, base)
		2: _neuro(x0, x1, floor_y, base)
		4: _karaoke(x0, x1, floor_y, far)
		5: _bar_room(x0, x1, floor_y, far)

func _pawn_shop(x0: float, x1: float, y: float, far: float) -> void:
	# Lit cases of other people's hands and eyes, behind the shop's own bars.
	var f := _front
	for i: int in range(4):
		var x := x0 + .72 + float(i) * 1.42
		_bar("room", f, x, y + .55, far + .3, Vector3(1.2, 1.1, .4), Color("#3a1a18"))
		for shelf: int in range(3):
			_bar("lamp", f, x, y + .84 + float(shelf) * .36, far + .32, Vector3(1.1, .02, .36), Color(.38, .3, .18))
			for item: int in range(5):
				var tone: Color = [Color("#c9b070"), Color("#9aa4ac"), Color("#e8e0cc")][(item + shelf) % 3]
				_bar("room", f, x - .44 + float(item) * .22, y + .9 + float(shelf) * .36, far + .36, Vector3(.1, .1, .1), tone)
	var rods := 26
	for rod: int in range(rods + 1):
		_bar("metal", f, x0 + (x1 - x0) * float(rod) / float(rods), y + 1.0, GLASS + .05, Vector3(.018, 1.4, .018), Color("#2a2b2d"))

func _mahjong(x0: float, x1: float, y: float, base: float) -> void:
	# Automatic tables under low green-shaded lamps, the way they have always been lit.
	var f := _front
	for i: int in range(3):
		var x := x0 + 1.0 + float(i) * 2.0
		var z := GLASS - .75 - float(i % 2) * .4
		_bar("room", f, x, y + .38, z, Vector3(.8, .76, .8), Color("#2a2c2e"))
		_bar("room", f, x, y + .77, z, Vector3(.86, .03, .86), Color("#1f7a4e"))
		for side: int in range(4):
			var dir := Vector2(1, 0).rotated(float(side) * PI * .5)
			_bar("room", f, x + dir.x * .24, y + .81, z + dir.y * .24, Vector3(.2 if side % 2 == 1 else .03, .03, .03 if side % 2 == 1 else .2), Color("#ece6d2"))
			_kit.lathe("room", f * Vector3(x + dir.x * .62, y, z + dir.y * .62), [Vector2(.17, .45), Vector2(.16, .5), Vector2(.04, .5), Vector2(.04, .02)], Color("#5a4028"), 7)
		_kit.tube("plain", [f * Vector3(x, base + HEAD, z), f * Vector3(x, y + 1.7, z)], .006, Color("#1a1a1a"), 3)
		_kit.lathe("lamp", f * Vector3(x, y + 1.46, z), [Vector2(.42, 0), Vector2(.3, .14), Vector2(.05, .24)], Color(.42, .62, .4), 10)

func _neuro(x0: float, x1: float, y: float, base: float) -> void:
	# A treatment couch and a ring of coils, seen under half-drawn white blinds.
	var f := _front
	var x := x0 + 3.0
	var z := GLASS - .95
	_bar("room", f, x, y + .42, z, Vector3(1.8, .12, .7), Color("#f0f4f4"))
	_bar("room", f, x, y + .2, z, Vector3(.5, .4, .4), Color("#8a9aa0"))
	_kit.tube("room", [f * Vector3(x - .95, y + 1.0, z - .3), f * Vector3(x - .7, y + 1.3, z), f * Vector3(x - .95, y + 1.0, z + .3)], .03, Color("#3fb6d4"), 6)
	_bar("lamp", f, x, base + HEAD - .03, z, Vector3(1.6, .02, .3), Color(.7, .78, .8))
	var drops: Array[float] = [.78, .78, .78, 1.15]
	var bay := (x1 - x0) / 4.0
	for i: int in range(4):
		var low := base + 3.0 - drops[i]
		_kit.quad("plain", f * Vector3(x0 + float(i) * bay + .04, low, GLASS - .03), f * Vector3(x0 + float(i) * bay + .04, base + 3.0, GLASS - .03), f * Vector3(x0 + float(i + 1) * bay - .04, base + 3.0, GLASS - .03), f * Vector3(x0 + float(i + 1) * bay - .04, low, GLASS - .03), Color("#e6e8e4"), .9, 1.0)
		_bar("plain", f, x0 + (float(i) + .5) * bay, low, GLASS - .03, Vector3(bay - .08, .025, .025), Color("#b9bcb8"))

func _karaoke(x0: float, x1: float, y: float, far: float) -> void:
	# Corridor of booth doors, each with its slot of light, and a mirror ball in the window.
	var f := _front
	for i: int in range(5):
		var x := x0 + .6 + float(i) * 1.14
		var tone: Color = [Color("#ff5fd2"), Color("#ffd34e"), Color("#49c8ff"), Color("#ff5f6a"), Color("#a06bff")][i]
		_bar("room", f, x, y + 1.0, far + .03, Vector3(.82, 2.0, .05), Color("#2a0f33"))
		_bar("lamp", f, x + .22, y + 1.1, far + .07, Vector3(.1, 1.2, .01), tone)
	var ball := f * Vector3((x0 + x1) * .5, y + 1.6, GLASS - .6)
	_kit.lathe("metal", ball + Vector3.DOWN * .17, [Vector2(.02, 0), Vector2(.12, .05), Vector2(.17, .17), Vector2(.12, .29), Vector2(.02, .34)], Color("#d8dade"), 10)
	_kit.tube("plain", [ball + Vector3.UP * .17, ball + Vector3.UP * .7], .006, Color("#1a1a1a"), 3)
	_neon([f * Vector3(x0 + .4, y + .75, GLASS - .1), f * Vector3(x0 + .4, y + 1.2, GLASS - .1), f * Vector3(x0 + .72, y + 1.3, GLASS - .1), f * Vector3(x0 + .72, y + .85, GLASS - .1)], PINK)

func _bar_room(x0: float, x1: float, y: float, far: float) -> void:
	# Backlit bottles and nothing else worth seeing from the street.
	var f := _front
	var mid := (x0 + x1) * .5
	_bar("lamp", f, mid, y + 1.28, far + .04, Vector3(3.4, .9, .02), Color(.55, .36, .16))
	for shelf: int in range(2):
		var line := y + .92 + float(shelf) * .42
		_bar("room", f, mid, line, far + .14, Vector3(3.5, .03, .2), Color("#1d120a"))
		for i: int in range(16):
			var tone: Color = [Color("#2e4a2c"), Color("#5a2c16"), Color("#14181c"), Color("#7a6a30")][(i + shelf * 2) % 4]
			_kit.lathe("room", f * Vector3(mid - 1.55 + float(i) * .206, line + .015, far + .14), [Vector2(.04, 0), Vector2(.04, .19), Vector2(.014, .26), Vector2(.014, .32)], tone, 6)
	_bar("room", f, mid, y + .55, GLASS - .95, Vector3(4.2, 1.1, .5), Color("#2a1a10"))
	_bar("room", f, mid, y + 1.12, GLASS - .95, Vector3(4.3, .04, .6), Color("#5a3c20"))

func _data_floor(base: float, x0: float, x1: float) -> void:
	# 9F: no tenant, no glass. Louvres the height of the window and racks humming behind them.
	var f := _front
	var y0 := base + SILL
	var y1 := base + HEAD
	var far := -1.1
	_kit.quad("room", f * Vector3(x0, y0, far), f * Vector3(x0, y1, far), f * Vector3(x1, y1, far), f * Vector3(x1, y0, far), Color("#0a0e18"))
	_reveal(f.translated_local(Vector3(0, 0, SPAN)), Rect2(x0, y0, x1 - x0, y1 - y0), -far + SPAN, Color("#3c3f42"))
	for i: int in range(7):
		var x := x0 + .4 + float(i) * .86
		_bar("metal", f, x, (y0 + y1) * .5, far + .12, Vector3(.7, y1 - y0, .2), Color("#15171b"))
		var k := 0
		while k < 8:
			_bar("led", f, x - .22 + float(k % 4) * .15, y0 + .24 + float(k / 4) * .22 + float(i % 3) * .3, far + .225, Vector3(.05, .012, .006), Color(.25, .55, 1.0) if (k + i) % 5 != 0 else GREEN)
			k += 1
	var y := y0 + .03
	while y < y1 - .02:
		_kit.quad("metal", f * Vector3(x0, y, GLASS + .02), f * Vector3(x0, y + .11, GLASS - .06), f * Vector3(x1, y + .11, GLASS - .06), f * Vector3(x1, y, GLASS + .02), Color("#7f8488"), .8, 1.0)
		y += .14
	_bar("metal", f, (x0 + x1) * .5, y0 + .02, SPAN - .02, Vector3(x1 - x0, .05, .1), Color("#5d5f5e"))
	_panel("painted", f, x1 - .9, x1 - .1, y0 - .4, y0 - .1, SPAN + .01, _cell(320, 1680, 300, 110))

func _arcade() -> void:
	# ゲーム天国: open to the pavement, cabinets glowing out of a dark room.
	var f := _front
	var x0 := STAIR + PIER
	var x1 := 6.72
	var far := -7.4
	var ceiling := 3.0
	_kit.quad("carpet", f * Vector3(x0, .02, .0), f * Vector3(x0, .02, far), f * Vector3(x1, .02, far), f * Vector3(x1, .02, .0), Color(.2, .12, .34), 1.0, 1.0, 0.0, Vector2(x0, 0))
	_kit.quad("room", f * Vector3(x0, ceiling, far), f * Vector3(x0, ceiling, .0), f * Vector3(x1, ceiling, .0), f * Vector3(x1, ceiling, far), Color("#0d0d14"))
	_kit.quad("room", f * Vector3(x0, 0, .0), f * Vector3(x0, ceiling, .0), f * Vector3(x0, ceiling, far), f * Vector3(x0, 0, far), Color("#1c1430"), .8, 1.0)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, ceiling, .0), f * Vector3(x1, 0, .0), Color("#1c1430"), .8, 1.0)
	_panel("arcade", f, x0, x1, .9, 2.8, far + .02, _cell(1800, 1570, 240, 160))
	_kit.quad("room", f * Vector3(x0, 0, far + .01), f * Vector3(x0, .9, far + .01), f * Vector3(x1, .9, far + .01), f * Vector3(x1, 0, far + .01), Color("#101018"))
	var mid := (x0 + x1) * .5
	for z: float in [-1.2, -3.2, -5.2]:
		_bar("led", f, mid, ceiling - .02, z, Vector3(x1 - x0 - .4, .012, .03), PINK if z == -3.2 else ACID)
	for row: int in range(3):
		for column: int in range(3):
			_crane(x0 + 1.0 + float(column) * 1.35, -1.5 - float(row) * 1.9, (row + column) % 4)
	# Pier below the fascia, the fascia itself with its chasing bulbs, and the shutter box.
	_tile(f, x1, WIDE - PIER, 3.0, 3.1, SPAN, .8, .9)
	_bar("metal", f, (x0 + x1) * .5, 3.08, -.1, Vector3(x1 - x0, .16, .24), Color("#55585a"))
	_bar("plain", f, (STAIR + WIDE) * .5, 3.52, .02, Vector3(WIDE - STAIR, .86, .3), Color("#17181a"))
	_panel("sign", f, STAIR + .02, WIDE - .02, 3.13, 3.93, .174, _cell(0, 1370, 1536, 190))
	for side: float in [3.1, 3.96]:
		var x := STAIR + .08
		var i := 0
		while x < WIDE - .06:
			_kit.disc("lamp", f * Vector3(x, side, .18), f.basis.x, f.basis.y, .022, ACID if i % 3 != 0 else Color(1.0, .86, .5))
			x += .13
			i += 1
	_gacha_bank()

func _crane(x: float, z: float, topper: int) -> void:
	# Prize crane: lit case on a coin base, a heap of plush and a claw that never quite grips.
	var f := _front
	var tone: Color = [Color("#d9307f"), Color("#2c5fd8"), Color("#e89a1c"), Color("#17a06e")][topper]
	_bar("hall", f, x, .42, z, Vector3(.96, .8, .96), tone * .75)
	_bar("hall", f, x, 2.14, z, Vector3(.96, .28, .96), tone)
	_panel("arcade", f, x - .46, x + .46, 2.03, 2.25, z + .485, _cell(1800, 1370.0 + float(topper) * 48.0, 240, 44))
	_bar("lamp", f, x, 1.98, z, Vector3(.84, .02, .84), Color(.8, .8, .78))
	_kit.quad("arcade", f * Vector3(x - .46, .84, z + .46), f * Vector3(x - .46, .84, z - .46), f * Vector3(x + .46, .84, z - .46), f * Vector3(x + .46, .84, z + .46), Color(.8, .78, .86), 1.0, 1.0, 0.0, Vector2(.9, .78))
	for dx: float in [-.46, .46]:
		for dz: float in [-.46, .46]:
			_bar("metal", f, x + dx, 1.41, z + dz, Vector3(.035, 1.16, .035), Color("#c2c4c6"))
	for i: int in range(9):
		var at := f * Vector3(x + _rng.randf_range(-.32, .32), .84, z + _rng.randf_range(-.32, .32))
		var size := _rng.randf_range(.1, .15)
		var plush: Color = [Color("#ff9fc8"), Color("#ffe18a"), Color("#9fd8ff"), Color("#f4f0e6"), Color("#b0ee9c"), Color("#c9a0ff")][_rng.randi_range(0, 5)]
		_kit.lathe("hall", at, [Vector2(size * .4, 0), Vector2(size, size * .7), Vector2(size * .85, size * 1.4), Vector2(.01, size * 1.9)], plush, 7)
	var claw := f * Vector3(x + .12, 1.5, z - .08)
	_kit.tube("metal", [f * Vector3(x + .12, 1.98, z - .08), claw], .008, Color("#d0d2d4"), 4)
	for angle: float in [.5, 2.6, 4.7]:
		_kit.tube("metal", [claw, claw + Vector3(cos(angle) * .09, -.08, sin(angle) * .09), claw + Vector3(cos(angle) * .05, -.16, sin(angle) * .05)], .008, Color("#d0d2d4"), 4)
	_kit.quad("front", f * Vector3(x - .46, .82, z + .47), f * Vector3(x - .46, 1.98, z + .47), f * Vector3(x + .46, 1.98, z + .47), f * Vector3(x + .46, .82, z + .47), Color.WHITE)

func _gacha_bank() -> void:
	# Capsule machines stacked two high along the pavement, the street's first thing to light.
	var f := _front
	var cards: Array[Color] = [Color.WHITE, Color(.8, .9, 1.0), Color(1.0, .85, .92), Color(.86, 1.0, .82), Color(1.0, .96, .72)]
	for column: int in range(5):
		var x := 2.56 + float(column) * .46
		for row: int in range(2):
			var y := .12 + float(row) * .68
			_bar("plain", f, x, y + .33, .3, Vector3(.44, .66, .44), Color("#d3d7da"), .85, 1.0)
			_panel("arcade", f, x - .21, x + .21, y + .02, y + .64, .524, _cell(1544, 1370, 240, 360), cards[(column * 2 + row * 3) % 5])
		_bar("metal", f, x, .06, .3, Vector3(.45, .12, .46), Color("#2a2c2e"))

func _lift_lobby() -> void:
	# A slot of a lobby beside the arcade: one lift, and every tenant's name on a board.
	var f := _front
	var door := Rect2(6.8, 0, .98, 2.6)
	var deep := 2.4
	_kit.quad("hall", f * Vector3(door.position.x, .03, .0), f * Vector3(door.position.x, .03, -deep), f * Vector3(door.end.x, .03, -deep), f * Vector3(door.end.x, .03, .0), Color("#6e6a60"), .8, .7)
	_kit.quad("hall", f * Vector3(door.position.x, 0, .0), f * Vector3(door.position.x, door.end.y, .0), f * Vector3(door.position.x, door.end.y, -deep), f * Vector3(door.position.x, 0, -deep), Color("#7d7a70"), .8, .9)
	_kit.quad("hall", f * Vector3(door.end.x, 0, -deep), f * Vector3(door.end.x, door.end.y, -deep), f * Vector3(door.end.x, door.end.y, .0), f * Vector3(door.end.x, 0, .0), Color("#7d7a70"), .8, .9)
	_kit.quad("hall", f * Vector3(door.position.x, door.end.y, -deep), f * Vector3(door.position.x, door.end.y, .0), f * Vector3(door.end.x, door.end.y, .0), f * Vector3(door.end.x, door.end.y, -deep), Color("#b9b5a8"))
	_bar("metal", f, door.get_center().x, 1.06, -deep + .02, Vector3(.86, 2.1, .03), Color("#8e9092"))
	_bar("metal", f, door.get_center().x, 1.06, -deep + .04, Vector3(.012, 2.1, .01), Color("#2a2b2d"))
	_bar("led", f, door.get_center().x, 2.28, -deep + .04, Vector3(.2, .08, .006), AMBER)
	_bar("lamp", f, door.get_center().x, door.end.y - .02, -1.0, Vector3(.06, .03, .8), Color(.8, .84, .86))
	_tile(f, door.position.x, door.end.x, door.end.y, 3.1, SPAN * .3, .6, .8)
	_panel("decal", f, door.position.x + .02, door.end.x - .02, 2.68, 2.92, -.02, _cell(320, 1570, 480, 90))
	_tile(f, 6.72, 6.8, 0.0, 3.1, .0, .8, .9)
	# Tenant board on the pier, by the palm reader that calls the lift.
	var board := Vector2(WIDE - PIER * .5, 1.55)
	_bar("metal", f, board.x, board.y, .025, Vector3(.3, .47, .03), Color("#26282b"))
	_panel("sign", f, board.x - .14, board.x + .14, board.y - .22, board.y + .22, .042, _cell(0, 1570, 300, 470))

func _stair_walls() -> void:
	# The slot the stair stands in: rendered, and streaked by every rain since 1991.
	var f := _front
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(STAIR, 0, -SLOT))
	_render_wall(east, SLOT, TOP, GROUND, STOREY, RENDER * .92, [] as Array[Rect2])
	var back := f.translated_local(Vector3(0, 0, -SLOT))
	var holes: Array[Rect2] = []
	for index: int in range(-1, FLOORS):
		var y := _floor_y(index) if index >= 0 else 0.0
		holes.append(Rect2(.5, y + .02, .9, 2.04))
	_render_wall(back, STAIR, TOP, GROUND, STOREY, RENDER * .9, holes)
	for hole: Rect2 in holes:
		_reveal(back, hole, .08, Color("#4e5150"))
		_bar("paint", back, hole.get_center().x, hole.get_center().y, -.08, Vector3(hole.size.x, hole.size.y, .03), OXIDE.darkened(.25), .85, 1.0)
		_bar("metal", back, hole.position.x + .78, hole.position.y + 1.0, -.05, Vector3(.03, .14, .05), ALUMINIUM)
	_kit.quad("plain", f * Vector3(0, .03, .0), f * Vector3(0, .03, -SLOT), f * Vector3(STAIR, .03, -SLOT), f * Vector3(STAIR, .03, .0), Color("#5c5d59"), .8, .8)

func _stairs() -> void:
	# Painted steel scissor of flights, a landing at the street and one at each door.
	var f := _front
	var floors: Array[float] = [0.0]
	for index: int in range(FLOORS + 1):
		floors.append(_floor_y(index))
	for i: int in range(floors.size() - 1):
		var a := floors[i]
		var b := floors[i + 1]
		var mid := (a + b) * .5
		_flight(.2, 1.0, -2.5, a, -.95, mid)
		_flight(1.06, 1.86, -.95, mid, -2.5, b)
		_landing(.14, 1.88, -.1, -.95, mid, true)
		if i > 0:
			_landing(.14, 1.88, -2.5, -SLOT + .03, a, false)
			_bar("lamp", f, .95, a + 2.5, -SLOT + .04, Vector3(.7, .035, .05), Color(.72, .78, .78))
	_landing(.14, 1.88, -2.5, -SLOT + .03, TOP, false)
	for corner: Vector2 in [Vector2(.1, -.08), Vector2(1.9, -.08), Vector2(.1, -2.5)]:
		_kit.block("paint", _at(f, corner.x, TOP * .5, corner.y), Vector3(.1, TOP, .1), OXIDE * .9, .85, 1.0, .6)
	# Street gate, a bicycle left against it, and the exit sign over the first door.
	var bars := 13
	for bar: int in range(bars + 1):
		_bar("paint", f, .2 + 1.6 * float(bar) / float(bars), 1.1, -.08, Vector3(.025, 2.1, .025), OXIDE.darkened(.15))
	for y: float in [.1, 2.12]:
		_bar("paint", f, 1.0, y, -.08, Vector3(1.62, .05, .05), OXIDE.darkened(.15))
	_bicycle(.9, .18)
	_panel("painted", f.translated_local(Vector3(0, 0, -SLOT)), .78, 1.12, 2.2, 2.42, .02, _cell(320, 1800, 180, 110))

func _flight(x0: float, x1: float, z0: float, y0: float, z1: float, y1: float) -> void:
	var f := _front
	var steps := int(absf(y1 - y0) / .2)
	for side: float in [x0, x1]:
		_kit.beam("paint", f * Vector3(side, y0 - .06, z0), f * Vector3(side, y1 - .06, z1), .04, .14, Vector3.RIGHT, OXIDE * .9)
		_kit.tube("metal", [f * Vector3(side, y0 + .9, z0), f * Vector3(side, y1 + .9, z1)], .018, OXIDE.lightened(.1), 5)
	for i: int in range(1, steps):
		var t := float(i) / float(steps)
		_bar("paint", f, (x0 + x1) * .5, lerpf(y0, y1, t), lerpf(z0, z1, t), Vector3(x1 - x0, .025, absf(z1 - z0) / float(steps) + .02), OXIDE * .78)

func _landing(x0: float, x1: float, z0: float, z1: float, y: float, guarded: bool) -> void:
	var f := _front
	_kit.block("paint", _at(f, (x0 + x1) * .5, y - .03, (z0 + z1) * .5), Vector3(x1 - x0, .06, absf(z1 - z0)), OXIDE * .8, .75, 1.0, .5)
	if not guarded: return
	# Guard to the street and round the corner, close-barred so nothing falls on anyone.
	for rail: float in [.1, .6, 1.12]:
		_kit.tube("metal", [f * Vector3(x0, y + rail, z1), f * Vector3(x0, y + rail, z0), f * Vector3(x1, y + rail, z0)], .016, OXIDE.lightened(.1), 5)
	var x := x0
	while x < x1:
		_bar("paint", f, x, y + .56, z0, Vector3(.02, 1.12, .02), OXIDE)
		x += .13
	var z := z0
	while z > z1:
		_bar("paint", f, x0, y + .56, z, Vector3(.02, 1.12, .02), OXIDE)
		z -= .13

func _bicycle(x: float, z: float) -> void:
	var f := _front
	var tint := Color("#1f2226")
	for dx: float in [-.52, .52]:
		var centre := f * Vector3(x + dx, .33, z)
		var points: Array[Vector3] = []
		for i: int in range(17):
			var angle := TAU * float(i) / 16.0
			points.append(centre + Vector3(cos(angle), sin(angle), 0) * .31)
		_kit.tube("metal", points, .012, tint, 4)
	var seat := f * Vector3(x - .22, .88, z)
	var bars := f * Vector3(x + .36, .98, z)
	_kit.tube("metal", [f * Vector3(x - .52, .33, z), seat, bars, f * Vector3(x + .52, .33, z)], .016, Color("#7a2a24"), 5)
	_kit.tube("metal", [f * Vector3(x - .52, .33, z), f * Vector3(x, .33, z), bars], .014, Color("#7a2a24"), 5)
	_bar("plain", f, seat.x - f.origin.x, .9, z, Vector3(.24, .05, .1), Color("#17181a"))
	_kit.tube("metal", [bars + Vector3(0, 0, -.24), bars + Vector3(0, 0, .24)], .012, tint, 4)

func _blades() -> void:
	# Blade signs up the east pier, one to each floor it advertises, on a shared steel post.
	var f := _front
	var steel := Color("#3a3c3e")
	var x := WIDE - .14
	var post := .22
	_bar("metal", f, x, 14.0, post, Vector3(.1, 24.0, .1), steel)
	for index: int in range(FLOORS):
		var low := _floor_y(index) + .2
		var tall := 2.72
		var near := post + .14
		var far := near + .9
		var mid := (near + far) * .5
		var rect := _cell(float(index) * 256.0, 0, 240, 720)
		_bar("metal", f, x, low + tall * .5, mid, Vector3(.1, tall + .04, .92), Color("#1a1b1d"), .8, 1.0)
		_kit.atlas("sign", f * Vector3(x + .052, low, far), f * Vector3(x + .052, low + tall, far), f * Vector3(x + .052, low + tall, near), f * Vector3(x + .052, low, near), rect, Color.WHITE, 1.0, .25)
		_kit.atlas("sign", f * Vector3(x - .052, low, near), f * Vector3(x - .052, low + tall, near), f * Vector3(x - .052, low + tall, far), f * Vector3(x - .052, low, far), rect, Color.WHITE, 1.0, .25)
		for y: float in [low + .3, low + tall - .3]:
			_bar("metal", f, x, y, post * .5 + .05, Vector3(.05, .05, post + .1), steel)
	_kit.tube("plain", [f * Vector3(x + .07, 4.0, post), f * Vector3(x + .07, 26.0, post)], .013, Color("#1d1e20"), 4)

func _west_wall() -> void:
	# The sun's side, behind the stair: tile low down, and solar cladding from 5F up.
	var w := _west
	var length := DEEP - SLOT
	var holes: Array[Rect2] = []
	for index: int in range(4):
		holes.append(Rect2(2.6, _floor_y(index) + 1.05, .9, 1.1))
	_render_wall(w, length, PARAPET, GROUND, STOREY, RENDER, holes)
	_bar("render", w, DEEP * .5, PARAPET + .05, -.05, Vector3(DEEP + .1, .1, .3), RENDER, .7, 1.0)
	for index: int in range(4):
		_window(w, Rect2(2.6, _floor_y(index) + 1.05, .9, 1.1), fposmod(.17 + float(index) * .29, 1.0), index < 2)
	var rows := 6
	var low := _floor_y(4) - .4
	for row: int in range(rows):
		for column: int in range(4):
			_solar_module(Transform3D(w.basis, w * Vector3(.75 + float(column) * 1.42, low + 1.05 + float(row) * 2.08, .05)), 1.36, 2.02)
	_bar("metal", w, length * .5, low - .03, .05, Vector3(length - .2, .06, .1), Color("#6d7073"))
	_kit.tube("plain", [w * Vector3(length - .18, low + 12.0, .06), w * Vector3(length - .18, 4.2, .06)], .03, Color("#17181a"), 5)
	# Condensers for the lower tenants, racked against the wall in a steel cage.
	for row: int in range(3):
		_outdoor_unit(w, 1.05, 4.6 + float(row) * .8, .2)
		if row == 0:
			_outdoor_unit(w, 2.0, 4.6, .2)
	for y: float in [4.15, 4.95, 5.75]:
		_bar("metal", w, 1.3, y, .24, Vector3(2.0, .04, .44), STEEL)

func _east_wall() -> void:
	# Blank above the gyoza shop's roof, with a drug company's ghost still on it.
	var e := _east
	var holes: Array[Rect2] = []
	for index: int in range(FLOORS):
		holes.append(Rect2(7.4, _floor_y(index) + 1.3, .7, .8))
	_render_wall(e, DEEP, PARAPET, GROUND, STOREY, RENDER, holes)
	_bar("render", e, DEEP * .5, PARAPET + .05, -.05, Vector3(DEEP + .1, .1, .3), RENDER, .7, 1.0)
	for index: int in range(FLOORS):
		_window(e, Rect2(7.4, _floor_y(index) + 1.3, .7, .8), fposmod(.41 + float(index) * .23, 1.0), true)
	_panel("ghost", e, .6, 7.0, 18.0, 19.86, .012, _cell(1000, 1740, 1040, 300), Color(.82, .78, .7), .5)
	_kit.tube("metal", [e * Vector3(4.2, .1, .07), e * Vector3(4.2, PARAPET - .4, .07)], .05, Color("#8a8b84"), 7)

func _rooftop() -> void:
	var half := WIDE * .5
	var level := TOP + .02
	_kit.quad("plain", Vector3(-half + STAIR, level, -.1), Vector3(-half + STAIR, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, -.1), Color("#5a5c5c"), .8, .9)
	_kit.quad("plain", Vector3(-half, level, -SLOT), Vector3(-half, level, -DEEP), Vector3(-half + STAIR, level, -DEEP), Vector3(-half + STAIR, level, -SLOT), Color("#5a5c5c"), .8, .9)
	var inner := Color(.82, .8, .74)
	_kit.quad("render", Vector3(-half + .02, level, -DEEP), Vector3(-half + .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, level, -DEEP), inner, .7, 1.0, .8)
	_kit.quad("render", Vector3(half - .02, level, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -.1), Vector3(half - .02, level, -.1), inner, .7, 1.0, .8)
	# Lift overrun and dry coolers for the racks: the roof is now the building's radiator.
	var head := Vector3(-.4, TOP + 1.6, -7.4)
	_kit.block("render", Transform3D(Basis.IDENTITY, head), Vector3(2.6, 3.2, 2.6), RENDER * .92, .75, 1.0, .9)
	for i: int in range(2):
		var at := Vector3(.3 + float(i) * 2.0, TOP + 1.25, -2.9)
		_bar("metal", Transform3D.IDENTITY, at.x, at.y, at.z, Vector3(1.7, 2.2, 3.4), Color("#a9adae"), .85, 1.0)
		for z: float in [-1.0, .0, 1.0]:
			_kit.lathe("plain", at + Vector3(0, 1.1, z), [Vector2(.44, 0), Vector2(.46, .14)], Color("#1a1c1e"), 12)
			_kit.lathe("metal", at + Vector3(0, 1.12, z), [Vector2(.04, 0), Vector2(.4, .02)], Color("#6d7073"), 8)
		for x: float in [-.6, .6]:
			_bar("metal", Transform3D.IDENTITY, at.x + x, TOP + .1, at.z, Vector3(.1, .2, 3.4), STEEL)
	var mast := Vector3(2.8, level, -6.6)
	_kit.tube("metal", [mast, mast + Vector3.UP * 5.2], .05, Color("#c7cac9"), 7)
	for angle: float in [.2, 2.3, 4.4]:
		var turn := Basis(Vector3.UP, angle)
		_kit.block("plain", Transform3D(turn, mast + Vector3.UP * 4.7 + turn * Vector3(0, 0, .22)), Vector3(.36, .9, .1), Color("#dfe0db"), .9, 1.0)
	_status(Transform3D.IDENTITY, mast.x + .08, mast.y + 5.25, mast.z, Color(1.0, .2, .15))
	# Top landing rail, where the stair comes out on the roof.
	var f := _front
	for y: float in [TOP + .6, TOP + 1.12]:
		_kit.tube("metal", [f * Vector3(.14, y, -SLOT), f * Vector3(.14, y, -2.5), f * Vector3(1.88, y, -2.5)], .018, OXIDE.lightened(.1), 5)

func _retrofit() -> void:
	# What the decades bolted to the street front.
	var f := _front
	# Galvanised exhaust from the racks, up the pier and over the parapet.
	var duct := STAIR + PIER * .5
	_bar("metal", f, duct, (_floor_y(7) + 1.6 + PARAPET + .4) * .5, .24, Vector3(.28, PARAPET + .4 - _floor_y(7) - 1.6, .42), Color("#a4a8aa"), .85, 1.0)
	for y: float in [27.0, 28.4, 29.8]:
		_bar("metal", f, duct, y, .24, Vector3(.3, .05, .44), Color("#7f8488"))
	_bar("metal", f, duct, PARAPET + .3, -1.0, Vector3(.28, .42, 2.6), Color("#a4a8aa"), .85, 1.0)
	# Condensers caged on the front, where a tenant could get away with it.
	for row: Array in [[0, 3.0], [1, 6.4], [6, 5.9]]:
		var base := _floor_y(row[0])
		var x: float = row[1]
		_outdoor_unit(f, x, base + .46, .14)
		_bar("metal", f, x, base + .1, .1, Vector3(.96, .03, .46), STEEL)
		for dx: float in [-.46, .46]:
			_bar("metal", f, x + dx, base + .46, .32, Vector3(.025, .7, .025), STEEL)
			_kit.block("plain", _at(f, x + dx, base - .2, SPAN + .012), Vector3(.05, .6, .004), Color("#6a4a30"), 1.0, 1.0, .9)
	# Fibre down the west pier, a camera on the fascia, smart meters in the lift porch.
	_fibre([f * Vector3(STAIR + .08, 26.0, .03), f * Vector3(STAIR + .08, 4.0, .03), f * Vector3(STAIR + .4, 3.1, .22)])
	_camera(f * Vector3(6.72, 2.9, .12))
	for i: int in range(8):
		_bar("metal", f, 6.86, 1.1 + float(i) * .18, -.5 - float(i % 2) * .16, Vector3(.05, .14, .13), Color("#c7c8c2"))
		_status(f, 6.895, 1.1 + float(i) * .18, -.5 - float(i % 2) * .16, GREEN)

func _standee() -> void:
	# Cut-out of the arcade's angel by the pavement, one hand out to whoever walks past.
	var f := _front
	_panel("decal", f, 5.72, 6.5, .03, 1.53, .42, _cell(820, 1570, 170, 330))
	_bar("metal", f, 6.11, .02, .36, Vector3(.5, .04, .24), Color("#2a2c2e"))
	# Pavement board for the floors nobody can see from here.
	_bar("metal", f, 7.35, .62, .62, Vector3(.6, .84, .03), Color("#1d1f22"))
	_panel("poster", f, 7.08, 7.62, .24, 1.0, .638, _cell(1040, 1410, 300, 420))
	for x: float in [7.1, 7.6]:
		_kit.beam("metal", f * Vector3(x, 1.0, .6), f * Vector3(x, 0, .3), .03, .03, Vector3.RIGHT, Color("#1d1f22"))
		_kit.beam("metal", f * Vector3(x, .3, .64), f * Vector3(x, 0, .8), .03, .03, Vector3.RIGHT, Color("#1d1f22"))
