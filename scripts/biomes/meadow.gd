extends RefCounted
## Harappa 原っぱ, the overgrown meadow round the west playground
## (docs/biome_concepts/after_meadow.png, extra/after_meadow_north.png,
## extra/after_meadow_west.png). The mown lawn has been left for years: knee-high
## unmown grass with straw tips in irregular drifts, tall feathery susuki in
## loose stands, a few lone broadleaf trees and shaggy untrimmed shrub masses
## instead of round bushes. Walk shoulders (0.2-1.65 m from the paving) keep
## short grass so the walks still read. The even beds of spiky fountain grass
## mostly give way to the new grass.
##
## The grass is three layers: a dense low sward that closes the ground within
## about 40 m, wide soft clumps of thin arching blades (near and far meshes to
## 70 m) and susuki drifts with fanned plumes (to 110 m).
##
## Everything new is procedural geometry batched by cell (_cells /
## Kit.batch_parts) with visibility ranges; wind sway is in the vertex shader,
## so nothing runs per frame. Grass casts no shadows.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
const ID := "harappa"
const CENTRE := Vector2(-152, 104)
const RADII := Vector2(66, 74)
# Ellipse plus its full feather and noise wobble (weight reaches zero about
# 14 m outside the ellipse), clamped to the park. A tighter box cut the faded
# grass along a straight line at z 22 and x -78.
const RECT := Rect2(-220, 10, 162, 170)
const PLAYGROUND := "MidoriKidsPlayground"
# Playground floor half-size (33.2 x 25.2 m) plus a hand's width of margin.
const FLOOR_HALF := Vector2(17.0, 13.0)
# Grass roots stand at least this far outside FLOOR_HALF.
const FLOOR_MIN := 0.3
# Walk shoulders: nothing tall nearer than this to the paving edge.
const SHOULDER_IN := 0.2
const SHOULDER_OUT := 1.65
# Caps thin the whole meadow evenly (random subsample), never cut the scan.
const MAX_CLUMPS := 32000
const MAX_TUFTS := 76000
const MAX_SUSUKI := 3200
const MAX_SHRUBS := 420
const TREES := 9
# Each layer is cut into square cells with its own visibility range. Godot
# measures the range to a cell's centre, so short ranges get small cells (a
# 30 m cell would drop the sward 20 m from the eye). The near and far meshes
# of a layer share one cell grid and cross-dither over FADE_MARGIN.
const SWARD_CELL := 14.0
const SWARD_RANGE := 40.0
const CLUMP_CELL := 18.0
const CLUMP_NEAR := 34.0
const CLUMP_RANGE := 70.0
const PANICLE_TEXTURE := "res://assets/shinrai/parks/midori_park/materials/susuki/susuki_panicle.png"
const SUSUKI_CELL := 24.0
const SUSUKI_NEAR := 44.0
const SUSUKI_RANGE := 110.0
const FADE_MARGIN := 5.0
# Susuki drifts where the concept frames show the big stands (views meadow,
# meadow_north, meadow_west in docs/biome_concepts). Centre, radius in metres;
# each edge is wobbled by noise so none reads as a circle. The noise stands
# elsewhere stay as they were.
const SUSUKI_DRIFTS := [
	[Vector2(-147.6, 58.8), 2.2],
	[Vector2(-171.0, 85.0), 3.6],
	[Vector2(-163.0, 74.0), 2.4],
	[Vector2(-123.4, 148.8), 2.2],
	[Vector2(-128.7, 143.4), 2.0],
	[Vector2(-119.6, 135.4), 2.4],
	[Vector2(-198.4, 76.8), 2.2],
	[Vector2(-195.6, 92.1), 3.0],
	[Vector2(-158.7, 65.8), 4.0],
	[Vector2(-182.0, 70.5), 3.0],
]

## One shader for the meadow grass and the susuki. UV.y runs base to tip along
## each blade, UV2.x is a per-blade tone, UV2.y marks the part (0 leaf, .5 stem,
## 1 plume). Instance colour: rgb tint, alpha how far the tips have gone to straw.
## Leaves run dark olive at the root, muted olive through the body and only the
## last third turns toward straw, so the sward reads green with warm tips.
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_col = vec3(0.07, 0.084, 0.034);
uniform vec3 mid_col = vec3(0.148, 0.176, 0.07);
uniform vec3 top_col = vec3(0.21, 0.232, 0.096);
uniform vec3 straw_col = vec3(0.45, 0.39, 0.232);
uniform vec3 stem_col = vec3(0.38, 0.33, 0.2);
// Linear albedo: about sRGB (203, 191, 175) before the per-blade tone and
// tint, which together can lift it ~35%. The earlier 0.72 clipped to white in
// sun, reading as white spikes rather than straw-silver plumes.
uniform vec3 plume_col = vec3(0.6, 0.53, 0.44);
uniform float sway = 0.05;
uniform float base_shade = 0.55;
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y, 0.0, 1.2);
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + wp.x * 0.045 + wp.z * 0.03);
	float ph = TIME * 1.35 + wp.x * 0.37 + wp.z * 0.29;
	// One world wind (lean toward +x, cross sway in z), turned into each
	// instance's own frame so randomly yawed clumps all bend the same way.
	vec3 push = vec3(sin(ph) * 0.7 + 0.45, 0.0, sin(ph * 0.83 + 1.7) * 0.6);
	mat3 m = mat3(MODEL_MATRIX);
	vec3 scale2 = max(vec3(dot(m[0], m[0]), dot(m[1], m[1]), dot(m[2], m[2])), vec3(0.0001));
	vec3 local_push = (transpose(m) * push) / scale2;
	VERTEX.xz += local_push.xz * sway * gust * h * h;
}
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	float t = UV.y;
	float part = UV2.y;
	float tone = 0.86 + 0.28 * UV2.x;
	vec3 leaf = mix(base_col, mid_col, smoothstep(0.0, 0.3, t));
	leaf = mix(leaf, top_col, smoothstep(0.3, 0.8, t));
	leaf = mix(leaf, straw_col, smoothstep(0.58, 1.0, t) * COLOR.a);
	vec3 c = leaf;
	c = mix(c, stem_col, step(0.25, part) * (1.0 - step(0.75, part)));
	// Plume fingers pale toward their tips (silver-pink straw).
	c = mix(c, plume_col * mix(0.84, 1.06, t), step(0.75, part));
	c *= tone * COLOR.rgb;
	// The base of a clump sits in its own shade.
	c *= mix(base_shade, 1.0, smoothstep(0.0, 0.4, t + step(0.25, part)));
	ALBEDO = c;
	ROUGHNESS = 0.86;
	SPECULAR = 0.22;
	BACKLIGHT = c * mix(0.32, 0.65, step(0.75, part));
}
"""

## Susuki seed heads use an alpha-cut panicle. Leaves, culms and panicles share
## the cell batch and wind phase. Only head fragments sample the texture.
const SUSUKI_SHADER := """
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
uniform vec3 base_col = vec3(0.07, 0.084, 0.034);
uniform vec3 mid_col = vec3(0.148, 0.176, 0.07);
uniform vec3 top_col = vec3(0.21, 0.232, 0.096);
uniform vec3 straw_col = vec3(0.45, 0.39, 0.232);
uniform vec3 stem_col = vec3(0.34, 0.29, 0.18);
uniform sampler2D panicle : source_color, filter_linear_mipmap, repeat_disable;
uniform float sway = 0.085;
uniform float base_shade = 0.6;
varying float seed_head;
void vertex() {
	seed_head = step(0.75, UV2.y);
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(VERTEX.y, 0.0, 1.2);
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + wp.x * 0.045 + wp.z * 0.03);
	float ph = TIME * 1.35 + wp.x * 0.37 + wp.z * 0.29;
	vec3 push = vec3(sin(ph) * 0.7 + 0.45, 0.0, sin(ph * 0.83 + 1.7) * 0.6);
	mat3 m = mat3(MODEL_MATRIX);
	vec3 scale2 = max(vec3(dot(m[0], m[0]), dot(m[1], m[1]), dot(m[2], m[2])), vec3(0.0001));
	vec3 local_push = (transpose(m) * push) / scale2;
	VERTEX.xz += local_push.xz * sway * gust * h * h;
}
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	float t = UV.y;
	float part = UV2.y;
	float plume = step(0.75, part);
	float tone = 0.88 + 0.24 * UV2.x;
	vec3 leaf = mix(base_col, mid_col, smoothstep(0.0, 0.3, t));
	leaf = mix(leaf, top_col, smoothstep(0.3, 0.8, t));
	leaf = mix(leaf, straw_col, smoothstep(0.58, 1.0, t) * COLOR.a);
	vec3 c = leaf;
	c = mix(c, stem_col, step(0.25, part) * (1.0 - plume));
	c *= tone * COLOR.rgb;
	c *= mix(base_shade, 1.0, smoothstep(0.0, 0.4, t + step(0.25, part)));
	if (plume > 0.5) {
		vec4 fibers = texture(panicle, vec2(UV.x, 1.0 - UV.y));
		float distant = smoothstep(6.0, 36.0, -VERTEX.z);
		if (fibers.a < mix(0.19, 0.10, distant)) discard;
		float detail = smoothstep(0.05, 0.74, dot(fibers.rgb, vec3(0.2126, 0.7152, 0.0722)));
		c = mix(vec3(0.29, 0.26, 0.19), vec3(0.68, 0.63, 0.50), detail);
		c *= mix(0.74, 1.0, smoothstep(0.14, 0.78, fibers.a)) * mix(0.94, 1.03, UV2.x);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float diffuse = max(0.0, (ndl + 0.35) / 1.35);
	float transmitted = max(0.0, -ndl) * 0.42;
	vec3 illumination = LIGHT_COLOR;
	if (LIGHT_IS_DIRECTIONAL) {
		// Ground bounce follows the directional light's energy, including night.
		float energy = dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722));
		illumination = mix(LIGHT_COLOR, vec3(energy), 0.70 * seed_head);
		vec3 bounce = mix(vec3(0.86, 0.95, 1.0), vec3(1.0, 0.99, 0.92), seed_head);
		DIFFUSE_LIGHT += mix(0.06, 0.235, seed_head) * energy * bounce / PI;
	}
	DIFFUSE_LIGHT += illumination * ATTENUATION * (diffuse + transmitted) / PI;
}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeMeadow"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501108
	var inventory_before := Kit.inventory(park, RECT)
	var floor_frame := _playground_frame(park)
	var trees := await _trees(park, terrain, root, rng, floor_frame)
	if not is_instance_valid(root): return {"aborted": true}
	var shrubs := await _shrubs(park, terrain, root, rng, floor_frame, trees)
	if not is_instance_valid(root): return {"aborted": true}
	var grass := await _grass(park, terrain, root, rng, floor_frame, trees)
	if not is_instance_valid(root) or grass.has("aborted"): return {"aborted": true}
	var thinned := _thin(park, terrain)
	var hedges := _shaggy_playground_hedges(park, rng)
	return {
		"trees": trees.size(),
		"shrubs": shrubs,
		"grass_clumps": grass.clumps,
		"grass_tufts": grass.tufts,
		"susuki": grass.susuki,
		"cells_checked": grass.cells,
		"grass_batches": grass.batches,
		"playground_hedges": hedges,
		"thinned": thinned,
		"inventory": inventory_before,
	}

# --- Area helpers -------------------------------------------------------------

static func _w(p: Vector2, terrain: Node) -> float:
	return Biomes.weight(p, ID, terrain)

static func _n(p: Vector2, scale: float, offset: Vector2) -> float:
	return Biomes.noise().get_noise_2dv(p * scale + offset)

## World xz -> playground local (identity frame when the playground is missing).
static func _playground_frame(park: Node3D) -> Dictionary:
	var area := park.find_child(PLAYGROUND, true, false) as Node3D
	if area == null: return {"ok": false}
	var frame := Transform2D(-area.global_rotation.y, Vector2(area.global_position.x, area.global_position.z))
	return {"ok": true, "inverse": frame.affine_inverse()}

## How far outside the playground floor a point is (negative inside), metres.
static func _floor_gap(frame: Dictionary, p: Vector2) -> float:
	if not frame.ok: return 99.0
	var inverse: Transform2D = frame.inverse
	var local: Vector2 = inverse * p
	var q := Vector2(absf(local.x) - FLOOR_HALF.x, absf(local.y) - FLOOR_HALF.y)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)

## Distance to the edge of paving or of a worn trail (trails are about 1.2 m).
static func _walk_edge(park: Node3D, p: Vector2) -> float:
	var edge: float = park.path_edge_distance_world(p) if park.has_method("path_edge_distance_world") else 99.0
	var trails := park.get_node_or_null("MidoriDesirePaths")
	if trails != null and trails.has_method("distance_to_path"):
		var d: float = trails.distance_to_path(p)
		edge = minf(edge, d - 0.6)
	return edge

## True when nothing but the ground is under the point (no prop, deck, bench).
static func _bare(park: Node3D, terrain: Node, p: Vector2) -> bool:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	return hit.is_empty() or float(hit.position.y) < ground + 0.35

static func _near_any(points: Array, p: Vector2, gap: float) -> bool:
	for q: Vector2 in points:
		if q.distance_to(p) < gap: return true
	return false

## Every trunk in and round the meadow (the park's own trees and the new ones),
## hashed in 2 m cells so the per-instance check stays cheap.
static func _trunk_grid(park: Node3D) -> Dictionary:
	var grid := {}
	var area := RECT.grow(4.0)
	for local: Vector2 in park.occupied_tree_positions:
		var p := local * 2.0
		if not area.has_point(p): continue
		var key := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
		if not grid.has(key): grid[key] = []
		(grid[key] as Array).append(p)
	return grid

## True within `gap` (at most 2 m) of a trunk in the grid.
static func _near_trunk(grid: Dictionary, p: Vector2, gap: float) -> bool:
	var key := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var list: Array = grid.get(key + Vector2i(dx, dz), [])
			for q: Vector2 in list:
				if q.distance_to(p) < gap: return true
	return false

## Thins a list evenly to `cap` with the builder's own RNG, so a cap never
## leaves the last rows of the scan bare along a straight line.
static func _keep_at_most(rows: Array, cap: int, rng: RandomNumberGenerator) -> void:
	if rows.size() <= cap: return
	for i: int in range(cap):
		var j := rng.randi_range(i, rows.size() - 1)
		var held: Variant = rows[i]
		rows[i] = rows[j]
		rows[j] = held
	rows.resize(cap)

# --- Lone broadleaf trees -----------------------------------------------------

static func _trees(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, floor_frame: Dictionary) -> Array:
	var placed: Array = []
	var raw: Variant = park.get("broadleaf_prototypes")
	if not (raw is Array) or (raw as Array).is_empty(): return placed
	var protos: Array = []
	for source: Variant in raw:
		if source is Node3D:
			var parts := Kit.prototype_parts(park, source)
			if not (parts.parts as Array).is_empty(): protos.append(parts)
	if protos.is_empty(): return placed
	var spots: Array = []
	for attempt: int in range(700):
		if placed.size() >= TREES: break
		# Yield before the checks: most attempts `continue` early, and each
		# open_ground walks every trunk in the park.
		if attempt % 40 == 39:
			await park.get_tree().process_frame
			if not is_instance_valid(root): return []
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.88
		var p := CENTRE + Vector2(cos(a) * RADII.x, sin(a) * RADII.y) * r
		if _w(p, terrain) < 0.6: continue
		if _floor_gap(floor_frame, p) < 5.0: continue
		# Lone trees, one loose pair at most: never an avenue or a grid.
		if _near_any(spots, p, 17.0 + rng.randf() * 8.0): continue
		if not Kit.open_ground(park, terrain, p, 3.2, 11.0): continue
		if _walk_edge(park, p) < 3.2: continue
		if not _bare(park, terrain, p): continue
		spots.append(p)
		placed.append({"p": p, "h": rng.randf_range(7.5, 11.5), "yaw": rng.randf() * TAU, "kind": rng.randi() % protos.size()})
	var rows: Array = []
	for i: int in range(protos.size()): rows.append([])
	for i: int in range(placed.size()):
		var m: Dictionary = placed[i]
		var proto: Dictionary = protos[int(m.kind)]
		var box: AABB = proto.box
		var s: float = float(m.h) / maxf(box.size.y, 0.001)
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.035, 0.035)) * Basis(Vector3.FORWARD, rng.randf_range(-0.035, 0.035))
		var basis := (Basis(Vector3.UP, float(m.yaw)) * lean).scaled(Vector3(s * rng.randf_range(0.9, 1.12), s, s * rng.randf_range(0.9, 1.12)))
		var at: Vector2 = m.p
		var ground: float = terrain.height_at(at)
		var origin := Vector3(at.x, ground - 0.05, at.y) - basis * Vector3(0.0, box.position.y, 0.0)
		(rows[int(m.kind)] as Array).append(Transform3D(basis, origin))
		# Trunk collision, as the park's other trees have.
		var body := StaticBody3D.new()
		body.name = "MeadowTrunk_%02d" % i
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.24
		cylinder.height = 2.6
		shape.shape = cylinder
		body.add_child(shape)
		root.add_child(body)
		body.global_position = Vector3(at.x, ground + 1.3, at.y)
		park.occupied_tree_positions.append(at / 2.0)
		park.occupied_tree_is_skinny.append(false)
	for k: int in range(protos.size()):
		var list: Array = rows[k]
		if list.is_empty(): continue
		Kit.batch_parts(root, "MeadowBroadleaf%d" % k, protos[k], list, 64.0, 300.0, true)
	return placed

# --- Shaggy shrub masses ------------------------------------------------------

## Untrimmed shrubs: two to four bushes grown into one another, uneven in
## height and width, scattered in loose noise patches and at the feet of the
## lone trees. Never round singles on a spacing.
static func _shrubs(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, floor_frame: Dictionary, trees: Array) -> int:
	var raw: Variant = park.get("forest_floor_bush_prototypes")
	if not (raw is Array) or (raw as Array).is_empty(): return 0
	var list: Array = raw
	var bush_a := Kit.prototype_parts(park, list[0])
	# The park has a single floor bush today; only a distinct second one gets its
	# own batches (a copy of A would just double its meshes and draw calls).
	var bush_b: Dictionary = Kit.prototype_parts(park, list[1]) if list.size() > 1 and list[1] != list[0] else {"parts": [], "box": AABB()}
	if (bush_a.parts as Array).is_empty(): return 0
	var rows_a: Array = []
	var rows_b: Array = []
	var centres: Array = []
	for m: Dictionary in trees:
		if rng.randf() < 0.65:
			var a := rng.randf() * TAU
			var tp: Vector2 = m.p
			centres.append(tp + Vector2(cos(a), sin(a)) * rng.randf_range(2.0, 4.0))
	var row := 0
	for z: int in range(int(RECT.position.y), int(RECT.end.y), 3):
		for x: int in range(int(RECT.position.x), int(RECT.end.x), 3):
			var p := Vector2(x + rng.randf() * 3.0, z + rng.randf() * 3.0)
			var w := _w(p, terrain)
			if w < 0.2: continue
			var patch := _n(p, 1.4, Vector2(-31, 77))
			var chance := w * (0.05 * smoothstep(0.25, 0.6, patch) + 0.004)
			if rng.randf() < chance: centres.append(p)
		row += 1
		if row % 4 == 0:
			await park.get_tree().process_frame
			if not is_instance_valid(root): return 0
	var made := 0
	for c: Vector2 in centres:
		var members := rng.randi_range(2, 4)
		for k: int in range(members):
			if made >= MAX_SHRUBS: break
			var p: Vector2 = c + Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4))
			if _floor_gap(floor_frame, p) < 1.5: continue
			if _walk_edge(park, p) < 2.2: continue
			if not Kit.open_ground(park, terrain, p, 0.0, 1.4): continue
			if not _bare(park, terrain, p): continue
			var h := rng.randf_range(1.0, 2.1) * (0.75 + 0.35 * _w(p, terrain))
			# Uneven spread and a slight lean: grown out, not clipped.
			var extra := (Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))).scaled(Vector3(rng.randf_range(0.8, 1.35), 1.0, rng.randf_range(0.8, 1.35)))
			var use_b := k % 2 == 1 and not (bush_b.parts as Array).is_empty()
			var proto: Dictionary = bush_b if use_b else bush_a
			var t := Kit.seat(proto, terrain, p, h, rng.randf() * TAU, 0.06, extra)
			if use_b: rows_b.append(t)
			else: rows_a.append(t)
			made += 1
	Kit.batch_parts(root, "MeadowShrubsA", bush_a, rows_a, 40.0, 120.0, true)
	if not rows_b.is_empty(): Kit.batch_parts(root, "MeadowShrubsB", bush_b, rows_b, 40.0, 120.0, true)
	return made

# --- Long grass and susuki ----------------------------------------------------

static func _grass(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, floor_frame: Dictionary, _placed_trees: Array) -> Dictionary:
	var clumps: Array = []
	var tufts: Array = []
	var susuki: Array = []
	var cells := 0
	# Meshes first: their real heights turn the metre heights below into
	# instance scales.
	var clump_near := _clump_mesh(28, 3, 20501108, 1.0)
	var clump_far := _clump_mesh(16, 2, 20501108, 1.45)
	var sward_mesh := _sward_mesh(16, 20501109)
	var susuki_near := _susuki_mesh(20501110, 14, 4, 5)
	var susuki_far := _susuki_mesh(20501110, 8, 2, 3)
	var clump_unit := maxf(clump_near.get_aabb().end.y, 0.1)
	var sward_unit := maxf(sward_mesh.get_aabb().end.y, 0.05)
	var susuki_unit := maxf(susuki_near.get_aabb().end.y, 0.1)
	# The park's own trunks as well as the new lone trees (already appended to
	# occupied_tree_positions by _trees).
	var trunks := _trunk_grid(park)
	for z: int in range(int(RECT.position.y), int(RECT.end.y)):
		for x: int in range(int(RECT.position.x), int(RECT.end.x)):
			var cell := Vector2(x + 0.5, z + 0.5)
			var w := _w(cell, terrain)
			if w < 0.03: continue
			# Plants jitter up to 0.71 m from the cell centre, so cells near the
			# paving or the floor are kept here and checked per plant in _scatter.
			var edge := _walk_edge(park, cell)
			if edge < SHOULDER_IN - 0.72: continue
			if terrain.water_at(cell): continue
			var gap := _floor_gap(floor_frame, cell)
			if gap < -0.72: continue
			if not _bare(park, terrain, cell): continue
			cells += 1
			# Feathered edge: fewer and lower plants as the meadow weight falls.
			# The low sward runs a little further out than the long grass so the
			# edge thins from tall to short to bare, never with a line.
			var fade := smoothstep(0.05, 0.65, w)
			var cover := smoothstep(0.03, 0.42, w)
			var drift := _n(cell, 1.8, Vector2(13, -5))
			var fine := _n(cell, 5.2, Vector2(-71, 22))
			# Straw tips come and go in drifts; most of the sward stays olive.
			var straw := clampf(0.3 + 0.5 * _n(cell, 2.6, Vector2(48, 91)) + 0.12 * fine, 0.05, 0.88)
			# Shoulders stay short; the long grass steps up beyond them over a
			# ramp whose width wanders, so the verge never runs parallel to the walk.
			var verge := SHOULDER_OUT + 1.5 + 1.4 * (0.5 + 0.5 * _n(cell, 3.4, Vector2(27, -64)))
			var shoulder := smoothstep(SHOULDER_OUT, verge, edge)
			var near_floor := smoothstep(0.0, 3.0, gap)
			var tall := shoulder * near_floor
			# Irregular drifts: tall swathes, knee-high body, a few lower windows.
			# Metres to the longest blade tops; most blades stop at about two
			# thirds of that, so the body of the sward stands 0.35 to 0.75 m.
			var height := lerpf(0.52, 1.05, smoothstep(-0.45, 0.5, drift)) * lerpf(0.88, 1.1, 0.5 + 0.5 * fine)
			height *= lerpf(0.55, 1.0, fade)
			var clump_density := fade * tall * (1.05 + 1.0 * smoothstep(-0.35, 0.45, drift))
			_scatter(clumps, rng, park, terrain, floor_frame, cell, edge, gap, SHOULDER_OUT, clump_density, height, clump_unit, straw, trunks, 0.45, 0.3, 0.1, 0.55)
			# The sward: a dense low layer of leaning tufts that closes the
			# ground between the clumps. On the shoulders it is the only grass,
			# kept low; the height blends (no step) from shoulder to field.
			var low_tuft := rng.randf_range(0.11, 0.18)
			var field_tuft := lerpf(0.28, 0.48, smoothstep(-0.4, 0.5, drift))
			var tuft_height := lerpf(low_tuft, field_tuft, smoothstep(0.0, 0.6, tall)) * lerpf(0.7, 1.0, cover)
			var tuft_density := cover * (2.3 + 1.5 * tall)
			# Sideways scale follows height: a fixed 1.1-1.6 squashed the low
			# shoulder tufts into flat 1.4 m stars whose blades lay over the
			# paving. Low tufts now reach about 0.6 m, field tufts about 0.8 m;
			# centres stand a bit further out so the leaves stay off the paving.
			_scatter(tufts, rng, park, terrain, floor_frame, cell, edge, gap, SHOULDER_IN + 0.3, tuft_density, tuft_height, sward_unit, straw * 0.45, trunks, 0.7, 1.2, 0.12, 0.35)
			# Susuki stands: loose drifts in their own noise, the framed drifts,
			# plus rare singles.
			if edge > 2.2 and gap > 2.0:
				var anchor := _drift_anchor(cell)
				var stand := maxf(smoothstep(0.18, 0.55, _n(cell, 1.25, Vector2(-112, 40))), anchor)
				if edge > 2.6 or anchor > 0.3:
					var s_density := maxf(fade, anchor * 0.85) * (0.6 * stand + 0.01)
					if rng.randf() < s_density:
						var p := cell + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
						if not _near_trunk(trunks, p, 1.2):
							var h := rng.randf_range(1.3, 1.95) * lerpf(0.75, 1.0, maxf(fade, anchor))
							# Width follows height so plumes keep their arch
							# instead of being stretched into upright spikes.
							var spread := h * rng.randf_range(0.72, 0.92)
							susuki.append(_row(rng, terrain, p, h / susuki_unit, clampf(straw + 0.3, 0.3, 1.0), 0.07, spread))
		if z % 3 == 0:
			await park.get_tree().process_frame
			if not is_instance_valid(root): return {"aborted": true}
	_keep_at_most(clumps, MAX_CLUMPS, rng)
	_keep_at_most(tufts, MAX_TUFTS, rng)
	_keep_at_most(susuki, MAX_SUSUKI, rng)
	var shader := Shader.new()
	shader.code = GRASS_SHADER
	var grass_look := _material(shader, 0.045, 0.55)
	var sward_look := _material(shader, 0.03, 0.72)
	var susuki_shader := Shader.new()
	susuki_shader.code = SUSUKI_SHADER
	var susuki_look := _material(susuki_shader, 0.085, 0.6)
	susuki_look.set_shader_parameter("panicle", load(PANICLE_TEXTURE))
	# Near and far versions of each layer over the same cells: the far ones
	# keep the silhouette with a third of the triangles.
	var batches := 0
	batches += await _cells(root, "MeadowSward", sward_mesh, sward_look, tufts, SWARD_CELL, 0.0, SWARD_RANGE)
	if not is_instance_valid(root): return {"aborted": true}
	batches += await _cells(root, "MeadowLongGrass", clump_near, grass_look, clumps, CLUMP_CELL, 0.0, CLUMP_NEAR)
	if not is_instance_valid(root): return {"aborted": true}
	batches += await _cells(root, "MeadowLongGrassFar", clump_far, grass_look, clumps, CLUMP_CELL, CLUMP_NEAR - FADE_MARGIN, CLUMP_RANGE)
	if not is_instance_valid(root): return {"aborted": true}
	batches += await _cells(root, "MeadowSusuki", susuki_near, susuki_look, susuki, SUSUKI_CELL, 0.0, SUSUKI_NEAR)
	if not is_instance_valid(root): return {"aborted": true}
	batches += await _cells(root, "MeadowSusukiFar", susuki_far, susuki_look, susuki, SUSUKI_CELL, SUSUKI_NEAR - FADE_MARGIN, SUSUKI_RANGE)
	if not is_instance_valid(root): return {"aborted": true}
	return {"clumps": clumps.size(), "tufts": tufts.size(), "susuki": susuki.size(), "cells": cells, "batches": batches}

## 0..1: how deep a point lies inside one of the framed susuki drifts. The rim
## wobbles with fine noise, so each drift has a ragged, feathered outline.
static func _drift_anchor(p: Vector2) -> float:
	var best := 0.0
	for drift: Array in SUSUKI_DRIFTS:
		var c: Vector2 = drift[0]
		var r: float = drift[1]
		var d := p.distance_to(c)
		if d > r * 1.4: continue
		var wobble := 0.8 + 0.4 * (0.5 + 0.5 * _n(p, 6.0, c))
		best = maxf(best, 1.0 - smoothstep(0.45, 1.0, d / (r * wobble)))
	return best

## Places a fractional count of plants in one 1 m cell. Near a walk or the
## playground floor each plant is checked at its own spot: nothing nearer the
## paving than `min_edge`, nothing on the floor. `height` is metres to the
## blade tops; `unit` is the mesh's own height. Sideways scale is
## `spread + height * spread_h`.
static func _scatter(rows: Array, rng: RandomNumberGenerator, park: Node3D, terrain: Node, floor_frame: Dictionary, cell: Vector2, cell_edge: float, cell_gap: float, min_edge: float, density: float, height: float, unit: float, straw: float, trunks: Dictionary, spread: float, spread_h: float, tilt: float, trunk_gap: float) -> void:
	if density <= 0.0: return
	var count := int(density) + (1 if rng.randf() < density - floorf(density) else 0)
	for k: int in range(count):
		var p := cell + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
		if cell_edge < min_edge + 0.72 and _walk_edge(park, p) < min_edge: continue
		# Roots keep FLOOR_MIN off the playground floor so low leaves do not
		# lie across its rim.
		if cell_gap < FLOOR_MIN + 0.72 and _floor_gap(floor_frame, p) < FLOOR_MIN: continue
		if _near_trunk(trunks, p, trunk_gap): continue
		var h := height * rng.randf_range(0.78, 1.18)
		rows.append(_row(rng, terrain, p, h / unit, straw, tilt, (spread + h * spread_h) * rng.randf_range(0.9, 1.25)))

## One instance row: transform (random yaw, slight tilt) and colour. `h` is
## the vertical scale, `width` the sideways one.
static func _row(rng: RandomNumberGenerator, terrain: Node, p: Vector2, h: float, straw: float, tilt: float, width: float) -> Array:
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-tilt, tilt)) * Basis(Vector3.FORWARD, rng.randf_range(-tilt, tilt))
	basis = basis.scaled(Vector3(width * rng.randf_range(0.85, 1.15), h, width * rng.randf_range(0.85, 1.15)))
	var ground: float = terrain.height_at(p)
	# Muted olive with small warm and cool shifts; never lime.
	var tint := Color(1.0, 1.0, 1.0).lerp(Color(1.08, 0.97, 0.86), rng.randf()) * rng.randf_range(0.86, 1.1)
	tint.a = clampf(straw + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	return [Transform3D(basis, Vector3(p.x, ground - 0.03, p.y)), tint]

static func _material(shader: Shader, sway: float, base_shade: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sway", sway)
	material.set_shader_parameter("base_shade", base_shade)
	return material

## Instance batches in square cells with a begin and an end range (Kit's
## cell_batches has no begin, which the far meshes need). No shadows and no GI:
## grass is too small to cast either, and thousands of blades would only add
## shadow passes. Yields between cells to spread the build over frames.
static func _cells(parent: Node3D, name: String, mesh: Mesh, material: Material, rows: Array, cell: float, begin: float, end: float) -> int:
	if rows.is_empty(): return 0
	var groups := {}
	for row: Array in rows:
		var t: Transform3D = row[0]
		var key := Vector2i(floori(t.origin.x / cell), floori(t.origin.z / cell))
		if not groups.has(key): groups[key] = []
		(groups[key] as Array).append(row)
	var made := 0
	for key: Vector2i in groups:
		var list: Array = groups[key]
		var centre := Vector3((key.x + 0.5) * cell, 0.0, (key.y + 0.5) * cell)
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.use_colors = true
		many.mesh = mesh
		many.instance_count = list.size()
		for i: int in range(list.size()):
			var row: Array = list[i]
			var t: Transform3D = row[0]
			t.origin -= centre
			many.set_instance_transform(i, t)
			many.set_instance_color(i, row[1])
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d_%d" % [name, key.x, key.y]
		node.multimesh = many
		node.position = centre
		node.material_override = material
		node.visibility_range_begin = begin
		node.visibility_range_begin_margin = FADE_MARGIN if begin > 0.0 else 0.0
		node.visibility_range_end = end
		node.visibility_range_end_margin = FADE_MARGIN
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(node)
		made += 1
		if made % 8 == 0:
			await parent.get_tree().process_frame
			if not is_instance_valid(parent): return made
	return made

# --- Procedural meshes --------------------------------------------------------

## One tapering blade bent along an arc. Base at `base`, leaning toward `dir`
## from `lean0` to `lean1` radians off vertical. Returns the tip.
static func _blade(st: SurfaceTool, base: Vector3, dir: Vector2, length: float, lean0: float, lean1: float, width: float, segs: int, tone: float, part: float) -> Vector3:
	var out := Vector3(dir.x, 0.0, dir.y).normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	var spine: Array[Vector3] = [base]
	var tangents: Array[Vector3] = []
	var pos := base
	var step := length / float(segs)
	for i: int in range(segs):
		var t := (float(i) + 0.5) / float(segs)
		var ang := lerpf(lean0, lean1, t * t)
		var tangent := (out * sin(ang) + Vector3.UP * cos(ang)).normalized()
		tangents.append(tangent)
		pos += tangent * step
		spine.append(pos)
	tangents.append(tangents[tangents.size() - 1])
	var lefts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for i: int in range(segs + 1):
		var t := float(i) / float(segs)
		var w := width * pow(1.0 - t, 0.8)
		lefts.append(spine[i] - side * w * 0.5)
		rights.append(spine[i] + side * w * 0.5)
		# Face normal leaned toward the sky so the backs of blades never go black.
		var face := tangents[i].cross(side).normalized()
		if face.y < 0.0: face = -face
		normals.append((face * 0.45 + Vector3.UP * 0.55).normalized())
	for i: int in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var last := i == segs - 1
		var a := [lefts[i], rights[i], lefts[i + 1], rights[i + 1]]
		var uv := [Vector2(0, t0), Vector2(1, t0), Vector2(0, t1), Vector2(1, t1)]
		var nm := [normals[i], normals[i], normals[i + 1], normals[i + 1]]
		var tris: Array = [[0, 2, 1], [1, 2, 3]]
		if last:
			# The tip closes to a point on the spine.
			a[2] = spine[i + 1]
			uv[2] = Vector2(0.5, 1.0)
			tris = [[0, 2, 1]]
		for tri: Array in tris:
			for idx: int in tri:
				st.set_normal(nm[idx])
				st.set_uv(uv[idx])
				st.set_uv2(Vector2(tone, part))
				st.add_vertex(a[idx])
	return spine[segs]

## A clump of arching grass blades, about 0.8 high and 0.9 across before
## instance scale: thin blades fanning out from a loose crown, outer ones
## leaning further, a quarter of them short to fill the crown. The far version
## uses the same seed with fewer, wider blades, so it is the near clump's
## first blades and the swap keeps the silhouette.
static func _clump_mesh(blades: int, segs: int, seed_value: int, width_scale: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: int in range(blades):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.16
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		# Outer blades lean further; a few stand nearly upright.
		var out_a := a + rng.randf_range(-0.55, 0.55)
		var dir := Vector2(cos(out_a), sin(out_a))
		var lean0 := rng.randf_range(0.04, 0.26) + r * 1.8
		var lean1 := lean0 + rng.randf_range(0.3, 1.15)
		var length := rng.randf_range(0.6, 1.1)
		if b % 4 == 3: length *= 0.6
		var width := rng.randf_range(0.019, 0.03) * width_scale
		_blade(st, base, dir, length, lean0, lean1, width, segs, rng.randf(), 0.0)
	# Share the vertices of each blade's quads (about 40% fewer to shade, and
	# these meshes are drawn tens of thousands of times).
	st.index()
	var mesh := st.commit()
	mesh.resource_name = "harappa_long_grass"
	return mesh

## The sward under the long grass: a low tuft whose blades lean well out and
## lie over one another, about 0.35 high and 0.7 across before scale. Drawn
## densely near the eye, it is what closes the ground between the clumps.
static func _sward_mesh(blades: int, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: int in range(blades):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.12
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var out_a := a + rng.randf_range(-0.7, 0.7)
		var dir := Vector2(cos(out_a), sin(out_a))
		var lean0 := rng.randf_range(0.18, 0.5) + r * 1.5
		var lean1 := lean0 + rng.randf_range(0.3, 0.85)
		# Slightly broader than the clump blades: the sward is what hides the
		# soil, and width costs no triangles.
		_blade(st, base, dir, rng.randf_range(0.3, 0.56), lean0, lean1, rng.randf_range(0.03, 0.046), 2, rng.randf(), 0.0)
	st.index()
	var mesh := st.commit()
	mesh.resource_name = "harappa_sward"
	return mesh

## Susuki (Miscanthus): a fountain of long arching leaves, and arching stems
## carrying feathery plumes that fan out and nod the same way. Unit height to
## the plume tops; leaves reach about two thirds of that. Leaves and stems
## draw from separate generators and always consume the same numbers, so the
## far version (fewer leaves and stems) is a subset of the near one.
static func _susuki_mesh(seed_value: int, leaves: int, leaf_segs: int, stems: int) -> ArrayMesh:
	var leaf_rng := RandomNumberGenerator.new()
	leaf_rng.seed = seed_value
	var stem_rng := RandomNumberGenerator.new()
	stem_rng.seed = seed_value + 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b: int in range(leaves):
		var a := leaf_rng.randf() * TAU
		var r := sqrt(leaf_rng.randf()) * 0.08
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var turn := leaf_rng.randf_range(-0.5, 0.5)
		var dir := Vector2(cos(a + turn), sin(a + turn))
		var lean0 := leaf_rng.randf_range(0.1, 0.4)
		var length := leaf_rng.randf_range(0.48, 0.78)
		_blade(st, base, dir, length, lean0, lean0 + leaf_rng.randf_range(0.9, 1.7), leaf_rng.randf_range(0.02, 0.03), leaf_segs, leaf_rng.randf(), 0.0)
	var nod := stem_rng.randf() * TAU
	var nod_dir := Vector2(cos(nod), sin(nod))
	for s: int in range(stems):
		var a := stem_rng.randf() * TAU
		var r := sqrt(stem_rng.randf()) * 0.07
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var lean_dir := Vector2(cos(a), sin(a)).lerp(nod_dir, 0.6).normalized()
		var lean := stem_rng.randf_range(0.06, 0.3)
		var tall := stem_rng.randf_range(0.74, 0.92)
		var tone := stem_rng.randf()
		var top := _blade(st, base, lean_dir, tall, lean, lean + 0.22, 0.008, 3, tone, 0.5)
		var angle := lean + stem_rng.randf_range(0.25, 0.64)
		var axis := Vector3(lean_dir.x * sin(angle), cos(angle), lean_dir.y * sin(angle))
		var side := Vector3(-lean_dir.y, 0.0, lean_dir.x)
		var length := stem_rng.randf_range(0.24, 0.32)
		# Each panicle presents a different face in the loose clump.
		_panicle(st, top, axis, side.rotated(axis, stem_rng.randf_range(-1.25, 1.25)), length, tone)
	st.index()
	var mesh := st.commit()
	mesh.resource_name = "harappa_susuki"
	return mesh

## UV.y follows the culm from root to tip. The image carries the curved awns
## and the gaps between them, so a whole head needs only two triangles.
static func _panicle(st: SurfaceTool, root: Vector3, axis: Vector3, side: Vector3, length: float, tone: float) -> void:
	var normal := (axis.cross(side) * 0.25 + Vector3.UP).normalized()
	var width := length * 0.50
	for uv: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		st.set_normal(normal)
		st.set_uv(uv)
		st.set_uv2(Vector2(tone, 1.0))
		st.add_vertex(root + axis * (uv.y * length) + side * ((uv.x - 0.5) * width))

# --- Thinning and the playground hedges ---------------------------------------

## The even beds of spiky fountain grass mostly give way to the long grass;
## odd clumps stay, more of them toward the meadow edge.
static func _thin(park: Node3D, terrain: Node) -> Dictionary:
	var report := {}
	var is_spiky := func(label: String) -> bool:
		var l := label.to_lower()
		return l.contains("fountain") or l.contains("emerald") or l.contains("woodlandfill") or l.contains("spiky") or l.contains("forestgrass")
	var keep_spiky := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		return not Biomes.pick(p, smoothstep(0.25, 0.75, _w(p, terrain)) * 0.86, 61)
	if ResourceLoader.exists(THIN_ALL):
		var helper := load(THIN_ALL) as Script
		if helper != null and _has_static(helper, "hide_low_planting"):
			report["spiky"] = helper.call("hide_low_planting", park, is_spiky, keep_spiky, RECT)
			report["via"] = "thin_all"
			return report
	var spiky_nodes := func(node: MultiMeshInstance3D) -> bool:
		return is_spiky.call(String(node.name) + " " + (node.multimesh.mesh.resource_name if node.multimesh.mesh else ""))
	var roots: Array = [park]
	var grass := park.get_tree().root.get_node_or_null("MidoriGrassDetail")
	if grass != null: roots.append(grass)
	report["spiky"] = Kit.thin_multimeshes(roots, spiky_nodes, keep_spiky)
	report["via"] = "kit"
	return report

static func _has_static(script: Script, method: String) -> bool:
	for entry: Dictionary in script.get_script_method_list():
		if String(entry.name) == method: return true
	return false

## The playground's edge shrubs have grown out: taller and wider, unevenly.
## Maples and grass tufts in the same planting stay as they are.
static func _shaggy_playground_hedges(park: Node3D, rng: RandomNumberGenerator) -> int:
	var planting := park.find_child(PLAYGROUND + "Planting", true, false) as Node3D
	if planting == null: return 0
	# The edge plants are renamed copies ("ActivityEdgePlant_N") of park plants,
	# so maples and fountain-grass tufts are told apart by their shared meshes
	# as well as by name and size.
	var skip_meshes := {}
	for key: String in ["japanese_maple_prototype", "emerald_fountain_grass_prototype"]:
		var source := park.get(key) as Node3D
		if source == null: continue
		for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			if part.mesh != null: skip_meshes[part.mesh.get_instance_id()] = true
	var grown := 0
	for child: Node in planting.get_children():
		var plant := child as Node3D
		if plant == null: continue
		var label := String(plant.name)
		var skip := false
		var low := INF
		var high := -INF
		for part: MeshInstance3D in plant.find_children("*", "MeshInstance3D", true, false):
			label += " " + String(part.name) + " " + (part.mesh.resource_name if part.mesh else "")
			if part.mesh == null: continue
			if skip_meshes.has(part.mesh.get_instance_id()): skip = true
			var box := part.global_transform * part.get_aabb()
			low = minf(low, box.position.y)
			high = maxf(high, box.end.y)
		label = label.to_lower()
		if skip or label.contains("maple") or label.contains("fountain") or label.contains("emerald") or label.contains("grass"): continue
		var tall := high - low
		# Shrubs only: no ground cover, no trees.
		if tall < 0.6 or tall > 4.5: continue
		# Grown out, but no shrub past about 3.4 m.
		var grow_y := minf(rng.randf_range(1.25, 1.55), maxf(1.0, 3.4 / tall))
		plant.scale = Vector3(plant.scale.x * rng.randf_range(1.0, 1.2), plant.scale.y * grow_y, plant.scale.z * rng.randf_range(1.0, 1.2))
		plant.rotation.x += rng.randf_range(-0.06, 0.06)
		plant.rotation.z += rng.randf_range(-0.06, 0.06)
		grown += 1
	return grown
