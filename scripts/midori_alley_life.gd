extends Node3D
## Lived-in Tokyo alleys (路地) in the gaps the near city leaves between lots, in
## WORLD metres. Direct child of the scene root; reads the near city's `alleys`
## list and never edits its geometry.
##
## Mouths onto a street get the busy end: vending machines, bicycles, nobori
## flags and crates in shopping blocks; pots, bins and drying towels where
## people live. Walls carry meters, AC units and downpipes, cables cross
## overhead, and wall lamps come on after dark. Cloth, leaves, nets and cables
## all sway in the shared Midori breeze, calmer at night.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const PROPS_SHADER := preload("res://scripts/midori_street_props.gdshader")
const PARK := Rect2(-222, -182, 444, 364)
const RANGE := 150.0
const CHUNK := 96.0
const FLOOR_Y := 0.085
const MAX_LIGHTS := 12
const SEED := 20261102
## Lamp housings render on their own layer, which the lamps' own lights skip:
## the light leaves through the glass, it does not wash over the shell.
const FIXTURE_LAYER := 1 << 13
## Housings sit in finer tiles drawn only out to 150 m, where a lamp is a few pixels.
const FIXTURE_CHUNK := 48.0
const FIXTURE_RANGE := 150.0

var installed := false
var report: Dictionary = {}
var alleys: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _chunks: Dictionary = {}
var _fixtures: Dictionary = {}
var _material: ShaderMaterial
var _lights: Array[OmniLight3D] = []
var _light_spots: Array[Dictionary] = []
var _lamp_rng := RandomNumberGenerator.new()
var _assign_clock := 0.0
var _night := false
var _st: SurfaceTool
var _flex := 0.0
var _glow := 0.0

func _ready() -> void:
	add_to_group("midori_horizon")
	var park := get_parent() as Node3D
	await Budget.wait_structure(park)
	var city: Node = null
	var deadline := Time.get_ticks_msec() + 120000
	while city == null and Time.get_ticks_msec() < deadline:
		city = park.get_node_or_null("MidoriHorizon/NearCity")
		if city == null: await get_tree().process_frame
	if city == null or city.get("alleys") == null:
		report = {"error":"near city alleys unavailable"}
		print("MIDORI_ALLEY_LIFE_SKIPPED ", JSON.stringify(report))
		return
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	_rng.seed = SEED
	_lamp_rng.seed = SEED + 7
	_material = ShaderMaterial.new()
	_material.shader = PROPS_SHADER
	# Hand-built buildings sometimes build over a gap (a lane, a shared wall).
	# Their real footprints, less 35 cm of eaves, decide which gaps stay open.
	var avoid: Array[Rect2] = []
	for node: Node3D in city.get("_handmade"):
		var bounds := AABB()
		var first := true
		for part: Node in node.find_children("*", "MeshInstance3D", true, false):
			var visual := part as MeshInstance3D
			if visual.mesh == null: continue
			var box := visual.global_transform * visual.get_aabb()
			if box.size.y < 0.05 and box.position.y < 0.3: continue # Ground paving.
			bounds = box if first else bounds.merge(box)
			first = false
		if not first:
			avoid.append(Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z).grow(-0.35))
	var clear: Array[Rect2] = []
	for zone: Rect2 in city.get("CLEAR_ZONES"): clear.append(zone)
	for entry: Dictionary in city.get("alleys"):
		var rect: Rect2 = entry.rect
		var width := minf(rect.size.x, rect.size.y)
		var length := maxf(rect.size.x, rect.size.y)
		if width < 0.5 or length < 4.0: continue
		# The near city also lays out (and rejects) lots inside the park and the
		# ring road, so their gaps are in its list too. Only real blocks count.
		if PARK.grow(23.0).intersects(rect): continue
		if _park_distance(rect.get_center()) > RANGE: continue
		var blocked := false
		for zone: Rect2 in clear:
			if zone.intersects(rect): blocked = true
		for footprint: Rect2 in avoid:
			if footprint.intersects(rect): blocked = true
		if blocked: continue
		alleys.append({"rect":rect, "commercial":bool(entry.commercial), "width":width, "length":length})
	var pieces := 0
	for alley: Dictionary in alleys:
		pieces += _dress(alley)
	_commit()
	_place_lights()
	installed = true
	set_night_mode(bool(park.get("is_night_mode")))
	report = {"alleys":alleys.size(), "pieces":pieces, "chunks":_chunks.size(), "lights":_lights.size()}
	print("MIDORI_ALLEY_LIFE_READY ", JSON.stringify(report))

func set_night_mode(value: bool) -> void:
	if _material != null:
		_material.set_shader_parameter("night", 1.0 if value else 0.0)
		_material.set_shader_parameter("wind_strength", 0.45 if value else 1.0)
	_night = value
	_assign_clock = 0.0
	if not value:
		for light: OmniLight3D in _lights: light.visible = false

func _park_distance(p: Vector2) -> float:
	var d := p.abs() - PARK.size * 0.5
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()

## An alley end that meets a street: block edges sit 10 m from each grid road
## centre, and park-side blocks stop 24 m out from the park.
func _is_mouth(along: float, axis_z: bool) -> bool:
	if absf(absf(fposmod(along + 32.0, 64.0) - 32.0) - 10.0) < 0.9: return true
	var ring := 206.0 if axis_z else 246.0
	return absf(absf(along) - ring) < 0.9

# ---------------------------------------------------------------- building

func _use(point: Vector3) -> void:
	var key := Vector2i(floori(point.x / CHUNK), floori(point.z / CHUNK))
	if not _chunks.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_chunks[key] = st
	_st = _chunks[key]

func _use_fixture(point: Vector3) -> void:
	var key := Vector2i(floori(point.x / FIXTURE_CHUNK), floori(point.z / FIXTURE_CHUNK))
	if not _fixtures.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_fixtures[key] = st
	_st = _fixtures[key]

func _v(at: Vector3, normal: Vector3, color: Color, flex := -1.0) -> void:
	_st.set_color(color)
	_st.set_normal(normal)
	_st.set_uv2(Vector2(_flex if flex < 0.0 else flex, _glow))
	_st.add_vertex(at)

## Oriented box: half extents along x, y, z.
func _box(centre: Vector3, x: Vector3, y: Vector3, z: Vector3, color: Color) -> void:
	var faces: Array = [[x, y, z], [-x, y, -z], [z, y, -x], [-z, y, x], [y, -z, x], [-y, z, x]]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var t: Vector3 = face[1]
		var b: Vector3 = face[2]
		var c := centre + n
		var quad: Array[Vector3] = [c - t - b, c - t + b, c + t + b, c + t - b]
		var shade := color.darkened(0.12) if n.y < -0.01 else (color.lightened(0.04) if n.y > 0.01 else color)
		for index: int in [0, 1, 2, 0, 2, 3]:
			_v(quad[index], n.normalized(), shade)

func _tube(a: Vector3, b: Vector3, radius: float, color: Color, sides := 6, flex_a := -1.0, flex_b := -1.0, radius_b := -1.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side).normalized()
	var rb := radius if radius_b < 0.0 else radius_b
	for i: int in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var ring: Array = [[a + d0 * radius, d0, flex_a], [b + d0 * rb, d0, flex_b], [b + d1 * rb, d1, flex_b], [a + d0 * radius, d0, flex_a], [b + d1 * rb, d1, flex_b], [a + d1 * radius, d1, flex_a]]
		for corner: Array in ring:
			_v(corner[0], corner[1], color, corner[2])

func _blob(centre: Vector3, radius: float, color: Color, flex: float) -> void:
	# Low octahedron of leaves, stretched a little so clumps are not regular.
	var stretch := Vector3(_rng.randf_range(0.8, 1.3), _rng.randf_range(0.7, 1.1), _rng.randf_range(0.8, 1.3)) * radius
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var faces: Array = [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	for face: Array in faces:
		var pts: Array[Vector3] = []
		for index: int in face: pts.append(centre + dirs[index] * stretch)
		var n := (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
		var shade := color.lightened(_rng.randf_range(-0.08, 0.1))
		for p: Vector3 in pts: _v(p, n, shade, flex * clampf((p.y - centre.y + radius) / (2.0 * radius), 0.3, 1.0))

## Hanging cloth: fixed along its top edge, freer the lower it hangs.
func _cloth(top_left: Vector3, across: Vector3, drop: float, color: Color, flex: float, rows := 4) -> void:
	var n := across.cross(Vector3.DOWN).normalized()
	for r: int in range(rows):
		var y0 := drop * float(r) / float(rows)
		var y1 := drop * float(r + 1) / float(rows)
		var f0 := flex * pow(float(r) / float(rows), 0.8)
		var f1 := flex * pow(float(r + 1) / float(rows), 0.8)
		var a := top_left + Vector3.DOWN * y0
		var b := top_left + across + Vector3.DOWN * y0
		var c := top_left + across + Vector3.DOWN * y1
		var d := top_left + Vector3.DOWN * y1
		var shade := color.darkened(0.04 * float(r))
		for corner: Array in [[a, f0], [b, f0], [c, f1], [a, f0], [c, f1], [d, f1]]:
			_v(corner[0], n, shade, corner[1])

## Sagging cable between two points, its middle free to swing.
func _cable(a: Vector3, b: Vector3, sag: float, color: Color) -> void:
	var steps := 8
	var previous := a
	for i: int in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var t0 := float(i - 1) / float(steps)
		_tube(previous, p, 0.012, color, 4, 0.14 * sin(PI * t0), 0.14 * sin(PI * t))
		previous = p

# ------------------------------------------------------------------ dressing

## Lays out one alley. Returns how many props it placed.
func _dress(alley: Dictionary) -> int:
	var rect: Rect2 = alley.rect
	var axis_z := rect.size.y >= rect.size.x
	var along := Vector3(0, 0, 1) if axis_z else Vector3(1, 0, 0)
	var across := Vector3(1, 0, 0) if axis_z else Vector3(0, 0, 1)
	var width: float = alley.width
	var length: float = alley.length
	var start := Vector3(rect.get_center().x, FLOOR_Y, rect.position.y) if axis_z else Vector3(rect.position.x, FLOOR_Y, rect.get_center().y)
	var commercial: bool = alley.commercial
	_use(start + along * length * 0.5)
	_flex = 0.0
	_glow = 0.0
	var count := 0
	# Concrete floor with the drain channel's precast lids down one side.
	_box(start + along * length * 0.5 + Vector3.UP * 0.004, along * length * 0.5, Vector3.UP * 0.004, across * width * 0.5, Color("#aaa69c"))
	# Damp, mossy strip where the drain side never dries.
	var damp_side := 1.0 if _rng.randf() < 0.5 else -1.0
	_box(start + along * length * 0.5 + across * damp_side * (width * 0.5 - 0.12) + Vector3.UP * 0.0085, along * length * 0.5, Vector3.UP * 0.0005, across * 0.12, Color("#5f6a4e"))
	var channel_side := -1.0 if _rng.randf() < 0.5 else 1.0
	var lid_x := (width * 0.5 - 0.2) * channel_side
	var lid_count := int(minf(length, 22.0) / 0.62)
	for i: int in range(lid_count):
		for end: int in range(2):
			var s := 0.31 + float(i) * 0.62
			var from_start := end == 0
			var at := start + along * (s if from_start else length - s) + across * lid_x
			if width > 0.7 and (from_start or length > 44.0):
				_box(at + Vector3.UP * 0.018, along * 0.29, Vector3.UP * 0.012, across * 0.17, Color("#a29e95").darkened(_rng.randf_range(0.0, 0.18)))
	for end: int in range(2):
		var mouth_along := (rect.position.y if axis_z else rect.position.x) if end == 0 else (rect.end.y if axis_z else rect.end.x)
		var mouth := start if end == 0 else start + along * length
		var inward := along if end == 0 else -along
		var is_mouth := _is_mouth(mouth_along, axis_z)
		var depth := minf(length * 0.5, 16.0 if is_mouth else 8.0)
		count += _walls(mouth, inward, across, width, depth, commercial, is_mouth)
		if is_mouth: count += _mouth(mouth, inward, across, width, commercial)
	return count

## Meters, AC units, downpipes, pots and cables for the first `depth` metres.
func _walls(mouth: Vector3, inward: Vector3, across: Vector3, width: float, depth: float, commercial: bool, is_mouth: bool) -> int:
	var count := 0
	var half := width * 0.5
	var s := 1.4 + _rng.randf() * 1.2
	while s < depth:
		for side: float in [-1.0, 1.0]:
			var wall := mouth + inward * s + across * side * half
			var into := -across * side
			var roll := _rng.randf()
			if roll < 0.18:
				# Downpipe from the roof, with an elbow onto the drain.
				_tube(wall + into * 0.07 + Vector3.UP * (5.5 if commercial else 5.0), wall + into * 0.07 + Vector3.UP * 0.25, 0.045, Color("#8a8e8c"), 6)
				_tube(wall + into * 0.07 + Vector3.UP * 0.25, wall + into * 0.2 + Vector3.UP * 0.05, 0.045, Color("#8a8e8c"), 6)
				count += 1
			elif roll < 0.36:
				# Gas and electricity meters at chest height.
				_box(wall + into * 0.09 + Vector3.UP * 1.55, inward * 0.15, Vector3.UP * 0.2, into * 0.08, Color("#cfcbbd"))
				_box(wall + into * 0.07 + Vector3.UP * 1.95 + inward * 0.32, inward * 0.12, Vector3.UP * 0.17, into * 0.06, Color("#9fa4a3"))
				_box(wall + into * 0.135 + Vector3.UP * 2.0 + inward * 0.32, inward * 0.06, Vector3.UP * 0.05, into * 0.01, Color("#1c2124"))
				_tube(wall + into * 0.05 + Vector3.UP * 1.35, wall + into * 0.05 + Vector3.UP * 0.1, 0.018, Color("#c9b24a"), 5)
				count += 1
			elif roll < 0.58 and width > 0.9:
				# Outdoor AC unit with its pipe run up the wall.
				var unit := wall + into * 0.18 + Vector3.UP * 0.33
				_box(unit, inward * 0.4, Vector3.UP * 0.3, into * 0.15, Color("#dedbd1"))
				_box(unit + into * 0.152 + inward * 0.1, inward * 0.22, Vector3.UP * 0.22, into * 0.004, Color("#2b2e30"))
				# Insulated pipe pair: out of the unit's side, then straight up the wall.
				var top := Vector3.UP * _rng.randf_range(2.6, 7.0 if commercial else 4.5)
				var riser := wall + into * 0.05 - inward * 0.48
				_tube(unit - inward * 0.4 + Vector3.UP * 0.1, riser + Vector3.UP * 0.43, 0.035, Color("#e7e1d3"), 5)
				_tube(riser + Vector3.UP * 0.43, riser + top, 0.035, Color("#e7e1d3"), 5)
				count += 1
			elif roll < 0.62 and commercial:
				# AC unit on a wall bracket, a storey up.
				var high := wall + into * 0.2 + Vector3.UP * _rng.randf_range(3.4, 6.5)
				_box(high, inward * 0.4, Vector3.UP * 0.3, into * 0.15, Color("#d6d3c9"))
				_tube(high + Vector3.DOWN * 0.31 + inward * 0.3, wall + Vector3.DOWN * 0.31 + high.y * Vector3.UP - wall.y * Vector3.UP + inward * 0.3, 0.02, Color("#505456"), 4)
				_tube(high + Vector3.DOWN * 0.31 - inward * 0.3, wall + Vector3.DOWN * 0.31 + high.y * Vector3.UP - wall.y * Vector3.UP - inward * 0.3, 0.02, Color("#505456"), 4)
				count += 1
			elif roll < 0.8 and width > 0.8 and not commercial:
				count += _pots(wall + into * 0.2, inward, into)
			elif roll < 0.86 and width > 1.1:
				count += _bin(wall + into * 0.3, inward, into)
		# Wall lamp now and then; it lights at night.
		if _rng.randf() < 0.22:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var wall_at := mouth + inward * s + across * side * half + Vector3.UP * 2.6
			_wall_lamp(wall_at, -across * side, inward, commercial)
			count += 1
		s += _rng.randf_range(1.3, 2.6)
	# Two or three cables cross overhead near the mouth.
	if is_mouth:
		for i: int in range(_rng.randi_range(2, 4)):
			var at := _rng.randf_range(0.8, minf(depth, 9.0))
			var height := _rng.randf_range(4.0, 7.5)
			_cable(mouth + inward * at - across * half + Vector3.UP * height, mouth + inward * (at + _rng.randf_range(-1.2, 1.2)) + across * half + Vector3.UP * (height + _rng.randf_range(-0.6, 0.6)), 0.12 + width * 0.05, Color("#1e2021"))
			count += 1
		if not commercial and width > 0.8 and _rng.randf() < 0.55:
			count += _laundry(mouth + inward * _rng.randf_range(2.0, 6.0), across, width)
	return count

func _pots(base: Vector3, inward: Vector3, into: Vector3) -> int:
	var placed := 0
	for i: int in range(_rng.randi_range(2, 5)):
		var at := base + inward * (float(i) * 0.38 - 0.4) + into * _rng.randf_range(-0.05, 0.12)
		if _rng.randf() < 0.3:
			# Foam fish box turned planter.
			_box(at + Vector3.UP * 0.16, inward * 0.26, Vector3.UP * 0.16, into * 0.18, Color("#e8e6df"))
			for k: int in range(3):
				_blob(at + Vector3.UP * 0.38 + inward * (float(k) - 1.0) * 0.15, 0.13, Color("#4a6b3a"), 0.04)
		else:
			var radius := _rng.randf_range(0.1, 0.19)
			var height := radius * _rng.randf_range(1.2, 1.8)
			var colors: Array[Color] = [Color("#a35a3a"), Color("#2c2e2b"), Color("#556b4a"), Color("#b98a5e")]
			_tube(at, at + Vector3.UP * height, radius * 0.75, colors[_rng.randi_range(0, 3)], 8, -1.0, -1.0, radius)
			var leaf := Color("#4f7a3c") if _rng.randf() < 0.7 else Color("#6c8a3f")
			for k: int in range(_rng.randi_range(2, 4)):
				_blob(at + Vector3.UP * (height + radius * 0.6 + float(k) * 0.08) + Vector3(_rng.randf_range(-0.08, 0.08), 0, _rng.randf_range(-0.08, 0.08)), radius * 1.2, leaf, 0.05)
		placed += 1
	return placed

func _bin(at: Vector3, inward: Vector3, into: Vector3) -> int:
	var colors: Array[Color] = [Color("#2f5d4a"), Color("#3c5f8a"), Color("#6b6f6f")]
	_tube(at, at + Vector3.UP * 0.66, 0.24, colors[_rng.randi_range(0, 2)], 10)
	_tube(at + Vector3.UP * 0.66, at + Vector3.UP * 0.7, 0.26, Color("#2a2d2c"), 10)
	# Yellow crow net thrown over the bags.
	_cloth(at + Vector3.UP * 0.74 - inward * 0.3 - into * 0.3, inward * 0.6, 0.55, Color("#d9b21e"), 0.04, 2)
	return 1

func _laundry(at: Vector3, across: Vector3, width: float) -> int:
	# A drying pole out from the wall, with towels and a shirt pegged on.
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var wall := at + across * side * width * 0.5 + Vector3.UP * 2.9
	var tip := wall - across * side * minf(0.9, width * 0.7)
	_tube(wall, tip, 0.02, Color("#b9bcbd"), 5)
	var colors: Array[Color] = [Color("#e6e3dc"), Color("#7aa3c8"), Color("#d98c8c"), Color("#f0d68a"), Color("#9cbf8f")]
	var steps := _rng.randi_range(2, 3)
	for i: int in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var hang := wall.lerp(tip, t)
		var piece := 0.22 + _rng.randf() * 0.1
		_cloth(hang - across * side * -piece * 0.5 * 0.0 + Vector3(0, -0.01, 0) - (tip - wall).normalized() * piece * 0.5, (tip - wall).normalized() * piece, _rng.randf_range(0.4, 0.65), colors[_rng.randi_range(0, 4)], 0.16)
	return steps

## The street end of an alley.
func _mouth(mouth: Vector3, inward: Vector3, across: Vector3, width: float, commercial: bool) -> int:
	var count := 0
	var half := width * 0.5
	if commercial and width > 1.9 and _rng.randf() < 0.45:
		# Vending machine set into the mouth, facing the street.
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var at := mouth + inward * 0.42 + across * side * (half - 0.55)
		var body := [Color("#e9e7e1"), Color("#c8312b"), Color("#2c5aa8")][_rng.randi_range(0, 2)] as Color
		_box(at + Vector3.UP * 0.92, across * 0.5, Vector3.UP * 0.92, inward * 0.37, body)
		_glow = 1.0
		_box(at + Vector3.UP * 1.32 - inward * 0.372, across * 0.43, Vector3.UP * 0.42, inward * 0.004, Color("#f4f6f2"))
		var drinks: Array[Color] = [Color("#d23a32"), Color("#2f7fd0"), Color("#f2c230"), Color("#38a35a"), Color("#f2f2f2"), Color("#a05a2a")]
		for row: int in range(3):
			for col: int in range(7):
				_box(at + Vector3.UP * (1.06 + float(row) * 0.26) - inward * 0.378 + across * (float(col) - 3.0) * 0.115, across * 0.035, Vector3.UP * 0.07, inward * 0.004, drinks[(row * 3 + col) % drinks.size()])
		_glow = 0.0
		_box(at + Vector3.UP * 0.32 - inward * 0.372, across * 0.3, Vector3.UP * 0.1, inward * 0.006, Color("#151718"))
		count += 1
	if width > 1.0 and _rng.randf() < 0.6:
		# Bicycles parked in the mouth, leaning on the wall.
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		for i: int in range(_rng.randi_range(1, 3)):
			count += _bicycle(mouth + inward * (0.9 + float(i) * 0.55) + across * side * (half - 0.32), inward, across * side)
	if commercial and _rng.randf() < 0.5:
		# Crates stacked against the wall.
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var at := mouth + inward * _rng.randf_range(2.0, 4.0) + across * side * (half - 0.25)
		var crate := [Color("#d8b42a"), Color("#c03a2e"), Color("#2e5fa5")][_rng.randi_range(0, 2)] as Color
		for level: int in range(_rng.randi_range(2, 4)):
			_box(at + Vector3.UP * (0.17 + float(level) * 0.33), inward * 0.22, Vector3.UP * 0.16, across * 0.17, crate.darkened(0.05 * float(level)))
		count += 1
	if count == 0 and width > 0.8:
		# Every mouth onto a street shows something of the people who use it.
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var wall := mouth + inward * 1.2 + across * side * half
		count += _bin(wall - across * side * 0.3, inward, -across * side) if commercial else _pots(wall - across * side * 0.2, inward, -across * side)
	if commercial and _rng.randf() < 0.55:
		# Nobori flag on the pavement beside the mouth, fluttering.
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var pole := mouth - inward * 1.1 + across * side * (half + 0.45)
		_tube(pole + Vector3.UP * 0.02, pole + Vector3.UP * 2.45, 0.017, Color("#c9c9c3"), 5, 0.0, 0.03)
		_box(pole + Vector3.UP * 0.06, Vector3.RIGHT * 0.16, Vector3.UP * 0.06, Vector3.BACK * 0.16, Color("#3d3f40"))
		var palette: Array = [[Color("#c8282a"), Color("#f2efe6")], [Color("#1f4f9a"), Color("#f2efe6")], [Color("#e2b21e"), Color("#b0201e")], [Color("#2e7d4a"), Color("#f2efe6")]]
		var pair: Array = palette[_rng.randi_range(0, palette.size() - 1)]
		var outward := across * side
		_cloth(pole + Vector3.UP * 2.35, outward * 0.45, 1.75, pair[0], 0.22, 6)
		_cloth(pole + Vector3.UP * 2.33 + outward * 0.04 + inward * 0.002, outward * 0.12, 1.7, pair[1], 0.2, 6)
		count += 1
	return count

func _bicycle(at: Vector3, inward: Vector3, toward_wall: Vector3) -> int:
	# Mamachari standing on its kickstand, its front basket toward the street.
	var frame := [Color("#c9cccd"), Color("#2b2d2e"), Color("#e7e4dc"), Color("#8b2a2a")][_rng.randi_range(0, 3)] as Color
	var lean := toward_wall * 0.06
	var rear := at + inward * 0.55
	var front := at - inward * 0.55
	for wheel: Vector3 in [rear, front]:
		var centre := wheel + Vector3.UP * 0.33
		for i: int in range(12):
			var a0 := TAU * float(i) / 12.0
			var a1 := TAU * float(i + 1) / 12.0
			_tube(centre + (inward * cos(a0) + Vector3.UP * sin(a0)) * 0.33 + lean * sin(a0), centre + (inward * cos(a1) + Vector3.UP * sin(a1)) * 0.33 + lean * sin(a1), 0.018, Color("#1b1c1d"), 4)
	var crank := at + Vector3.UP * 0.3 + inward * 0.05
	var seat := at + Vector3.UP * 0.85 + inward * 0.25 + lean
	var head := at + Vector3.UP * 0.9 - inward * 0.42 + lean
	_tube(rear + Vector3.UP * 0.33, crank, 0.016, frame, 5)
	_tube(rear + Vector3.UP * 0.33, seat, 0.016, frame, 5)
	_tube(crank, seat, 0.02, frame, 5)
	_tube(crank, head + Vector3.DOWN * 0.15, 0.022, frame, 5)
	_tube(head + Vector3.DOWN * 0.2, front + Vector3.UP * 0.33, 0.018, frame, 5)
	_box(seat + Vector3.UP * 0.05, inward * 0.13, Vector3.UP * 0.035, toward_wall * 0.07, Color("#1d1e1f"))
	_tube(head - toward_wall * 0.27, head + toward_wall * 0.27, 0.014, Color("#b9bbbc"), 4)
	# Wire basket over the front wheel.
	_box(head - inward * 0.18 + Vector3.DOWN * 0.12, inward * 0.15, Vector3.UP * 0.12, toward_wall * 0.18, Color("#8d9091"))
	return 1

# ---------------------------------------------------------------- finishing

func _commit() -> void:
	for group: Array in [[_chunks, "AlleyLife", 1, CHUNK, 230.0], [_fixtures, "AlleyLamps", FIXTURE_LAYER, FIXTURE_CHUNK, FIXTURE_RANGE]]:
		var chunks: Dictionary = group[0]
		for key: Vector2i in chunks:
			var st: SurfaceTool = chunks[key]
			var mesh := st.commit()
			if mesh.get_surface_count() == 0: continue
			mesh.surface_set_material(0, _material)
			var instance := MeshInstance3D.new()
			instance.name = "%s_%d_%d" % [group[1], key.x, key.y]
			instance.mesh = mesh
			instance.layers = group[2]
			var size: float = group[3]
			instance.visibility_range_end = group[4]
			instance.custom_aabb = AABB(Vector3(key.x * size - 4.0, -1.0, key.y * size - 4.0), Vector3(size + 8.0, 12.0, size + 8.0))
			add_child(instance)

func _place_lights() -> void:
	# A small pool of real lights follows the camera: the lamps nearest the
	# player light their walls and floors, the rest show only their glow. A
	# gentle falloff and a long reach give the soft pool a real lamp throws.
	for i: int in range(MAX_LIGHTS):
		var light := OmniLight3D.new()
		light.name = "AlleyLampLight%d" % i
		light.omni_attenuation = 1.1
		light.light_cull_mask = 0xFFFFF & ~FIXTURE_LAYER
		light.shadow_enabled = false
		light.light_specular = 0.35
		light.distance_fade_enabled = true
		light.distance_fade_begin = 45.0
		light.distance_fade_length = 15.0
		light.visible = false
		light.add_child(_moths())
		add_child(light)
		_lights.append(light)

## A few moths worrying at the lamp: soft pale specks on a jittery flight that
## keeps falling back toward the light.
func _moths() -> GPUParticles3D:
	var moths := GPUParticles3D.new()
	moths.name = "Moths"
	moths.amount = 5
	moths.lifetime = 2.5
	moths.preprocess = 2.5
	moths.local_coords = true
	moths.visibility_aabb = AABB(Vector3(-0.8, -0.8, -0.8), Vector3(1.6, 1.6, 1.6))
	moths.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flight := ParticleProcessMaterial.new()
	flight.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flight.emission_sphere_radius = 0.2
	flight.direction = Vector3.UP
	flight.spread = 180.0
	flight.gravity = Vector3.ZERO
	flight.initial_velocity_min = 0.1
	flight.initial_velocity_max = 0.3
	flight.radial_accel_min = -1.6
	flight.radial_accel_max = -0.8
	flight.damping_min = 0.3
	flight.damping_max = 0.6
	flight.turbulence_enabled = true
	flight.turbulence_noise_strength = 1.6
	flight.turbulence_noise_scale = 0.6
	flight.turbulence_noise_speed = Vector3(0.6, 0.8, 0.6)
	flight.turbulence_influence_min = 0.3
	flight.turbulence_influence_max = 0.6
	moths.process_material = flight
	var speck := QuadMesh.new()
	speck.size = Vector2(0.022, 0.022)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = soft
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 16
	dot.height = 16
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_texture = dot
	look.albedo_color = Color(0.82, 0.77, 0.66, 0.85)
	speck.material = look
	moths.draw_pass_1 = speck
	return moths

func _process(delta: float) -> void:
	if not installed or not _night or _light_spots.is_empty(): return
	_assign_clock -= delta
	if _assign_clock > 0.0: return
	_assign_clock = 0.25
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var eye := camera.global_position
	var order: Array[Vector2] = []
	for i: int in range(_light_spots.size()):
		var gap: float = eye.distance_squared_to(_light_spots[i].at)
		if gap < 3600.0: order.append(Vector2(gap, i))
	order.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for i: int in range(_lights.size()):
		var light := _lights[i]
		if i >= order.size():
			light.visible = false
			continue
		var spot: Dictionary = _light_spots[int(order[i].y)]
		light.position = spot.at
		light.light_color = spot.color
		light.light_energy = spot.energy
		light.omni_range = spot.range
		light.visible = true

# ------------------------------------------------------------------ lamps

## One alley wall lamp, `out` pointing away from the wall, `along` down the alley.
func _wall_lamp(wall: Vector3, out: Vector3, along: Vector3, commercial: bool) -> void:
	var roll := _lamp_rng.randf()
	if roll < (0.5 if commercial else 0.6):
		_security_lamp(wall, out, along)
	elif commercial and roll < 0.8:
		_enamel_lamp(wall, out, along)
	else:
		_bulkhead_lamp(wall + Vector3.DOWN * 0.45, out, along)

## 防犯灯: the ward's LED crime-prevention light. A slim ivory shell on a bent
## steel arm, a milky lens underneath, a dusk switch on its back, the feed
## cable clipped down the wall and the lamp's number plate screwed on below.
func _security_lamp(wall: Vector3, out: Vector3, along: Vector3) -> void:
	var centre := wall + out * 0.5 + Vector3.UP * 0.12
	var plate := wall + out * 0.006 + Vector3.DOWN * 0.3
	_box(plate, out * 0.004, Vector3.UP * 0.05, along * 0.085, Color("#f2f2ee"))
	_box(plate + out * 0.005 + Vector3.UP * 0.032, out * 0.001, Vector3.UP * 0.011, along * 0.083, Color("#2a5aa8"))
	for digit: int in range(3):
		_box(plate + out * 0.005 + Vector3.DOWN * 0.012 + along * (float(digit) - 1.0) * 0.03, out * 0.001, Vector3.UP * 0.016, along * 0.009, Color("#222426"))
	_light_spots.append({"at":centre + Vector3.DOWN * 0.08, "color":Color(0.86, 0.92, 1.0), "energy":1.25, "range":9.0, "kind":"security", "out":out, "along":along, "fixture":centre})
	var keep := _st
	_use_fixture(wall)
	var steel := Color("#a3a7a6")
	var ivory := Color("#e6e5df")
	var cable := Color("#141516")
	_box(wall + out * 0.01, out * 0.01, Vector3.UP * 0.09, along * 0.05, Color("#8e9290"))
	for bolt: float in [-0.065, 0.065]:
		_tube(wall + out * 0.02 + Vector3.UP * bolt, wall + out * 0.032 + Vector3.UP * bolt, 0.009, Color("#5a5c5a"), 6)
	# Feed cable down from the overhead line, saddle-clipped to the wall.
	var feed := wall + out * 0.008 + along * 0.075
	_tube(feed + Vector3.UP * 1.6, feed + Vector3.UP * 0.05, 0.006, cable, 4)
	_curve([feed + Vector3.UP * 0.05, feed + Vector3.DOWN * 0.02, wall + out * 0.02 + along * 0.05, wall + out * 0.03 + along * 0.02], 0.006, cable, 4)
	for clip: float in [0.4, 0.85, 1.3]:
		_box(feed + Vector3.UP * clip + out * 0.004, out * 0.005, Vector3.UP * 0.01, along * 0.013, Color("#a9aba6"))
	# Steel arm rising off the bracket and bending out level; a collar where it
	# enters the shell.
	var socket := centre - out * 0.2 + Vector3.UP * 0.025
	_curve([wall + out * 0.02, wall + out * 0.05 + Vector3.UP * 0.16, socket - out * 0.2 + Vector3.UP * 0.05, socket], 0.017, steel, 10)
	_tube(socket - out * 0.03, socket + out * 0.03, 0.022, steel.darkened(0.15), 10)
	# Rounded shell, a flat bezel, then the lens: brightest down its middle.
	_dome(centre, Vector3.UP, Vector2(0.2, 0.074), 0.05, ivory, out, 0.0, 4, 14)
	# The bezel catches a little of the lens's spill after dark.
	_glow = 1.05
	_dome(centre, Vector3.DOWN, Vector2(0.2, 0.074), 0.005, ivory.darkened(0.18), out, 0.0, 1, 14)
	_glow = 1.3
	_dome(centre + Vector3.DOWN * 0.005, Vector3.DOWN, Vector2(0.175, 0.056), 0.024, Color("#f1f5ff"), out, 1.35, 4, 14)
	_glow = 0.0
	# Dusk switch (自動点滅器) on the shell's back.
	_lathe(centre - out * 0.115 + Vector3.UP * 0.036, [Vector2(0.019, 0.0), Vector2(0.019, 0.02), Vector2(0.014, 0.028), Vector2(0.0, 0.031)], Color("#55595b"), 10)
	_st = keep

## Green enamel shade (ホーロー) on a swan neck over a shop's back door: white
## enamel inside, glowing warmest round the bulb that just shows below the rim.
func _enamel_lamp(wall: Vector3, out: Vector3, along: Vector3) -> void:
	var mouth := wall + out * 0.5 + Vector3.UP * 0.04
	_light_spots.append({"at":mouth + Vector3.DOWN * 0.06, "color":Color(1.0, 0.78, 0.52), "energy":1.1, "range":8.0, "kind":"enamel", "out":out, "along":along, "fixture":mouth})
	var keep := _st
	_use_fixture(wall)
	var green := Color("#3a7357")
	var rose := wall + Vector3.UP * 0.3
	_tube(rose, rose + out * 0.022, 0.052, green.darkened(0.3), 14)
	_dome(rose + out * 0.022, out, Vector2(0.052, 0.052), 0.012, green.darkened(0.3), Vector3.ZERO, 0.0, 1, 12)
	_curve([rose + out * 0.03, rose + out * 0.24 + Vector3.UP * 0.06, mouth + Vector3.UP * 0.4, mouth + Vector3.UP * 0.205], 0.013, green.darkened(0.12), 12)
	_lathe(mouth + Vector3.UP * 0.148, [Vector2(0.025, 0.0), Vector2(0.025, 0.05), Vector2(0.016, 0.058), Vector2(0.016, 0.062)], Color("#1c1d1e"), 12)
	_lathe(mouth, [Vector2(0.19, -0.01), Vector2(0.186, 0.012), Vector2(0.15, 0.05), Vector2(0.06, 0.12), Vector2(0.028, 0.15)], green, 16)
	_lathe(mouth, [Vector2(0.025, 0.14), Vector2(0.055, 0.112), Vector2(0.14, 0.047), Vector2(0.18, 0.006)], Color("#fbf4e4"), 16, true, [1.6, 1.5, 1.25, 1.1])
	_glow = 2.2
	_bulb(mouth + Vector3.UP * 0.05, 0.042, Color("#ffe2b0"), 0.6)
	_glow = 0.0
	_ring(mouth + Vector3.DOWN * 0.008, 0.188, 0.006, green.darkened(0.15))
	_st = keep

## Caged glass bulkhead over a back door, the cheap warm kind every landlord
## fits: an oval cast base, frosted glass brightest at its crown, two bars and a hoop.
func _bulkhead_lamp(wall: Vector3, out: Vector3, along: Vector3) -> void:
	_light_spots.append({"at":wall + out * 0.3, "color":Color(1.0, 0.8, 0.56), "energy":0.8, "range":6.5, "kind":"bulkhead", "out":out, "along":along, "fixture":wall + out * 0.08})
	var keep := _st
	_use_fixture(wall)
	var iron := Color("#2e3032")
	var glass := Vector2(0.07, 0.1)
	var lip := wall + out * 0.018
	_dome(wall, out, Vector2(0.092, 0.122), 0.028, iron, Vector3.ZERO, 0.0, 2, 12)
	_glow = 1.2
	_dome(lip, out, glass, 0.085, Color("#ffdfb4"), Vector3.ZERO, 0.85)
	_glow = 0.0
	var side := out.cross(Vector3.UP).normalized()
	var up := side.cross(out).normalized()
	for tilt: float in [-0.4, 0.4]:
		var bar := up * cos(tilt) + side * sin(tilt)
		var reach := 1.0 / sqrt(pow(cos(tilt) / glass.y, 2.0) + pow(sin(tilt) / glass.x, 2.0)) + 0.01
		var previous := lip + bar * reach
		for i: int in range(1, 11):
			var a := PI * float(i) / 10.0
			var p := lip + bar * cos(a) * reach + out * sin(a) * 0.095
			_tube(previous, p, 0.006, iron, 4)
			previous = p
	var hoop := lip + out * 0.045
	var squeeze := cos(asin(0.045 / 0.085))
	var last := hoop + side * (glass.x * squeeze + 0.01)
	for i: int in range(1, 17):
		var a := TAU * float(i) / 16.0
		var p := hoop + side * cos(a) * (glass.x * squeeze + 0.01) + up * sin(a) * (glass.y * squeeze + 0.01)
		_tube(last, p, 0.006, iron, 4)
		last = p
	_st = keep

## Smooth bent pipe along a cubic Bézier through four control points.
func _curve(points: Array[Vector3], radius: float, color: Color, steps := 10) -> void:
	var previous := points[0]
	for i: int in range(1, steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		var p := points[0] * u * u * u + points[1] * 3.0 * u * u * t + points[2] * 3.0 * u * t * t + points[3] * t * t * t
		_tube(previous, p, radius, color, 6)
		previous = p

## Turned shape around the vertical; profile is (radius, height). `inside` faces
## it inward; `glows`, one per profile point, shades its glow along the profile.
func _lathe(base: Vector3, profile: Array[Vector2], color: Color, sides: int, inside := false, glows: Array = []) -> void:
	var rest := _glow
	for j: int in range(profile.size() - 1):
		var p0 := profile[j]
		var p1 := profile[j + 1]
		var slope := Vector2(p1.y - p0.y, p0.x - p1.x).normalized() * (-1.0 if inside else 1.0)
		for k: int in range(sides):
			var a0 := TAU * float(k) / float(sides)
			var a1 := TAU * float(k + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (d0 * slope.x + Vector3.UP * slope.y).normalized()
			var n1 := (d1 * slope.x + Vector3.UP * slope.y).normalized()
			var a := base + d0 * p0.x + Vector3.UP * p0.y
			var b := base + d0 * p1.x + Vector3.UP * p1.y
			var c := base + d1 * p1.x + Vector3.UP * p1.y
			var d := base + d1 * p0.x + Vector3.UP * p0.y
			for corner: Array in [[a, n0, j], [b, n0, j + 1], [c, n1, j + 1], [a, n0, j], [c, n1, j + 1], [d, n1, j]]:
				if not glows.is_empty(): _glow = glows[corner[2]]
				_v(corner[0], corner[1], color)
	_glow = rest

## Half an ellipsoid standing out along `axis`: radii across (the first one
## toward `toward` when given) and its depth. `hot` adds glow toward the crown.
func _dome(base: Vector3, axis: Vector3, radii: Vector2, depth: float, color: Color, toward := Vector3.ZERO, hot := 0.0, rings := 4, sides := 12) -> void:
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	if toward != Vector3.ZERO: side = (toward - axis * axis.dot(toward)).normalized()
	var up := side.cross(axis).normalized()
	var rest := _glow
	for r: int in range(rings):
		var t0 := PI * 0.5 * float(r) / float(rings)
		var t1 := PI * 0.5 * float(r + 1) / float(rings)
		for k: int in range(sides):
			var a0 := TAU * float(k) / float(sides)
			var a1 := TAU * float(k + 1) / float(sides)
			var corners: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var crowns: Array[float] = []
			for pair: Vector2 in [Vector2(t0, a0), Vector2(t1, a0), Vector2(t1, a1), Vector2(t0, a1)]:
				var ring := cos(pair.x)
				var radial := side * cos(pair.y) * radii.x + up * sin(pair.y) * radii.y
				corners.append(base + radial * ring + axis * sin(pair.x) * depth)
				normals.append((side * cos(pair.y) * ring / radii.x + up * sin(pair.y) * ring / radii.y + axis * sin(pair.x) / depth).normalized())
				crowns.append(sin(pair.x))
			for index: int in [0, 1, 2, 0, 2, 3]:
				_glow = rest + hot * crowns[index] * crowns[index]
				_v(corners[index], normals[index], color)
	_glow = rest

## Lamp bulb hanging cap-up: `hot` brightens its lowest point.
func _bulb(centre: Vector3, radius: float, color: Color, hot := 0.0) -> void:
	_dome(centre, Vector3.DOWN, Vector2(radius, radius), radius * 1.2, color, Vector3.ZERO, hot, 3, 10)
	_dome(centre, Vector3.UP, Vector2(radius * 0.7, radius * 0.7), radius * 0.6, color, Vector3.ZERO, 0.0, 2, 10)

func _ring(centre: Vector3, radius: float, thick: float, color: Color, axis := Vector3.UP) -> void:
	var side := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.BACK).normalized()
	var up := axis.cross(side).normalized()
	var previous := centre + side * radius
	for i: int in range(1, 19):
		var a := TAU * float(i) / 18.0
		var p := centre + (side * cos(a) + up * sin(a)) * radius
		_tube(previous, p, thick, color, 4)
		previous = p