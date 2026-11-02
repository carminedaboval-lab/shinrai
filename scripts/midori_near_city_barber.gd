extends "res://scripts/midori_near_city_handmade.gd"
## 理容 あおば: a corner barber behind a 1958 false front, in mint paint nobody has renewed
## since the owner's father died. Two chairs that weigh more than he does, a tobacco and
## lottery hatch cut into the splayed corner, a tin flank onto the side street, and the flat
## upstairs where the towels dry.
const ATLAS := "res://assets/shinrai/near_city/barber_atlas.png"
const WIDE := 4.22
const DEEP := 6.66
const CUT := .9
const GROUND := 3.3
const FIRST := 6.0
const EAVE := 6.05
const PARAPET := 6.8
const CREST := 7.4
const RIDGE := 7.35
const RIDGE_Z := -3.5
const FRONT_Z := -.3
const ROOM_TOP := 2.62
const ROOM_DEEP := 5.9
const SHOP_TOP := 2.72
const RX0 := .12
const RX1 := WIDE - .12
const MINT := Color("#a6c8b6")
const SEAFOAM := Color("#8fb8a6")
const PAINT := Color("#c3dccd")
const CREAM := Color("#e6dfca")
const OXBLOOD := Color("#5e2a26")
const ENAMEL := Color("#dcd8ca")
const CHROME := Color("#c6cacc")
const DARKWOOD := Color("#3a2a20")
const DOOR := Rect2(1.2, .02, .86, 2.3)
const TRANSOM := Rect2(1.2, 2.32, .86, .26)
const WINDOW := Rect2(2.5, .62, 1.52, 1.82)
const POLE_X := 2.28
const POLE_Z := .17
const HATCH := Rect2(.1, .96, 1.07, 1.16)
const CASE := Rect2(.1, .24, 1.07, .62)
const SHOP_LOW := Rect2(1.1, 3.72, 1.2, 1.74)
const SHOP_HIGH := Rect2(2.86, 3.84, .9, 1.5)
const SLIT := Rect2(.36, 3.84, .56, 1.5)
const WEST_LOW := Rect2(.74, 1.02, .72, .94)
const WEST_A := Rect2(.74, 4.0, 1.16, 1.3)
const WEST_B := Rect2(3.5, 4.0, 1.16, 1.3)
const AD := Rect2(1.76, .86, 3.54, 2.36)
const SPIN_REACH := 40.0
const SPIN_RATE := 1.5

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
var _corner := Transform3D(Basis(Vector3(1, 0, 1).normalized(), Vector3.UP, Vector3(-1, 0, 1).normalized()), Vector3(-WIDE * .5, 0, -CUT))
var _splay := CUT * sqrt(2.0)
var _spin: Node3D

func _ready() -> void:
	_rng.seed = 1958
	_build_looks()
	_shop_wall()
	_room()
	_counter()
	_chair(_front * Vector3(2.98, .03, -2.05), .22, false)
	_chair(_front * Vector3(2.88, .03, -3.95), 1.2, true)
	_trolley(_front * Vector3(3.2, .03, -3.0))
	_towel_wall()
	_bench()
	_shop_window()
	_door()
	_kiosk()
	_fascia()
	_awning()
	_pole()
	_upper_front()
	_false_front()
	_west_flank()
	_tin_end(_east, Color("#9aa39c"), false)
	_tin_end(_back, Color("#8f9690"), true)
	_roof()
	_street_things()
	_kit.commit(self, _looks, ["front", "decal", "paint", "lamp", "led", "sign", "room", "floor", "display", "steel", "vinyl", "vial", "shade", "towel"])
	_kit = null
	_build_spinner()
	_omni("BarberRoom", Vector3(.3, 2.3, -3.0), Color(1.0, .9, .74), .6, 5.0)
	_omni("BarberKiosk", Vector3(-1.75, 2.1, .25), Color(1.0, .78, .52), .7, 4.2)

func _process(delta: float) -> void:
	# The stripes only climb for someone close enough to see them climb.
	if _spin == null:
		return
	var eye := get_viewport().get_camera_3d()
	if eye == null or eye.global_position.distance_squared_to(_spin.global_position) > SPIN_REACH * SPIN_REACH:
		return
	_spin.rotate_y(delta * SPIN_RATE)

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

func _build_looks() -> void:
	_shared_looks()
	_looks.tile = _look("", 1.0, .32)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.092, .092))
	_looks.mortar = _look("plastered_wall_03", 2.2, .95)
	_looks.mortar.set_shader_parameter("chroma", .35)
	_looks.clap = _look("japanese_cedar_planks", 1.6, .85)
	_looks.clap.set_shader_parameter("chroma", .15)
	_looks.wood = _look("japanese_cedar_planks", 1.2, .7)
	_looks.wood.set_shader_parameter("chroma", .1)
	_looks.tin = _look("worn_corrugated_iron", 2.0, .75)
	_looks.tin.set_shader_parameter("chroma", .55)
	_looks.rust = _look("rusty_corrugated_iron", 2.0, .85)
	_looks.rust.set_shader_parameter("chroma", .8)
	_looks.roof = _look("rusty_corrugated_iron", 2.4, .8)
	_looks.roof.set_shader_parameter("chroma", .7)
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .6)
	_looks.cloth = _look("", 1.0, .94)
	_lit_look("room", .55, .3, .1)
	_lit_look("steel", .3, .18, .06, .7)
	_lit_look("vinyl", .34, .24, .08)
	_lit_look("vial", .14, .32, .1)
	_lit_look("towel", .95, .28, .1)
	_lit_look("shade", .4, 1.1, .14)
	_atlas_look("sign", .4, .46, .1)
	_atlas_look("display", .3, .42, .16)
	_atlas_look("floor", .45, .28, .1)
	_atlas_look("board", .5, .04, .02)
	_atlas_look("spin", .25, .9, .2)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", load(ATLAS))
	letters.set_shader_parameter("glow", .3)
	letters.set_shader_parameter("day_glow", .1)
	_looks.decal = letters
	var brushed := ShaderMaterial.new()
	brushed.shader = DECAL_SHADER
	brushed.set_shader_parameter("atlas", load(ATLAS))
	brushed.set_shader_parameter("glow", .03)
	_looks.paint = brushed

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _pad(part: String, xf: Transform3D, size: Vector3, tint: Color) -> void:
	# Upholstery: a rounded section swept along z and pinched shut, so no chair is a stack of bricks.
	var half := size * .5
	var r := minf(size.x, size.y) * .34
	var section: Array[Vector2] = []
	var rims: Array[Vector2] = []
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for q: int in range(4):
		var c := Vector2(corners[q].x * (half.x - r), corners[q].y * (half.y - r))
		for i: int in range(3):
			var a := PI * .5 * float(q) + PI * .25 * float(i)
			var dir := Vector2(cos(a), sin(a))
			section.append(c + dir * r)
			rims.append(dir)
	var ends: Array[Vector2] = [Vector2(-half.z, .84), Vector2(-half.z + r * .7, 1.0), Vector2(half.z - r * .7, 1.0), Vector2(half.z, .84)]
	var slants: Array[float] = [-.8, 0.0, 0.0, .8]
	var count := section.size()
	for s: int in range(3):
		for k: int in range(count):
			var n := (k + 1) % count
			var a := xf * Vector3(section[k].x * ends[s].y, section[k].y * ends[s].y, ends[s].x)
			var b := xf * Vector3(section[k].x * ends[s + 1].y, section[k].y * ends[s + 1].y, ends[s + 1].x)
			var c := xf * Vector3(section[n].x * ends[s + 1].y, section[n].y * ends[s + 1].y, ends[s + 1].x)
			var d := xf * Vector3(section[n].x * ends[s].y, section[n].y * ends[s].y, ends[s].x)
			var na := xf.basis * Vector3(rims[k].x, rims[k].y, slants[s]).normalized()
			var nb := xf.basis * Vector3(rims[k].x, rims[k].y, slants[s + 1]).normalized()
			var nc := xf.basis * Vector3(rims[n].x, rims[n].y, slants[s + 1]).normalized()
			var nd := xf.basis * Vector3(rims[n].x, rims[n].y, slants[s]).normalized()
			_kit.smooth(part, a, b, c, d, na, nb, nc, nd, tint)
	for s: int in [0, 3]:
		var out := xf.basis * Vector3(0, 0, slants[s]).normalized()
		var mid := xf * Vector3(0, 0, ends[s].x)
		for k: int in range(count):
			var n := (k + 1) % count
			var a := xf * Vector3(section[k].x * ends[s].y, section[k].y * ends[s].y, ends[s].x)
			var b := xf * Vector3(section[n].x * ends[s].y, section[n].y * ends[s].y, ends[s].x)
			_kit.smooth(part, a, b, mid, mid, out, out, out, out, tint)

func _shop_wall() -> void:
	# Mint mosaic round the shop front, as laid in 1958, chipped along the plinth.
	var f := _front
	var door := Rect2(DOOR.position.x, DOOR.position.y, DOOR.size.x, TRANSOM.end.y - DOOR.position.y)
	_mosaic(f, Rect2(CUT, 0, WIDE - CUT, SHOP_TOP), [door, WINDOW])
	_reveal(f, door, .14, Color("#6f8a7e"))
	_reveal(f, WINDOW, .12, Color("#6f8a7e"))
	for span: Vector2 in [Vector2(CUT, DOOR.position.x), Vector2(DOOR.end.x, WIDE)]:
		_kit.quad("plain", f * Vector3(span.x, 0, .008), f * Vector3(span.x, .13, .008), f * Vector3(span.y, .13, .008), f * Vector3(span.y, 0, .008), Color("#4a504c"), .7, .9)
	# Louvres under the sill (the room breathes through them), as on the old salons.
	var x0 := WINDOW.position.x + .02
	var x1 := WINDOW.end.x - .02
	_bar("wood", f, (x0 + x1) * .5, .36, .012, Vector3(x1 - x0, .36, .024), Color("#35463f"))
	var y := .22
	while y < .52:
		_kit.quad("wood", f * Vector3(x0, y, .05), f * Vector3(x0, y + .05, .012), f * Vector3(x1, y + .05, .012), f * Vector3(x1, y, .05), PAINT, .7, 1.0)
		y += .056
	for edge: Vector4 in [Vector4((x0 + x1) * .5, .17, x1 - x0, .03), Vector4((x0 + x1) * .5, .55, x1 - x0, .03), Vector4(x0, .36, .03, .4), Vector4(x1, .36, .03, .4)]:
		_bar("wood", f, edge.x, edge.y, .03, Vector3(edge.z, edge.w, .06), PAINT * .92)

func _mosaic(face: Transform3D, area: Rect2, holes: Array[Rect2]) -> void:
	for piece: Rect2 in _minus(area, holes):
		var a := face * Vector3(piece.position.x, piece.position.y, 0)
		var b := face * Vector3(piece.position.x, piece.end.y, 0)
		var c := face * Vector3(piece.end.x, piece.end.y, 0)
		var d := face * Vector3(piece.end.x, piece.position.y, 0)
		_kit.quad("tile", a, b, c, d, SEAFOAM, .85, 1.0, .55, Vector2(piece.position.x, -piece.position.y))

func _room() -> void:
	# Cream distemper over mint boards, a chequered vinyl floor, two battens and one cassette.
	var f := _front
	var rail := 1.14
	var deep := -ROOM_DEEP
	var near := -.1
	var wall := Color("#e4dcc4")
	var boards := Color("#9fc2b0")
	_kit.atlas("floor", f * Vector3(RX0, .03, near), f * Vector3(RX0, .03, deep), f * Vector3(RX1, .03, deep), f * Vector3(RX1, .03, near), _cell(0, 790, 400, 600))
	_kit.quad("room", f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, ROOM_TOP, near), f * Vector3(RX1, ROOM_TOP, near), f * Vector3(RX1, ROOM_TOP, deep), Color("#d6cfb8"), .75, .75)
	_kit.quad("room", f * Vector3(RX0, 0, deep), f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX1, ROOM_TOP, deep), f * Vector3(RX1, 0, deep), wall, .7, .9)
	# West: boards to the rail, paint over.
	_kit.quad("room", f * Vector3(RX0, 0, near), f * Vector3(RX0, rail, near), f * Vector3(RX0, rail, deep), f * Vector3(RX0, 0, deep), boards, .6, .95)
	_kit.quad("room", f * Vector3(RX0, rail, near), f * Vector3(RX0, ROOM_TOP, near), f * Vector3(RX0, ROOM_TOP, deep), f * Vector3(RX0, rail, deep), wall, .95, .8)
	_kit.quad("room", f * Vector3(RX1, 0, deep), f * Vector3(RX1, rail, deep), f * Vector3(RX1, rail, near), f * Vector3(RX1, 0, near), boards, .6, .95)
	_kit.quad("room", f * Vector3(RX1, rail, deep), f * Vector3(RX1, ROOM_TOP, deep), f * Vector3(RX1, ROOM_TOP, near), f * Vector3(RX1, rail, near), wall, .95, .8)
	# Inside of the front, for whoever looks back from the chairs' mirror angle.
	_kit.quad("room", f * Vector3(RX1, 0, near - .02), f * Vector3(RX1, .6, near - .02), f * Vector3(WINDOW.position.x, .6, near - .02), f * Vector3(WINDOW.position.x, 0, near - .02), boards, .5, .8)
	var z := -.3
	while z > deep:
		_kit.quad("room", f * Vector3(RX0 + .004, 0, z), f * Vector3(RX0 + .004, rail, z), f * Vector3(RX0 + .004, rail, z - .007), f * Vector3(RX0 + .004, 0, z - .007), Color("#6f8f80"))
		z -= .1
	_bar("room", f, RX0 + .012, rail, (near + deep) * .5, Vector3(.024, .035, -deep + near), Color("#7c9c8c"))
	_bar("room", f, RX1 - .012, rail, (near + deep) * .5, Vector3(.024, .035, -deep + near), Color("#7c9c8c"))
	# Cornice, then the lights.
	for x: float in [RX0 + .02, RX1 - .02]:
		_bar("room", f, x, ROOM_TOP - .02, (near + deep) * .5, Vector3(.04, .04, -deep + near), Color("#c9c2a8"))
	for x: float in [1.5, 2.9]:
		_kit.block("metal", _at(f, x, ROOM_TOP - .03, -3.2), Vector3(.14, .05, 1.26), Color("#d7d4c8"))
		_kit.block("lamp", _at(f, x - .04, ROOM_TOP - .07, -3.2), Vector3(.03, .03, 1.2), Color(.95, .9, .76))
		_kit.block("lamp", _at(f, x + .04, ROOM_TOP - .07, -3.2), Vector3(.03, .03, 1.2), Color(.95, .9, .76))
	_kit.block("lamp", _at(f, 2.2, ROOM_TOP - .05, -1.3), Vector3(.9, .03, .03), Color(.9, .84, .7))
	_kit.block("room", _at(f, 2.2, ROOM_TOP - .03, -4.9), Vector3(.72, .05, .72), Color("#d3cdb9"))
	_kit.block("room", _at(f, 2.2, ROOM_TOP - .058, -4.9), Vector3(.5, .012, .5), Color("#8f8b7c"))
	# Stairs curtain in the back corner, and the dark it hides.
	var cx0 := 3.32
	var cx1 := RX1 - .02
	_kit.quad("plain", f * Vector3(cx0, 0, deep + .01), f * Vector3(cx0, 2.1, deep + .01), f * Vector3(cx1, 2.1, deep + .01), f * Vector3(cx1, 0, deep + .01), Color("#1a1512"))
	var pleats := 9
	for i: int in range(pleats):
		var x0 := lerpf(cx0, cx1, float(i) / float(pleats))
		var x1 := lerpf(cx0, cx1, float(i + 1) / float(pleats))
		var z0 := deep + .05 + (.03 if i % 2 == 0 else 0.0)
		var z1 := deep + .05 + (.0 if i % 2 == 0 else .03)
		_kit.quad("room", f * Vector3(x0, .28, z0), f * Vector3(x0, 2.12, z0), f * Vector3(x1, 2.12, z1), f * Vector3(x1, .28, z1), Color("#7a2c2a") * (.8 + .2 * float(i % 2)), .9, .8)
	_kit.tube("steel", [f * Vector3(cx0, 2.14, deep + .05), f * Vector3(cx1, 2.14, deep + .05)], .012, CHROME, 6)
	_panel("display", f, cx0 + .02, cx0 + .46, 2.2, 2.56, deep + .012, _cell(860, 1430, 180, 260))

func _counter() -> void:
	# The working wall: a mint-painted run of drawers, two basins, two old mirrors, tonics above.
	var f := _front
	var x0 := 3.54
	var near := -1.15
	var far := -4.85
	var run := near - far
	var middle := (near + far) * .5
	var x := (x0 + RX1) * .5
	_bar("room", f, x, .4, middle, Vector3(RX1 - x0 - .03, .8, run - .03), Color("#9cbfae"))
	_bar("room", f, x, .03, middle, Vector3(RX1 - x0 - .08, .06, run - .1), Color("#3c3a36"))
	_bar("room", f, x, .82, middle, Vector3(RX1 - x0 + .03, .035, run), Color("#ccd4c4"))
	_bar("steel", f, x0 - .018, .82, middle, Vector3(.012, .045, run), CHROME)
	var z := near - .12
	while z > far + .1:
		_bar("room", f, x0 - .007, .55, z - .17, Vector3(.012, .3, .32), Color("#b0cfc0"))
		_bar("room", f, x0 - .007, .21, z - .17, Vector3(.012, .32, .32), Color("#aaccba"))
		_bar("steel", f, x0 - .02, .55, z - .17, Vector3(.016, .02, .1), CHROME)
		_bar("steel", f, x0 - .02, .24, z - .17, Vector3(.016, .02, .1), CHROME)
		z -= .36
	for centre: float in [-2.05, -3.95]:
		_basin(f * Vector3(x, .84, centre))
		var high := 2.3
		var low := 1.0
		var a := centre + .85
		var b := centre - .85
		var at := RX1 - .012
		var flip := _cell(420, 800, 560, 420)
		if centre < -3.0:
			flip = Rect2(flip.end.x, flip.position.y, -flip.size.x, flip.size.y)
		_kit.atlas("display", f * Vector3(at, low, b), f * Vector3(at, high, b), f * Vector3(at, high, a), f * Vector3(at, low, a), flip)
		var frame := Color("#231a15")
		_bar("room", f, at - .012, high + .03, centre, Vector3(.036, .07, 1.78), frame)
		_bar("room", f, at - .012, low - .02, centre, Vector3(.036, .05, 1.78), frame)
		_bar("room", f, at - .012, (low + high) * .5, a + .02, Vector3(.036, high - low + .1, .05), frame)
		_bar("room", f, at - .012, (low + high) * .5, b - .02, Vector3(.036, high - low + .1, .05), frame)
		# The strip of glass under each mirror, thick with what the morning uses.
		_kit.block("steel", _at(f, RX1 - .08, .99, centre), Vector3(.13, .012, 1.6), Color("#9fb6b0"))
		var dot := centre + .72
		while dot > centre - .75:
			if _rng.randf() > .25:
				_tonic(f * Vector3(RX1 - .08, .996, dot))
			dot -= _rng.randf_range(.1, .16)
	# Long tonic shelf over both mirrors.
	_bar("room", f, RX1 - .09, 2.385, middle, Vector3(.18, .03, run), Color("#6a4a34"))
	for bracket: float in [near - .3, middle, far + .3]:
		_bar("room", f, RX1 - .05, 2.35, bracket, Vector3(.1, .05, .03), Color("#4a3628"))
	var along := near - .06
	while along > far + .06:
		_tonic(f * Vector3(RX1 - .09, 2.4, along))
		along -= _rng.randf_range(.085, .13)
	# Hand tools on the counter: clipper block, brush mug, a folded strop on its hook.
	_kit.lathe("room", f * Vector3(x - .1, .84, -3.0), [Vector2(.05, 0), Vector2(.055, .02), Vector2(.055, .1), Vector2(.05, .1)], Color("#efece0"), 10)
	_kit.lathe("room", f * Vector3(x - .1, .9, -3.0), [Vector2(.018, 0), Vector2(.02, .08), Vector2(.05, .1), Vector2(.052, .15), Vector2(0, .17)], Color("#6a3c22"), 8)
	_bar("room", f, x + .1, .88, -2.98, Vector3(.1, .06, .22), Color("#25262a"))
	_bar("room", f, RX1 - .02, 1.0, -3.0, Vector3(.02, .4, .05), Color("#6a4326"))

func _basin(at: Vector3) -> void:
	# Porcelain basin set into the top, with a swan-neck tap on the mirror side.
	_kit.lathe("room", at, [Vector2(.17, .0), Vector2(.2, .02), Vector2(.2, .045), Vector2(.17, .05), Vector2(.14, .02), Vector2(.03, .005)], Color("#eae7dc"), 14)
	_kit.tube("steel", [at + Vector3(.2, .02, 0), at + Vector3(.2, .2, 0), at + Vector3(.13, .24, 0), at + Vector3(.07, .19, 0)], .011, CHROME, 6)
	for side: float in [-.09, .09]:
		_kit.lathe("steel", at + Vector3(.2, .02, side), [Vector2(.016, 0), Vector2(.016, .05), Vector2(.03, .06), Vector2(.012, .09)], CHROME, 6)
	# The rubber spray hose, looped on its hook.
	_kit.tube("plain", [at + Vector3(.21, .02, .2), at + Vector3(.23, .3, .23), at + Vector3(.21, .4, .18), at + Vector3(.2, .3, .13), at + Vector3(.14, .06, .16)], .009, Color("#22242a"), 5)

func _tonic(base: Vector3) -> void:
	# One bottle: shoulders, neck and a coloured cap. Six kinds, none of them bought since 2030.
	var kinds: Array[Color] = [Color("#7a4a18"), Color("#3e6a4a"), Color("#3a5a8a"), Color("#d8d4c0"), Color("#8e2a22"), Color("#c9a24a")]
	var body := kinds[_rng.randi() % kinds.size()]
	var tall := _rng.randf_range(.12, .2)
	var r := _rng.randf_range(.024, .036)
	var square := _rng.randf() < .3
	_kit.lathe("vial", base, [Vector2(r * .9, 0), Vector2(r, .01), Vector2(r, tall * .7), Vector2(r * .45, tall * .84), Vector2(r * .4, tall)], body, 4 if square else 7)
	_kit.lathe("room", base + Vector3.UP * tall, [Vector2(r * .46, 0), Vector2(r * .46, .02), Vector2(0, .024)], [Color("#e4dfd0"), Color("#222222"), Color("#b02a22")][_rng.randi() % 3], 6)
	_kit.quad("room", base + Vector3(-r - .001, tall * .16, r * .7), base + Vector3(-r - .001, tall * .56, r * .7), base + Vector3(-r - .001, tall * .56, -r * .7), base + Vector3(-r - .001, tall * .16, -r * .7), Color("#e8e0c8"))

func _chair(at: Vector3, tilt: float, laid: bool) -> void:
	# A heavy hydraulic chair: chrome dish, enamel carriage, oxblood vinyl, a footplate worn
	# bright. tilt is the back's lean from upright, in radians.
	var xf := Transform3D(Basis(Vector3.UP, PI * .5), at)
	_kit.lathe("steel", at, [Vector2(.3, 0), Vector2(.29, .02), Vector2(.13, .06), Vector2(.09, .1), Vector2(.085, .36), Vector2(.12, .4)], CHROME, 14)
	_kit.lathe("room", at + Vector3.UP * .4, [Vector2(.12, 0), Vector2(.2, .03), Vector2(.2, .08), Vector2(.1, .1)], ENAMEL, 12)
	_pad("room", xf * Transform3D(Basis.IDENTITY, Vector3(0, .54, 0)), Vector3(.56, .1, .56), ENAMEL)
	_pad("vinyl", xf * Transform3D(Basis.IDENTITY, Vector3(0, .65, .01)), Vector3(.5, .15, .54), OXBLOOD)
	_kit.tube("vinyl", [xf * Vector3(-.2, .725, .27), xf * Vector3(.2, .725, .27)], .012, Color("#7a3a34"), 5)
	# Back, its enamel shell, the headrest on a chrome stem.
	var back := xf * Transform3D(Basis(Vector3.RIGHT, -tilt), Vector3(0, .68, -.25))
	_pad("vinyl", back * Transform3D(Basis.IDENTITY, Vector3(0, .32, .02)), Vector3(.48, .68, .13), OXBLOOD)
	_pad("room", back * Transform3D(Basis.IDENTITY, Vector3(0, .31, -.07)), Vector3(.52, .72, .07), ENAMEL)
	for rib: float in [.14, .28, .42]:
		_kit.tube("vinyl", [back * Vector3(-.21, rib + .03, .09), back * Vector3(.21, rib + .03, .09)], .008, Color("#472020"), 4)
	_kit.tube("steel", [back * Vector3(0, .62, -.04), back * Vector3(0, .8, -.03)], .014, CHROME, 6)
	var head := back * Transform3D(Basis.IDENTITY, Vector3(0, .84, .01))
	_pad("vinyl", head, Vector3(.28, .15, .1), OXBLOOD)
	_pad("towel", head * Transform3D(Basis.IDENTITY, Vector3(0, .0, .055)), Vector3(.24, .12, .025), Color("#efece0"))
	# Leg rest, swung up on the reclined chair, and its footplate.
	var drop := 1.25 if laid else .34
	var leg := xf * Transform3D(Basis(Vector3.RIGHT, -drop), Vector3(0, .62, .28))
	_pad("vinyl", leg * Transform3D(Basis.IDENTITY, Vector3(0, -.22, 0)), Vector3(.44, .44, .11), OXBLOOD)
	var plate := leg * Transform3D(Basis.IDENTITY, Vector3(0, -.5, .07))
	_kit.block("steel", plate, Vector3(.42, .02, .24), Color("#a6aaac"))
	for i: int in range(5):
		_kit.block("steel", plate * Transform3D(Basis.IDENTITY, Vector3(0, .014, -.08 + float(i) * .04)), Vector3(.38, .008, .01), Color("#dfe2e2"))
	# Arms on chrome stanchions, with side cheeks of enamel.
	for side: float in [-1.0, 1.0]:
		_pad("room", xf * Transform3D(Basis.IDENTITY, Vector3(side * .29, .6, 0)), Vector3(.05, .24, .5), ENAMEL)
		_pad("vinyl", xf * Transform3D(Basis.IDENTITY, Vector3(side * .315, .86, .03)), Vector3(.08, .055, .44), OXBLOOD)
		_kit.tube("steel", [xf * Vector3(side * .3, .7, .18), xf * Vector3(side * .315, .84, .19)], .013, CHROME, 6)
		_kit.tube("steel", [xf * Vector3(side * .3, .7, -.15), xf * Vector3(side * .315, .84, -.13)], .013, CHROME, 6)
	# Pump lever on the operator's side.
	_kit.tube("steel", [xf * Vector3(.22, .22, 0), xf * Vector3(.42, .28, .04), xf * Vector3(.46, .52, .04)], .012, CHROME, 6)
	_kit.lathe("steel", xf * Vector3(.46, .52, .04), [Vector2(.012, 0), Vector2(.03, .02), Vector2(.03, .05), Vector2(.01, .07)], Color("#22242a"), 8)

func _trolley(at: Vector3) -> void:
	# Two wire trays on castors, with clippers and combs dumped in the top one.
	var top := .86
	for dx: float in [-.15, .15]:
		for dz: float in [-.17, .17]:
			_kit.tube("steel", [at + Vector3(dx, .05, dz), at + Vector3(dx, top + .05, dz)], .009, CHROME, 5)
			_kit.lathe("plain", at + Vector3(dx, 0, dz), [Vector2(.022, 0), Vector2(.024, .03), Vector2(.012, .05)], Color("#1c1c1e"), 6)
	for y: float in [.4, top]:
		_kit.block("steel", Transform3D(Basis.IDENTITY, at + Vector3(0, y, 0)), Vector3(.32, .012, .36), Color("#9da1a3"))
		for dz: float in [-.17, .17]:
			_kit.tube("steel", [at + Vector3(-.16, y + .04, dz), at + Vector3(.16, y + .04, dz)], .006, CHROME, 4)
		for dx: float in [-.16, .16]:
			_kit.tube("steel", [at + Vector3(dx, y + .04, -.18), at + Vector3(dx, y + .04, .18)], .006, CHROME, 4)
	_kit.block("room", Transform3D(Basis(Vector3.UP, .5), at + Vector3(-.06, top + .03, .05)), Vector3(.06, .05, .17), Color("#1f2024"))
	_kit.block("room", Transform3D(Basis(Vector3.UP, -.4), at + Vector3(.07, top + .018, -.06)), Vector3(.03, .01, .18), Color("#2a1e16"))
	_kit.block("steel", Transform3D(Basis(Vector3.UP, 1.1), at + Vector3(.06, top + .02, .1)), Vector3(.02, .012, .14), CHROME)
	_pad("towel", Transform3D(Basis.IDENTITY, at + Vector3(0, .45, 0)), Vector3(.26, .08, .28), Color("#e4e0d0"))

func _towel_wall() -> void:
	# Open shelves floor to lintel, every towel the shop owns, boiled grey-pink over forty years.
	var f := _front
	var x0 := .92
	var x1 := 3.22
	var depth := .34
	var z := -ROOM_DEEP + depth * .5 + .01
	var shelf := Color("#7f9c8e")
	var tones: Array[Color] = [Color("#ece8da"), Color("#e2dccb"), Color("#d6cfc0"), Color("#d8b8b0"), Color("#b4cfc0"), Color("#efece2"), Color("#c8c4b8")]
	_bar("room", f, (x0 + x1) * .5, .28, z, Vector3(x1 - x0, .56, depth), Color("#8fb09f"))
	for door: float in [x0 + .56, x0 + 1.72]:
		_bar("room", f, door, .29, z + depth * .5 + .006, Vector3(1.08, .48, .012), Color("#a8c8b8"))
		_bar("steel", f, door, .42, z + depth * .5 + .02, Vector3(.1, .018, .018), CHROME)
	for level: int in range(4):
		var y := .58 + float(level) * .46
		_bar("room", f, (x0 + x1) * .5, y, z, Vector3(x1 - x0, .024, depth), shelf)
		var x := x0 + .09
		while x < x1 - .34:
			var wide := _rng.randf_range(.36, .44)
			var fold := _rng.randf_range(.042, .052)
			var tone := tones[_rng.randi() % tones.size()]
			var h := y + .012
			for t: int in range(_rng.randi_range(5, 7)):
				var shift := _rng.randf_range(-.012, .012)
				_pad("towel", _at(f, x + wide * .5 + shift, h + fold * .5, z + shift), Vector3(wide, fold, depth - .06), tone.darkened(_rng.randf_range(0.0, .08)))
				h += fold
			x += wide + .03
	_bar("room", f, (x0 + x1) * .5, 2.42, z, Vector3(x1 - x0, .024, depth), shelf)
	for x: float in [x0, (x0 + x1) * .5, x1]:
		_bar("room", f, x, 1.44, z, Vector3(.03, 2.0, depth), shelf)
	# The steamer on top, chrome box and all, and yesterday's towels hung on the end rail.
	_bar("steel", f, 2.7, 2.5, z, Vector3(.38, .13, .26), Color("#b8bcbc"))
	_bar("led", f, 2.58, 2.5, z + .135, Vector3(.03, .03, .01), Color(1.0, .3, .2))
	for i: int in range(3):
		var y := 1.9
		var left := x1 + .03 + float(i) * .012
		_kit.quad("towel", f * Vector3(left, y - .6, z + .17 + float(i) * .03), f * Vector3(left, y, z + .17 + float(i) * .03), f * Vector3(left, y, z - .12 + float(i) * .03), f * Vector3(left, y - .6, z - .12 + float(i) * .03), tones[i * 2])
		_kit.quad("towel", f * Vector3(left, y - .6, z - .12 + float(i) * .03), f * Vector3(left, y, z - .12 + float(i) * .03), f * Vector3(left, y, z + .17 + float(i) * .03), f * Vector3(left, y - .6, z + .17 + float(i) * .03), tones[i * 2])

func _bench() -> void:
	# Waiting bench down the west wall: split vinyl, chrome legs, the weekly's back issues above.
	var f := _front
	var x := RX0 + .24
	var near := -1.9
	var far := -4.2
	var run := near - far
	var middle := (near + far) * .5
	var seat := Color("#4a6a62")
	_pad("vinyl", _at(f, x, .45, middle), Vector3(.44, .1, run), seat)
	_pad("vinyl", _at(f, RX0 + .05, .78, middle), Vector3(.07, .48, run), seat)
	_bar("steel", f, x, .39, middle, Vector3(.4, .02, run - .04), CHROME)
	for z: float in [near - .1, middle, far + .1]:
		_kit.tube("steel", [f * Vector3(x - .16, .39, z), f * Vector3(x - .17, .04, z)], .012, CHROME, 5)
		_kit.tube("steel", [f * Vector3(x + .16, .39, z), f * Vector3(x + .17, .04, z)], .012, CHROME, 5)
	# Loose copies, as left by the last customer.
	var tones: Array[Color] = [Color("#c23a2a"), Color("#e0b83c"), Color("#3a6ea8"), Color("#e8e2d2")]
	var h := .505
	for i: int in range(4):
		_kit.block("room", Transform3D(Basis(Vector3.UP, _rng.randf_range(-.3, .3)), f * Vector3(x + .02, h, -3.5)), Vector3(.19, .018, .13), tones[i])
		h += .018
	_kit.block("room", Transform3D(Basis(Vector3.UP, .8), f * Vector3(x, .505, -2.3)), Vector3(.19, .02, .13), tones[2])
	# Long shelf over the bench.
	var at := RX0 + .1
	_bar("room", f, at, 1.54, middle, Vector3(.2, .03, run), Color("#7a5a3e"))
	for z: float in [near - .2, far + .2]:
		_bar("room", f, RX0 + .05, 1.5, z, Vector3(.1, .06, .03), Color("#5a4230"))
	_spine_run(at + .05, 1.555, near - .06, -3.05, 0)
	_spine_run(at + .05, 1.555, -3.1, far + .1, 1)
	# Low manga case past the bench, and the back issues nobody has the heart to bin.
	var case_x := RX0 + .15
	_bar("room", f, case_x, .48, -4.92, Vector3(.3, .96, 1.04), Color("#6a4a34"))
	for y: float in [.1, .41, .72]:
		_kit.quad("plain", f * Vector3(RX0 + .3, y, -4.42), f * Vector3(RX0 + .3, y + .26, -4.42), f * Vector3(RX0 + .3, y + .26, -5.42), f * Vector3(RX0 + .3, y, -5.42), Color("#16120e"))
		_kit.atlas("display", f * Vector3(RX0 + .304, y, -4.43), f * Vector3(RX0 + .304, y + .25, -4.43), f * Vector3(RX0 + .304, y + .25, -5.41), f * Vector3(RX0 + .304, y, -5.41), _cell(1300, 804 if int(y * 10.0) % 2 == 0 else 902, 470, 92))
	# Frames high on the wall, the licence first; price list where the door faces it.
	_panel_side(RX0 + .006, 1.72, 2.34, -1.9, -4.1, _cell(1300, 1020, 480, 180))
	_panel_side(RX0 + .006, 1.28, 1.48, -4.4, -4.9, _cell(790, 1240, 170, 170))
	_panel("display", f, .24, .8, 1.5, 2.28, -ROOM_DEEP + .012, _cell(990, 800, 300, 420))
	_panel("display", f, .3, .8, .78, 1.42, -ROOM_DEEP + .012, _cell(540, 1430, 300, 400))
	var clock := f * Vector3(RX0 + .01, 2.42, -3.0)
	_kit.disc("room", clock, Vector3.BACK, Vector3.UP, .13, Color("#efe9d6"))
	_kit.tube("plain", [clock + Vector3(.006, 0, 0), clock + Vector3(.006, .09, .01)], .004, Color("#222222"), 3)
	_kit.tube("plain", [clock + Vector3(.006, 0, 0), clock + Vector3(.006, -.02, .07)], .005, Color("#222222"), 3)

func _spine_run(x: float, y: float, near: float, far: float, row: int) -> void:
	var f := _front
	var rect := _cell(1300, 804.0 + float(row) * 98.0, 470, 92)
	_bar("room", f, x - .1, y + .11, (near + far) * .5, Vector3(.1, .22, near - far), Color("#1a1612"))
	_kit.atlas("display", f * Vector3(x, y, near), f * Vector3(x, y + .22, near), f * Vector3(x, y + .22, far), f * Vector3(x, y, far), rect)

func _panel_side(x: float, y0: float, y1: float, near: float, far: float, rect: Rect2) -> void:
	var f := _front
	_kit.atlas("display", f * Vector3(x, y0, near), f * Vector3(x, y1, near), f * Vector3(x, y1, far), f * Vector3(x, y0, far), rect)

func _shop_window() -> void:
	# Big fixed light in painted timber, a narrow upper light, and a glass shelf of old stock.
	var f := _front
	var r := WINDOW
	var top := 2.06
	var z := -.1
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, z), f * Vector3(r.position.x, r.end.y, z), f * Vector3(r.end.x, r.end.y, z), f * Vector3(r.end.x, r.position.y, z), Color.WHITE)
	for x: float in [r.position.x + .03, r.end.x - .03]:
		_bar("wood", f, x, r.get_center().y, -.07, Vector3(.06, r.size.y, .07), PAINT)
	for y: float in [r.position.y + .03, top, r.end.y - .03]:
		_bar("wood", f, r.get_center().x, y, -.07, Vector3(r.size.x, .06, .07), PAINT)
	_bar("wood", f, r.get_center().x, r.position.y - .02, .03, Vector3(r.size.x + .08, .04, .14), PAINT * .95)
	_panel("decal", f, r.position.x + .08, r.end.x - .08, 1.72, 2.0, -.098, _cell(1060, 1240, 700, 150))
	_panel("decal", f, r.position.x + .08, r.position.x + .28, .72, .92, -.098, _cell(790, 1240, 170, 170))
	_panel("display", f, r.end.x - .36, r.end.x - .08, .7, .9, -.11, _cell(540, 1240, 230, 170))
	# Window bottom: a mint board, then the display a salon keeps for nobody.
	_bar("room", f, r.get_center().x, .6, -.42, Vector3(r.size.x, .03, .56), Color("#c4d8ca"))
	_bar("room", f, r.get_center().x, .3, -.7, Vector3(r.size.x, .6, .03), Color("#9cbfae"))
	var shelf_y := 1.22
	_kit.block("steel", _at(f, r.get_center().x, shelf_y, -.34), Vector3(r.size.x - .1, .012, .3), Color("#a9c0ba"))
	for x: float in [r.position.x + .12, r.end.x - .12]:
		_kit.tube("steel", [f * Vector3(x, .62, -.44), f * Vector3(x, shelf_y, -.44)], .008, CHROME, 5)
	# Goblets and a swan from the customers' gifts (the photographed window had the same), tonics.
	for x: float in [2.72, 3.46]:
		_kit.lathe("room", f * Vector3(x, .615, -.34), [Vector2(.05, 0), Vector2(.02, .03), Vector2(.018, .08), Vector2(.05, .12), Vector2(.06, .17), Vector2(.05, .17), Vector2(.03, .13)], Color("#d8e8dc"), 10)
	_ball(f * Vector3(3.08, .68, -.34), Vector3(.1, .06, .06), Color("#e4ece4"), "room", 5, 8)
	_kit.tube("room", [f * Vector3(3.16, .7, -.34), f * Vector3(3.2, .78, -.34), f * Vector3(3.18, .84, -.34), f * Vector3(3.13, .83, -.34)], .012, Color("#e4ece4"), 5)
	var x2 := r.position.x + .16
	while x2 < r.end.x - .16:
		_tonic(f * Vector3(x2, shelf_y + .008, -.34))
		x2 += _rng.randf_range(.12, .2)
	_bar("lamp", f, r.get_center().x, r.end.y - .1, -.3, Vector3(r.size.x - .2, .02, .03), Color(.95, .88, .7))

func _door() -> void:
	# Single leaf in mint timber with a brass bar, the shop's name in gold on the glass.
	var f := _front
	var r := DOOR
	var z := -.1
	_kit.quad("front", f * Vector3(r.position.x, .36, z), f * Vector3(r.position.x, r.end.y, z), f * Vector3(r.end.x, r.end.y, z), f * Vector3(r.end.x, .36, z), Color.WHITE)
	_bar("wood", f, r.get_center().x, .2, -.1, Vector3(r.size.x, .36, .05), PAINT * .94)
	for x: float in [r.position.x + .04, r.end.x - .04]:
		_bar("wood", f, x, r.get_center().y, -.09, Vector3(.08, r.size.y, .06), PAINT)
	_bar("wood", f, r.get_center().x, r.end.y - .04, -.09, Vector3(r.size.x, .08, .06), PAINT)
	_bar("wood", f, r.get_center().x, r.end.y + .02, -.09, Vector3(r.size.x, .05, .08), PAINT * .9)
	_bar("wood", f, r.get_center().x, .39, -.09, Vector3(r.size.x, .06, .06), PAINT)
	# Pebbled glass in the transom, a slot of light.
	_kit.quad("display", f * Vector3(TRANSOM.position.x, TRANSOM.position.y, -.12), f * Vector3(TRANSOM.position.x, TRANSOM.end.y, -.12), f * Vector3(TRANSOM.end.x, TRANSOM.end.y, -.12), f * Vector3(TRANSOM.end.x, TRANSOM.position.y, -.12), Color.WHITE)
	_bar("metal", f, r.get_center().x, 1.02, -.04, Vector3(.6, .026, .026), Color("#a88a4a"))
	for x: float in [r.get_center().x - .26, r.get_center().x + .26]:
		_bar("metal", f, x, 1.02, -.06, Vector3(.02, .02, .05), Color("#a88a4a"))
	_panel("decal", f, r.position.x + .13, r.end.x - .13, 1.5, 1.74 + .02, -.098, _cell(0, 1410, 520, 210))
	# Two steps' worth of concrete and a rubber mat.
	_bar("plain", f, r.get_center().x, .04, .14, Vector3(r.size.x + .1, .08, .32), Color("#6a6a64"), .8, 1.0)
	_bar("plain", f, r.get_center().x, .092, .13, Vector3(.7, .02, .24), Color("#25231f"))
	# Red post box, and the palm pad wired in beside it for when the owner's asleep upstairs.
	_bar("plain", f, 1.05, 1.42, .08, Vector3(.2, .28, .13), Color("#a82418"))
	_bar("plain", f, 1.05, 1.57, .08, Vector3(.23, .02, .16), Color("#8a1e14"))
	_bar("plain", f, 1.05, 1.46, .147, Vector3(.13, .015, .004), Color("#2a120e"))
	_bar("metal", f, 1.05, 1.05, .02, Vector3(.1, .14, .04), Color("#26282c"))
	_bar("led", f, 1.05, 1.07, .042, Vector3(.06, .08, .004), CYAN * .55)

func _kiosk() -> void:
	# たばこ in the splayed corner: glass case below, sliding hatch above, a stool and a radio.
	var c := _corner
	var long := _splay
	_mosaic(c, Rect2(0, 0, long, SHOP_TOP), [Rect2(HATCH.position.x, CASE.position.y, HATCH.size.x, HATCH.end.y - CASE.position.y)])
	_kit.quad("plain", c * Vector3(0, 0, .008), c * Vector3(0, .13, .008), c * Vector3(long, .13, .008), c * Vector3(long, 0, .008), Color("#4a504c"), .7, .9)
	var deep := -.78
	var x0 := .06
	var x1 := long - .06
	var top := 2.38
	var wall := Color("#d8cfb6")
	_kit.quad("room", c * Vector3(x0, 0, deep), c * Vector3(x0, top, deep), c * Vector3(x1, top, deep), c * Vector3(x1, 0, deep), wall, .7, .9)
	_kit.quad("room", c * Vector3(x0, 0, 0), c * Vector3(x0, top, 0), c * Vector3(x0, top, deep), c * Vector3(x0, 0, deep), wall, .7, .85)
	_kit.quad("room", c * Vector3(x1, 0, deep), c * Vector3(x1, top, deep), c * Vector3(x1, top, 0), c * Vector3(x1, 0, 0), wall, .7, .85)
	_kit.quad("room", c * Vector3(x0, top, deep), c * Vector3(x0, top, 0), c * Vector3(x1, top, 0), c * Vector3(x1, top, deep), Color("#c9c0a6"), .8, .8)
	_kit.quad("room", c * Vector3(x0, .03, 0), c * Vector3(x0, .03, deep), c * Vector3(x1, .03, deep), c * Vector3(x1, .03, 0), Color("#5a5650"), .7, .7)
	# Its outside: the booth's back, as the barber's customers see it.
	var out_z := deep - .012
	var wx0 := x1 + .02
	var wx1 := x0 - .02
	_kit.quad("room", c * Vector3(wx0, 0, out_z), c * Vector3(wx0, 1.14, out_z), c * Vector3(wx1, 1.14, out_z), c * Vector3(wx1, 0, out_z), Color("#9fc2b0"), .6, .95)
	_kit.quad("room", c * Vector3(wx0, 1.14, out_z), c * Vector3(wx0, ROOM_TOP, out_z), c * Vector3(wx1, ROOM_TOP, out_z), c * Vector3(wx1, 1.14, out_z), Color("#e4dcc4"), .95, .8)
	_kit.quad("room", c * Vector3(long + .01, 0, deep), c * Vector3(long + .01, ROOM_TOP, deep), c * Vector3(long + .01, ROOM_TOP, -.02), c * Vector3(long + .01, 0, -.02), Color("#b4cabc"), .7, .9)
	# Wall of packs, a fine lip on each row of its shelf.
	_panel("display", c, x0 + .02, x1 - .02, 1.02, 2.3, deep + .01, _cell(1010, 250, 520, 400))
	_kit.atlas("display", c * Vector3(x0 + .006, 1.36, -.1), c * Vector3(x0 + .006, 2.02, -.1), c * Vector3(x0 + .006, 2.02, -.56), c * Vector3(x0 + .006, 1.36, -.56), _cell(1540, 250, 240, 340))
	for i: int in range(3):
		_bar("room", c, long * .5, 1.42 + float(i) * .3, deep + .03, Vector3(long - .16, .012, .05), Color("#a89878"))
	# The case: lit, shelved, cartons on its back and a glass front.
	_kit.quad("front", c * Vector3(CASE.position.x, CASE.position.y, -.03), c * Vector3(CASE.position.x, CASE.end.y, -.03), c * Vector3(CASE.end.x, CASE.end.y, -.03), c * Vector3(CASE.end.x, CASE.position.y, -.03), Color.WHITE)
	_panel("display", c, CASE.position.x, CASE.end.x, CASE.position.y, CASE.end.y, -.44, _cell(500, 520, 500, 250))
	_kit.quad("room", c * Vector3(CASE.position.x, CASE.position.y, -.03), c * Vector3(CASE.position.x, CASE.position.y, -.44), c * Vector3(CASE.end.x, CASE.position.y, -.44), c * Vector3(CASE.end.x, CASE.position.y, -.03), Color("#c8bfa4"))
	_kit.block("steel", _at(c, long * .5, .54, -.2), Vector3(CASE.size.x, .01, .36), Color("#b5cac4"))
	_bar("lamp", c, long * .5, CASE.end.y - .02, -.2, Vector3(CASE.size.x - .1, .015, .02), Color(.95, .9, .74))
	for i: int in range(9):
		var x := CASE.position.x + .08 + float(i) * .115
		var tone: Color = [Color("#b02a22"), Color("#1d3f7a"), Color("#e9d9b0"), Color("#2f6a58")][i % 4]
		_kit.block("room", _at(c, x, .3, -.2), Vector3(.1, .1, .16), tone)
		if i % 2 == 0:
			_kit.block("room", _at(c, x, .6, -.2), Vector3(.1, .1, .16), tone.lightened(.1))
	for x: float in [CASE.position.x, CASE.end.x]:
		_bar("wood", c, x, CASE.get_center().y, -.02, Vector3(.04, CASE.size.y + .04, .06), PAINT)
	_bar("wood", c, CASE.get_center().x, CASE.position.y - .01, -.02, Vector3(CASE.size.x + .04, .04, .06), PAINT)
	# Counter, its worn brass edge, the rubber coin mat, the palm reader the union made them fit.
	_bar("room", c, long * .5, .92, -.14, Vector3(long - .08, .04, .86), Color("#b9a988"))
	_bar("metal", c, long * .5, .92, .29, Vector3(long - .06, .05, .016), Color("#a88a4a"))
	_kit.block("plain", _at(c, .7, .943, .12), Vector3(.3, .008, .22), Color("#2a4a3e"))
	_bar("metal", c, .28, .975, .1, Vector3(.13, .07, .17), Color("#26282c"))
	_bar("led", c, .28, 1.01, .1, Vector3(.09, .004, .12), CYAN * .5)
	# Hatch: two glass leaves pushed to the left, with the gap you buy through.
	var y0 := HATCH.position.y
	var y1 := HATCH.end.y
	var open_left := HATCH.position.x
	var open_mid := .68
	_kit.quad("front", c * Vector3(open_left, y0, -.03), c * Vector3(open_left, y1, -.03), c * Vector3(open_mid, y1, -.03), c * Vector3(open_mid, y0, -.03), Color.WHITE)
	_kit.quad("front", c * Vector3(open_left + .03, y0, -.06), c * Vector3(open_left + .03, y1, -.06), c * Vector3(open_mid + .03, y1, -.06), c * Vector3(open_mid + .03, y0, -.06), Color.WHITE)
	for x: float in [open_left + .02, open_mid, open_mid + .03]:
		_bar("wood", c, x, HATCH.get_center().y, -.045, Vector3(.035, HATCH.size.y, .03), PAINT)
	for y: float in [y0 + .015, y1 - .015]:
		_bar("wood", c, HATCH.get_center().x, y, -.045, Vector3(HATCH.size.x, .03, .06), PAINT * .9)
	_bar("wood", c, HATCH.end.x, HATCH.get_center().y, -.03, Vector3(.04, HATCH.size.y, .08), PAINT)
	# Attendant's stool, radio and a nodding cat on the sill: as the shop photographs have them.
	_kit.lathe("room", c * Vector3(.8, .03, -.6), [Vector2(.14, 0), Vector2(.02, .03), Vector2(.02, .5), Vector2(.15, .52), Vector2(.15, .58), Vector2(0, .6)], Color("#5e2a26"), 10)
	_bar("room", c, .3, 1.02, -.38, Vector3(.24, .15, .08), Color("#6a4a34"))
	_kit.disc("room", c * Vector3(.26, 1.02, -.336), Vector3(c.basis.x), Vector3.UP, .05, Color("#2a2a2a"))
	_ball(c * Vector3(.84, .99, -.1), Vector3(.05, .05, .04), Color("#d8a058"), "room", 5, 8)
	_ball(c * Vector3(.84, 1.06, -.09), Vector3(.035, .035, .03), Color("#d8a058"), "room", 5, 8)
	_bar("lamp", c, long * .5, top - .02, -.42, Vector3(.7, .02, .04), Color(.96, .9, .72))
	# Yellow 宝くじ board over the hatch, with the enamel plate around the corner.
	_bar("metal", c, long * .5, 2.27, .02, Vector3(1.1, .24, .04), Color("#3a3a38"))
	_panel("sign", c, long * .5 - .53, long * .5 + .53, 2.16, 2.38, .044, _cell(500, 390, 500, 120))
	var w := _west
	var at := DEEP - CUT - .1
	_bar("metal", w, at - .22, 1.5, .012, Vector3(.42, 1.02, .02), Color("#30302e"))
	_panel("board", w, at - .42, at - .02, 1.02, 1.98, .024, _cell(270, 250, 220, 540))

func _fascia() -> void:
	# A painted board under its own sheet-metal hood, reaching the awning's top line.
	var f := _front
	var c := _corner
	_bar("wood", f, (1.04 + WIDE) * .5, 3.0, .05, Vector3(WIDE - 1.04, .56, .1), Color("#71988a"), .85, 1.0)
	_panel("sign", f, 1.08, WIDE - .05, 2.76, 3.24, .104, _cell(0, 0, 1400, 230))
	_bar("metal", f, (1.04 + WIDE) * .5, 3.29, .08, Vector3(WIDE - 1.04, .03, .18), Color("#5c7268"))
	_kit.quad("lamp", f * Vector3(1.6, 2.74, .1), f * Vector3(1.6, 2.74, .02), f * Vector3(3.8, 2.74, .02), f * Vector3(3.8, 2.74, .1), Color(1.0, .86, .62))
	# Plain mortar between the shop and the upper boards where the fascia stops.
	for piece: Array in [[f, CUT, 1.04], [c, 0.0, _splay]]:
		var face: Transform3D = piece[0]
		var p0: float = piece[1]
		var p1: float = piece[2]
		_kit.quad("mortar", face * Vector3(p0, SHOP_TOP, 0), face * Vector3(p0, GROUND, 0), face * Vector3(p1, GROUND, 0), face * Vector3(p1, SHOP_TOP, 0), MINT, .85, 1.0, .7, Vector2(p0 * .7, .2))
	_kit.quad("mortar", f * Vector3(1.04, SHOP_TOP, 0), f * Vector3(1.04, GROUND, 0), f * Vector3(WIDE, GROUND, 0), f * Vector3(WIDE, SHOP_TOP, 0), MINT, .85, 1.0, .7)

func _awning() -> void:
	# Striped canvas over door and window, mint and bone, and a short red one for the hatch.
	var f := _front
	var c := _corner
	var left := 1.12
	var right := WIDE - .04
	var count := int((right - left) / .19)
	var hi := 2.72
	var lo := 2.4
	var out := .66
	for i: int in range(count):
		var x0 := lerpf(left, right, float(i) / float(count))
		var x1 := lerpf(left, right, float(i + 1) / float(count))
		var tone: Color = Color("#7fae9a") if i % 2 == 0 else Color("#e5dfcc")
		tone = tone.darkened(_rng.randf_range(0.0, .1))
		_kit.quad("cloth", f * Vector3(x0, lo, out), f * Vector3(x0, hi, .02), f * Vector3(x1, hi, .02), f * Vector3(x1, lo, out), tone, .9, 1.0)
		_kit.quad("cloth", f * Vector3(x0, lo - .15, out + .012), f * Vector3(x0, lo, out), f * Vector3(x1, lo, out), f * Vector3(x1, lo - .15, out + .012), tone.darkened(.06), .85, 1.0)
		_kit.quad("cloth", f * Vector3(x1, hi, .02), f * Vector3(x0, hi, .02), f * Vector3(x0, lo, out), f * Vector3(x1, lo, out), tone.darkened(.35), .6, .7)
	_kit.tube("metal", [f * Vector3(left, lo, out), f * Vector3(right, lo, out)], .01, ALUMINIUM, 4)
	for x: float in [left, (left + right) * .5, right]:
		_kit.tube("metal", [f * Vector3(x, lo, out), f * Vector3(x, hi - .28, .02)], .009, ALUMINIUM, 4)
	var red := Color("#b5281e")
	_kit.quad("plain", c * Vector3(0, 2.43, .6), c * Vector3(0, 2.73, 0), c * Vector3(_splay, 2.73, 0), c * Vector3(_splay, 2.43, .6), Color(.72, .2, .16), .9, 1.0)
	_kit.atlas("board", c * Vector3(0, 2.26, .612), c * Vector3(0, 2.43, .6), c * Vector3(_splay, 2.43, .6), c * Vector3(_splay, 2.26, .612), _cell(500, 250, 500, 130))
	_kit.quad("plain", c * Vector3(_splay, 2.73, 0), c * Vector3(0, 2.73, 0), c * Vector3(0, 2.43, .6), c * Vector3(_splay, 2.43, .6), red.darkened(.4), .6, .7)
	for x: float in [0.0, _splay]:
		_kit.quad("plain", c * Vector3(x, 2.43, .6), c * Vector3(x, 2.73, 0), c * Vector3(x, 2.26, 0), c * Vector3(x, 2.26, .6), red.darkened(.15), .8, .9)
		_kit.quad("plain", c * Vector3(x, 2.26, 0), c * Vector3(x, 2.73, 0), c * Vector3(x, 2.43, .6), c * Vector3(x, 2.26, .6), red.darkened(.3), .8, .9)

func _pole() -> void:
	# サインポール on its own tapered post, glass flutes, milk-glass cap, as in the photographed
	# one. Everything here is fixed: the striped drum inside turns on its own node.
	var at := _front * Vector3(POLE_X, 0, POLE_Z)
	var cream := Color("#e4dcc4")
	_kit.lathe("plain", at, [Vector2(.13, 0), Vector2(.12, .04), Vector2(.05, .08), Vector2(.05, .44), Vector2(.075, .92)], cream, 10)
	_kit.lathe("metal", at + Vector3.UP * .9, [Vector2(.1, 0), Vector2(.112, .03), Vector2(.112, .09), Vector2(.1, .11)], Color("#7a7c7c"), 12)
	var flutes: Array[Vector2] = [Vector2(.1, 0), Vector2(.108, .08), Vector2(.098, .16), Vector2(.108, .24), Vector2(.098, .32), Vector2(.108, .4), Vector2(.098, .48), Vector2(.108, .56), Vector2(.1, .64)]
	_kit.lathe("front", at + Vector3.UP * 1.0, flutes, Color.WHITE, 14)
	_kit.lathe("metal", at + Vector3.UP * 1.62, [Vector2(.1, 0), Vector2(.112, .03), Vector2(.1, .07)], Color("#7a7c7c"), 12)
	_kit.lathe("plain", at + Vector3.UP * 1.68, [Vector2(.1, 0), Vector2(.09, .06), Vector2(.05, .14)], cream, 12)
	_kit.lathe("plain", at + Vector3.UP * 1.82, [Vector2(.05, 0), Vector2(.052, .03), Vector2(.05, .05)], Color("#b5281e"), 10)
	_kit.lathe("shade", at + Vector3.UP * 1.87, [Vector2(.082, 0), Vector2(.09, .03), Vector2(.066, .2), Vector2(.03, .3), Vector2(0, .31)], Color("#f4f2ea"), 14)
	for y: float in [.5, 1.74]:
		_kit.tube("metal", [_front * Vector3(POLE_X, y, 0), _front * Vector3(POLE_X, y, POLE_Z - .05)], .012, STEEL, 5)
	_kit.tube("plain", [_front * Vector3(POLE_X + .02, .06, .02), _front * Vector3(POLE_X + .02, 1.7, .02), _front * Vector3(POLE_X + .02, 1.76, POLE_Z - .06)], .007, Color("#1e1e20"), 4)

func _build_spinner() -> void:
	# A separate instance so turning it never rebuilds or re-submits the shop.
	var kit := Kit.new()
	var bottom := 1.0
	kit.lathe("spin", Vector3.ZERO, [Vector2(.082, 0), Vector2(.082, .2), Vector2(.082, .4), Vector2(.082, .62)], Color.WHITE, 12, _cell(0, 250, 256, 512))
	_spin = Node3D.new()
	_spin.name = "BarberPoleDrum"
	_spin.position = _front * Vector3(POLE_X, bottom + .01, POLE_Z)
	add_child(_spin)
	kit.commit(_spin, _looks, ["spin"])

func _boards(face: Transform3D, area: Rect2, holes: Array[Rect2], tint: Color) -> void:
	# Lapped weatherboard, each course its own quad kicked out at the bottom edge.
	var course := .128
	var y := area.position.y
	while y < area.end.y - .001:
		var top := minf(y + course, area.end.y)
		var tone := _rng.randf_range(.9, 1.03)
		var paint := Color(tint.r * tone, tint.g * tone, tint.b * tone)
		var uv := Vector2(_rng.randf() * 3.0, _rng.randf() * 3.0)
		for piece: Rect2 in _minus(Rect2(area.position.x, y, area.size.x, top - y), holes):
			var at := uv + Vector2(piece.position.x, 0)
			_kit.quad("clap", face * Vector3(piece.position.x, y, .02), face * Vector3(piece.position.x, top, 0), face * Vector3(piece.end.x, top, 0), face * Vector3(piece.end.x, y, .02), paint, .72, 1.0, .75, at)
			_kit.quad("plain", face * Vector3(piece.position.x, y, 0), face * Vector3(piece.position.x, y, .02), face * Vector3(piece.end.x, y, .02), face * Vector3(piece.end.x, y, 0), Color("#3c4a44"))
		y = top

func _sash(face: Transform3D, r: Rect2, cell: float, bars: int) -> void:
	# Timber double-hung sash, cream trim and a little hood, the flat's one vanity.
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var mid := (y0 + y1) * .5
	_reveal(face, r, .1, Color("#7f938a"))
	_kit.pane("glass", face, x0, x1, mid - .02, y1, -.09, cell)
	_kit.pane("glass", face, x0, x1, y0, mid + .02, -.06, fposmod(cell + .31, 1.0))
	var trim := CREAM
	for x: float in [x0 + .02, x1 - .02]:
		_bar("wood", face, x, mid, -.05, Vector3(.04, r.size.y, .08), trim)
	for y: float in [y0 + .02, y1 - .02]:
		_bar("wood", face, r.get_center().x, y, -.05, Vector3(r.size.x, .04, .08), trim)
	_bar("wood", face, r.get_center().x, mid + .015, -.06, Vector3(r.size.x, .035, .05), trim)
	for i: int in range(1, bars):
		var x := x0 + r.size.x * float(i) / float(bars)
		_bar("wood", face, x, mid + (y1 - mid) * .5, -.075, Vector3(.018, y1 - mid, .02), trim)
		_bar("wood", face, x, y0 + (mid - y0) * .5, -.045, Vector3(.018, mid - y0, .02), trim)
	# Architrave and hood, proud of the boards.
	for x: float in [x0 - .04, x1 + .04]:
		_bar("wood", face, x, mid, .03, Vector3(.08, r.size.y + .08, .05), trim)
	_bar("wood", face, r.get_center().x, y1 + .07, .05, Vector3(r.size.x + .24, .06, .12), trim)
	_bar("wood", face, r.get_center().x, y0 - .04, .05, Vector3(r.size.x + .2, .05, .12), trim)
	#
	_bar("wood", face, r.get_center().x, y1 + .12, .07, Vector3(r.size.x + .3, .03, .16), trim * .92)

func _upper_front() -> void:
	# The flat: lapped boards in a thinner mint than the tile, two different windows and a rail.
	var f := _front
	var c := _corner
	var paint := Color("#bcd8c8")
	_boards(f, Rect2(CUT, GROUND, WIDE - CUT, FIRST - GROUND), [SHOP_LOW.grow(.06), SHOP_HIGH.grow(.06)], paint)
	_boards(c, Rect2(0, GROUND, _splay, FIRST - GROUND), [SLIT.grow(.06)], paint)
	_sash(f, SHOP_LOW, .23, 3)
	_sash(f, SHOP_HIGH, .67, 2)
	_sash(c, SLIT, .41, 1)
	# Mitred belt at each floor: a mortar band under the boards, a cornice above them.
	for band: Vector3 in [Vector3(GROUND + .03, .12, .05), Vector3(FIRST - .02, .1, .07)]:
		_bar("mortar", f, (CUT + WIDE) * .5, band.x, band.z * .5, Vector3(WIDE - CUT, band.y, band.z), MINT, .85, 1.0)
		_bar("mortar", c, _splay * .5, band.x, band.z * .5, Vector3(_splay + .04, band.y, band.z), MINT, .85, 1.0)
	# Corner boards at the arrises.
	_bar("wood", f, WIDE - .04, (GROUND + FIRST) * .5, .03, Vector3(.08, FIRST - GROUND, .06), CREAM * .92)
	# Iron flower rail on the long window, the owner's wife's geraniums still in it.
	var low := SHOP_LOW.position.y - .1
	var x0 := SHOP_LOW.position.x - .1
	var x1 := SHOP_LOW.end.x + .1
	var rail := Color("#2c3a36")
	_bar("plain", f, (x0 + x1) * .5, low, .16, Vector3(x1 - x0, .03, .28), rail)
	_bar("cloth", f, (x0 + x1) * .5, low + .1, .16, Vector3(x1 - x0 - .1, .16, .17), Color("#8a5a3e"))
	_kit.tube("metal", [f * Vector3(x0, low + .46, .3), f * Vector3(x1, low + .46, .3)], .011, rail, 5)
	for i: int in range(13):
		var x := lerpf(x0, x1, float(i) / 12.0)
		_bar("metal", f, x, low + .23, .3, Vector3(.012, .46, .012), rail)
	for i: int in range(5):
		var at := f * Vector3(lerpf(x0 + .18, x1 - .18, float(i) / 4.0), low + .18, .16)
		_plant(at, .26, Color("#4e7a44"))
		_ball(at + Vector3(.03, .24, 0), Vector3(.05, .04, .05), Color("#b83a3a"), "plain", 4, 7)
	# Air-con by the small window, drip hose running down the boards, and the 2050 layer:
	# a drone drop shelf under it and the fibre coming in at the eave.
	_outdoor_unit(f, 3.3, SHOP_HIGH.position.y - .4, .19)
	_kit.tube("plain", [f * Vector3(3.8, 3.46, .05), f * Vector3(3.92, 3.46, .05), f * Vector3(3.92, GROUND + .05, .05)], .012, Color("#d6d0c0"), 4)
	_bar("metal", f, 3.0, 5.72, .26, Vector3(.42, .04, .46), Color("#3a3d40"))
	_strip(f * Vector3(2.8, 5.75, .48), f * Vector3(3.2, 5.75, .48), CYAN * .7)
	_status(f, 3.18, 5.8, .04, GREEN)
	_camera(f * Vector3(.98, 3.2, .12))
	_fibre([f * Vector3(WIDE - .1, FIRST + .3, .05), f * Vector3(WIDE - .1, 3.1, .05), f * Vector3(WIDE - .34, 2.9, .13)])
	# Blade sign out at the east end.
	var near := .1
	var far := .72
	var x := WIDE - .14
	_bar("metal", f, x, 4.4, (near + far) * .5, Vector3(.08, 1.72, far - near + .04), Color("#2c3a34"))
	_kit.atlas("sign", f * Vector3(x + .042, 3.56, far), f * Vector3(x + .042, 5.24, far), f * Vector3(x + .042, 5.24, near), f * Vector3(x + .042, 3.56, near), _cell(1800, 1030, 200, 620))
	_kit.atlas("sign", f * Vector3(x - .042, 3.56, near), f * Vector3(x - .042, 5.24, near), f * Vector3(x - .042, 5.24, far), f * Vector3(x - .042, 3.56, far), _cell(1800, 1030, 200, 620))
	for y: float in [3.8, 5.0]:
		_bar("metal", f, x, y, .06, Vector3(.04, .04, .14), STEEL)

func _false_front() -> void:
	# 看板建築: a cement front stood up in front of a plain tin house, stepped at the crown.
	var f := _front
	var c := _corner
	var cap := Color("#8fb0a0")
	var step0 := 1.5
	var step1 := 3.1
	_kit.quad("mortar", c * Vector3(0, FIRST, 0), c * Vector3(0, PARAPET, 0), c * Vector3(_splay, PARAPET, 0), c * Vector3(_splay, FIRST, 0), MINT, .9, 1.0, .9, Vector2(.3, 0))
	_kit.quad("mortar", f * Vector3(CUT, FIRST, 0), f * Vector3(CUT, PARAPET, 0), f * Vector3(WIDE, PARAPET, 0), f * Vector3(WIDE, FIRST, 0), MINT, .9, 1.0, .9, Vector2(1.0, 0))
	_kit.quad("mortar", f * Vector3(step0, PARAPET, 0), f * Vector3(step0, CREST, 0), f * Vector3(step1, CREST, 0), f * Vector3(step1, PARAPET, 0), MINT, .95, 1.0, .9, Vector2(2.0, 0))
	# Recessed panel and raised letters.
	_bar("mortar", f, (step0 + step1) * .5, 6.46, .012, Vector3(2.5, .04, .03), cap)
	_bar("mortar", f, (step0 + step1) * .5, 6.12, .012, Vector3(2.5, .04, .03), cap)
	_panel("decal", f, 1.42, 3.2, 6.14, 6.44, .03, _cell(1420, 0, 620, 160), Color(.8, .85, .8))
	# Pilasters that carry the lines of the storey up through the crown.
	for x: float in [CUT + .08, step0, step1, WIDE - .08]:
		_bar("mortar", f, x, (FIRST + PARAPET) * .5, .03, Vector3(.14, PARAPET - FIRST, .06), cap)
	_bar("mortar", f, step0, PARAPET + .3, .02, Vector3(.1, .6, .05), cap)
	_bar("mortar", f, step1, PARAPET + .3, .02, Vector3(.1, .6, .05), cap)
	# Cap of the wall, in sheet zinc: thin and straight, with the rust at its fixings.
	var zinc := Color("#6f8078")
	_bar("metal", f, (CUT + step0) * .5 - .01, PARAPET + .025, -.06, Vector3(step0 - CUT + .04, .05, .24), zinc)
	_bar("metal", f, (step1 + WIDE) * .5 + .01, PARAPET + .025, -.06, Vector3(WIDE - step1 + .04, .05, .24), zinc)
	_bar("metal", f, (step0 + step1) * .5, CREST + .025, -.06, Vector3(step1 - step0 + .1, .05, .24), zinc)
	_bar("metal", c, _splay * .5, PARAPET + .025, -.06, Vector3(_splay + .1, .05, .24), zinc)
	# Crest medallion: a round plaque the size of a tea tray.
	var medal := f * Vector3((step0 + step1) * .5, 6.98, .03)
	_kit.disc("mortar", medal, f.basis.x, f.basis.y, .3, cap)
	_kit.disc("sign", medal + f.basis.z * .006, f.basis.x, f.basis.y, .23, Color(.82, .86, .8), _cell(790, 1240, 170, 170))
	# Its plain back, seen from the roof and the side street, and the short return in mortar.
	var back := -.14
	_kit.quad("plain", f * Vector3(WIDE, FIRST, back), f * Vector3(WIDE, CREST, back), f * Vector3(CUT - .1, CREST, back), f * Vector3(CUT - .1, FIRST, back), Color("#6a6e68"), .8, .9)
	_kit.quad("plain", c * Vector3(_splay + .1, FIRST, back), c * Vector3(_splay + .1, PARAPET, back), c * Vector3(0, PARAPET, back), c * Vector3(0, FIRST, back), Color("#6a6e68"), .8, .9)
	_kit.block("mortar", Transform3D(Basis.IDENTITY, Vector3(step0 - WIDE * .5 - .05, CREST - .3, -.07)), Vector3(.1, .6, .14), MINT * .9)
	_kit.block("mortar", Transform3D(Basis.IDENTITY, Vector3(step1 - WIDE * .5 + .05, CREST - .3, -.07)), Vector3(.1, .6, .14), MINT * .9)
	# West return, ground to crown: mosaic to the shop's head, render above.
	var w := _west
	var return_at := DEEP - CUT
	var edge := .24
	_mosaic(w, Rect2(return_at - edge, 0, edge, SHOP_TOP), [] as Array[Rect2])
	_kit.quad("mortar", w * Vector3(return_at - edge, SHOP_TOP, 0), w * Vector3(return_at - edge, GROUND + .1, 0), w * Vector3(return_at, GROUND + .1, 0), w * Vector3(return_at, SHOP_TOP, 0), MINT, .9, 1.0, .7)
	_boards(w, Rect2(return_at - edge, GROUND + .1, edge, FIRST - GROUND - .1), [] as Array[Rect2], Color("#bcd8c8"))
	_kit.quad("mortar", w * Vector3(return_at - edge, FIRST, 0), w * Vector3(return_at - edge, PARAPET, 0), w * Vector3(return_at, PARAPET, 0), w * Vector3(return_at, FIRST, 0), MINT, .9, 1.0, .9)
	_kit.quad("plain", w * Vector3(return_at - edge, 0, 0), w * Vector3(return_at - edge, PARAPET, 0), w * Vector3(return_at - edge, PARAPET, -.14), w * Vector3(return_at - edge, 0, -.14), Color("#5a5e58"))
	_bar("metal", w, return_at - edge * .5, PARAPET + .025, -.05, Vector3(edge + .06, .05, .2), zinc)

func _roof_y(z: float) -> float:
	var t := clampf((z - FRONT_Z) / (RIDGE_Z - FRONT_Z), 0.0, 1.0) if z > RIDGE_Z else clampf((z + DEEP) / (RIDGE_Z + DEEP), 0.0, 1.0)
	return lerpf(EAVE, RIDGE, t)

func _tin_strips(face: Transform3D, length: float, holes: Array[Rect2], z_at: Callable, base: Color, rusty: float) -> void:
	# Sheets a metre wide lapped over one another: each its own tone, some gone to rust, the
	# last course following the roof up the gable.
	var x := .0
	while x < length - .01:
		var run := minf(_rng.randf_range(.72, .84), length - x)
		var tone := _rng.randf_range(.84, 1.06)
		var paint := Color(base.r * tone, base.g * tone * 1.01, base.b * tone)
		var part := "rust" if _rng.randf() < rusty else "tin"
		if part == "rust": paint = Color(.86, .8, .74)
		var uv := Vector2(_rng.randf() * 4.0, _rng.randf() * 4.0)
		for piece: Rect2 in _minus(Rect2(x, .3, run, EAVE - .3), holes):
			var at := uv + Vector2(piece.position.x - x, .3 - piece.position.y)
			_kit.quad(part, face * Vector3(piece.position.x, piece.position.y, 0), face * Vector3(piece.position.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.end.y, 0), face * Vector3(piece.end.x, piece.position.y, 0), paint, .9, 1.0, .85, at)
		var top0 := _roof_y(z_at.call(x))
		var top1 := _roof_y(z_at.call(x + run))
		if maxf(top0, top1) > EAVE + .01:
			_kit.quad(part, face * Vector3(x, EAVE, 0), face * Vector3(x, top0, 0), face * Vector3(x + run, top1, 0), face * Vector3(x + run, EAVE, 0), paint, .95, .9, .6, uv)
		x += run
		if x < length - .01:
			_bar("metal", face, x, (.3 + EAVE) * .5, .012, Vector3(.024, EAVE - .3, .016), base.darkened(.3))

func _west_flank() -> void:
	# The side street's wall: tin on a cement plinth, an old painted tonic ad, pipes and sashes.
	var w := _west
	var edge := DEEP - CUT - .24
	var holes: Array[Rect2] = [WEST_LOW.grow(.05), WEST_A.grow(.05), WEST_B.grow(.05)]
	var to_z := func(x: float) -> float: return x - DEEP
	_tin_strips(w, edge, holes, to_z, Color("#8db0a0"), .16)
	_bar("mortar", w, edge * .5, .15, .03, Vector3(edge, .3, .06), Color("#8f9a92"), .8, 1.0)
	_bar("metal", w, edge * .5, .315, .05, Vector3(edge, .03, .1), Color("#55605a"))
	_kit.atlas("paint", w * Vector3(AD.position.x, AD.position.y, .018), w * Vector3(AD.position.x, AD.end.y, .018), w * Vector3(AD.end.x, AD.end.y, .018), w * Vector3(AD.end.x, AD.position.y, .018), _cell(1060, 1410, 720, 480))
	_window(w, WEST_LOW, .13, true)
	_sash(w, WEST_A, .57, 2)
	_sash(w, WEST_B, .83, 2)
	# Water and gas along the plinth, tee'd up to the meter; soil pipe from the upstairs bathroom.
	var pipe := Color("#7c6a58")
	_kit.tube("metal", [w * Vector3(.3, .52, .05), w * Vector3(1.66, .52, .05), w * Vector3(1.66, 3.5, .05), w * Vector3(1.66, 3.86, .12), w * Vector3(1.66, 5.7, .12), w * Vector3(1.66, 5.9, 0)], .026, pipe, 6)
	_kit.tube("metal", [w * Vector3(.3, .68, .05), w * Vector3(4.9, .68, .05)], .016, Color("#b4a24a"), 6)
	_kit.tube("metal", [w * Vector3(2.8, .68, .05), w * Vector3(2.8, .78, .09)], .016, Color("#b4a24a"), 6)
	_bar("metal", w, 2.8, .92, .1, Vector3(.26, .3, .14), Color("#c8c6b8"))
	_bar("plain", w, 2.8, .96, .172, Vector3(.14, .1, .004), Color("#1c1e20"))
	_kit.tube("plain", [w * Vector3(5.28, EAVE + .1, .08), w * Vector3(5.28, .1, .08), w * Vector3(5.1, .03, .12)], .04, Color("#6e7a72"), 7)
	for x: float in [.3, 1.0, 1.66, 2.4, 3.3, 4.3]:
		_bar("metal", w, x, .6, .04, Vector3(.03, .22, .05), Color("#4a4a48"))
	for y: float in [1.2, 2.4, 3.6, 4.8]:
		_bar("metal", w, 1.66, y, .04, Vector3(.08, .03, .05), Color("#4a4a48"))
		_bar("metal", w, 5.28, y, .05, Vector3(.1, .03, .06), Color("#4a4a48"))
	_outdoor_unit(w, 2.64, 4.42, .19)
	_kit.tube("plain", [w * Vector3(2.2, 4.3, .03), w * Vector3(2.0, 4.3, .03), w * Vector3(2.0, 5.3, .03), w * Vector3(1.96, 5.3, .0)], .018, Color("#d6d0c0"), 4)
	# Gable louvre, street-name plate, and the fibre passing on to the next house.
	var vent_y := 6.56
	_bar("plain", w, 3.16, vent_y, .01, Vector3(.6, .36, .02), Color("#2a2a28"))
	for i: int in range(5):
		_bar("wood", w, 3.16, vent_y - .14 + float(i) * .07, .02, Vector3(.56, .03, .03), PAINT)
	_bar("plain", w, 4.86, 2.56, .02, Vector3(.42, .12, .012), Color("#1f3a6a"))
	_fibre([w * Vector3(.1, EAVE - .1, .05), w * Vector3(5.2, EAVE - .1, .05)])

func _tin_end(face: Transform3D, base: Color, flat: bool) -> void:
	# The sides nobody looks at, in the same tin without the paint.
	var back_z := func(_x: float) -> float: return -DEEP
	var side_z := func(x: float) -> float: return -x - .14
	if flat:
		_tin_strips(face, WIDE, [Rect2(1.5, 3.9, .9, 1.1)] as Array[Rect2], back_z, base, .3)
		_window(face, Rect2(1.5, 3.9, .9, 1.1), .37, false)
	else:
		_tin_strips(face, DEEP - .14, [] as Array[Rect2], side_z, base, .24)
		_kit.quad("render", face * Vector3(0, 0, -.01), face * Vector3(0, .3, -.01), face * Vector3(DEEP, .3, -.01), face * Vector3(DEEP, 0, -.01), Color("#7a7e78"))
	var plinth := Color("#6f756f")
	var long := WIDE if flat else DEEP
	_bar("mortar", face, long * .5, .15, .02, Vector3(long, .3, .04), plinth, .8, 1.0)

func _roof_sheet(x0: float, x1: float, near: float, far: float, tint: Color) -> void:
	var half := WIDE * .5
	var a := Vector3(x0 - half, _roof_y(near) + .02, near)
	var b := Vector3(x0 - half, _roof_y(far) + .02, far)
	var c := Vector3(x1 - half, _roof_y(far) + .02, far)
	var d := Vector3(x1 - half, _roof_y(near) + .02, near)
	_kit.quad("roof", a, b, c, d, tint, .8, 1.0, .5, Vector2(x0, near))

func _roof() -> void:
	# Tin gable behind the false front, oxide paint gone chalky, ribs at every sheet.
	var tint := Color("#7a5a4c")
	var half := WIDE * .5
	var over := .09
	var left := -over
	_roof_sheet(left, CUT + .1, -1.14, RIDGE_Z, tint)
	_roof_sheet(CUT + .1, WIDE, FRONT_Z, RIDGE_Z, tint)
	var rise := Vector3(CUT + .1 - half, _roof_y(FRONT_Z) + .02, FRONT_Z)
	_kit.quad("roof", Vector3(left - half, _roof_y(-1.14) + .02, -1.14), Vector3(CUT + .1 - half, _roof_y(-1.14) + .02, -1.14), rise, rise, tint, .8, .8)
	_roof_sheet(WIDE, left, -DEEP - .13, RIDGE_Z, tint.darkened(.1))
	var rib := left + .2
	while rib < WIDE:
		var x := rib - half
		var near := FRONT_Z if rib > CUT + .1 else -1.14
		_kit.beam("metal", Vector3(x, _roof_y(near) + .035, near), Vector3(x, RIDGE + .035, RIDGE_Z), .03, .03, Vector3(0, 1, .4), tint.darkened(.2))
		_kit.beam("metal", Vector3(x, RIDGE + .035, RIDGE_Z), Vector3(x, _roof_y(-DEEP) + .035 - .02, -DEEP - .13), .03, .03, Vector3(0, 1, -.4), tint.darkened(.25))
		rib += .46
	_kit.beam("metal", Vector3(left - half, RIDGE + .06, RIDGE_Z), Vector3(half, RIDGE + .06, RIDGE_Z), .2, .04, Vector3.UP, tint.darkened(.3))
	# Barge boards on the street end, mint like the front, and the rear gutter.
	var w := Color("#a3c4b4")
	_kit.beam("wood", Vector3(left - half + .02, RIDGE - .04, RIDGE_Z + .02), Vector3(left - half + .02, _roof_y(-1.14) - .08, -1.14), .16, .04, Vector3.RIGHT, w)
	_kit.beam("wood", Vector3(left - half + .02, RIDGE - .04, RIDGE_Z - .02), Vector3(left - half + .02, EAVE - .1, -DEEP - .13), .16, .04, Vector3.RIGHT, w)
	_kit.tube("metal", [Vector3(left - half, EAVE - .1, -DEEP - .14), Vector3(half, EAVE - .1, -DEEP - .14)], .05, Color("#6a6e6a"), 6)
	# Solar on the south slope, peeping above the crown, and the old aerial with a new sensor on it.
	var slope := atan2(RIDGE - EAVE, RIDGE_Z - FRONT_Z)
	_solar_module(Transform3D(Basis(Vector3.RIGHT, -PI * .5 - slope), Vector3(.9, _roof_y(-2.1) + .1, -2.1)), 1.3, .9)
	_kit.tube("metal", [Vector3(1.5, _roof_y(-5.0), -5.0), Vector3(1.5, RIDGE + 1.6, -5.0)], .018, ALUMINIUM, 5)
	for y: float in [RIDGE + .9, RIDGE + 1.15, RIDGE + 1.4]:
		_kit.tube("metal", [Vector3(1.0, y, -5.0), Vector3(2.0, y, -5.0)], .006, ALUMINIUM, 3)
	_kit.lathe("plain", Vector3(1.5, RIDGE + 1.6, -5.0), [Vector2(.05, 0), Vector2(.06, .04), Vector2(.02, .1)], Color("#d6d6d0"), 8)
	_kit.lathe("metal", Vector3(-1.2, _roof_y(-5.2), -5.2), [Vector2(.07, 0), Vector2(.07, .62), Vector2(.17, .68), Vector2(.17, .72), Vector2(.02, .82)], Color("#70706a"), 8)

func _street_things() -> void:
	# Pot plants along the sill (old barbers garden), the lottery flag and a parked bicycle.
	var f := _front
	var c := _corner
	# 宝くじ のぼり on a water-filled foot, in the angle of the corner.
	var base := c * Vector3(.08, 0, .5)
	_kit.lathe("plain", base, [Vector2(.17, 0), Vector2(.17, .09), Vector2(.05, .12), Vector2(.03, .14)], Color("#2a2a2c"), 10)
	_kit.tube("metal", [base, base + Vector3.UP * 2.3], .012, Color("#d8d8d4"), 5)
	var along := f.basis.x
	_kit.tube("metal", [base + Vector3.UP * 2.2, base + Vector3.UP * 2.2 + along * .46], .007, Color("#d8d8d4"), 4)
	var rect := _cell(1800, 250, 220, 760)
	var out := f.basis.z * .01
	var a := base + Vector3.UP * .54 + along * .02
	var b := base + Vector3.UP * 2.18 + along * .02
	var c0 := base + Vector3.UP * 2.18 + along * .46
	var d := base + Vector3.UP * .54 + along * .46 + out * 3.0
	_kit.atlas("board", a, b, c0, d, rect, Color.WHITE, .95, .25)
	_kit.atlas("board", d, c0, b, a, rect, Color(.72, .72, .72), .85)
	# Pots under the window, rainwater-stained, one broken.
	var tones: Array[Color] = [Color("#9a5a3a"), Color("#a86a4a"), Color("#6a7a8a"), Color("#8a4f34"), Color("#b9b2a0")]
	for i: int in range(5):
		var x := 2.66 + float(i) * .3
		var at := f * Vector3(x, 0, .24 + float(i % 2) * .05)
		var size := _rng.randf_range(.09, .13)
		_kit.lathe("plain", at, [Vector2(size * .7, 0), Vector2(size, size * 1.5), Vector2(size * 1.08, size * 1.55), Vector2(size * 1.08, size * 1.8), Vector2(size * .9, size * 1.8)], tones[i], 10)
		_plant(at + Vector3.UP * size * 1.7, .34 + float(i % 3) * .12, Color("#46703e"))
	_parked_bicycle(_west * Vector3(.7, 0, .42), Color("#3a5a52"))
