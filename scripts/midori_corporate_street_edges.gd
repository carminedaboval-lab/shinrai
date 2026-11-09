extends RefCounted
## Precast curbs, gutter dishes and cast-iron gullies for the corporate
## district's streets (parcel-local metres) and the connector road (world
## metres). The district's roads sit 15-18 mm below its sidewalks with a bare
## 10 cm strip between them; the curb fills that strip, 45 mm proud of the
## walk, and the dish sits on the road. The connector keeps the main street's
## profile (road .02, walk .09, curb top .132). Curbs stop at every pedestrian
## crossing, flush spine and drive opening. Geometry is batched into a few
## meshes per street edge; collision is one layer-1 box per unbroken run.
const Kit = preload("res://scripts/midori_park_kit.gd")
const PrimitiveSources = preload("res://scripts/midori_primitive_sources.gd")
const UNIT := 0.918      # precast unit pitch, as on the main street
const JOINT := 0.004
const GULLY_EVERY := 16.0

class Edge:
	var axis: int           # 0: the run follows X, 2: the run follows Z
	var fixed: float        # across coordinate of the curb centre line
	var from: float
	var to: float
	var toward_road: float  # +1 / -1 along the across axis
	var road_y: float
	var curb_top: float
	var gaps: Array[Vector2] = []
	var gully_phase := 8.0
	var gutter := true      # false where the road falls away on a ramp
	func _init(p_axis: int, p_fixed: float, p_from: float, p_to: float, p_toward: float, p_road_y: float, p_top: float) -> void:
		axis = p_axis; fixed = p_fixed; from = p_from; to = p_to
		toward_road = p_toward; road_y = p_road_y; curb_top = p_top

static func build(corporate: Node3D, street: Node3D, parcel: Node3D) -> Dictionary:
	var mats := _materials(street)
	var totals := {"edges":0, "curb_units":0, "gullies":0, "collision_runs":0, "meshes":0}
	var district_root := Node3D.new()
	district_root.name = "CorporateStreetEdges"
	district_root.set_meta("creator_protected", true)
	parcel.add_child(district_root)
	for edge: Edge in _district_edges():
		_build_edge(district_root, edge, mats, totals)
	var connector_root := Node3D.new()
	connector_root.name = "ConnectorStreetEdges"
	connector_root.set_meta("creator_protected", true)
	corporate.add_child(connector_root)
	for edge: Edge in _connector_edges():
		_build_edge(connector_root, edge, mats, totals)
	# The road widens across the south walk on a diagonal.
	_angled_curb(connector_root, Vector2(150, 190), Vector2(162.5, 195), .02, .132, mats, totals)
	district_root.set_meta("street_edges", totals)
	return totals

## Two north-south roads at local x ±51.5 (width 12) and two avenues at local
## z -50 / 55, each with sidewalks 6.1..9.9 m from the centre line.
static func _district_edges() -> Array[Edge]:
	var edges: Array[Edge] = []
	for xr: float in [-51.5, 51.5]:
		for side: float in [-1.0, 1.0]:
			var edge := Edge.new(2, xr + side * 6.05, -123.5, 123.5, -side, -.018, .045)
			# Avenue sidewalks cross the road flush, and the crossing at z 34
			# joins the pedestrian spine (z 30..38) on the side facing the tower.
			edge.gaps = [Vector2(-59.9, -40.1), Vector2(45.1, 64.9)]
			var inner: bool = (side < 0.0) == (xr > 0.0)
			edge.gaps.append(Vector2(29.9, 38.1) if inner else Vector2(32.1, 35.9))
			edges.append(edge)
	for za: float in [-50.0, 55.0]:
		for side: float in [-1.0, 1.0]:
			var edge := Edge.new(0, za + side * 6.05, -147.5, 147.5, -side, -.015, .045)
			# North-south sidewalks cross the avenues flush at both roads.
			edge.gaps = [Vector2(-61.4, -41.6), Vector2(41.6, 61.4)]
			# Garage and police drives meet the north edge of the southern avenue.
			if za > 0.0 and side < 0.0:
				edge.gaps.append_array([Vector2(75.9, 90.1), Vector2(-71.1, -60.9)])
			edges.append(edge)
	return edges

## The main-road continuation east of the shops, world metres: walks at .09
## either side of a 7 m road at .02, then round the turn into the district.
## The road falls away on its ramp south of z 195, so those curbs start below
## it and carry no gutter.
static func _connector_edges() -> Array[Edge]:
	var east_ramp := Edge.new(2, 174.57, 195.0, 204.0, -1.0, -.02, .132)
	east_ramp.gutter = false
	var west_ramp := Edge.new(2, 162.43, 197.5, 204.0, 1.0, -.02, .132)
	west_ramp.gutter = false
	return [Edge.new(0, 182.93, 52.6, 174.5, 1.0, .02, .132), Edge.new(0, 190.07, 52.6, 150.0, -1.0, .02, .132),
		Edge.new(2, 174.57, 182.86, 195.0, -1.0, .02, .132), east_ramp, west_ramp]

static func _materials(street: Node3D) -> Dictionary:
	var source: Dictionary = street.get("materials") if street != null else {}
	var out := {}
	for key: String in ["land_curb", "land_gutter", "land_iron", "land_void"]:
		var found: Material = source.get(key) as Material
		out[key] = found.duplicate() if found != null else null
	if out.land_curb == null: out.land_curb = Kit.mat(Color("#b7b5a7"), .9)
	if out.land_gutter == null: out.land_gutter = Kit.mat(Color("#a09f93"), .92)
	if out.land_iron == null: out.land_iron = Kit.mat(Color("#3a413d"), .8, .4)
	if out.land_void == null: out.land_void = Kit.mat(Color("#0a0c0b"), 1.0)
	return out

static func _build_edge(root: Node3D, edge: Edge, mats: Dictionary, totals: Dictionary) -> void:
	var along := Vector3.RIGHT if edge.axis == 0 else Vector3.BACK
	var across := (Vector3.BACK if edge.axis == 0 else Vector3.RIGHT) * edge.toward_road
	var h := edge.curb_top - edge.road_y
	var curb_profile := _curb_profile(h)
	var dish := _dish_profile()
	var tools := _new_tools()
	var runs := 0
	for seg: Vector2 in _segments(edge.from, edge.to, edge.gaps):
		var length := seg.y - seg.x
		if length < .3: continue
		var n := maxi(1, int(round(length / UNIT)))
		var pitch := length / float(n)
		for i: int in range(n):
			var centre := seg.x + (float(i) + .5) * pitch
			var base := _point(edge, centre, edge.fixed, edge.road_y)
			_extrude(tools.curb, curb_profile, base, along, across, pitch - JOINT)
			if edge.gutter:
				_extrude(tools.gutter, dish, base + across * .18 + Vector3.DOWN * .004, along, across, pitch - JOINT)
				if i < n - 1:
					_box_into(tools.seal, _size(edge, .005, .013, .22), _point(edge, seg.x + float(i + 1) * pitch, edge.fixed + edge.toward_road * .18, edge.road_y + .0025))
			totals.curb_units += 1
		_solid(root, "CurbRun", _point(edge, (seg.x + seg.y) * .5, edge.fixed, (edge.road_y + edge.curb_top) * .5), _size(edge, length, h, .14))
		runs += 1
		var g := edge.from + edge.gully_phase
		while edge.gutter and g < edge.to:
			if g > seg.x + 1.2 and g < seg.y - 1.2:
				_gully(tools, edge, g, h)
				totals.gullies += 1
			g += GULLY_EVERY
	totals.collision_runs += runs
	totals.edges += 1
	_commit_tools(root, tools, mats, totals)

static func _curb_profile(h: float) -> Array[Vector2]:
	return [Vector2(-.07, 0), Vector2(.07, 0), Vector2(.07, h - .013), Vector2(.057, h), Vector2(-.057, h), Vector2(-.07, h - .013)]

static func _dish_profile() -> Array[Vector2]:
	return [Vector2(-.11, 0), Vector2(.11, 0), Vector2(.11, .012), Vector2(.08, .012), Vector2(0, .006), Vector2(-.08, .012), Vector2(-.11, .012)]

static func _new_tools() -> Dictionary:
	var tools := {}
	for key: String in ["curb", "gutter", "seal", "bed", "iron", "void"]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = tool
	return tools

## A curb along any road edge a -> b, with the walk on the left of that direction.
static func _angled_curb(root: Node3D, a: Vector2, b: Vector2, road_y: float, curb_top: float, mats: Dictionary, totals: Dictionary) -> void:
	var flat := (b - a).normalized()
	var length := a.distance_to(b)
	var along := Vector3(flat.x, 0, flat.y)
	var toward_walk := Vector3(-flat.y, 0, flat.x)
	var across := -toward_walk
	var h := curb_top - road_y
	var tools := _new_tools()
	var n := maxi(1, int(round(length / UNIT)))
	var pitch := length / float(n)
	var start := Vector3(a.x, road_y, a.y) + toward_walk * .07
	for i: int in range(n):
		var base := start + along * ((float(i) + .5) * pitch)
		_extrude(tools.curb, _curb_profile(h), base, along, across, pitch - JOINT)
		_extrude(tools.gutter, _dish_profile(), base + across * .18 + Vector3.DOWN * .004, along, across, pitch - JOINT)
		totals.curb_units += 1
	_commit_tools(root, tools, mats, totals)
	var centre := start + along * (length * .5) + Vector3.UP * (h * .5)
	var body := _solid(root, "CurbRun", centre, Vector3(length, h, .14))
	body.rotation.y = atan2(-flat.y, flat.x)
	totals.collision_runs += 1
	totals.edges += 1

static func _commit_tools(root: Node3D, tools: Dictionary, mats: Dictionary, totals: Dictionary) -> void:
	for pair: Array in [["curb", mats.land_curb, true], ["gutter", mats.land_gutter, false], ["seal", mats.land_void, false], ["bed", mats.land_gutter, false], ["iron", mats.land_iron, false], ["void", mats.land_void, false]]:
		var mesh: ArrayMesh = (tools[pair[0]] as SurfaceTool).commit()
		if mesh == null or mesh.get_surface_count() == 0: continue
		var visual := MeshInstance3D.new()
		visual.name = "StreetEdge_" + String(pair[0])
		visual.mesh = mesh
		visual.material_override = pair[1]
		if not pair[2]: visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(visual)
		totals.meshes += 1

## Cast-iron gully in the gutter dish with an inlet through the curb face,
## the same construction as the main street, relative to this edge's road level.
static func _gully(tools: Dictionary, edge: Edge, at: float, h: float) -> void:
	var gutter_across := edge.fixed + edge.toward_road * .18
	var ry := edge.road_y
	_box_into(tools.bed, _size(edge, .64, .008, .26), _point(edge, at, gutter_across, ry + .004))
	_box_into(tools.void, _size(edge, .56, .003, .20), _point(edge, at, gutter_across, ry + .0075))
	for c: float in [-.105, .105]:
		_box_into(tools.iron, _size(edge, .60, .006, .03), _point(edge, at, gutter_across + c, ry + .011))
	for a: float in [-.285, .285]:
		_box_into(tools.iron, _size(edge, .03, .006, .24), _point(edge, at + a, gutter_across, ry + .011))
	for i: int in range(13):
		_box_into(tools.iron, _size(edge, .022, .004, .18), _point(edge, at - .252 + float(i) * .042, gutter_across, ry + .010))
	for c: float in [-.03, .03]:
		_box_into(tools.iron, _size(edge, .54, .003, .012), _point(edge, at, gutter_across + c, ry + .0105))
	# Inlet opening in the road face of the curb, with a cast lintel above it.
	var inlet_h := clampf(h - .02, .02, .056)
	var face := edge.fixed + edge.toward_road * .066
	_box_into(tools.void, _size(edge, .46, inlet_h, .008), _point(edge, at, face, ry + .01 + inlet_h * .5))
	_box_into(tools.iron, _size(edge, .50, .008, .014), _point(edge, at, edge.fixed + edge.toward_road * .067, ry + .014 + inlet_h))

static func _segments(from: float, to: float, gaps: Array[Vector2]) -> Array[Vector2]:
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	var cursor := from
	for gap: Vector2 in sorted:
		if gap.y <= cursor or gap.x >= to: continue
		if gap.x > cursor: out.append(Vector2(cursor, gap.x))
		cursor = maxf(cursor, gap.y)
	if cursor < to: out.append(Vector2(cursor, to))
	return out

static func _point(edge: Edge, along_v: float, across_v: float, y: float) -> Vector3:
	return Vector3(along_v, y, across_v) if edge.axis == 0 else Vector3(across_v, y, along_v)

static func _size(edge: Edge, along_s: float, height: float, across_s: float) -> Vector3:
	return Vector3(along_s, height, across_s) if edge.axis == 0 else Vector3(across_s, height, along_s)

static func _box_into(tool: SurfaceTool, size: Vector3, centre: Vector3) -> void:
	# A BoxMesh of this size, read back from the GPU once per distinct size (see
	# midori_primitive_sources.gd), not once per seal, gully bar and inlet.
	tool.append_from(PrimitiveSources.box(size), 0, Transform3D(Basis.IDENTITY, centre))

## Extrude a closed (across, up) profile along `along` for `length`, centred on `base`.
static func _extrude(tool: SurfaceTool, profile: Array[Vector2], base: Vector3, along: Vector3, across: Vector3, length: float) -> void:
	var centroid := Vector2.ZERO
	for p: Vector2 in profile: centroid += p
	centroid /= float(profile.size())
	var half := along * (length * .5)
	for i: int in range(profile.size()):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % profile.size()]
		var pa := base + across * a.x + Vector3.UP * a.y
		var pb := base + across * b.x + Vector3.UP * b.y
		var mid := (a + b) * .5 - centroid
		var outward := (across * mid.x + Vector3.UP * mid.y).normalized()
		_tri(tool, pa - half, pa + half, pb + half, outward)
		_tri(tool, pa - half, pb + half, pb - half, outward)
	var packed := PackedVector2Array(profile)
	var indices := Geometry2D.triangulate_polygon(packed)
	for sgn: float in [-1.0, 1.0]:
		var normal := along * sgn
		for t: int in range(0, indices.size(), 3):
			var v: Array[Vector3] = []
			for k: int in range(3):
				var p: Vector2 = profile[indices[t + k]]
				v.append(base + across * p.x + Vector3.UP * p.y + along * (sgn * length * .5))
			_tri(tool, v[0], v[1], v[2], normal)

## Godot front faces wind clockwise: the vertex-order cross product points
## opposite the face normal, so flip the order when it agrees with it.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b; b = c; c = swap
	for vertex: Vector3 in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)

static func _solid(parent: Node3D, label: String, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = centre
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body
