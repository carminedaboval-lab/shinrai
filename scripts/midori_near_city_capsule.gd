extends "res://scripts/midori_near_city_handmade.gd"
## カプセル蜂の巣: a 1972 capsule tower, sixty-odd steel pods bolted to two concrete shafts
## and meant to be swapped every twenty-five years. Almost none ever were. It stands on a
## white tiled podium with a standing soba bar beneath it, sells nights to travellers and
## months to people with nowhere else, and the rust-steel heads of its shafts can be seen
## from most of the ward. Local origin is the middle of the street front of the west lot;
## it spreads over the lots beside and behind, which are cleared for it.
const ATLAS := "res://assets/shinrai/near_city/capsule_atlas.png"
const PORT_SHADER := preload("res://scripts/midori_near_city_porthole.gdshader")
const SHIFT := 3.385 # From the west lot's middle to the middle of the whole site.
const WIDE := 12.6
const DEEP := 13.5
const GROUND := 3.3
const PODIUM := 6.9
const LIP := .5 # The tiled band stands out over the pavement.
const FIRST := 7.1 # Where the lowest pod hangs.
const PITCH := 2.72
const POD_HALF := 1.3 # Pods are square in section.
const POD_LONG := 1.6 # And half this long.
const CHAMFER := .05
const SHAFT := 1.1
const TURN := .3 # Pods sit off centre, so each shaft's arms pinwheel.
const PORT := .62
const POD_GREY := Color(.8, .86, .92)
const SHAFT_GREY := Color(.3, .3, .3)
const CONCRETE := Color(.72, .71, .68)
const TILE := Color(1.0, 1.0, .97)
const RUST := Color("#6a4a30")
const CORTEN := Color(.8, .54, .4)
const HONEY := Color(1.0, .68, .16)
# Shaft centre in x and z, pods high on each of its four arms, and how far each arm's pods
# may push out: as far as the neighbours and the other shaft allow.
const SHAFTS: Array[Array] = [[-2.7, -4.2, 8, 7, 9, 6, [1.2, .1, 1.2, .5]], [2.7, -8.2, 10, 9, 10, 8, [1.2, .35, 1.2, .05]]]

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))

func _ready() -> void:
	position.x += SHIFT
	_rng.seed = 1972
	_build_looks()
	for index: int in range(SHAFTS.size()):
		_shaft(index)
	_podium()
	_soba()
	_lobby()
	_undercroft()
	_roof_sign()
	_retrofit()
	_cables()
	_kit.commit(self, _looks, ["front", "decal", "lamp", "led", "sign", "room", "cloth"])
	_kit = null
	_omni("SobaSpill", Vector3(-4.6, 2.3, 1.1), Color(1.0, .86, .62), .9, 6.5)
	_omni("LobbyGlow", Vector3(-1.6, 2.3, .9), Color(1.0, .8, .4), .6, 5.0)
	_omni("Undercroft", Vector3(3.2, 2.7, -1.6), Color(.9, .95, 1.0), .5, 6.0)
	_omni("PodWash", Vector3(1.2, 8.4, -1.4), Color(.82, .9, 1.0), .9, 16.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.shell = _look("white_stucco", 2.0, .9)
	_looks.shell.set_shader_parameter("chroma", .15)
	_looks.shell.set_shader_parameter("glow", .05)
	_looks.concrete = _look("white_stucco", 2.0, .95)
	_looks.concrete.set_shader_parameter("chroma", .25)
	_looks.mosaic = _look("", 1.0, .36)
	_looks.mosaic.set_shader_parameter("tile_size", Vector2(.1, .1))
	_looks.corten = _look("rusty_corrugated_iron", 2.0, 1.0)
	_looks.corten.set_shader_parameter("glow", .1)
	_looks.cedar = _look("japanese_cedar_planks", 1.13, 1.0)
	_looks.cedar.set_shader_parameter("chroma", .55)
	_looks.room = _look("", 1.0, .7)
	_looks.room.set_shader_parameter("glow", .4)
	_looks.room.set_shader_parameter("day_glow", .12)
	_looks.sign = _look("", 1.0, .9)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .7)
	_looks.sign.set_shader_parameter("day_glow", .3)
	_looks.cloth = _look("", 1.0, .9)
	_looks.cloth.set_shader_parameter("albedo_map", signs)
	_looks.cloth.set_shader_parameter("glow", .2)
	var port := ShaderMaterial.new()
	port.shader = PORT_SHADER
	_looks.port = port
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", .55)
	letters.set_shader_parameter("day_glow", .24)
	_looks.decal = letters

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect)

func _shaft(index: int) -> void:
	# One concrete shaft, its arms of pods half a storey out of step, a corten head on top.
	var row: Array = SHAFTS[index]
	var x: float = row[0]
	var z: float = row[1]
	var reach: Array = row[6]
	var counts: Array = row.slice(2, 6)
	var tallest := 0.0
	for side: int in range(4):
		var count: int = counts[side]
		var spin := Basis(Vector3.UP, float(side) * PI * .5)
		var step := .5 if side % 2 == 1 else 0.0
		var bottom := FIRST + step * PITCH
		var last := bottom + float(count) * PITCH - (PITCH - POD_HALF * 2.0)
		tallest = maxf(tallest, last)
		# Black spine down the arm, so the seams between pods read as deep shadow.
		var spine := Vector3(x, (bottom + last) * .5, z) + spin * Vector3(TURN, 0, SHAFT + POD_LONG - .3)
		_kit.block("plain", Transform3D(spin, spine), Vector3(POD_HALF * 2.0 - .3, last - bottom, POD_LONG * 2.0 - .6), Color("#0a0b0c"), .4, .4)
		var most: float = reach[side]
		var top_out := 0.0
		var below := 0.0
		for level: int in range(count):
			var y := bottom + POD_HALF + float(level) * PITCH
			var roll := _rng.randf()
			var push := _rng.randf_range(0.0, .1)
			if roll > .78:
				push = most
			elif roll > .4:
				push = most * _rng.randf_range(.4, .7)
			top_out = SHAFT + POD_LONG + push
			var at := Transform3D(spin, Vector3(x, y, z) + spin * Vector3(TURN, 0, top_out))
			if level * 5 + side * 7 + index * 3 in [31, 44, 19]:
				_empty_socket(at)
			else:
				_pod(at, below > push + .1)
			below = push
		if count < counts.max():
			var roof := Vector3(x, last, z) + spin * Vector3(TURN, 0, top_out)
			_arm_top(Transform3D(spin, roof), side + index * 4)
	var top := tallest + .2
	_kit.block("concrete", Transform3D(Basis.IDENTITY, Vector3(x, (PODIUM + top) * .5, z)), Vector3(SHAFT * 2.0, top - PODIUM, SHAFT * 2.0), SHAFT_GREY, .6, 1.0, .4)
	_head(Vector3(x, top - 1.4, z), 1.0 if index == 0 else -1.0, 7.0 if index == 0 else 8.6)

func _pod(at: Transform3D, overhung: bool) -> void:
	# A welded steel box: a window on its end, or on its flank where the plan demanded it.
	var roll := _rng.randf()
	var tint := POD_GREY * _rng.randf_range(.92, 1.08)
	tint.a = 1.0
	if roll > .92:
		tint = Color("#2a2d30") # A new one, paid for by somebody with money.
	elif roll > .87:
		tint = Color(.7, .62, .54)
	var flank := 0
	if _rng.randf() < .22:
		flank = 1 if _rng.randf() < .5 else 3
	var streak := _rng.randf_range(.6, 1.0)
	var w := POD_HALF
	var far := POD_LONG - CHAMFER
	for i: int in range(4):
		var turn := at.basis * Basis(Vector3.BACK, float(i) * PI * .5)
		var plate := Transform3D(turn, at.origin)
		var ao := 1.0 if i == 0 else (.5 if i == 2 else .86)
		var mid := (far - POD_LONG) * .5
		if i == flank:
			var face := Transform3D(Basis(turn.x, -turn.z, turn.y), plate * Vector3(0, w, mid))
			_holed(face, Vector2(w, (far + POD_LONG) * .5), Vector2.ZERO, tint, ao, streak)
			_porthole(face, Vector2.ZERO)
		else:
			_kit.quad("shell", plate * Vector3(-w, w, far), plate * Vector3(-w, w, -POD_LONG), plate * Vector3(w, w, -POD_LONG), plate * Vector3(w, w, far), tint, ao, ao, 0.0 if i == 0 else streak)
			# Weld lines where the shell plates were joined.
			if i % 2 == 1:
				for seam: float in [-.35, .75]:
					_kit.quad("plain", plate * Vector3(-w, w + .004, seam + .012), plate * Vector3(-w, w + .004, seam - .012), plate * Vector3(w, w + .004, seam - .012), plate * Vector3(w, w + .004, seam + .012), tint * .5, ao, ao)
		var inner := w - CHAMFER
		_kit.quad("shell", plate * Vector3(-inner, inner, POD_LONG), plate * Vector3(-w, w, far), plate * Vector3(w, w, far), plate * Vector3(inner, inner, POD_LONG), tint * 1.06, ao, ao, 0.0 if i == 0 else streak)
	var end := Transform3D(at.basis, at * Vector3(0, 0, POD_LONG))
	var size := Vector2(w - CHAMFER, w - CHAMFER)
	_end_detail(end, tint)
	if flank == 0:
		var hole := Vector2(0, .1)
		_holed(end, size, hole, tint, .92, streak)
		_porthole(end, hole)
	else:
		_kit.quad("shell", end * Vector3(-size.x, -size.y, 0), end * Vector3(-size.x, size.y, 0), end * Vector3(size.x, size.y, 0), end * Vector3(size.x, -size.y, 0), tint, .92, 1.0, streak)
		for slat: int in range(4):
			_kit.block("metal", _at(end, 0, .1 + float(slat) * .07, .012), Vector3(.5, .03, .024), Color("#3a3c3e"))
	# Rust weeping from the bolts, and grime run down from the window's lip.
	for i: int in range(_rng.randi_range(0, 2)):
		var x := _rng.randf_range(-.9, .9)
		var thin := _rng.randf_range(.012, .04)
		var drop := _rng.randf_range(.15, .5)
		_kit.quad("plain", end * Vector3(x, -.62 - drop, .004), end * Vector3(x, -.62, .004), end * Vector3(x + thin, -.62, .004), end * Vector3(x + thin, -.62 - drop, .004), RUST * _rng.randf_range(.7, 1.05), 1.0, 1.0, .9)
	# Patches, and whatever the tenant has done to the front of their room.
	if _rng.randf() < .3:
		var px := _rng.randf_range(-.95, .35)
		var py := -1.15 if _rng.randf() < .5 else .78
		_kit.quad("shell", end * Vector3(px, py, .006), end * Vector3(px, py + .34, .006), end * Vector3(px + .6, py + .34, .006), end * Vector3(px + .6, py, .006), tint * .84, 1.0, 1.0, .5, Vector2(px, py))
	var life := _rng.randf()
	if life < .4:
		# A sign would be lost behind the pod below if that one stands further out.
		if not overhung:
			_tenant_board(end)
	elif life < .54:
		_washing(end)
	elif life < .62:
		_outdoor_unit(end, _rng.randf_range(-.3, .3), -.88, .18)
	elif life > .97:
		_tarp(end)
	if flank == 0 and _rng.randf() < .06:
		var tone: Color = [Color(1.0, .37, .82), Color(.3, .86, 1.0), Color(1.0, .68, .16)][_rng.randi_range(0, 2)]
		var ring: Array[Vector3] = []
		for i: int in range(25):
			var a := TAU * float(i) / 24.0
			ring.append(end * Vector3(cos(a) * (PORT + .07), .1 + sin(a) * (PORT + .07), .03))
		_neon(ring, tone)

func _holed(face: Transform3D, half: Vector2, hole: Vector2, tint: Color, ao: float, streak: float) -> void:
	# A flat plate with a true round hole cut through it, swept from each edge in to the circle.
	var corners: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	var parts := 5
	for side: int in range(4):
		var from := corners[side]
		var to := corners[(side + 1) % 4]
		for i: int in range(parts):
			var o0 := from.lerp(to, float(i) / float(parts))
			var o1 := from.lerp(to, float(i + 1) / float(parts))
			var i0 := hole + (o0 - hole).normalized() * PORT
			var i1 := hole + (o1 - hole).normalized() * PORT
			_kit.quad("shell", face * Vector3(o0.x, o0.y, 0), face * Vector3(i0.x, i0.y, 0), face * Vector3(i1.x, i1.y, 0), face * Vector3(o1.x, o1.y, 0), tint, ao, ao, streak, o0)

func _porthole(face: Transform3D, hole: Vector2) -> void:
	# Steel tube let into the shell, a bright lip at its mouth, the glass well back inside it.
	var centre := face * Vector3(hole.x, hole.y, 0)
	var sink := -face.basis.z.normalized() * .24
	var steps := 18
	var lip: Array[Vector3] = []
	for i: int in range(steps + 1):
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var n0 := (face.basis.x * cos(a0) + face.basis.y * sin(a0)).normalized()
		var n1 := (face.basis.x * cos(a1) + face.basis.y * sin(a1)).normalized()
		lip.append(centre + n0 * (PORT + .012) + face.basis.z * .012)
		if i < steps:
			var p0 := centre + n0 * PORT
			var p1 := centre + n1 * PORT
			_kit.smooth("metal", p0, p0 + sink, p1 + sink, p1, -n0, -n0, -n1, -n1, Color("#26282a"), .7)
	_kit.tube("metal", lip, .034, Color("#c9cccd"), 4)
	var r := PORT + .01
	_kit.disc("port", centre + sink, face.basis.x, face.basis.y, r, Color(_rng.randf(), 0, 0), Rect2(-r, -r, r * 2.0, r * 2.0))

func _end_detail(end: Transform3D, tint: Color) -> void:
	# What daylight finds: a weld line round the end plate, its corner bolts, a stencilled room
	# number, and the grime that gathers along the foot of every plate.
	var edge := 1.12
	var line := tint * .5
	for side: int in range(4):
		var turn := Transform3D(end.basis * Basis(Vector3.BACK, float(side) * PI * .5), end.origin)
		_kit.quad("plain", turn * Vector3(-edge, edge - .014, .004), turn * Vector3(-edge, edge + .014, .004), turn * Vector3(edge, edge + .014, .004), turn * Vector3(edge, edge - .014, .004), line)
		_kit.block("metal", _at(turn, edge - .07, edge - .07, .014), Vector3(.08, .08, .024), Color("#5a5c5c"))
	_kit.quad("plain", end * Vector3(-edge, -1.22, .004), end * Vector3(-edge, -1.04, .004), end * Vector3(edge, -1.04, .004), end * Vector3(edge, -1.22, .004), tint * .62, 1.0, 1.0, 1.0)
	var pick := _rng.randi_range(0, 11)
	var rect := _cell(420.0 + float(pick % 3) * 210.0, 1700.0 + float(pick / 3) * 60.0, 200, 50)
	_panel("decal", end, -1.02, -.46, .9, 1.04, .006, rect)

func _tenant_board(end: Transform3D) -> void:
	# A pod let to a trade: a lit blade on the outer corner, fanned out from the wall so it reads
	# along the street and from straight ahead, and swings its far edge clear of the window.
	var pick := _rng.randi_range(0, 11)
	var rect := _cell(1370.0 + float(pick % 6) * 112.0, 1200.0 + float(pick / 6) * 410.0, 110, 400)
	var fan := .7
	var wide := .52
	var first := 1.0 if _rng.randf() < .5 else -1.0
	var side := 0.0
	for option: float in [first, -first]:
		var tip := Vector3(option * 1.12, 0, .12) + Vector3(option * sin(fan), 0, cos(fan)) * wide
		if side == 0.0 and _open_air(end * tip):
			side = option
	if side == 0.0:
		return
	var root := Vector3(side * 1.12, 0, .12)
	var along := Vector3(side * sin(fan), 0, cos(fan))
	var out := Vector3.UP.cross(along)
	var low := -.95
	var high := .95
	var near := root
	var far := root + along * wide
	var mid := (near + far) * .5
	_kit.block("metal", Transform3D(end.basis * Basis(out, Vector3.UP, along), end * mid), Vector3(.06, high - low + .02, wide + .02), Color("#1a1b1d"), .85, 1.0)
	var skin := out * .032
	_kit.atlas("sign", end * (far + skin + Vector3.UP * low), end * (far + skin + Vector3.UP * high), end * (near + skin + Vector3.UP * high), end * (near + skin + Vector3.UP * low), rect, Color.WHITE, 1.0, .2)
	_kit.atlas("sign", end * (near - skin + Vector3.UP * low), end * (near - skin + Vector3.UP * high), end * (far - skin + Vector3.UP * high), end * (far - skin + Vector3.UP * low), rect, Color.WHITE, 1.0, .2)
	for y: float in [low + .22, high - .22]:
		_kit.tube("metal", [end * Vector3(root.x, y, 0), end * (root + Vector3.UP * y)], .014, STEEL, 4)
	_kit.tube("plain", [end * (near + Vector3.UP * high), end * Vector3(root.x, high + .22, .02)], .009, Color("#141517"), 3)

func _open_air(tip: Vector3) -> bool:
	# Whether a sign's outer edge clears the site and every column of pods.
	if absf(tip.x) > WIDE * .5 + .2 or tip.z < -DEEP - .2:
		return false
	for row: Array in SHAFTS:
		var reach: Array = row[6]
		for side: int in range(4):
			var p := Basis(Vector3.UP, float(side) * PI * .5).inverse() * Vector3(tip.x - float(row[0]), 0, tip.z - float(row[1]))
			if absf(p.x - TURN) < POD_HALF + .1 and p.z > SHAFT - .2 and p.z < SHAFT + POD_LONG * 2.0 + float(reach[side]) + .1:
				return false
	return true

func _washing(end: Transform3D) -> void:
	# A pole clamped under the window, because the tower never had a balcony.
	var y := -.5
	_kit.tube("metal", [end * Vector3(-.95, y, .4), end * Vector3(.95, y, .4)], .014, ALUMINIUM, 5)
	for x: float in [-.7, .7]:
		_kit.tube("metal", [end * Vector3(x, y, .4), end * Vector3(x, y, 0)], .012, STEEL, 4)
	var at := -.85
	for i: int in range(_rng.randi_range(2, 4)):
		var wide := _rng.randf_range(.26, .46)
		var tall := _rng.randf_range(.36, .62)
		var cloth: Color = [Color("#e8e4d8"), Color("#3c5a7a"), Color("#c9b8a0"), Color("#7a3a34"), Color("#d8d8d2"), Color("#e0a33c")][_rng.randi_range(0, 5)]
		_kit.block("plain", Transform3D(end.basis * Basis(Vector3.UP, _rng.randf_range(-.25, .25)), end * Vector3(at + wide * .5, y - tall * .5 - .02, .4)), Vector3(wide, tall, .012), cloth, .8, 1.0)
		at += wide + .12

func _tarp(end: Transform3D) -> void:
	# Blue sheet roped over a failed seal, the same blue on every roof in Japan.
	var blue := Color("#0f3fb0")
	_kit.block("plain", Transform3D(end.basis * Basis(Vector3.BACK, .03), end * Vector3(-.1, .32, .06)), Vector3(2.3, 1.9, .06), blue, .85, 1.0)
	_kit.block("plain", Transform3D(end.basis * Basis(Vector3.BACK, -.05), end * Vector3(.2, -.3, .1)), Vector3(1.9, 1.3, .05), blue * 1.25, .85, 1.0)
	for y: float in [-.6, .5]:
		_kit.tube("plain", [end * Vector3(-1.34, y, .14), end * Vector3(1.34, y + .08, .14)], .012, Color("#d9c9a0"), 3)

func _arm_top(top: Transform3D, kind: int) -> void:
	# Where an arm stops short, its last roof belongs to whoever gets there first.
	match kind % 4:
		0:
			# A garden in polystyrene boxes and a chair to look at it from.
			for i: int in range(6):
				var at := top * Vector3(_rng.randf_range(-.95, .95), 0, _rng.randf_range(-1.2, 1.2))
				_kit.lathe("plain", at, [Vector2(.14, 0), Vector2(.19, .3), Vector2(.2, .32)], Color("#8c5a3c"), 8)
				_plant(at + Vector3.UP * .28, _rng.randf_range(.5, 1.1), Color("#3f6a35"))
			_bar("cedar", top, .4, .44, .2, Vector3(.42, .05, .42), Color("#7a5c3e"))
		1:
			# A roof tank nobody asked permission for, and its feed down the side.
			_kit.lathe("plain", top * Vector3(.1, .08, -.2), [Vector2(.5, 0), Vector2(.55, .1), Vector2(.55, 1.0), Vector2(.3, 1.2), Vector2(.02, 1.26)], Color("#b9c4c6"), 12)
			_kit.tube("metal", [top * Vector3(.6, .3, -.2), top * Vector3(1.25, .3, -.2), top * Vector3(1.25, -2.4, -.2)], .03, Color("#7c8084"), 6)
		2:
			# A tin shed, an aerial, and somebody's whole workshop.
			_kit.block("metal", _at(top, -.1, .86, 0), Vector3(1.8, 1.7, 2.0), Color("#7d8078"), .8, 1.0, .9)
			_kit.block("metal", _at(top, .55, 1.74, 0), Vector3(.5, .06, 2.1), Color("#5a4a3c"))
			_bar("metal", top, -.2, .8, 1.01, Vector3(.7, 1.5, .03), Color("#4a5a60"))
			_kit.tube("metal", [top * Vector3(-.6, 1.7, -.4), top * Vector3(-.6, 3.6, -.4)], .02, Color("#7a7468"), 5)
		3:
			# Panels on a frame and a dish on a bracket: power and a signal of one's own.
			_solar_module(Transform3D(top.basis * Basis(Vector3.RIGHT, -PI * .36), top * Vector3(0, .5, -.3)), 1.9, 1.6)
			_kit.disc("metal", top * Vector3(.8, .7, .9), top.basis.x, (top.basis.y + top.basis.z * .4).normalized(), .36, Color("#c7c8c4"))
			_kit.tube("metal", [top * Vector3(.8, 0, .85), top * Vector3(.8, .6, .85)], .02, Color("#8d9092"), 5)
	for y: float in [.5, 1.0]:
		var edge := POD_HALF - .06
		_kit.tube("metal", [top * Vector3(-edge, y, 1.5), top * Vector3(edge, y, 1.5)], .016, Color("#8d9092"), 4)

func _cables() -> void:
	# Fifty years of feeds: slung across the gap between the shafts and run down the corners.
	var black := Color("#141517")
	for i: int in range(7):
		var y := _rng.randf_range(9.0, 27.0)
		var a := Vector3(-1.05, y, _rng.randf_range(-3.0, -.6))
		var b := Vector3(1.68, y + _rng.randf_range(-1.1, .7), _rng.randf_range(-6.0, -3.6))
		var sag := _rng.randf_range(.3, .9)
		var points: Array[Vector3] = []
		for k: int in range(9):
			var u := float(k) / 8.0
			points.append(a.lerp(b, u) + Vector3.DOWN * sag * 4.0 * u * (1.0 - u))
		_kit.tube("plain", points, _rng.randf_range(.01, .02), black, 4)
	for row: Array in [[-1.04, -.9, 26.0], [1.66, -3.8, 33.0], [-4.0, 1.9, 22.0]]:
		var x: float = row[0]
		var z: float = row[1]
		var high: float = row[2]
		for offset: float in [0.0, .05, .1]:
			_kit.tube("plain", [Vector3(x + offset, high - offset * 8.0, z), Vector3(x + offset, PODIUM, z)], .014, black, 4)

func _empty_socket(at: Transform3D) -> void:
	# Four brackets and a capped-off pipe, where somebody's room used to be.
	var steel := Color("#5a4a3c")
	for x: float in [-POD_HALF + .1, POD_HALF - .1]:
		for y: float in [-POD_HALF + .1, POD_HALF - .1]:
			_kit.block("metal", _at(at, x, y, -POD_LONG + .4), Vector3(.1, .1, .8), steel)
	_kit.tube("metal", [at * Vector3(.3, -.4, -POD_LONG), at * Vector3(.3, -.4, -POD_LONG + .6)], .05, Color("#8a8b84"), 6)

func _head(at: Vector3, flip: float, rise: float) -> void:
	# The shaft's machine room, cut off on the slant and left to rust.
	var h := 1.9
	var west := rise - 2.6 if flip > 0.0 else rise
	var east := rise if flip > 0.0 else rise - 2.6
	var tint := CORTEN
	var o := at
	_kit.quad("corten", o + Vector3(-h, 0, h), o + Vector3(-h, west, h), o + Vector3(h, east, h), o + Vector3(h, 0, h), tint, .8, 1.0, .5)
	_kit.quad("corten", o + Vector3(h, 0, -h), o + Vector3(h, east, -h), o + Vector3(-h, west, -h), o + Vector3(-h, 0, -h), tint, .8, 1.0, .5)
	_kit.quad("corten", o + Vector3(h, 0, h), o + Vector3(h, east, h), o + Vector3(h, east, -h), o + Vector3(h, 0, -h), tint * .92, .8, 1.0, .5)
	_kit.quad("corten", o + Vector3(-h, 0, -h), o + Vector3(-h, west, -h), o + Vector3(-h, west, h), o + Vector3(-h, 0, h), tint * .92, .8, 1.0, .5)
	_kit.quad("corten", o + Vector3(-h, west, h), o + Vector3(-h, west, -h), o + Vector3(h, east, -h), o + Vector3(h, east, h), tint * .8, 1.0, 1.0)
	# Name in white steel on the taller head, and the aerials the tenants never took down.
	if flip < 0.0:
		var face := Transform3D(Basis.IDENTITY, o + Vector3(-.75, 0, h + .01))
		_panel("decal", face, -.6, .6, 2.6, 6.2, 0.0, _cell(200, 1000, 200, 620))
	var mast := o + Vector3(flip * .4, (east + west) * .5, 0)
	_kit.tube("metal", [mast, mast + Vector3.UP * 2.4], .02, Color("#7a7468"), 5)
	for i: int in range(4):
		var y := 1.4 + float(i) * .28
		_kit.tube("metal", [mast + Vector3(-.5, y, 0), mast + Vector3(.5, y, 0)], .007, Color("#6b5d4c"), 3)
	if flip < 0.0:
		_status(Transform3D.IDENTITY, mast.x, mast.y + 2.45, mast.z, Color(1.0, .2, .15))

func _podium() -> void:
	# Two tiled bands and a ribbon of glass between, standing out over the pavement on columns.
	var long := DEEP + LIP
	var front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, LIP))
	var east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, LIP))
	var back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
	var west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))
	var runs: Array[Array] = [[front, WIDE], [east, long], [back, WIDE], [west, long]]
	for run: Array in runs:
		var face: Transform3D = run[0]
		var length: float = run[1]
		for band: Vector2 in [Vector2(GROUND, 4.2), Vector2(5.5, PODIUM)]:
			_kit.quad("mosaic", face * Vector3(0, band.x, 0), face * Vector3(0, band.y, 0), face * Vector3(length, band.y, 0), face * Vector3(length, band.x, 0), TILE, .85, 1.0, .5, Vector2(0, -band.x))
		_kit.quad("mosaic", face * Vector3(0, 4.2, -.18), face * Vector3(0, 5.5, -.18), face * Vector3(length, 5.5, -.18), face * Vector3(length, 4.2, -.18), TILE * .5, .7, .7)
		var x := .04
		var cell := .13
		while x < length - .1:
			var wide := minf(1.5, length - x - .04)
			_kit.pane("glass", face, x, x + wide - .05, 4.24, 5.46, -.16, cell)
			_bar("metal", face, x + wide - .025, 4.85, -.14, Vector3(.05, 1.3, .06), Color("#3a3d3f"))
			x += wide
			cell = fposmod(cell + .37, 1.0)
		_kit.quad("mosaic", face * Vector3(0, 4.2, 0), face * Vector3(0, 4.2, -.18), face * Vector3(length, 4.2, -.18), face * Vector3(length, 4.2, 0), TILE * .8, .9, .9)
		_kit.quad("mosaic", face * Vector3(0, 5.5, -.18), face * Vector3(0, 5.5, 0), face * Vector3(length, 5.5, 0), face * Vector3(length, 5.5, -.18), TILE * .5, .6, .6)
		_bar("metal", face, length * .5, PODIUM + .03, -.05, Vector3(length, .06, .14), Color("#8d8f8c"))
	_panel("decal", front, .4, 8.6, 5.62, 6.74, .012, _cell(420, 1000, 1240, 180))
	# Roof of the podium, plant on the open corner, and the soffit over the street.
	var x0 := -WIDE * .5
	var x1 := WIDE * .5
	_kit.quad("plain", Vector3(x0, PODIUM, LIP), Vector3(x0, PODIUM, -DEEP), Vector3(x1, PODIUM, -DEEP), Vector3(x1, PODIUM, LIP), Color("#5c5d59"), .8, .9)
	_kit.quad("concrete", Vector3(x0, GROUND, -4.1), Vector3(x0, GROUND, LIP), Vector3(x1, GROUND, LIP), Vector3(x1, GROUND, -4.1), CONCRETE * .78, .7, .7)
	# Everything at street level behind the shops is plant, stores and the shafts' feet.
	_kit.block("concrete", Transform3D(Basis.IDENTITY, Vector3(0, GROUND * .5, -8.8)), Vector3(WIDE, GROUND, 9.4), CONCRETE * .9, .8, 1.0, .5)
	# The long west side at street level: tiled to the head of the doors, with the back of
	# house let into it, and the pipes that keep sixty rooms going.
	var side := Transform3D(west.basis, Vector3(-WIDE * .5 - .01, 0, -DEEP))
	_kit.quad("mosaic", side * Vector3(0, 0, 0), side * Vector3(0, GROUND, 0), side * Vector3(DEEP, GROUND, 0), side * Vector3(DEEP, 0, 0), TILE * .86, .8, 1.0, .5)
	_kit.quad("mosaic", side * Vector3(0, 0, .006), side * Vector3(0, .62, .006), side * Vector3(DEEP, .62, .006), side * Vector3(DEEP, 0, .006), TILE * .48, .8, .9, .3)
	for x: float in [2.4, 7.2]:
		_bar("metal", side, x, 1.08, .03, Vector3(1.1, 2.14, .05), Color("#4d5a5e"), .85, 1.0)
		_bar("metal", side, x, 2.28, .08, Vector3(1.4, .05, .24), Color("#6e6f6a"))
		_bar("lamp", side, x, 2.4, .05, Vector3(.4, .05, .05), Color(.72, .76, .74))
	_bar("metal", side, 4.8, 1.6, .05, Vector3(1.5, .9, .08), Color("#7f8488"))
	for slat: int in range(7):
		_bar("metal", side, 4.8, 1.24 + float(slat) * .12, .1, Vector3(1.4, .03, .03), Color("#4a4d50"))
	for x: float in [9.6, 9.9, 12.2]:
		_kit.tube("metal", [side * Vector3(x, .06, .09), side * Vector3(x, GROUND, .09)], .05, Color("#8a8b84"), 7)
	_bar("metal", side, 10.9, 1.3, .06, Vector3(.7, .9, .1), Color("#c7c8c2"))
	_status(side, 10.7, 1.6, .115, GREEN)
	var f := _front
	for row: Array in [[.07, -.5, 1.0], [3.27, -.5, 1.0], [5.93, -.5, 1.0], [.07, -2.7, 3.0], [5.93, -2.7, 3.0]]:
		_kit.block("concrete", _at(f, row[0], GROUND * .5, row[1]), Vector3(.14, GROUND, row[2]), CONCRETE, .8, 1.0, .4)

func _soba() -> void:
	# 立ち食いそば はちや: a counter, a ticket machine, a curtain, and six minutes for lunch.
	var f := _front
	var x0 := .15
	var x1 := 3.2
	var far := -4.0
	var ceiling := 2.7
	_kit.quad("room", f * Vector3(x0, .03, 0), f * Vector3(x0, .03, far), f * Vector3(x1, .03, far), f * Vector3(x1, .03, 0), Color("#6a5a4a"), .9, .9)
	_kit.quad("room", f * Vector3(x0, ceiling, far), f * Vector3(x0, ceiling, 0), f * Vector3(x1, ceiling, 0), f * Vector3(x1, ceiling, far), Color("#c8bc9e"))
	_kit.quad("room", f * Vector3(x0, 0, far), f * Vector3(x0, ceiling, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, 0, far), Color("#a89070"), .8, 1.0)
	_kit.quad("room", f * Vector3(x0, 0, 0), f * Vector3(x0, ceiling, 0), f * Vector3(x0, ceiling, far), f * Vector3(x0, 0, far), Color("#b09a78"), .8, 1.0)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, ceiling, 0), f * Vector3(x1, 0, 0), Color("#b09a78"), .8, 1.0)
	# Counter along the back, bowls on it, and the steel of the kitchen behind.
	_bar("room", f, (x0 + x1) * .5, .52, -2.7, Vector3(x1 - x0, 1.04, .1), Color("#7a5c3e"))
	_bar("room", f, (x0 + x1) * .5, 1.06, -2.65, Vector3(x1 - x0, .05, .46), Color("#c9a878"))
	for x: float in [.6, 1.35, 2.2]:
		_kit.lathe("room", f * Vector3(x, 1.085, -2.6), [Vector2(.05, 0), Vector2(.09, .02), Vector2(.105, .08)], Color("#e8e2d0"), 9)
	_bar("metal", f, (x0 + x1) * .5, 1.4, -3.6, Vector3(x1 - x0 - .3, .9, .5), Color("#a9adae"))
	for i: int in range(3):
		_kit.lathe("metal", f * Vector3(.9 + float(i) * .9, 1.86, -3.6), [Vector2(.24, 0), Vector2(.26, .3), Vector2(.25, .32)], Color("#c9cbc9"), 10)
	_bar("lamp", f, (x0 + x1) * .5, ceiling - .02, -2.4, Vector3(2.0, .03, .1), Color(.8, .72, .56))
	_bar("room", f, 3.0, 1.2, -1.2, Vector3(.3, 2.2, .6), Color("#3a3d40"))
	_kit.atlas("sign", f * Vector3(2.84, .9, -.9), f * Vector3(2.84, 1.9, -.9), f * Vector3(2.84, 1.9, -1.5), f * Vector3(2.84, .9, -1.5), _cell(640, 160, 200, 300))
	# Fascia, curtain, and the photo menu on its own lit board outside.
	_bar("cedar", f, (x0 + x1) * .5, 2.98, .08, Vector3(x1 - x0 + .1, .56, .22), Color("#3a2414"), .7, .9)
	_panel("sign", f, x0 + .02, x1 - .02, 2.72, 3.24, .194, _cell(200, 0, 900, 150))
	var panels := 2
	var width := (x1 - x0 - .3) / float(panels)
	_kit.tube("metal", [f * Vector3(x0, 2.6, .1), f * Vector3(x1, 2.6, .1)], .016, Color("#2a241d"), 5)
	for i: int in range(panels):
		var a := x0 + .1 + float(i) * (width + .1)
		var rect := _cell(200.0 + float(i) * 450.0, 740, 448, 240)
		_kit.atlas("cloth", f * Vector3(a, 1.72, .1), f * Vector3(a, 2.58, .1), f * Vector3(a + width, 2.58, .1), f * Vector3(a + width, 1.72, .1), rect)
		_kit.atlas("cloth", f * Vector3(a + width, 1.72, .096), f * Vector3(a + width, 2.58, .096), f * Vector3(a, 2.58, .096), f * Vector3(a, 1.72, .096), rect)
	# Glass on the left half, the door standing open on the right.
	_kit.quad("front", f * Vector3(x0, .1, -.1), f * Vector3(x0, 1.72, -.1), f * Vector3(1.6, 1.72, -.1), f * Vector3(1.6, .1, -.1), Color.WHITE)
	_bar("metal", f, 1.6, 1.3, -.1, Vector3(.05, 2.6, .05), Color("#3a3028"))
	var board := f * Vector3(.5, 0, .7)
	_kit.block("metal", Transform3D(Basis.IDENTITY, board + Vector3(0, 1.0, 0)), Vector3(.86, 1.14, .08), Color("#2a1c10"))
	_panel("sign", Transform3D(Basis.IDENTITY, board), -.4, .4, .46, 1.53, .044, _cell(200, 160, 420, 560))
	_kit.tube("metal", [board + Vector3(-.3, .44, 0), board + Vector3(-.3, 0, 0)], .02, STEEL, 5)
	_kit.tube("metal", [board + Vector3(.3, .44, 0), board + Vector3(.3, 0, 0)], .02, STEEL, 5)
	_bar("metal", Transform3D(Basis.IDENTITY, board), 0, .02, 0, Vector3(.8, .04, .34), STEEL)

func _lobby() -> void:
	# The hotel's door: black, honey-edged, a sample pod in the window to climb into.
	var f := _front
	var x0 := 3.34
	var x1 := 5.86
	var far := -3.0
	var ceiling := 2.8
	_kit.quad("room", f * Vector3(x0, .03, 0), f * Vector3(x0, .03, far), f * Vector3(x1, .03, far), f * Vector3(x1, .03, 0), Color("#2a2620"), .9, .9)
	_kit.quad("room", f * Vector3(x0, ceiling, far), f * Vector3(x0, ceiling, 0), f * Vector3(x1, ceiling, 0), f * Vector3(x1, ceiling, far), Color("#1c1a16"))
	_kit.quad("room", f * Vector3(x0, 0, far), f * Vector3(x0, ceiling, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, 0, far), Color("#3a3226"), .8, 1.0)
	_kit.quad("room", f * Vector3(x0, 0, 0), f * Vector3(x0, ceiling, 0), f * Vector3(x0, ceiling, far), f * Vector3(x0, 0, far), Color("#2e281e"), .8, 1.0)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, ceiling, 0), f * Vector3(x1, 0, 0), Color("#2e281e"), .8, 1.0)
	# Nobody at the desk now: a screen on a post, a honey-lit wall, a bench to wait on.
	_bar("metal", f, 4.1, .6, -1.9, Vector3(.1, 1.2, .1), Color("#17181a"))
	_bar("bottle", f, 4.1, 1.28, -1.86, Vector3(.42, .3, .03), Color("#0b0c0e"))
	_bar("led", f, 4.1, 1.28, -1.84, Vector3(.36, .24, .004), HONEY * .6)
	_bar("lamp", f, (x0 + x1) * .5, 1.5, far + .03, Vector3(1.9, 1.2, .02), Color(.46, .28, .08))
	_bar("cedar", f, 5.1, .22, -2.7, Vector3(1.2, .06, .36), Color("#7a5c3e"))
	_bar("metal", f, 5.1, .1, -2.7, Vector3(1.0, .2, .1), STEEL)
	_strip(f * Vector3(x0 + .1, ceiling - .06, -.2), f * Vector3(x1 - .1, ceiling - .06, -.2), HONEY)
	_kit.quad("front", f * Vector3(x0, .03, -.08), f * Vector3(x0, ceiling, -.08), f * Vector3(x1, ceiling, -.08), f * Vector3(x1, .03, -.08), Color.WHITE)
	for x: float in [x0 + .03, 4.6, x1 - .03]:
		_bar("metal", f, x, ceiling * .5, -.06, Vector3(.05, ceiling, .06), Color("#0d0a06"))
	_bar("metal", f, (x0 + x1) * .5, 2.98, .06, Vector3(x1 - x0 + .12, .36, .2), Color("#0d0a06"))
	_strip(f * Vector3(x0, 2.8, .16), f * Vector3(x1, 2.8, .16), HONEY)
	_panel("sign", f, 4.72, 5.8, .9, 1.72, -.05, _cell(860, 160, 400, 300))
	_bar("bottle", f, 4.5, 1.2, -.04, Vector3(.1, .16, .02), Color("#0b0c0e"))
	_status(f, 4.5, 1.2, -.026, HONEY)

func _undercroft() -> void:
	# The open corner under the podium: columns, bicycles, a wall of parcel lockers.
	var f := _front
	for x: float in [9.1, 12.3]:
		_kit.lathe("concrete", f * Vector3(x, 0, -.3), [Vector2(.26, 0), Vector2(.26, GROUND)], CONCRETE, 16)
		_kit.lathe("concrete", f * Vector3(x, 0, -3.9), [Vector2(.26, 0), Vector2(.26, GROUND)], CONCRETE * .9, 16)
	_kit.quad("plain", f * Vector3(6.0, .03, .3), f * Vector3(6.0, .03, -4.1), f * Vector3(WIDE, .03, -4.1), f * Vector3(WIDE, .03, .3), Color("#5e5e5a"), .75, .75)
	for x: float in [7.4, 10.6]:
		_bar("lamp", f, x, GROUND - .02, -2.0, Vector3(1.2, .03, .08), Color(.76, .8, .8))
	var wall := f.translated_local(Vector3(0, 0, -4.08))
	_bar("metal", wall, 7.6, 1.05, .16, Vector3(2.8, 2.1, .3), Color("#2b2d30"))
	for row: int in range(4):
		for column: int in range(7):
			var x := 6.36 + float(column) * .41
			var y := .3 + float(row) * .5
			_bar("metal", wall, x, y, .318, Vector3(.38, .46, .012), Color("#3a3d40"))
			_status(wall, x + .13, y - .16, .328, AMBER if (row * 7 + column) % 6 == 4 else GREEN)
	for i: int in range(5):
		_parked_bicycle(f * Vector3(8.9 + float(i) * .62, 0, -3.2), [Color("#7a2a24"), Color("#1f4a6a"), Color("#d9d5c6"), Color("#2a2c2e"), Color("#3f6a35")][i])
	_bar("metal", f, 10.1, .28, -3.5, Vector3(3.2, .04, .04), STEEL)
	# What collects at the foot of any old building: pot plants, a cone, a sign nobody moved.
	for row: Array in [[6.5, -.1, .7], [6.95, .12, .95], [7.4, -.2, .6], [11.6, -.2, .85], [12.1, .05, .6]]:
		var at := f * Vector3(row[0], 0, row[1])
		_kit.lathe("plain", at, [Vector2(.14, 0), Vector2(.2, .34), Vector2(.22, .36)], Color("#7f7a70"), 10)
		_plant(at + Vector3.UP * .32, row[2], Color("#3f6a35"))
		_plant(at + Vector3.UP * .34, row[2] * .7, Color("#507a3f"))
	for x: float in [8.3, 10.4]:
		var cone := f * Vector3(x, 0, .2)
		_kit.block("plain", Transform3D(Basis.IDENTITY, cone + Vector3.UP * .02), Vector3(.36, .04, .36), Color("#1b1c1e"))
		_kit.lathe("plain", cone, [Vector2(.14, .04), Vector2(.03, .7)], Color("#e8541c"), 10)
		_kit.lathe("plain", cone + Vector3.UP * .36, [Vector2(.092, 0), Vector2(.066, .14)], Color("#f4f2ea"), 10)

func _roof_sign() -> void:
	# Stood on the open corner of the podium in a steel frame, as every tower here has one.
	var x := WIDE * .5 - .8
	var z := -.7
	var low := PODIUM + .5
	var high := low + 7.4
	var half := .48
	var steel := Color("#35373a")
	_bar("metal", Transform3D.IDENTITY, x, (low + high) * .5, z - .06, Vector3(half * 2.0 + .06, high - low + .06, .1), Color("#101214"))
	_panel("sign", Transform3D.IDENTITY, x - half, x + half, low, high, z, _cell(0, 0, 180, 1400))
	for side: float in [-.36, .36]:
		_kit.tube("metal", [Vector3(x + side, PODIUM, z - .16), Vector3(x + side, high - .1, z - .16)], .04, steel, 6)
		_kit.tube("metal", [Vector3(x + side, PODIUM, z - 1.5), Vector3(x + side, high - 2.0, z - .16)], .025, steel, 5)
	_strip(Vector3(x - half, high + .05, z - .02), Vector3(x + half, high + .05, z - .02), HONEY)

func _retrofit() -> void:
	# What fifty years added: plant on the open podium, and a camera.
	var roof := Transform3D(Basis.IDENTITY, Vector3(0, PODIUM, 0))
	for x: float in [-.2, .9]:
		_bar("metal", roof, x, .06, -1.8, Vector3(.9, .12, .46), STEEL)
		_outdoor_unit(roof, x, .44, -1.8)
	_bar("metal", roof, 1.9, .55, -2.6, Vector3(.8, 1.1, .5), Color("#c9cbc7"))
	_status(roof, 1.7, .96, -2.34, GREEN)
	_kit.tube("metal", [Vector3(-.2, PODIUM + .1, -2.1), Vector3(1.0, PODIUM + .1, -3.2), Vector3(2.2, PODIUM + .1, -3.2), Vector3(2.2, PODIUM + .1, -4.2)], .03, Color("#7c8084"), 6)
	_camera(_front * Vector3(6.1, 3.0, .3))
