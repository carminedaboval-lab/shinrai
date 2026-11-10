extends RefCounted
## Koke-niwa 苔庭, the moss stroll garden on the wooded rise west of the lake
## (docs/biome_concepts/after_moss_garden.png and extra/after_moss_garden_*.png),
## plus its small satellite by the northern iris pocket. The ground look map
## already lays the moss carpet; this builder adds what stands on it:
##  - clipped round mounds (tamamono) of azalea, boxwood and holly in loose
##    groups of 3 and 5, some of the azaleas in pink-red flower,
##  - Kasuga stone lanterns in pairs, near and far, each seated on a checked
##    clear spot found outward from where the concept frames show it,
##  - irregular flattened stepping stones along composed strolls that cross
##    the moss from each approach, and along the garden's worn trails,
##  - half-sunk mossy stones by some groups and the lanterns, with moss
##    cushions round their feet,
##  - a few green maples on the rim, built exactly as the maple glen builds them.
## The spiky grass beds and most upright lawn blades thin out inside.
## Nothing is laid on a grid or in a line: every placement is jittered and
## clustered, and all thinning is a dithered pick by weight, so edges feather.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
const ClippedShrubs := preload("res://scripts/midori_clipped_shrubs.gd")
const ID := "koke"
const MAIN_C := Vector2(-14, 20)
const MAIN_R := Vector2(44, 40)
const SAT_C := Vector2(24, -114)
const SAT_R := 18.0
# Region bounds plus their feather, for cheap early-outs.
const MAIN_RECT := Rect2(-72, -34, 116, 108)
const SAT_RECT := Rect2(-2, -140, 52, 52)
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const MOSS := "res://assets/shinrai/parks/midori_park/models/island_nature/moss_%02d.glb"
const MAPLE := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/free3d_japanese_maple_n030123/midori_japanese_maple_lite.res"
const LANTERN := "res://assets/shinrai/parks/midori_park/models/stone_lantern/kasuga_lantern.glb"
const LANTERN_DATA := "res://assets/shinrai/parks/midori_park/models/stone_lantern/measurements.json"
# Spots are back-projected from the concept frames through the review cameras
# (fov 70, eye 1.7 m; see docs/biome_concepts/extra). Each pair is the near and
# the far lantern of one view: east walk (moss_garden), north approach, west
# approach, satellite. Each is searched outward from its spot, nearest first.
const LANTERN_SPOTS := [
	Vector2(10.6, 31.8), Vector2(5.6, 20.7),
	Vector2(-10.1, -6.1), Vector2(-19.0, 1.2),
	Vector2(-44.7, 34.8), Vector2(-30.1, 39.9),
	Vector2(10.5, -106.5), Vector2(19.5, -99.5),
]
const LANTERN_GAP := 9.0
# Height the lanterns stand at, as a multiple of the asset's 1.5 m: 1.8 m.
const LANTERN_SCALE := 1.2
# Mound groups tried first: [centre, members, blooms (0 green, 1 flowering,
# 2 mixed)]. Front groups sit 3.5-6 m from the review eyes, as in the concepts.
const FOCUS := [
	# moss_garden: flowering five front left, flowering three front right,
	# a green group behind each.
	[Vector2(13.5, 31.1), 5, 1], [Vector2(14.4, 24.7), 3, 1], [Vector2(8.9, 33.9), 3, 0], [Vector2(9.5, 23.5), 3, 0],
	# moss_garden_north
	[Vector2(-11.8, -8.5), 5, 2], [Vector2(-17.2, -6.2), 5, 2], [Vector2(-7.6, -5.2), 3, 0],
	# moss_garden_west
	# (The green three sits just left of the near lantern, x~270 px at 7.5 m;
	# further west it fell half out of the frame's left edge.)
	[Vector2(-46.2, 38.3), 5, 2], [Vector2(-42.9, 42.6), 3, 1], [Vector2(-45.2, 32.3), 3, 0],
	# Deeper across the knoll.
	[Vector2(-3, 31), 3, 1], [Vector2(-24, 30), 5, 2], [Vector2(-30, 22), 3, 0], [Vector2(-4, 15), 3, 1],
	# Satellite.
	[Vector2(10.0, -109.0), 3, 2], [Vector2(14.0, -97.8), 3, 1],
]
# Stepping-stone strolls framed by the same cameras: from the edge of each
# approach across the moss toward the far lantern. Points wander; stones are
# jittered along them, so nothing reads as a ruled line.
const STROLLS := [
	[Vector2(15.7, 29.5), Vector2(15.1, 28.2), Vector2(14.3, 27.1), Vector2(12.8, 26.5), Vector2(10.8, 26.5), Vector2(8.6, 26.0), Vector2(6.9, 24.6), Vector2(5.0, 23.6), Vector2(3.0, 23.1), Vector2(1.2, 24.2), Vector2(0.2, 26.4), Vector2(0.0, 28.4)],
	[Vector2(-14.4, -9.8), Vector2(-15.4, -8.9), Vector2(-15.6, -7.7), Vector2(-15.0, -6.6), Vector2(-14.6, -5.3), Vector2(-14.8, -3.9), Vector2(-15.7, -2.5), Vector2(-17.0, -1.0), Vector2(-17.6, 1.0), Vector2(-17.2, 3.5)],
	[Vector2(-46.4, 40.0), Vector2(-44.9, 40.3), Vector2(-43.6, 40.3), Vector2(-42.4, 39.6), Vector2(-41.4, 38.2), Vector2(-39.8, 37.1), Vector2(-37.5, 36.8), Vector2(-35.2, 37.3), Vector2(-33.2, 38.4)],
	[Vector2(9.9, -100.1), Vector2(11.0, -100.6), Vector2(12.2, -102.2), Vector2(13.2, -104.0), Vector2(14.6, -105.6), Vector2(16.6, -106.6), Vector2(18.8, -107.4)],
	[Vector2(12.4, -100.5), Vector2(14.1, -99.6), Vector2(15.9, -99.2), Vector2(17.6, -99.4)],
]
# Light-green maples on the rim where the concept frames show them.
const MAPLE_SPOTS := [Vector2(-1.5, 22.0), Vector2(-4.5, 41.5), Vector2(-20.4, -5.0), Vector2(-43.8, 25.9), Vector2(-31.9, 33.9)]
# The concepts show the lanterns lit. The park's flame component
# (stone_lantern_fire.gd) runs _process every frame, so these lanterns get a
# script-free copy instead: the same flame shader (it flickers on TIME) and the
# same two small lights, faded out by the lights' own distance fade.
const LANTERNS_LIT := true
# The flame text itself lives in stone_lantern_fire.gd: one exact string, so the
# pool compiles one flame shader for both kinds of lantern (that script preloads
# only the pool, so there is no preload cycle).
const FLAME_SHADER: String = preload("res://scripts/stone_lantern_fire.gd").FLAME_SHADER
const TRAILS := ["Wooded rise garden", "Northern iris pocket"]
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
const MAX_GROUPS_MAIN := 18
const MAX_GROUPS_SAT := 3
const MAX_MAPLES_MAIN := 5
const MAX_MAPLES_SAT := 1
# Shell visibility, as the clipped shrubs use them: fringe first, core last.
const SHELL_RANGES := [160.0, 70.0, 40.0]

const MAPLE_LEAF_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
void fragment() {
	vec3 t = texture(leaf_tex, UV).rgb;
	float l = dot(t, vec3(0.3, 0.59, 0.11));
	ALBEDO = COLOR.rgb * (0.55 + 1.25 * l);
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	BACKLIGHT = COLOR.rgb * 0.5;
}
"""

## The clipped-shrub shader (shaders/midori_clipped_shrub.gdshader) with
## satsuki flowers: a coarser jittered cell set in world space marks single
## round blooms, mostly on the upper faces, kept through the shell cut-out.
const BLOOM_SHADER := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform float shell = 0.0;
uniform float leaf_size = 0.028;
uniform float flower_size = 0.08;
uniform float bloom = 0.6;
uniform vec3 petal_a : source_color = vec3(0.74, 0.17, 0.3);
uniform vec3 petal_b : source_color = vec3(0.86, 0.36, 0.47);
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
	// Blooms: one per coarse cell where the hash says so.
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
	vec3 colour = mix(foliage, flower * mix(0.7, 1.0, depth), petal);
	ALBEDO = colour;
	vec3 tilt = (h - 0.5) * 1.3 * (1.0 - petal * 0.6);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = mix(mix(0.42, 0.7, h.y), 0.8, petal);
	SPECULAR = 0.45;
	BACKLIGHT = colour * 0.35;
}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeMossGarden"
	park.add_child(root)
	# Every batch below is laid in world metres; pin the root to the world
	# origin so a moved or scaled park root can never offset them.
	root.global_transform = Transform3D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501104
	# Footprints of everything this builder stands up:
	# {Vector2i: [Vector4(x, z, spacing radius, cover radius)]}. Spacing lets
	# group members tuck together; cover is the full drawn footprint, which
	# the thinning clears so nothing pokes through.
	var taken := {}
	# Stepping-stone footprints alone, so mounds and boulders keep their whole
	# drawn width off the treads (taken only spaces them by the tuck radius).
	var treads := {}
	var maples := await _plant_maples(park, terrain, root, rng)
	if not is_instance_valid(park): return {}
	var lanterns := _lanterns(park, terrain, root, taken)
	var stones := _stepping_stones(park, terrain, root, rng, taken, treads)
	await park.get_tree().process_frame
	if not is_instance_valid(park): return {}
	var mounds := await _mound_groups(park, terrain, root, rng, taken, treads)
	if not is_instance_valid(park): return {}
	# Moss cushions at the feet of stones, lanterns and mounds.
	var anchors: Array = []
	anchors.append_array(mounds.moss_anchors)
	for lamp: Dictionary in lanterns: anchors.append([lamp.p, 0.32, 0.95, 260])
	anchors.append_array(stones.moss_anchors)
	var moss := _moss_cushions(park, terrain, root, rng, anchors)
	var leaves := 0
	if not maples.is_empty():
		var box := Rect2(maples[0].p, Vector2.ZERO)
		for m: Dictionary in maples: box = box.expand(m.p)
		box = box.grow(5.5)
		leaves = await Kit.leaf_floor(park, terrain, root, rng, box, func(p: Vector2) -> float:
			var near := 0.0
			for m: Dictionary in maples:
				var d: float = (m.p as Vector2).distance_to(p)
				if d < 5.0: near = maxf(near, 1.0 - d / 5.0)
			return near * near * 7.0, 0.45, "KokeMapleLeaves")
	if not is_instance_valid(park): return {}
	var thinned := _thin(park, terrain, taken)
	return {
		"maples": maples.size(),
		"lanterns": lanterns.map(func(l: Dictionary) -> Array: return [snappedf(l.p.x, 0.1), snappedf(l.p.y, 0.1)]),
		"stepping_stones": stones.count,
		"mound_groups": mounds.groups,
		"framed_groups": mounds.framed,
		"mounds": mounds.count,
		"stroll_stones": stones.strolls,
		"flowering_mounds": mounds.flowering,
		"mossy_stones": mounds.boulders,
		"moss_fronds": moss,
		"maple_leaves": leaves,
		"thinned": thinned,
	}

static func _w(p: Vector2, terrain: Node) -> float:
	return Biomes.weight(p, ID, terrain)

static func _in_bounds(p: Vector2) -> bool:
	return MAIN_RECT.has_point(p) or SAT_RECT.has_point(p)

static func _reserve(taken: Dictionary, p: Vector2, r: float, cover: float = -1.0) -> void:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	if not taken.has(key): taken[key] = []
	(taken[key] as Array).append(Vector4(p.x, p.y, r, cover if cover >= 0.0 else r))

## True when a disc of radius r at p touches nothing this builder placed.
static func _free(taken: Dictionary, p: Vector2, r: float) -> bool:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for v: Vector4 in taken.get(key + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(v.x, v.y)) < r + v.z: return false
	return true

## True when p lies within pad of the drawn footprint of something placed here.
static func _covered(taken: Dictionary, p: Vector2, pad: float) -> bool:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for v: Vector4 in taken.get(key + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(v.x, v.y)) < pad + v.w: return true
	return false

static func _trunk_near(park: Node3D, p: Vector2, r: float) -> bool:
	if park.has_method("any_trunk_within"): return park.any_trunk_within(p, r)
	return Kit.trunk_distance(park, p, r + 1.0) < r

## True when nothing but the ground is under the point (no prop, deck or roof).
static func _bare(park: Node3D, terrain: Node, p: Vector2) -> bool:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.position.y < ground + 0.35

## _bare at the centre and at four points round a disc of radius r, so a wide
## mound cannot lean its shell into a crate or bench the centre ray missed.
static func _bare_disc(park: Node3D, terrain: Node, p: Vector2, r: float) -> bool:
	if not _bare(park, terrain, p): return false
	for side: int in range(4):
		if not _bare(park, terrain, p + Vector2(r, 0).rotated(float(side) * TAU / 4.0 + 0.3)): return false
	return true

## Lowest ground under a disc, so nothing floats on a slope.
static func _low_ground(terrain: Node, p: Vector2, r: float) -> float:
	var low: float = terrain.height_at(p)
	for k: int in range(6):
		var q := p + Vector2(r, 0).rotated(float(k) * TAU / 6.0 + 0.4)
		low = minf(low, float(terrain.height_at(q)))
	return low

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
	# Iris and flower colonies (the satellite sits on the northern iris pocket).
	if flowers != null and flowers.has_method("_inside_colony") and flowers.call("_inside_colony", p, r + 0.3): return false
	# The park's big mossy cover boulders.
	var nature := park.get_node_or_null("MidoriIslandNature")
	if nature != null and nature.get("mainland_cover") != null:
		for rock: Dictionary in nature.get("mainland_cover"):
			if p.distance_to(rock.p) < r + float(rock.radius) + 0.5: return false
	return true

# --- Green maples on the rim -------------------------------------------------

static func _plant_maples(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator) -> Array:
	var placed: Array = []
	if not ResourceLoader.exists(MAPLE): return placed
	var mesh: ArrayMesh = load(MAPLE)
	# Trunk base: the lowest bark ring, so the tree stands on its own root.
	var bark: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := INF
	for v: Vector3 in bark: low = minf(low, v.y)
	var base := Vector3.ZERO
	var n := 0
	for v: Vector3 in bark:
		if v.y < low + 4.0:
			base += v
			n += 1
	base /= maxf(1.0, float(n))
	base.y = low
	var tall := mesh.get_aabb().size.y
	var main_count := 0
	var sat_count := 0
	# The framed rim spots first, each searched outward to 5 m, nearest first.
	for target: Vector2 in MAPLE_SPOTS:
		if main_count >= MAX_MAPLES_MAIN: break
		for attempt: int in range(80):
			var p: Vector2 = target + Vector2(1, 0).rotated(float(attempt) * 2.399963) * sqrt(float(attempt) / 79.0) * 5.0
			if not _maple_spot(park, terrain, p, placed, 12.0, 0.3, 3.6): continue
			placed.append({"p": p, "h": rng.randf_range(5.5, 7.5), "yaw": rng.randf() * TAU})
			main_count += 1
			break
	await park.get_tree().process_frame
	if not is_instance_valid(park): return []
	for attempt: int in range(700):
		if main_count >= MAX_MAPLES_MAIN and sat_count >= MAX_MAPLES_SAT: break
		var sat := attempt % 4 == 3
		if sat and sat_count >= MAX_MAPLES_SAT: continue
		if not sat and main_count >= MAX_MAPLES_MAIN: continue
		var a := rng.randf() * TAU
		var p: Vector2
		if sat: p = SAT_C + Vector2(cos(a), sin(a)) * SAT_R * rng.randf_range(0.6, 0.95)
		else: p = MAIN_C + Vector2(cos(a) * MAIN_R.x, sin(a) * MAIN_R.y) * rng.randf_range(0.74, 0.98)
		# On the rim: inside the garden, but not at its heart.
		if not _maple_spot(park, terrain, p, placed, 9.0 if sat else 15.0, 0.4, 4.6): continue
		placed.append({"p": p, "h": rng.randf_range(5.5, 7.5), "yaw": rng.randf() * TAU})
		if sat: sat_count += 1
		else: main_count += 1
		await park.get_tree().process_frame
		if not is_instance_valid(park): return []
	if placed.is_empty(): return placed
	var leaf_look := ShaderPool.material(MAPLE_LEAF_SHADER)
	var source_leaf := mesh.surface_get_material(1)
	if source_leaf is BaseMaterial3D: leaf_look.set_shader_parameter("leaf_tex", source_leaf.albedo_texture)
	var tree_mesh := mesh.duplicate() as ArrayMesh
	tree_mesh.surface_set_material(1, leaf_look)
	# Japanese maple bark is smooth grey-brown, not the source's pale yellow-brown.
	var bark_look := (mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
	bark_look.albedo_color = Color(0.46, 0.4, 0.36)
	bark_look.roughness = 0.85
	tree_mesh.surface_set_material(0, bark_look)
	# One batch per 32 m cell rather than one garden-wide batch, so a maple
	# behind the camera is frustum-culled instead of drawn with the rest.
	var rows: Array = []
	for i: int in range(placed.size()):
		var m: Dictionary = placed[i]
		var s: float = m.h / tall
		var ground: float = terrain.height_at(m.p)
		var basis := Basis(Vector3.UP, m.yaw).scaled(Vector3(s * rng.randf_range(0.92, 1.08), s, s * rng.randf_range(0.92, 1.08)))
		var origin := Vector3(m.p.x, ground - 0.05, m.p.y) - basis * base
		rows.append([Transform3D(basis, origin), Color(0.22, 0.31, 0.085).lerp(Color(0.3, 0.35, 0.11), rng.randf())])
		var body := StaticBody3D.new()
		body.name = "KokeMapleTrunk_%02d" % i
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.2
		cylinder.height = 2.6
		shape.shape = cylinder
		body.add_child(shape)
		root.add_child(body)
		body.global_position = Vector3(m.p.x, ground + 1.3, m.p.y)
		park.occupied_tree_positions.append(m.p / 2.0)
		park.occupied_tree_is_skinny.append(false)
	# The surfaces keep their own leaf and bark materials (no override).
	Kit.cell_batches(root, "KokeMaples", tree_mesh, null, rows, 32.0, 220.0, true)
	return placed

## A maple may stand here: in the garden, spaced from the others, on open
## unbuilt ground clear of the park's own garden pieces.
static func _maple_spot(park: Node3D, terrain: Node, p: Vector2, placed: Array, gap: float, min_w: float, tree_gap: float) -> bool:
	if not _in_bounds(p) or _w(p, terrain) < min_w: return false
	for m: Dictionary in placed:
		if (m.p as Vector2).distance_to(p) < gap: return false
	if not Kit.open_ground(park, terrain, p, 2.0, tree_gap): return false
	if not _clear_of_gardens(park, p, 1.5): return false
	return _bare(park, terrain, p)

# --- Kasuga lanterns ---------------------------------------------------------

static func _lanterns(park: Node3D, terrain: Node, root: Node3D, taken: Dictionary) -> Array:
	var placed: Array = []
	if not ResourceLoader.exists(LANTERN): return placed
	var data: Dictionary = {}
	if FileAccess.file_exists(LANTERN_DATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LANTERN_DATA))
		if parsed is Dictionary: data = parsed
	# The asset is 1.5 m; the concepts' lanterns stand about 1.8 m (back-
	# projected: 215 px tall at 6.5 m in the east walk frame), so it is scaled
	# up, footprint, flame and colliders with it.
	var s := LANTERN_SCALE * 1.5 / maxf(float(data.get("height", 1.5)), 0.1)
	var base_r: float = float(data.get("base_radius", 0.28)) * s
	var roof_r: float = float(data.get("clearance_radius", 0.41)) * s
	var source := load(LANTERN) as PackedScene
	if source == null: return placed
	for index: int in range(LANTERN_SPOTS.size()):
		var target: Vector2 = LANTERN_SPOTS[index]
		var spot := Vector2.INF
		var base_y := 0.0
		# Prefer the authored pocket; spiral out to 8 m.
		for attempt: int in range(320):
			var p := target + Vector2(1, 0).rotated(float(attempt) * 2.399963) * sqrt(float(attempt) / 319.0) * 8.0
			var seat := _lantern_seat(park, terrain, p, base_r, roof_r, placed)
			if is_nan(seat): continue
			spot = p
			base_y = seat
			break
		if spot == Vector2.INF: continue
		var lamp := Node3D.new()
		lamp.name = "KokeLantern_%d" % index
		root.add_child(lamp)
		lamp.global_position = Vector3(spot.x, base_y, spot.y)
		# The open front (+Z) faces the nearest walk or trail.
		var toward := _nearest_walk(park, terrain, spot) - spot
		if toward.length() > 0.01: lamp.rotation.y = atan2(toward.x, toward.y)
		var model := source.instantiate() as Node3D
		model.scale = Vector3.ONE * s
		lamp.add_child(model)
		if LANTERNS_LIT and data.has("fire_origin"):
			var fire := _static_flame(3.1 + float(index) * 2.399963)
			var o: Array = data.fire_origin
			fire.position = Vector3(float(o[0]), float(o[1]), float(o[2])) * s
			fire.scale = Vector3.ONE * s
			lamp.add_child(fire)
		var body := StaticBody3D.new()
		body.name = "StoneCollision"
		body.collision_layer = 1
		body.collision_mask = 1
		lamp.add_child(body)
		var parts: Array = data.get("collision_parts", [])
		if parts.is_empty(): parts = [{"centre": [0.0, 0.7, 0.0], "size": [0.5, 1.4, 0.5]}]
		for part: Dictionary in parts:
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			var size: Array = part.size
			var centre: Array = part.centre
			# Scaled numerically: physics shapes under a scaled node are unreliable.
			box.size = Vector3(float(size[0]), float(size[1]), float(size[2])) * s
			collider.shape = box
			collider.position = Vector3(float(centre[0]), float(centre[1]), float(centre[2])) * s
			body.add_child(collider)
		# Keep mounds a step away, but clear grass only round the stone foot.
		_reserve(taken, spot, roof_r + 0.75, base_r + 0.12)
		placed.append({"p": spot, "radius": base_r})
	return placed

## The oil flame and its two small lights, as stone_lantern_fire.gd builds them,
## without the per-frame script: the shader flickers on TIME and the lights
## fade out between 18 and 24 m on their own.
static func _static_flame(phase: float) -> Node3D:
	var fire := Node3D.new()
	fire.name = "LanternFlame"
	# One pooled flame shader for every lantern; the phase is a uniform.
	var material := ShaderPool.material(FLAME_SHADER)
	material.set_shader_parameter("phase", phase)
	var flame := MeshInstance3D.new()
	flame.name = "SmallOilFlame"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.026, 0.055)
	flame.mesh = quad
	flame.position.y = 0.0275
	flame.material_override = material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.visibility_range_end = 45.0
	fire.add_child(flame)
	var light := OmniLight3D.new()
	light.name = "WarmChamberLight"
	light.position.y = 0.025
	light.light_color = Color(1.0, 0.64, 0.30)
	light.light_energy = 0.045
	light.omni_range = 1.8
	light.omni_attenuation = 1.8
	# At 0.045 energy its shadow cannot be seen; a shadowed omni costs a cube
	# map render per lantern in range, and there are eight lanterns now.
	light.shadow_enabled = false
	light.light_size = 0.025
	light.distance_fade_enabled = true
	light.distance_fade_begin = 18.0
	light.distance_fade_shadow = 18.0
	light.distance_fade_length = 6.0
	fire.add_child(light)
	var spill := SpotLight3D.new()
	spill.name = "ReflectedApertureGlow"
	spill.position = Vector3(0, 0.025, 0.225)
	spill.rotation_degrees = Vector3(-35, 180, 0)
	spill.light_color = Color(1.0, 0.64, 0.30)
	spill.light_energy = 0.65
	spill.spot_range = 1.8
	spill.spot_angle = 50
	spill.spot_attenuation = 2.0
	spill.shadow_enabled = true
	spill.shadow_bias = 0.03
	spill.shadow_normal_bias = 0.15
	spill.light_size = 0.025
	spill.distance_fade_enabled = true
	spill.distance_fade_begin = 18.0
	spill.distance_fade_shadow = 18.0
	spill.distance_fade_length = 6.0
	fire.add_child(spill)
	return fire

## Base height for a lantern at p, or NAN when the spot is not clear or flat.
static func _lantern_seat(park: Node3D, terrain: Node, p: Vector2, base_r: float, roof_r: float, placed: Array) -> float:
	if _w(p, terrain) < 0.3: return NAN
	if not Kit.open_ground(park, terrain, p, roof_r + 0.6): return NAN
	if park.has_method("_is_near_destination_path") and park._is_near_destination_path(p / 2.0, (roof_r + 0.45) / 2.0): return NAN
	if _trunk_near(park, p, base_r + 1.4): return NAN
	if not _clear_of_gardens(park, p, roof_r): return NAN
	for prior: Dictionary in placed:
		if p.distance_to(prior.p) < LANTERN_GAP: return NAN
	var low: float = terrain.height_at(p)
	var high := low
	for side: int in range(8):
		var q := p + Vector2(base_r, 0).rotated(float(side) * TAU / 8.0)
		if terrain.water_at(q): return NAN
		var h: float = terrain.height_at(q)
		low = minf(low, h)
		high = maxf(high, h)
	# The stone base is about 23 cm tall and is seated at the lowest point, so
	# up to 9 cm of fall across it only buries its uphill side a little. The
	# knoll's own slope is about that; a stricter limit pushed the lanterns
	# metres off their framed spots.
	if high - low > 0.09: return NAN
	if not _bare(park, terrain, p): return NAN
	for side: int in range(4):
		if not _bare(park, terrain, p + Vector2(roof_r, 0).rotated(float(side) * TAU / 4.0 + 0.6)): return NAN
	return low - 0.008

static func _nearest_walk(park: Node3D, terrain: Node, p: Vector2) -> Vector2:
	var best := p + Vector2(0, 1)
	var distance := INF
	var lines: Array = []
	if terrain != null and terrain.get("paths") != null: lines.append_array(terrain.get("paths"))
	lines.append_array(_trail_lines(park))
	for line: Variant in lines:
		var points := PackedVector2Array(line)
		for i: int in range(points.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
			var d := p.distance_to(q)
			if d < distance:
				distance = d
				best = q
	return best

static func _trail_lines(park: Node3D) -> Array:
	var lines: Array = []
	var desire := park.get_node_or_null("MidoriDesirePaths")
	if desire == null or desire.get("routes") == null: return lines
	for route: Dictionary in desire.get("routes"):
		if String(route.get("name", "")) in TRAILS: lines.append(PackedVector2Array(route.points))
	return lines

# --- Stepping stones (tobi-ishi) ---------------------------------------------

## The forest-floor stones as prototypes, their material toned: tread stones
## a muted grey (walked clean), garden stones a faint moss-olive cast.
static func _stone_parts(tone: Color, roughness: float) -> Array:
	var protos: Array = []
	for i: int in range(6):
		var proto := Kit.file_parts(FLOOR + "stone_%02d.glb" % i)
		if proto.parts.is_empty(): continue
		for part: Dictionary in proto.parts:
			var mesh: Mesh = part.mesh
			for s: int in range(mesh.get_surface_count()):
				var look := mesh.surface_get_material(s)
				if look is BaseMaterial3D:
					var toned := look.duplicate() as BaseMaterial3D
					toned.albedo_color = tone
					toned.roughness = roughness
					mesh.surface_set_material(s, toned)
		protos.append(proto)
	return protos

## Seat a stone prototype by its widest horizontal span (the glbs differ in
## proportion, so seating by height could make a flat one huge), sunk by a
## fraction of its resulting height. Returns [transform, height].
static func _seat_wide(proto: Dictionary, terrain: Node, p: Vector2, width: float, yaw: float, sink: float, extra: Basis = Basis.IDENTITY) -> Array:
	var box: AABB = proto.box
	var span := maxf(maxf(box.size.x, box.size.z), 0.001)
	var s := width / span
	var basis := (Basis(Vector3.UP, yaw) * extra).scaled(Vector3.ONE * s)
	var footprint := Transform3D(basis, Vector3.ZERO) * box
	var anchor := Vector3(footprint.get_center().x, footprint.position.y, footprint.get_center().z)
	var tall := footprint.size.y
	var ground := _low_ground(terrain, p, width * 0.3)
	return [Transform3D(basis, Vector3(p.x, ground - tall * sink, p.y) - anchor), tall]

static func _stepping_stones(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, taken: Dictionary, treads: Dictionary) -> Dictionary:
	var out := {"count": 0, "strolls": 0, "moss_anchors": []}
	var protos := _stone_parts(Color(0.9, 0.89, 0.86), 0.82)
	if protos.is_empty(): return out
	# [points, framed]: the framed strolls first, then the worn trails.
	var lines: Array = []
	for stroll: Array in STROLLS: lines.append([PackedVector2Array(stroll), true])
	var trails := _trail_lines(park)
	if trails.is_empty(): trails.append(PackedVector2Array([Vector2(-25, 30), Vector2(-13, 31.2), Vector2(0, 29)]))
	for trail: PackedVector2Array in trails: lines.append([trail, false])
	var rows: Array = []
	for i: int in range(protos.size()): rows.append([])
	for entry: Array in lines:
		var line: PackedVector2Array = entry[0]
		var framed: bool = entry[1]
		var lengths: Array[float] = []
		var total := 0.0
		for i: int in range(line.size() - 1):
			var l := line[i].distance_to(line[i + 1])
			lengths.append(l)
			total += l
		var along := rng.randf_range(0.2, 0.5) if framed else rng.randf_range(0.4, 0.9)
		var lateral := 0.0
		# Stroll stones are the broad treads of the concepts; trail stones smaller.
		var next_width := rng.randf_range(0.62, 0.95) if framed else rng.randf_range(0.46, 0.74)
		while along < total - 0.3:
			# Point and heading at this distance along the line.
			var rest := along
			var seg := 0
			while seg < lengths.size() - 1 and rest > lengths[seg]:
				rest -= lengths[seg]
				seg += 1
			var dir := (line[seg + 1] - line[seg]).normalized()
			var at := line[seg] + dir * rest
			var width := next_width
			var depth := width * rng.randf_range(0.72, 0.95)
			# A wandering lateral offset, not a zigzag.
			lateral = clampf(lateral * 0.55 + rng.randf_range(-0.12, 0.12), -0.2, 0.2)
			var p := at + Vector2(-dir.y, dir.x) * lateral
			next_width = rng.randf_range(0.62, 0.95) if framed else rng.randf_range(0.46, 0.74)
			# Centre to centre: half of this stone, a stride gap, half the next.
			along += maxf(width, depth) * 0.5 + rng.randf_range(0.16, 0.3) + next_width * 0.5
			var sw := _w(p, terrain)
			if framed:
				# The strolls are composed: they run on toward the garden's edge and
				# only rarely miss a stone.
				if sw < 0.1 or rng.randf() < 0.05: continue
			# Trail stones thin out with the garden's weight instead of stopping on
			# a line across the trail; inside, now and then one is simply missing.
			elif sw < 0.12 or rng.randf() > smoothstep(0.12, 0.5, sw) * 0.94: continue
			if terrain.water_at(p): continue
			if park.has_method("path_edge_distance_world") and park.path_edge_distance_world(p) < 0.75: continue
			# Never under a lantern, another stone, or a prop.
			if not _free(taken, p, maxf(width, depth) * 0.4): continue
			# Never through a trunk or into the park's own garden stones and shrubs.
			if _trunk_near(park, p, maxf(width, depth) * 0.5 + 0.3): continue
			if not _clear_of_gardens(park, p, maxf(width, depth) * 0.4): continue
			if framed and not _bare(park, terrain, p): continue
			var k := rng.randi() % protos.size()
			var proto: Dictionary = protos[k]
			var box: AABB = proto.box
			var rise := rng.randf_range(0.08, 0.13)
			var yaw := atan2(dir.x, dir.y) + rng.randf_range(-0.7, 0.7)
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.035, 0.035)) * Basis(Vector3.FORWARD, rng.randf_range(-0.035, 0.035))
			# The stone lies along the knoll's slope: seated level at the lowest
			# point, a 6 % fall buried its uphill edge entirely.
			var e := 0.4
			var gx: float = (float(terrain.height_at(p + Vector2(e, 0))) - float(terrain.height_at(p - Vector2(e, 0)))) / (2.0 * e)
			var gz: float = (float(terrain.height_at(p + Vector2(0, e))) - float(terrain.height_at(p - Vector2(0, e)))) / (2.0 * e)
			var lean := Basis(Quaternion(Vector3.UP, Vector3(-gx, 1.0, -gz).normalized()))
			var basis := lean * Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(Vector3(width / maxf(box.size.x, 0.01), rise / maxf(box.size.y, 0.01), depth / maxf(box.size.z, 0.01)))
			var anchor: Vector3 = basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
			# A little under half the stone's rise is buried, so it reads set into
			# the moss with its face a few centimetres proud all round.
			var ground: float = terrain.height_at(p)
			rows[k].append(Transform3D(basis, Vector3(p.x, ground - rise * 0.45, p.y) - anchor))
			_reserve(taken, p, maxf(width, depth) * 0.5)
			_reserve(treads, p, maxf(width, depth) * 0.5)
			if rng.randf() < 0.5: out.moss_anchors.append([p, maxf(width, depth) * 0.48, maxf(width, depth) * 0.62, 18])
			out.count += 1
			if framed: out.strolls += 1
	for k: int in range(protos.size()):
		Kit.batch_parts(root, "KokeSteppingStones%d" % k, protos[k], rows[k], 24.0, 70.0, false)
	return out

# --- Clipped mounds in groups ------------------------------------------------

static func _sample_centre(rng: RandomNumberGenerator, sat: bool) -> Vector2:
	var a := rng.randf() * TAU
	var k := sqrt(rng.randf())
	if sat: return SAT_C + Vector2(cos(a), sin(a)) * SAT_R * k * 0.85
	return MAIN_C + Vector2(cos(a) * MAIN_R.x, sin(a) * MAIN_R.y) * k * 0.9

static func _mound_groups(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, taken: Dictionary, treads: Dictionary) -> Dictionary:
	var out := {"groups": 0, "framed": 0, "count": 0, "flowering": 0, "boulders": 0, "moss_anchors": []}
	var centres: Array[Vector2] = []
	# Per centre: [members (0 = roll), blooms (-1 = roll), framed].
	var plans: Array = []
	var sat_groups := 0
	var main_groups := 0
	for focus: Array in FOCUS:
		var at: Vector2 = focus[0]
		var sat := SAT_RECT.has_point(at)
		# The framed spot itself, then outward in widening rings (to about 3.8 m)
		# until a clear seat turns up, so a prop or trail nudges the group
		# aside instead of dropping it out of the frame.
		for k: int in range(12):
			var p: Vector2 = at
			if k > 0: p += Vector2.from_angle(rng.randf() * TAU) * (0.5 + 0.3 * float(k)) * sqrt(rng.randf())
			if _w(p, terrain) < 0.2: continue
			var spaced := true
			for c: Vector2 in centres: if c.distance_to(p) < 4.0: spaced = false
			if not spaced or not Kit.open_ground(park, terrain, p, 1.2): continue
			if _trunk_near(park, p, 1.4) or not _free(taken, p, 1.0) or not _clear_of_gardens(park, p, 0.9): continue
			centres.append(p)
			plans.append([int(focus[1]), int(focus[2]), true])
			if sat: sat_groups += 1
			else: main_groups += 1
			break
	for attempt: int in range(1200):
		if main_groups >= MAX_GROUPS_MAIN and sat_groups >= MAX_GROUPS_SAT: break
		var sat := attempt % 5 == 4
		if sat and sat_groups >= MAX_GROUPS_SAT: continue
		if not sat and main_groups >= MAX_GROUPS_MAIN: continue
		var p := _sample_centre(rng, sat)
		if _w(p, terrain) < 0.55: continue
		var spaced := true
		for c: Vector2 in centres: if c.distance_to(p) < (7.0 if sat else 8.5): spaced = false
		if not spaced: continue
		if not Kit.open_ground(park, terrain, p, 2.0): continue
		if _trunk_near(park, p, 2.0) or not _free(taken, p, 1.4): continue
		if not _clear_of_gardens(park, p, 1.2): continue
		centres.append(p)
		plans.append([0, -1, false])
		if sat: sat_groups += 1
		else: main_groups += 1
	var green_rows: Array = []
	var bloom_rows: Array = []
	var boulder_rows: Array = []
	var boulders := _stone_parts(Color(0.8, 0.83, 0.72), 0.9)
	for gi: int in range(centres.size()):
		var c := centres[gi]
		var plan: Array = plans[gi]
		var framed: bool = plan[2]
		var roll := rng.randf()
		var size: int = int(plan[0]) if int(plan[0]) > 0 else (3 if roll < 0.55 else 5)
		# Share of the members in flower: framed groups follow their concept,
		# the scattered rest roll as before.
		var bloom_share := 0.0
		match int(plan[1]):
			0: bloom_share = 0.0
			1: bloom_share = 0.85
			2: bloom_share = 0.55
			_: bloom_share = 0.85 if rng.randf() < 0.45 else 0.0
		var flowering := bloom_share > 0.0
		var species: int = [0, 0, 1, 2, 2, 3][rng.randi() % 6]
		var members: Array = [] # [Vector2, width]
		for m: int in range(size):
			# The first is the largest; the rest gather against one already placed.
			# Concept sizes: the lead azalea ~1.35 m drawn (w ~1.2-1.4), the rest
			# ~0.8-1.2 m; larger leads at 4 m hid the near lantern's foot.
			var w := rng.randf_range(1.15, 1.55) if m == 0 else rng.randf_range(0.7, 1.2)
			for attempt: int in range(36 if framed else 28):
				var q := c
				if m > 0:
					var host: Array = members[rng.randi() % members.size()]
					var a := rng.randf() * TAU
					q = (host[0] as Vector2) + Vector2(cos(a), sin(a)) * (float(host[1]) * 0.5 + w * 0.5) * rng.randf_range(0.72, 1.02)
				elif attempt > 0:
					q = c + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
				if not _free(taken, q, w * 0.4): continue
				# The leaf shells reach 0.56 w: keep all of that off the treads.
				if not _free(treads, q, w * 0.56 + 0.1): continue
				if _w(q, terrain) < (0.2 if framed else 0.35) or not Kit.open_ground(park, terrain, q, w * 0.5 + 0.35): continue
				if _trunk_near(park, q, w * 0.5 + 0.45): continue
				if not _clear_of_gardens(park, q, w * 0.5): continue
				if not _bare_disc(park, terrain, q, w * 0.5): continue
				members.append([q, w])
				# Lumps and leaf shells reach a little past half the width.
				_reserve(taken, q, w * 0.4, w * 0.56)
				break
		if members.is_empty(): continue
		out.groups += 1
		if framed: out.framed += 1
		for mi: int in range(members.size()):
			var member: Array = members[mi]
			var q: Vector2 = member[0]
			var w: float = member[1]
			# Low and broad like the concepts' tamamono: the drawn mound is about
			# 1.1 w across and 1.15 h tall, so this gives a crown 0.55-0.7 of the
			# drawn width (the front azaleas there are ~1.35 m wide, ~0.8 m tall).
			var h := w * rng.randf_range(0.5, 0.64)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w * rng.randf_range(0.8, 1.0)))
			# The mound's base (mesh y 0) sits 5 cm below the lowest ground under
			# its footprint; its crown rises to about 1.16 h, so it always stands
			# proud of the moss even on the knoll's slope.
			var ground := _low_ground(terrain, q, w * 0.4)
			var t := Transform3D(basis, Vector3(q.x, ground - 0.05, q.y))
			# Now and then a green mound stands among the flowering ones; the
			# largest of a flowering group always blooms.
			var blooms := flowering and (mi == 0 or rng.randf() < bloom_share)
			if blooms:
				var leaf := Color(0.1, 0.17, 0.06) * rng.randf_range(0.9, 1.1)
				leaf.a = 0.04
				bloom_rows.append([t, leaf])
				out.flowering += 1
			else:
				var kind: Array = ClippedShrubs.SPECIES[species if not flowering else 2]
				# A little lighter than the street's shrubs: these stand in open
				# moss, not against walls, and read black in canopy shade otherwise.
				var leaf: Color = (kind[0] as Color) * rng.randf_range(1.12, 1.36)
				leaf.a = float(kind[1])
				green_rows.append([t, leaf])
			# Moss starts at the mound's foot, not hidden under it.
			out.moss_anchors.append([q, w * 0.5, w * 0.72, 48])
			out.count += 1
		# Half-sunk mossy stones at the edge of some groups.
		if boulders.is_empty() or rng.randf() > 0.5: continue
		for b: int in range(rng.randi_range(1, 2)):
			var host: Array = members[rng.randi() % members.size()]
			var a := rng.randf() * TAU
			var width := rng.randf_range(0.55, 1.05)
			var q: Vector2 = (host[0] as Vector2) + Vector2(cos(a), sin(a)) * (float(host[1]) * 0.5 + width * 0.42)
			if not _free(taken, q, width * 0.4) or not _free(treads, q, width * 0.5) or not Kit.open_ground(park, terrain, q, 0.8): continue
			if _trunk_near(park, q, 0.9) or not _clear_of_gardens(park, q, 0.5) or not _bare(park, terrain, q): continue
			var k := rng.randi() % boulders.size()
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
			var seated := _seat_wide(boulders[k], terrain, q, width, rng.randf() * TAU, 0.35, tilt)
			var tall: float = seated[1]
			boulder_rows.append([k, seated[0]])
			_reserve(taken, q, width * 0.45, width * 0.5)
			# Only stones that stand proud enough to bump into get a collider.
			if tall * 0.65 > 0.18: _collider(root, terrain, q, width * 0.4, tall * 0.65)
			out.moss_anchors.append([q, width * 0.4, width * 0.8, 160])
			out.boulders += 1
		if gi % 3 == 2:
			await park.get_tree().process_frame
			if not is_instance_valid(park): return out
	# Lanterns get a stone or two at their feet as well.
	var lamps: Array = []
	for child: Node in root.get_children():
		if String(child.name).begins_with("KokeLantern_"): lamps.append(child)
	for lamp: Node3D in lamps:
		var at := Vector2(lamp.global_position.x, lamp.global_position.z)
		var feet: Array[Vector3] = []
		for b: int in range(2):
			var a := rng.randf() * TAU
			var width := rng.randf_range(0.32, 0.55)
			var q := at + Vector2(cos(a), sin(a)) * rng.randf_range(0.7, 0.95)
			if boulders.is_empty() or not Kit.open_ground(park, terrain, q, 0.6) or not _bare(park, terrain, q): continue
			if not _free(treads, q, width * 0.5): continue
			if not _clear_of_gardens(park, q, width * 0.45): continue
			# The two foot stones never sit inside each other.
			var apart := true
			for other: Vector3 in feet:
				if q.distance_to(Vector2(other.x, other.y)) < (width + other.z) * 0.5 + 0.08: apart = false
			if not apart: continue
			feet.append(Vector3(q.x, q.y, width))
			var k := rng.randi() % boulders.size()
			var seated := _seat_wide(boulders[k], terrain, q, width, rng.randf() * TAU, 0.3)
			boulder_rows.append([k, seated[0]])
			_reserve(taken, q, width * 0.4, width * 0.5)
			out.moss_anchors.append([q, width * 0.4, width * 0.85, 70])
			out.boulders += 1
	_batch_mounds(root, green_rows, bloom_rows)
	var by_piece: Array = []
	for k: int in range(boulders.size()): by_piece.append([])
	for row: Array in boulder_rows: by_piece[row[0]].append(row[1])
	for k: int in range(boulders.size()):
		Kit.batch_parts(root, "KokeMossyStones%d" % k, boulders[k], by_piece[k], 24.0, 110.0, true)
	return out

static func _collider(root: Node3D, terrain: Node, p: Vector2, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "KokeStone"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	root.add_child(body)
	body.global_position = Vector3(p.x, float(terrain.height_at(p)) + height * 0.5 - 0.1, p.y)

static func _batch_mounds(root: Node3D, green_rows: Array, bloom_rows: Array) -> void:
	var bloom_shader := ShaderPool.shader(BLOOM_SHADER)
	for s: int in range(ClippedShrubs.SHELLS.size()):
		var mesh := ClippedShrubs._mound(float(ClippedShrubs.SHELLS[s]))
		var range_end: float = SHELL_RANGES[s]
		if not green_rows.is_empty():
			var look := ShaderMaterial.new()
			look.shader = ClippedShrubs.SHADER
			look.set_shader_parameter("shell", float(s))
			Kit.cell_batches(root, "KokeMounds%d" % s, mesh, look, green_rows, 24.0, range_end, s == 0)
		if not bloom_rows.is_empty():
			var bloom := ShaderMaterial.new()
			bloom.shader = bloom_shader
			bloom.set_shader_parameter("shell", float(s))
			# Azaleas in full flower, as the concepts show them: about half the
			# upper face in 5 cm blooms (the shader's defaults).
			bloom.set_shader_parameter("bloom", 0.6)
			Kit.cell_batches(root, "KokeAzaleas%d" % s, mesh, bloom, bloom_rows, 24.0, range_end, s == 0)

# --- Moss cushions -----------------------------------------------------------

## Moss fronds (the island moss pieces) scattered in soft rings at the feet of
## stones, lanterns and mounds. anchors: [centre, inner radius, outer radius, count].
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
	var walks := park.has_method("path_edge_distance_world")
	for anchor: Array in anchors:
		var c: Vector2 = anchor[0]
		var inner: float = anchor[1]
		var outer: float = anchor[2]
		var count: int = anchor[3]
		# The fronds are 2-3 cm sprigs: scattered singly they vanish, so they
		# gather in small cushions of a dozen or so, densest against the stone.
		var left := count
		while left > 0 and total < 30000:
			var tuft := mini(rng.randi_range(8, 18), left)
			left -= tuft
			var a := rng.randf() * TAU
			var r := lerpf(inner, outer, pow(rng.randf(), 1.6)) * rng.randf_range(0.92, 1.1)
			var centre := c + Vector2(cos(a), sin(a)) * r
			var spread := rng.randf_range(0.05, 0.12)
			if terrain.water_at(centre): continue
			if walks and park.path_edge_distance_world(centre) < spread + 0.05: continue
			for j: int in range(tuft):
				var p := centre + Vector2.from_angle(rng.randf() * TAU) * spread * sqrt(rng.randf())
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
				# Fuller in the middle of the cushion, smaller at its rim.
				var fullness := 1.0 - 0.35 * p.distance_to(centre) / spread
				basis = basis.scaled(Vector3.ONE * rng.randf_range(0.95, 1.5) * fullness)
				rows[rng.randi() % meshes.size()].append([Transform3D(basis, Vector3(p.x, float(terrain.height_at(p)) + 0.002, p.y))])
				total += 1
	for i: int in range(meshes.size()):
		if rows[i].is_empty(): continue
		Kit.cell_batches(root, "KokeMoss%d" % i, meshes[i], null, rows[i], 16.0, 20.0, false)
	return total

# --- Thinning ----------------------------------------------------------------

## Spiky beds mostly go; the lawn keeps about a third of its blades; nothing
## pokes up through a mound, stone or lantern this builder set down.
static func _thin(park: Node3D, terrain: Node, taken: Dictionary) -> Dictionary:
	var report := {}
	# Weight per 0.5 m cell: the shore search inside weights_at is costly and
	# the keep test runs for every grass instance in the area.
	var cache := {}
	var weight_at := func(p: Vector2) -> float:
		var key := Vector2i(floori(p.x * 2.0), floori(p.y * 2.0))
		if not cache.has(key): cache[key] = _w((Vector2(key) + Vector2(0.5, 0.5)) * 0.5, terrain)
		return float(cache[key])
	var is_spiky := func(label: String) -> bool:
		var l := label.to_lower()
		# Dense grass patches (VEG06_DenseGrass_*, tag "dense_grass") are spiky
		# clumps too; as "grass" they would otherwise keep a fifth like the lawn.
		return l.contains("fountain") or l.contains("emerald") or l.contains("woodlandfill") or l.contains("spiky") or l.contains("forestgrass") or l.contains("densegrass") or l.contains("dense_grass")
	var is_lawn := func(label: String) -> bool:
		var l := label.to_lower()
		if is_spiky.call(l): return false
		return l.contains("grass") or l.contains("blade") or l.contains("tuft") or l.contains("lawn") or l.contains("clump")
	# No spiky clump survives inside the garden (weight 0.5 and up); across the
	# feather they drop out by a dithered pick, so the edge stays ragged.
	var keep_spiky := func(p: Vector2) -> bool:
		if not _in_bounds(p): return true
		if _covered(taken, p, 0.08): return false
		return not Biomes.pick(p, smoothstep(0.12, 0.5, weight_at.call(p)), 41)
	var keep_lawn := func(p: Vector2) -> bool:
		if not _in_bounds(p): return true
		if _covered(taken, p, 0.05): return false
		# The moss carpet is the floor here. The lawn's upright grass_1k clumps
		# and ground clumps read as spiky tufts on moss, so none stay where the
		# garden is full; across the feather they drop out by a dithered pick.
		return not Biomes.pick(p, smoothstep(0.25, 0.7, weight_at.call(p)), 43)
	# Ferns and low bushes stay in the garden, except where one of this
	# builder's mounds or stones now stands on them.
	var is_under := func(label: String) -> bool:
		var l := label.to_lower()
		if l.contains("koke"): return false
		return l.contains("fern") or l.contains("forest_floor_bush") or l.contains("lilac") or l.contains("companion") or l.contains("understory") or l.contains("groundcover")
	var keep_under := func(p: Vector2) -> bool:
		if not _in_bounds(p): return true
		return not _covered(taken, p, 0.3)
	# The park's own clipped mounds (ClippedShrubs/Shrubs_<x>_<z>_<shell>, the
	# Bush006 swap) suit the garden and stay, except where a stroll stone,
	# mound or lantern of this builder now stands in one. They are up to 1.4 m
	# wide, so the pad covers their half width.
	var is_shrub := func(label: String) -> bool:
		return label.to_lower().begins_with("shrubs_")
	var keep_shrub := func(p: Vector2) -> bool:
		if not _in_bounds(p): return true
		return not _covered(taken, p, 0.7)
	if ResourceLoader.exists(THIN_ALL):
		# Also reaches the distance-detail copies, which a node-name filter misses.
		var helper := load(THIN_ALL) as Script
		if helper != null and helper.can_instantiate():
			# The optional area argument only speeds it up; pass it when offered.
			var takes_area := false
			for method: Dictionary in helper.get_script_method_list():
				if String(method.name) == "hide_low_planting": takes_area = (method.args as Array).size() >= 4
			var area := MAIN_RECT.merge(SAT_RECT)
			if takes_area:
				report["spiky"] = helper.hide_low_planting(park, is_spiky, keep_spiky, area)
				report["lawn"] = helper.hide_low_planting(park, is_lawn, keep_lawn, area)
				report["under"] = helper.hide_low_planting(park, is_under, keep_under, area)
				report["clipped"] = helper.hide_low_planting(park, is_shrub, keep_shrub, area)
			else:
				report["spiky"] = helper.hide_low_planting(park, is_spiky, keep_spiky)
				report["lawn"] = helper.hide_low_planting(park, is_lawn, keep_lawn)
				report["under"] = helper.hide_low_planting(park, is_under, keep_under)
				report["clipped"] = helper.hide_low_planting(park, is_shrub, keep_shrub)
			report["via"] = "thin_all"
			return report
	var grass := park.get_tree().root.get_node_or_null("MidoriGrassDetail")
	var label_of := func(node: MultiMeshInstance3D) -> String:
		return String(node.name) + " " + (node.multimesh.mesh.resource_name if node.multimesh.mesh else "")
	var spiky_nodes := func(node: MultiMeshInstance3D) -> bool: return is_spiky.call(label_of.call(node))
	var lawn_nodes := func(node: MultiMeshInstance3D) -> bool: return is_lawn.call(label_of.call(node))
	report["spiky"] = Kit.thin_multimeshes([park, grass], spiky_nodes, keep_spiky)
	report["lawn"] = Kit.thin_multimeshes([park, grass], lawn_nodes, keep_lawn)
	var under_nodes := func(node: MultiMeshInstance3D) -> bool: return is_under.call(label_of.call(node))
	report["under"] = Kit.thin_multimeshes([park], under_nodes, keep_under)
	var shrub_nodes := func(node: MultiMeshInstance3D) -> bool: return is_shrub.call(String(node.name))
	report["clipped"] = Kit.thin_multimeshes([park], shrub_nodes, keep_shrub)
	report["via"] = "kit"
	return report
