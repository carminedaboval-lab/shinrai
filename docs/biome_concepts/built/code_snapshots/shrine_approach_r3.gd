extends RefCounted
## Sando 参道, the tended shrine approach round the south-east landmark plaza
## (docs/biome_concepts/after_shrine_approach.png and
## extra/after_shrine_approach_reverse.png). The one place in the lapsed park
## that is still kept. The ground look map already lays the rich, dark, short
## turf (care 0); this builder adds what stands on it:
##  - a swept stone approach of irregular flat slabs (ishidatami) with grass
##    joints, running due south on the plaza's north axis (x ~ 164) from the
##    turf by the big boulder to the plaza rim, as the concept frames it from
##    (164, 95). The axis is nudged sideways a little (never swung round) when
##    a stone, tree or walk is in the way; only if no axis line is clear does
##    it fall back to the clearest bearing round the plaza's north half,
##  - a vermilion myojin torii on that axis at the plaza threshold, facing
##    north down the approach. The neon portal at (164, 136) stays the inner
##    gate, about 30 m further on and seen through the vermilion one,
##  - Kasuga stone lanterns lining the approach in irregular pairs, with a
##    soft static glow in the chamber (no light nodes, no per-frame scripts),
##  - clipped karikomi mounds (satsuki, boxwood, holly) in loose groups of
##    2 to 7: low red and pale-pink azalea drifts in the turf round the outer
##    end of the approach, banks behind the lanterns and groups scattered
##    round the crescent of turf,
##  - a few set garden stones by the torii and some groups, moss at their feet.
## The spiky fountain grass and woodland fill mostly go; lawn blades thin a
## little; wild ferns and floor bushes thin out. Nothing is laid on a grid or
## in a line, and all thinning is a dithered pick by weight, so edges feather.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ClippedShrubs := preload("res://scripts/midori_clipped_shrubs.gd")
const ID := "sando"
const CENTRE := Vector2(168, 128)
const RADII := Vector2(46, 40)
# Region bounds plus the feather, for cheap early-outs.
const RECT := Rect2(113, 79, 110, 98)
# Plaza centre x, z and outer radius, used when the plaza mesh is not found.
const PLAZA_FALLBACK := Vector3(164, 136, 31.0)
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const MOSS := "res://assets/shinrai/parks/midori_park/models/island_nature/moss_%02d.glb"
const LANTERN := "res://assets/shinrai/parks/midori_park/models/stone_lantern/kasuga_lantern.glb"
const LANTERN_DATA := "res://assets/shinrai/parks/midori_park/models/stone_lantern/measurements.json"
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
# Approach: half width of the paving, and the run it may take off the plaza.
const BAND_HALF := 1.4
const MIN_RUN := 8.0
const MAX_RUN := 24.0
const MAX_LANTERNS := 14
const MAX_BANK_GROUPS := 10
const MAX_RING_GROUPS := 14
# The approach axis: the plaza's north radius, as the concept frames it from
# the walk at (164, 95). Lines are tried a few metres either side of it and
# tilted a few degrees at most; the shortest acceptable axis run is shorter
# than a fallback bearing's because the plaza rim is only ~10 m off the walk.
const AXIS_X := 164.0
const AXIS_OFFSETS := [0.0, -0.5, 0.5, -1.0, 1.0, -1.5, 1.5, -2.0, 2.0, -2.5, 2.5, -3.0, 3.0]
const AXIS_TILTS := [0.0, -4.0, 4.0, -8.0, 8.0]
const MIN_AXIS_RUN := 4.0
# Where the walk arrives at the approach (the review eye): lanterns keep this
# standing spot open, so no lamp stands at the walker's elbow.
const ARRIVAL := Vector2(164, 95)
const ARRIVAL_CLEAR := 3.6
# Azalea and karikomi drifts round the outer end of the approach, per side.
const MAX_DRIFTS_PER_SIDE := 3
# Mound group kinds.
const RING := 0
const BANK := 1
const DRIFT := 2
# Moss fronds are 2 to 4 cm pieces; island stones carry about 1,300 each.
const MOSS_CAP := 12000
const SLAB_SHAPES := 7
# Torii proportions (metres): pillar spacing centre to centre.
const TORII_SPAN := 3.44
# Shell visibility, as the clipped shrubs use them: fringe first, core last.
const SHELL_RANGES := [160.0, 70.0, 40.0]

## Satsuki in flower: the clipped-shrub look with single round blooms in a
## coarser jittered world-space cell set, mostly on the upper faces.
const BLOOM_SHADER := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform float shell = 0.0;
uniform float leaf_size = 0.028;
uniform float flower_size = 0.058;
uniform float bloom = 0.5;
uniform vec3 petal_a : source_color = vec3(0.63, 0.16, 0.24);
uniform vec3 petal_b : source_color = vec3(0.74, 0.3, 0.38);
varying vec3 world;
varying vec4 tint;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR;
}

void fragment() {
	vec3 p = world / leaf_size;
	vec3 cell = floor(p);
	float best = 8.0;
	float second = 8.0;
	vec3 id = cell;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 c = cell + vec3(float(x), float(y), float(z));
		vec3 o = c + hash3(c) * 0.9 + 0.05;
		float d = length(p - o);
		if (d < best) { second = best; best = d; id = c; }
		else if (d < second) { second = d; }
	}
	vec3 h = hash3(id + 17.0);
	float edge = smoothstep(0.0, 0.22, second - best);
	vec3 leaf = tint.rgb * mix(0.7, 1.25, h.x);
	leaf = mix(leaf, vec3(0.3, 0.1, 0.045) * mix(0.8, 1.2, h.x), step(1.0 - tint.a, h.y) * 0.8);
	leaf = mix(leaf, leaf * vec3(1.2, 1.25, 0.9), shell * 0.2 * h.z);
	vec3 fp = world / flower_size;
	vec3 fcell = floor(fp);
	float fbest = 8.0;
	vec3 fid = fcell;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 c = fcell + vec3(float(x), float(y), float(z));
		vec3 o = c + hash3(c + 5.0) * 0.8 + 0.1;
		float d = length(fp - o);
		if (d < fbest) { fbest = d; fid = c; }
	}
	vec3 fh = hash3(fid + 41.0);
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float density = bloom * (shell > 0.5 ? 1.0 : 0.6) * smoothstep(-0.35, 0.25, up);
	float petal = step(fh.x, density) * (1.0 - smoothstep(0.26, 0.36, fbest));
	vec3 flower = mix(petal_a, petal_b, fh.y) * mix(0.82, 1.08, fh.z);
	flower = mix(flower * 0.6, flower, smoothstep(0.03, 0.15, fbest));
	if (shell > 0.5) {
		float keep = shell > 1.5 ? 0.38 : 0.62;
		if (petal < 0.5 && (h.z > keep || best > 0.48)) discard;
	}
	float depth = shell > 0.5 ? 1.0 : 0.42;
	vec3 foliage = leaf * mix(0.45, 1.0, edge) * depth;
	ALBEDO = mix(foliage, flower * mix(0.7, 1.0, depth), petal);
	vec3 tilt = (h - 0.5) * 1.3 * (1.0 - petal * 0.6);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = mix(mix(0.42, 0.7, h.y), 0.8, petal);
	SPECULAR = 0.45;
	BACKLIGHT = ALBEDO * 0.35;
}
"""

## Swept granite slabs: speckle and broad tone from world-space value noise
## read at a rotation (no axis-aligned blocks), a little olive lichen on old
## slabs (instance alpha). Instance colour carries each slab's own grey.
const SLAB_SHADER := """
shader_type spatial;
varying vec3 wp;
varying vec4 tint;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR;
}
void fragment() {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wp.xz;
	vec2 r = mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * wp.xz;
	float broad = vn(q * 1.6) * 0.6 + vn(r * 3.3 + 4.1) * 0.4;
	float fine = vn(q * 21.0) * 0.55 + vn(r * 53.0) * 0.45;
	float speck = smoothstep(0.78, 0.9, vn(q * 97.0 + broad * 3.0));
	vec3 c = tint.rgb * mix(0.84, 1.1, broad) * mix(0.9, 1.07, fine);
	c = mix(c, c * 0.5, speck * 0.55);
	float lichen = smoothstep(0.58, 0.82, vn(r * 2.7 + 9.0)) * tint.a;
	c = mix(c, vec3(0.19, 0.2, 0.11), lichen * 0.45);
	ALBEDO = c;
	ROUGHNESS = mix(0.76, 0.93, fine);
	SPECULAR = 0.32;
}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeShrineApproach"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501107
	var inventory_before := Kit.inventory(park, RECT)
	# Footprints of everything this builder stands up: {Vector2i: [Vector3(x, z, r)]}.
	var taken := {}
	var plaza := _plaza(park)
	var approach: Dictionary = await _choose_approach(park, terrain, plaza)
	if not is_instance_valid(park): return {}
	var torii := {}
	var slabs := 0
	var lanterns: Array = []
	if not approach.is_empty():
		torii = _torii(park, terrain, root, approach, plaza, taken)
		slabs = _paving(park, terrain, root, rng, approach, plaza, taken)
		await park.get_tree().process_frame
		if not is_instance_valid(park): return {}
		lanterns = _lanterns(park, terrain, root, rng, approach, plaza, taken)
	var mounds: Dictionary = await _mound_groups(park, terrain, root, rng, plaza, approach, taken)
	if not is_instance_valid(park): return {}
	var anchors: Array = []
	anchors.append_array(mounds.moss_anchors)
	for lamp: Dictionary in lanterns: anchors.append([lamp.p, float(lamp.radius) * 0.95, float(lamp.radius) + 0.5, 260])
	var moss := _moss_cushions(park, terrain, root, rng, anchors)
	var thinned := _thin(park, terrain, plaza, approach, taken)
	var line := {}
	if not approach.is_empty():
		var a: Vector2 = approach.a
		var b: Vector2 = approach.b
		line = {"from": [snappedf(a.x, 0.1), snappedf(a.y, 0.1)], "to": [snappedf(b.x, 0.1), snappedf(b.y, 0.1)], "half_width": BAND_HALF, "joins_walk": approach.joins, "bearing": approach.bearing}
	return {
		"approach": line,
		"torii": torii,
		"slabs": slabs,
		"lanterns": lanterns.map(func(l: Dictionary) -> Array: return [snappedf(l.p.x, 0.1), snappedf(l.p.y, 0.1)]),
		"mound_groups": mounds.groups,
		"mounds": mounds.count,
		"flowering_red": mounds.red,
		"flowering_pale": mounds.pale,
		"garden_stones": mounds.boulders,
		"moss_fronds": moss,
		"thinned": thinned,
		"inventory": inventory_before,
	}

# --- Shared checks -----------------------------------------------------------

static func _w(p: Vector2, terrain: Node) -> float:
	return Biomes.weight(p, ID, terrain)

static func _reserve(taken: Dictionary, p: Vector2, r: float) -> void:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	if not taken.has(key): taken[key] = []
	(taken[key] as Array).append(Vector3(p.x, p.y, r))

## True when a disc of radius r at p touches nothing this builder placed.
static func _free(taken: Dictionary, p: Vector2, r: float) -> bool:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for v: Vector3 in taken.get(key + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(v.x, v.y)) < r + v.z: return false
	return true

static func _trunk_near(park: Node3D, p: Vector2, r: float) -> bool:
	if park.has_method("any_trunk_within"): return park.any_trunk_within(p, r)
	return Kit.trunk_distance(park, p, r + 1.0) < r

## True when nothing but the ground is under the point (no prop, deck or roof).
static func _bare(park: Node3D, terrain: Node, p: Vector2) -> bool:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).y < ground + 0.35

## Lowest ground under a disc, so nothing floats on a slope.
static func _low_ground(terrain: Node, p: Vector2, r: float) -> float:
	var low: float = terrain.height_at(p)
	for k: int in range(6):
		var q := p + Vector2(r, 0).rotated(float(k) * TAU / 6.0 + 0.4)
		low = minf(low, float(terrain.height_at(q)))
	return low

## On or at the edge of a paved walk or a worn trail.
static func _on_walk(park: Node3D, p: Vector2, margin: float) -> bool:
	if park.has_method("path_edge_distance_world") and park.path_edge_distance_world(p) < margin: return true
	var trails := park.get_node_or_null("MidoriDesirePaths")
	if trails != null and trails.has_method("distance_to_path") and trails.distance_to_path(p) < margin + 0.4: return true
	return false

## Clear of the park's own garden stones, lanterns and azaleas.
static func _clear_of_gardens(park: Node3D, p: Vector2, r: float) -> bool:
	var gardens := park.get_node_or_null("MidoriGardenSpots")
	if gardens != null and gardens.get("footprints") != null:
		for footprint: Dictionary in gardens.get("footprints"):
			if p.distance_to(footprint.p) < r + float(footprint.radius) + 0.45: return false
	var lamps := park.get_node_or_null("MidoriStoneLanterns")
	if lamps != null and lamps.get("footprints") != null:
		for footprint: Dictionary in lamps.get("footprints"):
			if p.distance_to(footprint.p) < r + float(footprint.radius) + 0.8: return false
	var flowers := park.get_node_or_null("MidoriJapaneseFlowers")
	if flowers != null and flowers.get("azalea_positions") != null:
		for at: Vector3 in flowers.get("azalea_positions"):
			if p.distance_to(Vector2(at.x, at.z)) < r + 0.7: return false
	return true

## Plaza court centre (x, z) and outer radius, read from its own floor mesh.
static func _plaza(park: Node3D) -> Vector3:
	var court := park.find_child("PlazaGroundingCourt", true, false) as MeshInstance3D
	if court != null and court.mesh != null:
		var box: AABB = court.global_transform * court.get_aabb()
		if box.size.x > 4.0: return Vector3(box.get_center().x, box.get_center().z, maxf(box.size.x, box.size.z) * 0.5)
	return PLAZA_FALLBACK

static func _in_plaza(plaza: Vector3, p: Vector2, margin: float) -> bool:
	return p.distance_to(Vector2(plaza.x, plaza.y)) < plaza.z + margin

## Lateral distance from the approach centreline, or a large number when the
## point is beyond either end.
static func _band_gap(ap: Dictionary, p: Vector2) -> float:
	if ap.is_empty(): return 1.0e9
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	var s := (p - a).dot(dir)
	if s < -0.8 or s > float(ap.length) + 0.8: return 1.0e9
	return absf((p - a).dot(side))

## Distance from the open strip of turf between the arrival point and the
## outer end of the approach, or a large number when the arrival is beside
## the paving already or nowhere near it. Mounds and stones keep off it, so
## nothing stands across the entrance to the paving.
static func _entry_gap(ap: Dictionary, p: Vector2) -> float:
	if ap.is_empty(): return 1.0e9
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	if (ARRIVAL - a).dot(dir) > -0.5 or a.distance_to(ARRIVAL) > 12.0: return 1.0e9
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, ARRIVAL, a))

# --- The approach line -------------------------------------------------------

## The approach runs on the plaza's north axis: lines leave the rim at x near
## AXIS_X heading north (tilted a few degrees at most) and the clearest one
## wins, scored on its run of open turf, whether it meets a walk, and how far
## it strays from the axis. Only when no axis line is clear for MIN_AXIS_RUN
## does the old sweep of bearings round the north half take over.
static func _choose_approach(park: Node3D, terrain: Node, plaza: Vector3) -> Dictionary:
	var c := Vector2(plaza.x, plaza.y)
	var r := plaza.z
	var best: Dictionary = {}
	var best_score := -INF
	var trial := 0
	for off: float in AXIS_OFFSETS:
		var x := AXIS_X + off
		if absf(x - c.x) > r * 0.6: continue
		# Where the line crosses the rim on the north side.
		var rim := Vector2(x, c.y - sqrt(r * r - (x - c.x) * (x - c.x)))
		for tilt: float in AXIS_TILTS:
			var u := Vector2(sin(deg_to_rad(tilt)), -cos(deg_to_rad(tilt)))
			var found := _clear_run(park, terrain, rim, u)
			trial += 1
			if trial % 6 == 5:
				await park.get_tree().process_frame
				if not is_instance_valid(park): return {}
			var run: float = found[0]
			var joins: bool = found[1]
			if run < MIN_AXIS_RUN: continue
			# Beyond about 10 m the run is behind the arrival point and only
			# matters for meeting a walk; straying off the axis costs fast.
			var score := minf(run, 10.0) + (3.0 if joins else 0.0) - 1.2 * off * off - 0.06 * tilt * tilt
			if score <= best_score: continue
			best_score = score
			best = _line(rim + u * run, rim + u * 0.15, u, joins)
	if not best.is_empty(): return best
	return await _sweep_approach(park, terrain, plaza)

## Marches north from a rim point along u and returns [run, joins]: how far the
## band of turf stays clear (metres from the rim) and whether it met a walk.
static func _clear_run(park: Node3D, terrain: Node, rim: Vector2, u: Vector2) -> Array:
	var side := Vector2(-u.y, u.x)
	var run := 0.0
	var joins := false
	var t := 0.6
	while t < MAX_RUN:
		var p := rim + u * t
		if _w(p, terrain) < 0.3: break
		if _on_walk(park, p, 0.45):
			# Run the paving on to the walk itself (slabs that would lie on it
			# are dropped one by one), so the approach meets the walk instead
			# of stopping short on a strip of turf.
			if run > 0.0: run = t
			joins = true
			break
		var ok := true
		for lat: float in [-(BAND_HALF + 0.3), 0.0, BAND_HALF + 0.3]:
			var q := p + side * lat
			if terrain.water_at(q) or _trunk_near(park, q, 0.9) or not _clear_of_gardens(park, q, 0.4) or not _bare(park, terrain, q):
				ok = false
				break
		# Two more rays inside the band, so a small loose stone between the
		# centre and edge samples does not end up sitting in the paving.
		if ok:
			for lat: float in [-0.8, 0.8]:
				if not _bare(park, terrain, p + side * lat):
					ok = false
					break
		if not ok: break
		run = t
		t += 0.8
	return [run, joins]

## The approach record: a is the outer end, b the rim end, u points outward.
static func _line(a: Vector2, b: Vector2, u: Vector2, joins: bool) -> Dictionary:
	var length := a.distance_to(b)
	# The torii defaults to the plaza end; _torii moves it to where it fits.
	return {"a": a, "b": b, "dir": -u, "side": Vector2(u.y, -u.x), "length": length, "joins": joins, "bearing": snappedf(rad_to_deg(atan2(u.y, u.x)), 0.1), "torii_s": length}

## Fallback: tries bearings round the plaza's north half and keeps the longest
## clear run of turf off the rim, preferring one that reaches a walk and points
## north.
static func _sweep_approach(park: Node3D, terrain: Node, plaza: Vector3) -> Dictionary:
	var c := Vector2(plaza.x, plaza.y)
	var r := plaza.z
	var best: Dictionary = {}
	var best_score := -INF
	for k: int in range(35):
		var bearing := -175.0 + 5.0 * float(k)
		var u := Vector2(cos(deg_to_rad(bearing)), sin(deg_to_rad(bearing)))
		var rim := c + u * r
		var found := _clear_run(park, terrain, rim, u)
		if k % 6 == 5: await park.get_tree().process_frame
		if not is_instance_valid(park): return {}
		var run: float = found[0]
		var joins: bool = found[1]
		if run < MIN_RUN: continue
		var score := minf(run, 20.0) + (8.0 if joins else 0.0) - absf(bearing + 90.0) * 0.6
		if score <= best_score: continue
		best_score = score
		best = _line(rim + u * run, rim + u * 0.15, u, joins)
	return best

# --- Vermilion torii ---------------------------------------------------------

## The gate stands on the approach at the plaza threshold, about a metre clear
## of the rim and facing north down the paving; when that spot is blocked it
## steps back toward the outer end until both pillars fit.
static func _torii(park: Node3D, terrain: Node, root: Node3D, ap: Dictionary, plaza: Vector3, taken: Dictionary) -> Dictionary:
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	var length: float = ap.length
	var spot := Vector2.INF
	var along := length - 1.1
	while along >= 0.6:
		var m := a + dir * along
		var ok := true
		for sd: float in [-1.0, 1.0]:
			var q := m + side * sd * TORII_SPAN * 0.5
			if _in_plaza(plaza, q, 0.5) or not Kit.open_ground(park, terrain, q, 0.4) or _trunk_near(park, q, 0.8) or not _clear_of_gardens(park, q, 0.3) or not _bare(park, terrain, q):
				ok = false
				break
			for k: int in range(4):
				if not _bare(park, terrain, q + Vector2(0.45, 0).rotated(float(k) * TAU / 4.0 + 0.3)): ok = false
			# The kasagi overhangs the pillars by about 1.2 m each side, at 4.7 m:
			# keep a trunk from standing through the beam end.
			if ok and _trunk_near(park, m + side * sd * 2.95, 0.7): ok = false
			if not ok: break
		if ok:
			spot = m
			break
		along -= 0.4
	if spot == Vector2.INF: return {"placed": false}
	ap["torii_s"] = along
	var left := spot - side * TORII_SPAN * 0.5
	var right := spot + side * TORII_SPAN * 0.5
	var base_y := minf(float(terrain.height_at(left)), float(terrain.height_at(right)))
	var gate := Node3D.new()
	gate.name = "SandoTorii"
	root.add_child(gate)
	# Local +Z runs along the approach toward the plaza; local X across it.
	gate.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(spot.x, base_y, spot.y))
	var visual := MeshInstance3D.new()
	visual.name = "ToriiMesh"
	visual.mesh = _torii_mesh()
	visual.visibility_range_end = 450.0
	gate.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "ToriiCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	gate.add_child(body)
	for sd: float in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.26
		cylinder.height = 5.0
		shape.shape = cylinder
		shape.position = Vector3(sd * TORII_SPAN * 0.5, 2.2, 0.0)
		body.add_child(shape)
	for q: Vector2 in [left, right]: _reserve(taken, q, 0.6)
	return {"placed": true, "at": [snappedf(spot.x, 0.1), snappedf(spot.y, 0.1)], "height_m": 5.2, "span_m": TORII_SPAN}

## A myojin torii about 5.2 m tall, base at the origin, opening along +Z:
## two slightly inward-leaning vermilion pillars on black sleeves and low
## stone footings, the nuki tie beam through them, a gakuzuka strut with a
## black plaque, and the shimaki and black kasagi above with upturned ends.
static func _torii_mesh() -> ArrayMesh:
	var red := SurfaceTool.new()
	red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var black := SurfaceTool.new()
	black.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pillar_h := 4.85
	var lean := 0.06 # top of each pillar sits this much further in
	var tilt := atan2(lean, pillar_h)
	for sd: float in [-1.0, 1.0]:
		var x := sd * TORII_SPAN * 0.5
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.17
		pillar.bottom_radius = 0.195
		pillar.height = pillar_h
		pillar.radial_segments = 24
		pillar.rings = 1
		var lean_basis := Basis(Vector3(0, 0, 1), sd * tilt)
		red.append_from(pillar, 0, Transform3D(lean_basis, Vector3(x - sd * lean * 0.5, -0.3 + pillar_h * 0.5, 0.0)))
		# Black sleeve (nemaki) over the foot of the pillar.
		var sleeve := CylinderMesh.new()
		sleeve.top_radius = 0.225
		sleeve.bottom_radius = 0.235
		sleeve.height = 0.85
		sleeve.radial_segments = 24
		sleeve.rings = 1
		black.append_from(sleeve, 0, Transform3D(lean_basis, Vector3(x - sd * lean * 0.07, 0.125, 0.0)))
		# A thin black collar where sleeve meets lacquer.
		var collar := CylinderMesh.new()
		collar.top_radius = 0.215
		collar.bottom_radius = 0.24
		collar.height = 0.05
		collar.radial_segments = 24
		collar.rings = 1
		black.append_from(collar, 0, Transform3D(lean_basis, Vector3(x - sd * lean * 0.12, 0.57, 0.0)))
		# Low dressed-stone footing (kamebara) half in the turf.
		var footing := CylinderMesh.new()
		footing.top_radius = 0.33
		footing.bottom_radius = 0.4
		footing.height = 0.3
		footing.radial_segments = 20
		footing.rings = 1
		stone.append_from(footing, 0, Transform3D(Basis.IDENTITY, Vector3(x, -0.07, 0.0)))
	# Nuki: the tie beam passing through both pillars, ends proud.
	var nuki := BoxMesh.new()
	nuki.size = Vector3(4.55, 0.22, 0.15)
	red.append_from(nuki, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.86, 0.0)))
	# Gakuzuka strut and its plaque.
	var strut := BoxMesh.new()
	strut.size = Vector3(0.16, 0.52, 0.13)
	red.append_from(strut, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.21, 0.0)))
	var frame := BoxMesh.new()
	frame.size = Vector3(0.46, 0.5, 0.17)
	red.append_from(frame, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 0.0)))
	var plaque := BoxMesh.new()
	plaque.size = Vector3(0.36, 0.4, 0.19)
	black.append_from(plaque, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 0.0)))
	# Shimaki (lacquered) under the black kasagi; both lift at the ends.
	red.append_from(_bent_beam(4.95, 0.22, 0.26, 0.1), 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.46, 0.0)))
	black.append_from(_bent_beam(5.8, 0.25, 0.36, 0.28), 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.68, 0.0)))
	var red_look := StandardMaterial3D.new()
	red_look.albedo_color = Color(0.6, 0.15, 0.07)
	red_look.roughness = 0.62
	red_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	var black_look := StandardMaterial3D.new()
	black_look.albedo_color = Color(0.05, 0.045, 0.042)
	black_look.roughness = 0.5
	black_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stone_look := StandardMaterial3D.new()
	stone_look.albedo_color = Color(0.42, 0.41, 0.38)
	stone_look.roughness = 0.9
	var mesh := red.commit()
	black.commit(mesh)
	stone.commit(mesh)
	mesh.surface_set_material(0, red_look)
	mesh.surface_set_material(1, black_look)
	mesh.surface_set_material(2, stone_look)
	return mesh

## A beam of the given length, height and depth along X, bottom at y = 0 in
## the middle, rising by `lift` at both ends on a soft curve (sori).
static func _bent_beam(length: float, height: float, depth: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var sections: Array[PackedVector3Array] = []
	var mids: Array[Vector3] = []
	for i: int in range(n + 1):
		var x := -length * 0.5 + length * float(i) / float(n)
		var y := lift * pow(absf(x) / (length * 0.5), 2.4)
		var ring := PackedVector3Array([Vector3(x, y, -depth * 0.5), Vector3(x, y, depth * 0.5), Vector3(x, y + height, depth * 0.5), Vector3(x, y + height, -depth * 0.5)])
		sections.append(ring)
		mids.append(Vector3(x, y + height * 0.5, 0.0))
	for i: int in range(n):
		var s0 := sections[i]
		var s1 := sections[i + 1]
		var mid := (mids[i] + mids[i + 1]) * 0.5
		for k: int in range(4):
			var k1 := (k + 1) % 4
			var a := s0[k]
			var b := s1[k]
			var c := s1[k1]
			var d := s0[k1]
			_quad(st, a, b, c, d, (a + b + c + d) * 0.25 - mid)
	_quad(st, sections[0][0], sections[0][1], sections[0][2], sections[0][3], Vector3.LEFT)
	_quad(st, sections[n][0], sections[n][1], sections[n][2], sections[n][3], Vector3.RIGHT)
	return st.commit()

## One flat quad with its face turned toward `out`, wound clockwise as seen
## from that side (Godot's front face).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12: normal = (c - a).cross(d - a)
	if normal.dot(out) < 0.0:
		var swap := b
		b = d
		d = swap
		normal = -normal
	normal = normal.normalized()
	for v: Vector3 in [a, c, b, a, d, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.dot(out) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	for v: Vector3 in [a, c, b]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)

# --- Swept stone paving ------------------------------------------------------

## One irregular flat slab, about 1 m across (radius <= 1 in X/Z after
## scaling by its radius), top 4 cm above its origin with a soft bevel.
static func _slab_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := rng.randi_range(6, 9)
	var dirs: Array[Vector2] = []
	var radii: Array[float] = []
	var biggest := 0.0
	for i: int in range(n):
		var a := TAU * (float(i) + rng.randf_range(-0.32, 0.32)) / float(n)
		dirs.append(Vector2(cos(a), sin(a)))
		var r := rng.randf_range(0.8, 1.0)
		radii.append(r)
		biggest = maxf(biggest, r)
	var top := Vector3(0.0, 0.045, 0.0)
	var inner: Array[Vector3] = []
	var edge: Array[Vector3] = []
	var foot: Array[Vector3] = []
	for i: int in range(n):
		var d := dirs[i] * (radii[i] / biggest)
		inner.append(Vector3(d.x * 0.88, 0.04, d.y * 0.88))
		edge.append(Vector3(d.x, 0.016, d.y))
		foot.append(Vector3(d.x * 0.96, -0.08, d.y * 0.96))
	for i: int in range(n):
		var j := (i + 1) % n
		var out := Vector3(dirs[i].x + dirs[j].x, 0.0, dirs[i].y + dirs[j].y)
		_tri(st, top, inner[i], inner[j], Vector3.UP)
		_quad(st, inner[i], inner[j], edge[j], edge[i], out + Vector3.UP * 0.6)
		_quad(st, edge[i], edge[j], foot[j], foot[i], out)
	return st.commit()

## Irregular slabs packed into a ragged band with grass joints: dart throwing,
## larger slabs first, then small fill stones in the gaps. No rows or courses.
static func _paving(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, ap: Dictionary, plaza: Vector3, taken: Dictionary) -> int:
	var shapes: Array[ArrayMesh] = []
	var rows: Array = []
	for i: int in range(SLAB_SHAPES):
		shapes.append(_slab_mesh(rng))
		rows.append([])
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	var length: float = ap.length
	var grid := {}
	var count := 0
	var area := length * BAND_HALF * 2.0
	for pass_index: int in range(2):
		var lo := 0.3 if pass_index == 0 else 0.15
		var hi := 0.52 if pass_index == 0 else 0.27
		var tries := int(area * (55.0 if pass_index == 0 else 40.0))
		for k: int in range(tries):
			var along := rng.randf() * length
			# The band's edge wanders a little; it is never a ruled line.
			var sd := -1.0 if rng.randf() < 0.5 else 1.0
			var half := BAND_HALF + Biomes.noise().get_noise_2d(along * 6.0, 11.0 + sd * 30.0) * 0.22
			var lateral := sd * rng.randf() * half
			var radius := rng.randf_range(lo, hi)
			if absf(lateral) + radius * 0.55 > half: continue
			var p := a + dir * along + side * lateral
			if _in_plaza(plaza, p, radius * 0.4): continue
			# A slab may meet the walk's edge but never lie on it, nor on the
			# torii footings.
			if _on_walk(park, p, radius * 0.8) or terrain.water_at(p): continue
			if not _free(taken, p, radius * 0.85): continue
			var key := Vector2i(floori(p.x), floori(p.y))
			var clear := true
			for dz: int in range(-2, 3):
				for dx: int in range(-2, 3):
					for v: Vector3 in grid.get(key + Vector2i(dx, dz), []):
						if p.distance_to(Vector2(v.x, v.y)) < radius + v.z + 0.035:
							clear = false
							break
					if not clear: break
				if not clear: break
			if not clear: continue
			# Never under a stone or prop the march between samples missed.
			if not _bare(park, terrain, p): continue
			if not grid.has(key): grid[key] = []
			(grid[key] as Array).append(Vector3(p.x, p.y, radius))
			var aspect := rng.randf_range(0.8, 1.0)
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.012, 0.012)) * Basis(Vector3.FORWARD, rng.randf_range(-0.012, 0.012))
			# Lie in the local slope of the turf, so no edge stands proud on the
			# downhill side or drowns on the uphill side.
			var reach := maxf(radius * 0.7, 0.2)
			var gx: float = (float(terrain.height_at(p + Vector2(reach, 0.0))) - float(terrain.height_at(p - Vector2(reach, 0.0)))) / (2.0 * reach)
			var gz: float = (float(terrain.height_at(p + Vector2(0.0, reach))) - float(terrain.height_at(p - Vector2(0.0, reach)))) / (2.0 * reach)
			var up := Vector3(-gx, 1.0, -gz).normalized()
			var slope := Basis(Quaternion(Vector3.UP, up))
			var basis := slope * Basis(Vector3.UP, rng.randf() * TAU) * tilt * Basis.from_scale(Vector3(radius, 1.0, radius * aspect))
			var ground: float = terrain.height_at(p)
			var grey := Color(0.5, 0.49, 0.46).lerp(Color(0.55, 0.5, 0.44) if rng.randf() < 0.5 else Color(0.44, 0.46, 0.47), rng.randf() * 0.6)
			grey = grey * rng.randf_range(0.85, 1.1)
			grey.a = pow(rng.randf(), 2.0) * 0.6
			rows[rng.randi() % SLAB_SHAPES].append([Transform3D(basis, Vector3(p.x, ground - 0.012 + rng.randf() * 0.006, p.y)), grey])
			count += 1
	var shader := Shader.new()
	shader.code = SLAB_SHADER
	var look := ShaderMaterial.new()
	look.shader = shader
	for i: int in range(SLAB_SHAPES):
		if rows[i].is_empty(): continue
		Kit.cell_batches(root, "SandoSlabs%d" % i, shapes[i], look, rows[i], 24.0, 120.0, false)
	return count

# --- Kasuga lanterns in irregular pairs --------------------------------------

static func _lanterns(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, ap: Dictionary, plaza: Vector3, taken: Dictionary) -> Array:
	var placed: Array = []
	var proto := Kit.file_parts(LANTERN)
	if proto.parts.is_empty(): return placed
	var data: Dictionary = {}
	if FileAccess.file_exists(LANTERN_DATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LANTERN_DATA))
		if parsed is Dictionary: data = parsed
	var base_r: float = float(data.get("base_radius", 0.28))
	var roof_r: float = float(data.get("clearance_radius", 0.41))
	var fire := Vector3(0.0, 0.89, 0.0)
	if data.has("fire_origin"):
		var o: Array = data.fire_origin
		fire = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var parts: Array = data.get("collision_parts", [])
	if parts.is_empty(): parts = [{"centre": [0.0, 0.7, 0.0], "size": [0.5, 1.4, 0.5]}]
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	var rows: Array = []
	var glow := _glow_material()
	# Pairs run from just outside the torii back toward the outer end. The
	# stretch within about 9 m of the torii (all that shows between the walk
	# and the plaza rim) gets a tighter rhythm, so it still reads as lined
	# rather than as one stray pair; further out the pairs open up.
	var torii_s: float = float(ap.torii_s)
	var s: float = torii_s - rng.randf_range(1.4, 1.9)
	while s > 0.3 and placed.size() < MAX_LANTERNS:
		# One size per pair; pairs differ a little, as gifts of different years do.
		var size := rng.randf_range(1.12, 1.3)
		for sd: float in [-1.0, 1.0]:
			if placed.size() >= MAX_LANTERNS: break
			if rng.randf() < 0.07: continue
			var spot := Vector2.INF
			var base_y := 0.0
			for attempt: int in range(6):
				var along := s + rng.randf_range(-0.6, 0.6)
				# The paving's ragged edge reaches about BAND_HALF + 0.45 m; the
				# lantern foot stays on the turf beyond it.
				var lateral := BAND_HALF + 0.45 + base_r * size + rng.randf_range(0.08, 0.4) + float(attempt) * 0.18
				var p := a + dir * along + side * sd * lateral
				if p.distance_to(ARRIVAL) < ARRIVAL_CLEAR: continue
				var seat := _lantern_seat(park, terrain, p, base_r * size, roof_r * size, plaza, taken)
				if is_nan(seat): continue
				spot = p
				base_y = seat
				break
			if spot == Vector2.INF: continue
			# The open front (+Z) faces the approach.
			var foot := a + dir * (spot - a).dot(dir)
			var toward := foot - spot
			var yaw := atan2(toward.x, toward.y) + rng.randf_range(-0.05, 0.05)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
			var origin := Vector3(spot.x, base_y, spot.y)
			rows.append(Transform3D(basis, origin))
			var body := StaticBody3D.new()
			body.name = "SandoLanternCollision_%02d" % placed.size()
			body.collision_layer = 1
			body.collision_mask = 1
			root.add_child(body)
			body.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
			for part: Dictionary in parts:
				var collider := CollisionShape3D.new()
				var box := BoxShape3D.new()
				var part_size: Array = part.size
				var centre: Array = part.centre
				box.size = Vector3(float(part_size[0]), float(part_size[1]), float(part_size[2])) * size
				collider.shape = box
				collider.position = Vector3(float(centre[0]), float(centre[1]), float(centre[2])) * size
				body.add_child(collider)
			# A soft warm glow in the chamber: a static card, no light, no script.
			var card := MeshInstance3D.new()
			card.name = "SandoLanternGlow_%02d" % placed.size()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.15, 0.17) * size
			card.mesh = quad
			card.material_override = glow
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			card.visibility_range_end = 70.0
			root.add_child(card)
			card.global_position = origin + Basis(Vector3.UP, yaw) * (fire * size) + Vector3.UP * 0.07 * size
			_reserve(taken, spot, roof_r * size + 0.35)
			placed.append({"p": spot, "radius": base_r * size})
		s -= rng.randf_range(2.4, 3.3) if torii_s - s < 9.0 else rng.randf_range(4.3, 5.9)
	Kit.batch_parts(root, "SandoLanterns", proto, rows, 32.0, 170.0, true)
	return placed

static func _glow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.86, 0.6, 0.95))
	gradient.set_color(1, Color(1.0, 0.5, 0.16, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.55)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_texture = texture
	look.albedo_color = Color(1.0, 0.72, 0.4, 0.8)
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	return look

## Base height for a lantern at p, or NAN when the spot is not clear or flat.
static func _lantern_seat(park: Node3D, terrain: Node, p: Vector2, base_r: float, roof_r: float, plaza: Vector3, taken: Dictionary) -> float:
	if _w(p, terrain) < 0.35: return NAN
	if _in_plaza(plaza, p, roof_r + 0.25): return NAN
	if not Kit.open_ground(park, terrain, p, roof_r + 0.15): return NAN
	if _trunk_near(park, p, base_r + 1.0): return NAN
	if not _clear_of_gardens(park, p, roof_r): return NAN
	if not _free(taken, p, roof_r + 0.2): return NAN
	var low: float = terrain.height_at(p)
	var high := low
	for k: int in range(8):
		var q := p + Vector2(base_r, 0).rotated(float(k) * TAU / 8.0)
		if terrain.water_at(q): return NAN
		var h: float = terrain.height_at(q)
		low = minf(low, h)
		high = maxf(high, h)
	if high - low > 0.06: return NAN
	if not _bare(park, terrain, p): return NAN
	for k: int in range(4):
		if not _bare(park, terrain, p + Vector2(roof_r, 0).rotated(float(k) * TAU / 4.0 + 0.6)): return NAN
	return low - 0.01

# --- Clipped mounds, azaleas and garden stones -------------------------------

static func _stone_parts() -> Array:
	var protos: Array = []
	for i: int in range(6):
		var proto := Kit.file_parts(FLOOR + "stone_%02d.glb" % i)
		if not proto.parts.is_empty(): protos.append(proto)
	return protos

static func _mound_groups(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, plaza: Vector3, ap: Dictionary, taken: Dictionary) -> Dictionary:
	var out := {"groups": 0, "count": 0, "red": 0, "pale": 0, "boulders": 0, "moss_anchors": []}
	# Group centres: [centre, kind] with kind RING, BANK or DRIFT.
	var centres: Array = []
	if not ap.is_empty():
		var a: Vector2 = ap.a
		var dir: Vector2 = ap.dir
		var side: Vector2 = ap.side
		var length: float = ap.length
		var torii_s: float = ap.torii_s
		# Drifts first: low azalea and karikomi groups in the turf either side
		# of the outer end of the approach, between the walk and the torii (the
		# foreground of the concept). Scattered, never in step across the
		# paving; the park's own boulders, lanterns and azaleas are kept clear.
		# When the paving runs on past the arrival point, the drifts stay ahead
		# of it, where the walker (and the review camera) looks.
		var drift_lo := -2.0
		var drift_hi := maxf(torii_s - 0.2, 0.5)
		var s_arrival := (ARRIVAL - a).dot(dir)
		if absf((ARRIVAL - a).dot(side)) < 4.0 and s_arrival + 1.2 < drift_hi - 1.0:
			drift_lo = maxf(drift_lo, s_arrival + 1.2)
		for sd: float in [-1.0, 1.0]:
			var here := 0
			for attempt: int in range(36):
				if here >= MAX_DRIFTS_PER_SIDE: break
				var p := a + dir * rng.randf_range(drift_lo, drift_hi) + side * sd * (BAND_HALF + rng.randf_range(1.9, 6.4))
				var spaced := true
				for row: Array in centres:
					if (row[0] as Vector2).distance_to(p) < 2.9: spaced = false
				if not spaced: continue
				if _w(p, terrain) < 0.4 or _in_plaza(plaza, p, 1.2): continue
				if not Kit.open_ground(park, terrain, p, 1.0) or _trunk_near(park, p, 1.4): continue
				if not _clear_of_gardens(park, p, 0.8) or not _free(taken, p, 0.9) or not _bare(park, terrain, p): continue
				centres.append([p, DRIFT])
				here += 1
		await park.get_tree().process_frame
		if not is_instance_valid(park) or not is_instance_valid(root): return out
		# Banks behind the lanterns, each side on its own irregular rhythm.
		var banks := 0
		for sd: float in [-1.0, 1.0]:
			var s := rng.randf_range(0.5, 3.0)
			while s < length + 1.5:
				if banks >= MAX_BANK_GROUPS: break
				# Set back by a different amount each time, so the banks never
				# read as a hedge line parallel to the paving.
				var p := a + dir * s + side * sd * (BAND_HALF + rng.randf_range(2.3, 5.0))
				s += rng.randf_range(4.0, 7.5)
				var spaced := true
				for row: Array in centres:
					if (row[0] as Vector2).distance_to(p) < 2.6: spaced = false
				if not spaced: continue
				if _w(p, terrain) < 0.45 or _in_plaza(plaza, p, 1.6): continue
				if not Kit.open_ground(park, terrain, p, 1.4) or _trunk_near(park, p, 1.6): continue
				if not _clear_of_gardens(park, p, 1.0) or not _free(taken, p, 1.0) or not _bare(park, terrain, p): continue
				centres.append([p, BANK])
				banks += 1
	# Loose groups round the crescent of turf.
	var ring := 0
	for attempt: int in range(900):
		if ring >= MAX_RING_GROUPS: break
		# Spread the trials over frames whether or not they succeed; each one
		# samples the biome weight (a shoreline search) and casts a ray.
		if attempt % 100 == 99:
			await park.get_tree().process_frame
			if not is_instance_valid(park) or not is_instance_valid(root): return out
		var ang := rng.randf() * TAU
		var p := CENTRE + Vector2(cos(ang) * RADII.x, sin(ang) * RADII.y) * sqrt(rng.randf()) * 0.97
		if _w(p, terrain) < 0.5 or _in_plaza(plaza, p, 2.0): continue
		if _band_gap(ap, p) < BAND_HALF + 2.4 or _entry_gap(ap, p) < BAND_HALF + 2.4: continue
		var spaced := true
		for row: Array in centres:
			if (row[0] as Vector2).distance_to(p) < 7.5: spaced = false
		if not spaced: continue
		if not Kit.open_ground(park, terrain, p, 1.8) or _trunk_near(park, p, 1.8): continue
		if not _clear_of_gardens(park, p, 1.2) or not _free(taken, p, 1.2) or not _bare(park, terrain, p): continue
		centres.append([p, RING])
		ring += 1
	var green_rows: Array = []
	var red_rows: Array = []
	var pale_rows: Array = []
	var boulder_rows: Array = []
	var boulders := _stone_parts()
	for gi: int in range(centres.size()):
		if gi % 3 == 2:
			await park.get_tree().process_frame
			if not is_instance_valid(park) or not is_instance_valid(root): return out
		var c: Vector2 = centres[gi][0]
		var kind: int = centres[gi][1]
		var drift := kind == DRIFT
		var roll := rng.randf()
		var size := 3
		if kind == BANK: size = 2 if roll < 0.3 else (3 if roll < 0.65 else 5)
		elif drift: size = 3 if roll < 0.4 else (4 if roll < 0.75 else 5)
		else: size = 3 if roll < 0.45 else (5 if roll < 0.85 else 7)
		var flower_roll := rng.randf()
		# 0 green, 1 red satsuki, 2 pale-pink satsuki. Drifts are mostly in
		# flower, red a little more often than pale.
		var bloom_kind := 0
		if drift: bloom_kind = 1 if flower_roll < 0.45 else (2 if flower_roll < 0.78 else 0)
		else: bloom_kind = 1 if flower_roll < 0.3 else (2 if flower_roll < 0.5 else 0)
		var species: int = [0, 0, 2, 2, 3, 1][rng.randi() % 6]
		var members: Array = [] # [Vector2, width]
		for m: int in range(size):
			var w := 0.0
			if drift: w = rng.randf_range(1.1, 1.6) if m == 0 else rng.randf_range(0.7, 1.25)
			else: w = rng.randf_range(1.2, 1.9) if m == 0 else rng.randf_range(0.65, 1.3)
			for attempt: int in range(28):
				var q := c
				if m > 0:
					var host: Array = members[rng.randi() % members.size()]
					var ang := rng.randf() * TAU
					q = (host[0] as Vector2) + Vector2(cos(ang), sin(ang)) * (float(host[1]) * 0.5 + w * 0.5) * rng.randf_range(0.7, 1.0)
				elif attempt > 0:
					q = c + Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4))
				if not _free(taken, q, w * 0.4): continue
				if _in_plaza(plaza, q, w * 0.5 + 0.5): continue
				if _band_gap(ap, q) < BAND_HALF + 0.9 + w * 0.5: continue
				if _entry_gap(ap, q) < BAND_HALF + 0.6 + w * 0.5: continue
				if _w(q, terrain) < 0.35 or not Kit.open_ground(park, terrain, q, w * 0.5 + 0.3): continue
				if _trunk_near(park, q, w * 0.5 + 0.45): continue
				if not _clear_of_gardens(park, q, w * 0.5): continue
				if q.distance_to(ARRIVAL) < w * 0.5 + 1.4: continue
				if not _bare(park, terrain, q): continue
				# The rim too, so no mound climbs the flank of a boulder or prop.
				var flank_clear := true
				for k: int in range(3):
					if not _bare(park, terrain, q + Vector2(w * 0.45, 0.0).rotated(float(k) * TAU / 3.0 + 0.5)):
						flank_clear = false
						break
				if not flank_clear: continue
				members.append([q, w])
				_reserve(taken, q, w * 0.4)
				break
		if members.is_empty(): continue
		out.groups += 1
		for member: Array in members:
			var q: Vector2 = member[0]
			var w: float = member[1]
			# Tended mounds: fuller and rounder than the moss garden's; the
			# azalea drifts lower and spreading.
			var h := w * (rng.randf_range(0.45, 0.6) if drift and bloom_kind > 0 else rng.randf_range(0.55, 0.72))
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w * rng.randf_range(0.82, 1.0)))
			var t := Transform3D(basis, Vector3(q.x, _low_ground(terrain, q, w * 0.4) - 0.05, q.y))
			# Now and then a green mound stands among the flowering ones.
			if bloom_kind > 0 and rng.randf() < 0.85:
				var leaf := Color(0.085, 0.15, 0.055) * rng.randf_range(0.9, 1.1)
				leaf.a = 0.03
				# In a drift the other colour slips in now and then, so red and
				# pale stand side by side as in the concept.
				var colour := bloom_kind
				if drift and rng.randf() < 0.22: colour = 3 - bloom_kind
				if colour == 1:
					red_rows.append([t, leaf])
					out.red += 1
				else:
					pale_rows.append([t, leaf])
					out.pale += 1
			else:
				var look: Array = ClippedShrubs.SPECIES[species if bloom_kind == 0 else 2]
				var leaf: Color = (look[0] as Color) * rng.randf_range(0.88, 1.1)
				# Kept shrubs: hardly any autumn bronze.
				leaf.a = float(look[1]) * 0.4
				green_rows.append([t, leaf])
			out.count += 1
		# A set stone at the edge of some ring groups (not crowding the banks).
		if boulders.is_empty() or kind != RING or rng.randf() > 0.4: continue
		var host_row: Array = members[rng.randi() % members.size()]
		var ang := rng.randf() * TAU
		var height := rng.randf_range(0.45, 0.85)
		var spot: Vector2 = (host_row[0] as Vector2) + Vector2(cos(ang), sin(ang)) * (float(host_row[1]) * 0.5 + height * 1.0)
		var reach := _place_stone(park, terrain, root, rng, boulders, boulder_rows, taken, plaza, ap, spot, height)
		if reach > 0.0:
			out.boulders += 1
			out.moss_anchors.append([spot, reach * 0.75, reach + 0.45, 320])
	# One or two larger set stones beside the torii, on the approach side of it.
	if not ap.is_empty() and not boulders.is_empty():
		var a: Vector2 = ap.a
		var dir: Vector2 = ap.dir
		var side: Vector2 = ap.side
		var torii_s: float = ap.torii_s
		var big := 0
		for k: int in range(10):
			if big >= 2: break
			var sd := -1.0 if k % 2 == 0 else 1.0
			var spot := a + dir * (torii_s - rng.randf_range(0.3, 2.6)) + side * sd * (BAND_HALF + rng.randf_range(2.6, 3.8))
			var height := rng.randf_range(0.6, 0.95)
			var reach := _place_stone(park, terrain, root, rng, boulders, boulder_rows, taken, plaza, ap, spot, height)
			if reach > 0.0:
				big += 1
				out.moss_anchors.append([spot, reach * 0.75, reach + 0.55, 420])
		out.boulders += big
	_batch_mounds(root, green_rows, red_rows, pale_rows)
	var by_piece: Array = []
	for k: int in range(boulders.size()): by_piece.append([])
	for row: Array in boulder_rows: by_piece[row[0]].append(row[1])
	for k: int in range(boulders.size()):
		Kit.batch_parts(root, "SandoStones%d" % k, boulders[k], by_piece[k], 24.0, 130.0, true)
	return out

## Sets one stone of the given height at spot. Returns its footprint radius
## (half its longest plan extent once scaled), or 0 when the spot is not clear.
## The forest-floor stones are 1.3 to 2.6 times wider than tall, so every
## clearance is taken from that real footprint, not from the height.
static func _place_stone(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, boulders: Array, rows: Array, taken: Dictionary, plaza: Vector3, ap: Dictionary, spot: Vector2, height: float) -> float:
	var k := rng.randi() % boulders.size()
	var box: AABB = (boulders[k] as Dictionary).box
	var scale := height / maxf(box.size.y, 0.001)
	var reach := maxf(box.size.x, box.size.z) * 0.5 * scale
	var mean := (box.size.x + box.size.z) * 0.25 * scale
	if not _free(taken, spot, reach * 0.7) or _in_plaza(plaza, spot, reach + 0.4): return 0.0
	if _band_gap(ap, spot) < BAND_HALF + 0.6 + reach or _entry_gap(ap, spot) < BAND_HALF + 0.4 + reach: return 0.0
	if _w(spot, terrain) < 0.35 or not Kit.open_ground(park, terrain, spot, reach + 0.3): return 0.0
	if _trunk_near(park, spot, reach + 0.4) or not _clear_of_gardens(park, spot, reach) or not _bare(park, terrain, spot): return 0.0
	var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
	rows.append([k, Kit.seat(boulders[k], terrain, spot, height, rng.randf() * TAU, height * 0.35, tilt)])
	_reserve(taken, spot, reach * 0.85)
	var body := StaticBody3D.new()
	body.name = "SandoStone"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = mean * 0.85
	cylinder.height = height * 0.75
	shape.shape = cylinder
	body.add_child(shape)
	root.add_child(body)
	body.global_position = Vector3(spot.x, float(terrain.height_at(spot)) + height * 0.375 - 0.1, spot.y)
	return reach

static func _batch_mounds(root: Node3D, green_rows: Array, red_rows: Array, pale_rows: Array) -> void:
	var bloom_shader := Shader.new()
	bloom_shader.code = BLOOM_SHADER
	for s: int in range(ClippedShrubs.SHELLS.size()):
		var mesh := ClippedShrubs._mound(float(ClippedShrubs.SHELLS[s]))
		var range_end: float = SHELL_RANGES[s]
		if not green_rows.is_empty():
			var look := ShaderMaterial.new()
			look.shader = ClippedShrubs.SHADER
			look.set_shader_parameter("shell", float(s))
			Kit.cell_batches(root, "SandoMounds%d" % s, mesh, look, green_rows, 24.0, range_end, s == 0)
		if not red_rows.is_empty():
			var red := ShaderMaterial.new()
			red.shader = bloom_shader
			red.set_shader_parameter("shell", float(s))
			red.set_shader_parameter("bloom", 0.55)
			red.set_shader_parameter("petal_a", Color(0.62, 0.07, 0.09))
			red.set_shader_parameter("petal_b", Color(0.74, 0.14, 0.15))
			Kit.cell_batches(root, "SandoRedAzaleas%d" % s, mesh, red, red_rows, 24.0, range_end, s == 0)
		if not pale_rows.is_empty():
			var pale := ShaderMaterial.new()
			pale.shader = bloom_shader
			pale.set_shader_parameter("shell", float(s))
			pale.set_shader_parameter("bloom", 0.58)
			pale.set_shader_parameter("petal_a", Color(0.84, 0.66, 0.69))
			pale.set_shader_parameter("petal_b", Color(0.92, 0.8, 0.81))
			Kit.cell_batches(root, "SandoPaleAzaleas%d" % s, mesh, pale, pale_rows, 24.0, range_end, s == 0)

# --- Moss at the feet of lanterns and stones ---------------------------------

## Moss fronds (the island moss pieces) in soft rings round each anchor:
## [centre, inner radius, outer radius, count].
static func _moss_cushions(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, anchors: Array) -> int:
	var meshes: Array[Mesh] = []
	var look: StandardMaterial3D = null
	for i: int in [0, 3, 6, 9]:
		var path := MOSS % i
		if not ResourceLoader.exists(path): continue
		var scene: Node3D = load(path).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			scene.free()
			continue
		var mesh := ((found[0] as MeshInstance3D).mesh).duplicate() as Mesh
		for s: int in range(mesh.get_surface_count()):
			if look == null:
				var source := mesh.surface_get_material(s)
				if source is StandardMaterial3D:
					look = source.duplicate() as StandardMaterial3D
					look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					look.alpha_scissor_threshold = 0.35
					look.cull_mode = BaseMaterial3D.CULL_DISABLED
			if look != null: mesh.surface_set_material(s, look)
		meshes.append(mesh)
		scene.free()
	if meshes.is_empty(): return 0
	var rows: Array = []
	for i: int in range(meshes.size()): rows.append([])
	var total := 0
	for anchor: Array in anchors:
		var c: Vector2 = anchor[0]
		var inner: float = anchor[1]
		var outer: float = anchor[2]
		var count: int = anchor[3]
		for k: int in range(count):
			if total >= MOSS_CAP: break
			var ang := rng.randf() * TAU
			var r := lerpf(inner, outer, pow(rng.randf(), 1.6)) * rng.randf_range(0.9, 1.15)
			var p := c + Vector2(cos(ang), sin(ang)) * r
			if terrain.water_at(p) or _on_walk(park, p, 0.1): continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
			basis = basis.scaled(Vector3.ONE * rng.randf_range(1.4, 2.4))
			rows[rng.randi() % meshes.size()].append([Transform3D(basis, Vector3(p.x, float(terrain.height_at(p)) + 0.002, p.y))])
			total += 1
	for i: int in range(meshes.size()):
		if rows[i].is_empty(): continue
		Kit.cell_batches(root, "SandoMoss%d" % i, meshes[i], null, rows[i], 16.0, 32.0, false)
	return total

# --- Thinning ----------------------------------------------------------------

## Spiky beds almost all go; lawn blades thin a little (the turf itself is in
## the ground look); wild ferns and floor bushes thin out, but never inside
## the plaza or beside its gardens and azaleas. Nothing pokes up through the
## paving, a mound, a lantern or a stone this builder set down.
static func _thin(park: Node3D, terrain: Node, plaza: Vector3, ap: Dictionary, taken: Dictionary) -> Dictionary:
	var report := {}
	# keep() runs once per planting instance in the rect (tens of thousands of
	# lawn blades). The biome weight (a shoreline search here, by the lake) and
	# the garden check are cached on a half-metre grid; the dithered pick still
	# decides each instance, so edges stay feathered.
	var weights := {}
	var gardens := {}
	var wt := func(p: Vector2) -> float:
		var key := Vector2i(floori(p.x * 2.0), floori(p.y * 2.0))
		if not weights.has(key): weights[key] = _w((Vector2(key) + Vector2(0.5, 0.5)) * 0.5, terrain)
		return float(weights[key])
	var near_garden := func(p: Vector2) -> bool:
		var key := Vector2i(floori(p.x * 2.0), floori(p.y * 2.0))
		if not gardens.has(key): gardens[key] = not _clear_of_gardens(park, (Vector2(key) + Vector2(0.5, 0.5)) * 0.5, 2.5)
		return bool(gardens[key])
	# The paving's ragged edge reaches BAND_HALF + 0.45 m.
	var under := func(p: Vector2) -> bool:
		return _band_gap(ap, p) < BAND_HALF + 0.5 or not _free(taken, p, 0.06)
	var is_spiky := func(label: String) -> bool:
		var l := label.to_lower()
		return l.contains("fountain") or l.contains("emerald") or l.contains("woodlandfill") or l.contains("spiky") or l.contains("forestgrass")
	var is_lawn := func(label: String) -> bool:
		var l := label.to_lower()
		if is_spiky.call(l): return false
		return l.contains("grass") or l.contains("blade") or l.contains("tuft") or l.contains("lawn") or l.contains("clump")
	var is_wild := func(label: String) -> bool:
		var l := label.to_lower()
		if l.contains("azalea") or l.contains("iris") or l.contains("lilac"): return false
		return l.contains("fern") or l.contains("forest_floor_bush") or l.contains("forestfloorbush") or l.contains("dense_grass") or l.contains("densegrass") or l.contains("transition")
	var keep_spiky := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		if under.call(p): return false
		return not Biomes.pick(p, smoothstep(0.2, 0.7, float(wt.call(p))) * 0.94, 61)
	var keep_lawn := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		if under.call(p): return false
		return not Biomes.pick(p, smoothstep(0.3, 0.8, float(wt.call(p))) * 0.35, 63)
	var keep_wild := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		if _in_plaza(plaza, p, 0.5): return true
		if near_garden.call(p): return true
		if under.call(p): return false
		return not Biomes.pick(p, smoothstep(0.35, 0.85, float(wt.call(p))) * 0.75, 67)
	if ResourceLoader.exists(THIN_ALL):
		# Also reaches the distance-detail copies, which a node-name filter misses.
		var helper := load(THIN_ALL) as Script
		report["spiky"] = helper.hide_low_planting(park, is_spiky, keep_spiky, RECT)
		report["lawn"] = helper.hide_low_planting(park, is_lawn, keep_lawn, RECT)
		report["wild"] = helper.hide_low_planting(park, is_wild, keep_wild, RECT)
		report["via"] = "thin_all"
		return report
	var grass := park.get_tree().root.get_node_or_null("MidoriGrassDetail")
	var label_of := func(node: MultiMeshInstance3D) -> String:
		return String(node.name) + " " + (node.multimesh.mesh.resource_name if node.multimesh.mesh else "")
	var spiky_nodes := func(node: MultiMeshInstance3D) -> bool: return is_spiky.call(label_of.call(node))
	var lawn_nodes := func(node: MultiMeshInstance3D) -> bool: return is_lawn.call(label_of.call(node))
	var wild_nodes := func(node: MultiMeshInstance3D) -> bool: return is_wild.call(label_of.call(node))
	var roots: Array = [park, grass]
	report["spiky"] = Kit.thin_multimeshes(roots, spiky_nodes, keep_spiky)
	report["lawn"] = Kit.thin_multimeshes(roots, lawn_nodes, keep_lawn)
	report["wild"] = Kit.thin_multimeshes(roots, wild_nodes, keep_wild)
	report["via"] = "kit"
	return report
