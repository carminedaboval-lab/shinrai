extends "res://scripts/midori_near_city_handmade.gd"
## ふわりビル: the newest thing on the street, put up in 2031 on a plot barely four metres
## wide. Charcoal metal and cedar, a coin laundry open all night, a hair salon upstairs
## with a pole that still turns, and two flats under a roof tilted at the sun.
const ATLAS := "res://assets/shinrai/near_city/laundry_atlas.png"
const WIDE := 4.25
const DEEP := 7.0
const GROUND := 3.1
const STOREY := 2.8
const TOP := 11.5
const RIDGE := 12.5 # The roof climbs to the back of the plot.
const SHOP := Rect2(.15, .12, 3.05, 2.6)
const ROOM_DEEP := 6.1
const SLATE := Color(.5, .52, .55)
const CEDAR := Color(.72, .5, .32)
const FRAME := Color("#26282b")
const SKY := Color(.72, .88, .94)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _pole: Node3D

func _ready() -> void:
	_rng.seed = 2031
	_build_looks()
	_street_front()
	_laundry()
	_salon()
	_flats()
	_flanks()
	_roof()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "leaf", "led", "shop", "floor", "goods", "sign", "room"])
	_kit = null
	_barber_pole()
	_omni("LaundrySpill", Vector3(-.5, 2.2, .9), Color(.88, .95, 1.0), .9, 7.0)
	_omni("LaundryRoom", Vector3(-.5, 2.2, -2.6), Color(.9, .96, 1.0), .6, 6.0)

func _process(delta: float) -> void:
	_pole.rotate_y(delta * 1.4)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.steel = _look("corrugated_iron_02", 1.0, .8, .3)
	_looks.steel.set_shader_parameter("chroma", .2)
	_looks.cedar = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.cedar.set_shader_parameter("chroma", .62)
	_looks.shop = _look("", 1.0, .6)
	_looks.shop.set_shader_parameter("glow", .46)
	_looks.shop.set_shader_parameter("day_glow", .24)
	_looks.floor = _look("", 1.0, .14)
	_looks.floor.set_shader_parameter("tile_size", Vector2(.3, .3))
	_looks.floor.set_shader_parameter("glow", .2)
	_looks.floor.set_shader_parameter("day_glow", .12)
	_looks.room = _look("", 1.0, .7)
	_looks.room.set_shader_parameter("glow", .36)
	_looks.room.set_shader_parameter("day_glow", .12)
	_looks.goods = _look("", 1.0, .4)
	_looks.goods.set_shader_parameter("albedo_map", signs)
	_looks.goods.set_shader_parameter("glow", .6)
	_looks.goods.set_shader_parameter("day_glow", .3)
	_looks.sign = _look("", 1.0, .35)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .7)
	_looks.sign.set_shader_parameter("day_glow", .14)
	_looks.painted = _look("", 1.0, .6)
	_looks.painted.set_shader_parameter("albedo_map", signs)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .55)
	letters.set_shader_parameter("day_glow", .22)
	_looks.decal = letters

func _clad(part: String, face: Transform3D, area: Rect2, holes: Array[Rect2], tint: Color) -> void:
	# Sheet wall with its openings cut out, the texture keeping its place across the pieces.
	for piece: Rect2 in _minus(area, holes):
		_kit.quad(part, face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), tint, .9, 1.0, .25, Vector2(piece.position.x, -piece.position.y))

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect)

func _street_front() -> void:
	# Cedar at hand height, the board over the glass, and the sheep out on its arm.
	var f := _front
	var door := Rect2(3.45, 0, .66, 2.3)
	var holes: Array[Rect2] = [SHOP, door]
	_clad("cedar", f, Rect2(0, 0, WIDE, GROUND), holes, CEDAR)
	_reveal(f, SHOP, .1, Color("#3a3028"))
	_kit.quad("front", f * Vector3(SHOP.position.x, SHOP.position.y, -.1), f * Vector3(SHOP.position.x, SHOP.end.y, -.1), f * Vector3(SHOP.end.x, SHOP.end.y, -.1), f * Vector3(SHOP.end.x, SHOP.position.y, -.1), Color.WHITE)
	for x: float in [SHOP.position.x, 1.6, SHOP.end.x]:
		_bar("metal", f, x, SHOP.get_center().y, -.08, Vector3(.05, SHOP.size.y, .06), FRAME)
	for y: float in [SHOP.position.y + .02, SHOP.end.y - .02]:
		_bar("metal", f, SHOP.get_center().x, y, -.08, Vector3(SHOP.size.x, .05, .06), FRAME)
	_panel("decal", f, .3, 3.1, 2.76, 3.04, .012, _cell(0, 0, 900, 150))
	_panel("decal", f, 3.2, 4.1, 2.74, 3.06, .012, _cell(880, 0, 420, 150))
	_panel("goods", f, 1.72, 2.5, 1.5, 2.08, -.12, _cell(0, 310, 420, 320))
	_panel("goods", f, 2.56, 3.14, 1.6, 2.4, -.12, _cell(840, 310, 300, 420))
	_panel("goods", f, .26, 1.5, 2.12, 2.64, -.12, _cell(430, 310, 400, 170))
	# Stair door to the floors above, its plate, and a palm reader.
	_reveal(f, door, .18, Color("#3a3028"))
	_bar("metal", f, door.get_center().x, 1.15, -.17, Vector3(.62, 2.26, .04), Color("#2d3033"))
	_panel("sign", f, 3.54, 4.02, 1.62, 1.88, -.145, _cell(720, 960, 280, 150))
	_bar("bottle", f, 3.54, 1.2, -.14, Vector3(.05, .13, .02), Color("#0b0c0e"))
	_status(f, 3.54, 1.2, -.126, CYAN)
	# Blade sign on a thin arm, two sided, the sheep looking both ways down the pavement.
	var arm := Color("#2a2c2e")
	var hub := f * Vector3(.08, 3.7, .68)
	_kit.tube("metal", [f * Vector3(.08, 3.7, 0), hub + Vector3(0, 0, -.45)], .02, arm, 5)
	var rect := _cell(1352, 2, 296, 296)
	_kit.disc("sign", hub + Vector3.RIGHT * .05, Vector3.FORWARD, Vector3.UP, .46, Color.WHITE, rect)
	_kit.disc("sign", hub + Vector3.LEFT * .05, Vector3.BACK, Vector3.UP, .46, Color.WHITE, rect)
	var ring: Array[Vector3] = []
	for i: int in range(29):
		var angle := TAU * float(i) / 28.0
		ring.append(hub + Vector3(0, sin(angle), cos(angle)) * .47)
	_kit.tube("metal", ring, .05, Color("#d6d9d8"), 6)
	_camera(f * Vector3(3.6, 3.02, .1))

func _laundry() -> void:
	# Machines down one wall, dryers stacked at the end, a bench and a table to fold on.
	var f := _front
	var x0 := SHOP.position.x
	var x1 := SHOP.end.x + .1
	var far := -ROOM_DEEP
	_kit.quad("floor", f * Vector3(x0, .03, -.1), f * Vector3(x0, .03, far), f * Vector3(x1, .03, far), f * Vector3(x1, .03, -.1), Color(.84, .86, .86), 1.0, 1.0, 0.0, Vector2(x0, 0))
	_kit.quad("shop", f * Vector3(x0, 2.82, far), f * Vector3(x0, 2.82, -.1), f * Vector3(x1, 2.82, -.1), f * Vector3(x1, 2.82, far), Color(.76, .8, .82))
	var left := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x0, 0, -.1))
	var right := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x1, 0, far))
	var length := ROOM_DEEP - .1
	_kit.quad("shop", left * Vector3(0, 0, 0), left * Vector3(0, 2.82, 0), left * Vector3(length, 2.82, 0), left * Vector3(length, 0, 0), SKY * .8, .8, 1.0)
	_kit.quad("shop", right * Vector3(0, 0, 0), right * Vector3(0, 2.82, 0), right * Vector3(length, 2.82, 0), right * Vector3(length, 0, 0), SKY * .8, .8, 1.0)
	_kit.quad("shop", f * Vector3(x0, 0, far), f * Vector3(x0, 2.82, far), f * Vector3(x1, 2.82, far), f * Vector3(x1, 0, far), SKY * .7, .8, 1.0)
	for z: float in [-1.2, -3.0, -4.8]:
		_kit.quad("lamp", f * Vector3(1.3, 2.81, z - .7), f * Vector3(1.3, 2.81, z + .7), f * Vector3(1.5, 2.81, z + .7), f * Vector3(1.5, 2.81, z - .7), Color(.64, .68, .7))
	# Five washers along the left wall, each a real drum behind a real door.
	for i: int in range(5):
		_washer(left, 1.0 + float(i) * .86, .0, .76, i)
	# Dryers two high across the end wall.
	var end := f.translated_local(Vector3(0, 0, far))
	for column: int in range(4):
		for row: int in range(2):
			_washer(end, x0 + .4 + float(column) * .76, .1 + float(row) * .8, .7, column + row * 3 + 5)
	# Folding table, bench, and a basket somebody forgot.
	_bar("shop", f, 2.76, .84, -2.6, Vector3(.6, .05, 1.8), Color(.86, .82, .74))
	_bar("metal", f, 2.76, .42, -2.6, Vector3(.08, .82, 1.5), STEEL)
	_bar("shop", f, 2.9, .44, -4.4, Vector3(.4, .05, 1.3), CEDAR)
	_bar("metal", f, 2.9, .22, -4.4, Vector3(.3, .42, .06), STEEL)
	_kit.lathe("plain", f * Vector3(2.7, .87, -2.1), [Vector2(.17, 0), Vector2(.22, .22), Vector2(.23, .24)], Color("#4a9fd0"), 10)
	for i: int in range(4):
		_bar("plain", f, 2.62 + float(i) * .05, .95 + float(i) * .04, -2.9 - float(i) * .02, Vector3(.34, .03, .3), [Color("#e8e0cc"), Color("#f0a0c0"), Color("#ffffff"), Color("#3a8fd0")][i], .8, 1.0)

func _washer(wall: Transform3D, x: float, y: float, size: float, seed_at: int) -> void:
	# Steel case, a round door of dark glass, and the washing going round behind it.
	var body := .78 if y == 0.0 else size
	_bar("shop", wall, x, y + body * .5, .36, Vector3(size - .03, body, .7), Color(.88, .9, .9))
	var face := wall * Vector3(x, y + body * .52, .715)
	var reach := size * .36
	var running := seed_at % 3 != 2
	var rect := _cell(1200, 310, 200, 200) if running else Rect2()
	if running:
		_kit.disc("goods", face, wall.basis.x, wall.basis.y, reach, Color.WHITE, rect)
	else:
		_kit.disc("plain", face, wall.basis.x, wall.basis.y, reach, Color("#20262b"))
	var ring: Array[Vector3] = []
	for i: int in range(19):
		var angle := TAU * float(i) / 18.0
		ring.append(face + (wall.basis.x * cos(angle) + wall.basis.y * sin(angle)) * reach + wall.basis.z * .006)
	_kit.tube("metal", ring, .022, Color("#b9bcbc"), 5)
	var screen := _cell(1420, 310, 300, 110) if running else _cell(1730, 310, 300, 110)
	_panel("goods", wall, x - .17, x + .17, y + body - .17, y + body - .05, .715, screen)

func _salon() -> void:
	# ヘアサロン みゆき: one wide window, chairs facing their mirrors, a comb on the glass.
	var f := _front
	var base := GROUND
	var r := Rect2(.2, base + .62, 3.85, 1.86)
	var holes: Array[Rect2] = [r]
	_clad("steel", f, Rect2(0, base, WIDE, STOREY), holes, SLATE)
	var far := -2.2
	_reveal(f, r, .14, FRAME)
	_kit.quad("room", f * Vector3(r.position.x, r.position.y - .3, far), f * Vector3(r.position.x, r.end.y + .1, far), f * Vector3(r.end.x, r.end.y + .1, far), f * Vector3(r.end.x, r.position.y - .3, far), Color("#e8c4c8"), .8, 1.0)
	_kit.quad("room", f * Vector3(r.position.x, r.end.y, far), f * Vector3(r.position.x, r.end.y, -.14), f * Vector3(r.end.x, r.end.y, -.14), f * Vector3(r.end.x, r.end.y, far), Color("#f4ece4"))
	_kit.quad("room", f * Vector3(r.position.x, r.position.y - .02, -.14), f * Vector3(r.position.x, r.position.y - .02, far), f * Vector3(r.end.x, r.position.y - .02, far), f * Vector3(r.end.x, r.position.y - .02, -.14), Color("#8a7060"))
	_kit.quad("room", f * Vector3(r.position.x, r.position.y, -.14), f * Vector3(r.position.x, r.end.y, -.14), f * Vector3(r.position.x, r.end.y, far), f * Vector3(r.position.x, r.position.y, far), Color("#e0b4bc"), .85, 1.0)
	_kit.quad("room", f * Vector3(r.end.x, r.position.y, far), f * Vector3(r.end.x, r.end.y, far), f * Vector3(r.end.x, r.end.y, -.14), f * Vector3(r.end.x, r.position.y, -.14), Color("#e0b4bc"), .85, 1.0)
	for i: int in range(2):
		var x := 1.2 + float(i) * 1.8
		_bar("metal", f, x, r.position.y + 1.0, far + .03, Vector3(1.1, 1.4, .03), Color("#c7d4d8"))
		_bar("lamp", f, x - .62, r.position.y + 1.0, far + .05, Vector3(.04, 1.3, .02), Color(.8, .78, .7))
		_bar("lamp", f, x + .62, r.position.y + 1.0, far + .05, Vector3(.04, 1.3, .02), Color(.8, .78, .7))
		_bar("room", f, x, r.position.y + .42, -1.25, Vector3(.56, .1, .56), Color("#2a2022"))
		_bar("room", f, x, r.position.y + .78, -.98, Vector3(.54, .7, .08), Color("#2a2022"))
		_kit.tube("metal", [f * Vector3(x, r.position.y + .36, -1.25), f * Vector3(x, r.position.y - .05, -1.25)], .04, ALUMINIUM, 7)
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, -.14), f * Vector3(r.position.x, r.end.y, -.14), f * Vector3(r.end.x, r.end.y, -.14), f * Vector3(r.end.x, r.position.y, -.14), Color.WHITE)
	for x: float in [r.position.x + .02, 2.12, r.end.x - .02]:
		_bar("metal", f, x, r.get_center().y, -.11, Vector3(.05, r.size.y, .06), FRAME)
	for y: float in [r.position.y + .02, r.end.y - .02]:
		_bar("metal", f, r.get_center().x, y, -.11, Vector3(r.size.x, .05, .06), FRAME)
	_panel("decal", f, .4, 3.0, r.end.y - .5, r.end.y - .1, -.128, _cell(0, 740, 980, 140))
	_panel("decal", f, .4, 3.1, r.position.y + .05, r.position.y + .26, -.128, _cell(0, 884, 1000, 66))
	_panel("decal", f, 3.2, 3.9, r.position.y + .6, r.position.y + 1.3, -.128, _cell(1080, 790, 200, 180))

func _flats() -> void:
	# A deep cedar-framed window on one floor, a slatted balcony on the next.
	var f := _front
	var base := GROUND + STOREY
	var square := Rect2(.5, base + .55, 1.9, 1.9)
	var banner := Rect2(2.72, base + .9, 1.3, .41)
	var holes: Array[Rect2] = [square]
	_clad("steel", f, Rect2(0, base, WIDE, STOREY), holes, SLATE)
	_kit.pane("glass", f, square.position.x, square.end.x, square.position.y, square.end.y, -.2, .41)
	_reveal(f, square, .2, CEDAR * .8)
	for x: float in [square.position.x - .06, square.end.x + .06]:
		_bar("cedar", f, x, square.get_center().y, .1, Vector3(.12, square.size.y + .24, .4), CEDAR)
	for y: float in [square.position.y - .06, square.end.y + .06]:
		_bar("cedar", f, square.get_center().x, y, .1, Vector3(square.size.x + .24, .12, .4), CEDAR)
	_bar("plain", f, 1.0, square.position.y + .95, -.16, Vector3(.9, 1.74, .01), Color("#e4dfd2"), .9, 1.0)
	# Vacancy banner cable-tied to the wall.
	_panel("painted", f, banner.position.x, banner.end.x, banner.position.y, banner.end.y, .03, _cell(0, 960, 700, 220))
	var upper := base + STOREY
	var recess := Rect2(.0, upper + .05, WIDE, 2.4)
	holes = [recess]
	_clad("steel", f, Rect2(0, upper, WIDE, TOP - upper), holes, SLATE)
	_clad("cedar", f.translated_local(Vector3(0, 0, -1.0)), recess, [] as Array[Rect2], CEDAR * .86)
	_reveal(f, recess, 1.0, Color("#6a5a48"))
	_kit.pane("glass", f, 2.0, 3.9, recess.position.y + .1, recess.end.y - .2, -.96, .23)
	var x := .1
	while x < 1.86:
		_bar("cedar", f, x, recess.get_center().y, -.05, Vector3(.05, recess.size.y, .07), CEDAR)
		x += .11
	_bar("metal", f, 3.0, recess.position.y + 1.05, -.03, Vector3(2.3, .03, .03), FRAME)
	for rail: float in [2.0, 3.0, 4.1]:
		_bar("metal", f, rail, recess.position.y + .52, -.03, Vector3(.02, 1.05, .02), FRAME)
	var pot := f * Vector3(3.5, recess.position.y, -.6)
	_kit.lathe("plain", pot, [Vector2(.1, 0), Vector2(.15, .3), Vector2(.16, .32)], Color("#3a3d40"), 9)
	_plant(pot + Vector3.UP * .3, 1.0, Color("#3f6a35"))

func _flanks() -> void:
	# Sheeting down both sides, climbing with the roof at the top of each.
	for face: Transform3D in [_east, _west]:
		_clad("steel", face, Rect2(0, 0, DEEP, TOP), [] as Array[Rect2], SLATE * .92)
	_kit.quad("steel", _east * Vector3(0, TOP, 0), _east * Vector3(0, TOP + .001, 0), _east * Vector3(DEEP, RIDGE, 0), _east * Vector3(DEEP, TOP, 0), SLATE * .92, .9, 1.0, .2, Vector2(0, -TOP))
	_kit.quad("steel", _west * Vector3(0, TOP, 0), _west * Vector3(0, RIDGE, 0), _west * Vector3(DEEP, TOP + .001, 0), _west * Vector3(DEEP, TOP, 0), SLATE * .92, .9, 1.0, .2, Vector2(0, -TOP))
	_clad("steel", _back, Rect2(0, 0, WIDE, RIDGE), [] as Array[Rect2], SLATE * .9)
	for row: int in range(2):
		var y := GROUND + 3.0 + float(row) * STOREY
		_window(_west, Rect2(3.0, y, .9, .9), fposmod(.31 + float(row) * .41, 1.0), false)
	_outdoor_unit(_west, 5.0, 6.8, .22)
	_fibre([_west * Vector3(6.2, RIDGE - .3, .03), _west * Vector3(6.2, 3.0, .03)])

func _roof() -> void:
	# Steel roof tilted at the sun, solar laid straight on it.
	var half := WIDE * .5 + .12
	var a := Vector3(-half, TOP - .02, .2)
	var b := Vector3(-half, RIDGE + .05, -DEEP - .1)
	var c := Vector3(half, RIDGE + .05, -DEEP - .1)
	var d := Vector3(half, TOP - .02, .2)
	_kit.quad("metal", a, b, c, d, Color("#3a3d40"), .9, 1.0)
	_kit.quad("metal", d, c, b, a, Color("#2a2c2e"), .7, .7)
	var seams := 7
	for i: int in range(seams):
		var t := float(i) / float(seams - 1)
		_kit.beam("metal", a.lerp(d, t) + Vector3.UP * .03, b.lerp(c, t) + Vector3.UP * .03, .03, .04, Vector3.UP, Color("#4a4d50"))
	var pitch := atan2(RIDGE - TOP, DEEP)
	var tilt := Basis(Vector3.RIGHT, -PI * .5 + pitch)
	for column: int in range(2):
		for row: int in range(3):
			var z := -1.6 - float(row) * 2.05
			var at := Vector3(-1.0 + float(column) * 2.0, TOP + (.2 - z) / (DEEP + .3) * (RIDGE - TOP) + .1, z)
			_solar_module(Transform3D(tilt, at), 1.9, 1.95)

func _barber_pole() -> void:
	# Its own little mesh, since it is the one thing on the street still moving.
	var f := _front
	var holder := Node3D.new()
	holder.name = "BarberPole"
	holder.position = f * Vector3(3.32, 1.05, .1)
	add_child(holder)
	var kit := Kit.new()
	kit.lathe("sign", Vector3.ZERO, [Vector2(.07, 0), Vector2(.07, .8)], Color.WHITE, 14, _cell(1420, 440, 240, 240))
	kit.commit(holder, _looks, ["sign"])
	_pole = holder
	var caps := Kit.new()
	var steel := Color("#c9cbc9")
	caps.lathe("metal", f * Vector3(3.32, .97, .1), [Vector2(.05, 0), Vector2(.09, .08), Vector2(.09, .09)], steel, 12)
	caps.lathe("metal", f * Vector3(3.32, 1.85, .1), [Vector2(.09, 0), Vector2(.09, .03), Vector2(.05, .1), Vector2(.01, .12)], steel, 12)
	caps.commit(self, _looks, [])
