extends Node3D
## Evacuation cover and signs of recent life across Midori's open lawns, in WORLD
## metres. Direct child of the scene root; never parent it to the 2x park layout.
##
## Cover is seeded on a 36 m hex lattice so a run between pieces stays short.
## Low pieces stop bullets at the hip; tall pieces block sight while moving.
## Geometry is merged into one mesh per 120 m cell, so 80 props cost a handful
## of draw calls. Small litter has no collision and never blocks a route.
const Budget = preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace = preload("res://scripts/startup_trace.gd")

const SPACING := 36.0
const NUDGE_RINGS := 3
const MIN_COVER_GAP := 26.0
const CELL := 120.0
const LIMIT := Vector2(208.0, 168.0)
const SEED := 20261031
## Tall kinds block standing sight lines; they alternate with low kinds.
const TALL_KINDS: Array[String] = ["tarp_screen", "relief_crates", "portable_cabins", "water_tanks"]
const LOW_KINDS: Array[String] = ["jersey_chevron", "sandbag_corner", "draped_barriers", "cable_drums"]
const CAMP_ANCHORS: Array[Vector2] = [Vector2(152, -146), Vector2(-150, -30), Vector2(-60, 122), Vector2(62, 118), Vector2(-172, 132), Vector2(172, 42), Vector2(42, -132)]
const CONCRETE := Color("#8e8d86")
const CONCRETE_DARK := Color("#6f6e68")
const HAZARD_RED := Color("#a23a2c")
const HAZARD_WHITE := Color("#c9c6bb")
const SACK := Color("#8d8064")
const STEEL := Color("#5e6664")
const TIMBER := Color("#a08660")
const PLY := Color("#b89c70")
const TARP_BLUE := Color("#2f5d86")
const TARP_ORANGE := Color("#b9652c")
const TARP_GREEN := Color("#4d6246")
const CABIN_BLUE := Color("#33678f")
const CABIN_GREY := Color("#8d9796")
const TANK_WHITE := Color("#c3c6bf")
const RUST := Color("#6d4630")
const ASH := Color("#3a3634")

const SURFACE_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_p;
varying vec3 world_n;
varying vec3 tint;
float hsh(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float nz(vec3 p){
	vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hsh(i), hsh(i+vec3(1,0,0)), f.x), mix(hsh(i+vec3(0,1,0)), hsh(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hsh(i+vec3(0,0,1)), hsh(i+vec3(1,0,1)), f.x), mix(hsh(i+vec3(0,1,1)), hsh(i+vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = NORMAL;
	tint = pow(COLOR.rgb, vec3(2.2));
}
void fragment() {
	float grain = nz(world_p * 42.0);
	float blotch = nz(world_p * 2.6) * 0.62 + nz(world_p * 7.0) * 0.38;
	// Soft weathering only: damp dirt climbs from the ground.
	float grime = smoothstep(0.75, 0.0, world_p.y + (blotch - 0.5) * 0.5) * 0.5;
	vec3 color = tint * (0.74 + 0.5 * blotch) * (0.92 + 0.14 * grain);
	color = mix(color, vec3(0.1, 0.095, 0.07), grime);
	ALBEDO = color;
	ROUGHNESS = 0.78 + 0.16 * grain;
	SPECULAR = 0.32;
}
"""

var installed := false
var report: Dictionary = {}
var placements: Array[Dictionary] = []
var camps: Array[Vector3] = []
var _batches: Dictionary = {}
var _park: Node3D
var _terrain: Node
var _space: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _material: ShaderMaterial
var _body: StaticBody3D
var _query: PhysicsShapeQueryParameters3D
var _box: BoxShape3D
var _reserved: Array[Vector2] = []
var _trunks: Array[Vector2] = []
var _fires: Array[Dictionary] = []
var _night := false
var _fire_time := 0.0

func _ready() -> void:
	add_to_group("midori_horizon")
	_park = get_parent() as Node3D
	await Budget.wait_structure(_park)
	for producer_name: String in ["MidoriTerrain", "Midori2050Identity", "MidoriSouthStreet", "MidoriAftermath", "MidoriStoneLanterns", "MidoriJapanesePathLamps", "MidoriSecondaryPathLamps"]:
		var producer: Node = _park.get_node_or_null(NodePath(producer_name))
		while producer != null and producer.get("installed") != true:
			await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _build()

func _build() -> void:
	var tick := StartupTrace.begin()
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	_terrain = _park.get_node_or_null("MidoriTerrain")
	_space = get_world_3d().direct_space_state
	_rng.seed = SEED
	_night = bool(_park.get("is_night_mode"))
	_material = ShaderMaterial.new()
	var surface := Shader.new()
	surface.code = SURFACE_SHADER
	_material.shader = surface
	_body = StaticBody3D.new()
	_body.name = "CoverCollision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_box = BoxShape3D.new()
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = _box
	_query.collision_mask = 1
	var player: Node = _park.get_node_or_null("ParkScaleReviewPlayer")
	if player is CollisionObject3D: _query.exclude = [(player as CollisionObject3D).get_rid()]
	for gate: Vector2 in [Vector2(0, 167), Vector2(-205, 40)]: _reserved.append(gate)
	# Young pines have no collision, so the box query alone cannot see them.
	for trunk: Vector2 in _park.occupied_tree_positions: _trunks.append(trunk * float(_park.LAYOUT_SCALE))
	await _place_camps()
	await _place_cover()
	await _place_strewn_items()
	var batch_count := _batches.size()
	_commit()
	installed = true
	set_night_mode(_night)
	report = {"cover":placements.size(), "camps":camps.size(), "fires":_fires.size(), "batches":batch_count, "tall":placements.filter(func(p: Dictionary) -> bool: return p.tall).size()}
	print("MIDORI_PARK_COVER_READY ", JSON.stringify(report))
	StartupTrace.finish("park_cover.build", tick)

# -------------------------------------------------------------- placement

func _ground(point: Vector2) -> float:
	if _terrain != null and _terrain.has_method("height_at"): return float(_terrain.height_at(point))
	return 0.0

func _clear(point: Vector2, half: float, min_gap: float, respect_layout := true) -> bool:
	if absf(point.x) > LIMIT.x or absf(point.y) > LIMIT.y: return false
	if _terrain != null and _terrain.has_method("water_at") and bool(_terrain.water_at(point)): return false
	if respect_layout and not _park._is_vegetation_clear(Vector3(point.x / 2.0, 0, point.y / 2.0), 1.4): return false
	for other: Vector2 in _reserved:
		if other.distance_to(point) < min_gap: return false
	var trunk_gap := half * 1.42 + 0.7
	for trunk: Vector2 in _trunks:
		if trunk.distance_squared_to(point) < trunk_gap * trunk_gap: return false
	var base := _ground(point)
	for offset: Vector2 in [Vector2(half, half), Vector2(-half, half), Vector2(half, -half), Vector2(-half, -half)]:
		if absf(_ground(point + offset) - base) > 0.45: return false
	_box.size = Vector3(half * 2.0, 2.4, half * 2.0)
	_query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, base + 1.65, point.y))
	return _space.intersect_shape(_query, 1).is_empty()

func _find_spot(anchor: Vector2, half: float, min_gap: float, rings: int, respect_layout := true) -> Variant:
	if _clear(anchor, half, min_gap, respect_layout): return anchor
	for ring: int in range(1, rings + 1):
		for step: int in range(8):
			var angle := TAU * (float(step) + 0.5 * float(ring % 2)) / 8.0
			var candidate := anchor + Vector2.RIGHT.rotated(angle) * float(ring) * 4.0
			if _clear(candidate, half, min_gap, respect_layout): return candidate
	return null

func _place_cover() -> void:
	var row_step := SPACING * 0.866
	var rows := int(LIMIT.y * 2.0 / row_step) + 1
	var cols := int(LIMIT.x * 2.0 / SPACING) + 1
	var low_index := 0
	var tall_index := 0
	for row: int in range(rows):
		await Budget.checkpoint(_park)
		for col: int in range(cols):
			var anchor := Vector2(-LIMIT.x + (float(col) + (0.5 if row % 2 == 1 else 0.0)) * SPACING, -LIMIT.y + float(row) * row_step)
			anchor += Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
			var spot: Variant = _find_spot(anchor, 2.6, MIN_COVER_GAP, NUDGE_RINGS)
			if spot == null: continue
			var tall := (row + col) % 2 == 0
			var kind: String
			if tall:
				kind = TALL_KINDS[tall_index % TALL_KINDS.size()]
				tall_index += 1
			else:
				kind = LOW_KINDS[low_index % LOW_KINDS.size()]
				low_index += 1
			var point: Vector2 = spot
			var yaw := _rng.randf_range(0.0, TAU)
			var origin := Transform3D(Basis(Vector3.UP, yaw), Vector3(point.x, _ground(point) - 0.02, point.y))
			_reserved.append(point)
			placements.append({"kind":kind, "position":origin.origin, "tall":tall})
			call("_kind_" + kind, origin)

func _place_camps() -> void:
	for index: int in range(CAMP_ANCHORS.size()):
		await Budget.checkpoint(_park)
		var spot: Variant = _find_spot(CAMP_ANCHORS[index], 3.8, 12.0, 10, index != 0)
		if spot == null: continue
		var point: Vector2 = spot
		var origin := Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), Vector3(point.x, _ground(point), point.y))
		_reserved.append(point)
		camps.append(origin.origin)
		_camp(origin, index)

func _place_strewn_items() -> void:
	# Dropped in a hurry: small items along the route shoulders, no collision.
	var routes: Array = [_park.OUTER_CIRCUIT, _park.SOUTH_ARRIVAL_ROUTE, _park.WEST_DESTINATION_ROUTE, _park.NORTH_ENTRY_ROUTE, _park.EAST_DECK_ROUTE]
	var kinds: Array[String] = ["_item_duffel", "_item_bike", "_item_tipped_bin", "_item_suitcase", "_item_clothes", "_item_bike"]
	var made := 0
	for route: Array in routes:
		await Budget.checkpoint(_park)
		var points: Array = route
		for index: int in range(1, points.size() - 1, 2):
			var a: Vector2 = Vector2(points[index]) * 2.0
			var b: Vector2 = Vector2(points[index + 1]) * 2.0
			var along := (b - a).normalized()
			var side := Vector2(-along.y, along.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var at := a.lerp(b, _rng.randf_range(0.25, 0.75)) + side * _rng.randf_range(3.4, 5.0)
			if absf(at.x) > LIMIT.x or absf(at.y) > LIMIT.y: continue
			if _terrain != null and bool(_terrain.water_at(at)): continue
			var origin := Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), Vector3(at.x, _ground(at), at.y))
			call(kinds[made % kinds.size()], origin)
			made += 1
	report["strewn"] = made

# ---------------------------------------------------------- mesh batching

func _batch(point: Vector3) -> SurfaceTool:
	var key := Vector2i(int(floor(point.x / CELL)), int(floor(point.z / CELL)))
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		_batches[key] = st
	return _batches[key]

func _commit() -> void:
	for key: Vector2i in _batches:
		var st: SurfaceTool = _batches[key]
		st.generate_normals()
		# Flat normals are set; indexing then merges only vertices identical in
		# position, normal and colour (the two triangles of each quad share two),
		# so the same triangles draw from fewer vertex bytes.
		st.index()
		var mesh := st.commit()
		# The mesh owns the geometry now; drop the SurfaceTool's copy.
		st.clear()
		mesh.surface_set_material(0, _material)
		var instance := MeshInstance3D.new()
		instance.name = "CoverBatch_%d_%d" % [key.x, key.y]
		instance.mesh = mesh
		instance.visibility_range_end = 240.0
		add_child(instance)
	_batches.clear()

func _tri(st: SurfaceTool, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(xf * a)
	st.add_vertex(xf * b)
	st.add_vertex(xf * c)

func _quad(st: SurfaceTool, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, xf, a, b, c, color)
	_tri(st, xf, a, c, d, color)

## Extrudes a counter-clockwise convex XY profile along Z, centred on the origin.
func _prism(xf: Transform3D, profile: PackedVector2Array, length: float, color: Color) -> void:
	var st := _batch(xf.origin)
	var half := length * 0.5
	var count := profile.size()
	# Shade from the part's position, not the placement RNG, so adding detail to a
	# prop never moves where later cover lands.
	var h := absi(hash(Vector3i(xf.origin * 100.0))) % 1000 / 1000.0
	var shade := color.lightened(h * 0.1 - 0.05) if h < 0.5 else color.darkened((h - 0.5) * 0.16)
	for i: int in range(count):
		var p := profile[i]
		var q := profile[(i + 1) % count]
		_quad(st, xf, Vector3(p.x, p.y, half), Vector3(q.x, q.y, half), Vector3(q.x, q.y, -half), Vector3(p.x, p.y, -half), shade)
	for i: int in range(1, count - 1):
		var a := profile[0]
		var b := profile[i]
		var c := profile[i + 1]
		_tri(st, xf, Vector3(a.x, a.y, half), Vector3(c.x, c.y, half), Vector3(b.x, b.y, half), shade)
		_tri(st, xf, Vector3(a.x, a.y, -half), Vector3(b.x, b.y, -half), Vector3(c.x, c.y, -half), shade)

func _block(xf: Transform3D, size: Vector3, at: Vector3, color: Color, tilt := Vector3.ZERO) -> void:
	var local := Transform3D(Basis.from_euler(tilt), at)
	var h := Vector2(size.x, size.y) * 0.5
	_prism(xf * local, PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]), size.z, color)

func _cylinder(xf: Transform3D, radius: float, length: float, at: Vector3, color: Color, sides := 12, tilt := Vector3.ZERO) -> void:
	var profile := PackedVector2Array()
	for i: int in range(sides):
		var angle := TAU * float(i) / float(sides)
		profile.append(Vector2(cos(angle), sin(angle)) * radius)
	_prism(xf * Transform3D(Basis.from_euler(tilt), at), profile, length, color)

func _bar(xf: Transform3D, a: Vector3, b: Vector3, thick: float, color: Color) -> void:
	var span := b - a
	var forward := span.normalized()
	var side := forward.cross(Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(forward).normalized()
	var local := Transform3D(Basis(side, up, forward), (a + b) * 0.5)
	var h := thick * 0.5
	_prism(xf * local, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]), span.length(), color)

func _solid(xf: Transform3D, size: Vector3, at: Vector3, yaw := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xf * Transform3D(Basis(Vector3.UP, yaw), at + Vector3.UP * (size.y * 0.5))
	_body.add_child(shape)

# ----------------------------------------------------------- low cover

func _jersey(xf: Transform3D, at: Vector3, yaw: float, stripe: Color) -> void:
	var local := xf * Transform3D(Basis(Vector3.UP, yaw), at)
	var profile := PackedVector2Array([Vector2(-0.31, 0), Vector2(0.31, 0), Vector2(0.31, 0.08), Vector2(0.11, 0.3), Vector2(0.075, 0.86), Vector2(-0.075, 0.86), Vector2(-0.11, 0.3), Vector2(-0.31, 0.08)])
	# Profile is across the barrier, so the prism runs along local Z.
	_prism(local, profile, 2.6, CONCRETE)
	_block(local, Vector3(0.16, 0.14, 0.62), Vector3(0, 0.80, 0.95), stripe)
	_block(local, Vector3(0.16, 0.14, 0.62), Vector3(0, 0.80, -0.95), stripe)
	_solid(local, Vector3(0.52, 0.86, 2.6), Vector3.ZERO)

func _kind_jersey_chevron(xf: Transform3D) -> void:
	_jersey(xf, Vector3(-1.3, 0, 0.6), 0.5, HAZARD_RED)
	_jersey(xf, Vector3(1.3, 0, 0.6), -0.5, HAZARD_WHITE)
	_jersey(xf, Vector3(0, 0, -1.5), PI * 0.5, HAZARD_RED)

func _sandbag_row(xf: Transform3D, a: Vector3, b: Vector3, rows: int) -> void:
	var span := Vector2(b.x - a.x, b.z - a.z)
	var yaw := -atan2(span.y, span.x)
	var count := int(span.length() / 0.58)
	var profile := PackedVector2Array([Vector2(-0.29, -0.05), Vector2(-0.22, -0.09), Vector2(0.22, -0.09), Vector2(0.29, -0.05), Vector2(0.29, 0.05), Vector2(0.22, 0.09), Vector2(-0.22, 0.09), Vector2(-0.29, 0.05)])
	for row: int in range(rows):
		var offset := 0.29 if row % 2 == 1 else 0.0
		for i: int in range(count - (row % 2)):
			var t := (float(i) + 0.5) * 0.58 + offset
			var flat := Vector2(a.x, a.z) + span.normalized() * t
			var at := Vector3(flat.x, 0.09 + float(row) * 0.165, flat.y)
			var wobble := Basis(Vector3.UP, yaw + _rng.randf_range(-0.09, 0.09))
			_prism(xf * Transform3D(wobble, at), profile, 0.36, SACK)
	_solid(xf, Vector3(span.length(), float(rows) * 0.165 + 0.02, 0.42), (a + b) * 0.5, yaw)

func _kind_sandbag_corner(xf: Transform3D) -> void:
	_sandbag_row(xf, Vector3(-1.9, 0, -1.2), Vector3(1.9, 0, -1.2), 6)
	_sandbag_row(xf, Vector3(1.9, 0, -0.9), Vector3(1.9, 0, 1.4), 6)

func _kind_draped_barriers(xf: Transform3D) -> void:
	for index: int in range(3):
		var at := Vector3(-2.4 + float(index) * 2.4, 0, 0.3 * float(index % 2))
		var yaw := _rng.randf_range(-0.14, 0.14)
		var local := xf * Transform3D(Basis(Vector3.UP, yaw), at)
		for x: float in [-1.15, 1.15]:
			_bar(local, Vector3(x, 0.02, 0), Vector3(x, 1.12, 0), 0.05, STEEL)
			_bar(local, Vector3(x, 0.03, -0.3), Vector3(x, 0.03, 0.3), 0.05, STEEL)
		_bar(local, Vector3(-1.15, 1.12, 0), Vector3(1.15, 1.12, 0), 0.05, STEEL)
		_bar(local, Vector3(-1.15, 0.2, 0), Vector3(1.15, 0.2, 0), 0.04, STEEL)
		# Tarp tied over the rails turns see-through steel into real concealment:
		# it sags between the ties, folds over the top rail and ripples below.
		var tarp := TARP_ORANGE if index == 1 else TARP_BLUE
		var st := _batch(local.origin)
		# One smooth sheet: a single soft sag and billow, no repeating folds.
		_sheet(st, local, Vector2(-1.12, 1.12), 1.12, 0.2, 0.05, 0.06, 0.05, tarp)
		var columns := 8
		for i: int in range(columns):
			var u0 := float(i) / float(columns)
			var u1 := float(i + 1) / float(columns)
			var x0 := lerpf(-1.12, 1.12, u0)
			var x1 := lerpf(-1.12, 1.12, u1)
			# Lip folded over the top rail.
			_quad(st, local, Vector3(x0, 1.15 - sin(u0 * PI) * 0.02, -0.03), Vector3(x1, 1.15 - sin(u1 * PI) * 0.02, -0.03), Vector3(x1, 1.12 - sin(u1 * PI) * 0.06, 0.05), Vector3(x0, 1.12 - sin(u0 * PI) * 0.06, 0.05), tarp)
		# Cord ties at the corners and the middle.
		for x: float in [-1.1, 0.0, 1.1]:
			_block(local, Vector3(0.03, 0.08, 0.03), Vector3(x, 1.08, 0.07), Color("#d8d2b8"))
			_block(local, Vector3(0.03, 0.06, 0.03), Vector3(x, 0.24, 0.07), Color("#d8d2b8"))
		_solid(local, Vector3(2.3, 1.15, 0.12), Vector3.ZERO)

func _kind_cable_drums(xf: Transform3D) -> void:
	_cable_drum(xf, Vector3(-1.1, 0, 0.1), 0.2)
	_cable_drum(xf, Vector3(0.75, 0, -0.7), -0.5)
	_generator(xf * Transform3D(Basis(Vector3.UP, 0.08), Vector3(0.9, 0, 1.1)))
	_solid(xf, Vector3(1.6, 1.05, 0.9), Vector3(0.9, 0, 1.1))

## Smooth hanging sheet across x0..x1 from `top` down to `bottom` at depth z:
## it sags in the middle of its top edge and billows out once, gently.
func _sheet(st: SurfaceTool, xf: Transform3D, span: Vector2, top: float, bottom: float, z: float, sag: float, billow: float, color: Color) -> void:
	var columns := 8
	var rows := 4
	for i: int in range(columns):
		for j: int in range(rows):
			var corners: Array[Vector3] = []
			for c: Vector2 in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var u := c.x / float(columns)
				var v := c.y / float(rows)
				var y := lerpf(top - sin(u * PI) * sag, bottom, v)
				corners.append(Vector3(lerpf(span.x, span.y, u), y, z + sin(u * PI) * sin(v * PI) * billow))
			_quad(st, xf, corners[0], corners[1], corners[2], corners[3], color)
			_quad(st, xf, corners[1], corners[0], corners[3], corners[2], color.darkened(0.15))

## Wooden cable drum on its rim: plank flanges, bolts and a
## steel hub, the cable wound almost to the rim and a loose tail on the grass.
func _cable_drum(xf: Transform3D, at: Vector3, yaw: float) -> void:
	var local := xf * Transform3D(Basis(Vector3.UP, yaw), at + Vector3.UP * 0.72)
	var cable := Color("#1c1e1d")
	for side: float in [-1.0, 1.0]:
		var face := side * 0.495
		_cylinder(local, 0.72, 0.05, Vector3(0, 0, side * 0.47), TIMBER, 28)
		# Two battens hold the flange planks together.
		for x: float in [-0.3, 0.3]:
			_block(local, Vector3(0.09, 2.0 * sqrt(0.72 * 0.72 - x * x) - 0.08, 0.025), Vector3(x, 0, face + side * 0.012), TIMBER.darkened(0.12))
		_cylinder(local, 0.15, 0.02, Vector3(0, 0, face + side * 0.012), STEEL, 16)
		_cylinder(local, 0.055, 0.024, Vector3(0, 0, face + side * 0.014), ASH, 12)
		for k: int in range(6):
			var a := TAU * float(k) / 6.0
			_block(local, Vector3(0.03, 0.03, 0.02), Vector3(cos(a) * 0.11, sin(a) * 0.11, face + side * 0.024), STEEL.darkened(0.3))
		# Faded maker's stencil.
		_block(local, Vector3(0.34, 0.1, 0.004), Vector3(0, -0.3, face + side * 0.004), Color("#cfc8b4").darkened(0.15))
	# Wound cable: a core and ribs where each layer of turns stands proud.
	_cylinder(local, 0.6, 0.89, Vector3.ZERO, cable, 24)
	for k: int in range(8):
		_cylinder(local, 0.612 + 0.006 * float(k % 2), 0.075, Vector3(0, 0, -0.39 + float(k) * 0.111), cable.lightened(0.04), 24)
	# The free end drops off the top of the wraps and trails on the ground.
	var tail: Array[Vector3] = [Vector3(0.2, 0.6, 0.3), Vector3(0.55, 0.45, 0.32), Vector3(0.78, 0.0, 0.36), Vector3(0.85, -0.66, 0.42), Vector3(1.3, -0.69, 0.6), Vector3(1.75, -0.69, 0.5)]
	for i: int in range(tail.size() - 1):
		_bar(local, tail[i], tail[i + 1], 0.045, cable)
	_solid(local, Vector3(1.24, 1.44, 0.98), Vector3(0, -0.72, 0))

## Soundproofed site generator, the blue-grey box every Japanese works yard has:
## skids, louvres, a door, a control panel, exhaust stub and a lifting eye.
func _generator(xf: Transform3D) -> void:
	var body := Color("#7d939c")
	var dark := body.darkened(0.45)
	for z: float in [-0.32, 0.32]:
		_block(xf, Vector3(1.62, 0.09, 0.09), Vector3(0, 0.045, z), STEEL)
	_block(xf, Vector3(1.56, 0.05, 0.8), Vector3(0, 0.115, 0), STEEL.darkened(0.1))
	_block(xf, Vector3(1.5, 0.82, 0.76), Vector3(0, 0.55, 0), body)
	_block(xf, Vector3(1.54, 0.05, 0.8), Vector3(0, 0.985, 0), body.darkened(0.08))
	for side: float in [-1.0, 1.0]:
		var face := side * 0.385
		# Recessed intake and outlet grilles, and the service door latch.
		_block(xf, Vector3(0.42, 0.46, 0.02), Vector3(-0.47, 0.52, face), dark)
		_block(xf, Vector3(0.3, 0.3, 0.02), Vector3(0.55, 0.62, face), dark)
		_block(xf, Vector3(0.04, 0.09, 0.03), Vector3(0.24, 0.6, face + side * 0.01), STEEL.darkened(0.2))
	# Control panel behind a small window on the end.
	_block(xf, Vector3(0.012, 0.3, 0.42), Vector3(0.755, 0.68, 0), dark)
	_block(xf, Vector3(0.008, 0.12, 0.2), Vector3(0.762, 0.74, 0.06), Color("#3a4a50").lightened(0.2))
	for z: float in [-0.12, -0.04]:
		_block(xf, Vector3(0.03, 0.035, 0.035), Vector3(0.77, 0.6, z), ASH)
	# Maker's band and rating plate.
	_block(xf, Vector3(0.9, 0.06, 0.004), Vector3(0.05, 0.86, 0.388), Color("#d9d6cc"))
	_block(xf, Vector3(0.16, 0.1, 0.004), Vector3(-0.05, 0.42, 0.388), Color("#b9b6aa"))
	# Exhaust stub, fuel cap and the lifting eye on the roof.
	_cylinder(xf, 0.045, 0.14, Vector3(-0.55, 1.07, 0.18), RUST, 10, Vector3(PI * 0.5, 0, 0))
	_cylinder(xf, 0.05, 0.03, Vector3(0.45, 1.02, -0.2), ASH, 10, Vector3(PI * 0.5, 0, 0))
	_bar(xf, Vector3(-0.08, 1.0, 0), Vector3(-0.08, 1.12, 0), 0.025, STEEL)
	_bar(xf, Vector3(0.08, 1.0, 0), Vector3(0.08, 1.12, 0), 0.025, STEEL)
	_bar(xf, Vector3(-0.09, 1.12, 0), Vector3(0.09, 1.12, 0), 0.025, STEEL)

# ---------------------------------------------------------- tall cover

func _kind_tarp_screen(xf: Transform3D) -> void:
	# Windbreak of scaffold tube and tarp: stops eyes more than bullets.
	var colors: Array[Color] = [TARP_GREEN, TARP_BLUE, TARP_ORANGE]
	var color: Color = colors[_rng.randi_range(0, 2)]
	var length := 5.6
	for x: float in [-length * 0.5, 0.0, length * 0.5]:
		_bar(xf, Vector3(x, 0, 0), Vector3(x, 2.45, 0), 0.06, STEEL)
		_bar(xf, Vector3(x, 1.6, 0), Vector3(x, 0, 1.1), 0.05, STEEL)
		_block(xf, Vector3(0.6, 0.18, 0.36), Vector3(x, 0.09, 1.1), SACK)
	_bar(xf, Vector3(-length * 0.5, 2.4, 0), Vector3(length * 0.5, 2.4, 0), 0.05, STEEL)
	# Two smooth panels, one each side of the middle pole.
	var st := _batch(xf.origin)
	_sheet(st, xf, Vector2(-length * 0.5, 0.0), 2.36, 0.16, 0.02, 0.05, 0.08, color)
	_sheet(st, xf, Vector2(0.0, length * 0.5), 2.36, 0.16, 0.02, 0.05, 0.08, color)
	_solid(xf, Vector3(length, 2.45, 0.14), Vector3.ZERO)

func _crate(xf: Transform3D, size: Vector3, at: Vector3, yaw: float) -> void:
	var tilt := Vector3(0, yaw, 0)
	_block(xf, size, at + Vector3.UP * (size.y * 0.5), PLY, tilt)
	var rib := Vector3(size.x + 0.03, 0.07, size.z + 0.03)
	_block(xf, rib, at + Vector3.UP * (size.y - 0.04), TIMBER, tilt)
	_block(xf, rib, at + Vector3.UP * 0.04, TIMBER, tilt)
	# Corner battens and a diagonal brace, so it reads as a crate at a glance.
	var turn := Basis(Vector3.UP, yaw)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := turn * Vector3(corner.x * (size.x * 0.5 - 0.02), 0, corner.y * (size.z * 0.5 - 0.02))
		_block(xf, Vector3(0.09, size.y, 0.09), at + c + Vector3.UP * (size.y * 0.5), TIMBER, tilt)
	var face := turn * Vector3(0, 0, size.z * 0.5 + 0.012)
	var low := turn * Vector3(-size.x * 0.42, 0, 0)
	_bar(xf, at + face + low + Vector3.UP * 0.1, at + face - low + Vector3.UP * (size.y - 0.1), 0.06, TIMBER)
	_solid(xf, size, at, yaw)

func _pallet(xf: Transform3D, at: Vector3, yaw: float) -> void:
	_block(xf, Vector3(1.2, 0.12, 1.0), at + Vector3.UP * 0.06, TIMBER, Vector3(0, yaw, 0))

func _kind_relief_crates(xf: Transform3D) -> void:
	_pallet(xf, Vector3(-0.8, 0, 0), 0.0)
	_pallet(xf, Vector3(0.65, 0, -0.1), 0.1)
	_crate(xf, Vector3(1.1, 1.0, 0.95), Vector3(-0.8, 0.12, 0), 0.04)
	_crate(xf, Vector3(1.05, 0.95, 0.95), Vector3(-0.75, 1.12, 0.02), -0.12)
	_crate(xf, Vector3(1.1, 1.1, 0.95), Vector3(0.65, 0.12, -0.1), 0.1)
	_crate(xf, Vector3(0.9, 0.7, 0.8), Vector3(1.2, 0, 1.25), 0.7)
	# Relief stencil block on the tallest stack.
	_block(xf, Vector3(0.5, 0.5, 0.02), Vector3(-0.8, 0.65, 0.49), HAZARD_RED)

## Site toilet cabin (仮設トイレ): moulded ribbed walls, a pale translucent
## roof dome, the door in its frame with an engaged/vacant latch, a vent stack,
## a wall louvre and the base it stands on.
func _cabin(xf: Transform3D, at: Vector3, yaw: float, color: Color) -> void:
	var local := xf * Transform3D(Basis(Vector3.UP, yaw), at)
	var white := Color("#d9dad4")
	_block(local, Vector3(1.24, 0.12, 1.24), Vector3(0, 0.06, 0), CONCRETE_DARK)
	_block(local, Vector3(1.12, 2.1, 1.12), Vector3(0, 1.17, 0), color)
	# Roof: a translucent white dome over a lip, so daylight reaches inside.
	_block(local, Vector3(1.2, 0.06, 1.2), Vector3(0, 2.25, 0), white)
	var arch := PackedVector2Array()
	for i: int in range(9):
		var a := PI * float(i) / 8.0
		arch.append(Vector2(cos(a) * 0.58, 2.28 + sin(a) * 0.16))
	_prism(local, arch, 1.16, white.lightened(0.05))
	# Door: frame, panel, pull handle and the red/green indicator above it.
	_block(local, Vector3(0.9, 1.98, 0.04), Vector3(0, 1.11, 0.575), white.darkened(0.1))
	_block(local, Vector3(0.78, 1.86, 0.03), Vector3(0, 1.1, 0.595), color.lightened(0.08))
	_block(local, Vector3(0.04, 0.2, 0.05), Vector3(0.28, 1.05, 0.625), STEEL)
	_block(local, Vector3(0.12, 0.05, 0.02), Vector3(0.28, 1.28, 0.615), Color("#2f8a4a") if hash(at) % 2 == 0 else Color("#b8322a"))
	_block(local, Vector3(0.18, 0.18, 0.01), Vector3(0, 1.62, 0.615), white)
	# Wall louvre and the vent stack through the roof.
	for i: int in range(4):
		_block(local, Vector3(0.012, 0.025, 0.3), Vector3(0.567, 1.85 + float(i) * 0.06, 0), color.darkened(0.4))
	_cylinder(local, 0.045, 0.5, Vector3(-0.42, 2.45, -0.42), Color("#4a4c4b"), 10, Vector3(PI * 0.5, 0, 0))
	_solid(local, Vector3(1.26, 2.3, 1.26), Vector3.ZERO)

func _kind_portable_cabins(xf: Transform3D) -> void:
	_cabin(xf, Vector3(-1.32, 0, 0), 0.0, CABIN_BLUE)
	_cabin(xf, Vector3(0, 0, 0), 0.0, CABIN_GREY)
	_cabin(xf, Vector3(1.4, 0, 0.1), -0.08, CABIN_BLUE)

## IBC water tote: milky tank showing its water line through the plastic, in
## a galvanised grid cage on a black plastic pallet, filler cap and outlet valve.
func _tank(xf: Transform3D, at: Vector3) -> void:
	var cage := Color("#8f9594")
	_block(xf, Vector3(1.2, 0.14, 1.0), at + Vector3.UP * 0.07, Color("#262827"))
	_block(xf, Vector3(1.08, 0.96, 0.9), at + Vector3.UP * 0.62, TANK_WHITE)
	# Water seen through the walls: darker below a line two-thirds up.
	_block(xf, Vector3(1.086, 0.6, 0.906), at + Vector3.UP * 0.45, TANK_WHITE.darkened(0.16))
	for x: float in [-0.58, -0.29, 0.0, 0.29, 0.58]:
		for z: float in [-0.48, 0.48]:
			_bar(xf, at + Vector3(x, 0.14, z), at + Vector3(x, 1.14, z), 0.022 if absf(x) < 0.5 else 0.03, cage)
	for z: float in [-0.24, 0.0, 0.24]:
		for x: float in [-0.58, 0.58]:
			_bar(xf, at + Vector3(x, 0.14, z), at + Vector3(x, 1.14, z), 0.022, cage)
	for y: float in [0.14, 0.47, 0.8, 1.14]:
		_bar(xf, at + Vector3(-0.58, y, 0.48), at + Vector3(0.58, y, 0.48), 0.022, cage)
		_bar(xf, at + Vector3(-0.58, y, -0.48), at + Vector3(0.58, y, -0.48), 0.022, cage)
		_bar(xf, at + Vector3(0.58, y, -0.48), at + Vector3(0.58, y, 0.48), 0.022, cage)
		_bar(xf, at + Vector3(-0.58, y, -0.48), at + Vector3(-0.58, y, 0.48), 0.022, cage)
	_cylinder(xf, 0.11, 0.04, at + Vector3(0, 1.12, 0), Color("#d6d0bc"), 12, Vector3(PI * 0.5, 0, 0))
	_cylinder(xf, 0.05, 0.12, at + Vector3(0, 0.22, 0.5), Color("#3c3e3d"), 10)
	_block(xf, Vector3(0.14, 0.03, 0.03), at + Vector3(0, 0.26, 0.56), Color("#c8a22a"))

func _kind_water_tanks(xf: Transform3D) -> void:
	for at: Vector3 in [Vector3(-0.7, 0, 0), Vector3(0.7, 0, 0), Vector3(-0.7, 1.16, 0)]:
		_tank(xf, at)
	_solid(xf, Vector3(2.6, 1.16, 1.04), Vector3.ZERO)
	_solid(xf, Vector3(1.24, 1.16, 1.04), Vector3(-0.7, 1.16, 0))

# -------------------------------------------------------------- recent life

func _camp(xf: Transform3D, index: int) -> void:
	var colors: Array[Color] = [TARP_ORANGE, TARP_GREEN, TARP_BLUE, Color("#8c3b3b")]
	_tent(xf * Transform3D(Basis(Vector3.UP, 0.4), Vector3(-2.2, 0, -1.6)), colors[index % 4], true)
	_tent(xf * Transform3D(Basis(Vector3.UP, -0.7), Vector3(2.3, 0, -1.2)), colors[(index + 1) % 4], false)
	_sleeping_bag(xf * Transform3D(Basis(Vector3.UP, 1.2), Vector3(-0.5, 0, 2.2)), colors[(index + 2) % 4])
	_item_duffel(xf * Transform3D(Basis(Vector3.UP, 0.3), Vector3(1.2, 0, 2.0)))
	_item_clothes(xf * Transform3D(Basis(Vector3.UP, 2.1), Vector3(-2.4, 0, 1.4)))
	_item_suitcase(xf * Transform3D(Basis(Vector3.UP, -1.1), Vector3(2.7, 0, 1.3)))
	_cooler(xf * Transform3D(Basis(Vector3.UP, 0.8), Vector3(0.9, 0, -2.0)))
	_burn_barrel(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)))

func _tent(xf: Transform3D, color: Color, flap_open: bool) -> void:
	var st := _batch(xf.origin)
	var half_l := 1.15
	var half_w := 0.85
	var ridge := 1.1
	var nw := Vector3(-half_w, 0, -half_l)
	var ne := Vector3(half_w, 0, -half_l)
	var sw := Vector3(-half_w, 0, half_l)
	var se := Vector3(half_w, 0, half_l)
	var top_n := Vector3(0, ridge, -half_l)
	var top_s := Vector3(0, ridge, half_l)
	_quad(st, xf, top_s, top_n, ne, se, color)
	_quad(st, xf, top_n, top_s, sw, nw, color.darkened(0.12))
	_tri(st, xf, top_n, nw, ne, color.darkened(0.2))
	_tri(st, xf, top_n, ne, nw, color.darkened(0.3))
	if flap_open:
		_tri(st, xf, top_s, se, Vector3(0.1, 0, half_l), color.darkened(0.08))
		_tri(st, xf, top_s, Vector3(-0.1, 0, half_l), sw, color.darkened(0.08))
		_tri(st, xf, Vector3(0, ridge - 0.1, half_l - 0.3), Vector3(0.6, 0.01, half_l - 0.4), Vector3(-0.6, 0.01, half_l - 0.4), Color("#1b1c1d"))
		_block(xf, Vector3(1.5, 0.02, 2.2), Vector3(0, 0.012, 0), Color("#24262a"))
	else:
		_tri(st, xf, top_s, se, sw, color.darkened(0.08))
	_solid(xf, Vector3(1.5, 1.05, 2.3), Vector3.ZERO)

func _sleeping_bag(xf: Transform3D, color: Color) -> void:
	var profile := PackedVector2Array([Vector2(-0.38, 0.0), Vector2(0.38, 0.0), Vector2(0.34, 0.1), Vector2(0.18, 0.16), Vector2(-0.18, 0.16), Vector2(-0.34, 0.1)])
	_prism(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), profile, 1.8, color)
	_block(xf, Vector3(0.62, 0.1, 0.36), Vector3(0, 0.07, 0.72), color.lightened(0.3), Vector3(0.12, 0, 0))

func _cooler(xf: Transform3D) -> void:
	_block(xf, Vector3(0.62, 0.34, 0.38), Vector3(0, 0.17, 0), TARP_BLUE)
	_block(xf, Vector3(0.65, 0.07, 0.41), Vector3(0, 0.37, 0), HAZARD_WHITE)

func _item_duffel(xf: Transform3D) -> void:
	_cylinder(xf, 0.17, 0.72, Vector3(0, 0.16, 0), Color("#39473a"), 10)
	_bar(xf, Vector3(-0.1, 0.32, -0.2), Vector3(0.1, 0.36, 0.2), 0.03, Color("#23262a"))

func _item_suitcase(xf: Transform3D) -> void:
	# Burst open on its side, with the lid thrown back.
	_block(xf, Vector3(0.62, 0.1, 0.44), Vector3(0, 0.05, 0), Color("#7a3d33"))
	_block(xf, Vector3(0.62, 0.05, 0.44), Vector3(0, 0.22, -0.28), Color("#7a3d33"), Vector3(-1.1, 0, 0))
	_block(xf, Vector3(0.56, 0.06, 0.38), Vector3(0, 0.1, 0), Color("#a79f8e"), Vector3(0, 0.1, 0))

func _item_clothes(xf: Transform3D) -> void:
	var colors: Array[Color] = [Color("#556a7a"), Color("#a67f4d"), Color("#7a4d58"), Color("#d4d0c6")]
	for i: int in range(4):
		var at := Vector3(_rng.randf_range(-0.5, 0.5), 0.015 + float(i) * 0.008, _rng.randf_range(-0.5, 0.5))
		_block(xf, Vector3(_rng.randf_range(0.34, 0.6), 0.012, _rng.randf_range(0.24, 0.5)), at, colors[i], Vector3(0, _rng.randf_range(0, TAU), 0))

func _item_tipped_bin(xf: Transform3D) -> void:
	_cylinder(xf, 0.28, 0.8, Vector3(0, 0.28, 0), Color("#3c4a45"), 12)
	_cylinder(xf, 0.2, 0.02, Vector3(0, 0.28, 0.41), Color("#101312"), 12)
	var litter: Array[Color] = [HAZARD_WHITE, Color("#b7a98b"), Color("#6f8088"), TARP_ORANGE]
	for i: int in range(9):
		var at := Vector3(_rng.randf_range(-0.7, 0.7), 0.012, _rng.randf_range(0.5, 1.9))
		_block(xf, Vector3(_rng.randf_range(0.06, 0.2), 0.01, _rng.randf_range(0.06, 0.2)), at, litter[i % 4], Vector3(0, _rng.randf_range(0, TAU), 0))

func _wheel(xf: Transform3D, at: Vector3, color: Color) -> void:
	var count := 14
	var radius := 0.33
	for i: int in range(count):
		var a0 := TAU * float(i) / float(count)
		var a1 := TAU * float(i + 1) / float(count)
		_bar(xf, at + Vector3(cos(a0) * radius, 0, sin(a0) * radius), at + Vector3(cos(a1) * radius, 0, sin(a1) * radius), 0.035, color)

func _item_bike(xf: Transform3D) -> void:
	# A bicycle dropped flat on the grass: the frame plane lies on the ground.
	var frame := Color("#8b3232")
	var y := 0.05
	var rear := Vector3(-0.52, y, 0)
	var front := Vector3(0.54, y, 0)
	var crank := Vector3(-0.08, y, 0.02)
	var seat := Vector3(-0.2, y + 0.02, -0.46)
	var head := Vector3(0.34, y + 0.02, -0.5)
	_wheel(xf, rear, Color("#1d1e1f"))
	_wheel(xf, front, Color("#1d1e1f"))
	_bar(xf, rear, crank, 0.024, frame)
	_bar(xf, rear, seat, 0.02, frame)
	_bar(xf, crank, seat, 0.03, frame)
	_bar(xf, crank, head, 0.032, frame)
	_bar(xf, seat, head, 0.03, frame)
	_bar(xf, head, front, 0.028, frame)
	_bar(xf, seat, seat + Vector3(-0.04, 0, -0.14), 0.024, STEEL)
	_block(xf, Vector3(0.24, 0.05, 0.1), seat + Vector3(-0.06, 0, -0.17), Color("#1d1e1f"))
	_bar(xf, head + Vector3(0, 0, -0.08), head + Vector3(0.18, 0.2, -0.1), 0.022, STEEL)

func _burn_barrel(xf: Transform3D) -> void:
	var up := Vector3(PI * 0.5, 0, 0)
	_cylinder(xf, 0.3, 0.86, Vector3(0, 0.43, 0), RUST, 14, up)
	_cylinder(xf, 0.31, 0.03, Vector3(0, 0.28, 0), RUST.darkened(0.2), 14, up)
	_cylinder(xf, 0.31, 0.03, Vector3(0, 0.6, 0), RUST.darkened(0.2), 14, up)
	_cylinder(xf, 0.27, 0.02, Vector3(0, 0.85, 0), ASH, 14, up)
	_solid(xf, Vector3(0.6, 0.88, 0.6), Vector3.ZERO)
	var fire := MeshInstance3D.new()
	fire.name = "BarrelFire"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 1.05)
	fire.mesh = quad
	fire.material_override = _fire_material()
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.position = xf.origin + Vector3.UP * 1.3
	add_child(fire)
	var light := OmniLight3D.new()
	light.name = "BarrelFireLight"
	light.light_color = Color("#ff9140")
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 55.0
	light.distance_fade_length = 20.0
	light.position = xf.origin + Vector3.UP * 1.25
	add_child(light)
	_fires.append({"fire":fire, "light":light})

func _fire_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
float hsh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float nz(vec2 p){ vec2 c = floor(p); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hsh(c), hsh(c+vec2(1,0)), u.x), mix(hsh(c+vec2(0,1)), hsh(c+vec2(1,1)), u.x), u.y); }
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], vec4(0,1,0,0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0,1,0))), 0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 uv = vec2(UV.x - 0.5, 1.0 - UV.y);
	float wobble = nz(vec2(uv.x * 5.0, uv.y * 3.0 - TIME * 2.6)) * 0.36;
	float width = (1.0 - uv.y) * 0.42 + 0.02;
	float body = 1.0 - smoothstep(width * 0.3, width, abs(uv.x + (wobble - 0.18) * uv.y));
	float rise = smoothstep(1.0, 0.1, uv.y + wobble * 0.55);
	float flame = body * rise;
	ALBEDO = mix(vec3(1.0, 0.24, 0.04), vec3(1.0, 0.82, 0.36), flame * flame) * 2.2;
	ALPHA = clamp(flame, 0.0, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func set_night_mode(value: bool) -> void:
	_night = value
	for entry: Dictionary in _fires:
		(entry.fire as Node3D).visible = value
		(entry.light as Light3D).visible = value
	set_process(value and not _fires.is_empty())

func _process(delta: float) -> void:
	_fire_time += delta
	var index := 0.0
	for entry: Dictionary in _fires:
		var light: OmniLight3D = entry.light
		light.light_energy = 2.3 + 0.5 * sin(_fire_time * 9.0 + index) + 0.3 * sin(_fire_time * 23.0 + index * 2.0)
		index += 1.7
