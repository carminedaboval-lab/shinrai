extends RefCounted
## Street furniture for the main south street, in WORLD metres: park-side guard
## rail, crossing bollards, a cycle rack, recycling stations beside the vending
## machines, water-valve covers in the pavement, a convex traffic mirror, stop
## signs with painted stop lines at both side-street junctions, and guards and
## plates on the utility poles. Everything sits on the pavements or the curb
## line; nothing enters the carriageway except the painted stop lines.
## Props with collision use layer 1, so the enemy navigation capsule sweeps see
## them and route around (extraction_navigation.gd marks those cells solid).
const Kit = preload("res://scripts/midori_park_kit.gd")
const BOLLARD := "res://assets/shinrai/parks/midori_park/models/furniture/ambient/entrance_bollards/sunpole_pa114sk_installed.glb"
const CYCLE_RACK := "res://assets/shinrai/parks/midori_park/models/furniture/ambient/bicycle_rack/midori_bicycle_rack.glb"
const RECYCLING := "res://assets/shinrai/parks/midori_park/models/furniture/ambient/recycling_station/recycling_cyberpunk.glb"
const PAVEMENT_Y := 0.09
const ROAD_Y := 0.02
# Utility poles as built by midori_neon_street.gd (radius 0.13).
const POLES: Array[Vector3] = [Vector3(-16.5,.09,190.9), Vector3(3.4,.09,190.9), Vector3(13.6,.09,190.9)]

static func build(street: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "StreetFurniture"
	root.set_meta("creator_protected", true)
	street.add_child(root)
	var mats := _materials()
	var report := {"coordinates":"world_metres","collision_layer":1}
	report["guard_rail"] = _guard_rail(street, root, mats)
	report["bollards"] = _bollards(street, root)
	report["cycle_rack"] = _cycle_rack(street, root)
	report["recycling_stations"] = _recycling(street, root)
	report["water_valve_covers"] = _water_valve_covers(street, root, mats)
	report["traffic_mirror"] = _traffic_mirror(street, root, mats)
	report["stop_signs"] = _stop_signs(street, root, mats)
	report["pole_guards"] = _pole_guards(root, mats)
	root.set_meta("street_furniture", report)
	return report

static func _materials() -> Dictionary:
	var mirror := Kit.mat(Color("#e9eef3"), .08, .85)
	var sign_red := Kit.mat(Color("#c01a2c"), .45)
	sign_red.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sign_white := Kit.mat(Color("#f1f1ec"), .45)
	sign_white.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {
		"rail_white": Kit.mat(Color("#e6e8e2"), .42, .25),
		"rail_valley": Kit.mat(Color("#b8bbb4"), .5, .25),
		"galvanised": Kit.mat(Color("#9ea3a6"), .48, .65),
		"orange": Kit.mat(Color("#f0641e"), .5),
		"mirror": mirror,
		"mirror_back": Kit.mat(Color("#2b2e31"), .6, .3),
		"sign_red": sign_red,
		"sign_white": sign_white,
		"guard_yellow": Kit.mat(Color("#e3b422"), .6),
		"guard_black": Kit.mat(Color("#17191c"), .7),
		"plate_white": Kit.mat(Color("#e4e4df"), .5),
		"plate_blue": Kit.mat(Color("#1f4fae"), .5),
		"valve_lid": Kit.mat(Color("#2c5a9c"), .65, .4),
	}

## White W-beam guard rail along the park-side curb, 0.80 m high, posts every
## 2 m, orange reflectors on each post, open at the crossing and the junctions.
static func _guard_rail(street: Node3D, root: Node3D, mats: Dictionary) -> Dictionary:
	var posts := 0
	var runs: Array[Vector2] = [Vector2(-31.5,-4.4), Vector2(4.4,31.5)]
	var beam_z := 182.52
	var top := PAVEMENT_Y + .80
	for run: Vector2 in runs:
		var length := run.y - run.x
		var cx := (run.x + run.y) * .5
		Kit.box(root, "GuardRailBeam", Vector3(length, .35, .05), Vector3(cx, top - .175, beam_z), mats.rail_white)
		Kit.box(root, "GuardRailValley", Vector3(length + .002, .05, .014), Vector3(cx, top - .175, beam_z - .024), mats.rail_valley)
		# Rounded-off terminal plates at each end of the run.
		for end: float in [run.x, run.y]:
			Kit.box(root, "GuardRailTerminal", Vector3(.06, .37, .07), Vector3(end, top - .175, beam_z), mats.rail_white)
		var xs: Array[float] = [run.x + .25]
		var x := run.x + 2.0
		while x < run.y - 1.0:
			xs.append(x)
			x += 2.0
		xs.append(run.y - .25)
		for px: float in xs:
			Kit.tube(root, "GuardRailPost", Vector3(px, PAVEMENT_Y, beam_z + .09), Vector3(px, top - .03, beam_z + .09), .057, mats.rail_white)
			Kit.box(root, "GuardRailReflector", Vector3(.09, .09, .012), Vector3(px, top - .175, beam_z - .031), mats.orange)
			posts += 1
		street.call("_solid", root, "GuardRailBlock", Vector3(cx, PAVEMENT_Y + .42, beam_z + .03), Vector3(length, .84, .17))
	return {"runs":runs.size(), "posts":posts, "height_m":.80, "z":beam_z}

## Sunpole bollards flanking the dropped curbs, before the tactile strips.
static func _bollards(street: Node3D, root: Node3D) -> Dictionary:
	var placed := 0
	for pos: Vector3 in [Vector3(-2.0,PAVEMENT_Y,181.25), Vector3(2.0,PAVEMENT_Y,181.25), Vector3(-2.0,PAVEMENT_Y,191.72), Vector3(2.0,PAVEMENT_Y,191.72)]:
		if _model(root, "CrossingBollard", BOLLARD, pos, 0.0) != null:
			street.call("_solid", root, "CrossingBollardBlock", pos + Vector3(0,.45,0), Vector3(.16,.9,.16))
			placed += 1
	return {"placed":placed, "model":BOLLARD}

## Four hoop stands on the park-side pavement east of the crossing (the shop
## frontages carry display tables), hoops across the pavement so bicycles stand
## parallel to the guard rail.
static func _cycle_rack(street: Node3D, root: Node3D) -> Dictionary:
	var hoops := 0
	for x: float in [13.0, 13.9, 14.8, 15.7]:
		if _model(root, "CycleHoop", CYCLE_RACK, Vector3(x, PAVEMENT_Y, 181.0), PI * .5) != null:
			hoops += 1
	if hoops > 0:
		street.call("_solid", root, "CycleRackBlock", Vector3(14.35, PAVEMENT_Y + .43, 181.0), Vector3(3.6, .86, .9))
	return {"hoops":hoops, "model":CYCLE_RACK}

## A can-and-bottle station beside each vending pair, as every Japanese
## vending machine has.
static func _recycling(street: Node3D, root: Node3D) -> Dictionary:
	var placed := 0
	for x: float in [-13.2, 28.3]:
		# The model's origin is at mid height (bounds min y -0.354).
		if _model(root, "RecyclingStation", RECYCLING, Vector3(x, PAVEMENT_Y + .354, 193.1), 0.0) != null:
			street.call("_solid", root, "RecyclingBlock", Vector3(x, PAVEMENT_Y + .64, 193.1), Vector3(1.2, 1.28, .78))
			placed += 1
	return {"placed":placed, "model":RECYCLING}

## 300 mm cast frames with blue-painted 止水栓 lids, 6 mm proud of the pavers.
static func _water_valve_covers(street: Node3D, root: Node3D, mats: Dictionary) -> Dictionary:
	# Clear of the shop display tables, planters, lamps and the cycle hoops.
	var spots: Array[Vector2] = [Vector2(-27.5,192.4), Vector2(-11.8,191.8), Vector2(29.8,192.4), Vector2(-20.3,180.6), Vector2(-14.0,181.6), Vector2(24.0,180.6)]
	var street_mats: Dictionary = street.get("materials")
	for spot: Vector2 in spots:
		var frame := Kit.box(root, "WaterValveFrame", Vector3(.30, .006, .30), Vector3(spot.x, PAVEMENT_Y + .003, spot.y), street_mats.land_iron)
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lid := Kit.box(root, "WaterValveLid", Vector3(.24, .004, .24), Vector3(spot.x, PAVEMENT_Y + .0075, spot.y), mats.valve_lid)
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Two lifting slots.
		for dx: float in [-.07, .07]:
			Kit.box(root, "WaterValveSlot", Vector3(.03, .003, .012), Vector3(spot.x + dx, PAVEMENT_Y + .0095, spot.y), mats.guard_black)
	return {"covers":spots.size(), "size_m":.30}

## Convex traffic mirror on a 3 m galvanised pole at the crossing's park-side
## corner, angled down the road toward the junction.
static func _traffic_mirror(street: Node3D, root: Node3D, mats: Dictionary) -> Dictionary:
	var base := Vector3(-3.7, PAVEMENT_Y, 182.3)
	var head := base + Vector3(0, 3.0, 0)
	Kit.tube(root, "MirrorPole", base, head + Vector3(0, .1, 0), .045, mats.galvanised)
	Kit.disc(root, "MirrorPoleFoot", .09, .06, base + Vector3(0, .03, 0), mats.galvanised)
	for band_y: float in [.9, 1.1]:
		Kit.disc(root, "MirrorPoleBand", .048, .12, base + Vector3(0, band_y, 0), mats.orange)
	# The mirror faces the road and slightly down, so a driver sees the crossing.
	var facing := Vector3(.35, -.22, .91).normalized()
	var centre := head + Vector3(0, -.05, 0) + facing * .12
	var basis := Basis(Quaternion(Vector3.UP, facing))
	var back := Kit.disc(root, "MirrorBack", .44, .09, centre - facing * .06, mats.mirror_back)
	back.basis = basis
	var rim := Kit.disc(root, "MirrorRim", .44, .02, centre - facing * .012, mats.orange)
	rim.basis = basis
	var glass := Kit.disc(root, "MirrorGlass", .40, .012, centre, mats.mirror)
	glass.basis = basis
	Kit.box(root, "MirrorBracket", Vector3(.06, .06, .14), head + Vector3(0, -.05, 0) + facing * .05, mats.galvanised)
	street.call("_solid", root, "MirrorPoleBlock", base + Vector3(0, 1.5, 0), Vector3(.12, 3.0, .12))
	return {"position":base, "mirror_diameter_m":.80}

## Japanese stop control at both side-street mouths: inverted red triangle on
## a 2.6 m pole on the driver's left, a 45 cm stop line across the approach
## lane and 止まれ painted vertically in the lane.
static func _stop_signs(street: Node3D, root: Node3D, mats: Dictionary) -> Dictionary:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic", "Meiryo", "Noto Sans CJK JP", "sans-serif"])
	font.font_weight = 700
	var count := 0
	# [pole x, lane centre x] for the west and east side streets (left-hand traffic,
	# northbound approach lane is the western half of each 6 m street).
	for spec: Vector2 in [Vector2(-38.85, -37.0), Vector2(32.1, 34.0)]:
		var base := Vector3(spec.x, PAVEMENT_Y, 191.7)
		Kit.tube(root, "StopSignPole", base, base + Vector3(0, 2.6, 0), .034, mats.galvanised)
		var centre := base + Vector3(0, 2.15, .04)
		_triangle(root, "StopSignBorder", .84, centre, mats.sign_white)
		_triangle(root, "StopSignFace", .72, centre + Vector3(0, 0, .004), mats.sign_red)
		var label := Label3D.new()
		label.name = "StopSignText"
		label.text = "止まれ"
		label.font = font
		label.font_size = 64
		label.pixel_size = .0027
		label.modulate = Color("#f6f6f2")
		label.shaded = true
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		label.position = centre + Vector3(0, .11, .009)
		root.add_child(label)
		street.call("_solid", root, "StopSignBlock", base + Vector3(0, 1.3, 0), Vector3(.1, 2.6, .1))
		# Paint: stop line, then 止まれ painted vertically in the approach lane as
		# thick strokes (the way it is stencilled on Japanese roads), the driver
		# reading 止 first at the far end.
		street.call("_box", root, "StopLine", Vector3(spec.y, ROAD_Y + .005, 191.5), Vector3(2.8, .006, .45), "land_paint", false)
		_road_glyph(street, root, GLYPH_RE, spec.y, 193.6)
		_road_glyph(street, root, GLYPH_MA, spec.y, 196.1)
		_road_glyph(street, root, GLYPH_TOMARU, spec.y, 198.6)
		count += 1
	return {"junctions":count, "pole_height_m":2.6, "triangle_side_m":.72}

## Yellow-and-black guards on the utility poles with an advertising plate and a
## blue block-address plate, the standard Tokyo pole dressing.
static func _pole_guards(root: Node3D, mats: Dictionary) -> Dictionary:
	for base: Vector3 in POLES:
		for i: int in range(6):
			var band := Kit.disc(root, "PoleGuardBand", .165, .19, base + Vector3(0, .095 + float(i) * .19, 0), mats.guard_yellow if i % 2 == 0 else mats.guard_black)
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Plates face the road (local -Z of the street).
		Kit.box(root, "PoleAdPlate", Vector3(.44, .92, .025), base + Vector3(0, 2.05, -.165), mats.plate_white)
		Kit.box(root, "PoleAdPlateBand", Vector3(.44, .20, .03), base + Vector3(0, 2.40, -.168), mats.plate_blue)
		Kit.box(root, "PoleAddressPlate", Vector3(.025, .40, .13), base + Vector3(.16, 2.95, 0), mats.plate_blue)
	return {"poles":POLES.size(), "guard_height_m":1.14}

# Road-marking glyphs as stroke rectangles in a unit cell: (u0, v0, u1, v1), u to
# the reader's right and v up, both -0.5..0.5. Stencilled 1.1 m wide, 2.0 m long.
const GLYPH_TOMARU: Array[Vector4] = [Vector4(-.5,-.5,.5,-.3), Vector4(-.1,-.5,.1,.5), Vector4(-.5,-.5,-.3,.05), Vector4(-.1,0,.5,.2)]
const GLYPH_MA: Array[Vector4] = [Vector4(-.4,.3,.4,.5), Vector4(-.3,-.02,.3,.18), Vector4(-.1,-.5,.1,.5), Vector4(-.45,-.5,.1,-.3), Vector4(-.45,-.5,-.25,-.1)]
const GLYPH_RE: Array[Vector4] = [Vector4(-.45,-.5,-.25,.5), Vector4(-.5,.15,0,.35), Vector4(.15,-.45,.35,.45), Vector4(.15,-.5,.5,-.3)]

## The reader drives toward -Z, so "up" is -Z and "right" is -X.
static func _road_glyph(street: Node3D, root: Node3D, strokes: Array[Vector4], cx: float, cz: float, width := 1.1, length := 2.0) -> void:
	for s: Vector4 in strokes:
		var u := (s.x + s.z) * .5
		var v := (s.y + s.w) * .5
		var size := Vector3((s.z - s.x) * width, .006, (s.w - s.y) * length)
		street.call("_box", root, "StopGlyphStroke", Vector3(cx - u * width, ROAD_Y + .005, cz - v * length), size, "land_paint", false)

static func _triangle(parent: Node3D, label: String, side: float, centre: Vector3, material: Material) -> void:
	# Inverted equilateral triangle in the XY plane, facing +Z, centroid at origin.
	var h := side * sqrt(3.0) * .5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector2 in [Vector2(-side * .5, h / 3.0), Vector2(side * .5, h / 3.0), Vector2(0, -2.0 * h / 3.0)]:
		tool.set_normal(Vector3.BACK)
		tool.set_uv(Vector2(point.x / side + .5, .5 - point.y / h))
		tool.add_vertex(Vector3(point.x, point.y, 0))
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = tool.commit()
	visual.material_override = material
	visual.position = centre
	parent.add_child(visual)

static func _model(parent: Node3D, label: String, path: String, pos: Vector3, yaw: float) -> Node3D:
	if not ResourceLoader.exists(path): return null
	var scene := load(path) as PackedScene
	if scene == null: return null
	var node := scene.instantiate() as Node3D
	if node == null: return null
	node.name = label
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)
	return node
