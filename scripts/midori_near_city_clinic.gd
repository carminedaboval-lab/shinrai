extends "res://scripts/midori_near_city_handmade.gd"
## 高橋内科: three generations of the same family doctor, in rose-beige tile from 1971.
## The side street is its real front: a canopy, a ramp, frosted windows and a tall green
## cross, with a booth where the night patients now see a doctor on a screen.
const ATLAS := "res://assets/shinrai/near_city/clinic_atlas.png"
const WIDE := 5.2
const DEEP := 7.2
const GROUND := 3.3
const STOREY := 3.0
const TOP := 9.3
const PARAPET := 10.0
const TILE := Color(.82, .68, .62)
const CREAM := Color(.98, .93, .82)
const RENDER := Color(.9, .86, .78)
const SASH := Color("#9a9a95")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1971
	_build_looks()
	_main_front()
	_entrance()
	_booth()
	_blade()
	_render_wall(_east, DEEP, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2], .5)
	_render_wall(_back, WIDE, PARAPET, GROUND, STOREY, RENDER, [] as Array[Rect2], .5)
	_street_side()
	_rooftop()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "leaf", "led", "sign", "room", "hall"])
	_kit = null
	_omni("ClinicLamp", Vector3(-3.4, 2.6, -3.6), Color(.86, 1.0, .9), .7, 6.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.tile = _look("", 1.0, .4)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.108, .06))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .7)
	_looks.room = _look("", 1.0, .7)
	_looks.room.set_shader_parameter("glow", .34)
	_looks.room.set_shader_parameter("day_glow", .1)
	_looks.hall = _look("", 1.0, .7)
	_looks.hall.set_shader_parameter("glow", .24)
	_looks.hall.set_shader_parameter("day_glow", .08)
	_looks.sign = _look("", 1.0, .35)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .62)
	_looks.sign.set_shader_parameter("day_glow", .12)
	_looks.painted = _look("", 1.0, .6)
	_looks.painted.set_shader_parameter("albedo_map", signs)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .4)
	letters.set_shader_parameter("day_glow", .2)
	_looks.decal = letters

func _cell_small(x: float, y: float, wide: float, tall: float) -> Rect2:
	return Rect2(x / 1024.0, y / 1024.0, wide / 1024.0, tall / 1024.0)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect)

func _tiled(face: Transform3D, area: Rect2, holes: Array[Rect2]) -> void:
	for piece: Rect2 in _minus(area, holes):
		_kit.quad("tile", face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), TILE, .9, 1.0, .6, Vector2(piece.position.x, -piece.position.y))

func _main_front() -> void:
	# Three bays of the same honest window, floor upon floor, with a slab line between.
	var w := _west
	var holes: Array[Rect2] = [Rect2(.5, .85, 1.9, 1.55), Rect2(3.0, 0, 1.5, 2.55), Rect2(5.0, .85, 1.7, 1.55)]
	for row: int in range(2):
		var y := GROUND + float(row) * STOREY + .95
		for x: float in [.5, 2.75, 5.0]:
			holes.append(Rect2(x, y, 1.7, 1.45))
	_tiled(w, Rect2(0, 0, DEEP, PARAPET), holes)
	_bar("render", w, DEEP * .5, PARAPET + .05, -.05, Vector3(DEEP + .1, .1, .3), CREAM, .7, 1.0)
	for i: int in range(2):
		_bar("render", w, DEEP * .5, GROUND + float(i) * STOREY, .03, Vector3(DEEP, .14, .1), CREAM, .6, 1.0)
	# Dark tile plinth, where a hundred years of bicycle pedals have caught it.
	_kit.quad("tile", w * Vector3(0, 0, .006), w * Vector3(0, .5, .006), w * Vector3(3.0, .5, .006), w * Vector3(3.0, 0, .006), TILE * .62, .8, .9, .2)
	_kit.quad("tile", w * Vector3(4.5, 0, .006), w * Vector3(4.5, .5, .006), w * Vector3(DEEP, .5, .006), w * Vector3(DEEP, 0, .006), TILE * .62, .8, .9, .2)
	var kinds: Array[int] = [0, 1, 2, 2, 0, 1]
	var index := 0
	for row: int in range(2):
		var y := GROUND + float(row) * STOREY + .95
		for x: float in [.5, 2.75, 5.0]:
			var r := Rect2(x, y, 1.7, 1.45)
			_window(w, r, fposmod(.27 + float(index) * .31, 1.0), false)
			_dress(r, kinds[index])
			_bar("render", w, r.get_center().x, y - .04, .05, Vector3(1.86, .05, .14), CREAM, .7, 1.0)
			index += 1
	# The two ground-floor rooms keep their frosted glass; nobody sees the waiting room.
	for r: Rect2 in [holes[0], holes[2]]:
		_window(w, r, .6, false)
		_kit.quad("room", w * Vector3(r.position.x + .05, r.position.y + .05, -.06), w * Vector3(r.position.x + .05, r.end.y - .05, -.06), w * Vector3(r.end.x - .05, r.end.y - .05, -.06), w * Vector3(r.end.x - .05, r.position.y + .05, -.06), Color("#e8ece6"), .9, 1.0)
		_bar("render", w, r.get_center().x, r.position.y - .04, .05, Vector3(r.size.x + .16, .05, .14), CREAM, .7, 1.0)
	_panel("painted", w, .7, 1.25, 1.0, 1.8, -.05, _cell_small(620, 140, 300, 420))

func _dress(r: Rect2, kind: int) -> void:
	# Upstairs is wards turned offices: frosted film, pale curtains or a blind half down.
	var w := _west
	var x0 := r.position.x + .06
	var x1 := r.end.x - .06
	var y0 := r.position.y + .06
	var y1 := r.end.y - .05
	match kind:
		0:
			_kit.quad("plain", w * Vector3(x0, y0, -.062), w * Vector3(x0, y0 + .8, -.062), w * Vector3(x1, y0 + .8, -.062), w * Vector3(x1, y0, -.062), Color("#dfe4e0"), .9, 1.0)
		1:
			var folds := 10
			for i: int in range(folds):
				var a := x0 + (x1 - x0) * .45 * float(i) / float(folds)
				var b := x0 + (x1 - x0) * .45 * float(i + 1) / float(folds)
				_kit.quad("plain", w * Vector3(a, y0, -.06 + .004 * float(i % 2)), w * Vector3(a, y1, -.06 + .004 * float(i % 2)), w * Vector3(b, y1, -.06 + .004 * float((i + 1) % 2)), w * Vector3(b, y0, -.06 + .004 * float((i + 1) % 2)), Color("#d6e0d8") * (.88 + .12 * sin(float(i) * 2.2)), .9, 1.0)
		2:
			var y := y1
			while y > y1 - .7:
				_kit.quad("plain", w * Vector3(x0, y - .036, -.062), w * Vector3(x0, y, -.056), w * Vector3(x1, y, -.056), w * Vector3(x1, y - .036, -.062), Color("#c9cbc4"), .85, 1.0)
				y -= .05

func _entrance() -> void:
	# Concrete canopy on two posts, a ramp with a worn rail, and doors that open themselves.
	var w := _west
	var door := Rect2(3.0, 0, 1.5, 2.55)
	var deep := 1.3
	_reveal(w, door, deep, Color("#b8ac9c"))
	_kit.quad("hall", w * Vector3(door.position.x, .02, 0), w * Vector3(door.position.x, .02, -deep), w * Vector3(door.end.x, .02, -deep), w * Vector3(door.end.x, .02, 0), Color("#8d8a7e"), .8, .8)
	_kit.quad("hall", w * Vector3(door.position.x, 0, -deep), w * Vector3(door.position.x, door.end.y, -deep), w * Vector3(door.end.x, door.end.y, -deep), w * Vector3(door.end.x, 0, -deep), Color("#cfd8d0"))
	_kit.quad("front", w * Vector3(door.position.x + .04, .02, -deep + .1), w * Vector3(door.position.x + .04, 2.5, -deep + .1), w * Vector3(door.end.x - .04, 2.5, -deep + .1), w * Vector3(door.end.x - .04, .02, -deep + .1), Color.WHITE)
	for x: float in [door.position.x + .05, door.get_center().x, door.end.x - .05]:
		_bar("metal", w, x, 1.25, -deep + .12, Vector3(.05, 2.5, .05), SASH)
	_bar("metal", w, door.get_center().x, 2.28, -deep + .12, Vector3(door.size.x, .05, .05), SASH)
	_kit.block("render", _at(w, door.get_center().x, 2.78, .75), Vector3(3.2, .16, 1.5), CREAM, .55, 1.0, .5)
	_kit.quad("lamp", w * Vector3(3.3, 2.695, .9), w * Vector3(3.3, 2.695, .3), w * Vector3(3.5, 2.695, .3), w * Vector3(3.5, 2.695, .9), Color(.7, .72, .66))
	_kit.quad("lamp", w * Vector3(4.0, 2.695, .9), w * Vector3(4.0, 2.695, .3), w * Vector3(4.2, 2.695, .3), w * Vector3(4.2, 2.695, .9), Color(.7, .72, .66))
	for x: float in [2.4, 5.1]:
		_kit.tube("metal", [w * Vector3(x, 0, 1.3), w * Vector3(x, 2.7, 1.3)], .05, Color("#c9cbc9"), 8)
	_panel("decal", w, 2.3, 5.2, 2.92, 3.2, .02, _cell_small(210, 0, 800, 130))
	_panel("sign", w, 4.62, 4.98, 1.1, 1.42, .02, _cell_small(210, 140, 400, 340))
	# Low planter by the wall, the one thing the doctor's wife still waters.
	_bar("render", w, 1.45, .18, .28, Vector3(1.9, .36, .34), CREAM * .8, .8, 1.0)
	for x: float in [.8, 1.3, 1.8, 2.2]:
		_plant(w * Vector3(x, .34, .28), _rng.randf_range(.45, .8), Color("#3f6a35"))
	_kit.tube("metal", [w * Vector3(2.5, .9, .5), w * Vector3(.6, .9, .5)], .022, Color("#c9cbc9"), 6)

func _booth() -> void:
	# 遠隔診療: a phone-box of a room bolted on for the nights the doctor is asleep.
	var w := _west
	var x := 6.2
	_kit.block("metal", _at(w, x, 1.1, .5), Vector3(1.0, 2.2, 1.0), Color("#dfe3e2"), .85, 1.0)
	_panel("sign", w, x - .46, x + .46, 2.0, 2.18, 1.004, _cell_small(210, 490, 400, 120))
	_kit.quad("front", w * Vector3(x - .4, .06, 1.006), w * Vector3(x - .4, 1.92, 1.006), w * Vector3(x + .4, 1.92, 1.006), w * Vector3(x + .4, .06, 1.006), Color.WHITE)
	_kit.quad("hall", w * Vector3(x - .4, .06, 1.003), w * Vector3(x - .4, 1.92, 1.003), w * Vector3(x + .4, 1.92, 1.003), w * Vector3(x + .4, .06, 1.003), Color("#3a5a60"))
	_bar("led", w, x, 1.4, 1.008, Vector3(.42, .3, .004), CYAN * .6)
	_status(w, x + .32, 1.1, 1.01, GREEN)

func _blade() -> void:
	# Tall sign on the corner, cross first, visible all the way up the street.
	var w := _west
	var x := DEEP - .2
	var low := 3.7
	var high := 8.9
	_bar("metal", w, x, (low + high) * .5, .55, Vector3(.06, high - low, .84), Color("#2c2e30"), .8, 1.0)
	var rect := _cell_small(0, 0, 200, 760)
	var near := .15
	var far := .95
	_kit.atlas("sign", w * Vector3(x - .034, low, near), w * Vector3(x - .034, high, near), w * Vector3(x - .034, high, far), w * Vector3(x - .034, low, far), rect)
	_kit.atlas("sign", w * Vector3(x + .034, low, far), w * Vector3(x + .034, high, far), w * Vector3(x + .034, high, near), w * Vector3(x + .034, low, near), rect)
	for y: float in [low + .4, high - .4]:
		_bar("metal", w, x, y, .08, Vector3(.05, .05, .16), Color("#2c2e30"))

func _street_side() -> void:
	# The narrow front facing the chemist: small windows, pipes, the back of everything.
	var f := _front
	var holes: Array[Rect2] = []
	for row: int in range(2):
		holes.append(Rect2(1.0, GROUND + float(row) * STOREY + 1.1, .9, 1.0))
		holes.append(Rect2(3.6, GROUND + float(row) * STOREY + 1.1, .9, 1.0))
	_tiled(f, Rect2(0, 0, WIDE, PARAPET), holes)
	_bar("render", f, WIDE * .5, PARAPET + .05, -.05, Vector3(WIDE + .1, .1, .3), CREAM, .7, 1.0)
	for row: int in range(2):
		_window(f, Rect2(1.0, GROUND + float(row) * STOREY + 1.1, .9, 1.0), fposmod(.13 + float(row) * .41, 1.0), true)
		_window(f, Rect2(3.6, GROUND + float(row) * STOREY + 1.1, .9, 1.0), fposmod(.71 + float(row) * .37, 1.0), true)
		_outdoor_unit(f, 2.75, GROUND + float(row) * STOREY + .4, .2)
		_bar("metal", f, 2.75, GROUND + float(row) * STOREY + .07, .2, Vector3(.9, .03, .42), STEEL)
	_kit.tube("metal", [f * Vector3(.3, .1, .06), f * Vector3(.3, PARAPET - .3, .06)], .05, Color("#8a8b84"), 7)
	_fibre([f * Vector3(4.9, PARAPET - .1, .03), f * Vector3(4.9, 3.0, .03)])

func _rooftop() -> void:
	var half := WIDE * .5
	var level := TOP + .02
	_kit.quad("plain", Vector3(-half, level, 0), Vector3(-half, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, 0), Color("#62625e"), .8, .9)
	var inner := Color(.86, .84, .78)
	_kit.quad("render", Vector3(half - .02, level, -.02), Vector3(half - .02, PARAPET, -.02), Vector3(-half + .02, PARAPET, -.02), Vector3(-half + .02, level, -.02), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(-half + .02, level, -DEEP), Vector3(-half + .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, level, -DEEP), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(-half + .02, level, -.02), Vector3(-half + .02, PARAPET, -.02), Vector3(-half + .02, PARAPET, -DEEP), Vector3(-half + .02, level, -DEEP), inner, .7, 1.0, .5)
	_kit.quad("render", Vector3(half - .02, level, -DEEP), Vector3(half - .02, PARAPET, -DEEP), Vector3(half - .02, PARAPET, -.02), Vector3(half - .02, level, -.02), inner, .7, 1.0, .5)
	_kit.block("render", Transform3D(Basis.IDENTITY, Vector3(1.2, TOP + 1.2, -5.6)), Vector3(2.0, 2.4, 2.4), RENDER * .92, .75, 1.0, .7)
	var tank := Vector3(-1.0, TOP + 1.3, -5.4)
	_kit.lathe("plain", tank + Vector3.DOWN * .7, [Vector2(.7, 0), Vector2(.75, .1), Vector2(.75, 1.2), Vector2(.5, 1.45), Vector2(.02, 1.5)], Color("#b9c4c6"), 14)
	for x: float in [-.5, .5]:
		_kit.block("metal", Transform3D(Basis.IDENTITY, Vector3(tank.x + x, TOP + .3, tank.z)), Vector3(.08, .6, 1.2), STEEL)
	for x: float in [-1.5, .2]:
		_outdoor_unit(Transform3D(Basis.IDENTITY, Vector3(x, level, 0)), 0, .4, -1.4)
