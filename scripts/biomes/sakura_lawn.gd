extends RefCounted
## Hanami-hiroba 花見広場, the sakura lawn in the south (docs/biome_concepts/
## after_sakura_lawn.png, extra/after_sakura_lawn_east.png and _west.png).
## A short, fine olive lawn under loose groves of mature someiyoshino in full
## pale bloom: short thick trunks branching low, broad umbrella crowns wider
## than tall, the bloom a dense soft pale-pink mass with the branches showing
## through. Petals lie in soft drifts ringing each trunk out to the drip line,
## thin between the trees. No understory: shrubs, beds, ferns and spiky grass
## give way, the lawn blades are mown short and every tree in the core of the
## lawn is a cherry. Paths, plaza and props stay.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ShaderPool := preload("res://scripts/shinrai_shader_pool.gd")
const ID := "hanami"
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
# Grove centres from docs/PARK_BIOME_PLAN.md; each takes 3-5 trees, loosely.
const GROVES: Array[Vector2] = [Vector2(-30, 128), Vector2(30, 140), Vector2(84, 128)]
# A 1 m weight grid over the lawn and its feather (world metres). The hanami
# ellipse c(20,138) r(96,40) with its 15 m feather and noise wobble reaches
# about x -90..130, z 84..192 (midori_biomes.gd REGIONS).
const GRID := Rect2i(-100, 82, 240, 114)
const AREA := Rect2(-100.0, 82.0, 240.0, 114.0)
# Lawn blade instances mown between frame yields.
const MOW_PER_FRAME := 24000
const MAX_PETALS := 90000
const TREE_SPACING := 12.0
# Hanami ellipse (midori_biomes.gd REGIONS) for the west-edge clean-up.
const ELLIPSE_C := Vector2(20, 138)
const ELLIPSE_R := Vector2(96, 40)
# Mature cherries stand apart with open lawn between: each kept tree claims a
# trunk spacing of 11-15 m (hashed per tree, so no rows), the park's ~7 m
# tree grid is thinned to that by a greedy pick in hash order; trees the
# concept cameras frame are picked first. The rest are retired (hidden, no
# collision). A standing non-cherry tree keeps a kept cherry this far off.
const SPACING_MIN := 11.0
const SPACING_MAX := 15.0
const STAY_GAP := 7.5
# Concept cameras (eye, target) from the biome build captures: a tree that
# stands in their frame at a good distance is picked before its neighbours.
const FRAMES: Array = [[Vector2(0, 165), Vector2(10, 120)], [Vector2(-70, 125), Vector2(30, 140)], [Vector2(100, 112), Vector2(20, 140)]]
# Where the concepts stand their trees, measured off the paintings through
# those cameras (trunk base pixel -> ground point): the park tree nearest
# each (within FRAME_SNAP) holds the spot, else a new cherry is planted there.
const FRAME_SPOTS: Array[Vector2] = [
	# Main view: the tree left of the shelter, the one behind it, and right.
	Vector2(-14.0, 134.5), Vector2(3.0, 139.0), Vector2(36.5, 137.0),
	# West view: near left, the big centre tree, the two right.
	Vector2(-61.3, 117.5), Vector2(-58.5, 128.8), Vector2(-51.6, 138.6), Vector2(-55.6, 148.0),
	# East view: the big one left of the path and the two behind.
	Vector2(85.4, 123.4), Vector2(82.1, 140.0), Vector2(64.8, 115.8)]
# How tall each spot's tree stands: the concepts' framed trees are the big
# ones (the east view's tree left of the path rises high into the frame).
const FRAME_HEIGHTS: Array[float] = [8.6, 8.8, 8.4, 8.6, 9.2, 8.4, 8.6, 9.4, 8.6, 8.6]
const FRAME_SNAP := 3.5
# A ray hit this far above height_at is a deck, paver or prop, not the turf
# (terrain collision can sit a few cm off the sampled height).
const SITE_LIFT := 0.08
const PAVED_LIFT := 0.06
# Petals drift a little downwind (east-south-east) of the crowns.
const WIND := Vector2(1.3, 0.5)
# The park breeze (midori_vegetation_breeze.gd sways the planting along it).
const BREEZE := Vector2(0.83205, 0.5547)
# Airborne petals: emission points per cherry, particles over the whole lawn
# (~300-800 of them round the camera), crowns that throw gust bursts.
const DRIFT_POINTS_PER_TREE := 64
const DRIFT_AMOUNT := 2400
const GUSTS := 8
# The veil round the camera: VEIL_AMOUNT petals in a box 2 x VEIL_HALF wide.
const VEIL_AMOUNT := 800
const VEIL_HALF := 9.0
## Keeps the veil on the camera, a few times a second: moves its box there and
## fades it with the hanami weight under the camera (none off the lawn).
const VEIL_FOLLOW := """
extends Node
const Biomes := preload("res://scripts/midori_biomes.gd")
var veil: GPUParticles3D
var terrain: Node
var upwind := Vector3.ZERO
var wait := 0.0
var last := Vector3(INF, INF, INF)

func _process(delta: float) -> void:
	wait -= delta
	if wait > 0.0: return
	wait = 0.25
	if not is_instance_valid(veil): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var at := camera.global_position
	var w := Biomes.weight(Vector2(at.x, at.z), "hanami", terrain) if is_instance_valid(terrain) else 0.0
	var ratio := smoothstep(0.15, 0.45, w)
	veil.amount_ratio = ratio
	veil.global_position = Vector3(at.x, at.y + 1.2, at.z) + upwind
	# Arriving (spawn, teleport, a jump of the view): fill the veil at once
	# (restart re-runs the preprocess) instead of letting it trickle in.
	if ratio > 0.01 and at.distance_to(last) > 15.0: veil.restart()
	veil.emitting = ratio > 0.01
	last = at
"""
# Single planted nodes (not batched) that read as understory in the lawn.
const PLANT_PREFIXES: Array[String] = ["ReferenceLilacMass_", "MixedTreeGapBush_", "ForestFloorBush_", "MidnightFern_", "EmeraldFountainGrass_", "MainlandDenseGrass_", "VEG06_MainlandTransition_", "AzaleaShrubBase_"]
# Park trees that turn into cherries in the lawn (node name prefixes).
const TREE_PATTERNS: Array[String] = ["ReferenceBroadleaf_*", "MicroGrove*", "SparseGapTree_*", "ReferencePine_*", "MainlandPineSapling_*", "IslandTree_*", "Free3DJapaneseMaple_*"]

# Mature someiyoshino: 6.5-8.5 m tall (the framed ones to 9.4 m), procedural
# (sakura_tree_generator.gd): a short flaring trunk forking low into 3-5
# arching leaders, limbs, branches and zig-zag twigs, flower clusters on the
# twigs; a broad flat-topped umbrella ~1.5x as wide as tall. VARIANTS trees are
# built once and reused, each scaled and turned per tree.
const Generator := preload("res://scripts/biomes/sakura_tree_generator.gd")
const VARIANTS := 5
const TREE_SEED := 8121
const HEIGHT_MIN := 6.5
const HEIGHT_MAX := 8.5
# With the lawn thinned to 11-15 m the crowns only touch: a cherry is at most
# CROWD_K x its nearest neighbour's distance tall, never below HEIGHT_MIN.
const CROWD_K := 0.66
const CROWN_XZ := 1.0
# Levels of detail: the near mesh to NEAR_END, the mid one to MID_END, the far
# one to RANGE.
const NEAR_END := 16.0
const MID_END := 70.0
const RANGE := 190.0
## Somei-yoshino bark: the source bark texture warmed to a red/grey-brown,

## Blossom: pale pink from the texture's brightness only (the source sprigs'
## red flower centres and brown stems become a slightly deeper pink), a soft
## round crown normal so the mass shades as one cloud, wrap lighting and a
## transmitted glow on the far side. Lighting is the shader's own: the sun's
## colour is half desaturated (a low orange sun had turned the bloom salmon),
## the blue sky ambient is off (it turned the shaded side lavender) and a fill
## that follows the sun stands in for it, so the shade side is a deeper pink.
## The crown does not receive shadows (its own self-shadow went grey-violet);
## its cards cast them.
const BLOSSOM_SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled, ambient_light_disabled;
uniform sampler2D blossom : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 lit_tint : source_color = vec4(0.97, 0.87, 0.87, 1.0);
uniform vec4 shade_tint : source_color = vec4(0.88, 0.7, 0.72, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.86, 0.82, 1.0);
uniform float light_saturation = 0.3;
uniform float wrap = 0.38;
uniform float fill = 0.3;
uniform float glow_strength = 0.55;
// Share of the crown that lets the sun through in the shadow map (cards only).
uniform float shadow_gaps = 0.5;
uniform bool from_instance = false;
uniform vec3 crown_centre = vec3(0.0);
uniform vec3 crown_radii = vec3(1.0);
uniform vec3 crown_up = vec3(0.0, 1.0, 0.0);
uniform float round_normals = 0.55;
uniform float alpha_cut = 0.42;
uniform float alpha_boost = 0.22;
// Share of the texture's own colour kept over the pale tint (the cards are
// drawn in the right colours already).
uniform float keep_texture = 0.0;
varying float shade;
// Height within a puff (0 bottom .. 1 top): each clump has a lit crown and a
// deeper underside, so the bloom reads as lumps, not one flat pink sheet.
varying float clump;

void vertex() {
	clump = 0.8;
	if (from_instance) {
		// Puffs: the outward crown direction (world) rides in the instance colour.
		vec3 dir = normalize(COLOR.rgb * 2.0 - 1.0);
		NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * dir);
		shade = COLOR.a;
		clump = clamp((mat3(MODEL_MATRIX) * VERTEX).y / max(length(MODEL_MATRIX[1].xyz), 0.001) + 0.5, 0.0, 1.0);
	} else {
		vec3 e = (VERTEX - crown_centre) / crown_radii;
		vec3 dir = normalize(normalize(e + crown_up * 0.001) + crown_up * 0.35);
		NORMAL = normalize(mix(NORMAL, dir, round_normals));
		shade = clamp(0.3 + 0.62 * length(e) + 0.15 * dot(e, crown_up), 0.0, 1.0);
	}
}

float gap_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gap_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(gap_hash(i), gap_hash(i + vec2(1.0, 0.0)), u.x), mix(gap_hash(i + vec2(0.0, 1.0)), gap_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// The sun's shadow map is an orthographic pass: there the crown casts with
	// soft holes, so the lawn under it is dappled, not one solid shade.
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (!from_instance && PROJECTION_MATRIX[3][3] > 0.5) {
		if (gap_noise(wp.xz * 0.8 + vec2(wp.y * 0.35, 0.0)) < shadow_gaps) discard;
	}
	// Two-sided cards keep the crown's outward normal on both faces.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec4 tex = texture(blossom, UV);
	// Keep the coverage of far mips (scissored alpha thins out with distance).
	vec2 px = UV * vec2(textureSize(blossom, 0));
	float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
	ALPHA = tex.a * (1.0 + lod * alpha_boost);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	float lum = dot(tex.rgb, vec3(0.3, 0.59, 0.11));
	// The flowers keep their own drawing (petal edges, the deeper centres and
	// stems), softened toward pale pink.
	vec3 pale = mix(shade_tint.rgb * 0.9, lit_tint.rgb, smoothstep(0.25, 0.8, lum));
	// Near-white petals, the source drawing's deeper pink eyes kept.
	vec3 c = mix(tex.rgb, pale, 0.5);
	c = mix(c, tex.rgb, keep_texture);
	// Soft tonal clumping over the crown (~1.2 m lumps), and each puff's own
	// lit top and deeper underside.
	float lumps = gap_noise(wp.xz * 0.85 + vec2(wp.y * 0.7, wp.y * 0.45) + vec2(17.0, 3.0));
	ALBEDO = c * mix(0.74, 1.0, shade) * mix(0.84, 1.05, lumps) * mix(0.8, 1.04, clump);
	ROUGHNESS = 0.82;
}

void light() {
	float grey = dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114));
	vec3 lc = mix(vec3(grey), LIGHT_COLOR, light_saturation) * ATTENUATION / PI;
	float lit = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	// Light through the petals when the sun stands behind the crown.
	float through = pow(clamp(dot(LIGHT, -VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += lc * (lit + fill + glow_strength * through * glow.rgb);
}
"""

## Fallen petals light themselves like the bloom: no blue sky ambient (in the
## crown shade it turned them pale lilac-blue), a warm fill that follows the
## sun's brightness instead, so a petal in shade stays a deeper pink-beige.
const PETAL_SHADER := """
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;
uniform vec3 fill_tint = vec3(0.95, 0.76, 0.66);
uniform float fill = 0.3;
uniform float light_saturation = 0.45;
void fragment() {
	// Petals are seen from above; light the far side as the near one.
	if (!FRONT_FACING) NORMAL = -NORMAL;
	// A faint darker heel where the petal joined the flower, no lines.
	float heel = smoothstep(0.35, 0.0, UV.x) * 0.1;
	ALBEDO = COLOR.rgb * (1.0 - heel);
	ROUGHNESS = 0.8;
}

void light() {
	float grey = dot(LIGHT_COLOR, vec3(0.299, 0.587, 0.114));
	vec3 lc = mix(vec3(grey), LIGHT_COLOR, light_saturation) / PI;
	// Thin petals: a little light wraps through to a petal tilted away.
	float lit = clamp((dot(NORMAL, LIGHT) + 0.25) / 1.25, 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += lc * lit;
	// The fill stands in for the sky, so only the sun (or moon) carries it.
	if (LIGHT_IS_DIRECTIONAL) DIFFUSE_LIGHT += grey / PI * fill * fill_tint;
}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeSakuraLawn"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501106
	# The cherry variants grow on worker threads while the main thread takes the
	# inventory and lays the weight grid (they share nothing).
	var growing := _early if not _early.is_empty() else _grow_variants()
	_early = {}
	var inventory_before := Kit.inventory(park, AREA)
	var grid: PackedFloat32Array = await _weight_grid(park, terrain)
	if not _alive(park):
		WorkerThreadPool.wait_for_group_task_completion(int(growing.task))
		return {"error": "park freed"}
	var kit: Dictionary = await _cherry_kit(park, growing)
	if kit.is_empty(): return {"error": "sakura source missing"}
	var cherries: Array = []
	var thinned: Dictionary = _thin_understory(park, grid)
	var mowed: Dictionary = await _mow_lawn(park, grid)
	if not _alive(park): return {"error": "park freed"}
	# The lawn's own trees turn into mature cherries, spaced out (the crowded
	# ones retire); new cherries then fill the concept spots left open and the
	# groves. The park's own sakura in the lawn take the same shape and bloom.
	var swapped: Dictionary = await _swap_to_cherries(park, terrain, grid, kit, cherries)
	if not _alive(park): return {"error": "park freed"}
	var planted: Dictionary = await _plant_cherries(park, terrain, root, rng, grid, kit, cherries, swapped.get("open_spots", []))
	if not _alive(park): return {"error": "park freed"}
	var existing := _restyle_park_sakura(park, grid, kit, cherries)
	var drifts := _petal_drifts(root, terrain, rng, cherries)
	var airborne := _wind_petals(root, terrain, grid, cherries)
	var petals: int = await _petal_floor(park, terrain, root, rng, grid, cherries)
	if not _alive(park): return {"error": "park freed"}
	return {"cherries_planted": planted.count, "swapped_to_cherry": swapped.count, "swapped_height_min_median_max": swapped.get("height_m", []), "retired_crowded": swapped.get("retired", 0), "retired_collision_bodies": swapped.get("retired_collision_bodies", 0), "retired_trunk_records": swapped.get("retired_trunk_records", 0), "kept_swapped_xz_h": swapped.get("kept_xz_h", []), "planted_xz_h": planted.get("spots", []), "frame_spots_planted": planted.get("frame_spots", 0), "frame_spots_held_by_park_tree": swapped.get("frame_held", 0), "bloom": kit.get("bloom", {}), "trees_left_in_core": swapped.left, "existing_sakura_in_lawn": existing, "cherries_total": cherries.size(), "cherry_height_m": [HEIGHT_MIN, HEIGHT_MAX], "petal_drift_decals": drifts, "wind_petals": airborne, "petals": petals, "thinned": thinned, "mowed": mowed, "inventory": inventory_before}

## Hanami weight on a 1 m grid, computed once: thinning, mowing and petals
## all read it (the shoreline distance inside weights_at is not cheap).
static func _weight_grid(park: Node3D, terrain: Node) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(GRID.size.x * GRID.size.y)
	var since := Kit.frames_now()
	# Pure maths per row, on WorkerThreadPool; same floats in the same cells.
	Biomes.noise()
	# Each row reads its own copy of the weight kernel (Biomes.Kernel: the same
	# floats as Biomes.weight, nothing shared between the threads).
	var kernel := Biomes.terrain_kernel(terrain)
	var id_index := Biomes.region_index(ID)
	var job := func(z: int) -> PackedFloat32Array:
		var k := kernel.clone()
		var row := PackedFloat32Array()
		row.resize(GRID.size.x)
		for x: int in range(GRID.size.x):
			row[x] = k.weight(Vector2(GRID.position.x + x + 0.5, GRID.position.y + z + 0.5), id_index)
		return row
	var rows := Kit.parallel(GRID.size.y, job, "sakura_lawn weights")
	for z: int in range(GRID.size.y):
		var row: PackedFloat32Array = rows[z]
		for x: int in range(GRID.size.x): grid[z * GRID.size.x + x] = row[x]
	await Kit.settle(park, since)
	return grid

## The park can be freed (raid ends, scene change) while a builder yields.
## Untyped on purpose: a freed instance passed to a typed parameter errors.
static func _alive(park: Variant) -> bool:
	if not is_instance_valid(park): return false
	return (park as Node).is_inside_tree()

static func _w(grid: PackedFloat32Array, p: Vector2) -> float:
	var x := floori(p.x) - GRID.position.x
	var z := floori(p.y) - GRID.position.y
	if x < 0 or z < 0 or x >= GRID.size.x or z >= GRID.size.y: return 0.0
	return grid[z * GRID.size.x + x]

static func _hash01(p: Vector2, salt: int) -> float:
	return float(absi(hash(Vector3i(floori(p.x * 3.0), floori(p.y * 3.0), salt))) % 10007) / 10007.0

## True when only the bare ground lies under the point and a ring round it: no
## prop, deck, shelter, paved plaza apron or roof within `radius`.
static func _site_clear(park: Node3D, terrain: Node, p: Vector2, radius: float) -> bool:
	var centre := _surface_lift(park, terrain, p)
	if centre < 0.0 or centre > SITE_LIFT: return false
	for k: int in range(8):
		var a := TAU * float(k) / 8.0 + 0.3
		for r: float in [radius * 0.5, radius]:
			var lift := _surface_lift(park, terrain, p + Vector2(cos(a), sin(a)) * r)
			if lift < 0.0 or lift > SITE_LIFT: return false
	return true

## Surface lift above the terrain at p (a paved plaza or deck), or -1 when
## something tall stands there.
static func _surface_lift(park: Node3D, terrain: Node, p: Vector2) -> float:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return 0.0
	var lift: float = hit.position.y - ground
	if lift > 0.35: return -1.0
	return maxf(0.0, lift)

# --- the cherry kit ----------------------------------------------------------

static func _is_blossom(material: Material) -> bool:
	if not material is BaseMaterial3D: return false
	var base := material as BaseMaterial3D
	var label := base.resource_name.to_lower()
	var path := base.albedo_texture.resource_path.to_lower() if base.albedo_texture != null else ""
	if label.contains("bark") or path.contains("bark"): return false
	return base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or path.contains("sakura")

## The cherry kit: VARIANTS procedural somei-yoshino (sakura_tree_generator.gd),
## built once, each with its near / mid / far meshes (surface 0 bark, 1 bloom)
## under one shared bark material and one shared blossom material. A frame
## goes by between variants. Returns the variants, the tree-space box (foot at
## the origin, its height the variants' mean, so a tree scaled to `height`
## stands that tall), the crown frame and the trunk radius.
## Starts Generator.grow (pure data) for every variant on WorkerThreadPool.
## Each task writes only its own slot. _cherry_kit() waits for them.
## The last slot draws the blossom atlas image (Generator.cluster_image).
static var _early: Dictionary = {}

## midori_biomes.prefetch(): starts the variants growing when the world-complete
## step begins, so they are ready by the time this builder runs (same seeds,
## same arrays; build() takes them over, or grows them itself if not started).
static func start_early() -> void:
	if _early.is_empty(): _early = _grow_variants()

static func _grow_variants() -> Dictionary:
	var slots: Array = []
	for v: int in range(VARIANTS + 1): slots.append({})
	var grow_one := func(v: int) -> void:
		if v == VARIANTS: (slots[v] as Dictionary)["image"] = Generator.cluster_image()
		else: (slots[v] as Dictionary)["grown"] = Generator.grow(TREE_SEED + v * 7919)
	var task := WorkerThreadPool.add_group_task(grow_one, VARIANTS + 1, -1, true, "sakura_lawn cherry variants")
	return {"task": task, "slots": slots}

static func _cherry_kit(park: Node3D, growing: Dictionary) -> Dictionary:
	var since := Kit.frames_now()
	var bark := Generator.bark_material()
	var variants: Array = []
	var stats: Array = []
	var box := AABB()
	var height := 0.0
	var started := Time.get_ticks_msec()
	var task := int(growing.task)
	while not WorkerThreadPool.is_group_task_completed(task):
		await park.get_tree().process_frame
		if not _alive(park): break
	WorkerThreadPool.wait_for_group_task_completion(task)
	if not _alive(park): return {}
	var slots: Array = growing.slots
	var atlas: Variant = (slots[VARIANTS] as Dictionary).get("image")
	var bloom := _blossom_material(ImageTexture.create_from_image(atlas) if atlas is Image else Generator.cluster_texture(), false)
	bloom.set_shader_parameter("crown_centre", Vector3(0.0, Generator.H * 0.66, 0.0))
	bloom.set_shader_parameter("crown_radii", Vector3(Generator.R, Generator.H * 0.3, Generator.R))
	bloom.set_shader_parameter("alpha_cut", 0.45)
	bloom.set_shader_parameter("keep_texture", 0.7)
	bloom.set_shader_parameter("shadow_gaps", 0.0)
	for v: int in range(VARIANTS):
		# A variant whose task failed on its thread grows here instead.
		if not (slots[v] as Dictionary).has("grown"): slots[v]["grown"] = Generator.grow(TREE_SEED + v * 7919)
		var tree := Generator.finish(slots[v].grown)
		for key: String in ["near", "mid", "far"]:
			var mesh: ArrayMesh = tree[key]
			mesh.surface_set_material(0, bark)
			mesh.surface_set_material(1, bloom)
		variants.append(tree)
		stats.append(tree.stats)
		var b: AABB = tree.box
		box = b if v == 0 else box.merge(b)
		height += b.end.y
	# The frame boundary and physics steps the per-variant yields always gave.
	await Kit.settle(park, since)
	if not _alive(park): return {}
	height /= float(VARIANTS)
	box = AABB(Vector3(box.position.x, 0.0, box.position.z), Vector3(box.size.x, height, box.size.z))
	var radii := Vector3(Generator.R, Generator.H * 0.3, Generator.R)
	return {"variants": variants, "box": box, "centre": Vector3(0.0, height * 0.66, 0.0), "radii": radii, "trunk_r": float(variants[0].trunk_r), "bloom": {"variants": stats, "build_ms": Time.get_ticks_msec() - started}}

## One cherry under `parent` at `t` (tree space -> world), a variant picked by
## position: the near mesh (every twig and cluster) to NEAR_END, the mid mesh
## to MID_END, the far mesh to RANGE, the far mesh casting the shadow at every
## range; all four share one box, so they switch at the same distance.
static func _spawn_cherry(parent: Node3D, t: Transform3D, kit: Dictionary) -> Node3D:
	var tree := Node3D.new()
	tree.name = "BiomeSakuraContent"
	parent.add_child(tree)
	tree.global_transform = t
	var variants: Array = kit.variants
	var pick: Dictionary = variants[int(_hash01(Vector2(t.origin.x, t.origin.z), 53) * variants.size()) % variants.size()]
	var box: AABB = (pick.near as ArrayMesh).get_aabb()
	# The shadow is the far mesh's all the way (the near and mid cards are
	# many small alpha-scissor quads, costly in every shadow cascade).
	var levels: Array = [["Near", pick.near, 0.0, NEAR_END, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF], ["Mid", pick.mid, NEAR_END, MID_END, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF], ["Shadow", pick.far, 0.0, MID_END, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY], ["Far", pick.far, MID_END, RANGE, GeometryInstance3D.SHADOW_CASTING_SETTING_ON]]
	for level: Array in levels:
		var mesh := MeshInstance3D.new()
		mesh.name = level[0]
		mesh.mesh = level[1]
		mesh.custom_aabb = box
		mesh.visibility_range_begin = level[2]
		mesh.visibility_range_end = level[3]
		mesh.cast_shadow = level[4]
		tree.add_child(mesh)
	return tree

static func _find(parent: PackedInt32Array, i: int) -> int:
	var r := i
	while parent[r] != r: r = parent[r]
	# Path halving keeps the next lookups short.
	var at := i
	while parent[at] != r:
		var next := parent[at]
		parent[at] = r
		at = next
	return r

static func _blossom_material(texture: Texture2D, from_instance: bool) -> ShaderMaterial:
	var material := ShaderPool.material(BLOSSOM_SHADER)
	material.set_shader_parameter("blossom", texture)
	material.set_shader_parameter("from_instance", from_instance)
	return material

## Tree-local -> world basis for a cherry `height` tall: uniform scale plus
## the gentle CROWN_XZ spread of the whole tree, at `yaw` with a slight lean.
static func _cherry_basis(kit: Dictionary, height: float, yaw: float, lean: Vector2) -> Basis:
	var box: AABB = kit.box
	var s := height / maxf(box.size.y, 0.001)
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean.x) * Basis(Vector3.FORWARD, lean.y) * Basis.from_scale(Vector3(s * CROWN_XZ, s, s * CROWN_XZ))

static func _record(cherries: Array, kit: Dictionary, t: Transform3D) -> void:
	var radii: Vector3 = kit.radii
	var sx := t.basis.x.length()
	var sz := t.basis.z.length()
	cherries.append({"t": t, "p": Vector2(t.origin.x, t.origin.z), "r": maxf(radii.x * sx, radii.z * sz), "y": t.origin.y, "h": t.basis.y.length() * (kit.box as AABB).size.y})

# --- planting ----------------------------------------------------------------

static func _plant_cherries(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, grid: PackedFloat32Array, kit: Dictionary, cherries: Array, spots: Array) -> Dictionary:
	var out := {"count": 0, "frame_spots": 0}
	var placed: Array = []
	# The cherries standing already (the swapped park trees) keep their room.
	var standing: Array = []
	for c: Dictionary in cherries: standing.append({"p": c.p})
	# The concept spots left open first: on the spot, or a step off it.
	for spot: Vector3 in spots:
		for attempt: int in range(10):
			var p := Vector2(spot.x, spot.y)
			if attempt > 0: p += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.8, 2.5)
			if _w(grid, p) < 0.3: continue
			var crowded := false
			for other: Dictionary in standing + placed:
				if other.p.distance_to(p) < 8.5: crowded = true
			if crowded: continue
			if not Kit.open_ground(park, terrain, p, 2.5, 5.0): continue
			if park.has_method("_is_vegetation_clear") and not park._is_vegetation_clear(Vector3(p.x / 2.0, 0.0, p.y / 2.0), 1.2): continue
			if not _site_clear(park, terrain, p, 3.0): continue
			placed.append({"p": p, "h": spot.z, "yaw": rng.randf() * TAU, "lean": Vector2(rng.randf_range(-0.035, 0.035), rng.randf_range(-0.035, 0.035))})
			out.frame_spots += 1
			break
	await park.get_tree().process_frame
	if not _alive(park): return out
	for g: Vector2 in GROVES:
		var want := rng.randi_range(2, 3)
		for attempt: int in range(90):
			if want <= 0: break
			# Loose, uneven clusters: the search widens as spots fill up.
			var spread := 5.0 + float(attempt) * 0.16
			var p := g + Vector2(rng.randfn(0.0, 1.0) * spread, rng.randfn(0.0, 1.0) * spread * 0.7)
			if _w(grid, p) < 0.45: continue
			var crowded := false
			for other: Dictionary in standing + placed:
				if other.p.distance_to(p) < TREE_SPACING * rng.randf_range(0.95, 1.25): crowded = true
			if crowded: continue
			if not Kit.open_ground(park, terrain, p, 3.0, 7.0): continue
			if park.has_method("_is_vegetation_clear") and not park._is_vegetation_clear(Vector3(p.x / 2.0, 0.0, p.y / 2.0), 1.8): continue
			if not _site_clear(park, terrain, p, 4.0): continue
			placed.append({"p": p, "h": rng.randf_range(HEIGHT_MIN, HEIGHT_MAX), "yaw": rng.randf() * TAU, "lean": Vector2(rng.randf_range(-0.035, 0.035), rng.randf_range(-0.035, 0.035))})
			want -= 1
		await park.get_tree().process_frame
		if not _alive(park): return out
	var rows: Array = []
	for i: int in range(placed.size()):
		var m: Dictionary = placed[i]
		var ground: float = terrain.height_at(m.p)
		var tree := Transform3D(_cherry_basis(kit, m.h, m.yaw, m.lean), Vector3(m.p.x, ground - 0.06, m.p.y))
		rows.append(tree)
		_record(cherries, kit, tree)
		# Trunk collision as thick as the trunk (~0.034 source units across).
		var thick := tree.basis.y.length() * float(kit.trunk_r) * 2.0
		var body := StaticBody3D.new()
		body.name = "SakuraLawnTrunk_%02d" % i
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.5 * thick
		cylinder.height = 2.6
		shape.shape = cylinder
		body.add_child(shape)
		root.add_child(body)
		body.global_position = Vector3(m.p.x, ground + 1.3, m.p.y)
		park.occupied_tree_positions.append(m.p / 2.0)
		park.occupied_tree_is_skinny.append(false)
		_falling_petals(root, m.p, ground, m.h, i)
	if park.has_method("invalidate_trunk_index"): park.invalidate_trunk_index()
	for tree: Transform3D in rows: _spawn_cherry(root, tree, kit)
	out.count = placed.size()
	out["spots"] = placed.map(func(m: Dictionary) -> Array: return [snappedf(m.p.x, 0.1), snappedf(m.p.y, 0.1), snappedf(m.h, 0.1)])
	return out

## Broadleaf, pine and maple trees standing in the hanami lawn become mature
## cherries: the old visual is hidden (trunk, collision and spacing stay), a
## blooming sakura takes its place. Every tree in the core of the lawn turns;
## toward the edge the swap is dithered by position so the edge mixes.
static func _swap_to_cherries(park: Node3D, terrain: Node, grid: PackedFloat32Array, kit: Dictionary, cherries: Array) -> Dictionary:
	var out := {"count": 0, "left": {}, "retired": 0, "retired_collision_bodies": 0, "retired_trunk_records": 0}
	var trees: Array[Node] = []
	var seen: Dictionary = {}
	for pattern: String in TREE_PATTERNS:
		for found: Node in park.find_children(pattern, "Node3D", true, false):
			if seen.has(found.get_instance_id()): continue
			seen[found.get_instance_id()] = true
			trees.append(found)
	# Which trees turn cherry (as before: the whole core, dithered at the edge);
	# every other standing tree near the lawn stays as it is.
	var candidates: Array = []
	var stay := PackedVector2Array()
	var step := 0
	for node: Node in trees:
		step += 1
		# Only reads the trees (the swap itself comes after the frame below):
		# yield on time, not every 48 trees.
		if step % 48 == 0:
			await Kit.slice(park)
			if not _alive(park): return out
		var tree := node as Node3D
		if tree == null or not is_instance_valid(tree) or not tree.is_visible_in_tree(): continue
		if tree.has_meta("biome_cherry"): continue
		var gp := Vector2(tree.global_position.x, tree.global_position.z)
		if not AREA.grow(12.0).has_point(gp): continue
		var w := _w(grid, gp)
		var content := tree.get_node_or_null("Content") as Node3D
		var core := w > 0.5
		var swap := AREA.has_point(gp) and w >= 0.3 and content != null and content.visible
		if swap and tree.has_meta("biome_pine") and not core: swap = false
		if swap and not core and not Biomes.pick(gp, smoothstep(0.3, 0.5, w), 61): swap = false
		if not swap:
			if core and AREA.has_point(gp) and content == null:
				var family := String(tree.name).rstrip("0123456789_")
				out.left[family] = int(out.left.get(family, 0)) + 1
			stay.append(gp)
			continue
		candidates.append({"tree": tree, "content": content, "p": gp, "s": lerpf(SPACING_MIN, SPACING_MAX, _hash01(gp, 23)), "rank": _hash01(gp, 29) - 0.7 * _framing(gp)})
	# Greedy spaced pick: the planted cherries first, then in rank order.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.rank) < float(b.rank))
	# The concept spots: the nearest candidate holds each; an open spot is
	# reserved for a new cherry (planted after this pass).
	var held: Dictionary = {}
	var open_spots: Array = []
	for n: int in range(FRAME_SPOTS.size()):
		var spot: Vector2 = FRAME_SPOTS[n]
		var best := -1
		var best_d := FRAME_SNAP
		for i: int in range(candidates.size()):
			var d := spot.distance_to(candidates[i].p)
			if d < best_d and not held.has(i):
				best = i
				best_d = d
		if best >= 0: held[best] = FRAME_HEIGHTS[n]
		else: open_spots.append(Vector3(spot.x, spot.y, FRAME_HEIGHTS[n]))
	out["open_spots"] = open_spots
	out["frame_held"] = held.size()
	var kept: Array = []
	for c: Dictionary in cherries: kept.append({"p": c.p, "s": TREE_SPACING})
	for spot: Vector3 in open_spots: kept.append({"p": Vector2(spot.x, spot.y), "s": TREE_SPACING})
	for i: int in held: kept.append(candidates[i])
	var keep: Array = []
	var retire: Array = []
	for i: int in range(candidates.size()):
		var c: Dictionary = candidates[i]
		if held.has(i):
			c["frame"] = held[i]
			keep.append(c)
			continue
		var ok := true
		for k: Dictionary in kept:
			if (c.p as Vector2).distance_to(k.p) < 0.5 * (float(c.s) + float(k.s)):
				ok = false
				break
		if ok:
			for o: Vector2 in stay:
				if o.distance_to(c.p) < STAY_GAP:
					ok = false
					break
		if ok:
			kept.append(c)
			keep.append(c)
		else:
			retire.append(c)
	await park.get_tree().process_frame
	if not _alive(park): return out
	var retired := _retire_trees(park, retire)
	out.retired = retire.size()
	out.retired_collision_bodies = retired.bodies
	out.retired_trunk_records = retired.records
	# Every kept cherry, planted or swapped, and every tree left standing is a
	# neighbour for the crown size.
	var others := PackedVector2Array(stay)
	for k: Dictionary in kept: others.append(k.p)
	var heights: Array[float] = []
	var spots: Array = []
	for c: Dictionary in keep:
		var tree: Node3D = c.tree
		var content: Node3D = c.content
		if not is_instance_valid(tree) or not is_instance_valid(content): continue
		var gp: Vector2 = c.p
		content.visible = false
		content.set_meta("biome_replaced_by_cherry", true)
		var height := _crowd_height(gp, others)
		# A tree the concept frames is one of the big ones.
		if c.has("frame"): height = float(c.frame)
		heights.append(height)
		var yaw := _hash01(gp, 11) * TAU
		var base := Vector3(gp.x, tree.global_position.y, gp.y)
		var cherry := _spawn_cherry(tree, Transform3D(_cherry_basis(kit, height, yaw, Vector2.ZERO), base), kit)
		tree.set_meta("biome_cherry", true)
		_record(cherries, kit, cherry.global_transform)
		spots.append([snappedf(gp.x, 0.1), snappedf(gp.y, 0.1), snappedf(height, 0.1)])
		out.count += 1
	if not heights.is_empty():
		heights.sort()
		out["height_m"] = [snappedf(heights[0], 0.1), snappedf(heights[heights.size() / 2], 0.1), snappedf(heights[-1], 0.1)]
	out["kept_xz_h"] = spots
	return out

## How well the concept cameras frame a tree at p: 1 inside one of their
## views at 12-55 m, fading out toward the frame edge.
static func _framing(p: Vector2) -> float:
	var best := 0.0
	for view: Array in FRAMES:
		var eye: Vector2 = view[0]
		var look: Vector2 = ((view[1] as Vector2) - eye).normalized()
		var to := p - eye
		var d := to.length()
		if d < 12.0 or d > 55.0: continue
		var off := absf(look.angle_to(to))
		best = maxf(best, 1.0 - smoothstep(0.35, 0.6, off))
	return best

## Retired trees vanish whole: the node hidden (old visual, Content and any
## cherry under it), every collision body in it or standing on its trunk
## switched off, and its trunk record taken out of the park's tree list (the
## parallel skinny flags with it) so spacing and cover checks forget it.
static func _retire_trees(park: Node3D, retire: Array) -> Dictionary:
	var out := {"bodies": 0, "records": 0}
	if retire.is_empty(): return out
	var spots := PackedVector2Array()
	for c: Dictionary in retire:
		var tree: Node3D = c.tree
		if not is_instance_valid(tree): continue
		tree.visible = false
		tree.set_meta("biome_retired_hanami", true)
		spots.append(c.p)
		for body: Node in tree.find_children("*", "CollisionObject3D", true, false):
			_disable_body(body as CollisionObject3D)
			out.bodies += 1
	# Trunk bodies kept beside the tree (named for collision or trunk), within
	# half a metre of a retired trunk.
	for body: Node in park.find_children("*", "CollisionObject3D", true, false):
		var co := body as CollisionObject3D
		if co == null or co.collision_layer == 0 and co.collision_mask == 0: continue
		var label := String(co.name).to_lower()
		if not (label.contains("collision") or label.contains("trunk")): continue
		if String(co.get_path()).contains("BiomeSakuraLawn"): continue
		var at := Vector2(co.global_position.x, co.global_position.z)
		if not AREA.grow(1.0).has_point(at): continue
		for s: Vector2 in spots:
			if s.distance_to(at) < 0.5:
				_disable_body(co)
				out.bodies += 1
				break
	var positions: Array = park.occupied_tree_positions
	var skinny: Array = park.occupied_tree_is_skinny
	for s: Vector2 in spots:
		for i: int in range(positions.size() - 1, -1, -1):
			if ((positions[i] as Vector2) * 2.0).distance_to(s) < 0.6:
				positions.remove_at(i)
				if i < skinny.size(): skinny.remove_at(i)
				out.records += 1
				break
	if park.has_method("invalidate_trunk_index"): park.invalidate_trunk_index()
	return out

static func _disable_body(body: CollisionObject3D) -> void:
	if body == null: return
	body.collision_layer = 0
	body.collision_mask = 0
	for shape: Node in body.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", true)

## Height of a cherry among `others` (world x, z): its free height, or less
## when a neighbour stands close (crown spread ~1.35x the height), never
## below HEIGHT_MIN.
static func _crowd_height(p: Vector2, others: PackedVector2Array) -> float:
	var nearest := 99.0
	for o: Vector2 in others:
		var d := o.distance_to(p)
		if d > 0.5: nearest = minf(nearest, d)
	var free := lerpf(HEIGHT_MIN, HEIGHT_MAX, _hash01(p, 7))
	return clampf(nearest * CROWD_K, HEIGHT_MIN, free)

## The park's own sakura (DenseSakura_*) standing in the lawn become hanami
## cherries too: their own visual and branch-tip sticker cards hidden, a kit
## cherry in their place (trunk collision stays).
static func _restyle_park_sakura(park: Node3D, grid: PackedFloat32Array, kit: Dictionary, cherries: Array) -> int:
	var count := 0
	for found: Node in park.find_children("DenseSakura_*", "Node3D", true, false):
		var tree := found as Node3D
		if tree == null or not tree.is_visible_in_tree() or tree.has_meta("biome_cherry"): continue
		var gp := Vector2(tree.global_position.x, tree.global_position.z)
		# Down to the outer feather: a lone park sakura at the lawn's rim in
		# its old lilac bloom stood out against the hanami crowns.
		if not AREA.has_point(gp) or _w(grid, gp) < 0.06: continue
		var height := lerpf(HEIGHT_MIN, HEIGHT_MAX, _hash01(gp, 7))
		var yaw := tree.global_rotation.y
		for child: Node in tree.get_children():
			if child is Node3D: (child as Node3D).visible = false
		var cherry := _spawn_cherry(tree, Transform3D(_cherry_basis(kit, height, yaw, Vector2.ZERO), tree.global_position), kit)
		tree.set_meta("biome_cherry", true)
		_record(cherries, kit, cherry.global_transform)
		count += 1
	return count

# --- falling petals ---------------------------------------------------------

## Petals adrift on the breeze over the lawn (the park breeze blows along
## BREEZE, midori_vegetation_breeze.gd). One GPU emitter covers the lawn: its
## emission points sit in and under every crown and in a plume downwind of it,
## a thin scatter over the rest of the lawn, so the drift is densest round the
## trees and thins out past the lawn edge. Petals ride the wind in loose
## streams: turbulence swirls them, some lift, they tumble (a tilted petal
## spinning about Y) and fade in and out; never a straight snow-like fall. A
## few gust emitters on crowns throw a short burst every 7-14 s. No shadows,
## no collision, no script.
static func _wind_petals(root: Node3D, terrain: Node, grid: PackedFloat32Array, cherries: Array) -> Dictionary:
	if cherries.is_empty(): return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 61207
	var wind := Vector3(BREEZE.x, 0.0, BREEZE.y)
	var points := PackedVector3Array()
	for c: Dictionary in cherries:
		var p: Vector2 = c.p
		var r: float = c.r
		var ground: float = terrain.height_at(p)
		for k: int in range(DRIFT_POINTS_PER_TREE):
			var at: Vector2
			var h: float
			if k % 3 == 0:
				# The plume downwind of the crown, sinking as it goes.
				var along := rng.randf_range(0.0, 12.0)
				at = p + BREEZE * along + Vector2(-BREEZE.y, BREEZE.x) * rng.randfn() * (r * 0.5 + along * 0.25)
				h = rng.randf_range(0.6, 5.5) * (1.0 - along / 20.0)
			else:
				at = p + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
				h = rng.randf_range(1.2, 6.5)
			points.append(Vector3(at.x, ground + h, at.y))
	# A thin scatter over the lawn between the trees.
	for k: int in range(DRIFT_POINTS_PER_TREE * 4):
		var at := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y, AREA.end.y))
		if _w(grid, at) < 0.25: continue
		points.append(Vector3(at.x, terrain.height_at(at) + rng.randf_range(0.8, 4.0), at.y))
	var image := Image.create(points.size(), 1, false, Image.FORMAT_RGBF)
	for i: int in range(points.size()):
		var q := points[i]
		image.set_pixel(i, 0, Color(q.x, q.y, q.z))
	var drift := _petal_process(wind, 0.5, 1.2, 0.18)
	drift.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	drift.emission_point_texture = ImageTexture.create_from_image(image)
	drift.emission_point_count = points.size()
	var mesh := _petal_mesh(0.9, true)
	mesh.surface_set_material(0, _petal_air_material())
	var emitter := GPUParticles3D.new()
	emitter.name = "HanamiWindPetals"
	emitter.amount = DRIFT_AMOUNT
	emitter.lifetime = 9.0
	emitter.randomness = 0.5
	emitter.preprocess = 9.0
	emitter.local_coords = false
	emitter.fixed_fps = 30
	emitter.process_material = drift
	emitter.draw_pass_1 = mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := AREA.grow(25.0)
	emitter.visibility_aabb = AABB(Vector3(box.position.x, -5.0, box.position.y), Vector3(box.size.x, 25.0, box.size.y))
	root.add_child(emitter)
	emitter.global_position = Vector3.ZERO
	# Gusts: a few crowns throw a burst now and then (each its own period).
	var gusts := 0
	var order := cherries.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _hash01(a.p, 91) < _hash01(b.p, 91))
	for c: Dictionary in order.slice(0, GUSTS):
		var p: Vector2 = c.p
		var r: float = c.r
		var height: float = c.h
		var process := _petal_process(wind, 1.2, 2.4, 0.45)
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(r * 0.6, height * 0.1, r * 0.6)
		process.direction = (wind + Vector3.UP * 0.8).normalized()
		process.spread = 35.0
		# Seen for the first ~4 s of the cycle, then gone till the next burst.
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.03, 0.3, 0.42, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		process.color_ramp = ramp
		var gust := GPUParticles3D.new()
		gust.name = "HanamiGust_%02d" % gusts
		gust.amount = 46
		gust.lifetime = lerpf(7.0, 14.0, _hash01(p, 93))
		gust.explosiveness = 0.8
		gust.randomness = 0.3
		gust.preprocess = gust.lifetime * _hash01(p, 94)
		gust.local_coords = false
		gust.fixed_fps = 30
		gust.process_material = process
		gust.draw_pass_1 = mesh
		gust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gust.visibility_range_end = 70.0
		gust.visibility_aabb = AABB(Vector3(-r - 4.0, -height, -r - 4.0), Vector3(r * 2.0 + 20.0, height * 2.2, r * 2.0 + 20.0))
		root.add_child(gust)
		gust.global_position = Vector3(p.x, terrain.height_at(p) + height * 0.7, p.y)
		gusts += 1
	# Round the camera: a veil of petals in a box that follows the eye (offset
	# upwind, so they drift through the view), only where the lawn is.
	var veil_process := _petal_process(wind, 0.4, 1.1, 0.12)
	veil_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	veil_process.emission_box_extents = Vector3(VEIL_HALF, 3.0, VEIL_HALF)
	var veil := GPUParticles3D.new()
	veil.name = "HanamiPetalVeil"
	veil.amount = VEIL_AMOUNT
	veil.lifetime = 8.0
	veil.randomness = 0.5
	veil.preprocess = 8.0
	veil.local_coords = false
	veil.fixed_fps = 30
	veil.process_material = veil_process
	veil.draw_pass_1 = mesh
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.amount_ratio = 0.0
	veil.visibility_aabb = AABB(Vector3(-VEIL_HALF - 20.0, -8.0, -VEIL_HALF - 20.0), Vector3(VEIL_HALF * 2.0 + 40.0, 20.0, VEIL_HALF * 2.0 + 40.0))
	root.add_child(veil)
	var follow := GDScript.new()
	follow.source_code = VEIL_FOLLOW
	follow.reload()
	var helper := Node.new()
	helper.name = "HanamiPetalVeilFollow"
	helper.set_script(follow)
	helper.set("veil", veil)
	helper.set("terrain", terrain)
	helper.set("upwind", -wind * VEIL_HALF * 0.6)
	root.add_child(helper)
	return {"drift_points": points.size(), "drift_amount": DRIFT_AMOUNT, "gusts": gusts, "veil_amount": VEIL_AMOUNT}

## The airborne petal motion: carried along `wind` at `speed_min`..`speed_max`
## m/s, swirled by turbulence (some rise), tumbling; `sink` m/s2 settles them.
static func _petal_process(wind: Vector3, speed_min: float, speed_max: float, sink: float) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.direction = (wind + Vector3.UP * 0.15).normalized()
	process.spread = 25.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = wind * 0.12 + Vector3.DOWN * sink
	process.damping_min = 0.1
	process.damping_max = 0.3
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.6
	process.turbulence_noise_scale = 5.0
	process.turbulence_noise_speed = Vector3(0.35, 0.12, 0.25)
	process.turbulence_noise_speed_random = 0.3
	process.turbulence_influence_min = 0.15
	process.turbulence_influence_max = 0.4
	process.particle_flag_rotate_y = true
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	# Drawn a little over life size (1.5 cm petals are sub-pixel past a few
	# metres): 3-5 cm.
	process.scale_min = 1.0
	process.scale_max = 1.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	return process

## Near-white petal with a pale pink blush, lit on both faces, the light
## through it soft pink.
static func _petal_air_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.9, 0.9)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.8
	material.backlight_enabled = true
	material.backlight = Color(0.55, 0.42, 0.44)
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return material

## A few petals letting go of each crown: a GPU particle loop, no script.
static func _falling_petals(root: Node3D, p: Vector2, ground: float, height: float, index: int) -> void:
	var fall := height * 0.62
	var lifetime := 6.0
	# Reach the turf at about 85% of the life, then fade out there (a fixed
	# gravity sent them ~7 m down, half their life spent under the ground).
	var land := lifetime * 0.85
	var speed := 0.16
	var sink := maxf(0.03, 2.0 * (fall - speed * land) / (land * land))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(height * 0.5, height * 0.08, height * 0.5)
	process.direction = Vector3(0.3, -1.0, 0.12)
	process.spread = 24.0
	process.initial_velocity_min = speed * 0.7
	process.initial_velocity_max = speed * 1.3
	process.gravity = Vector3(0.1, -sink, 0.04)
	process.particle_flag_rotate_y = true
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -70.0
	process.angular_velocity_max = 70.0
	process.scale_min = 0.9
	process.scale_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.82, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.74, 0.76)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.8
	# Tilted and centred: the Y spin then turns the petal broadside to the eye
	# (a flat petal spinning about Y stays edge-on from standing height).
	var mesh := _petal_mesh(0.9, true)
	mesh.surface_set_material(0, material)
	var emitter := GPUParticles3D.new()
	emitter.name = "HanamiFallingPetals_%02d" % index
	emitter.amount = 9
	emitter.lifetime = lifetime
	emitter.randomness = 0.6
	emitter.preprocess = 3.0
	emitter.local_coords = false
	emitter.process_material = process
	emitter.draw_pass_1 = mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_range_end = 45.0
	emitter.visibility_aabb = AABB(Vector3(-height, -fall - 0.5, -height), Vector3(height * 2.0, fall + height * 0.3, height * 2.0))
	root.add_child(emitter)
	emitter.global_position = Vector3(p.x, ground + fall, p.y)

## One sakura petal, about 3 cm: a soft oval with the notch at its tip, cupped
## a touch, base at the origin, lying flat. `tilt` (radians about X) and
## `centred` shape the falling variant.
static func _petal_mesh(tilt: float = 0.0, centred: bool = false) -> ArrayMesh:
	var turn := Basis(Vector3.RIGHT, tilt)
	var shift := Vector3(0.015, 0.0, 0.0) if centred else Vector3.ZERO
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector3Array()
	var n := 9
	for k: int in range(n):
		var a := TAU * float(k) / float(n)
		var x := (cos(a) * 0.5 + 0.5) * 0.03
		var zr := sin(a) * 0.0105 * (0.75 + 0.35 * sin((x / 0.03) * PI))
		# The notch: the tip point pulls back toward the centre.
		if k == 0: x -= 0.005
		rim.append(Vector3(x, 0.0025 * absf(sin(a)), zr))
	var centre := Vector3(0.014, -0.0008, 0.0)
	for k: int in range(n):
		var a := rim[k]
		var b := rim[(k + 1) % n]
		for v: Vector3 in [centre, b, a]:
			st.set_normal(turn * Vector3.UP)
			st.set_uv(Vector2(v.x / 0.03, v.z / 0.03 + 0.5))
			st.add_vertex(turn * (v - shift))
	return st.commit()

static func _petal_material() -> ShaderMaterial:
	return ShaderPool.material(PETAL_SHADER)

static func _petal_colour(rng: RandomNumberGenerator) -> Color:
	var roll := rng.randf()
	var c: Color
	# Pink enough that the blue sky light in the crown shade leaves them pink.
	if roll < 0.5: c = Color(0.87, 0.6, 0.64)
	elif roll < 0.8: c = Color(0.92, 0.71, 0.73)
	elif roll < 0.94: c = Color(0.78, 0.5, 0.56)
	else: c = Color(0.68, 0.53, 0.48) # browning
	return c * rng.randf_range(0.86, 1.02)

## Soft pink drift texture: fallen petals massed in a ring from the trunk out
## to the drip line in loose patches, a thin scatter beyond. Mip-mapped, so
## from afar the specks blend into a soft pink wash on the turf.
static func _drift_texture() -> ImageTexture:
	var n := 768
	var rng := RandomNumberGenerator.new()
	rng.seed = 41917
	var noise := FastNoiseLite.new()
	noise.seed = 913
	noise.frequency = 0.011
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for i: int in range(n * n):
		data[i * 4] = 226
		data[i * 4 + 1] = 176
		data[i * 4 + 2] = 182
		data[i * 4 + 3] = 0
	var half := float(n) * 0.5
	# Densest close round the trunk, thinning out to nothing at the drip line
	# (r ~0.95): a faint scatter, never a solid pool. The turf it lies on is lit
	# by the blue sky in the crown shade, so the colours lean warm (beige-pink):
	# cooler pinks went lilac there.
	var falloff := func(r: float) -> float:
		return smoothstep(0.02, 0.07, r) * pow(1.0 - smoothstep(0.06, 0.9, r), 1.6)
	# Specks only: any tint under them (the turf's own blue sky light on it)
	# read as a mauve-grey pool in the crown shade.
	for k: int in range(60000):
		var x := rng.randf() * float(n)
		var y := rng.randf() * float(n)
		var r := Vector2(x - half, y - half).length() / half
		if r > 0.97: continue
		var patch := 0.5 + 0.5 * noise.get_noise_2d(x, y)
		var dens: float = falloff.call(r) * (0.25 + 0.75 * patch * patch) * 0.95 + 0.03 * (1.0 - smoothstep(0.8, 0.97, r))
		if rng.randf() > dens: continue
		var roll := rng.randf()
		var col: Color
		if roll < 0.5: col = Color8(236, 170, 154)
		elif roll < 0.82: col = Color8(244, 192, 174)
		elif roll < 0.95: col = Color8(226, 150, 140)
		else: col = Color8(196, 160, 132)
		var a := rng.randf() * PI
		var ca := cos(a)
		var sa := sin(a)
		var along := rng.randf_range(1.7, 2.6)
		var wid := along * 0.62
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				var u := (float(dx) * ca + float(dy) * sa) / along
				var v := (-float(dx) * sa + float(dy) * ca) / wid
				if u * u + v * v > 1.0: continue
				var px := int(x) + dx
				var py := int(y) + dy
				if px < 0 or py < 0 or px >= n or py >= n: continue
				var o := (py * n + px) * 4
				data[o] = col.r8
				data[o + 1] = col.g8
				data[o + 2] = col.b8
				data[o + 3] = 255
	var image := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## One drift decal under each crown, pushed a little downwind: the soft pink
## ring that reads from across the lawn (the mesh petals carry the near view).
static func _petal_drifts(root: Node3D, terrain: Node, rng: RandomNumberGenerator, cherries: Array) -> int:
	if cherries.is_empty(): return 0
	var texture := _drift_texture()
	var count := 0
	for c: Dictionary in cherries:
		var p: Vector2 = c.p + WIND * 0.45
		var radius: float = c.r
		var decal := Decal.new()
		decal.name = "HanamiPetalDrift_%02d" % count
		var d := radius * 2.0 * 1.05 * rng.randf_range(0.95, 1.08)
		decal.size = Vector3(d, 1.6, d)
		decal.texture_albedo = texture
		decal.albedo_mix = 1.0
		decal.modulate = Color(1, 1, 1, 0.72)
		decal.upper_fade = 0.25
		decal.lower_fade = 0.25
		decal.normal_fade = 0.5
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 110.0
		decal.distance_fade_length = 40.0
		root.add_child(decal)
		decal.global_position = Vector3(p.x, terrain.height_at(p) + 0.1, p.y)
		decal.rotation.y = rng.randf() * TAU
		count += 1
	return count

## Fallen petals: a carpet ringing each trunk out to its drip line, pushed a
## little downwind, a thin noisy drift between the trees, swept thin on paths
## and the plaza.
static func _petal_floor(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, grid: PackedFloat32Array, cherries: Array) -> int:
	var rows: Array = []
	var since := Kit.frames_now()
	for z: int in range(GRID.size.y):
		var cz := float(GRID.position.y + z) + 0.5
		var near: Array = []
		for c: Dictionary in cherries:
			if absf(c.p.y + WIND.y - cz) < c.r * 1.2 + 1.0: near.append(c)
		for x: int in range(GRID.size.x):
			var w: float = grid[z * GRID.size.x + x]
			if w < 0.06: continue
			var cell := Vector2(GRID.position.x + x + 0.5, cz)
			if terrain.water_at(cell): continue
			var under := 0.0
			for c: Dictionary in near:
				var r: float = c.r
				var d: float = (c.p + WIND).distance_to(cell)
				# Densest at the trunk, gone by the drip line.
				if d < r: under = maxf(under, pow(smoothstep(r, r * 0.1, d), 1.5))
			var drift := 0.5 + 0.5 * Biomes.noise().get_noise_2dv(cell * 2.6 + Vector2(31, 7))
			var per_m2 := w * (0.3 + 1.6 * drift * drift) + 34.0 * under * (0.45 + 0.8 * drift)
			if per_m2 < 0.05: continue
			var edge: float = park.path_edge_distance_world(cell) if park.has_method("path_edge_distance_world") else 9.0
			if edge < 0.3: per_m2 *= 0.12
			var lift := _surface_lift(park, terrain, cell)
			if lift < 0.0: continue
			# Turf (collision a few cm off height_at) rests on height_at, as the
			# visible ground does; only a real deck or paver lifts the petals.
			var raised := lift > PAVED_LIFT
			if raised: per_m2 *= 0.15
			# Cells touching the lake: each petal is checked, none sink in water.
			var shore: bool = Biomes.LAKE_NEAR.has_point(cell) and (terrain.water_at(cell + Vector2(0.5, 0.5)) or terrain.water_at(cell + Vector2(-0.5, 0.5)) or terrain.water_at(cell + Vector2(0.5, -0.5)) or terrain.water_at(cell + Vector2(-0.5, -0.5)))
			var count := int(per_m2) + (1 if rng.randf() < per_m2 - floorf(per_m2) else 0)
			for k: int in range(count):
				var p := cell + Vector2(rng.randf() - 0.5, rng.randf() - 0.5)
				var clear := true
				for c: Dictionary in near:
					if (c.p as Vector2).distance_to(p) < 0.6: clear = false
				if not clear: continue
				if shore and terrain.water_at(p): continue
				# On a raised cell each petal finds its own surface, so the ones
				# past a deck or plaza edge drop to the turf instead of floating.
				var rest := 0.0
				if raised:
					rest = _surface_lift(park, terrain, p)
					if rest < 0.0: continue
					if rest <= PAVED_LIFT: rest = 0.0
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.FORWARD, rng.randf_range(-0.35, 0.35))
				# Some lie on the soil, some rest on the mown blades.
				var y: float = terrain.height_at(p) + rest + 0.015 + rng.randf() * rng.randf() * 0.06
				rows.append([Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(1.25, 1.8)), Vector3(p.x, y, p.y)), _petal_colour(rng)])
		# The first row runs before any frame (as it always did) right after the
		# trunks joined the space; then a frame and physics steps, then the rows
		# yield on time (nothing joins the scene in this loop).
		if z == 0: await Kit.settle(park, since)
		else: await Kit.slice(park)
		if not _alive(park): return 0
	if rows.size() > MAX_PETALS:
		var keep_share := float(MAX_PETALS) / float(rows.size())
		rows = rows.filter(func(_r: Array) -> bool: return rng.randf() < keep_share)
	Kit.cell_batches(root, "HanamiPetals", _petal_mesh(), _petal_material(), rows, 8.0, 32.0, false)
	return rows.size()

# --- understory and lawn -----------------------------------------------------

## Labels (node name + mesh name, lower case) of the low planting the lawn
## sheds: shrubs, bushes, beds, ferns, flowers, forest grass, spiky grass and
## the floor litter of leaves and twigs. Lawn blades, trees, petals, stones and
## lily ponds are never matched. (The park's bush mesh is called "Tree EZT",
## so "tree" alone does not mean a tree.)
static func _is_low_planting(source: String) -> bool:
	for never: String in ["upright", "groundclump", "meshyground", "sakura", "cherry", "petal", "broadleaf", "pine", "maple", "trunk", "pond", "lily", "stone", "boulder", "rock", "lantern", "lamp", "collision", "hanami", "can_"]:
		if source.contains(never): return false
	for token: String in ["fountain", "emerald", "meadow", "spiky", "woodlandfill", "densegrass", "dense_grass", "forestgrass", "grassdrift", "shoulder", "transition", "bush", "shrub", "lilac", "fern", "bed_", "flower", "wildflower", "azalea", "iris", "companion", "understory", "diversity", "groundcover", "tree ezt", "parkfloor_grass", "parkfloor_leaf", "parkfloor_branch", "curled serrated", "branches_b"]:
		if source.contains(token): return true
	return false

## Nothing low stays in the core of the lawn; toward the edge it thins by a
## position dither so no line shows.
static func _keep_low(grid: PackedFloat32Array, p: Vector2) -> bool:
	if not AREA.has_point(p): return true
	# The west end of the lawn is open turf right out to the ellipse rim (the
	# dither had left fountain grass and tufts standing in the west view).
	if _west_open(p): return false
	return not Biomes.pick(p, smoothstep(0.15, 0.55, _w(grid, p)), 31)

static func _west_open(p: Vector2) -> bool:
	return p.x < -40.0 and ((p - ELLIPSE_C) / ELLIPSE_R).length() < 1.03

## No understory on the lawn: batched low planting goes through the shared
## thinning helper when it exists, single planted nodes are hidden here (only
## those without collision, so no invisible walls are left).
static func _thin_understory(park: Node3D, grid: PackedFloat32Array) -> Dictionary:
	var report := {}
	var keep := func(p: Vector2) -> bool: return _keep_low(grid, p)
	if ResourceLoader.exists(THIN_ALL):
		var helper: Resource = load(THIN_ALL)
		var label_filter := func(label: String) -> bool: return _is_low_planting(label.to_lower())
		# The area only skips far nodes for speed; keep() still decides inside it.
		report["batched"] = helper.call("hide_low_planting", park, label_filter, keep, AREA, true)
	else:
		var filter := func(node: MultiMeshInstance3D) -> bool:
			if String(node.get_path()).contains("/Biome"): return false
			var label := (String(node.name) + " " + (node.multimesh.mesh.resource_name if node.multimesh.mesh else "")).to_lower()
			return _is_low_planting(label)
		report["batched"] = Kit.thin_multimeshes([park], filter, keep)
	var single := 0
	for node: Node in park.find_children("*", "Node3D", true, false):
		var plant := node as Node3D
		if plant == null or not plant.visible: continue
		var label := String(plant.name)
		var listed := false
		for prefix: String in PLANT_PREFIXES:
			if label.begins_with(prefix): listed = true
		if not listed: continue
		var at := plant.global_position
		if keep.call(Vector2(at.x, at.z)): continue
		if not plant.find_children("*", "CollisionObject3D", true, false).is_empty(): continue
		plant.hide()
		single += 1
	report["single"] = single
	return report

## The lawn is kept: upright blades and ground clumps are mown to about half
## height (bases stay on the soil) and the broad blades thinned, so the turf
## reads short and fine. Feathered by weight, so no mowing edge shows.
##
## midori_distance_detail.gd (run before the biomes) copies every visible grass
## MultiMesh, MidoriGrassDetail included, into park/MidoriDistanceDetail cell
## chunks and HIDES the sources (see thin_all.gd findings 1 and 4). The chunks
## share the source Mesh, so the lawn meshes are found in the sources and the
## same position-based cut is applied to every chunk drawing them; mowing only
## the hidden sources would change nothing on screen.
static func _mow_lawn(park: Node3D, grid: PackedFloat32Array) -> Dictionary:
	# The grass producer adds its root under the current scene (the park itself).
	var grass: Node = park.get_node_or_null("MidoriGrassDetail")
	var scene := park.get_tree().current_scene
	if grass == null and scene != null: grass = scene.get_node_or_null("MidoriGrassDetail")
	if grass == null: grass = park.get_tree().root.get_node_or_null("MidoriGrassDetail")
	if grass == null: return {"mowed": 0, "thinned_broad": 0, "grass_root": false}
	# Lawn meshes: mesh instance id -> broad (thinned as well as mown).
	var lawn: Dictionary = {}
	var targets: Array[MultiMeshInstance3D] = []
	for node: MultiMeshInstance3D in grass.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh == null or node.multimesh.mesh == null: continue
		var label := String(node.name)
		var broad := label.begins_with("UprightGrass")
		if not (broad or label.begins_with("ThinUprightGrass") or label.begins_with("MeshyGroundClumps")): continue
		var id := node.multimesh.mesh.get_instance_id()
		if not lawn.has(id): lawn[id] = broad
		targets.append(node)
	if lawn.is_empty(): return {"mowed": 0, "thinned_broad": 0, "grass_root": true, "lawn_meshes": 0}
	var chunks := 0
	var copies: Node = park.get_node_or_null("MidoriDistanceDetail")
	if copies != null:
		for node: MultiMeshInstance3D in copies.find_children("*", "MultiMeshInstance3D", true, false):
			if node.multimesh == null or node.multimesh.mesh == null: continue
			if not lawn.has(node.multimesh.mesh.get_instance_id()): continue
			targets.append(node)
			chunks += 1
	# Shadow proxies share the chunk MultiMesh and cache its bounds: suspend the
	# soft fade while editing and re-capture after (thin_all.gd finding 2).
	var shadows: Node = park.get_node_or_null("MidoriNearPlantShadows")
	var guarded := shadows != null and shadows.has_method("before_source_change") and shadows.has_method("after_source_change")
	if guarded: shadows.before_source_change()
	var mowed := 0
	var thinned := 0
	var since_yield := 0
	var done: Dictionary = {}
	for node: MultiMeshInstance3D in targets:
		if not is_instance_valid(node) or node.multimesh == null: continue
		var many := node.multimesh
		if done.has(many.get_instance_id()): continue
		done[many.get_instance_id()] = true
		var broad: bool = lawn.get(many.mesh.get_instance_id(), false)
		var to_world := node.global_transform
		# Skip whole batches that cannot reach the lawn.
		var reach: AABB = to_world * (many.custom_aabb if many.custom_aabb.size != Vector3.ZERO else many.get_aabb())
		if not AREA.intersects(Rect2(reach.position.x, reach.position.z, maxf(reach.size.x, 0.01), maxf(reach.size.z, 0.01))): continue
		var bounds := many.mesh.get_aabb()
		var anchor := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var changed := false
		var count := many.visible_instance_count if many.visible_instance_count >= 0 else many.instance_count
		for i: int in range(count):
			var t := many.get_instance_transform(i)
			if t.basis.get_scale().x < 0.0001: continue
			var at := to_world * t.origin
			var p := Vector2(at.x, at.z)
			var w := _w(grid, p)
			if w < 0.08: continue
			# Broad blades thinned, and gone at the open west end.
			if broad and (Biomes.pick(p, smoothstep(0.3, 0.85, w) * 0.45, 37) or _west_open(p)):
				t.basis = t.basis.scaled(Vector3.ONE * 0.00001)
				many.set_instance_transform(i, t)
				thinned += 1
				changed = true
				continue
			var k := lerpf(1.0, 0.5, smoothstep(0.15, 0.85, w))
			var foot := t.origin + t.basis * anchor
			var b := Basis.from_scale(Vector3(1.0, k, 1.0)) * t.basis
			many.set_instance_transform(i, Transform3D(b, foot - b * anchor))
			mowed += 1
			changed = true
		if changed: node.set_meta("biome_mowed", true)
		since_yield += count
		if since_yield >= MOW_PER_FRAME:
			since_yield = 0
			await park.get_tree().process_frame
			if not _alive(park): return {"mowed": mowed, "thinned_broad": thinned, "aborted": true}
	if guarded and is_instance_valid(shadows): shadows.after_source_change()
	return {"mowed": mowed, "thinned_broad": thinned, "lawn_meshes": lawn.size(), "distance_chunks": chunks}
