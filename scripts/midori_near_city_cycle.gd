extends "res://scripts/midori_near_city_handmade.gd"
## 小鳩サイクル: a neighbourhood bicycle shop of the 1970s, three storeys, the family living above.
## By day the shutter is rolled up and the stock stands nose-in on the pavement with its tags;
## after closing the bikes are wheeled inside, the shutter comes half down and the owner works on
## under the tubes until the last puncture is done. The dove on the fascia has faded to chalk.
const ATLAS := "res://assets/shinrai/near_city/cycle_atlas.png"
const WIDE := 6.9
const DEEP := 7.6
const GROUND := 3.7
const THIRD := 6.5
const TOP := 9.75
const DECK := 9.35
const OPENING := Rect2(.95, 0, 4.6, 2.6)
const HOUSE := Rect2(5.9, 0, .85, 2.12)
const RX0 := .15
const RX1 := 5.62
const ROOM_TOP := 2.95
const ROOM_DEEP := 5.4
const NEAR := -.2
const BACK_DOOR := Rect2(2.35, 0, .8, 2.0)
const SLIDE := Rect2(.55, 3.88, 2.8, 1.98)
const KITCHEN := Rect2(3.85, 4.55, 1.3, 1.15)
const LOO := Rect2(6.05, 4.75, .5, .6)
const W3A := Rect2(.7, 7.0, 1.8, 1.25)
const W3B := Rect2(3.4, 7.0, 1.8, 1.25)
const W3C := Rect2(6.05, 7.45, .5, .6)
const E_STAIR2 := Rect2(.6, 4.6, .7, .6)
const E_STAIR3 := Rect2(.6, 7.4, .7, .6)
const E_ROOM2 := Rect2(4.3, 4.5, 1.1, 1.0)
const E_ROOM3 := Rect2(4.3, 7.2, 1.1, 1.0)
const B_DOOR := Rect2(4.6, 0, .85, 2.0)
const B_WIN2 := Rect2(1.0, 4.6, 1.4, 1.0)
const B_WIN3 := Rect2(1.0, 7.3, 1.4, 1.0)
const TILE_TINT := Color("#d8dccb")
const RENDER_TINT := Color("#d6d0c2")
const WARM := Color(1.0, .92, .78)
const SPOKE_CODE := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Cut-outs (spokes, basket wire): the atlas alpha draws the wire, the rest is air.
uniform float night = 0.0;
uniform float glow = 0.0;
uniform float day_glow = 0.0;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
void fragment(){
	vec4 face = texture(atlas, UV);
	vec3 color = face.rgb * COLOR.rgb;
	ALBEDO = color * mix(vec3(1.0), vec3(0.42, 0.34, 0.27), night);
	ROUGHNESS = 0.35;
	METALLIC = 0.5;
	EMISSION = color * (mix(vec3(0.09, 0.07, 0.04), vec3(0.12, 0.09, 0.07), night) + mix(day_glow, glow, night));
	ALPHA = face.a;
}
"""

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _day: Node3D
var _night: Node3D
var _bx := Transform3D.IDENTITY
var _bs := 1.0

func _ready() -> void:
	_rng.seed = 1974
	_build_looks()
	_ground_front()
	_shop_room()
	_counter()
	_back_room()
	_workbench()
	_repair_corner()
	_stock_inside()
	_fixtures()
	_shutter_box()
	_awning()
	_drone()
	_fascia()
	_side_sign()
	_locker()
	_house_door()
	_pump_post()
	_upper_front()
	_balcony()
	_side_walls()
	_roof()
	var unshadowed: Array[String] = ["front", "decal", "lamp", "led", "signlit", "screen", "spoke", "spoke_in", "room", "floor", "display", "ply", "plaster_in", "steel", "cloth", "frost", "curtain", "curtain_lit", "dim", "homelit"]
	_kit.commit(self, _looks, unshadowed)
	# Two sets of things that move at closing time: what stands outside by day, what comes in at night.
	_day = Node3D.new()
	_day.name = "DayStock"
	add_child(_day)
	_kit = Kit.new()
	_pavement_stock()
	_kit.commit(_day, _looks, unshadowed)
	_night = Node3D.new()
	_night.name = "AfterHours"
	_night.visible = false
	add_child(_night)
	_kit = Kit.new()
	_after_hours()
	_kit.commit(_night, _looks, unshadowed)
	_kit = null
	_omni("CycleShop", _front * Vector3(2.9, 2.5, -2.3), Color(1.0, .86, .66), .6, 5.5)
	_omni("CycleSpill", _front * Vector3(3.2, .55, -.45), Color(1.0, .84, .62), .45, 3.4)

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

func _lit_tex(name: String, texture: String, tile: float, rough: float, glow: float, day: float) -> void:
	var look := _look(texture, tile, rough)
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	look.set_shader_parameter("chroma", .45)
	_looks[name] = look

func _decal_look(name: String, glow: float, day: float) -> void:
	var look := ShaderMaterial.new()
	look.shader = DECAL_SHADER
	look.set_shader_parameter("atlas", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
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
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .45)
	_looks.tile = _look("square_tiled_wall", 1.0, .7)
	_looks.tile.set_shader_parameter("chroma", .2)
	_looks.pier = _look("rectangular_facade_tiles", 1.2, .8)
	_looks.pier.set_shader_parameter("chroma", .5)
	_looks.shutter = _look("painted_metal_shutter", 1.2, .6, .2)
	_looks.shutter.set_shader_parameter("chroma", .6)
	_looks.rust = _look("rusty_painted_metal", 1.2, .8, .25)
	_looks.rust.set_shader_parameter("chroma", .7)
	_looks.corr = _look("worn_corrugated_iron", 1.6, .7, .3)
	_looks.corr.set_shader_parameter("chroma", .6)
	_looks.slab = _look("precast_concrete_wall", 1.6, .9)
	_looks.slab.set_shader_parameter("chroma", .3)
	_looks.canvas = _look("", 1.0, .95)
	_lit_tex("ply", "japanese_cedar_planks", 1.0, .8, .26, .08)
	_lit_tex("plaster_in", "white_stucco", 2.5, .9, .28, .09)
	_lit_look("room", .6, .28, .1)
	_lit_look("steel", .35, .24, .08, .55)
	_lit_look("frost", .5, .22, .05)
	_lit_look("dim", .8, .035, .02)
	_lit_look("homelit", .8, .3, .04)
	_atlas_look("fascia", .5, .05, .02)
	_atlas_look("signlit", .4, 1.0, .06)
	_atlas_look("board", .6, .03, .02)
	_atlas_look("display", .5, .3, .1)
	_atlas_look("floor", .55, .26, .1)
	_atlas_look("screen", .3, .9, .35)
	_atlas_look("curtain", .9, .02, .02)
	_atlas_look("curtain_lit", .9, .5, .04)
	_atlas_look("cloth", .9, .26, .08)
	_decal_look("decal", .0, .0)
	var cut := Shader.new()
	cut.code = SPOKE_CODE
	_cut_look("spoke", cut, 0.0, 0.0)
	_cut_look("spoke_in", cut, .26, .08)

# ---------------------------------------------------------------- atlas cells

func _px(x: float, y: float, w: float, h: float) -> Rect2:
	return _cell(x, y, w, h)

func _tag_cell(i: int) -> Rect2:
	return _cell(624.0 + float(i % 4) * 160.0, 804.0 + float(i / 4) * 110.0, 152, 102)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _flat(part: String, face: Transform3D, area: Rect2, z: float, tint: Color, low := .9, streak := .6) -> void:
	_kit.quad(part, face * Vector3(area.position.x, area.position.y, z), face * Vector3(area.position.x, area.end.y, z), face * Vector3(area.end.x, area.end.y, z), face * Vector3(area.end.x, area.position.y, z), tint, low, 1.0, streak, Vector2(area.position.x, -area.position.y))

func _west_panel(part: String, x: float, z0: float, z1: float, y0: float, y1: float, rect: Rect2) -> void:
	# On a wall facing +x (the shop's west wall): z0 is the nearer edge.
	var f := _front
	_kit.atlas(part, f * Vector3(x, y0, z0), f * Vector3(x, y1, z0), f * Vector3(x, y1, z1), f * Vector3(x, y0, z1), rect)

func _east_panel(part: String, x: float, z0: float, z1: float, y0: float, y1: float, rect: Rect2) -> void:
	# On a wall facing -x: z0 is the deeper edge.
	var f := _front
	_kit.atlas(part, f * Vector3(x, y0, z0), f * Vector3(x, y1, z0), f * Vector3(x, y1, z1), f * Vector3(x, y0, z1), rect)

# ---------------------------------------------------------------- bicycles

func _q(x: float, y: float, z: float) -> Vector3:
	return _bx * (Vector3(x, y, z) * _bs)

func _bt(part: String, pts: Array, radius: float, tint: Color, sides := 4) -> void:
	var points: Array[Vector3] = []
	for p: Vector3 in pts:
		points.append(_q(p.x, p.y, p.z))
	_kit.tube(part, points, radius * _bs, tint, sides)

func _bike_xf(at: Vector3, forward: Vector3) -> Transform3D:
	var f := forward.normalized()
	return Transform3D(Basis(f, Vector3.UP, f.cross(Vector3.UP)), at)

func _wheel(cx: float, r: float, tr: float, paint: String, metal: String, cut: String, rim_tint: Color) -> void:
	var fwd := _bx.basis.x
	var up := _bx.basis.y
	var side := _bx.basis.z
	var c := _q(cx, r, 0)
	var big := r * _bs
	var tyre: Array[Vector3] = []
	var rim: Array[Vector3] = []
	for i: int in range(17):
		var a := TAU * float(i) / 16.0
		var dir := fwd * cos(a) + up * sin(a)
		tyre.append(c + dir * (big - tr))
		rim.append(c + dir * (big - tr * 2.0 - .006))
	_kit.tube(paint, tyre, tr, Color("#17181a"), 5)
	_kit.tube(metal, rim, .009, rim_tint, 3)
	_kit.disc(cut, c, fwd, up, big - tr * 2.0 - .012, Color.WHITE, _px(1644, 264, 392, 392))
	_kit.tube(metal, [c - side * .05, c + side * .05], .02, Color("#8a8c90"), 6)

func _fender(cx: float, r: float, a0: float, a1: float, part: String, tint: Color) -> void:
	var fwd := _bx.basis.x
	var up := _bx.basis.y
	var side := _bx.basis.z * .024 * _bs
	var c := _q(cx, r, 0)
	var big := (r + .035) * _bs
	var before := Vector3.ZERO
	for i: int in range(8):
		var a := lerpf(a0, a1, float(i) / 7.0)
		var p := c + (fwd * cos(a) + up * sin(a)) * big
		if i > 0:
			_kit.quad(part, before - side, before + side, p + side, p - side, tint, .8, 1.0)
			_kit.quad(part, p - side, p + side, before + side, before - side, tint * .7, .7, .8)
		before = p

func _basket(o: Vector3, size: Vector3, cut: String, metal: String, tint: Color) -> void:
	var x0 := o.x - size.x * .5
	var x1 := o.x + size.x * .5
	var z0 := -size.z * .5
	var z1 := size.z * .5
	var y0 := o.y
	var y1 := o.y + size.y
	var cell := _px(1640, 680, 200, 200)
	_kit.atlas(cut, _q(x1, y0, z0), _q(x1, y1, z0), _q(x1, y1, z1), _q(x1, y0, z1), cell, tint)
	_kit.atlas(cut, _q(x0, y0, z1), _q(x0, y1, z1), _q(x0, y1, z0), _q(x0, y0, z0), cell, tint)
	_kit.atlas(cut, _q(x0, y0, z0), _q(x0, y1, z0), _q(x1, y1, z0), _q(x1, y0, z0), cell, tint)
	_kit.atlas(cut, _q(x1, y0, z1), _q(x1, y1, z1), _q(x0, y1, z1), _q(x0, y0, z1), cell, tint)
	_kit.atlas(cut, _q(x0, y0, z0), _q(x0, y0, z1), _q(x1, y0, z1), _q(x1, y0, z0), cell, tint)
	_bt(metal, [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], .008, tint, 3)

func _bike(xf: Transform3D, kind: int, tint: Color, paint: String, metal: String, cut: String, tag := -1) -> void:
	# kind: 0 mamachari, 1 e-assist, 2 child's bike, 3 cross bike, 4 e-assist with a child seat.
	# Local: +x forward, +y up, +z the drive side. One builder for every bike in the shop.
	_bx = xf
	_bs = .66 if kind == 2 else 1.0
	var sport := kind == 3
	var assist := kind == 1 or kind == 4
	var r := .3 if assist else (.34 if sport else .33)
	var black := Color("#18191b")
	var chrome := Color("#a4a8ac")
	_wheel(.55, r, .016 if sport else .021, paint, metal, cut, chrome if not sport else Color("#2a2c2e"))
	_wheel(-.55, r, .016 if sport else .021, paint, metal, cut, chrome if not sport else Color("#2a2c2e"))
	if not sport:
		_fender(.55, r, .3, 2.45, metal, tint if kind == 2 else chrome)
		_fender(-.55, r, .55, 3.05, metal, tint if kind == 2 else chrome)
	var bb := Vector3(-.06, .3, 0)
	var head_lo := Vector3(.4, .7, 0)
	var head_hi := Vector3(.35, .86, 0)
	var seat_top := Vector3(-.22, .78, 0)
	_bt(paint, [head_lo, head_hi], .024, tint, 6)
	if sport:
		_bt(paint, [head_hi + Vector3(0, -.03, 0), seat_top + Vector3(0, .02, 0)], .017, tint, 5)
		_bt(paint, [head_lo, bb], .021, tint, 5)
	else:
		_bt(paint, [head_lo + Vector3(-.01, .06, 0), Vector3(.27, .5, 0), Vector3(.1, .32, 0), bb], .027 if assist else .022, tint, 5)
	_bt(paint, [bb, seat_top], .018, tint, 5)
	for s: float in [-1.0, 1.0]:
		_bt(paint, [bb + Vector3(0, 0, s * .03), Vector3(-.55, r, s * .06)], .011, tint, 4)
		_bt(paint, [seat_top + Vector3(0, -.03, s * .02), Vector3(-.55, r, s * .06)], .01, tint, 4)
		_bt(paint, [head_lo + Vector3(0, 0, s * .03), Vector3(.48, .5, s * .05), Vector3(.55, r, s * .05)], .012, tint, 4)
	# Seat post and saddle.
	var post := seat_top + Vector3(-.035, .1 if kind != 2 else .06, 0)
	_bt(metal, [seat_top, post], .012, chrome, 4)
	var wide := .15 if not sport else .1
	_kit.block(paint, Transform3D(_bx.basis, _q(post.x - .05, post.y + .04, 0)), Vector3(.15, .055, wide) * _bs, black)
	_kit.block(paint, Transform3D(_bx.basis * Basis(Vector3(0, 0, 1), -.08), _q(post.x + .07, post.y + .035, 0)), Vector3(.13, .04, .06) * _bs, black)
	_kit.block(paint, Transform3D(_bx.basis, _q(post.x - .05, post.y + .068, 0)), Vector3(.13, .012, wide - .02) * _bs, Color("#2a2b2e"))
	_bt(metal, [Vector3(post.x + .04, post.y, -.04), Vector3(post.x - .08, post.y, -.04)], .006, chrome, 3)
	_bt(metal, [Vector3(post.x + .04, post.y, .04), Vector3(post.x - .08, post.y, .04)], .006, chrome, 3)
	# Stem and bars: swept-back city bars, or a straight flat bar on the cross bike.
	var stem := Vector3(.33, 1.0, 0)
	_bt(metal, [head_hi, stem], .014, chrome, 4)
	if sport:
		_bt(metal, [Vector3(.35, .99, -.29), Vector3(.35, .99, .29)], .011, black, 4)
		for s: float in [-1.0, 1.0]:
			_bt(paint, [Vector3(.35, .99, s * .2), Vector3(.35, .99, s * .3)], .016, black, 5)
	else:
		_bt(metal, [Vector3(.17, 1.03, -.29), Vector3(.28, 1.02, -.24), Vector3(.34, 1.0, -.1), Vector3(.34, 1.0, .1), Vector3(.28, 1.02, .24), Vector3(.17, 1.03, .29)], .011, chrome, 4)
		for s: float in [-1.0, 1.0]:
			_bt(paint, [Vector3(.2, 1.03, s * .285), Vector3(.09, 1.035, s * .29)], .017, black, 5)
			_bt(metal, [Vector3(.27, 1.02, s * .24), Vector3(.2, .99, s * .27)], .005, black, 3)
	# Front basket on its stays; the dynamo lamp under it.
	if not sport:
		var wire := chrome if kind != 4 else black
		if kind == 2:
			wire = Color("#f2f0ea")
		_basket(Vector3(.64, .8, 0), Vector3(.3, .25, .36), cut, metal, wire)
		for s: float in [-1.0, 1.0]:
			_bt(metal, [Vector3(.55, r, s * .05), Vector3(.6, .8, s * .12)], .006, chrome, 3)
		_kit.block(paint, Transform3D(_bx.basis, _q(.5, .68, 0)), Vector3(.07, .06, .07) * _bs, Color("#d8d6cc"))
		_kit.disc(paint, _q(.54, .68, 0), -_bx.basis.z, _bx.basis.y, .026 * _bs, Color("#f2e8c8"))
	# Rear carrier on the city bikes.
	if kind == 0 or assist:
		for s: float in [-1.0, 1.0]:
			_bt(metal, [Vector3(-.24, .76, s * .08), Vector3(-.8, .76, s * .08), Vector3(-.55, r, s * .07)], .008, chrome, 3)
		for x: float in [-.4, -.6, -.78]:
			_bt(metal, [Vector3(x, .76, -.08), Vector3(x, .76, .08)], .007, chrome, 3)
		_kit.disc(paint, _q(-.82, .7, 0), _bx.basis.z, _bx.basis.y, .03 * _bs, Color("#b01810"))
	if kind == 4:
		# Rear child seat: a moulded shell in charcoal, a lighter cushion, the harness and a headrest.
		var shell := Color("#3e3c3a")
		_kit.block(paint, Transform3D(_bx.basis, _q(-.55, .81, 0)), Vector3(.3, .05, .28), shell)
		_kit.block(paint, Transform3D(_bx.basis * Basis(Vector3(0, 0, 1), .18), _q(-.7, .98, 0)), Vector3(.045, .32, .27), shell)
		_kit.block(paint, Transform3D(_bx.basis * Basis(Vector3(0, 0, 1), .18), _q(-.735, 1.2, 0)), Vector3(.05, .12, .2), Color("#8a8278"))
		for s: float in [-1.0, 1.0]:
			_kit.block(paint, Transform3D(_bx.basis, _q(-.6, .88, s * .135)), Vector3(.26, .12, .02), shell)
			_bt(paint, [Vector3(-.67, 1.06, s * .06), Vector3(-.57, .86, s * .05)], .006, Color("#c8b040"), 3)
		_kit.block(paint, Transform3D(_bx.basis, _q(-.56, .845, 0)), Vector3(.2, .025, .22), Color("#8a8278"))
	if assist:
		var tilt := Basis(Vector3(0, 0, 1), .31)
		_kit.block(paint, Transform3D(_bx.basis * tilt, _q(-.25, .53, 0)), Vector3(.08, .36, .09), Color("#2a2c30"))
		_kit.block(paint, Transform3D(_bx.basis * tilt, _q(-.29, .72, 0)), Vector3(.085, .03, .095), tint)
		_kit.block(paint, Transform3D(_bx.basis, _q(-.02, .26, 0)), Vector3(.17, .14, .13), Color("#3a3c40"))
	# Drive: chain guard, chainring, cranks, pedals.
	if not sport:
		_kit.block(paint, Transform3D(_bx.basis, _q(-.3, .31, .078)), Vector3(.56, .11, .012) * _bs, tint)
	_kit.disc(paint, _q(-.06, .3, .07), _bx.basis.x, _bx.basis.y, .09 * _bs, Color("#3a3c3e"))
	_bt(metal, [bb + Vector3(0, 0, .085), Vector3(.03, .14, .085)], .01, chrome, 4)
	_bt(metal, [bb + Vector3(0, 0, -.085), Vector3(-.15, .46, -.085)], .01, chrome, 4)
	_kit.block(paint, Transform3D(_bx.basis, _q(.03, .14, .13)), Vector3(.1, .025, .08) * _bs, black)
	_kit.block(paint, Transform3D(_bx.basis, _q(-.15, .46, -.13)), Vector3(.1, .025, .08) * _bs, black)
	# Stand: the double stand of a city bike, a side stand on the others.
	if kind == 0 or assist:
		for s: float in [-1.0, 1.0]:
			_bt(metal, [Vector3(-.55, r, s * .07), Vector3(-.68, 0.0, s * .13)], .009, chrome, 3)
		_bt(metal, [Vector3(-.68, .0, -.13), Vector3(-.68, .0, .13)], .009, chrome, 3)
	else:
		_bt(metal, [Vector3(-.2, .28, -.05), Vector3(-.34, 0.0, -.2)], .009, chrome, 3)
	# Swing tag under the saddle, and the yellow 防犯登録 sticker on the seat tube.
	if tag >= 0:
		var tx := post.x - .14
		_kit.atlas("board", _q(tx, .66, -.065), _q(tx, .745, -.065), _q(tx, .745, .065), _q(tx, .66, .065), _tag_cell(tag))
		_bt(metal, [Vector3(tx, .745, 0), Vector3(post.x - .1, post.y + .01, 0)], .002, Color("#e8e0c8"), 3)
		_kit.atlas("board", _q(-.2, .48, -.03), _q(-.2, .53, -.03), _q(-.2, .53, .03), _q(-.2, .48, .03), _px(1280, 700, 120, 60))

# ---------------------------------------------------------------- ground floor front

func _ground_front() -> void:
	var f := _front
	for piece: Rect2 in _minus(Rect2(0, .14, WIDE, 3.05 - .14), [OPENING, HOUSE]):
		_flat("pier", f, piece, 0.0, Color("#8c7c6c"), .85, .5)
	for piece: Rect2 in _minus(Rect2(0, 0, WIDE, .14), [OPENING, HOUSE]):
		_bar("slab", f, piece.get_center().x, .07, .015, Vector3(piece.size.x, .14, .04), Color("#6e6a64"))
	# The opening's reveals and soffit, steel angle on the arrises.
	var x0 := OPENING.position.x
	var x1 := OPENING.end.x
	var y1 := OPENING.end.y
	var pier := Color("#7a6c5e")
	_kit.quad("pier", f * Vector3(x0, 0, 0), f * Vector3(x0, y1, 0), f * Vector3(x0, y1, NEAR), f * Vector3(x0, 0, NEAR), pier, .7, .8)
	_kit.quad("pier", f * Vector3(x1, 0, NEAR), f * Vector3(x1, y1, NEAR), f * Vector3(x1, y1, 0), f * Vector3(x1, 0, 0), pier, .7, .8)
	_kit.quad("plain", f * Vector3(x0, y1, NEAR), f * Vector3(x0, y1, 0), f * Vector3(x1, y1, 0), f * Vector3(x1, y1, NEAR), Color("#5a5650"), .6, .6)
	# Shutter guides down both sides, the threshold rail.
	for x: float in [x0 + .035, x1 - .035]:
		_bar("metal", f, x, y1 * .5, .03, Vector3(.07, y1, .07), Color("#6a6e6a"))
		_bar("plain", f, x, y1 * .5, .067, Vector3(.025, y1, .004), Color("#2a2c2c"))
	_bar("metal", f, OPENING.get_center().x, .008, -.03, Vector3(OPENING.size.x, .016, .12), Color("#7a7670"))
	# Hours card on the pier above the locker, camera and fibre down the west edge.
	_bar("plain", f, .47, 2.06, .012, Vector3(.34, .45, .01), Color("#d8d4cc"))
	_panel("display", f, .32, .62, 1.85, 2.26, .02, _px(1400, 700, 220, 300))
	_camera(f * Vector3(.45, 2.95, .2))
	_bar("metal", f, .45, 2.96, .08, Vector3(.06, .06, .16), Color("#d5d6d2"))
	_fibre([f * Vector3(.05, 9.6, .1), f * Vector3(.05, 3.0, .1), f * Vector3(.05, .3, .1)])

func _shutter_box() -> void:
	# The roller shutter is wound up into its box; by day only the box and the bottom bar show.
	var f := _front
	var cx := OPENING.get_center().x
	_bar("shutter", f, cx, 2.76, .1, Vector3(OPENING.size.x + .12, .32, .2), Color("#8a948a"), .8, 1.0)
	_bar("metal", f, cx, 2.6, .1, Vector3(OPENING.size.x + .1, .03, .2), Color("#4a4e4a"))
	_bar("metal", f, cx, 2.63, .05, Vector3(OPENING.size.x - .1, .05, .05), Color("#5a5e5a"))
	for x: float in [OPENING.position.x + .4, OPENING.end.x - .4]:
		_bar("metal", f, x, 2.58, .07, Vector3(.08, .03, .03), Color("#3a3c3a"))

# ---------------------------------------------------------------- the shop

func _shop_room() -> void:
	var f := _front
	var deep := -ROOM_DEEP
	# Concrete floor in four patches of the atlas, so the stains do not repeat in one big smear.
	var xs: Array[float] = [RX0, 2.9, RX1]
	var zs: Array[float] = [NEAR, -2.8, deep]
	for i: int in range(2):
		for j: int in range(2):
			_kit.atlas("floor", f * Vector3(xs[i], .02, zs[j]), f * Vector3(xs[i], .02, zs[j + 1]), f * Vector3(xs[i + 1], .02, zs[j + 1]), f * Vector3(xs[i + 1], .02, zs[j]), _px(1000.0 + float(i) * 10.0, 1040.0 + float(j) * 10.0, 410, 410))
	# Ceiling boards, painted, with battens and a run of conduit.
	_kit.quad("room", f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, ROOM_TOP, NEAR), f * Vector3(RX1, ROOM_TOP, NEAR), f * Vector3(RX1, ROOM_TOP, deep), Color("#c8c2b0"), .7, .7)
	var x := RX0 + .45
	while x < RX1:
		_bar("room", f, x, ROOM_TOP - .01, (NEAR + deep) * .5, Vector3(.03, .02, -deep + NEAR), Color("#a8a290"))
		x += .9
	_kit.tube("steel", [f * Vector3(RX0 + .1, ROOM_TOP - .03, -1.0), f * Vector3(RX1 - .1, ROOM_TOP - .03, -1.0)], .012, Color("#d8d6d0"), 4)
	# Plywood to waist height, plaster over, on all three walls.
	var rail := 1.15
	var ply := Color("#c8a478")
	var wall := Color("#f0ead8")
	_kit.quad("ply", f * Vector3(RX0, 0, NEAR), f * Vector3(RX0, rail, NEAR), f * Vector3(RX0, rail, deep), f * Vector3(RX0, 0, deep), ply, .7, 1.0)
	_kit.quad("plaster_in", f * Vector3(RX0, rail, NEAR), f * Vector3(RX0, ROOM_TOP, NEAR), f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, rail, deep), wall, 1.0, .8)
	_kit.quad("ply", f * Vector3(RX1, 0, deep), f * Vector3(RX1, rail, deep), f * Vector3(RX1, rail, NEAR), f * Vector3(RX1, 0, NEAR), ply, .7, 1.0)
	_kit.quad("plaster_in", f * Vector3(RX1, rail, deep), f * Vector3(RX1, ROOM_TOP, deep), f * Vector3(RX1, ROOM_TOP, NEAR), f * Vector3(RX1, rail, NEAR), wall, 1.0, .8)
	for piece: Rect2 in _minus(Rect2(RX0, 0, RX1 - RX0, ROOM_TOP), [BACK_DOOR]):
		var lower := Rect2(piece.position.x, piece.position.y, piece.size.x, minf(rail, piece.end.y) - piece.position.y)
		if lower.size.y > .01:
			_flat("ply", f, lower, deep, ply, .7, 0.0)
		var upper := Rect2(piece.position.x, maxf(rail, piece.position.y), piece.size.x, piece.end.y - maxf(rail, piece.position.y))
		if upper.size.y > .01:
			_flat("plaster_in", f, upper, deep, wall, 1.0, 0.0)
	for at: float in [RX0 + .012, RX1 - .012]:
		_bar("room", f, at, rail, (NEAR + deep) * .5, Vector3(.024, .04, -deep + NEAR), Color("#7a5a3a"))
	_bar("room", f, (RX0 + RX1) * .5, rail, deep + .012, Vector3(RX1 - RX0, .04, .024), Color("#7a5a3a"))
	# Inside face of the front wall, seen through the opening only at its edges.
	_kit.quad("room", f * Vector3(RX1, OPENING.end.y, NEAR), f * Vector3(RX1, ROOM_TOP, NEAR), f * Vector3(RX0, ROOM_TOP, NEAR), f * Vector3(RX0, OPENING.end.y, NEAR), Color("#8a8070"))
	# Posters on the west wall, where customers wait: insurance, registration, the makers.
	var w := RX0 + .008
	_west_panel("display", w, -.45, -.87, 1.42, 2.0, _px(1000, 260, 300, 420))
	_west_panel("display", w, -.97, -1.39, 1.42, 2.0, _px(1320, 260, 300, 420))
	_west_panel("display", w, -1.6, -2.24, 1.42, 2.02, _px(860, 1760, 300, 280))
	_west_panel("display", w, -2.45, -3.09, 1.42, 2.02, _px(1180, 1760, 300, 280))
	# Clock over the back doorway.
	var clock := f * Vector3(BACK_DOOR.get_center().x, 2.4, deep + .02)
	_kit.disc("display", clock, Vector3.RIGHT, Vector3.UP, .15, Color.WHITE, _px(1762, 1302, 156, 156))

func _counter() -> void:
	# The till counter by the back wall: register, payment pad, a mug, receipts on a spike.
	var f := _front
	var x0 := .45
	var x1 := 2.05
	var z := -4.45
	_bar("ply", f, (x0 + x1) * .5, .45, z, Vector3(x1 - x0, .9, .5), Color("#b89068"), .7, 1.0)
	_bar("room", f, (x0 + x1) * .5, .92, z, Vector3(x1 - x0 + .06, .04, .58), Color("#6a5038"))
	_bar("room", f, x0 + .45, 1.02, z - .05, Vector3(.36, .16, .3), Color("#3a3c40"))
	_bar("room", f, x0 + .45, 1.12, z - .14, Vector3(.3, .08, .06), Color("#2a2c30"))
	_kit.block("led", Transform3D(Basis(Vector3.RIGHT, -.4), f * Vector3(x0 + .45, 1.14, z - .1)), Vector3(.2, .07, .006), Color(.12, .22, .25))
	_kit.block("room", Transform3D(Basis(Vector3.RIGHT, -.5), f * Vector3(x0 + .95, 1.0, z + .12)), Vector3(.12, .14, .02), Color("#1c1e20"))
	_kit.block("led", Transform3D(Basis(Vector3.RIGHT, -.5), f * Vector3(x0 + .95, 1.002, z + .132)), Vector3(.09, .1, .002), CYAN * .4)
	_kit.lathe("room", f * Vector3(x0 + 1.25, .94, z), [Vector2(.04, 0), Vector2(.04, .1)], Color("#e8e2d4"), 8)
	_kit.tube("steel", [f * Vector3(x1 - .15, .94, z - .1), f * Vector3(x1 - .15, 1.08, z - .1)], .004, Color("#c0c0c0"), 3)
	_bar("room", f, x1 - .15, 1.0, z - .1, Vector3(.08, .06, .002), Color("#f6f2e6"))
	# Shelves behind: boxes of tubes and tyres end-on, labels out.
	var sz := -ROOM_DEEP + .17
	for level: int in range(3):
		var y := 1.25 + float(level) * .42
		_bar("room", f, (x0 + x1) * .5 - .1, y, sz, Vector3(1.8, .025, .32), Color("#8a6a48"))
		var x := x0 - .2
		var k := level * 3
		while x < x1 - .1:
			var bw := _rng.randf_range(.16, .24)
			var bh := _rng.randf_range(.18, .3)
			_bar("room", f, x + bw * .5, y + .013 + bh * .5, sz + .01, Vector3(bw, bh, .26), Color("#c8b898"))
			_panel("display", f, x + .01, x + bw - .01, y + .03, y + .03 + bh * .5, sz + .141, _px(1890, 1760.0 + float(k % 7) * 40.0, 150, 38))
			k += 1
			x += bw + .02
	for x: float in [x0 - .18, x1 - .02]:
		_bar("room", f, x, 1.45, sz, Vector3(.025, 1.3, .32), Color("#7a5a3a"))
	_panel("display", f, x1 + .02, x1 + .2, 1.6, 1.87, -ROOM_DEEP + .012, _px(1760, 1040, 160, 240))
	# Stool behind the counter.
	_kit.lathe("room", f * Vector3(x0 + .9, 0, z - .55), [Vector2(.16, 0), Vector2(.12, .05), Vector2(.03, .08), Vector2(.03, .55), Vector2(.17, .58), Vector2(.17, .63), Vector2(0, .64)], Color("#4a4c50"), 10)

func _back_room() -> void:
	# Through the doorway: the family's back room, a step up, dimmer, the indigo noren half across.
	var f := _front
	var near := -ROOM_DEEP
	var deep := -7.3
	var x0 := BACK_DOOR.position.x - .4
	var x1 := BACK_DOOR.end.x + .5
	var tint := Color("#8a7a66")
	_kit.quad("room", f * Vector3(x0, .2, near), f * Vector3(x0, .2, deep), f * Vector3(x1, .2, deep), f * Vector3(x1, .2, near), Color("#7a6248"), .6, .6)
	_kit.quad("room", f * Vector3(x0, 0, deep), f * Vector3(x0, 2.4, deep), f * Vector3(x1, 2.4, deep), f * Vector3(x1, 0, deep), tint, .6, .8)
	_kit.quad("room", f * Vector3(x0, 0, near), f * Vector3(x0, 2.4, near), f * Vector3(x0, 2.4, deep), f * Vector3(x0, 0, deep), tint * .9, .6, .8)
	_kit.quad("room", f * Vector3(x1, 0, deep), f * Vector3(x1, 2.4, deep), f * Vector3(x1, 2.4, near), f * Vector3(x1, 0, near), tint * .9, .6, .8)
	_kit.quad("room", f * Vector3(x0, 2.4, deep), f * Vector3(x0, 2.4, near), f * Vector3(x1, 2.4, near), f * Vector3(x1, 2.4, deep), tint * .7, .6, .6)
	_bar("room", f, BACK_DOOR.get_center().x, .1, near - .1, Vector3(BACK_DOOR.size.x, .2, .2), Color("#5a4632"))
	_bar("room", f, (x0 + x1) * .5, 1.1, deep + .2, Vector3(x1 - x0 - .2, .02, .35), Color("#6a5038"))
	_bar("room", f, (x0 + x1) * .5 - .3, 1.25, deep + .2, Vector3(.4, .28, .25), Color("#a83a2a"))
	_bar("room", f, (x0 + x1) * .5 + .3, 1.2, deep + .2, Vector3(.3, .18, .3), Color("#d8d0b8"))
	# Door frame and the noren.
	for x: float in [BACK_DOOR.position.x, BACK_DOOR.end.x]:
		_bar("room", f, x, 1.0, near, Vector3(.06, 2.0, .14), Color("#5a4030"))
	_bar("room", f, BACK_DOOR.get_center().x, 2.02, near, Vector3(BACK_DOOR.size.x + .1, .06, .14), Color("#5a4030"))
	for half: int in range(2):
		var a := BACK_DOOR.position.x + float(half) * BACK_DOOR.size.x * .5 + .01
		var b := a + BACK_DOOR.size.x * .5 - .02
		_kit.atlas("cloth", f * Vector3(a, 1.15, near + .05 + float(half) * .01), f * Vector3(a, 1.98, near + .04), f * Vector3(b, 1.98, near + .04), f * Vector3(b, 1.15, near + .05 + float(half) * .01), _px(float(half) * 200.0, 1480, 200, 300))

func _workbench() -> void:
	# East wall: the bench, pegboard of tools over it, the truing stand, the vice, bins below.
	var f := _front
	var x := RX1 - .3
	var z0 := -1.6
	var z1 := -4.3
	var zc := (z0 + z1) * .5
	var top := .92
	_bar("room", f, x, top - .025, zc, Vector3(.6, .05, z0 - z1), Color("#7a5a3c"))
	_bar("room", f, x, top - .06, zc, Vector3(.6, .03, z0 - z1 - .05), Color("#4a3a2a"))
	for z: float in [z0 + .05, zc, z1 - .05]:
		for dx: float in [-.26, .26]:
			_bar("steel", f, x + dx, (top - .05) * .5, z, Vector3(.04, top - .05, .04), Color("#5a6066"))
	_bar("room", f, x, .2, zc, Vector3(.56, .025, z0 - z1 - .1), Color("#6a5038"))
	var bins: Array[Color] = [Color("#2a6ab0"), Color("#d0a020"), Color("#c03a2a"), Color("#2a6ab0"), Color("#3a3c40")]
	for i: int in range(5):
		_bar("room", f, x - .02, .3, z0 - .3 - float(i) * .52, Vector3(.4, .18, .42), bins[i])
	# Pegboard, and a few real tools standing proud of it.
	_bar("room", f, RX1 - .01, 1.68, -2.65, Vector3(.02, 1.3, 1.96), Color("#6a5038"))
	_east_panel("display", RX1 - .022, -3.6, -1.7, 1.05, 2.3, _px(0, 1040, 640, 420))
	for i: int in range(5):
		var at := f * Vector3(RX1 - .05, 1.85, -1.85 - float(i) * .09)
		_kit.tube("steel", [at, at + Vector3(0, -.24 - float(i) * .02, 0)], .009, Color("#b8bcc0"), 4)
	_kit.tube("steel", [f * Vector3(RX1 - .06, 1.75, -3.0), f * Vector3(RX1 - .06, 1.35, -3.05)], .012, Color("#c42a24"), 5)
	_kit.tube("plain", [f * Vector3(RX1 - .07, 2.05, -3.3), f * Vector3(RX1 - .25, 1.6, -3.3), f * Vector3(RX1 - .07, 1.25, -3.3)], .008, Color("#202022"), 4)
	# Vice at the front end of the bench.
	_bar("steel", f, x - .1, top + .08, z0 - .15, Vector3(.16, .12, .22), Color("#3a5a8a"))
	_bar("steel", f, x - .1, top + .17, z0 - .15, Vector3(.18, .06, .1), Color("#4a4c50"))
	_kit.tube("steel", [f * Vector3(x - .1, top + .1, z0 + .0), f * Vector3(x - .1, top + .1, z0 + .14)], .008, Color("#c0c0c0"), 4)
	# Truing stand with a rear wheel in it, the hub just off the gauge.
	var tz := -3.85
	_bar("steel", f, x, top + .02, tz, Vector3(.24, .04, .5), Color("#2a2c30"))
	for dz: float in [-.2, .2]:
		_kit.tube("steel", [f * Vector3(x, top + .03, tz + dz), f * Vector3(x, top + .38, tz + dz * .9)], .014, Color("#3a5a8a"), 5)
	var wc := f * Vector3(x - .02, top + .38, tz)
	var rim: Array[Vector3] = []
	for i: int in range(17):
		var a := TAU * float(i) / 16.0
		rim.append(wc + Vector3(0, sin(a), cos(a)) * .29)
	_kit.tube("steel", rim, .012, Color("#b8bcc0"), 3)
	_kit.disc("spoke_in", wc, Vector3.FORWARD, Vector3.UP, .282, Color.WHITE, _px(1644, 264, 392, 392))
	_kit.tube("steel", [wc + Vector3(-.06, 0, 0), wc + Vector3(.06, 0, 0)], .02, Color("#8a8c90"), 6)
	# Oil can and a rag on the bench.
	_kit.lathe("steel", f * Vector3(x + .1, top, -2.6), [Vector2(.06, 0), Vector2(.06, .1), Vector2(.02, .14), Vector2(.008, .3)], Color("#c8a030"), 8)
	_bar("room", f, x - .05, top + .01, -2.2, Vector3(.25, .02, .2), Color("#b04a3a"))
	# Inner tubes hung on hooks over the back of the bench.
	for i: int in range(4):
		var hook := f * Vector3(RX1 - .06, 2.72, -3.85 - float(i) * .22)
		var loop: Array[Vector3] = []
		for k: int in range(13):
			var a := TAU * float(k) / 12.0
			loop.append(hook + Vector3(-.03, -.32 + cos(a) * .32, sin(a) * .07))
		_kit.tube("room", loop, .012, Color("#1e1e20"), 3)
	# Compressor by the front corner: red tank on wheels, motor, gauge, its hose.
	var cz := -1.0
	var tank0 := f * Vector3(4.7, .26, cz)
	var tank1 := f * Vector3(5.32, .26, cz)
	_kit.tube("steel", [tank0, tank1], .17, Color("#b8281e"), 10)
	_kit.disc("steel", tank0, Vector3.FORWARD, Vector3.UP, .17, Color("#a8241a"))
	_kit.disc("steel", tank1, Vector3.BACK, Vector3.UP, .17, Color("#a8241a"))
	_bar("steel", f, 5.05, .53, cz, Vector3(.3, .2, .22), Color("#2a2c30"))
	_kit.tube("steel", [f * Vector3(4.85, .5, cz), f * Vector3(4.85, .62, cz)], .05, Color("#5a5c60"), 8)
	_kit.disc("steel", f * Vector3(4.78, .5, cz + .19), Vector3.RIGHT, Vector3.UP, .045, Color("#f0eee8"))
	for dx: float in [4.75, 5.28]:
		_kit.disc("steel", f * Vector3(dx, .07, cz + .17), Vector3.RIGHT, Vector3.UP, .07, Color("#1a1a1c"))
	var hose: Array[Vector3] = [f * Vector3(4.72, .4, cz + .15)]
	for k: int in range(9):
		var a := TAU * float(k) / 8.0
		hose.append(f * Vector3(4.5 + cos(a) * .14, .05 + float(k) * .004, cz + .35 + sin(a) * .14))
	_kit.tube("room", hose, .012, Color("#d0a020"), 3)

func _repair_corner() -> void:
	# The stand in the middle of the floor with an e-assist clamped by its seat post, the
	# diagnostic tablet swung in on its arm; the puncture tub beside it.
	var f := _front
	var sx := 3.75
	var sz := -2.55
	var foot := f * Vector3(sx, 0, sz)
	for k: int in range(3):
		var a := TAU * float(k) / 3.0 + .4
		_kit.tube("steel", [foot + Vector3(cos(a) * .45, .02, sin(a) * .45), foot + Vector3(0, .15, 0)], .016, Color("#2a2c30"), 4)
	_kit.tube("steel", [foot + Vector3(0, .1, 0), foot + Vector3(0, 1.25, 0)], .025, Color("#3a5a8a"), 6)
	_kit.tube("steel", [foot + Vector3(0, 1.25, 0), foot + Vector3(-.14, 1.3, 0)], .02, Color("#3a5a8a"), 5)
	_kit.block("steel", Transform3D(Basis.IDENTITY, foot + Vector3(-.18, 1.3, 0)), Vector3(.1, .1, .12), Color("#c42a24"))
	# The bike on it: drive side to the street, wheels off the floor.
	_bike(_bike_xf(f * Vector3(sx - .18 + .26, 1.3 - .86, sz), Vector3.RIGHT), 1, Color("#3a5a7a"), "room", "steel", "spoke_in", -1)
	# Tablet arm.
	var arm := foot + Vector3(0, 1.1, 0)
	_kit.tube("steel", [arm, arm + Vector3(.25, .25, .2), arm + Vector3(.3, .45, .32)], .01, Color("#2a2c30"), 4)
	var pad := arm + Vector3(.3, .5, .34)
	var tilt := Basis(Vector3.RIGHT, -.45) * Basis(Vector3.UP, -.3)
	_kit.block("room", Transform3D(tilt, pad), Vector3(.28, .19, .014), Color("#1a1c1e"))
	var c := pad + tilt * Vector3(0, 0, .008)
	_kit.atlas("screen", c + tilt * Vector3(-.125, -.08, 0), c + tilt * Vector3(-.125, .08, 0), c + tilt * Vector3(.125, .08, 0), c + tilt * Vector3(.125, -.08, 0), _px(1860, 680, 180, 120))
	# Puncture tub: blue basin of water on a stool, a tube half under.
	var tub := f * Vector3(2.25, 0, -3.65)
	for dx: float in [-.15, .15]:
		for dz: float in [-.15, .15]:
			_kit.tube("steel", [tub + Vector3(dx, 0, dz), tub + Vector3(dx * .8, .42, dz * .8)], .012, Color("#4a4c50"), 4)
	_kit.lathe("room", tub + Vector3.UP * .42, [Vector2(.22, 0), Vector2(.3, .16), Vector2(.32, .17), Vector2(.3, .17)], Color("#2a6ab8"), 14)
	_kit.disc("steel", tub + Vector3.UP * .55, Vector3.RIGHT, Vector3.FORWARD, .28, Color("#3a5a6a"))
	var tube: Array[Vector3] = []
	for k: int in range(10):
		var a := PI * float(k) / 9.0
		tube.append(tub + Vector3(cos(a) * .2, .57 + sin(a) * .16, sin(a) * .04))
	_kit.tube("room", tube, .012, Color("#1e1e20"), 3)
	# Rail of tyres hung under the ceiling at the back right, and the parts cabinet under them.
	_kit.tube("steel", [f * Vector3(3.3, 2.75, -4.98), f * Vector3(5.5, 2.75, -4.98)], .015, Color("#6a6e72"), 4)
	for i: int in range(7):
		var hx := 3.45 + float(i) * .29
		var c2 := f * Vector3(hx, 2.42, -4.98 + float(i % 2) * .05)
		var ring: Array[Vector3] = []
		for k: int in range(17):
			var a := TAU * float(k) / 16.0
			ring.append(c2 + Vector3(sin(a) * .3 * sin(.45), cos(a) * .3, sin(a) * .3 * cos(.45)))
		_kit.tube("room", ring, .024, Color("#1c1c1e"), 4)
	var cx := 3.85
	var cz := -ROOM_DEEP + .21
	_bar("steel", f, cx, .15, cz, Vector3(.86, .3, .4), Color("#3a4448"))
	_bar("steel", f, cx, .3 + .56, cz, Vector3(.86, 1.12, .4), Color("#5a6a70"))
	_panel("display", f, cx - .43, cx + .43, .3, 1.42, cz + .202, _px(660, 1040, 320, 420))
	for i: int in range(3):
		_bar("room", f, cx - .25 + float(i) * .25, 1.52, cz, Vector3(.22, .18, .3), [Color("#c8b898"), Color("#2a6ab0"), Color("#d0a020")][i])

func _stock_inside() -> void:
	# Three bikes for sale against the west wall, tagged, angled the way the owner parks them.
	var f := _front
	var forward := Vector3(-.75, 0, -.66)
	var kinds: Array[int] = [0, 1, 3]
	var tints: Array[Color] = [Color("#e8e2d0"), Color("#7a2230"), Color("#2e3236")]
	for i: int in range(3):
		_bike(_bike_xf(f * Vector3(1.05, 0, -1.45 - float(i) * .78), forward), kinds[i], tints[i], "room", "steel", "spoke_in", [1, 3, 6][i])

func _fixtures() -> void:
	# Fluorescent troughs, warm-white tubes, running front to back.
	var f := _front
	for at: Vector2 in [Vector2(1.6, -1.4), Vector2(4.1, -1.4), Vector2(1.6, -3.7), Vector2(4.1, -3.7)]:
		_bar("steel", f, at.x, ROOM_TOP - .04, at.y, Vector3(.16, .06, 1.3), Color("#e0e0dc"))
		_bar("lamp", f, at.x, ROOM_TOP - .085, at.y, Vector3(.035, .035, 1.22), WARM * .62)

# ---------------------------------------------------------------- awning, fascia, sign

func _awning() -> void:
	# Canvas テント over the shop, faded stripes, on three steel arms.
	var f := _front
	var x0 := .75
	var x1 := 5.75
	var high := 3.0
	var low := 2.66
	var out := 1.05
	var drop := .22
	var x := x0
	var k := 0
	while x < x1 - .01:
		var w := minf(.25, x1 - x)
		var tint := Color("#ddd4bc") if k % 2 == 0 else Color("#56705c")
		var a := f * Vector3(x, low, out)
		var b := f * Vector3(x, high, .02)
		var c := f * Vector3(x + w, high, .02)
		var d := f * Vector3(x + w, low, out)
		_kit.quad("canvas", a, b, c, d, tint, .9, 1.0, .5, Vector2(x, 0))
		_kit.quad("canvas", d, c, b, a, tint * .55, .7, .8)
		var v0 := f * Vector3(x, low - drop, out)
		var v1 := f * Vector3(x + w, low - drop, out)
		_kit.quad("canvas", v0, a, d, v1, tint * .95, .8, 1.0, .7, Vector2(x, 0))
		_kit.quad("canvas", v1 + Vector3(0, 0, -.004), d + Vector3(0, 0, -.004), a + Vector3(0, 0, -.004), v0 + Vector3(0, 0, -.004), tint * .5, .7, .8)
		x += w
		k += 1
	for ax: float in [x0 + .05, (x0 + x1) * .5, x1 - .05]:
		_kit.tube("metal", [f * Vector3(ax, high - .08, .02), f * Vector3(ax, low - .02, out - .02)], .014, Color("#8a8c88"), 4)
	_kit.tube("metal", [f * Vector3(x0, low - .01, out - .02), f * Vector3(x1, low - .01, out - .02)], .016, Color("#8a8c88"), 4)

func _drone() -> void:
	# 2050: the delivery drone parked on its pad on the awning between runs.
	var f := _front
	var px := 5.15
	var pz := .5
	var py := 3.0
	for dx: float in [-.22, .22]:
		for dz: float in [-.22, .22]:
			_kit.tube("metal", [f * Vector3(px + dx, py, pz + dz), f * Vector3(px + dx, 2.9 - (pz + dz) * .3, pz + dz)], .01, Color("#5a5c5e"), 3)
	_bar("metal", f, px, py - .01, pz, Vector3(.5, .02, .5), Color("#3a3c3e"))
	_kit.atlas("board", f * Vector3(px - .24, py + .002, pz + .24), f * Vector3(px - .24, py + .002, pz - .24), f * Vector3(px + .24, py + .002, pz - .24), f * Vector3(px + .24, py + .002, pz + .24), _px(1720, 1760, 160, 160))
	var body := f * Vector3(px, py + .1, pz)
	_kit.block("plain", Transform3D(Basis(Vector3.UP, .3), body), Vector3(.3, .07, .2), Color("#d8dad8"))
	_kit.block("plain", Transform3D(Basis(Vector3.UP, .3), body + Vector3(0, -.06, 0)), Vector3(.2, .06, .14), Color("#d8a830"))
	for k: int in range(4):
		var a := .3 + PI * .25 + PI * .5 * float(k)
		var tip := body + Vector3(cos(a) * .24, .02, -sin(a) * .24)
		_kit.tube("plain", [body, tip], .012, Color("#2a2c2e"), 4)
		_kit.tube("plain", [tip, tip + Vector3.UP * .04], .02, Color("#2a2c2e"), 6)
		_kit.disc("plain", tip + Vector3.UP * .045, Vector3.RIGHT, Vector3.FORWARD, .11, Color("#4a4e52"))
	for s: float in [-.08, .08]:
		_kit.tube("plain", [body + Vector3(-.12, -.09, s), body + Vector3(.12, -.09, s)], .007, Color("#2a2c2e"), 3)
	_kit.block("led", Transform3D(Basis.IDENTITY, body + Vector3(.0, .04, .1)), Vector3(.03, .015, .01), GREEN)

func _fascia() -> void:
	var f := _front
	_bar("metal", f, WIDE * .5, 3.335, .03, Vector3(WIDE, .62, .06), Color("#4a4a48"))
	_panel("fascia", f, .08, WIDE - .08, 3.07, 3.6, .062, _px(0, 0, 1700, 140))
	_bar("metal", f, WIDE * .5, 3.64, .05, Vector3(WIDE + .02, .03, .1), Color("#6a6a66"))

func _side_sign() -> void:
	# Acrylic box sign standing off the east end, lit from inside after dark.
	var f := _front
	var x := 6.6
	var z0 := .14
	var z1 := .74
	var y0 := 3.95
	var y1 := 6.15
	_bar("metal", f, x, (y0 + y1) * .5, (z0 + z1) * .5, Vector3(.15, y1 - y0 + .06, z1 - z0 + .06), Color("#e2ded4"))
	var cell := _px(0, 260, 200, 760)
	_kit.atlas("signlit", f * Vector3(x - .077, y0, z0), f * Vector3(x - .077, y1, z0), f * Vector3(x - .077, y1, z1), f * Vector3(x - .077, y0, z1), cell)
	_kit.atlas("signlit", f * Vector3(x + .077, y0, z1), f * Vector3(x + .077, y1, z1), f * Vector3(x + .077, y1, z0), f * Vector3(x + .077, y0, z0), cell)
	for y: float in [y0 + .2, y1 - .2]:
		_bar("metal", f, x, y, z0 * .5, Vector3(.05, .05, z0 + .02), Color("#5a5a58"))
	_bar("metal", f, x, y1 + .05, (z0 + z1) * .5, Vector3(.17, .04, z1 - z0 + .08), Color("#8a2a22"))

func _locker() -> void:
	# 2050: the battery-swap locker on the west pier, open all night.
	var f := _front
	var x := .48
	_bar("metal", f, x, .91, .19, Vector3(.7, 1.62, .38), Color("#cfd3cf"), .8, 1.0)
	_bar("metal", f, x, 1.74, .2, Vector3(.76, .04, .42), Color("#127a7a"))
	_bar("plain", f, x, .06, .19, Vector3(.66, .12, .34), Color("#3a3c3e"))
	_panel("display", f, x - .33, x + .33, .76, 1.68, .382, _px(1440, 1040, 300, 420))
	_panel("screen", f, x - .3, x - .06, .78, .9, .385, _px(1452, 1360, 160, 88))
	_kit.tube("plain", [f * Vector3(x + .36, 1.4, .2), f * Vector3(x + .42, 1.0, .25), f * Vector3(x + .4, .3, .25), f * Vector3(x + .36, .16, .2)], .01, Color("#1e1e20"), 3)

func _house_door() -> void:
	# The family's own door beside the shop: aluminium, reeded glass with the stair light behind.
	var f := _front
	var d := HOUSE
	_reveal(f, d, .12, Color("#6a6a64"))
	_flat("frost", f, Rect2(d.position.x + .06, .5, d.size.x - .12, d.size.y - .62), -.07, Color("#b8bcb4"), 1.0, 0.0)
	var y := .58
	while y < d.end.y - .1:
		_bar("frost", f, d.get_center().x, y, -.065, Vector3(d.size.x - .14, .008, .004), Color("#a0a49c"))
		y += .06
	_bar("metal", f, d.get_center().x, .27, -.07, Vector3(d.size.x - .04, .46, .03), Color("#8a8c88"))
	for x: float in [d.position.x + .03, d.end.x - .03]:
		_bar("metal", f, x, d.size.y * .5, -.06, Vector3(.06, d.size.y, .05), Color("#9a9a95"))
	_bar("metal", f, d.get_center().x, d.end.y - .03, -.06, Vector3(d.size.x, .06, .05), Color("#9a9a95"))
	_bar("metal", f, d.position.x + .12, 1.0, -.03, Vector3(.025, .16, .03), Color("#3a3a38"))
	_bar("slab", f, d.get_center().x, .06, .12, Vector3(d.size.x + .1, .12, .26), Color("#8a8680"))
	# Mailbox, intercom, nameplate on the pier between the doors.
	_bar("metal", f, 5.73, 1.12, .07, Vector3(.28, .34, .14), Color("#c8c4b4"))
	_bar("plain", f, 5.73, 1.2, .142, Vector3(.2, .025, .004), Color("#2a2a28"))
	_bar("plain", f, 5.73, 1.42, .02, Vector3(.1, .14, .03), Color("#d8d8d0"))
	_status(f, 5.73, 1.46, .036, CYAN * .6)
	_panel("board", f, 5.62, 5.84, 1.56, 1.65, .012, _px(1720, 1930, 160, 60))

func _pump_post() -> void:
	# 空気入れ ご自由に: a red post with a gauge, a coiled hose, chained to the pier.
	var f := _front
	var base := f * Vector3(5.72, 0, .55)
	_kit.lathe("plain", base, [Vector2(.14, 0), Vector2(.14, .04), Vector2(.05, .06)], Color("#3a3a3c"), 10)
	_kit.tube("plain", [base, base + Vector3.UP * 1.0], .045, Color("#c4281e"), 8)
	_kit.lathe("metal", base + Vector3.UP * .78, [Vector2(.08, 0), Vector2(.08, .02), Vector2(.075, .04)], Color("#c8c8c4"), 10)
	_kit.disc("plain", base + Vector3(0, .92, .05), Vector3.RIGHT, Vector3.UP, .075, Color("#f2f0ea"))
	_kit.lathe("metal", base + Vector3(0, .92, .047), [Vector2(.08, 0), Vector2(.08, .01)], Color("#a8a8a4"), 12)
	_kit.tube("plain", [base + Vector3(0, .92, .056), base + Vector3(.04, .95, .056)], .004, Color("#c42a24"), 3)
	_bar("metal", f, 5.72, 1.2, .55, Vector3(.34, .26, .03), Color("#d8d8d4"))
	_panel("board", f, 5.56, 5.88, 1.08, 1.32, .567, _px(1720, 0, 320, 240))
	var hose: Array[Vector3] = [base + Vector3(.05, .8, 0), base + Vector3(.15, .5, .05), base + Vector3(.12, .25, .09), base + Vector3(0, .2, .11), base + Vector3(-.1, .3, .09), base + Vector3(-.09, .7, .06), base + Vector3(-.05, .86, .05)]
	_kit.tube("plain", hose, .012, Color("#1e1e20"), 4)
	_kit.block("metal", Transform3D(Basis.IDENTITY, base + Vector3(-.05, .9, .05)), Vector3(.03, .06, .03), Color("#b0b0aa"))
	_kit.tube("metal", [base + Vector3(-.04, .3, -.03), f * Vector3(5.6, .3, .02)], .006, Color("#8a8c88"), 3)

# ---------------------------------------------------------------- upstairs

func _home_window(face: Transform3D, r: Rect2, curtain: String, cell: Rect2, gap: float, mullion: bool) -> void:
	# A real window: frame, clear glass, curtains a hand behind it, and the room past them.
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	_reveal(face, r, .14, Color("#8a8680"))
	var room := "homelit" if curtain == "curtain_lit" else "dim"
	var back := -1.4
	var tone := Color("#c8b89c")
	_kit.quad(room, face * Vector3(x0, y0, back), face * Vector3(x0, y1 + .3, back), face * Vector3(x1, y1 + .3, back), face * Vector3(x1, y0, back), tone, .6, .9)
	_kit.quad(room, face * Vector3(x0, y0 - .2, -.14), face * Vector3(x0, y1 + .3, -.14), face * Vector3(x0, y1 + .3, back), face * Vector3(x0, y0 - .2, back), tone * .8, .6, .9)
	_kit.quad(room, face * Vector3(x1, y0 - .2, back), face * Vector3(x1, y1 + .3, back), face * Vector3(x1, y1 + .3, -.14), face * Vector3(x1, y0 - .2, -.14), tone * .8, .6, .9)
	_kit.quad(room, face * Vector3(x0, y1 + .3, back), face * Vector3(x0, y1 + .3, -.14), face * Vector3(x1, y1 + .3, -.14), face * Vector3(x1, y1 + .3, back), tone * .9, .6, .6)
	_kit.quad(room, face * Vector3(x0, y0 - .2, -.14), face * Vector3(x0, y0 - .2, back), face * Vector3(x1, y0 - .2, back), face * Vector3(x1, y0 - .2, -.14), Color("#6a5440"), .6, .6)
	var mid := (x0 + x1) * .5
	var shade := Color.WHITE if curtain == "curtain_lit" else Color(.62, .62, .62)
	if gap <= 0.0:
		_panel(curtain, face, x0 + .02, x1 - .02, y0 + .02, y1 - .02, -.11, cell, shade)
	else:
		var half := Rect2(cell.position, Vector2(cell.size.x * .5, cell.size.y))
		_panel(curtain, face, x0 + .02, mid - gap * .5, y0 + .02, y1 - .02, -.11, half, shade)
		_panel(curtain, face, mid + gap * .5, x1 - .02, y0 + .02, y1 - .02, -.115, Rect2(half.position + Vector2(half.size.x, 0), half.size), shade)
	_kit.quad("front", face * Vector3(x0, y0, -.05), face * Vector3(x0, y1, -.05), face * Vector3(x1, y1, -.05), face * Vector3(x1, y0, -.05), Color.WHITE)
	var alu := ALUMINIUM
	_bar("metal", face, mid, y1 - .02, -.05, Vector3(r.size.x, .04, .07), alu)
	_bar("metal", face, mid, y0 + .02, -.05, Vector3(r.size.x, .04, .07), alu)
	_bar("metal", face, x0 + .02, (y0 + y1) * .5, -.05, Vector3(.04, r.size.y, .07), alu)
	_bar("metal", face, x1 - .02, (y0 + y1) * .5, -.05, Vector3(.04, r.size.y, .07), alu)
	if mullion:
		_bar("metal", face, mid - .02, (y0 + y1) * .5, -.065, Vector3(.035, r.size.y - .06, .025), alu)
		_bar("metal", face, mid + .02, (y0 + y1) * .5, -.04, Vector3(.035, r.size.y - .06, .025), alu)
	_bar("metal", face, mid, y0 - .012, .03, Vector3(r.size.x + .1, .03, .1), Color("#6e6f6c"))

func _small_window(face: Transform3D, r: Rect2) -> void:
	# Bathroom or stair: obscure glass behind a grille.
	_reveal(face, r, .1, Color("#8a8680"))
	_kit.atlas("curtain", face * Vector3(r.position.x, r.position.y, -.08), face * Vector3(r.position.x, r.end.y, -.08), face * Vector3(r.end.x, r.end.y, -.08), face * Vector3(r.end.x, r.position.y, -.08), _px(420, 1480, 200, 300), Color(.85, .88, .86))
	var rods := int(r.size.x / .1)
	for rod: int in range(1, rods):
		_bar("metal", face, r.position.x + r.size.x * float(rod) / float(rods), r.get_center().y, .04, Vector3(.016, r.size.y + .06, .016), ALUMINIUM)
	for y: float in [r.position.y - .02, r.end.y + .02]:
		_bar("metal", face, r.get_center().x, y, .04, Vector3(r.size.x + .08, .03, .03), ALUMINIUM)

func _upper_front() -> void:
	var f := _front
	var holes: Array[Rect2] = [SLIDE.grow(.04), KITCHEN.grow(.04), LOO.grow(.04), W3A.grow(.04), W3B.grow(.04), W3C.grow(.04)]
	for piece: Rect2 in _minus(Rect2(0, 3.62, WIDE, TOP - 3.62), holes):
		_flat("tile", f, piece, 0.0, TILE_TINT, .9, .6)
	_bar("slab", f, WIDE * .5, 6.5, .03, Vector3(WIDE, .12, .07), Color("#a8a49a"), .8, 1.0)
	_bar("slab", f, WIDE * .5, TOP + .04, -.08, Vector3(WIDE + .06, .08, .26), Color("#9a968e"), .8, 1.0)
	for x: float in [.04, WIDE - .04]:
		_bar("slab", f, x, (3.7 + TOP) * .5, .02, Vector3(.08, TOP - 3.7, .05), Color("#b0aca2"), .8, 1.0)
	_home_window(f, SLIDE, "curtain", _px(640, 1480, 200, 300), .5, true)
	_home_window(f, KITCHEN, "curtain", _px(420, 1480, 200, 300), .26, true)
	_home_window(f, W3A, "curtain_lit", _px(420, 1480, 200, 300), .3, true)
	_home_window(f, W3B, "curtain", _px(640, 1480, 200, 300), .18, true)
	_small_window(f, LOO)
	_small_window(f, W3C)
	# 3F west window: a wrought rail and a planter of herbs on the sill.
	var r := W3A
	_bar("rust", f, r.get_center().x, r.position.y - .05, .16, Vector3(r.size.x + .1, .04, .2), Color("#5a4a40"))
	_bar("plain", f, r.get_center().x, r.position.y + .07, .15, Vector3(r.size.x - .3, .18, .16), Color("#a86a48"))
	for k: int in range(3):
		_plant(f * Vector3(r.position.x + .45 + float(k) * .45, r.position.y + .16, .15), .3, Color("#4a6a3a"))
	for y: float in [r.position.y + .45, r.position.y + .5]:
		_bar("rust", f, r.get_center().x, y, .26, Vector3(r.size.x + .1, .03, .03), Color("#4a3a32"))
	var x := r.position.x
	while x <= r.end.x + .01:
		_bar("rust", f, x, r.position.y + .22, .26, Vector3(.025, .5, .025), Color("#4a3a32"))
		x += .18
	# 3F east window: the air-con of that room on a wall bracket under it.
	_outdoor_unit(f, W3B.get_center().x + .4, 6.08, .22)
	_bar("metal", f, W3B.get_center().x + .4, 5.75, .2, Vector3(.9, .04, .34), Color("#3a3a38"))
	_kit.tube("plain", [f * Vector3(W3B.get_center().x, 6.1, .05), f * Vector3(W3B.position.x - .1, 6.1, .05), f * Vector3(W3B.position.x - .1, 5.9, .05)], .018, Color("#d6d0c0"), 4)

func _balcony() -> void:
	var f := _front
	var x0 := .25
	var x1 := 5.45
	var z := .92
	_bar("slab", f, (x0 + x1) * .5, 3.79, .47, Vector3(x1 - x0, .14, .94), Color("#9a968e"), .7, 1.0)
	_bar("slab", f, (x0 + x1) * .5, 3.73, .93, Vector3(x1 - x0, .03, .03), Color("#7a766e"))
	var rail := Color("#4e5a54")
	_bar("rust", f, (x0 + x1) * .5, 4.96, z, Vector3(x1 - x0, .05, .07), rail)
	_bar("rust", f, (x0 + x1) * .5, 3.94, z, Vector3(x1 - x0, .04, .04), rail)
	var x := x0 + .02
	while x < x1:
		_bar("rust", f, x, 4.45, z, Vector3(.018, 1.0, .018), rail)
		x += .12
	for sx: float in [x0 + .02, x1 - .02]:
		_bar("rust", f, sx, 4.96, z * .5, Vector3(.05, .05, z), rail)
		var zz := .1
		while zz < z:
			_bar("rust", f, sx, 4.45, zz, Vector3(.018, 1.0, .018), rail)
			zz += .12
	# Laundry on its pole, a futon over the rail, planters along the edge, the air-con.
	var py := 5.62
	for ax: float in [x0 + .15, 3.25]:
		_kit.tube("metal", [f * Vector3(ax, py + .12, .02), f * Vector3(ax, py, .62)], .012, ALUMINIUM, 4)
	_kit.tube("metal", [f * Vector3(x0 + .05, py, .6), f * Vector3(3.35, py, .6)], .016, Color("#b8bcc0"), 6)
	var hung: Array[Color] = [Color("#e8e6de"), Color("#4a5a7a"), Color("#d8c8b0"), Color("#a84a3a"), Color("#e8e6de")]
	var lx := x0 + .3
	for k: int in range(5):
		var w := _rng.randf_range(.3, .48)
		var long := _rng.randf_range(.35, .62)
		_kit.quad("plain", f * Vector3(lx, py - long, .62), f * Vector3(lx, py, .6), f * Vector3(lx + w, py, .6), f * Vector3(lx + w, py - long, .62), hung[k], .85, 1.0)
		_kit.quad("plain", f * Vector3(lx + w, py - long, .6), f * Vector3(lx + w, py, .59), f * Vector3(lx, py, .59), f * Vector3(lx, py - long, .6), hung[k].darkened(.3), .8, 1.0)
		lx += w + .14
	var fx0 := 3.55
	var fx1 := 4.35
	var futon := Color("#b8705e")
	_kit.quad("plain", f * Vector3(fx0, 4.35, z + .05), f * Vector3(fx0, 4.99, z + .04), f * Vector3(fx1, 4.99, z + .04), f * Vector3(fx1, 4.35, z + .05), futon, .8, 1.0)
	_kit.quad("plain", f * Vector3(fx0, 4.99, z + .04), f * Vector3(fx0, 5.01, z - .04), f * Vector3(fx1, 5.01, z - .04), f * Vector3(fx1, 4.99, z + .04), futon, 1.0, 1.0)
	_kit.quad("plain", f * Vector3(fx1, 4.45, z - .05), f * Vector3(fx1, 4.99, z - .04), f * Vector3(fx0, 4.99, z - .04), f * Vector3(fx0, 4.45, z - .05), futon.darkened(.25), .8, 1.0)
	for k: int in range(3):
		var px := .55 + float(k) * .55
		_bar("plain", f, px, 3.98, .75, Vector3(.42, .2, .2), Color("#8a6a50") if k != 1 else Color("#d8d0c0"))
		_plant(f * Vector3(px, 4.08, .75), .38, Color("#4a6a3a"))
	_outdoor_unit(f, 4.95, 4.17, .45)
	_kit.tube("plain", [f * Vector3(4.55, 4.3, .4), f * Vector3(4.4, 4.3, .05), f * Vector3(4.4, 4.9, .05)], .018, Color("#d6d0c0"), 4)

# ---------------------------------------------------------------- side, back, roof

func _side_walls() -> void:
	var e := _east
	_render_wall(e, DEEP, TOP, GROUND, THIRD - GROUND, RENDER_TINT, [E_STAIR2.grow(.04), E_STAIR3.grow(.04), E_ROOM2.grow(.04), E_ROOM3.grow(.04)])
	_small_window(e, E_STAIR2)
	_small_window(e, E_STAIR3)
	_home_window(e, E_ROOM2, "curtain", _px(420, 1480, 200, 300), .3, true)
	_home_window(e, E_ROOM3, "curtain", _px(640, 1480, 200, 300), 0.0, true)
	# The old painted advertisement high on the side, for the trains that used to pass.
	_panel("decal", e, 1.2, 6.1, 8.35, 9.43, .012, _px(860, 1480, 1180, 260))
	_bar("metal", e, 2.05, 4.62, .015, Vector3(.24, .34, .02), Color("#2a2a28"))
	_panel("board", e, 1.95, 2.15, 4.48, 4.76, .027, _px(1500, 1760, 200, 280))
	_outdoor_unit(e, 3.0, 4.75, .2)
	_bar("metal", e, 3.0, 4.42, .2, Vector3(.9, .04, .34), Color("#3a3a38"))
	_kit.tube("plain", [e * Vector3(2.6, 4.7, .03), e * Vector3(2.3, 4.7, .03), e * Vector3(2.3, .3, .03)], .016, Color("#d6d0c0"), 4)
	_bar("metal", e, 1.2, 1.3, .08, Vector3(.3, .4, .14), Color("#c8c6b8"))
	_kit.tube("metal", [e * Vector3(1.2, 1.1, .08), e * Vector3(1.2, .3, .05)], .014, Color("#b4a24a"), 5)
	_kit.tube("metal", [e * Vector3(DEEP - .1, TOP, .08), e * Vector3(DEEP - .1, .1, .08)], .04, Color("#6a6e6a"), 7)
	_fibre([e * Vector3(.1, 3.6, .06), e * Vector3(DEEP - .2, 3.6, .06)])
	_kit.tube("metal", [e * Vector3(5.6, DECK, .2), e * Vector3(5.6, TOP + 1.6, .2)], .018, ALUMINIUM, 5)
	_status(e, 5.6, TOP + 1.62, .23, GREEN)
	var w := _west
	_render_wall(w, DEEP, TOP, GROUND, THIRD - GROUND, RENDER_TINT * .97, [])
	_kit.tube("metal", [w * Vector3(.15, TOP, .08), w * Vector3(.15, .1, .08)], .04, Color("#6a6e6a"), 7)
	var b := _back
	_render_wall(b, WIDE, GROUND, GROUND, THIRD - GROUND, RENDER_TINT * .95, [B_DOOR])
	for piece: Rect2 in _minus(Rect2(0, GROUND, WIDE, TOP - GROUND), [B_WIN2.grow(.04), B_WIN3.grow(.04)]):
		_flat("corr", b, piece, 0.0, Color("#9a8c7c"), .9, .8)
	_window(b, B_WIN2, .83, false)
	_window(b, B_WIN3, .91, true)
	_flat("metal", b, B_DOOR, .01, Color("#7a7c78"), .8, .5)
	_bar("metal", b, 3.6, 1.2, .2, Vector3(.5, .8, .34), Color("#d8d6cc"))
	_bar("slab", b, WIDE * .5, TOP + .04, -.08, Vector3(WIDE + .06, .08, .26), Color("#9a968e"))
	_bar("slab", e, DEEP * .5, TOP + .04, -.08, Vector3(DEEP, .08, .26), Color("#9a968e"))
	_bar("slab", w, DEEP * .5, TOP + .04, -.08, Vector3(DEEP, .08, .26), Color("#9a968e"))

func _roof() -> void:
	var h := WIDE * .5
	_kit.quad("slab", Vector3(-h, DECK, 0), Vector3(-h, DECK, -DEEP), Vector3(h, DECK, -DEEP), Vector3(h, DECK, 0), Color("#7a7670"), .8, .8)
	var t := .15
	var parapet := Color("#a8a49a")
	_kit.quad("render", Vector3(h - t, DECK, -t), Vector3(h - t, TOP, -t), Vector3(-h + t, TOP, -t), Vector3(-h + t, DECK, -t), parapet, .8, 1.0)
	_kit.quad("render", Vector3(-h + t, DECK, -DEEP + t), Vector3(-h + t, TOP, -DEEP + t), Vector3(h - t, TOP, -DEEP + t), Vector3(h - t, DECK, -DEEP + t), parapet, .8, 1.0)
	_kit.quad("render", Vector3(-h + t, DECK, -t), Vector3(-h + t, TOP, -t), Vector3(-h + t, TOP, -DEEP + t), Vector3(-h + t, DECK, -DEEP + t), parapet, .8, 1.0)
	_kit.quad("render", Vector3(h - t, DECK, -DEEP + t), Vector3(h - t, TOP, -DEEP + t), Vector3(h - t, TOP, -t), Vector3(h - t, DECK, -t), parapet, .8, 1.0)
	_kit.quad("slab", Vector3(-h, TOP + .08, -.1), Vector3(-h, TOP + .08, -DEEP + .1), Vector3(-h + .25, TOP + .08, -DEEP + .1), Vector3(-h + .25, TOP + .08, -.1), Color("#9a968e"))
	_kit.quad("slab", Vector3(h - .25, TOP + .08, -.1), Vector3(h - .25, TOP + .08, -DEEP + .1), Vector3(h, TOP + .08, -DEEP + .1), Vector3(h, TOP + .08, -.1), Color("#9a968e"))
	# Old water tank on its stand, a solar strip of the 2050s, the aerial with a sensor on top.
	var tank := Vector3(-1.4, DECK, -5.4)
	for dx: float in [-.4, .4]:
		for dz: float in [-.4, .4]:
			_kit.tube("metal", [tank + Vector3(dx, 0, dz), tank + Vector3(dx, .5, dz)], .025, Color("#5a5c58"), 4)
	_kit.lathe("metal", tank + Vector3.UP * .5, [Vector2(.55, 0), Vector2(.56, .05), Vector2(.56, .9), Vector2(.5, 1.0), Vector2(.1, 1.08), Vector2(0, 1.08)], Color("#7a9aa8"), 14)
	_solar_module(Transform3D(Basis(Vector3.RIGHT, -PI * .5 + .35), Vector3(1.3, DECK + .5, -3.0)), 2.4, 1.1)
	for dx: float in [.3, 2.3]:
		_kit.tube("metal", [Vector3(dx, DECK, -3.3), Vector3(dx, DECK + .55, -3.3)], .02, ALUMINIUM, 4)
	_kit.tube("metal", [Vector3(-.5, DECK, -1.5), Vector3(-.5, DECK + 2.2, -1.5)], .018, ALUMINIUM, 5)
	for y: float in [DECK + 1.5, DECK + 1.9]:
		_kit.tube("metal", [Vector3(-1.0, y, -1.5), Vector3(.0, y, -1.5)], .006, ALUMINIUM, 3)
	_kit.lathe("plain", Vector3(-.5, DECK + 2.2, -1.5), [Vector2(.05, 0), Vector2(.06, .04), Vector2(.02, .1)], Color("#d6d6d0"), 8)

# ---------------------------------------------------------------- what moves at closing time

func _pavement_stock() -> void:
	# By day: the stock nose-in on the pavement, tagged; the board; two maker's banners.
	var f := _front
	var kinds: Array[int] = [0, 4, 2, 0, 1, 2, 3]
	var tints: Array[Color] = [Color("#c8ccd0"), Color("#8a2228"), Color("#e07aa0"), Color("#e2d6b8"), Color("#2e4a3e"), Color("#3a6ab0"), Color("#5a5e62")]
	var tags: Array[int] = [0, 2, 4, 1, 3, 5, 6]
	for i: int in range(7):
		var x := 1.35 + float(i) * .58
		var lean := .2 if i % 2 == 0 else -.2
		var z := 1.22 if i % 2 == 0 else 1.36
		if kinds[i] == 2:
			z = 1.0
		_bike(_bike_xf(f * Vector3(x, 0, z), Vector3(sin(lean), 0, -cos(lean))), kinds[i], tints[i], "plain", "metal", "spoke", tags[i])
	# The A-board with the puncture prices, out by the pump.
	var bx := 5.1
	var bz := 1.65
	var x0 := bx - .25
	var x1 := bx + .25
	_kit.atlas("board", f * Vector3(x0, .12, bz + .2), f * Vector3(x0, .86, bz + .02), f * Vector3(x1, .86, bz + .02), f * Vector3(x1, .12, bz + .2), _px(620, 260, 360, 520))
	_kit.quad("plain", f * Vector3(x1, .1, bz + .19), f * Vector3(x1, .88, bz + .01), f * Vector3(x0, .88, bz + .01), f * Vector3(x0, .1, bz + .19), Color("#2a2a2c"))
	_kit.quad("plain", f * Vector3(x1, 0, bz - .22), f * Vector3(x1, .9, bz - .01), f * Vector3(x0, .9, bz - .01), f * Vector3(x0, 0, bz - .22), Color("#3a3a3c"))
	_kit.quad("plain", f * Vector3(x0, 0, bz - .22), f * Vector3(x0, .9, bz - .01), f * Vector3(x1, .9, bz - .01), f * Vector3(x1, 0, bz - .22), Color("#2a2a2c"))
	for x: float in [x0, x1]:
		_kit.tube("plain", [f * Vector3(x, 0, bz + .23), f * Vector3(x, .9, bz)], .014, Color("#1a1a1c"), 4)
	_kit.tube("plain", [f * Vector3(x0, .9, bz), f * Vector3(x1, .9, bz)], .014, Color("#1a1a1c"), 4)
	_nobori(f * Vector3(.25, 0, 2.3), -1.0, _px(220, 260, 180, 760))
	_nobori(f * Vector3(6.6, 0, 2.3), 1.0, _px(420, 260, 180, 760))

func _nobori(base: Vector3, toward: float, rect: Rect2) -> void:
	# のぼり on a weighted base: pole, top arm, the banner printed both sides.
	_kit.lathe("plain", base, [Vector2(.16, 0), Vector2(.16, .09), Vector2(.05, .12), Vector2(.03, .14)], Color("#2a2a2c"), 10)
	_kit.tube("metal", [base, base + Vector3.UP * 2.35], .012, Color("#d8d8d4"), 5)
	var along := Vector3.LEFT * toward
	_kit.tube("metal", [base + Vector3.UP * 2.25, base + Vector3.UP * 2.25 + along * .44], .007, Color("#d8d8d4"), 4)
	var a := base + Vector3.UP * .5 + along * .02
	var b := base + Vector3.UP * 2.23 + along * .02
	var c := base + Vector3.UP * 2.23 + along * .44
	var d := base + Vector3.UP * .5 + along * .44 + Vector3.BACK * .03
	if toward > 0.0:
		_kit.atlas("board", d, c, b, a, rect, Color.WHITE, .95, .2)
		_kit.atlas("board", a, b, c, d, Rect2(rect.end.x, rect.position.y, -rect.size.x, rect.size.y), Color(.7, .7, .7), .85)
	else:
		_kit.atlas("board", a, b, c, d, rect, Color.WHITE, .95, .2)
		_kit.atlas("board", d, c, b, a, Rect2(rect.end.x, rect.position.y, -rect.size.x, rect.size.y), Color(.7, .7, .7), .85)

func _after_hours() -> void:
	# After closing: the shutter half down, three of the pavement bikes wheeled in under it.
	var f := _front
	var y0 := 1.12
	var x0 := OPENING.position.x + .03
	var x1 := OPENING.end.x - .03
	_flat("shutter", f, Rect2(x0, y0, x1 - x0, OPENING.end.y - y0), .05, Color("#9aa29a"), .8, .7)
	_bar("metal", f, (x0 + x1) * .5, y0 + .02, .055, Vector3(x1 - x0, .05, .06), Color("#4a4e4a"))
	for x: float in [x0 + .8, x1 - .8]:
		_bar("metal", f, x, y0 + .09, .085, Vector3(.12, .03, .03), Color("#2a2c2a"))
	var kinds: Array[int] = [0, 4, 3]
	var tints: Array[Color] = [Color("#c8ccd0"), Color("#8a2228"), Color("#5a5e62")]
	for i: int in range(3):
		var lean := .15 if i % 2 == 0 else -.12
		_bike(_bike_xf(f * Vector3(2.3 + float(i) * .66, 0, -.95 - float(i % 2) * .15), Vector3(sin(lean), 0, -cos(lean))), kinds[i], tints[i], "room", "steel", "spoke_in", -1)
