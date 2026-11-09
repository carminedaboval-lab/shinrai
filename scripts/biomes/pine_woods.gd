extends RefCounted
## Matsubayashi 松林, the pine woods round the clubhouse, the court lobe and the
## east stand (docs/biome_concepts/after_pine_woods.png and extra/after_pine_woods_*).
## Tall pines over a clean grey-brown needle floor with long open sightlines:
##  1. many broadleaf trees in the lobes are reskinned as pines (trunk positions
##     and tree count unchanged), ramped by a position hash so edges interleave,
##  2. the spiky grass beds and most lawn blades thin out to the needle floor,
##  3. the floor gets sparse cones, a few fallen branches and half-buried stones,
##     some low clipped evergreen mounds in odd drifts, and small iris clumps,
##  4. new tall red pines (bare trunk low, crown high) stand round the views the
##     concepts were drawn from, plus a few in the widest gaps, and every pine in
##     the lobes takes a muted olive crown and a warmer orange-grey bark.
## Nothing is planted in rows or lattices; every scatter is jittered and noise-led.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const Woodland := preload("res://scripts/midori_woodland_layout.gd")
const Contacts := preload("res://scripts/midori_tree_branch_contacts.gd")
const Foliage := preload("res://scripts/midori_foliage_materials.gd")
const PINE_PACK := "res://assets/shinrai/parks/midori_park/models/vegetation/vendor/pine_trees_pack/scene.glb"
# The pack's tall variants with the highest clear trunk: large_3 carries no
# needles below 41 % of its height, big_3 none below 34 % (big_1, the park's
# first pine prototype, starts at 24 % and reads bushy low). Second value: share.
const TALL_PINES := [["Pine_large_3", 0.7], ["Pine_big_3", 0.3]]
# LOD1 near, LOD2 beyond; hysteresis margins, no alpha fade (that would put the
# whole cell in the transparent pass while it fades).
const PINE_NEAR_END := 55.0
const PINE_FAR_END := 190.0
const PINE_SEED := 20501117
const MAX_NEW_PINES := 38
const MAX_FILL_PINES := 6
# Muted olive needles and a warmer orange-grey bark, as Japanese red pine
# (akamatsu). The pack's cluster texture averages a light yellow-green (sRGB
# ~109,124,62); a low-blue tint would only push that further towards lime, so the
# needle tint darkens and pulls green down against blue: ~76,83,47, muted olive.
const NEEDLE_TINT := Color(0.72, 0.69, 0.8)
const BARK_TINT := Color(1.0, 0.86, 0.74)
const TINT_META := &"matsu_tint"
# The concept views: eye and look point (world xz), and what should stand in
# frame in camera terms, Vector2(metres ahead, metres to the right). Read off
# the concept images (docs/biome_concepts/after_pine_woods*.png); every spot is
# jittered and then searched round, so nothing lands on a line.
const FRAMES := [
	{"view": "pine_woods", "eye": Vector2(-112, -40), "look": Vector2(-160, -70),
		# A big trunk each side close in, then trunks scattered at mixed depths
		# left of the path, one beside the path's far bend and two rising behind
		# the clubhouse (concept x ~260, ~20, ~740, ~860 px). The near-left trunk
		# stands ~6 m ahead and only ~1 m off the path in the concept; with 2.5 m
		# path clearance it sits ~8.6 m ahead (x ~120 px), still framing the left.
		# Nothing goes right of the clubhouse past ~20 m: that is the five-a-side
		# pitch fence. The spots zigzag in depth so no two-three of them line up.
		"pines": [Vector2(8.6, -9.4), Vector2(7.5, 8.6), Vector2(21.5, -19.5), Vector2(27.0, -31.0), Vector2(30.0, -19.5), Vector2(37.5, -10.2), Vector2(39.5, -4.5), Vector2(44.0, -24.0), Vector2(48.0, -36.0), Vector2(11.5, 16.0), Vector2(22.0, 18.5)],
		"mounds": [Vector2(5.9, 4.9), Vector2(17.0, -12.5)],
		"iris": [Vector2(6.6, 2.8), Vector2(15.6, -15.4), Vector2(13.1, 12.7)]},
	{"view": "pine_woods_reverse", "eye": Vector2(-185, -95), "look": Vector2(-130, -45),
		# First: the big centre trunk ~6 m ahead (an existing broadleaf stands
		# there today; the swap turns any tree holding a frame spot to pine).
		"pines": [Vector2(5.9, 0.6), Vector2(10.5, 4.6), Vector2(6.5, -9.5), Vector2(7.5, 11.0), Vector2(24.0, 9.5), Vector2(16.0, 15.5), Vector2(34.0, 3.0)],
		"mounds": [Vector2(3.4, -0.4), Vector2(8.4, 6.8), Vector2(9.0, -3.0)],
		"iris": [Vector2(4.6, 2.2), Vector2(7.4, 9.0)]},
	{"view": "pine_woods_court", "eye": Vector2(-95, -118), "look": Vector2(-110, -160),
		"pines": [Vector2(8.8, -2.8), Vector2(5.2, 5.3), Vector2(14.0, -17.0), Vector2(20.0, -20.5), Vector2(26.0, -25.0), Vector2(30.0, -15.0)],
		"mounds": [Vector2(6.6, 0.6), Vector2(3.2, 3.2)],
		"iris": [Vector2(3.6, -1.0), Vector2(8.2, -7.5)]},
	{"view": "pine_woods_east_stand", "eye": Vector2(186, 68), "look": Vector2(184, 20),
		"pines": [Vector2(5.0, 2.5), Vector2(7.3, -8.6), Vector2(10.1, -5.8), Vector2(8.8, 7.5), Vector2(11.9, 11.4), Vector2(14.6, -13.6), Vector2(21.9, 9.9), Vector2(32.0, -12.0), Vector2(37.0, 10.6), Vector2(26.0, -3.0)],
		"mounds": [Vector2(4.2, 0.4), Vector2(13.0, -10.6), Vector2(11.9, 7.7)],
		"iris": [Vector2(4.6, -4.5), Vector2(5.4, 4.6), Vector2(13.0, -1.0)]},
]
const ID := "matsu"
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const EVERGREEN := "res://assets/shinrai/parks/midori_park/models/vegetation/midori_evergreen_shrub_v1.glb"
const IRIS := "res://assets/shinrai/parks/midori_park/models/plants/iris_japonica/iris_japonica_lod1.glb"
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
# Share of broadleaf trees turned to pine at full weight (on top of the pines
# already standing there, so the core reads as roughly two thirds pine).
const PINE_SHARE := 0.9
# Each lobe's ellipse plus its feather; anything outside has zero weight.
const AREAS := [Rect2(-230, -130, 160, 136), Rect2(-158, -188, 108, 96), Rect2(148, 0, 74, 80)]
# Scan rectangles for scatters (the first two lobes overlap, so one box covers both).
const SCANS := [Rect2(-230, -188, 180, 194), Rect2(148, 0, 74, 80)]
# Built footprints kept clear and the clipped mounds gather round (fallback world
# anchors when missing). The five-a-side pitch (fence ~(-160..-120, -96.5..-75.5))
# sits inside the main lobe at full weight: without it, fill pines, cones, stones
# and mounds could land on the turf or against the fence.
const LANDMARKS := [["MidoriClubhouseCafeteria", Vector2(-126, -59)], ["MidoriBasketballCourt", Vector2.INF], ["ACT03_FiveASideSteelFence", Vector2.INF]]
const MAX_MOUNDS := 46
# Keep-out pad for the concept-framed mounds and iris (negative: inside the 2 m
# footprint margin, never on the built edge itself).
const FRAMED_PAD := -0.6
# One small flowering accent near each framed mound group, plus a few at
# other mound feet. Keep the open stretches of needles between these clumps.
const MAX_IRIS_CLUMPS := 8

static var _terrain: Node
static var _cache: Dictionary = {}
# Built footprints (court, clubhouse) grown by a margin: no floor detail or
# planting inside them. The landmarks' own origins say nothing about their size.
static var _keep_out: Array[Rect2] = []
# Source material -> matsu-tinted copy (and each copy to itself).
static var _tints: Dictionary = {}

static func build(park: Node3D, terrain: Node) -> Dictionary:
	_terrain = terrain
	_cache = {}
	_tints = {}
	_keep_out = _landmark_footprints(park)
	var root := Node3D.new()
	root.name = "BiomePineWoods"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501103
	# Weights first, a row per frame: the thinning asks for them per instance
	# inside a synchronous pass, and the east lobe pays a shoreline search.
	if not await _prewarm(park): return _abort()
	var swap := await _swap_pines(park)
	if not is_instance_valid(park): return _abort()
	# New tall pines before the floor: cones ring them, mounds and iris keep off them.
	var planted := await _plant_pines(park, terrain, root)
	if not is_instance_valid(park): return _abort()
	var pine_spots: Array[Vector2] = _pine_spots(park)
	var new_spots: Array = planted.get("spots", [])
	for p: Vector2 in new_spots: pine_spots.append(p)
	planted.erase("spots")
	var thinned := await _thin(park)
	if not is_instance_valid(park): return _abort()
	var cones := await _cones(park, terrain, root, rng, pine_spots)
	if not is_instance_valid(park): return _abort()
	var litter := await _floor_litter(park, terrain, root, rng)
	if not is_instance_valid(park): return _abort()
	var mounds := await _mounds(park, terrain, root, rng)
	if not is_instance_valid(park): return _abort()
	var iris := await _iris(park, terrain, root, rng, mounds.spots)
	if not is_instance_valid(park): return _abort()
	var keep_out := _keep_out.size()
	_abort()
	return {"pines": swap, "new_pines": planted, "pine_trunks": pine_spots.size(), "cones": cones, "stones": litter.stones, "branches": litter.branches, "mounds": mounds.count, "iris_clumps": iris.clumps, "iris_fans": iris.fans, "iris_stems": iris.stems, "thinned": thinned, "keep_out_footprints": keep_out}

## Drops the static state (also when the park went away mid-build).
static func _abort() -> Dictionary:
	_cache = {}
	_tints = {}
	_terrain = null
	_keep_out = []
	return {}

static func _prewarm(park: Node3D) -> bool:
	var since := Kit.frames_now()
	# Every cell _w() would fill, in the order it would fill them; the weights
	# (pure maths) are worked out on WorkerThreadPool in chunks and stored as
	# the same float values _w() stores.
	var keys: Array[Vector2i] = []
	var seen := {}
	for rect: Rect2 in AREAS:
		for z: int in range(floori(rect.position.y), ceili(rect.end.y)):
			for x: int in range(floori(rect.position.x), ceili(rect.end.x)):
				var p := Vector2(x, z)
				if not _in_areas(p): continue
				var key := Vector2i(floori(p.x), floori(p.y))
				if _cache.has(key) or seen.has(key): continue
				seen[key] = true
				keys.append(key)
	var terrain := _terrain
	Biomes.noise() # made before the threads read it
	var chunk := 512
	# Each chunk reads its own copy of the weight kernel (Biomes.Kernel: the
	# same floats as Biomes.weight, nothing shared between the threads).
	var kernel := Biomes.terrain_kernel(terrain)
	var id_index := Biomes.region_index(ID)
	var job := func(c: int) -> PackedFloat64Array:
		var k := kernel.clone()
		var out := PackedFloat64Array()
		for i: int in range(c * chunk, mini((c + 1) * chunk, keys.size())):
			out.append(k.weight(Vector2(keys[i]) + Vector2(0.5, 0.5), id_index))
		return out
	var parts := Kit.parallel(ceili(float(keys.size()) / float(chunk)), job, "pine_woods weights")
	for c: int in range(parts.size()):
		var values: PackedFloat64Array = parts[c]
		for k: int in range(values.size()): _cache[keys[c * chunk + k]] = values[k]
	await Kit.settle(park, since)
	return is_instance_valid(park)

## World footprints of the clubhouse and the basketball court, from their own
## meshes (the court node sits at its centre, the clubhouse at its anchor).
static func _landmark_footprints(park: Node3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for mark: Array in LANDMARKS:
		var node := park.find_child(String(mark[0]), true, false) as Node3D
		var fallback: Vector2 = mark[1]
		if node == null:
			if fallback.is_finite(): out.append(Rect2(fallback - Vector2(9, 9), Vector2(18, 18)).grow(2.0))
			continue
		var origin := Vector2(node.global_position.x, node.global_position.z)
		var box := Rect2(origin, Vector2.ZERO)
		for found: Node in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
			var b: AABB = mesh.global_transform * mesh.get_aabb()
			var flat := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
			# Ignore anything far-flung or huge (a ground apron, a stray sign).
			if flat.size.x > 60.0 or flat.size.y > 60.0 or flat.get_center().distance_to(origin) > 30.0: continue
			box = box.merge(flat)
		if box.size.x < 4.0 or box.size.y < 4.0: box = Rect2(origin - Vector2(9, 9), Vector2(18, 18))
		out.append(box.grow(2.0))
	return out

static func _kept_out(p: Vector2, pad: float = 0.0) -> bool:
	for box: Rect2 in _keep_out:
		if box.grow(pad).has_point(p): return true
	return false

## A point a little outside a footprint, any side, at a random gap.
static func _ring_point(box: Rect2, rng: RandomNumberGenerator, gap_min: float, gap_max: float) -> Vector2:
	var a := rng.randf() * TAU
	var d := Vector2(cos(a), sin(a))
	var half := box.size * 0.5
	var t := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	return box.get_center() + d * (t + rng.randf_range(gap_min, gap_max))

static func _in_areas(p: Vector2) -> bool:
	for rect: Rect2 in AREAS:
		if rect.has_point(p): return true
	return false

## Matsu weight, cached on a 1 m grid (thinning asks for it per instance).
static func _w(p: Vector2) -> float:
	if not _in_areas(p): return 0.0
	var key := Vector2i(floori(p.x), floori(p.y))
	if _cache.has(key): return float(_cache[key])
	var w := Biomes.weight(Vector2(key) + Vector2(0.5, 0.5), ID, _terrain)
	_cache[key] = w
	return w

static func _hash01(p: Vector2, salt: int) -> float:
	return float(absi(hash(Vector3i(floori(p.x * 8.0), floori(p.y * 8.0), salt))) % 10007) / 10007.0

## True when nothing but the ground is under the point (no prop, deck or roof).
static func _bare(park: Node3D, terrain: Node, p: Vector2) -> bool:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return true
	# The terrain's own floor bodies are ground; anything else standing more than
	# a few centimetres proud (court slab, terrace, deck, plinth, prop) is not.
	var body: Variant = hit.get("collider")
	if body is Node and (body as Node).is_in_group("midori_terrain_floor"): return true
	var at: Vector3 = hit.position
	return at.y < ground + 0.04

static func _clear_of_plants(park: Node3D, p: Vector2, radius: float) -> bool:
	if not park.has_method("_is_vegetation_clear"): return true
	return park._is_vegetation_clear(Vector3(p.x / 2.0, 0.0, p.y / 2.0), radius * 0.5)

# ---------------------------------------------------------------- trees

static func _nearest_tree_index(positions: Array, layout: Vector2) -> int:
	var best := -1
	var best_d := 0.6
	for i: int in range(positions.size()):
		var q: Vector2 = positions[i]
		var d := q.distance_to(layout)
		if d < best_d:
			best_d = d
			best = i
	return best

## Reskins broadleaf trees as pines: the trunk stays where it is, the old visual
## is hidden (not freed, other systems may still hold its meshes) and a pine
## visual of matching crown size takes its place. A position hash ramps the
## share with the weight, so edge trees mix with the lapsed broadleaf.
static func _swap_pines(park: Node3D) -> Dictionary:
	var report := {"swapped": 0, "already_pine": 0, "kept_broadleaf": 0, "framing": 0, "by_variant": [0, 0, 0]}
	var raw: Variant = park.get("pine_prototypes")
	if not (raw is Array) or (raw as Array).is_empty(): return report
	var pines: Array = raw
	var crowns_raw: Variant = park.get("_occupied_tree_crowns")
	var crowns: Dictionary = crowns_raw if crowns_raw is Dictionary else {}
	var positions: Array = park.occupied_tree_positions
	var skinny: Array = park.occupied_tree_is_skinny
	var crown_of: Array[float] = []
	for proto: Node3D in pines:
		crown_of.append(park._tree_crown_radius(proto) if park.has_method("_tree_crown_radius") else 3.0)
	var protected := {}
	for contact: Dictionary in Contacts.MOVES: protected[String(contact.name)] = true
	var trees: Array[Node] = []
	for pattern: String in ["ReferenceBroadleaf_*", "MicroGroveBroadleaf*", "SparseGapTree_*"]:
		trees.append_array(park.find_children(pattern, "Node3D", true, false))
	var step := 0
	for node: Node in trees:
		step += 1
		if step % 64 == 0:
			await park.get_tree().process_frame
			if not is_instance_valid(park): return report
		if not is_instance_valid(node): continue
		var tree := node as Node3D
		if tree == null or tree.is_queued_for_deletion() or not tree.is_visible_in_tree(): continue
		if tree.has_meta("iris_grove") or tree.has_meta("biome_pine"): continue
		var content := tree.get_node_or_null("Content") as Node3D
		if content == null: continue
		var gp := Vector2(tree.global_position.x, tree.global_position.z)
		if not _in_areas(gp): continue
		# A tree standing on a concept frame spot holds it (no new pine goes
		# there), so it always turns pine: that is what the view was drawn with.
		# Branch-contact trees are only kept broadleaf elsewhere; a pine crown is
		# narrower than the broadleaf one that contact was measured for.
		var framing := _holds_frame_spot(gp)
		if protected.has(String(tree.name)) and not framing: continue
		var w := _w(gp)
		if w < 0.04 and not framing: continue
		var index := _nearest_tree_index(positions, gp / 2.0)
		if index >= 0 and index < skinny.size() and bool(skinny[index]):
			report.already_pine += 1
			continue
		if framing: report.framing += 1
		elif not Biomes.pick(gp, PINE_SHARE * smoothstep(0.05, 0.85, w), 41):
			report.kept_broadleaf += 1
			continue
		# Mostly the large pine (index 1, the clearest trunk of the three), then the
		# big one (bushier low), a few medium ones for an uneven skyline.
		var roll := _hash01(gp, 42)
		var variant := 1 if roll < 0.55 else (0 if roll < 0.87 else 2)
		variant = mini(variant, pines.size() - 1)
		var proto: Node3D = pines[variant]
		var crown: float = maxf(crown_of[variant], 0.5)
		var key: Vector2 = positions[index] if index >= 0 else gp / 2.0
		var old_radius: float = float(crowns.get(key, crown * tree.scale.y))
		# Pine crowns are narrower, so the same allowance gives a taller tree.
		# Pines stand taller than the broadleaf they replace; crowns may touch.
		var size := clampf(old_radius / crown * 1.08, 0.95, 1.35) * lerpf(0.94, 1.08, _hash01(gp, 43))
		var source := proto.get_node_or_null("Content") as Node3D
		if source == null: continue
		content.visible = false
		content.set_meta("biome_replaced_by_pine", true)
		var fresh := source.duplicate() as Node3D
		fresh.name = "BiomePineContent"
		tree.add_child(fresh)
		_match_draw_settings(content, fresh)
		_retint(fresh)
		tree.scale *= size / maxf(tree.scale.y, 0.001)
		crowns[key] = crown * size
		if index >= 0 and index < skinny.size(): skinny[index] = true
		tree.set_meta("biome_pine", true)
		tree.set_meta("grove_tree_source", String(proto.name))
		report.swapped += 1
		report.by_variant[variant] += 1
	return report

## The draw-distance and reflection passes ran over the old visual at boot; the
## new pine visual takes the same ranges, layers and shadow mode so it fades
## out with the rest of the woods instead of drawing forever.
static func _match_draw_settings(old: Node3D, fresh: Node3D) -> void:
	var model: GeometryInstance3D = null
	for found: Node in old.find_children("*", "GeometryInstance3D", true, false):
		var geometry := found as GeometryInstance3D
		if geometry != null and geometry.visibility_range_end > 0.0:
			model = geometry
			break
	if model == null: return
	for found: Node in fresh.find_children("*", "GeometryInstance3D", true, false):
		var geometry := found as GeometryInstance3D
		if geometry == null: continue
		# A pine LOD that already has its own far range keeps it (when it is nearer).
		if geometry.visibility_range_end <= 0.0 or geometry.visibility_range_end > model.visibility_range_end:
			geometry.visibility_range_end = model.visibility_range_end
			geometry.visibility_range_end_margin = model.visibility_range_end_margin
			geometry.visibility_range_fade_mode = model.visibility_range_fade_mode
		geometry.layers = model.layers
		geometry.cast_shadow = model.cast_shadow

## World positions of every standing pine trunk in the lobes, swapped or already
## there. Read from the live tree nodes, not occupied_tree_positions: that list
## keeps trees later cleared (the court) and misses branch-contact moves, so
## cones would ring phantom trunks.
static func _pine_spots(park: Node3D) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var positions: Array = park.occupied_tree_positions
	var skinny: Array = park.occupied_tree_is_skinny
	for pattern: String in ["ReferencePine_*", "ReferenceBroadleaf_*", "MicroGrove*", "SparseGapTree_*"]:
		for found: Node in park.find_children(pattern, "Node3D", true, false):
			var tree := found as Node3D
			if tree == null or tree.is_queued_for_deletion() or not tree.is_visible_in_tree(): continue
			var gp := Vector2(tree.global_position.x, tree.global_position.z)
			if _w(gp) <= 0.15: continue
			var label := String(tree.name)
			var pine := label.begins_with("ReferencePine") or label.begins_with("MicroGrovePine") or tree.has_meta("biome_pine") or tree.has_meta("iris_grove")
			if not pine and label.begins_with("SparseGapTree_"):
				var index := _nearest_tree_index(positions, gp / 2.0)
				pine = index >= 0 and index < skinny.size() and bool(skinny[index])
			if pine:
				out.append(gp)
				# The pines already standing take the same crown and bark as the new
				# ones (per instance; the shared prototype materials stay as they are).
				if _w(gp) > 0.3: _retint(tree)
	return out

# ---------------------------------------------------------------- pine look

## Which part of a pine-pack material this is: "needle", "bark" or "" (not the
## pack). The pack's textures are bare scene_N.png files, so the texture path
## only says it is the pack; the material name (Bark_Mat, Clusters_Mat,
## Pine_*_Billboard_Mat, kept by every copy) says which part.
static func _pine_part(material: Material) -> String:
	if not (material is BaseMaterial3D): return ""
	if material.has_meta(TINT_META): return String(material.get_meta(TINT_META))
	var base := material as BaseMaterial3D
	if base.albedo_texture == null: return ""
	if not base.albedo_texture.resource_path.to_lower().contains("/pine_trees_pack/"): return ""
	var label := material.resource_name.to_lower()
	if label.contains("bark"): return "bark"
	if label.contains("cluster") or label.contains("billboard"): return "needle"
	return ""

## The matsu copy of a material: the park's foliage adaptation first (cutout,
## sheen and backlight as every other pine), then the needle or bark tint.
static func _matsu_material(source: Material) -> Material:
	if source == null: return null
	if _tints.has(source): return _tints[source]
	if source.has_meta(TINT_META): return source
	var adapted: Material = Foliage.build(source)
	var out: Material = adapted
	var kind := _pine_part(adapted)
	if kind != "":
		var from := adapted as BaseMaterial3D
		var copy := from.duplicate() as BaseMaterial3D
		# Resource.duplicate drops coverage values hidden by the active mode.
		copy.alpha_scissor_threshold = from.alpha_scissor_threshold
		copy.alpha_hash_scale = from.alpha_hash_scale
		copy.albedo_color = from.albedo_color * (NEEDLE_TINT if kind == "needle" else BARK_TINT)
		copy.set_meta(TINT_META, kind)
		out = copy
	_tints[source] = out
	_tints[adapted] = out
	_tints[out] = out
	return out

## Per-instance overrides on a placed pine (its meshes stay shared).
static func _retint(node: Node) -> void:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: meshes.append(node)
	for found: Node in meshes:
		var mesh := found as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh.material_override != null: continue
		for s: int in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(s)
			var tinted := _matsu_material(source)
			if tinted != null and tinted != source: mesh.set_surface_override_material(s, tinted)

# ---------------------------------------------------------------- new pines

static func _chain_to(node: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != top:
		if at is Node3D: t = (at as Node3D).transform * t
		at = at.get_parent()
	return t

## One LOD of a pack pine as batch parts, tinted, with its trunk foot (the
## centre of the lowest bark ring, so the trunk stands exactly on its site and
## collision) and height in the pack's own units.
static func _pack_lod(scene: Node, node_name: String) -> Dictionary:
	var source := scene.find_child(node_name, true, false)
	if source == null: return {}
	var meshes: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
	if source is MeshInstance3D: meshes.append(source)
	var parts: Array = []
	var low := INF
	var high := -INF
	var bark := PackedVector3Array()
	var other := PackedVector3Array()
	for found: Node in meshes:
		var instance := found as MeshInstance3D
		if instance == null or instance.mesh == null: continue
		var relative := _chain_to(instance, scene)
		var mesh := instance.mesh.duplicate() as Mesh
		for s: int in range(mesh.get_surface_count()):
			var material := _matsu_material(instance.get_active_material(s))
			mesh.surface_set_material(s, material)
			var is_bark := _pine_part(material) == "bark"
			var vertices: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vertices:
				var p := relative * v
				low = minf(low, p.y)
				high = maxf(high, p.y)
				if is_bark: bark.append(p)
				else: other.append(p)
		parts.append({"mesh": mesh, "relative": relative})
	if parts.is_empty() or high <= low: return {}
	# The pack lays its trees out on a grid, so the pack origin is never the
	# fallback: without a bark ring, the centre of whatever is lowest.
	var band := low + (high - low) * 0.03
	var foot := _band_centre(bark, band)
	if not foot.is_finite(): foot = _band_centre(other, band)
	if not foot.is_finite(): return {}
	foot.y = low
	return {"parts": parts, "foot": foot, "height": high - low}

static func _band_centre(points: PackedVector3Array, band: float) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for p: Vector3 in points:
		if p.y < band:
			sum += p
			n += 1
	return sum / float(n) if n > 0 else Vector3.INF

static func _tall_pine_variants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not ResourceLoader.exists(PINE_PACK): return out
	var pack := load(PINE_PACK) as PackedScene
	if pack == null: return out
	var scene := pack.instantiate()
	for spec: Array in TALL_PINES:
		var near := _pack_lod(scene, String(spec[0]) + "_LOD1")
		if near.is_empty(): continue
		var far := _pack_lod(scene, String(spec[0]) + "_LOD2")
		if far.is_empty(): far = near
		out.append({"name": String(spec[0]), "share": float(spec[1]), "lods": [near, far]})
	scene.free()
	return out

static func _frame_point(frame: Dictionary, local: Vector2) -> Vector2:
	var eye: Vector2 = frame.eye
	var look: Vector2 = frame.look
	var ahead := (look - eye).normalized()
	# Camera right in xz when looking along `ahead` (north is -z).
	var right := Vector2(-ahead.y, ahead.x)
	return eye + ahead * local.x + right * local.y

## Horizontal screen offset of a world point in a frame's camera, as
## |right| / ahead (the capture camera is 70 degrees vertical at 16:9, so the
## frame edge is at 1.245); INF behind or right at the eye.
static func _frame_slope(frame: Dictionary, p: Vector2) -> float:
	var eye: Vector2 = frame.eye
	var look: Vector2 = frame.look
	var ahead := (look - eye).normalized()
	var d := p - eye
	var along := d.dot(ahead)
	if along < 2.5: return INF
	return absf(d.dot(Vector2(-ahead.y, ahead.x))) / along

## True when a standing tree is on (or next to) one of the concept frame spots.
static func _holds_frame_spot(p: Vector2) -> bool:
	for frame: Dictionary in FRAMES:
		var eye: Vector2 = frame.eye
		if eye.distance_squared_to(p) > 60.0 * 60.0: continue
		for local: Vector2 in frame.pines:
			if _frame_point(frame, local).distance_squared_to(p) < 4.2 * 4.2: return true
	return false

static func _trunk_near(park: Node3D, p: Vector2, radius: float) -> bool:
	if park.has_method("any_trunk_within"): return bool(park.any_trunk_within(p, radius))
	return Kit.trunk_distance(park, p, radius + 1.0) < radius

## Every trunk round the lobes in an 8 m grid (world metres), built once for the
## planting: the park's own index rebuilds on every append. Entries inside the
## bare court/clubhouse footprints are trees the court build cleared (the list
## keeps them), so they do not push pines off the court's edge.
static func _trunk_grid(park: Node3D) -> Dictionary:
	var grid := {}
	var bare: Array[Rect2] = []
	for box: Rect2 in _keep_out: bare.append(box.grow(-2.0))
	for local: Vector2 in park.occupied_tree_positions:
		var p := local * 2.0
		var near := false
		for scan: Rect2 in SCANS:
			if scan.grow(12.0).has_point(p): near = true
		if not near: continue
		var phantom := false
		for box: Rect2 in bare:
			if box.has_point(p): phantom = true
		if not phantom: _grid_add(grid, p)
	return grid

static func _grid_add(grid: Dictionary, p: Vector2) -> void:
	var key := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not grid.has(key): grid[key] = PackedVector2Array()
	(grid[key] as PackedVector2Array).append(p)

static func _grid_near(grid: Dictionary, p: Vector2, radius: float) -> bool:
	var r2 := radius * radius
	for y: int in range(floori((p.y - radius) / 8.0), floori((p.y + radius) / 8.0) + 1):
		for x: int in range(floori((p.x - radius) / 8.0), floori((p.x + radius) / 8.0) + 1):
			var key := Vector2i(x, y)
			if not grid.has(key): continue
			for q: Vector2 in (grid[key] as PackedVector2Array):
				if q.distance_squared_to(p) < r2: return true
	return false

## Live tree nodes round the lobes (after the swap). Every one of them goes into
## `trunks` (a branch-contact move leaves the listed position behind, so the list
## alone would let a new pine stand inside a moved trunk); only mature trees go
## into the returned grid: a frame spot is left to a tree that really stands
## there, never to a sapling the swap does not turn into a tall pine.
static func _live_trees(park: Node3D, trunks: Dictionary) -> Dictionary:
	var grid := {}
	for pattern: String in ["ReferencePine_*", "ReferenceBroadleaf_*", "MicroGrove*", "SparseGapTree_*", "MainlandPineSapling_*"]:
		for found: Node in park.find_children(pattern, "Node3D", true, false):
			var tree := found as Node3D
			if tree == null or tree.is_queued_for_deletion() or not tree.is_visible_in_tree(): continue
			var gp := Vector2(tree.global_position.x, tree.global_position.z)
			if not _in_areas(gp): continue
			if not _grid_near(trunks, gp, 0.5): _grid_add(trunks, gp)
			if not pattern.begins_with("MainlandPineSapling"): _grid_add(grid, gp)
	return grid

## A spot a tall pine may stand on: in the lobes, off paths, trails, water,
## built footprints, props and decks, and 5 m from any other trunk.
static func _pine_ok(park: Node3D, terrain: Node, p: Vector2, trunks: Dictionary) -> bool:
	if _w(p) < 0.3 or _kept_out(p, 2.0): return false
	if _grid_near(trunks, p, 5.0): return false
	if not Kit.open_ground(park, terrain, p, 2.5): return false
	return _bare(park, terrain, p)

## Searches outward round an anchor on a jittered golden-angle spiral. With a
## frame, a candidate must also stay inside that camera's view (`slope_max`),
## so path clearance cannot push a framing trunk off the edge of the picture.
static func _pine_site(park: Node3D, terrain: Node, anchor: Vector2, rng: RandomNumberGenerator, reach: float, trunks: Dictionary, frame: Dictionary = {}, slope_max: float = INF) -> Vector2:
	var start := rng.randf() * TAU
	for k: int in range(24):
		var q := anchor + Vector2.from_angle(start + float(k) * 2.39996) * reach * sqrt(float(k) / 23.0)
		if not frame.is_empty() and _frame_slope(frame, q) > slope_max: continue
		if _pine_ok(park, terrain, q, trunks): return q
	return Vector2.INF

static func _claim_trunk(park: Node3D, p: Vector2, height: float) -> void:
	var layout := p / 2.0
	park.occupied_tree_positions.append(layout)
	park.occupied_tree_is_skinny.append(true)
	var crowns_raw: Variant = park.get("_occupied_tree_crowns")
	if crowns_raw is Dictionary: (crowns_raw as Dictionary)[layout] = height * 0.3

## New tall pines: first round each concept camera (a spot already held by a
## standing trunk is left to it, the swap makes that one a pine), then a few
## in the widest gaps of the main lobes. Drawn as LOD batches per 32 m cell.
static func _plant_pines(park: Node3D, terrain: Node, root: Node3D) -> Dictionary:
	var spots: Array[Vector2] = []
	var out := {"placed": 0, "frames": {}, "held": 0, "fill": 0, "spots": spots}
	var variants := _tall_pine_variants()
	if variants.is_empty(): return out
	# Its own stream, so the floor scatters keep their layout.
	var rng := RandomNumberGenerator.new()
	rng.seed = PINE_SEED
	var sites: Array[Dictionary] = []
	var trunks := _trunk_grid(park)
	var live := _live_trees(park, trunks)
	await park.get_tree().process_frame
	if not is_instance_valid(park): return out
	for frame: Dictionary in FRAMES:
		var count := 0
		for local: Vector2 in frame.pines:
			if sites.size() >= MAX_NEW_PINES: break
			var anchor := _frame_point(frame, local) + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			# Left to a tree that really stands there (the swap made it a pine);
			# a listed trunk with no tree on it (cleared at the court) holds nothing.
			if _grid_near(live, anchor, 3.0):
				out.held += 1
				continue
			var slope_max := maxf(1.15, _frame_slope(frame, anchor) + 0.05)
			var p := _pine_site(park, terrain, anchor, rng, 3.2, trunks, frame, slope_max)
			# Path clearance or a neighbour can close the whole first ring; a wider
			# second ring, still inside the picture, keeps the framing trunk.
			if not p.is_finite(): p = _pine_site(park, terrain, anchor, rng, 5.5, trunks, frame, slope_max)
			if not p.is_finite(): continue
			# The framing trunks nearest the camera are the tallest, so their
			# crowns sit high over the view as in the concepts.
			var tall := rng.randf_range(15.0, 18.0) if local.x < 9.0 else rng.randf_range(12.5, 17.0)
			sites.append({"p": p, "h": tall})
			_claim_trunk(park, p, tall)
			_grid_add(trunks, p)
			count += 1
		out.frames[String(frame.view)] = count
		await park.get_tree().process_frame
		if not is_instance_valid(park): return out
	var fill := 0
	for attempt: int in range(240):
		if fill >= MAX_FILL_PINES or sites.size() >= MAX_NEW_PINES: break
		var scan: Rect2 = SCANS[0] if rng.randf() < 0.85 else SCANS[1]
		var c := Vector2(rng.randf_range(scan.position.x, scan.end.x), rng.randf_range(scan.position.y, scan.end.y))
		if _w(c) < 0.7 or _grid_near(trunks, c, 8.0) or not _pine_ok(park, terrain, c, trunks): continue
		var tall := rng.randf_range(12.5, 17.0)
		sites.append({"p": c, "h": tall})
		_claim_trunk(park, c, tall)
		_grid_add(trunks, c)
		fill += 1
	out.fill = fill
	if park.has_method("invalidate_trunk_index"): park.invalidate_trunk_index()
	# rows[variant][lod]
	var rows: Array = []
	for v: Dictionary in variants: rows.append([[], []])
	var total_share := 0.0
	for v: Dictionary in variants: total_share += float(v.share)
	for i: int in range(sites.size()):
		var p: Vector2 = sites[i].p
		var tall: float = sites[i].h
		var roll := _hash01(p, 61) * total_share
		var pick := 0
		while pick < variants.size() - 1 and roll > float(variants[pick].share):
			roll -= float(variants[pick].share)
			pick += 1
		var ground: float = terrain.height_at(p)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.03, 0.03)) * Basis(Vector3.FORWARD, rng.randf_range(-0.03, 0.03))
		var crown := Vector2(rng.randf_range(0.93, 1.07), rng.randf_range(0.93, 1.07))
		var lods: Array = variants[pick].lods
		for l: int in range(lods.size()):
			var lod: Dictionary = lods[l]
			var s: float = tall / maxf(float(lod.height), 0.001)
			var b := basis.scaled(Vector3(s * crown.x, s, s * crown.y))
			var foot: Vector3 = lod.foot
			(rows[pick][l] as Array).append(Transform3D(b, Vector3(p.x, ground - 0.08, p.y)) * Transform3D(Basis.IDENTITY, -foot))
		# Trunk collision, as the park's other trees have.
		var body := StaticBody3D.new()
		body.name = "MatsuPineTrunk_%02d" % i
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.3
		cylinder.height = 3.2
		shape.shape = cylinder
		body.add_child(shape)
		root.add_child(body)
		body.global_position = Vector3(p.x, ground + 1.6, p.y)
		spots.append(p)
	for v: int in range(variants.size()):
		var lods: Array = variants[v].lods
		for l: int in range(lods.size()):
			var begin := 0.0 if l == 0 else PINE_NEAR_END
			var end := PINE_NEAR_END if l == 0 else PINE_FAR_END
			_batch_lod(root, "MatsuPine%d_LOD%d" % [v, l + 1], lods[l], rows[v][l], begin, end)
	out.placed = sites.size()
	return out

## One MultiMesh per part per 32 m cell, shown between `begin` and `end` metres.
## Cells go by trunk position (t * foot): the pack lays its trees out on a grid,
## so a row's own origin sits tens of metres off the tree.
static func _batch_lod(parent: Node3D, label: String, lod: Dictionary, rows: Array, begin: float, end: float) -> void:
	var parts: Array = lod.parts
	var foot: Vector3 = lod.foot
	if rows.is_empty() or parts.is_empty(): return
	var cells := {}
	for t: Transform3D in rows:
		var at := t * foot
		var key := Vector2i(floori(at.x / 32.0), floori(at.z / 32.0))
		if not cells.has(key): cells[key] = []
		(cells[key] as Array).append(t)
	for key: Vector2i in cells:
		var list: Array = cells[key]
		var centre := Vector3((key.x + 0.5) * 32.0, 0.0, (key.y + 0.5) * 32.0)
		for part: Dictionary in parts:
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.mesh = part.mesh
			many.instance_count = list.size()
			many.buffer = Kit.pack_transforms(list, part.relative, centre)
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%d_%d" % [label, key.x, key.y]
			node.multimesh = many
			node.position = centre
			node.visibility_range_begin = begin
			node.visibility_range_begin_margin = 4.0 if begin > 0.0 else 0.0
			node.visibility_range_end = end
			node.visibility_range_end_margin = 4.0 if end < PINE_FAR_END else 15.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(node)

# ---------------------------------------------------------------- thinning

## Which kind of low planting a node is, from its path and mesh name.
## Empty means leave it alone.
static func _class_of(label: String) -> String:
	# Lilac first: its meshes are named "Lilac_bush", which the "bush" guard
	# below would otherwise leave alone.
	if label.contains("lilac") and not label.contains("biome"): return "lilac"
	for word: String in ["iris", "flower", "azalea", "moss", "periwinkle", "lantern", "biome", "reed", "lily", "sakura", "petal", "maple", "evergreen", "shrub", "bush", "boulder", "stone"]:
		if label.contains(word): return ""
	for word: String in ["fountain", "emerald", "woodlandfill", "spiky", "meadow", "dense", "tuft", "clump", "drift", "forestgrass"]:
		if label.contains(word): return "spiky"
	for word: String in ["grass", "blade", "lawn"]:
		if label.contains(word): return "lawn"
	if label.contains("fern"): return "fern"
	if label.contains("lilac") or label.contains("flowering"): return "lilac"
	return ""

## Path below the park (the scene's own ancestors must not decide the class)
## plus the mesh name.
static func _label(park: Node3D, node: Node) -> String:
	var mesh_name := ""
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null and (node as MultiMeshInstance3D).multimesh.mesh != null:
		mesh_name = (node as MultiMeshInstance3D).multimesh.mesh.resource_name
	return (str(park.get_path_to(node)) + " " + mesh_name).to_lower()

## Share hidden at full weight, per class: the floor is needles, not grass.
## The concept floor is nearly bare duff, so spiky beds and lawn blades go almost
## entirely in the core; ferns and lilac masses only open up for the sightlines.
## Round 4: the needle floor reads clean. Spiky tufts go entirely once the
## pine weight is up (they only feather out at the woods' edge), and the patch
## noise no longer lets up to half of them survive in "lighter gaps"; lawn
## blades go almost entirely. Evergreen mounds and iris are this builder's own
## planting and are not touched.
const HIDE := {"spiky": 1.0, "lawn": 0.97, "fern": 0.7, "lilac": 0.8}
const SALT := {"spiky": 51, "lawn": 52, "fern": 53, "lilac": 54}
# How much the patch noise may lift the kept share, per class.
const PATCH := {"spiky": 0.0, "lawn": 0.06, "fern": 0.3, "lilac": 0.3}

static func _keep(p: Vector2, kind: String) -> bool:
	var w := _w(p)
	if w <= 0.0: return true
	# Patchy, not even: what ferns and lilac survive gather in the lighter gaps.
	var patch := 1.0 - float(PATCH[kind]) * (0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * 1.9 + Vector2(31, 7)))
	var hide := clampf(float(HIDE[kind]) * smoothstep(0.15, 0.6, w) * patch, 0.0, 1.0)
	return not Biomes.pick(p, hide, int(SALT[kind]))

static func _thin(park: Node3D) -> Dictionary:
	var report := {}
	var helper: Variant = load(THIN_ALL) if ResourceLoader.exists(THIN_ALL) else null
	if not _has_static(helper, "hide_low_planting"): helper = null
	report["helper"] = "thin_all" if helper != null else "kit"
	# The grass-detail blades are built under the park (park/MidoriGrassDetail);
	# the /root autoload of that name only builds them, so the park covers all.
	# Fallback only: distance-detail chunks share their source's mesh, so they
	# are classified by that mesh.
	var by_mesh := {}
	if helper == null:
		for node: MultiMeshInstance3D in park.find_children("*", "MultiMeshInstance3D", true, false):
			if node.multimesh == null or node.multimesh.mesh == null: continue
			var label := _label(park, node)
			if label.contains("midoridistancedetail"): continue
			var id := node.multimesh.mesh.get_instance_id()
			if not by_mesh.has(id): by_mesh[id] = _class_of(label)
		await park.get_tree().process_frame
		if not is_instance_valid(park): return report
	for kind: String in HIDE:
		var keep := func(p: Vector2) -> bool: return _keep(p, kind)
		if helper != null:
			# The helper also reaches the distance-detail copies that actually draw
			# the grass; one call per scan box keeps each pass to the lobes.
			var label_filter := func(label: String) -> bool: return _class_of(label.to_lower()) == kind
			var parts: Array = []
			for scan: Rect2 in SCANS:
				parts.append(helper.hide_low_planting(park, label_filter, keep, scan))
				await park.get_tree().process_frame
				if not is_instance_valid(park): return report
			report[kind] = parts
		else:
			var node_filter := func(node: MultiMeshInstance3D) -> bool:
				if not _in_any(node): return false
				var id := node.multimesh.mesh.get_instance_id() if node.multimesh.mesh != null else 0
				var cls: String = by_mesh[id] if by_mesh.has(id) else _class_of(_label(park, node))
				return cls == kind
			report[kind] = Kit.thin_multimeshes([park], node_filter, keep)
			await park.get_tree().process_frame
			if not is_instance_valid(park): return report
	return report

static func _has_static(script: Variant, method: String) -> bool:
	if not (script is Script): return false
	for entry: Dictionary in (script as Script).get_script_method_list():
		if String(entry.name) == method: return true
	return false

## Cheap reject for nodes whose bounds miss every lobe.
static func _in_any(node: MultiMeshInstance3D) -> bool:
	if node.multimesh == null or node.multimesh.mesh == null: return false
	var box: AABB = node.global_transform * node.multimesh.get_aabb()
	var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(1.0)
	for rect: Rect2 in AREAS:
		if rect.intersects(flat): return true
	return false

# ---------------------------------------------------------------- floor

## A small closed pine cone, about 7 cm long, lying on its side.
static func _cone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.012, 0.015), Vector2(0.028, 0.023), Vector2(0.046, 0.021), Vector2(0.062, 0.012), Vector2(0.071, 0.0)]
	var sides := 7
	var pts: Array = []
	for r: int in range(rings.size()):
		var ring := PackedVector3Array()
		for k: int in range(sides):
			var a := TAU * (float(k) + 0.5 * float(r % 2)) / float(sides)
			var radius := rings[r].y * (0.9 + 0.2 * fposmod(sin(float(k * 7 + r * 3)) * 43.7, 1.0))
			ring.append(Vector3(rings[r].x - 0.035, cos(a) * radius + 0.021, sin(a) * radius))
		pts.append(ring)
	for r: int in range(rings.size() - 1):
		var a_ring: PackedVector3Array = pts[r]
		var b_ring: PackedVector3Array = pts[r + 1]
		for k: int in range(sides):
			var quad: Array[Vector3] = [a_ring[k], b_ring[k], b_ring[(k + 1) % sides], a_ring[(k + 1) % sides]]
			for v: Vector3 in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				st.set_normal(Vector3(0.0, v.y - 0.021, v.z).normalized() if absf(v.y - 0.021) + absf(v.z) > 0.0001 else Vector3.UP)
				st.add_vertex(v)
	return st.commit()

static func _cone_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Cones drop under pine crowns, thickest near the trunk.
static func _cones(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, pines: Array[Vector2]) -> int:
	var rows: Array = []
	var step := 0
	for trunk: Vector2 in pines:
		var w := _w(trunk)
		var count := int(rng.randf_range(6.0, 22.0) * w)
		for k: int in range(count):
			var a := rng.randf() * TAU
			var p := trunk + Vector2(cos(a), sin(a)) * (0.5 + 5.5 * sqrt(rng.randf()))
			if terrain.water_at(p) or _kept_out(p): continue
			if park.path_edge_distance_world(p) < 0.3 and rng.randf() < 0.85: continue
			# The mesh already lies on its side; a yaw and a slight roll settle it.
			var basis := (Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6))).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25))
			var c := Color(0.36, 0.24, 0.13).lerp(Color(0.24, 0.17, 0.1), rng.randf())
			if rng.randf() < 0.3: c = c.lerp(Color(0.34, 0.31, 0.27), 0.6)
			rows.append([Transform3D(basis, Vector3(p.x, terrain.height_at(p) - 0.006, p.y)), c * rng.randf_range(0.85, 1.08)])
		step += 1
		if step % 40 == 0:
			await park.get_tree().process_frame
			if not is_instance_valid(park): return 0
	if rows.is_empty(): return 0
	Kit.cell_batches(root, "PineCones", _cone_mesh(), _cone_material(), rows, 12.0, 32.0, false)
	return rows.size()

## Scales the materials of loaded parts towards the pine-duff palette.
static func _tone(proto: Dictionary, tint: Color, roughness: float = 0.9) -> Dictionary:
	for part: Dictionary in proto.parts:
		var mesh: Mesh = part.mesh
		for s: int in range(mesh.get_surface_count()):
			var source := mesh.surface_get_material(s)
			if source is BaseMaterial3D:
				var material := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
				material.albedo_color = material.albedo_color * tint
				material.roughness = roughness
				mesh.surface_set_material(s, material)
	return proto

## A lying piece (branch) seated flat: `length` across its long side.
static func _lay(proto: Dictionary, terrain: Node, p: Vector2, length: float, yaw: float, sink: float) -> Transform3D:
	var box: AABB = proto.box
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * length / maxf(maxf(box.size.x, box.size.z), 0.001))
	var footprint := Transform3D(basis, Vector3.ZERO) * box
	var anchor := Vector3(footprint.get_center().x, footprint.position.y, footprint.get_center().z)
	return Transform3D(basis, Vector3(p.x, terrain.height_at(p) - sink, p.y) - anchor)

## Half-buried stones and a few fallen branches on the needle floor.
static func _floor_litter(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var stones: Array[Dictionary] = []
	for i: int in range(6): stones.append(_tone(Kit.file_parts(FLOOR + "stone_%02d.glb" % i), Color(0.82, 0.78, 0.72)))
	var branches: Array[Dictionary] = []
	for i: int in range(3): branches.append(_tone(Kit.file_parts(FLOOR + "branch_%02d.glb" % i), Color(0.78, 0.7, 0.62)))
	var stone_rows := {}
	var branch_rows := {}
	var stone_count := 0
	var branch_count := 0
	var since := Kit.frames_now()
	for scan: Rect2 in SCANS:
		for z: int in range(int(scan.position.y), int(scan.end.y), 3):
			# Placement only reads the ground, paths and physics (nothing is added
			# inside this loop), so it yields on time, not on a row count.
			await Kit.slice(park)
			if not is_instance_valid(park): return {"stones": 0, "branches": 0}
			for x: int in range(int(scan.position.x), int(scan.end.x), 3):
				var p := Vector2(x + rng.randf() * 3.0, z + rng.randf() * 3.0)
				var roll := rng.randf()
				var w := _w(p)
				if w < 0.2 or _kept_out(p): continue
				# Litter gathers in loose drifts, so the floor never reads as evenly dotted.
				var drift := 0.5 + 0.5 * Biomes.noise().get_noise_2dv(p * 0.9 + Vector2(12, 40))
				if roll < 0.05 * w * (0.4 + drift):
					if not Kit.open_ground(park, terrain, p, 0.9, 1.2) or not _bare(park, terrain, p): continue
					var k := rng.randi_range(0, stones.size() - 1)
					if stones[k].parts.is_empty(): continue
					var size := rng.randf_range(0.1, 0.32)
					if not stone_rows.has(k): stone_rows[k] = []
					stone_rows[k].append(Kit.seat(stones[k], terrain, p, size, rng.randf() * TAU, size * 0.35))
					stone_count += 1
				elif roll < 0.11 * w * (0.4 + drift):
					if not Kit.open_ground(park, terrain, p, 1.3, 1.0) or not _bare(park, terrain, p): continue
					var k := rng.randi_range(0, branches.size() - 1)
					if branches[k].parts.is_empty(): continue
					if not branch_rows.has(k): branch_rows[k] = []
					branch_rows[k].append(_lay(branches[k], terrain, p, rng.randf_range(0.8, 2.1), rng.randf() * TAU, 0.02))
					branch_count += 1
	await Kit.settle(park, since)
	if not is_instance_valid(park): return {"stones": 0, "branches": 0}
	for k: int in stone_rows: Kit.batch_parts(root, "PineFloorStones%d" % k, stones[k], stone_rows[k], 32.0, 70.0)
	for k: int in branch_rows: Kit.batch_parts(root, "PineFloorBranches%d" % k, branches[k], branch_rows[k], 32.0, 60.0, false)
	return {"stones": stone_count, "branches": branch_count}

# ---------------------------------------------------------------- planting

## Low clipped evergreen mounds in odd drifts (1, 3, sometimes 5), gathered near
## the clubhouse and court and only now and then out in the woods.
static func _mounds(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var spots: Array[Vector2] = []
	if not ResourceLoader.exists(EVERGREEN): return {"count": 0, "spots": spots}
	var proto := _tone(Kit.file_parts(EVERGREEN), Color(0.58, 0.62, 0.46), 0.88)
	if proto.parts.is_empty(): return {"count": 0, "spots": spots}
	var box: AABB = proto.box
	var centres: Array[Vector2] = []
	# First the drifts each concept view shows near the path (a big lead mound
	# with one or two lower ones), then the landmark and woodland drifts.
	for frame: Dictionary in FRAMES:
		for local: Vector2 in frame.mounds:
			var c := _frame_point(frame, local) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
			# The concepts set these against the court fence and the clubhouse wall:
			# the footprint already carries a 2 m margin, so a framed drift may come
			# to ~1.4 m of the built edge (a lead mound is up to ~1.25 m in radius).
			if _w(c) > 0.15 and not _kept_out(c, FRAMED_PAD): centres.append(c)
	var framed := centres.size()
	# Drifts sit just outside each built footprint (any side), never on it: the
	# court alone is 32 x 19 m, so a ring round its centre landed on the court.
	for footprint: Rect2 in _keep_out:
		if _w(footprint.get_center()) < 0.3: continue
		var found := 0
		for attempt: int in range(60):
			if found >= 3: break
			var c := _ring_point(footprint, rng, 2.5, 8.0)
			if _w(c) < 0.4: continue
			var spaced := true
			for other: Vector2 in centres: if other.distance_to(c) < 7.0: spaced = false
			if spaced:
				centres.append(c)
				found += 1
	# A few drifts out under the pines, well apart.
	for attempt: int in range(300):
		if centres.size() >= 16: break
		var scan: Rect2 = SCANS[0] if rng.randf() < 0.8 else SCANS[1]
		var c := Vector2(rng.randf_range(scan.position.x, scan.end.x), rng.randf_range(scan.position.y, scan.end.y))
		if _w(c) < 0.6 or _kept_out(c, 2.0): continue
		var spaced := true
		for other: Vector2 in centres: if other.distance_to(c) < 22.0: spaced = false
		if spaced: centres.append(c)
	var rows: Array[Transform3D] = []
	for ci: int in range(centres.size()):
		var c: Vector2 = centres[ci]
		var frame := ci < framed
		var roll := rng.randf()
		var want := (2 if roll < 0.6 else 3) if frame else (1 if roll < 0.35 else (3 if roll < 0.85 else 5))
		var placed: Array[Vector2] = []
		for attempt: int in range(30):
			if placed.size() >= want or rows.size() >= MAX_MOUNDS: break
			var a := rng.randf() * TAU
			# A framed drift keeps its lead mound where the view wants it.
			var reach := (0.7 if placed.is_empty() else 1.0 + 0.7 * float(want)) if frame else 1.0 + 0.9 * float(want)
			var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(0.0, reach)
			var crowded := false
			for other: Vector2 in placed: if other.distance_to(p) < 1.5: crowded = true
			# Neighbouring drifts may be only 7 m apart: no mound inside another.
			for other: Vector2 in spots: if other.distance_to(p) < 1.8: crowded = true
			if crowded or _kept_out(p, FRAMED_PAD if frame else 1.2): continue
			if not Kit.open_ground(park, terrain, p, 1.6, 2.2): continue
			# Framed mounds may lean into thinned planting; the rest keep clear.
			if not frame and not _clear_of_plants(park, p, 1.0): continue
			if not _bare(park, terrain, p): continue
			# The first of a drift is the largest; the rest are lower and smaller.
			var lead := placed.is_empty()
			var height := rng.randf_range(0.65, 0.95) if lead else rng.randf_range(0.4, 0.7)
			var width := height * rng.randf_range(2.0, 2.6)
			var widen := width / maxf(maxf(box.size.x, box.size.z) * height / maxf(box.size.y, 0.001), 0.001)
			var extra := Basis.IDENTITY.scaled(Vector3(widen, 1.0, widen * rng.randf_range(0.85, 1.0)))
			rows.append(Kit.seat(proto, terrain, p, height, rng.randf() * TAU, 0.1, extra))
			placed.append(p)
		spots.append_array(placed)
		await park.get_tree().process_frame
		if not is_instance_valid(park): return {"count": 0, "spots": spots}
	Kit.batch_parts(root, "PineClippedMounds", proto, rows, 32.0, 120.0)
	return {"count": rows.size(), "spots": spots}

## Small Iris japonica clumps at mound feet, away from the existing grove carpets.
static func _iris(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, mounds: Array[Vector2]) -> Dictionary:
	var out := {"clumps": 0, "fans": 0, "stems": 0}
	if not ResourceLoader.exists(IRIS): return out
	var scene: Node = load(IRIS).instantiate()
	var fan_node := scene.find_child("LeafFan", true, false) as MeshInstance3D
	var stem_node := scene.find_child("FlowerStem", true, false) as MeshInstance3D
	# The meadow and other planting share this GLB. Tone only the pine copies.
	var fan_mesh: Mesh = fan_node.mesh.duplicate() if fan_node != null and fan_node.mesh != null else null
	var stem_mesh: Mesh = stem_node.mesh.duplicate() if stem_node != null and stem_node.mesh != null else null
	scene.free()
	if fan_mesh == null: return out
	var fan := {"parts": [{"mesh": fan_mesh, "relative": Transform3D.IDENTITY}], "box": fan_mesh.get_aabb()}
	var stem := {"parts": [{"mesh": stem_mesh, "relative": Transform3D.IDENTITY}] if stem_mesh != null else [], "box": stem_mesh.get_aabb() if stem_mesh != null else AABB()}
	_tone(fan, Color(0.73, 0.70, 0.94), 0.93)
	_tone(stem, Color(0.91, 0.86, 0.96), 0.88)
	var fans: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var centres: Array[Vector2] = []
	# The clumps each concept view shows beside the path and the mounds.
	for frame: Dictionary in FRAMES:
		for local: Vector2 in frame.iris:
			var c := _frame_point(frame, local) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			if _w(c) < 0.15 or _kept_out(c, FRAMED_PAD) or _trunk_near(park, c, 1.2): continue
			var next_to_mound := false
			for m: Vector2 in mounds:
				if m.distance_to(c) < 4.5:
					next_to_mound = true
					break
			if not next_to_mound: continue
			centres.append(c)
			break
	var framed := centres.size()
	# Some clumps sit at the foot of a mound, as in the concept.
	for m: Vector2 in mounds:
		if centres.size() >= MAX_IRIS_CLUMPS: break
		if rng.randf() > 0.4: continue
		var a := rng.randf() * TAU
		var foot := m + Vector2(cos(a), sin(a)) * rng.randf_range(1.6, 2.1)
		if Woodland.grove_at(foot) >= 0 or Kit.trunk_distance(park, foot, 3.0) < 1.8: continue
		var spaced := true
		for other: Vector2 in centres: if other.distance_to(foot) < 4.0: spaced = false
		if spaced: centres.append(foot)
	for ci: int in range(centres.size()):
		var c: Vector2 = centres[ci]
		var pad := FRAMED_PAD if ci < framed else 0.0
		var roots := rng.randi_range(2, 3)
		var placed := 0
		var angle := rng.randf() * TAU
		for k: int in range(roots * 3):
			if placed >= roots: break
			# Roots spread from the rhizome in an irregular blob, longer one way.
			var off := Vector2(rng.randf_range(-0.27, 0.27), rng.randf_range(-0.16, 0.16)).rotated(angle)
			var p := c + off * sqrt(rng.randf())
			if _kept_out(p, pad): continue
			# Clear of the mounds' skirts (a lead mound is up to ~2.5 m across).
			var under_mound := false
			for m: Vector2 in mounds: if m.distance_to(p) < 1.35: under_mound = true
			if under_mound: continue
			if not Kit.open_ground(park, terrain, p, 0.8): continue
			if not _clear_of_plants(park, p, 0.3) or not _bare(park, terrain, p): continue
			var root_at := Vector3(p.x, terrain.height_at(p) - 0.008, p.y)
			var size := rng.randf_range(0.73, 0.97)
			var yaw := rng.randf() * TAU
			for f: int in range(rng.randi_range(1, 2)):
				var leaf := Basis(Vector3.UP, yaw + f * rng.randf_range(0.8, 1.9)) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.21))
				fans.append(Transform3D(leaf.scaled(Vector3(1.0, 0.94, 1.0) * size), root_at))
			if stem_mesh != null and (placed == 0 or rng.randf() < 0.32):
				stems.append(Transform3D(Basis(Vector3.UP, yaw + 1.3).scaled(Vector3.ONE * size), root_at))
			placed += 1
		if placed > 0: out.clumps += 1
	await park.get_tree().process_frame
	if not is_instance_valid(park): return out
	Kit.batch_parts(root, "PineIrisLeaves", fan, fans, 24.0, 55.0, false)
	if not stems.is_empty(): Kit.batch_parts(root, "PineIrisStems", stem, stems, 24.0, 55.0, false)
	out.fans = fans.size()
	out.stems = stems.size()
	return out
