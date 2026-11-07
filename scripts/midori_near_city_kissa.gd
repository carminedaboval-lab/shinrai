extends "res://scripts/midori_near_city_handmade.gd"
## 純喫茶リラ: a three-storey coffee house of 1961 on a five-metre lot. Dark brick to the street,
## two arched windows with lace half drawn, a heavy oak door with a bell, and the plastic sample
## case by it. Inside: wine velvet booths, a long counter with its siphons and cup wall, a tall
## clock. The Takanashi family live over the shop; a drone hatch was let into their wall in the 40s.
const ATLAS := "res://assets/shinrai/near_city/kissa_atlas.png"
const WIDE := 5.2
const DEEP := 7.3
const GROUND := 3.3
const PITCH := 2.75
const ROOF := GROUND + PITCH * 2.0
const PARAPET := ROOF + .6
const CASE_X0 := .3
const CASE_X1 := 1.45
const CASE_Y0 := .72
const CASE_Y1 := 1.5
const CASE_Z := .42
const DOOR_X0 := 1.68
const DOOR_X1 := 2.56
const DOOR_TOP := 2.18
const ARCHES: Array[Vector2] = [Vector2(2.82, 3.86), Vector2(3.98, 5.0)]
const SILL := .78
const SPRING := 2.06
const REVEAL := .26
const ROOM_X0 := .28
const ROOM_X1 := 4.92
const ROOM_Z0 := -.27
const ROOM_Z1 := -6.8
const ROOM_TOP := 2.85
const BRICK := Color("#7a3e2c")
const DARK_BRICK := Color("#4e2a20")
const TILE := Color("#cbb48e")
const PAINT := Color("#b8ae9c")
const OAK := Color("#4a2c1a")
const DARK_OAK := Color("#2e1a10")
const VELVET := Color("#6a1a20")
const BRASS := Color("#b8903a")
const ALU := Color("#a4a6a2")
const FRAME := Color("#5a3a24")

var _front := Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, 0, 0))
var _east := Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(WIDE * .5, 0, 0))
var _back := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(WIDE * .5, 0, -DEEP))
var _west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(-WIDE * .5, 0, -DEEP))

func _ready() -> void:
	_rng.seed = 1961
	_build_looks()
	_ground_front()
	_sample_case()
	_door()
	_arched_windows()
	_fascia()
	_room()
	_booths()
	_counter()
	_upper_front()
	_sign_box()
	_side_walls()
	_back_wall()
	_roof()
	_pavement()
	_kit.commit(self, _looks, ["front", "decal", "lace", "paint", "lamp", "led", "sign", "sign_dim", "lit", "eink", "screen", "case", "case_cloth", "case_food", "kis", "kis_wood", "kis_plaster", "kis_floor", "kis_board", "velvet", "shade", "brass"])
	_kit = null
	_omni("KissaRoom", _front * Vector3(3.2, 2.3, -2.4), Color(1.0, .72, .42), .9, 5.5)
	_omni("KissaCase", _front * Vector3(1.2, 1.9, 1.1), Color(1.0, .84, .62), .4, 3.2)

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

func _decal_look(name: String, glow: float, day: float) -> void:
	var look := ShaderMaterial.new()
	look.shader = DECAL_SHADER
	look.set_shader_parameter("atlas", load(ATLAS))
	look.set_shader_parameter("glow", glow)
	look.set_shader_parameter("day_glow", day)
	_looks[name] = look

func _build_looks() -> void:
	_shared_looks()
	_looks.brick = _look("white_stucco", 3.0, .85)
	_looks.brick.set_shader_parameter("chroma", .25)
	_looks.brick.set_shader_parameter("tile_size", Vector2(.235, .072))
	_looks.tile = _look("white_stucco", 3.0, .7)
	_looks.tile.set_shader_parameter("chroma", .2)
	_looks.tile.set_shader_parameter("tile_size", Vector2(.227, .06))
	_looks.render = _look("white_stucco", 3.0, .92)
	_looks.render.set_shader_parameter("chroma", .4)
	_looks.concrete = _look("precast_concrete_wall", 2.0, .9)
	_looks.concrete.set_shader_parameter("chroma", .3)
	_looks.stone = _look("concrete_tile_facade", 1.2, .5)
	_looks.steel = _look("rusty_painted_metal", 1.6, .8)
	_looks.steel.set_shader_parameter("chroma", .35)
	_looks.wood = _look("japanese_cedar_planks", 1.0, .7)
	_looks.wood.set_shader_parameter("chroma", .5)
	_looks.tin = _look("worn_corrugated_iron", 1.2, .6, .25)
	_looks.tin.set_shader_parameter("chroma", .45)
	_atlas_look("sign", .35, 1.5, .12)
	_atlas_look("sign_dim", .4, .7, .06)
	_atlas_look("lit", .9, .45, 0.0)
	_atlas_look("film", .4, 0.0, 0.0)
	_atlas_look("board", .75, .03, .03)
	_atlas_look("eink", .8, .12, .03)
	_atlas_look("screen", .3, .7, .2)
	_atlas_look("case_cloth", .9, .5, .2)
	_atlas_look("case_food", .5, .55, .2)
	_atlas_look("kis_board", .7, .3, .1)
	_atlas_look("shade", .4, 1.4, .1)
	_lit_look("case", .5, .55, .2)
	_lit_look("kis", .6, .3, .1)
	_lit_look("velvet", .95, .32, .1)
	_lit_look("brass", .35, .3, .1, .6)
	_lit_tex("kis_wood", "japanese_cedar_planks", 1.0, .6, .3, .1, .5)
	_lit_tex("kis_plaster", "plastered_wall_03", 2.0, .9, .3, .1, .4)
	_lit_tex("kis_floor", "square_tiled_wall", 1.0, .5, .26, .1, .35)
	_decal_look("decal", .3, .1)
	_decal_look("lace", .55, .12)
	_decal_look("paint", 0.0, 0.0)

# ---------------------------------------------------------------- helpers

func _px(x: float, y: float, w: float, h: float) -> Rect2:
	return _cell(x, y, w, h)

func _panel(part: String, face: Transform3D, x0: float, x1: float, y0: float, y1: float, z: float, rect: Rect2, tint := Color.WHITE) -> void:
	_kit.atlas(part, face * Vector3(x0, y0, z), face * Vector3(x0, y1, z), face * Vector3(x1, y1, z), face * Vector3(x1, y0, z), rect, tint)

func _flat(part: String, face: Transform3D, area: Rect2, z: float, tint: Color, low := .9, streak := .6) -> void:
	_kit.quad(part, face * Vector3(area.position.x, area.position.y, z), face * Vector3(area.position.x, area.end.y, z), face * Vector3(area.end.x, area.end.y, z), face * Vector3(area.end.x, area.position.y, z), tint, low, 1.0, streak, Vector2(area.position.x, -area.position.y))

func _side_panel(part: String, x: float, z0: float, z1: float, y0: float, y1: float, rect: Rect2, facing_east: bool) -> void:
	# A panel standing along z: seen from +X when facing_east, else from -X. z0 is the street end.
	var f := _front
	if facing_east:
		_kit.atlas(part, f * Vector3(x, y0, z0), f * Vector3(x, y1, z0), f * Vector3(x, y1, z1), f * Vector3(x, y0, z1), rect)
	else:
		_kit.atlas(part, f * Vector3(x, y0, z1), f * Vector3(x, y1, z1), f * Vector3(x, y1, z0), f * Vector3(x, y0, z0), rect)

func _frame(face: Transform3D, r: Rect2, z: float, tint: Color, mullion: bool, part := "metal") -> void:
	var cx := r.get_center().x
	var cy := r.get_center().y
	_bar(part, face, cx, r.end.y - .025, z, Vector3(r.size.x, .05, .06), tint)
	_bar(part, face, cx, r.position.y + .025, z, Vector3(r.size.x, .05, .06), tint)
	_bar(part, face, r.position.x + .025, cy, z, Vector3(.05, r.size.y, .06), tint)
	_bar(part, face, r.end.x - .025, cy, z, Vector3(.05, r.size.y, .06), tint)
	if mullion:
		_bar(part, face, cx, cy, z - .01, Vector3(.04, r.size.y, .05), tint)

func _ac(face: Transform3D, x: float, y: float, z := .22) -> void:
	# Condenser on a wall bracket: case, fan, guard cross, the pipes going in, a stain under it.
	_bar("metal", face, x, y, z, Vector3(.78, .58, .28), Color("#c4c4ba"))
	_kit.disc("plain", face * Vector3(x - .1, y, z + .142), face.basis.x, face.basis.y, .2, Color("#26272a"))
	_bar("metal", face, x - .1, y, z + .146, Vector3(.4, .015, .008), Color("#8f908c"))
	_bar("metal", face, x - .1, y, z + .146, Vector3(.015, .4, .008), Color("#8f908c"))
	_bar("metal", face, x, y - .32, z, Vector3(.88, .04, .38), Color("#3a3a38"))
	for xx: float in [x - .34, x + .34]:
		_kit.beam("metal", face * Vector3(xx, y - .32, z + .16), face * Vector3(xx, y - .78, .02), .03, .03, Vector3.UP, Color("#3a3a38"))
	_kit.tube("plain", [face * Vector3(x + .3, y - .1, z - .02), face * Vector3(x + .5, y - .1, z - .02), face * Vector3(x + .5, y + .5, .06)], .025, Color("#d8d4c4"), 5)
	_panel("paint", face, x - .25, x + .25, y - 1.6, y - .36, .006, _px(1130, 1140, 100, 240))

func _arc(cx: float, cy: float, r: float, i: int, n: int) -> Vector2:
	var a := PI - PI * float(i) / float(n)
	return Vector2(cx + cos(a) * r, cy + sin(a) * r)

# ---------------------------------------------------------------- brick ground floor

func _ground_front() -> void:
	var f := _front
	var holes: Array[Rect2] = [Rect2(DOOR_X0, 0, DOOR_X1 - DOOR_X0, DOOR_TOP + .42)]
	for a: Vector2 in ARCHES:
		holes.append(Rect2(a.x, SILL, a.y - a.x, SPRING - SILL + (a.y - a.x) * .5))
	for piece: Rect2 in _minus(Rect2(0, 0, WIDE, GROUND), holes):
		var tone := _rng.randf_range(.93, 1.04)
		_flat("brick", f, piece, 0.0, Color(BRICK.r * tone, BRICK.g * tone, BRICK.b * tone), .85, .5)
	# Dark plinth course and a soldier course at the slab.
	_bar("brick", f, WIDE * .5, .14, .02, Vector3(WIDE, .28, .04), DARK_BRICK, .8, 1.0)
	_bar("brick", f, WIDE * .5, GROUND - .06, .03, Vector3(WIDE + .02, .12, .06), DARK_BRICK, .9, 1.0)
	# Granite step at the door.
	_bar("stone", f, (DOOR_X0 + DOOR_X1) * .5, .06, .12, Vector3(DOOR_X1 - DOOR_X0 + .3, .12, .3), Color("#6a6662"))
	# Morning-service board screwed to the brick over the sample case, in its own frame.
	_bar("wood", f, (CASE_X0 + CASE_X1) * .5, 2.0, .025, Vector3(.66, .9, .05), DARK_OAK)
	_panel("board", f, .55, 1.2, 1.6, 2.4, .052, _px(320, 740, 360, 520))
	# Downpipe on the west corner; the gas meter and the fibre at the east.
	_kit.tube("metal", [f * Vector3(.1, PARAPET - .1, .12), f * Vector3(.1, .15, .12), f * Vector3(.1, .05, .3)], .045, Color("#6a5a4a"), 7)
	for k: int in range(4):
		_bar("metal", f, .1, 1.2 + float(k) * 2.4, .06, Vector3(.12, .04, .1), Color("#4a4642"))
	_fibre([f * Vector3(5.12, ROOF - .3, .06), f * Vector3(5.12, 3.4, .06), f * Vector3(5.1, .3, .08)])

func _arched_windows() -> void:
	var f := _front
	var n := 10
	for k: int in range(ARCHES.size()):
		var x0 := ARCHES[k].x
		var x1 := ARCHES[k].y
		var cx := (x0 + x1) * .5
		var r := (x1 - x0) * .5
		var top := SPRING + r
		# Brick between the arch and the square cut, strip by strip.
		for i: int in range(n):
			var p := _arc(cx, SPRING, r, i, n)
			var q := _arc(cx, SPRING, r, i + 1, n)
			_kit.quad("brick", f * Vector3(p.x, p.y, 0), f * Vector3(p.x, top, 0), f * Vector3(q.x, top, 0), f * Vector3(q.x, q.y, 0), BRICK, .9, 1.0, .4, Vector2(p.x, -p.y))
			# Soffit through the wall.
			_kit.quad("brick", f * Vector3(p.x, p.y, -REVEAL), f * Vector3(p.x, p.y, 0), f * Vector3(q.x, q.y, 0), f * Vector3(q.x, q.y, -REVEAL), BRICK * .8, .6, .6)
			# Soldier ring, proud of the face.
			var po := _arc(cx, SPRING, r + .13, i, n)
			var qo := _arc(cx, SPRING, r + .13, i + 1, n)
			_kit.quad("brick", f * Vector3(p.x, p.y, .015), f * Vector3(po.x, po.y, .015), f * Vector3(qo.x, qo.y, .015), f * Vector3(q.x, q.y, .015), DARK_BRICK * (1.0 + .08 * float(i % 2)), .95, 1.0)
			# Glass fan and its wood frame.
			_kit.quad("front", f * Vector3(cx, SPRING, -REVEAL + .06), f * Vector3(p.x, p.y, -REVEAL + .06), f * Vector3(q.x, q.y, -REVEAL + .06), f * Vector3(cx, SPRING, -REVEAL + .06), Color.WHITE)
			var pi := _arc(cx, SPRING, r - .05, i, n)
			var qi := _arc(cx, SPRING, r - .05, i + 1, n)
			_kit.quad("wood", f * Vector3(pi.x, pi.y, -REVEAL + .09), f * Vector3(p.x, p.y, -REVEAL + .09), f * Vector3(q.x, q.y, -REVEAL + .09), f * Vector3(qi.x, qi.y, -REVEAL + .09), FRAME, .9, 1.0)
		# Keystone.
		_bar("stone", f, cx, top + .06, .03, Vector3(.13, .16, .06), Color("#b8ac98"))
		# Side reveals and sill.
		_kit.quad("brick", f * Vector3(x0, SILL, 0), f * Vector3(x0, SPRING, 0), f * Vector3(x0, SPRING, -REVEAL), f * Vector3(x0, SILL, -REVEAL), BRICK * .85, .7, .7)
		_kit.quad("brick", f * Vector3(x1, SILL, -REVEAL), f * Vector3(x1, SPRING, -REVEAL), f * Vector3(x1, SPRING, 0), f * Vector3(x1, SILL, 0), BRICK * .85, .7, .7)
		_bar("stone", f, cx, SILL - .03, -.06, Vector3(x1 - x0 + .14, .06, REVEAL + .2), Color("#9a9288"))
		# Square part of the glass, the frame, a transom at the spring and a glazing bar up the fan.
		var gz := -REVEAL + .06
		_kit.quad("front", f * Vector3(x0, SILL, gz), f * Vector3(x0, SPRING, gz), f * Vector3(x1, SPRING, gz), f * Vector3(x1, SILL, gz), Color.WHITE)
		_frame(f, Rect2(x0, SILL, x1 - x0, SPRING - SILL), gz + .03, FRAME, true, "wood")
		_bar("wood", f, cx, SPRING, gz + .03, Vector3(x1 - x0, .05, .06), FRAME)
		for i: int in [3, 7]:
			var p := _arc(cx, SPRING, r - .03, i, n)
			_kit.beam("wood", f * Vector3(cx, SPRING, gz + .03), f * Vector3(p.x, p.y, gz + .03), .03, .03, Vector3.BACK, FRAME)
		# Lace: a gathered panel down each side, a cafe curtain across the bottom; the middle open.
		var lz := gz - .05
		_panel("lace", f, x0 + .02, x0 + .3, SILL + .02, SPRING + .25, lz, _px(840, 210, 512, 512))
		_panel("lace", f, x1 - .3, x1 - .02, SILL + .02, SPRING + .25, lz, _px(840, 210, 512, 512))
		_panel("lace", f, x0 + .02, x1 - .02, SILL + .02, SILL + .5, lz - .01, _px(320, 210, 512, 400))
		_kit.tube("brass", [f * Vector3(x0 + .02, SILL + .5, lz + .005), f * Vector3(x1 - .02, SILL + .5, lz + .005)], .007, BRASS, 4)
		# Gold leaf name on the right-hand window.
		if k == 1:
			_panel("decal", f, x0 + .2, x1 - .2, SILL + .62, SILL + .97, gz + .005, _px(1580, 560, 300, 140))
	# E-paper cake card propped inside the left window.
	var l := ARCHES[0]
	_bar("kis", f, l.x + .3, SILL + .14, -REVEAL - .04, Vector3(.24, .3, .02), Color("#2a2a2a"))
	_panel("eink", f, l.x + .195, l.x + .405, SILL + .01, SILL + .27, -REVEAL - .025, _px(1356, 560, 220, 280))
	_status(f, l.x + .4, SILL + .28, -REVEAL - .02, GREEN)

func _sample_case() -> void:
	# サンプルケース: a chrome-edged glass case on a brick plinth, lit from the top, red cloth.
	var f := _front
	var x0 := CASE_X0
	var x1 := CASE_X1
	var y0 := CASE_Y0
	var y1 := CASE_Y1
	var z1 := CASE_Z
	_kit.block("brick", Transform3D(Basis.IDENTITY, f * Vector3((x0 + x1) * .5, y0 * .5, z1 * .5)), Vector3(x1 - x0 + .06, y0, z1), DARK_BRICK, .8, 1.0)
	_bar("stone", f, (x0 + x1) * .5, y0 - .02, z1 * .5 + .01, Vector3(x1 - x0 + .1, .04, z1 + .04), Color("#8a847a"))
	var cloth := _px(1360, 380, 340, 146)
	_kit.atlas("case_cloth", f * Vector3(x0, y0, z1), f * Vector3(x0, y0, .02), f * Vector3(x1, y0, .02), f * Vector3(x1, y0, z1), cloth)
	_panel("case_cloth", f, x0, x1, y0, y1, .02, _px(1360, 380, 340, 160))
	# The step at the back, cloth over it.
	var sy := y0 + .16
	_bar("case", f, (x0 + x1) * .5, y0 + .08, .1, Vector3(x1 - x0, .16, .16), Color("#5a0e0c"))
	_kit.atlas("case_cloth", f * Vector3(x0, sy + .002, .18), f * Vector3(x0, sy + .002, .02), f * Vector3(x1, sy + .002, .02), f * Vector3(x1, sy + .002, .18), cloth)
	# Inner ends and the lit top.
	_kit.quad("case", f * Vector3(x0, y0, z1), f * Vector3(x0, y1, z1), f * Vector3(x0, y1, .02), f * Vector3(x0, y0, .02), Color("#e8e0d0"))
	_kit.quad("case", f * Vector3(x1, y0, .02), f * Vector3(x1, y1, .02), f * Vector3(x1, y1, z1), f * Vector3(x1, y0, z1), Color("#e8e0d0"))
	_kit.quad("case", f * Vector3(x0, y1, .02), f * Vector3(x0, y1, z1), f * Vector3(x1, y1, z1), f * Vector3(x1, y1, .02), Color("#f0ece0"))
	_bar("lamp", f, (x0 + x1) * .5, y1 - .02, .12, Vector3(x1 - x0 - .1, .02, .04), Color(1.0, .94, .82))
	# Glass front, ends and lid, in a chrome edge; a cap on top.
	_kit.quad("front", f * Vector3(x0, y0, z1), f * Vector3(x0, y1, z1), f * Vector3(x1, y1, z1), f * Vector3(x1, y0, z1), Color.WHITE)
	_kit.quad("front", f * Vector3(x0 - .003, y0, .02), f * Vector3(x0 - .003, y1, .02), f * Vector3(x0 - .003, y1, z1), f * Vector3(x0 - .003, y0, z1), Color.WHITE)
	_kit.quad("front", f * Vector3(x1 + .003, y0, z1), f * Vector3(x1 + .003, y1, z1), f * Vector3(x1 + .003, y1, .02), f * Vector3(x1 + .003, y0, .02), Color.WHITE)
	_bar("metal", f, (x0 + x1) * .5, y1 + .03, z1 * .5 + .01, Vector3(x1 - x0 + .06, .06, z1 + .04), Color("#c8c8c4"))
	for x: float in [x0, x1]:
		_bar("metal", f, x, (y0 + y1) * .5, z1, Vector3(.025, y1 - y0, .025), Color("#d8d8d4"))
	_bar("metal", f, (x0 + x1) * .5, y0 + .012, z1, Vector3(x1 - x0, .025, .025), Color("#d8d8d4"))
	# Back row on the step: cream soda, pudding a la mode, hot cakes, the blend.
	_cream_soda(Vector3(.47, sy, .1))
	_pudding(Vector3(.8, sy, .1))
	_hot_cake(Vector3(1.13, sy, .1))
	_cup(Vector3(1.36, sy, .1))
	# Front row: napolitan, beef curry, thick toast.
	_napolitan(Vector3(.5, y0, .29))
	_curry(Vector3(.87, y0, .29))
	_toast(Vector3(1.24, y0, .29))
	# Tags leaning on the glass.
	var tags: Array = [[.5, 0], [.87, 4], [1.24, 3]]
	for t: Array in tags:
		var i: int = t[1]
		var cell := _px(1360 + float(i % 4) * 170, 210 + float(i / 4) * 80, 164, 74)
		_kit.atlas("case_food", f * Vector3(t[0] - .055, y0 + .005, z1 - .015), f * Vector3(t[0] - .055, y0 + .05, z1 - .03), f * Vector3(t[0] + .055, y0 + .05, z1 - .03), f * Vector3(t[0] + .055, y0 + .005, z1 - .015), cell)
	for t: Array in [[.47, 2], [.8, 1], [1.13, 5]]:
		var i: int = t[1]
		var cell := _px(1360 + float(i % 4) * 170, 210 + float(i / 4) * 80, 164, 74)
		_kit.atlas("case_food", f * Vector3(t[0] - .055, sy + .005, .185), f * Vector3(t[0] - .055, sy + .05, .17), f * Vector3(t[0] + .055, sy + .05, .17), f * Vector3(t[0] + .055, sy + .005, .185), cell)

func _plate(base: Vector3, r: float) -> void:
	_kit.lathe("case", base, [Vector2(r * .6, 0), Vector2(r * .85, .008), Vector2(r, .018)], Color("#f4f2ec"), 14)

func _napolitan(at: Vector3) -> void:
	var b := _front * at
	_plate(b, .115)
	_kit.lathe("case_food", b + Vector3.UP * .008, [Vector2(.09, 0), Vector2(.082, .025), Vector2(.05, .045), Vector2(.0, .052)], Color.WHITE, 12, _px(1710, 380, 160, 160))
	for k: int in range(4):
		var a := float(k) * 1.7
		_kit.block("case_food", Transform3D(Basis(Vector3.UP, a), b + Vector3(cos(a) * .045, .042, sin(a) * .045)), Vector3(.03, .008, .012), Color("#3a8a2a") if k % 2 == 0 else Color("#c85a4a"))

func _curry(at: Vector3) -> void:
	var b := _front * at
	_plate(b, .12)
	_kit.lathe("case_food", b + Vector3(.0, .01, 0), [Vector2(.1, 0), Vector2(.1, .006), Vector2(.0, .01)], Color("#7a3e14"), 14)
	_kit.lathe("case", b + Vector3(-.035, .012, -.01), [Vector2(.06, 0), Vector2(.05, .03), Vector2(.025, .048), Vector2(.0, .052)], Color("#f6f2e8"), 12)
	for k: int in range(3):
		_kit.block("case_food", Transform3D(Basis(Vector3.UP, float(k)), b + Vector3(.04 + float(k) * .012, .02, .01 - float(k) * .02)), Vector3(.025, .02, .025), Color("#c8902a") if k != 1 else Color("#a83a1a"))
	_kit.block("case_food", Transform3D(Basis.IDENTITY, b + Vector3(.07, .02, .05)), Vector3(.03, .012, .02), Color("#c82a2a"))

func _toast(at: Vector3) -> void:
	# 厚切り: two thick slices, one leaning, the butter melting on top.
	var b := _front * at
	_plate(b, .1)
	_kit.block("case_food", Transform3D(Basis(Vector3.UP, .2), b + Vector3(0, .03, .01)), Vector3(.1, .04, .1), Color("#c8904a"))
	_kit.quad("case_food", b + Vector3(-.044, .051, .06), b + Vector3(-.044, .051, -.04), b + Vector3(.054, .051, -.04), b + Vector3(.054, .051, .06), Color("#e0aa58"))
	_kit.block("case_food", Transform3D(Basis(Vector3.FORWARD, .5) * Basis(Vector3.UP, -.3), b + Vector3(.04, .06, -.03)), Vector3(.1, .035, .1), Color("#d8a050"))
	_kit.block("case_food", Transform3D(Basis.IDENTITY, b + Vector3(-.01, .058, .02)), Vector3(.025, .012, .025), Color("#f4e08a"))

func _cream_soda(at: Vector3) -> void:
	var b := _front * at
	_kit.lathe("bottle", b, [Vector2(.035, 0), Vector2(.03, .006), Vector2(.008, .012), Vector2(.008, .045), Vector2(.03, .06), Vector2(.038, .14), Vector2(.042, .2)], Color("#3ac85a"), 12)
	_ball(b + Vector3.UP * .205, Vector3(.04, .03, .04), Color("#f6f2e4"), "case", 5, 10)
	_ball(b + Vector3(.012, .245, .01), Vector3(.012, .012, .012), Color("#d81a1a"), "case_food", 4, 8)
	_kit.tube("case_food", [b + Vector3(.012, .25, .01), b + Vector3(.02, .27, .0)], .0015, Color("#3a2a1a"), 3)
	_kit.tube("case", [b + Vector3(-.02, .12, 0), b + Vector3(-.035, .3, .01)], .004, Color("#f0f0f0"), 4)

func _pudding(at: Vector3) -> void:
	# The boat glass, the pudding with its caramel, cream, a cherry and cut fruit.
	var b := _front * at
	_kit.lathe("bottle", b, [Vector2(.03, 0), Vector2(.01, .01), Vector2(.01, .03)], Color("#d8e8e8"), 10)
	_kit.block("bottle", Transform3D(Basis.IDENTITY, b + Vector3(0, .045, 0)), Vector3(.24, .03, .1), Color("#c8dcdc"), .9, 1.0)
	var top := b + Vector3.UP * .06
	_kit.lathe("case_food", top, [Vector2(.035, 0), Vector2(.028, .045), Vector2(.0, .048)], Color("#f0c048"), 12)
	_kit.lathe("case_food", top + Vector3.UP * .04, [Vector2(.029, 0), Vector2(.027, .008), Vector2(.0, .009)], Color("#6a2a0a"), 12)
	for k: int in range(3):
		_ball(top + Vector3(-.075 + float(k) * .075 * (1 if k != 1 else 0), .018, -.025 if k == 1 else .02), Vector3(.022, .02, .022), Color("#f6f2e6"), "case", 4, 8)
	_ball(top + Vector3(.0, .062, .0), Vector3(.012, .012, .012), Color("#d81a1a"), "case_food", 4, 8)
	_kit.block("case_food", Transform3D(Basis(Vector3.UP, .4), top + Vector3(.085, .015, .0)), Vector3(.05, .03, .02), Color("#a8d860"))
	_kit.block("case_food", Transform3D(Basis(Vector3.UP, -.4), top + Vector3(-.09, .012, -.01)), Vector3(.045, .02, .02), Color("#f0a020"))
	_kit.lathe("case_food", top + Vector3(.05, .0, .03), [Vector2(.015, 0), Vector2(.015, .01)], Color("#f6e8a0"), 8)

func _hot_cake(at: Vector3) -> void:
	var b := _front * at
	_plate(b, .1)
	for k: int in range(2):
		_kit.lathe("case_food", b + Vector3(.0, .01 + float(k) * .022, .0), [Vector2(.075, 0), Vector2(.078, .01), Vector2(.075, .02), Vector2(.0, .021)], Color("#c88a3a"), 14)
	_kit.block("case_food", Transform3D(Basis(Vector3.UP, .3), b + Vector3(0, .06, 0)), Vector3(.03, .014, .03), Color("#f4e08a"))
	_kit.lathe("case_food", b + Vector3(0, .052, 0), [Vector2(.05, 0), Vector2(.0, .002)], Color("#8a4a10"), 10)

func _cup(at: Vector3) -> void:
	var b := _front * at
	_kit.lathe("case", b, [Vector2(.06, 0), Vector2(.065, .008)], Color("#f4f0e4"), 12)
	_kit.lathe("case", b + Vector3.UP * .008, [Vector2(.022, 0), Vector2(.038, .05), Vector2(.04, .055)], Color("#f4f0e4"), 12)
	_kit.lathe("case_food", b + Vector3.UP * .056, [Vector2(.036, 0), Vector2(.0, .001)], Color("#3a1a0a"), 10)
	_kit.tube("case", [b + Vector3(.035, .045, 0), b + Vector3(.055, .04, 0), b + Vector3(.04, .018, 0)], .005, Color("#f4f0e4"), 4)

# ---------------------------------------------------------------- the door

func _door() -> void:
	var f := _front
	var x0 := DOOR_X0
	var x1 := DOOR_X1
	var dz := -REVEAL + .04
	_reveal(f, Rect2(x0, 0, x1 - x0, DOOR_TOP + .42), REVEAL, BRICK * .8)
	# Oak frame and the transom over the door, stained glass in it.
	_bar("wood", f, (x0 + x1) * .5, DOOR_TOP + .02, dz, Vector3(x1 - x0, .06, .1), DARK_OAK)
	_bar("wood", f, (x0 + x1) * .5, DOOR_TOP + .4, dz, Vector3(x1 - x0, .05, .1), DARK_OAK)
	_panel("shade", f, x0 + .03, x1 - .03, DOOR_TOP + .05, DOOR_TOP + .375, dz - .01, _px(1340, 860, 300, 140))
	for x: float in [x0 + .3, x0 + .59]:
		_bar("wood", f, x, DOOR_TOP + .21, dz, Vector3(.03, .33, .05), DARK_OAK)
	# The door: heavy oak in stiles and rails round a small window and two fielded panels.
	var a := x0 + .04
	var b := x1 - .04
	var t := .055
	var wy0 := 1.25
	var wy1 := 1.85
	var wx0 := a + .2
	var wx1 := b - .2
	_bar("wood", f, a + .1, DOOR_TOP * .5, dz, Vector3(.2, DOOR_TOP, t), OAK)
	_bar("wood", f, b - .1, DOOR_TOP * .5, dz, Vector3(.2, DOOR_TOP, t), OAK)
	_bar("wood", f, (a + b) * .5, (DOOR_TOP + wy1) * .5, dz, Vector3(wx1 - wx0, DOOR_TOP - wy1, t), OAK)
	_bar("wood", f, (a + b) * .5, (wy0 + 1.0) * .5, dz, Vector3(wx1 - wx0, wy0 - 1.0, t), OAK)
	_bar("wood", f, (a + b) * .5, .5, dz - .01, Vector3(wx1 - wx0, 1.0, t - .02), OAK * .9)
	for py: Vector2 in [Vector2(.14, .5), Vector2(.55, .92)]:
		_bar("wood", f, (a + b) * .5, (py.x + py.y) * .5, dz + .03, Vector3(wx1 - wx0 - .04, py.y - py.x, .02), OAK * 1.12)
	_bar("wood", f, (a + b) * .5, .05, dz + .01, Vector3(b - a, .1, t + .02), DARK_OAK)
	# Its window, gold leaf on it, the 営業中 plate hung below.
	_kit.quad("front", f * Vector3(wx0, wy0, dz), f * Vector3(wx0, wy1, dz), f * Vector3(wx1, wy1, dz), f * Vector3(wx1, wy0, dz), Color.WHITE)
	_frame(f, Rect2(wx0, wy0, wx1 - wx0, wy1 - wy0), dz + .03, DARK_OAK, false, "wood")
	_panel("decal", f, wx0 + .04, wx1 - .04, wy0 + .2, wy0 + .46, dz + .002, _px(1580, 560, 300, 96))
	_panel("board", f, (a + b) * .5 - .14, (a + b) * .5 + .14, 1.04, 1.14, dz + .045, _px(1580, 780, 200, 70))
	_kit.tube("brass", [f * Vector3((a + b) * .5 - .1, 1.14, dz + .04), f * Vector3((a + b) * .5, 1.22, dz + .03), f * Vector3((a + b) * .5 + .1, 1.14, dz + .04)], .003, BRASS, 3)
	# Brass pull, kick plate, the bell on its spring over the latch side.
	_kit.tube("brass", [f * Vector3(b - .1, .85, dz + .03), f * Vector3(b - .1, .85, dz + .08), f * Vector3(b - .1, 1.45, dz + .08), f * Vector3(b - .1, 1.45, dz + .03)], .014, BRASS, 6)
	_bar("brass", f, (a + b) * .5, .17, dz + .032, Vector3(b - a - .06, .2, .006), BRASS * .85)
	var bell := f * Vector3(b - .08, DOOR_TOP - .14, dz + .11)
	_kit.tube("brass", [f * Vector3(b - .08, DOOR_TOP - .04, dz + .03), f * Vector3(b - .08, DOOR_TOP - .04, dz + .11), bell + Vector3.UP * .04], .004, BRASS, 3)
	_kit.lathe("brass", bell - Vector3.UP * .05, [Vector2(.035, 0), Vector2(.03, .02), Vector2(.02, .07), Vector2(.008, .09)], BRASS, 10)
	_ball(bell - Vector3.UP * .055, Vector3(.01, .01, .01), Color("#4a3a1a"), "metal", 4, 6)
	# A copper hood over the door on two scroll brackets.
	var hy := DOOR_TOP + .5
	_kit.quad("tin", f * Vector3(x0 - .2, hy - .14, .55), f * Vector3(x0 - .2, hy, 0), f * Vector3(x1 + .2, hy, 0), f * Vector3(x1 + .2, hy - .14, .55), Color("#4a6a5a"), .9, 1.0, .5)
	_kit.quad("tin", f * Vector3(x0 - .2, hy - .02, 0), f * Vector3(x0 - .2, hy - .16, .55), f * Vector3(x1 + .2, hy - .16, .55), f * Vector3(x1 + .2, hy - .02, 0), Color("#3a3a32"), .6, .6)
	_bar("metal", f, (x0 + x1) * .5, hy - .17, .55, Vector3(x1 - x0 + .42, .06, .03), Color("#3a5246"))
	for x: float in [x0 - .1, x1 + .1]:
		_kit.tube("metal", [f * Vector3(x, hy - .5, .01), f * Vector3(x, hy - .3, .3), f * Vector3(x, hy - .16, .5)], .012, Color("#2a2a26"), 4)
	_kit.disc("lamp", f * Vector3((x0 + x1) * .5, hy - .175, .3), Vector3.RIGHT, Vector3.BACK, .05, Color(1.0, .84, .6))

func _fascia() -> void:
	# Black lacquer name board across the top of the brick, two goose-neck lamps on it.
	var f := _front
	_bar("wood", f, WIDE * .5, 2.97, .04, Vector3(WIDE - .2, .5, .07), Color("#140e0a"))
	_panel("sign_dim", f, .2, WIDE - .2, 2.75, 3.19, .076, _px(320, 0, 1400, 190))
	for lx: float in [1.0, 4.0]:
		_kit.tube("metal", [f * Vector3(lx, 3.22, .06), f * Vector3(lx, 3.36, .22), f * Vector3(lx, 3.33, .38)], .012, Color("#2a2a2a"), 4)
		_kit.lathe("metal", f * Vector3(lx, 3.25, .4), [Vector2(.02, .08), Vector2(.07, 0)], Color("#2a2a2a"), 8)
		_kit.disc("lamp", f * Vector3(lx, 3.248, .4), Vector3.RIGHT, Vector3.BACK, .055, Color(1.0, .86, .6))

# ---------------------------------------------------------------- inside

func _room() -> void:
	var f := _front
	var x0 := ROOM_X0
	var x1 := ROOM_X1
	var near := ROOM_Z0
	var far := ROOM_Z1
	var top := ROOM_TOP
	_kit.quad("kis_floor", f * Vector3(x0, .02, near), f * Vector3(x0, .02, far), f * Vector3(x1, .02, far), f * Vector3(x1, .02, near), Color("#7a4a34"), .8, .8)
	_kit.quad("kis_plaster", f * Vector3(x0, top, far), f * Vector3(x0, top, near), f * Vector3(x1, top, near), f * Vector3(x1, top, far), Color("#d8c8a8"), .7, .7)
	_kit.quad("kis_plaster", f * Vector3(x0, 0, near), f * Vector3(x0, top, near), f * Vector3(x0, top, far), f * Vector3(x0, 0, far), Color("#d8c49a"), .7, 1.0)
	_kit.quad("kis_plaster", f * Vector3(x1, 0, far), f * Vector3(x1, top, far), f * Vector3(x1, top, near), f * Vector3(x1, 0, near), Color("#d0bc94"), .7, 1.0)
	_kit.quad("kis_wood", f * Vector3(x0, 0, far), f * Vector3(x0, top, far), f * Vector3(x1, top, far), f * Vector3(x1, 0, far), Color("#5a3622"), .7, 1.0)
	# Back of the street wall, seen in the glass.
	_kit.quad("kis_plaster", f * Vector3(x1, 0, near), f * Vector3(x1, top, near), f * Vector3(x0, top, near), f * Vector3(x0, 0, near), Color("#c8b48c"), .7, 1.0)
	# Dark oak wainscot and its rail round the side walls.
	for side: Array in [[x0 + .006, true], [x1 - .006, false]]:
		var x: float = side[0]
		if side[1]:
			_kit.quad("kis_wood", f * Vector3(x, 0, near), f * Vector3(x, 1.0, near), f * Vector3(x, 1.0, far), f * Vector3(x, 0, far), Color("#4a2a18"), .7, 1.0)
		else:
			_kit.quad("kis_wood", f * Vector3(x, 0, far), f * Vector3(x, 1.0, far), f * Vector3(x, 1.0, near), f * Vector3(x, 0, near), Color("#4a2a18"), .7, 1.0)
		_bar("kis_wood", f, x + (.012 if side[1] else -.012), 1.02, (near + far) * .5, Vector3(.03, .05, near - far), Color("#2e1a10"))
		_bar("kis_wood", f, x + (.012 if side[1] else -.012), top - .1, (near + far) * .5, Vector3(.03, .12, near - far), Color("#3a2214"))
	# Beams across the ceiling.
	var z := near - .9
	while z > far + .3:
		_bar("kis_wood", f, (x0 + x1) * .5, top - .09, z, Vector3(x1 - x0, .18, .16), Color("#2e1a10"))
		z -= 1.5
	# Tall clock on the west wall: case, dial, the pendulum behind its glass.
	var cz := -2.3
	_bar("kis_wood", f, x0 + .14, .95, cz, Vector3(.26, 1.9, .42), Color("#3a2010"))
	_bar("kis_wood", f, x0 + .15, 1.96, cz, Vector3(.28, .12, .5), Color("#2a160a"))
	_side_panel("kis_board", x0 + .272, cz + .19, cz - .19, 1.38, 1.76, _px(1890, 560, 150, 150), true)
	_bar("kis", f, x0 + .27, .9, cz, Vector3(.01, .72, .26), Color("#1a1208"))
	_kit.tube("brass", [f * Vector3(x0 + .262, 1.25, cz), f * Vector3(x0 + .262, .76, cz + .04)], .004, BRASS, 3)
	_kit.disc("brass", f * Vector3(x0 + .263, .72, cz + .045), Vector3.BACK, Vector3.UP, .05, BRASS)
	# Painting over the two-seat table, the menu frame by the counter.
	_bar("kis_wood", f, x0 + .02, 1.75, -3.6, Vector3(.03, .6, .8), Color("#5a3a1a"))
	_side_panel("kis_board", x0 + .037, -3.25, -3.95, 1.5, 2.0, _px(1660, 1000, 200, 150), true)
	_side_panel("kis_board", x1 - .012, -4.2, -4.6, 1.3, 1.8, _px(1880, 1000, 160, 200), false)
	# Magazine rack inside the door.
	var mz := -.95
	_bar("kis_wood", f, x0 + .2, .5, mz, Vector3(.36, 1.0, .5), Color("#4a2a18"))
	for k: int in range(3):
		var y := .38 + float(k) * .26
		for j: int in range(2):
			var cell := _px(1660 + float((k * 2 + j) % 6) * 63, 870, 60, 120)
			var zz := mz + .2 - float(j) * .25
			_kit.atlas("kis_board", f * Vector3(x0 + .4, y, zz), f * Vector3(x0 + .36, y + .28, zz), f * Vector3(x0 + .36, y + .28, zz - .2), f * Vector3(x0 + .4, y, zz - .2), cell)
	# Two-seat table under the painting.
	_table(Vector3(.85, 0, -3.6), .6, .6)
	_chair(Vector3(.85, 0, -3.05), PI)
	_chair(Vector3(.85, 0, -4.15), 0.0)
	# A kentia palm by the right window, and one by the counter end.
	_kit.lathe("kis", f * Vector3(2.95, 0, -.7), [Vector2(.14, 0), Vector2(.18, .38)], Color("#8a5a3a"), 10)
	_plant(f * Vector3(2.95, .36, -.7), 1.1, Color("#3a5a2a"))
	_kit.lathe("kis", f * Vector3(4.55, 0, -4.4), [Vector2(.12, 0), Vector2(.15, .32)], Color("#3a3a34"), 10)
	_plant(f * Vector3(4.55, .3, -4.4), .9, Color("#3a5a2a"))

func _table(at: Vector3, wx: float, wz: float) -> void:
	var f := _front
	_bar("kis_wood", f, at.x, .72, at.z, Vector3(wx, .04, wz), Color("#3a2010"))
	_bar("kis", f, at.x, .745, at.z, Vector3(wx - .04, .01, wz - .04), Color("#5a6a68"))
	_bar("kis", f, at.x, .36, at.z, Vector3(.08, .7, .08), Color("#1a1a1a"))
	_bar("kis", f, at.x, .02, at.z, Vector3(.42, .04, .42), Color("#1a1a1a"))
	# Sugar pot, napkins, the order tablet on its little stand.
	_kit.lathe("kis", f * Vector3(at.x - .08, .75, at.z + .05), [Vector2(.035, 0), Vector2(.04, .05), Vector2(.02, .07)], Color("#f0ece0"), 8)
	_bar("kis", f, at.x + .1, .79, at.z + .08, Vector3(.08, .08, .04), Color("#c8c4b8"))
	var tx := at.x + .02
	var tz := at.z - .12
	_bar("kis", f, tx, .78, tz, Vector3(.13, .06, .02), Color("#101214"))
	_kit.atlas("screen", f * Vector3(tx - .055, .755, tz + .025), f * Vector3(tx - .055, .8, tz + .005), f * Vector3(tx + .055, .8, tz + .005), f * Vector3(tx + .055, .755, tz + .025), _px(1510, 1140, 120, 80))

func _chair(at: Vector3, yaw: float) -> void:
	# Bentwood-backed chair in velvet; yaw 0 faces the street.
	var xf := Transform3D(Basis(Vector3.UP, yaw), _front * at)
	_kit.block("velvet", xf.translated_local(Vector3(0, .45, 0)), Vector3(.42, .07, .42), VELVET)
	_kit.block("velvet", xf.translated_local(Vector3(0, .78, -.19)), Vector3(.38, .5, .06), VELVET * .9)
	for c: Vector2 in [Vector2(-.18, -.18), Vector2(.18, -.18), Vector2(-.18, .18), Vector2(.18, .18)]:
		_kit.block("kis_wood", xf.translated_local(Vector3(c.x, .21, c.y)), Vector3(.035, .42, .035), Color("#2a160a"))

func _booth(z: float) -> void:
	# Booth at right angles to the window: two benches facing over a table, a leaded lamp over it.
	var f := _front
	var cx := 3.95
	_table(Vector3(cx, 0, z), .62, .95)
	for side: float in [-1.0, 1.0]:
		var bx := cx + side * .62
		_bar("kis_wood", f, bx, .2, z, Vector3(.5, .4, 1.1), Color("#2e1a10"))
		_bar("velvet", f, bx, .45, z, Vector3(.5, .1, 1.1), VELVET)
		_bar("velvet", f, bx + side * .22, .85, z, Vector3(.12, .75, 1.1), VELVET * .92)
		for k: int in range(3):
			_bar("velvet", f, bx + side * .155, .85, z - .36 + float(k) * .36, Vector3(.01, .7, .012), VELVET * .7)
		_bar("kis_wood", f, bx + side * .22, 1.25, z, Vector3(.16, .05, 1.14), Color("#2e1a10"))
	var lamp := f * Vector3(cx, 1.7, z)
	_kit.tube("plain", [lamp + Vector3.UP * .2, lamp + Vector3.UP * (ROOM_TOP - 1.7)], .006, Color("#1a1a1a"), 3)
	_kit.lathe("shade", lamp, [Vector2(.24, 0), Vector2(.2, .1), Vector2(.12, .18), Vector2(.04, .22)], Color.WHITE, 12, _px(1340, 860, 300, 200))
	_kit.disc("lamp", lamp + Vector3.UP * .03, Vector3.RIGHT, Vector3.BACK, .08, Color(1.0, .8, .5))

func _booths() -> void:
	_booth(-1.25)
	_booth(-2.95)

func _counter() -> void:
	# Long counter across the back, stools, siphons on their burners, the cup wall behind.
	var f := _front
	var cx0 := .6
	var cx1 := 3.6
	var cz := -4.85
	_bar("kis_wood", f, (cx0 + cx1) * .5, .5, cz, Vector3(cx1 - cx0, 1.0, .45), Color("#4a2814"))
	_bar("kis_wood", f, (cx0 + cx1) * .5, 1.02, cz + .03, Vector3(cx1 - cx0 + .08, .05, .55), Color("#7a4a2a"))
	_bar("kis", f, (cx0 + cx1) * .5, .1, cz + .24, Vector3(cx1 - cx0, .2, .02), Color("#1a0e08"))
	for k: int in range(4):
		var sx := .95 + float(k) * .75
		_kit.tube("metal", [f * Vector3(sx, .02, cz + .6), f * Vector3(sx, .66, cz + .6)], .025, Color("#b8b8b4"), 6)
		_kit.lathe("metal", f * Vector3(sx, .01, cz + .6), [Vector2(.18, 0), Vector2(.17, .03)], Color("#3a3a3a"), 10)
		_kit.lathe("velvet", f * Vector3(sx, .66, cz + .6), [Vector2(.18, 0), Vector2(.19, .05), Vector2(.16, .09), Vector2(.0, .1)], VELVET, 10)
	# Siphons: a round lower bowl of coffee, the upper globe, a lamp under each.
	for k: int in range(3):
		var b := f * Vector3(1.2 + float(k) * .45, 1.045, cz - .05)
		_kit.lathe("metal", b, [Vector2(.07, 0), Vector2(.07, .015), Vector2(.02, .03), Vector2(.02, .06)], Color("#8a7a5a"), 8)
		_kit.disc("lamp", b + Vector3.UP * .065, Vector3.RIGHT, Vector3.BACK, .02, Color(.5, .7, 1.0))
		_ball(b + Vector3.UP * .14, Vector3(.07, .07, .07), Color("#3a1a0a"), "bottle", 6, 10)
		_kit.lathe("bottle", b + Vector3.UP * .2, [Vector2(.015, 0), Vector2(.06, .07), Vector2(.065, .14), Vector2(.05, .2), Vector2(.03, .21)], Color("#c8d4d0"), 10)
		_kit.tube("metal", [b + Vector3(.09, .02, 0), b + Vector3(.09, .3, 0), b + Vector3(.05, .34, 0)], .006, Color("#8a8a84"), 3)
	# Cups on saucers waiting on the counter end, the till.
	for k: int in range(3):
		var c := f * Vector3(2.75 + float(k) * .14, 1.045, cz + .1)
		_kit.lathe("kis", c, [Vector2(.06, 0), Vector2(.065, .008)], Color("#f4f0e4"), 10)
		_kit.lathe("kis", c + Vector3.UP * .008, [Vector2(.022, 0), Vector2(.038, .05)], Color("#f4f0e4"), 10)
	_bar("kis", f, 3.35, 1.13, cz, Vector3(.3, .16, .26), Color("#1a1a1c"))
	_status(f, 3.35, 1.2, cz + .131, AMBER)
	# Back counter and the cup wall: open shelves of cups, a jar row of beans, the menu board.
	var bz := ROOM_Z1
	_bar("kis_wood", f, 2.3, .45, bz + .3, Vector3(3.8, .9, .58), Color("#3a2010"))
	_bar("kis_wood", f, 2.3, .92, bz + .3, Vector3(3.8, .04, .6), Color("#6a4024"))
	_panel("kis_board", f, .9, 3.3, 2.05, 2.62, bz + .02, _px(0, 1400, 700, 200))
	for row: int in range(2):
		var y := 1.25 + float(row) * .38
		_bar("kis_wood", f, 2.0, y, bz + .14, Vector3(2.6, .03, .26), Color("#5a3420"))
		for k: int in range(9):
			var c := f * Vector3(.85 + float(k) * .28, y + .015, bz + .14)
			if row == 0:
				_kit.lathe("kis", c, [Vector2(.022, 0), Vector2(.036, .055), Vector2(.038, .06)], [Color("#f4f0e4"), Color("#3a5a8a"), Color("#f4f0e4"), Color("#a83a2a")][k % 4], 8)
			else:
				_kit.lathe("bottle", c, [Vector2(.045, 0), Vector2(.045, .16), Vector2(.03, .18)], Color("#3a2a1a") if k % 3 else Color("#5a3a1a"), 8)
	_panel("kis_board", f, 3.45, 3.95, 1.2, 1.78, bz + .02, _px(720, 1400, 260, 300))
	# Kitchen door in the back corner, a curtain half across it.
	_bar("kis", f, 4.35, 1.0, bz + .01, Vector3(.7, 2.0, .02), Color("#1a120c"))
	_bar("velvet", f, 4.35, 1.65, bz + .04, Vector3(.72, .7, .02), Color("#8a6a3a"))
	# Pendants over the counter.
	for x: float in [1.2, 2.6]:
		var at := f * Vector3(x, 2.05, cz)
		_kit.tube("plain", [at + Vector3.UP * .2, at + Vector3.UP * (ROOM_TOP - 2.05)], .006, Color("#1a1a1a"), 3)
		_kit.lathe("lamp", at, [Vector2(.03, 0), Vector2(.12, .05), Vector2(.13, .12), Vector2(.06, .2)], Color(1.0, .78, .5), 10)

# ---------------------------------------------------------------- upstairs

func _upper_front() -> void:
	var f := _front
	var w2 := Rect2(.55, GROUND + .8, 3.0, 1.3)
	var w3a := Rect2(.5, GROUND + PITCH + .75, 1.1, 1.25)
	var w3b := Rect2(2.1, GROUND + PITCH + .75, 1.1, 1.25)
	var w3c := Rect2(3.75, GROUND + PITCH + 1.0, .6, .8)
	var holes: Array[Rect2] = [w2.grow(.05), w3a.grow(.05), w3b.grow(.05), w3c.grow(.04)]
	for piece: Rect2 in _minus(Rect2(0, GROUND, WIDE, ROOF - .3 - GROUND), holes):
		var tone := _rng.randf_range(.95, 1.03)
		_flat("tile", f, piece, 0.0, Color(TILE.r * tone, TILE.g * tone, TILE.b * tone), .88, .8)
	_bar("tile", f, WIDE * .5, (ROOF - .3 + PARAPET) * .5, .035, Vector3(WIDE, PARAPET - ROOF + .3, .07), Color("#8a6a4a"), .9, 1.0)
	_bar("concrete", f, WIDE * .5, PARAPET + .04, -.05, Vector3(WIDE + .04, .08, .3), Color("#9a968e"))
	_bar("tile", f, WIDE * .5, GROUND + PITCH + .04, .02, Vector3(WIDE, .1, .04), Color("#8a6a4a"))
	# 2F: the family's front room, a wide brown sash, a flower box of geraniums under it.
	_house_window(w2, 0, true)
	var bx0 := w2.position.x - .05
	var bx1 := w2.end.x + .05
	var by := w2.position.y - .08
	_bar("wood", f, (bx0 + bx1) * .5, by - .1, .16, Vector3(bx1 - bx0, .2, .26), Color("#5a3a22"))
	for k: int in range(2):
		_kit.beam("metal", f * Vector3(bx0 + .3 + float(k) * (bx1 - bx0 - .6), by - .2, .26), f * Vector3(bx0 + .3 + float(k) * (bx1 - bx0 - .6), by - .45, .01), .03, .03, Vector3.UP, Color("#2a2a26"))
	for k: int in range(7):
		var x := bx0 + .22 + float(k) * .44
		_plant(f * Vector3(x, by, .16), .32, Color("#3a6a2a"))
		for j: int in range(3):
			_ball(f * Vector3(x + _rng.randf_range(-.08, .08), by + _rng.randf_range(.18, .3), .16 + _rng.randf_range(-.06, .06)), Vector3(.04, .035, .04), Color("#d82a3a") if k % 3 else Color("#f0a0b0"), "leaf", 3, 6)
	# 2050: the drone hatch beside it, a steel box let through the tile with its lip and lights.
	var hx := 4.35
	var hy := GROUND + 1.75
	_bar("steel", f, hx, hy, .12, Vector3(.66, .5, .24), Color("#5a6064"))
	_bar("metal", f, hx, hy - .27, .3, Vector3(.7, .03, .36), Color("#8a8e90"))
	_panel("sign_dim", f, hx - .3, hx + .3, hy + .02, hy + .22, .242, _px(1640, 1140, 200, 80))
	_bar("plain", f, hx, hy - .1, .243, Vector3(.5, .18, .004), Color("#1a1c1e"))
	for x: float in [hx - .3, hx + .3]:
		_status(f, x, hy - .25, .47, AMBER)
	_ac(f, 4.3, GROUND + .55)
	# 3F: two windows over a narrow steel balcony, the laundry pole, a small one to the stair.
	_house_window(w3a, 2, false)
	_house_window(w3b, 3, false)
	_house_window(w3c, 1, false)
	var ly := GROUND + PITCH
	_bar("steel", f, 1.85, ly + .03, .3, Vector3(3.4, .06, .6), Color("#4a4e50"))
	_bar("steel", f, 1.85, ly + .95, .6, Vector3(3.4, .04, .04), Color("#4a4e50"))
	for k: int in range(18):
		_bar("steel", f, .2 + float(k) * .194, ly + .5, .6, Vector3(.018, .9, .018), Color("#4a4e50"))
	for x: float in [.16, 3.54]:
		_bar("steel", f, x, ly + .5, .3, Vector3(.03, .9, .6), Color("#4a4e50"))
	_kit.tube("metal", [f * Vector3(.3, ly + 1.75, .45), f * Vector3(3.4, ly + 1.75, .45)], .014, ALU, 5)
	for x: float in [.3, 3.4]:
		_kit.tube("metal", [f * Vector3(x, ly + 1.75, .45), f * Vector3(x, ly + 1.85, .02)], .01, ALU, 3)
	_bar("plain", f, 1.0, ly + 1.38, .45, Vector3(.42, .72, .01), Color("#e8e0d0"))
	_bar("plain", f, 1.55, ly + 1.45, .45, Vector3(.32, .55, .01), Color("#6a8ab0"))
	_bar("plain", f, 2.6, ly + 1.5, .45, Vector3(.5, .45, .01), Color("#d8c8a0"))
	for k: int in range(3):
		_kit.lathe("plain", f * Vector3(2.2 + float(k) * .4, ly + .06, .4), [Vector2(.1, 0), Vector2(.13, .22)], Color("#9a5a3a"), 8)
		_plant(f * Vector3(2.2 + float(k) * .4, ly + .26, .4), .4, Color("#4a6a32"))
	_ac(f, .95, ly + .45, .3)
	# 2F nameplate and the old shutter box over the door to the stair.
	_panel("board", f, 4.6, 4.88, GROUND + .3, GROUND + .4, .006, _px(1850, 1140, 180, 60))

func _house_window(r: Rect2, cell: int, wide: bool) -> void:
	# Brown aluminium sash in a tiled reveal: curtain behind glass, lit or dark.
	var f := _front
	_reveal(f, r, .16, Color("#a8987a"))
	var rect := _px(float(cell) * 250.0, 1140, 240, 240)
	var part := "film" if cell == 1 else "lit"
	_kit.atlas(part, f * Vector3(r.position.x, r.position.y, -.15), f * Vector3(r.position.x, r.end.y, -.15), f * Vector3(r.end.x, r.end.y, -.15), f * Vector3(r.end.x, r.position.y, -.15), rect, Color(.85, .85, .85))
	_kit.quad("front", f * Vector3(r.position.x, r.position.y, -.1), f * Vector3(r.position.x, r.end.y, -.1), f * Vector3(r.end.x, r.end.y, -.1), f * Vector3(r.end.x, r.position.y, -.1), Color.WHITE)
	_frame(f, r, -.08, Color("#5a4a3a"), true)
	if wide:
		for x: float in [r.position.x + r.size.x / 3.0, r.position.x + r.size.x * 2.0 / 3.0]:
			_bar("metal", f, x, r.get_center().y, -.09, Vector3(.035, r.size.y, .04), Color("#5a4a3a"))
	_bar("concrete", f, r.get_center().x, r.position.y - .04, .04, Vector3(r.size.x + .12, .05, .16), Color("#9a9890"))
	_panel("paint", f, r.get_center().x - .25, r.get_center().x + .25, r.position.y - 1.0, r.position.y - .07, .004, _px(1130, 1140, 100, 240))

func _sign_box() -> void:
	# 袖看板: lit both faces, the roundel at the top, out from the east pier on two arms.
	var f := _front
	var sx := 4.98
	var z0 := .14
	var z1 := .94
	var y0 := 3.55
	var y1 := 6.47
	var t := .2
	_bar("metal", f, sx, (y0 + y1) * .5, (z0 + z1) * .5, Vector3(t, y1 - y0, z1 - z0), Color("#3a2214"))
	var cell := _px(0, 0, 300, 1100)
	_kit.atlas("sign", f * Vector3(sx - t * .5 - .004, y0, z0), f * Vector3(sx - t * .5 - .004, y1, z0), f * Vector3(sx - t * .5 - .004, y1, z1), f * Vector3(sx - t * .5 - .004, y0, z1), cell)
	_kit.atlas("sign", f * Vector3(sx + t * .5 + .004, y0, z1), f * Vector3(sx + t * .5 + .004, y1, z1), f * Vector3(sx + t * .5 + .004, y1, z0), f * Vector3(sx + t * .5 + .004, y0, z0), cell)
	_panel("sign", f, sx - t * .5, sx + t * .5, y0 + .05, y1 - .05, z1 + .004, _px(14, 330, 40, 640))
	for y: float in [y0 - .015, y1 + .015]:
		_bar("metal", f, sx, y, (z0 + z1) * .5, Vector3(t + .03, .03, z1 - z0 + .03), BRASS * .8)
	for y: float in [y0 + .5, y1 - .5]:
		_bar("steel", f, sx, y, z0 * .5, Vector3(.08, .08, z0), STEEL)
		_kit.beam("steel", f * Vector3(sx, y, z1 - .1), f * Vector3(sx, y + .5, .01), .035, .035, Vector3.UP, STEEL)
	_kit.tube("plain", [f * Vector3(sx - .06, y0 + .1, z0), f * Vector3(sx - .06, y0 - .3, .05), f * Vector3(4.8, 3.0, .05)], .015, Color("#1a1a1a"), 4)

# ---------------------------------------------------------------- flanks, back, roof

func _side_walls() -> void:
	var w := _west
	var e := _east
	var west_windows: Array[Rect2] = [Rect2(3.0, GROUND + 1.1, .6, .8), Rect2(5.2, GROUND + PITCH + 1.1, .6, .8), Rect2(1.6, GROUND + PITCH + 1.0, .9, .9)]
	var east_windows: Array[Rect2] = [Rect2(4.3, GROUND + 1.1, .6, .8), Rect2(1.8, GROUND + PITCH + 1.05, .6, .8)]
	var west_holes: Array[Rect2] = []
	for r: Rect2 in west_windows: west_holes.append(r.grow(.04))
	var east_holes: Array[Rect2] = []
	for r: Rect2 in east_windows: east_holes.append(r.grow(.04))
	_render_wall(w, DEEP, PARAPET, GROUND, PITCH, PAINT, west_holes)
	_render_wall(e, DEEP, PARAPET, GROUND, PITCH, PAINT * .96, east_holes)
	# The brick and the tile turn the corner a hand's breadth.
	_flat("brick", w, Rect2(DEEP - .3, 0, .3, GROUND), .006, BRICK, .85, .4)
	_flat("brick", e, Rect2(0, 0, .3, GROUND), .006, BRICK, .85, .4)
	_flat("tile", w, Rect2(DEEP - .3, GROUND, .3, ROOF - GROUND), .006, TILE, .88, .6)
	_flat("tile", e, Rect2(0, GROUND, .3, ROOF - GROUND), .006, TILE, .88, .6)
	for k: int in range(west_windows.size()):
		_side_window(w, west_windows[k], k == 2)
	for k: int in range(east_windows.size()):
		_side_window(e, east_windows[k], k == 0)
	# East: the old painted name up the wall, showing through the newer paint.
	_panel("paint", e, 2.9, 3.62, 3.4, 8.2, .01, _px(1000, 1140, 120, 800))
	_ac(e, 5.6, GROUND + PITCH + .6)
	_kit.tube("metal", [e * Vector3(6.9, PARAPET - .2, .1), e * Vector3(6.9, .1, .1)], .05, Color("#8a8476"), 7)
	_kit.tube("plain", [e * Vector3(6.4, .1, .07), e * Vector3(6.4, ROOF + .3, .07)], .03, Color("#c8b878"), 5)
	_bar("metal", e, 5.2, 1.2, .1, Vector3(.4, .5, .2), Color("#8a8c88"))
	_kit.lathe("metal", e * Vector3(.9, 2.6, .02), [Vector2(.09, 0), Vector2(.09, .14)], Color("#b8b8b0"), 8)
	_bar("metal", e, .9, 2.55, .12, Vector3(.24, .2, .18), Color("#c8c8c0"))
	_camera(e * Vector3(.6, 3.0, .25))
	# West: the kitchen extract up to the roof, two condensers, the gas meters.
	_kit.tube("metal", [w * Vector3(4.4, 1.6, .02), w * Vector3(4.4, 1.6, .3), w * Vector3(4.4, ROOF + .9, .3), w * Vector3(4.2, ROOF + 1.2, .3)], .12, Color("#b8b8b2"), 10)
	for k: int in range(4):
		_bar("metal", w, 4.4, 2.5 + float(k) * 2.0, .16, Vector3(.32, .04, .28), Color("#6a6a66"))
	_ac(w, 2.0, GROUND + .7)
	_ac(w, 6.2, GROUND + PITCH + .5)
	for k: int in range(2):
		_bar("plain", w, 1.2 + float(k) * .5, 1.3, .12, Vector3(.32, .42, .22), Color("#c8c4b4"))
		_bar("plain", w, 1.2 + float(k) * .5, 1.35, .232, Vector3(.16, .1, .004), Color("#1a1c1c"))
	_kit.tube("metal", [w * Vector3(.3, PARAPET - .2, .1), w * Vector3(.3, .1, .1)], .05, Color("#8a8476"), 7)
	_fibre([w * Vector3(6.9, ROOF, .05), w * Vector3(6.9, 3.6, .05), w * Vector3(7.1, 3.2, .05)])

func _side_window(face: Transform3D, r: Rect2, lit: bool) -> void:
	_reveal(face, r, .12, Color("#8a8072"))
	var part := "lit" if lit else "film"
	_kit.atlas(part, face * Vector3(r.position.x, r.position.y, -.1), face * Vector3(r.position.x, r.end.y, -.1), face * Vector3(r.end.x, r.end.y, -.1), face * Vector3(r.end.x, r.position.y, -.1), _px(756, 1146, 228, 228), Color(.8, .78, .74))
	_frame(face, r, -.06, ALU, false)
	for k: int in range(1, 4):
		_bar("metal", face, r.position.x + r.size.x * float(k) / 4.0, r.get_center().y, .05, Vector3(.015, r.size.y + .06, .015), ALU)

func _back_wall() -> void:
	var b := _back
	var holes: Array[Rect2] = [Rect2(.8, 0, .85, 2.0), Rect2(3.0, GROUND + 1.0, 1.2, 1.0), Rect2(3.0, GROUND + PITCH + 1.0, 1.2, 1.0)]
	_render_wall(b, WIDE, PARAPET, GROUND, PITCH, PAINT * .92, holes)
	_flat("steel", b, holes[0], -.04, Color("#5a6460"), .8, .4)
	for k: int in [1, 2]:
		_side_window(b, holes[k], k == 1)
	_bar("metal", b, 1.22, 2.05, .02, Vector3(.95, .06, .06), Color("#5a5c58"))
	for k: int in range(2):
		_kit.lathe("plain", b * Vector3(2.0 + float(k) * .5, 0, .35), [Vector2(.22, 0), Vector2(.24, .6), Vector2(.2, .62)], Color("#3a5a8a"), 10)

func _roof() -> void:
	var f := _front
	var t := .18
	_kit.quad("concrete", f * Vector3(t, ROOF, -t), f * Vector3(t, ROOF, -DEEP + t), f * Vector3(WIDE - t, ROOF, -DEEP + t), f * Vector3(WIDE - t, ROOF, -t), Color("#8a8882"), .8, .8)
	var inner := Color("#a8a49a")
	_kit.quad("concrete", f * Vector3(WIDE - t, ROOF, -t), f * Vector3(WIDE - t, PARAPET, -t), f * Vector3(t, PARAPET, -t), f * Vector3(t, ROOF, -t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(WIDE - t, ROOF, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -t), f * Vector3(WIDE - t, ROOF, -t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(t, ROOF, -t), f * Vector3(t, PARAPET, -t), f * Vector3(t, PARAPET, -DEEP + t), f * Vector3(t, ROOF, -DEEP + t), inner, .7, 1.0)
	_kit.quad("concrete", f * Vector3(t, ROOF, -DEEP + t), f * Vector3(t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, PARAPET, -DEEP + t), f * Vector3(WIDE - t, ROOF, -DEEP + t), inner, .7, 1.0)
	for x: float in [.09, WIDE - .09]:
		_bar("concrete", f, x, PARAPET + .04, -DEEP * .5, Vector3(.28, .08, DEEP), Color("#9a968e"))
	_bar("concrete", f, WIDE * .5, PARAPET + .04, -DEEP + .09, Vector3(WIDE, .08, .28), Color("#9a968e"))
	# Stair hut at the back, a light over its door.
	var px0 := 2.8
	var px1 := 5.0
	var pz0 := -4.4
	var pz1 := -7.1
	var ph := ROOF + 2.4
	var wall := PAINT * .9
	_kit.quad("render", f * Vector3(px0, ROOF, pz0), f * Vector3(px0, ph, pz0), f * Vector3(px1, ph, pz0), f * Vector3(px1, ROOF, pz0), wall, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px1, ROOF, pz0), f * Vector3(px1, ph, pz0), f * Vector3(px1, ph, pz1), f * Vector3(px1, ROOF, pz1), wall * .95, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px0, ROOF, pz1), f * Vector3(px0, ph, pz1), f * Vector3(px0, ph, pz0), f * Vector3(px0, ROOF, pz0), wall * .95, .8, 1.0, .9)
	_kit.quad("render", f * Vector3(px1, ROOF, pz1), f * Vector3(px1, ph, pz1), f * Vector3(px0, ph, pz1), f * Vector3(px0, ROOF, pz1), wall * .9, .8, 1.0, .9)
	_kit.quad("concrete", f * Vector3(px0 - .05, ph, pz0 + .05), f * Vector3(px0 - .05, ph, pz1 - .05), f * Vector3(px1 + .05, ph, pz1 - .05), f * Vector3(px1 + .05, ph, pz0 + .05), Color("#7a7872"), .9, .9)
	_bar("steel", f, 3.4, ROOF + 1.0, pz0 + .02, Vector3(.8, 2.0, .04), Color("#6a7470"))
	_kit.disc("lamp", f * Vector3(3.4, ROOF + 2.15, pz0 + .05), Vector3.RIGHT, Vector3.UP, .05, Color(1.0, .9, .75))
	# Roof garden of the owner: planters, a bench, the old TV aerial, a solar module on a frame.
	for k: int in range(3):
		_bar("wood", f, .7 + float(k) * .7, ROOF + .2, -1.0, Vector3(.6, .4, .35), Color("#6a4a2a"))
		_plant(f * Vector3(.7 + float(k) * .7, ROOF + .4, -1.0), .5, Color("#4a6a32"))
	var solar := Transform3D(Basis(Vector3.RIGHT, -.4), f * Vector3(1.3, ROOF + .55, -3.6))
	_solar_module(solar, 1.6, 1.0)
	for x: float in [.6, 2.0]:
		_bar("steel", f, x, ROOF + .3, -3.6, Vector3(.05, .6, .05), STEEL)
	_kit.tube("metal", [f * Vector3(4.6, ph, pz1 + .4), f * Vector3(4.6, ph + 2.2, pz1 + .4)], .025, ALUMINIUM, 5)
	for k: int in range(3):
		_kit.tube("metal", [f * Vector3(4.0 + float(k) * .1, ph + 1.6 + float(k) * .2, pz1 + .4), f * Vector3(5.1 - float(k) * .1, ph + 1.6 + float(k) * .2, pz1 + .4)], .008, ALUMINIUM, 3)
	_ac(Transform3D(Basis.IDENTITY, Vector3(-WIDE * .5, ROOF, -5.7)), 1.2, .44, .0)

# ---------------------------------------------------------------- pavement

func _pavement() -> void:
	var f := _front
	# Lit stand sign by the right window, on a weighted chrome foot, its cable to the wall.
	var sx := 4.55
	var sz := .55
	_kit.lathe("metal", f * Vector3(sx, 0, sz), [Vector2(.24, 0), Vector2(.24, .03), Vector2(.05, .06)], Color("#b8b8b4"), 12)
	_kit.tube("metal", [f * Vector3(sx, .05, sz), f * Vector3(sx, .32, sz)], .025, Color("#c8c8c4"), 6)
	_bar("metal", f, sx, .73, sz, Vector3(.42, .78, .14), Color("#2a2a2c"))
	var stand := _px(1080, 740, 240, 420)
	_kit.atlas("sign", f * Vector3(sx - .2, .35, sz + .072), f * Vector3(sx - .2, 1.1, sz + .072), f * Vector3(sx + .2, 1.1, sz + .072), f * Vector3(sx + .2, .35, sz + .072), stand)
	_kit.atlas("sign", f * Vector3(sx + .2, .35, sz - .072), f * Vector3(sx + .2, 1.1, sz - .072), f * Vector3(sx - .2, 1.1, sz - .072), f * Vector3(sx - .2, .35, sz - .072), stand)
	_kit.tube("plain", [f * Vector3(sx + .1, .05, sz - .05), f * Vector3(sx + .3, .02, sz - .3), f * Vector3(5.05, .02, .01)], .008, Color("#1a1a1a"), 3)
	# The chalk board on an easel between the window and the door.
	var ax := 3.2
	var az := .62
	var hw := .26
	var cell := _px(700, 740, 360, 520)
	_kit.atlas("board", f * Vector3(ax - hw, .28, az + .2), f * Vector3(ax - hw, 1.02, az + .02), f * Vector3(ax + hw, 1.02, az + .02), f * Vector3(ax + hw, .28, az + .2), cell)
	_kit.atlas("board", f * Vector3(ax + hw, .28, az - .2), f * Vector3(ax + hw, 1.02, az - .02), f * Vector3(ax - hw, 1.02, az - .02), f * Vector3(ax - hw, .28, az - .2), cell)
	for x: float in [ax - hw - .015, ax + hw + .015]:
		for s: float in [1.0, -1.0]:
			_kit.beam("wood", f * Vector3(x, 0, az + s * .27), f * Vector3(x, 1.06, az), .03, .03, Vector3.UP, Color("#6a4a2a"))
	# A rubber plant in a glazed pot by the door, the umbrella stand.
	_kit.lathe("plain", f * Vector3(1.55, 0, .3), [Vector2(.14, 0), Vector2(.19, .4), Vector2(.2, .43)], Color("#2a3a5a"), 10)
	_plant(f * Vector3(1.55, .4, .3), .9, Color("#2a4a22"))
	_kit.lathe("metal", f * Vector3(2.72, 0, .2), [Vector2(.1, 0), Vector2(.1, .5)], Color("#8a8a84"), 10)
	_kit.tube("plain", [f * Vector3(2.7, .1, .2), f * Vector3(2.66, .9, .22)], .012, Color("#1a2a5a"), 4)
