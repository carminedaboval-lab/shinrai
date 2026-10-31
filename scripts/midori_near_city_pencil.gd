extends "res://scripts/midori_near_city_handmade.gd"
## 大黒ビル: a 1970s pencil building still standing in 2050, in pale glazed tile with
## eighty years of retrofits bolted on: seismic bracing, solar, trunk fibre, a micro-LED
## wall. The old coffee shop keeps the street; a prosthetics clinic, a device repairer
## and a VR bar stack above it, each named on its window glass.
const ATLAS := "res://assets/shinrai/near_city/pencil_atlas.png"
const SCREEN_FRAMES := "res://assets/shinrai/near_city/screen_frames.png"
const SCREEN_SHADER := preload("res://scripts/midori_near_city_screen.gdshader")
const ScreenPlayer := preload("res://scripts/midori_near_city_screen.gd")
const WIDE := 5.7
const DEEP := 9.7
const GROUND := 3.6
const STOREY := 3.0
const FLOORS := 3
const TOP := 12.6
const PARAPET := 13.5
const PIER := .38
const INFILL := -.14 # Spandrels sit back from the piers.
const GLASS_LINE := -.26
const CELADON := Color(.6, .71, .65)
const BRONZE := Color("#3b332a")
const STONE := Color("#2c2826")
const RENDER := Color(1.26, 1.24, 1.18)
const STAIN := Color("#5a3d29")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1974
	_build_looks()
	_front_frame()
	for floor_index: int in range(FLOORS):
		_storey(floor_index)
	_coffee_shop()
	_stair_door()
	_sign_tower()
	_flank(_west, 11)
	_flank(_east, 29)
	_rear()
	_rooftop()
	_retrofit()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "leaf", "screen", "neon", "led"])
	_kit = null
	_omni("CafeGlow", Vector3(-1.1, 2.0, -1.0), Color(1.0, .8, .56), 1.2, 6.5)
	_omni("StairGlow", Vector3(1.9, 2.1, .4), Color(.82, .92, 1.0), .7, 4.5)
	var player: Node = ScreenPlayer.new()
	player.name = "ScreenPlayer"
	add_child(player)
	player.play_on(_looks.screen)

func _build_looks() -> void:
	_shared_looks()
	_looks.glazed = _look("", 1.0, .34)
	_looks.glazed.set_shader_parameter("tile_size", Vector2(.114, .062))
	_looks.render = _look("plastered_wall_03", 4.0, 1.0)
	_looks.render.set_shader_parameter("chroma", .55)
	_looks.hall = _look("", 1.0, .7)
	_looks.hall.set_shader_parameter("glow", .22)
	_looks.hall.set_shader_parameter("day_glow", .05)
	_looks.paint = _look("rusty_painted_metal", 2.2, 1.0)
	_looks.cedar = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.cedar.set_shader_parameter("chroma", .42)
	_looks.stone = _look("", 1.0, .14)
	_looks.room = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.room.set_shader_parameter("glow", .3)
	_looks.room.set_shader_parameter("day_glow", .05)
	_looks.room.set_shader_parameter("chroma", .6)
	var signs: Texture2D = load(ATLAS)
	_looks.sign = _look("", 1.0, .4)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .5)
	var screen := ShaderMaterial.new()
	screen.shader = SCREEN_SHADER
	screen.set_shader_parameter("frames", load(SCREEN_FRAMES))
	_looks.screen = screen
	_looks.painted = _look("", 1.0, .7)
	_looks.painted.set_shader_parameter("albedo_map", signs)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .5)
	letters.set_shader_parameter("day_glow", .22)
	_looks.decal = letters

func _tiled(face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, tint: Color, low := 1.0, high := 1.0, streak := .6) -> void:
	_kit.quad("glazed", face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), tint, low, high, streak, Vector2(x0, -y0))

func _pier(x: float) -> void:
	# Tiled pier running the full height, with a slip of the tile returned on each side.
	var f := _front
	var half := PIER * .5
	_tiled(f, x - half, x + half, GROUND, PARAPET, 0.0, CELADON, .9, .92)
	var ret := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x + half, 0, 0))
	_tiled(ret, 0.0, -INFILL, GROUND, PARAPET, 0.0, CELADON * .92, .7, .8)
	ret = Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x - half, 0, INFILL))
	_tiled(ret, 0.0, -INFILL, GROUND, PARAPET, 0.0, CELADON * .92, .7, .8)

func _front_frame() -> void:
	var f := _front
	_pier(PIER * .5)
	_pier(WIDE - PIER * .5)
	_tiled(f, PIER, WIDE - PIER, TOP, PARAPET, INFILL, CELADON, .85, .95)
	# Pre-cast coping round the parapet.
	var coping := Color("#a8a59b")
	_bar("render", f, WIDE * .5, PARAPET + .05, -.08, Vector3(WIDE + .1, .1, .3), coping, .7, 1.0)

func _storey(index: int) -> void:
	var f := _front
	var base := GROUND + float(index) * STOREY
	var head := base + 2.72
	var sill := base + .95
	var low := PIER
	var high := WIDE - PIER
	# Tiled spandrel and head band, slab edge standing proud with its stain below it.
	_tiled(f, low, high, base, sill, INFILL, CELADON, .8, 1.0)
	_tiled(f, low, high, head, base + STOREY, INFILL, CELADON, .6, .9)
	_bar("render", f, WIDE * .5, base + .05, INFILL + .04, Vector3(high - low, .13, .1), Color("#a8a59b"), .6, 1.0)
	_bar("metal", f, WIDE * .5, sill + .012, INFILL + .03, Vector3(high - low, .03, .08), BRONZE)
	var opening := Rect2(low, sill, high - low, head - sill)
	_reveal(f.translated_local(Vector3(0, 0, INFILL)), opening, -GLASS_LINE + INFILL, Color("#7f8079"))
	# A three-bay strip of bronze sash, opening lights under fixed ones.
	var bays := 3
	var bay := opening.size.x / float(bays)
	var transom := head - .62
	for i: int in range(bays):
		var x0 := low + bay * float(i)
		var cell := fposmod(.137 + float(index) * .41 + float(i) * .29, 1.0)
		_kit.pane("glass", f, x0 + .02, x0 + bay - .02, sill + .02, transom, GLASS_LINE, cell)
		_kit.pane("glass", f, x0 + .02, x0 + bay - .02, transom, head - .02, GLASS_LINE, fposmod(cell + .17, 1.0))
		_dress_bay(index, i, x0 + .05, x0 + bay - .05, sill + .05, transom - .03)
		_bar("metal", f, x0 + bay * .5, (sill + transom) * .5, GLASS_LINE + .05, Vector3(.03, transom - sill, .03), BRONZE)
	for i: int in range(bays + 1):
		_bar("metal", f, low + bay * float(i), (sill + head) * .5, GLASS_LINE + .04, Vector3(.06, head - sill, .08), BRONZE)
	_bar("metal", f, WIDE * .5, transom, GLASS_LINE + .04, Vector3(high - low, .05, .08), BRONZE)
	_bar("metal", f, WIDE * .5, head - .02, GLASS_LINE + .04, Vector3(high - low, .04, .08), BRONZE)
	_bar("metal", f, WIDE * .5, sill + .03, GLASS_LINE + .04, Vector3(high - low, .05, .08), BRONZE)
	# Tenant's name stuck to the glass, as high as the street can read it.
	var letters: Array[Rect2] = [_cell(0, 1350, 1800, 220), _cell(0, 1580, 1800, 220), _cell(0, 1810, 1800, 220)]
	var y0 := transom + .02
	var y1 := transom + .54
	_kit.atlas("decal", f * Vector3(low + .2, y0, GLASS_LINE + .012), f * Vector3(low + .2, y1, GLASS_LINE + .012), f * Vector3(high - .2, y1, GLASS_LINE + .012), f * Vector3(high - .2, y0, GLASS_LINE + .012), letters[index])

func _dress_bay(index: int, bay: int, x0: float, x1: float, y0: float, y1: float) -> void:
	# What tenants hang behind their glass: office blinds, heavy drapes, or nothing at all.
	var f := _front
	var z := GLASS_LINE + .008
	if index == 0:
		# Venetian blinds, each lowered to its own height.
		var drop := [.62, .28, .78][bay] as float
		var y := y1
		while y > y1 - (y1 - y0) * drop:
			var tone := Color("#c9cbc8")
			_kit.quad("plain", f * Vector3(x0, y - .034, z), f * Vector3(x0, y, z + .004), f * Vector3(x1, y, z + .004), f * Vector3(x1, y - .034, z), tone, .82, 1.0)
			y -= .048
		_bar("metal", f, (x0 + x1) * .5, y1 + .01, z + .01, Vector3(x1 - x0, .04, .03), Color("#8e908c"))
	elif index == 2 and bay > 0:
		# Plum drapes, pulled most of the way across.
		var folds := 9
		var close := .86 if bay == 1 else .6
		for i: int in range(folds):
			var a := x0 + (x1 - x0) * close * float(i) / float(folds)
			var b := x0 + (x1 - x0) * close * float(i + 1) / float(folds)
			var tone := Color("#4a2230") * (.8 + .24 * sin(float(i) * 2.2))
			_kit.quad("plain", f * Vector3(a, y0, z + .004 * float(i % 2)), f * Vector3(a, y1 + .55, z + .004 * float(i % 2)), f * Vector3(b, y1 + .55, z + .004 * float((i + 1) % 2)), f * Vector3(b, y0, z + .004 * float((i + 1) % 2)), tone, .8, 1.0)

func _coffee_shop() -> void:
	# 純喫茶: dark timber and brick slip, a lit sample case, and a door set back in its porch.
	var f := _front
	var left := .0
	var right := 4.12
	var dark := STAIN.darkened(.3)
	# Polished stone round the piers.
	_bar("stone", f, PIER * .5, GROUND * .5, -.13, Vector3(PIER + .04, GROUND, .3), STONE, .8, .7)
	_bar("stone", f, right + .05, GROUND * .5, -.13, Vector3(.14, GROUND, .3), STONE, .8, .7)
	_bar("stone", f, WIDE - PIER * .5, GROUND * .5, -.13, Vector3(PIER + .04, GROUND, .3), STONE, .8, .7)
	# Fascia box with cut brass letters and two globe lamps.
	_bar("cedar", f, (PIER + right) * .5, 3.02, .03, Vector3(right - PIER, .86, .22), dark, .6, .7)
	_kit.atlas("decal", f * Vector3(.52, 2.78, .146), f * Vector3(.52, 3.28, .146), f * Vector3(3.92, 3.28, .146), f * Vector3(3.92, 2.78, .146), _cell(0, 1120, 1200, 220))
	_bar("metal", f, (PIER + right) * .5, 3.47, .08, Vector3(right - PIER + .04, .03, .28), Color("#8a6a38"))
	_bar("render", f, WIDE * .5, GROUND - .03, -.08, Vector3(WIDE - PIER * 2.0, .12, .12), Color("#8f8d84"), .6, 1.0)
	for x: float in [.55, 3.92]:
		_kit.tube("metal", [f * Vector3(x, 2.64, .1), f * Vector3(x, 2.5, .22)], .012, Color("#8a6a38"), 5)
		_kit.lathe("lamp", f * Vector3(x, 2.3, .22), [Vector2(.02, 0), Vector2(.09, .05), Vector2(.11, .1), Vector2(.09, .16), Vector2(.02, .2)], Color(1.0, .82, .56), 10)
	# Brick-slip stall riser under the window.
	_tiled(f, PIER, 2.72, .0, .72, -.09, Color(.3, .17, .12), .75, 1.0, .3)
	_bar("cedar", f, (PIER + 2.72) * .5, .75, -.04, Vector3(2.72 - PIER, .07, .14), dark, 1.0, 1.0)
	# Sample case: a real shallow box of plastic food behind glass.
	var case := Rect2(.5, .8, 1.02, 1.26)
	_bar("cedar", f, case.get_center().x, .79, -.3, Vector3(case.size.x + .16, .05, .42), dark)
	_kit.quad("room", f * Vector3(case.position.x, case.position.y, -.5), f * Vector3(case.position.x, case.end.y, -.5), f * Vector3(case.end.x, case.end.y, -.5), f * Vector3(case.end.x, case.position.y, -.5), Color(.8, .72, .56))
	for shelf: int in range(3):
		var y := case.position.y + .05 + float(shelf) * .4
		_bar("room", f, case.get_center().x, y, -.3, Vector3(case.size.x, .02, .4), Color(.85, .8, .7))
		for dish: int in range(3):
			var at := f * Vector3(case.position.x + .2 + float(dish) * .31, y + .012, -.28)
			_kit.lathe("room", at, [Vector2(.12, 0), Vector2(.13, .02)], Color(.92, .9, .84), 10)
			var food: Color = [Color("#b8431f"), Color("#d7a64a"), Color("#e7d5b0"), Color("#7a4a26")][(dish + shelf) % 4]
			_kit.lathe("room", at + Vector3.UP * .02, [Vector2(.09, 0), Vector2(.075, .06), Vector2(0, .09)], food, 8)
	_kit.quad("front", f * Vector3(case.position.x, case.position.y, -.1), f * Vector3(case.position.x, case.end.y, -.1), f * Vector3(case.end.x, case.end.y, -.1), f * Vector3(case.end.x, case.position.y, -.1), Color.WHITE)
	# Main window: small-paned, with amber glass over a dim room.
	_kit.pane("glass", f, 1.62, 2.72, .8, 2.56, -.1, .71)
	for x: float in [1.56, 2.72]:
		_bar("cedar", f, x, 1.68, -.06, Vector3(.07, 1.76, .12), dark)
	_bar("cedar", f, 1.04, 2.1, -.06, Vector3(1.2, .07, .12), dark)
	_bar("cedar", f, 1.04, 2.6, -.05, Vector3(2.0, .07, .14), dark)
	_tiled(f, .44, 1.54, 2.13, 2.56, -.08, Color(.3, .17, .12), .7, .7, .3)
	for x: float in [1.98, 2.35]:
		_bar("cedar", f, x, 1.68, -.08, Vector3(.025, 1.76, .03), dark)
	for y: float in [1.4, 1.98]:
		_bar("cedar", f, 2.17, y, -.08, Vector3(1.1, .025, .03), dark)
	# Porch and panelled door with a brass bar and a round light.
	var porch := Rect2(2.8, .0, 1.25, 2.6)
	_reveal(f, porch, .6, Color("#4a3a2c"))
	_kit.quad("plain", f * Vector3(porch.position.x, .03, .02), f * Vector3(porch.position.x, .03, -.6), f * Vector3(porch.end.x, .03, -.6), f * Vector3(porch.end.x, .03, .02), Color("#4d4238"), .7, .6)
	_bar("cedar", f, porch.get_center().x, 1.3, -.61, Vector3(porch.size.x, 2.6, .05), dark.lightened(.08), .6, .7)
	for x: float in [.2, .62, 1.05]:
		_bar("cedar", f, porch.position.x + x, 1.3, -.58, Vector3(.05, 2.56, .02), dark)
	_kit.disc("room", f * Vector3(porch.get_center().x + .16, 1.7, -.57), f.basis.x, f.basis.y, .15, Color("#a8702a"))
	_bar("metal", f, porch.position.x + .3, 1.15, -.5, Vector3(.03, .9, .03), Color("#a58a4f"))
	# A planter either side of the street, a menu on an easel.
	_kit.lathe("plain", f * Vector3(2.84, 0, .26), [Vector2(.13, 0), Vector2(.19, .42), Vector2(.2, .44)], Color("#7f7a70"), 12)
	_plant(f * Vector3(2.84, .42, .26), 1.05, Color("#39572f"))
	_plant(f * Vector3(2.84, .5, .26), .75, Color("#46683a"))
	var easel := f * Vector3(3.55, 0, .75)
	var tilt := Basis(Vector3.RIGHT, -.12)
	_kit.block("cedar", Transform3D(tilt, easel + Vector3.UP * .78), Vector3(.5, .78, .03), dark)
	var c := easel + Vector3.UP * .78
	_kit.atlas("painted", c + tilt * Vector3(-.22, -.36, .017), c + tilt * Vector3(-.22, .36, .017), c + tilt * Vector3(.22, .36, .017), c + tilt * Vector3(.22, -.36, .017), _cell(1760, 0, 280, 440))
	for x: float in [-.2, .2]:
		_kit.beam("cedar", easel + Vector3(x, 1.2, -.05), easel + Vector3(x, 0, .12), .03, .03, Vector3.FORWARD, dark)
		_kit.beam("cedar", easel + Vector3(x, 1.2, -.05), easel + Vector3(x, 0, -.34), .03, .03, Vector3.FORWARD, dark)
	_round_sign()
	_interior_glow()

func _interior_glow() -> void:
	# Enough of the room behind the door that the porch does not read as a dead end.
	var f := _front
	_kit.quad("room", f * Vector3(.3, 0, -.14), f * Vector3(.3, 2.8, -.14), f * Vector3(.3, 2.8, -2.0), f * Vector3(.3, 0, -2.0), Color(.5, .36, .26), .7, .7)

func _round_sign() -> void:
	# Round blade sign on an iron arm, turned to catch people walking the pavement.
	var f := _front
	var centre := f * Vector3(.12, 3.05 + .75, .78)
	var arm := Color("#232425")
	_kit.tube("metal", [f * Vector3(.12, 4.3, .0), f * Vector3(.12, 4.3, 1.28)], .02, arm, 5)
	_kit.tube("metal", [f * Vector3(.12, 3.5, .0), f * Vector3(.12, 3.9, .32), f * Vector3(.12, 4.3, .5)], .014, arm, 5)
	var rect := _cell(1000, 0, 400, 400)
	_kit.disc("sign", centre + Vector3.RIGHT * .09, Vector3.FORWARD, Vector3.UP, .46, Color.WHITE, rect)
	_kit.disc("sign", centre + Vector3.LEFT * .09, Vector3.BACK, Vector3.UP, .46, Color.WHITE, rect)
	# Pressed metal band round the drum, a plain ring either side.
	for i: int in range(28):
		var a0 := TAU * float(i) / 28.0
		var a1 := TAU * float(i + 1) / 28.0
		var n0 := Vector3(0, sin(a0), cos(a0))
		var n1 := Vector3(0, sin(a1), cos(a1))
		_kit.smooth("metal", centre + n0 * .47 + Vector3.LEFT * .1, centre + n0 * .47 + Vector3.RIGHT * .1, centre + n1 * .47 + Vector3.RIGHT * .1, centre + n1 * .47 + Vector3.LEFT * .1, n0, n0, n1, n1, Color("#4e3a22"))
	for z: float in [.46, 1.1]:
		_kit.tube("metal", [f * Vector3(.12, 4.3, z), f * Vector3(.12, 4.22, z)], .008, arm, 3)

func _stair_door() -> void:
	# The tenants' way in: terrazzo, post boxes, a steep flight under a bare tube.
	var f := _front
	var door := Rect2(4.2, .0, 1.08, 2.58)
	var deep := 3.2
	var wall := Color("#b9b5a8")
	_reveal(f, door, deep, wall)
	_kit.quad("plain", f * Vector3(door.position.x, .03, .0), f * Vector3(door.position.x, .03, -1.05), f * Vector3(door.end.x, .03, -1.05), f * Vector3(door.end.x, .03, .0), Color("#6e6a60"), .8, .7)
	_kit.quad("plain", f * Vector3(door.position.x, 2.55, -deep), f * Vector3(door.position.x, 2.55, 0), f * Vector3(door.end.x, 2.55, 0), f * Vector3(door.end.x, 2.55, -deep), Color("#a9a79c"))
	var steps := 11
	var rise := .19
	var tread := .25
	for i: int in range(steps):
		var z := -1.05 - float(i) * tread
		_bar("hall", f, door.get_center().x, rise * float(i) + rise * .5, z - tread * .5, Vector3(door.size.x, rise, tread), Color(.4, .42, .38), .7, 1.0)
		_bar("metal", f, door.get_center().x, rise * float(i) + rise - .01, z - .01, Vector3(door.size.x, .02, .03), Color("#7a6a48"))
	# Cool tube on the ceiling, handrail and post boxes.
	_bar("lamp", f, door.get_center().x, 2.53, -1.3, Vector3(.05, .05, 1.18), Color(.82, .92, 1.0))
	_kit.tube("metal", [f * Vector3(door.end.x - .05, 1.0, -.9), f * Vector3(door.end.x - .05, 2.6, -3.1)], .017, Color("#5d4632"), 5)
	var boxes := Vector3(door.position.x + .03, 1.25, -.5)
	_bar("metal", f, boxes.x, boxes.y, boxes.z, Vector3(.05, .62, .78), Color("#a9aba6"))
	for row: int in range(2):
		for column: int in range(3):
			_bar("metal", f, boxes.x + .03, boxes.y - .15 + float(row) * .3, boxes.z - .26 + float(column) * .26, Vector3(.012, .24, .22), Color("#7d7f7b"))
	# Building name in brass over the door, and the tenant list by it.
	_kit.atlas("decal", f * Vector3(4.28, 2.76, -.02), f * Vector3(4.28, 3.02, -.02), f * Vector3(5.22, 3.02, -.02), f * Vector3(5.22, 2.76, -.02), _cell(1210, 1120, 400, 100))
	_tiled(f, door.position.x, door.end.x, 2.58, 3.5, -.03, CELADON * .9, .55, .75, .4)
	var board := Vector2(WIDE - PIER * .5, 1.7)
	_bar("metal", f, board.x, board.y, .03, Vector3(.31, .47, .03), Color("#6c6c66"))
	_kit.atlas("sign", f * Vector3(board.x - .14, board.y - .21, .047), f * Vector3(board.x - .14, board.y + .21, .047), f * Vector3(board.x + .14, board.y + .21, .047), f * Vector3(board.x + .14, board.y - .21, .047), _cell(1440, 0, 300, 440))

func _sign_tower() -> void:
	# Steel tower bolted to the east pier: one thin display a tenant.
	var f := _front
	var steel := Color("#3e4042")
	var x := WIDE - .16
	var boxes: Array[Array] = [[3.95, _cell(0, 0, 240, 700), "sign"], [6.72, _cell(750, 0, 240, 700), "sign"], [9.49, _cell(250, 0, 240, 700), "sign"]]
	var post := .22
	_bar("metal", f, x, 8.1, post, Vector3(.1, 8.9, .1), steel)
	var y := 4.0
	while y < 12.4:
		_bar("metal", f, x, y, post * .5, Vector3(.06, .06, post), steel)
		y += 1.38
	for row: Array in boxes:
		var low: float = row[0]
		var tall := 2.55
		var depth := .8
		var mid := Vector3(x, low + tall * .5, post + .08 + depth * .5)
		var rect: Rect2 = row[1]
		var part: String = row[2]
		_bar("metal", f, mid.x, mid.y, mid.z, Vector3(.06, tall, depth), Color("#141517"), .8, 1.0)
		var near := mid.z - depth * .5 + .04
		var far := mid.z + depth * .5 - .04
		var bottom := low + .04
		var top := low + tall - .04
		_kit.atlas(part, f * Vector3(x + .032, bottom, far), f * Vector3(x + .032, top, far), f * Vector3(x + .032, top, near), f * Vector3(x + .032, bottom, near), rect, Color.WHITE, 1.0, .35)
		_kit.atlas(part, f * Vector3(x - .032, bottom, near), f * Vector3(x - .032, top, near), f * Vector3(x - .032, top, far), f * Vector3(x - .032, bottom, far), rect, Color.WHITE, 1.0, .35)
		_strip(f * Vector3(mid.x, low + tall + .01, near), f * Vector3(mid.x, low + tall + .01, far), CYAN)
		_bar("metal", f, mid.x, low + tall * .5, post + .05, Vector3(.06, .08, .1), steel)
	# Power run up the post, with a junction box per sign.
	_kit.tube("plain", [f * Vector3(x + .08, 3.7, post), f * Vector3(x + .08, 12.3, post)], .013, Color("#1d1e20"), 4)
	for box_y: float in [4.4, 7.2, 10.0]:
		_bar("metal", f, x + .1, box_y, post - .06, Vector3(.14, .18, .08), Color("#76786f"))

func _retrofit() -> void:
	# What the decades added to the street front.
	var f := _front
	# Seismic zig-zag standing off the piers, each diagonal with an oil damper at its middle.
	var graphite := Color("#26282b")
	var collar := Color("#d9681c")
	for floor_index: int in range(FLOORS):
		var base := GROUND + float(floor_index) * STOREY + .1
		var flip := floor_index % 2 == 1
		var a := f * Vector3(5.5 if flip else .2, base, .12)
		var b := f * Vector3(.2 if flip else 5.5, base + STOREY - .2, .12)
		var along := (b - a).normalized()
		var mid := (a + b) * .5
		_kit.beam("metal", a, mid - along * .42, .1, .1, Vector3.BACK, graphite)
		_kit.beam("metal", mid + along * .42, b, .1, .1, Vector3.BACK, graphite)
		_kit.tube("metal", [mid - along * .42, mid + along * .1], .085, Color("#a9adb0"), 9)
		_kit.tube("metal", [mid + along * .1, mid + along * .42], .04, Color("#dfe2e3"), 8)
		_kit.tube("metal", [mid - along * .44, mid - along * .4], .1, collar, 9)
		for end: Vector3 in [a, b]:
			_kit.block("metal", Transform3D(f.basis, end - Vector3(0, 0, .05)), Vector3(.34, .34, .1), graphite)
	# Trunk fibre down the east pier, in past the stair door.
	var run: Array[Vector3] = [f * Vector3(5.1, PARAPET - .1, .03), f * Vector3(5.2, 9.0, .03), f * Vector3(5.2, 2.9, .03), f * Vector3(4.7, 2.72, .03)]
	_fibre(run)
	# Neon round the coffee shop fascia, the one thing here that stayed in fashion.
	var neon := Color(1.0, .5, .24)
	_neon([f * Vector3(.5, 2.68, .16), f * Vector3(.5, 3.36, .16), f * Vector3(3.96, 3.36, .16), f * Vector3(3.96, 2.68, .16), f * Vector3(.5, 2.68, .16)], neon)
	_strip(f * Vector3(.0, PARAPET - .08, .03), f * Vector3(WIDE, PARAPET - .08, .03), CYAN * .8)
	# Street door: palm reader on the jamb, parcel lockers in place of post boxes, a camera over it.
	_bar("bottle", f, 5.31, 1.32, -.1, Vector3(.012, .2, .13), Color("#0b0c0e"))
	_status(f, 5.3, 1.32, -.1, CYAN)
	_camera(f * Vector3(4.72, 2.5, .05))
	_bar("metal", f, 4.27, 1.25, -.5, Vector3(.08, 1.7, .78), Color("#2b2d30"))
	for row: int in range(3):
		_status(f, 4.32, .7 + float(row) * .5, -.2, GREEN)
	# Charge post on the pavement.
	_kit.tube("metal", [f * Vector3(5.1, 0, .55), f * Vector3(5.1, 1.0, .55)], .06, Color("#d7d8d4"), 8)
	_status(f, 5.1, .92, .612, CYAN)

func _flank(face: Transform3D, seed_offset: int) -> void:
	# The wall nobody designed: render, small barred windows, plant and pipes.
	var holes: Array[Rect2] = []
	var near_street := DEEP - 1.6 if face == _west else 1.6
	var mid_wall := 4.4
	for floor_index: int in range(FLOORS):
		var y := GROUND + float(floor_index) * STOREY + 1.15
		holes.append(Rect2(near_street - .45, y, .9, 1.05))
		holes.append(Rect2(mid_wall - .3, y + .3, .6, .7))
	_render_wall(face, DEEP, PARAPET, GROUND, STOREY, RENDER, holes)
	_bar("render", face, DEEP * .5, PARAPET + .05, -.05, Vector3(DEEP + .1, .1, .3), Color("#a8a59b"), .7, 1.0)
	for floor_index: int in range(FLOORS):
		var y := GROUND + float(floor_index) * STOREY + 1.15
		_window(face, Rect2(near_street - .45, y, .9, 1.05), fposmod(.31 + float(seed_offset + floor_index) * .23, 1.0), true)
		_window(face, Rect2(mid_wall - .3, y + .3, .6, .7), fposmod(.57 + float(seed_offset + floor_index) * .19, 1.0), true)
		# Outdoor unit on a wall bracket, its pipes in ivory duct stepping down to it.
		var unit := Vector2(mid_wall + 1.7, y - .2)
		_outdoor_unit(face, unit.x, unit.y, .22)
		for x: float in [unit.x - .3, unit.x + .3]:
			_bar("metal", face, x, unit.y - .33, .22, Vector3(.04, .04, .44), STEEL)
		_kit.tube("plain", [face * Vector3(mid_wall + .3, y + .6, .04), face * Vector3(unit.x - .5, y + .6, .04), face * Vector3(unit.x - .5, unit.y + .1, .04)], .04, Color("#c8c2b0"), 6)
	# Soil stack and rainwater down the wall, clipped at each floor.
	var pipe := face * Vector3(mid_wall - 1.0, .0, .08)
	_kit.tube("metal", [pipe + Vector3.UP * .1, pipe + Vector3.UP * (PARAPET - .3)], .05, Color("#8a8b84"), 7)
	var clip := GROUND
	while clip < PARAPET:
		_bar("metal", face, mid_wall - 1.0, clip, .08, Vector3(.14, .03, .14), STEEL)
		clip += STOREY

func _rear() -> void:
	var none: Array[Rect2] = []
	_render_wall(_back, WIDE, PARAPET, GROUND, STOREY, RENDER, none)
	_bar("render", _back, WIDE * .5, PARAPET + .05, -.05, Vector3(WIDE + .1, .1, .3), Color("#a8a59b"), .7, 1.0)

func _rooftop() -> void:
	var half := WIDE * .5
	var level := TOP + .02
	var felt := Color("#5a5c5c")
	_kit.quad("plain", Vector3(-half, level, -.14), Vector3(-half, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, -.14), felt, .8, .9)
	# Parapet's inner face, rendered and streaked.
	var inner := Color(.8, .78, .72)
	_kit.quad("render", Vector3(half - .02, level, -.14), Vector3(half - .02, PARAPET, -.14), Vector3(-half + .02, PARAPET, -.14), Vector3(-half + .02, level, -.14), inner, .7, 1.0, .8)
	_kit.quad("render", Vector3(-half + .02, level, -DEEP), Vector3(-half + .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, level, -DEEP), inner, .7, 1.0, .8)
	_kit.quad("render", Vector3(-half + .02, level, -.14), Vector3(-half + .02, PARAPET, -.14), Vector3(-half + .02, PARAPET, -DEEP), Vector3(-half + .02, level, -DEEP), inner, .7, 1.0, .8)
	_kit.quad("render", Vector3(half - .02, level, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -.14), Vector3(half - .02, level, -.14), inner, .7, 1.0, .8)
	# Stair head, tiled like the street front on the side the street can see.
	var head := Vector3(-.9, TOP + 1.55, -7.2)
	var size := Vector3(3.2, 3.1, 3.6)
	_kit.block("render", Transform3D(Basis.IDENTITY, head), size, RENDER * .92, .75, 1.0, .9)
	var wall := Transform3D(Basis.IDENTITY, head + Vector3(-size.x * .5, -size.y * .5, size.z * .5 + .01))
	_tiled(wall, .0, size.x, .0, size.y, .0, CELADON, .75, .95)
	_bar("render", Transform3D.IDENTITY, head.x, head.y + size.y * .5 + .05, head.z, Vector3(size.x + .12, .1, size.z + .12), Color("#a8a59b"), .7, 1.0)
	_bar("paint", wall, 1.0, 1.0, .02, Vector3(.82, 1.98, .05), Color("#54616a"), .85, 1.0)
	_bar("metal", wall, 2.45, 2.2, .0, Vector3(.5, .36, .03), Color("#3c4042"))
	# Water tank in moulded panels on a steel stand, and its feed.
	var tank := Vector3(1.5, TOP + 1.65, -7.0)
	var panel := Color("#a8b6ba")
	_kit.block("plain", Transform3D(Basis.IDENTITY, tank), Vector3(2.0, 1.5, 2.0), panel, .85, 1.0, .6)
	for i: int in range(5):
		var x := -.8 + float(i) * .4
		_bar("plain", Transform3D.IDENTITY, tank.x + x, tank.y, tank.z + 1.01, Vector3(.06, 1.5, .03), panel.darkened(.12))
		_bar("plain", Transform3D.IDENTITY, tank.x + 1.01, tank.y, tank.z + x, Vector3(.03, 1.5, .06), panel.darkened(.12))
		_bar("plain", Transform3D.IDENTITY, tank.x - 1.01, tank.y, tank.z + x, Vector3(.03, 1.5, .06), panel.darkened(.12))
	for z: float in [-.4, .4]:
		_bar("plain", Transform3D.IDENTITY, tank.x, tank.y + z, tank.z + 1.015, Vector3(2.0, .05, .03), panel.darkened(.12))
	for x: float in [-.85, .85]:
		for z: float in [-.85, .85]:
			_bar("metal", Transform3D.IDENTITY, tank.x + x, TOP + .46, tank.z + z, Vector3(.08, .9, .08), STEEL)
	_kit.tube("metal", [tank + Vector3(.5, -.74, 1.0), tank + Vector3(.5, -1.2, 1.2), Vector3(tank.x + .5, level + .1, -4.2), Vector3(-.6, level + .1, -4.2)], .03, Color("#7c8084"), 6)
	# Heat pumps for the three floors, on steel skids under the solar canopy.
	var roof := Transform3D(Basis.IDENTITY, Vector3(0, level, 0))
	for x: float in [-1.8, -.7, .4]:
		_bar("metal", roof, x, .06, -3.2, Vector3(.9, .12, .46), STEEL)
		_outdoor_unit(roof, x, .44, -3.2)
	var pitch := Basis(Vector3.RIGHT, -.32)
	for column: int in range(3):
		_solar_module(Transform3D(pitch, Vector3(-1.75 + float(column) * 1.72, TOP + 1.65, -3.6)), 1.66, 2.1)
	for x: float in [-2.5, .0, 2.5]:
		_kit.block("metal", Transform3D(Basis.IDENTITY, Vector3(x, TOP + .7, -2.95)), Vector3(.06, 1.4, .06), STEEL)
		_kit.block("metal", Transform3D(Basis.IDENTITY, Vector3(x, TOP + 1.1, -4.55)), Vector3(.06, 2.2, .06), STEEL)
	# Storage cabinet for the array, and the 6G panels on a new mast.
	_bar("metal", roof, 2.0, .62, -5.0, Vector3(.9, 1.24, .5), Color("#c9cbc7"))
	_status(roof, 1.74, 1.08, -4.74, GREEN)
	_status(roof, 1.84, 1.08, -4.74, GREEN)
	var mast := Vector3(-2.1, level, -5.4)
	_kit.tube("metal", [mast, mast + Vector3.UP * 4.4], .04, Color("#c7cac9"), 7)
	for angle: float in [.4, 2.5, 4.6]:
		var turn := Basis(Vector3.UP, angle)
		_kit.block("plain", Transform3D(turn, mast + Vector3.UP * 3.9 + turn * Vector3(0, 0, .2)), Vector3(.34, .8, .1), Color("#dfe0db"), .9, 1.0)
	_rail()
	_billboard()

func _rail() -> void:
	# Galvanised fall guard round the open roof, set just inside the parapet.
	var half := WIDE * .5 - .16
	var steel := Color("#7f8488")
	for y: float in [TOP + 1.42, TOP + 1.9]:
		_kit.tube("metal", [Vector3(-half, y, -5.0), Vector3(-half, y, -.3), Vector3(half, y, -.3), Vector3(half, y, -5.0)], .022, steel, 5)
	var points: Array[Vector3] = [Vector3(-half, 0, -5.0), Vector3(-half, 0, -3.5), Vector3(-half, 0, -2.0), Vector3(-half, 0, -.3), Vector3(-half * .33, 0, -.3), Vector3(half * .33, 0, -.3), Vector3(half, 0, -.3), Vector3(half, 0, -2.0), Vector3(half, 0, -3.5), Vector3(half, 0, -5.0)]
	for p: Vector3 in points:
		_kit.tube("metal", [p + Vector3.UP * TOP, p + Vector3.UP * (TOP + 1.92)], .022, steel, 5)

func _billboard() -> void:
	# Micro-LED wall: a frameless slab carried on two slim masts, lit along its top edge.
	var z := -1.5
	var low := TOP + 2.25
	var high := low + 1.75
	var half := 2.66
	var steel := Color("#3f4345")
	_bar("metal", Transform3D.IDENTITY, 0, (low + high) * .5, z - .05, Vector3(half * 2.0 + .03, high - low + .03, .1), Color("#0d0e10"), .7, 1.0)
	_strip(Vector3(-half, high + .02, z - .04), Vector3(half, high + .02, z - .04), CYAN)
	_kit.atlas("screen", Vector3(-half, low, z + .004), Vector3(-half, high, z + .004), Vector3(half, high, z + .004), Vector3(half, low, z + .004), Rect2(0, 0, 1, 1))
	# Controller box behind it, with its feed down to the roof.
	_bar("metal", Transform3D.IDENTITY, 1.7, TOP + 1.3, z - .3, Vector3(.6, .8, .22), Color("#8c8f8c"))
	_kit.tube("plain", [Vector3(1.7, TOP + .9, z - .3), Vector3(1.7, TOP + .06, z - .6), Vector3(.2, TOP + .06, -3.0)], .018, Color("#1c1d1f"), 5)
	for x: float in [-1.7, 1.7]:
		_kit.tube("metal", [Vector3(x, TOP + .02, z - .16), Vector3(x, high - .1, z - .16)], .05, Color("#2a2c2f"), 8)
		_kit.tube("metal", [Vector3(x, high - .1, z - .16), Vector3(x, TOP + .02, z - 1.4)], .012, Color("#8d9092"), 4)
