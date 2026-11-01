extends "res://scripts/midori_near_city_handmade.gd"
## パーラー銀河: a pachinko hall dressed, as they so often are, as a European palace nobody
## asked for. Three floors of arched windows that were never windows, iron balconies nobody
## can reach, cornices, gold uplights; a tube band over the doors, neon on a dark top band and
## a red billboard on the roof. By 2050 it runs itself, and the machines take palms.
## Local origin is the middle of the east lot's street front; it spreads over two lots west.
const ATLAS := "res://assets/shinrai/near_city/pachinko_atlas.png"
const WASH_SHADER := preload("res://scripts/midori_near_city_wash.gdshader")
const TICKER_SHADER := preload("res://scripts/midori_near_city_ticker.gdshader")
const SHIFT := -4.63 # From the east lot's middle to the middle of the whole site.
const WIDE := 13.6
const DEEP := 9.0
const GROUND := 4.3
const STOREY := 3.3
const FLOORS := 3
const BAYS := 5
const BAY := 2.72
const TOP := 14.2
const BAND := 16.5
const ARCH := .62
const SILL := .55
const SPRING := 1.66 # Where each arch springs, above its floor.
const SHOP_WEST := 1.6
const SHOP_EAST := 12.0
const GLASS := -.5
const ROOM_DEEP := -7.6
const CREAM := Color(.9, .82, .68)
const TRIM := Color(1.0, .94, .82)
const DARK_WALL := Color("#17130f")
const IRON := Color("#1f1a16")
const BRONZE := Color("#3a2c20")
const WARM := Color(1.0, .6, .22)

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	position.x += SHIFT
	_rng.seed = 777
	_build_looks()
	_palace()
	_top_band()
	_ground_floor()
	_hall()
	_arrivals()
	_kiosk()
	_blade()
	_flanks()
	_rooftop()
	_kit.commit(self, _looks, ["front", "wash", "ticker", "decal", "lamp", "led", "leaf", "fascia", "poster", "goods", "room", "carpet", "filigree", "slab", "frost"])
	_kit = null
	_omni("DoorSpill", Vector3(0.2, 2.5, 1.4), Color(1.0, .86, .66), 1.5, 9.0)
	_omni("HallGlow", Vector3(0.2, 2.2, -3.4), Color(1.0, .76, .5), .8, 7.0)

func _build_looks() -> void:
	_shared_looks()
	var signs: Texture2D = load(ATLAS)
	_looks.wall = _look("white_stucco", 2.4, .95)
	_looks.wall.set_shader_parameter("chroma", .7)
	_looks.trim = _look("white_stucco", 1.6, .8)
	_looks.trim.set_shader_parameter("chroma", .5)
	_looks.render = _look("plastered_wall_03", 2.4, .92)
	_looks.render.set_shader_parameter("chroma", .6)
	_looks.slab = _look("", 1.0, .22)
	_looks.slab.set_shader_parameter("albedo_map", signs)
	_looks.frost = _look("", 1.0, .5)
	_looks.frost.set_shader_parameter("albedo_map", signs)
	_looks.frost.set_shader_parameter("glow", .62)
	_looks.frost.set_shader_parameter("day_glow", .12)
	_looks.dark = _look("", 1.0, .28, .35)
	_looks.filigree = _look("", 1.0, .42, .55) # Ironwork too fine to throw a clean shadow.
	_looks.cladding = _look("", 1.0, .5, .3)
	_looks.stone = _look("", 1.0, .2)
	_looks.room = _look("", 1.0, .7)
	_looks.room.set_shader_parameter("glow", .36)
	_looks.room.set_shader_parameter("day_glow", .14)
	_looks.carpet = _look("", 1.0, .9)
	_looks.carpet.set_shader_parameter("tile_size", Vector2(.5, .5))
	_looks.carpet.set_shader_parameter("glow", .22)
	_looks.carpet.set_shader_parameter("day_glow", .14)
	_looks.goods = _look("", 1.0, .4)
	_looks.goods.set_shader_parameter("albedo_map", signs)
	_looks.goods.set_shader_parameter("glow", .6)
	_looks.goods.set_shader_parameter("day_glow", .3)
	_looks.fascia = _look("", 1.0, .9)
	_looks.fascia.set_shader_parameter("albedo_map", signs)
	_looks.fascia.set_shader_parameter("glow", .92)
	_looks.fascia.set_shader_parameter("day_glow", .22)
	_looks.sign = _look("", 1.0, .9)
	_looks.sign.set_shader_parameter("albedo_map", signs)
	_looks.sign.set_shader_parameter("glow", .75)
	_looks.sign.set_shader_parameter("day_glow", .26)
	_looks.poster = _look("", 1.0, .8)
	_looks.poster.set_shader_parameter("albedo_map", signs)
	_looks.poster.set_shader_parameter("glow", .55)
	_looks.poster.set_shader_parameter("day_glow", .3)
	_looks.cloth = _look("", 1.0, .9)
	_looks.cloth.set_shader_parameter("albedo_map", signs)
	_looks.cloth.set_shader_parameter("glow", .2)
	_looks.cloth.set_shader_parameter("day_glow", .08)
	var letters := ShaderMaterial.new()
	letters.shader = DECAL_SHADER
	letters.set_shader_parameter("atlas", signs)
	letters.set_shader_parameter("glow", 1.5)
	letters.set_shader_parameter("day_glow", .5)
	_looks.decal = letters
	var wash := ShaderMaterial.new()
	wash.shader = WASH_SHADER
	_looks.wash = wash
	var ticker := ShaderMaterial.new()
	ticker.shader = TICKER_SHADER
	ticker.set_shader_parameter("atlas", signs)
	var strip := _cell(0, 984, 2048, 56)
	ticker.set_shader_parameter("strip", Vector4(strip.position.x, strip.position.y, strip.size.x, strip.size.y))
	_looks.ticker = ticker

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _stucco(x0: float, x1: float, y0: float, y1: float) -> void:
	var f := _front
	_kit.quad("wall", f * Vector3(x0, y0, 0), f * Vector3(x0, y1, 0), f * Vector3(x1, y1, 0), f * Vector3(x1, y0, 0), CREAM, .9, 1.0, .55, Vector2(x0, -y0))

func _palace() -> void:
	for floor_index: int in range(FLOORS):
		var base := GROUND + float(floor_index) * STOREY
		for bay: int in range(BAYS):
			_arch_bay(BAY * (float(bay) + .5), base)
		_cornice(base)
		_uplights(base)
	_cornice(TOP)
	# Quoins up both corners: plaster pretending to be stone, a block at a time.
	var f := _front
	for x: float in [0.0, WIDE]:
		var y := GROUND + .12
		var long := true
		while y < TOP - .3:
			var wide := .74 if long else .46
			var mid := x + wide * .5 if x == 0.0 else x - wide * .5
			_bar("trim", f, mid, y + .24, .03, Vector3(wide, .46, .06), TRIM, .9, 1.0)
			y += .54
			long = not long
	# Two long sale banners roped down the wall, because the palace still has a job to do.
	for row: Array in [[BAY * 1.0, 130.0], [BAY * 4.0, 2.0]]:
		var x: float = row[0]
		_panel("cloth", f, x - .52, x + .52, GROUND + 1.0, GROUND + 4.82, .05, _cell(row[1], 1410, 120, 440))
		for y: float in [GROUND + .98, GROUND + 4.84]:
			_kit.tube("metal", [f * Vector3(x - .54, y, .055), f * Vector3(x + .54, y, .055)], .012, ALUMINIUM, 4)

func _arch_bay(cx: float, base: float) -> void:
	var f := _front
	var half := BAY * .5
	var sill := base + SILL
	var spring := base + SPRING
	var top := base + STOREY
	var left := cx - half
	var right := cx + half
	_stucco(left, right, base, sill)
	_stucco(left, cx - ARCH, sill, spring)
	_stucco(cx + ARCH, right, sill, spring)
	# Above the spring line the plaster is swept in round the true curve of the arch.
	var rise := top - spring
	var corner := atan2(rise, half)
	var angles: Array[float] = [corner, PI - corner]
	for i: int in range(17):
		angles.append(PI * float(i) / 16.0)
	angles.sort()
	for i: int in range(angles.size() - 1):
		var a0: float = angles[i]
		var a1: float = angles[i + 1]
		if a1 - a0 < .001:
			continue
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var o0 := d0 * minf(half / maxf(absf(d0.x), .001), rise / maxf(d0.y, .001))
		var o1 := d1 * minf(half / maxf(absf(d1.x), .001), rise / maxf(d1.y, .001))
		var i0 := d0 * ARCH
		var i1 := d1 * ARCH
		_kit.quad("wall", f * Vector3(cx + i1.x, spring + i1.y, 0), f * Vector3(cx + o1.x, spring + o1.y, 0), f * Vector3(cx + o0.x, spring + o0.y, 0), f * Vector3(cx + i0.x, spring + i0.y, 0), CREAM, .92, 1.0, .5, Vector2(cx + i1.x, -(spring + i1.y)))
		# The arch's soffit, running back to the dark glass.
		var n0 := Vector3(-d0.x, -d0.y, 0)
		var n1 := Vector3(-d1.x, -d1.y, 0)
		_kit.smooth("plain", f * Vector3(cx + i0.x, spring + i0.y, 0), f * Vector3(cx + i0.x, spring + i0.y, -.32), f * Vector3(cx + i1.x, spring + i1.y, -.32), f * Vector3(cx + i1.x, spring + i1.y, 0), n0, n0, n1, n1, CREAM * .72, .75)
	var x0 := cx - ARCH
	var x1 := cx + ARCH
	var shade := CREAM * .72
	_kit.quad("plain", f * Vector3(x0, sill, 0), f * Vector3(x0, spring, 0), f * Vector3(x0, spring, -.32), f * Vector3(x0, sill, -.32), shade, .8, .75)
	_kit.quad("plain", f * Vector3(x1, sill, -.32), f * Vector3(x1, spring, -.32), f * Vector3(x1, spring, 0), f * Vector3(x1, sill, 0), shade, .8, .75)
	_kit.quad("plain", f * Vector3(x0, sill, 0), f * Vector3(x0, sill, -.32), f * Vector3(x1, sill, -.32), f * Vector3(x1, sill, 0), shade, .9, .9)
	# Black glass that has never had a room behind it, bronze bars and a sunburst head.
	var z := -.3
	_kit.quad("dark", f * Vector3(x0, sill, z), f * Vector3(x0, spring, z), f * Vector3(x1, spring, z), f * Vector3(x1, sill, z), Color("#10151c"))
	_kit.disc("dark", f * Vector3(cx, spring, z - .002), Vector3.RIGHT, Vector3.UP, ARCH, Color("#10151c"))
	_bar("metal", f, cx, (sill + spring + ARCH) * .5, z + .02, Vector3(.03, spring + ARCH - sill, .03), BRONZE)
	for y: float in [sill + .38, sill + .74, spring]:
		_bar("metal", f, cx, y, z + .02, Vector3(ARCH * 2.0, .03, .03), BRONZE)
	for a: float in [PI * .25, PI * .75]:
		var tip := Vector3(cx + cos(a) * ARCH, spring + sin(a) * ARCH, z + .02)
		_kit.beam("metal", f * Vector3(cx, spring, z + .02), f * tip, .025, .025, Vector3.BACK, BRONZE)
	var head: Array[Vector3] = []
	for i: int in range(11):
		var a := PI * float(i) / 10.0
		head.append(f * Vector3(cx + cos(a) * ARCH * .5, spring + sin(a) * ARCH * .5, z + .02))
	_kit.tube("metal", head, .014, BRONZE, 4)
	# Moulded surround, keystone and sill, all of it plaster over a steel box.
	var mould: Array[Vector3] = [f * Vector3(cx + ARCH + .06, sill, .05)]
	for i: int in range(17):
		var a := PI * float(i) / 16.0
		mould.append(f * Vector3(cx + cos(a) * (ARCH + .06), spring + sin(a) * (ARCH + .06), .05))
	mould.append(f * Vector3(cx - ARCH - .06, sill, .05))
	_kit.tube("trim", mould, .06, TRIM, 6)
	_bar("trim", f, cx, spring + ARCH + .14, .07, Vector3(.26, .38, .14), TRIM)
	_bar("trim", f, cx, sill - .05, .08, Vector3(ARCH * 2.0 + .4, .1, .18), TRIM)
	for side: float in [-1.0, 1.0]:
		_bar("trim", f, cx + side * (ARCH + .06), spring, .07, Vector3(.2, .1, .15), TRIM)
	_balcony(cx, sill + .04)

func _balcony(cx: float, y: float) -> void:
	# Wrought iron nobody has ever stood behind, with a scroll in each panel.
	var f := _front
	var half := .78
	var tall := .66
	var z := .24
	_bar("metal", f, cx, y - .02, .13, Vector3(half * 2.0 + .1, .04, .26), IRON)
	_kit.tube("metal", [f * Vector3(cx - half, y + tall, 0), f * Vector3(cx - half, y + tall, z), f * Vector3(cx + half, y + tall, z), f * Vector3(cx + half, y + tall, 0)], .018, IRON, 5)
	_kit.tube("filigree", [f * Vector3(cx - half, y + .05, z), f * Vector3(cx + half, y + .05, z)], .012, IRON, 4)
	_kit.tube("filigree", [f * Vector3(cx - half, y + .48, z), f * Vector3(cx + half, y + .48, z)], .01, IRON, 4)
	var rods := 12
	for i: int in range(rods + 1):
		_bar("filigree", f, cx - half + half * 2.0 * float(i) / float(rods), y + tall * .5, z, Vector3(.014, tall, .014), IRON)
	for i: int in range(4):
		var c := Vector3(cx - half + half * (float(i) + .5) * .5, y + .26, z + .005)
		var ring: Array[Vector3] = []
		for k: int in range(9):
			var a := TAU * float(k) / 8.0
			ring.append(f * (c + Vector3(cos(a), sin(a), 0) * .13))
		_kit.tube("filigree", ring, .009, IRON, 3)

func _cornice(y: float) -> void:
	# Three stepped courses, deep enough for the sun to rule a line of shadow under them.
	var f := _front
	var mid := WIDE * .5
	_bar("trim", f, mid, y + .02, .04, Vector3(WIDE + .1, .1, .1), TRIM, .75, 1.0)
	_bar("trim", f, mid, y + .12, .1, Vector3(WIDE + .16, .1, .22), TRIM, .7, 1.0)
	_bar("trim", f, mid, y + .22, .15, Vector3(WIDE + .24, .1, .32), TRIM, .7, 1.0)
	_bar("led", f, WIDE * .5, y - .075, .135, Vector3(WIDE, .02, .02), WARM * .7)
	_bar("metal", f, WIDE * .5, y - .05, .1, Vector3(WIDE, .03, .06), Color("#6e6a60"))

func _uplights(base: float) -> void:
	# A small lamp on a bracket at the foot of every pier, and the fan of light it throws.
	var f := _front
	for i: int in range(BAYS + 1):
		var x := clampf(BAY * float(i), .86, WIDE - .86)
		var y := base + .3
		_kit.lathe("metal", f * Vector3(x, y, .16), [Vector2(.03, 0), Vector2(.08, .1), Vector2(.09, .12)], Color("#2a2622"), 8)
		_bar("metal", f, x, y + .03, .08, Vector3(.03, .03, .16), Color("#2a2622"))
		_kit.disc("lamp", f * Vector3(x, y + .125, .16), Vector3.RIGHT, Vector3.FORWARD, .07, Color(1.0, .74, .4))
		_panel("wash", f, x - .72, x + .72, y + .1, base + STOREY - .1, .012, Rect2(0, 0, 1, 1), Color(1.0, .54, .16) * .9)

func _top_band() -> void:
	# Dark cladding over the palace: nobody ever explained why, and they all have it.
	var f := _front
	_kit.quad("cladding", f * Vector3(0, TOP, 0), f * Vector3(0, BAND, 0), f * Vector3(WIDE, BAND, 0), f * Vector3(WIDE, TOP, 0), DARK_WALL, .9, 1.0, .3)
	var x := .0
	while x <= WIDE + .01:
		_bar("metal", f, x, (TOP + BAND) * .5, .012, Vector3(.02, BAND - TOP, .024), Color("#2c2622"))
		x += 1.36
	_panel("ticker", f, .3, WIDE - .3, TOP + .34, TOP + .78, .06, Rect2(0, 0, 1, 1))
	_bar("metal", f, WIDE * .5, TOP + .56, .02, Vector3(WIDE - .5, .52, .06), Color("#0a0b0e"))
	_panel("decal", f, .42, WIDE - .42, TOP + .84, BAND - .1, .024, _cell(0, 180, 2048, 300))
	_bar("metal", f, WIDE * .5, BAND + .06, -.1, Vector3(WIDE + .1, .12, .34), Color("#8a8c8a"))
	# Hooded lamps along the top cornice, doing the job of a chandelier.
	for i: int in range(BAYS):
		var lamp_x := BAY * (float(i) + .5)
		_kit.tube("metal", [f * Vector3(lamp_x, TOP + .02, .1), f * Vector3(lamp_x, TOP - .2, .42)], .012, IRON, 4)
		_kit.lathe("metal", f * Vector3(lamp_x, TOP - .34, .42), [Vector2(.16, 0), Vector2(.12, .08), Vector2(.03, .15)], Color("#2a2622"), 9)
		_kit.disc("lamp", f * Vector3(lamp_x, TOP - .342, .42), Vector3.RIGHT, Vector3.BACK, .14, Color(1.0, .78, .46))

func _ground_floor() -> void:
	var f := _front
	# Polished stone to each end, the white tube band across the whole front.
	for row: Array in [[0.0, SHOP_WEST], [SHOP_EAST, WIDE]]:
		var x0: float = row[0]
		var x1: float = row[1]
		_bar("stone", f, (x0 + x1) * .5, 1.56, -.15, Vector3(x1 - x0, 3.12, .3), Color("#1c1616"), .8, .8)
		_slabs(x0, x1)
	_bar("metal", f, WIDE * .5, 3.72, .1, Vector3(WIDE + .04, 1.16, .4), Color("#c6cbce"))
	_panel("fascia", f, .0, WIDE, 3.16, 4.28, .302, _cell(0, 0, 2048, 170))
	_stucco(0.0, WIDE, 3.0, GROUND)
	_bar("metal", f, WIDE * .5, 3.1, -.1, Vector3(WIDE, .1, .86), Color("#57504a"))
	for i: int in range(8):
		var at := f * Vector3(2.3 + float(i) * 1.3, 3.048, .0)
		_kit.disc("lamp", at, Vector3.RIGHT, Vector3.BACK, .06, Color(.9, .82, .68))
	# Riser and glass, doors in the middle, posters filling every pane they can.
	for row: Array in [[SHOP_WEST, 5.2], [8.4, SHOP_EAST]]:
		var x0: float = row[0]
		var x1: float = row[1]
		_bar("stone", f, (x0 + x1) * .5, .24, GLASS - .03, Vector3(x1 - x0, .48, .14), Color("#2c2422"), .8, .9)
		_kit.quad("front", f * Vector3(x0, .48, GLASS), f * Vector3(x0, 3.05, GLASS), f * Vector3(x1, 3.05, GLASS), f * Vector3(x1, .48, GLASS), Color.WHITE)
		var x := x0
		while x <= x1 + .01:
			_bar("metal", f, x, 1.76, GLASS, Vector3(.06, 2.6, .1), BRONZE)
			x += (x1 - x0) / 3.0
		_bar("metal", f, (x0 + x1) * .5, .5, GLASS, Vector3(x1 - x0, .05, .1), BRONZE)
		_bar("metal", f, (x0 + x1) * .5, 2.32, GLASS, Vector3(x1 - x0, .05, .1), BRONZE)
	var cards: Array[int] = [0, 3, 2, 1, 4, 0]
	for i: int in range(6):
		var left := SHOP_WEST + .16 + float(i % 3) * 1.2 + (6.8 if i > 2 else 0.0)
		_panel("poster", f, left, left + .9, .86, 2.14, GLASS - .04, _cell(float(cards[i]) * 250.0, 1056, 240, 340))
	# Doors: two sliding leaves, a brass-coloured frame, and the greeting on the transom.
	var d0 := 5.2
	var d1 := 8.4
	_kit.quad("front", f * Vector3(d0, .03, GLASS), f * Vector3(d0, 2.36, GLASS), f * Vector3(d1, 2.36, GLASS), f * Vector3(d1, .03, GLASS), Color.WHITE)
	for x: float in [d0, 6.0, 6.8, 7.6, d1]:
		_bar("metal", f, x, 1.2, GLASS + .01, Vector3(.07, 2.36, .08), Color("#a8843c"))
	_bar("metal", f, 6.8, 2.38, GLASS + .01, Vector3(d1 - d0, .1, .1), Color("#a8843c"))
	_bar("metal", f, 6.8, 2.74, GLASS - .02, Vector3(d1 - d0, .62, .06), Color("#14171c"))
	_panel("poster", f, 5.4, 8.2, 2.5, 2.98, GLASS + .02, _cell(1670, 1410, 370, 100))
	_bar("metal", f, 6.8, .03, GLASS + .3, Vector3(d1 - d0, .03, .7), Color("#7a1218"))

func _slabs(x0: float, x1: float) -> void:
	# Polished granite, each slab cut from a different part of the block, a hair of joint between.
	var per_metre := 160.0
	var y := .0
	while y < 3.11:
		var high := minf(y + .9, 3.12)
		var x := x0
		while x < x1 - .01:
			var right := minf(x + .8, x1)
			var u := 1210.0 + _rng.randf() * (400.0 - (right - x) * per_metre)
			var v := 500.0 + _rng.randf() * (400.0 - (high - y) * per_metre)
			_panel("slab", _front, x + .006, right - .006, y + .006, high - .006, .004, _cell(u, v, (right - x) * per_metre, (high - y) * per_metre))
			x = right
		y = high

func _hall() -> void:
	# The real thing behind the palace: banks of machines down a loud carpet.
	var f := _front
	var x0 := SHOP_WEST
	var x1 := SHOP_EAST
	var far := ROOM_DEEP
	var ceiling := 3.04
	_kit.quad("carpet", f * Vector3(x0, .02, GLASS), f * Vector3(x0, .02, far), f * Vector3(x1, .02, far), f * Vector3(x1, .02, GLASS), Color(.5, .12, .2), 1.0, 1.0, 0.0, Vector2(x0, 0))
	_kit.quad("room", f * Vector3(x0, ceiling, far), f * Vector3(x0, ceiling, GLASS), f * Vector3(x1, ceiling, GLASS), f * Vector3(x1, ceiling, far), Color("#2a2228"))
	_kit.quad("room", f * Vector3(x0, 0, far), f * Vector3(x0, ceiling, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, 0, far), Color("#5a2030"), .8, 1.0)
	_kit.quad("room", f * Vector3(x0, 0, GLASS), f * Vector3(x0, ceiling, GLASS), f * Vector3(x0, ceiling, far), f * Vector3(x0, 0, far), Color("#5a2030"), .8, 1.0)
	_kit.quad("room", f * Vector3(x1, 0, far), f * Vector3(x1, ceiling, far), f * Vector3(x1, ceiling, GLASS), f * Vector3(x1, 0, GLASS), Color("#5a2030"), .8, 1.0)
	for x: float in [3.0, 4.9, 8.7, 10.6]:
		_bank(x)
	for x: float in [2.0, 4.0, 6.8, 9.6, 11.6]:
		_bar("lamp", f, x, ceiling - .02, -3.8, Vector3(.1, .02, 5.6), Color(.7, .62, .48))

func _bank(x: float) -> void:
	# Machines shoulder to shoulder on both faces, each with its stool and its lamp on top.
	var f := _front
	var near := -1.3
	var far := -7.0
	var mid := (near + far) * .5
	var length := near - far
	_bar("room", f, x, 1.1, mid, Vector3(.5, 2.2, length), Color("#2a2228"))
	for side: Transform3D in [Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x, 0, near)), Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x, 0, far))]:
		var count := 9
		for i: int in range(count):
			var at := (float(i) + .5) * length / float(count)
			var wide := length / float(count) - .04
			var kind := _rng.randi_range(0, 2)
			_panel("goods", side, at - wide * .5, at + wide * .5, .72, 1.68, .26, _cell(1270.0 + float(kind) * 256.0, 1056, 240, 340))
			_bar("led", side, at, 1.78, .26, Vector3(wide - .04, .05, .01), [Color(1.0, .2, .2), Color(.3, .8, 1.0), Color(1.0, .8, .2)][kind])
			_kit.lathe("room", side * Vector3(at, 0, .78), [Vector2(.14, .04), Vector2(.04, .06), Vector2(.04, .42), Vector2(.16, .46), Vector2(.15, .52), Vector2(0, .54)], Color("#7a2a30"), 7)
	_bar("goods", f, x, 1.2, near + .03, Vector3(.46, .9, .03), Color.WHITE)
	_panel("goods", f, x - .22, x + .22, .84, 1.52, near + .05, _cell(float(int(x) % 5) * 250.0, 1056, 240, 340))

func _arrivals() -> void:
	# What a parlour puts out for a new line-up: balloons, flower rounds, flags and a greeter.
	var f := _front
	var tones: Array[Color] = [Color("#e8202a"), Color("#ffffff"), Color("#ffd21e"), Color("#2a6fe0"), Color("#ff6aa8")]
	var count := 34
	for i: int in range(count):
		var a := PI * float(i) / float(count - 1)
		var r := 1.0 + .03 * sin(float(i) * 2.1)
		var at := Vector3(6.8 + cos(a) * 1.92 * r, sin(a) * 2.96 * r, .34)
		_balloon(f * at, tones[i % 5], .15)
		_balloon(f * (at + Vector3(cos(a) * .18, sin(a) * .16, .1)), tones[(i + 2) % 5], .12)
	_wreath(3.6, _cell(400, 1410, 256, 256))
	_wreath(10.0, _cell(662, 1410, 256, 256))
	_flag(f * Vector3(2.5, 0, 1.5), .15, 2)
	_flag(f * Vector3(10.7, 0, 1.5), -.15, 132)
	_flag(f * Vector3(12.0, 0, 1.5), .2, 262)
	_greeter(f * Vector3(4.55, 0, .3))

func _balloon(at: Vector3, tint: Color, size: float) -> void:
	_kit.lathe("bottle", at, [Vector2(.01, -size), Vector2(size * .5, -size * .87), Vector2(size * .87, -size * .5), Vector2(size, 0), Vector2(size * .87, size * .5), Vector2(size * .5, size * .87), Vector2(.01, size)], tint, 12)

func _wreath(x: float, rect: Rect2) -> void:
	# 花輪 on a bamboo tripod, turned a little towards whoever is coming.
	var f := _front
	var c := f * Vector3(x, 1.72, .56)
	var bamboo := Color("#b8a468")
	for foot: Vector3 in [Vector3(-.4, 0, .3), Vector3(.4, 0, .3), Vector3(0, 0, -.3)]:
		_kit.tube("metal", [c + Vector3.DOWN * .3, f * Vector3(x, 0, .56) + foot], .018, bamboo, 5)
	_kit.disc("cloth", c, Vector3.RIGHT, Vector3.UP, .66, Color.WHITE, rect)
	_kit.disc("metal", c + Vector3.BACK * -.01, Vector3.LEFT, Vector3.UP, .66, Color("#8a8c8a"))

func _flag(foot: Vector3, turn: float, column: float) -> void:
	var spin := Basis(Vector3.UP, turn)
	_kit.lathe("metal", foot, [Vector2(.16, 0), Vector2(.16, .1), Vector2(.03, .14)], Color("#3a3d40"), 10)
	_kit.tube("metal", [foot, foot + Vector3.UP * 2.9], .016, Color("#c9cbc9"), 6)
	_kit.tube("metal", [foot + Vector3.UP * 2.86, foot + Vector3.UP * 2.86 + spin * Vector3(.6, 0, 0)], .01, Color("#c9cbc9"), 5)
	var rect := _cell(column, 1410, 120, 440)
	var low := .7
	var high := 2.84
	var a := foot + spin * Vector3(.02, 0, 0)
	var e := foot + spin * Vector3(.6, 0, 0)
	_kit.atlas("cloth", a + Vector3.UP * low, a + Vector3.UP * high, e + Vector3.UP * high, e + Vector3.UP * low, rect)
	_kit.atlas("cloth", e + Vector3.UP * low, e + Vector3.UP * high, a + Vector3.UP * high, a + Vector3.UP * low, rect)

func _greeter(at: Vector3) -> void:
	# The only member of staff: a white post on wheels that bows when the doors open.
	_kit.lathe("plain", at, [Vector2(.22, .02), Vector2(.24, .1), Vector2(.17, .4), Vector2(.15, .9), Vector2(.17, 1.02), Vector2(.13, 1.14), Vector2(.02, 1.18)], Color("#e6e8e6"), 12)
	_panel("poster", Transform3D(Basis.IDENTITY, at), -.1, .1, .86, 1.06, .172, _cell(920, 1510, 140, 140))
	_bar("led", Transform3D(Basis.IDENTITY, at), 0, .46, .19, Vector3(.2, .03, .01), Color(1.0, .68, .16))

func _kiosk() -> void:
	# 景品交換所: the hut where the prizes quietly become money. It is never part of the hall and
	# never shows a face: frosted glass, a mouse-hole, a dish and, since the palms, a pad.
	var f := _front
	var west := .2
	var east := 1.4
	var out := .36
	var counter := 1.0
	var head := 1.86
	var roof := 2.44
	var sheet := Color("#cfd2cc")
	var mid := (west + east) * .5
	_bar("plain", f, mid, counter * .5, out * .5, Vector3(east - west, counter, out), sheet)
	_bar("plain", f, mid, (head + roof) * .5, out * .5, Vector3(east - west, roof - head, out), sheet)
	for x: float in [west + .07, east - .07]:
		_bar("plain", f, x, (counter + head) * .5, out * .5, Vector3(.14, head - counter, out), sheet)
	var rib := west + .06
	while rib < east - .02:
		_bar("plain", f, rib, counter * .5, out + .006, Vector3(.035, counter, .012), sheet)
		_bar("plain", f, rib, (head + roof) * .5, out + .006, Vector3(.035, roof - head, .012), sheet)
		rib += .12
	# The pane sits back in its box, with an aluminium frame and the hole the money comes through.
	var pane_west := west + .14
	var pane_east := east - .14
	_panel("frost", f, pane_west, pane_east, counter, head, .26, _cell(1670, 1520, 300, 286))
	_bar("metal", f, mid, head - .015, .27, Vector3(pane_east - pane_west, .03, .03), ALUMINIUM)
	_bar("metal", f, mid, 1.5, .27, Vector3(pane_east - pane_west, .02, .02), ALUMINIUM)
	for x: float in [pane_west + .015, pane_east - .015]:
		_bar("metal", f, x, (counter + head) * .5, .27, Vector3(.03, head - counter, .03), ALUMINIUM)
	_kit.disc("dark", f * Vector3(mid, counter, .266), Vector3.RIGHT, Vector3.UP, .19, Color("#08090b"))
	var arch: Array[Vector3] = []
	for i: int in range(13):
		var a := PI * float(i) / 12.0
		arch.append(f * Vector3(mid + cos(a) * .2, counter + sin(a) * .2, .272))
	_kit.tube("metal", arch, .01, ALUMINIUM, 4)
	# Steel shelf, the dish that is always slightly dented, and the palm pad on its stalk.
	_bar("metal", f, mid, counter - .005, .42, Vector3(east - west - .1, .035, .3), Color("#c8ccca"))
	var dish := f * Vector3(mid - .08, counter + .013, .43)
	_kit.lathe("metal", dish, [Vector2(.08, 0), Vector2(.125, .03), Vector2(.13, .04)], Color("#d4d6d4"), 16)
	_kit.lathe("metal", dish, [Vector2(.13, .04), Vector2(.105, .012), Vector2(.0, .006)], Color("#8e9290"), 16)
	_kit.tube("metal", [f * Vector3(1.14, counter + .012, .46), f * Vector3(1.14, counter + .15, .44)], .012, STEEL, 5)
	_bar("bottle", f, 1.14, counter + .165, .44, Vector3(.17, .025, .15), Color("#0b0c0e"))
	_kit.disc("lamp", f * Vector3(1.14, counter + .179, .44), Vector3.RIGHT, Vector3.FORWARD, .055, CYAN)
	_panel("poster", f, .5, 1.1, .46, .84, out + .014, _cell(920, 1660, 300, 190))
	# Lit name box on top, with a lamp in its belly to keep the shelf readable at night.
	_bar("plain", f, mid, 2.6, .24, Vector3(east - west + .16, .32, .48), Color("#14306e"))
	_panel("sign", f, .3, 1.3, 2.45, 2.75, .482, _cell(920, 1410, 300, 90))
	_bar("lamp", f, mid, 2.436, .4, Vector3(.8, .012, .06), Color(1.0, .92, .78))
	_bar("bottle", f, east - .07, 1.3, out + .01, Vector3(.08, .14, .02), Color("#0b0c0e"))
	_status(f, east - .07, 1.3, out + .025, CYAN)
	_camera(f * Vector3(.3, 2.43, .42))
	_fibre([f * Vector3(.26, 3.1, .03), f * Vector3(.26, 2.76, .03), f * Vector3(.26, 2.76, .4)])
	# Staff door at the far end, and the plant that keeps the building cold.
	_bar("metal", f, 12.8, 1.1, .015, Vector3(1.02, 2.2, .03), Color("#26231f"))
	_bar("plain", f, 12.8, 1.08, .035, Vector3(.9, 2.1, .03), Color("#4a4640"))
	_bar("metal", f, 13.1, 1.1, .065, Vector3(.03, .2, .04), ALUMINIUM)
	_camera(f * Vector3(12.8, 3.04, .4))
	_fibre([f * Vector3(13.45, 3.0, .03), f * Vector3(13.45, .3, .03)])

func _blade() -> void:
	# Tower sign off the east corner: the palace speaks to the park, this speaks along the street.
	var f := _front
	var x := WIDE - .42
	var near := .46
	var far := 1.76
	var low := 5.0
	var mid := 9.4
	var high := 13.8
	var steel := Color("#22242a")
	var out := (near + far) * .5
	_bar("metal", f, x, (low + high) * .5, out, Vector3(.24, high - low, far - near), steel)
	var east_side := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), f * Vector3(x + .12, 0, far))
	var west_side := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), f * Vector3(x - .12, 0, near))
	for side: Transform3D in [east_side, west_side]:
		_panel("sign", side, 0, far - near, low, mid, .004, _cell(1620, 496, 140, 470))
		_panel("sign", side, 0, far - near, mid, high, .004, _cell(1770, 496, 140, 470))
	_bar("led", f, x, (low + high) * .5, far + .012, Vector3(.2, high - low, .02), WARM)
	for y: float in [low + .4, 7.6, mid + .2, 11.8, high - .4]:
		_bar("metal", f, x, y, .23, Vector3(.1, .1, .46), steel)
	# ギンちゃん on a round crown, both ways, with a ring of steel to hold him together.
	var crown := f * Vector3(x, high + .78, out)
	_bar("metal", f, x, high + .04, out, Vector3(.1, .08, .9), steel)
	_kit.disc("sign", crown + Vector3.RIGHT * .05, Vector3.FORWARD, Vector3.UP, .72, Color.WHITE, _cell(1240, 1410, 420, 420))
	_kit.disc("sign", crown + Vector3.LEFT * .05, Vector3.BACK, Vector3.UP, .72, Color.WHITE, _cell(1240, 1410, 420, 420))
	var ring: Array[Vector3] = []
	for i: int in range(25):
		var a := TAU * float(i) / 24.0
		ring.append(crown + Vector3(0, sin(a), cos(a)) * .74)
	_kit.tube("metal", ring, .05, steel, 6)

func _flanks() -> void:
	# The palace stops a hand past the corner: everywhere else is cheap panel, pipes and plant.
	var paint := Color(.72, .71, .66)
	_render_wall(_east, DEEP, BAND, GROUND, STOREY, paint, [] as Array[Rect2], .6)
	_render_wall(_west, DEEP, BAND, GROUND, STOREY, paint, [] as Array[Rect2], .6)
	_render_wall(_back, WIDE, BAND, GROUND, STOREY, paint, [] as Array[Rect2], .6)
	for face: Transform3D in [_east, _west]:
		var x := .6
		while x < DEEP - .1:
			_bar("plain", face, x, BAND * .5, .004, Vector3(.016, BAND, .012), paint * .55)
			x += .6
	# The plaster wraps the corner just far enough to fool anyone walking straight at it.
	_bar("wall", _east, .24, TOP * .5, .02, Vector3(.48, TOP, .04), CREAM)
	_bar("wall", _west, DEEP - .24, TOP * .5, .02, Vector3(.48, TOP, .04), CREAM)
	_kit.block("cladding", _at(_east, .5, (TOP + BAND) * .5, .01), Vector3(1.0, BAND - TOP, .02), DARK_WALL, .9, 1.0, .3)
	_kit.block("cladding", _at(_west, DEEP - .5, (TOP + BAND) * .5, .01), Vector3(1.0, BAND - TOP, .02), DARK_WALL, .9, 1.0, .3)
	for x: float in [.5, 7.6]:
		_kit.tube("plain", [_west * Vector3(x, .1, .08), _west * Vector3(x, BAND - .2, .08)], .05, Color("#8a8b84"), 7)
	# The lane opened this wall up, so ギンちゃん gets it after all, in sign paint gone chalky.
	_panel("sign", _west, 1.0, 7.0, 7.4, 13.4, .03, _cell(1240, 1410, 420, 420), Color(.82, .8, .76))
	_kit.tube("plain", [_east * Vector3(1.4, .1, .08), _east * Vector3(1.4, BAND - .2, .08)], .05, Color("#8a8b84"), 7)
	_east_plant()
	_alley()

func _east_plant() -> void:
	# Condensers racked over the lane, and the hall's own stale air going up the far side.
	var e := _east
	for row: int in range(3):
		_bar("metal", _west, 2.9, 3.3 + float(row) * .96, .16, Vector3(3.5, .05, .42), STEEL)
		for col: int in range(3):
			_outdoor_unit(_west, 1.8 + float(col) * 1.1, 3.66 + float(row) * .96, .22)
	var duct := Color("#b4b6b2")
	_kit.tube("metal", [e * Vector3(5.2, 7.0, .3), e * Vector3(5.2, BAND + .5, .3), e * Vector3(5.2, BAND + .5, -1.4)], .24, duct, 10)
	var y := 7.8
	while y < BAND:
		_bar("metal", e, 5.2, y, .3, Vector3(.54, .04, .54), STEEL)
		y += 1.6

func _alley() -> void:
	# What the slot beside the dentist hides: fire door, meters, yellow gas pipe, the bins.
	var w := _west
	var street := DEEP
	var door := street - 2.3
	_bar("metal", w, door, 1.04, .02, Vector3(1.02, 2.08, .04), Color("#3e3c38"))
	_bar("plain", w, door, 1.02, .045, Vector3(.9, 2.0, .03), Color(.5, .5, .46))
	_bar("metal", w, door + .34, 1.0, .08, Vector3(.03, .2, .04), ALUMINIUM)
	_panel("sign", w, door - .3, door + .3, 2.24, 2.54, .012, _cell(1240, 1840, 300, 150))
	var meter_x := street - 1.0
	_bar("metal", w, meter_x, 1.5, .1, Vector3(.56, .74, .2), Color("#9a9c98"))
	for i: int in range(3):
		_kit.disc("bottle", w * Vector3(meter_x - .16 + float(i) * .16, 1.62, .202), w.basis.x, w.basis.y, .055, Color("#20262a"))
	_bar("led", w, meter_x + .2, 1.3, .205, Vector3(.03, .03, .01), GREEN)
	var gas := Color("#d8b020")
	_kit.tube("plain", [w * Vector3(street - .62, .02, .06), w * Vector3(street - .62, 1.0, .06), w * Vector3(street - .62, 2.8, .06)], .022, gas, 6)
	_bar("metal", w, street - .62, 1.04, .14, Vector3(.26, .34, .18), Color("#b8bab6"))
	_kit.tube("plain", [w * Vector3(meter_x, 1.88, .1), w * Vector3(meter_x, 2.9, .1)], .03, Color("#3a3c3e"), 6)
	# The back, seen for a moment through the gap: one pipe and a condenser, and no effort at all.
	_kit.tube("plain", [_back * Vector3(WIDE - 1.2, .1, .08), _back * Vector3(WIDE - 1.2, BAND - .2, .08)], .05, Color("#8a8b84"), 7)
	_outdoor_unit(_back, WIDE - 2.4, 3.4, .2)
	for row: Array in [[-1.6, Color("#2c5c94")], [-2.3, Color("#3a6a4a")]]:
		var at := Vector3(-WIDE * .5 - .32, 0, row[0])
		_kit.lathe("plain", at, [Vector2(.18, 0), Vector2(.22, .62), Vector2(.24, .66), Vector2(.2, .7), Vector2(0, .72)], row[1], 12)

func _rooftop() -> void:
	var half := WIDE * .5
	var level := BAND + .02
	_kit.quad("plain", Vector3(-half, level, 0), Vector3(-half, level, -DEEP), Vector3(half, level, -DEEP), Vector3(half, level, 0), Color("#5f7560"), .8, .9)
	var roof := Transform3D(Basis.IDENTITY, Vector3(0, level, 0))
	# Green waterproofing with its patches, a parapet, and the stair that brings the chiller man up.
	for row: Array in [[-2.6, -3.4, 5.0], [1.9, -4.9, 3.2]]:
		_bar("plain", roof, row[0], .006, row[1], Vector3(row[2], .012, .7), Color("#54675a"))
	var parapet := Color("#8f8e88")
	for row: Array in [[0.0, -.09, WIDE, .18], [0.0, -DEEP + .09, WIDE, .18], [-half + .09, -DEEP * .5, .18, DEEP], [half - .09, -DEEP * .5, .18, DEEP]]:
		_bar("render", roof, row[0], .2, row[1], Vector3(row[2], .4, row[3]), parapet)
		_bar("metal", roof, row[0], .42, row[1], Vector3(row[2] + .03, .04, row[3] + .03), Color("#a8aaa8"))
	_bar("render", roof, 5.9, 1.1, -5.0, Vector3(1.4, 2.2, 2.4), Color(.72, .71, .66))
	_bar("metal", roof, 5.9, 2.24, -5.0, Vector3(1.5, .08, 2.5), Color("#8a8c8a"))
	_bar("metal", roof, 5.18, .95, -4.6, Vector3(.04, 1.9, .84), Color("#5e5a52"))
	# Chillers: a room full of machines runs hot in any century.
	for x: float in [-4.6, -1.8, 1.0, 3.8]:
		_bar("metal", roof, x, .7, -6.6, Vector3(2.3, 1.4, 1.7), Color("#a9adae"), .85, 1.0)
		for dx: float in [-.56, .56]:
			_kit.lathe("plain", Vector3(x + dx, level + 1.4, -6.6), [Vector2(.46, 0), Vector2(.48, .12)], Color("#1a1c1e"), 12)
	_kit.tube("metal", [Vector3(-5.6, level + .3, -5.6), Vector3(-5.6, level + .3, -4.2), Vector3(4.6, level + .3, -4.2)], .1, Color("#a4a8aa"), 8)
	_billboard()

func _billboard() -> void:
	# Red board on a steel frame, the first thing the ward sees of the place, lit from above.
	var z := -1.5
	var low := BAND + 1.0
	var wide := 10.0
	var tall := 4.0
	var high := low + tall
	var steel := Color("#3a3d40")
	var f := Transform3D(Basis.IDENTITY, Vector3(0, 0, z))
	_bar("metal", f, 0, low + tall * .5, -.1, Vector3(wide + .1, tall + .1, .16), Color("#2a2c2e"), .85, 1.0)
	_panel("sign", f, -wide * .5, wide * .5, low, high, .0, _cell(0, 490, 1200, 480))
	for x: float in [-4.4, -2.2, 0.0, 2.2, 4.4]:
		_kit.tube("metal", [Vector3(x, BAND, z - .3), Vector3(x, high, z - .3)], .07, steel, 7)
		_kit.tube("metal", [Vector3(x, BAND, z - 2.2), Vector3(x, high - 1.0, z - .3)], .05, steel, 6)
		_bar("metal", Transform3D.IDENTITY, x, BAND + .1, z - 1.2, Vector3(.08, .08, 2.4), steel)
		# Lamp on a long arm over the top edge, in the old way.
		_kit.tube("metal", [Vector3(x + .9, high + .06, z - .1), Vector3(x + .9, high + .56, z + .62)], .022, steel, 5)
		_bar("metal", Transform3D.IDENTITY, x + .9, high + .56, z + .66, Vector3(.42, .1, .2), Color("#55585a"))
		_bar("lamp", Transform3D.IDENTITY, x + .9, high + .5, z + .66, Vector3(.36, .012, .16), Color(1.0, .92, .76))
	_kit.tube("metal", [Vector3(-wide * .5, low - .3, z + .3), Vector3(wide * .5, low - .3, z + .3)], .02, Color("#7f8488"), 5)
	_bar("metal", Transform3D.IDENTITY, 0, low - .42, z + .1, Vector3(wide, .04, .44), steel)
