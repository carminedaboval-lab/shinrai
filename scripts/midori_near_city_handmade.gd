extends Node3D
## What every hand-modelled city building shares: its kit, its looks, and the
## small parts that recur on any Tokyo wall. Local origin is the middle of the
## street front at pavement level, facing +Z.
const Kit := preload("res://scripts/midori_near_city_kit.gd")
const SHADER := preload("res://scripts/midori_near_city_bespoke.gdshader")
const GLASS_SHADER := preload("res://scripts/midori_near_city_glass.gdshader")
const FRONT_GLASS_SHADER := preload("res://scripts/midori_near_city_storefront.gdshader")
const DECAL_SHADER := preload("res://scripts/midori_near_city_decal.gdshader")
const TEXTURES := "res://assets/shinrai/near_city/textures/"
const ALUMINIUM := Color("#9a9a95")
const STEEL := Color("#4a4c4e")
const CYAN := Color(.3, .86, 1.0)
const AMBER := Color(1.0, .66, .22)
const GREEN := Color(.3, 1.0, .55)

var _kit := Kit.new()
var _rng := RandomNumberGenerator.new()
var _looks := {}
var _lamps: Array[Light3D] = []

func set_night_mode(value: bool) -> void:
	for look: ShaderMaterial in _looks.values():
		look.set_shader_parameter("night", 1.0 if value else 0.0)
	for lamp: Light3D in _lamps:
		lamp.visible = value

func _look(texture: String, tile: float, rough: float, metal := 0.0) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("tile", tile)
	look.set_shader_parameter("rough_scale", rough)
	look.set_shader_parameter("metal", metal)
	if texture != "":
		look.set_shader_parameter("albedo_map", load(TEXTURES + texture + "_diff.jpg"))
		look.set_shader_parameter("normal_map", load(TEXTURES + texture + "_nor.jpg"))
		if ResourceLoader.exists(TEXTURES + texture + "_rough.jpg"):
			look.set_shader_parameter("rough_map", load(TEXTURES + texture + "_rough.jpg"))
	return look

func _shared_looks() -> void:
	_looks.plain = _look("", 1.0, .82)
	_looks.metal = _look("", 1.0, .42, .55)
	_looks.bottle = _look("", 1.0, .16)
	_looks.leaf = _look("", 1.0, .6)
	_looks.lamp = _look("", 1.0, .5)
	_looks.lamp.set_shader_parameter("glow", 3.2)
	_looks.lamp.set_shader_parameter("day_glow", .5)
	_looks.neon = _look("", 1.0, .3)
	_looks.neon.set_shader_parameter("glow", 2.6)
	_looks.neon.set_shader_parameter("day_glow", .75)
	_looks.led = _look("", 1.0, .3)
	_looks.led.set_shader_parameter("glow", 1.5)
	_looks.led.set_shader_parameter("day_glow", .55)
	_looks.solar = _look("", 1.0, .1, .35)
	_looks.solar.set_shader_parameter("tile_size", Vector2(.156, .156))
	var glass := ShaderMaterial.new()
	glass.shader = GLASS_SHADER
	_looks.glass = glass
	var front_glass := ShaderMaterial.new()
	front_glass.shader = FRONT_GLASS_SHADER
	_looks.front = front_glass

func _cell(x: float, y: float, wide: float, tall: float) -> Rect2:
	return Rect2(x / 2048.0, y / 2048.0, wide / 2048.0, tall / 2048.0)

func _at(face: Transform3D, x: float, y: float, z: float) -> Transform3D:
	return Transform3D(face.basis, face * Vector3(x, y, z))

func _bar(part: String, face: Transform3D, x: float, y: float, z: float, size: Vector3, tint: Color, low := 1.0, high := 1.0) -> void:
	_kit.block(part, _at(face, x, y, z), size, tint, low, high)

func _reveal(face: Transform3D, r: Rect2, deep: float, tint: Color) -> void:
	# The four inner faces of an opening cut through a wall.
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	_kit.quad("plain", face * Vector3(x0, y0, 0), face * Vector3(x0, y1, 0), face * Vector3(x0, y1, -deep), face * Vector3(x0, y0, -deep), tint, .8, .6)
	_kit.quad("plain", face * Vector3(x1, y0, -deep), face * Vector3(x1, y1, -deep), face * Vector3(x1, y1, 0), face * Vector3(x1, y0, 0), tint, .8, .6)
	_kit.quad("plain", face * Vector3(x0, y1, -deep), face * Vector3(x0, y1, 0), face * Vector3(x1, y1, 0), face * Vector3(x1, y1, -deep), tint, .5, .5)
	_kit.quad("plain", face * Vector3(x0, y0, 0), face * Vector3(x0, y0, -deep), face * Vector3(x1, y0, -deep), face * Vector3(x1, y0, 0), tint, .9, .9)

func _minus(rect: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	# What is left of a rectangle once every hole is cut from it.
	var pieces: Array[Rect2] = [rect]
	for hole: Rect2 in holes:
		var kept: Array[Rect2] = []
		for piece: Rect2 in pieces:
			if not piece.intersects(hole):
				kept.append(piece)
				continue
			var cut := piece.intersection(hole)
			if cut.position.x > piece.position.x: kept.append(Rect2(piece.position, Vector2(cut.position.x - piece.position.x, piece.size.y)))
			if cut.end.x < piece.end.x: kept.append(Rect2(cut.end.x, piece.position.y, piece.end.x - cut.end.x, piece.size.y))
			if cut.position.y > piece.position.y: kept.append(Rect2(cut.position.x, piece.position.y, cut.size.x, cut.position.y - piece.position.y))
			if cut.end.y < piece.end.y: kept.append(Rect2(cut.position.x, cut.end.y, cut.size.x, piece.end.y - cut.end.y))
		pieces = kept
	return pieces

func _window(face: Transform3D, r: Rect2, cell: float, grille: bool) -> void:
	# Old aluminium sliding sash in a shallow reveal, with its two leaves on separate tracks.
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var middle := (x0 + x1) * .5
	var tall := r.size.y
	_reveal(face, r, .11, Color("#6b6a66"))
	_kit.pane("glass", face, x0, middle + .025, y0, y1, -.1, cell)
	_kit.pane("glass", face, middle - .025, x1, y0, y1, -.07, fposmod(cell + .37, 1.0))
	var alu := ALUMINIUM
	_bar("metal", face, (x0 + x1) * .5, y1 - .02, -.05, Vector3(r.size.x, .04, .07), alu)
	_bar("metal", face, (x0 + x1) * .5, y0 + .02, -.05, Vector3(r.size.x, .04, .07), alu)
	_bar("metal", face, x0 + .02, (y0 + y1) * .5, -.05, Vector3(.04, tall, .07), alu)
	_bar("metal", face, x1 - .02, (y0 + y1) * .5, -.05, Vector3(.04, tall, .07), alu)
	_bar("metal", face, middle - .028, (y0 + y1) * .5, -.075, Vector3(.035, tall - .06, .025), alu)
	_bar("metal", face, middle + .028, (y0 + y1) * .5, -.045, Vector3(.035, tall - .06, .025), alu)
	# Sheet flashing round the opening, proud of the wall.
	var edge := Color("#6e6f6c")
	_bar("metal", face, (x0 + x1) * .5, y0 - .012, .03, Vector3(r.size.x + .1, .03, .12), edge)
	_bar("metal", face, (x0 + x1) * .5, y1 + .012, .015, Vector3(r.size.x + .1, .03, .05), edge)
	_bar("metal", face, x0 - .015, (y0 + y1) * .5, .015, Vector3(.03, tall, .05), edge)
	_bar("metal", face, x1 + .015, (y0 + y1) * .5, .015, Vector3(.03, tall, .05), edge)
	if grille:
		var rods := int(r.size.x / .11)
		for rod: int in range(1, rods):
			_bar("metal", face, x0 + r.size.x * float(rod) / float(rods), (y0 + y1) * .5, .05, Vector3(.016, tall + .08, .016), alu)
		for y: float in [y0 - .02, y1 + .02]:
			_bar("metal", face, (x0 + x1) * .5, y, .05, Vector3(r.size.x + .1, .03, .03), alu)

func _render_wall(face: Transform3D, length: float, height: float, first: float, lift: float, paint: Color, holes: Array[Rect2], streak := .9) -> void:
	# Painted render in lifts, a storey at a time, so each pour shows its own weathering.
	var y := .0
	var top := first
	while y < height - .01:
		var bay := .0
		while bay < length - .01:
			var run := minf(2.4, length - bay)
			var tone := _rng.randf_range(.9, 1.04)
			var tint := Color(paint.r * tone, paint.g * tone, paint.b * tone)
			var uv := Vector2(_rng.randf() * 4.0, _rng.randf() * 4.0)
			for piece: Rect2 in _minus(Rect2(bay, y, run, minf(top, height) - y), holes):
				var at := uv + Vector2(piece.position.x - bay, y - piece.position.y)
				_kit.quad("render", face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), tint, .92, 1.0, streak, at)
			bay += run
		y = top
		top += lift
	# Construction joints, proud lines of old sealant.
	var line := first
	while line < height:
		_bar("plain", face, length * .5, line, .006, Vector3(length, .02, .012), Color("#5b5a54"))
		line += lift

func _plant(base: Vector3, tall: float, tint: Color) -> void:
	# A fan of leaves: enough to break the outline of a pot.
	for i: int in range(9):
		var angle := _rng.randf() * TAU
		var out := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-out.z, 0, out.x) * _rng.randf_range(.018, .04)
		var reach := _rng.randf_range(.4, 1.0)
		var tip := base + out * tall * .55 * reach + Vector3.UP * tall * _rng.randf_range(.5, 1.0)
		var tone := tint.darkened(_rng.randf_range(0.0, .3))
		_kit.quad("leaf", base - side, tip - side * .3, tip + side * .3, base + side, tone, .7, 1.0)
		_kit.quad("leaf", base + side, tip + side * .3, tip - side * .3, base - side, tone, .6, .9)

func _outdoor_unit(face: Transform3D, x: float, y: float, z: float) -> void:
	# Air-conditioner condenser: cased box, round fan guard, and a slatted side.
	var casing := Color("#c2c2b8")
	_bar("metal", face, x, y, z, Vector3(.82, .62, .3), casing)
	var front := face * Vector3(x - .1, y, z + .152)
	_kit.disc("plain", front, face.basis.x, face.basis.y, .23, Color("#222326"))
	for ring: float in [.08, .15, .22]:
		var points: Array[Vector3] = []
		for i: int in range(13):
			var angle := TAU * float(i) / 12.0
			points.append(front + (face.basis.x * cos(angle) + face.basis.y * sin(angle)) * ring + face.basis.z * .006)
		_kit.tube("metal", points, .005, Color("#8f908c"), 3)
	_bar("plain", face, x + .3, y, z + .153, Vector3(.13, .5, .004), casing.darkened(.3))

func _neon(points: Array[Vector3], tint: Color) -> void:
	# Bent glass tube, the one old trade the city never let go of.
	_kit.tube("neon", points, .013, tint, 5)

func _strip(from: Vector3, to: Vector3, tint: Color) -> void:
	_kit.beam("led", from, to, .03, .012, Vector3.UP, tint)

func _status(face: Transform3D, x: float, y: float, z: float, tint: Color) -> void:
	# Pin-prick status light on a piece of plant.
	_bar("led", face, x, y, z, Vector3(.035, .035, .012), tint)

func _camera(at: Vector3) -> void:
	# Street-safety dome, the same on every building since the ordinance.
	_kit.lathe("metal", at + Vector3.DOWN * .06, [Vector2(.03, 0), Vector2(.075, .03), Vector2(.075, .06)], Color("#d5d6d2"), 10)
	_kit.lathe("bottle", at + Vector3.DOWN * .12, [Vector2(0, 0), Vector2(.05, .012), Vector2(.07, .06)], Color("#0d0e11"), 10)

func _fibre(points: Array[Vector3]) -> void:
	# Later trunk cabling, run wherever was easiest: black with an orange tracer alongside.
	_kit.tube("plain", points, .022, Color("#17181a"), 5)
	var tracer: Array[Vector3] = []
	for p: Vector3 in points: tracer.append(p + Vector3(.03, 0, .02))
	_kit.tube("plain", tracer, .009, Color("#d9681c"), 4)

func _solar_module(xf: Transform3D, wide: float, tall: float) -> void:
	# Glass-faced module in a slim frame: xf.origin is its middle, +Z its face.
	var a := xf * Vector3(-wide * .5, -tall * .5, .025)
	var b := xf * Vector3(-wide * .5, tall * .5, .025)
	var c := xf * Vector3(wide * .5, tall * .5, .025)
	var d := xf * Vector3(wide * .5, -tall * .5, .025)
	_kit.quad("solar", a, b, c, d, Color(.035, .055, .11))
	_kit.block("metal", xf, Vector3(wide + .03, tall + .03, .04), Color("#6d7073"))

func _omni(label: String, at: Vector3, tint: Color, energy: float, reach: float) -> void:
	# A real lamp, on only after dark.
	var lamp := OmniLight3D.new()
	lamp.name = label
	lamp.position = at
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 1.3
	lamp.visible = false
	add_child(lamp)
	_lamps.append(lamp)
