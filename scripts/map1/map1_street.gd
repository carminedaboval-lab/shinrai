extends Node3D
## A real edge for one side of a Map 1 street: precast gutter and kerb units, and the raised
## footway behind them. The road itself stays the painted ground for now.
##
## Built from one entry of "street_edges" in the generated map file (the street's centre line,
## its width and its footway width). Sizes are a Tokyo homes street's:
##   kerb     14 cm wide, 13 cm high, its top edges chamfered, in units 60 cm long
##   gutter   22 cm wide, cast with the kerb unit, falling towards the kerb so water runs there
##   footway  from the kerb's back to the footway width, level with the kerb's top
## The edge stops wherever the ground picture shows road on that side (a side street, a
## turning circle), one unit short of it: the corner pieces are not built yet.
##
## One mesh and one draw call for the whole edge; one body to stand on. The kerb is a 13 cm
## step, which the player's own step-up (32 cm) takes.

const UNIT := 0.6            # one precast unit along the street
const JOINT := 0.006         # the gap between two units
const KERB_WIDE := 0.14
const KERB_HIGH := 0.13
const CHAMFER := 0.013
const GUTTER_WIDE := 0.22
const GUTTER_LIP := 0.02     # the gutter's road edge stands this far above the painted road
const GUTTER_LOW := 0.008    # and it falls to this at the kerb's foot
const FOOT := 0.05           # how far every piece goes down into the ground
const CONCRETE := Color(0.47, 0.46, 0.43)
const FOOTWAY := Color(0.17, 0.17, 0.18)      # asphalt too, a little lighter than the road's
const IRON := Color(0.20, 0.15, 0.12)          # a cast grate, rusted brown
const PIT := Color(0.02, 0.02, 0.02)           # the dark of the catch pit under it
const POLE_CONCRETE := Color(0.56, 0.56, 0.54)
const GALVANISED := Color(0.62, 0.64, 0.66)
const PORCELAIN := Color(0.78, 0.77, 0.73)
## The road's own surface, laid over the painted ground on this street only: asphalt with a
## worn white edge line. UV is metres: x out from the centre line towards the built side,
## y along the street.
const ASPHALT := preload("res://scripts/map1/map1_trial_asphalt.tres")
const ASPHALT_LIFT := 0.012   # above the painted ground, below the gutter's road edge
const LINE_WIDE := 0.10
const LINE_GAP := 0.02        # asphalt showing between the white line and the gutter
## The one drain inlet: a narrow grate in place of a gutter unit's channel, this far into
## the longest stretch (a whole number of units).
const GRATE_INTO_RUN := 9.0
const GRATE_BAR := 0.006
const GRATE_PITCH := 0.027
const GRATE_RIM := 0.022
## The one utility pole: a tapered concrete pole 11 m out of the footway, standing just
## behind the kerb at the boundary between two plots.
const POLE_INTO_RUN := 21.0
const POLE_HIGH := 11.0
const POLE_FOOT_RADIUS := 0.15
const POLE_TOP_RADIUS := 0.095
const POLE_BEHIND_KERB := 0.30   # from the kerb's back to the pole's middle
## A lowered kerb at an entrance: the kerb and the whole narrow footway dip to 3 cm over three
## units, with two units of slope to either side (11 cm in 1.2 m, about one in eleven).
const FORECOURT := Color(0.36, 0.355, 0.34)    # old concrete paving, darker than the kerb's
const FORECOURT_END := 0.012   # its edge at the shop fronts stands this far above the ground
## A corner into a side street: the kerb and gutter turn through a quarter circle of this
## radius (to the kerb's road face) in short curved pieces, then run straight along the side
## street to the footway's back and stop there.
const CORNER_R := 0.9
const CORNER_PIECES := 4
const DROP_HIGH := 0.03
const CAR_PARK := Color8(112, 112, 114)   # the ground picture's grey for a plot cars are parked on
const DROP_UNITS := 3
const RAMP_UNITS := 2

var runs: Array[Vector2] = []       # each built stretch: from and to, metres along the street
var opposite_runs: Array[Vector2] = []  # gutter stretches bordering the far edge of the asphalt
var opposite_zones: Array[Vector2] = [] # and the other side's side-street mouths (see mouth_zones)
## How far the road's surface is laid into a side street, past the footway's back.
const MOUTH_DEEP := 3.0
var units := 0
var triangles := 0
var half := 0.0                     # the road's half width: the kerb's road face is here
var footway_wide := 0.0
## A shop forecourt behind the footway, this deep (0: none). The shops stand on the ground,
## 13 cm under the footway, as old shop-houses do beside a pavement raised since: the paving
## falls from the footway's back to the ground at the shop fronts. Set before build().
var forecourt := 0.0
var side := 1.0
## A surface of its own for the footway's top and for the forecourt's, where a material is
## given (set before build()). UV is metres: x out from the kerb's road face, y along the
## street. Without one the top is plain vertex colour in the edge's one mesh.
var footway_material: Material
var forecourt_material: Material
var _tops := {}      # "Footway" / "Forecourt": its SurfaceTool
var grate_at := -1.0                # metres along the street to the grate unit's start, or -1
var pole_at := -1.0                 # metres along the street to the pole, or -1
var pole_out := 0.0                 # and how far out from the centre line it stands
var line_out := 0.0                 # the white line's middle, out from the centre line
var drops: Array[Vector2] = []
## Each corner into a side street: {"mouth": metres along to the side street's edge, "dir": +1
## if the side street lies further along than the stretch, -1 if before it, "from": where the
## stretch's whole units stop}.
var corners: Array = []
var _near := 0.5
## Where another built street crosses this one on this side, from the map's own lines (the
## ground picture can be half a metre off): x = from, y = to (metres along), z = 1 if that
## street is built on this side (its own surface starts at the footway's back), else 0.
var _crossings: Array[Vector3] = []
## Ends of this edge that no other street's corner comes round to meet (road lies on both
## sides of the footway there): -1 for the start, +1 for the end. The kerb goes round the
## footway's end in a half circle as wide as the footway. Set before build().
var noses: Array[float] = []
## The rounded nose of another street's footway standing in one of this edge's mouths: the
## mouth's asphalt is cut round it. Each: {"s", "out": the half circle's middle (metres along
## and out on this edge), "radius": to the kerb's face, "kerb": +1 or -1, the way along this
## edge that the nose's straight kerb and gutter lie from the middle}.
var mouth_holes: Array = []
## A nose shared by two lanes' sides (an island too narrow for two footways): its half circle's
## radius, and how far its tip reaches past the last unit (the street it stands in: that
## street's footway width). -1: half the footway, and the footway's width.
var nose_radius := -1.0
var nose_reach := -1.0
## A kerb round a turning circle: the edge is a circle, not a line. Metres along are measured
## round the kerb's face from `round_from` (radians, x towards z), metres out from the centre.
var is_round := false
var round_centre := Vector2.ZERO
var round_from := 0.0
## Where this side flares out into a turning circle: the straight kerb stops at `fillet_at`
## (metres along) and turns on a curve of `fillet_r` through `fillet_angle` (radians) until it
## meets the circle's kerb. -1: no flare.
var fillet_at := -1.0
var fillet_r := 0.0
var fillet_angle := 0.0
## The same curve where a street ends at a wider cross road that is not built (the shop row's
## west end at the Outer ring): it turns a quarter round into the cross road's kerb line and
## stops there, its end closed, with a patch of road out to the corner the two kerb lines make.
var fillet_end := false
## Where a footway ends at the road with nothing to turn into (the shop row's east end, at the
## tram track): metres along its last stretch's end, which it is lowered to meet; -1: none.
var low_end_at := -1.0
## A patch of this street's road surface past its end, out to what lies beyond (world x, z): the
## shop row's east end, up to the painted tram bed's edge. Laid by the side that lays the road.
var end_patch: PackedVector2Array = []
## Where the road's ribbon stops (a turning circle's own surface takes over), or -1.
var ribbon_end := -1.0
## Where a tram runs down the middle of the street: the road's surface leaves this far either
## side of the centre line as it is (the rail bed). 0: none.
var median := 0.0
var _edge_line := true
var _exact := false      # an edge between two built streets: laid for its whole length, no picture test
var _cross_sign := 1.0      # each lowered kerb: from and to along the street, at its lowest

var _points: PackedVector2Array = []
var _lengths := PackedFloat32Array()
var _map: Node3D


## `map` is the blockout (ground_height, ground_image, frame). `which_side` is +1 for the
## left of the street's direction of travel in the plan (x to z turned a quarter), -1 for
## the other.
## Laying comes first and makes nothing to see: it works out where the edge runs, so that the
## houses can be planned up to the footway's back before anything is built.
func lay(map: Node3D, edge: Dictionary, which_side: float) -> void:
	_map = map
	side = which_side
	half = float(edge.w) * 0.5
	footway_wide = float(edge.pavement)
	for point: Array in edge.points: _points.append(Vector2(float(point[0]), float(point[1])))
	_lengths.append(0.0)
	for i: int in range(1, _points.size()): _lengths.append(_lengths[i - 1] + _points[i].distance_to(_points[i - 1]))
	var length := _lengths[_lengths.size() - 1]
	var count := int(floor(length / UNIT))
	_near = 0.5 if footway_wide < 1.8 else 1.2
	_exact = bool(edge.get("exact", false))
	for crossing: Dictionary in edge.get("crossings", []):
		for entry: Dictionary in crossing.sides:
			if is_equal_approx(float(entry.side), side): _crossings.append(Vector3(float(entry.from), float(entry.to), 1.0 if bool(entry.built) else 0.0))
	if _exact and _crossings.is_empty():
		# It is laid for its whole length: whole units from its start, and a cut unit for what
		# is left at its end.
		runs.append(Vector2(0.0, length))
		return
	if _exact:
		_lay_between_crossings(length)
		return
	# Which units have ground, not road, behind them. (A piece laid between built streets that
	# a lower lane crosses: open all along but where the map says the lane crosses.)
	var open: Array[bool] = []
	for i: int in count:
		var s := (float(i) + 0.5) * UNIT
		# (The ground picture can lie up to a metre off a wide road's true edge: an even width
		# falls between its pixels. So the nearer test stands 1.2 m out where the footway has room.)
		open.append(true if _exact else not _behind(s))
	# Road that reaches under three metres behind the footway is not a street: where one road
	# starts from another the picture's paint pokes a little way past the far side. The kerb
	# runs on past it.
	var from_unit := -1
	for i: int in count + 1:
		var shut: bool = i < count and not open[i] and not _exact
		if shut and from_unit < 0: from_unit = i
		elif not shut and from_unit >= 0:
			var deep := false
			for j: int in range(from_unit, i):
				if _road((float(j) + 0.5) * UNIT, half + footway_wide + 3.0): deep = true
			if not deep:
				for j: int in range(from_unit, i): open[j] = true
			from_unit = -1
	# Where a built street crosses, the map's own lines decide, not the picture.
	for crossing: Vector3 in _crossings:
		for i: int in count:
			var middle := (float(i) + 0.5) * UNIT
			if middle > crossing.x - 1.5 and middle < crossing.y + 1.5: open[i] = middle < crossing.x or middle > crossing.y
	var first := -1
	for i: int in count + 1:
		var here: bool = i < count and open[i]
		if here and first < 0: first = i
		elif not here and first >= 0:
			# One unit short of the road at each end; a stretch of under two metres is left out.
			if i - first - 2 >= 4: runs.append(Vector2(float(first + 1) * UNIT, float(i - 1) * UNIT))
			first = -1
	# A piece laid between built streets runs to its own ends, not one unit short of them.
	# (So does a street at an end where a piece carries it on: the shop row at its west end.)
	if bool(edge.get("joined_start", false)) and not runs.is_empty() and open[0] and is_equal_approx(runs[0].x, UNIT): runs[0] = Vector2(0.0, runs[0].y)
	if _exact and not runs.is_empty():
		if open[0] and is_equal_approx(runs[0].x, UNIT): runs[0] = Vector2(0.0, runs[0].y)
		if open[count - 1] and is_equal_approx(runs[runs.size() - 1].y, float(count - 1) * UNIT): runs[runs.size() - 1] = Vector2(runs[runs.size() - 1].x, length)
	# Where a stretch ends at a side street's mouth, the kerb turns the corner into it: the
	# stretch gives up one more unit, and a short cut unit and the curved pieces take its place.
	for index: int in runs.size():
		var run := runs[index]
		var found: Array = []
		for dir: float in [1.0, -1.0]:
			var mouth := _mouth(run.y if dir > 0.0 else run.x, dir, length)
			if not is_nan(mouth): found.append([mouth, dir])
		if run.y - run.x - UNIT * float(found.size()) < 2.0 * UNIT - 0.001: continue
		for pair: Array in found:
			if float(pair[1]) > 0.0: run.y -= UNIT
			else: run.x += UNIT
			var deep := MOUTH_DEEP
			for crossing: Vector3 in _crossings:
				if (is_equal_approx(float(pair[0]), crossing.x) or is_equal_approx(float(pair[0]), crossing.y)) and crossing.z > 0.5: deep = 0.0
			corners.append({"mouth": float(pair[0]), "dir": float(pair[1]), "from": run.y if float(pair[1]) > 0.0 else run.x, "deep": deep})
		runs[index] = run


## A piece laid between built streets that lower lanes cross: a stretch of kerb between each
## two crossings, however short (an island between two lanes), each end turning the corner into
## the lane beside it; the corner's curve is smaller where the stretch is short.
func _lay_between_crossings(length: float) -> void:
	var crossings := _crossings.duplicate()
	crossings.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var from := 0.0
	var bounds: Array = []         # [start, end, the crossing before or null, the crossing after or null]
	var before: Variant = null
	for crossing: Vector3 in crossings:
		if crossing.x > from + 0.05: bounds.append([from, crossing.x, before, crossing])
		from = maxf(from, crossing.y)
		before = crossing
	if length > from + 0.05: bounds.append([from, length, before, null])
	for bound: Array in bounds:
		var a: float = bound[0]
		var b: float = bound[1]
		var turns := (1 if bound[2] != null else 0) + (1 if bound[3] != null else 0)
		# (Between two lanes with too little room for two curves and a unit between them, there is
		# no stretch: that is an island between the lanes, and its own rounded end meets the street.)
		if turns == 2 and b - a < 2.0 * CORNER_R + UNIT: continue
		# Room for the curve at each end turning into a lane: as much of CORNER_R as the stretch
		# leaves, keeping at least a unit of straight kerb between two curves.
		var take := minf(CORNER_R, maxf((b - a - UNIT) / maxf(float(turns), 1.0), 0.0)) if turns > 0 else 0.0
		var run := Vector2(a + (take if bound[2] != null else 0.0), b - (take if bound[3] != null else 0.0))
		if run.y - run.x < 0.05: continue
		runs.append(run)
		for pair: Array in [[bound[3], 1.0, run.y, b], [bound[2], -1.0, run.x, a]]:
			if pair[0] == null: continue
			var crossing: Vector3 = pair[0]
			corners.append({"mouth": float(pair[3]), "dir": float(pair[1]), "from": float(pair[2]), "deep": 0.0 if crossing.z > 0.5 else MOUTH_DEEP})


## Is there road behind the kerb at s: a side street's mouth, a turning circle? Looked for
## a metre past the footway's back, where a side street's road is and a junction's own paint
## on the footway is not.
func _behind(s: float) -> bool:
	return _road(s, half + _near) or _road(s, half + footway_wide - 0.3) or _road(s, half + footway_wide + 1.0)


## Where the road of a side street begins past the end of a stretch (`dir` +1: further along,
## -1: back), or NAN if what lies there is not a side street: ground must come again on this
## side within 24 m past it. (A turning circle or the street's own end has none.)
func _mouth(end: float, dir: float, length: float) -> float:
	for crossing: Vector3 in _crossings:
		var edge := crossing.x if dir > 0.0 else crossing.y
		if (edge - end) * dir >= 0.0 and (edge - end) * dir <= 3.0: return edge
	if _exact: return NAN      # (a piece laid between built streets: only the map's crossings, not the picture)
	var mouth := NAN
	var t := 0.0
	while t <= 3.0:
		var s := end + dir * t
		if s < 0.0 or s > length: return NAN
		if _behind(s):
			mouth = s
			break
		t += 0.05
	if is_nan(mouth): return NAN
	t = 1.0
	while t <= 24.0:
		var s := mouth + dir * t
		if s < 0.0 or s > length: return NAN
		if not _behind(s): return mouth
		t += 0.3
	return NAN


## How far a point (a house's front) stands behind the footway's back edge, or INF where this
## edge has no footway in front of it (the other side of the street, a side street's mouth).
func plot_gap(point: Vector3) -> float:
	var out := out_of(point)
	if out < half or out > half + footway_wide + 12.0: return INF
	var s := along_of(point)
	if not beside(point, s): return INF
	for run: Vector2 in runs:
		if s >= run.x and s <= run.y: return out - half - footway_wide
	return INF


## Whether a point is beside this edge at `s` (its nearest place on the centre line), not off past
## one of its ends: along_of holds a point beyond an end at that end, and a lane's line, carried on
## past its end, would otherwise answer for houses a hundred metres away.
func beside(point: Vector3, s: float) -> bool:
	if is_round: return true
	var foot := at(s, 0.0)
	var ahead := at(s + 0.01, 0.0) - foot
	if ahead.length() < 1e-6: return true
	return absf(Vector2(point.x - foot.x, point.z - foot.z).dot(Vector2(ahead.x, ahead.z).normalized())) < 0.2


## How far the paving stands above the ground at a point: the footway's height on the footway,
## falling across the forecourt, 0 anywhere else. For what is stood on it.
func lift_at(point: Vector3) -> float:
	var out := out_of(point)
	# (Only where there is a forecourt: on a homes street nothing of a house stands on the footway.)
	if forecourt <= 0.0 or out < half or out > half + footway_wide + forecourt: return 0.0
	var s := along_of(point)
	if not beside(point, s): return 0.0
	for run: Vector2 in runs:
		if s < run.x or s > run.y: continue
		if out <= half + footway_wide: return kerb_high(s)
		return lerpf(kerb_high(s), FORECOURT_END, (out - half - footway_wide) / forecourt)
	return 0.0


## Where a car is parked on open ground behind the footway (the ground picture's car-park
## grey): the middle of each such frontage, for a lowered kerb `wide` metres across.
func car_parks(wide: float) -> Array:
	var found: Array = []
	var image: Image = _map.ground_image
	if image == null: return found
	var frame: Rect2 = _map.frame
	for run: Vector2 in runs:
		var first := -1.0
		var s := run.x
		while s <= run.y + UNIT:
			var here := at(s, half + footway_wide + 1.2)
			var pixel := image.get_pixel(clampi(int(here.x - frame.position.x), 0, image.get_width() - 1), clampi(int(here.z - frame.position.y), 0, image.get_height() - 1))
			var parked := s <= run.y and absf(pixel.r8 - CAR_PARK.r8) <= 1 and absf(pixel.g8 - CAR_PARK.g8) <= 1 and absf(pixel.b8 - CAR_PARK.b8) <= 1
			if parked and first < 0.0: first = s
			elif not parked and first >= 0.0:
				if s - first >= wide: found.append({"at": at((first + s) * 0.5, half + footway_wide + 1.2), "wide": wide, "what": "car park"})
				first = -1.0
			s += UNIT
	return found


## Builds the edge. `entrances`: each lowered kerb wanted, as {"at": where its middle stands in
## the world (behind the footway), "wide": metres}. Those on the other side are passed over.
## `with`: what else this side gets ("asphalt", "grate", "pole"); the road's surface is one
## ribbon, so only one side lays it.
func build(entrances: Array = [], with: Array = ["asphalt", "grate", "pole"]) -> void:
	# A lowered kerb for each entrance, on whole units, where its slopes fit inside a stretch.
	for entrance: Dictionary in entrances:
		var gate: Vector3 = entrance.at
		var out := out_of(gate)
		if out < half + KERB_WIDE or out > half + footway_wide + 12.0: continue      # not on this side
		var middle := along_of(gate)
		var count := int(ceil(float(entrance.wide) / UNIT - 0.001))
		for run: Vector2 in runs:
			var from: float = run.x + roundf((middle - float(count) * UNIT * 0.5 - run.x) / UNIT) * UNIT
			var to: float = from + float(count) * UNIT
			# (Its slopes may run on into a corner that follows the stretch.)
			var low := run.x
			var high := run.y
			for corner: Dictionary in corners:
				if is_equal_approx(float(corner.from), run.x) and float(corner.dir) < 0.0: low = float(corner.mouth)
				if is_equal_approx(float(corner.from), run.y) and float(corner.dir) > 0.0: high = float(corner.mouth)
			if from >= run.x - 0.001 and to <= run.y + 0.001 and from - float(RAMP_UNITS) * UNIT >= low - 0.001 and to + float(RAMP_UNITS) * UNIT <= high + 0.301: drops.append(Vector2(from, to))
	var look := SurfaceTool.new()
	look.begin(Mesh.PRIMITIVE_TRIANGLES)
	look.set_smooth_group(-1)      # every face flat: these are cast concrete edges
	var stand := SurfaceTool.new()
	stand.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The grate and the pole go on the longest stretch.
	var longest := Vector2.ZERO
	for run: Vector2 in runs:
		if run.y - run.x > longest.y - longest.x: longest = run
	if with.has("grate") and longest.y - longest.x > GRATE_INTO_RUN + 6.0: grate_at = longest.x + round(GRATE_INTO_RUN / UNIT) * UNIT
	if with.has("pole") and longest.y - longest.x > POLE_INTO_RUN + 6.0:
		pole_at = longest.x + POLE_INTO_RUN
		pole_out = half + KERB_WIDE + POLE_BEHIND_KERB
	line_out = half - GUTTER_WIDE - LINE_GAP - LINE_WIDE * 0.5
	for run: Vector2 in runs:
		var n := int(floor((run.y - run.x) / UNIT + 0.001))
		# (A stretch that is not a whole number of units ends in a cut one.)
		var left := (run.y - run.x) - float(n) * UNIT
		if left > 0.05:
			_unit(look, run.x + float(n) * UNIT + JOINT * 0.5, run.y - JOINT * 0.5)
			units += 1
		for i: int in n:
			var from := run.x + float(i) * UNIT
			var inlet := grate_at >= 0.0 and absf(from - grate_at) < 0.01
			_unit(look, from + JOINT * 0.5, from + UNIT - JOINT * 0.5, inlet)
			if inlet: _grate(look, from + JOINT * 0.5, from + UNIT - JOINT * 0.5)
			units += 1
		_footway(look, run.x, run.y)
		_standing(stand, run.x, run.y)
	if units == 0: return
	# (Which way round a triangle faces up, taken from the footway's own top.)
	var ref_a := at(1.0, half + 0.2)
	var ref_b := at(1.0, half + 1.0)
	var ref_c := at(2.0, half + 1.0)
	_cross_sign = signf(((ref_b if side < 0.0 else ref_c) - ref_a).cross((ref_c if side < 0.0 else ref_b) - ref_a).y)
	for corner: Dictionary in corners: _corner(look, stand, corner)
	for dir: float in noses: _nose(look, stand, dir)
	if fillet_at >= 0.0: _fillet(look, stand)
	if pole_at >= 0.0: _pole(look)
	look.generate_normals()
	var mesh := look.commit()
	triangles = mesh.get_faces().size() / 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true      # the colours above are as seen, not linear light
	material.roughness = 0.92
	var instance := MeshInstance3D.new()
	instance.name = "Edge"
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	for which: String in _tops:
		var top_tool: SurfaceTool = _tops[which]
		top_tool.generate_normals()
		var top_mesh := top_tool.commit()
		triangles += top_mesh.get_faces().size() / 3
		var paved := MeshInstance3D.new()
		paved.name = which
		paved.mesh = top_mesh
		paved.material_override = footway_material if which == "Footway" else forecourt_material
		add_child(paved)
	var body := StaticBody3D.new()
	body.name = "EdgeBody"
	var shape := CollisionShape3D.new()
	shape.shape = stand.commit().create_trimesh_shape()
	body.add_child(shape)
	if pole_at >= 0.0:
		var shaft := CylinderShape3D.new()
		shaft.radius = POLE_FOOT_RADIUS
		shaft.height = POLE_HIGH
		var pole := CollisionShape3D.new()
		pole.name = "Pole"
		pole.shape = shaft
		pole.position = _lifted(pole_at, pole_out, top(pole_at) + POLE_HIGH * 0.5)
		body.add_child(pole)
	add_child(body)
	_mouth_asphalt()
	_edge_line = not with.has("no line")
	if with.has("asphalt"): _asphalt()
	if with.has("asphalt") and end_patch.size() >= 3: _end_patch_asphalt()
	if fillet_end and fillet_at >= 0.0: _end_corner_asphalt()


## The point `s` metres along the street and `out` metres towards this edge's side, on the
## ground, `lift` above it.
func at(s: float, out: float, lift := 0.0) -> Vector3:
	if is_round:
		var angle := round_from + s / half
		var spot := round_centre + Vector2(cos(angle), sin(angle)) * out
		return Vector3(spot.x, float(_map.ground_height(spot.x, spot.y)) + lift, spot.y)
	var i := 0
	while i < _lengths.size() - 2 and _lengths[i + 1] < s: i += 1
	var a := _points[i]
	var b := _points[i + 1]
	var along := (b - a).normalized()
	var flat := a + along * (s - _lengths[i]) + Vector2(-along.y, along.x) * side * out
	return Vector3(flat.x, float(_map.ground_height(flat.x, flat.y)) + lift, flat.y)


## How high the kerb stands above the road, `s` metres along: 13 cm, less at a lowered kerb.
func kerb_high(s: float) -> float:
	var ramp := float(RAMP_UNITS) * UNIT
	# (A footway that ends where people step off onto the road: its last unit lies low, and the
	# units before it slope down to it, the footway's top, its forecourt edge and what is stood on
	# with them.)
	if low_end_at >= 0.0 and s > low_end_at - UNIT - ramp:
		if s >= low_end_at - UNIT: return DROP_HIGH
		return lerpf(KERB_HIGH, DROP_HIGH, (s - (low_end_at - UNIT - ramp)) / ramp)
	for drop: Vector2 in drops:
		if s <= drop.x - ramp or s >= drop.y + ramp: continue
		if s < drop.x: return lerpf(KERB_HIGH, DROP_HIGH, (s - (drop.x - ramp)) / ramp)
		if s > drop.y: return lerpf(DROP_HIGH, KERB_HIGH, (s - drop.y) / ramp)
		return DROP_HIGH
	return KERB_HIGH


## How far along the street a point lies (the nearest place on its centre line).
func along_of(point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	if is_round: return wrapf(atan2(flat.y - round_centre.y, flat.x - round_centre.x) - round_from, 0.0, TAU) * half
	var best := 0.0
	var gap := INF
	for i: int in _points.size() - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var t := clampf((flat - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var here := flat.distance_to(a.lerp(b, t))
		if here < gap:
			gap = here
			best = _lengths[i] + (_lengths[i + 1] - _lengths[i]) * t
	return best


## How far out from the centre line a point lies, towards this edge's side (less than
## nothing on the other side).
func out_of(point: Vector3) -> float:
	if is_round: return Vector2(point.x, point.z).distance_to(round_centre)
	var s := along_of(point)
	var centre := at(s, 0.0)
	var outward := at(s, 1.0) - centre
	return Vector3(point.x - centre.x, 0.0, point.z - centre.z).dot(Vector3(outward.x, 0.0, outward.z))


## The top of the footway and of the kerb: the kerb's height above the road at its face.
func top(s: float) -> float:
	return at(s, half).y + kerb_high(s)


func _road(s: float, out: float) -> bool:
	var image: Image = _map.ground_image
	if image == null: return false
	var here := at(s, out)
	var centre := at(s, 0.0)
	var frame: Rect2 = _map.frame
	var a := Vector2i(clampi(int(here.x - frame.position.x), 0, image.get_width() - 1), clampi(int(here.z - frame.position.y), 0, image.get_height() - 1))
	var b := Vector2i(clampi(int(centre.x - frame.position.x), 0, image.get_width() - 1), clampi(int(centre.z - frame.position.y), 0, image.get_height() - 1))
	return image.get_pixelv(a).is_equal_approx(image.get_pixelv(b))


## One precast unit from s0 to s1: the gutter and the kerb, with both its ends.
func _unit(tool: SurfaceTool, s0: float, s1: float, inlet := false) -> void:
	# The outline across the street: metres out from the kerb's road face, metres above the
	# road at that face. Clockwise seen from the street's start on side +1.
	var outline: Array[Vector2] = [
		Vector2(-GUTTER_WIDE, -FOOT), Vector2(-GUTTER_WIDE, GUTTER_LIP), Vector2(0.0, GUTTER_LOW),
		Vector2(0.0, KERB_HIGH - CHAMFER), Vector2(CHAMFER, KERB_HIGH), Vector2(KERB_WIDE - CHAMFER, KERB_HIGH),
		Vector2(KERB_WIDE, KERB_HIGH - CHAMFER), Vector2(KERB_WIDE, -FOOT)]
	# At the drain inlet the unit is a kerb only: the grate takes the channel's place.
	if inlet:
		outline = outline.slice(2)
		outline[0] = Vector2(0.0, -FOOT)
	tool.set_color(CONCRETE)
	var y0 := at(s0, half).y
	var y1 := at(s1, half).y
	var near: Array[Vector3] = []
	var far: Array[Vector3] = []
	# At a lowered kerb the unit's top comes down with it: every point above the gutter is
	# lowered by as much as the kerb is, at each end by its own amount.
	var less0 := KERB_HIGH - kerb_high(s0)
	var less1 := KERB_HIGH - kerb_high(s1)
	for p: Vector2 in outline:
		var a := at(s0, half + p.x)
		var b := at(s1, half + p.x)
		var kerb_top := p.y > GUTTER_LIP + 0.001
		near.append(Vector3(a.x, y0 + p.y - (less0 if kerb_top else 0.0), a.z))
		far.append(Vector3(b.x, y1 + p.y - (less1 if kerb_top else 0.0), b.z))
	for i: int in outline.size() - 1: _quad(tool, near[i], near[i + 1], far[i + 1], far[i])
	# The two ends, seen through the joints. The outline has a step in it (gutter, then kerb),
	# so each end is closed in two pieces that have none: the gutter's, then the kerb's, both
	# fanned from the point under the kerb's face.
	var a0 := at(s0, half)
	var b0 := at(s1, half)
	var near_foot := Vector3(a0.x, y0 - FOOT, a0.z)
	var far_foot := Vector3(b0.x, y1 - FOOT, b0.z)
	for i: int in outline.size() - 1:
		if i == (0 if inlet else 2): continue      # the kerb's face runs through the fan's own point
		_tri(tool, near_foot, near[i + 1], near[i])
		_tri(tool, far_foot, far[i], far[i + 1])


## The footway of one stretch: its top, its back face and its two ends.
func _footway(tool: SurfaceTool, s0: float, s1: float) -> void:
	tool.set_color(FOOTWAY)
	var steps := maxi(int(round((s1 - s0) / UNIT)), 1)      # a unit at a time, so it dips with a lowered kerb
	var inner := half + KERB_WIDE
	var outer := half + footway_wide
	for i: int in steps:
		var a := lerpf(s0, s1, float(i) / float(steps))
		var b := lerpf(s0, s1, float(i + 1) / float(steps))
		var ia := _lifted(a, inner, top(a))
		var ib := _lifted(b, inner, top(b))
		var oa := _lifted(a, outer, top(a))
		var ob := _lifted(b, outer, top(b))
		if footway_material != null: _paved("Footway", [a, inner, ia.y], [a, outer, oa.y], [b, outer, ob.y], [b, inner, ib.y])
		else: _quad(tool, ia, oa, ob, ib)
		if forecourt <= 0.0:
			_quad(tool, oa, at(a, outer, -FOOT), at(b, outer, -FOOT), ob)
		else:
			# The forecourt: from the footway's back down to the ground at the shop fronts.
			tool.set_color(FORECOURT)
			var fa := at(a, outer + forecourt, FORECOURT_END)
			var fb := at(b, outer + forecourt, FORECOURT_END)
			if forecourt_material != null: _paved("Forecourt", [a, outer, oa.y], [a, outer + forecourt, fa.y], [b, outer + forecourt, fb.y], [b, outer, ob.y])
			else: _quad(tool, oa, fa, fb, ob)
			_quad(tool, fa, at(a, outer + forecourt, -FOOT), at(b, outer + forecourt, -FOOT), fb)
			tool.set_color(FOOTWAY)
	for s: float in [s0, s1]:
		var i0 := _lifted(s, inner, top(s))
		var o0 := _lifted(s, outer, top(s))
		if s == s0: _quad(tool, at(s, inner, -FOOT), at(s, outer, -FOOT), o0, i0)
		else: _quad(tool, i0, o0, at(s, outer, -FOOT), at(s, inner, -FOOT))
		if forecourt > 0.0:
			tool.set_color(FORECOURT)
			var f0 := at(s, outer + forecourt, FORECOURT_END)
			if s == s0: _quad(tool, at(s, outer, -FOOT), at(s, outer + forecourt, -FOOT), f0, o0)
			else: _quad(tool, o0, f0, at(s, outer + forecourt, -FOOT), at(s, outer, -FOOT))
			tool.set_color(FOOTWAY)


## ---- corners ----

func _round(cs: float, cout: float, dir: float, radius: float, angle: float) -> Vector2:
	return Vector2(cs + dir * radius * sin(angle), cout - radius * cos(angle))


func _high(point: Vector2) -> Vector3:
	return at(point.x, point.y, kerb_high(point.x))      # (a lowered kerb's slope may run into a corner)


## A triangle turned so that it faces `toward`.
func _facing(tool: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, toward: Vector3) -> void:
	tool.add_vertex(p)
	if (q - p).cross(r - p).dot(toward) * _cross_sign < 0.0:
		tool.add_vertex(r)
		tool.add_vertex(q)
	else:
		tool.add_vertex(q)
		tool.add_vertex(r)


## An upright face from the ground to the kerb's height between two points, facing `toward`.
func _upright(tool: SurfaceTool, a: Vector2, b: Vector2, toward: Vector3) -> void:
	_facing(tool, at(a.x, a.y, -FOOT), _high(a), _high(b), toward)
	_facing(tool, at(a.x, a.y, -FOOT), _high(b), at(b.x, b.y, -FOOT), toward)


## A piece of the footway's top between three points (metres along, metres out).
func _foot_tri(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	if footway_material == null:
		tool.set_color(FOOTWAY)
		_facing(tool, _high(a), _high(b), _high(c), Vector3.UP)
		return
	if not _tops.has("Footway"):
		var fresh := SurfaceTool.new()
		fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tops["Footway"] = fresh
	var paved: SurfaceTool = _tops["Footway"]
	var order: Array[Vector2] = [a, b, c]
	if (_high(b) - _high(a)).cross(_high(c) - _high(a)).y * _cross_sign < 0.0: order = [a, c, b]
	for point: Vector2 in order:
		paved.set_uv(Vector2(point.y - half, point.x))
		paved.add_vertex(_high(point))


func _foot_quad(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	_foot_tri(tool, a, b, c)
	_foot_tri(tool, a, c, d)


## One cast piece of gutter and kerb between two cross-sections. `near_of` and `far_of` give,
## for a distance in from the kerb's road face, the place (metres along, metres out).
func _piece(tool: SurfaceTool, near_of: Callable, far_of: Callable) -> void:
	var outline: Array[Vector2] = [
		Vector2(-GUTTER_WIDE, -FOOT), Vector2(-GUTTER_WIDE, GUTTER_LIP), Vector2(0.0, GUTTER_LOW),
		Vector2(0.0, KERB_HIGH - CHAMFER), Vector2(CHAMFER, KERB_HIGH), Vector2(KERB_WIDE - CHAMFER, KERB_HIGH),
		Vector2(KERB_WIDE, KERB_HIGH - CHAMFER), Vector2(KERB_WIDE, -FOOT)]
	tool.set_color(CONCRETE)
	var near: Array[Vector3] = []
	var far: Array[Vector3] = []
	for p: Vector2 in outline:
		var a: Vector2 = near_of.call(p.x)
		var b: Vector2 = far_of.call(p.x)
		var kerb_top := p.y > GUTTER_LIP + 0.001
		near.append(at(a.x, a.y, p.y - ((KERB_HIGH - kerb_high(a.x)) if kerb_top else 0.0)))
		far.append(at(b.x, b.y, p.y - ((KERB_HIGH - kerb_high(b.x)) if kerb_top else 0.0)))
	var n0: Vector2 = near_of.call(0.0)
	var n1: Vector2 = near_of.call(1.0)
	var f0: Vector2 = far_of.call(0.0)
	var inward := (at(n1.x, n1.y) - at(n0.x, n0.y)).normalized()
	var travel := (at(f0.x, f0.y) - at(n0.x, n0.y)).normalized()
	for i: int in outline.size() - 1:
		var step := outline[i + 1] - outline[i]
		var toward := inward * (-step.y) + Vector3.UP * step.x
		_facing(tool, near[i], near[i + 1], far[i + 1], toward)
		_facing(tool, near[i], far[i + 1], far[i], toward)
	# The two ends, each closed in two pieces fanned from the point under the kerb's face.
	var near_foot := at(n0.x, n0.y, -FOOT)
	var far_foot := at(f0.x, f0.y, -FOOT)
	for i: int in outline.size() - 1:
		if i == 2: continue
		_facing(tool, near_foot, near[i + 1], near[i], -travel)
		_facing(tool, far_foot, far[i], far[i + 1], travel)


## The kerb, gutter and footway round one corner into a side street, and what one stands on.
func _corner(look: SurfaceTool, stand: SurfaceTool, corner: Dictionary) -> void:
	var dir: float = corner.dir
	var mouth: float = corner.mouth
	var from: float = corner.from
	var radius := minf(CORNER_R, absf(mouth - from))
	var cs := mouth - dir * radius          # the circle's middle: along
	var cout := half + radius               # and out
	var back := half + footway_wide
	var centre := Vector2(cs, cout)
	# The cut unit between the last whole unit and the start of the curve.
	var lo := minf(from, cs)
	var hi := maxf(from, cs)
	if hi - lo > 0.05:
		_unit(look, lo + JOINT * 0.5, hi - JOINT * 0.5)
		_foot_quad(look, Vector2(lo, half + KERB_WIDE), Vector2(lo, back), Vector2(hi, back), Vector2(hi, half + KERB_WIDE))
		_facing(stand, _high(Vector2(lo, half)), _high(Vector2(lo, back)), _high(Vector2(hi, back)), Vector3.UP)
		_facing(stand, _high(Vector2(lo, half)), _high(Vector2(hi, back)), _high(Vector2(hi, half)), Vector3.UP)
		_upright(stand, Vector2(lo, half), Vector2(hi, half), at(lo, half - 1.0) - at(lo, half))
	# The curved pieces.
	for k: int in CORNER_PIECES:
		var a0 := PI * 0.5 * float(k) / float(CORNER_PIECES)
		var a1 := PI * 0.5 * float(k + 1) / float(CORNER_PIECES)
		var joint := JOINT * 0.5 / radius
		_piece(look,
			func(inward: float) -> Vector2: return _round(cs, cout, dir, radius - inward, a0 + joint),
			func(inward: float) -> Vector2: return _round(cs, cout, dir, radius - inward, a1 - joint))
		_foot_tri(look, centre, _round(cs, cout, dir, radius - KERB_WIDE, a0), _round(cs, cout, dir, radius - KERB_WIDE, a1))
		var f0 := _round(cs, cout, dir, radius, a0)
		var f1 := _round(cs, cout, dir, radius, a1)
		_facing(stand, _high(centre), _high(f0), _high(f1), Vector3.UP)
		_upright(stand, f0, f1, at(f0.x, f0.y) - at(cs, cout))
	# Straight on along the side street to the footway's back, where the kerb stops.
	var along_side := at(mouth + dir, back) - at(mouth, back)      # towards the side street
	if back - cout > 0.05:
		_piece(look,
			func(inward: float) -> Vector2: return Vector2(mouth - dir * inward, cout + JOINT * 0.5),
			func(inward: float) -> Vector2: return Vector2(mouth - dir * inward, back))
		_foot_quad(look, centre, Vector2(cs, back), Vector2(mouth - dir * KERB_WIDE, back), Vector2(mouth - dir * KERB_WIDE, cout))
		_facing(stand, _high(centre), _high(Vector2(cs, back)), _high(Vector2(mouth, back)), Vector3.UP)
		_facing(stand, _high(centre), _high(Vector2(mouth, back)), _high(Vector2(mouth, cout)), Vector3.UP)
		_upright(stand, Vector2(mouth, cout), Vector2(mouth, back), along_side)
	# The footway's back face round the corner. (A forecourt stops where the whole units do.)
	if true:
		var behind := at(from, back + 1.0) - at(from, back)
		look.set_color(FOOTWAY)
		_upright(look, Vector2(from, back), Vector2(mouth - dir * KERB_WIDE, back), behind)
		_upright(stand, Vector2(from, back), Vector2(mouth, back), behind)


## The rounded end of a footway that has road on both sides: the kerb and gutter carry on
## past the last unit by half the footway's width, then go round its end in a half circle.
func _nose(look: SurfaceTool, stand: SurfaceTool, dir: float) -> void:
	if runs.is_empty(): return
	var base: float = runs[0].x if dir < 0.0 else runs[runs.size() - 1].y
	var radius := nose_radius if nose_radius > 0.0 else footway_wide * 0.5
	var reach := nose_reach if nose_reach > 0.0 else radius * 2.0
	var cs := base + dir * (reach - radius)
	var cout := half + radius
	var back := half + footway_wide
	var centre := Vector2(cs, cout)
	var lo := minf(base, cs)
	var hi := maxf(base, cs)
	# The straight piece up to the half circle, and the footway behind it.
	_unit(look, lo + JOINT * 0.5, hi - JOINT * 0.5)
	_foot_quad(look, Vector2(lo, half + KERB_WIDE), Vector2(lo, back), Vector2(hi, back), Vector2(hi, half + KERB_WIDE))
	_facing(stand, _high(Vector2(lo, half)), _high(Vector2(lo, back)), _high(Vector2(hi, back)), Vector3.UP)
	_facing(stand, _high(Vector2(lo, half)), _high(Vector2(hi, back)), _high(Vector2(hi, half)), Vector3.UP)
	_upright(stand, Vector2(lo, half), Vector2(hi, half), at(lo, half - 1.0) - at(lo, half))
	var behind := at(base, back + 1.0) - at(base, back)
	look.set_color(FOOTWAY)
	_upright(look, Vector2(lo, back), Vector2(hi, back), behind)
	_upright(stand, Vector2(lo, back), Vector2(hi, back), behind)
	# The half circle, in pieces about as long as a corner's.
	var pieces := _nose_pieces(radius)
	for k: int in pieces:
		var a0 := PI * float(k) / float(pieces)
		var a1 := PI * float(k + 1) / float(pieces)
		var joint := JOINT * 0.5 / radius
		_piece(look,
			func(inward: float) -> Vector2: return _round(cs, cout, dir, radius - inward, a0 + joint),
			func(inward: float) -> Vector2: return _round(cs, cout, dir, radius - inward, a1 - joint))
		_foot_tri(look, centre, _round(cs, cout, dir, radius - KERB_WIDE, a0), _round(cs, cout, dir, radius - KERB_WIDE, a1))
		var f0 := _round(cs, cout, dir, radius, a0)
		var f1 := _round(cs, cout, dir, radius, a1)
		_facing(stand, _high(centre), _high(f0), _high(f1), Vector3.UP)
		_upright(stand, f0, f1, at(f0.x, f0.y) - at(cs, cout))


## A dead end: the lane stops at the boundary of the plot beyond it, a rendered wall across
## the carriageway and the footway, from the centre line to `reach` out, standing just past
## the end (`dir` +1: past the end, -1: before the start).
const END_WALL_THICK := 0.12
const END_WALL_HIGH := 1.2
const COPING_PROUD := 0.03
const COPING_HIGH := 0.06
const RENDER := Color(0.62, 0.61, 0.58)
var end_walls := 0

## ack: how far past the end the wall stands (0: at the end itself). Further back where a
## house's door would otherwise be cut off by it.
func end_wall(dir: float, reach: float, back: float = 0.0) -> void:
	if runs.is_empty(): return
	var edge_s: float = (runs[runs.size() - 1].y if dir > 0.0 else runs[0].x) + dir * back
	var s0 := edge_s if dir > 0.0 else edge_s - END_WALL_THICK
	var s1 := s0 + END_WALL_THICK
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var stand := SurfaceTool.new()
	stand.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_color(RENDER)
	_solid(tool, stand, s0, s1, 0.0, reach, -FOOT, END_WALL_HIGH)
	tool.set_color(RENDER.lightened(0.08))
	_solid(tool, stand, s0 - COPING_PROUD, s1 + COPING_PROUD, 0.0, reach + COPING_PROUD, END_WALL_HIGH, END_WALL_HIGH + COPING_HIGH)
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.94
	var wall := MeshInstance3D.new()
	wall.name = "EndWall%d" % end_walls
	wall.mesh = tool.commit()
	wall.material_override = material
	add_child(wall)
	var body := StaticBody3D.new()
	body.name = "EndWallBody%d" % end_walls
	var shape := CollisionShape3D.new()
	shape.shape = stand.commit().create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
	end_walls += 1


## A box between two places along (s), two out and two heights above the ground at the centre
## line's end, every face turned outwards.
func _solid(tool: SurfaceTool, stand: SurfaceTool, s0: float, s1: float, o0: float, o1: float, y0: float, y1: float) -> void:
	var ground := at(s0, 0.0).y
	var c: Array[Vector3] = []
	for corner: Array in [[s0, o0, y0], [s1, o0, y0], [s1, o1, y0], [s0, o1, y0], [s0, o0, y1], [s1, o0, y1], [s1, o1, y1], [s0, o1, y1]]:
		var p := at(float(corner[0]), float(corner[1]))
		c.append(Vector3(p.x, ground + float(corner[2]), p.z))
	var middle := Vector3.ZERO
	for p: Vector3 in c: middle += p / 8.0
	for face: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var q: Array[Vector3] = [c[int(face[0])], c[int(face[1])], c[int(face[2])], c[int(face[3])]]
		var toward := (q[0] + q[1] + q[2] + q[3]) / 4.0 - middle
		for target: SurfaceTool in [tool, stand]:
			_facing(target, q[0], q[1], q[2], toward)
			_facing(target, q[0], q[2], q[3], toward)


## The paving between this side's footway and another lane's, where the two lanes run so close
## that the ground between them would be a trench: from `out0` to `out1` (metres out from the
## centre line), `s0` to `s1` along. At footway height, with an upright face at each end.
func infill(s0: float, s1: float, out0: float, out1: float, outer_face: bool = false) -> void:
	var look := SurfaceTool.new()
	look.begin(Mesh.PRIMITIVE_TRIANGLES)
	look.set_smooth_group(-1)
	var stand := SurfaceTool.new()
	stand.begin(Mesh.PRIMITIVE_TRIANGLES)
	look.set_color(FOOTWAY)
	var steps := maxi(int(ceil((s1 - s0) / UNIT)), 1)
	for i: int in steps:
		var a := lerpf(s0, s1, float(i) / float(steps))
		var b := lerpf(s0, s1, float(i + 1) / float(steps))
		for tool: SurfaceTool in [look, stand]:
			_facing(tool, _high(Vector2(a, out0)), _high(Vector2(a, out1)), _high(Vector2(b, out1)), Vector3.UP)
			_facing(tool, _high(Vector2(a, out0)), _high(Vector2(b, out1)), _high(Vector2(b, out0)), Vector3.UP)
	var forward := at(s1, out0) - at(s0, out0)
	for tool: SurfaceTool in [look, stand]:
		_upright(tool, Vector2(s0, out0), Vector2(s0, out1), -forward)
		_upright(tool, Vector2(s1, out0), Vector2(s1, out1), forward)
		# (Where nothing stands along its outer edge, that edge's own face: the strip before a set-back end wall.)
		if outer_face: _upright(tool, Vector2(s0, out1), Vector2(s1, out1), at(s0, out1 + 1.0) - at(s0, out1))
	look.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	var instance := MeshInstance3D.new()
	instance.name = "Infill"
	instance.mesh = look.commit()
	instance.material_override = material
	add_child(instance)
	var body := StaticBody3D.new()
	body.name = "InfillBody"
	var shape := CollisionShape3D.new()
	shape.shape = stand.commit().create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


## Makes this edge the kerb round a turning circle: centre, the kerb face's radius, from one
## angle round to the other (radians, increasing), and the footway's width outside it.
func make_round(map: Node3D, centre: Vector2, kerb_r: float, from_angle: float, to_angle: float, footway: float) -> void:
	_map = map
	is_round = true
	side = -1.0      # (metres out grow away from the centre: faces are turned as on the -1 side of a line)
	half = kerb_r
	footway_wide = footway
	round_centre = centre
	round_from = from_angle
	runs.append(Vector2(0.0, (to_angle - from_angle) * kerb_r))


func fillet_pieces() -> int:
	return maxi(int(ceil(fillet_r * fillet_angle / 0.5)), 3)


func fillet_point(radius: float, angle: float) -> Vector2:
	return _round(fillet_at, half + fillet_r, 1.0, radius, angle)


## The flare from the straight kerb into a turning circle's: a curve of fillet_r with the road
## round its outside and the footway inside it, as wide as the straight footway, so its back
## runs smoothly from the straight footway's back to the circle's.
func _fillet(look: SurfaceTool, stand: SurfaceTool) -> void:
	var centre := Vector2(fillet_at, half + fillet_r)
	var pieces := fillet_pieces()
	var joint := JOINT * 0.5 / fillet_r
	for k: int in pieces:
		var a0 := fillet_angle * float(k) / float(pieces)
		var a1 := fillet_angle * float(k + 1) / float(pieces)
		_piece(look,
			func(inward: float) -> Vector2: return fillet_point(fillet_r - inward, a0 + joint),
			func(inward: float) -> Vector2: return fillet_point(fillet_r - inward, a1 - joint))
		_foot_quad(look, fillet_point(fillet_r - KERB_WIDE, a0), fillet_point(fillet_r - footway_wide, a0), fillet_point(fillet_r - footway_wide, a1), fillet_point(fillet_r - KERB_WIDE, a1))
		var f0 := fillet_point(fillet_r, a0)
		var f1 := fillet_point(fillet_r, a1)
		var b0 := fillet_point(fillet_r - footway_wide, a0)
		var b1 := fillet_point(fillet_r - footway_wide, a1)
		_facing(stand, _high(f0), _high(b0), _high(b1), Vector3.UP)
		_facing(stand, _high(f0), _high(b1), _high(f1), Vector3.UP)
		_upright(stand, f0, f1, at(f0.x, f0.y) - at(centre.x, centre.y))
		look.set_color(FOOTWAY)
		_upright(look, b0, b1, at(centre.x, centre.y) - at(b0.x, b0.y))
		_upright(stand, b0, b1, at(centre.x, centre.y) - at(b0.x, b0.y))
	# (At a street's own end the footway stops with the kerb: its end face, toward the cross road.)
	if fillet_end:
		var i0 := fillet_point(fillet_r - KERB_WIDE, fillet_angle)
		var o0 := fillet_point(fillet_r - footway_wide, fillet_angle)
		var onward := at(o0.x, o0.y + 1.0) - at(o0.x, o0.y)
		look.set_color(FOOTWAY)
		_upright(look, i0, o0, onward)
		_upright(stand, fillet_point(fillet_r, fillet_angle), o0, onward)


## The road's surface past the street's end, over `end_patch` (an outline in the world), on the
## ground as the ribbon is, in this street's own metres so its grain carries on from the ribbon's.
func _end_patch_asphalt() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := Geometry2D.triangulate_polygon(end_patch)
	# (Its metres along run on past the end in a straight line: along_of stops at the end, and
	# would stretch the grain into streaks.)
	var last := _points[_points.size() - 1]
	var ahead := (last - _points[_points.size() - 2]).normalized()
	var across := Vector2(-ahead.y, ahead.x) * side
	var length := _lengths[_lengths.size() - 1]
	for i: int in range(0, corners.size(), 3):
		var order: Array[Vector2] = [end_patch[corners[i]], end_patch[corners[i + 1]], end_patch[corners[i + 2]]]
		# (Turned to face up: clockwise seen from above, where +z is down the screen.)
		if (order[1] - order[0]).cross(order[2] - order[0]) < 0.0: order = [order[0], order[2], order[1]]
		for point: Vector2 in order:
			tool.set_uv(Vector2((point - last).dot(across), length + (point - last).dot(ahead)))
			tool.add_vertex(Vector3(point.x, float(_map.ground_height(point.x, point.y)) + ASPHALT_LIFT, point.y))
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "EndAsphalt"
	instance.mesh = tool.commit()
	var plain: ShaderMaterial = ASPHALT.duplicate()
	plain.set_shader_parameter("edge_line_offset", 1000.0)
	instance.material_override = plain
	add_child(instance)


## The road between an end corner's curve and the corner its two kerb lines would make: a fan
## from that corner (at the gutter's outer edge) round to the gutter's outer edge on the curve.
## The cross road's own painted surface lies beyond it.
func _end_corner_asphalt() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sharp := Vector2(fillet_at + fillet_r + GUTTER_WIDE, half - GUTTER_WIDE)
	var pieces := fillet_pieces()
	for k: int in pieces:
		var p0 := fillet_point(fillet_r + GUTTER_WIDE, fillet_angle * float(k) / float(pieces))
		var p1 := fillet_point(fillet_r + GUTTER_WIDE, fillet_angle * float(k + 1) / float(pieces))
		var order: Array[Vector2] = [sharp, p0, p1]
		var a := at(sharp.x, sharp.y)
		# (Turned to face up as the footway's own top is: see _facing.)
		if (at(p0.x, p0.y) - a).cross(at(p1.x, p1.y) - a).y * _cross_sign < 0.0: order = [sharp, p1, p0]
		for point: Vector2 in order:
			tool.set_uv(Vector2(point.y, point.x))
			tool.add_vertex(at(point.x, point.y, ASPHALT_LIFT))
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "CornerAsphalt"
	instance.mesh = tool.commit()
	var plain: ShaderMaterial = ASPHALT.duplicate()
	plain.set_shader_parameter("edge_line_offset", 1000.0)
	instance.material_override = plain
	add_child(instance)


## The road's surface over a turning circle: a fan from its centre to the outline that runs
## along the outer edge of every cast gutter piece round it (given in the world), and across
## the street where this side's ribbon stops. Grain in this side's own metres, so it carries on
## from the ribbon's.
func circle_asphalt(outline: PackedVector3Array, centre: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := at(0.0, 0.0)
	var heading := (at(1.0, 0.0) - origin).normalized()
	var outward := (at(0.0, 1.0) - origin).normalized()
	var points: Array[Vector3] = []
	for p: Vector3 in outline: points.append(Vector3(p.x, float(_map.ground_height(p.x, p.z)) + ASPHALT_LIFT, p.z))
	var middle := Vector3(centre.x, float(_map.ground_height(centre.x, centre.z)) + ASPHALT_LIFT, centre.z)
	for i: int in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var tri: Array[Vector3] = [middle, a, b]
		# (Godot's front faces wind clockwise seen from above.)
		if (a - middle).cross(b - middle).y > 0.0: tri = [middle, b, a]
		for p: Vector3 in tri:
			var flat := p - origin
			tool.set_uv(Vector2(flat.dot(outward), flat.dot(heading)))
			tool.add_vertex(p)
	tool.generate_normals()
	var no_line: ShaderMaterial = ASPHALT.duplicate()
	no_line.set_shader_parameter("edge_line_offset", 1000.0)
	var instance := MeshInstance3D.new()
	instance.name = "CircleAsphalt"
	instance.mesh = tool.commit()
	instance.material_override = no_line
	add_child(instance)


## One piece of a paved top on its own surface. Each corner: metres along, metres out, height.
func _paved(which: String, p0: Array, p1: Array, p2: Array, p3: Array) -> void:
	if not _tops.has(which):
		var fresh := SurfaceTool.new()
		fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tops[which] = fresh
	var tool: SurfaceTool = _tops[which]
	var corners: Array = [p0, p1, p2, p3]
	var order := PackedInt32Array([0, 1, 2, 0, 2, 3]) if side < 0.0 else PackedInt32Array([0, 2, 1, 0, 3, 2])
	for index: int in order:
		var corner: Array = corners[index]
		tool.set_uv(Vector2(float(corner[1]) - half, float(corner[0])))
		tool.add_vertex(_lifted(float(corner[0]), float(corner[1]), float(corner[2])))


## What one stands on: the kerb's face, the top from the kerb to the footway's back, the back
## face and the ends. Plain faces, no chamfer, so a foot meets a clean step.
func _standing(tool: SurfaceTool, s0: float, s1: float) -> void:
	var steps := maxi(int(round((s1 - s0) / UNIT)), 1)
	var outer := half + footway_wide
	for i: int in steps:
		var a := lerpf(s0, s1, float(i) / float(steps))
		var b := lerpf(s0, s1, float(i + 1) / float(steps))
		var fa := _lifted(a, half, top(a))
		var fb := _lifted(b, half, top(b))
		var oa := _lifted(a, outer, top(a))
		var ob := _lifted(b, outer, top(b))
		_quad(tool, at(a, half, -FOOT), fa, fb, at(b, half, -FOOT))
		_quad(tool, fa, oa, ob, fb)
		if forecourt <= 0.0: _quad(tool, oa, at(a, outer, -FOOT), at(b, outer, -FOOT), ob)
		else: _quad(tool, oa, at(a, outer + forecourt, FORECOURT_END), at(b, outer + forecourt, FORECOURT_END), ob)
	for s: float in [s0, s1]:
		var f := _lifted(s, half, top(s))
		var o := _lifted(s, outer, top(s))
		if s == s0: _quad(tool, at(s, half, -FOOT), at(s, outer, -FOOT), o, f)
		else: _quad(tool, f, o, at(s, outer, -FOOT), at(s, half, -FOOT))


func _lifted(s: float, out: float, height: float) -> Vector3:
	var point := at(s, out)
	return Vector3(point.x, height, point.z)


## Faces are given so that they show from outside on side +1; the other side is the mirror,
## so its faces are turned.
func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)


## The drain inlet in the gutter of one unit: an iron rim with bars across the channel (across,
## so a bicycle's tyre cannot drop between them), flush with the gutter's road edge, and the
## dark of the catch pit under them.
func _grate(tool: SurfaceTool, s0: float, s1: float) -> void:
	var level := GUTTER_LIP
	var inner := half - GUTTER_WIDE
	# The pit: a dark floor just under the bars. (The pit itself would be under the ground.)
	tool.set_color(PIT)
	_slab(tool, s0, s1, inner, half, level - 0.014, level - 0.013)
	tool.set_color(IRON)
	# The rim: two long sides and two ends.
	_slab(tool, s0, s1, inner, inner + GRATE_RIM, -FOOT, level)
	_slab(tool, s0, s1, half - GRATE_RIM, half, -FOOT, level)
	_slab(tool, s0, s0 + GRATE_RIM, inner + GRATE_RIM, half - GRATE_RIM, -FOOT, level)
	_slab(tool, s1 - GRATE_RIM, s1, inner + GRATE_RIM, half - GRATE_RIM, -FOOT, level)
	# The bars, across the channel, as many as fit at their pitch.
	var room := s1 - s0 - GRATE_RIM * 2.0
	var bars := int(floor((room - GRATE_PITCH + GRATE_BAR) / GRATE_PITCH))
	var first := s0 + GRATE_RIM + (room - float(bars - 1) * GRATE_PITCH - GRATE_BAR) * 0.5
	for i: int in bars:
		var a := first + float(i) * GRATE_PITCH
		_slab(tool, a, a + GRATE_BAR, inner + GRATE_RIM, half - GRATE_RIM, level - 0.012, level)
	# One tie bar along the middle, under the bars' tops, holding them.
	var mid := (inner + half) * 0.5
	_slab(tool, s0 + GRATE_RIM, s1 - GRATE_RIM, mid - 0.004, mid + 0.004, level - 0.012, level - 0.003)


## A block from s0 to s1 along, out0 to out1 across, low to high above the road at the kerb's
## face: its top and its four sides.
func _slab(tool: SurfaceTool, s0: float, s1: float, out0: float, out1: float, low: float, high: float) -> void:
	var y0 := at(s0, half).y
	var y1 := at(s1, half).y
	var a := _lifted(s0, out0, y0 + high)
	var b := _lifted(s0, out1, y0 + high)
	var c := _lifted(s1, out1, y1 + high)
	var d := _lifted(s1, out0, y1 + high)
	var al := _lifted(s0, out0, y0 + low)
	var bl := _lifted(s0, out1, y0 + low)
	var cl := _lifted(s1, out1, y1 + low)
	var dl := _lifted(s1, out0, y1 + low)
	_quad(tool, a, b, c, d)
	_quad(tool, al, bl, b, a)
	_quad(tool, bl, cl, c, b)
	_quad(tool, cl, dl, d, c)
	_quad(tool, dl, al, a, d)


## The utility pole: a tapered concrete shaft out of the footway, a galvanised cable riser
## clamped to it by two bands, and a cross-arm with three insulators near the top. No wires:
## they wait for the rest of the pole line.
func _pole(tool: SurfaceTool) -> void:
	var foot := _lifted(pole_at, pole_out, top(pole_at))
	var along := (at(pole_at + 1.0, 0.0) - at(pole_at, 0.0)).normalized()
	var across := (at(pole_at, 1.0) - at(pole_at, 0.0)).normalized()
	tool.set_smooth_group(1)
	tool.set_color(POLE_CONCRETE)
	_tube(tool, foot, POLE_FOOT_RADIUS, foot + Vector3.UP * POLE_HIGH, POLE_TOP_RADIUS, 18, true)
	# The riser: a steel pipe up the pole's down-street side, for the cable that goes
	# underground to a house.
	tool.set_color(GALVANISED)
	var pipe_foot := foot + along * (POLE_FOOT_RADIUS + 0.03)
	var lean := (POLE_FOOT_RADIUS - POLE_TOP_RADIUS) / POLE_HIGH
	var pipe_top := pipe_foot + Vector3.UP * 3.2 - along * lean * 3.2
	_tube(tool, pipe_foot, 0.027, pipe_top, 0.027, 10, true)
	# Two bands round the pole, each with a clamp round the pipe.
	for high: float in [0.9, 2.4]:
		var radius := POLE_FOOT_RADIUS - lean * high + 0.004
		_tube(tool, foot + Vector3.UP * high, radius, foot + Vector3.UP * (high + 0.03), radius - lean * 0.03, 18, false)
		var clamp_foot := pipe_foot + Vector3.UP * high - along * lean * high
		_tube(tool, clamp_foot, 0.031, clamp_foot + Vector3.UP * 0.03, 0.031, 10, false)
	tool.set_smooth_group(-1)
	# The cross-arm, across the street's direction, and its three insulators.
	var arm := foot + Vector3.UP * (POLE_HIGH - 0.6) + along * (POLE_TOP_RADIUS + 0.05)
	_box(tool, arm, along * 0.0375, Vector3.UP * 0.0375, across * side * 0.9)
	tool.set_smooth_group(2)
	tool.set_color(PORCELAIN)
	for offset: float in [-0.75, -0.3, 0.6]:
		var seat := arm + across * offset + Vector3.UP * 0.0375
		_tube(tool, seat, 0.045, seat + Vector3.UP * 0.13, 0.03, 10, true)
	tool.set_smooth_group(-1)


## A round bar from one point up to another, its radius changing between them; `capped` closes
## its top.
func _tube(tool: SurfaceTool, low: Vector3, low_radius: float, high: Vector3, high_radius: float, sides: int, capped: bool) -> void:
	for i: int in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		_face(tool, low + d0 * low_radius, high + d1 * high_radius, high + d0 * high_radius)
		_face(tool, low + d0 * low_radius, low + d1 * low_radius, high + d1 * high_radius)
		if capped: _face(tool, high, high + d1 * high_radius, high + d0 * high_radius)


## A box about a middle point, given its three half-extents as vectors (x, y, z in turn, a
## right-handed set).
func _box(tool: SurfaceTool, middle: Vector3, x: Vector3, y: Vector3, z: Vector3) -> void:
	for axis: Array in [[x, y, z], [y, z, x], [z, x, y]]:
		for way: float in [1.0, -1.0]:
			var n: Vector3 = (axis[0] as Vector3) * way
			var u: Vector3 = axis[1]
			var v: Vector3 = (axis[2] as Vector3) * way
			_face(tool, middle + n - u - v, middle + n + u + v, middle + n + u - v)
			_face(tool, middle + n - u - v, middle + n - u + v, middle + n + u + v)


## A triangle given the same way round on both sides of the street (the pole is no mirror).
func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


## Each side street this edge turns into, as the stretch of the street it takes up: from where
## the whole kerb units stop before it to where they start again after it. (A mouth with a
## corner at both ends; known once the edge is laid.)
func mouth_zones() -> Array[Vector2]:
	var zones: Array[Vector2] = []
	for a: Dictionary in corners:
		if float(a.dir) < 0.0: continue
		var best := {}
		for b: Dictionary in corners:
			if float(b.dir) > 0.0 or float(b.mouth) <= float(a.mouth): continue
			if best.is_empty() or float(b.mouth) < float(best.mouth): best = b
		if best.is_empty(): continue
		var between := false
		for run: Vector2 in runs:
			if run.x > float(a.from) - 0.01 and run.y < float(best.from) + 0.01: between = true
		if not between: zones.append(Vector2(float(a.from), float(best.from)))
	# A mouth with a corner on one side only (the other side of the lane has no footway to turn
	# onto): its other edge is the lane's own, from the map's line.
	for corner: Dictionary in corners:
		var from := float(corner.from)
		if float(corner.dir) > 0.0 and not zones.any(func(z: Vector2) -> bool: return is_equal_approx(z.x, from)):
			for crossing: Vector3 in _crossings:
				if is_equal_approx(crossing.x, float(corner.mouth)): zones.append(Vector2(from, crossing.y))
		if float(corner.dir) < 0.0 and not zones.any(func(z: Vector2) -> bool: return is_equal_approx(z.y, from)):
			for crossing: Vector3 in _crossings:
				if is_equal_approx(crossing.y, float(corner.mouth)): zones.append(Vector2(crossing.x, from))
	return zones


## The road's surface in the mouth of each side street: from the gutter line out past the
## footway's back, round the two corners' gutters. The same asphalt, with no line.
func _mouth_asphalt() -> void:
	var zones := mouth_zones()
	if zones.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near := half - GUTTER_WIDE
	var back := half + footway_wide
	for zone: Vector2 in zones:
		var a := {}
		var b := {}
		for corner: Dictionary in corners:
			if is_equal_approx(float(corner.from), zone.x) and float(corner.dir) > 0.0: a = corner
			if is_equal_approx(float(corner.from), zone.y) and float(corner.dir) < 0.0: b = corner
		if a.is_empty() and b.is_empty(): continue
		var pair: Array = []
		for corner: Dictionary in [a, b]:
			if not corner.is_empty(): pair.append(corner)
		# (Where the side street is built too, this surface stops at the footway's back, where
		# that street's own begins.)
		var far := back + MOUTH_DEEP
		for corner: Dictionary in pair: far = minf(far, back + float(corner.get("deep", MOUTH_DEEP)))
		# Fine steps round the curves, coarse ones across the open mouth.
		var cuts: Array[float] = []
		var s := zone.x
		while s < zone.y - 0.001:
			cuts.append(s)
			var fine := false
			for corner: Dictionary in pair:
				if absf(s - float(corner.mouth)) < CORNER_R + GUTTER_WIDE + 0.3: fine = true
			s += 0.06 if fine else 0.5
		cuts.append(zone.y)
		# And a cut exactly where each curve starts, where the side street's edge is, and where
		# the gutter of the corner's straight return ends, so no piece straddles one of them.
		for corner: Dictionary in pair:
			var dir: float = corner.dir
			var radius := minf(CORNER_R, absf(float(corner.mouth) - float(corner.from)))
			for mark: float in [float(corner.mouth) - dir * radius, float(corner.mouth), float(corner.mouth) + dir * GUTTER_WIDE]:
				if mark > zone.x + 0.001 and mark < zone.y - 0.001: cuts.append(mark)
			# And at the end of each cast piece of the curve's gutter.
			for k: int in range(1, CORNER_PIECES):
				var piece_end := float(corner.mouth) - dir * radius + dir * (radius + GUTTER_WIDE) * sin(PI * 0.5 * float(k) / float(CORNER_PIECES))
				if piece_end > zone.x + 0.001 and piece_end < zone.y - 0.001: cuts.append(piece_end)
		# And fine cuts across any nose that stands in this mouth, with exact ones at its bounds.
		for hole: Dictionary in mouth_holes:
			var ring := float(hole.radius) + GUTTER_WIDE
			var middle := float(hole.s)
			if middle < zone.x or middle > zone.y: continue
			# (The gutter round a nose is cast in straight pieces: a cut at each piece's end, so the
			# asphalt meets the concrete along the pieces' own outer edges, not along the circle.)
			var pieces := _nose_pieces(float(hole.radius))
			for k: int in pieces + 1:
				var mark := middle + float(hole.kerb) * ring * cos(PI * float(k) / float(pieces))
				if mark > zone.x + 0.001 and mark < zone.y - 0.001: cuts.append(mark)
			var bare := middle - float(hole.kerb) * float(hole.radius)
			if bare > zone.x + 0.001 and bare < zone.y - 0.001: cuts.append(bare)
		cuts.sort()
		for i: int in cuts.size() - 1:
			var s0 := cuts[i]
			var s1 := cuts[i + 1]
			if s1 - s0 < 0.0005: continue
			var hole0 := _hole_span(s0 + 0.0002)
			var hole1 := _hole_span(s1 - 0.0002)
			if hole0.x < INF and hole1.x < INF:
				# Round a nose: the asphalt up to its gutter, and again behind it where it ends.
				var top0 := minf(_mouth_reach(pair, s0 + 0.0002, far).x, hole0.x)
				var top1 := minf(_mouth_reach(pair, s1 - 0.0002, far).x, hole1.x)
				if top0 > near + 0.001 or top1 > near + 0.001:
					_road_shape(tool, [[s0, near], [s0, maxf(top0, near)], [s1, maxf(top1, near)], [s1, near]])
				if hole0.y < far - 0.001 and hole1.y < far - 0.001:
					_road_shape(tool, [[s0, hole0.y], [s0, far], [s1, far], [s1, hole1.y]])
				continue
			# How far out the asphalt reaches from the gutter line at each end of the piece
			# (taken just inside the piece, so a boundary belongs to one piece only).
			var reach0 := _mouth_reach(pair, s0 + 0.0002, far)
			var reach1 := _mouth_reach(pair, s1 - 0.0002, far)
			if reach0.x > near + 0.001 or reach1.x > near + 0.001:
				_road_shape(tool, [[s0, near], [s0, maxf(reach0.x, near)], [s1, maxf(reach1.x, near)], [s1, near]])
		# Behind each corner's straight return, between the side street's edge and the end of
		# the return's gutter: the strip from the footway's back outwards, laid between its
		# exact bounds.
		for corner: Dictionary in pair:
			var dir: float = corner.dir
			var edge := float(corner.mouth)
			var strip_from := minf(edge, edge + dir * GUTTER_WIDE)
			if far - back > 0.01: _road_shape(tool, [[strip_from, back], [strip_from, far], [strip_from + GUTTER_WIDE, far], [strip_from + GUTTER_WIDE, back]])
	tool.generate_normals()
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0: return
	var no_line: ShaderMaterial = ASPHALT.duplicate()
	no_line.set_shader_parameter("edge_line_offset", 1000.0)
	var instance := MeshInstance3D.new()
	instance.name = "MouthAsphalt"
	instance.mesh = mesh
	instance.material_override = no_line
	add_child(instance)


## How many straight pieces the kerb round a nose of this radius is cast in.
func _nose_pieces(radius: float) -> int:
	return maxi(int(ceil(PI * radius / 0.36)), 4)


## Where a nose's gutter stops this edge's mouth asphalt at `s`: x = where the asphalt must end
## (metres out), y = where it may begin again behind the nose (INF if the nose's footway runs
## on behind). Both INF where no nose stands.
func _hole_span(s: float) -> Vector2:
	for hole: Dictionary in mouth_holes:
		var ring := float(hole.radius) + GUTTER_WIDE
		var offset := s - float(hole.s)
		if absf(offset) >= ring: continue
		# The gutter's outer edge is the straight pieces' own: between the ends of the piece
		# this place lies under.
		var pieces := _nose_pieces(float(hole.radius))
		var reach := 0.0
		for k: int in pieces:
			var a0 := PI * float(k) / float(pieces)
			var a1 := PI * float(k + 1) / float(pieces)
			var x0 := float(hole.kerb) * ring * cos(a0)
			var x1 := float(hole.kerb) * ring * cos(a1)
			if (offset - x0) * (offset - x1) <= 0.0 and not is_equal_approx(x0, x1):
				reach = lerpf(ring * sin(a0), ring * sin(a1), (offset - x0) / (x1 - x0))
				break
		# On the kerb's side of the middle, and under the footway, the nose runs on behind. Past
		# the footway's bare back the half circle's gutter ends square at the middle's line.
		var under := offset * float(hole.kerb) > -float(hole.radius) or bool(hole.get("closed", false))
		return Vector2(float(hole.out) - reach, INF if under else float(hole.out))
	return Vector2(INF, INF)


## At `s` in a side street's mouth: x = how far out the asphalt reaches from the gutter line
## before a corner's gutter stops it (`far` if nothing does); y = where it begins again behind
## a corner's straight return (`far` if it does not).
func _mouth_reach(pair: Array, s: float, far: float) -> Vector2:
	var reach := far
	var again := far
	var outer := CORNER_R + GUTTER_WIDE
	for corner: Dictionary in pair:
		var dir: float = corner.dir
		var radius := minf(CORNER_R, absf(float(corner.mouth) - float(corner.from)))
		var u := (s - (float(corner.mouth) - dir * radius)) * dir      # into the mouth from the curve's start
		var ring := radius + GUTTER_WIDE
		if u <= 0.0:
			reach = minf(reach, half - GUTTER_WIDE)
		elif u < ring:
			# The corner's gutter is cast in straight pieces: its outer edge at this place lies
			# between the ends of the piece it is under, not on the circle.
			var depth := 0.0
			for k: int in CORNER_PIECES:
				var a0 := PI * 0.5 * float(k) / float(CORNER_PIECES)
				var a1 := PI * 0.5 * float(k + 1) / float(CORNER_PIECES)
				if u >= ring * sin(a0) and u <= ring * sin(a1):
					depth = lerpf(ring * cos(a0), ring * cos(a1), (u - ring * sin(a0)) / (ring * sin(a1) - ring * sin(a0)))
					break
			reach = minf(reach, half + radius - depth)
			if u >= radius: again = minf(again, half + footway_wide)
	if reach >= far: again = far
	return Vector2(reach, again)


## A four-cornered piece of road surface from corners given as [metres along, metres out],
## in the order (s0, low), (s0, high), (s1, high), (s1, low).
func _road_shape(tool: SurfaceTool, corners_of: Array) -> void:
	var order := PackedInt32Array([0, 1, 2, 0, 2, 3]) if side < 0.0 else PackedInt32Array([0, 2, 1, 0, 3, 2])
	for index: int in order:
		var s: float = corners_of[index][0]
		var out: float = corners_of[index][1]
		tool.set_uv(Vector2(out, s))
		tool.add_vertex(at(s, out, ASPHALT_LIFT))


## The asphalt: a ribbon over the road's width that follows the ground, with the white line
## beside the gutter along each built stretch and none across a side street's mouth.
func _asphalt() -> void:
	var length := _lengths[_lengths.size() - 1]
	var own := length       # (the street's own length: an end corner's ribbon runs on past it)
	if ribbon_end >= 0.0: length = ribbon_end if fillet_end else minf(length, ribbon_end)
	var marks: Array[float] = [0.0, own]
	for run: Vector2 in runs: marks.append_array([run.x, run.y])
	for run: Vector2 in opposite_runs: marks.append_array([run.x, run.y])
	var zones := mouth_zones()
	for zone: Vector2 in zones: marks.append_array([zone.x, zone.y])
	for zone: Vector2 in opposite_zones: marks.append_array([zone.x, zone.y])
	marks.append(length)
	marks.sort()
	var lined := SurfaceTool.new()
	lined.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plain := SurfaceTool.new()
	plain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_plain := false
	for i: int in marks.size() - 1:
		# (Only over the street's own length: a run may reach past an end, towards an island's
		# nose in another street's mouth, where that street's surface lies.)
		var s0 := clampf(marks[i], 0.0, length)
		var s1 := clampf(marks[i + 1], 0.0, length)
		if s1 - s0 < 0.01: continue
		var middle := (s0 + s1) * 0.5
		var built := _in_gutter_run(middle, runs)
		var tool := lined if built else plain
		if not built: any_plain = true
		# Up to the gutter where there is one, to the road's edge where there is not.
		# (And to the gutter line across a side street's mouth: the mouth's own surface starts there.)
		var edge := (half - GUTTER_WIDE) if (built or _in_gutter_run(middle, zones)) else half
		var opposite := -half + GUTTER_WIDE if (_in_gutter_run(middle, opposite_runs) or _in_gutter_run(middle, opposite_zones)) else -half
		# (Past an end corner's start, out to the cross road's kerb line: between the two curves'
		# gutters, each side's own patch filling from its gutter round to the corner.)
		if fillet_end and middle > own:
			edge = half - GUTTER_WIDE
			opposite = -half + GUTTER_WIDE
		var strips: Array = [[opposite, -half * 0.5, 0.0, half * 0.5, edge]] if median <= 0.0 else [[opposite, -median], [median, edge]]
		var steps := maxi(int(ceil((s1 - s0) / 1.25)), 1)
		for step: int in steps:
			var a := lerpf(s0, s1, float(step) / float(steps))
			var b := lerpf(s0, s1, float(step + 1) / float(steps))
			for across: Array in strips:
				for column: int in across.size() - 1:
					_road_quad(tool, a, b, float(across[column]), float(across[column + 1]))
	var mesh := ArrayMesh.new()
	lined.generate_normals()
	lined.commit(mesh)
	var with_line: ShaderMaterial = ASPHALT.duplicate()
	with_line.set_shader_parameter("edge_line_offset", line_out if _edge_line else 1000.0)
	with_line.set_shader_parameter("line_width", LINE_WIDE)
	mesh.surface_set_material(0, with_line)
	if any_plain:
		plain.generate_normals()
		plain.commit(mesh)
		var no_line: ShaderMaterial = ASPHALT.duplicate()
		no_line.set_shader_parameter("edge_line_offset", 1000.0)
		mesh.surface_set_material(1, no_line)
	var instance := MeshInstance3D.new()
	instance.name = "Asphalt"
	instance.mesh = mesh
	add_child(instance)


func _in_gutter_run(distance: float, stretches: Array[Vector2]) -> bool:
	for stretch: Vector2 in stretches:
		if distance >= stretch.x and distance <= stretch.y: return true
	return false


func _road_quad(tool: SurfaceTool, s0: float, s1: float, o0: float, o1: float) -> void:
	var corners: Array = [[s0, o0], [s0, o1], [s1, o1], [s1, o0]]
	var order := PackedInt32Array([0, 1, 2, 0, 2, 3]) if side < 0.0 else PackedInt32Array([0, 2, 1, 0, 3, 2])
	for index: int in order:
		var s: float = corners[index][0]
		var out: float = corners[index][1]
		tool.set_uv(Vector2(out, s))
		tool.add_vertex(at(s, out, ASPHALT_LIFT))


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	if side < 0.0:
		tool.add_vertex(b)
		tool.add_vertex(c)
	else:
		tool.add_vertex(c)
		tool.add_vertex(b)
