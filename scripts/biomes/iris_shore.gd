extends RefCounted
## Mizube / Hanashobu 水辺・花菖蒲, the iris shore band
## (docs/biome_concepts/after_iris_shore.png, extra/after_iris_shore_*.png).
## A damp dark bank along the lake: reed stands hugging the waterline (never
## out in open water), drifts of violet hanashobu right at the edge, low rushes
## feathering up the bank, half-sunk mossy stones, extra lily rafts and a few
## dark fallen leaves. Every plant grows in stands of several clumps around a
## noise-picked centre, never as scattered singles and never in rows; density
## fades out with the band weight so the bank feathers into the lawn behind it.
## Bridges, landings and walks stay clear. The ground itself (peat, wet, moss)
## comes from the look map; the lawn is thinned at the waterline so it shows.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
const ID := "mizube"
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const MOSS := "res://assets/shinrai/parks/midori_park/models/island_nature/"
const LILY := "res://scripts/midori_water_lily.gd"
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
# The plan's four pockets, plus the bank seen from the main iris_shore view
# (eye (40,70)): between the promenade walk and the water, 7-19 m out.
const HEROES: Array[Vector2] = [Vector2(52, 56), Vector2(149, 24), Vector2(64, -97), Vector2(124, -123), Vector2(49, 63)]
# Landward beds in world metres (x, z, drift length, number of root clusters).
# The southern walk covers the first six metres of the view. The north eye is
# in open water, so its flowers grow on the facing bank, 14–25 m away.
const BANK_BEDS := {
	"south_outer": Vector4(45.2, 61.5, 3.3, 6),
	"south_walk_margin": Vector4(47.8, 66.4, 3.1, 7),
	"south_east": Vector4(51.2, 65.6, 4.7, 7),
	"south_inner": Vector4(49.8, 60.0, 2.6, 4),
	"south_lip": Vector4(56.7, 63.3, 2.9, 5),
	"north_west": Vector4(50.4, -88.4, 4.6, 7),
	"north_near": Vector4(53.3, -94.5, 3.2, 5),
	"north_east": Vector4(58.0, -106.1, 4.1, 6),
}
# Ground cover around the beds (centre, elliptical reach). The shore distance,
# path and depth samples below decide the actual planted edge of each patch.
const LOW_BANK_POCKETS := [Vector4(51.0, 62.9, 9.8, 8.0), Vector4(55.0, -96.7, 8.0, 16.0),
	Vector4(149.0, 21.0, 9.0, 14.0), Vector4(121.7, -128.0, 13.0, 8.0)]
# Distance grid over the lake and its band, 1 m cells (Biomes.LAKE_NEAR grown 6 m).
const GRID := Rect2(4.0, -161.0, 178.0, 284.0)
const COLS := 178
const ROWS := 284
const SHORE_REACH := 15.0
const ISLAND_REACH := 6.5
const LAYOUT := 2.0
const MAX_REEDS := 950
const MAX_RUSHES := 1400
const MAX_SEDGES := 2600
const MAX_RHIZOMES := 1180
const MAX_STONE_GROUPS := 34
const MAX_LILY_RAFTS := 70
const MAX_MOSS := 40000
# Reeds stay on the bank lip: at most REED_REACH inland of the waterline and
# REED_WATER_M out into it, in water no deeper than REED_DEPTH.
const REED_REACH := 1.5
const REED_WATER_M := 0.9
const REED_DEPTH := 0.26
const REED_RANGE_M := 70.0
# Plants cast shadows only this close to the camera (shadow-only copies).
const NEAR_SHADOW_M := 20.0
const IRIS_DEPTH := 0.2
# The park's ContinuousNaturalBank ribbon (midori_park_size_blockout
# _add_shoreline_ribbon) is a visible slope from y .104 at the waterline to .22
# at 2.3 m inland, laid OVER terrain that stays near 0 there and is never
# draped. Anything seated on terrain.height_at in that strip would be buried.
const BANK_M := 2.3
const BANK_INNER_Y := 0.104
const BANK_OUTER_Y := 0.22

# --------------------------------------------------------------- shaders

## Reeds, rushes and iris share one shader. Vertex colour rgb is the plant
## colour; vertex alpha marks petal (1) against leaf/stem (0), and petals take
## the instance's custom colour (the drift's violet). UV.x is 0/1 on blade
## edges and .5 on midribs and solid parts, UV2.x the blade's half width there,
## TANGENT the blade's sideways axis.
const PLANT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float sway = 0.03;
// Smallest half width (m per m of distance) a blade keeps on screen, about
// 0.7 px at 1080p: a far stand stays a soft stand instead of breaking into
// flickering hairs. Growth is capped so near blades are never fattened.
uniform float aa_half = 0.00045;
varying vec3 petal_tint;
void vertex() {
	// A slow breeze: only the upper blade moves, each clump out of phase.
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float t = TIME * 0.85 + root.x * 0.21 + root.z * 0.17;
	float gust = sin(t) * 0.6 + sin(t * 2.3 + root.x * 0.7) * 0.25;
	// One world wind direction for every clump, brought into the clump's own
	// (randomly yawed) axes: M^T w / |M^T w|^2 is M^-1 w for rotation * scale.
	vec3 local_wind = (vec4(0.857, 0.0, 0.514, 0.0) * MODEL_MATRIX).xyz;
	local_wind /= max(dot(local_wind, local_wind), 0.0001);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float half_w = UV2.x;
	// Only for the perspective view camera: the orthographic directional
	// shadow camera sits at an arbitrary distance and would fatten every blade.
	float persp = step(PROJECTION_MATRIX[3][3], 0.5);
	float grow = persp * clamp(distance(CAMERA_POSITION_WORLD, world) * aa_half - half_w, 0.0, half_w * 1.6);
	VERTEX += TANGENT * ((UV.x * 2.0 - 1.0) * grow);
	VERTEX += local_wind * gust * sway * h * h;
	petal_tint = vec3(1.0);
	//CUSTOM
}
void fragment() {
	// Blades are seen from both sides; keep the soft upward normal on the back
	// face instead of the engine's flipped (downward, dark) one.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 c = mix(COLOR.rgb, COLOR.rgb * petal_tint, COLOR.a);
	ALBEDO = c;
	ROUGHNESS = mix(0.82, 0.6, COLOR.a);
	SPECULAR = 0.26;
	BACKLIGHT = c * mix(0.4, 0.6, COLOR.a);
}
"""

# ------------------------------------------------------------------ build

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var started := Time.get_ticks_msec()
	if terrain == null or terrain.shoreline.size() < 3: return {"error": "terrain unavailable"}
	var root := Node3D.new()
	root.name = "BiomeIrisShore"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501105
	# Distance to the main waterline and to the island edges, 1 m cells.
	var shore := PackedFloat32Array()
	shore.resize(COLS * ROWS)
	shore.fill(99.0)
	var island := shore.duplicate()
	var tree := park.get_tree()
	shore = await _stamp(park, shore, terrain.shoreline, SHORE_REACH)
	for isle: Dictionary in terrain.islands:
		if not is_instance_valid(park): return {"error": "park freed"}
		island = await _stamp(park, island, isle.points, ISLAND_REACH)
	if not is_instance_valid(park): return {"error": "park freed"}
	var inventory := Kit.inventory(park, GRID)
	var thinned := _thin(park, shore, island)
	var water_y := _water_y(park, terrain)
	var scan: Dictionary = await _scan(park, terrain, rng, shore, island, water_y)
	if not is_instance_valid(park): return {"error": "park freed"}
	# Stones first, so no reed, rush or iris grows through one.
	var stones := _stones(park, terrain, root, rng, scan.stones, water_y, shore)
	var footprints: Array = stones.footprints
	var reeds := _reeds(park, terrain, root, rng, _clear_of(scan.reeds, footprints, 0.15), water_y, shore)
	var rushes := _rushes(park, terrain, root, rng, _clear_of(scan.rushes, footprints, 0.1), water_y, shore)
	var sedges := _sedges(park, terrain, root, rng, _clear_of(scan.sedges, footprints, 0.15), water_y, shore)
	await tree.process_frame
	if not is_instance_valid(park): return {"error": "park freed"}
	var iris := _iris(park, terrain, root, rng, _clear_of(scan.iris, footprints, 0.12), _clear_of(scan.bank_iris, footprints, 0.12), water_y, shore)
	var low_fans := _low_bank_fans(park, terrain, root, _clear_of(scan.low_bank, footprints, 0.15), water_y, shore)
	iris.beds["low_fans"] = low_fans
	await tree.process_frame
	if not is_instance_valid(park): return {"error": "park freed"}
	var lilies := _lilies(park, terrain, root, rng, scan.lilies, water_y)
	var shoreline: PackedVector2Array = terrain.shoreline
	var leaves := await Kit.leaf_floor(park, terrain, root, rng, GRID, func(p: Vector2) -> float:
		var ds := _sample(shore, p)
		var di := _sample(island, p)
		if ds > 15.0 and di > 6.5: return 0.0
		# Hidden under the bank ribbon on the mainland strip.
		if ds < BANK_M + 0.1 and not Geometry2D.is_point_in_polygon(p, shoreline): return 0.0
		var w := _shore_w(ds, p)
		if di < 6.5: w = maxf(w, 0.6 * (1.0 - smoothstep(2.5, 6.0, di)))
		if w < 0.1: return 0.0
		return w * 1.1 * smoothstep(0.35, 0.75, 0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * 2.9 + Vector2(-9, 14))), 0.3, "ShoreLeaves")
	var damp_bank := _dress_bank(park)
	return {"reeds": reeds.clumps, "reed_cattails": reeds.cattails, "reed_singles_dropped": reeds.dropped_singles, "wet_reeds": reeds.wet, "rushes": rushes.count, "wet_rushes": rushes.wet, "sedges": sedges, "iris_rhizomes": iris.rhizomes, "iris_flowers": iris.flowers, "iris_fans": 0, "iris_swords": iris.swords, "bank_beds": iris.beds, "damp_bank": damp_bank, "stands": scan.groups, "stones": stones.stones, "stone_colliders": stones.colliders, "maple_opening_stones": stones.excluded, "moss": stones.moss, "lily_rafts": lilies, "leaves": leaves, "band_cells": scan.cells, "rejected": scan.rejected, "thinned": thinned, "inventory": inventory, "ms": Time.get_ticks_msec() - started}

## The narrow bank mesh overlays terrain. Use its existing world-space soil
## scan and wetness for irregular peat and tiny olive cushions on that surface.
## The path geometry has its own material and never receives this treatment.
static func _dress_bank(park: Node3D) -> bool:
	var bank := park.get("mat_shore_bank") as ShaderMaterial
	if bank == null or bank.shader == null: return false
	var original := bank.shader.code
	var marker := "ground_color *= mix(1.0, 0.62, wetness);"
	if not original.contains(marker): return false
	var edited := bank.shader.duplicate() as Shader
	edited.code = original.replace(marker, """
		vec2 q = world_position.xz;
		float humus = smoothstep(0.15, 0.39, source_luma * 0.5 + 0.22
			+ 0.105 * sin(q.x * 0.73 + sin(q.y * 0.62))
			+ 0.08 * sin(q.y * 1.37 + q.x * 0.86));
		float moisture = clamp(wetness * 0.7 + (1.0 - landward) * 0.22 + humus * 0.13, 0.0, 1.0);
		float scan = max(0.035, dot(dry_ground, vec3(0.30, 0.58, 0.12)));
		vec3 peat_soil = scan * mix(vec3(0.69, 0.50, 0.34), vec3(0.49, 0.57, 0.33), humus);
		ground_color = mix(ground_color, peat_soil, 0.40 + 0.38 * moisture);
		ground_color *= mix(1.0, 0.77, moisture);
	""")
	bank.shader = edited
	return true

# ----------------------------------------------------------- distance map

## Writes the exact distance to a closed polygon's edge into the grid, out to
## `reach`: each segment visits only the cells of its own grown bounding box
## (much cheaper than an edge_distance per cell, and exact, unlike brushing
## discs at sample points).
static func _stamp(park: Node3D, dist: PackedFloat32Array, poly: PackedVector2Array, reach: float) -> PackedFloat32Array:
	var n := poly.size()
	var visited := 0
	var stamped_a_frame := false
	var since := Kit.frames_now()
	for i: int in range(n):
		var a := poly[i] - GRID.position
		var b := poly[(i + 1) % n] - GRID.position
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.000001)
		var x0 := maxi(0, floori(minf(a.x, b.x) - reach))
		var x1 := mini(COLS - 1, ceili(maxf(a.x, b.x) + reach))
		var z0 := maxi(0, floori(minf(a.y, b.y) - reach))
		var z1 := mini(ROWS - 1, ceili(maxf(a.y, b.y) + reach))
		for z: int in range(z0, z1 + 1):
			var qz := float(z) + 0.5
			var row := z * COLS
			for x: int in range(x0, x1 + 1):
				var qx := float(x) + 0.5
				var t := clampf(((qx - a.x) * ab.x + (qz - a.y) * ab.y) / len2, 0.0, 1.0)
				var dx := qx - (a.x + ab.x * t)
				var dz := qz - (a.y + ab.y * t)
				var d := sqrt(dx * dx + dz * dz)
				if d < dist[row + x]: dist[row + x] = d
			visited += x1 - x0 + 1
		if visited > 30000:
			visited = 0
			stamped_a_frame = true
			await Kit.slice(park)
			if not is_instance_valid(park): return dist
	# Only where the old count-based yield fell: then the frame it gave.
	if stamped_a_frame: await Kit.settle(park, since)
	return dist

## Bilinear read of a grid; far (99) outside it.
static func _sample(arr: PackedFloat32Array, p: Vector2) -> float:
	var q := p - GRID.position - Vector2(0.5, 0.5)
	var x := floori(q.x)
	var z := floori(q.y)
	if x < 0 or z < 0 or x >= COLS - 1 or z >= ROWS - 1: return 99.0
	var f := q - Vector2(x, z)
	var i := z * COLS + x
	return lerpf(lerpf(arr[i], arr[i + 1], f.x), lerpf(arr[i + COLS], arr[i + COLS + 1], f.x), f.y)

## The band weight exactly as Biomes.weights_at computes it, from the grid.
static func _shore_w(ds: float, p: Vector2) -> float:
	var s := ds + Biomes.noise().get_noise_2dv(p * 1.7) * 3.0
	return 1.0 - smoothstep(Biomes.SHORE_FULL_M, Biomes.SHORE_EDGE_M, s)

static func _hero(p: Vector2) -> float:
	var h := 0.0
	for c: Vector2 in HEROES: h = maxf(h, 1.0 - smoothstep(7.0, 22.0, c.distance_to(p)))
	return h

static func _drift(p: Vector2, scale: float, offset: Vector2) -> float:
	return 0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * scale + offset)

static func _water_y(park: Node3D, terrain: Node) -> float:
	var water := park.find_child("LakeWaterSurface", true, false) as MeshInstance3D
	if water != null: return (water.global_transform * water.get_aabb()).position.y
	var y: Variant = terrain.get("WATER_Y")
	return float(y) if y != null else 0.102

## The visible ground height: terrain, or the bank ribbon on the mainland
## strip just above the waterline, whichever is higher.
static func _ground(terrain: Node, shore: PackedFloat32Array, p: Vector2) -> float:
	var y: float = terrain.height_at(p)
	var ds := _sample(shore, p)
	if ds >= BANK_M: return y
	var shoreline: PackedVector2Array = terrain.shoreline
	if Geometry2D.is_point_in_polygon(p, shoreline): return y # lake or island
	return maxf(y, lerpf(BANK_INNER_Y, BANK_OUTER_Y, ds / BANK_M))

## Spot rows whose point does not fall inside any stone footprint [p, r].
static func _clear_of(spots: Array, footprints: Array, pad: float) -> Array:
	if footprints.is_empty(): return spots
	var out: Array = []
	for spot: Array in spots:
		var p: Vector2 = spot[0]
		var free := true
		for f: Array in footprints:
			if p.distance_to(f[0]) < float(f[1]) + pad:
				free = false
				break
		if free: out.append(spot)
	return out

# ------------------------------------------------------------------- scan

## One pass over the band. Per 1 m cell, how many stand centres of each plant
## may start there; every centre then grows a stand of several clumps close
## round it, each clump checked on its own (distance to the waterline, water
## depth, walks, bridges). Rates come from the distance to the waterline, the
## band weight, slow noise drifts and the hero pockets.
static func _scan(park: Node3D, terrain: Node, rng: RandomNumberGenerator, shore: PackedFloat32Array, island: PackedFloat32Array, water_y: float) -> Dictionary:
	var out := {"reeds": [], "rushes": [], "sedges": [], "iris": [], "bank_iris": [], "low_bank": [], "stones": [], "lilies": [], "cells": 0, "groups": 0, "rejected": {"path": 0, "bridge": 0}}
	var trails := park.get_node_or_null("MidoriDesirePaths")
	var has_trails := trails != null and trails.has_method("distance_to_path")
	var has_paths := park.has_method("path_edge_distance_world")
	var shoreline: PackedVector2Array = terrain.shoreline
	var landings: Array[Rect2] = []
	var bounds: Variant = terrain.get("landing_bounds")
	if bounds is Array:
		for r: Variant in bounds: if r is Rect2: landings.append((r as Rect2).grow(2.5))
	var gap_at := func(q: Vector2) -> float:
		var g := 99.0
		if has_paths: g = float(park.path_edge_distance_world(q))
		if has_trails: g = minf(g, float(trails.distance_to_path(q)) - 0.4)
		return g
	var ctx := {"park": park, "terrain": terrain, "shore": shore, "island": island, "shoreline": shoreline, "water_y": water_y, "landings": landings, "gap_at": gap_at}
	var group := 0
	var since := Kit.frames_now()
	for z: int in range(ROWS):
		for x: int in range(COLS):
			var i := z * COLS + x
			var ds: float = shore[i]
			var di: float = island[i]
			if ds > SHORE_REACH and di > ISLAND_REACH: continue
			var c := GRID.position + Vector2(x + 0.5, z + 0.5)
			var water: bool = terrain.water_at(c)
			var ground: float = terrain.height_at(c)
			var depth := water_y - ground
			# Signed distance to the waterline: + inland, - out into the lake.
			var edge: float
			var w: float
			if water:
				edge = -minf(ds, di)
				w = 1.0
				if edge < -7.5: continue
			else:
				var on_island := Geometry2D.is_point_in_polygon(c, shoreline)
				edge = di if on_island else ds
				w = _shore_w(ds, c)
				if on_island or di < ISLAND_REACH: w = maxf(w, 0.75 * (1.0 - smoothstep(2.5, 6.0, di)))
				if w < 0.04: continue
			out.cells += 1
			if _near_bridge(park, c, landings):
				out.rejected.bridge += 1
				continue
			var gap: float = gap_at.call(c)
			if gap < 0.55:
				out.rejected.path += 1
				continue
			var h := _hero(c)
			# Lily rafts: open water a little way out from the bank.
			if water and edge < -1.4 and depth > 0.3:
				if rng.randf() < 0.22: out.lilies.append([c + _jitter(rng), h * 2.0 + rng.randf()])
				continue
			if water and depth > 0.42: continue
			var n_reed := _drift(c, 2.4, Vector2(31, 7))
			var n_iris := _drift(c, 3.1, Vector2(-17, 53))
			var n_rush := _drift(c, 1.9, Vector2(5, -41))
			# Iris: right at the waterline, in drifts; every hero pocket has some.
			var iris_band := (1.0 - smoothstep(0.1, 0.6, -edge)) if water else (1.0 - smoothstep(0.5, 1.7, edge))
			# The hero pockets keep a floor, so a low noise value there cannot
			# leave the pocket without iris (e.g. the iris_shore_east foreground).
			var iris_patch := clampf(smoothstep(0.48, 0.7, n_iris) + h * (0.4 + 0.6 * smoothstep(0.25, 0.5, n_iris)), 0.0, 1.0)
			var iris_rate := 0.45 * iris_band * iris_patch * w * (0.8 + 0.7 * h)
			# Reeds: the bank lip only, in stands with gaps between them.
			var reed_band := 1.0 - smoothstep(0.6, REED_REACH, absf(edge))
			var reed_patch := clampf(smoothstep(0.4, 0.7, n_reed) + h * 0.3, 0.0, 1.0)
			var reed_rate := 0.15 * reed_band * reed_patch * w * (0.6 + 0.7 * h) * (1.0 - 0.7 * iris_patch * iris_band)
			# Low rushes: patchy further up the bank, fading with the band, and
			# a few in the very edge of the water.
			var rush_rate := 0.0
			if not water: rush_rate = 0.075 * w * smoothstep(0.35, 0.68, n_rush) * smoothstep(0.4, 1.4, edge) * (1.0 - smoothstep(9.0, 13.0, edge))
			elif -edge < 0.7: rush_rate = 0.05 * smoothstep(0.45, 0.7, n_rush)
			rush_rate *= 1.0 - 0.6 * iris_patch
			# Bank meadow: knee-high sage sedge and grass with straw tips across
			# the damp bank behind the lip, in drifts, fullest in the hero
			# pockets (the concept's foreground bank), fading out with the band.
			var sedge_rate := 0.0
			var inland_iris := 0.0
			if not water:
				var n_sedge := _drift(c, 1.6, Vector2(-29, -12))
				var reach := lerpf(10.5, 14.0, h)
				sedge_rate = 0.11 * w * (0.45 + 1.1 * h) * smoothstep(0.36, 0.6, n_sedge + 0.15 * h) * smoothstep(1.0, 2.2, edge) * (1.0 - smoothstep(reach - 4.0, reach, edge))
				# Hero pockets also carry iris colonies some metres up the bank.
				inland_iris = 0.15 * h * h * w * clampf(smoothstep(0.42, 0.62, n_iris) + 0.25, 0.0, 1.0) * smoothstep(1.2, 2.0, edge) * (1.0 - smoothstep(6.0, 10.0, edge))
				sedge_rate *= 1.0 - 0.7 * smoothstep(0.5, 0.68, n_iris) * h
			if gap > 0.9:
				for k: int in range(_count(rng, sedge_rate)):
					group += 1
					_stand(out.sedges, rng, ctx, c + _jitter(rng), rng.randi_range(3, 6), 0.7, 0.8, 14.0, 0.0, 0.8, group, h)
				for k: int in range(_count(rng, inland_iris)):
					group += 1
					_stand(out.iris, rng, ctx, c + _jitter(rng), rng.randi_range(4, 7), 0.75, 1.2, 10.0, 0.0, 0.8, group, h)
			if gap > 1.2:
				for k: int in range(_count(rng, reed_rate)):
					group += 1
					_stand(out.reeds, rng, ctx, c + _jitter(rng), rng.randi_range(5, 9), 0.6, -REED_WATER_M, REED_REACH, REED_DEPTH, 0.85, group, h)
			if gap > 0.9:
				for k: int in range(_count(rng, iris_rate)):
					group += 1
					_stand(out.iris, rng, ctx, c + _jitter(rng), rng.randi_range(3, 6) + int(round(2.0 * h)), 0.85, -0.6, 1.9, IRIS_DEPTH, 0.65, group, h)
			for k: int in range(_count(rng, rush_rate)):
				group += 1
				_stand(out.rushes, rng, ctx, c + _jitter(rng), rng.randi_range(2, 5), 0.5, -0.7, 13.0, 0.3, 0.5, group, h)
			if gap > 1.5 and edge > -1.2 and edge < 2.6 and rng.randf() < 0.05 * w + 0.08 * h:
				out.stones.append([c + _jitter(rng), h + rng.randf(), water])
		# The scan only collects rows: yield on time, not on a row count.
		await Kit.slice(park)
		if not is_instance_valid(park): return out
	await Kit.settle(park, since)
	if not is_instance_valid(park): return out
	out.groups = group
	var bed_rng := RandomNumberGenerator.new()
	bed_rng.seed = 371105
	var bed_id := -1
	for key: String in BANK_BEDS:
		var bed: Vector4 = BANK_BEDS[key]
		var anchor := Vector2(bed.x, bed.y)
		var axis := Vector2.from_angle(bed_rng.randf_range(0.0, PI))
		for i: int in range(int(bed.w)):
			var centre := anchor + axis * bed_rng.randf_range(-0.5, 0.5) * bed.z + axis.orthogonal() * bed_rng.randf_range(-0.6, 0.6)
			_stand(out.bank_iris, bed_rng, ctx, centre, bed_rng.randi_range(4, 7), bed_rng.randf_range(0.37, 0.68), 0.08, 12.0, 0.0, 0.95, bed_id, 1.0)
		bed_id -= 1
	for pocket: Vector4 in LOW_BANK_POCKETS:
		for i: int in range(180):
			var az := bed_rng.randf() * TAU
			var offset := Vector2(cos(az) * pocket.z, sin(az) * pocket.w) * sqrt(bed_rng.randf())
			var centre := Vector2(pocket.x, pocket.y) + offset
			if _drift(centre, 1.4, Vector2(28, -53)) < 0.40: continue
			_stand(out.low_bank, bed_rng, ctx, centre, bed_rng.randi_range(3, 8), bed_rng.randf_range(0.4, 1.05), 0.06, 12.6, 0.0, 0.65, 0, 1.0)
	return out

## A stand: `count` clumps round a centre, packed towards it. Each clump must
## itself sit between `lo` and `hi` metres of the waterline (signed, + inland),
## in water no deeper than `max_depth`, `min_gap` clear of walks and off every
## bridge and landing. Rows: [p, edge, hero, group].
static func _stand(rows: Array, rng: RandomNumberGenerator, ctx: Dictionary, centre: Vector2, count: int, radius: float, lo: float, hi: float, max_depth: float, min_gap: float, group: int, h: float) -> void:
	var terrain: Node = ctx.terrain
	var water_y: float = ctx.water_y
	var gap_at: Callable = ctx.gap_at
	for k: int in range(count):
		var a := rng.randf() * TAU
		var q := centre + Vector2(cos(a), sin(a)) * radius * pow(rng.randf(), 0.75)
		var edge := _edge_at(ctx, q)
		if edge < lo or edge > hi: continue
		if edge < 0.0 and water_y - float(terrain.height_at(q)) > max_depth: continue
		if float(gap_at.call(q)) < min_gap: continue
		if _on_bridge(ctx, q): continue
		rows.append([q, edge, h, group])

## Signed distance to the nearest waterline (main shore or island): + on land.
static func _edge_at(ctx: Dictionary, q: Vector2) -> float:
	var terrain: Node = ctx.terrain
	var ds := _sample(ctx.shore, q)
	var di := _sample(ctx.island, q)
	if terrain.water_at(q): return -minf(ds, di)
	var shoreline: PackedVector2Array = ctx.shoreline
	return di if Geometry2D.is_point_in_polygon(q, shoreline) else ds

static func _on_bridge(ctx: Dictionary, q: Vector2) -> bool:
	for r: Rect2 in (ctx.landings as Array):
		if r.has_point(q): return true
	var park: Node3D = ctx.park
	if park.has_method("bridge_surface_height") and is_finite(float(park.bridge_surface_height(q))): return true
	if park.has_method("_is_near_future_bridge_corridor") and park._is_near_future_bridge_corridor(q / LAYOUT, 0.6): return true
	return false

static func _count(rng: RandomNumberGenerator, rate: float) -> int:
	if rate <= 0.0: return 0
	return int(rate) + (1 if rng.randf() < rate - floorf(rate) else 0)

static func _jitter(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf() - 0.5, rng.randf() - 0.5)

## Bridge decks, landings (with an apron) and the planned bridge corridors.
static func _near_bridge(park: Node3D, p: Vector2, landings: Array[Rect2]) -> bool:
	for r: Rect2 in landings: if r.has_point(p): return true
	if park.has_method("bridge_surface_height"):
		for o: Vector2 in [Vector2.ZERO, Vector2(1.8, 0), Vector2(-1.8, 0), Vector2(0, 1.8), Vector2(0, -1.8)]:
			if is_finite(float(park.bridge_surface_height(p + o))): return true
	if park.has_method("_is_near_future_bridge_corridor") and park._is_near_future_bridge_corridor(p / LAYOUT, 0.6): return true
	return false

## Nothing but ground or water under the point: no prop, deck, trunk or bench.
static func _bare(space: PhysicsDirectSpaceState3D, terrain: Node, p: Vector2, water_y: float) -> bool:
	var ground: float = terrain.height_at(p)
	var top := maxf(ground, water_y)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, top + 30.0, p.y), Vector3(p.x, ground - 1.0, p.y)))
	return hit.is_empty() or float(hit.position.y) < top + 0.35

## Keeps about `cap` rows, dropping whole stands evenly over the shore (so a
## cap thins the number of stands, never leaves stray singles).
static func _cap(rng: RandomNumberGenerator, rows: Array, cap: int) -> Array:
	if rows.size() <= cap: return rows
	var keep := float(cap) / float(rows.size())
	var verdict := {}
	var out: Array = []
	for row: Array in rows:
		var g: int = row[3]
		if not verdict.has(g): verdict[g] = rng.randf() < keep
		if verdict[g]: out.append(row)
	return out

# ------------------------------------------------------------- plant meshes

static func _buffer() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}

## `side` is the blade's sideways axis (always a unit vector, it is stored as
## the tangent) and `half` its half width there, for the shader's far-blade
## widening; solid parts pass half 0 and are never widened.
static func _vertex(buf: Dictionary, p: Vector3, n: Vector3, uv: Vector2, colour: Color, side: Vector3 = Vector3.RIGHT, half: float = 0.0) -> int:
	var index: int = buf.v.size()
	buf.v.append(p)
	buf.n.append(n)
	buf.t.append_array(PackedFloat32Array([side.x, side.y, side.z, 1.0]))
	buf.uv.append(uv)
	buf.uv2.append(Vector2(half, 0.0))
	buf.c.append(colour)
	return index

static func _finish(buf: Dictionary, name: String) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buf.v
	arrays[Mesh.ARRAY_NORMAL] = buf.n
	arrays[Mesh.ARRAY_TANGENT] = buf.t
	arrays[Mesh.ARRAY_TEX_UV] = buf.uv
	arrays[Mesh.ARRAY_TEX_UV2] = buf.uv2
	arrays[Mesh.ARRAY_COLOR] = buf.c
	arrays[Mesh.ARRAY_INDEX] = buf.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = name
	return mesh

static func _lin(r: float, g: float, b: float) -> Color:
	return Color(r, g, b).srgb_to_linear()

## Colour times k, alpha (the petal mask) untouched.
static func _shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## One narrow leaf blade from `base`: leaning out along `heading`, arching more
## towards the tip and turning `twist` radians along its length, so a clump of
## them crosses and catches light differently instead of reading as flat
## ribbons. `edge_on` turns the blade's flat face across the lean (iris fans
## lean within their own plane). `crease` adds a midrib vertex; a `tip_width`
## gives a blunt stem instead of a point. Returns the tip position.
static func _blade(buf: Dictionary, base: Vector3, heading: float, lean: float, bend: float, length: float, width: float, twist: float, c0: Color, c1: Color, c2: Color, rows: int, crease: bool = false, tip_width: float = 0.0, edge_on: bool = false) -> Vector3:
	var out := Vector3(cos(heading), 0.0, sin(heading))
	var pos := base
	var seg := length / float(rows)
	var start: int = buf.v.size()
	var k := 3 if crease else 2
	var pointed := tip_width <= 0.0
	var full := rows if pointed else rows + 1
	var tip := base
	for r: int in range(rows + 1):
		var t := float(r) / float(rows)
		var theta := lean + bend * t * t
		var tangent := (out * sin(theta) + Vector3.UP * cos(theta)).normalized()
		var spin := heading + twist * t + (0.0 if edge_on else PI * 0.5)
		var side := Vector3(cos(spin), 0.0, sin(spin))
		side -= tangent * side.dot(tangent)
		if side.length_squared() < 0.000001: side = Vector3(-out.z, 0.0, out.x)
		side = side.normalized()
		var normal := side.cross(tangent).normalized()
		if normal.y < 0.0: normal = -normal
		# Soft, mostly-up normals light both faces like a grass tuft.
		var soft := (normal * 0.55 + Vector3.UP * 0.45 + out * 0.12).normalized()
		var colour := c0.lerp(c1, smoothstep(0.0, 0.4, t)).lerp(c2, smoothstep(0.55, 1.0, t))
		colour.a = 0.0
		tip = pos
		if r == rows and pointed:
			_vertex(buf, pos, soft, Vector2(0.5, 1.0), colour, side, 0.0)
		else:
			var half: float
			if pointed: half = width * 0.5 * pow(1.0 - t, 0.7) * (0.8 + 0.2 * smoothstep(0.0, 0.15, t))
			else: half = lerpf(width, tip_width, t) * 0.5
			_vertex(buf, pos - side * half, soft, Vector2(0.0, t), colour, side, half)
			if crease: _vertex(buf, pos + normal * half * 0.35, soft, Vector2(0.5, t), _shade(colour, 1.06), side, 0.0)
			_vertex(buf, pos + side * half, soft, Vector2(1.0, t), colour, side, half)
		if r < rows: pos += tangent * seg
	for r: int in range(full - 1):
		var a := start + r * k
		var b := a + k
		for j: int in range(k - 1):
			buf.i.append_array(PackedInt32Array([a + j, b + j, a + j + 1, a + j + 1, b + j, b + j + 1]))
	if pointed:
		var last := start + (rows - 1) * k
		var top := start + rows * k
		for j: int in range(k - 1):
			buf.i.append_array(PackedInt32Array([last + j, top, last + j + 1]))
	return tip

## A straight stiff stalk from a to b: two crossed narrow strips, so it reads
## as a round stem from any side.
static func _stalk(buf: Dictionary, a: Vector3, b: Vector3, w0: float, w1: float, c0: Color, c1: Color, spin: float) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3(cos(spin), 0.0, sin(spin))
	var s1 := (ref - axis * ref.dot(axis)).normalized()
	var s2 := axis.cross(s1).normalized()
	for side: Vector3 in [s1, s2]:
		var start: int = buf.v.size()
		var normal := side.cross(axis).normalized()
		if normal.y < 0.0: normal = -normal
		var soft := (normal * 0.5 + Vector3.UP * 0.5).normalized()
		for r: int in range(3):
			var t := float(r) * 0.5
			var p := a.lerp(b, t)
			var half := lerpf(w0, w1, t) * 0.5
			var c := c0.lerp(c1, t)
			c.a = 0.0
			_vertex(buf, p - side * half, soft, Vector2(0.0, t), c, side, half)
			_vertex(buf, p + side * half, soft, Vector2(1.0, t), c, side, half)
		for r: int in range(2):
			var i0 := start + r * 2
			buf.i.append_array(PackedInt32Array([i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3]))

## A cattail's seed head: a short rounded six-sided spindle along `axis`.
static func _head(buf: Dictionary, h0: Vector3, axis: Vector3, length: float, radius: float, colour: Color) -> void:
	var s1 := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
	var s2 := axis.cross(s1).normalized()
	var c := colour
	c.a = 0.0
	var rings: Array[Vector2] = [Vector2(0.0, 0.6), Vector2(0.14, 1.0), Vector2(0.86, 1.0), Vector2(1.0, 0.62)]
	var sides := 6
	var bottom := _vertex(buf, h0 - axis * 0.006, -axis, Vector2(0.5, 0.0), c, s1, 0.0)
	var starts: Array[int] = []
	for ring: Vector2 in rings:
		starts.append(buf.v.size())
		for k: int in range(sides):
			var a := TAU * float(k) / float(sides)
			var radial := s1 * cos(a) + s2 * sin(a)
			var shade := 0.9 + 0.1 * sin(a * 2.0 + ring.x * 3.0)
			_vertex(buf, h0 + axis * (ring.x * length) + radial * radius * ring.y, (radial + Vector3.UP * 0.35).normalized(), Vector2(0.5, ring.x), _shade(c, shade), s1, 0.0)
	var top := _vertex(buf, h0 + axis * (length + 0.006), axis, Vector2(0.5, 1.0), c, s1, 0.0)
	var first: int = starts[0]
	var last: int = starts[starts.size() - 1]
	for k: int in range(sides):
		var k1 := (k + 1) % sides
		buf.i.append_array(PackedInt32Array([bottom, first + k, first + k1, last + k, top, last + k1]))
	for r: int in range(rings.size() - 1):
		var a: int = starts[r]
		var b: int = starts[r + 1]
		for k: int in range(sides):
			var k1 := (k + 1) % sides
			buf.i.append_array(PackedInt32Array([a + k, b + k, a + k1, a + k1, b + k, b + k1]))

## A reedmace (cattail) stem standing up through the clump: a stiff stalk, the
## dark brown head nestled at about the blade tops, a thin straw spike above.
static func _cattail(buf: Dictionary, base: Vector3, heading: float, lean: float, length: float, rng: RandomNumberGenerator) -> void:
	var axis := (Vector3(cos(heading), 0.0, sin(heading)) * sin(lean) + Vector3.UP * cos(lean)).normalized()
	var head_len := rng.randf_range(0.12, 0.17)
	var radius := rng.randf_range(0.011, 0.014)
	var spike := rng.randf_range(0.06, 0.1)
	var s0 := maxf(0.3, length - head_len - spike)
	_stalk(buf, base, base + axis * (s0 + 0.01), 0.0075, 0.006, _lin(0.22, 0.25, 0.12), _lin(0.34, 0.36, 0.19), rng.randf() * TAU)
	var h0 := base + axis * s0
	var h1 := h0 + axis * head_len
	_head(buf, h0, axis, head_len, radius, _shade(_lin(0.27, 0.17, 0.09), rng.randf_range(0.85, 1.12)))
	_stalk(buf, h1, h1 + axis * spike, 0.0045, 0.0018, _lin(0.4, 0.34, 0.21), _lin(0.52, 0.46, 0.31), rng.randf() * TAU)

## A clump of narrow blades from one rootstock, spreading from a small base,
## the outer blades shorter and leaning further; about half turn their flat
## face across the others so the clump has depth from every side. Reed
## clumps can carry a few cattails.
static func _clump_mesh(seed_value: int, spec: Dictionary, name: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buf := _buffer()
	var spread: float = spec.spread
	var h_min: float = spec.h_min
	var h_max: float = spec.h_max
	var palette: Array = spec.palette
	var dead_palette: Array = spec.dead_palette
	var twist: float = spec.twist
	for b: int in range(int(spec.blades)):
		var az := rng.randf() * TAU
		var r := spread * sqrt(rng.randf())
		var base := Vector3(cos(az) * r, -0.02, sin(az) * r)
		var outer := r / maxf(spread, 0.001)
		var height := rng.randf_range(h_min, h_max) * (1.0 - 0.22 * outer)
		var lean := rng.randf_range(float(spec.lean_min), float(spec.lean_max)) * (0.5 + 0.9 * outer)
		var bend := rng.randf_range(float(spec.bend_min), float(spec.bend_max)) * (0.5 + 0.5 * height / h_max)
		var width := rng.randf_range(float(spec.w_min), float(spec.w_max))
		var pal: Array = dead_palette if rng.randf() < float(spec.dead) else palette
		var shade := rng.randf_range(0.86, 1.08)
		var c0: Color = pal[0]
		var c1: Color = pal[1]
		var c2: Color = pal[2]
		_blade(buf, base, az + rng.randf_range(-0.5, 0.5), lean, bend, height, width, rng.randf_range(-twist, twist), _shade(c0, shade), _shade(c1, shade), _shade(c2, shade), int(spec.rows), false, 0.0, rng.randf() < float(spec.edge_on))
	for k: int in range(int(spec.get("cattails", 0))):
		var az := rng.randf() * TAU
		var base := Vector3(cos(az), 0.0, sin(az)) * spread * 0.6 * rng.randf() + Vector3(0.0, -0.02, 0.0)
		_cattail(buf, base, az + rng.randf_range(-0.4, 0.4), rng.randf_range(0.02, 0.12), h_max * rng.randf_range(0.86, 1.0), rng)
	# Grass seed stalks: a thin straw stem rising a little above the blades,
	# ending in a slim nodding head.
	for k: int in range(int(spec.get("plumes", 0))):
		var az := rng.randf() * TAU
		var base := Vector3(cos(az), 0.0, sin(az)) * spread * 0.5 * rng.randf() + Vector3(0.0, -0.02, 0.0)
		var stem0 := _lin(0.3, 0.3, 0.16)
		var stem1 := _lin(0.5, 0.45, 0.28)
		var top := _blade(buf, base, az, rng.randf_range(0.08, 0.25), rng.randf_range(0.1, 0.3), h_max * rng.randf_range(1.0, 1.15), 0.004, 0.0, stem0, stem1, stem1, 3, false, 0.003)
		var head0 := _lin(0.48, 0.42, 0.27)
		var head1 := _lin(0.62, 0.55, 0.37)
		_blade(buf, top - Vector3(0.0, 0.01, 0.0), az + rng.randf_range(-0.3, 0.3), rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 0.9), rng.randf_range(0.1, 0.15), 0.016, 0.3, head0, head1, head1, 3, false, 0.0, true)
	return _finish(buf, name)

## Reed / reedmace clump: knee-to-waist high (it stays under eye height, so no
## head ever shows against the sky), 5-10 mm blades.
static func _reed_spec(blades: int, cattails: int) -> Dictionary:
	return {"blades": blades, "cattails": cattails, "spread": 0.13, "h_min": 0.6, "h_max": 1.25, "lean_min": 0.04, "lean_max": 0.3, "bend_min": 0.1, "bend_max": 0.6, "w_min": 0.0055, "w_max": 0.0105, "rows": 4, "dead": 0.2, "twist": 0.9, "edge_on": 0.5,
		"palette": [_lin(0.16, 0.15, 0.08), _lin(0.3, 0.33, 0.16), _lin(0.42, 0.41, 0.24)],
		"dead_palette": [_lin(0.3, 0.26, 0.16), _lin(0.48, 0.42, 0.28), _lin(0.58, 0.52, 0.36)]}

## Bank sedge / tall grass: knee to thigh high, arching, sage olive with dry
## straw blades mixed in (never lime).
static func _sedge_spec(blades: int, plumes: int) -> Dictionary:
	return {"blades": blades, "plumes": plumes, "spread": 0.12, "h_min": 0.5, "h_max": 0.95, "lean_min": 0.1, "lean_max": 0.5, "bend_min": 0.4, "bend_max": 1.3, "w_min": 0.0045, "w_max": 0.0085, "rows": 4, "dead": 0.3, "twist": 0.7, "edge_on": 0.4,
		"palette": [_lin(0.17, 0.18, 0.09), _lin(0.31, 0.33, 0.17), _lin(0.46, 0.45, 0.27)],
		"dead_palette": [_lin(0.34, 0.29, 0.18), _lin(0.52, 0.46, 0.3), _lin(0.63, 0.56, 0.39)]}

static func _rush_spec() -> Dictionary:
	return {"blades": 26, "spread": 0.07, "h_min": 0.3, "h_max": 0.62, "lean_min": 0.05, "lean_max": 0.35, "bend_min": 0.2, "bend_max": 0.9, "w_min": 0.0035, "w_max": 0.006, "rows": 3, "dead": 0.22, "twist": 0.6, "edge_on": 0.5,
		"palette": [_lin(0.2, 0.2, 0.11), _lin(0.33, 0.35, 0.18), _lin(0.47, 0.45, 0.28)],
		"dead_palette": [_lin(0.32, 0.28, 0.18), _lin(0.5, 0.45, 0.3), _lin(0.6, 0.54, 0.38)]}

## One iris petal: narrow claw at the base, broad blade, rounded tip, cupped
## along its midline. Colours carry the petal mask in alpha.
static func _petal(buf: Dictionary, base: Vector3, heading: float, theta0: float, bend: float, length: float, width: float, cup: float, c0: Color, c1: Color, c2: Color, rows: int) -> void:
	var out := Vector3(cos(heading), 0.0, sin(heading))
	var side := Vector3(-out.z, 0.0, out.x)
	var pos := base
	var seg := length / float(rows)
	var start: int = buf.v.size()
	var tangent := Vector3.UP
	var normal := Vector3.UP
	for r: int in range(rows + 1):
		var t := float(r) / float(rows)
		var theta := theta0 + bend * t * t
		tangent = (out * sin(theta) + Vector3.UP * cos(theta)).normalized()
		normal = side.cross(tangent).normalized()
		if normal.y < 0.0: normal = -normal
		var soft := (normal * 0.7 + Vector3.UP * 0.3).normalized()
		var half := width * 0.5 * pow(sin(PI * clampf(0.12 + 0.8 * t, 0.0, 1.0)), 0.6) * (0.3 + 0.7 * smoothstep(0.0, 0.4, t))
		var colour := c0.lerp(c1, smoothstep(0.0, 0.35, t)).lerp(c2, smoothstep(0.4, 1.0, t))
		_vertex(buf, pos - side * half, soft, Vector2(0.0, t), colour, side, 0.0)
		_vertex(buf, pos + normal * half * cup, soft, Vector2(0.5, t), _shade(colour, 0.78), side, 0.0)
		_vertex(buf, pos + side * half, soft, Vector2(1.0, t), colour, side, 0.0)
		if r < rows: pos += tangent * seg
	var apex := _vertex(buf, pos + tangent * seg * 0.4, (normal * 0.7 + Vector3.UP * 0.3).normalized(), Vector2(0.5, 1.0), c2, side, 0.0)
	for r: int in range(rows):
		var a := start + r * 3
		var b := a + 3
		for j: int in range(2):
			buf.i.append_array(PackedInt32Array([a + j, b + j, a + j + 1, a + j + 1, b + j, b + j + 1]))
	var last := start + rows * 3
	buf.i.append_array(PackedInt32Array([last, apex, last + 1, last + 1, apex, last + 2]))

## A hanashobu bloom: three broad falls spreading and drooping, each with a
## yellow signal at its base, and three small upright standards between them.
static func _bloom(buf: Dictionary, top: Vector3, rng: RandomNumberGenerator) -> void:
	var a0 := rng.randf() * TAU
	var fleck := Color(0.72, 0.5, 0.08, 0.0)
	for k: int in range(3):
		var hd := a0 + TAU * float(k) / 3.0 + rng.randf_range(-0.15, 0.15)
		_petal(buf, top, hd, rng.randf_range(1.12, 1.35), rng.randf_range(1.2, 1.7), rng.randf_range(0.071, 0.093), rng.randf_range(0.05, 0.065), 0.38, fleck, Color(0.63, 0.63, 0.63, 1.0), Color(0.88, 0.88, 0.88, 1.0), 4)
	for k: int in range(3):
		var hd := a0 + PI / 3.0 + TAU * float(k) / 3.0
		_petal(buf, top + Vector3(0.0, 0.004, 0.0), hd, rng.randf_range(0.25, 0.45), 0.35, 0.045, 0.017, 0.2, Color(0.48, 0.48, 0.48, 1.0), Color(0.66, 0.66, 0.66, 1.0), Color(0.82, 0.82, 0.82, 1.0), 2)

## A closed bud: two crossed narrow upright petals, deeper coloured.
static func _bud(buf: Dictionary, top: Vector3, rng: RandomNumberGenerator) -> void:
	var az := rng.randf() * TAU
	for k: int in range(2):
		_petal(buf, top - Vector3(0.0, 0.004, 0.0), az + PI * 0.5 * float(k), 0.04, 0.0, 0.06, 0.016, 0.0, Color(0.3, 0.32, 0.18, 0.0), Color(0.4, 0.4, 0.4, 1.0), Color(0.5, 0.5, 0.5, 1.0), 2)

## A hanashobu plant: two or three fans of upright sword leaves (each fan's
## leaves lean apart within its own plane, as iris leaves grow), and
## `flowers` bloom stalks plus `buds` bud stalks rising to about the leaf tips
## or a little above, each with a short spathe leaf under the bloom.
static func _iris_mesh(seed_value: int, flowers: int, buds: int, name: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buf := _buffer()
	var leaf := [_lin(0.15, 0.19, 0.09), _lin(0.25, 0.31, 0.14), _lin(0.34, 0.37, 0.19)]
	var dead := [_lin(0.3, 0.27, 0.16), _lin(0.45, 0.41, 0.26), _lin(0.55, 0.5, 0.33)]
	var stalk0 := _lin(0.2, 0.25, 0.11)
	var stalk1 := _lin(0.3, 0.35, 0.16)
	var fans := rng.randi_range(2, 3)
	for f: int in range(fans):
		var dir := rng.randf() * TAU
		var origin := Vector3(cos(dir + 1.4), 0.0, sin(dir + 1.4)) * rng.randf_range(0.0, 0.05)
		var n := rng.randi_range(4, 6)
		for k: int in range(n):
			var across := float(k) / float(n - 1) * 2.0 - 1.0
			var heading := dir if across >= 0.0 else dir + PI
			var lean := 0.04 + absf(across) * rng.randf_range(0.32, 0.53)
			var length := rng.randf_range(0.5, 0.78) * (1.0 - 0.3 * absf(across))
			var bend := rng.randf_range(0.08, 0.4) * (0.4 + absf(across))
			var pal: Array = dead if rng.randf() < 0.08 else leaf
			var shade := rng.randf_range(0.86, 1.08)
			var base := origin + Vector3(cos(dir), 0.0, sin(dir)) * across * 0.025 + Vector3(0.0, -0.02, 0.0)
			_blade(buf, base, heading, lean, bend, length, rng.randf_range(0.022, 0.032), rng.randf_range(-0.32, 0.32), _shade(pal[0], shade), _shade(pal[1], shade), _shade(pal[2], shade), 4, true, 0.0, true)
	for s: int in range(flowers + buds):
		var az := rng.randf() * TAU
		var base := Vector3(cos(az), 0.0, sin(az)) * rng.randf_range(0.0, 0.04) + Vector3(0.0, -0.02, 0.0)
		var length := rng.randf_range(0.58, 0.78) - (0.1 if s >= flowers else 0.0)
		var top := _blade(buf, base, az, rng.randf_range(0.02, 0.1), 0.04, length, 0.0065, 0.0, stalk0, stalk1, stalk1, 3, false, 0.0045)
		_blade(buf, top - Vector3(0.0, 0.07, 0.0), az + PI + rng.randf_range(-0.4, 0.4), 0.25, 0.2, 0.09, 0.012, 0.0, stalk1, leaf[1], leaf[2], 2)
		if s < flowers: _bloom(buf, top, rng)
		else: _bud(buf, top, rng)
	return _finish(buf, name)

static func _plant_material(petals: bool, sway: float) -> ShaderMaterial:
	# Two pooled shaders (with / without petal tint) serve every plant material
	# here and in the coppice; sway is a uniform per material.
	var material := ShaderPool.material(PLANT_SHADER.replace("//CUSTOM", "petal_tint = INSTANCE_CUSTOM.rgb;") if petals else PLANT_SHADER)
	material.set_shader_parameter("sway", sway)
	return material

## Like Kit.cell_batches, but each row also carries a custom colour
## ([transform, colour, custom]) for the shader's INSTANCE_CUSTOM.
static func _custom_batches(parent: Node3D, name: String, mesh: Mesh, material: Material, rows: Array, cell: float, range_end: float, shadows: bool) -> int:
	return _rows_batches(parent, name, mesh, material, rows, cell, range_end, GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

## Visible plant batches never cast shadows; this draws the same rows again
## as shadow-only casters in small cells near the camera only.
static func _near_shadows(parent: Node3D, name: String, mesh: Mesh, material: Material, rows: Array) -> int:
	return _rows_batches(parent, name, mesh, material, rows, 10.0, NEAR_SHADOW_M, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)

## Rows are [transform, colour] or [transform, colour, custom].
static func _rows_batches(parent: Node3D, name: String, mesh: Mesh, material: Material, rows: Array, cell: float, range_end: float, shadow: GeometryInstance3D.ShadowCastingSetting) -> int:
	if rows.is_empty(): return 0
	var cells := {}
	for row: Array in rows:
		var t: Transform3D = row[0]
		var key := Vector2i(floori(t.origin.x / cell), floori(t.origin.z / cell))
		if not cells.has(key): cells[key] = []
		(cells[key] as Array).append(row)
	var keys: Array = cells.keys()
	# Each cell's buffer is pure data: packed on WorkerThreadPool when large.
	var pack := func(i: int) -> PackedFloat32Array:
		var k: Vector2i = keys[i]
		var cell_rows: Array = cells[k]
		return Kit.pack_rows(cell_rows, Vector3((k.x + 0.5) * cell, 0.0, (k.y + 0.5) * cell), true, (cell_rows[0] as Array).size() > 2)
	var buffers: Array = []
	if rows.size() >= Kit.PACK_THREADS_MIN and keys.size() > 1: buffers = Kit.parallel(keys.size(), pack, "iris_shore pack")
	else:
		for i: int in range(keys.size()): buffers.append(pack.call(i))
	for index: int in range(keys.size()):
		var key: Vector2i = keys[index]
		var list: Array = cells[key]
		var centre := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		var custom: bool = (list[0] as Array).size() > 2
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_colors = true
		many.use_custom_data = custom
		many.mesh = mesh
		many.instance_count = list.size()
		many.buffer = buffers[index]
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d_%d" % [name, key.x, key.y]
		node.multimesh = many
		node.position = centre
		node.material_override = material
		node.extra_cull_margin = 0.1
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = range_end * 0.15
		var shadow_only := shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED if shadow_only else GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = shadow
		parent.add_child(node)
	return cells.size()

# ------------------------------------------------------------------ plants

static func _reeds(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, spots: Array, water_y: float, shore: PackedFloat32Array) -> Dictionary:
	var space := park.get_world_3d().direct_space_state
	var meshes: Array[ArrayMesh] = [_clump_mesh(71101, _reed_spec(54, 3), "ShoreReedClumpA"), _clump_mesh(71102, _reed_spec(60, 0), "ShoreReedClumpB")]
	var rows: Array = [[], []]
	var standing: Array = []
	for spot: Array in _cap(rng, spots, MAX_REEDS):
		if _bare(space, terrain, spot[0], water_y): standing.append(spot)
	# A reed never stands alone: a clump needs two others within reach, so
	# every reed is part of a bed at the bank lip, never a single in the water.
	var placed := _in_company(_in_company(standing, 0.85, 2), 0.85, 2)
	var supported := _supported_stand(placed, terrain, water_y, 2)
	var wet := 0
	for spot: Array in placed:
		var p: Vector2 = spot[0]
		var h: float = spot[2]
		var ground := _ground(terrain, shore, p)
		# Standing in water, the clump rises from the bed: the drowned part is
		# made up so the blades above water keep their height.
		var tall := rng.randf_range(0.84, 1.12) * (1.0 + 0.8 * maxf(0.0, water_y - ground))
		var wide := rng.randf_range(0.85, 1.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06)) * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06))
		var t := Transform3D(basis.scaled(Vector3(wide, tall, wide)), Vector3(p.x, ground - 0.02, p.y))
		var tint := Color(1, 1, 1).lerp(Color(1.1, 1.03, 0.86), rng.randf() * rng.randf()) * rng.randf_range(0.88, 1.04)
		var variant := 0 if rng.randf() < 0.4 + 0.2 * h else 1
		if not supported.has(p): continue
		rows[variant].append([t, tint])
		if terrain.water_at(p): wet += 1
	var material := _plant_material(false, 0.03)
	for k: int in range(2):
		_rows_batches(root, "ShoreReeds%s" % ["A", "B"][k], meshes[k], material, rows[k], 24.0, REED_RANGE_M, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_near_shadows(root, "ShoreShadowReeds%s" % ["A", "B"][k], meshes[k], material, rows[k])
	var count: int = rows[0].size() + rows[1].size()
	return {"clumps": count, "cattails": rows[0].size() * 3, "dropped_singles": standing.size() - count, "wet": wet}

## Wet stems require a surviving dry clump within 75 cm on the same lip.
## Re-evaluate after each prune; removing an unsupported wet clump can strand
## a dry reed at the edge of a stand. Dry rushes can grow away from the lip.
static func _supported_stand(spots: Array, terrain: Node, water_y: float, neighbours: int) -> Dictionary:
	var candidates: Array = []
	var wet := {}
	for spot: Array in spots:
		var p: Vector2 = spot[0]
		if terrain.water_at(p):
			if float(spot[1]) < -0.35 or water_y - float(terrain.height_at(p)) > 0.16: continue
			wet[p] = true
		candidates.append(spot)
	var valid := {}
	while not candidates.is_empty():
		var clustered := _in_company(candidates, 0.85, neighbours) if neighbours else candidates
		var dry := {}
		for spot: Array in clustered:
			if not wet.has(spot[0]): _bucket(dry, spot[0])
		var next: Array = []
		for spot: Array in clustered:
			if not wet.has(spot[0]) or _bucket_near(dry, spot[0], 0.75):
				next.append(spot)
		if next.size() == candidates.size():
			for spot: Array in next: valid[spot[0]] = true
			break
		candidates = next
	return valid

## Rows ([p, ...]) that have at least `need` other rows within `reach` metres.
static func _in_company(rows: Array, reach: float, need: int) -> Array:
	var grid := {}
	for row: Array in rows:
		var p: Vector2 = row[0]
		_bucket(grid, p)
	var out: Array = []
	for row: Array in rows:
		var p: Vector2 = row[0]
		var cx := floori(p.x / 1.5)
		var cz := floori(p.y / 1.5)
		var near := -1 # the row itself is counted once
		for z: int in range(cz - 1, cz + 2):
			for x: int in range(cx - 1, cx + 2):
				var key := Vector2i(x, z)
				if not grid.has(key): continue
				for q: Vector2 in (grid[key] as PackedVector2Array):
					if q.distance_to(p) < reach: near += 1
		if near >= need: out.append(row)
	return out

static func _rushes(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, spots: Array, water_y: float, shore: PackedFloat32Array) -> Dictionary:
	var space := park.get_world_3d().direct_space_state
	var mesh := _clump_mesh(71103, _rush_spec(), "ShoreRushClump")
	var rows: Array = []
	# The few rushes out in the water's edge only in company, never alone.
	var dry: Array = []
	var wet: Array = []
	for spot: Array in _cap(rng, spots, MAX_RUSHES): (wet if float(spot[1]) < 0.0 else dry).append(spot)
	var standing: Array = []
	for spot: Array in dry + _in_company(wet, 0.7, 1):
		if _bare(space, terrain, spot[0], water_y): standing.append(spot)
	var supported := _supported_stand(standing, terrain, water_y, 0)
	var wet_count := 0
	for spot: Array in standing:
		var p: Vector2 = spot[0]
		var s := rng.randf_range(0.75, 1.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
		var t := Transform3D(basis.scaled(Vector3(s * rng.randf_range(0.9, 1.3), s, s * rng.randf_range(0.9, 1.3))), Vector3(p.x, _ground(terrain, shore, p) - 0.015, p.y))
		var tint := Color(1, 1, 1).lerp(Color(1.1, 1.03, 0.85), rng.randf()) * rng.randf_range(0.88, 1.05)
		if not supported.has(p): continue
		rows.append([t, tint])
		if terrain.water_at(p): wet_count += 1
	Kit.cell_batches(root, "ShoreRushes", mesh, _plant_material(false, 0.04), rows, 32.0, 70.0, false)
	return {"count": rows.size(), "wet": wet_count}

## Bank meadow sedge: two clump shapes, a few straw-tipped seed stalks in one.
static func _sedges(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, spots: Array, water_y: float, shore: PackedFloat32Array) -> int:
	var space := park.get_world_3d().direct_space_state
	var meshes: Array[ArrayMesh] = [_clump_mesh(71107, _sedge_spec(40, 5), "ShoreSedgeClumpA"), _clump_mesh(71108, _sedge_spec(46, 0), "ShoreSedgeClumpB")]
	var rows: Array = [[], []]
	for spot: Array in _cap(rng, spots, MAX_SEDGES):
		var p: Vector2 = spot[0]
		if not _bare(space, terrain, p, water_y): continue
		var s := rng.randf_range(0.8, 1.2) * (1.0 + 0.15 * float(spot[2]))
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.07, 0.07))
		var t := Transform3D(basis.scaled(Vector3(s * rng.randf_range(0.9, 1.25), s, s * rng.randf_range(0.9, 1.25))), Vector3(p.x, _ground(terrain, shore, p) - 0.02, p.y))
		var tint := Color(1, 1, 1).lerp(Color(1.12, 1.04, 0.84), rng.randf() * rng.randf()) * rng.randf_range(0.86, 1.04)
		rows[0 if rng.randf() < 0.45 else 1].append([t, tint])
	var material := _plant_material(false, 0.045)
	for k: int in range(2):
		_rows_batches(root, "ShoreSedge%s" % ["A", "B"][k], meshes[k], material, rows[k], 24.0, 60.0, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_near_shadows(root, "ShoreShadowSedge%s" % ["A", "B"][k], meshes[k], material, rows[k])
	return rows[0].size() + rows[1].size()

## Hanashobu drifts: plants of sword-leaf fans, most with one or two violet
## blooms or a bud. One colour per drift (the odd drift white), as a planted
## cultivar would be.
static func _iris(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, spots: Array, beds: Array, water_y: float, shore: PackedFloat32Array) -> Dictionary:
	var out := {"rhizomes": 0, "flowers": 0, "swords": 0, "beds": {}}
	var space := park.get_world_3d().direct_space_state
	var meshes: Array[ArrayMesh] = [_iris_mesh(71104, 2, 0, "ShoreIrisBloomsA"), _iris_mesh(71105, 1, 1, "ShoreIrisBloomsB"), _iris_mesh(71106, 0, 0, "ShoreIrisLeaves")]
	var blooms: Array[int] = [2, 1, 0]
	var violets: Array[Color] = [Color(0.52, 0.4, 0.82), Color(0.45, 0.33, 0.75), Color(0.58, 0.46, 0.85), Color(0.4, 0.28, 0.66), Color(0.5, 0.36, 0.72)]
	var rows: Array = [[], [], []]
	var bed_names := BANK_BEDS.keys()
	for name: String in bed_names: out.beds[name] = 0
	# Trade a share of the widespread planting for a known number in each bed.
	for spot: Array in _cap(rng, spots, MAX_RHIZOMES - beds.size()) + beds:
		var p: Vector2 = spot[0]
		var h: float = spot[2]
		var group: int = spot[3]
		if not _bare(space, terrain, p, water_y): continue
		var at := Vector3(p.x, _ground(terrain, shore, p) - 0.01, p.y)
		var size := rng.randf_range(0.72, 1.03) + 0.06 * h
		if group < 0: size *= 1.22
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
		var roll := rng.randf()
		var which := 0 if roll < 0.36 + 0.15 * h else (1 if roll < 0.8 else 2)
		var violet: Color = Color(0.8, 0.78, 0.84) if group % 13 == 0 else violets[posmod(group, violets.size())]
		if group < 0:
			out.beds[bed_names[-group - 1]] += 1
		violet = (violet * rng.randf_range(0.92, 1.06)).srgb_to_linear()
		violet.a = 1.0
		rows[which].append([Transform3D(basis.scaled(Vector3.ONE * size), at), _shade(Color.WHITE, rng.randf_range(0.9, 1.06)), violet])
		out.flowers += blooms[which]
		out.rhizomes += 1
	var material := _plant_material(true, 0.02)
	_custom_batches(root, "ShoreIrisA", meshes[0], material, rows[0], 28.0, 65.0, false)
	_custom_batches(root, "ShoreIrisB", meshes[1], material, rows[1], 28.0, 65.0, false)
	_custom_batches(root, "ShoreIrisC", meshes[2], material, rows[2], 28.0, 65.0, false)
	out.swords = out.rhizomes
	return out

## A short arching sedge under the flowering fans fills the peat in irregular
## tussocks. Shared opaque geometry; no distant or duplicate shadow meshes.
static func _low_bank_fans(park: Node3D, terrain: Node, root: Node3D, spots: Array, water_y: float, shore: PackedFloat32Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71316
	var spec := _sedge_spec(15, 0)
	spec.merge({"spread": 0.12, "h_min": 0.17, "h_max": 0.41, "w_min": 0.010, "w_max": 0.019,
			"lean_min": 0.32, "lean_max": 0.83, "bend_min": 0.43, "bend_max": 1.32, "dead": 0.27, "rows": 3}, true)
	var mesh := _clump_mesh(71983, spec, "LowBankSedge")
	var space := park.get_world_3d().direct_space_state
	var used := {}
	var rows: Array = []
	for spot: Array in spots:
		var p: Vector2 = spot[0]
		if _bucket_near(used, p, 0.20) or not _bare(space, terrain, p, water_y): continue
		_bucket(used, p)
		var wide := rng.randf_range(0.84, 1.42)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, rng.randf_range(0.63, 1.22), wide))
		var colour := Color(0.85, 0.94, 0.75).lerp(Color(1.08, 0.98, 0.8), rng.randf())
		rows.append([Transform3D(basis, Vector3(p.x, _ground(terrain, shore, p) - 0.01, p.y)), colour])
	Kit.cell_batches(root, "LowBankSedge", mesh, _plant_material(false, 0.022), rows, 12.0, 39.0, false)
	return rows.size()

# ---------------------------------------------------------- stones, moss

## Groups of one to four half-sunk mossy stones at the waterline, a ring of
## moss on the bank round the bigger ones. The big ones collide.
static func _stones(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, spots: Array, water_y: float, shore: PackedFloat32Array) -> Dictionary:
	var out := {"stones": 0, "colliders": 0, "moss": 0, "footprints": [], "excluded": []}
	var protos: Array[Dictionary] = []
	for i: int in range(6):
		var proto := Kit.file_parts(FLOOR + "stone_%02d.glb" % i)
		for part: Dictionary in proto.parts:
			var stone_mesh: Mesh = part.mesh
			for s: int in range(stone_mesh.get_surface_count()):
				var old := stone_mesh.surface_get_material(s) as BaseMaterial3D
				if old == null: continue
				var damp_stone := old.duplicate() as BaseMaterial3D
				damp_stone.albedo_color *= Color(0.48, 0.60, 0.64)
				damp_stone.roughness = 0.91
				stone_mesh.surface_set_material(s, damp_stone)
		if not proto.parts.is_empty(): protos.append(proto)
	if protos.is_empty(): return out
	var space := park.get_world_3d().direct_space_state
	var trails := park.get_node_or_null("MidoriDesirePaths")
	var has_trails := trails != null and trails.has_method("distance_to_path")
	var has_paths := park.has_method("path_edge_distance_world")
	spots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var centres: Array[Vector2] = []
	for spot: Array in spots:
		if centres.size() >= MAX_STONE_GROUPS: break
		var p: Vector2 = spot[0]
		var gap := 5.0 if _hero(p) > 0.4 else 10.0
		var spaced := true
		for c: Vector2 in centres: if c.distance_to(p) < gap: spaced = false
		if spaced and _bare(space, terrain, p, water_y): centres.append(p)
	var rows: Array = []
	for i: int in range(protos.size()): rows.append([])
	var rings: Array = []
	var convex := {}
	for c: Vector2 in centres:
		var count := rng.randi_range(1, 4)
		var lead := rng.randf_range(0.5, 1.1) + 0.3 * _hero(c)
		for k: int in range(count):
			var p := c
			var size := lead
			if k > 0:
				var a := rng.randf() * TAU
				p = c + Vector2(cos(a), sin(a)) * rng.randf_range(0.5, 1.5) * lead
				size = lead * rng.randf_range(0.3, 0.6)
				# The group centre is clear of walks; its satellites must be too,
				# and not lost under deeper water.
				if has_paths and park.path_edge_distance_world(p) < 0.6 + size * 0.5: continue
				if has_trails and trails.distance_to_path(p) - 0.4 < 0.6 + size * 0.5: continue
				if water_y - float(terrain.height_at(p)) > 0.3: continue
				if not _bare(space, terrain, p, water_y): continue
			var which := rng.randi() % protos.size()
			var proto: Dictionary = protos[which]
			var box: AABB = proto.box
			var height := size * box.size.y / maxf(0.001, maxf(box.size.x, box.size.z))
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
			var t := Kit.seat(proto, terrain, p, height, rng.randf() * TAU, height * rng.randf_range(0.25, 0.4), tilt)
			# Kit.seat sits on terrain; lift onto the bank ribbon where it covers it.
			var ground := _ground(terrain, shore, p)
			t.origin.y += ground - float(terrain.height_at(p))
			# Low reed-and-iris margin in front of the maple pavilion: the
			# stone's footprint must miss this short opening on the bank.
			var opening := Geometry2D.get_closest_point_to_segment(p, Vector2(120.35, -129.83), Vector2(122.65, -130.7))
			var exclude := p.distance_to(opening) < 1.15 + size * 0.5
			if size >= 0.45 and not terrain.water_at(p) and ground > water_y - 0.03:
				rings.append([p, size, exclude])
			if exclude:
				out.excluded.append({"x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01), "variant": which, "size": snappedf(size, 0.01)})
				continue
			rows[which].append(t)
			(out.footprints as Array).append([p, size * 0.5])
			out.stones += 1
			if size >= 0.6:
				out.colliders += _collider(root, proto, t, convex, which)
	for i: int in range(protos.size()): Kit.batch_parts(root, "ShoreStones%d" % i, protos[i], rows[i], 48.0, 110.0, true)
	out.moss = _moss(terrain, root, rng, rings, water_y, shore)
	return out

static func _collider(root: Node3D, proto: Dictionary, t: Transform3D, convex: Dictionary, which: int) -> int:
	var body := StaticBody3D.new()
	body.name = "ShoreStoneCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	var parts: Array = proto.parts
	for k: int in range(parts.size()):
		var part: Dictionary = parts[k]
		var key := "%d_%d" % [which, k]
		if not convex.has(key):
			var made := (part.mesh as Mesh).create_convex_shape(true, true)
			convex[key] = made.points if made != null else PackedVector3Array()
		var points: PackedVector3Array = convex[key]
		if points.is_empty(): continue
		var relative: Transform3D = part.relative
		var full: Transform3D = t * relative
		var placed := PackedVector3Array()
		for v: Vector3 in points: placed.append(full * v)
		var shape := ConvexPolygonShape3D.new()
		shape.points = placed
		var node := CollisionShape3D.new()
		node.shape = shape
		body.add_child(node)
	if body.get_child_count() == 0:
		body.free()
		return 0
	root.add_child(body)
	return 1

static func _moss(terrain: Node, root: Node3D, rng: RandomNumberGenerator, rings: Array, water_y: float, shore: PackedFloat32Array) -> int:
	var meshes: Array[Mesh] = []
	var shared: StandardMaterial3D = null
	for i: int in range(6):
		var path := MOSS + "moss_%02d.glb" % i
		if not ResourceLoader.exists(path): continue
		var model: Node = load(path).instantiate()
		var found: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			model.free()
			continue
		var mesh := (found[0] as MeshInstance3D).mesh.duplicate() as Mesh
		for s: int in range(mesh.get_surface_count()):
			if shared == null:
				var src := mesh.surface_get_material(s) as StandardMaterial3D
				if src == null: continue
				shared = src.duplicate() as StandardMaterial3D
				shared.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				shared.alpha_scissor_threshold = 0.35
				shared.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(s, shared)
		meshes.append(mesh)
		model.free()
	if meshes.is_empty(): return 0
	var rows: Array = []
	for i: int in range(meshes.size()): rows.append([])
	var made := 0
	var sampled := 0
	# The fronds are a few centimetres across (island_nature lays them on a
	# 3.5 cm grid), so a cushion needs hundreds. Each stone gets two to four
	# uneven cushions hugging its foot, denser at the stone, never a full ring.
	for ring: Array in rings:
		var c: Vector2 = ring[0]
		var size: float = ring[1]
		for patch: int in range(rng.randi_range(2, 4)):
			var a0 := rng.randf() * TAU
			var arc := rng.randf_range(0.6, 1.5)
			for k: int in range(int(size * size * rng.randf_range(90.0, 160.0))):
				if sampled >= MAX_MOSS: break
				var a := a0 + (rng.randf() + rng.randf() - 1.0) * arc
				var p := c + Vector2(cos(a), sin(a)) * size * (0.42 + 0.38 * pow(rng.randf(), 1.6))
				if terrain.water_at(p): continue
				var ground := _ground(terrain, shore, p)
				if ground < water_y - 0.01: continue
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
				var variant := rng.randi() % meshes.size()
				sampled += 1
				# Consume exactly the same random sequence for the omitted stone
				# cushions so the other stone groups retain their moss and sizes.
				if ring[2]: continue
				rows[variant].append([Transform3D(basis, Vector3(p.x, ground + 0.003, p.y))])
				made += 1
	# Small cells: a cell is culled by the distance to its centre, so a 32 m
	# cell with an 18 m range would hide the moss right at the player's feet.
	for i: int in range(meshes.size()): Kit.cell_batches(root, "ShoreMoss%d" % i, meshes[i], null, rows[i], 10.0, 22.0, false)
	return made

# ------------------------------------------------------------------ lilies

static func _bucket(grid: Dictionary, p: Vector2) -> void:
	var key := Vector2i(floori(p.x / 1.5), floori(p.y / 1.5))
	if not grid.has(key): grid[key] = PackedVector2Array()
	var list: PackedVector2Array = grid[key]
	list.append(p)
	grid[key] = list

static func _bucket_near(grid: Dictionary, p: Vector2, r: float) -> bool:
	var cx := floori(p.x / 1.5)
	var cz := floori(p.y / 1.5)
	for z: int in range(cz - 1, cz + 2):
		for x: int in range(cx - 1, cx + 2):
			var key := Vector2i(x, z)
			if not grid.has(key): continue
			for q: Vector2 in (grid[key] as PackedVector2Array):
				if q.distance_to(p) < r: return true
	return false

## A few more lily rafts off the reed stands and in the hero bays, spaced from
## the existing pockets. Mostly foliage, the odd bud or ivory flower.
static func _lilies(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, spots: Array, water_y: float) -> int:
	if not ResourceLoader.exists(LILY): return 0
	var source: Script = load(LILY)
	# Existing pads in 1.5 m buckets: the pockets hold about 600 rafts x 4
	# part batches, too many to scan per candidate.
	var existing := {}
	var pockets := park.find_child("WaterLilyPockets", true, false)
	if pockets != null:
		for node: Node in pockets.find_children("*", "", true, false):
			if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
				var mmi := node as MultiMeshInstance3D
				for i: int in range(mmi.multimesh.instance_count):
					var o := mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
					_bucket(existing, Vector2(o.x, o.z))
			elif node is Node3D and node.get_parent() == pockets:
				var o3 := (node as Node3D).global_position
				_bucket(existing, Vector2(o3.x, o3.z))
	spots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var placed: Array[Vector2] = []
	var rows: Array = [[], [], [], [], []]
	for spot: Array in spots:
		if placed.size() >= MAX_LILY_RAFTS: break
		var p: Vector2 = spot[0]
		if not terrain.water_at(p) or terrain.height_at(p) > water_y - 0.3: continue
		var free := true
		for q: Vector2 in placed: if q.distance_to(p) < 2.4: free = false
		if not free: continue
		if _bucket_near(existing, p, 1.5): continue
		var roll := rng.randf()
		var variant := 3 if roll < 0.5 else (4 if roll < 0.82 else (2 if roll < 0.93 else 1))
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), Vector3(p.x, water_y, p.y))
		rows[variant].append(t)
		placed.append(p)
	for variant: int in range(5):
		if rows[variant].is_empty(): continue
		var plant: Node3D = source.build(variant)
		var parts: Array = []
		for part: Node in plant.get_children():
			if part is MeshInstance3D and (part as MeshInstance3D).mesh != null:
				parts.append({"mesh": (part as MeshInstance3D).mesh, "relative": (part as MeshInstance3D).transform})
		plant.free()
		Kit.batch_parts(root, "ShoreLilies%d" % variant, {"parts": parts, "box": AABB()}, rows[variant], 64.0, 70.0, false)
	return placed.size()

# ---------------------------------------------------------------- thinning

## The bank gives the spiky beds and lawn over to reeds and iris: most
## fountain grass goes near the water, some stays as odd clumps; lawn blades
## thin over the last few metres to the water so the dark damp peat of the
## look map shows through. Dithered, so the change interleaves instead of
## stopping on a line.
static func _thin(park: Node3D, shore: PackedFloat32Array, island: PackedFloat32Array) -> Dictionary:
	var protect: Array[String] = ["iris", "reed", "rush", "lily", "moss", "biome", "stone", "boulder", "fern", "azalea", "flower", "sakura", "maple", "lantern", "petal", "shore"]
	var spiky_words: Array[String] = ["fountain", "emerald", "woodlandfill", "spiky", "meadow", "forestgrass", "drift", "dense"]
	var lawn_words: Array[String] = ["grass", "blade", "lawn", "tuft"]
	var spiky := func(label: String) -> bool:
		var l := label.to_lower()
		for word: String in protect: if l.contains(word): return false
		for word: String in spiky_words: if l.contains(word): return true
		return false
	var lawn := func(label: String) -> bool:
		var l := label.to_lower()
		for word: String in protect: if l.contains(word): return false
		for word: String in spiky_words: if l.contains(word): return false
		for word: String in lawn_words: if l.contains(word): return true
		return false
	var keep_spiky := func(p: Vector2) -> bool:
		if not GRID.has_point(p): return true
		var ds := _sample(shore, p)
		var di := _sample(island, p)
		if ds > 16.0 and di > 7.0: return true
		var edge := minf(ds, di)
		var share := smoothstep(0.25, 0.9, _shore_w(ds, p)) * 0.55 + (1.0 - smoothstep(1.0, 3.5, edge)) * 0.3
		return not Biomes.pick(p, clampf(share, 0.0, 0.88), 61)
	var keep_lawn := func(p: Vector2) -> bool:
		if not GRID.has_point(p): return true
		var edge := minf(_sample(shore, p), _sample(island, p))
		if edge > 3.8: return true
		return not Biomes.pick(p, (1.0 - smoothstep(1.0, 3.6, edge)) * 0.82, 62)
	var report := {}
	if ResourceLoader.exists(THIN_ALL):
		var thin: Script = load(THIN_ALL)
		report["spiky"] = thin.hide_low_planting(park, spiky, keep_spiky, GRID, true)
		report["lawn"] = thin.hide_low_planting(park, lawn, keep_lawn, GRID, true)
		report["via"] = "thin_all"
	else:
		var roots: Array = [park, park.get_tree().root.get_node_or_null("MidoriGrassDetail")]
		var node_label := func(node: MultiMeshInstance3D) -> String:
			return String(node.name) + " " + (node.multimesh.mesh.resource_name if node.multimesh.mesh else "")
		report["spiky"] = Kit.thin_multimeshes(roots, func(node: MultiMeshInstance3D) -> bool: return spiky.call(node_label.call(node)), keep_spiky)
		report["lawn"] = Kit.thin_multimeshes(roots, func(node: MultiMeshInstance3D) -> bool: return lawn.call(node_label.call(node)), keep_lawn)
		report["via"] = "kit"
	return report
