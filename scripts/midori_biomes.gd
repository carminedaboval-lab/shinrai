extends RefCounted
## Midori Park biomes (docs/PARK_BIOME_PLAN.md, docs/biome_concepts/).
## One soft map of themed grounds laid over the lapsed park. It runs once the
## raid has finished booting, so no producer's placement or random sequence
## changes. It does three things:
##  1. bakes two look maps (2 m per pixel) the shared ground shader reads,
##  2. injects that look into the ground shader, before the worn-path pass,
##  3. hands each biome's area to its own builder (scripts/biomes/*.gd), which
##     thins what does not belong there and adds what does.
## Edges are feathered and wobbled by noise, never drawn as lines.

const Budget := preload("res://scripts/shinrai_loading_budget.gd")
const StartupTrace := preload("res://scripts/startup_trace.gd")
const ORIGIN := Vector2(-220.0, -180.0)
const SIZE := Vector2(440.0, 360.0)
const RES := 0.5 # look-map pixels per metre

# Look channels. A: leaf litter, care (0 tended, .5 today, 1 overgrown), moss,
# wet. B: pine needles, meadow straw, petals, peat.
const LOOKS := {
	"momiji": [1.0, 0.55, 0.08, 0.0, 0.0, 0.0, 0.0, 0.0],
	"zoki": [0.22, 0.68, 0.55, 0.05, 0.0, 0.0, 0.0, 0.0],
	"matsu": [0.05, 0.4, 0.04, 0.0, 1.0, 0.0, 0.0, 0.0],
	"koke": [0.05, 0.2, 1.0, 0.1, 0.0, 0.0, 0.0, 0.0],
	"mizube": [0.1, 0.62, 0.45, 0.8, 0.0, 0.0, 0.0, 1.0],
	"hanami": [0.0, 0.22, 0.0, 0.0, 0.0, 0.0, 0.08, 0.0],
	"sando": [0.0, 0.0, 0.2, 0.0, 0.0, 0.0, 0.08, 0.0],
	"harappa": [0.0, 0.72, 0.05, 0.0, 0.0, 0.35, 0.0, 0.0],
	"yard": [0.22, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
}

# World metres; north is -z. Feather is the soft edge width in metres.
const REGIONS := [
	{"id":"momiji", "shape":"ellipse", "c":Vector2(110, -148), "r":Vector2(70, 30), "f":14.0},
	{"id":"yard", "shape":"ellipse", "c":Vector2(152, -146), "r":Vector2(24, 16), "f":8.0},
	{"id":"matsu", "shape":"ellipse", "c":Vector2(-150, -62), "r":Vector2(64, 52), "f":15.0},
	{"id":"matsu", "shape":"ellipse", "c":Vector2(-104, -140), "r":Vector2(38, 32), "f":15.0},
	{"id":"matsu", "shape":"ellipse", "c":Vector2(185, 40), "r":Vector2(26, 29), "f":10.0},
	{"id":"zoki", "shape":"rect", "x":Vector2(-86, 40), "z":Vector2(-178, -50), "f":12.0},
	{"id":"koke", "shape":"ellipse", "c":Vector2(-14, 20), "r":Vector2(44, 40), "f":12.0},
	{"id":"koke", "shape":"ellipse", "c":Vector2(24, -114), "r":Vector2(18, 18), "f":6.0},
	{"id":"hanami", "shape":"ellipse", "c":Vector2(20, 138), "r":Vector2(96, 40), "f":15.0},
	{"id":"sando", "shape":"ellipse", "c":Vector2(168, 128), "r":Vector2(46, 40), "f":9.0},
	{"id":"harappa", "shape":"ellipse", "c":Vector2(-152, 104), "r":Vector2(66, 74), "f":15.0},
]
# Later regions win where they overlap earlier ones; the shore band wins over all.
const SHORE_FULL_M := 8.0
const SHORE_EDGE_M := 14.0
# Lake bounds plus the shore band; points outside skip the shoreline search.
const LAKE_NEAR := Rect2(10.0, -155.0, 166.0, 272.0)
const BUILDERS := [
	"res://scripts/biomes/maple_glen.gd",
	"res://scripts/biomes/north_coppice.gd",
	"res://scripts/biomes/pine_woods.gd",
	"res://scripts/biomes/moss_garden.gd",
	"res://scripts/biomes/sakura_lawn.gd",
	"res://scripts/biomes/shrine_approach.gd",
	"res://scripts/biomes/meadow.gd",
	# Last: its thinning is keyed on the shore band and must follow the others.
	"res://scripts/biomes/iris_shore.gd",
]

static var _noise: FastNoiseLite

static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 52031
		_noise.frequency = 0.035
		_noise.fractal_octaves = 3
	return _noise

## Weight 0..1 of one region at a world point, feathered and wobbled.
static func region_weight(region: Dictionary, p: Vector2) -> float:
	var outside: float
	if region.shape == "ellipse":
		var r: Vector2 = region.r
		var c: Vector2 = region.c
		var d: float = ((p - c) / r).length()
		outside = (d - 1.0) * (r.x + r.y) * 0.5
	else:
		var x: Vector2 = region.x
		var z: Vector2 = region.z
		var q := Vector2(maxf(x.x - p.x, p.x - x.y), maxf(z.x - p.y, p.y - z.y))
		outside = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	var f: float = region.f
	outside += noise().get_noise_2dv(p) * f * 0.45
	return 1.0 - smoothstep(-f * 0.5, f * 0.5, outside)

## Per-biome weights at a world point. Missing ids are zero; "base" gets the rest.
static func weights_at(p: Vector2, terrain: Object = null) -> Dictionary:
	var out := {}
	var left := 1.0
	if terrain != null and terrain.shoreline.size() > 2 and LAKE_NEAR.has_point(p) and not terrain.water_at(p):
		# Beyond SHORE_CAP_M the band weight is 0 whatever the noise adds, as it
		# always was; below it this is terrain.edge_distance() exactly.
		var shore: float = shore_distance(terrain, p, SHORE_CAP_M)
		if shore < SHORE_CAP_M:
			shore += noise().get_noise_2dv(p * 1.7) * 3.0
			var w := 1.0 - smoothstep(SHORE_FULL_M, SHORE_EDGE_M, shore)
			if w > 0.0:
				out["mizube"] = w
				left -= w
	var stack := {}
	for region: Dictionary in REGIONS:
		var w: float = region_weight(region, p)
		if w <= 0.0: continue
		var id: String = region.id
		# Later regions take their share from earlier ones.
		for key: String in stack.keys(): stack[key] *= 1.0 - w
		stack[id] = maxf(float(stack.get(id, 0.0)), w)
	for id: String in stack:
		out[id] = float(out.get(id, 0.0)) + stack[id] * left
	var used := 0.0
	for id: String in out: used += out[id]
	out["base"] = maxf(0.0, 1.0 - used)
	return out

# ------------------------------------------------------------ shore distance
## The shoreline search is the costly part of weights_at (a scripted loop over
## its ~200 segments per point, for every point near the lake), and the bake,
## the builders' grids and their thinning ask for weights hundreds of
## thousands of times. shore_distance() answers from a 4 m cell table over
## LAKE_NEAR: per cell, the segments that can hold the nearest point for some
## p in that cell (centre distance minus the half diagonal no more than the
## smallest centre distance plus the half diagonal, or than SHORE_CAP_M).
## The others are provably farther, so the minimum over a cell's list, each
## distance worked out exactly as terrain.edge_distance() does (same call,
## same arguments), is the same float whenever it is below the cap; a cell
## with no segment within the cap answers INF. Outside the table it falls back
## to every segment. Checked against edge_distance on 180,000 points (scratch
## speed\biomes\pc\shore_test.gd): no difference.
## Noise adds at most 3 m to the shore distance and past 14 m the band is 0,
## so at 30 m and beyond weights_at needs no exact value.
const SHORE_CAP_M := 30.0
const SHORE_CELL_M := 4.0
const SHORE_EPS_M := 0.01 # far above float error of the per-segment distances
static var _shore_lock := Mutex.new()
static var _shore_poly := PackedVector2Array()
static var _shore_table: Array = [] # cell index -> PackedInt32Array of segment starts
static var _shore_origin := Vector2i.ZERO # first cell (x, z)
static var _shore_size := Vector2i.ZERO # cells across

## The cell table for `poly`, built once (and again only if the shoreline
## changes). Locked, so the first caller may be a WorkerThreadPool thread; a
## built table is never written again, only replaced.
static func _shore_index(poly: PackedVector2Array) -> Array:
	# Published table for this very polygon: read without the lock. The table
	# is written once (under the lock, before _shore_poly is set) and only
	# replaced when the shoreline changes, which never happens while workers run
	# (the shore is final once the terrain is installed). The lock used to be
	# taken on every call, so the row tasks of the bake and the builder grids
	# queued behind one another near the lake.
	if not _shore_table.is_empty() and _shore_poly == poly: return _shore_table
	_shore_lock.lock()
	if _shore_table.is_empty() or _shore_poly != poly:
		var n := poly.size()
		var first := Vector2i(floori(LAKE_NEAR.position.x / SHORE_CELL_M) - 1, floori(LAKE_NEAR.position.y / SHORE_CELL_M) - 1)
		var last := Vector2i(floori(LAKE_NEAR.end.x / SHORE_CELL_M) + 1, floori(LAKE_NEAR.end.y / SHORE_CELL_M) + 1)
		var size := last - first + Vector2i.ONE
		var half := SHORE_CELL_M * 0.5 * sqrt(2.0)
		var table: Array = []
		table.resize(size.x * size.y)
		var centre_d := PackedFloat64Array()
		centre_d.resize(n)
		for z: int in range(size.y):
			for x: int in range(size.x):
				var c := (Vector2(first + Vector2i(x, z)) + Vector2(0.5, 0.5)) * SHORE_CELL_M
				var nearest := INF
				for i: int in range(n):
					var d := c.distance_to(Geometry2D.get_closest_point_to_segment(c, poly[i], poly[(i + 1) % n]))
					centre_d[i] = d
					nearest = minf(nearest, d)
				var keep_below := minf(nearest + half, SHORE_CAP_M) + SHORE_EPS_M
				var list := PackedInt32Array()
				for i: int in range(n):
					if centre_d[i] - half <= keep_below: list.append(i)
				table[z * size.x + x] = list
		_shore_origin = first
		_shore_size = size
		_shore_table = table
		_shore_poly = poly
	var out := _shore_table
	_shore_lock.unlock()
	return out

## terrain.edge_distance(p, terrain.shoreline) when that is below `cap`
## (cap <= SHORE_CAP_M); otherwise a value >= cap.
static func shore_distance(terrain: Object, p: Vector2, cap: float) -> float:
	var poly: PackedVector2Array = terrain.shoreline
	var n := poly.size()
	if n == 0: return INF
	var table := _shore_index(poly)
	var cell := Vector2i(floori(p.x / SHORE_CELL_M), floori(p.y / SHORE_CELL_M)) - _shore_origin
	var best := INF
	if cap > SHORE_CAP_M or cell.x < 0 or cell.y < 0 or cell.x >= _shore_size.x or cell.y >= _shore_size.y:
		for i: int in range(n):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n])))
		return best
	for i: int in (table[cell.y * _shore_size.x + cell.x] as PackedInt32Array):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % n])))
	return best

## weights_at(p, terrain)[id] (0 when absent), worked out for that one id with
## the same float operations in the same order and no Dictionary per call: the
## builders ask this hundreds of thousands of times, partly on worker threads,
## where the two dictionaries weights_at builds per point (and the key list per
## region) made the heap the bottleneck. For a region id the value is that id's
## share after every later region took its part, times what the shore band left
## (adding it to 0.0, as weights_at does, leaves the same float); "mizube" is the
## shore band itself; "base" needs every share and takes weights_at.
static func weight(p: Vector2, id: String, terrain: Node = null) -> float:
	if id == "base": return float(weights_at(p, terrain).get(id, 0.0))
	# During install_now the main thread asks through the kernel made from this
	# terrain's (final) shore data: the same floats, no Dictionary reads per region.
	if _main_kernel != null and terrain != null and _main_kernel_terrain == terrain.get_instance_id() and OS.get_thread_caller_id() == OS.get_main_thread_id():
		return _main_kernel.weight(p, region_index(id))
	var left := 1.0
	var mizube := 0.0
	if terrain != null and terrain.shoreline.size() > 2 and LAKE_NEAR.has_point(p) and not terrain.water_at(p):
		var shore: float = shore_distance(terrain, p, SHORE_CAP_M)
		if shore < SHORE_CAP_M:
			shore += noise().get_noise_2dv(p * 1.7) * 3.0
			var w := 1.0 - smoothstep(SHORE_FULL_M, SHORE_EDGE_M, shore)
			if w > 0.0:
				mizube = w
				left -= w
	if id == "mizube": return mizube
	var share := 0.0
	var present := false
	for region: Dictionary in REGIONS:
		var w: float = region_weight(region, p)
		if w <= 0.0: continue
		# weights_at: every id already stacked gives up (1 - w) ...
		if present: share *= 1.0 - w
		# ... then this region's id takes the larger of its share and w.
		if region.id == id:
			share = maxf(share, w)
			present = true
	return 0.0 + share * left if present else 0.0

# ------------------------------------------------------------ weight kernel
## Biome weights without shared state. weight() reads REGIONS (dictionaries and
## strings), the one shared FastNoiseLite and the static shore table: on worker
## threads every such read contends with the other threads (measured: a row
## job ran slower on 12 threads than on one). A Kernel holds its own copies,
## REGIONS flattened to packed arrays, the shore polygon, islands and table
## flattened, and its own FastNoiseLite with the same seed and settings (the
## same noise values), so a worker that clones one touches nothing shared.
## Kernel.weight() is weight() step for step: the same float operations in the
## same order give the same floats (checked on 396,000 point/id pairs, scratch
## speed\p2\tail\bench_parallel.gd).
const REGION_IDS := ["momiji", "yard", "matsu", "zoki", "koke", "hanami", "sando", "harappa"]

## Index of a region id in REGION_IDS; -2 for the shore band, -1 for none.
static func region_index(id: String) -> int:
	if id == "mizube": return -2
	return REGION_IDS.find(id)

static var _main_kernel: Kernel = null
static var _main_kernel_terrain := 0

## The kernel for `terrain` while the builders run (made once in install_now),
## else a new one. Builders' worker jobs take kernel.clone() per task.
static func terrain_kernel(terrain: Object) -> Kernel:
	if _main_kernel != null and terrain != null and _main_kernel_terrain == terrain.get_instance_id(): return _main_kernel
	return kernel_for(terrain)

## A kernel for `terrain` (a node or TerrainShore), made on the main thread
## once the shore table is built.
static func kernel_for(terrain: Object) -> Kernel:
	var k := Kernel.new()
	k.setup_regions()
	if terrain != null:
		var poly: PackedVector2Array = terrain.shoreline
		k.shore.append_array(poly)
		for island: Variant in terrain.islands:
			var points := PackedVector2Array()
			points.append_array(island.points)
			k.isles.append(points)
		if poly.size() > 2 and not _shore_table.is_empty() and _shore_poly == poly:
			k.t_origin = _shore_origin
			k.t_size = _shore_size
			for list: PackedInt32Array in _shore_table:
				k.t_start.append(k.t_segs.size())
				k.t_segs.append_array(list)
			k.t_start.append(k.t_segs.size())
	return k

class Kernel extends RefCounted:
	var nz := FastNoiseLite.new()
	var shape := PackedInt32Array() # 0 ellipse (a = centre, b = radii), 1 rect (a = x span, b = z span)
	var region_id := PackedInt32Array()
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var feather := PackedFloat64Array()
	var shore := PackedVector2Array()
	var isles: Array[PackedVector2Array] = []
	var t_start := PackedInt32Array()
	var t_segs := PackedInt32Array()
	var t_origin := Vector2i.ZERO
	var t_size := Vector2i.ZERO

	func _init() -> void:
		nz.seed = 52031
		nz.frequency = 0.035
		nz.fractal_octaves = 3

	func setup_regions() -> void:
		for region: Dictionary in REGIONS:
			if region.shape == "ellipse":
				shape.append(0)
				a.append(region.c)
				b.append(region.r)
			else:
				shape.append(1)
				a.append(region.x)
				b.append(region.z)
			region_id.append(REGION_IDS.find(region.id))
			feather.append(region.f)

	## A copy that shares no buffer with this one (for one worker task).
	func clone() -> Kernel:
		var k := Kernel.new()
		k.shape.append_array(shape)
		k.region_id.append_array(region_id)
		k.a.append_array(a)
		k.b.append_array(b)
		k.feather.append_array(feather)
		k.shore.append_array(shore)
		for points: PackedVector2Array in isles:
			var copy := PackedVector2Array()
			copy.append_array(points)
			k.isles.append(copy)
		k.t_start.append_array(t_start)
		k.t_segs.append_array(t_segs)
		k.t_origin = t_origin
		k.t_size = t_size
		return k

	func water_at(p: Vector2) -> bool:
		if not Geometry2D.is_point_in_polygon(p, shore): return false
		for points: PackedVector2Array in isles:
			if Geometry2D.is_point_in_polygon(p, points): return false
		return true

	## shore_distance() on the kernel's own polygon and table.
	func shore_distance(p: Vector2, cap: float) -> float:
		var n := shore.size()
		if n == 0: return INF
		var cell := Vector2i(floori(p.x / SHORE_CELL_M), floori(p.y / SHORE_CELL_M)) - t_origin
		var best := INF
		if t_start.is_empty() or cap > SHORE_CAP_M or cell.x < 0 or cell.y < 0 or cell.x >= t_size.x or cell.y >= t_size.y:
			for i: int in range(n):
				best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, shore[i], shore[(i + 1) % n])))
			return best
		var c := cell.y * t_size.x + cell.x
		for j: int in range(t_start[c], t_start[c + 1]):
			var i := t_segs[j]
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, shore[i], shore[(i + 1) % n])))
		return best

	## region_weight() for region k.
	func region_w(k: int, p: Vector2) -> float:
		var outside: float
		if shape[k] == 0:
			var r: Vector2 = b[k]
			var c: Vector2 = a[k]
			var d: float = ((p - c) / r).length()
			outside = (d - 1.0) * (r.x + r.y) * 0.5
		else:
			var x: Vector2 = a[k]
			var z: Vector2 = b[k]
			var q := Vector2(maxf(x.x - p.x, p.x - x.y), maxf(z.x - p.y, p.y - z.y))
			outside = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
		var f: float = feather[k]
		outside += nz.get_noise_2dv(p) * f * 0.45
		return 1.0 - smoothstep(-f * 0.5, f * 0.5, outside)

	## Biomes.weight(p, REGION_IDS[index]) (index from region_index()).
	func weight(p: Vector2, index: int) -> float:
		if index == -1: return 0.0
		var left := 1.0
		var mizube := 0.0
		if shore.size() > 2 and LAKE_NEAR.has_point(p) and not water_at(p):
			var dist: float = shore_distance(p, SHORE_CAP_M)
			if dist < SHORE_CAP_M:
				dist += nz.get_noise_2dv(p * 1.7) * 3.0
				var w := 1.0 - smoothstep(SHORE_FULL_M, SHORE_EDGE_M, dist)
				if w > 0.0:
					mizube = w
					left -= w
		if index == -2: return mizube
		var share := 0.0
		var present := false
		# region_weight() asks the noise at p once per region: the same value
		# each time, so it is read once (an object call; on worker threads those
		# serialise on the engine's object lookup, plain maths does not).
		var wobble: float = nz.get_noise_2dv(p)
		for k: int in range(shape.size()):
			# region_w(k, p), inline.
			var outside: float
			if shape[k] == 0:
				var r: Vector2 = b[k]
				var c: Vector2 = a[k]
				var d: float = ((p - c) / r).length()
				outside = (d - 1.0) * (r.x + r.y) * 0.5
			else:
				var x: Vector2 = a[k]
				var z: Vector2 = b[k]
				var q := Vector2(maxf(x.x - p.x, p.x - x.y), maxf(z.x - p.y, p.y - z.y))
				outside = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
			var f: float = feather[k]
			outside += wobble * f * 0.45
			var w := 1.0 - smoothstep(-f * 0.5, f * 0.5, outside)
			if w <= 0.0: continue
			if present: share *= 1.0 - w
			if region_id[k] == index:
				share = maxf(share, w)
				present = true
		return 0.0 + share * left if present else 0.0

## A dithered yes/no from position: species and thinning interleave at edges
## instead of switching on a line. Uses no RNG.
static func pick(p: Vector2, w: float, salt: int = 0) -> bool:
	var h := absi(hash(Vector3i(floori(p.x * 4.0), floori(p.y * 4.0), salt))) % 10007
	return float(h) / 10007.0 < w

const GROUND_UNIFORMS := """
uniform sampler2D biome_look_a : repeat_disable, filter_linear;
uniform sampler2D biome_look_b : repeat_disable, filter_linear;
uniform sampler2D biome_coppice_weight : repeat_disable, filter_linear;
uniform sampler2D biome_coppice_litter : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool biome_ready = false;
"""

## Value noise is laid on a square grid; read at two rotations with a warp so
## no axis-aligned blocks show in the fine leaf layers.
const GROUND_FUNCTIONS := """
float biome_noise(vec2 p) {
	vec2 w = vec2(midori_floor_noise(p * 0.37 + vec2(5.1, 1.7)), midori_floor_noise(p * 0.37 + vec2(2.9, 8.3))) - 0.5;
	p += w * 1.6;
	float a = midori_floor_noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p);
	float b = midori_floor_noise(mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * p * 1.31 + vec2(17.3, 4.1));
	return a * 0.55 + b * 0.45;
}
"""

## Applied after the layered ground and before worn paths, so trails still wear
## through the biome floor.
const GROUND_FRAGMENT := """
	if (biome_ready && landscape_ready) {
		vec2 biome_uv = (world_pos.xz + vec2(220.0, 180.0)) / vec2(440.0, 360.0);
		vec4 la = texture(biome_look_a, biome_uv);
		vec4 lb = texture(biome_look_b, biome_uv);
		vec3 base = ALBEDO / max(scene_light_factor, 0.01);
		float base_luma = dot(base, vec3(0.299, 0.587, 0.114));
		float b_broad = midori_floor_noise(world_pos.xz * 0.21 + vec2(4.4, 6.6));
		float b_mid = midori_floor_noise(world_pos.xz * 1.7 + vec2(2.3, 9.1));
		float coppice = texture(biome_coppice_weight, biome_uv).r;
		float leaf_cover = smoothstep(0.12, 0.62, la.r * (0.7 + 0.5 * b_mid) + (b_broad - 0.5) * 0.25);
		// Inside the coppice, its opaque litter replaces these other looks.
		if (coppice < 1.0) {
			float b_fine = biome_noise(world_pos.xz * 7.9 + vec2(7.7, 1.9));
			float b_leaf = biome_noise(world_pos.xz * 15.0 + vec2(3.3, 0.7));
			// Care: below .5 a richer, darker kept turf; above .5 drier, straw olive.
			float care = la.g - 0.5;
			vec3 kept = base * vec3(0.84, 0.98, 0.78);
			vec3 dry = mix(base, vec3(base_luma) * vec3(1.22, 1.1, 0.72), 0.55);
			base = care < 0.0 ? mix(base, kept, -care * 2.0) : mix(base, dry, care * 2.0);
			// Moss carpet, patchy at low strength and nearly whole at full.
			float moss_cover = smoothstep(0.15, 0.55, la.b * (0.7 + 0.5 * b_mid) - (1.0 - b_broad) * 0.15);
			vec3 moss = vec3(0.105, 0.15, 0.048) * mix(0.75, 1.2, b_fine) * mix(0.85, 1.1, b_broad);
			base = mix(base, moss, moss_cover * 0.92);
			// Pine duff: grey-brown needles, fine speckle.
			float needle_cover = smoothstep(0.1, 0.6, lb.r * (0.75 + 0.4 * b_mid));
			vec3 needles = mix(vec3(0.22, 0.15, 0.10), vec3(0.32, 0.22, 0.15), b_fine) * mix(0.85, 1.08, b_broad);
			base = mix(base, needles, needle_cover * 0.9);
			// Leaf litter: rust, tan, dun and old brown leaves in overlapping drifts,
			// dark gaps between them, the ground's own relief kept underneath.
			float l_a = biome_noise(world_pos.xz * 9.0 + vec2(1.3, 8.2));
			float l_b = biome_noise(world_pos.xz * 23.0 + vec2(6.1, 2.4));
			float l_c = biome_noise(world_pos.xz * 57.0 + vec2(3.7, 9.9));
			vec3 leaves = mix(vec3(0.25, 0.105, 0.04), vec3(0.33, 0.215, 0.095), smoothstep(0.35, 0.65, l_a));
			leaves = mix(leaves, vec3(0.16, 0.095, 0.05), smoothstep(0.6, 0.85, l_b) * 0.8);
			leaves = mix(leaves, vec3(0.23, 0.2, 0.095), smoothstep(0.72, 0.92, b_leaf) * 0.6);
			leaves *= mix(0.62, 1.0, smoothstep(0.15, 0.6, l_c));
			leaves *= mix(0.78, 1.06, b_broad) * mix(0.85, 1.12, base_luma / max(base_luma + 0.12, 0.01) * 1.6);
			base = mix(base, leaves, leaf_cover * 0.94);
			// Meadow: the soil under long grass reads straw and dun.
			float straw = lb.g * smoothstep(0.2, 0.7, b_mid + 0.2);
			base = mix(base, vec3(base_luma) * vec3(1.28, 1.12, 0.66), straw * 0.45);
			// Fallen petals dusting short turf.
			float petal = lb.b * smoothstep(0.8, 0.93, b_leaf) * smoothstep(0.35, 0.7, b_broad);
			base = mix(base, vec3(0.78, 0.6, 0.62), petal * 0.6);
			// Shore peat: dark damp soil in blobs.
			float peat = lb.a * smoothstep(0.25, 0.65, b_mid + 0.15);
			base = mix(base, base * vec3(0.62, 0.6, 0.55), peat * 0.75);
		}
		// Retain individual oak leaves and moss between the three-dimensional
		// drifts. Two orientations break the repeating texture at middle distance.
		if (coppice > 0.0) {
			vec2 uv = world_pos.xz / 2.9;
			mat2 turn = mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6));
			vec3 litter_a = texture(biome_coppice_litter, uv).rgb;
			vec3 litter_b = texture(biome_coppice_litter, turn * uv * 0.83 + vec2(0.37, 0.11)).rgb;
			vec3 woodland = mix(litter_a, litter_b, smoothstep(0.39, 0.60, b_broad));
			vec3 moss_tint = mix(vec3(0.94, 0.94, 0.85), vec3(0.70, 0.91, 0.67), b_broad);
			base = mix(base, woodland * moss_tint * mix(0.78, 1.04, b_mid), coppice);
			NORMAL_MAP = mix(NORMAL_MAP, source_normal, coppice);
			NORMAL_MAP_DEPTH = mix(NORMAL_MAP_DEPTH, 0.29, coppice);
		}
		ALBEDO = base * scene_light_factor;
		float wet = la.a * smoothstep(0.35, 0.75, b_broad);
		ROUGHNESS = mix(ROUGHNESS, ROUGHNESS - 0.18, wet);
		ROUGHNESS = mix(ROUGHNESS, 0.95, leaf_cover * 0.6);
	}
"""

## With a raid, the world-complete step (scripts/shinrai_world_complete.gd)
## calls install_now() before HQ; this legacy entry only runs for a raid that
## left BOOT without that step, or with no raid at all.
static func install(park: Node3D) -> void:
	var tree := park.get_tree()
	var raid := park.get_node_or_null("ExtractionRun")
	while is_instance_valid(raid) and raid.phase == raid.Phase.BOOT:
		if is_instance_valid(park) and park.get_meta(&"shinrai_world_complete_started", false): return
		await tree.process_frame
	if not is_instance_valid(park): return
	await install_now(park)

## Bakes, injects and runs every builder once per park. `progress` (optional)
## is called with (stage text, 0..1 through the biomes) for the loading bar.
static func install_now(park: Node3D, progress: Callable = Callable()) -> Dictionary:
	if not is_instance_valid(park): return {}
	if park.has_meta("midori_biomes"): return park.get_meta("midori_biomes")
	if park.get_meta(&"midori_biomes_running", false):
		while is_instance_valid(park) and not park.has_meta("midori_biomes"): await park.get_tree().process_frame
		return park.get_meta("midori_biomes", {}) if is_instance_valid(park) else {}
	park.set_meta(&"midori_biomes_running", true)
	if OS.get_environment("MIDORI_BIOMES_OFF") == "1":
		park.set_meta("midori_biomes", {"disabled": true})
		return park.get_meta("midori_biomes")
	prefetch()
	var started := Time.get_ticks_msec()
	var terrain := park.get_node_or_null("MidoriTerrain")
	var material := _ground_material(park)
	var report := {}
	if progress.is_valid(): progress.call("Mapping the park's grounds", 0.0)
	if material != null:
		var maps := await bake(park, terrain)
		if not is_instance_valid(park): return {}
		await Budget.checkpoint(park, true)
		_inject(material, maps[0], maps[1], maps[2])
		report["look_maps"] = maps[0].get_size()
	else:
		report["error"] = "ground shader unavailable"
		_drop_prebake()
	# The builders' grids read the shore table on worker threads: it is finished
	# before the first of them starts (built once, see _shore_index).
	if terrain != null:
		await _ensure_shore(park, terrain.shoreline)
		if not is_instance_valid(park): return {}
		# The shore data is final: weight() on the main thread and the builders'
		# worker grids read kernels made from it (see Kernel).
		_main_kernel = kernel_for(terrain)
		_main_kernel_terrain = terrain.get_instance_id()
	report["bake_ms"] = Time.get_ticks_msec() - started
	# MIDORI_BIOMES_ONLY=sakura_lawn,meadow runs just those builders (for checks).
	var only := OS.get_environment("MIDORI_BIOMES_ONLY").split(",", false)
	var timings := {}
	var thin_all: Script = load("res://scripts/biomes/thin_all.gd")
	# The thinning walk is kept across builders until a node outside the Biome*
	# roots enters or leaves the tree (thin_all.track).
	thin_all.track(park, true)
	Budget.reset_site_profile()
	for index: int in range(BUILDERS.size()):
		var path: String = BUILDERS[index]
		if not only.is_empty() and not only.has(path.get_file().get_basename()): continue
		if not ResourceLoader.exists(path): continue
		if progress.is_valid(): progress.call(BUILDER_STAGES.get(path.get_file().get_basename(), "Planting the park"), 0.1 + 0.9 * float(index) / float(BUILDERS.size()))
		# No extra yield between builders: one may queue_free what the next scans,
		# and a frame boundary here would change what the next one sees.
		var tick := Time.get_ticks_msec()
		# The thinning helper shares one park walk between the calls of a single
		# builder (thin_all.batch), never across builders.
		thin_all.batch(true)
		var builder: Script = load(path)
		var result = await builder.build(park, terrain)
		thin_all.batch(false)
		report[path.get_file().get_basename()] = result
		timings[path.get_file().get_basename()] = Time.get_ticks_msec() - tick
		if not is_instance_valid(park): return {}
	report["builder_ms"] = timings
	thin_all.track(park, false)
	_main_kernel = null
	_main_kernel_terrain = 0
	release_prefetch()
	Budget.print_site_profile("biomes")
	report["ms"] = Time.get_ticks_msec() - started
	park.set_meta("midori_biomes", report)
	print("MIDORI_BIOMES ", JSON.stringify(report))
	return report

# ------------------------------------------------------------ asset prefetch
## The builders load their scenes, meshes and textures with plain load() at
## the moment they need them, on the main thread, and pieces several builders
## share (moss fronds, forest-floor stones) are read from disk again by each,
## since nothing holds them in between (about 2-3 s of the stage). prefetch()
## asks ResourceLoader for all of them on its threads as soon as the
## world-complete step starts; a builder's load() then returns the loaded
## resource (or joins its load). The pending requests hold the resources until
## release_prefetch() after the last builder, so memory afterwards is as
## before. Same files, same resources: nothing about what is built changes.
const PREFETCH_EXTENSIONS := ["glb", "gltf", "tscn", "scn", "res", "tres", "mesh", "png", "jpg", "jpeg", "webp", "exr"]
const PREFETCH_NUMBERED := [
	["res://assets/shinrai/parks/midori_park/models/island_nature/moss_%02d.glb", 10],
	["res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/stone_%02d.glb", 6],
	["res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/branch_%02d.glb", 3],
]
static var _prefetched := PackedStringArray()

static func prefetch() -> void:
	if not _prefetched.is_empty(): return
	var paths := PackedStringArray()
	for row: Array in PREFETCH_NUMBERED:
		for i: int in range(int(row[1])): paths.append(String(row[0]) % i)
	# Every resource path a builder names as a constant.
	for source: String in BUILDERS + ["res://scripts/biomes/sakura_tree_generator.gd"]:
		if not ResourceLoader.exists(source): continue
		var script := load(source) as Script
		if script == null: continue
		for value: Variant in script.get_script_constant_map().values():
			if value is String and (value as String).begins_with("res://") and PREFETCH_EXTENSIONS.has((value as String).get_extension().to_lower()):
				paths.append(value)
	for path: String in paths:
		if _prefetched.has(path) or not ResourceLoader.exists(path): continue
		if ResourceLoader.has_cached(path): continue
		if ResourceLoader.load_threaded_request(path) == OK: _prefetched.append(path)
	# Pure-data tree geometry (own seeds, no scene access) starts on
	# WorkerThreadPool now too; the builders take the finished jobs over.
	for source: String in ["res://scripts/biomes/maple_glen.gd", "res://scripts/biomes/sakura_lawn.gd"]:
		if OS.get_environment("MIDORI_BIOMES_OFF") == "1" or not ResourceLoader.exists(source): continue
		(load(source) as Script).call("start_early")

## Drops the prefetch requests' hold (blocks only on one still loading).
static func release_prefetch() -> void:
	for path: String in _prefetched:
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(path)
	_prefetched = PackedStringArray()

const BUILDER_STAGES := {
	"maple_glen": "Planting the maple glen", "north_coppice": "Growing the north coppice",
	"pine_woods": "Planting the pine woods", "moss_garden": "Laying the moss garden",
	"sakura_lawn": "Planting the cherry lawn", "shrine_approach": "Paving the shrine approach",
	"meadow": "Sowing the meadow", "iris_shore": "Planting the iris shore",
}

static func _ground_material(park: Node3D) -> ShaderMaterial:
	var terrain := park.get_node_or_null("MidoriTerrain")
	if terrain == null: return null
	for child: Node in terrain.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			var material: ShaderMaterial = child.material_override
			if material.shader.code.contains("uniform sampler2D landscape_tex"): return material
	return null

static func bake(park: Node3D, terrain: Node) -> Array[Image]:
	var w := int(SIZE.x * RES)
	var h := int(SIZE.y * RES)
	# The look values are pure maths (constants, the shared noise and the
	# terrain's data methods), so the rows are worked out on WorkerThreadPool,
	# each task filling only its own row; the images are written here.
	noise()
	# The rows read a plain copy of the terrain's shore data, not the node: the
	# main thread awaits frames meanwhile, and a quit or Retry can free the park
	# (and its terrain) before the rows finish.
	var shore := TerrainShore.new(terrain)
	# Maps baked ahead (prebake(), started once the terrain was installed) from
	# the same shore data are the same images: use them.
	var early: Array = await _take_prebake(park, shore)
	if not is_instance_valid(park): return []
	if early.size() == 3:
		var maps: Array[Image] = []
		maps.assign(early)
		return maps
	var a := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var b := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var coppice := Image.create(w, h, false, Image.FORMAT_R8)
	await _ensure_shore(park, shore.shoreline)
	if not is_instance_valid(park): return [a, b, coppice]
	var rows: Array = []
	for y: int in range(h): rows.append({})
	var bake_row := func(y: int) -> void:
		(rows[y] as Dictionary)["px"] = _bake_row(y, w, shore)
	var task := WorkerThreadPool.add_group_task(bake_row, h, -1, true, "midori_biomes look maps")
	while not WorkerThreadPool.is_group_task_completed(task):
		await park.get_tree().process_frame
		if not is_instance_valid(park): break
	WorkerThreadPool.wait_for_group_task_completion(task)
	if not is_instance_valid(park): return [a, b, coppice]
	for y: int in range(h):
		# A row whose task failed on its thread is worked out here instead.
		if not (rows[y] as Dictionary).has("px"): rows[y]["px"] = _bake_row(y, w, shore)
		var px: PackedColorArray = rows[y].px
		for x: int in range(w):
			a.set_pixel(x, y, px[x * 3])
			b.set_pixel(x, y, px[x * 3 + 1])
			coppice.set_pixel(x, y, px[x * 3 + 2])
		# Time-based: the maps are the same however the rows split across frames.
		await Budget.checkpoint(park, true)
		if not is_instance_valid(park): return [a, b, coppice]
	return [a, b, coppice]

# ------------------------------------------------------------ early bake
## The look maps read nothing but the constants above, the shared noise and the
## terrain's shoreline and islands, which are final once the terrain is
## installed (about 40 s before the world-complete step). The raid calls
## prebake() then: one WorkerThreadPool task builds the shore table and bakes
## the three images exactly as bake() would (same rows, same pixels). bake()
## takes them only when the shoreline and islands are still equal to the copy
## the task read; otherwise it bakes again as before. Nothing touches the scene
## or the ground material early: _inject() runs where it always did.
static var _pre: Dictionary = {}

static func prebake(park: Node3D) -> void:
	if OS.get_environment("MIDORI_BIOMES_OFF") == "1" or not is_instance_valid(park): return
	var terrain := park.get_node_or_null("MidoriTerrain")
	if terrain == null: return
	_drop_prebake()
	noise() # made here, before a thread reads it
	var shore := TerrainShore.new(terrain, true)
	var w := int(SIZE.x * RES)
	var h := int(SIZE.y * RES)
	var out := {}
	var job := func() -> void:
		if shore.shoreline.size() > 2: _shore_index(shore.shoreline)
		out["maps"] = _bake_images(w, h, shore)
	_pre = {"park": park.get_instance_id(), "shore": shore, "out": out, "task": WorkerThreadPool.add_task(job, false, "midori_biomes prebake")}

## The prebaked maps when they were made for this park from equal shore data
## (waits for the task on frames, never blocking the main thread), else [].
static func _take_prebake(park: Node3D, shore: TerrainShore) -> Array:
	if _pre.is_empty(): return []
	var pre := _pre
	var early: TerrainShore = pre.shore
	var same: bool = int(pre.park) == park.get_instance_id() and early.shoreline == shore.shoreline and early.islands == shore.islands
	if same:
		while not WorkerThreadPool.is_task_completed(int(pre.task)):
			await park.get_tree().process_frame
			if not is_instance_valid(park): break
	_drop_prebake()
	var maps: Array = (pre.out as Dictionary).get("maps", [])
	if StartupTrace.enabled: print("MIDORI_BIOMES_PREBAKE ", "hit" if same and maps.size() == 3 else "stale, baking again")
	return maps if same and is_instance_valid(park) else []

static func _drop_prebake() -> void:
	if _pre.has("task"): WorkerThreadPool.wait_for_task_completion(int(_pre.task))
	_pre = {}

## The shore table for `poly` built on a worker (one task, nothing else reading
## it meanwhile) when it is not there yet, so the row tasks and the builders'
## grids only ever read a finished table.
static func _ensure_shore(park: Node3D, poly: PackedVector2Array) -> void:
	if poly.size() <= 2 or (not _shore_table.is_empty() and _shore_poly == poly): return
	var task := WorkerThreadPool.add_task(func() -> void: _shore_index(poly), false, "midori_biomes shore table")
	while not WorkerThreadPool.is_task_completed(task):
		await park.get_tree().process_frame
		if not is_instance_valid(park): break
	WorkerThreadPool.wait_for_task_completion(task)

## The three look maps on the calling thread: bake()'s rows and pixels in order.
static func _bake_images(w: int, h: int, shore: TerrainShore) -> Array:
	var a := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var b := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var coppice := Image.create(w, h, false, Image.FORMAT_R8)
	for y: int in range(h):
		var px := _bake_row(y, w, shore)
		for x: int in range(w):
			a.set_pixel(x, y, px[x * 3])
			b.set_pixel(x, y, px[x * 3 + 1])
			coppice.set_pixel(x, y, px[x * 3 + 2])
	return [a, b, coppice]

## One row of the look maps: per pixel the A colour, the B colour and the
## coppice weight (red), exactly as the images take them.
## The two things weights_at reads from the terrain (its shoreline and
## water_at), copied once on the main thread. water_at is MidoriTerrain's code
## line for line on the same data, so every answer is the same.
class TerrainShore extends RefCounted:
	var shoreline := PackedVector2Array()
	var islands: Array = []
	func _init(terrain: Object, deep := false) -> void:
		if terrain == null: return
		shoreline = terrain.shoreline
		islands = (terrain.islands as Array).duplicate(deep)
	func water_at(p: Vector2) -> bool:
		if not Geometry2D.is_point_in_polygon(p,shoreline): return false
		for island in islands:
			if Geometry2D.is_point_in_polygon(p,island.points): return false
		return true

static func _bake_row(y: int, w: int, terrain: Object) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(w * 3)
	for x: int in range(w):
		var p := ORIGIN + (Vector2(x, y) + Vector2(0.5, 0.5)) / RES
		var weights := weights_at(p, terrain)
		var look := [0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for id: String in weights:
			if id == "base" or not LOOKS.has(id): continue
			var wt: float = weights[id]
			var values: Array = LOOKS[id]
			for k: int in range(8): look[k] += (float(values[k]) - (0.5 if k == 1 else 0.0)) * wt
		out[x * 3] = Color(look[0], look[1], look[2], look[3])
		out[x * 3 + 1] = Color(look[4], look[5], look[6], look[7])
		out[x * 3 + 2] = Color(float(weights.get("zoki", 0.0)), 0.0, 0.0)
	return out

static func _inject(material: ShaderMaterial, a: Image, b: Image, coppice: Image) -> void:
	if not material.shader.code.contains("uniform bool biome_ready"):
		var parameters := {}
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			parameters[uniform.name] = material.get_shader_parameter(uniform.name)
		var code: String = material.shader.code
		code = code.replace("varying vec3 world_pos;", GROUND_UNIFORMS + "varying vec3 world_pos;")
		code = code.replace("void vertex()", GROUND_FUNCTIONS + "void vertex()")
		# Before the worn-path pass when it is already there, else at the end.
		var at := code.find("\tif (worn_ready) {")
		if at < 0: at = code.rfind("}")
		code = code.insert(at, GROUND_FRAGMENT)
		var shader := Shader.new()
		shader.code = code
		material.shader = shader
		for key: String in parameters: material.set_shader_parameter(key, parameters[key])
	material.set_shader_parameter("biome_look_a", ImageTexture.create_from_image(a))
	material.set_shader_parameter("biome_look_b", ImageTexture.create_from_image(b))
	material.set_shader_parameter("biome_coppice_weight", ImageTexture.create_from_image(coppice))
	material.set_shader_parameter("biome_coppice_litter", preload("res://assets/shinrai/parks/midori_park/materials/coppice_litter/coppice_litter.png"))
	material.set_shader_parameter("biome_ready", true)
