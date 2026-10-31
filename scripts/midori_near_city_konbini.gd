extends "res://scripts/midori_near_city_handmade.gd"
## コーポ松風: a 1984 five-storey block in brown 二丁掛 tile, on the corner of its street,
## with an unstaffed ヨリミチ on the ground floor. Eight flats of eight households up the
## front; the 2044 flood, ration tickets and swap batteries down at street level.
const ATLAS := "res://assets/shinrai/near_city/konbini_atlas.png"
const WIDE := 9.2
const DEEP := 9.6
const GROUND := 3.9
const STOREY := 2.85
const FLOORS := 4
const TOP := 15.3
const PARAPET := 16.2
const FIN := .2 # Tiled side walls of the balconies.
const BALCONY := 1.2
const BAY := 4.4 # One flat's width.
const SOFFIT := .16
const FASCIA_WEST := 1.55
const SHOP_WEST := 2.7
const DOOR_WEST := 6.9
const DOOR_EAST := 8.86
const GLASS := -.3
const HEAD := 2.86
const ROOM_DEEP := 7.2
const FLOOD := .62 # How high the 2044 water stood.
const BROWN := Color(.5, .33, .24)
const CREAM := Color(.98, .93, .82)
const PALE := Color(.9, .86, .76)
const SHELF := Color(.86, .88, .89)
const WHITE_GOODS := Color("#e4e6e4")
const CORAL := Color("#ee5a3f")
const LACE := Color("#e6e3da")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1984
	_build_looks()
	_street_front()
	_residents()
	_fascia()
	_shop()
	_frame()
	for floor_index: int in range(FLOORS):
		_floor(floor_index)
	_east_side()
	_west_side()
	_render_wall(_back, WIDE, PARAPET, GROUND, STOREY, PALE, [] as Array[Rect2])
	_rooftop()
	_street_things()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "leaf", "led", "goods", "shop", "floor", "display", "fascia", "hall"])
	_kit = null
	_omni("ShopSpill", Vector3(1.0, 2.5, 1.0), Color(.93, .97, 1.0), 1.5, 8.5)
	_omni("ShopRoom", Vector3(1.2, 2.3, -3.6), Color(.95, .98, 1.0), .9, 7.0)
	_omni("VendingSpill", Vector3(-2.5, 1.1, 1.3), Color(.8, .92, 1.0), .35, 3.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.nicho = _look("", 1.0, .46)
	_looks.nicho.set_shader_parameter("tile_size", Vector2(.227, .06))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.paint = _look("rusty_painted_metal", 2.2, 1.0)
	_looks.hall = _look("", 1.0, .7)
	_looks.hall.set_shader_parameter("glow", .34)
	_looks.hall.set_shader_parameter("day_glow", .08)
	_looks.shop = _look("", 1.0, .6)
	_looks.shop.set_shader_parameter("glow", .46)
	_looks.shop.set_shader_parameter("day_glow", .26)
	_looks.floor = _look("", 1.0, .1)
	_looks.floor.set_shader_parameter("tile_size", Vector2(.3, .3))
	_looks.floor.set_shader_parameter("glow", .2)
	_looks.floor.set_shader_parameter("day_glow", .14)
	_looks.goods = _look("", 1.0, .5)
	_looks.goods.set_shader_parameter("albedo_map", signs)
	_looks.goods.set_shader_parameter("glow", .6)
	_looks.goods.set_shader_parameter("day_glow", .3)
	_looks.fascia = _look("", 1.0, .35)
	_looks.fascia.set_shader_parameter("albedo_map", signs)
	_looks.fascia.set_shader_parameter("glow", .82)
	_looks.fascia.set_shader_parameter("day_glow", .1)
	_looks.display = _look("", 1.0, .25)
	_looks.display.set_shader_parameter("albedo_map", signs)
	_looks.display.set_shader_parameter("glow", .85)
	_looks.display.set_shader_parameter("day_glow", .5)
	_looks.painted = _look("", 1.0, .6)
	_looks.painted.set_shader_parameter("albedo_map", signs)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .6)
	letters.set_shader_parameter("day_glow", .3)
	_looks.decal = letters

func _brown(face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, low := .9, high := 1.0, streak := .3) -> void:
	# The building's tile, stained darker wherever the flood stood against it.
	if y0 < FLOOD and y1 > FLOOD:
		_brown(face, x0, x1, y0, FLOOD, z, low, high, streak)
		y0 = FLOOD
	var tint := BROWN * (.76 if y1 <= FLOOD else 1.0)
	_kit.quad("nicho", face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), tint, low, high, streak, Vector2(x0, -y0))

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _goods(index: int, from: float, share: float) -> Rect2:
	# Part of one shelf strip: left column first, then the right.
	var rect := _cell(float(index / 6) * 1024.0, 160.0 + float(index % 6) * 176.0, 1020, 168)
	return Rect2(rect.position.x + rect.size.x * from, rect.position.y, rect.size.x * share, rect.size.y)

func _street_front() -> void:
	# Tiled base to the west, then the glass of the shop to the corner.
	var f := _front
	var entry := Rect2(.45, 0, 1.0, 2.5)
	var holes: Array[Rect2] = [entry]
	for piece: Rect2 in _minus(Rect2(0, 0, SHOP_WEST, GROUND - .15), holes):
		_brown(f, piece.position.x, piece.end.x, piece.position.y, piece.end.y, 0.0)
	var side := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(SHOP_WEST, 0, 0))
	_brown(side, 0.0, -GLASS, 0.0, HEAD, 0.0, .7, .8)
	# Stall riser in the same tile under the window, its rail above it.
	_brown(f, SHOP_WEST, DOOR_WEST, 0.0, .42, GLASS + .03, .7, .9, .2)
	# Clear glass in three lights, then two sliding leaves.
	var mullions: Array[float] = [SHOP_WEST, 4.1, 5.5, DOOR_WEST]
	_kit.quad("front", f * Vector3(SHOP_WEST, .42, GLASS), f * Vector3(SHOP_WEST, HEAD, GLASS), f * Vector3(DOOR_WEST, HEAD, GLASS), f * Vector3(DOOR_WEST, .42, GLASS), Color.WHITE)
	_kit.quad("front", f * Vector3(DOOR_WEST, .02, GLASS - .02), f * Vector3(DOOR_WEST, HEAD, GLASS - .02), f * Vector3(DOOR_EAST, HEAD, GLASS - .02), f * Vector3(DOOR_EAST, .02, GLASS - .02), Color.WHITE)
	for x: float in mullions:
		_bar("metal", f, x, (.42 + HEAD) * .5, GLASS, Vector3(.06, HEAD - .42, .14), ALUMINIUM)
	_bar("metal", f, (SHOP_WEST + DOOR_WEST) * .5, .44, GLASS + .01, Vector3(DOOR_WEST - SHOP_WEST, .05, .16), ALUMINIUM)
	_bar("metal", f, (SHOP_WEST + DOOR_EAST) * .5, HEAD - .02, GLASS, Vector3(DOOR_EAST - SHOP_WEST, .07, .16), ALUMINIUM)
	var middle := (DOOR_WEST + DOOR_EAST) * .5
	for x0: float in [DOOR_WEST + .02, middle]:
		var x1 := x0 + (DOOR_EAST - DOOR_WEST) * .5 - .02
		for x: float in [x0 + .02, x1 - .02]:
			_bar("metal", f, x, 1.24, GLASS - .02, Vector3(.045, 2.36, .05), ALUMINIUM)
		_bar("metal", f, (x0 + x1) * .5, .06, GLASS - .02, Vector3(x1 - x0, .08, .05), ALUMINIUM)
		_bar("metal", f, (x0 + x1) * .5, 2.42, GLASS - .02, Vector3(x1 - x0, .05, .05), ALUMINIUM)
	_bar("metal", f, middle, 2.64, GLASS - .03, Vector3(DOOR_EAST - DOOR_WEST, .34, .1), Color("#8d8f8c"))
	# Corner pier, tiled on both streets.
	_bar("plain", f, (DOOR_EAST + WIDE) * .5, 1.5, -.17, Vector3(WIDE - DOOR_EAST, 3.0, .34), BROWN * .7)
	_brown(f, DOOR_EAST, WIDE, 0.0, 2.95, .004)
	_brown(_east, .0, .34, 0.0, 2.95, .004)
	# Notices on the glass, and a clear display showing what the ward wants known.
	var z := GLASS + .012
	_panel("decal", f, 2.86, 3.52, 1.66, 2.6, z, _cell(0, 1216, 240, 340))
	_panel("decal", f, 6.1, 6.74, 1.66, 2.56, z, _cell(500, 1216, 240, 340))
	_bar("bottle", f, 4.86, 2.2, GLASS - .04, Vector3(1.16, .62, .02), Color("#0a0d11"))
	for x: float in [4.4, 5.32]:
		_bar("metal", f, x, 2.68, GLASS - .04, Vector3(.012, .36, .012), STEEL)
	_panel("decal", f, 4.34, 5.38, 1.94, 2.46, z, _cell(750, 1216, 640, 300))
	_panel("decal", f, 7.04, 7.46, 1.5, 2.1, z - .02, _cell(250, 1216, 240, 340))
	# Flood height plate on the corner pier, and the ward's channels for its boards.
	_panel("painted", f, DOOR_EAST + .05, WIDE - .05, 1.3, 1.65, .012, _cell(1810, 1216, 230, 340))
	for x: float in [DOOR_WEST + .02, DOOR_EAST - .02]:
		_bar("metal", f, x, .46, GLASS + .08, Vector3(.1, .92, .07), Color("#d0b23c"))
		_bar("metal", f, x, .46, GLASS + .09, Vector3(.035, .92, .08), Color("#1c1d1f"))

func _residents() -> void:
	# The tenants' way in: a step, a deep tiled porch and the auto-lock door.
	var f := _front
	var door := Rect2(.45, 0, 1.0, 2.5)
	var deep := 1.7
	_reveal(f, door, deep, Color("#6a5044"))
	_kit.quad("plain", f * Vector3(door.position.x, .05, .0), f * Vector3(door.position.x, .05, -deep), f * Vector3(door.end.x, .05, -deep), f * Vector3(door.end.x, .05, .0), Color("#7b736a"), .8, .7)
	_kit.quad("hall", f * Vector3(door.position.x, .0, -deep), f * Vector3(door.position.x, door.end.y, -deep), f * Vector3(door.end.x, door.end.y, -deep), f * Vector3(door.end.x, .0, -deep), Color(.84, .8, .68))
	_kit.quad("front", f * Vector3(door.position.x + .02, .05, -deep + .06), f * Vector3(door.position.x + .02, door.end.y, -deep + .06), f * Vector3(door.end.x - .02, door.end.y, -deep + .06), f * Vector3(door.end.x - .02, .05, -deep + .06), Color.WHITE)
	var bronze := Color("#3a3028")
	for x: float in [door.position.x + .04, door.get_center().x, door.end.x - .04]:
		_bar("metal", f, x, 1.25, -deep + .08, Vector3(.05, 2.5, .05), bronze)
	_bar("metal", f, door.get_center().x, 2.2, -deep + .08, Vector3(1.0, .05, .05), bronze)
	_bar("lamp", f, door.get_center().x, 2.47, -.8, Vector3(.08, .03, .5), Color(.8, .78, .7))
	# Intercom turned palm reader on the jamb; the name in cut letters over the porch.
	_bar("bottle", f, door.end.x - .01, 1.3, -.6, Vector3(.016, .24, .15), Color("#0b0c0e"))
	_status(f, door.end.x - .022, 1.36, -.6, CYAN)
	_panel("decal", f, .47, 1.43, 2.6, 2.84, .012, _cell(1400, 1216, 400, 100))
	# Smart meters for the eight flats, over where the vending machine stands.
	for row: int in range(2):
		for column: int in range(4):
			var x := 1.74 + float(column) * .25
			var y := 2.26 + float(row) * .3
			_bar("metal", f, x, y, .035, Vector3(.2, .25, .07), Color("#c7c8c2"))
			_bar("bottle", f, x, y + .04, .072, Vector3(.13, .08, .005), Color("#0d1d1c"))
			_status(f, x + .06, y - .07, .074, GREEN)
	_kit.tube("plain", [f * Vector3(1.66, 2.15, .03), f * Vector3(2.62, 2.15, .03)], .02, Color("#17181a"), 4)

func _fascia() -> void:
	# Lit board round the corner, and a thin canopy of downlights over the glass.
	var f := _front
	var mid := (FASCIA_WEST + WIDE) * .5
	_bar("plain", f, mid, 3.35, .0, Vector3(WIDE - FASCIA_WEST, .8, .4), Color("#bcb8ae"))
	_panel("fascia", f, FASCIA_WEST + .02, WIDE, 2.97, 3.73, .202, _cell(0, 0, 1536, 150))
	_bar("plain", _east, 1.0, 3.35, .1, Vector3(2.6, .8, .2), Color("#bcb8ae"))
	_panel("fascia", _east, -.2, 2.3, 2.97, 3.73, .202, _cell(1544, 0, 504, 150))
	var canopy := Color("#55585a")
	_bar("metal", f, (SHOP_WEST + WIDE) * .5, 2.91, .08, Vector3(WIDE - SHOP_WEST, .06, .76), canopy)
	for i: int in range(7):
		var at := f * Vector3(3.0 + float(i) * 1.0, 2.878, .12)
		_kit.disc("lamp", at, Vector3.RIGHT, Vector3.BACK, .055, Color(.72, .75, .78))
	_camera(f * Vector3(9.0, 2.86, .3))

func _shop() -> void:
	# A real room to look into: bright, shallow shelves of goods and a cold wall at the end.
	var f := _front
	var x0 := SHOP_WEST + .05
	var x1 := WIDE - .12
	var far := -ROOM_DEEP
	_kit.quad("floor", f * Vector3(x0, .02, GLASS), f * Vector3(x0, .02, far), f * Vector3(x1, .02, far), f * Vector3(x1, .02, GLASS), Color(.82, .82, .8), 1.0, 1.0, 0.0, Vector2(x0, GLASS))
	_kit.quad("shop", f * Vector3(x0, HEAD, far), f * Vector3(x0, HEAD, GLASS), f * Vector3(x1, HEAD, GLASS), f * Vector3(x1, HEAD, far), Color(.5, .52, .53))
	var west := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x0, 0, GLASS))
	var length := ROOM_DEEP + GLASS
	_kit.quad("shop", west * Vector3(.0, 0, 0), west * Vector3(.0, HEAD, 0), west * Vector3(length, HEAD, 0), west * Vector3(length, 0, 0), Color(.56, .57, .55), .8, 1.0)
	var east := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x1, 0, far))
	_kit.quad("shop", east * Vector3(.0, 0, 0), east * Vector3(.0, HEAD, 0), east * Vector3(3.6, HEAD, 0), east * Vector3(3.6, 0, 0), Color(.56, .57, .55), .8, 1.0)
	_kit.quad("shop", f * Vector3(x0, 0, far), f * Vector3(x0, HEAD, far), f * Vector3(x1, HEAD, far), f * Vector3(x1, 0, far), Color(.46, .47, .47))
	# Ceiling panels in long rows, between the aisles.
	for x: float in [3.35, 4.62, 5.9, 7.2, 8.45]:
		for row: int in range(3):
			var z := -1.3 - float(row) * 2.1
			_kit.quad("lamp", f * Vector3(x - .08, HEAD - .01, z - .75), f * Vector3(x - .08, HEAD - .01, z + .75), f * Vector3(x + .08, HEAD - .01, z + .75), f * Vector3(x + .08, HEAD - .01, z - .75), Color(.62, .64, .66))
	_gondola(4.0, -1.5, -5.7, 0, _cell(300, 1660, 300, 70))
	_gondola(5.26, -1.5, -5.7, 1, _cell(610, 1660, 300, 70))
	_gondola(6.52, -1.5, -5.7, 3, _cell(920, 1660, 300, 70))
	_wall_shelf(west, 1.2, length - .2)
	_cold_wall(x0, x1)
	_window_rack()
	_counter()
	_gate()
	_stock_arm(x0, x1)

func _gondola(x: float, near: float, far: float, first: int, board: Rect2) -> void:
	# A double-sided run: four shelves of goods on each face, and an end cap to the street.
	var f := _front
	var mid := (near + far) * .5
	var length := near - far
	_bar("shop", f, x, .08, mid, Vector3(.92, .16, length), Color(.2, .21, .23))
	_bar("shop", f, x, .8, mid, Vector3(.05, 1.44, length), SHELF)
	var sides: Array[Transform3D] = [Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x, 0, near)), Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x, 0, far))]
	var offset := first
	for side: Transform3D in sides:
		for level: int in range(4):
			var y := .2 + float(level) * .34
			_bar("shop", side, length * .5, y, .22, Vector3(length, .022, .4), SHELF)
			_bar("led", side, length * .5, y + .004, .425, Vector3(length, .018, .004), Color(.5, .62, .6))
			var run := .0
			var piece := 0
			while run < length - .05:
				var wide := minf(1.7, length - run)
				var rect := _goods((offset + level * 2 + piece) % 6 if (offset + level + piece) % 5 != 4 else 3, _rng.randf() * (1.0 - wide / 1.72), wide / 1.72)
				_panel("goods", side, run, run + wide, y + .012, y + .3, .34, rect)
				run += wide
				piece += 1
		offset += 2
	# End cap, and the board over the aisle on two thin rods.
	_bar("shop", f, x, .8, near + .03, Vector3(.92, 1.44, .05), Color(.8, .82, .82))
	for level: int in range(4):
		_panel("goods", f, x - .44, x + .44, .2 + float(level) * .34, .49 + float(level) * .34, near + .06, _goods(first + level * 3, _rng.randf() * .4, .52))
	_panel("goods", f, x - .46, x + .46, 2.12, 2.34, near + .02, board)
	for dx: float in [-.36, .36]:
		_bar("metal", f, x + dx, 2.6, near + .02, Vector3(.01, .52, .01), STEEL)

func _wall_shelf(wall: Transform3D, from: float, to: float) -> void:
	# Tall shelving down the party wall.
	var y := .2
	var level := 0
	while y < 1.9:
		var run := from
		while run < to - .05:
			var wide := minf(1.7, to - run)
			_panel("goods", wall, run, run + wide, y + .012, y + .3, .36, _goods((level + int(run)) % 6, _rng.randf() * (1.0 - wide / 1.72), wide / 1.72))
			run += wide
		_bar("shop", wall, (from + to) * .5, y, .2, Vector3(to - from, .022, .4), SHELF)
		y += .34
		level += 1
	_bar("shop", wall, (from + to) * .5, .08, .22, Vector3(to - from, .16, .44), Color(.2, .21, .23))

func _cold_wall(x0: float, x1: float) -> void:
	# Glass-doored fridges the width of the back wall, each lit down its own frame.
	var f := _front
	var doors := 6
	var wide := (x1 - x0) / float(doors)
	var z := -ROOM_DEEP + .03
	var mix_of := [6, 7, 8, 9, 10]
	for door: int in range(doors):
		var left := x0 + float(door) * wide
		for level: int in range(5):
			var y := .16 + float(level) * .39
			var kind: int = mix_of[(door * 2 + level) % 5]
			_panel("goods", f, left + .03, left + wide - .03, y, y + .37, z, _goods(kind, _rng.randf() * .55, .44))
		_kit.quad("front", f * Vector3(left, .12, z + .1), f * Vector3(left, 2.12, z + .1), f * Vector3(left + wide, 2.12, z + .1), f * Vector3(left + wide, .12, z + .1), Color.WHITE)
		_bar("metal", f, left, 1.12, z + .08, Vector3(.05, 2.0, .06), Color("#55585a"))
		_bar("lamp", f, left + .035, 1.12, z + .1, Vector3(.012, 1.9, .012), Color(.62, .66, .7))
		_bar("metal", f, left + wide - .1, 1.15, z + .13, Vector3(.025, .8, .04), ALUMINIUM)
	_bar("metal", f, (x0 + x1) * .5, 2.15, z + .08, Vector3(x1 - x0, .07, .08), Color("#55585a"))
	_bar("metal", f, (x0 + x1) * .5, .1, z + .08, Vector3(x1 - x0, .1, .08), Color("#55585a"))
	_bar("shop", f, (x0 + x1) * .5, 2.42, z + .02, Vector3(x1 - x0, .42, .04), Color(.9, .92, .92))
	_bar("led", f, (x0 + x1) * .5, 2.28, z + .05, Vector3(x1 - x0, .02, .006), CORAL)

func _window_rack() -> void:
	# The low rack under the window, with its back to the glass and a row of goods on top.
	var f := _front
	var x0 := SHOP_WEST + .1
	var x1 := DOOR_WEST - .1
	_bar("shop", f, (x0 + x1) * .5, .4, -.62, Vector3(x1 - x0, .8, .4), Color(.32, .34, .36))
	var run := x0
	while run < x1 - .05:
		var wide := minf(1.6, x1 - run)
		_panel("goods", f, run, run + wide, .8, 1.06, -.6, _goods(11 if int(run) % 2 == 0 else 5, _rng.randf() * (1.0 - wide / 1.56), wide / 1.56))
		run += wide
	_bar("shop", f, (x0 + x1) * .5, .81, -.62, Vector3(x1 - x0, .02, .42), Color(.74, .76, .76))

func _counter() -> void:
	# Nobody stands behind it now: steamer and coffee machine serve themselves.
	var f := _front
	var mid := 7.98
	var z := -3.9
	_bar("shop", f, mid, .46, z, Vector3(1.9, .9, .62), Color(.8, .78, .72))
	_bar("shop", f, mid, .93, z, Vector3(1.98, .05, .7), Color(.3, .31, .33))
	_bar("shop", f, mid, .48, z + .32, Vector3(1.86, .05, .02), CORAL)
	_bar("shop", f, mid - .5, 1.17, z - .04, Vector3(.64, .42, .4), Color(.8, .81, .82))
	_panel("goods", f, mid - .8, mid - .2, .98, 1.28, z + .17, _cell(300, 1740, 300, 150))
	_bar("shop", f, mid + .44, 1.25, z - .05, Vector3(.42, .6, .38), Color(.2, .2, .22))
	_panel("goods", f, mid + .24, mid + .64, .96, 1.56, z + .15, _cell(610, 1740, 200, 300))
	# Thin wall of parcel shelves behind, with an order screen at the end.
	_bar("shop", f, mid, 1.55, -5.2, Vector3(1.9, 1.5, .1), Color(.84, .85, .84))
	for row: int in range(3):
		for column: int in range(5):
			_bar("shop", f, mid - .76 + float(column) * .38, 1.0 + float(row) * .5, -5.14, Vector3(.34, .44, .02), Color(.68, .7, .71))
			_status(f, mid - .62 + float(column) * .38, .84 + float(row) * .5, -5.125, GREEN)

func _gate() -> void:
	# Unstaffed exit: two slim readers and a pair of glass paddles.
	var f := _front
	for x: float in [7.32, 8.42]:
		_bar("metal", f, x, .52, -1.5, Vector3(.1, 1.0, .6), Color("#2b2d30"))
		_bar("led", f, x, 1.03, -1.5, Vector3(.1, .012, .58), CYAN)
		_bar("bottle", f, x, 1.1, -1.28, Vector3(.08, .12, .1), Color("#101214"))
	_kit.quad("front", f * Vector3(7.38, .3, -1.5), f * Vector3(7.38, .96, -1.5), f * Vector3(7.84, .96, -1.5), f * Vector3(7.84, .3, -1.5), Color.WHITE)
	_kit.quad("front", f * Vector3(7.9, .3, -1.5), f * Vector3(7.9, .96, -1.5), f * Vector3(8.36, .96, -1.5), f * Vector3(8.36, .3, -1.5), Color.WHITE)

func _stock_arm(x0: float, x1: float) -> void:
	# The night staff: a jointed arm on a ceiling rail, working the cold wall.
	var f := _front
	var z := -6.72
	_bar("metal", f, (x0 + x1) * .5, HEAD - .07, z, Vector3(x1 - x0 - .2, .08, .14), Color("#3c3f42"))
	var x := 5.75
	var joint := f * Vector3(x, HEAD - .3, z)
	var elbow := f * Vector3(x - .3, HEAD - .95, z + .1)
	var wrist := f * Vector3(x + .08, 1.28, z + .02)
	_bar("metal", f, x, HEAD - .17, z, Vector3(.3, .16, .24), WHITE_GOODS)
	for pair: Array in [[f * Vector3(x, HEAD - .2, z), joint], [joint, elbow], [elbow, wrist]]:
		var from: Vector3 = pair[0]
		var to: Vector3 = pair[1]
		_kit.tube("metal", [from, to], .05, WHITE_GOODS, 8)
	for at: Vector3 in [joint, elbow, wrist]:
		_kit.lathe("metal", at + Vector3.DOWN * .06, [Vector2(.04, 0), Vector2(.075, .03), Vector2(.075, .09), Vector2(.04, .12)], CORAL, 10)
	for dx: float in [-.04, .04]:
		_kit.tube("metal", [wrist, wrist + Vector3(dx, -.14, -.04)], .012, Color("#3c3f42"), 5)
	_kit.lathe("bottle", wrist + Vector3(0, -.3, -.04), [Vector2(.035, 0), Vector2(.035, .14), Vector2(.012, .2)], Color("#2f8f4e"), 8)
	_status(f, x + .1, HEAD - .17, z + .125, CYAN)

func _frame() -> void:
	# Tiled side walls run the balconies up to a parapet, with a concrete edge to each floor.
	var f := _front
	var height := PARAPET - GROUND + .16
	for x: float in [FIN * .5, WIDE - FIN * .5]:
		var mid := GROUND - .16 + height * .5
		_bar("render", f, x, mid, -BALCONY * .5, Vector3(FIN, height, BALCONY), Color(.62, .5, .42), .8, 1.0)
		_brown(f, x - FIN * .5, x + FIN * .5, GROUND - .16, PARAPET, .004, .9, .95, .5)
	_kit.block("render", _at(f, WIDE * .5, (TOP + PARAPET) * .5, -.09), Vector3(WIDE, PARAPET - TOP, .18), CREAM, .8, 1.0, .5)
	_brown(f, 0.0, WIDE, TOP, PARAPET, .004, .86, .94, .55)
	_bar("render", f, WIDE * .5, PARAPET + .05, -.08, Vector3(WIDE + .08, .1, .3), CREAM, .7, 1.0)
	_kit.block("render", _at(f, WIDE * .5, TOP - SOFFIT * .5, -BALCONY * .5), Vector3(WIDE - FIN * 2.0, SOFFIT, BALCONY), CREAM, .55, 1.0, .5)
	# Rainwater down the balcony's corner, one for each stack of flats.
	for x: float in [FIN + .1, FIN + BAY + .13]:
		_kit.tube("plain", [f * Vector3(x, TOP - .1, -BALCONY + .08), f * Vector3(x, GROUND, -BALCONY + .08)], .035, Color("#cfc9b8"), 7)

func _floor(index: int) -> void:
	var f := _front
	var base := GROUND + float(index) * STOREY
	var wall := f.translated_local(Vector3(0, 0, -BALCONY))
	_kit.block("render", _at(f, WIDE * .5, base - SOFFIT * .5, -BALCONY * .5), Vector3(WIDE - FIN * 2.0, SOFFIT, BALCONY), CREAM, .55, 1.0, .35)
	_kit.quad("plain", f * Vector3(FIN, base + .004, .0), f * Vector3(FIN, base + .004, -BALCONY), f * Vector3(WIDE - FIN, base + .004, -BALCONY), f * Vector3(WIDE - FIN, base + .004, .0), Color("#6e6f6a"), .7, .85)
	for bay: int in range(2):
		var x0 := FIN + float(bay) * BAY
		_flat(index, bay, x0, base, wall)
		_balcony_front(index, bay, x0, base)
	# Fire board between the two flats, thin enough to kick through in an emergency.
	var boards := Color("#c4bda9")
	_bar("plain", f, FIN + BAY, base + 1.1, -BALCONY * .5, Vector3(.03, 2.2, BALCONY - .14), boards, .8, 1.0)
	_bar("metal", f, FIN + BAY, base + 1.1, -.08, Vector3(.06, 2.24, .05), ALUMINIUM)

func _flat(index: int, bay: int, x0: float, base: float, wall: Transform3D) -> void:
	# Wall, sliding door and window; then the household that lives behind them.
	var door := Rect2(x0 + .32, base + .04, 2.2, 2.12)
	var sash := Rect2(x0 + 2.84, base + .88, 1.22, 1.14)
	var holes: Array[Rect2] = [door, sash]
	for piece: Rect2 in _minus(Rect2(x0, base, BAY, STOREY), holes):
		_brown(wall, piece.position.x, piece.end.x, piece.position.y, piece.end.y, 0.0, .78, .92, .2)
	var flat := index * 2 + bay
	_window(wall, door, fposmod(.19 + float(flat) * .37, 1.0), false)
	_window(wall, sash, fposmod(.53 + float(flat) * .29, 1.0), false)
	var glass_z := -BALCONY - .062
	match flat:
		0:
			_curtain(door, glass_z, Color("#a7b2a2"), .36)
			_old_unit(x0 + 3.5, base)
			_laundry(x0 + .25, x0 + 2.6, base, [[Color("#e8e4d8"), .46, .62, true], [Color("#3c5a7a"), .46, .62, true], [Color("#c9b8a0"), .4, .78], [Color("#d8d8d2"), .3, .5], [Color("#7a3a34"), .3, .5]])
		1:
			_curtain(door, glass_z, LACE, .8)
			_sudare(x0 + .25, x0 + 2.65, base)
			_heat_pump(x0 + 3.4, base)
			_pot(x0 + 2.75, base, -.4, .55, Color("#3f6a35"))
		2:
			_curtain(door, glass_z, Color("#5b4a56"), .62)
			_curtain(sash, glass_z, Color("#5b4a56"), .5)
			_heat_pump(x0 + .75, base)
			_bar("plain", _front, x0 + 3.2, base + .36, -.82, Vector3(1.1, .7, .5), Color("#b6b09e"), .7, 1.0)
		3:
			_curtain(door, glass_z, Color("#c7bfa8"), .22)
			_old_unit(x0 + 3.5, base)
			_laundry(x0 + .35, x0 + 2.4, base, [[Color("#d5d9dc"), .5, .9], [Color("#26304a"), .36, .84], [Color("#e2e0d8"), .28, .46]])
		4:
			_curtain(door, glass_z, LACE, .55)
			_curtain(sash, glass_z, LACE, 1.0)
			_old_unit(x0 + .78, base)
			for i: int in range(5):
				_pot(x0 + 1.75 + float(i) * .46, base, -.38 - .12 * float(i % 2), _rng.randf_range(.4, .95), Color("#3f6a35").lightened(float(i) * .05))
		5:
			_shutter(door)
			_shutter(sash)
		6:
			_curtain(door, glass_z, Color("#3a4a5c"), .5)
			_heat_pump(x0 + 3.4, base)
			_laundry(x0 + .4, x0 + 2.5, base, [[Color("#f0ece0"), .26, .38, true], [Color("#e0a33c"), .26, .38, true], [Color("#7fb0c8"), .24, .36], [Color("#e8e4d8"), .46, .62, true]])
			_bar("plain", _front, x0 + 2.6, base + .16, -.72, Vector3(.42, .32, .34), Color("#3f8c8a"), .8, 1.0)
		7:
			_blackout(door, glass_z)
			_blackout(sash, glass_z)
			_heat_pump(x0 + .8, base)
			_pot(x0 + 3.9, base, -.42, .8, Color("#35592e"))

func _balcony_front(index: int, bay: int, x0: float, base: float) -> void:
	# Flats that could afford it swapped their concrete for solar glass after the '38 rebate.
	var f := _front
	var mid := x0 + BAY * .5
	var flat := index * 2 + bay
	if flat in [2, 6, 7]:
		for i: int in range(3):
			_solar_module(Transform3D(f.basis, f * Vector3(mid + (float(i) - 1.0) * 1.44, base + .52, -.06)), 1.4, .92)
		_bar("metal", f, mid, base + .03, -.06, Vector3(BAY, .06, .08), Color("#6d7073"))
	else:
		_kit.block("render", _at(f, mid, base + .47, -.07), Vector3(BAY, .94, .14), CREAM, .86, 1.0, .4, Vector2(x0, base))
		_bar("plain", f, mid, base + .66, .004, Vector3(BAY, .025, .012), Color("#8f897a"))
	var rail := Color("#b2b4b0") if flat % 2 == 0 else Color("#a8aaa5")
	_bar("metal", f, mid, base + 1.15, -.07, Vector3(BAY, .04, .06), rail)
	for i: int in range(5):
		_bar("metal", f, x0 + .12 + float(i) * (BAY - .24) / 4.0, base + 1.03, -.07, Vector3(.03, .22, .03), rail)

func _curtain(r: Rect2, z: float, tint: Color, close: float) -> void:
	# Drawn from the left to how far this household likes it.
	var wall := _front
	var folds := int(r.size.x * 9.0)
	for i: int in range(folds):
		var a := r.position.x + .03 + (r.size.x - .06) * close * float(i) / float(folds)
		var b := r.position.x + .03 + (r.size.x - .06) * close * float(i + 1) / float(folds)
		var tone := tint * (.86 + .16 * sin(float(i) * 2.3))
		_kit.quad("plain", wall * Vector3(a, r.position.y + .05, z + .004 * float(i % 2)), wall * Vector3(a, r.end.y - .04, z + .004 * float(i % 2)), wall * Vector3(b, r.end.y - .04, z + .004 * float((i + 1) % 2)), wall * Vector3(b, r.position.y + .05, z + .004 * float((i + 1) % 2)), tone, .86, .95)

func _blackout(r: Rect2, z: float) -> void:
	# Blackout blind with the faintest light of a rig leaking round it.
	_kit.quad("plain", _front * Vector3(r.position.x + .03, r.position.y + .04, z), _front * Vector3(r.position.x + .03, r.end.y - .03, z), _front * Vector3(r.end.x - .03, r.end.y - .03, z), _front * Vector3(r.end.x - .03, r.position.y + .04, z), Color("#17181c"), .9, 1.0)
	_strip(_front * Vector3(r.position.x + .05, r.position.y + .06, z + .004), _front * Vector3(r.end.x - .05, r.position.y + .06, z + .004), Color(.5, .26, .9) * .55)

func _shutter(r: Rect2) -> void:
	# Nobody has lived here since the water: rain shutters down, the paint going.
	var f := _front.translated_local(Vector3(0, 0, -BALCONY))
	var y := r.position.y
	while y < r.end.y:
		_kit.quad("paint", f * Vector3(r.position.x, y, .012), f * Vector3(r.position.x, y + .1, .004), f * Vector3(r.end.x, y + .1, .004), f * Vector3(r.end.x, y, .012), Color("#7d8078"), .9, 1.0, .7, Vector2(r.position.x, -y))
		y += .1
	_bar("metal", f, r.get_center().x, r.end.y + .08, .08, Vector3(r.size.x + .1, .16, .16), Color("#6e6f6a"))
	for x: float in [r.position.x, r.end.x]:
		_bar("metal", f, x, r.get_center().y, .03, Vector3(.05, r.size.y, .06), Color("#6e6f6a"))

func _old_unit(x: float, base: float) -> void:
	# Condenser on the balcony floor, its pipe taped up the wall and in.
	_outdoor_unit(_front, x, base + .4, -BALCONY + .24)
	for dx: float in [-.3, .3]:
		_bar("metal", _front, x + dx, base + .04, -BALCONY + .24, Vector3(.05, .08, .32), STEEL)
	_kit.tube("plain", [_front * Vector3(x + .46, base + .36, -BALCONY + .1), _front * Vector3(x + .46, base + 2.1, -BALCONY + .05)], .03, Color("#cfc9b8"), 6)

func _heat_pump(x: float, base: float) -> void:
	# The new kind: thin, dark and quiet, one sealed fan behind a fine grille.
	var f := _front
	var z := -BALCONY + .22
	_bar("metal", f, x, base + .1, z, Vector3(.8, .05, .3), STEEL)
	_bar("metal", f, x, base + .52, z, Vector3(.96, .8, .3), Color("#2b2e31"))
	var front := f * Vector3(x, base + .54, z + .152)
	_kit.disc("plain", front, f.basis.x, f.basis.y, .29, Color("#121315"))
	for ring: float in [.1, .19, .28]:
		var points: Array[Vector3] = []
		for i: int in range(17):
			var angle := TAU * float(i) / 16.0
			points.append(front + (f.basis.x * cos(angle) + f.basis.y * sin(angle)) * ring + f.basis.z * .006)
		_kit.tube("metal", points, .004, Color("#55585a"), 3)
	_status(f, x + .4, base + .84, z + .154, GREEN)

func _laundry(x0: float, x1: float, base: float, garments: Array) -> void:
	# A pole on two hangers from the slab; each thing on it has come out of the wash differently.
	var f := _front
	var y := base + 2.04
	var z := -.46
	_kit.tube("metal", [f * Vector3(x0, y, z), f * Vector3(x1, y, z)], .016, ALUMINIUM, 6)
	for x: float in [x0 + .16, x1 - .16]:
		_kit.tube("metal", [f * Vector3(x, base + STOREY - SOFFIT, z), f * Vector3(x, y, z)], .008, STEEL, 4)
	var at := x0 + .3
	for garment: Array in garments:
		var cloth: Color = garment[0]
		var wide: float = garment[1]
		var tall: float = garment[2]
		var turn := Basis(Vector3.UP, _rng.randf_range(-.28, .28))
		var mid := f * Vector3(at + wide * .5, y - tall * .5 - .04, z)
		_kit.block("plain", Transform3D(turn, mid), Vector3(wide, tall, .012), cloth, .78, 1.0)
		if garment.size() > 3:
			for side: float in [-1.0, 1.0]:
				var sleeve := mid + turn * Vector3(side * (wide * .5 + wide * .13), tall * .34, 0)
				_kit.block("plain", Transform3D(turn * Basis(Vector3.BACK, side * .65), sleeve), Vector3(wide * .34, tall * .42, .012), cloth * .93, .8, 1.0)
		at += wide + .17

func _sudare(x0: float, x1: float, base: float) -> void:
	# Reed blind hung against the afternoon sun.
	var f := _front
	var top := base + STOREY - SOFFIT - .04
	var low := base + .62
	var z := -.34
	_kit.block("plain", _at(f, (x0 + x1) * .5, (top + low) * .5, z), Vector3(x1 - x0, top - low, .01), Color("#a58a5c"), .85, 1.0)
	var y := low + .02
	while y < top:
		_kit.quad("plain", f * Vector3(x0, y, z + .007), f * Vector3(x0, y + .012, z + .007), f * Vector3(x1, y + .012, z + .007), f * Vector3(x1, y, z + .007), Color("#7a6340"), 1.0, 1.0)
		y += .055 + _rng.randf() * .02
	for x: float in [x0 + .3, (x0 + x1) * .5, x1 - .3]:
		_bar("plain", f, x, (top + low) * .5, z + .009, Vector3(.012, top - low, .006), Color("#4e3f28"))

func _pot(x: float, base: float, z: float, tall: float, tint: Color) -> void:
	var at := _front * Vector3(x, base, z)
	_kit.lathe("plain", at, [Vector2(.09, 0), Vector2(.13, .22), Vector2(.14, .24)], Color("#8c5a3c"), 9)
	_plant(at + Vector3.UP * .2, tall, tint)
	_plant(at + Vector3.UP * .22, tall * .7, tint.lightened(.1))

func _east_side() -> void:
	# The side street: the shop's glass turns the corner, then plain render, plant and pipes.
	var e := _east
	var glass := Rect2(.34, .42, 3.2, 2.44)
	var stock := Rect2(5.5, 0, 1.1, 2.2)
	var holes: Array[Rect2] = [glass, stock]
	for floor_index: int in range(FLOORS):
		var y := GROUND + float(floor_index) * STOREY
		holes.append(Rect2(2.5, y + .95, 1.2, 1.1))
		holes.append(Rect2(6.4, y + 1.25, .7, .8))
	_render_wall(e, DEEP, PARAPET, GROUND, STOREY, PALE, holes)
	_bar("render", e, DEEP * .5, PARAPET + .05, -.05, Vector3(DEEP + .1, .1, .3), CREAM, .7, 1.0)
	_brown(e, .34, 3.54, 0.0, .42, .005, .7, .9, .2)
	_reveal(e, glass, .12, ALUMINIUM)
	_kit.quad("front", e * Vector3(glass.position.x, glass.position.y, -.12), e * Vector3(glass.position.x, glass.end.y, -.12), e * Vector3(glass.end.x, glass.end.y, -.12), e * Vector3(glass.end.x, glass.position.y, -.12), Color.WHITE)
	for x: float in [.34, 1.4, 2.47, 3.54]:
		_bar("metal", e, x, (glass.position.y + glass.end.y) * .5, -.1, Vector3(.06, glass.size.y, .1), ALUMINIUM)
	_panel("decal", e, 2.62, 3.32, 1.7, 2.6, -.108, _cell(0, 1216, 240, 340))
	for floor_index: int in range(FLOORS):
		var y := GROUND + float(floor_index) * STOREY
		var cell := fposmod(.23 + float(floor_index) * .31, 1.0)
		_window(e, Rect2(2.5, y + .95, 1.2, 1.1), cell, floor_index == 0)
		_window(e, Rect2(6.4, y + 1.25, .7, .8), fposmod(cell + .41, 1.0), true)
		# Condenser on a wall bracket, its pipes in ivory duct.
		var unit := Vector2(4.6, y + .5)
		_outdoor_unit(e, unit.x, unit.y, .22)
		for x: float in [unit.x - .3, unit.x + .3]:
			_bar("metal", e, x, unit.y - .33, .22, Vector3(.04, .04, .44), STEEL)
		_kit.tube("plain", [e * Vector3(3.8, y + 1.4, .04), e * Vector3(4.1, y + 1.4, .04), e * Vector3(4.1, unit.y + .1, .04)], .04, Color("#c8c2b0"), 6)
	# Stock door, soil stack, and the service run up to the roof.
	_reveal(e, stock, .08, Color("#5b5c58"))
	_bar("paint", e, stock.get_center().x, 1.1, -.07, Vector3(1.06, 2.16, .04), Color("#6d7a7c"), .85, 1.0)
	_bar("metal", e, stock.position.x + .92, 1.05, -.03, Vector3(.03, .22, .05), ALUMINIUM)
	_bar("metal", e, stock.get_center().x, 2.34, .04, Vector3(1.3, .05, .16), Color("#6e6f6a"))
	var pipe := e * Vector3(5.25, .0, .08)
	_kit.tube("metal", [pipe + Vector3.UP * .1, pipe + Vector3.UP * (PARAPET - .3)], .05, Color("#8a8b84"), 7)
	var clip := GROUND
	while clip < PARAPET:
		_bar("metal", e, 5.25, clip, .08, Vector3(.14, .03, .14), STEEL)
		clip += STOREY
	_fibre([e * Vector3(7.8, PARAPET - .1, .03), e * Vector3(7.8, 4.2, .03), e * Vector3(6.9, 3.0, .03), e * Vector3(6.9, 2.3, .03)])
	_battery_cabinet()

func _battery_cabinet() -> void:
	# Swap-your-cell cabinet for scooters and prosthetics, charged off the balconies upstairs.
	var e := _east
	var mid := 4.65
	var tall := 1.86
	_bar("metal", e, mid, tall * .5, .32, Vector3(1.5, tall, .62), Color("#1a1d20"), .8, 1.0)
	_panel("display", e, mid - .72, mid + .72, tall - .3, tall - .04, .634, _cell(300, 1566, 480, 84))
	for row: int in range(3):
		for column: int in range(4):
			var cx := mid - .54 + float(column) * .36
			var cy := .3 + float(row) * .46
			_bar("metal", e, cx, cy, .632, Vector3(.3, .4, .012), Color("#2e3236"))
			_bar("metal", e, cx, cy + .02, .64, Vector3(.1, .02, .02), Color("#7c8084"))
			var empty := (row * 4 + column) % 5 == 2
			_status(e, cx + .1, cy - .14, .64, AMBER if empty else GREEN)
	_kit.tube("plain", [e * Vector3(mid, tall, .1), e * Vector3(mid, 2.86, .05)], .02, Color("#17181a"), 5)

func _west_side() -> void:
	# Faces the pencil building across a gap a metre wide: only its top ever sees the sun.
	var w := _west
	var holes: Array[Rect2] = []
	for floor_index: int in range(FLOORS):
		holes.append(Rect2(4.0, GROUND + float(floor_index) * STOREY + 1.2, .7, .8))
	_render_wall(w, DEEP, PARAPET, GROUND, STOREY, PALE * .94, holes)
	_bar("render", w, DEEP * .5, PARAPET + .05, -.05, Vector3(DEEP + .1, .1, .3), CREAM, .7, 1.0)
	for floor_index: int in range(FLOORS):
		_window(w, Rect2(4.0, GROUND + float(floor_index) * STOREY + 1.2, .7, .8), fposmod(.71 + float(floor_index) * .23, 1.0), true)

func _rooftop() -> void:
	var half := WIDE * .5
	var level := TOP + .02
	_kit.quad("plain", Vector3(-half, level, -.18), Vector3(-half, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, -.18), Color("#62625e"), .8, .9)
	var inner := Color(.8, .78, .72)
	_kit.quad("render", Vector3(-half + .02, level, -DEEP), Vector3(-half + .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, level, -DEEP), inner, .7, 1.0, .8)
	_kit.quad("render", Vector3(-half + .02, level, -.18), Vector3(-half + .02, PARAPET, -.18), Vector3(-half + .02, PARAPET, -DEEP), Vector3(-half + .02, level, -DEEP), inner, .7, 1.0, .8)
	_kit.quad("render", Vector3(half - .02, level, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -.18), Vector3(half - .02, level, -.18), inner, .7, 1.0, .8)
	# Stair head at the back, its door, and the old aerial nobody took down.
	var head := Vector3(-2.7, TOP + 1.35, -7.4)
	var size := Vector3(2.8, 2.7, 3.6)
	_kit.block("render", Transform3D(Basis.IDENTITY, head), size, PALE * .92, .75, 1.0, .9)
	_bar("render", Transform3D.IDENTITY, head.x, head.y + size.y * .5 + .05, head.z, Vector3(size.x + .14, .1, size.z + .14), CREAM, .7, 1.0)
	var wall := Transform3D(Basis.IDENTITY, head + Vector3(-size.x * .5, -size.y * .5, size.z * .5 + .01))
	_bar("paint", wall, 1.1, 1.0, .02, Vector3(.82, 1.98, .05), Color("#6d7a7c"), .85, 1.0)
	var mast := head + Vector3(.5, size.y * .5, -.6)
	_kit.tube("metal", [mast, mast + Vector3.UP * 3.0], .022, Color("#7a7468"), 6)
	for i: int in range(5):
		var y := 2.1 + float(i) * .16
		var reach := .62 - float(i) * .08
		_kit.tube("metal", [mast + Vector3(-reach, y, 0), mast + Vector3(reach, y, 0)], .007, Color("#6b5d4c"), 4)
	_kit.tube("metal", [mast + Vector3(0, 2.1, -.5), mast + Vector3(0, 2.1, .5)], .012, Color("#6b5d4c"), 4)
	# Common-parts solar on a low frame, and the rack that keeps the flats running when the grid does not.
	var pitch := Basis(Vector3.RIGHT, -.2)
	for row: int in range(2):
		for column: int in range(3):
			_solar_module(Transform3D(pitch, Vector3(-.5 + float(column) * 1.62, TOP + .72, -2.2 - float(row) * 2.4)), 1.56, 2.0)
	for x: float in [-1.3, .32, 1.94, 3.56]:
		for z: float in [-2.9, -5.3]:
			_kit.block("metal", Transform3D(Basis.IDENTITY, Vector3(x, TOP + .34, z)), Vector3(.05, .68, .05), STEEL)
	_bar("metal", Transform3D(Basis.IDENTITY, Vector3(0, level, 0)), 2.2, .64, -7.6, Vector3(1.8, 1.28, .6), Color("#c9cbc7"))
	_status(Transform3D(Basis.IDENTITY, Vector3(0, level, 0)), 1.6, 1.1, -7.29, GREEN)
	_status(Transform3D(Basis.IDENTITY, Vector3(0, level, 0)), 1.72, 1.1, -7.29, GREEN)
	_status(Transform3D(Basis.IDENTITY, Vector3(0, level, 0)), 1.84, 1.1, -7.29, AMBER)
	# Dish on a bracket, lightning rod at the corner, fibre over the parapet.
	var dish := Vector3(-3.6, PARAPET + .4, -.4)
	_kit.tube("metal", [Vector3(dish.x, PARAPET, dish.z), dish], .02, Color("#8d9092"), 5)
	_kit.disc("metal", dish + Vector3(0, .1, .06), Vector3.RIGHT, Vector3(0, .9, .35).normalized(), .3, Color("#c7c8c4"))
	_kit.tube("metal", [Vector3(half - .3, PARAPET, -.3), Vector3(half - .3, PARAPET + 2.2, -.3)], .012, Color("#7f8488"), 4)
	_fibre([Vector3(half - .1, PARAPET + .04, -2.0), Vector3(half + .03, PARAPET + .02, -2.0), Vector3(half + .03, PARAPET - .1, -2.0)])

func _street_things() -> void:
	# Drink machine against the tiles, recycling by the door, the flood boards stacked ready.
	var f := _front
	var mid := 2.12
	_bar("plain", f, mid, .95, .4, Vector3(1.02, 1.9, .8), Color("#e4e5e2"), .8, 1.0)
	_panel("display", f, mid - .5, mid + .5, .04, 1.86, .802, _cell(0, 1560, 280, 488))
	_bar("metal", f, mid, 1.92, .46, Vector3(1.08, .06, .92), Color("#c6c8c6"))
	_bar("metal", f, mid, .03, .4, Vector3(1.02, .06, .8), Color("#2a2c2e"))
	var tints: Array[Color] = [Color("#3f7a4c"), Color("#2f5f9c"), Color("#c9c5b8")]
	for i: int in range(3):
		var x := 5.72 + float(i) * .4
		_bar("plain", f, x, .46, .14, Vector3(.36, .92, .36), tints[i], .85, 1.0)
		_bar("plain", f, x, .95, .14, Vector3(.38, .06, .38), Color("#2c2e30"))
		_kit.disc("plain", f * Vector3(x, .78, .322), f.basis.x, f.basis.y, .09, Color("#121315"))
	# Aluminium stop-logs stacked by the side, chained so nobody walks off with them.
	for i: int in range(4):
		_bar("metal", f, 3.9, .08 + float(i) * .115, -.2, Vector3(1.5, .1, .05), Color("#adb0ae"))
	_kit.tube("metal", [f * Vector3(3.3, .5, -.165), f * Vector3(3.3, .02, -.165)], .012, Color("#3c3f42"), 5)
