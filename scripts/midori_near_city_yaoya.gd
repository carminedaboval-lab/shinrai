extends "res://scripts/midori_near_city_handmade.gd"
## マルモ青果: the Marumo family's greengrocer, open since 1973, two storeys under a tin gable.
## By day the shutter is up and the stock spills onto the pavement on a stepped wooden stand
## (fruit) and a steel one (vegetables), every pile in its blue basket or its market carton under
## a marker card; change hangs in a ざる on elastic over the stand. After seven everything is
## wheeled in, the painted shutter comes down, the empty crates wait under a tarp, and only the
## stair door and the family's front room stay lit.
const ATLAS := "res://assets/shinrai/near_city/yaoya_atlas.png"
const WIDE := 8.6
const DEEP := 10.4
const GROUND := 3.85
const EAVE := 6.7
const RIDGE := 8.35
const RIDGE_Z := -5.2
const FRONT_EDGE := .5
const BACK_EDGE := -10.9
const OPENING := Rect2(.3, 0, 6.7, 2.75)
const HOUSE := Rect2(7.3, 0, .85, 2.1)
const RX0 := .4
const RX1 := 6.9
const ROOM_TOP := 3.1
const ROOM_DEEP := 7.4
const NEAR := -.2
const STORE := Rect2(2.6, 0, .9, 2.0)
const W_LIVE := Rect2(.7, 4.45, 2.7, 1.35)
const W_OFF := Rect2(4.35, 4.55, 1.6, 1.15)
const W_STAIR := Rect2(7.5, 4.7, .5, .7)
const HATCH := Rect2(6.25, 4.75, .65, .6)
const E_STAIR := Rect2(.9, 4.6, .6, .7)
const E_WIN := Rect2(7.0, 4.35, 1.2, 1.05)
const E_GABLE := Rect2(4.9, 7.05, .6, .5)
const B_WIN := Rect2(2.0, 4.5, 1.4, 1.0)
const B_DOOR := Rect2(5.4, 0, .85, 2.0)
const CLAD := Color("#e4d4b0")
const RENDER_TINT := Color("#d4cebf")
const WOOD := Color("#4a3426")
const KRAFT := Color("#b8905e")
const WARM := Color(1.0, .9, .74)
const CUT_CODE := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Openwork plastic (baskets, crates): the atlas alpha draws the weave, the rest is air.
uniform float night = 0.0;
uniform float glow = 0.0;
uniform float day_glow = 0.0;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
void fragment(){
	vec4 face = texture(atlas, UV);
	vec3 color = face.rgb * COLOR.rgb;
	ALBEDO = color * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
	ROUGHNESS = 0.55;
	EMISSION = color * (mix(vec3(0.09, 0.07, 0.04), vec3(0.12, 0.09, 0.07), night) + mix(day_glow, glow, night));
	ALPHA = step(0.5, face.a);
}
"""
# kind: produce cell, half-size (y is the axis), lying, rings, sides.
const KINDS := {
	"mikan": [0, Vector3(.037, .031, .037), false, 4, 6],
	"kaki": [1, Vector3(.042, .032, .042), false, 4, 6],
	"apple": [2, Vector3(.045, .041, .045), false, 4, 7],
	"imo": [3, Vector3(.032, .09, .028), true, 4, 6],
	"kabocha": [4, Vector3(.1, .072, .1), false, 5, 10],
	"cabbage": [5, Vector3(.095, .085, .095), false, 5, 9],
	"hakusai": [6, Vector3(.08, .18, .075), true, 5, 9],
	"onion": [10, Vector3(.042, .038, .042), false, 4, 6],
	"potato": [11, Vector3(.038, .03, .045), false, 3, 6],
}

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _in := false
var _day: Node3D
var _night: Node3D

func _ready() -> void:
	_rng.seed = 1973
	_build_looks()
	_ground_front()
	_shutter_box()
	_canopy()
	_fascia()
	_shop_room()
	_in = true
	_fridge_case()
	_island()
	_back_wall_things()
	_east_shelves()
	_in = false
	_house_door()
	_upper_front()
	_side_walls()
	_roof()
	var unshadowed: Array[String] = ["front", "decal", "lamp", "led", "room", "steel_in", "floor_in", "tile_in", "plaster_in", "ply_in", "produce_in", "board_in", "weave_in", "veg_in", "cold", "curtain", "curtain_lit", "dim", "homelit", "frost", "cloth_in"]
	_kit.commit(self, _looks, unshadowed)
	_day = Node3D.new()
	_day.name = "OpenHours"
	add_child(_day)
	_kit = Kit.new()
	_open_front()
	_kit.commit(_day, _looks, unshadowed)
	_night = Node3D.new()
	_night.name = "Closed"
	_night.visible = false
	add_child(_night)
	_kit = Kit.new()
	_closed_front()
	_kit.commit(_night, _looks, unshadowed)
	_kit = null
	_omni("YaoyaDoor", _front * Vector3(7.72, 2.45, .55), Color(1.0, .84, .6), .5, 3.6)
	_omni("YaoyaShutter", _front * Vector3(3.6, 2.4, .6), Color(1.0, .82, .58), .45, 4.2)

func set_night_mode(value: bool) -> void:
	super.set_night_mode(value)
	if _day != null:
		_day.visible = not value
	if _night != null:
		_night.visible = value

# ---------------------------------------------------------------- looks

func _atlas_look(name: String, rough: float, glow: float, day: float) -> void:
	var look := _look("", 1.0, rough)
	look.set_shader_parameter("albedo_map", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _lit_look(name: String, rough: float, glow: float, day: float, metal := 0.0) -> void:
	var look := _look("", 1.0, rough, metal)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _lit_tex(name: String, texture: String, tile: float, rough: float, glow: float, day: float, chroma := .45) -> void:
	var look := _look(texture, tile, rough)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	look.set_shader_parameter("chroma", chroma)
	_looks[name] = look

func _cut_look(name: String, shader: Shader, glow: float, day: float) -> void:
	var look := ShaderMaterial.new()
	look.shader = shader
	look.set_shader_parameter("atlas", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _build_looks() -> void:
	_shared_looks()
	_looks.pier = _look("concrete_tile_facade", 1.4, .8)
	_looks.pier.set_shader_parameter("chroma", .5)
	_looks.clad = _look("white_stucco", 2.4, .9)
	_looks.clad.set_shader_parameter("chroma", .5)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .45)
	_looks.tin = _look("worn_corrugated_iron", 1.4, .6, .25)
	_looks.tin.set_shader_parameter("chroma", .5)
	_looks.canopy = _look("rusty_corrugated_iron", 1.2, .7, .2)
	_looks.canopy.set_shader_parameter("chroma", .55)
	_looks.shutter = _look("painted_metal_shutter", 1.2, .6, .2)
	_looks.shutter.set_shader_parameter("chroma", .5)
	_looks.slab = _look("precast_concrete_wall", 1.6, .9)
	_looks.slab.set_shader_parameter("chroma", .3)
	_looks.wood = _look("japanese_cedar_planks", 1.0, .8)
	_looks.wood.set_shader_parameter("chroma", .5)
	_looks.veg = _look("", 1.0, .6)
	_looks.veg.set_shader_parameter("day_glow", .04)
	_lit_look("veg_in", .6, .26, .1)
	_lit_tex("floor_in", "plastered_wall_03", 2.0, .5, .22, .1, .3)
	_lit_tex("tile_in", "long_white_tiles", 1.0, .35, .26, .1, .4)
	_lit_tex("plaster_in", "white_stucco", 2.5, .9, .26, .1)
	_lit_tex("ply_in", "japanese_cedar_planks", 1.0, .8, .26, .1)
	_lit_look("room", .6, .26, .1)
	_lit_look("steel_in", .35, .26, .1, .5)
	_lit_look("cold", .4, .5, .2)
	_lit_look("frost", .5, .34, .05)
	_lit_look("dim", .8, .035, .02)
	_lit_look("homelit", .8, .45, .04)
	_atlas_look("fascia", .5, .0, .02)
	_atlas_look("cloth", .9, .03, .02)
	_atlas_look("cloth_in", .9, .22, .08)
	_atlas_look("board", .7, .03, .05)
	_atlas_look("board_in", .7, .26, .1)
	_atlas_look("produce", .5, .02, .05)
	_atlas_look("produce_in", .5, .26, .1)
	_atlas_look("curtain", .9, .02, .02)
	_atlas_look("curtain_lit", .9, 1.1, .04)
	var decal := ShaderMaterial.new()
	decal.shader = DECAL_SHADER
	decal.set_shader_parameter("atlas", load(ATLAS))
	decal.set_shader_parameter("glow", .0)
	decal.set_shader_parameter("day_glow", .0)
	_looks.decal = decal
	var cut := Shader.new()
	cut.code = CUT_CODE
	_cut_look("weave", cut, .0, .03)
	_cut_look("weave_in", cut, .26, .1)

func _p(part: String) -> String:
	# Inside the shop the same things take their lit version of a look.
	return part + "_in" if _in else part

# ---------------------------------------------------------------- atlas cells

func _px(x: float, y: float, w: float, h: float) -> Rect2:
	return _cell(x, y, w, h)

func _card_cell(i: int) -> Rect2:
	return _px(1206.0 + float(i % 5) * 168.0, 202.0 + float(i / 5) * 110.0, 164, 106)

func _pop_cell(i: int) -> Rect2:
	return _px(float(i) * 200.0 + 4.0, 364, 192, 252)

func _box_cell(i: int) -> Rect2:
	return _px(float(i) * 256.0 + 2.0, 1132, 252, 96)

func _skin_cell(i: int) -> Rect2:
	return _px(float(i % 8) * 256.0 + 2.0, 1538.0 + float(i / 8) * 256.0, 252, 252)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _flat(part: String, face: Transform3D, area: Rect2, z: float, tint: Color, low := .9, streak := .6) -> void:
	_kit.quad(part, face * Vector3(area.position.x, area.position.y, z), face * Vector3(area.position.x, area.end.y, z), face * Vector3(area.end.x, area.end.y, z), face * Vector3(area.end.x, area.position.y, z), tint, low, 1.0, streak, Vector2(area.position.x, -area.position.y))

func _west_panel(part: String, x: float, z0: float, z1: float, y0: float, y1: float, rect: Rect2) -> void:
	# On a wall facing +x: z0 is the nearer edge.
	var f := _front
	_kit.atlas(part, f * Vector3(x, y0, z0), f * Vector3(x, y1, z0), f * Vector3(x, y1, z1), f * Vector3(x, y0, z1), rect)

# ---------------------------------------------------------------- shapes

func _sp(xf: Transform3D, size: Vector3, a: float, t: float) -> Vector3:
	return xf * Vector3(cos(t) * cos(a) * size.x, sin(a) * size.y, sin(t) * cos(a) * size.z)

func _sn(xf: Transform3D, size: Vector3, a: float, t: float) -> Vector3:
	return (xf.basis * Vector3(cos(t) * cos(a) / size.x, sin(a) / size.y, sin(t) * cos(a) / size.z)).normalized()

func _skin(part: String, xf: Transform3D, size: Vector3, cell: int, tint: Color, rings := 4, sides := 7, start := 0.0, around := TAU) -> void:
	# An egg with a drawn skin wrapped round it: the top of the atlas cell is the stem end.
	var rect := _skin_cell(cell)
	var marks: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for r: int in range(rings):
		var a0 := -PI * .5 + PI * float(r) / float(rings)
		var a1 := -PI * .5 + PI * float(r + 1) / float(rings)
		var v0 := rect.position.y + rect.size.y * (1.0 - float(r) / float(rings))
		var v1 := rect.position.y + rect.size.y * (1.0 - float(r + 1) / float(rings))
		for s: int in range(sides):
			var t0 := start - around * float(s) / float(sides)
			var t1 := start - around * float(s + 1) / float(sides)
			var u0 := rect.position.x + rect.size.x * float(s) / float(sides)
			var u1 := rect.position.x + rect.size.x * float(s + 1) / float(sides)
			var pts: Array[Vector3] = [_sp(xf, size, a0, t0), _sp(xf, size, a1, t0), _sp(xf, size, a1, t1), _sp(xf, size, a0, t1)]
			var ns: Array[Vector3] = [_sn(xf, size, a0, t0), _sn(xf, size, a1, t0), _sn(xf, size, a1, t1), _sn(xf, size, a0, t1)]
			var uv: Array[Vector2] = [Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0)]
			_kit.mapped(part, pts, ns, uv, marks, tint)

func _spindle(part: String, a: Vector3, b: Vector3, radii: Array[float], cell: int, tint: Color, sides := 6) -> void:
	# Tapered root or stalk from a (top of the cell) to b.
	var rect := _skin_cell(cell)
	var dir := (b - a).normalized()
	var side := (Vector3.UP if absf(dir.y) < .9 else Vector3.RIGHT).cross(dir).normalized()
	var over := dir.cross(side)
	var marks: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var last := radii.size() - 1
	for i: int in range(last):
		var t0 := float(i) / float(last)
		var t1 := float(i + 1) / float(last)
		for s: int in range(sides):
			var g0 := TAU * float(s) / float(sides)
			var g1 := TAU * float(s + 1) / float(sides)
			var n0 := side * cos(g0) + over * sin(g0)
			var n1 := side * cos(g1) + over * sin(g1)
			var pts: Array[Vector3] = [a.lerp(b, t0) + n0 * radii[i], a.lerp(b, t1) + n0 * radii[i + 1], a.lerp(b, t1) + n1 * radii[i + 1], a.lerp(b, t0) + n1 * radii[i]]
			var ns: Array[Vector3] = [n0, n0, n1, n1]
			var u0 := rect.position.x + rect.size.x * float(s) / float(sides)
			var u1 := rect.position.x + rect.size.x * float(s + 1) / float(sides)
			var uv: Array[Vector2] = [Vector2(u0, rect.position.y + rect.size.y * t0), Vector2(u0, rect.position.y + rect.size.y * t1), Vector2(u1, rect.position.y + rect.size.y * t1), Vector2(u1, rect.position.y + rect.size.y * t0)]
			_kit.mapped(part, pts, ns, uv, marks, tint)

func _turn(part: String, xf: Transform3D, profile: Array[Vector2], tint: Color, sides := 10, cell := -1) -> void:
	# A lathe that can sit tilted on a stand; with cell, it wraps an atlas panel (the weave).
	var rect := _skin_cell(cell) if cell >= 0 else Rect2()
	var marks: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var last := profile.size() - 1
	for j: int in range(last):
		var p0 := profile[j]
		var p1 := profile[j + 1]
		var slope := Vector2(p1.y - p0.y, p0.x - p1.x).normalized()
		for k: int in range(sides):
			var a0 := TAU * float(k) / float(sides)
			var a1 := TAU * float(k + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (xf.basis * (d0 * slope.x + Vector3.UP * slope.y)).normalized()
			var n1 := (xf.basis * (d1 * slope.x + Vector3.UP * slope.y)).normalized()
			var a := xf * (d0 * p0.x + Vector3.UP * p0.y)
			var b := xf * (d0 * p1.x + Vector3.UP * p1.y)
			var c := xf * (d1 * p1.x + Vector3.UP * p1.y)
			var d := xf * (d1 * p0.x + Vector3.UP * p0.y)
			if cell < 0:
				_kit.smooth(part, a, b, c, d, n0, n0, n1, n1, tint)
			else:
				var u0 := rect.position.x + rect.size.x * float(k) / float(sides) * 3.0
				var u1 := rect.position.x + rect.size.x * float(k + 1) / float(sides) * 3.0
				u0 = rect.position.x + fposmod(u0 - rect.position.x, rect.size.x)
				u1 = u0 + rect.size.x * 3.0 / float(sides)
				var v0 := rect.end.y - rect.size.y * float(j) / float(last)
				var v1 := rect.end.y - rect.size.y * float(j + 1) / float(last)
				var pts: Array[Vector3] = [a, b, c, d]
				var ns: Array[Vector3] = [n0, n0, n1, n1]
				var uv: Array[Vector2] = [Vector2(u0, v0), Vector2(u0, v1), Vector2(minf(u1, rect.end.x), v1), Vector2(minf(u1, rect.end.x), v0)]
				_kit.mapped(part, pts, ns, uv, marks, tint)

func _xf(at: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(basis, at)

# ---------------------------------------------------------------- produce

func _jit() -> Color:
	var k := _rng.randf_range(.88, 1.08)
	return Color(k, k * _rng.randf_range(.96, 1.03), k * _rng.randf_range(.94, 1.02))

func _item(kind: String, foot: Vector3, basis: Basis) -> void:
	# One piece of produce standing (or lying) on foot, its stand's basis given.
	var row: Array = KINDS[kind]
	var size: Vector3 = row[1]
	var lying: bool = row[2]
	var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
	var part := _p("produce")
	if lying:
		var b := basis * yaw * Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
		var centre := foot + basis.y * size.z * .92
		_skin(part, _xf(centre, b), size, row[0], _jit(), row[3], row[4])
		return
	var tilt := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0, .25))
	var b2 := basis * yaw * tilt
	var c2 := foot + basis.y * size.y * .95
	_skin(part, _xf(c2, b2), size, row[0], _jit(), row[3], row[4])
	var top := c2 + b2.y * size.y
	if kind == "apple":
		_kit.tube(_p("veg"), [top - b2.y * .006, top + b2.y * .018 + b2.x * .004], .0025, Color("#4a3420"), 3)
	elif kind == "kaki":
		for k: int in range(4):
			var a := float(k) * PI * .5 + .4
			var out := b2.x * cos(a) + b2.z * sin(a)
			_kit.quad(_p("veg"), top - out * .004 - b2.y * .002, top + out * .03 - b2.y * .006 + (b2.x * -sin(a) + b2.z * cos(a)) * .012, top + out * .034 - b2.y * .008, top + out * .03 - b2.y * .006 - (b2.x * -sin(a) + b2.z * cos(a)) * .012, Color("#4a4a22"), .8, 1.0)
	elif kind == "kabocha":
		_kit.tube(_p("veg"), [top - b2.y * .01, top + b2.y * .03 + b2.x * .01], .012, Color("#7a6a46"), 5)

func _mori(xf: Transform3D, kind: String) -> void:
	# 一盛: a blue plastic basket and the heap the price is for, four round and one on top.
	var w := _p("weave")
	_turn(w, xf, [Vector2(.07, 0), Vector2(.095, .045), Vector2(.105, .055), Vector2(.1, .058)], Color.WHITE, 10, 13)
	_kit.disc(w, xf * Vector3(0, .004, 0), xf.basis.x, -xf.basis.z, .07, Color.WHITE, _skin_cell(13))
	var b := xf.basis
	if kind == "imo":
		for k: int in range(3):
			_item("imo", xf * Vector3(-.045 + float(k) * .045, .006, 0), b * Basis(Vector3.UP, .1 * float(k - 1)))
		_item("imo", xf * Vector3(0, .05, 0), b * Basis(Vector3.UP, PI * .5))
		return
	var size: Vector3 = KINDS[kind][1]
	var r := size.x * 1.05
	for k: int in range(4):
		var a := float(k) * PI * .5 + .6
		_item(kind, xf * Vector3(cos(a) * r, .006, sin(a) * r), b)
	_item(kind, xf * Vector3(0, size.y * 1.3, 0), b)

func _carton(xf: Transform3D, size: Vector3, print: int, kind: String, layer := true) -> void:
	# Open market carton: printed end to the street, flaps folded out, the top layer showing.
	var part := _p("board")
	var hx := size.x * .5
	var hz := size.z * .5
	var h := size.y
	var kraft := _skin_cell(15)
	var front := _box_cell(print) if print >= 0 else kraft
	var p := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x, y, z)
	_kit.atlas(part, p.call(-hx, 0, hz), p.call(-hx, h, hz), p.call(hx, h, hz), p.call(hx, 0, hz), front)
	_kit.atlas(part, p.call(hx, 0, -hz), p.call(hx, h, -hz), p.call(-hx, h, -hz), p.call(-hx, 0, -hz), kraft)
	_kit.atlas(part, p.call(hx, 0, hz), p.call(hx, h, hz), p.call(hx, h, -hz), p.call(hx, 0, -hz), kraft, Color(.92, .92, .92))
	_kit.atlas(part, p.call(-hx, 0, -hz), p.call(-hx, h, -hz), p.call(-hx, h, hz), p.call(-hx, 0, hz), kraft, Color(.92, .92, .92))
	var inner := Color(.6, .56, .52)
	_kit.atlas(part, p.call(hx, 0, hz), p.call(hx, h, hz), p.call(-hx, h, hz), p.call(-hx, 0, hz), kraft, inner)
	_kit.atlas(part, p.call(-hx, 0, -hz), p.call(-hx, h, -hz), p.call(hx, h, -hz), p.call(hx, 0, -hz), kraft, inner)
	# Side flaps out at an angle, front flap tucked down inside.
	for s: float in [-1.0, 1.0]:
		var e := hx * s
		var o := (hx + .09) * s
		_kit.atlas(part, p.call(e, h, hz), p.call(o, h + .06, hz), p.call(o, h + .06, -hz), p.call(e, h, -hz), kraft, Color(.85, .85, .85))
		_kit.atlas(part, p.call(e, h, -hz), p.call(o, h + .06, -hz), p.call(o, h + .06, hz), p.call(e, h, hz), kraft, Color(.85, .85, .85))
	if kind == "":
		return
	var row: Array = KINDS[kind]
	var fill := h - .035
	_kit.quad(_p("veg"), p.call(-hx, fill, hz), p.call(-hx, fill, -hz), p.call(hx, fill, -hz), p.call(hx, fill, hz), Color("#3a2a1e"))
	if not layer:
		return
	var s2: Vector3 = row[1]
	var step := s2.x * 2.1
	var nx := int(size.x / step)
	var nz := int(size.z / step)
	for i: int in range(nx):
		for k: int in range(nz):
			var x := -hx + step * (float(i) + .5) + (size.x - step * float(nx)) * .5
			var z := -hz + step * (float(k) + .5) + (size.z - step * float(nz)) * .5
			_item(kind, p.call(x, fill - s2.y * .5, z), xf.basis)

func _crate(part: String, xf: Transform3D, size: Vector3, tint: Color) -> void:
	# Folding plastic コンテナ: slotted sides, solid rim.
	var hx := size.x * .5
	var hz := size.z * .5
	var h := size.y
	var cell := _skin_cell(12)
	var p := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x, y, z)
	_kit.atlas(part, p.call(-hx, 0, hz), p.call(-hx, h, hz), p.call(hx, h, hz), p.call(hx, 0, hz), cell, tint)
	_kit.atlas(part, p.call(hx, 0, -hz), p.call(hx, h, -hz), p.call(-hx, h, -hz), p.call(-hx, 0, -hz), cell, tint)
	_kit.atlas(part, p.call(hx, 0, hz), p.call(hx, h, hz), p.call(hx, h, -hz), p.call(hx, 0, -hz), cell, tint)
	_kit.atlas(part, p.call(-hx, 0, -hz), p.call(-hx, h, -hz), p.call(-hx, h, hz), p.call(-hx, 0, hz), cell, tint)
	_kit.atlas(part, p.call(-hx, .01, hz), p.call(-hx, .01, -hz), p.call(hx, .01, -hz), p.call(hx, .01, hz), cell, tint * .8)
	var rim := Color(tint.r * .18, tint.g * .5, tint.b * .3)
	var solid := "veg_in" if _in else "plain"
	_kit.block(solid, Transform3D(xf.basis, p.call(0, h - .012, hz)), Vector3(size.x, .024, .012), rim)
	_kit.block(solid, Transform3D(xf.basis, p.call(0, h - .012, -hz)), Vector3(size.x, .024, .012), rim)
	_kit.block(solid, Transform3D(xf.basis, p.call(hx, h - .012, 0)), Vector3(.012, .024, size.z), rim)
	_kit.block(solid, Transform3D(xf.basis, p.call(-hx, h - .012, 0)), Vector3(.012, .024, size.z), rim)

func _card(at: Vector3, cell: Rect2, w := .13, stick := .14, lean := .3) -> void:
	# A marker card on a split chopstick, pushed into the pile, leaning back a little.
	var h := w * cell.size.y / cell.size.x
	var up := Vector3(0, cos(lean), -sin(lean))
	var right := Vector3.RIGHT.rotated(Vector3.UP, _rng.randf_range(-.15, .15))
	var foot := at + Vector3.UP * stick
	var part := _p("board")
	_kit.atlas(part, foot - right * w * .5, foot - right * w * .5 + up * h, foot + right * w * .5 + up * h, foot + right * w * .5, cell)
	_kit.quad(_p("veg"), foot + right * w * .5 - Vector3(0, 0, .002), foot + right * w * .5 + up * h - Vector3(0, 0, .002), foot - right * w * .5 + up * h - Vector3(0, 0, .002), foot - right * w * .5 - Vector3(0, 0, .002), Color("#c8b898"))
	_kit.tube(_p("veg"), [at, foot + up * h * .4 - Vector3(0, 0, .004)], .0035, Color("#d8c49a"), 3)

func _pop(at: Vector3, i: int, lean := .25, w := .22) -> void:
	# A big carton-lid POP standing behind the pile, propped on its own fold.
	var cell := _pop_cell(i)
	var h := w * cell.size.y / cell.size.x
	var up := Vector3(0, cos(lean), -sin(lean))
	var r := Vector3.RIGHT * w * .5
	var part := _p("board")
	_kit.atlas(part, at - r, at - r + up * h, at + r + up * h, at + r, cell)
	_kit.atlas(part, at + r - Vector3(0, 0, .004), at + r + up * h - Vector3(0, 0, .004), at - r + up * h - Vector3(0, 0, .004), at - r - Vector3(0, 0, .004), _skin_cell(15), Color(.8, .8, .8))

func _daikon(top: Vector3, tip: Vector3) -> void:
	var radii: Array[float] = [.03, .036, .036, .032, .024, .012, .003]
	_spindle(_p("produce"), top, tip, radii, 7, _jit(), 7)
	var along := (tip - top).normalized()
	for k: int in range(5):
		var a := float(k) * 1.3
		var out := (-along + Vector3(cos(a), 1.0, sin(a)) * .45).normalized()
		var side := out.cross(Vector3.UP).normalized() * .012
		var end := top + out * _rng.randf_range(.1, .16)
		_kit.quad(_p("veg"), top - side, end - side * .5, end + side * .5, top + side, Color("#4a7a34"), .8, 1.0)
		_kit.quad(_p("veg"), top + side, end + side * .5, end - side * .5, top - side, Color("#3e6a2c"), .8, 1.0)

func _negi(a: Vector3, b: Vector3) -> void:
	# A bundle of three, banded twice in red, the flags fanned at the far end.
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var radii: Array[float] = [.006, .011, .012, .012, .013]
	for k: int in range(3):
		var off := side * (float(k) - 1.0) * .022 + Vector3.UP * (.012 if k == 1 else 0.0)
		_spindle(_p("produce"), a + off - side * (float(k) - 1.0) * .015 * 0.0, b + off, radii, 8, _jit(), 5)
	for t: float in [.5, .78]:
		_kit.tube(_p("veg"), [a.lerp(b, t) - side * .045 + Vector3.UP * .012, a.lerp(b, t) + side * .045 + Vector3.UP * .012], .006, Color("#c42a2a"), 4)

func _hakusai_half(foot: Vector3, basis: Basis, yaw: float) -> void:
	# Cut lengthwise, cut face up under film: the yellow heart is what sells it.
	var size: Vector3 = KINDS.hakusai[1]
	var b := basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	var centre := foot + basis.y * .002
	_skin(_p("produce"), _xf(centre, b), size, 6, _jit(), 5, 8, PI, PI)
	_kit.disc(_p("produce"), centre + basis.y * .001, b.y * size.y, b.x * size.x, 1.0, Color.WHITE, _skin_cell(14))

# ---------------------------------------------------------------- ground floor front

func _ground_front() -> void:
	var f := _front
	for piece: Rect2 in _minus(Rect2(0, .14, WIDE, GROUND - .14), [OPENING, HOUSE] as Array[Rect2]):
		_flat("pier", f, piece, 0.0, Color("#a49a8a"), .85, .5)
	for piece: Rect2 in _minus(Rect2(0, 0, WIDE, .14), [OPENING, HOUSE] as Array[Rect2]):
		_bar("slab", f, piece.get_center().x, .07, .015, Vector3(piece.size.x, .14, .04), Color("#6e6a64"))
	var x0 := OPENING.position.x
	var x1 := OPENING.end.x
	var y1 := OPENING.end.y
	var pier := Color("#7a7268")
	_kit.quad("pier", f * Vector3(x0, 0, 0), f * Vector3(x0, y1, 0), f * Vector3(x0, y1, NEAR), f * Vector3(x0, 0, NEAR), pier, .7, .8)
	_kit.quad("pier", f * Vector3(x1, 0, NEAR), f * Vector3(x1, y1, NEAR), f * Vector3(x1, y1, 0), f * Vector3(x1, 0, 0), pier, .7, .8)
	_kit.quad("plain", f * Vector3(x0, y1, NEAR), f * Vector3(x0, y1, 0), f * Vector3(x1, y1, 0), f * Vector3(x1, y1, NEAR), Color("#4a4640"), .6, .6)
	for x: float in [x0 + .035, x1 - .035]:
		_bar("metal", f, x, y1 * .5, .03, Vector3(.07, y1, .07), Color("#6a6e6a"))
		_bar("plain", f, x, y1 * .5, .067, Vector3(.025, y1, .004), Color("#2a2c2c"))
	_bar("metal", f, OPENING.get_center().x, .008, -.03, Vector3(OPENING.size.x, .016, .12), Color("#7a7670"))
	# Drain grating along the threshold: the floor is hosed out every evening.
	_bar("metal", f, OPENING.get_center().x, .012, .12, Vector3(OPENING.size.x, .012, .14), Color("#3a3a38"))
	# Hours on the west pier, the camera, fibre up the east pier into the hatch.
	_bar("plain", f, .15, 1.62, .012, Vector3(.27, .2, .01), Color("#d8d4cc"))
	_panel("board", f, .025, .275, 1.53, 1.71, .019, _px(1802, 1352, 244, 176))
	_camera(f * Vector3(.15, 2.62, .2))
	_bar("metal", f, .15, 2.64, .08, Vector3(.06, .06, .16), Color("#d5d6d2"))
	# Meters and the electric box on the pier between shop and stair door.
	_bar("metal", f, 7.15, 1.55, .08, Vector3(.22, .32, .14), Color("#c8c6b8"))
	_bar("plain", f, 7.15, 1.6, .152, Vector3(.12, .08, .004), Color("#2a2a28"))
	_status(f, 7.15, 1.45, .155, GREEN * .7)

func _shutter_box() -> void:
	var f := _front
	var cx := OPENING.get_center().x
	_bar("shutter", f, cx, 2.88, .1, Vector3(OPENING.size.x + .12, .28, .2), Color("#8a8e88"), .8, 1.0)
	_bar("metal", f, cx, 2.74, .1, Vector3(OPENING.size.x + .1, .03, .2), Color("#4a4e4a"))

func _canopy_y(z: float) -> float:
	return lerpf(3.02, 2.8, z / 1.55)

func _canopy() -> void:
	# Fixed sheet-steel canopy, red oxide gone to brick, on three angle brackets.
	var f := _front
	var x0 := .08
	var x1 := 7.2
	var out := 1.55
	var paint := Color("#9a5a48")
	_kit.quad("canopy", f * Vector3(x0, _canopy_y(out), out), f * Vector3(x0, _canopy_y(0), .02), f * Vector3(x1, _canopy_y(0), .02), f * Vector3(x1, _canopy_y(out), out), paint, .9, 1.0, .6)
	_kit.quad("canopy", f * Vector3(x1, _canopy_y(out) - .02, out), f * Vector3(x1, _canopy_y(0) - .02, .02), f * Vector3(x0, _canopy_y(0) - .02, .02), f * Vector3(x0, _canopy_y(out) - .02, out), Color("#5a4a40"), .6, .7)
	# Front lip, the end cheeks, and a gutter that drips onto the drain.
	_bar("metal", f, (x0 + x1) * .5, _canopy_y(out) - .08, out + .01, Vector3(x1 - x0, .18, .025), Color("#8a4a3a"))
	for x: float in [x0, x1]:
		_kit.quad("metal", f * Vector3(x, _canopy_y(out) - .17, out), f * Vector3(x, _canopy_y(out), out), f * Vector3(x, _canopy_y(0), 0), f * Vector3(x, _canopy_y(0) - .1, 0), Color("#7a4234"), .8, .9)
	for x: float in [.4, 3.6, 6.9]:
		_kit.beam("metal", f * Vector3(x, 2.4, .02), f * Vector3(x, _canopy_y(out * .8) - .03, out * .8), .04, .04, Vector3.RIGHT, Color("#5a5450"))
	# Conduit along the underside for the lamps.
	_kit.tube("metal", [f * Vector3(.5, _canopy_y(1.0) - .05, 1.0), f * Vector3(6.8, _canopy_y(1.0) - .05, 1.0)], .012, Color("#d8d6d0"), 4)

func _fascia() -> void:
	var f := _front
	_bar("metal", f, WIDE * .5, 3.46, .03, Vector3(WIDE, .8, .06), Color("#5a4a40"))
	_panel("fascia", f, .06, WIDE - .06, 3.09, 3.83, .062, _px(0, 0, 2048, 200))
	_bar("metal", f, WIDE * .5, 3.87, .05, Vector3(WIDE + .02, .03, .1), Color("#6a5a50"))

# ---------------------------------------------------------------- the shop room

func _shop_room() -> void:
	var f := _front
	var deep := -ROOM_DEEP
	_kit.quad("floor_in", f * Vector3(RX0, .02, NEAR), f * Vector3(RX0, .02, deep), f * Vector3(RX1, .02, deep), f * Vector3(RX1, .02, NEAR), Color(.5, .5, .48), .75, .8)
	_kit.quad("room", f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, ROOM_TOP, NEAR), f * Vector3(RX1, ROOM_TOP, NEAR), f * Vector3(RX1, ROOM_TOP, deep), Color("#b8b4a4"), .7, .7)
	var z := -.8
	while z > deep:
		_bar("room", f, (RX0 + RX1) * .5, ROOM_TOP - .01, z, Vector3(RX1 - RX0, .02, .03), Color("#9a9686"))
		z -= .9
	var rail := 1.2
	var wall := Color("#e8e4d6")
	var tile := Color("#e8ece4")
	_kit.quad("tile_in", f * Vector3(RX0, 0, NEAR), f * Vector3(RX0, rail, NEAR), f * Vector3(RX0, rail, deep), f * Vector3(RX0, 0, deep), tile, .7, 1.0)
	_kit.quad("plaster_in", f * Vector3(RX0, rail, NEAR), f * Vector3(RX0, ROOM_TOP, NEAR), f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, rail, deep), wall, 1.0, .8)
	_kit.quad("tile_in", f * Vector3(RX1, 0, deep), f * Vector3(RX1, rail, deep), f * Vector3(RX1, rail, NEAR), f * Vector3(RX1, 0, NEAR), tile, .7, 1.0)
	_kit.quad("plaster_in", f * Vector3(RX1, rail, deep), f * Vector3(RX1, ROOM_TOP, deep), f * Vector3(RX1, ROOM_TOP, NEAR), f * Vector3(RX1, rail, NEAR), wall, 1.0, .8)
	for piece: Rect2 in _minus(Rect2(RX0, 0, RX1 - RX0, ROOM_TOP), [STORE] as Array[Rect2]):
		var lower := Rect2(piece.position.x, piece.position.y, piece.size.x, minf(rail, piece.end.y) - piece.position.y)
		if lower.size.y > .01:
			_flat("tile_in", f, lower, deep, tile, .7, 0.0)
		var upper := Rect2(piece.position.x, maxf(rail, piece.position.y), piece.size.x, piece.end.y - maxf(rail, piece.position.y))
		if upper.size.y > .01:
			_flat("plaster_in", f, upper, deep, wall, 1.0, 0.0)
	_kit.quad("room", f * Vector3(RX1, OPENING.end.y, NEAR), f * Vector3(RX1, ROOM_TOP, NEAR), f * Vector3(RX0, ROOM_TOP, NEAR), f * Vector3(RX0, OPENING.end.y, NEAR), Color("#8a8476"))
	# Bare fluorescent troughs across the room.
	for zz: float in [-1.3, -3.4, -5.5]:
		for xx: float in [1.9, 5.0]:
			_bar("steel_in", f, xx, ROOM_TOP - .04, zz, Vector3(2.4, .05, .12), Color("#d8d8d4"))
			for dz: float in [-.03, .03]:
				_kit.tube("lamp", [f * Vector3(xx - 1.15, ROOM_TOP - .09, zz + dz), f * Vector3(xx + 1.15, ROOM_TOP - .09, zz + dz)], .014, WARM * .55, 5)
	# The storeroom behind the noren: dim, sacks and crates.
	var x0 := STORE.position.x - .5
	var x1 := STORE.end.x + .7
	var back := deep - 1.3
	var dim := Color("#6a6052")
	_kit.quad("room", f * Vector3(x0, .02, deep), f * Vector3(x0, .02, back), f * Vector3(x1, .02, back), f * Vector3(x1, .02, deep), dim * .8)
	_kit.quad("room", f * Vector3(x0, 0, back), f * Vector3(x0, 2.4, back), f * Vector3(x1, 2.4, back), f * Vector3(x1, 0, back), dim * .7)
	_kit.quad("room", f * Vector3(x0, 0, deep), f * Vector3(x0, 2.4, deep), f * Vector3(x0, 2.4, back), f * Vector3(x0, 0, back), dim * .6)
	_kit.quad("room", f * Vector3(x1, 0, back), f * Vector3(x1, 2.4, back), f * Vector3(x1, 2.4, deep), f * Vector3(x1, 0, deep), dim * .6)
	_kit.quad("room", f * Vector3(x0, 2.4, back), f * Vector3(x0, 2.4, deep), f * Vector3(x1, 2.4, deep), f * Vector3(x1, 2.4, back), dim * .5)
	for k: int in range(3):
		_bar("room", f, x0 + .35, .2 + float(k) * .26, back + .3, Vector3(.5, .25, .34), Color("#2a6a40") * .7)
	_bar("room", f, x1 - .4, .3, back + .35, Vector3(.45, .6, .4), Color("#8a7454"))
	for x: float in [STORE.position.x, STORE.end.x]:
		_bar("room", f, x, 1.0, deep, Vector3(.06, 2.0, .12), Color("#5a4030"))
	_bar("room", f, STORE.get_center().x, 2.02, deep, Vector3(STORE.size.x + .1, .06, .12), Color("#5a4030"))
	for half: int in range(2):
		var a := STORE.position.x + float(half) * STORE.size.x * .5 + .01
		var b := a + STORE.size.x * .5 - .02
		_kit.atlas("cloth_in", f * Vector3(a, 1.25, deep + .05 + float(half) * .01), f * Vector3(a, 1.98, deep + .04), f * Vector3(b, 1.98, deep + .04), f * Vector3(b, 1.25, deep + .05 + float(half) * .01), _px(2.0 + float(half) * 150.0, 1352, 146, 176))

func _fridge_case() -> void:
	# Open multideck on the west wall: tofu, konnyaku, natto, eggs, pickles, a cold white light.
	var f := _front
	var xb := RX0 + .05
	var xf := 1.15
	var z0 := -1.4
	var z1 := -4.6
	var zc := (z0 + z1) * .5
	var run := z0 - z1
	_bar("steel_in", f, (xb + xf) * .5, .3, zc, Vector3(xf - xb, .6, run), Color("#e4e4de"))
	_bar("steel_in", f, xf - .01, .3, zc, Vector3(.02, .5, run - .1), Color("#3a3c3e"))
	_bar("steel_in", f, (xb + xf) * .5 - .1, 2.05, zc, Vector3(xf - xb - .2, .3, run), Color("#e4e4de"))
	_bar("steel_in", f, xb + .01, 1.3, zc, Vector3(.03, 1.5, run), Color("#2a2c2e"))
	for z: float in [z0, z1]:
		_bar("steel_in", f, (xb + xf) * .5, 1.05, z, Vector3(xf - xb, 2.1, .04), Color("#dcdcd6"))
	_kit.quad("cold", f * Vector3(xf - .25, 1.895, z0), f * Vector3(xf - .25, 1.895, z1), f * Vector3(xf - .2, 1.895, z1), f * Vector3(xf - .2, 1.895, z0), Color(.85, .95, 1.0))
	var shelves: Array[float] = [.6, .92, 1.24, 1.56]
	for i: int in range(shelves.size()):
		var y: float = shelves[i]
		var depth := .55 - float(i) * .05
		_bar("steel_in", f, xb + depth * .5, y, zc, Vector3(depth, .02, run - .06), Color("#c8ccd0"))
		_bar("steel_in", f, xb + depth, y + .02, zc, Vector3(.01, .05, run - .06), Color("#e8d040"))
		var z := z0 - .08
		var k := i * 3
		while z - .44 > z1:
			var tone := Color("#e8e6dc") if (k % 8) != 2 else Color("#7a7a72")
			_bar("room", f, xb + depth - .12, y + .1, z - .22, Vector3(.2, .16, .42), tone)
			_west_panel("board_in", xb + depth - .019, z, z - .44, y + .02, y + .18, _px(float(k % 8) * 256.0 + 2.0, 1242, 252, 96))
			z -= .48
			k += 1

func _island() -> void:
	# Low table down the middle: cartons of onions and potatoes, baskets, mikan by the box.
	var f := _front
	var x0 := 2.4
	var x1 := 4.8
	var zc := -3.2
	_bar("ply_in", f, (x0 + x1) * .5, .6, zc, Vector3(x1 - x0, .04, 1.4), Color("#c8a478"))
	for x: float in [x0 + .05, x1 - .05]:
		for z: float in [zc - .65, zc + .65]:
			_bar("steel_in", f, x, .3, z, Vector3(.04, .6, .04), Color("#6a6e72"))
	_bar("ply_in", f, (x0 + x1) * .5, .12, zc, Vector3(x1 - x0 - .1, .02, 1.3), Color("#a88458"))
	var t := Transform3D(Basis(Vector3.RIGHT, .08), f * Vector3((x0 + x1) * .5, .62, zc))
	_carton(Transform3D(t.basis, t * Vector3(-.85, 0, .3)), Vector3(.5, .16, .36), 4, "onion")
	_carton(Transform3D(t.basis, t * Vector3(-.85, 0, -.3)), Vector3(.5, .16, .36), 7, "potato")
	_carton(Transform3D(t.basis, t * Vector3(.0, 0, -.3)), Vector3(.5, .16, .36), 0, "mikan")
	_carton(Transform3D(t.basis, t * Vector3(.85, 0, -.3)), Vector3(.5, .16, .36), 5, "cabbage", false)
	for k: int in range(2):
		_item("cabbage", t * Vector3(.75 + float(k) * .18, .13, -.3), t.basis)
	var kinds: Array[String] = ["onion", "potato", "onion", "potato"]
	for k: int in range(4):
		_mori(Transform3D(t.basis, t * Vector3(-.3 + float(k) * .3, 0, .38)), kinds[k])
	_card(t * Vector3(-.85, .16, .5), _card_cell(10), .11, .08)
	_card(t * Vector3(.0, .05, .52), _card_cell(11), .11, .06)
	# Under the table: spare crates.
	for k: int in range(2):
		_crate("weave_in", Transform3D(Basis.IDENTITY, f * Vector3(x0 + .5 + float(k) * .9, .14, zc)), Vector3(.52, .3, .36), Color("#ffffff"))

func _back_wall_things() -> void:
	var f := _front
	var bz := -ROOM_DEEP
	# Rice: a pallet, ten-kilo sacks on end with the new crop's print out, the poster above.
	_bar("ply_in", f, 1.45, .06, bz + .3, Vector3(1.6, .12, .5), Color("#a88458"))
	for k: int in range(4):
		var x := .85 + float(k) * .41
		var lean := Basis(Vector3.RIGHT, -.08)
		var at := f * Vector3(x, .12 + .3, bz + .28)
		_kit.block("room", Transform3D(lean, at), Vector3(.38, .6, .16), Color("#ece6d6"))
		var c := at + lean * Vector3(0, 0, .081)
		_kit.atlas("board_in", c + lean * Vector3(-.18, -.29, 0), c + lean * Vector3(-.18, .29, 0), c + lean * Vector3(.18, .29, 0), c + lean * Vector3(.18, -.29, 0), _px(1882, 652, 156, 216))
	_kit.block("room", Transform3D(Basis(Vector3.UP, .1), f * Vector3(1.3, .5, bz + .65)), Vector3(.6, .15, .38), Color("#ece6d6"))
	_panel("board_in", f, 1.05, 1.55, 1.35, 2.04, bz + .012, _px(1882, 882, 156, 216))
	_panel("board_in", f, 3.85, 4.25, 1.5, 2.08, bz + .012, _px(1712, 822, 156, 232))
	# Counter at the back right: register, palm pad, the old scale, a bag of bags.
	var x0 := 4.5
	var x1 := 6.5
	var z := -6.55
	_bar("ply_in", f, (x0 + x1) * .5, .45, z, Vector3(x1 - x0, .9, .5), Color("#b89068"))
	_bar("room", f, (x0 + x1) * .5, .92, z, Vector3(x1 - x0 + .06, .04, .58), Color("#5a4a3a"))
	_bar("room", f, x0 + .5, 1.02, z - .05, Vector3(.36, .16, .3), Color("#3a3c40"))
	_kit.block("led", Transform3D(Basis(Vector3.RIGHT, -.4), f * Vector3(x0 + .5, 1.14, z - .1)), Vector3(.2, .07, .006), Color(.12, .22, .25))
	_scale(f * Vector3(x0 + 1.2, .94, z), "steel_in")
	_bar("room", f, x1 - .3, 1.0, z, Vector3(.25, .12, .2), Color("#e8e4d8"))
	# Shelf over the counter: konbu, dried shiitake, pickles in jars.
	for level: int in range(2):
		var y := 1.45 + float(level) * .4
		_bar("ply_in", f, (x0 + x1) * .5, y, bz + .18, Vector3(x1 - x0, .025, .3), Color("#8a6a48"))
		var x := x0 + .05
		while x < x1 - .15:
			var w := _rng.randf_range(.1, .18)
			var hh := _rng.randf_range(.14, .26)
			_kit.lathe("room", f * Vector3(x + w * .5, y + .013, bz + .18), [Vector2(w * .45, 0), Vector2(w * .45, hh), Vector2(w * .3, hh + .02)], [Color("#c8b898"), Color("#4a6a3a"), Color("#e8d8a0"), Color("#8a4a2a")][_rng.randi_range(0, 3)], 8)
			x += w + .04

func _east_shelves() -> void:
	# East wall: dry goods on a steel rack, net bags of onions hung off it, crates by the door.
	var f := _front
	var x := RX1 - .25
	var z0 := -1.2
	var z1 := -4.2
	var zc := (z0 + z1) * .5
	for zz: float in [z0, zc, z1]:
		_bar("steel_in", f, x, .9, zz, Vector3(.4, 1.8, .03), Color("#8a9096"))
	for y: float in [.2, .7, 1.2, 1.7]:
		_bar("steel_in", f, x, y, zc, Vector3(.42, .025, z0 - z1), Color("#a8aeb4"))
		var z := z0 - .1
		while z > z1 + .1:
			var w := _rng.randf_range(.14, .28)
			var hh := _rng.randf_range(.12, .3)
			var tones: Array[Color] = [Color("#d8c8a0"), Color("#c84a3a"), Color("#e8e4d8"), Color("#3a6a8a"), Color("#d8a040"), Color("#6a8a4a")]
			_bar("room", f, x - .02, y + .013 + hh * .5, z - w * .5, Vector3(.3, hh, w), tones[_rng.randi_range(0, 5)])
			z -= w + .03
	for k: int in range(3):
		var hook := f * Vector3(RX1 - .06, 2.25, -1.6 - float(k) * .9)
		_kit.tube("steel_in", [hook, hook + Vector3(-.04, -.15, 0)], .004, Color("#a8aeb4"), 3)
		_skin("produce_in", Transform3D(Basis.IDENTITY, hook + Vector3(-.1, -.38, 0)), Vector3(.1, .2, .1), 10, Color(1.15, .75, .55), 4, 7)
	for k: int in range(3):
		_crate("weave_in", Transform3D(Basis(Vector3.UP, .05 * float(k)), f * Vector3(6.4, float(k) * .3, -.75)), Vector3(.52, .3, .36), Color("#5a8ad8") if k == 1 else Color.WHITE)

func _scale(at: Vector3, part: String) -> void:
	# 上皿はかり: white body, round dial to the customer, a steel pan.
	_kit.block(part, Transform3D(Basis.IDENTITY, at + Vector3(0, .08, 0)), Vector3(.2, .16, .2), Color("#ecebe4"))
	_kit.block(part, Transform3D(Basis(Vector3.RIGHT, -.3), at + Vector3(0, .12, .1)), Vector3(.16, .16, .04), Color("#ecebe4"))
	_kit.disc(part, at + Vector3(0, .125, .125), Vector3.RIGHT, Vector3(0, cos(.3), -sin(.3)), .06, Color("#f8f6ee"))
	_kit.tube(part, [at + Vector3(0, .125, .128), at + Vector3(.03, .16, .126)], .003, Color("#c42a24"), 3)
	_kit.lathe(part, at + Vector3(0, .16, -.01), [Vector2(.02, 0), Vector2(.02, .015), Vector2(.13, .03), Vector2(.14, .045)], Color("#c8ccd0"), 12)

# ---------------------------------------------------------------- open hours: the street front

func _open_front() -> void:
	var f := _front
	# The centre post goes in each morning, the hours card on it.
	_bar("metal", f, 3.6, 1.375, .0, Vector3(.08, 2.75, .08), Color("#6a6e6a"))
	_panel("board", f, 3.38, 3.82, 1.42, 1.99, .045, _px(1206, 652, 316, 416))
	_bar("plain", f, 3.6, 1.705, .03, Vector3(.48, .61, .02), Color("#b8bab8"))
	_fruit_stand()
	_veg_stand()
	_spill()
	_lamps_over()

func _tier(x0: float, x1: float, y: float, zc: float, depth: float, tilt: float, wood: bool) -> Transform3D:
	var t := Transform3D(Basis(Vector3.RIGHT, tilt), _front * Vector3((x0 + x1) * .5, y, zc))
	if wood:
		_kit.block("wood", Transform3D(t.basis, t * Vector3(0, -.016, 0)), Vector3(x1 - x0, .032, depth), WOOD)
		_kit.block("wood", Transform3D(t.basis, t * Vector3(0, -.01, depth * .5 + .01)), Vector3(x1 - x0, .06, .02), WOOD * .8)
	else:
		# Steel shelf under a sheet of artificial turf, the yaoya's own green.
		_kit.block("metal", Transform3D(t.basis, t * Vector3(0, -.012, 0)), Vector3(x1 - x0, .012, depth), Color("#8a8e90"))
		_kit.block("plain", Transform3D(t.basis, t * Vector3(0, -.003, .01)), Vector3(x1 - x0 - .02, .008, depth + .04), Color("#3e7a36"), .9, 1.0)
		_kit.block("plain", Transform3D(t.basis, t * Vector3(0, -.04, depth * .5 + .035)), Vector3(x1 - x0 - .02, .08, .006), Color("#3a7232"), .9, 1.0)
		for s: float in [-.5, .5]:
			_kit.block("metal", Transform3D(t.basis, t * Vector3(0, -.02, depth * s)), Vector3(x1 - x0, .04, .03), ALUMINIUM)
	return t

func _fruit_stand() -> void:
	# ひな壇: three stepped boards of dark-stained plank, tipped toward the street.
	var f := _front
	var x0 := .45
	var x1 := 3.05
	var tilt := .17
	var t1 := _tier(x0, x1, .56, 1.0, .5, tilt, true)
	var t2 := _tier(x0, x1, .84, .5, .5, tilt, true)
	var t3 := _tier(x0, x1, 1.1, .0, .5, tilt, true)
	# Sides: stepped cheeks, a skirt board, styrofoam boxes stored underneath.
	for x: float in [x0 + .02, x1 - .02]:
		for row: Vector3 in [Vector3(.56, 1.0, .5), Vector3(.84, .5, .5), Vector3(1.1, 0.0, .5)]:
			_bar("wood", f, x, row.x * .5, row.y, Vector3(.04, row.x, row.z), WOOD * .9)
	_bar("wood", f, (x0 + x1) * .5, .28, 1.25, Vector3(x1 - x0, .38, .02), WOOD * .75)
	for k: int in range(3):
		_bar("plain", f, x0 + .45 + float(k) * .85, .22, .55, Vector3(.6, .3, .4), Color("#eceee8"))
	# Front: seven baskets, one 一盛 each.
	var kinds: Array[String] = ["mikan", "mikan", "kaki", "kaki", "apple", "apple", "mikan"]
	var backs: Array[String] = ["kaki", "mikan", "mikan", "apple", "kaki", "mikan", "apple"]
	for i: int in range(7):
		_mori(Transform3D(t1.basis, t1 * Vector3(-1.11 + float(i) * .37, 0, .12)), kinds[i])
		_mori(Transform3D(t1.basis * Basis(Vector3.UP, .4), t1 * Vector3(-1.11 + float(i) * .37 + .04, 0, -.12)), backs[i])
	_card(t1 * Vector3(-.93, .02, .235), _card_cell(0), .12, .1)
	_card(t1 * Vector3(-.19, .02, .235), _card_cell(1), .12, .1)
	_card(t1 * Vector3(.55, .02, .235), _card_cell(2), .12, .1)
	_card(t1 * Vector3(1.1, .02, .235), _card_cell(13), .1, .08)
	_card(t1 * Vector3(-.56, .02, .0), _card_cell(14), .1, .17)
	_card(t1 * Vector3(.2, .02, .0), _card_cell(17), .1, .17)
	# Middle: the market cartons themselves, mikan, apples, kaki.
	var prints: Array[int] = [0, 1, 2]
	var fills: Array[String] = ["mikan", "apple", "kaki"]
	for i: int in range(3):
		_carton(Transform3D(t2.basis, t2 * Vector3(-.85 + float(i) * .85, 0, 0)), Vector3(.56, .15, .38), prints[i], fills[i])
	_card(t2 * Vector3(-.6, .14, .17), _card_cell(12), .1, .03)
	# e-paper: the wholesaler's tag clipped on the apple carton, beside the marker one.
	_kit.atlas("board", t2 * Vector3(-.12, .1, .195), t2 * Vector3(-.12, .175, .21), t2 * Vector3(.0, .175, .21), t2 * Vector3(.0, .1, .195), _px(1532, 652, 164, 106))
	_card(t2 * Vector3(.95, .14, .17), _card_cell(18), .1, .03)
	# Top: sweet potatoes for roasting, shiitake trays, the scale, and the big cards behind.
	for i: int in range(3):
		_mori(Transform3D(t3.basis, t3 * Vector3(-1.05 + float(i) * .27, 0, .05)), "imo")
	_carton(Transform3D(t3.basis, t3 * Vector3(.45, 0, .02)), Vector3(.44, .13, .34), 1, "apple")
	for i: int in range(2):
		var at := t3 * Vector3(-.22 + float(i) * .24, 0, .08)
		_kit.block("plain", Transform3D(t3.basis, at + t3.basis.y * .012), Vector3(.2, .024, .14), Color("#f2f2ee"))
		for k: int in range(4):
			var c := at + t3.basis * Vector3(-.05 + float(k % 2) * .1, .035, -.03 + float(k / 2) * .06)
			_kit.lathe("produce", c, [Vector2(.012, -.01), Vector2(.012, .0)], Color("#e8dcc4"), 5)
			_kit.disc("produce", c + Vector3.UP * .002, Vector3.RIGHT, Vector3.FORWARD, .036, Color.WHITE, _skin_cell(9))
	_scale(t3 * Vector3(1.02, 0, .0), "plain")
	_card(t3 * Vector3(-.8, .02, .22), _card_cell(7), .12, .06)
	_card(t3 * Vector3(-.1, .02, .2), _card_cell(9), .11, .05)
	_pop(t3 * Vector3(-.95, 0, -.22), 5)
	_pop(t3 * Vector3(-.3, 0, -.22), 1)
	_pop(t3 * Vector3(.45, 0, -.22), 0)
	# Change in a zaru on elastic over the stand, the card reader on its lanyard beside it.
	var hang := f * Vector3(2.75, _canopy_y(.75) - .02, .75)
	var zaru := f * Vector3(2.75, 1.62, .75)
	_kit.tube("plain", [hang, zaru + Vector3.UP * .14], .004, Color("#2a2a2a"), 3)
	for k: int in range(3):
		var a := TAU * float(k) / 3.0
		_kit.tube("plain", [zaru + Vector3.UP * .14, zaru + Vector3(cos(a) * .11, .06, sin(a) * .11)], .002, Color("#2a2a2a"), 3)
	_kit.lathe("plain", zaru, [Vector2(.05, 0), Vector2(.1, .05), Vector2(.12, .065), Vector2(.112, .068), Vector2(.09, .05), Vector2(.0, .02)], Color("#b89a5a"), 12)
	for k: int in range(4):
		_kit.disc("metal", zaru + Vector3(_rng.randf_range(-.04, .04), .028 + float(k) * .002, _rng.randf_range(-.04, .04)), Vector3.RIGHT, Vector3.FORWARD, .012, Color("#c8b070") if k % 2 == 0 else Color("#b8bcc0"))
	var pad := f * Vector3(2.4, 1.6, .78)
	_kit.tube("plain", [f * Vector3(2.4, _canopy_y(.78) - .02, .78), pad + Vector3.UP * .1], .003, Color("#1e1e20"), 3)
	_kit.block("plain", Transform3D(Basis.IDENTITY, pad), Vector3(.1, .18, .02), Color("#202224"))
	_kit.block("led", Transform3D(Basis.IDENTITY, pad + Vector3(0, .02, .011)), Vector3(.075, .09, .002), CYAN * .45)
	_status(Transform3D(Basis.IDENTITY, pad), 0, -.065, .012, GREEN)

func _veg_stand() -> void:
	# Steel frame stand: hakusai, cabbage and kabocha low; daikon, negi, onions above.
	var f := _front
	var x0 := 4.15
	var x1 := 6.6
	var tilt := .12
	var t1 := _tier(x0, x1, .5, 1.0, .5, tilt, false)
	var t2 := _tier(x0, x1, .92, .45, .5, tilt, false)
	for x: float in [x0 + .02, x1 - .02]:
		for row: Vector2 in [Vector2(.5, 1.23), Vector2(.5, .77), Vector2(.92, .68), Vector2(.92, .22)]:
			_bar("metal", f, x, row.x * .5, row.y, Vector3(.03, row.x, .03), ALUMINIUM)
	_crate("weave", Transform3D(Basis.IDENTITY, f * Vector3(4.6, 0, .95)), Vector3(.52, .3, .36), Color.WHITE)
	_crate("weave", Transform3D(Basis.IDENTITY, f * Vector3(5.9, 0, .95)), Vector3(.52, .3, .36), Color.WHITE)
	for k: int in range(2):
		_item("cabbage", f * Vector3(4.5 + float(k) * .2, .2, .95), Basis.IDENTITY)
	# Low tier: a crate of cabbages, whole hakusai, two halves, kabocha on a carton.
	_crate("weave", Transform3D(t1.basis, t1 * Vector3(-.92, 0, 0)), Vector3(.52, .2, .38), Color.WHITE)
	for k: int in range(6):
		_item("cabbage", t1 * Vector3(-1.09 + float(k % 3) * .17, .03 + float(k % 2) * .02, -.09 + float(k / 3) * .18), t1.basis)
	var size: Vector3 = KINDS.hakusai[1]
	for k: int in range(5):
		var high := k >= 3
		var at := t1 * Vector3(-.42 + float(k) * .18 if not high else -.33 + float(k - 3) * .18, .13 if high else 0.0, -.01)
		var b := t1.basis * Basis(Vector3.UP, _rng.randf_range(-.1, .1)) * Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
		_skin("produce", _xf(at + t1.basis.y * size.z, b), size, 6, _jit(), 5, 9)
	_hakusai_half(t1 * Vector3(.2, 0, .02), t1.basis, .05)
	_hakusai_half(t1 * Vector3(.4, 0, .02), t1.basis, -.06)
	_carton(Transform3D(t1.basis, t1 * Vector3(.92, 0, 0)), Vector3(.52, .1, .38), 4, "", false)
	for k: int in range(5):
		var at2: Vector3 = [Vector3(.78, .07, -.08), Vector3(1.02, .07, -.08), Vector3(.78, .07, .1), Vector3(1.02, .07, .1), Vector3(.9, .2, .01)][k]
		_item("kabocha", t1 * at2, t1.basis)
	_card(t1 * Vector3(-.92, .2, .21), _card_cell(6), .12, .02)
	_card(t1 * Vector3(-.32, .02, .22), _card_cell(4), .12, .08)
	_card(t1 * Vector3(.28, .02, .22), _card_cell(15), .1, .07)
	_card(t1 * Vector3(.92, .1, .21), _card_cell(8), .12, .04)
	# Upper tier: daikon in their carton, negi bundles, onions and potatoes by the basket.
	var dc := Transform3D(t2.basis, t2 * Vector3(-.85, 0, 0))
	_carton(dc, Vector3(.6, .14, .4), 6, "", false)
	for k: int in range(5):
		var z := -.13 + float(k) * .065
		_daikon(dc * Vector3(-.36, .12 + float(k % 2) * .03, z), dc * Vector3(.26, .09 + float(k % 2) * .03, z + .02))
	for k: int in range(5):
		var x := -.34 + float(k) * .1
		_negi(t2 * Vector3(x, .03 + float(k % 2) * .01, -.3), t2 * Vector3(x + .03, .02, .32))
	var kinds: Array[String] = ["onion", "onion", "potato", "potato"]
	for k: int in range(4):
		_mori(Transform3D(t2.basis, t2 * Vector3(.3 + float(k) * .25, 0, .05)), kinds[k])
	_card(t2 * Vector3(-.85, .12, .22), _card_cell(3), .12, .03)
	_card(t2 * Vector3(-.15, .02, .3), _card_cell(5), .12, .05)
	_card(t2 * Vector3(.42, .02, .22), _card_cell(10), .11, .06)
	_card(t2 * Vector3(.92, .02, .22), _card_cell(16), .11, .06)
	_kit.atlas("board", t2 * Vector3(.6, .07, .2), t2 * Vector3(.6, .145, .215), t2 * Vector3(.72, .145, .215), t2 * Vector3(.72, .07, .2), _px(1532, 772, 164, 106))
	_pop(t2 * Vector3(-.75, 0, -.22), 2)
	_pop(t2 * Vector3(.2, 0, -.22), 3)
	_pop(t2 * Vector3(.95, 0, -.22), 4)

func _spill() -> void:
	# Empties stacked by the stair door, cardboard flattened against the pier, the banner.
	var f := _front
	var colours: Array[Color] = [Color.WHITE, Color.WHITE, Color("#5a8ad8"), Color.WHITE, Color(1.2, 1.0, .5)]
	for k: int in range(5):
		_crate("weave", Transform3D(Basis(Vector3.UP, _rng.randf_range(-.08, .08)), f * Vector3(6.95, float(k) * .3, .32)), Vector3(.52, .3, .36), colours[k])
	for k: int in range(3):
		var x0 := .02 + float(k) * .025
		var z0 := .26 + float(k) * .025
		_kit.atlas("board", f * Vector3(x0, 0, z0), f * Vector3(x0, .86, .03 + float(k) * .02), f * Vector3(x0 + .4, .86, .03 + float(k) * .02), f * Vector3(x0 + .4, 0, z0), _skin_cell(15) if k != 1 else _box_cell(3))
		_kit.atlas("board", f * Vector3(x0 + .4, 0, z0 - .005), f * Vector3(x0 + .4, .86, .025 + float(k) * .02), f * Vector3(x0, .86, .025 + float(k) * .02), f * Vector3(x0, 0, z0 - .005), _skin_cell(15), Color(.7, .7, .7))
	_panel("cloth", f, 1.6, 4.8, 2.32, 2.72, 1.585, _px(0, 202, 1200, 146))
	for x: float in [1.62, 4.78]:
		_kit.tube("plain", [f * Vector3(x, 2.7, 1.585), f * Vector3(x, 2.78, 1.575)], .003, Color("#e8e4d8"), 3)
	for row: Vector2 in [Vector2(1.12, 0.0), Vector2(5.22, 4.0)]:
		var x := row.x
		var cell := _pop_cell(int(row.y))
		_kit.atlas("board", f * Vector3(x - .12, 2.2, 1.585), f * Vector3(x - .12, 2.52, 1.585), f * Vector3(x + .12, 2.52, 1.585), f * Vector3(x + .12, 2.2, 1.585), cell)
		_kit.tube("plain", [f * Vector3(x, 2.52, 1.585), f * Vector3(x, _canopy_y(1.55) - .1, 1.57)], .003, Color("#2a2a2a"), 3)

func _lamps_over() -> void:
	# Bare bulbs on flex from the canopy conduit, two clip-on reflectors over the stands.
	var f := _front
	for x: float in [1.05, 2.15, 4.75, 5.95]:
		var top := f * Vector3(x, _canopy_y(1.0) - .06, 1.0)
		var bulb := top + Vector3.DOWN * .42
		_kit.tube("plain", [top, bulb + Vector3.UP * .06], .004, Color("#1e1e20"), 3)
		_kit.lathe("plain", bulb + Vector3.UP * .03, [Vector2(.018, 0), Vector2(.018, .05)], Color("#2a2a2a"), 8)
		_kit.lathe("lamp", bulb - Vector3.UP * .045, [Vector2(.008, 0), Vector2(.03, .02), Vector2(.034, .05), Vector2(.018, .075)], WARM * .8, 8)
	for x: float in [3.05, 4.1]:
		var clip := f * Vector3(x, _canopy_y(.6) - .04, .6)
		_kit.tube("metal", [clip, clip + Vector3(0, -.14, .06)], .008, Color("#3a3a3a"), 4)
		var mouth := clip + Vector3(0, -.3, .1)
		_kit.lathe("metal", mouth, [Vector2(.11, 0), Vector2(.07, .08), Vector2(.03, .14)], Color("#c8ccd0"), 12)
		_kit.disc("lamp", mouth + Vector3.UP * .07, Vector3.RIGHT, Vector3.BACK, .045, WARM * .8)

# ---------------------------------------------------------------- after closing

func _closed_front() -> void:
	var f := _front
	var x0 := OPENING.position.x + .03
	var x1 := OPENING.end.x - .03
	_flat("shutter", f, Rect2(x0, 0, x1 - x0, OPENING.end.y - .05), .05, Color("#a8aaa0"), .8, .7)
	_panel("decal", f, x0 + .03, x1 - .03, .06, OPENING.end.y - .1, .062, _px(2, 642, 1196, 456))
	_bar("metal", f, (x0 + x1) * .5, .03, .055, Vector3(x1 - x0, .06, .06), Color("#4a4e4a"))
	for x: float in [x0 + .8, x1 - .8]:
		_bar("metal", f, x, .1, .085, Vector3(.12, .03, .03), Color("#2a2c2a"))
		_bar("metal", f, x, .05, .09, Vector3(.06, .08, .05), Color("#8a6a2a"))
	# Empties under a blue sheet, roped, by the stair door.
	var at := f * Vector3(6.6, 0, .45)
	for k: int in range(3):
		_crate("weave", Transform3D(Basis.IDENTITY, at + Vector3(0, float(k) * .3, 0)), Vector3(.52, .3, .36), Color.WHITE)
	var blue := Color("#2a5ab0")
	var h := .95
	var a := at + Vector3(-.3, 0, .22)
	var b := at + Vector3(.3, 0, .22)
	var c := at + Vector3(.3, 0, -.22)
	var d := at + Vector3(-.3, 0, -.22)
	_kit.quad("plain", a + Vector3(0, .05, .02), a + Vector3(.02, h, -.02), b + Vector3(-.02, h, -.02), b + Vector3(0, .1, .03), blue, .7, 1.0)
	_kit.quad("plain", b + Vector3(.03, .1, 0), b + Vector3(-.02, h, -.02), c + Vector3(-.02, h, .02), c + Vector3(.02, .3, 0), blue * .85, .7, 1.0)
	_kit.quad("plain", d + Vector3(-.02, .2, 0), d + Vector3(.02, h, .02), a + Vector3(.02, h, -.02), a + Vector3(0, .05, .02), blue * .85, .7, 1.0)
	_kit.quad("plain", a + Vector3(.02, h, -.02), d + Vector3(.02, h, .02), c + Vector3(-.02, h, .02), b + Vector3(-.02, h, -.02), blue * 1.05, 1.0, 1.0)
	_kit.tube("plain", [a + Vector3(-.01, .6, .03), b + Vector3(.01, .58, .03), c + Vector3(.03, .6, -.01)], .006, Color("#d8c040"), 3)
	# Tomorrow's 資源ごみ: flattened cartons tied with string at the kerb side of the west pier.
	var bundle := f * Vector3(.55, 0, .4)
	_kit.block("plain", Transform3D(Basis(Vector3.RIGHT, -.15), bundle + Vector3(0, .32, 0)), Vector3(.6, .64, .1), KRAFT * .9)
	_kit.atlas("board", bundle + Vector3(-.3, .02, .06), bundle + Basis(Vector3.RIGHT, -.15) * Vector3(-.3, .64, .05), bundle + Basis(Vector3.RIGHT, -.15) * Vector3(.3, .64, .05), bundle + Vector3(.3, .02, .06), _skin_cell(15))
	# The one bulb left burning under the canopy all night, over the shutter.
	var top := f * Vector3(3.6, _canopy_y(.5) - .05, .5)
	var bulb := top + Vector3.DOWN * .3
	_kit.tube("plain", [top, bulb + Vector3.UP * .06], .004, Color("#1e1e20"), 3)
	_kit.lathe("plain", bulb + Vector3.UP * .03, [Vector2(.018, 0), Vector2(.018, .05)], Color("#2a2a2a"), 8)
	_kit.lathe("lamp", bulb - Vector3.UP * .045, [Vector2(.008, 0), Vector2(.03, .02), Vector2(.034, .05), Vector2(.018, .075)], WARM * .7, 8)
	_kit.tube("plain", [bundle + Vector3(-.31, .3, .02), bundle + Vector3(.31, .3, .02)], .004, Color("#e8e0c8"), 3)

# ---------------------------------------------------------------- the stair door

func _house_door() -> void:
	var f := _front
	var d := HOUSE
	_reveal(f, d, .12, Color("#6a6a64"))
	_flat("frost", f, Rect2(d.position.x + .06, .5, d.size.x - .12, d.size.y - .62), -.07, Color("#c8c4b0"), 1.0, 0.0)
	var y := .58
	while y < d.end.y - .1:
		_bar("frost", f, d.get_center().x, y, -.065, Vector3(d.size.x - .14, .008, .004), Color("#a8a49c"))
		y += .06
	_bar("metal", f, d.get_center().x, .27, -.07, Vector3(d.size.x - .04, .46, .03), Color("#7a6a58"))
	for x: float in [d.position.x + .03, d.end.x - .03]:
		_bar("metal", f, x, d.size.y * .5, -.06, Vector3(.06, d.size.y, .05), Color("#8a7a68"))
	_bar("metal", f, d.get_center().x, d.end.y - .03, -.06, Vector3(d.size.x, .06, .05), Color("#8a7a68"))
	_bar("metal", f, d.position.x + .12, 1.0, -.03, Vector3(.025, .16, .03), Color("#3a3a38"))
	_bar("slab", f, d.get_center().x, .06, .12, Vector3(d.size.x + .1, .12, .26), Color("#8a8680"))
	# Bulkhead lamp over it, on all night; mailbox and the family's nameplate.
	var lamp := f * Vector3(d.get_center().x, 2.32, .08)
	_kit.block("metal", Transform3D(Basis.IDENTITY, lamp), Vector3(.16, .1, .1), Color("#3a3a38"))
	_kit.lathe("lamp", lamp + Vector3(0, -.11, .04), [Vector2(.04, 0), Vector2(.05, .05), Vector2(.04, .07)], WARM, 8)
	_bar("metal", f, 8.38, 1.12, .07, Vector3(.28, .34, .14), Color("#c8c4b4"))
	_bar("plain", f, 8.38, 1.2, .142, Vector3(.2, .025, .004), Color("#2a2a28"))
	_bar("plain", f, 8.38, 1.48, .02, Vector3(.1, .14, .03), Color("#d8d8d0"))
	_status(f, 8.38, 1.52, .036, CYAN * .6)

# ---------------------------------------------------------------- upstairs

func _roof_y(z: float) -> float:
	if z >= RIDGE_Z:
		return lerpf(EAVE, RIDGE, (FRONT_EDGE - z) / (FRONT_EDGE - RIDGE_Z))
	return lerpf(EAVE, RIDGE, (z - BACK_EDGE) / (RIDGE_Z - BACK_EDGE))

func _home_window(face: Transform3D, r: Rect2, curtain: String, cell: Rect2, gap: float, tint := Color.WHITE) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	_reveal(face, r, .14, Color("#8a8680"))
	var room := "homelit" if curtain == "curtain_lit" else "dim"
	var back := -1.5
	var tone := Color("#c8b89c")
	_kit.quad(room, face * Vector3(x0, y0 - .3, back), face * Vector3(x0, y1 + .3, back), face * Vector3(x1, y1 + .3, back), face * Vector3(x1, y0 - .3, back), tone, .6, .9)
	_kit.quad(room, face * Vector3(x0, y0 - .3, -.14), face * Vector3(x0, y1 + .3, -.14), face * Vector3(x0, y1 + .3, back), face * Vector3(x0, y0 - .3, back), tone * .8, .6, .9)
	_kit.quad(room, face * Vector3(x1, y0 - .3, back), face * Vector3(x1, y1 + .3, back), face * Vector3(x1, y1 + .3, -.14), face * Vector3(x1, y0 - .3, -.14), tone * .8, .6, .9)
	_kit.quad(room, face * Vector3(x0, y1 + .3, back), face * Vector3(x0, y1 + .3, -.14), face * Vector3(x1, y1 + .3, -.14), face * Vector3(x1, y1 + .3, back), tone * .9, .6, .6)
	_kit.quad(room, face * Vector3(x0, y0 - .3, -.14), face * Vector3(x0, y0 - .3, back), face * Vector3(x1, y0 - .3, back), face * Vector3(x1, y0 - .3, -.14), Color("#6a5440"), .6, .6)
	var mid := (x0 + x1) * .5
	var half := Rect2(cell.position, Vector2(cell.size.x * .5, cell.size.y))
	_panel(curtain, face, x0 + .02, mid - gap * .5, y0 + .02, y1 - .02, -.11, half, tint)
	_panel(curtain, face, mid + gap * .5, x1 - .02, y0 + .02, y1 - .02, -.115, Rect2(half.position + Vector2(half.size.x, 0), half.size), tint)
	_kit.quad("front", face * Vector3(x0, y0, -.05), face * Vector3(x0, y1, -.05), face * Vector3(x1, y1, -.05), face * Vector3(x1, y0, -.05), Color.WHITE)
	var alu := ALUMINIUM
	_bar("metal", face, mid, y1 - .02, -.05, Vector3(r.size.x, .04, .07), alu)
	_bar("metal", face, mid, y0 + .02, -.05, Vector3(r.size.x, .04, .07), alu)
	_bar("metal", face, x0 + .02, (y0 + y1) * .5, -.05, Vector3(.04, r.size.y, .07), alu)
	_bar("metal", face, x1 - .02, (y0 + y1) * .5, -.05, Vector3(.04, r.size.y, .07), alu)
	_bar("metal", face, mid - .02, (y0 + y1) * .5, -.065, Vector3(.035, r.size.y - .06, .025), alu)
	_bar("metal", face, mid + .02, (y0 + y1) * .5, -.04, Vector3(.035, r.size.y - .06, .025), alu)
	_bar("metal", face, mid, y0 - .012, .03, Vector3(r.size.x + .1, .03, .1), Color("#6e6f6c"))

func _small_window(face: Transform3D, r: Rect2, lit: bool) -> void:
	_reveal(face, r, .1, Color("#8a8680"))
	_flat("frost" if lit else "dim", face, r, -.08, Color("#c8ccc4") if lit else Color("#9aa09a"), 1.0, 0.0)
	var rods := int(r.size.x / .1)
	for rod: int in range(1, rods):
		_bar("metal", face, r.position.x + r.size.x * float(rod) / float(rods), r.get_center().y, .04, Vector3(.016, r.size.y + .06, .016), ALUMINIUM)
	for y: float in [r.position.y - .02, r.end.y + .02]:
		_bar("metal", face, r.get_center().x, y, .04, Vector3(r.size.x + .08, .03, .03), ALUMINIUM)

func _upper_front() -> void:
	var f := _front
	var top := _roof_y(0) - .06
	var holes: Array[Rect2] = [W_LIVE.grow(.04), W_OFF.grow(.04), W_STAIR.grow(.04), HATCH.grow(.03)]
	for piece: Rect2 in _minus(Rect2(0, 3.9, WIDE, top - 3.9), holes):
		_flat("clad", f, piece, 0.0, CLAD, .9, .7)
	_bar("slab", f, WIDE * .5, 3.92, .03, Vector3(WIDE, .1, .08), Color("#8a8680"), .8, 1.0)
	for x: float in [.03, WIDE - .03]:
		_bar("metal", f, x, (3.9 + top) * .5, .02, Vector3(.06, top - 3.9, .04), Color("#8a8070"))
	# Front room: lace, lit late; the office: curtains drawn; the stair: frosted.
	_home_window(f, W_LIVE, "curtain_lit", _px(302, 1352, 176, 176), .4, Color(1.0, .86, .68))
	_home_window(f, W_OFF, "curtain", _px(1532, 892, 166, 206), .2)
	_small_window(f, W_STAIR, true)
	# Grille on the office window, a planter rail under the front room.
	var r := W_OFF
	var x := r.position.x + .08
	while x < r.end.x:
		_bar("metal", f, x, r.get_center().y, .06, Vector3(.016, r.size.y + .1, .016), ALUMINIUM)
		x += .12
	for y: float in [r.position.y - .04, r.end.y + .04]:
		_bar("metal", f, r.get_center().x, y, .06, Vector3(r.size.x + .1, .03, .03), ALUMINIUM)
	_bar("metal", f, W_LIVE.get_center().x, W_LIVE.position.y - .06, .14, Vector3(W_LIVE.size.x, .04, .22), Color("#5a5a56"))
	for k: int in range(4):
		var px := W_LIVE.position.x + .35 + float(k) * .65
		_bar("plain", f, px, W_LIVE.position.y + .04, .14, Vector3(.3, .16, .16), Color("#a86a48") if k % 2 == 0 else Color("#d8d0c0"))
		_plant(f * Vector3(px, W_LIVE.position.y + .1, .14), .32, Color("#4a6a3a"))
	# Air-con between the windows on its bracket, the pipe run down to the canopy.
	_outdoor_unit(f, 3.88, 4.3, .2)
	_bar("metal", f, 3.88, 3.97, .2, Vector3(.9, .04, .34), Color("#3a3a38"))
	_kit.tube("plain", [f * Vector3(3.5, 4.5, .05), f * Vector3(3.42, 4.5, .05), f * Vector3(3.42, 5.6, .05), f * Vector3(4.2, 5.6, .05)], .018, Color("#d6d0c0"), 4)
	# 2050: the delivery-drone hatch, its fold-out shelf, and the fibre that feeds it.
	var h := HATCH
	_reveal(f, h, .12, Color("#6a6a66"))
	_panel("board", f, h.position.x, h.end.x, h.position.y, h.end.y, -.08, _px(1712, 652, 156, 156))
	_bar("metal", f, h.get_center().x, h.position.y - .03, .22, Vector3(h.size.x + .06, .03, .46), Color("#d8d8d4"))
	for s: float in [-1.0, 1.0]:
		_kit.beam("metal", f * Vector3(h.get_center().x + s * .3, h.position.y - .3, .02), f * Vector3(h.get_center().x + s * .3, h.position.y - .04, .42), .025, .025, Vector3.RIGHT, Color("#8a8c88"))
	_status(f, h.end.x + .06, h.end.y - .05, .02, GREEN)
	_camera(f * Vector3(h.end.x + .1, h.end.y + .2, .1))
	_fibre([f * Vector3(8.5, 3.95, .08), f * Vector3(8.5, 5.5, .08), f * Vector3(h.end.x + .05, 5.5, .08)])
	# Gutter and downpipe at the east corner.
	_kit.tube("metal", [f * Vector3(8.5, EAVE - .1, FRONT_EDGE), f * Vector3(8.5, EAVE - .5, .1), f * Vector3(8.5, 3.95, .1)], .035, Color("#6a6458"), 6)

# ---------------------------------------------------------------- side, back, roof

func _gable(face: Transform3D, length: float, to_z: Callable, tint: Color) -> void:
	var x := .0
	while x < length - .01:
		var run := minf(.6, length - x)
		var t0: float = _roof_y(to_z.call(x)) - .08
		var t1: float = _roof_y(to_z.call(x + run)) - .08
		_kit.quad("render", face * Vector3(x, EAVE, 0), face * Vector3(x, t0, 0), face * Vector3(x + run, t1, 0), face * Vector3(x + run, EAVE, 0), tint, .9, .95, .9, Vector2(x, -EAVE))
		x += run

func _side_walls() -> void:
	var e := _east
	_render_wall(e, DEEP, EAVE, GROUND, EAVE - GROUND, RENDER_TINT, [E_STAIR.grow(.04), E_WIN.grow(.04)])
	_gable(e, DEEP, func(x: float) -> float: return -x, RENDER_TINT * .97)
	_small_window(e, E_STAIR, true)
	_home_window(e, E_WIN, "curtain", _px(302, 1352, 176, 176), .3, Color(.8, .8, .8))
	_small_window(e, E_GABLE, false)
	_panel("decal", e, .5, 6.4, 5.72, 6.55, .012, _px(500, 1350, 1300, 180))
	_outdoor_unit(e, 8.9, 4.05, .2)
	_bar("metal", e, 8.9, 3.72, .2, Vector3(.9, .04, .34), Color("#3a3a38"))
	_kit.tube("plain", [e * Vector3(8.5, 4.3, .03), e * Vector3(8.2, 4.3, .03), e * Vector3(8.2, 4.8, .03)], .016, Color("#d6d0c0"), 4)
	_bar("metal", e, 3.0, 1.3, .08, Vector3(.3, .4, .14), Color("#c8c6b8"))
	_kit.tube("metal", [e * Vector3(3.0, 1.1, .08), e * Vector3(3.0, .3, .05)], .014, Color("#b4a24a"), 5)
	_bar("metal", e, 5.5, 2.4, .1, Vector3(.3, .3, .2), Color("#a8a8a0"))
	_kit.tube("metal", [e * Vector3(DEEP - .1, EAVE - .1, .08), e * Vector3(DEEP - .1, .1, .08)], .04, Color("#6a6e6a"), 7)
	_fibre([e * Vector3(.1, 3.9, .06), e * Vector3(DEEP - .2, 3.9, .06)])
	var w := _west
	_render_wall(w, DEEP, EAVE, GROUND, EAVE - GROUND, RENDER_TINT * .95, [])
	_gable(w, DEEP, func(x: float) -> float: return x - DEEP, RENDER_TINT * .92)
	_kit.tube("metal", [w * Vector3(.15, EAVE - .1, .08), w * Vector3(.15, .1, .08)], .04, Color("#6a6e6a"), 7)
	var b := _back
	var btop := _roof_y(-DEEP) - .06
	_render_wall(b, WIDE, btop, GROUND, btop - GROUND, RENDER_TINT * .93, [B_WIN.grow(.04), B_DOOR])
	_window(b, B_WIN, .63, true)
	_flat("metal", b, B_DOOR, .01, Color("#7a7c78"), .8, .5)

func _roof() -> void:
	var h := WIDE * .5
	var x0 := -h - .22
	var x1 := h + .22
	var tin := Color("#7a5a4c")
	_kit.quad("tin", Vector3(x0, EAVE, FRONT_EDGE), Vector3(x0, RIDGE, RIDGE_Z), Vector3(x1, RIDGE, RIDGE_Z), Vector3(x1, EAVE, FRONT_EDGE), tin, .85, 1.0, .5)
	_kit.quad("plain", Vector3(x1, EAVE - .03, FRONT_EDGE), Vector3(x1, RIDGE - .03, RIDGE_Z), Vector3(x0, RIDGE - .03, RIDGE_Z), Vector3(x0, EAVE - .03, FRONT_EDGE), Color("#4a3e36"), .6, .6)
	_kit.quad("tin", Vector3(x1, EAVE, BACK_EDGE), Vector3(x1, RIDGE, RIDGE_Z), Vector3(x0, RIDGE, RIDGE_Z), Vector3(x0, EAVE, BACK_EDGE), tin * .92, .85, 1.0, .5)
	_kit.quad("plain", Vector3(x0, EAVE - .03, BACK_EDGE), Vector3(x0, RIDGE - .03, RIDGE_Z), Vector3(x1, RIDGE - .03, RIDGE_Z), Vector3(x1, EAVE - .03, BACK_EDGE), Color("#4a3e36"), .6, .6)
	# Ridge flashing, barge boards, the front gutter.
	_kit.beam("metal", Vector3(x0, RIDGE + .02, RIDGE_Z), Vector3(x1, RIDGE + .02, RIDGE_Z), .3, .06, Vector3.UP, tin * .8)
	for x: float in [x0, x1]:
		_kit.beam("metal", Vector3(x, EAVE - .05, FRONT_EDGE), Vector3(x, RIDGE - .02, RIDGE_Z), .04, .2, Vector3.RIGHT if x > 0 else Vector3.LEFT, Color("#5a4a40"))
		_kit.beam("metal", Vector3(x, EAVE - .05, BACK_EDGE), Vector3(x, RIDGE - .02, RIDGE_Z), .04, .2, Vector3.RIGHT if x > 0 else Vector3.LEFT, Color("#5a4a40"))
	_kit.tube("metal", [Vector3(x0, EAVE - .1, FRONT_EDGE + .08), Vector3(x1, EAVE - .1, FRONT_EDGE + .08)], .055, Color("#6a6458"), 6)
	_kit.tube("metal", [Vector3(x0, EAVE - .1, BACK_EDGE - .08), Vector3(x1, EAVE - .1, BACK_EDGE - .08)], .055, Color("#6a6458"), 6)
	# The 2050 layer up top: two modules on the front slope, the old aerial with a sensor.
	var slope := atan2(RIDGE - EAVE, FRONT_EDGE - RIDGE_Z)
	for k: int in range(2):
		var z := -2.6
		var x := 1.4 + float(k) * 1.15
		_solar_module(Transform3D(Basis(Vector3.RIGHT, -PI * .5 + slope), Vector3(x, _roof_y(z) + .1, z)), 1.05, 1.7)
	_kit.tube("metal", [Vector3(-2.0, _roof_y(-6.5), -6.5), Vector3(-2.0, RIDGE + 1.6, -6.5)], .018, ALUMINIUM, 5)
	for y: float in [RIDGE + 1.0, RIDGE + 1.35]:
		_kit.tube("metal", [Vector3(-2.5, y, -6.5), Vector3(-1.5, y, -6.5)], .006, ALUMINIUM, 3)
	_kit.lathe("plain", Vector3(-2.0, RIDGE + 1.6, -6.5), [Vector2(.05, 0), Vector2(.06, .04), Vector2(.02, .1)], Color("#d6d6d0"), 8)
	_status(Transform3D(Basis.IDENTITY, Vector3(-2.0, RIDGE + 1.66, -6.48)), 0, 0, 0, GREEN)
